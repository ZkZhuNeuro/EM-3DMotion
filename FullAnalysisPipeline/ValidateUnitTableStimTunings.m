function ValidationReport = ValidateUnitTableStimTunings(stateFile, options)
%VALIDATEUNITTABLESTIMTUNINGS Audit a completed population Stim result.
%
% Recomputes NoStim, Stim, and merged unit-1 tuning from every linked
% trial-FR file and compares all means, SEMs, and counts with the saved
% unit_table_stim cells. A compact CSV/MAT audit report is written beside
% the state file by default.

arguments
    stateFile (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\unit_table_stim.mat"
    options.WriteReport (1, 1) logical = true
    options.Tolerance (1, 1) double {mustBeNonnegative} = 1e-10
end

if ~isfile(stateFile)
    error('UnitTableStimValidation:MissingState', ...
        'State file does not exist: %s', stateFile);
end
loaded = load(stateFile, 'unit_table_stim', 'SessionManifest', ...
    'PipelineMetadata');
if ~isfield(loaded, 'unit_table_stim') || ...
        ~istable(loaded.unit_table_stim)
    error('UnitTableStimValidation:MissingTable', ...
        '%s does not contain table unit_table_stim.', stateFile);
end
tableData = loaded.unit_table_stim;
rowCount = height(tableData);
if rowCount == 0
    error('UnitTableStimValidation:EmptyTable', ...
        'unit_table_stim contains no rows.');
end

requiredColumns = [ ...
    "stim_tuning_status", "stim_tuning_source_signature", ...
    "stim_tuning_trial_FR_file", "stim_tuning_mean_noStim", ...
    "stim_tuning_SEM_noStim", "stim_tuning_mean_stim", ...
    "stim_tuning_SEM_stim", "stim_tuning_mean_merged", ...
    "stim_tuning_SEM_merged", "stim_tuning_n_noStim", ...
    "stim_tuning_n_stim", "stim_tuning_n_merged", ...
    "stim_tuning_coherence", "stim_tuning_extraction_summary", ...
    "stim_tuning_noStim_trial_count", ...
    "stim_tuning_stim_trial_count", "NChannels"];
missingColumns = setdiff(requiredColumns, ...
    string(tableData.Properties.VariableNames));
if ~isempty(missingColumns)
    error('UnitTableStimValidation:MissingColumns', ...
        'Missing required table column(s): %s', join(missingColumns, ', '));
end

if any(~startsWith(tableData.stim_tuning_status, "Success"))
    rows = find(~startsWith(tableData.stim_tuning_status, "Success"));
    error('UnitTableStimValidation:NonSuccessRows', ...
        'Non-success status remains at row(s): %s', mat2str(rows(:)'));
end

curveNames = ["mean_noStim", "SEM_noStim", "mean_stim", ...
    "SEM_stim", "mean_merged", "SEM_merged"];
tableCurveColumns = ["stim_tuning_mean_noStim", ...
    "stim_tuning_SEM_noStim", "stim_tuning_mean_stim", ...
    "stim_tuning_SEM_stim", "stim_tuning_mean_merged", ...
    "stim_tuning_SEM_merged"];
channelTrimCount = 0;
memorySafeCount = 0;
totalTrialFileBytes = 0;

for row = 1:rowCount
    trialFile = tableData.stim_tuning_trial_FR_file(row);
    if ~isfile(trialFile)
        error('UnitTableStimValidation:MissingTrialFile', ...
            'Row %d trial-FR file is missing: %s', row, trialFile);
    end
    information = dir(trialFile);
    totalTrialFileBytes = totalTrialFileBytes + information(1).bytes;
    trialData = load(trialFile, 'StimTrialFR');
    if ~isfield(trialData, 'StimTrialFR')
        error('UnitTableStimValidation:MissingTrialStruct', ...
            'Row %d file lacks StimTrialFR.', row);
    end
    trial = trialData.StimTrialFR;
    requiredFields = {'SourceSignature', 'FiringRateHz', 'TrialSummary', ...
        'Coherence', 'ExtractionSummary'};
    if ~all(isfield(trial, requiredFields))
        error('UnitTableStimValidation:MissingTrialFields', ...
            'Row %d StimTrialFR lacks required fields.', row);
    end
    if string(trial.SourceSignature) ~= ...
            tableData.stim_tuning_source_signature(row)
        error('UnitTableStimValidation:SourceSignatureMismatch', ...
            'Row %d trial/source signatures differ.', row);
    end
    if size(trial.FiringRateHz, 1) ~= height(trial.TrialSummary)
        error('UnitTableStimValidation:TrialAlignmentMismatch', ...
            'Row %d firing-rate rows do not align with TrialSummary.', row);
    end
    expectedChannels = double(tableData.NChannels(row));
    if size(trial.FiringRateHz, 2) ~= expectedChannels
        error('UnitTableStimValidation:ChannelCountMismatch', ...
            'Row %d has %d trial-FR channels; expected %d.', row, ...
            size(trial.FiringRateHz, 2), expectedChannels);
    end
    coherence = double(trial.Coherence(:)');
    if ~isequal(coherence, tableData.stim_tuning_coherence{row})
        error('UnitTableStimValidation:CoherenceMismatch', ...
            'Row %d coherence axes differ.', row);
    end

    [noStim, stim, merged] = recomputeGroups( ...
        trial.FiringRateHz, trial.TrialSummary, coherence);
    expectedCurves = {noStim.Mean, noStim.SEM, stim.Mean, stim.SEM, ...
        merged.Mean, merged.SEM};
    for curveIndex = 1:numel(tableCurveColumns)
        actual = tableData.(tableCurveColumns(curveIndex)){row};
        assertArraysEqual(actual, expectedCurves{curveIndex}, ...
            options.Tolerance, row, curveNames(curveIndex));
    end
    if ~isequal(tableData.stim_tuning_n_noStim{row}, noStim.Count) || ...
            ~isequal(tableData.stim_tuning_n_stim{row}, stim.Count) || ...
            ~isequal(tableData.stim_tuning_n_merged{row}, merged.Count)
        error('UnitTableStimValidation:CountMatrixMismatch', ...
            'Row %d saved count matrices differ from trial data.', row);
    end
    if ~isequal(merged.Count, noStim.Count + stim.Count)
        error('UnitTableStimValidation:MergedCountMismatch', ...
            'Row %d merged counts do not equal NoStim plus Stim.', row);
    end
    if sum(noStim.Count, 'all') ~= ...
            tableData.stim_tuning_noStim_trial_count(row) || ...
            sum(stim.Count, 'all') ~= ...
            tableData.stim_tuning_stim_trial_count(row)
        error('UnitTableStimValidation:TrialCountMismatch', ...
            'Row %d scalar and cellwise trial counts differ.', row);
    end

    summary = trial.ExtractionSummary;
    if isfield(summary, 'ChannelSelection') && ...
            summary.ChannelSelection.Applied
        channelTrimCount = channelTrimCount + 1;
    end
    if isfield(summary, 'MemorySafeSlimInput') && ...
            summary.MemorySafeSlimInput.Used
        memorySafeCount = memorySafeCount + 1;
    end
end

trialFolder = fileparts(tableData.stim_tuning_trial_FR_file(1));
allTrialFiles = dir(fullfile(trialFolder, 'Row*_StimTrialFR.mat'));
if numel(allTrialFiles) ~= rowCount
    error('UnitTableStimValidation:UnexpectedTrialFileCount', ...
        'Found %d trial-FR files for %d table rows.', ...
        numel(allTrialFiles), rowCount);
end

warningCount = nnz(tableData.stim_tuning_status == ...
    "SuccessWithEyeCheckWarning");
successCount = nnz(tableData.stim_tuning_status == "Success");
ValidationReport = table( ...
    ["RowsValidated"; "TrialFRFiles"; "Success"; ...
    "SuccessWithEyeCheckWarning"; "NoStimTrials"; "StimTrials"; ...
    "ChannelTrimSessions"; "MemorySafeInputSessions"; ...
    "TrialFRBytes"], ...
    [rowCount; numel(allTrialFiles); successCount; warningCount; ...
    sum(tableData.stim_tuning_noStim_trial_count); ...
    sum(tableData.stim_tuning_stim_trial_count); channelTrimCount; ...
    memorySafeCount; totalTrialFileBytes], ...
    'VariableNames', {'Metric', 'Value'});
ValidationReport.Properties.Description = ...
    "All tuning means, SEMs, and counts matched trial-level recomputation.";

if options.WriteReport
    outputFolder = fileparts(stateFile);
    reportCSV = fullfile(outputFolder, 'StimTuningValidationReport.csv');
    reportMAT = fullfile(outputFolder, 'StimTuningValidationReport.mat');
    writetable(ValidationReport, reportCSV);
    ValidatedAtUTC = datetime('now', 'TimeZone', 'UTC');
    save(reportMAT, 'ValidationReport', 'ValidatedAtUTC');
end

fprintf('Validated %d rows and %d trial-FR files with no mismatches.\n', ...
    rowCount, numel(allTrialFiles));
end


function [noStim, stim, merged] = recomputeGroups( ...
    firingRate, trialSummary, coherence)
noStim = recomputeGroup(firingRate, trialSummary, coherence, false);
stim = recomputeGroup(firingRate, trialSummary, coherence, true);
merged = recomputeGroup(firingRate, trialSummary, coherence, []);
end


function result = recomputeGroup( ...
    firingRate, trialSummary, coherence, electricalStimValue)
channelCount = size(firingRate, 2);
meanFR = nan(4, numel(coherence), channelCount);
semFR = nan(4, numel(coherence), channelCount);
count = zeros(4, numel(coherence));
for cue = 1:4
    for coherenceIndex = 1:numel(coherence)
        mask = trialSummary.Included & trialSummary.Condition == cue & ...
            round(trialSummary.Coherence, 2) == ...
            round(coherence(coherenceIndex), 2);
        if ~isempty(electricalStimValue)
            mask = mask & ...
                trialSummary.ElectricalStim == electricalStimValue;
        end
        count(cue, coherenceIndex) = nnz(mask);
        if count(cue, coherenceIndex) == 0
            continue
        end
        values = reshape(firingRate(mask, :, 1), [], channelCount);
        meanFR(cue, coherenceIndex, :) = mean(values, 1, 'omitnan');
        semFR(cue, coherenceIndex, :) = ...
            std(values, 0, 1, 'omitnan') ./ sqrt(count(cue, coherenceIndex));
    end
end
result = struct('Mean', meanFR, 'SEM', semFR, 'Count', count);
end


function assertArraysEqual(actual, expected, tolerance, row, label)
if ~isequal(size(actual), size(expected)) || ...
        ~isequal(isnan(actual), isnan(expected)) || ...
        ~isequal(isinf(actual), isinf(expected))
    error('UnitTableStimValidation:ArrayShapeOrMissingnessMismatch', ...
        'Row %d %s shape or missingness differs.', row, label);
end
delta = abs(actual - expected);
delta = delta(isfinite(delta));
if any(delta > tolerance)
    error('UnitTableStimValidation:ArrayValueMismatch', ...
        'Row %d %s differs by up to %.12g.', row, label, max(delta));
end
end

function [unitTablePrepared, audit] = ...
    PrepareStimNoStimSelectionCriteria(unitTable, options)
%PREPARESTIMNOSTIMSELECTIONCRITERIA Recompute neural gates from Stim NoStim.
%
% Replaces inherited Quick-task p_AI and Z3D_v_Z2D values with the same
% direction-test and partial-correlation calculations used by the selected
% Quick-channel pipeline, evaluated at StimElec using 3DMotionStim NoStim
% trials. Max OD from the same tuning source assigns the dominant eye.

arguments
    unitTable table
    options.PThreshold (1, 1) double {mustBePositive} = 0.05
end

requireVariables(unitTable, ["Date", "Monkey", "StimElec", "NChannels", ...
    "p_AI", "Z3D_v_Z2D", "stim_tuning_status", ...
    "stim_tuning_trial_FR_file", "stim_tuning_table_unit_index", ...
    "stim_tuning_mean_noStim", "stim_tuning_n_noStim", ...
    "stim_tuning_coherence", "stim_noStim_OD_max"]);

unitTablePrepared = unitTable;
rowCount = height(unitTable);
tableRow = (1:rowCount)';
monkey = strings(rowCount, 1);
recordingDate = normalizeDateColumn(unitTable.Date);
stimChannel = nan(rowCount, 1);
tableUnitIndex = nan(rowCount, 1);
trialFile = strings(rowCount, 1);
originalMonoLP = nan(rowCount, 1);
originalMonoRP = nan(rowCount, 1);
stimMonoLP = nan(rowCount, 1);
stimMonoRP = nan(rowCount, 1);
stimCueP = repmat({nan(4, 1)}, rowCount, 1);
originalZ = nan(rowCount, 1);
stimZ = nan(rowCount, 1);
signedMaxOD = nan(rowCount, 1);
dominantEye = strings(rowCount, 1);
originalPass = false(rowCount, 1);
stimPass = false(rowCount, 1);
gateChanged = false(rowCount, 1);
unitTypeChanged = false(rowCount, 1);
noStimTrialCount = zeros(rowCount, 1);
finiteFRCount = zeros(rowCount, 1);
outlierFRCount = zeros(rowCount, 1);
status = repmat("Pending", rowCount, 1);
message = strings(rowCount, 1);

for row = 1:rowCount
    monkey(row) = getRowText(unitTable.Monkey, row);
    stimChannel(row) = numericScalar(unitTable.StimElec, row);
    tableUnitIndex(row) = numericScalar( ...
        unitTable.stim_tuning_table_unit_index, row);
    trialFile(row) = getRowText(unitTable.stim_tuning_trial_FR_file, row);
    originalP = double(numericCellValue(unitTable.p_AI, row));
    originalP = originalP(:);
    originalZ(row) = numericScalar(unitTable.Z3D_v_Z2D, row);
    if numel(originalP) >= 3
        originalMonoLP(row) = originalP(2);
        originalMonoRP(row) = originalP(3);
        originalPass(row) = originalP(2) < options.PThreshold && ...
            originalP(3) < options.PThreshold;
    end

    if ~startsWith(string(unitTable.stim_tuning_status(row)), "Success")
        status(row) = "SkippedInputStatus";
        message(row) = "Input stimulation tuning was not successful.";
        [unitTablePrepared.p_AI, unitTablePrepared.Z3D_v_Z2D] = ...
            invalidateCriteria(unitTablePrepared.p_AI, ...
            unitTablePrepared.Z3D_v_Z2D, row);
        continue
    end

    try
        channel = stimChannel(row);
        unitIndex = tableUnitIndex(row);
        channelCount = numericScalar(unitTable.NChannels, row);
        if ~isfinite(channel) || channel ~= fix(channel) || ...
                channel < 1 || channel > channelCount
            error('StimNoStimSelection:InvalidStimChannel', ...
                'StimElec is outside the available acquisition channels.');
        end
        if ~isfinite(unitIndex) || unitIndex ~= fix(unitIndex) || ...
                unitIndex < 1
            error('StimNoStimSelection:InvalidUnitIndex', ...
                'stim_tuning_table_unit_index is invalid.');
        end
        if strlength(trialFile(row)) == 0 || ~isfile(trialFile(row))
            error('StimNoStimSelection:MissingTrialFile', ...
                'Trial-level stimulation cache does not exist: %s', ...
                trialFile(row));
        end

        loaded = load(trialFile(row), 'StimTrialFR');
        if ~isfield(loaded, 'StimTrialFR')
            error('StimNoStimSelection:MissingTrialStruct', ...
                'Trial cache does not contain StimTrialFR.');
        end
        trial = loaded.StimTrialFR;
        validateTrialStruct(trial, channel, unitIndex, row);

        [pValues, counts] = computeTuningPValues( ...
            trial, channel, unitIndex);
        noStimTrialCount(row) = counts.NoStimNonzeroTrials;
        finiteFRCount(row) = counts.FiniteFRObservations;
        outlierFRCount(row) = counts.OutlierObservations;

        signedMaxOD(row) = numericScalar( ...
            unitTable.stim_noStim_OD_max, row);
        dominantEye(row) = eyeFromSignedOD(signedMaxOD(row));
        if ~ismember(dominantEye(row), ["L", "R"])
            error('StimNoStimSelection:UndefinedDominantEye', ...
                'Stim-task NoStim Max OD does not define a dominant eye.');
        end
        zValue = computeZ3DMinusZ2D(unitTable, row, channel, ...
            dominantEye(row));

        stimCueP{row} = pValues;
        stimMonoLP(row) = pValues(2);
        stimMonoRP(row) = pValues(3);
        stimZ(row) = zValue;
        stimPass(row) = pValues(2) < options.PThreshold && ...
            pValues(3) < options.PThreshold && isfinite(zValue) && ...
            zValue ~= 0;
        gateChanged(row) = originalPass(row) ~= stimPass(row);
        unitTypeChanged(row) = classifyUnit(originalZ(row)) ~= ...
            classifyUnit(zValue);

        unitTablePrepared.p_AI = setRowValue( ...
            unitTablePrepared.p_AI, row, pValues);
        if ismember('p_adjusted', ...
                unitTablePrepared.Properties.VariableNames)
            unitTablePrepared.p_adjusted = setRowValue( ...
                unitTablePrepared.p_adjusted, row, ...
                adjustPValuesLikeUnitTable(pValues));
        end
        unitTablePrepared.Z3D_v_Z2D = setRowValue( ...
            unitTablePrepared.Z3D_v_Z2D, row, zValue);
        status(row) = "Success";
    catch ME
        [unitTablePrepared.p_AI, unitTablePrepared.Z3D_v_Z2D] = ...
            invalidateCriteria(unitTablePrepared.p_AI, ...
            unitTablePrepared.Z3D_v_Z2D, row);
        status(row) = "Error";
        message(row) = string(ME.identifier) + ": " + string(ME.message);
    end
end

unitTablePrepared.stim_noStim_p_AI = stimCueP;
unitTablePrepared.stim_noStim_Z3D_v_Z2D = stimZ;
unitTablePrepared.stim_noStim_tuning_gate_pass = stimPass;
unitTablePrepared.stim_noStim_selection_criteria_status = status;
unitTablePrepared.stim_noStim_selection_criteria_message = message;
unitTablePrepared.stim_noStim_selection_dominant_eye = dominantEye;
unitTablePrepared.stim_noStim_selection_criteria_source = repmat( ...
    "Trial-level 3DMotionStim NoStim responses at StimElec", ...
    rowCount, 1);

audit = table(tableRow, monkey, recordingDate, stimChannel, tableUnitIndex, ...
    trialFile, signedMaxOD, dominantEye, originalMonoLP, originalMonoRP, ...
    stimMonoLP, stimMonoRP, originalZ, stimZ, originalPass, stimPass, ...
    gateChanged, unitTypeChanged, noStimTrialCount, finiteFRCount, ...
    outlierFRCount, status, message, ...
    'VariableNames', {'SourceTableRow', 'Monkey', 'Date', 'StimChannel', ...
    'TableUnitIndex', 'TrialFile', 'SignedMaxOD', 'DominantEye', ...
    'OriginalMonoLP', 'OriginalMonoRP', 'SelectedMonoLP', ...
    'SelectedMonoRP', 'OriginalZ3DMinusZ2D', ...
    'SelectedZ3DMinusZ2D', 'OriginalTuningGatePass', ...
    'SelectedSourceTuningGatePass', 'TuningGateChanged', ...
    'UnitTypeChanged', 'NoStimNonzeroTrialCount', ...
    'FiniteFRObservationCount', 'OutlierFRObservationCount', ...
    'Status', 'Message'});
audit.Properties.Description = [ ...
    'Stim-task NoStim neural-selection audit. Raw MonoL/MonoR direction ' ...
    'p-values and Z3D-Z2D are recomputed at StimElec. Max OD from the ' ...
    'same NoStim tuning assigns the dominant eye.'];
end


function [pValues, counts] = computeTuningPValues(trial, channel, unitIndex)
summary = trial.TrialSummary;
firingRate = double(trial.FiringRateHz(:, channel, unitIndex));
firingRate = firingRate(:);
if isfield(trial, 'FiringRateOutlierMask') && ...
        ~isempty(trial.FiringRateOutlierMask)
    outlierMask = logical( ...
        trial.FiringRateOutlierMask(:, channel, unitIndex));
    outlierMask = outlierMask(:);
else
    outlierMask = false(size(firingRate));
end

baseMask = logical(summary.Included) & ~logical(summary.ElectricalStim) & ...
    double(summary.Coherence) ~= 0;
counts.NoStimNonzeroTrials = nnz(baseMask);
counts.OutlierObservations = nnz(baseMask & outlierMask);
counts.FiniteFRObservations = nnz(baseMask & ~outlierMask & ...
    isfinite(firingRate));

pValues = nan(4, 1);
for cue = 1:4
    mask = baseMask & double(summary.Condition) == cue & ...
        ~outlierMask & isfinite(firingRate) & ...
        isfinite(double(summary.Coherence));
    if nnz(mask) < 4 || numel(unique(sign(summary.Coherence(mask)))) < 2
        continue
    end
    rows = table(firingRate(mask), double(summary.Coherence(mask)), ...
        'VariableNames', {'FR', 'Coherence'});
    rows.Abs_Coherence = abs(rows.Coherence);
    rows.Direction = sign(rows.Coherence);
    model = fitlm(rows, 'FR ~ Abs_Coherence + Direction');
    result = anova(model);
    pValues(cue) = result.pValue(2);
end
end


function value = computeZ3DMinusZ2D(unitTable, row, channel, dominantEye)
meanTuning = double(numericCellValue( ...
    unitTable.stim_tuning_mean_noStim, row));
countTuning = double(numericCellValue( ...
    unitTable.stim_tuning_n_noStim, row));
coherence = double(numericCellValue( ...
    unitTable.stim_tuning_coherence, row));
coherence = coherence(:)';
if ndims(meanTuning) ~= 3 || size(meanTuning, 1) < 3 || ...
        size(meanTuning, 2) ~= numel(coherence) || ...
        channel > size(meanTuning, 3)
    error('StimNoStimSelection:InvalidMeanTuning', ...
        'Stim-task NoStim tuning dimensions are invalid.');
end
if ndims(countTuning) ~= 3 || ~isequal(size(countTuning), size(meanTuning))
    error('StimNoStimSelection:InvalidCountTuning', ...
        'Stim-task NoStim count dimensions are invalid.');
end

[coherence, order] = sort(coherence);
meanTuning = meanTuning(:, order, :);
countTuning = countTuning(:, order, :);
valid = coherence ~= 0 & reshape(countTuning(1, :, channel), 1, []) > 0;
if nnz(valid) < 4
    error('StimNoStimSelection:InsufficientCoherence', ...
        'Fewer than four supported nonzero coherence values.');
end
left = reshape(meanTuning(2, valid, channel), [], 1);
right = reshape(meanTuning(3, valid, channel), [], 1);
r2D = corr(left, flipud(right));
r3D = corr(left, right);
if dominantEye == "L"
    rPrediction = corr(right, flipud(right));
else
    rPrediction = corr(left, flipud(left));
end
[z2D, z3D] = partialCorrelationZ( ...
    r2D, r3D, rPrediction, nnz(valid));
value = z3D - z2D;
end


function validateTrialStruct(trial, channel, unitIndex, expectedRow)
required = {'FiringRateHz', 'TrialSummary'};
missing = required(~isfield(trial, required));
if ~isempty(missing) || ~istable(trial.TrialSummary)
    error('StimNoStimSelection:InvalidTrialStruct', ...
        'StimTrialFR is missing required trial-level fields.');
end
requiredColumns = ["Included", "ElectricalStim", "Condition", "Coherence"];
if any(~ismember(requiredColumns, ...
        string(trial.TrialSummary.Properties.VariableNames)))
    error('StimNoStimSelection:InvalidTrialSummary', ...
        'TrialSummary is missing required columns.');
end
if size(trial.FiringRateHz, 1) ~= height(trial.TrialSummary) || ...
        channel > size(trial.FiringRateHz, 2) || ...
        unitIndex > size(trial.FiringRateHz, 3)
    error('StimNoStimSelection:TrialDimensionMismatch', ...
        'Trial firing-rate dimensions do not match the selected row.');
end
if isfield(trial, 'UnitTableRow') && isfinite(trial.UnitTableRow) && ...
        double(trial.UnitTableRow) ~= expectedRow
    error('StimNoStimSelection:SourceRowMismatch', ...
        'Trial cache UnitTableRow does not match the source table row.');
end
end


function eye = eyeFromSignedOD(value)
if value > 0
    eye = "L";
elseif value < 0
    eye = "R";
else
    eye = "N";
end
end


function [zFirst, zSecond] = partialCorrelationZ(rFirst, rSecond, r12, n)
pFirst = (rFirst - rSecond .* r12) ./ ...
    sqrt((1 - rSecond .^ 2) .* (1 - r12 .^ 2));
pSecond = (rSecond - rFirst .* r12) ./ ...
    sqrt((1 - rFirst .^ 2) .* (1 - r12 .^ 2));
zFirst = atanh(pFirst) ./ sqrt(1 ./ (n - 3));
zSecond = atanh(pSecond) ./ sqrt(1 ./ (n - 3));
end


function adjusted = adjustPValuesLikeUnitTable(pValues)
adjustedColumn = nan(4, 1);
[~, order] = sort(pValues, 'descend');
adjustedColumn(order) = pValues(order) .* ...
    linspace(1, numel(order), numel(order))';
adjusted = adjustedColumn.';
end


function value = classifyUnit(zValue)
if zValue < 0
    value = "2D";
elseif zValue > 0
    value = "3D";
else
    value = "Unknown";
end
end


function [pColumn, zColumn] = invalidateCriteria(pColumn, zColumn, row)
pColumn = setRowValue(pColumn, row, nan(4, 1));
zColumn = setRowValue(zColumn, row, NaN);
end


function requireVariables(tableData, required)
missing = setdiff(required, string(tableData.Properties.VariableNames));
if ~isempty(missing)
    error('StimNoStimSelection:MissingVariables', ...
        'Missing required variable(s): %s', join(missing, ', '));
end
end


function value = numericCellValue(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
if ~isnumeric(value)
    error('StimNoStimSelection:ExpectedNumericValue', ...
        'Expected numeric data at row %d.', row);
end
end


function value = numericScalar(column, row)
value = numericCellValue(column, row);
if ~isscalar(value)
    error('StimNoStimSelection:ExpectedNumericScalar', ...
        'Expected a numeric scalar at row %d.', row);
end
value = double(value);
end


function value = getRowText(column, row)
if iscell(column)
    value = string(column{row});
else
    value = string(column(row));
end
end


function column = setRowValue(column, row, value)
if iscell(column)
    column{row} = value;
else
    column(row, :) = value;
end
end


function dates = normalizeDateColumn(values)
if isdatetime(values)
    dates = dateshift(values(:), 'start', 'day');
elseif isnumeric(values)
    if all(isnan(values) | values > 1e7)
        dates = datetime(string(values(:)), 'InputFormat', 'yyyyMMdd');
    else
        dates = datetime(values(:), 'ConvertFrom', 'datenum');
    end
else
    dates = dateshift(datetime(string(values(:))), 'start', 'day');
end
end

function [unitTablePrepared, audit] = ...
    PrepareBestQuickChannelSelectionCriteria(unitTable, options)
%PREPAREBESTQUICKCHANNELSELECTIONCRITERIA Recompute neural gates at best channel.
%
% The legacy population cohort reads p_AI and Z3D_v_Z2D from the
% stimulation channel. This function replaces those fields with the exact
% original calculations at best_quick_channel, using each session's cached
% trial-level 3D Quick Neuro data. Behavioral fields are not changed.

arguments
    unitTable table
    options.JimCacheFolder (1, 1) string = "C:\Jim\StimData"
    options.ClayCacheFolder (1, 1) string = "C:\Clay\StimData"
    options.TuningTolerance (1, 1) double {mustBeNonnegative} = 1e-10
    options.DominantEyeMethod (1, 1) string ...
        {mustBeMember(options.DominantEyeMethod, ...
        ["LegacyMax", "SelectedOD"])} = "LegacyMax"
end

requireVariables(unitTable, ["Date", "Monkey", "NChannels", ...
    "best_quick_channel", "p_AI", "Z3D_v_Z2D", "tuning_mean"]);

unitTablePrepared = unitTable;
rowCount = height(unitTable);
artifactTableRow = (1:rowCount)';
monkey = strings(rowCount, 1);
recordingDate = normalizeDateColumn(unitTable.Date);
bestQuickChannel = double(unitTable.best_quick_channel);
cacheFile = strings(rowCount, 1);
originalMonoLP = nan(rowCount, 1);
originalMonoRP = nan(rowCount, 1);
bestMonoLP = nan(rowCount, 1);
bestMonoRP = nan(rowCount, 1);
bestCueP = repmat({nan(4, 1)}, rowCount, 1);
originalZ3DMinusZ2D = nan(rowCount, 1);
bestZ3DMinusZ2D = nan(rowCount, 1);
originalPass = false(rowCount, 1);
bestPass = false(rowCount, 1);
gateChanged = false(rowCount, 1);
unitTypeChanged = false(rowCount, 1);
maxQuickTuningDifference = nan(rowCount, 1);
tuningCacheAligned = false(rowCount, 1);
status = repmat("Pending", rowCount, 1);
message = strings(rowCount, 1);
selectedDominantEye = strings(rowCount, 1);

for row = 1:rowCount
    monkey(row) = getRowText(unitTable.Monkey, row);
    originalP = numericCellValue(unitTable.p_AI, row);
    originalP = double(originalP(:));
    originalZ = numericScalar(unitTable.Z3D_v_Z2D, row);
    originalZ3DMinusZ2D(row) = originalZ;
    if numel(originalP) >= 3
        originalMonoLP(row) = originalP(2);
        originalMonoRP(row) = originalP(3);
        originalPass(row) = originalP(2) < 0.05 && originalP(3) < 0.05;
    end

    try
        channel = bestQuickChannel(row);
        channelCount = numericScalar(unitTable.NChannels, row);
        if ~isfinite(channel) || channel ~= fix(channel) || ...
                channel < 1 || channel > channelCount
            error('BestQuickSelection:InvalidBestChannel', ...
                'best_quick_channel is invalid.');
        end
        cacheFolder = selectCacheFolder( ...
            monkey(row), options.JimCacheFolder, options.ClayCacheFolder);
        cacheFile(row) = fullfile(cacheFolder, ...
            string(recordingDate(row), 'yyyyMMdd') + ".mat");
        if ~isfile(cacheFile(row))
            error('BestQuickSelection:MissingCache', ...
                'Quick cache does not exist: %s', cacheFile(row));
        end
        loaded = load(cacheFile(row), 'Neuro', 'Monocularity');
        if ~isfield(loaded, 'Neuro') || ~isfield(loaded, 'Monocularity')
            error('BestQuickSelection:MissingCacheVariables', ...
                'Cache is missing Neuro or Monocularity.');
        end
        Neuro = loaded.Neuro;
        Monocularity = loaded.Monocularity;
        validateNeuro(Neuro, channel);

        tableQuickMean = double(numericCellValue( ...
            unitTable.tuning_mean, row));
        maxQuickTuningDifference(row) = compareQuickTuning( ...
            tableQuickMean, Neuro, channel);
        tuningCacheAligned(row) = isfinite(maxQuickTuningDifference(row)) && ...
            maxQuickTuningDifference(row) <= options.TuningTolerance;
        if ~tuningCacheAligned(row)
            message(row) = sprintf([ ...
                'Trial cache retained for exact p/Z tests; cached ' ...
                'Neuro.Means versus table tuning_mean difference = %.17g.'], ...
                maxQuickTuningDifference(row));
        end

        coherence = getNeuroCoherence(Neuro);
        validCoherence = find(Neuro.Trials.NumTrials(1, :) > 0);
        pValues = computeTuningPValues( ...
            Neuro, channel, validCoherence, coherence);
        if options.DominantEyeMethod == "SelectedOD"
            if ~ismember('best_quick_OD_dominant_eye', ...
                    unitTable.Properties.VariableNames)
                error('BestQuickSelection:MissingSelectedDominantEye', ...
                    'best_quick_OD_dominant_eye is required.');
            end
            dominantEye = string( ...
                unitTable.best_quick_OD_dominant_eye(row));
        else
            dominantEye = dominantEyeFromLegacyMax( ...
                Monocularity, channel);
        end
        if ~ismember(dominantEye, ["L", "R"])
            error('BestQuickSelection:UndefinedDominantEye', ...
                'Selected channel does not have a defined dominant eye.');
        end
        selectedDominantEye(row) = dominantEye;
        zValue = computeZ3DMinusZ2D( ...
            Neuro, dominantEye, channel, validCoherence);

        bestCueP{row} = pValues;
        bestMonoLP(row) = pValues(2);
        bestMonoRP(row) = pValues(3);
        bestZ3DMinusZ2D(row) = zValue;
        bestPass(row) = pValues(2) < 0.05 && pValues(3) < 0.05 && ...
            isfinite(zValue) && zValue ~= 0;
        gateChanged(row) = originalPass(row) ~= bestPass(row);
        unitTypeChanged(row) = classifyUnit(originalZ) ~= classifyUnit(zValue);

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
        unitTablePrepared.p_AI = setRowValue( ...
            unitTablePrepared.p_AI, row, nan(4, 1));
        unitTablePrepared.Z3D_v_Z2D = setRowValue( ...
            unitTablePrepared.Z3D_v_Z2D, row, NaN);
        status(row) = "Error";
        message(row) = string(ME.identifier) + ": " + string(ME.message);
    end
end

unitTablePrepared.best_quick_p_AI = bestCueP;
unitTablePrepared.best_quick_Z3D_v_Z2D = bestZ3DMinusZ2D;
unitTablePrepared.best_quick_tuning_gate_pass = bestPass;
unitTablePrepared.best_quick_selection_criteria_status = status;
unitTablePrepared.best_quick_selection_criteria_message = message;
unitTablePrepared.best_quick_selection_criteria_source = repmat( ...
    "Cached trial-level 3D Quick Neuro at best_quick_channel", ...
    rowCount, 1);
unitTablePrepared.best_quick_selection_cache_file = cacheFile;
unitTablePrepared.best_quick_selection_dominant_eye = selectedDominantEye;
unitTablePrepared.best_quick_selection_dominant_eye_method = repmat( ...
    options.DominantEyeMethod, rowCount, 1);

audit = table(artifactTableRow, monkey, recordingDate, bestQuickChannel, ...
    cacheFile, repmat(options.DominantEyeMethod, rowCount, 1), ...
    selectedDominantEye, originalMonoLP, originalMonoRP, ...
    bestMonoLP, bestMonoRP, ...
    originalZ3DMinusZ2D, bestZ3DMinusZ2D, originalPass, bestPass, ...
    gateChanged, unitTypeChanged, maxQuickTuningDifference, ...
    tuningCacheAligned, status, message, ...
    'VariableNames', {'ArtifactTableRow', 'Monkey', 'Date', ...
    'BestQuickChannel', 'CacheFile', 'DominantEyeMethod', ...
    'SelectedDominantEye', 'OriginalMonoLP', 'OriginalMonoRP', ...
    'BestMonoLP', 'BestMonoRP', 'OriginalZ3DMinusZ2D', ...
    'BestZ3DMinusZ2D', 'OriginalTuningGatePass', ...
    'BestChannelTuningGatePass', 'TuningGateChanged', ...
    'UnitTypeChanged', 'MaxQuickTuningDifference', ...
    'TuningCacheAligned', 'Status', 'Message'});
audit.Properties.Description = [ ...
    'Exact selected-channel neural cohort audit. Cue-specific direction ' ...
    'p-values and Z3D-Z2D are recomputed from cached trial-level 3D Quick ' ...
    'data using the legacy population formulas; the configured dominant ' ...
    'eye definition is used for Z3D-Z2D.'];
end


function pValues = computeTuningPValues( ...
    Neuro, channel, validCoherence, coherence)
pValues = nan(4, 1);
for cue = 1:4
    rows = table();
    maximumIndex = min(numel(coherence), size(Neuro.All, 2));
    for coherenceIndex = 1:maximumIndex
        if ~ismember(coherenceIndex, validCoherence)
            continue
        end
        trialCount = Neuro.Trials.NumTrials(cue, coherenceIndex);
        if trialCount <= 0
            continue
        end
        firingRate = squeeze(Neuro.All( ...
            cue, coherenceIndex, 1:trialCount, channel));
        coherenceColumn = repelem( ...
            coherence(coherenceIndex), numel(firingRate), 1);
        rows = [rows; table(firingRate(:), coherenceColumn(:), ...
            'VariableNames', {'FR', 'Coherence'})]; %#ok<AGROW>
    end
    if height(rows) < 4
        continue
    end
    rows.Abs_Coherence = abs(rows.Coherence);
    rows.Direction = sign(rows.Coherence);
    model = fitlm(rows, 'FR ~ Abs_Coherence + Direction');
    result = anova(model);
    pValues(cue) = result.pValue(2);
end
end


function value = computeZ3DMinusZ2D( ...
    Neuro, dominantEye, channel, validCoherence)
left = reshape(Neuro.Means(2, validCoherence, channel), [], 1);
right = reshape(Neuro.Means(3, validCoherence, channel), [], 1);
r2D = corr(left, flipud(right));
r3D = corr(left, right);
if dominantEye == "L"
    rPrediction = corr(right, flipud(right));
else
    rPrediction = corr(left, flipud(left));
end
[z2D, z3D] = partialCorrelationZ( ...
    r2D, r3D, rPrediction, numel(validCoherence));
value = z3D - z2D;
end


function dominantEye = dominantEyeFromLegacyMax(Monocularity, channel)
if ~isfield(Monocularity, 'Max') || ...
        channel > numel(Monocularity.Max)
    error('BestQuickSelection:MissingMonocularityMax', ...
        'Monocularity.Max is unavailable for selected channel.');
end
if Monocularity.Max(channel) > 0
    dominantEye = "L";
elseif Monocularity.Max(channel) < 0
    dominantEye = "R";
else
    dominantEye = "N";
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


function difference = compareQuickTuning(tableMean, Neuro, channel)
cacheMean = double(Neuro.Means);
tableCoherence = inferQuickCoherence(size(tableMean, 2));
cacheCoherence = getNeuroCoherence(Neuro);
[shared, cacheIndices] = ismember( ...
    round(tableCoherence, 12), round(cacheCoherence, 12));
tableIndices = find(shared);
cacheIndices = cacheIndices(shared);
if isempty(tableIndices)
    difference = NaN;
    return
end
tableValues = tableMean(:, tableIndices, channel);
cacheValues = cacheMean(:, cacheIndices, channel);
finite = isfinite(tableValues) & isfinite(cacheValues);
if ~any(finite, 'all')
    difference = NaN;
else
    difference = max(abs(tableValues(finite) - cacheValues(finite)));
end
end


function coherence = getNeuroCoherence(Neuro)
if isfield(Neuro, 'CoherenceArray') && ...
        numel(Neuro.CoherenceArray) == size(Neuro.Means, 2)
    coherence = double(Neuro.CoherenceArray(:)');
else
    coherence = inferQuickCoherence(size(Neuro.Means, 2));
end
end


function coherence = inferQuickCoherence(count)
switch count
    case 8
        numerator = [-22 -14 -10 -8 8 10 14 22];
    case 12
        numerator = [-22 -14 -10 -8 -4 -2 2 4 8 10 14 22];
    case 13
        numerator = [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22];
    otherwise
        error('BestQuickSelection:UnknownCoherenceGrid', ...
            'Expected 8, 12, or 13 Quick coherence values; found %d.', count);
end
coherence = numerator ./ 22;
end


function validateNeuro(Neuro, channel)
required = {'All', 'Means', 'Trials'};
missing = required(~isfield(Neuro, required));
if ~isempty(missing) || ~isfield(Neuro.Trials, 'NumTrials')
    error('BestQuickSelection:InvalidNeuroCache', ...
        'Cached Neuro structure is incomplete.');
end
if channel > size(Neuro.All, 4) || channel > size(Neuro.Means, 3)
    error('BestQuickSelection:CacheChannelMismatch', ...
        'Selected channel exceeds cached Quick channel count.');
end
end


function adjusted = adjustPValuesLikeUnitTable(pValues)
adjustedColumn = nan(4, 1);
[~, order] = sort(pValues, 'descend');
adjustedColumn(order) = pValues(order) .* linspace(1, numel(order), numel(order))';
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


function folder = selectCacheFolder(monkey, jimFolder, clayFolder)
if strcmpi(monkey, "Jim")
    folder = jimFolder;
elseif strcmpi(monkey, "Clay")
    folder = clayFolder;
else
    error('BestQuickSelection:UnknownMonkey', ...
        'Unknown monkey: %s', monkey);
end
end


function requireVariables(tableData, required)
missing = setdiff(required, string(tableData.Properties.VariableNames));
if ~isempty(missing)
    error('BestQuickSelection:MissingVariables', ...
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
    error('BestQuickSelection:ExpectedNumericValue', ...
        'Expected numeric data at row %d.', row);
end
end


function value = numericScalar(column, row)
value = numericCellValue(column, row);
if ~isscalar(value)
    error('BestQuickSelection:ExpectedNumericScalar', ...
        'Expected numeric scalar at row %d.', row);
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
    column(row) = value;
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

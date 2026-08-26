function [unitTablePrepared, audit] = ...
    PrepareBestQuickChannelPopulationTable( ...
    unitTable, sessionSummary, methodName, metricVariable, odMethod)
%PREPAREBESTQUICKCHANNELPOPULATIONTABLE Inject selected Quick AI/OD values.
%
% The population analysis reads Quick AI from AI(:, StimElec) and signed
% ocular dominance from OD_max. This helper preserves StimElec, p_AI, and
% Z3D_v_Z2D, but replaces those two neural values with indices from each
% method's selected 3D Quick channel:
%
%   AI(:, StimElec) <- AI(:, BestChannel), originally calculated from
%                      that channel's trial-level 3D Quick responses;
%   OD_max          <- selected OD method evaluated from that channel's
%                      tuning_mean over nonzero Quick coherence. "Max" uses
%                      MonoL/MonoR maxima. "LSQ" uses each perspective cue's
%                      squared error to Combined; the closer eye dominates.
%
% OD_max_all(BestChannel) is retained only as a discrepancy audit and is
% never used as the selected-channel OD source.
%
% Rows without a successful, valid channel selection are assigned NaN at
% the population readout location so they cannot silently fall back to the
% original stimulation channel.

if ~istable(unitTable) || ~istable(sessionSummary)
    error('BestQuickPopulation:InputsMustBeTables', ...
        'unitTable and sessionSummary must both be tables.');
end

if nargin < 5 || isempty(odMethod)
    odMethod = "Max";
end

methodName = string(methodName);
metricVariable = string(metricVariable);
odMethod = validatestring(string(odMethod), ["Max", "LSQ"]);
odMethod = string(odMethod);
if ~isscalar(methodName) || strlength(strip(methodName)) == 0
    error('BestQuickPopulation:InvalidMethodName', ...
        'methodName must be a nonempty string scalar.');
end
if ~isscalar(metricVariable) || strlength(strip(metricVariable)) == 0
    error('BestQuickPopulation:InvalidMetricVariable', ...
        'metricVariable must be a nonempty string scalar.');
end

requireVariables(unitTable, ...
    ["StimElec", "NChannels", "AI", "OD_max", "OD_max_all", ...
    "tuning_mean"]);
requireVariables(sessionSummary, ...
    ["UnitTableRow", "BestChannel", "Status", metricVariable]);

unitTablePrepared = unitTable;
rowCount = height(unitTable);
artifactTableRow = (1:rowCount)';
originalStimChannel = nan(rowCount, 1);
bestQuickChannel = nan(rowCount, 1);
selectionMetric = nan(rowCount, 1);
selectedSignedODForEye = nan(rowCount, 1);
selectedODMagnitudeForModel = nan(rowCount, 1);
selectedODMax = nan(rowCount, 1);
selectedODMaxDominantEye = strings(rowCount, 1);
selectedODLSQSigned = nan(rowCount, 1);
selectedODLSQRaw = nan(rowCount, 1);
selectedODDominantEye = strings(rowCount, 1);
leftLSQ = nan(rowCount, 1);
rightLSQ = nan(rowCount, 1);
odDominanceChangedFromMax = false(rowCount, 1);
storedSelectedODMax = nan(rowCount, 1);
odRecalculationResidual = nan(rowCount, 1);
quickTuningValueCount = zeros(rowCount, 1);
selectedQuickAI = repmat({nan(4, 1)}, rowCount, 1);
status = repmat("Pending", rowCount, 1);
message = strings(rowCount, 1);

summaryRows = double(sessionSummary.UnitTableRow);
if any(~isfinite(summaryRows) | summaryRows ~= fix(summaryRows))
    error('BestQuickPopulation:InvalidSummaryRows', ...
        'SessionSummary.UnitTableRow must contain finite integers.');
end
if numel(unique(summaryRows)) ~= numel(summaryRows)
    error('BestQuickPopulation:DuplicateSummaryRows', ...
        'SessionSummary contains duplicate UnitTableRow values.');
end

for row = 1:rowCount
    stimChannel = numericScalar(unitTable.StimElec, row);
    declaredChannelCount = numericScalar(unitTable.NChannels, row);
    originalStimChannel(row) = stimChannel;
    summaryIndex = find(summaryRows == row, 1);

    aiMatrix = numericCellValue(unitTable.AI, row);
    odByChannel = numericCellValue(unitTable.OD_max_all, row);
    quickMean = numericCellValue(unitTable.tuning_mean, row);
    aiMatrix = double(aiMatrix);
    odByChannel = double(odByChannel(:));
    quickMean = double(quickMean);

    if ~isfinite(stimChannel) || stimChannel ~= fix(stimChannel) || ...
            stimChannel < 1 || stimChannel > size(aiMatrix, 2)
        error('BestQuickPopulation:InvalidStimChannel', ...
            'StimElec is invalid at artifact row %d.', row);
    end
    if ~isfinite(declaredChannelCount) || ...
            declaredChannelCount ~= size(aiMatrix, 2) || ...
            declaredChannelCount ~= numel(odByChannel) || ...
            declaredChannelCount ~= size(quickMean, 3)
        error('BestQuickPopulation:ChannelCountMismatch', ...
            ['NChannels, AI, OD_max_all, and tuning_mean disagree at ' ...
            'artifact row %d.'], row);
    end

    if isempty(summaryIndex)
        status(row) = "MissingSelectionRow";
        message(row) = "No channel-ranking row matched this artifact row.";
        [unitTablePrepared, aiMatrix] = invalidatePopulationReadout( ...
            unitTablePrepared, aiMatrix, row, stimChannel);
        unitTablePrepared.AI{row} = aiMatrix;
        continue
    end

    if string(sessionSummary.Status(summaryIndex)) ~= "Success"
        status(row) = "SelectionNotSuccessful";
        message(row) = "Ranking status: " + ...
            string(sessionSummary.Status(summaryIndex));
        [unitTablePrepared, aiMatrix] = invalidatePopulationReadout( ...
            unitTablePrepared, aiMatrix, row, stimChannel);
        unitTablePrepared.AI{row} = aiMatrix;
        continue
    end

    selectedChannel = double(sessionSummary.BestChannel(summaryIndex));
    selectedMetric = double( ...
        sessionSummary.(metricVariable)(summaryIndex));
    bestQuickChannel(row) = selectedChannel;
    selectionMetric(row) = selectedMetric;
    if ~isscalar(selectedChannel) || ~isfinite(selectedChannel) || ...
            selectedChannel ~= fix(selectedChannel) || ...
            selectedChannel < 1 || selectedChannel > declaredChannelCount
        status(row) = "InvalidBestChannel";
        message(row) = "BestChannel is outside the available Quick channels.";
        [unitTablePrepared, aiMatrix] = invalidatePopulationReadout( ...
            unitTablePrepared, aiMatrix, row, stimChannel);
        unitTablePrepared.AI{row} = aiMatrix;
        continue
    end

    selectedAI = aiMatrix(:, selectedChannel);
    odDetails = calculateQuickODFromTuningMean(quickMean, selectedChannel);
    if odMethod == "LSQ"
        selectedOD = odDetails.LSQSignedOD;
    else
        selectedOD = odDetails.MaxSignedOD;
    end
    storedOD = odByChannel(selectedChannel);
    storedSelectedODMax(row) = storedOD;
    selectedSignedODForEye(row) = selectedOD;
    selectedODMagnitudeForModel(row) = abs(selectedOD);
    selectedODMax(row) = odDetails.MaxSignedOD;
    selectedODMaxDominantEye(row) = odDetails.MaxDominantEye;
    selectedODLSQSigned(row) = odDetails.LSQSignedOD;
    selectedODLSQRaw(row) = odDetails.LSQRawIndex;
    selectedODDominantEye(row) = odDetails.(odMethod + "DominantEye");
    leftLSQ(row) = odDetails.LeftLSQ;
    rightLSQ(row) = odDetails.RightLSQ;
    odDominanceChangedFromMax(row) = ...
        odDetails.LSQDominantEye ~= odDetails.MaxDominantEye;
    odRecalculationResidual(row) = odDetails.MaxSignedOD - storedOD;
    quickTuningValueCount(row) = odDetails.SupportCount;
    selectedQuickAI{row} = selectedAI;
    if any(~isfinite(selectedAI)) || ~isfinite(selectedOD)
        status(row) = "InvalidSelectedQuickIndices";
        message(row) = ...
            "Selected Quick channel has nonfinite 3D Quick AI or OD values.";
        [unitTablePrepared, aiMatrix] = invalidatePopulationReadout( ...
            unitTablePrepared, aiMatrix, row, stimChannel);
        unitTablePrepared.AI{row} = aiMatrix;
        continue
    end
    if odMethod == "LSQ"
        message(row) = sprintf([ ...
            'Using LSQ OD (%s dominant); LSQ_L=%.17g, LSQ_R=%.17g; ' ...
            'direct max OD=%.17g.'], selectedODDominantEye(row), ...
            leftLSQ(row), rightLSQ(row), selectedODMax(row));
    elseif ~isfinite(storedOD) || ...
            abs(odDetails.MaxSignedOD - storedOD) > 1e-10
        message(row) = sprintf([ ...
            'Using tuning_mean-derived OD (max); stored OD_max_all ' ...
            'discrepancy = %.17g.'], odDetails.MaxSignedOD - storedOD);
    end

    aiMatrix(:, stimChannel) = selectedAI;
    unitTablePrepared.AI{row} = aiMatrix;
    unitTablePrepared.OD_max = setRowValue( ...
        unitTablePrepared.OD_max, row, selectedOD);
    eyeValue = char(selectedODDominantEye(row));
    if ismember('OD_max_eye', unitTablePrepared.Properties.VariableNames)
        unitTablePrepared.OD_max_eye = setRowValue( ...
            unitTablePrepared.OD_max_eye, row, eyeValue);
    end
    if ismember('OD_lsq', unitTablePrepared.Properties.VariableNames)
        unitTablePrepared.OD_lsq = setRowValue( ...
            unitTablePrepared.OD_lsq, row, abs(odDetails.LSQSignedOD));
    end
    if ismember('OD_lsq_eye', unitTablePrepared.Properties.VariableNames)
        unitTablePrepared.OD_lsq_eye = setRowValue( ...
            unitTablePrepared.OD_lsq_eye, row, ...
            char(odDetails.LSQDominantEye));
    end
    status(row) = "Success";
end

unitTablePrepared.best_quick_selection_method = ...
    repmat(methodName, rowCount, 1);
unitTablePrepared.best_quick_original_stim_channel = originalStimChannel;
unitTablePrepared.best_quick_channel = bestQuickChannel;
unitTablePrepared.best_quick_selection_metric = selectionMetric;
unitTablePrepared.best_quick_AI = selectedQuickAI;
unitTablePrepared.best_quick_OD_max = selectedODMax;
unitTablePrepared.best_quick_OD_max_dominant_eye = ...
    selectedODMaxDominantEye;
unitTablePrepared.best_quick_OD_lsq_signed = selectedODLSQSigned;
unitTablePrepared.best_quick_OD_lsq_raw = selectedODLSQRaw;
unitTablePrepared.best_quick_OD_signed_for_eye = selectedSignedODForEye;
unitTablePrepared.best_quick_OD_magnitude = selectedODMagnitudeForModel;
unitTablePrepared.best_quick_OD_method = repmat(odMethod, rowCount, 1);
unitTablePrepared.best_quick_OD_dominant_eye = selectedODDominantEye;
unitTablePrepared.best_quick_OD_lsq_left_error = leftLSQ;
unitTablePrepared.best_quick_OD_lsq_right_error = rightLSQ;
unitTablePrepared.best_quick_OD_dominance_changed_from_max = ...
    odDominanceChangedFromMax;
unitTablePrepared.best_quick_stored_OD_max_all = storedSelectedODMax;
unitTablePrepared.best_quick_OD_recalculation_residual = ...
    odRecalculationResidual;
unitTablePrepared.best_quick_AI_source = repmat( ...
    "AI(:, BestQuickChannel), calculated from trial-level 3D Quick tuning", ...
    rowCount, 1);
unitTablePrepared.best_quick_OD_source = repmat( ...
    odSourceDescription(odMethod), ...
    rowCount, 1);
unitTablePrepared.best_quick_selection_status = status;
unitTablePrepared.best_quick_selection_message = message;

method = repmat(methodName, rowCount, 1);
metricName = repmat(metricVariable, rowCount, 1);
audit = table(artifactTableRow, method, metricName, ...
    originalStimChannel, bestQuickChannel, selectionMetric, ...
    selectedQuickAI, repmat(odMethod, rowCount, 1), ...
    selectedSignedODForEye, selectedODMagnitudeForModel, ...
    selectedODMax, selectedODMaxDominantEye, selectedODLSQSigned, ...
    selectedODLSQRaw, selectedODDominantEye, leftLSQ, rightLSQ, ...
    odDominanceChangedFromMax, storedSelectedODMax, ...
    odRecalculationResidual, quickTuningValueCount, status, message, ...
    'VariableNames', {'ArtifactTableRow', 'Method', 'MetricName', ...
    'OriginalStimChannel', 'BestQuickChannel', 'SelectionMetric', ...
    'SelectedQuickAI', 'ODMethod', 'SelectedSignedODForEyeAssignment', ...
    'SelectedODMagnitudeForModel', ...
    'SelectedODMaxFromQuickTuning', 'SelectedODMaxDominantEye', ...
    'SelectedODLSQSigned', ...
    'SelectedODLSQRaw', 'SelectedODDominantEye', 'LSQLeftError', ...
    'LSQRightError', 'ODDominanceChangedFromMax', ...
    'StoredSelectedODMaxAll', 'ODRecalculationResidual', ...
    'QuickODSupportCount', 'Status', 'Message'});
audit.Properties.Description = [ ...
    'Provenance for substituting method-selected 3D Quick AI and OD into ' ...
    'the population analysis. AI is the channel-wise raw-trial Quick AI; ' ...
    'both maximum-response and LSQ OD are recalculated from that channel ' ...
    'tuning_mean. The configured OD method assigns the dominant eye, but ' ...
    'only its absolute magnitude enters models and plots. OD_max_all is ' ...
    'kept only as a discrepancy audit; neural selection gates are ' ...
    'recomputed separately from the selected-channel tuning.'];
end


function details = calculateQuickODFromTuningMean(quickMean, channel)
if size(quickMean, 1) < 3 || size(quickMean, 2) < 1 || ...
        channel > size(quickMean, 3)
    error('BestQuickPopulation:InvalidQuickTuningDimensions', ...
        'tuning_mean must be cue x coherence x channel.');
end
coherence = inferQuickCoherence(size(quickMean, 2));
combined = reshape(quickMean(1, :, channel), 1, []);
leftAll = reshape(quickMean(2, :, channel), 1, []);
rightAll = reshape(quickMean(3, :, channel), 1, []);
support = coherence ~= 0 & isfinite(combined) & ...
    isfinite(leftAll) & isfinite(rightAll);
if ~any(support)
    error('BestQuickPopulation:NoQuickODSupport', ...
        'Selected Quick channel has no nonzero Combined-cue support.');
end
combined = combined(support);
left = leftAll(support);
right = rightAll(support);
leftMaximum = max(left);
rightMaximum = max(right);
denominator = leftMaximum + rightMaximum;
if ~isfinite(leftMaximum) || ~isfinite(rightMaximum) || ...
        ~isfinite(denominator) || denominator == 0
    maxSignedOD = NaN;
else
    maxSignedOD = (leftMaximum - rightMaximum) ./ denominator;
end
if maxSignedOD > 0
    maxDominantEye = "L";
elseif maxSignedOD < 0
    maxDominantEye = "R";
else
    maxDominantEye = "N";
end

leftError = sum((combined - left) .^ 2);
rightError = sum((combined - right) .^ 2);
lsqDenominator = leftError + rightError;
if ~isfinite(lsqDenominator) || lsqDenominator <= 0
    lsqRawIndex = NaN;
    lsqSignedOD = NaN;
    lsqDominantEye = "N";
else
    % This is the legacy LSQ index. Its sign is negative for left-eye
    % dominance, so a separate sign-converted value is retained only for
    % compatibility with downstream eye assignment (positive means left).
    lsqRawIndex = (leftError - rightError) ./ lsqDenominator;
    if leftError < rightError
        lsqDominantEye = "L";
        lsqSignedOD = abs(lsqRawIndex);
    elseif rightError < leftError
        lsqDominantEye = "R";
        lsqSignedOD = -abs(lsqRawIndex);
    else
        lsqDominantEye = "N";
        lsqSignedOD = NaN;
    end
end
details = struct();
details.Coherence = coherence(support);
details.SupportCount = nnz(support);
details.LeftMaximum = leftMaximum;
details.RightMaximum = rightMaximum;
details.MaxSignedOD = maxSignedOD;
details.MaxDominantEye = maxDominantEye;
details.LeftLSQ = leftError;
details.RightLSQ = rightError;
details.LSQRawIndex = lsqRawIndex;
details.LSQSignedOD = lsqSignedOD;
details.LSQMagnitude = abs(lsqRawIndex);
details.LSQDominantEye = lsqDominantEye;
end


function description = odSourceDescription(odMethod)
if odMethod == "LSQ"
    description = [ ...
        "Normalized LSQ difference between Combined-to-MonoL and " ...
        "Combined-to-MonoR errors; lower-error eye dominates, and only " ...
        "the absolute magnitude enters models and plots"];
else
    description = [ ...
        "MonoL/MonoR maximum-response OD; sign assigns the dominant eye, " ...
        "and only the absolute magnitude enters models and plots"];
end
end


function coherence = inferQuickCoherence(coherenceCount)
switch coherenceCount
    case 8
        numerator = [-22 -14 -10 -8 8 10 14 22];
    case 12
        numerator = [-22 -14 -10 -8 -4 -2 2 4 8 10 14 22];
    case 13
        numerator = [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22];
    otherwise
        error('BestQuickPopulation:UnknownQuickCoherenceGrid', ...
            ['Cannot infer the 3D Quick coherence axis from %d columns. ' ...
            'Expected 8, 12, or 13.'], coherenceCount);
end
coherence = numerator ./ 22;
end


function [tableData, aiMatrix] = invalidatePopulationReadout( ...
    tableData, aiMatrix, row, stimChannel)
aiMatrix(:, stimChannel) = NaN;
tableData.OD_max = setRowValue(tableData.OD_max, row, NaN);
if ismember('OD_max_eye', tableData.Properties.VariableNames)
    tableData.OD_max_eye = setRowValue(tableData.OD_max_eye, row, '');
end
end


function requireVariables(tableData, required)
missing = setdiff(required, string(tableData.Properties.VariableNames));
if ~isempty(missing)
    error('BestQuickPopulation:MissingVariables', ...
        'Missing required table variable(s): %s', join(missing, ', '));
end
end


function value = numericCellValue(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
if ~isnumeric(value)
    error('BestQuickPopulation:ExpectedNumericValue', ...
        'Expected numeric data at table row %d.', row);
end
end


function value = numericScalar(column, row)
value = numericCellValue(column, row);
if ~isscalar(value)
    error('BestQuickPopulation:ExpectedNumericScalar', ...
        'Expected a numeric scalar at table row %d.', row);
end
value = double(value);
end


function column = setRowValue(column, row, value)
if iscell(column)
    column{row} = value;
elseif isstring(column)
    column(row) = string(value);
elseif iscategorical(column)
    column(row) = categorical(string(value));
else
    column(row) = value;
end
end

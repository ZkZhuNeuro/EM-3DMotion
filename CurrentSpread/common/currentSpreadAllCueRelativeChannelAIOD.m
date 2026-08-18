function result = currentSpreadAllCueRelativeChannelAIOD(paths, options)
%CURRENTSPREADALLCUERELATIVECHANNELAIOD Analyze all cues at local channels.
%
% For each requested signed position relative to the stimulation channel,
% this analysis takes AI and signed OD from that same physical channel.
% The sign of local OD independently assigns dominant and non-dominant eye
% cues at every position. Behavioral DeltaBias comes from the latest
% Behav_bias_NminusS columns in unit_table_gof.

arguments
    paths (1, 1) struct
    options.RelativePositions (1, :) double {mustBeInteger} = 0:4
end

relativePositions = unique(options.RelativePositions, 'stable');
if any(abs(relativePositions) > 15)
    error('CurrentSpread:RelativePositionRange', ...
        'Relative channel positions must lie within the 16-channel probe.');
end

unitData = load(paths.unitTableGof, 'unit_table_gof');
unitTableAll = unitData.unit_table_gof;
[selection, selectionAudit] = selectPopulationCohort(unitTableAll);
unitTable = unitTableAll(selection, :);
originalRowIndex = find(selection);

channelMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10];
conditionNames = ["Dominant", "Combined", "Stereo", "NonDominant"];
conditionColors = [254 191 15; 0 0 0; 234 0 233; 110 205 221] ./ 255;

observationAudit = buildObservationAudit(unitTable, originalRowIndex, ...
    relativePositions, channelMap, conditionNames);
fitPoints = observationAudit(observationAudit.IncludedInFit, :);
modelSummary = buildModelSummary(fitPoints, relativePositions, conditionNames);
perspectiveModelSummary = buildPerspectiveModelSummary( ...
    fitPoints, relativePositions);
channelSummary = buildChannelSummary(observationAudit, relativePositions);

result = struct();
result.analysis = "All-cue local-channel AI by OD analysis";
result.sourceTable = string(paths.unitTableGof);
result.behaviorField = "Behav_bias_NminusS{row}(source cue)";
result.behaviorFitField = "Behav_goodfit_both{row}(source cue)";
result.populationFormula = "DeltaBias ~ AI + AI:OD";
result.mergedPerspectiveFormula = ...
    "MergedEyeDeltaBias ~ AI + AI:OD; NonDominant DeltaBias is negated";
result.literalFullInteractionFormula = "DeltaBias ~ AI*OD";
result.displayFit = ["DeltaBias ~ AI weighted least squares"; ...
    "observation weight = abs(local channel OD)"];
result.localDominanceRule = [ ...
    "local signed OD > 0: Dominant=cue 2, NonDominant=cue 3"; ...
    "local signed OD <= 0: Dominant=cue 3, NonDominant=cue 2"];
result.nonDominantBiasRule = ...
    "DisplayedDeltaBias = -DeltaBias for NonDominant; unchanged otherwise";
result.selectionRule = ["Jim"; "MT"; "ND = 2D"; ...
    "stimulation-site p_AI cues 2 and 3 < 0.05"];
result.channelMap = channelMap;
result.relativePositions = relativePositions;
result.conditionNames = conditionNames;
result.conditionColors = conditionColors;
result.cohortSelection = selection;
result.cohortSelectionAudit = selectionAudit;
result.originalRowIndex = originalRowIndex;
result.cohortSessionCount = height(unitTable);
result.observationAudit = observationAudit;
result.fitPoints = fitPoints;
result.modelSummary = modelSummary;
result.perspectiveModelSummary = perspectiveModelSummary;
result.channelSummary = channelSummary;
end


function [selection, audit] = selectPopulationCohort(unitTable)
numRows = height(unitTable);
selection = false(numRows, 1);
isJim = false(numRows, 1);
isMT = false(numRows, 1);
is2D = false(numRows, 1);
passesPerspectiveTuning = false(numRows, 1);

for row = 1:numRows
    isJim(row) = strcmp(unitTable.Monkey{row}, 'Jim');
    isMT(row) = strcmp(unitTable.ROI{row}, 'MT');
    is2D(row) = strcmp(unitTable.ND{row}, '2D');
    pAI = unitTable.p_AI{row};
    passesPerspectiveTuning(row) = numel(pAI) >= 3 && ...
        isfinite(pAI(2)) && isfinite(pAI(3)) && ...
        pAI(2) < 0.05 && pAI(3) < 0.05;
    selection(row) = isJim(row) && isMT(row) && is2D(row) && ...
        passesPerspectiveTuning(row);
end

audit = table((1:numRows)', isJim, isMT, is2D, ...
    passesPerspectiveTuning, selection, ...
    'VariableNames', {'UnitTableRow', 'IsJim', 'IsMT', 'Is2D', ...
    'PassesPerspectiveTuning', 'Included'});
end


function observationTable = buildObservationAudit(unitTable, originalRowIndex, ...
    relativePositions, channelMap, conditionNames)
numSessions = height(unitTable);
numPositions = numel(relativePositions);
numConditions = numel(conditionNames);
numRows = numSessions * numPositions * numConditions;

Date = strings(numRows, 1);
UnitTableRow = NaN(numRows, 1);
OriginalRecIdx = NaN(numRows, 1);
StimulationChannel = NaN(numRows, 1);
RelativeChannelPosition = NaN(numRows, 1);
ActualChannel = NaN(numRows, 1);
ChannelAvailability = strings(numRows, 1);
ConditionIndex = NaN(numRows, 1);
ConditionName = strings(numRows, 1);
SourceCueIndex = NaN(numRows, 1);
DominantEye = strings(numRows, 1);
AI = NaN(numRows, 1);
SignedOD = NaN(numRows, 1);
OD = NaN(numRows, 1);
StimulationChannelSignedOD = NaN(numRows, 1);
DominanceSignDiffersFromStimulation = false(numRows, 1);
HasValidSignComparison = false(numRows, 1);
DeltaBias = NaN(numRows, 1);
DisplayedDeltaBias = NaN(numRows, 1);
BiasWasFlipped = false(numRows, 1);
BehaviorGoodFit = false(numRows, 1);
BehaviorFinite = false(numRows, 1);
IncludedInFit = false(numRows, 1);
ExclusionReason = strings(numRows, 1);

writeIndex = 0;
for session = 1:numSessions
    stimulationChannel = unitTable.StimElec(session);
    stimulationIndex = find(channelMap == stimulationChannel, 1);
    stimulationSignedOD = numericCellScalar(unitTable.OD_max{session});
    aiValues = unitTable.AI{session};
    odValues = unitTable.OD_max_all{session};
    deadChannels = unitTable.DeadChannel{session};
    biasValues = unitTable.Behav_bias_NminusS{session};
    goodFitValues = unitTable.Behav_goodfit_both{session};

    for positionIndex = 1:numPositions
        relativePosition = relativePositions(positionIndex);
        [channel, signedOD, channelStatus] = localChannelData( ...
            stimulationIndex, relativePosition, channelMap, deadChannels, ...
            odValues);

        if isfinite(signedOD)
            if signedOD > 0
                cueOrder = [2 1 4 3];
                dominantEye = "Left";
            else
                cueOrder = [3 1 4 2];
                dominantEye = "Right";
            end
        else
            cueOrder = NaN(1, 4);
            dominantEye = "unavailable";
        end

        for conditionIndex = 1:numConditions
            writeIndex = writeIndex + 1;
            sourceCue = cueOrder(conditionIndex);

            Date(writeIndex) = tableRowString(unitTable.Date, session);
            UnitTableRow(writeIndex) = originalRowIndex(session);
            OriginalRecIdx(writeIndex) = unitTable.OriginalRecIdx(session);
            StimulationChannel(writeIndex) = stimulationChannel;
            RelativeChannelPosition(writeIndex) = relativePosition;
            ActualChannel(writeIndex) = channel;
            ChannelAvailability(writeIndex) = channelStatus;
            ConditionIndex(writeIndex) = conditionIndex;
            ConditionName(writeIndex) = conditionNames(conditionIndex);
            SourceCueIndex(writeIndex) = sourceCue;
            DominantEye(writeIndex) = dominantEye;
            SignedOD(writeIndex) = signedOD;
            OD(writeIndex) = abs(signedOD);
            StimulationChannelSignedOD(writeIndex) = stimulationSignedOD;
            if isfinite(signedOD) && isfinite(stimulationSignedOD)
                HasValidSignComparison(writeIndex) = true;
                DominanceSignDiffersFromStimulation(writeIndex) = ...
                    signedOD .* stimulationSignedOD < 0;
            end

            if channelStatus ~= "available"
                ExclusionReason(writeIndex) = channelStatus;
                continue
            end

            if ~(isfinite(sourceCue) && sourceCue <= size(aiValues, 1) && ...
                    channel <= size(aiValues, 2))
                ExclusionReason(writeIndex) = "AI entry unavailable";
                continue
            end
            AI(writeIndex) = aiValues(sourceCue, channel);
            if ~isfinite(AI(writeIndex))
                ExclusionReason(writeIndex) = "nonfinite AI";
                continue
            end

            if sourceCue <= numel(goodFitValues)
                BehaviorGoodFit(writeIndex) = logical(goodFitValues(sourceCue));
            end
            if sourceCue <= numel(biasValues)
                DeltaBias(writeIndex) = biasValues(sourceCue);
                BehaviorFinite(writeIndex) = isfinite(DeltaBias(writeIndex));
                if BehaviorFinite(writeIndex)
                    DisplayedDeltaBias(writeIndex) = DeltaBias(writeIndex);
                    if conditionIndex == 4
                        DisplayedDeltaBias(writeIndex) = ...
                            -DisplayedDeltaBias(writeIndex);
                        BiasWasFlipped(writeIndex) = true;
                    end
                end
            end
            if ~BehaviorGoodFit(writeIndex)
                ExclusionReason(writeIndex) = "behavioral fit failed";
                continue
            end
            if ~BehaviorFinite(writeIndex)
                ExclusionReason(writeIndex) = "nonfinite DeltaBias";
                continue
            end

            IncludedInFit(writeIndex) = true;
            ExclusionReason(writeIndex) = "included";
        end
    end
end

observationTable = table(Date, UnitTableRow, OriginalRecIdx, ...
    StimulationChannel, RelativeChannelPosition, ActualChannel, ...
    ChannelAvailability, ConditionIndex, ConditionName, SourceCueIndex, ...
    DominantEye, AI, SignedOD, OD, StimulationChannelSignedOD, ...
    DominanceSignDiffersFromStimulation, HasValidSignComparison, ...
    DeltaBias, DisplayedDeltaBias, BiasWasFlipped, BehaviorGoodFit, ...
    BehaviorFinite, IncludedInFit, ExclusionReason);
end


function [channel, signedOD, status] = localChannelData( ...
    stimulationIndex, relativePosition, channelMap, deadChannels, odValues)
channel = NaN;
signedOD = NaN;
status = "available";
if isempty(stimulationIndex)
    status = "stimulation channel not mapped";
    return
end

probeIndex = stimulationIndex + relativePosition;
if probeIndex < 1 || probeIndex > numel(channelMap)
    status = "outside probe";
    return
end

channel = channelMap(probeIndex);
if ismember(channel, deadChannels)
    status = "dead channel";
    return
end
if channel > numel(odValues)
    status = "OD entry unavailable";
    return
end

signedOD = odValues(channel);
if ~isfinite(signedOD)
    status = "nonfinite OD";
end
end


function modelSummary = buildModelSummary(fitPoints, relativePositions, ...
    conditionNames)
numGroups = numel(relativePositions) * numel(conditionNames);
summaries = repmat(emptyModelSummary(), numGroups, 1);
writeIndex = 0;

for positionIndex = 1:numel(relativePositions)
    for conditionIndex = 1:numel(conditionNames)
        writeIndex = writeIndex + 1;
        useRows = fitPoints.RelativeChannelPosition == ...
            relativePositions(positionIndex) & ...
            fitPoints.ConditionIndex == conditionIndex;
        summaries(writeIndex) = summarizeGroup(fitPoints(useRows, :), ...
            relativePositions(positionIndex), conditionIndex, ...
            conditionNames(conditionIndex));
    end
end

modelSummary = struct2table(summaries, 'AsArray', true);
end


function perspectiveSummary = buildPerspectiveModelSummary( ...
    fitPoints, relativePositions)
numPositions = numel(relativePositions);
summaries = repmat(emptyPerspectiveSummary(), numPositions, 1);

for positionIndex = 1:numPositions
    relativePosition = relativePositions(positionIndex);
    useRows = fitPoints.RelativeChannelPosition == relativePosition & ...
        (fitPoints.ConditionIndex == 1 | fitPoints.ConditionIndex == 4);
    group = fitPoints(useRows, :);
    group.MergedEyeDeltaBias = group.DisplayedDeltaBias;

    summary = emptyPerspectiveSummary();
    summary.RelativeChannelPosition = relativePosition;
    summary.NPoints = height(group);
    summary.NUnits = numel(unique(group.UnitTableRow));
    summary.NDominantPoints = nnz(group.ConditionIndex == 1);
    summary.NNonDominantPoints = nnz(group.ConditionIndex == 4);
    if isempty(group)
        summaries(positionIndex) = summary;
        continue
    end

    summary.MeanAI = mean(group.AI, 'omitnan');
    summary.MeanMergedEyeDeltaBias = mean( ...
        group.MergedEyeDeltaBias, 'omitnan');
    summary.MeanOD = mean(group.OD, 'omitnan');
    [summary.WeightedSlope, summary.WeightedIntercept] = ...
        weightedFitLine(group.AI, group.MergedEyeDeltaBias, group.OD);

    model = safeFitlm(group, 'MergedEyeDeltaBias ~ AI + AI:OD');
    if ~isempty(model)
        summary.Intercept = coefficientValue( ...
            model, '(Intercept)', 'Estimate');
        [summary.AI, summary.AISE, summary.AIP] = ...
            coefficientTriplet(model, 'AI');
        [summary.AIxOD, summary.AIxODSE, summary.AIxODP] = ...
            coefficientTriplet(model, 'AI:OD');
        summary.R2 = model.Rsquared.Ordinary;
        summary.AdjustedR2 = model.Rsquared.Adjusted;
        summary.RMSE = model.RMSE;
    end
    summaries(positionIndex) = summary;
end

perspectiveSummary = struct2table(summaries, 'AsArray', true);
end


function summary = emptyPerspectiveSummary()
summary = struct( ...
    'RelativeChannelPosition', NaN, ...
    'NPoints', NaN, ...
    'NUnits', NaN, ...
    'NDominantPoints', NaN, ...
    'NNonDominantPoints', NaN, ...
    'MeanAI', NaN, ...
    'MeanMergedEyeDeltaBias', NaN, ...
    'MeanOD', NaN, ...
    'WeightedIntercept', NaN, ...
    'WeightedSlope', NaN, ...
    'Intercept', NaN, ...
    'AI', NaN, ...
    'AISE', NaN, ...
    'AIP', NaN, ...
    'AIxOD', NaN, ...
    'AIxODSE', NaN, ...
    'AIxODP', NaN, ...
    'R2', NaN, ...
    'AdjustedR2', NaN, ...
    'RMSE', NaN);
end


function summary = summarizeGroup(group, relativePosition, conditionIndex, ...
    conditionName)
summary = emptyModelSummary();
summary.RelativeChannelPosition = relativePosition;
summary.ConditionIndex = conditionIndex;
summary.ConditionName = conditionName;
summary.NPoints = height(group);
summary.NUnits = numel(unique(group.UnitTableRow));
if isempty(group)
    return
end

summary.MeanAI = mean(group.AI, 'omitnan');
summary.MeanDeltaBias = mean(group.DeltaBias, 'omitnan');
summary.MeanDisplayedDeltaBias = mean(group.DisplayedDeltaBias, 'omitnan');
summary.MeanOD = mean(group.OD, 'omitnan');
[summary.WeightedSlope, summary.WeightedIntercept] = ...
    weightedFitLine(group.AI, group.DisplayedDeltaBias, group.OD);

aiOnlyModel = safeFitlm(group, 'DisplayedDeltaBias ~ AI');
if ~isempty(aiOnlyModel)
    summary.AIOnlyIntercept = coefficientValue(aiOnlyModel, '(Intercept)', 'Estimate');
    summary.AIOnlySlope = coefficientValue(aiOnlyModel, 'AI', 'Estimate');
    summary.AIOnlySlopeP = coefficientValue(aiOnlyModel, 'AI', 'pValue');
    summary.AIOnlyR2 = aiOnlyModel.Rsquared.Ordinary;
end

populationModel = safeFitlm(group, 'DisplayedDeltaBias ~ AI + AI:OD');
if ~isempty(populationModel)
    summary.PopulationIntercept = coefficientValue( ...
        populationModel, '(Intercept)', 'Estimate');
    [summary.PopulationAI, summary.PopulationAISE, summary.PopulationAIP] = ...
        coefficientTriplet(populationModel, 'AI');
    [summary.PopulationAIxOD, summary.PopulationAIxODSE, ...
        summary.PopulationAIxODP] = coefficientTriplet( ...
        populationModel, 'AI:OD');
    summary.PopulationR2 = populationModel.Rsquared.Ordinary;
    summary.PopulationAdjustedR2 = populationModel.Rsquared.Adjusted;
    summary.PopulationRMSE = populationModel.RMSE;
end

fullInteractionModel = safeFitlm(group, 'DisplayedDeltaBias ~ AI*OD');
if ~isempty(fullInteractionModel)
    summary.FullIntercept = coefficientValue( ...
        fullInteractionModel, '(Intercept)', 'Estimate');
    [summary.FullAI, summary.FullAISE, summary.FullAIP] = ...
        coefficientTriplet(fullInteractionModel, 'AI');
    [summary.FullOD, summary.FullODSE, summary.FullODP] = ...
        coefficientTriplet(fullInteractionModel, 'OD');
    [summary.FullAIxOD, summary.FullAIxODSE, summary.FullAIxODP] = ...
        coefficientTriplet(fullInteractionModel, 'AI:OD');
    summary.FullR2 = fullInteractionModel.Rsquared.Ordinary;
    summary.FullAdjustedR2 = fullInteractionModel.Rsquared.Adjusted;
    summary.FullRMSE = fullInteractionModel.RMSE;
end
end


function summary = emptyModelSummary()
nanValue = NaN;
summary = struct( ...
    'RelativeChannelPosition', nanValue, ...
    'ConditionIndex', nanValue, ...
    'ConditionName', "", ...
    'NPoints', nanValue, ...
    'NUnits', nanValue, ...
    'MeanAI', nanValue, ...
    'MeanDeltaBias', nanValue, ...
    'MeanDisplayedDeltaBias', nanValue, ...
    'MeanOD', nanValue, ...
    'WeightedIntercept', nanValue, ...
    'WeightedSlope', nanValue, ...
    'AIOnlyIntercept', nanValue, ...
    'AIOnlySlope', nanValue, ...
    'AIOnlySlopeP', nanValue, ...
    'AIOnlyR2', nanValue, ...
    'PopulationIntercept', nanValue, ...
    'PopulationAI', nanValue, ...
    'PopulationAISE', nanValue, ...
    'PopulationAIP', nanValue, ...
    'PopulationAIxOD', nanValue, ...
    'PopulationAIxODSE', nanValue, ...
    'PopulationAIxODP', nanValue, ...
    'PopulationR2', nanValue, ...
    'PopulationAdjustedR2', nanValue, ...
    'PopulationRMSE', nanValue, ...
    'FullIntercept', nanValue, ...
    'FullAI', nanValue, ...
    'FullAISE', nanValue, ...
    'FullAIP', nanValue, ...
    'FullOD', nanValue, ...
    'FullODSE', nanValue, ...
    'FullODP', nanValue, ...
    'FullAIxOD', nanValue, ...
    'FullAIxODSE', nanValue, ...
    'FullAIxODP', nanValue, ...
    'FullR2', nanValue, ...
    'FullAdjustedR2', nanValue, ...
    'FullRMSE', nanValue);
end


function [slope, intercept] = weightedFitLine(x, y, weights)
slope = NaN;
intercept = NaN;
valid = isfinite(x) & isfinite(y) & isfinite(weights) & weights >= 0;
x = x(valid);
y = y(valid);
weights = weights(valid);
if numel(x) < 2 || sum(weights) <= eps || std(x) <= eps
    return
end

design = [x(:), ones(numel(x), 1)];
coefficients = lscov(design, y(:), weights(:));
slope = coefficients(1);
intercept = coefficients(2);
end


function model = safeFitlm(group, formula)
model = [];
if height(group) < 5 || std(group.AI) <= eps
    return
end
try
    model = fitlm(group, formula);
catch
    model = [];
end
end


function [estimate, standardError, pValue] = coefficientTriplet(model, name)
estimate = coefficientValue(model, name, 'Estimate');
standardError = coefficientValue(model, name, 'SE');
pValue = coefficientValue(model, name, 'pValue');
end


function value = coefficientValue(model, name, variableName)
value = NaN;
rowNames = model.Coefficients.Properties.RowNames;
rowIndex = find(strcmp(rowNames, name), 1);
if ~isempty(rowIndex)
    value = model.Coefficients.(variableName)(rowIndex);
end
end


function channelSummary = buildChannelSummary(observationAudit, relativePositions)
firstCondition = observationAudit.ConditionIndex == 1;
channelRows = observationAudit(firstCondition, :);
numPositions = numel(relativePositions);
RelativeChannelPosition = relativePositions(:);
NCohortSessions = NaN(numPositions, 1);
NAvailableChannels = NaN(numPositions, 1);
NValidSignComparisons = NaN(numPositions, 1);
NDominanceSignChanges = NaN(numPositions, 1);
FractionDominanceSignChanges = NaN(numPositions, 1);
NOutsideProbe = NaN(numPositions, 1);
NDeadChannels = NaN(numPositions, 1);
NNonfiniteOD = NaN(numPositions, 1);

for positionIndex = 1:numPositions
    rows = channelRows.RelativeChannelPosition == relativePositions(positionIndex);
    thisPosition = channelRows(rows, :);
    NCohortSessions(positionIndex) = height(thisPosition);
    NAvailableChannels(positionIndex) = nnz( ...
        thisPosition.ChannelAvailability == "available");
    NValidSignComparisons(positionIndex) = nnz( ...
        thisPosition.HasValidSignComparison);
    NDominanceSignChanges(positionIndex) = nnz( ...
        thisPosition.DominanceSignDiffersFromStimulation & ...
        thisPosition.HasValidSignComparison);
    if NValidSignComparisons(positionIndex) > 0
        FractionDominanceSignChanges(positionIndex) = ...
            NDominanceSignChanges(positionIndex) ./ ...
            NValidSignComparisons(positionIndex);
    end
    NOutsideProbe(positionIndex) = nnz( ...
        thisPosition.ChannelAvailability == "outside probe");
    NDeadChannels(positionIndex) = nnz( ...
        thisPosition.ChannelAvailability == "dead channel");
    NNonfiniteOD(positionIndex) = nnz( ...
        thisPosition.ChannelAvailability == "nonfinite OD");
end

channelSummary = table(RelativeChannelPosition, NCohortSessions, ...
    NAvailableChannels, NValidSignComparisons, NDominanceSignChanges, ...
    FractionDominanceSignChanges, NOutsideProbe, NDeadChannels, ...
    NNonfiniteOD);
end


function value = numericCellScalar(cellValue)
if isempty(cellValue)
    value = NaN;
else
    value = cellValue(1);
end
end


function value = tableRowString(variable, row)
if iscell(variable)
    value = string(variable{row});
else
    value = string(variable(row, :));
end
end

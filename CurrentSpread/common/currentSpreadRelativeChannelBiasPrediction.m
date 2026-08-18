function result = currentSpreadRelativeChannelBiasPrediction(paths, options)
%CURRENTSPREADRELATIVECHANNELBIASPREDICTION Test single-channel AI versus bias.
%
% This reproduces the population-analysis equation, DeltaBias ~ AI, after
% replacing stimulation-channel AI with combined-cue AI from selected signed
% positions relative to the stimulation channel. It reports both the ordinary
% in-sample population fit and repeated held-out cross-validation.

arguments
    paths (1, 1) struct
    options.RelativePositions (1, :) double {mustBeInteger} = [0 3 4]
    options.NumRepeats (1, 1) double {mustBeInteger, mustBePositive} = 5
    options.NumFolds (1, 1) double {mustBeInteger, ...
        mustBeGreaterThan(options.NumFolds, 1)} = 5
    options.RandomSeed (1, 1) double {mustBeInteger, mustBeNonnegative} = 1
end

relativePositions = unique(options.RelativePositions, 'stable');
if any(abs(relativePositions) > 15)
    error('CurrentSpread:RelativePositionRange', ...
        'Relative channel positions must lie within the 16-channel probe.');
end

unitData = load(paths.unitTableGof, 'unit_table_gof');
unitTableAll = unitData.unit_table_gof;
[selection, behavior] = selectJimMT2DCombinedCue(unitTableAll);
unitTable = unitTableAll(selection, :);
originalRowIndex = find(selection);

channelMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10];
numSessions = height(unitTable);
numPositions = numel(relativePositions);
channelAI = NaN(numSessions, numPositions);
actualChannel = NaN(numSessions, numPositions);
availabilityStatus = strings(numSessions, numPositions);

for positionIndex = 1:numPositions
    [channelAI(:, positionIndex), actualChannel(:, positionIndex), ...
        availabilityStatus(:, positionIndex)] = channelAIAtPosition( ...
        unitTable, relativePositions(positionIndex), channelMap);
end

validByPosition = isfinite(channelAI) & isfinite(behavior);
matchedSelection = all(validByPosition, 2);
if nnz(matchedSelection) < options.NumFolds
    error('CurrentSpread:TooFewMatchedSessions', ...
        'Only %d sessions contain all requested relative positions.', ...
        nnz(matchedSelection));
end

fullFitStatistics = repmat(emptyFitStatistics(), numPositions, 1);
matchedFitStatistics = repmat(emptyFitStatistics(), numPositions, 1);
fullCrossValidation = cell(numPositions, 1);
matchedCrossValidation = cell(numPositions, 1);

for positionIndex = 1:numPositions
    valid = validByPosition(:, positionIndex);
    x = channelAI(valid, positionIndex);
    y = behavior(valid);
    fullFitStatistics(positionIndex) = fitStatistics(x, y);
    fullFolds = repeatedBalancedFolds(numel(y), options.NumFolds, ...
        options.NumRepeats, options.RandomSeed);
    fullCrossValidation{positionIndex} = evaluateCrossValidation( ...
        x, y, fullFolds);
end

matchedBehavior = behavior(matchedSelection);
matchedFolds = repeatedBalancedFolds(numel(matchedBehavior), ...
    options.NumFolds, options.NumRepeats, options.RandomSeed);
for positionIndex = 1:numPositions
    matchedAI = channelAI(matchedSelection, positionIndex);
    matchedFitStatistics(positionIndex) = ...
        fitStatistics(matchedAI, matchedBehavior);
    matchedCrossValidation{positionIndex} = evaluateCrossValidation( ...
        matchedAI, matchedBehavior, matchedFolds);
end

fullModelTable = statisticsTable(relativePositions, ...
    fullFitStatistics, fullCrossValidation, "All available sessions");
matchedModelTable = statisticsTable(relativePositions, ...
    matchedFitStatistics, matchedCrossValidation, "Matched sessions");

sessionTable = table(unitTable.Date, originalRowIndex, ...
    unitTable.OriginalRecIdx, unitTable.StimElec, behavior, matchedSelection, ...
    'VariableNames', {'Date', 'UnitTableRow', 'OriginalRecIdx', ...
    'StimulationChannel', 'DeltaBias', 'IncludedInMatchedComparison'});

for positionIndex = 1:numPositions
    tag = positionTag(relativePositions(positionIndex));
    sessionTable.(['Channel_' tag]) = actualChannel(:, positionIndex);
    sessionTable.(['AI_' tag]) = channelAI(:, positionIndex);
    sessionTable.(['Status_' tag]) = availabilityStatus(:, positionIndex);

    fullMeanPrediction = NaN(numSessions, 1);
    valid = validByPosition(:, positionIndex);
    fullMeanPrediction(valid) = ...
        fullCrossValidation{positionIndex}.meanHeldOutPrediction;
    sessionTable.(['MeanCVPrediction_' tag]) = fullMeanPrediction;

    matchedMeanPrediction = NaN(numSessions, 1);
    matchedMeanPrediction(matchedSelection) = ...
        matchedCrossValidation{positionIndex}.meanHeldOutPrediction;
    sessionTable.(['MatchedMeanCVPrediction_' tag]) = matchedMeanPrediction;
end

result = struct();
result.analysis = "Single relative-channel combined-cue AI prediction";
result.modelEquation = "Behav_bias_NminusS = beta0 + beta1 * channel_AI";
result.sourceTable = string(paths.unitTableGof);
result.behaviorField = "Behav_bias_NminusS{row}(1)";
result.selectionRule = ["Jim"; "MT"; "ND = 2D"; ...
    "combined-cue Behav_goodfit_both"; ...
    "finite combined-cue Behav_bias_NminusS"];
result.channelMap = channelMap;
result.relativePositions = relativePositions;
result.originalRowIndex = originalRowIndex;
result.behavior = behavior;
result.channelAI = channelAI;
result.actualChannel = actualChannel;
result.availabilityStatus = availabilityStatus;
result.validByPosition = validByPosition;
result.matchedSelection = matchedSelection;
result.cohortSessionCount = numSessions;
result.matchedSessionCount = nnz(matchedSelection);
result.fullFitStatistics = fullFitStatistics;
result.matchedFitStatistics = matchedFitStatistics;
result.fullCrossValidation = fullCrossValidation;
result.matchedCrossValidation = matchedCrossValidation;
result.fullModelTable = fullModelTable;
result.matchedModelTable = matchedModelTable;
result.sessionTable = sessionTable;
result.numRepeats = options.NumRepeats;
result.numFolds = options.NumFolds;
result.randomSeed = options.RandomSeed;
end


function [selection, behavior] = selectJimMT2DCombinedCue(unitTable)
numRows = height(unitTable);
selection = false(numRows, 1);
behaviorAll = NaN(numRows, 1);

for row = 1:numRows
    isJimMT = strcmp(unitTable.ROI{row}, 'MT') && ...
        strcmp(unitTable.Monkey{row}, 'Jim');
    is2D = strcmp(unitTable.ND{row}, '2D');
    isGoodFit = ~isempty(unitTable.Behav_goodfit_both{row}) && ...
        logical(unitTable.Behav_goodfit_both{row}(1));
    if isempty(unitTable.Behav_bias_NminusS{row})
        target = NaN;
    else
        target = unitTable.Behav_bias_NminusS{row}(1);
    end
    selection(row) = isJimMT && is2D && isGoodFit && isfinite(target);
    behaviorAll(row) = target;
end
behavior = behaviorAll(selection);
end


function [ai, actualChannel, status] = channelAIAtPosition( ...
    unitTable, relativePosition, channelMap)
numSessions = height(unitTable);
ai = NaN(numSessions, 1);
actualChannel = NaN(numSessions, 1);
status = repmat("available", numSessions, 1);

for session = 1:numSessions
    stimulationIndex = find(channelMap == unitTable.StimElec(session), 1);
    if isempty(stimulationIndex)
        status(session) = "stimulation channel not mapped";
        continue
    end
    probeIndex = stimulationIndex + relativePosition;
    if probeIndex < 1 || probeIndex > numel(channelMap)
        status(session) = "outside probe";
        continue
    end

    channel = channelMap(probeIndex);
    actualChannel(session) = channel;
    if ismember(channel, unitTable.DeadChannel{session})
        status(session) = "dead channel";
        continue
    end

    value = unitTable.AI{session}(1, channel);
    if ~isfinite(value)
        status(session) = "nonfinite AI";
        continue
    end
    ai(session) = value;
end
end


function statistics = emptyFitStatistics()
statistics = struct('N', NaN, 'Intercept', NaN, 'Slope', NaN, ...
    'SlopeSE', NaN, 'SlopePValue', NaN, 'PearsonR', NaN, ...
    'PearsonPValue', NaN, 'OrdinaryR2', NaN, 'AdjustedR2', NaN, ...
    'RMSE', NaN);
end


function statistics = fitStatistics(x, y)
valid = isfinite(x) & isfinite(y);
x = x(valid);
y = y(valid);
statistics = emptyFitStatistics();
statistics.N = numel(y);
if numel(y) < 3 || std(x) <= eps
    return
end

linearModel = fitlm(x, y);
[pearsonR, pearsonP] = corr(x, y);
statistics.Intercept = linearModel.Coefficients.Estimate(1);
statistics.Slope = linearModel.Coefficients.Estimate(2);
statistics.SlopeSE = linearModel.Coefficients.SE(2);
statistics.SlopePValue = linearModel.Coefficients.pValue(2);
statistics.PearsonR = pearsonR;
statistics.PearsonPValue = pearsonP;
statistics.OrdinaryR2 = linearModel.Rsquared.Ordinary;
statistics.AdjustedR2 = linearModel.Rsquared.Adjusted;
statistics.RMSE = linearModel.RMSE;
end


function foldMatrix = repeatedBalancedFolds( ...
    numRows, numFolds, numRepeats, randomSeed)
numFolds = min(numFolds, numRows);
foldMatrix = zeros(numRows, numRepeats);
for repeatIndex = 1:numRepeats
    stream = RandStream('mt19937ar', ...
        'Seed', randomSeed + repeatIndex - 1);
    order = randperm(stream, numRows);
    folds = zeros(numRows, 1);
    folds(order) = mod(0:numRows-1, numFolds) + 1;
    foldMatrix(:, repeatIndex) = folds;
end
end


function cv = evaluateCrossValidation(x, y, foldMatrix)
numRepeats = size(foldMatrix, 2);
prediction = NaN(numel(y), numRepeats);
nullPrediction = NaN(numel(y), numRepeats);
betaByRepeat = cell(numRepeats, 1);
r2ByRepeat = NaN(numRepeats, 1);

for repeatIndex = 1:numRepeats
    folds = foldMatrix(:, repeatIndex);
    foldLabels = unique(folds)';
    foldBeta = NaN(numel(foldLabels), 2);
    for foldIndex = 1:numel(foldLabels)
        test = folds == foldLabels(foldIndex);
        train = ~test;
        design = [ones(nnz(train), 1), x(train)];
        beta = design \ y(train);
        prediction(test, repeatIndex) = ...
            beta(1) + beta(2) .* x(test);
        nullPrediction(test, repeatIndex) = mean(y(train), 'omitnan');
        foldBeta(foldIndex, :) = beta(:)';
    end
    r2ByRepeat(repeatIndex) = crossValidatedR2( ...
        y, prediction(:, repeatIndex), nullPrediction(:, repeatIndex));
    betaByRepeat{repeatIndex} = foldBeta;
end

cv = struct();
cv.foldMatrix = foldMatrix;
cv.predictionByRepeat = prediction;
cv.nullPredictionByRepeat = nullPrediction;
cv.meanHeldOutPrediction = mean(prediction, 2, 'omitnan');
cv.meanNullPrediction = mean(nullPrediction, 2, 'omitnan');
cv.betaByRepeat = betaByRepeat;
cv.r2ByRepeat = r2ByRepeat;
cv.meanR2 = mean(r2ByRepeat, 'omitnan');
cv.sdR2 = std(r2ByRepeat, 0, 'omitnan');
cv.semR2 = cv.sdR2 ./ sqrt(numRepeats);
end


function value = crossValidatedR2(observed, predicted, nullPredicted)
valid = isfinite(observed) & isfinite(predicted) & isfinite(nullPredicted);
modelSSE = sum((observed(valid) - predicted(valid)).^2);
nullSSE = sum((observed(valid) - nullPredicted(valid)).^2);
if nnz(valid) < 3 || nullSSE <= eps
    value = NaN;
else
    value = 1 - modelSSE ./ nullSSE;
end
end


function outputTable = statisticsTable( ...
    relativePositions, statistics, crossValidation, subsetLabel)
numPositions = numel(relativePositions);
N = NaN(numPositions, 1);
Intercept = NaN(numPositions, 1);
Slope = NaN(numPositions, 1);
SlopeSE = NaN(numPositions, 1);
SlopePValue = NaN(numPositions, 1);
PearsonR = NaN(numPositions, 1);
PearsonPValue = NaN(numPositions, 1);
OrdinaryR2 = NaN(numPositions, 1);
AdjustedR2 = NaN(numPositions, 1);
RMSE = NaN(numPositions, 1);
MeanCrossValidatedR2 = NaN(numPositions, 1);
SDCrossValidatedR2 = NaN(numPositions, 1);
SEMCrossValidatedR2 = NaN(numPositions, 1);

for positionIndex = 1:numPositions
    N(positionIndex) = statistics(positionIndex).N;
    Intercept(positionIndex) = statistics(positionIndex).Intercept;
    Slope(positionIndex) = statistics(positionIndex).Slope;
    SlopeSE(positionIndex) = statistics(positionIndex).SlopeSE;
    SlopePValue(positionIndex) = statistics(positionIndex).SlopePValue;
    PearsonR(positionIndex) = statistics(positionIndex).PearsonR;
    PearsonPValue(positionIndex) = statistics(positionIndex).PearsonPValue;
    OrdinaryR2(positionIndex) = statistics(positionIndex).OrdinaryR2;
    AdjustedR2(positionIndex) = statistics(positionIndex).AdjustedR2;
    RMSE(positionIndex) = statistics(positionIndex).RMSE;
    MeanCrossValidatedR2(positionIndex) = ...
        crossValidation{positionIndex}.meanR2;
    SDCrossValidatedR2(positionIndex) = ...
        crossValidation{positionIndex}.sdR2;
    SEMCrossValidatedR2(positionIndex) = ...
        crossValidation{positionIndex}.semR2;
end

outputTable = table(repmat(subsetLabel, numPositions, 1), ...
    relativePositions(:), N, Intercept, Slope, SlopeSE, SlopePValue, ...
    PearsonR, PearsonPValue, OrdinaryR2, AdjustedR2, RMSE, ...
    MeanCrossValidatedR2, SDCrossValidatedR2, SEMCrossValidatedR2, ...
    'VariableNames', {'Subset', 'RelativeChannelPosition', 'N', ...
    'Intercept', 'Slope', 'SlopeSE', 'SlopePValue', 'PearsonR', ...
    'PearsonPValue', 'OrdinaryR2', 'AdjustedR2', 'RMSE', ...
    'MeanCrossValidatedR2', 'SDCrossValidatedR2', ...
    'SEMCrossValidatedR2'});
end


function tag = positionTag(relativePosition)
if relativePosition < 0
    tag = sprintf('minus%02d', abs(relativePosition));
elseif relativePosition > 0
    tag = sprintf('plus%02d', relativePosition);
else
    tag = 'zero';
end
end

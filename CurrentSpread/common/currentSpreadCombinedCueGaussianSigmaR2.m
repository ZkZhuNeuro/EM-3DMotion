function result = currentSpreadCombinedCueGaussianSigmaR2(paths, method, options)
%CURRENTSPREADCOMBINEDCUEGAUSSIANSIGMAR2 Test Gaussian spread with CV R-squared.
%
% The common analysis is:
%   combined-cue DeltaBias = beta0 + beta1 * Gaussian-weighted AI.
%
% Sigma is evaluated on a fixed grid. For every sigma and outer fold, the
% regression coefficients are fit only on training sessions and evaluated on
% held-out sessions. For the FR method, Gaussian weights are applied to the
% channel tuning curves before AI is calculated.

arguments
    paths (1, 1) struct
    method (1, 1) string {mustBeMember(method, ["gaussian-ai", "gaussian-fr"])}
    options.NumRepeats (1, 1) double {mustBeInteger, mustBePositive} = 5
    options.NumFolds (1, 1) double {mustBeInteger, ...
        mustBeGreaterThan(options.NumFolds, 1)} = 5
    options.RandomSeed (1, 1) double {mustBeInteger, mustBeNonnegative} = 1
    options.SigmaValues (1, :) double = logspace(-2, 2, 41)
end

sigmaValues = sort(unique(options.SigmaValues(:)));
if isempty(sigmaValues) || any(~isfinite(sigmaValues)) || any(sigmaValues <= 0)
    error('CurrentSpread:SigmaValues', ...
        'SigmaValues must contain finite positive values.');
end

unitData = load(paths.unitTableGof, 'unit_table_gof');
unitTableAll = unitData.unit_table_gof;
[selection, behavior] = selectJimMT2DCombinedCue(unitTableAll);
unitTable = unitTableAll(selection, :);

channelMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10];
maxRadius = 7;
positionOffset = (-maxRadius:maxRadius)';

if method == "gaussian-ai"
    alignedData = alignCombinedCueAI(unitTable, channelMap, maxRadius);
    dataType = "ai";
else
    neuroData = load(paths.neuroAll, 'NeuroAll');
    neuroIndex = unitTable.OriginalRecIdx;
    if any(~isfinite(neuroIndex)) || any(neuroIndex < 1) || ...
            any(neuroIndex > numel(neuroData.NeuroAll))
        error('CurrentSpread:NeuroIndex', ...
            'Selected unit_table_gof rows do not map to NeuroAll via OriginalRecIdx.');
    end
    alignedData = alignCombinedCueFR(neuroData.NeuroAll(neuroIndex), ...
        unitTable, channelMap, maxRadius);
    dataType = "fr";
end

numSigmas = numel(sigmaValues);
numSessions = numel(behavior);
weightsBySigma = NaN(numel(positionOffset), numSigmas);
weightedAIBySigma = NaN(numSessions, numSigmas);
for sigmaIndex = 1:numSigmas
    weights = gaussianPositionWeights(positionOffset, sigmaValues(sigmaIndex));
    weightsBySigma(:, sigmaIndex) = weights;
    weightedAIBySigma(:, sigmaIndex) = calculateWeightedAI( ...
        alignedData, weights, dataType);
end

numRepeats = options.NumRepeats;
numFolds = min(options.NumFolds, numSessions);
r2ByRepeat = NaN(numRepeats, numSigmas);
predictionByRepeat = cell(numRepeats, numSigmas);
nullPredictionByRepeat = cell(numRepeats, numSigmas);
betaByRepeat = cell(numRepeats, numSigmas);

for repeatIndex = 1:numRepeats
    folds = balancedFolds(numSessions, numFolds, ...
        options.RandomSeed + repeatIndex - 1);

    for sigmaIndex = 1:numSigmas
        predictor = weightedAIBySigma(:, sigmaIndex);
        prediction = NaN(size(behavior));
        nullPrediction = NaN(size(behavior));
        foldBeta = NaN(numFolds, 2);

        for fold = 1:numFolds
            testIndex = folds == fold;
            trainIndex = ~testIndex;
            beta = fitLinearModel(predictor(trainIndex), behavior(trainIndex));
            if all(isfinite(beta))
                prediction(testIndex) = beta(1) + beta(2) .* predictor(testIndex);
            end
            nullPrediction(testIndex) = mean(behavior(trainIndex), 'omitnan');
            foldBeta(fold, :) = beta(:)';
        end

        r2ByRepeat(repeatIndex, sigmaIndex) = crossValidatedR2( ...
            behavior, prediction, nullPrediction);
        predictionByRepeat{repeatIndex, sigmaIndex} = prediction;
        nullPredictionByRepeat{repeatIndex, sigmaIndex} = nullPrediction;
        betaByRepeat{repeatIndex, sigmaIndex} = foldBeta;
    end
end

meanR2 = mean(r2ByRepeat, 1, 'omitnan')';
semR2 = std(r2ByRepeat, 0, 1, 'omitnan')' ./ sqrt(numRepeats);
finiteMean = isfinite(meanR2);
if any(finiteMean)
    finiteIndices = find(finiteMean);
    [~, relativeBestIndex] = max(meanR2(finiteMean));
    bestIndex = finiteIndices(relativeBestIndex);
else
    bestIndex = NaN;
end

effectiveChannels = 1 ./ sum(weightsBySigma.^2, 1)';

result = struct();
result.method = method;
result.methodLabel = methodLabel(method);
result.modelEquation = ...
    "DeltaBias_combined = beta0 + beta1 * AI_Gaussian(sigma)";
result.sourceTable = string(paths.unitTableGof);
result.behaviorField = "Behav_bias_NminusS{row}(1)";
result.selectionRule = ["Jim"; "MT"; "ND = 2D"; ...
    "combined-cue Behav_goodfit_both"; ...
    "finite combined-cue Behav_bias_NminusS"];
result.originalRowIndex = find(selection);
result.sessionCount = height(unitTable);
result.behavior = behavior;
result.sigmaValues = sigmaValues;
result.positionOffset = positionOffset;
result.weightsBySigma = weightsBySigma;
result.effectiveChannels = effectiveChannels;
result.weightedAIBySigma = weightedAIBySigma;
result.r2ByRepeat = r2ByRepeat;
result.meanR2 = meanR2;
result.semR2 = semR2;
result.predictionByRepeat = predictionByRepeat;
result.nullPredictionByRepeat = nullPredictionByRepeat;
result.betaByRepeat = betaByRepeat;
result.numRepeats = numRepeats;
result.numFolds = numFolds;
result.randomSeed = options.RandomSeed;
result.bestIndex = bestIndex;
if isfinite(bestIndex)
    result.bestSigma = sigmaValues(bestIndex);
    result.bestMeanR2 = meanR2(bestIndex);
    result.bestWeights = weightsBySigma(:, bestIndex);
else
    result.bestSigma = NaN;
    result.bestMeanR2 = NaN;
    result.bestWeights = NaN(size(positionOffset));
end
result.table = table(sigmaValues, effectiveChannels, meanR2, semR2, ...
    'VariableNames', {'Sigma', 'EffectiveChannels', ...
    'MeanCrossValidatedR2', 'SEMCrossValidatedR2'});
result.bestWeightTable = table(positionOffset, result.bestWeights, ...
    'VariableNames', {'RelativeChannelPosition', 'GaussianWeight'});
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

function alignedAI = alignCombinedCueAI(unitTable, channelMap, maxRadius)
numSessions = height(unitTable);
numPositions = 2 * maxRadius + 1;
alignedAI = NaN(numSessions, numPositions);

for session = 1:numSessions
    stimulationIndex = find(channelMap == unitTable.StimElec(session), 1);
    deadChannels = unitTable.DeadChannel{session};
    for relativePosition = -maxRadius:maxRadius
        probeIndex = stimulationIndex + relativePosition;
        outputIndex = relativePosition + maxRadius + 1;
        if probeIndex < 1 || probeIndex > numel(channelMap)
            continue
        end
        channel = channelMap(probeIndex);
        if ismember(channel, deadChannels)
            continue
        end
        value = unitTable.AI{session}(1, channel);
        if isfinite(value)
            alignedAI(session, outputIndex) = value;
        end
    end
end
end

function alignedFR = alignCombinedCueFR(neuroAll, unitTable, channelMap, maxRadius)
numSessions = height(unitTable);
numPositions = 2 * maxRadius + 1;
alignedFR = cell(numSessions, numPositions);

for session = 1:numSessions
    stimulationIndex = find(channelMap == unitTable.StimElec(session), 1);
    deadChannels = unitTable.DeadChannel{session};
    recording = neuroAll{session};
    coherenceIndex = [1:4, size(recording, 2)-3:size(recording, 2)];

    for relativePosition = -maxRadius:maxRadius
        probeIndex = stimulationIndex + relativePosition;
        outputIndex = relativePosition + maxRadius + 1;
        if probeIndex < 1 || probeIndex > numel(channelMap)
            continue
        end
        channel = channelMap(probeIndex);
        if ismember(channel, deadChannels)
            continue
        end

        channelData = squeeze(recording(1, coherenceIndex, :, channel));
        channelMean = mean(channelData, 'all', 'omitnan');
        channelStd = std(channelData, 0, 'all', 'omitnan');
        if ~(isfinite(channelStd) && channelStd > 0)
            continue
        end
        alignedFR{session, outputIndex} = ...
            (channelData - channelMean) ./ channelStd;
    end
end
end

function weightedAI = calculateWeightedAI(data, positionWeights, dataType)
if dataType == "ai"
    available = isfinite(data);
    values = data;
    values(~available) = 0;
    numerator = values * positionWeights;
    denominator = available * positionWeights;
    weightedAI = numerator ./ denominator;
    weightedAI(denominator <= eps) = NaN;
else
    weightedAI = firingRateAI(data, positionWeights);
end
end

function values = firingRateAI(frData, positionWeights)
numSessions = size(frData, 1);
values = NaN(numSessions, 1);

for session = 1:numSessions
    weightedNumerator = [];
    weightedDenominator = [];
    for position = 1:size(frData, 2)
        response = frData{session, position};
        if isempty(response) || ~any(isfinite(response), 'all') || ...
                positionWeights(position) <= eps
            continue
        end
        if isempty(weightedNumerator)
            weightedNumerator = zeros(size(response));
            weightedDenominator = zeros(size(response));
        end
        finiteResponse = isfinite(response);
        response(~finiteResponse) = 0;
        weightedNumerator = weightedNumerator + ...
            positionWeights(position) .* response;
        weightedDenominator = weightedDenominator + ...
            positionWeights(position) .* finiteResponse;
    end
    if isempty(weightedNumerator)
        continue
    end
    weightedResponse = weightedNumerator ./ weightedDenominator;
    weightedResponse(weightedDenominator <= eps) = NaN;
    values(session) = combinedCueAsymmetryIndex(weightedResponse);
end
end

function value = combinedCueAsymmetryIndex(response)
toward = flipud(response(5:8, :));
away = response(1:4, :);
towardMean = mean(toward, 2, 'omitnan');
awayMean = mean(away, 2, 'omitnan');
towardStd = std(toward, 0, 2, 'omitnan');
awayStd = std(away, 0, 2, 'omitnan');
denominator = abs(towardMean - awayMean) + ...
    mean([towardStd, awayStd], 2, 'omitnan');
perCoherence = (towardMean - awayMean) ./ denominator;
value = mean(perCoherence, 'omitnan');
end

function weights = gaussianPositionWeights(positionOffset, sigma)
weights = exp(-(positionOffset.^2) ./ (2 .* sigma.^2));
weights = weights ./ sum(weights);
end

function beta = fitLinearModel(predictor, behavior)
valid = isfinite(predictor) & isfinite(behavior);
if sum(valid) < 3 || std(predictor(valid)) <= eps
    beta = [NaN; NaN];
    return
end
design = [ones(sum(valid), 1), predictor(valid)];
beta = design \ behavior(valid);
end

function folds = balancedFolds(numRows, numFolds, seed)
stream = RandStream('mt19937ar', 'Seed', seed);
order = randperm(stream, numRows);
folds = zeros(numRows, 1);
folds(order) = mod(0:numRows-1, numFolds) + 1;
end

function value = crossValidatedR2(observed, predicted, nullPredicted)
valid = isfinite(observed) & isfinite(predicted) & isfinite(nullPredicted);
modelSSE = sum((observed(valid) - predicted(valid)).^2);
nullSSE = sum((observed(valid) - nullPredicted(valid)).^2);
if sum(valid) < 3 || nullSSE <= eps
    value = NaN;
else
    value = 1 - modelSSE ./ nullSSE;
end
end

function label = methodLabel(method)
switch method
    case "gaussian-ai"
        label = "Gaussian relative-position weights on combined-cue channel AI";
    case "gaussian-fr"
        label = ["Gaussian relative-position weights on combined-cue firing" ...
            " rates (AI calculated after averaging)"];
end
end

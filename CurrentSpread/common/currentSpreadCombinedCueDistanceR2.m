function result = currentSpreadCombinedCueDistanceR2(paths, method, options)
%CURRENTSPREADCOMBINEDCUEDISTANCER2 Optimize spatial weights and test DeltaBias ~ AI.
%
% The common analysis is:
%   combined-cue DeltaBias = beta0 + beta1 * spatially weighted AI.
%
% For AI models, the feature is a weighted average of the stored combined-cue
% AI values across channels. For FR models, combined-cue firing-rate tuning
% curves are first combined with the spatial weights and AI is then calculated
% from the weighted-average tuning curve. Weight fitting and beta fitting use
% only outer-training sessions. Held-out predictions determine CV R-squared.

arguments
    paths (1, 1) struct
    method (1, 1) string {mustBeMember(method, ...
        ["free-ai", "free-fr", "shell-ai", "shell-fr"])}
    options.NumRepeats (1, 1) double {mustBeInteger, mustBePositive} = 5
    options.NumFolds (1, 1) double {mustBeInteger, ...
        mustBeGreaterThan(options.NumFolds, 1)} = 5
    options.RandomSeed (1, 1) double {mustBeInteger, mustBeNonnegative} = 1
end

unitData = load(paths.unitTableGof, 'unit_table_gof');
unitTableAll = unitData.unit_table_gof;
[selection, behavior] = selectJimMT2DCombinedCue(unitTableAll);
unitTable = unitTableAll(selection, :);

channelMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10];
maxRadius = 7;
channelsIncluded = (1:2:(2 * maxRadius + 1))';
maxDistanceChannels = (0:maxRadius)';

if endsWith(method, "-ai")
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

if startsWith(method, "free-")
    weightModel = "free";
else
    weightModel = "shell";
end

numRepeats = options.NumRepeats;
numFolds = options.NumFolds;
r2ByRepeat = NaN(numRepeats, maxRadius + 1);
predictionByRepeat = cell(numRepeats, maxRadius + 1);
nullPredictionByRepeat = cell(numRepeats, maxRadius + 1);
weightsByRepeat = cell(numRepeats, maxRadius + 1);
betaByRepeat = cell(numRepeats, maxRadius + 1);

for repeatIndex = 1:numRepeats
    folds = balancedFolds(numel(behavior), numFolds, ...
        options.RandomSeed + repeatIndex - 1);

    for radius = 0:maxRadius
        window = (maxRadius + 1 - radius):(maxRadius + 1 + radius);
        windowData = alignedData(:, window);
        prediction = NaN(size(behavior));
        nullPrediction = NaN(size(behavior));
        foldWeights = cell(numFolds, 1);
        foldBeta = NaN(numFolds, 2);

        for fold = 1:numFolds
            testIndex = folds == fold;
            trainIndex = ~testIndex;
            [weights, beta] = fitWeightedLinearModel( ...
                windowData(trainIndex, :), behavior(trainIndex), ...
                dataType, weightModel, radius);

            testAI = calculateWeightedAI(windowData(testIndex, :), ...
                weights, dataType, weightModel, radius);
            prediction(testIndex) = beta(1) + beta(2) .* testAI;
            nullPrediction(testIndex) = mean(behavior(trainIndex), 'omitnan');
            foldWeights{fold} = weights;
            foldBeta(fold, :) = beta(:)';
        end

        r2ByRepeat(repeatIndex, radius + 1) = ...
            crossValidatedR2(behavior, prediction, nullPrediction);
        predictionByRepeat{repeatIndex, radius + 1} = prediction;
        nullPredictionByRepeat{repeatIndex, radius + 1} = nullPrediction;
        weightsByRepeat{repeatIndex, radius + 1} = foldWeights;
        betaByRepeat{repeatIndex, radius + 1} = foldBeta;
    end
end

result = struct();
result.method = method;
result.methodLabel = methodLabel(method);
result.modelEquation = "DeltaBias_combined = beta0 + beta1 * AI_weighted";
result.sourceTable = string(paths.unitTableGof);
result.behaviorField = "Behav_bias_NminusS{row}(1)";
result.selectionRule = ["Jim"; "MT"; "ND = 2D"; ...
    "combined-cue Behav_goodfit_both"; ...
    "finite combined-cue Behav_bias_NminusS"];
result.originalRowIndex = find(selection);
result.sessionCount = height(unitTable);
result.behavior = behavior;
result.channelsIncluded = channelsIncluded;
result.maxDistanceChannels = maxDistanceChannels;
result.r2ByRepeat = r2ByRepeat;
result.meanR2 = mean(r2ByRepeat, 1, 'omitnan')';
result.semR2 = std(r2ByRepeat, 0, 1, 'omitnan')' ./ sqrt(numRepeats);
result.predictionByRepeat = predictionByRepeat;
result.nullPredictionByRepeat = nullPredictionByRepeat;
result.weightsByRepeat = weightsByRepeat;
result.betaByRepeat = betaByRepeat;
result.numRepeats = numRepeats;
result.numFolds = numFolds;
result.randomSeed = options.RandomSeed;
result.table = table(channelsIncluded, maxDistanceChannels, ...
    result.meanR2, result.semR2, ...
    'VariableNames', {'ChannelsIncluded', 'MaxDistanceChannels', ...
    'MeanCrossValidatedR2', 'SEMCrossValidatedR2'});
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

function [weights, beta] = fitWeightedLinearModel(data, behavior, ...
    dataType, weightModel, radius)
[initialPoints, A, b, Aeq, beq, lb, ub] = ...
    weightConstraints(weightModel, radius);

if radius == 0
    weights = 1;
    weightedAI = calculateWeightedAI(data, weights, dataType, ...
        weightModel, radius);
    beta = fitLinearModel(weightedAI, behavior);
    return
end

options = optimoptions('fmincon', 'Display', 'off', 'Algorithm', 'sqp', ...
    'MaxIterations', 300, 'MaxFunctionEvaluations', 5000, ...
    'OptimalityTolerance', 1e-7, 'StepTolerance', 1e-8);
bestObjective = Inf;
weights = initialPoints(:, 1);

for startIndex = 1:size(initialPoints, 2)
    [candidate, objective] = fmincon( ...
        @(w) trainingObjective(w, data, behavior, dataType, ...
        weightModel, radius), initialPoints(:, startIndex), ...
        A, b, Aeq, beq, lb, ub, [], options);
    if objective < bestObjective
        bestObjective = objective;
        weights = candidate;
    end
end

weightedAI = calculateWeightedAI(data, weights, dataType, ...
    weightModel, radius);
beta = fitLinearModel(weightedAI, behavior);
end

function objective = trainingObjective(weights, data, behavior, ...
    dataType, weightModel, radius)
weightedAI = calculateWeightedAI(data, weights, dataType, ...
    weightModel, radius);
valid = isfinite(weightedAI) & isfinite(behavior);
if ~all(valid) || std(weightedAI) <= eps
    objective = 1e12;
    return
end
beta = fitLinearModel(weightedAI(valid), behavior(valid));
residual = behavior(valid) - beta(1) - beta(2) .* weightedAI(valid);
objective = sum(residual.^2);
end

function beta = fitLinearModel(weightedAI, behavior)
valid = isfinite(weightedAI) & isfinite(behavior);
design = [ones(sum(valid), 1), weightedAI(valid)];
beta = design \ behavior(valid);
end

function weightedAI = calculateWeightedAI(data, weights, dataType, ...
    weightModel, radius)
positionWeights = expandPositionWeights(weights, weightModel, radius);
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
% This sign convention matches unit_table.AI(:, cue 1).
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

function [initialPoints, A, b, Aeq, beq, lb, ub] = ...
    weightConstraints(weightModel, radius)
numPositions = 2 * radius + 1;

if weightModel == "free"
    numWeights = numPositions;
    uniform = ones(numWeights, 1) ./ numWeights;
    centerHeavy = ones(numWeights, 1) .* (0.2 ./ max(numWeights - 1, 1));
    centerHeavy(radius + 1) = 0.8;
    initialPoints = [uniform, centerHeavy];
    A = [];
    b = [];
    Aeq = ones(1, numWeights);
    beq = 1;
else
    numWeights = radius + 1;
    uniform = ones(numWeights, 1) ./ numPositions;
    centerHeavy = [0.8; repmat(0.2 ./ (2 * radius), radius, 1)];
    initialPoints = [uniform, centerHeavy];
    A = zeros(radius, numWeights);
    for distance = 1:radius
        A(distance, distance) = -1;
        A(distance, distance + 1) = 1;
    end
    b = zeros(radius, 1);
    Aeq = [1, 2 .* ones(1, radius)];
    beq = 1;
end

lb = zeros(numWeights, 1);
ub = ones(numWeights, 1);
end

function positionWeights = expandPositionWeights(weights, weightModel, radius)
if weightModel == "free"
    positionWeights = weights(:);
else
    distances = abs((-radius:radius)');
    positionWeights = weights(distances + 1);
end
end

function folds = balancedFolds(numRows, numFolds, seed)
numFolds = min(numFolds, numRows);
stream = RandStream('mt19937ar', 'Seed', seed);
order = randperm(stream, numRows);
folds = zeros(numRows, 1);
folds(order) = mod(0:numRows-1, numFolds) + 1;
end

function value = crossValidatedR2(observed, predicted, nullPredicted)
valid = isfinite(observed) & isfinite(predicted) & isfinite(nullPredicted);
modelSSE = sum((observed(valid) - predicted(valid)).^2);
nullSSE = sum((observed(valid) - nullPredicted(valid)).^2);
value = 1 - modelSSE ./ nullSSE;
end

function label = methodLabel(method)
switch method
    case "free-ai"
        label = "Free relative-position weights on combined-cue channel AI";
    case "free-fr"
        label = ["Free relative-position weights on combined-cue firing rates" ...
            " (AI calculated after averaging)"];
    case "shell-ai"
        label = "Symmetric monotonic distance-shell weights on combined-cue AI";
    case "shell-fr"
        label = ["Symmetric monotonic distance-shell weights on combined-cue" ...
            " firing rates (AI calculated after averaging)"];
end
end

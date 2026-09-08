function result = crossValidateGaussianChannelDesign(designGrid, observed, observationMap, sigmaValues, options)
%CROSSVALIDATEGAUSSIANCHANNELDESIGN Repeated and nested session-grouped CV.
% The same neural design can use either two (Combined AI) or three (local
% cue AI plus AI:OD) terms per condition. Sigma always minimizes equal-cue
% held-out MSE. Outer-test behavior never enters inner sigma selection.
% TuneSigma=false evaluates one fixed design (e.g. literal StimChannel AI)
% on the same outer folds without running inner CV or reporting a sigma.

arguments
    designGrid double
    observed (:, 1) double
    observationMap table
    sigmaValues (:, 1) double {mustBeFinite, mustBePositive}
    options.NumRepeats (1, 1) double {mustBeInteger, mustBePositive} = 5
    options.NumFolds (1, 1) double {mustBeInteger, mustBeGreaterThan(options.NumFolds, 1)} = 5
    options.NumInnerFolds (1, 1) double {mustBeInteger, mustBeGreaterThan(options.NumInnerFolds, 1)} = 5
    options.RandomSeed (1, 1) double {mustBeInteger, mustBeNonnegative} = 1
    options.RunNested (1, 1) logical = true
    options.TuneSigma (1, 1) logical = true
    options.Verbose (1, 1) logical = true
end

numSigmas = numel(sigmaValues);
if ~options.TuneSigma && numSigmas ~= 1
    error('GaussianChannelCV:FixedDesignSize', 'A model without sigma tuning must supply exactly one design page.');
end
numTerms = size(designGrid, 2) / 4;
if size(designGrid, 1) ~= numel(observed) || height(observationMap) ~= numel(observed) || ...
        size(designGrid, 3) ~= numSigmas || ~ismember(numTerms, [2 3]) || ...
        any(~isfinite(designGrid), 'all') || any(~isfinite(observed))
    error('GaussianChannelCV:InvalidDesign', 'Expected finite N-by-(8 or 12)-by-Sigma design and N observed rows.');
end
numSessions = max(observationMap.SessionIndex);
if ~isequal(unique(observationMap.SessionIndex), (1:numSessions)')
    error('GaussianChannelCV:SessionIndex', 'Session indices must be contiguous from 1.');
end
numFolds = min(options.NumFolds, numSessions);
if numFolds < 2
    error('GaussianChannelCV:TooFewSessions', 'At least two sessions are required.');
end
numRepeats = options.NumRepeats;
folds = zeros(numSessions, numRepeats);
for repeat = 1:numRepeats
    folds(:, repeat) = balancedFolds(numSessions, numFolds, options.RandomSeed + repeat - 1);
end
predictions = nan(numel(observed), numSigmas, numRepeats);
nullPredictions = nan(numel(observed), numRepeats);
perCueMSE = nan(numRepeats, 4, numSigmas);
perCueR2 = nan(numRepeats, 4, numSigmas);
pooledR2 = nan(numRepeats, numSigmas);
for repeat = 1:numRepeats
    [predictions(:, :, repeat), nullPredictions(:, repeat)] = cvPredictions( ...
        designGrid, observed, observationMap, folds(:, repeat), true(numSessions, 1));
    [mse, r2, pooled] = metrics(observed, predictions(:, :, repeat), ...
        nullPredictions(:, repeat), observationMap.ConditionIndex);
    perCueMSE(repeat, :, :) = reshape(mse, 1, 4, numSigmas);
    perCueR2(repeat, :, :) = reshape(r2, 1, 4, numSigmas);
    pooledR2(repeat, :) = pooled;
    if options.Verbose && numRepeats > 10 && ...
            (repeat == 1 || mod(repeat, 10) == 0 || repeat == numRepeats)
        fprintf('  Selection CV: completed repeat %d/%d.\n', repeat, numRepeats);
    end
end
meanMSE = reshape(mean(mean(perCueMSE, 2), 1), numSigmas, 1);
[bestMSE, bestIndex] = min(meanMSE);
if ~isfinite(bestMSE)
    error('GaussianChannelCV:InvalidObjective', 'Every cue needs held-out predictions at every sigma.');
end
result = struct();
result.SigmaValues = sigmaValues;
result.NumRepeats = numRepeats;
result.NumFolds = numFolds;
result.NumInnerFolds = options.NumInnerFolds;
result.RandomSeed = options.RandomSeed;
result.FoldAssignments = folds;
result.Observed = observed;
result.ObservationMap = observationMap;
result.PerCueCVMSEByRepeat = perCueMSE;
result.PerCueCVR2ByRepeat = perCueR2;
result.MeanCVMSE = meanMSE;
result.PerCueMeanCVMSE = reshape(mean(perCueMSE, 1), 4, numSigmas);
result.PerCueMeanCVR2 = reshape(mean(perCueR2, 1), 4, numSigmas);
result.MeanCVR2 = mean(pooledR2, 1)';
result.BestSigma = sigmaValues(bestIndex);
result.TuneSigma = options.TuneSigma;
if ~options.TuneSigma
    result.BestSigma = NaN; % Sigma has no meaning for the fixed design.
    result.SigmaValues = NaN;
end
result.BestIndex = bestIndex;
result.BestCVMSE = bestMSE;
result.BestCVR2 = result.MeanCVR2(bestIndex);
result.BestPredictionByRepeat = reshape(predictions(:, bestIndex, :), numel(observed), numRepeats);
result.NullPredictionByRepeat = nullPredictions;
result.MeanHeldOutPredictionBySigma = mean(predictions, 3);
result.Nested = struct();
if ~options.RunNested
    return
end
clear predictions

nestedPrediction = nan(numel(observed), numRepeats);
nestedSigma = nan(numRepeats, numFolds);
nestedBeta = cell(numRepeats, numFolds);
innerAssignments = zeros(numSessions, numFolds, numRepeats);
innerObjective = nan(numSigmas, numFolds, numRepeats);
foldMSE = nan(numRepeats, numFolds, 5);
foldSizeRatio = nan(numRepeats, numFolds, 5);
for repeat = 1:numRepeats
    for outerFold = 1:numFolds
        trainSessions = find(folds(:, repeat) ~= outerFold);
        train = ismember(observationMap.SessionIndex, trainSessions);
        test = ~train;
        if options.TuneSigma
            innerFolds = zeros(numSessions, 1);
            innerFolds(trainSessions) = balancedFolds(numel(trainSessions), ...
                min(options.NumInnerFolds, numel(trainSessions)), ...
                options.RandomSeed + 10000 + (repeat - 1) .* numFolds + outerFold);
            innerAssignments(:, outerFold, repeat) = innerFolds;
            [innerPrediction, innerNull] = cvPredictions(designGrid, observed, ...
                observationMap, innerFolds, folds(:, repeat) ~= outerFold);
            innerMSE = metrics(observed(train), innerPrediction(train, :), ...
                innerNull(train), observationMap.ConditionIndex(train));
            objective = mean(innerMSE, 1)';
            innerObjective(:, outerFold, repeat) = objective;
            [best, index] = min(objective);
            if ~isfinite(best)
                error('GaussianChannelCV:InvalidInnerObjective', 'Insufficient finite inner-CV observations.');
            end
            nestedSigma(repeat, outerFold) = sigmaValues(index);
        else
            index = 1;
        end
        [prediction, beta] = fitPredict(designGrid(:, :, index), observed, ...
            observationMap.ConditionIndex, train, test);
        nestedPrediction(test, repeat) = prediction;
        nestedBeta{repeat, outerFold} = beta;
        cueFoldMSE = nan(1, 4);
        for condition = 1:4
            use = test & observationMap.ConditionIndex == condition;
            trainUse = train & observationMap.ConditionIndex == condition;
            cueFoldMSE(condition) = mean((observed(use) - nestedPrediction(use, repeat)).^2);
            foldMSE(repeat, outerFold, condition + 1) = cueFoldMSE(condition);
            foldSizeRatio(repeat, outerFold, condition + 1) = nnz(use) ./ nnz(trainUse);
        end
        foldMSE(repeat, outerFold, 1) = mean(cueFoldMSE);
        foldSizeRatio(repeat, outerFold, 1) = nnz(test) ./ nnz(train);
        if options.Verbose && options.TuneSigma && numRepeats <= 10
            fprintf('  Nested CV repeat %d/%d fold %d/%d: sigma %.5g\n', ...
                repeat, numRepeats, outerFold, numFolds, sigmaValues(index));
        end
    end
    if options.Verbose && numRepeats > 10 && ...
            (repeat == 1 || mod(repeat, 10) == 0 || repeat == numRepeats)
        fprintf('  Outer CV: completed repeat %d/%d (%d/%d folds).\n', ...
            repeat, numRepeats, repeat * numFolds, numRepeats * numFolds);
    end
end
nestedMSE = nan(numRepeats, 4);
nestedR2 = nan(numRepeats, 4);
nestedPooledR2 = nan(numRepeats, 1);
for repeat = 1:numRepeats
    [mse, r2, pooled] = metrics(observed, nestedPrediction(:, repeat), ...
        nullPredictions(:, repeat), observationMap.ConditionIndex);
    nestedMSE(repeat, :) = mse';
    nestedR2(repeat, :) = r2';
    nestedPooledR2(repeat) = pooled;
end
result.Nested.PredictionByRepeat = nestedPrediction;
result.Nested.MeanPrediction = mean(nestedPrediction, 2);
result.Nested.SelectedSigma = nestedSigma;
result.Nested.BetaByOuterFold = nestedBeta;
result.Nested.InnerFoldAssignments = innerAssignments;
result.Nested.InnerObjectiveBySigma = innerObjective;
result.Nested.FoldMSE = foldMSE;
result.Nested.FoldTestTrainRatio = foldSizeRatio;
result.Nested.PerCueMSEByRepeat = nestedMSE;
result.Nested.PerCueR2ByRepeat = nestedR2;
result.Nested.PooledR2ByRepeat = nestedPooledR2;
result.Nested.PerCueMeanMSE = mean(nestedMSE, 1)';
result.Nested.PerCueMeanR2 = mean(nestedR2, 1)';
result.Nested.MeanMSE = mean(nestedMSE, 'all');
result.Nested.MeanPooledR2 = mean(nestedPooledR2);
end

function [predicted, nullPrediction] = cvPredictions(design, y, map, folds, includedSessions)
predicted = nan(numel(y), size(design, 3));
nullPrediction = nan(numel(y), 1);
included = includedSessions(map.SessionIndex);
rowFold = folds(map.SessionIndex);
for fold = reshape(unique(folds(includedSessions)), 1, [])
    train = included & rowFold ~= fold;
    test = included & rowFold == fold;
    predicted(test, :) = fitPredict(design, y, map.ConditionIndex, train, test);
    for condition = 1:4
        nullPrediction(test & map.ConditionIndex == condition) = ...
            mean(y(train & map.ConditionIndex == condition));
    end
end
end

function [predicted, allBeta] = fitPredict(design, y, conditionIndex, train, test)
numTerms = size(design, 2) / 4;
numSigmas = size(design, 3);
predicted = nan(nnz(test), numSigmas);
allBeta = nan(4 .* numTerms, numSigmas);
testConditions = conditionIndex(test);
for condition = 1:4
    columns = (condition - 1) .* numTerms + (1:numTerms);
    trainRows = train & conditionIndex == condition;
    testRows = test & conditionIndex == condition;
    if nnz(trainRows) < numTerms + 1
        error('GaussianChannelCV:InsufficientTraining', 'A training fold has too few observations for condition %d.', condition);
    end
    x = design(trainRows, columns, :);
    % Batched SVD evaluates all sigma values without normal-equation
    % conditioning problems. Zero singular values use a minimum-norm fit.
    [u, s, v] = pagesvd(x, 'econ');
    singularValues = zeros(numTerms, 1, numSigmas);
    for term = 1:numTerms
        singularValues(term, 1, :) = s(term, term, :);
    end
    tolerance = max(size(x, 1), numTerms) .* eps(max(singularValues, [], 1));
    projected = pagemtimes(u, 'transpose', y(trainRows), 'none');
    scaled = projected ./ singularValues;
    scaled(singularValues <= tolerance) = 0;
    beta = pagemtimes(v, scaled);
    allBeta(columns, :) = reshape(beta, numTerms, numSigmas);
    values = pagemtimes(design(testRows, columns, :), beta);
    predicted(testConditions == condition, :) = reshape(values, nnz(testRows), numSigmas);
end
end

function [mse, r2, pooledR2] = metrics(y, predicted, nullPrediction, conditionIndex)
numSigmas = size(predicted, 2);
mse = nan(4, numSigmas);
r2 = nan(4, numSigmas);
for condition = 1:4
    use = conditionIndex == condition;
    if ~any(use) || any(~isfinite(predicted(use, :)), 'all')
        continue
    end
    sse = sum((y(use) - predicted(use, :)).^2, 1);
    mse(condition, :) = sse ./ nnz(use);
    nullSSE = sum((y(use) - nullPrediction(use)).^2);
    if isfinite(nullSSE) && nullSSE > 0
        r2(condition, :) = 1 - sse ./ nullSSE;
    end
end
pooledNullSSE = sum((y - nullPrediction).^2);
pooledR2 = 1 - sum((y - predicted).^2, 1) ./ pooledNullSSE;
end

function folds = balancedFolds(numSessions, numFolds, seed)
stream = RandStream('mt19937ar', 'Seed', seed);
order = randperm(stream, numSessions);
folds = zeros(numSessions, 1);
folds(order) = mod(0:numSessions - 1, numFolds) + 1;
end

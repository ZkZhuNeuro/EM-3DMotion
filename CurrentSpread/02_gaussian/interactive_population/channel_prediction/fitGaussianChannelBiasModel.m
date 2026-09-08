function result = fitGaussianChannelBiasModel( ...
    channelAI, channelSignedOD, channelEligible, relativePositions, ...
    behavior, behaviorValid, behaviorSignedOD, sigmaValues, options)
%FITGAUSSIANCHANNELBIASMODEL Fit beta on channels and optimize sigma by CV.
%
% For each sigma, this function profiles the 12 beta coefficients (three
% coefficients for each local cue condition) by least squares. Predictions
% are formed on individual channels first and then Gaussian-averaged within
% session. Sigma minimizes the equally weighted mean of the four cue-wise
% held-out mean squared prediction errors. Folds are grouped by session.

arguments
    channelAI {mustBeNumeric, mustBeReal}
    channelSignedOD {mustBeNumeric, mustBeReal}
    channelEligible {mustBeNumericOrLogical}
    relativePositions {mustBeNumeric, mustBeReal}
    behavior {mustBeNumeric, mustBeReal}
    behaviorValid {mustBeNumericOrLogical}
    behaviorSignedOD {mustBeNumeric, mustBeReal}
    sigmaValues {mustBeNumeric, mustBeReal}
    options.NumRepeats (1, 1) double ...
        {mustBeInteger, mustBePositive} = 5
    options.NumFolds (1, 1) double ...
        {mustBeInteger, mustBeGreaterThan(options.NumFolds, 1)} = 5
    options.RandomSeed (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 1
end

sigmaValues = sort(unique(double(sigmaValues(:))));
if isempty(sigmaValues) || any(~isfinite(sigmaValues)) || ...
        any(sigmaValues <= 0)
    error('GaussianChannelPrediction:SigmaValues', ...
        'sigmaValues must contain finite positive values.');
end

numSessions = size(channelAI, 1);
numSigmas = numel(sigmaValues);
numRepeats = options.NumRepeats;
numFolds = min(options.NumFolds, numSessions);
if numFolds < 2
    error('GaussianChannelPrediction:TooFewSessions', ...
        'At least two sessions are required for cross-validation.');
end

foldAssignments = zeros(numSessions, numRepeats);
for repeatIndex = 1:numRepeats
    foldAssignments(:, repeatIndex) = balancedFolds( ...
        numSessions, numFolds, options.RandomSeed + repeatIndex - 1);
end

fullBeta = nan(12, numSigmas);
fullRank = nan(numSigmas, 1);
[referenceDesign, referenceObserved, referenceMap, referenceWeights] = ...
    buildGaussianChannelPredictionDesign( ...
    channelAI, channelSignedOD, channelEligible, relativePositions, ...
    behavior, behaviorValid, behaviorSignedOD, sigmaValues(1));
numObservations = numel(referenceObserved);
fullPrediction = nan(numObservations, numSigmas, 'single');
heldOutPrediction = nan(numObservations, numSigmas, 'single');
heldOutPredictionCount = zeros(numObservations, numSigmas, 'uint8');
fullMSE = nan(numSigmas, 1);
fullR2 = nan(numSigmas, 1);
perCueFullMSE = nan(4, numSigmas);
perCueFullR2 = nan(4, numSigmas);
cvMSEByRepeat = nan(numRepeats, numSigmas);
cvR2ByRepeat = nan(numRepeats, numSigmas);
perCueCVMSEByRepeat = nan(numRepeats, 4, numSigmas);
perCueCVR2ByRepeat = nan(numRepeats, 4, numSigmas);
betaByFold = nan(12, numFolds, numRepeats, numSigmas, 'single');
effectiveChannels = nan(numSessions, numSigmas, 'single');

for sigmaIndex = 1:numSigmas
    if sigmaIndex == 1
        design = referenceDesign;
        observed = referenceObserved;
        observationMap = referenceMap;
        channelWeights = referenceWeights;
    else
        [design, observed, observationMap, channelWeights] = ...
            buildGaussianChannelPredictionDesign( ...
            channelAI, channelSignedOD, channelEligible, ...
            relativePositions, behavior, behaviorValid, behaviorSignedOD, ...
            sigmaValues(sigmaIndex));
    end
    if ~isequal(observationMap, referenceMap) || ...
            ~isequaln(observed, referenceObserved)
        error('GaussianChannelPrediction:SigmaDependentObservations', ...
            'The valid behavioral observations changed across sigma.');
    end
    if isempty(observed)
        continue
    end

    beta = solveLeastSquares(design, observed);
    fullBeta(:, sigmaIndex) = beta;
    fullRank(sigmaIndex) = rank(design);
    prediction = design * beta;
    fullPrediction(:, sigmaIndex) = single(prediction);
    [fullMSE(sigmaIndex), fullR2(sigmaIndex)] = ...
        predictionMetrics(observed, prediction);
    for cue = 1:4
        cueRows = observationMap.ConditionIndex == cue;
        [perCueFullMSE(cue, sigmaIndex), ...
            perCueFullR2(cue, sigmaIndex)] = ...
            predictionMetrics(observed(cueRows), prediction(cueRows));
    end

    effectiveChannels(:, sigmaIndex) = single( ...
        effectiveChannelCount(channelWeights));
    predictionSum = zeros(numel(observed), 1);
    predictionCount = zeros(numel(observed), 1);
    for repeatIndex = 1:numRepeats
        repeatPrediction = nan(numel(observed), 1);
        repeatNull = nan(numel(observed), 1);
        sessionFolds = foldAssignments(:, repeatIndex);
        observationFolds = sessionFolds(observationMap.SessionIndex);
        for fold = 1:numFolds
            test = observationFolds == fold;
            train = ~test;
            foldBeta = solveLeastSquares(design(train, :), observed(train));
            betaByFold(:, fold, repeatIndex, sigmaIndex) = ...
                single(foldBeta);
            repeatPrediction(test) = design(test, :) * foldBeta;
            for cue = 1:4
                cueTrain = train & observationMap.ConditionIndex == cue;
                cueTest = test & observationMap.ConditionIndex == cue;
                if any(cueTrain)
                    repeatNull(cueTest) = mean(observed(cueTrain));
                end
            end
        end

        finitePrediction = isfinite(repeatPrediction);
        predictionSum(finitePrediction) = ...
            predictionSum(finitePrediction) + ...
            repeatPrediction(finitePrediction);
        predictionCount(finitePrediction) = ...
            predictionCount(finitePrediction) + 1;
        cueMSE = nan(4, 1);
        cueR2 = nan(4, 1);
        for cue = 1:4
            cueRows = observationMap.ConditionIndex == cue;
            [cueMSE(cue), cueR2(cue)] = predictionMetrics( ...
                observed(cueRows), repeatPrediction(cueRows), ...
                repeatNull(cueRows));
        end
        perCueCVMSEByRepeat(repeatIndex, :, sigmaIndex) = cueMSE;
        perCueCVR2ByRepeat(repeatIndex, :, sigmaIndex) = cueR2;
        if all(isfinite(cueMSE))
            cvMSEByRepeat(repeatIndex, sigmaIndex) = mean(cueMSE);
        end
        [~, cvR2ByRepeat(repeatIndex, sigmaIndex)] = ...
            predictionMetrics(observed, repeatPrediction, repeatNull);
    end
    validAverage = predictionCount > 0;
    heldOutPrediction(validAverage, sigmaIndex) = single( ...
        predictionSum(validAverage) ./ predictionCount(validAverage));
    heldOutPredictionCount(:, sigmaIndex) = uint8(predictionCount);
end

meanCVMSE = mean(cvMSEByRepeat, 1, 'omitnan')';
semCVMSE = finiteSEM(cvMSEByRepeat, 1)';
meanCVR2 = mean(cvR2ByRepeat, 1, 'omitnan')';
semCVR2 = finiteSEM(cvR2ByRepeat, 1)';
perCueMeanCVMSE = reshape(mean(perCueCVMSEByRepeat, 1, 'omitnan'), ...
    4, numSigmas);
perCueMeanCVR2 = reshape(mean(perCueCVR2ByRepeat, 1, 'omitnan'), ...
    4, numSigmas);
finiteObjective = isfinite(meanCVMSE);
if ~any(finiteObjective)
    error('GaussianChannelPrediction:NoFiniteObjective', ...
        'No sigma produced a finite four-cue cross-validated MSE.');
end
validIndices = find(finiteObjective);
[bestCVMSE, relativeBest] = min(meanCVMSE(finiteObjective));
bestIndex = validIndices(relativeBest);

result = struct();
result.SchemaVersion = 2;
result.PredictorMode = "CueAIOD";
result.CueFrame = "ChannelLocalDomNonDom";
result.BehaviorReference = "StimChannelSignedOD";
result.SessionSignedOD = double(behaviorSignedOD(:));
result.ModelDescription = [ ...
    "Predict bias on each significant channel before spatial aggregation"; ...
    "Local OD independently reorders each channel into Dominant/NonDominant before summing predictions"; ...
    "Observed Dominant/NonDominant behavior uses fixed stimulation-channel OD"; ...
    "Channel model: bias = beta0 + betaAI*AI + betaAIxOD*AI*abs(OD)"; ...
    "Gaussian weights are normalized over eligible channels within session"; ...
    "Sigma minimizes equal-cue repeated-CV mean squared prediction error"];
result.ConditionNames = ["Dominant", "Combined", "Stereo", ...
    "NonDominant"];
result.MetricConditionNames = result.ConditionNames;
result.BetaTermNames = ["Intercept", "AI", "AIxOD"];
result.SigmaValues = sigmaValues;
result.NumRepeats = numRepeats;
result.NumFolds = numFolds;
result.RandomSeed = options.RandomSeed;
result.FoldAssignments = foldAssignments;
result.ObservationMap = referenceMap;
result.Observed = referenceObserved;
result.FullBeta = fullBeta;
result.FullDesignRank = fullRank;
result.FullPrediction = fullPrediction;
result.HeldOutPrediction = heldOutPrediction;
result.HeldOutPredictionCount = heldOutPredictionCount;
result.FullMSE = fullMSE;
result.FullR2 = fullR2;
result.PerCueFullMSE = perCueFullMSE;
result.PerCueFullR2 = perCueFullR2;
result.CVMSEByRepeat = cvMSEByRepeat;
result.CVR2ByRepeat = cvR2ByRepeat;
result.PerCueCVMSEByRepeat = perCueCVMSEByRepeat;
result.PerCueCVR2ByRepeat = perCueCVR2ByRepeat;
result.MeanCVMSE = meanCVMSE;
result.SEMCVMSE = semCVMSE;
result.MeanCVR2 = meanCVR2;
result.SEMCVR2 = semCVR2;
result.PerCueMeanCVMSE = perCueMeanCVMSE;
result.PerCueMeanCVR2 = perCueMeanCVR2;
result.BetaByFold = betaByFold;
result.EffectiveChannels = effectiveChannels;
result.BestIndex = bestIndex;
result.BestSigma = sigmaValues(bestIndex);
result.BestCVMSE = bestCVMSE;
result.BestCVR2 = meanCVR2(bestIndex);
result.BestFullBeta = reshape(fullBeta(:, bestIndex), 3, 4)';
result.BestFullPrediction = double(fullPrediction(:, bestIndex));
result.BestHeldOutPrediction = double( ...
    heldOutPrediction(:, bestIndex));
[~, ~, ~, bestWeights] = buildGaussianChannelPredictionDesign( ...
    channelAI, channelSignedOD, channelEligible, relativePositions, ...
    behavior, behaviorValid, behaviorSignedOD, result.BestSigma);
result.BestChannelWeights = bestWeights;
end


function beta = solveLeastSquares(design, observed)
valid = all(isfinite(design), 2) & isfinite(observed);
if nnz(valid) < 2
    beta = nan(size(design, 2), 1);
    return
end
beta = lsqminnorm(design(valid, :), observed(valid));
end


function [mse, r2] = predictionMetrics(observed, predicted, nullPrediction)
if nargin < 3
    nullPrediction = repmat(mean(observed, 'omitnan'), size(observed));
end
valid = isfinite(observed) & isfinite(predicted);
mse = NaN;
r2 = NaN;
if ~any(valid)
    return
end
residual = observed(valid) - predicted(valid);
mse = mean(residual .^ 2);
nullValid = valid & isfinite(nullPrediction);
if nnz(nullValid) < 2
    return
end
modelSSE = sum((observed(nullValid) - predicted(nullValid)) .^ 2);
nullSSE = sum((observed(nullValid) - nullPrediction(nullValid)) .^ 2);
if nullSSE > eps(max(1, abs(nullSSE)))
    r2 = 1 - modelSSE ./ nullSSE;
end
end


function count = effectiveChannelCount(weights)
count = nan(size(weights, 1), 1);
for row = 1:size(weights, 1)
    if any(weights(row, :) > 0)
        count(row) = 1 ./ sum(weights(row, :) .^ 2);
    end
end
end


function sem = finiteSEM(values, dimension)
count = sum(isfinite(values), dimension);
sem = std(values, 0, dimension, 'omitnan') ./ sqrt(count);
sem(count == 0) = NaN;
end


function folds = balancedFolds(numRows, numFolds, seed)
stream = RandStream('mt19937ar', 'Seed', seed);
order = randperm(stream, numRows);
folds = zeros(numRows, 1);
folds(order) = mod(0:numRows-1, numFolds) + 1;
end

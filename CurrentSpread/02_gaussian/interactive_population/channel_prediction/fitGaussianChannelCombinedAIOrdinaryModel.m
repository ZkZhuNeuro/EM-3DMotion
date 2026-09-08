function result = fitGaussianChannelCombinedAIOrdinaryModel( ...
    channelAI, channelSignedOD, channelEligible, relativePositions, ...
    behavior, behaviorValid, behaviorSignedOD, sigmaValues, options)
%FITGAUSSIANCHANNELCOMBINEDAIORDINARYMODEL Fit cue models from channel predictor.
% For every sigma and behavioral condition c, independently fit
%   predictedBias(s,c) = sum_j w(s,j,sigma)*(beta0(c)+beta1(c)*AI(s,Combined,j)).
% All valid observations in that condition enter its ordinary least-squares
% fit. Sigma maximizes the sum of four centered ordinary R-squared values.
% There is no CV and no OD term in the regression. OD assigns behavior eyes.

arguments
    channelAI {mustBeNumeric, mustBeReal}
    channelSignedOD {mustBeNumeric, mustBeReal}
    channelEligible {mustBeNumericOrLogical}
    relativePositions {mustBeNumeric, mustBeReal}
    behavior {mustBeNumeric, mustBeReal}
    behaviorValid {mustBeNumericOrLogical}
    behaviorSignedOD {mustBeNumeric, mustBeReal}
    sigmaValues {mustBeNumeric, mustBeReal}
    options.PredictorMode (1, 1) string ...
        {mustBeMember(options.PredictorMode, ...
        ["CombinedAI", "DominantAIxOD"])} = "CombinedAI"
end

sigmaValues = sort(unique(double(sigmaValues(:))));
if isempty(sigmaValues) || any(~isfinite(sigmaValues)) || any(sigmaValues <= 0)
    error('GaussianChannelPrediction:SigmaValues', ...
        'sigmaValues must contain finite positive values.');
end
numSigmas = numel(sigmaValues);
numSessions = size(channelAI, 1);
[referenceDesign, observed, observationMap, referenceWeights] = ...
    buildGaussianChannelPredictionDesign( ...
    channelAI, channelSignedOD, channelEligible, relativePositions, ...
    behavior, behaviorValid, behaviorSignedOD, sigmaValues(1), ...
    PredictorMode=options.PredictorMode);
numObservations = numel(observed);
prediction = nan(numObservations, numSigmas);
fullBeta = nan(8, numSigmas);
perCueR2 = nan(4, numSigmas);
perCueMSE = nan(4, numSigmas);
perCueSSE = nan(4, numSigmas);
perCueSST = nan(4, 1);
perCueCount = zeros(4, 1);
perCueRank = zeros(4, numSigmas);
effectiveChannels = nan(numSessions, numSigmas);

for sigmaIndex = 1:numSigmas
    if sigmaIndex == 1
        design = referenceDesign;
        weights = referenceWeights;
    else
        [design, thisObserved, thisMap, weights] = ...
            buildGaussianChannelPredictionDesign( ...
            channelAI, channelSignedOD, channelEligible, relativePositions, ...
            behavior, behaviorValid, behaviorSignedOD, sigmaValues(sigmaIndex), ...
            PredictorMode=options.PredictorMode);
        if ~isequaln(observed, thisObserved) || ~isequal(observationMap, thisMap)
            error('GaussianChannelPrediction:SigmaDependentObservations', ...
                'The valid behavioral observations changed across sigma.');
        end
    end
    sumSquares = sum(weights .^ 2, 2);
    effectiveChannels(sumSquares > 0, sigmaIndex) = ...
        1 ./ sumSquares(sumSquares > 0);

    % Independent fits prevent one condition's targets from affecting any
    % other condition's beta at a fixed sigma.
    for condition = 1:4
        rows = observationMap.ConditionIndex == condition;
        columns = (condition - 1) .* 2 + (1:2);
        x = design(rows, columns);
        y = observed(rows);
        perCueCount(condition) = numel(y);
        perCueRank(condition, sigmaIndex) = rank(x);
        if numel(y) < 2
            continue
        end
        beta = lsqminnorm(x, y);
        yhat = x * beta;
        fullBeta(columns, sigmaIndex) = beta;
        prediction(rows, sigmaIndex) = yhat;
        sse = sum((y - yhat) .^ 2);
        sst = sum((y - mean(y)) .^ 2);
        perCueSSE(condition, sigmaIndex) = sse;
        perCueMSE(condition, sigmaIndex) = sse ./ numel(y);
        perCueSST(condition) = sst;
        if sst > 0
            perCueR2(condition, sigmaIndex) = 1 - sse ./ sst;
        end
    end
end

sumFourCueR2 = sum(perCueR2, 1)';
validObjective = all(isfinite(perCueR2), 1)';
sumFourCueR2(~validObjective) = NaN;
if ~any(validObjective)
    error('GaussianChannelPrediction:NoFiniteObjective', ...
        ['No sigma has four finite ordinary R-squared values. Each cue ' ...
        'needs at least two observations with nonconstant behavioral bias.']);
end
validIndices = find(validObjective);
[bestValue, relativeBest] = max(sumFourCueR2(validObjective));
bestIndex = validIndices(relativeBest);
[~, ~, ~, bestWeights] = buildGaussianChannelPredictionDesign( ...
    channelAI, channelSignedOD, channelEligible, relativePositions, ...
    behavior, behaviorValid, behaviorSignedOD, sigmaValues(bestIndex), ...
    PredictorMode=options.PredictorMode);

result = struct();
result.SchemaVersion = 4;
result.FitMethod = "OrdinaryR2";
result.PredictorMode = options.PredictorMode;
result.CueFrame = options.PredictorMode + "ToDomNonDomBehavior";
result.BehaviorReference = "StimChannelSignedOD";
result.SessionSignedOD = double(behaviorSignedOD(:));
if options.PredictorMode == "DominantAIxOD"
    predictorDescription = "AI_dominant*abs(local channel OD)";
    betaTermName = "DominantAIxOD";
else
    predictorDescription = "AI_combined";
    betaTermName = "CombinedAI";
end
result.ModelDescription = [ ...
    "Every behavioral cue uses each eligible channel's " + predictorDescription; ...
    "Channel prediction = beta0(condition) + beta1(condition)*" + predictorDescription; ...
    "Intercept and slope are independently fitted for each behavioral condition"; ...
    "Channel predictions are averaged using normalized Gaussian distance weights"; ...
    "Observed Dominant/NonDominant behavior uses stimulation-channel OD"; ...
    "Shared sigma maximizes the sum of four ordinary R-squared values; no CV"];
result.ConditionNames = ["Dominant", "Combined", "Stereo", "NonDominant"];
result.MetricConditionNames = result.ConditionNames;
result.BetaTermNames = ["Intercept", betaTermName];
result.SigmaValues = sigmaValues;
result.ObservationMap = observationMap;
result.Observed = observed;
result.FullBeta = fullBeta;
result.FullPrediction = prediction;
result.FullDesignRank = sum(perCueRank, 1)';
result.PerCueDesignRank = perCueRank;
result.PerCueFullR2 = perCueR2;
result.PerCueFullMSE = perCueMSE;
result.PerCueSSE = perCueSSE;
result.PerCueSST = perCueSST;
result.PerCuePointCount = perCueCount;
result.FullMSE = sum(perCueSSE, 1)' ./ sum(perCueCount);
result.SumFourCueOrdinaryR2 = sumFourCueR2;
result.MeanFourCueOrdinaryR2 = sumFourCueR2 ./ 4;
result.EffectiveChannels = effectiveChannels;
result.BestIndex = bestIndex;
result.BestSigma = sigmaValues(bestIndex);
result.BestSumFourCueOrdinaryR2 = bestValue;
result.BestMeanFourCueOrdinaryR2 = bestValue ./ 4;
result.BestPerCueOrdinaryR2 = perCueR2(:, bestIndex);
result.BestFullBeta = reshape(fullBeta(:, bestIndex), 2, 4)';
result.BestFullPrediction = prediction(:, bestIndex);
result.BestChannelWeights = bestWeights;
result.SigmaAtGridBoundary = bestIndex == 1 || bestIndex == numSigmas;
end

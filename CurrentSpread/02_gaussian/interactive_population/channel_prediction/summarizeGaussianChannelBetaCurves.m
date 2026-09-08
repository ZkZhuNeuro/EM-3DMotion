function curves = summarizeGaussianChannelBetaCurves(fit, predictor, eligible, positions)
%SUMMARIZEGAUSSIANCHANNELBETACURVES Extract beta and compare predictor scales.
% Scale-adjusted slope is beta1*SD(X_sigma), where X_sigma is the Gaussian
% pooled predictor across the exact valid neurons for that behavioral cue.
arguments
    fit (1, 1) struct
    predictor double
    eligible {mustBeNumericOrLogical}
    positions double
end
eligible = logical(eligible);
if ~isequal(size(predictor), size(eligible), size(positions)) || ...
        any(sum(eligible, 2) == 0) || any(~isfinite(predictor(eligible))) || ...
        any(~isfinite(positions(eligible))) || ...
        size(fit.FullBeta, 1) ~= 8 || fit.FitMethod ~= "OrdinaryR2"
    error('GaussianBetaCurves:InvalidInputs', 'Expected matched finite channel inputs and an ordinary two-term fit.');
end
sigma = double(fit.SigmaValues(:));
numSigmas = numel(sigma);
intercept = double(fit.FullBeta(1:2:8, :));
slope = double(fit.FullBeta(2:2:8, :));
predictorSD = nan(4, numSigmas);
pooledPredictor = nan(size(predictor, 1), numSigmas);
values = predictor;
values(~eligible) = 0;
for si = 1:numSigmas
    logWeights = -(positions.^2) ./ (2*sigma(si)^2);
    logWeights(~eligible) = -Inf;
    logWeights = logWeights-max(logWeights, [], 2);
    weights = exp(logWeights);
    weights = weights./sum(weights, 2);
    pooledPredictor(:, si) = sum(weights.*values, 2);
    for cue = 1:4
        rows = fit.ObservationMap.ConditionIndex == cue;
        x = pooledPredictor(fit.ObservationMap.SessionIndex(rows), si);
        predictorSD(cue, si) = std(x, 0);
        prediction = intercept(cue, si)+slope(cue, si).*x;
        saved = fit.FullPrediction(rows, si);
        tolerance = 1e-10*max(1, max(abs(saved)));
        if any(abs(prediction-saved) > tolerance)
            error('GaussianBetaCurves:PredictionMismatch', ...
                'Extracted beta and pooled predictor do not reproduce saved predictions.');
        end
    end
end
curves = struct('SigmaValues', sigma, 'Intercept', intercept, 'Slope', slope, ...
    'PredictorSD', predictorSD, 'ScaleAdjustedSlope', slope.*predictorSD, ...
    'PooledPredictor', pooledPredictor, 'PerCueCount', double(fit.PerCuePointCount(:)), ...
    'BestIndex', fit.BestIndex, 'BestSigma', fit.BestSigma, ...
    'PredictorMode', string(fit.PredictorMode));
end

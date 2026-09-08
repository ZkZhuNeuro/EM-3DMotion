function tests = TestGaussianChannelBetaCurves
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
folder = fullfile(fileparts(mfilename('fullpath')), '02_gaussian', ...
    'interactive_population', 'channel_prediction');
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
end

function testExtractedBetaReproducesPredictionsAndCueSpecificScale(testCase)
[fit, predictor, eligible, positions] = problem();
curves = summarizeGaussianChannelBetaCurves(fit, predictor, eligible, positions);
verifyEqual(testCase, curves.Intercept, fit.FullBeta(1:2:8, :));
verifyEqual(testCase, curves.Slope, fit.FullBeta(2:2:8, :));
for cue = 1:4
    rows = fit.ObservationMap.ConditionIndex == cue;
    sessions = fit.ObservationMap.SessionIndex(rows);
    expected = curves.Intercept(cue, :)+curves.Slope(cue, :).*curves.PooledPredictor(sessions, :);
    verifyEqual(testCase, expected, fit.FullPrediction(rows, :), 'AbsTol', 1e-12);
    verifyEqual(testCase, curves.PredictorSD(cue, :), ...
        std(curves.PooledPredictor(sessions, :), 0, 1), 'AbsTol', 1e-12);
    % An intercept makes the mean prediction flat as sigma changes.
    verifyEqual(testCase, mean(expected, 1), repmat(mean(fit.Observed(rows)), 1, 3), 'AbsTol', 1e-12);
end
verifyEqual(testCase, curves.ScaleAdjustedSlope, curves.Slope.*curves.PredictorSD);
end

function testScaleAdjustedSlopeIsInvariantToPositivePredictorRescaling(testCase)
[fit, predictor, eligible, positions, ai, od, behavior, valid, referenceOD] = problem();
base = summarizeGaussianChannelBetaCurves(fit, predictor, eligible, positions);
scaledAI = ai;
scaledAI(:, 1, :) = 3+5*scaledAI(:, 1, :);
changed = fitGaussianChannelCombinedAIOrdinaryModel(scaledAI, od, eligible, positions, ...
    behavior, valid, referenceOD, [0.01 0.8 10], PredictorMode="CombinedAI");
adjusted = summarizeGaussianChannelBetaCurves(changed, 3+5*predictor, eligible, positions);
verifyEqual(testCase, adjusted.Slope, base.Slope/5, 'AbsTol', 1e-12);
verifyEqual(testCase, adjusted.ScaleAdjustedSlope, base.ScaleAdjustedSlope, 'AbsTol', 1e-12);
verifyEqual(testCase, changed.FullPrediction, fit.FullPrediction, 'AbsTol', 1e-12);
end

function testIncorrectCoefficientsAreRejected(testCase)
[fit, predictor, eligible, positions] = problem();
fit.FullBeta(2, 2) = fit.FullBeta(2, 2)+1;
verifyError(testCase, @() summarizeGaussianChannelBetaCurves(fit, predictor, eligible, positions), ...
    'GaussianBetaCurves:PredictionMismatch');
end

function [fit, predictor, eligible, positions, ai, od, behavior, valid, referenceOD] = problem()
stream = RandStream('mt19937ar', 'Seed', 380);
n = 20;
ai = randn(stream, n, 4, 3);
predictor = reshape(ai(:, 1, :), n, 3);
od = 0.2+rand(stream, n, 3);
positions = repmat([-1 0 1], n, 1);
eligible = true(n, 3);
eligible(1, 1) = false;
behavior = predictor(:, 2)*[0.4 0.7 -0.9 1.2]+0.1*randn(stream, n, 4);
valid = true(n, 4);
valid([1 2], 2) = false;
referenceOD = od(:, 2);
fit = fitGaussianChannelCombinedAIOrdinaryModel(ai, od, eligible, positions, ...
    behavior, valid, referenceOD, [0.01 0.8 10], PredictorMode="CombinedAI");
end

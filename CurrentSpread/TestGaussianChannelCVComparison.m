function tests = TestGaussianChannelCVComparison
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
folder = fullfile(fileparts(mfilename('fullpath')), '02_gaussian', ...
    'interactive_population', 'channel_prediction');
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
end

function testRepeatedCVMatchesPreviousImplementation(testCase)
[ai, od, positions, behavior, behaviorOD, grid] = problem();
[design, y, map] = makeDesign(ai, od, positions, behavior, behaviorOD, grid, "CueAIOD");
actual = crossValidateGaussianChannelDesign(design, y, map, grid, ...
    NumRepeats=2, NumFolds=4, RunNested=false, Verbose=false);
expected = fitGaussianChannelBiasModel(ai, od, true(size(od)), positions, ...
    behavior, true(size(behavior)), behaviorOD, grid, NumRepeats=2, NumFolds=4);
verifyEqual(testCase, actual.FoldAssignments, expected.FoldAssignments);
verifyEqual(testCase, actual.PerCueMeanCVMSE, expected.PerCueMeanCVMSE, 'AbsTol', 1e-10);
verifyEqual(testCase, actual.PerCueMeanCVR2, expected.PerCueMeanCVR2, 'AbsTol', 1e-10);
verifyEqual(testCase, actual.BestSigma, expected.BestSigma);
verifyEqual(testCase, actual.MeanHeldOutPredictionBySigma, ...
    double(expected.HeldOutPrediction), 'AbsTol', 2e-7);
end

function testCombinedCVCoefficientsComeOnlyFromTrainingRows(testCase)
[ai, od, positions, behavior, behaviorOD, grid] = problem();
[design, y, map] = makeDesign(ai, od, positions, behavior, behaviorOD, grid, "CombinedAI");
actual = crossValidateGaussianChannelDesign(design, y, map, grid, ...
    NumRepeats=1, NumFolds=4, RunNested=false, Verbose=false);
manual = nan(numel(y), numel(grid));
rowFolds = actual.FoldAssignments(map.SessionIndex, 1);
for sigma = 1:numel(grid)
    for fold = 1:4
        for condition = 1:4
            train = rowFolds ~= fold & map.ConditionIndex == condition;
            test = rowFolds == fold & map.ConditionIndex == condition;
            columns = (condition - 1) .* 2 + (1:2);
            beta = lsqminnorm(design(train, columns, sigma), y(train));
            manual(test, sigma) = design(test, columns, sigma) * beta;
        end
    end
end
verifyEqual(testCase, actual.MeanHeldOutPredictionBySigma, manual, 'AbsTol', 1e-10);
end

function testOuterTestBehaviorCannotChangeItsSigmaOrBeta(testCase)
[ai, od, positions, behavior, behaviorOD, grid] = problem();
[design, y, map] = makeDesign(ai, od, positions, behavior, behaviorOD, grid, "CombinedAI");
first = crossValidateGaussianChannelDesign(design, y, map, grid, ...
    NumRepeats=1, NumFolds=3, NumInnerFolds=3, Verbose=false);
testSessions = first.FoldAssignments(:, 1) == 1;
test = testSessions(map.SessionIndex);
altered = y;
altered(test) = altered(test) + 100;
second = crossValidateGaussianChannelDesign(design, altered, map, grid, ...
    NumRepeats=1, NumFolds=3, NumInnerFolds=3, Verbose=false);
verifyEqual(testCase, first.Nested.SelectedSigma(1, 1), second.Nested.SelectedSigma(1, 1));
verifyEqual(testCase, first.Nested.BetaByOuterFold{1, 1}, ...
    second.Nested.BetaByOuterFold{1, 1}, 'AbsTol', 1e-12);
verifyEqual(testCase, first.Nested.PredictionByRepeat(test, 1), ...
    second.Nested.PredictionByRepeat(test, 1), 'AbsTol', 1e-12);
verifyEqual(testCase, first.Nested.InnerObjectiveBySigma(:, 1, 1), ...
    second.Nested.InnerObjectiveBySigma(:, 1, 1));
verifyEqual(testCase, first.Nested.InnerFoldAssignments(testSessions, 1, 1), ...
    zeros(nnz(testSessions), 1));
verifyTrue(testCase, all(isfinite(first.Nested.PredictionByRepeat), 'all'));
end

function testCorrectedTestDirectionAndVariance(testCase)
old = ones(2, 5, 5);
delta = reshape(linspace(0.02, 0.12, 10), 2, 5);
new = old - repmat(delta, 1, 1, 5);
ratio = 0.25 .* ones(size(old));
actual = compareGaussianChannelCVErrors(old, new, ratio);
expectedSE = sqrt((1/10 + 0.25) .* var(delta(:)));
expectedT = mean(delta(:)) ./ expectedSE;
verifyEqual(testCase, actual.CorrectedSE, repmat(expectedSE, 5, 1), 'AbsTol', 1e-12);
verifyEqual(testCase, actual.T, repmat(expectedT, 5, 1), 'AbsTol', 1e-12);
verifyEqual(testCase, actual.PImprovementOneSided(1), tcdf(expectedT, 9, 'upper'), 'AbsTol', 1e-12);
verifyGreaterThan(testCase, expectedSE, std(delta(:)) ./ sqrt(10));
verifyTrue(testCase, all(actual.PImprovementHolmWithinCues(2:5) >= actual.PImprovementOneSided(2:5)));
reversed = compareGaussianChannelCVErrors(new, old, ratio);
verifyGreaterThan(testCase, reversed.PImprovementOneSided(1), 0.5);
verifyFalse(testCase, any(reversed.SignificantImprovement));
equal = compareGaussianChannelCVErrors(old, old, ratio);
verifyEqual(testCase, equal.PImprovementOneSided, ones(5, 1));
end

function [design, y, map] = makeDesign(ai, od, positions, behavior, behaviorOD, grid, mode)
[x, y, map] = buildGaussianChannelPredictionDesign(ai, od, true(size(od)), ...
    positions, behavior, true(size(behavior)), behaviorOD, grid(1), PredictorMode=mode);
design = zeros(size(x, 1), size(x, 2), numel(grid));
design(:, :, 1) = x;
for sigma = 2:numel(grid)
    x = buildGaussianChannelPredictionDesign(ai, od, true(size(od)), ...
        positions, behavior, true(size(behavior)), behaviorOD, grid(sigma), PredictorMode=mode);
    design(:, :, sigma) = x;
end
end

function [ai, od, positions, behavior, behaviorOD, grid] = problem()
stream = RandStream('mt19937ar', 'Seed', 102);
n = 48;
ai = randn(stream, n, 4, 3);
od = (0.2 + rand(stream, n, 3)) .* sign(randn(stream, n, 3));
positions = repmat([0 1 2], n, 1);
behaviorOD = od(:, 1);
grid = [0.1; 0.8; 3];
weightedAI = reshape(ai(:, 1, :), n, 3) * [0.7; 0.25; 0.05];
behavior = weightedAI .* [0.4 0.9 0.6 0.5] + ...
    0.2 .* randn(stream, n, 4);
end

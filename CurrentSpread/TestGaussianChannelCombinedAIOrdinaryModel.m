function tests = TestGaussianChannelCombinedAIOrdinaryModel
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
folder = fullfile(fileparts(mfilename('fullpath')), '02_gaussian', ...
    'interactive_population', 'channel_prediction');
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
end

function testRecoversSeparateCueBetasAndSigma(testCase)
[ai, od, positions, behavior, referenceOD, beta] = problem();
previousRNG = rng;
result = fitGaussianChannelCombinedAIOrdinaryModel(ai, od, ...
    true(size(od)), positions, behavior, true(size(behavior)), ...
    referenceOD, [0.15 0.8 4]);
verifyEqual(testCase, rng, previousRNG);
verifyEqual(testCase, result.BestSigma, 0.8);
verifyEqual(testCase, result.BestFullBeta, beta, 'AbsTol', 1e-10);
verifyEqual(testCase, result.BestPerCueOrdinaryR2, ones(4, 1), 'AbsTol', 1e-12);
verifyEqual(testCase, result.BestSumFourCueOrdinaryR2, 4, 'AbsTol', 1e-12);
verifyFalse(testCase, isfield(result, 'HeldOutPrediction'));
verifyFalse(testCase, isfield(result, 'FoldAssignments'));
end

function testOnlyCombinedAIAffectsPredictions(testCase)
[ai, od, positions, behavior, referenceOD] = problem();
first = fitGaussianChannelCombinedAIOrdinaryModel(ai, od, true(size(od)), ...
    positions, behavior, true(size(behavior)), referenceOD, [0.15 0.8 4]);
ai(:, 2:4, :) = NaN;
% Local OD magnitude/sign is not a regression feature in this model.
od = -3 .* od;
second = fitGaussianChannelCombinedAIOrdinaryModel(ai, od, true(size(od)), ...
    positions, behavior, true(size(behavior)), referenceOD, [0.15 0.8 4]);
verifyEqual(testCase, second.FullPrediction, first.FullPrediction);
verifyEqual(testCase, second.FullBeta, first.FullBeta);
verifyEqual(testCase, second.SumFourCueOrdinaryR2, first.SumFourCueOrdinaryR2);
end

function testCueFitsIndependentAndOrdinaryR2UsesCenteredSST(testCase)
[ai, od, positions, behavior, referenceOD] = problem();
behavior = behavior + 0.1 .* sin(reshape(1:numel(behavior), size(behavior)));
valid = true(size(behavior));
valid(1:4, 1) = false;
first = fitGaussianChannelCombinedAIOrdinaryModel(ai, od, true(size(od)), ...
    positions, behavior, valid, referenceOD, [0.15 0.8 4]);
behavior(:, 1) = 2.3 .* behavior(:, 1) + 0.7;
second = fitGaussianChannelCombinedAIOrdinaryModel(ai, od, true(size(od)), ...
    positions, behavior, valid, referenceOD, [0.15 0.8 4]);
% Combined behavior is condition 2 (beta rows 3:4); other beta blocks stay fixed.
verifyEqual(testCase, second.FullBeta([1 2 5 6 7 8], :), ...
    first.FullBeta([1 2 5 6 7 8], :), 'AbsTol', 1e-12);
verifyEqual(testCase, second.FullBeta(3, :), ...
    2.3 .* first.FullBeta(3, :) + 0.7, 'AbsTol', 1e-12);
verifyEqual(testCase, second.FullBeta(4, :), ...
    2.3 .* first.FullBeta(4, :), 'AbsTol', 1e-12);
for sigmaIndex = 1:3
    for condition = 1:4
        use = first.ObservationMap.ConditionIndex == condition;
        y = first.Observed(use);
        yhat = first.FullPrediction(use, sigmaIndex);
        expected = 1 - sum((y - yhat).^2) ./ sum((y - mean(y)).^2);
        verifyEqual(testCase, first.PerCueFullR2(condition, sigmaIndex), ...
            expected, 'AbsTol', 1e-12);
    end
end
verifyEqual(testCase, first.SumFourCueOrdinaryR2, ...
    sum(first.PerCueFullR2, 1)', 'AbsTol', 1e-12);
[~, expectedBest] = max(sum(first.PerCueFullR2, 1));
verifyEqual(testCase, first.BestIndex, expectedBest);
end

function testOrdinaryBuilderContributionsAndViewer(testCase)
[ai, od, positions, behavior, referenceOD, beta] = problem();
n = size(ai, 1);
folder = string(tempname);
mkdir(folder);
folderCleanup = onCleanup(@() rmdir(folder, 's'));
cache = struct('SchemaVersion', 5, 'OutputFolder', folder, ...
    'Area', "MT", 'ODDefinition', "Max", 'TuningAlpha', 0.05, ...
    'SigmaValues', [0.15 0.8 4], 'SourceRows', (1:n)', ...
    'Monkey', repmat("Jim", n, 1), 'Date', repmat(datetime(2026, 1, 1), n, 1), ...
    'SessionStatus', repmat("Success", n, 1), ...
    'StimZ3DMinusZ2D', -ones(n, 1), 'StimReferenceOD', referenceOD, ...
    'BehaviorByPhysicalCue', behavior, 'BehaviorValidByPhysicalCue', true(n, 4), ...
    'ChannelNumbers', repmat(1:3, n, 1), 'ChannelRelativePositions', positions, ...
    'ChannelAI', ai, 'ChannelSignedOD', od, ...
    'ChannelAvailable', true(n, 3), 'ChannelTuningP', 0.01 .* ones(n, 4, 3), ...
    'StimChannel', ones(n, 1), 'StimChannelSourceP', 0.01 .* ones(n, 4), ...
    'ChannelEligibleForPrediction', false(n, 3));
% The previous all-cue validity gate must not remove valid Combined predictors.
cache.ChannelAI(:, 2:4, :) = NaN;
% A significant neighbor must not rescue a source-nonsignificant neuron.
cache.StimChannelSourceP(1, 2) = 0.2;
cache.StimChannelSourceP(2, 3) = 0.05;
cacheFile = fullfile(folder, 'cache.mat');
save(cacheFile, 'cache');
result = BuildGaussianChannelBiasPredictionObjective( ...
    CacheFile=cacheFile, PredictorMode="CombinedAI");
verifyEqual(testCase, result.FitMethod, "OrdinaryR2");
verifyEqual(testCase, result.BestFullBeta, beta, 'AbsTol', 1e-10);
verifyEqual(testCase, result.SourceRows, (3:n)');
verifyEqual(testCase, result.SessionCount, n - 2);
verifyTrue(testCase, all(result.PointTable.SourceMonoLP < 0.05 & ...
    result.PointTable.SourceMonoRP < 0.05));
verifyEqual(testCase, height(result.BetaTable), 8);
verifyFalse(testCase, ismember('HeldOutPrediction', result.PointTable.Properties.VariableNames));
verifyTrue(testCase, ismember('OrdinaryR2_Dominant', result.SigmaTable.Properties.VariableNames));
verifyTrue(testCase, endsWith(result.OutputFolder, ...
    'ChannelFirstBiasPrediction_CombinedAI_OrdinaryR2_SourceStimBothEyes'));
weights = result.WeightTable;
for condition = 1:4
    name = result.ConditionNames(condition);
    verifyEqual(testCase, weights.("ChannelSourceCue_" + name), ones(height(weights), 1));
    aiCombined = reshape(ai(:, 1, :), n, 3);
    indices = sub2ind(size(aiCombined), weights.SourceTableRow, weights.Channel);
    expected = beta(condition, 1) + beta(condition, 2) .* aiCombined(indices);
    verifyEqual(testCase, weights.("ChannelPrediction_" + name), expected, 'AbsTol', 1e-10);
    contribution = weights.("WeightedContribution_" + name);
    for session = 1:result.SessionCount
        point = result.PointTable.SessionIndex == session & ...
            result.PointTable.ConditionIndex == condition;
        verifyEqual(testCase, sum(contribution(weights.SessionIndex == session)), ...
            result.PointTable.FullPrediction(point), 'AbsTol', 1e-10);
    end
end
viewer = ExploreGaussianChannelBiasPrediction(ObjectiveFile=fullfile(result.OutputFolder, ...
    'GaussianChannelBiasPredictionOptimization.mat'), Visible="off");
figureCleanup = onCleanup(@() delete(viewer.Figure));
verifyTrue(testCase, contains(string(viewer.PopulationAxes.XLabel.String), 'ordinary fit'));
verifyFalse(testCase, contains(string(viewer.PopulationAxes.XLabel.String), 'Held-out'));
viewer.SetSigma(4);
use = result.PointTable.ConditionIndex == 1;
verifyEqual(testCase, viewer.ScatterHandles(1, 1).XData(:), result.FullPrediction(use, 3));
end


function testDominantAIxODUsesLocalDominantEyeAndMagnitude(testCase)
channelAI = zeros(2, 4, 2);
channelAI(1, :, 1) = [10 2 30 40];
channelAI(1, :, 2) = [50 60 7 80];
channelAI(2, :, :) = channelAI(1, :, :);
signedOD = [0.5 -0.25; -0.5 0.25];
behaviorOD = [0.5; -0.5];
behavior = zeros(2, 4);
[design, ~, map] = buildGaussianChannelPredictionDesign( ...
    channelAI, signedOD, true(2), [0 0], behavior, true(2, 4), ...
    behaviorOD, 1, PredictorMode="DominantAIxOD");
for condition = 1:4
    rows = map.ConditionIndex == condition;
    columns = (condition - 1) .* 2 + (1:2);
    % Session 1: mean([MonoL(ch1)*.5, MonoR(ch2)*.25]) = 1.375.
    % Session 2 swaps each channel's dominant physical eye.
    verifyEqual(testCase, design(rows, columns), ...
        [1 1.375; 1 15], 'AbsTol', 1e-12);
end
% Combined and non-dominant-eye AI entries do not enter this predictor.
changed = channelAI;
changed(:, [1 4], :) = 1e6;
changed(1, 3, 1) = 1e6;
changed(1, 2, 2) = 1e6;
same = buildGaussianChannelPredictionDesign(changed, signedOD, true(2), ...
    [0 0], behavior, true(2, 4), behaviorOD, 1, ...
    PredictorMode="DominantAIxOD");
verifyEqual(testCase, same, design);
end

function [ai, od, positions, behavior, referenceOD, beta] = problem()
stream = RandStream('mt19937ar', 'Seed', 24);
n = 48;
ai = randn(stream, n, 4, 3);
od = (0.2 + rand(stream, n, 3)) .* sign(randn(stream, n, 3));
referenceOD = od(:, 1);
positions = repmat([0 1 2], n, 1);
beta = [0.2 0.9; -0.1 0.4; 0.3 -0.6; -0.4 0.7];
behavior = nan(n, 4);
weights = exp(-[0 1 2].^2 ./ (2 .* 0.8^2));
weights = weights ./ sum(weights);
for session = 1:n
    if referenceOD(session) > 0
        order = [2 1 4 3];
    else
        order = [3 1 4 2];
    end
    for condition = 1:4
        % Generate targets explicitly from individual channel predictions.
        contributions = beta(condition, 1) + beta(condition, 2) .* ...
            reshape(ai(session, 1, :), 1, 3);
        behavior(session, order(condition)) = sum(weights .* contributions);
    end
end
end

function tests = TestGaussianCombinedAIStimChannelCVComparison
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
folder = fullfile(fileparts(mfilename('fullpath')), '02_gaussian', ...
    'interactive_population', 'channel_prediction');
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
end

function testBaselineUsesActualMappedStimulationChannel(testCase)
cache = problem();
data = buildCombinedAIStimComparisonDesign(cache, PredictorMode="CombinedAI");
verifyEqual(testCase, data.StimChannelMask, repmat([false true false], data.SessionCount, 1));
verifyEqual(testCase, data.StimPredictor, reshape(cache.ChannelAI(:, 1, 2), [], 1));
for condition = 1:4
    use = data.ObservationMap.ConditionIndex == condition;
    columns = (condition - 1) .* 2 + (1:2);
    expected = [ones(nnz(use), 1), cache.ChannelAI(data.ObservationMap.SessionIndex(use), 1, 2)];
    verifyEqual(testCase, data.StimDesign(use, columns), expected);
end
% Neighbors cannot contribute to the baseline even when their responses
% become very large or change sign.
cache.ChannelAI(:, 1, [1 3]) = 500 .* cache.ChannelAI(:, 1, [1 3]);
altered = buildCombinedAIStimComparisonDesign(cache, PredictorMode="CombinedAI");
verifyEqual(testCase, altered.StimDesign, data.StimDesign);
verifyGreaterThan(testCase, max(abs(altered.GaussianDesign-data.GaussianDesign), [], 'all'), 1);
end


function testDominantAIxODBaselineUsesLocalEyeAndODMagnitude(testCase)
cache = problem();
data = buildCombinedAIStimComparisonDesign(cache, ...
    PredictorMode="DominantAIxOD");
left = reshape(cache.ChannelAI(:, 2, 2), [], 1);
right = reshape(cache.ChannelAI(:, 3, 2), [], 1);
od = cache.ChannelSignedOD(:, 2);
expected = nan(size(od));
expected(od > 0) = left(od > 0) .* abs(od(od > 0));
expected(od < 0) = right(od < 0) .* abs(od(od < 0));
verifyEqual(testCase, data.StimPredictor, expected);
for condition = 1:4
    use = data.ObservationMap.ConditionIndex == condition;
    columns = (condition - 1) .* 2 + (1:2);
    verifyEqual(testCase, data.StimDesign(use, columns), ...
        [ones(nnz(use), 1), expected(data.ObservationMap.SessionIndex(use))]);
end
% Combined, stereo, and locally non-dominant AI never enter the predictor.
changed = cache;
changed.ChannelAI(:, [1 4], :) = 1e6;
for session = 1:size(od, 1)
    if od(session) > 0
        changed.ChannelAI(session, 3, 2) = 1e6;
    else
        changed.ChannelAI(session, 2, 2) = 1e6;
    end
end
same = buildCombinedAIStimComparisonDesign(changed, ...
    PredictorMode="DominantAIxOD");
verifyEqual(testCase, same.StimDesign, data.StimDesign);
end

function testInvalidStimChannelsAreExcludedFromBothModels(testCase)
cache = problem();
cache.ChannelTuningP(1, 2, 2) = 0.2;
cache.StimChannelSourceP(1, 2) = 0.2;
cache.ChannelAvailable(2, 2) = false;
cache.ChannelAI(3, 1, 2) = NaN;
% Unused non-Combined AI should not remove valid Combined-AI channels.
cache.ChannelAI(:, 2:4, :) = NaN;
data = buildCombinedAIStimComparisonDesign(cache, PredictorMode="CombinedAI");
verifyEqual(testCase, data.SourceRows, (4:48)');
verifyTrue(testCase, all(data.SessionAudit.HasEligibleGaussianChannel(1:3)));
verifyFalse(testCase, any(data.SessionAudit.Included(1:3)));
verifyEqual(testCase, data.SessionCount, 45);
verifyEqual(testCase, size(data.StimDesign, 1), size(data.GaussianDesign, 1));
end

function testFixedBaselineCVMatchesManualPerCueRegression(testCase)
data = buildCombinedAIStimComparisonDesign(problem(), PredictorMode="CombinedAI");
result = crossValidateGaussianChannelDesign(data.StimDesign, data.Observed, ...
    data.ObservationMap, 1, NumRepeats=1, NumFolds=3, NumInnerFolds=3, ...
    TuneSigma=false, Verbose=false);
verifyTrue(testCase, isnan(result.BestSigma));
verifyTrue(testCase, all(isnan(result.Nested.SelectedSigma), 'all'));
verifyEqual(testCase, result.Nested.InnerFoldAssignments, zeros(48, 3));
verifyEqual(testCase, result.BestPredictionByRepeat, result.Nested.PredictionByRepeat);
map = data.ObservationMap;
folds = result.FoldAssignments(map.SessionIndex, 1);
manual = nan(size(data.Observed));
for fold = 1:3
    for condition = 1:4
        train = folds ~= fold & map.ConditionIndex == condition;
        test = folds == fold & map.ConditionIndex == condition;
    xTrain = [ones(nnz(train), 1), data.StimPredictor(map.SessionIndex(train))];
    xTest = [ones(nnz(test), 1), data.StimPredictor(map.SessionIndex(test))];
        beta = xTrain \ data.Observed(train);
        manual(test) = xTest * beta;
    end
end
verifyEqual(testCase, result.Nested.PredictionByRepeat, manual, 'AbsTol', 1e-12);
end

function testNoPoolingGainWhenOnlyStimChannelIsAvailable(testCase)
cache = problem();
cache.ChannelAvailable(:, [1 3]) = false;
data = buildCombinedAIStimComparisonDesign(cache, PredictorMode="CombinedAI");
for sigma = 1:numel(data.SigmaValues)
    verifyEqual(testCase, data.GaussianDesign(:, :, sigma), data.StimDesign);
end
stim = crossValidateGaussianChannelDesign(data.StimDesign, data.Observed, ...
    data.ObservationMap, 1, NumRepeats=1, NumFolds=3, NumInnerFolds=3, ...
    TuneSigma=false, Verbose=false);
gaussian = crossValidateGaussianChannelDesign(data.GaussianDesign, data.Observed, ...
    data.ObservationMap, data.SigmaValues, NumRepeats=1, NumFolds=3, ...
    NumInnerFolds=3, Verbose=false);
verifyEqual(testCase, stim.FoldAssignments, gaussian.FoldAssignments);
verifyEqual(testCase, stim.Nested.PredictionByRepeat, gaussian.Nested.PredictionByRepeat, 'AbsTol', 1e-12);
verifyEqual(testCase, stim.Nested.FoldMSE, gaussian.Nested.FoldMSE, 'AbsTol', 1e-12);
end

function testSourceNeuronGateCannotBeReplacedBySignificantNeighbors(testCase)
cache = problem();
cache.StimChannelSourceP(1, 2) = 0.2;
cache.StimChannelSourceP(2, 3) = 0.05;
cache.StimChannelSourceP(3, 2) = NaN;
data = buildCombinedAIStimComparisonDesign(cache, PredictorMode="DominantAIxOD");
verifyEqual(testCase, data.SourceRows, (4:48)');
verifyTrue(testCase, all(data.SessionAudit.HasEligibleGaussianChannel(1:3)));
verifyFalse(testCase, any(data.SessionAudit.Included(1:3)));
verifyTrue(testCase, all(data.SourceTuningP(:, 2:3) < 0.05, 'all'));
end

function testSourceStimPIsAuthoritativeAndNeighborsUseOwnTests(testCase)
cache = problem();
cache.ChannelTuningP(1, 2, 2) = 0.9; % Disagrees with significant source p_AI.
cache.ChannelTuningP(1, 3, 1) = 0.2; % Nonsignificant neighboring channel.
cache.ChannelTuningP(2, 2, 3) = NaN;
selection = selectGaussianChannelPredictionCohort(cache, "2D", "DominantAIxOD");
verifyTrue(testCase, selection.SessionMask(1));
verifyTrue(testCase, selection.StimChannelMask(1, 2));
verifyTrue(testCase, selection.Audit.StimSignificanceDisagrees(1));
verifyEqual(testCase, selection.EffectiveChannelTuningP(1, 2, 2), 0.01);
verifyEqual(testCase, selection.RawChannelTuningP(1, 2, 2), 0.9);
verifyEqual(testCase, selection.ChannelTuningSource(1, 2), "UnitTable_p_AI");
verifyEqual(testCase, selection.ChannelTuningSource(1, 1), "QuickRawDirection");
verifyFalse(testCase, selection.ChannelEligible(1, 1));
verifyFalse(testCase, selection.ChannelEligible(2, 3));
left = reshape(selection.EffectiveChannelTuningP(:, 2, :), 48, 3);
right = reshape(selection.EffectiveChannelTuningP(:, 3, :), 48, 3);
verifyTrue(testCase, all(left(selection.ChannelEligible) < 0.05 & ...
    right(selection.ChannelEligible) < 0.05));
end

function testMissingSourcePDoesNotFallBackToRecomputedStimTests(testCase)
cache = rmfield(problem(), 'StimChannelSourceP');
verifyError(testCase, @() selectGaussianChannelPredictionCohort(cache, "2D", "DominantAIxOD"), ...
    'GaussianCohort:MissingSourceP');
end

function testLegacyCacheReadsSourceTestsAndChecksRowIdentity(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
cache = problem();
sourceP = cache.StimChannelSourceP;
sourceP(1, 2) = 0.2;
unit_table_gof = table(cache.StimChannel, num2cell(sourceP, 2), ...
    'VariableNames', {'StimElec', 'p_AI'});
cache = rmfield(cache, 'StimChannelSourceP');
cache.StateFile = fullfile(fixture.Folder, 'source.mat');
save(cache.StateFile, 'unit_table_gof');
selection = selectGaussianChannelPredictionCohort(cache, "2D", "DominantAIxOD");
verifyEqual(testCase, find(selection.SessionMask), (2:48)');
verifyEqual(testCase, selection.SourceTuningP, sourceP);
verifyEqual(testCase, selection.Audit.RecomputedStimMonoLP(1), 0.01);
unit_table_gof.StimElec(7) = 9;
save(cache.StateFile, 'unit_table_gof');
verifyError(testCase, @() selectGaussianChannelPredictionCohort(cache, "2D", "DominantAIxOD"), ...
    'GaussianCohort:SourceIdentity');
end

function cache = problem()
stream = RandStream('mt19937ar', 'Seed', 217);
n = 48;
ai = randn(stream, n, 4, 3);
od = 0.2 + rand(stream, n, 3);
od(2:2:end, :) = -od(2:2:end, :);
behavior = reshape(ai(:, 1, 2), n, 1) .* [0.4 0.8 -0.6 0.9] + ...
    0.2 .* randn(stream, n, 4);
cache = struct('ChannelAI', ai, 'ChannelSignedOD', od, ...
    'ChannelRelativePositions', repmat([-1 0 1], n, 1), ...
    'ChannelNumbers', repmat([9 5 2], n, 1), 'StimChannel', repmat(5, n, 1), ...
    'ChannelTuningP', 0.01 .* ones(n, 4, 3), 'TuningAlpha', 0.05, ...
    'StimChannelSourceP', 0.01 .* ones(n, 4), ...
    'ChannelAvailable', true(n, 3), 'StimReferenceOD', od(:, 2), ...
    'StimZ3DMinusZ2D', -ones(n, 1), 'BehaviorByPhysicalCue', behavior, ...
    'BehaviorValidByPhysicalCue', true(n, 4), 'SessionStatus', repmat("Success", n, 1), ...
    'SourceRows', (1:n)', 'SigmaValues', [0.01; 0.8; 3]);
end

function testOuterRepeatRobustnessUsesPairedCompleteRepeats(testCase)
data = buildCombinedAIStimComparisonDesign(problem(), PredictorMode="CombinedAI");
args = {'NumRepeats', 3, 'NumFolds', 3, 'NumInnerFolds', 3, 'Verbose', false};
stim = crossValidateGaussianChannelDesign(data.StimDesign, data.Observed, ...
    data.ObservationMap, 1, args{:}, TuneSigma=false);
gaussian = crossValidateGaussianChannelDesign(data.GaussianDesign, data.Observed, ...
    data.ObservationMap, data.SigmaValues, args{:});
robust = summarizeGaussianStimCVRobustness(stim, gaussian);
verifyEqual(testCase, height(robust.RepeatMetrics), 15);
verifyEqual(testCase, robust.Summary.NumOuterRepeats, repmat(3, 5, 1));
overall = robust.RepeatMetrics(robust.RepeatMetrics.Condition == "Equal-cue aggregate", :);
expected = mean(stim.Nested.PerCueMSEByRepeat - gaussian.Nested.PerCueMSEByRepeat, 2);
verifyEqual(testCase, overall.MSEImprovement, expected, 'AbsTol', 1e-12);
verifyEqual(testCase, robust.Summary.RepeatsImproved(1), nnz(expected > 0));
verifyEqual(testCase, robust.Summary.SplitMedian(1), median(expected), 'AbsTol', 1e-12);
verifyEqual(testCase, overall.StimOnlyCVR2, stim.Nested.PooledR2ByRepeat, 'AbsTol', 1e-12);
verifyEqual(testCase, overall.GaussianCVR2, gaussian.Nested.PooledR2ByRepeat, 'AbsTol', 1e-12);
verifyEqual(testCase, robust.SigmaSummary.NumOuterFits, 9);
verifyEqual(testCase, robust.SigmaSummary.MedianSigma, median(gaussian.Nested.SelectedSigma(:)));
end

function testIncreasingRepeatCountPreservesExistingOuterSplits(testCase)
data = buildCombinedAIStimComparisonDesign(problem(), PredictorMode="CombinedAI");
first = crossValidateGaussianChannelDesign(data.GaussianDesign, data.Observed, ...
    data.ObservationMap, data.SigmaValues, NumRepeats=2, NumFolds=3, ...
    NumInnerFolds=3, Verbose=false);
extended = crossValidateGaussianChannelDesign(data.GaussianDesign, data.Observed, ...
    data.ObservationMap, data.SigmaValues, NumRepeats=3, NumFolds=3, ...
    NumInnerFolds=3, Verbose=false);
verifyEqual(testCase, extended.FoldAssignments(:, 1:2), first.FoldAssignments);
verifyEqual(testCase, extended.Nested.InnerFoldAssignments(:, :, 1:2), first.Nested.InnerFoldAssignments);
verifyEqual(testCase, extended.Nested.SelectedSigma(1:2, :), first.Nested.SelectedSigma);
verifyEqual(testCase, extended.Nested.PredictionByRepeat(:, 1:2), first.Nested.PredictionByRepeat);
end

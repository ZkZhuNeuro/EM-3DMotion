function tests = TestWeightedMetaTuningBiasComparison
%TESTWEIGHTEDMETATUNINGBIASCOMPARISON Synthetic meta-tuning/CV tests.
tests = functiontests(localfunctions);
end


function testCenterOnlyFeaturesMatchManualCalculation(testCase)
cache = makeSyntheticCache(12);
features = CalculateThreeChannelMetaFeatures( ...
    cache.SessionStats(1), [0 1 0]);
stats = cache.SessionStats(1);
cue = 3;
values = nan(1, numel(stats.PositiveColumns));
for index = 1:numel(stats.PositiveColumns)
    positive = stats.PositiveColumns(index);
    negative = stats.NegativeColumns(index);
    numerator = stats.ZMean(cue, positive, 2) - ...
        stats.ZMean(cue, negative, 2);
    positiveSD = sqrt(stats.ZCov(cue, positive, 2, 2));
    negativeSD = sqrt(stats.ZCov(cue, negative, 2, 2));
    values(index) = numerator ./ ...
        (abs(numerator) + (positiveSD + negativeSD) ./ 2);
end
verifyEqual(testCase, features.AI(1, cue, 1), mean(values), ...
    'AbsTol', 1e-12)

rawLeft = squeeze(stats.RawMean(2, :, 2));
rawRight = squeeze(stats.RawMean(3, :, 2));
expectedOD = (max(rawLeft) - max(rawRight)) ./ ...
    (max(rawLeft) + max(rawRight));
verifyEqual(testCase, features.SignedOD, expectedOD, 'AbsTol', 1e-12)
end


function testNeighborSignalImprovesHeldOutPrediction(testCase)
cache = makeSyntheticCache(42);
result = FitWeightedMetaTuningBiasModels(cache, ...
    NumRepeats=4, NumFolds=3, RandomSeed=11, WeightStep=0.1, ...
    ModelVariants="AIOnly", Analyses="StereoOnly", ...
    MinimumGroupSize=8);
group = successfulGroup(result, "AIOnly", "StereoOnly", "MT", "2D");
verifyGreaterThan(testCase, group.MeanDeltaMacroCVR2, 0.15)
verifyLessThan(testCase, group.FullExpandedWeights(2), 0.5)
verifyGreaterThan(testCase, ...
    group.FullExpandedWeights(1) + group.FullExpandedWeights(3), 0.5)
verifyTrue(testCase, all(group.CV.WeightSamples >= 0, 'all'))
verifyEqual(testCase, sum(group.CV.WeightSamples, 2), ...
    ones(size(group.CV.WeightSamples, 1), 1), 'AbsTol', 1e-12)
end


function testConditionCueMappingUsesOriginalODAssignment(testCase)
cache = makeSyntheticCache(18);
cache.SessionStats(1).SourceCueByCondition = [2 1 4 3];
cache.SessionStats(2).SourceCueByCondition = [3 1 4 2];
cache.SessionTable.SourceCueByCondition{1} = [2 1 4 3];
cache.SessionTable.SourceCueByCondition{2} = [3 1 4 2];
result = FitWeightedMetaTuningBiasModels(cache, ...
    NumRepeats=1, NumFolds=3, RandomSeed=17, WeightStep=0.1, ...
    ModelVariants="AIOnly", Analyses="StereoOnly", ...
    MinimumGroupSize=8);
raw = result.Features.RawCueAI;
condition = result.Features.ConditionAI;
verifyEqual(testCase, squeeze(condition(1, 1, :)), ...
    squeeze(raw(1, 2, :)), 'AbsTol', 1e-12)
verifyEqual(testCase, squeeze(condition(2, 1, :)), ...
    squeeze(raw(2, 3, :)), 'AbsTol', 1e-12)
verifyEqual(testCase, squeeze(condition(:, 3, :)), ...
    squeeze(raw(:, 4, :)), 'AbsTol', 1e-12)
verifyEqual(testCase, squeeze(condition(1, 4, :)), ...
    squeeze(raw(1, 3, :)), 'AbsTol', 1e-12)
verifyEqual(testCase, squeeze(condition(2, 4, :)), ...
    squeeze(raw(2, 2, :)), 'AbsTol', 1e-12)
end


function testHeldOutBehaviorCannotChangeTrainingWeight(testCase)
cache = makeSyntheticCache(36);
result1 = FitWeightedMetaTuningBiasModels(cache, ...
    NumRepeats=1, NumFolds=3, RandomSeed=23, WeightStep=0.1, ...
    ModelVariants="AIOnly", Analyses="StereoOnly", ...
    MinimumGroupSize=8);
group1 = successfulGroup(result1, "AIOnly", "StereoOnly", "MT", "2D");
heldOutLocal = find(group1.CV.FoldMatrix(:, 1) == 1, 1);
sourceSession = group1.SourceSessionRows(heldOutLocal);
cache.SessionStats(sourceSession).Behavior(3) = ...
    cache.SessionStats(sourceSession).Behavior(3) + 50;
cache.SessionTable.Behavior{sourceSession}(3) = ...
    cache.SessionStats(sourceSession).Behavior(3);

result2 = FitWeightedMetaTuningBiasModels(cache, ...
    NumRepeats=1, NumFolds=3, RandomSeed=23, WeightStep=0.1, ...
    ModelVariants="AIOnly", Analyses="StereoOnly", ...
    MinimumGroupSize=8);
group2 = successfulGroup(result2, "AIOnly", "StereoOnly", "MT", "2D");
verifyEqual(testCase, group1.CV.WeightSamples(1, :), ...
    group2.CV.WeightSamples(1, :), 'AbsTol', 1e-12)
end


function testRadius2FiveChannelWeightsAndNestedBaseline(testCase)
cache = makeSyntheticCache(40, 2);
result = FitWeightedMetaTuningBiasModels(cache, ...
    NumRepeats=3, NumFolds=3, RandomSeed=29, WeightStep=0.2, ...
    ModelVariants="AIOnly", Analyses="StereoOnly", ...
    MinimumGroupSize=8);
group = successfulGroup(result, "AIOnly", "StereoOnly", "MT", "2D");
verifySize(testCase, group.CV.WeightSamples, [9 5])
verifyEqual(testCase, sum(group.CV.WeightSamples, 2), ...
    ones(9, 1), 'AbsTol', 1e-12)
verifyGreaterThan(testCase, group.MeanDeltaMacroCVR2, 0.1)
verifyEqual(testCase, result.BaselineWeights, [0 0 1 0 0])
verifyTrue(testCase, ismember('Weight_CHminus2', ...
    result.FullWeightSummary.Properties.VariableNames))
verifyTrue(testCase, ismember('Weight_CHplus2', ...
    result.FullWeightSummary.Properties.VariableNames))
end


function testOutputWriterCreatesVerifiedBundle(testCase)
cache = makeSyntheticCache(24);
result = FitWeightedMetaTuningBiasModels(cache, ...
    NumRepeats=2, NumFolds=3, RandomSeed=31, WeightStep=0.1, ...
    ModelVariants="AIOnly", Analyses="StereoOnly", ...
    MinimumGroupSize=8);
outputFolder = string(tempname);
mkdir(outputFolder)
cleanup = onCleanup(@() rmdir(outputFolder, 's'));
files = SaveWeightedMetaTuningBiasComparison( ...
    result, outputFolder, FigureVisible=false);
verifyEqual(testCase, numel(files), 14)
verifyTrue(testCase, all(isfile(files)))
clear cleanup
verifyFalse(testCase, isfolder(outputFolder))
end


function group = successfulGroup(result, variant, analysis, area, unitType)
match = arrayfun(@(item) item.ModelVariant == variant && ...
    item.Analysis == analysis && item.Area == area && ...
    item.UnitType == unitType && item.Status == "Success", result.Groups);
group = result.Groups(find(match, 1));
end


function cache = makeSyntheticCache(sessionCount, radius)
if nargin < 2
    radius = 1;
end
stream = RandStream('mt19937ar', 'Seed', 71);
coherence = [-4 -3 -2 -1 1 2 3 4];
positive = 5:8;
negative = 4:-1:1;
relativePositions = -radius:radius;
channelCount = numel(relativePositions);
stats = repmat(emptyStats(), sessionCount, 1);
for session = 1:sessionCount
    channelSignal = randn(stream, 1, channelCount);
    zMean = zeros(4, 8, channelCount);
    zCov = zeros(4, 8, channelCount, channelCount);
    rawMean = zeros(4, 8, channelCount);
    for cue = 1:4
        cueScale = 0.5 + 0.15 * cue;
        for pair = 1:4
            zMean(cue, positive(pair), :) = ...
                cueScale .* channelSignal ./ 2;
            zMean(cue, negative(pair), :) = ...
                -cueScale .* channelSignal ./ 2;
            zCov(cue, positive(pair), :, :) = ...
                0.04 .* eye(channelCount);
            zCov(cue, negative(pair), :, :) = ...
                0.04 .* eye(channelCount);
        end
    end
    odLatent = 0.8 .* randn(stream);
    rawMean(:, :, :) = 4;
    rawMean(2, :, :) = 4 + odLatent;
    rawMean(3, :, :) = 4 - odLatent;

    stats(session).SourceRow = session;
    stats(session).Date = string(datetime(2024, 1, 1) + days(session - 1));
    stats(session).Area = "MT";
    stats(session).UnitType = "2D";
    stats(session).Monkey = "Jim";
    stats(session).StimChannel = radius + 1;
    stats(session).Channels = 1:channelCount;
    stats(session).ChannelCenters = zeros(1, channelCount);
    stats(session).ChannelScales = ones(1, channelCount);
    stats(session).StoredStimAI = nan(4, 1);
    stats(session).OriginalSignedOD = odLatent ./ 4;
    stats(session).Behavior = nan(1, 4);
    stats(session).SourceCueByCondition = [2 1 4 3];
    stats(session).Coherence = coherence;
    stats(session).PositiveColumns = positive;
    stats(session).NegativeColumns = negative;
    stats(session).ZMean = zMean;
    stats(session).ZCov = zCov;
    stats(session).RawMean = rawMean;
    stats(session).Counts = 20 .* ones(4, 8);
    stats(session).CacheFile = "synthetic";
end

hiddenWeights = zeros(1, channelCount);
hiddenWeights([1 end]) = 0.5;
hiddenFeatures = CalculateThreeChannelMetaFeatures(stats, hiddenWeights);
noise = 0.03 .* randn(stream, sessionCount, 1);
for session = 1:sessionCount
    stats(session).Behavior(3) = ...
        hiddenFeatures.AI(session, 4, 1) + noise(session);
end

sourceRow = (1:sessionCount)';
date = string({stats.Date})';
area = string({stats.Area})';
unitType = string({stats.UnitType})';
monkey = string({stats.Monkey})';
stimChannel = [stats.StimChannel]';
channels = {stats.Channels}';
originalOD = [stats.OriginalSignedOD]';
behavior = {stats.Behavior}';
sourceCue = {stats.SourceCueByCondition}';
cacheFile = string({stats.CacheFile})';
sessionTable = table(sourceRow, date, area, unitType, monkey, ...
    stimChannel, channels, originalOD, behavior, sourceCue, cacheFile, ...
    'VariableNames', {'SourceRow', 'Date', 'Area', 'UnitType', 'Monkey', ...
    'StimChannel', 'Channels', 'OriginalSignedOD', 'Behavior', ...
    'SourceCueByCondition', 'CacheFile'});
cache = struct();
cache.SessionStats = stats;
cache.SessionTable = sessionTable;
cache.ConditionNames = ["Dominant", "Combined", "Stereo", "NonDominant"];
cache.RelativePositions = relativePositions;
cache.Audit = table();
end


function stats = emptyStats()
stats = struct('SourceRow', nan, 'Date', "", 'Area', "", ...
    'UnitType', "", 'Monkey', "", 'StimChannel', nan, ...
    'Channels', nan(1, 3), 'ChannelCenters', nan(1, 3), ...
    'ChannelScales', nan(1, 3), 'StoredStimAI', nan(4, 1), ...
    'OriginalSignedOD', nan, 'Behavior', nan(1, 4), ...
    'SourceCueByCondition', nan(1, 4), 'Coherence', nan(1, 0), ...
    'PositiveColumns', nan(1, 0), 'NegativeColumns', nan(1, 0), ...
    'ZMean', nan(4, 0, 3), 'ZCov', nan(4, 0, 3, 3), ...
    'RawMean', nan(4, 0, 3), 'Counts', zeros(4, 0), ...
    'CacheFile', "");
end

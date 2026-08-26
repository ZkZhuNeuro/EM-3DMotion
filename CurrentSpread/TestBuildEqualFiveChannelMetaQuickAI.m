function tests = TestBuildEqualFiveChannelMetaQuickAI
%TESTBUILDEQUALFIVECHANNELMETAQUICKAI Tests the fixed five-contact builder.
tests = functiontests(localfunctions);
end


function testAffineChannelsCollapseToSameMetaAI(testCase)
root = string(tempname);
mkdir(root);
cleanup = onCleanup(@() removeTestFolder(root));

[unitTable, expectedAI] = makeUnitTableAndCache(root, []);
[prepared, eligible, audit] = BuildEqualFiveChannelMetaQuickAI( ...
    unitTable, JimCacheFolder=root, ClayCacheFolder=root, ...
    ChannelMap=1:5);

verifyTrue(testCase, eligible);
verifyEqual(testCase, audit.Status, "Success");
verifyEqual(testCase, audit.FiveChannels{1}, 1:5);
verifyEqual(testCase, audit.MetaAI{1}, expectedAI, 'AbsTol', 1e-12);
verifyEqual(testCase, audit.ReconstructedStimAI{1}, expectedAI, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, prepared.AI{1}(:, 3), expectedAI, ...
    'AbsTol', 1e-12);
verifyTrue(testCase, all(audit.ChannelZScale{1} > 0));
verifyNotEqual(testCase, audit.MetaODMax, 0);
verifyTrue(testCase, isfinite(audit.MetaZ3DMinusZ2D));
verifyEqual(testCase, prepared.OD_max{1}, audit.MetaODMax, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, prepared.Z3D_v_Z2D{1}, ...
    audit.MetaZ3DMinusZ2D, 'AbsTol', 1e-12);

clear cleanup
removeTestFolder(root);
end


function testDeadRequiredChannelIsIneligible(testCase)
root = string(tempname);
mkdir(root);
cleanup = onCleanup(@() removeTestFolder(root));

[unitTable, ~] = makeUnitTableAndCache(root, 2);
[~, eligible, audit] = BuildEqualFiveChannelMetaQuickAI( ...
    unitTable, JimCacheFolder=root, ClayCacheFolder=root, ...
    ChannelMap=1:5);

verifyFalse(testCase, eligible);
verifyEqual(testCase, audit.Status, "Error");
verifyThat(testCase, audit.Message, ...
    matlab.unittest.constraints.ContainsSubstring( ...
    "FiveChannelMeta:DeadChannel"));

clear cleanup
removeTestFolder(root);
end


function testGaussianAllUsesEveryLiveChannelAndRenormalizes(testCase)
root = string(tempname);
mkdir(root);
cleanup = onCleanup(@() removeTestFolder(root));

[unitTable, expectedAI] = makeUnitTableAndCache(root, 2);
[prepared, eligible, audit] = BuildEqualFiveChannelMetaQuickAI( ...
    unitTable, JimCacheFolder=root, ClayCacheFolder=root, ...
    ChannelMap=1:5, WeightingMode="GaussianAll", GaussianSigma=1);

expectedChannels = [1 3 4 5];
expectedPositions = [-2 0 1 2];
expectedWeights = exp(-(expectedPositions .^ 2) ./ 2);
expectedWeights = expectedWeights ./ sum(expectedWeights);
verifyTrue(testCase, eligible);
verifyEqual(testCase, audit.Status, "Success");
verifyEqual(testCase, audit.MetaChannels{1}, expectedChannels);
verifyEqual(testCase, audit.RelativeChannelPositions{1}, expectedPositions);
verifyEqual(testCase, audit.MetaWeights{1}, expectedWeights, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, sum(audit.MetaWeights{1}), 1, 'AbsTol', 1e-12);
verifyEqual(testCase, audit.MetaAI{1}, expectedAI, 'AbsTol', 1e-12);
verifyEqual(testCase, prepared.MetaQuickWeightingMode, "GaussianAll");
verifyEqual(testCase, prepared.MetaQuickGaussianSigma, 1);
verifyEqual(testCase, prepared.AI{1}(:, 3), expectedAI, 'AbsTol', 1e-12);
verifyNotEqual(testCase, audit.MetaODMax, 0);
verifyTrue(testCase, isfinite(audit.MetaZ3DMinusZ2D));

clear cleanup
removeTestFolder(root);
end


function [unitTable, expectedAI] = makeUnitTableAndCache(folder, deadChannel)
coherence = [-4 -3 -2 -1 1 2 3 4];
cueMean = [ ...
    -4 -2 -1 -0.5 0.2 1 2 4; ...
     2  5  1  4.0 3.0 6 2 7; ...
     6  1  4  2.0 5.0 3 8 2; ...
    -1  3 -2  1.0 2.0 0 4 5];
trialNoise = reshape([-0.2 -0.1 0 0.1 0.2], 1, 1, []);
Neuro.All = nan(4, numel(coherence), numel(trialNoise), 5);
for cue = 1:4
    for coherenceIndex = 1:numel(coherence)
        base = cueMean(cue, coherenceIndex) + trialNoise;
        for channel = 1:5
            Neuro.All(cue, coherenceIndex, :, channel) = ...
                channel * 10 + channel .* base;
        end
    end
end
Neuro.Trials.NumTrials = 5 .* ones(4, numel(coherence));
Neuro.CoherenceArray = coherence;
save(fullfile(folder, '20240101.mat'), 'Neuro');

sampleSD = std(reshape(trialNoise, [], 1), 0);
expectedAI = nan(4, 1);
positiveColumns = 5:8;
negativeColumns = [4 3 2 1];
for cue = 1:4
    difference = cueMean(cue, positiveColumns) - ...
        cueMean(cue, negativeColumns);
    expectedAI(cue) = mean(difference ./ ...
        (abs(difference) + sampleSD));
end
AI = {repmat(expectedAI, 1, 5)};
Date = datetime(2024, 1, 1);
Monkey = {'Jim'};
ROI = {'MT'};
StimElec = 3;
NChannels = 5;
DeadChannel = {deadChannel};
OD_max = {0.25};
Z3D_v_Z2D = {-0.5};
unitTable = table(Date, Monkey, ROI, StimElec, NChannels, AI, ...
    DeadChannel, OD_max, Z3D_v_Z2D);
end


function removeTestFolder(folder)
if isfolder(folder)
    rmdir(folder, 's');
end
end

function tests = TestComputeAdjacentQuickTuningDiscontinuity
%TESTCOMPUTEADJACENTQUICKTUNINGDISCONTINUITY Synthetic full-curve tests.
tests = functiontests(localfunctions);
end


function testAffineChannelResponsesHaveZeroTuningChange(testCase)
root = string(tempname);
mkdir(root);
cleanup = onCleanup(@() removeTestFolder(root));
unitTable = makeUnitTableAndCache(root, "Affine", []);

audit = ComputeAdjacentQuickTuningDiscontinuity(unitTable, ...
    JimCacheFolder=root, ClayCacheFolder=root, ChannelMap=1:5, ...
    CandidateMask=true, NumSplits=25, RandomSeed=17);

verifyEqual(testCase, audit.Status, "Success");
verifyEqual(testCase, audit.FiveChannels{1}, 1:5);
verifyEqual(testCase, audit.ConditionCount, 32);
verifyEqual(testCase, audit.ConditionCountByCue{1}, 8 .* ones(1, 4));
verifyEqual(testCase, audit.AdjacentJumpSquared{1}, zeros(1, 4), ...
    'AbsTol', 1e-12);
verifyEqual(testCase, audit.AverageAdjacentJumpSquared, 0, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, audit.MaxAdjacentJumpSquared, 0, ...
    'AbsTol', 1e-12);

clear cleanup
removeTestFolder(root);
end


function testAbruptShapeChangeFindsCorrectPhysicalGap(testCase)
root = string(tempname);
mkdir(root);
cleanup = onCleanup(@() removeTestFolder(root));
unitTable = makeUnitTableAndCache(root, "Step", []);

audit = ComputeAdjacentQuickTuningDiscontinuity(unitTable, ...
    JimCacheFolder=root, ClayCacheFolder=root, ChannelMap=1:5, ...
    CandidateMask=true, NumSplits=50, RandomSeed=23);

edgeJumps = audit.AdjacentJumpSquared{1};
verifyEqual(testCase, audit.Status, "Success");
verifyEqual(testCase, audit.MaxJumpEdge, "0 to +1");
verifyGreaterThan(testCase, edgeJumps(3), 0.05);
verifyEqual(testCase, edgeJumps([1 2 4]), zeros(1, 3), ...
    'AbsTol', 1e-12);
verifyEqual(testCase, audit.AverageAdjacentJumpSquared, ...
    mean(edgeJumps), 'AbsTol', 1e-12);
verifyEqual(testCase, audit.MaxAdjacentJumpSquared, ...
    max(edgeJumps), 'AbsTol', 1e-12);

clear cleanup
removeTestFolder(root);
end


function testDeadRequiredChannelIsAuditedAsError(testCase)
root = string(tempname);
mkdir(root);
cleanup = onCleanup(@() removeTestFolder(root));
unitTable = makeUnitTableAndCache(root, "Affine", 2);

audit = ComputeAdjacentQuickTuningDiscontinuity(unitTable, ...
    JimCacheFolder=root, ClayCacheFolder=root, ChannelMap=1:5, ...
    CandidateMask=true, NumSplits=5);

verifyEqual(testCase, audit.Status, "Error");
verifyThat(testCase, audit.Message, ...
    matlab.unittest.constraints.ContainsSubstring( ...
    "AdjacentTuningDistance:DeadChannel"));

clear cleanup
removeTestFolder(root);
end


function unitTable = makeUnitTableAndCache(folder, pattern, deadChannel)
coherence = [-22 -14 -10 -8 8 10 14 22] ./ 22;
trialCount = 10;
Neuro = struct();
Neuro.CoherenceArray = coherence;
Neuro.All = nan(4, numel(coherence), trialCount, 5);
Neuro.Trials.NumTrials = repmat(trialCount, 4, numel(coherence));
trialNoise = linspace(-0.4, 0.4, trialCount);
for cue = 1:4
    for coherenceIndex = 1:numel(coherence)
        base = 0.6 .* cue + 2 .* coherence(coherenceIndex) + trialNoise;
        for channel = 1:5
            latent = base;
            if pattern == "Step" && channel >= 4
                latent = latent + 2.5 .* cue .* ...
                    sign(coherence(coherenceIndex));
            end
            Neuro.All(cue, coherenceIndex, :, channel) = ...
                10 .* channel + (0.5 + channel) .* latent;
        end
    end
end
save(fullfile(folder, '20240101.mat'), 'Neuro');

Date = datetime(2024, 1, 1);
Monkey = "Jim";
ROI = "MT";
StimElec = 3;
NChannels = 5;
DeadChannel = {deadChannel};
unitTable = table(Date, Monkey, ROI, StimElec, NChannels, DeadChannel);
end


function removeTestFolder(folder)
if isfolder(folder)
    rmdir(folder, 's');
end
end

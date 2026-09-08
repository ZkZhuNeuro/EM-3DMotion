function tests = TestComputeQuickTuningWindowDiameter
tests = functiontests(localfunctions);
end


function testGradualDriftFindsWindowEndpoints(testCase)
root = string(tempname);
mkdir(root);
cleanup = onCleanup(@() removeTestFolder(root));
unitTable = makeUnitTableAndCache(root, []);

audit = ComputeQuickTuningWindowDiameter(unitTable, ...
    JimCacheFolder=root, ClayCacheFolder=root, ChannelMap=1:9, ...
    RelativePositions=-4:4, CandidateMask=true, ...
    NumSplits=50, RandomSeed=11);

verifyEqual(testCase, audit.Status, "Success");
verifyEqual(testCase, audit.WindowChannels{1}, 1:9);
verifyEqual(testCase, numel(audit.PairDistanceSquared{1}), 36);
verifySize(testCase, audit.DistanceMatrixSquared{1}, [9 9]);
verifyEqual(testCase, audit.DiameterLeftRelativePosition, -4);
verifyEqual(testCase, audit.DiameterRightRelativePosition, 4);
verifyEqual(testCase, audit.DiameterPhysicalSpan, 8);
verifyEqual(testCase, audit.WindowDiameterSquared, ...
    audit.EndpointDistanceSquared, 'AbsTol', 1e-12);
verifyGreaterThan(testCase, audit.WindowDiameterSquared, 0.1);

clear cleanup
removeTestFolder(root);
end


function testDeadWindowContactIsAudited(testCase)
root = string(tempname);
mkdir(root);
cleanup = onCleanup(@() removeTestFolder(root));
unitTable = makeUnitTableAndCache(root, 2);

audit = ComputeQuickTuningWindowDiameter(unitTable, ...
    JimCacheFolder=root, ClayCacheFolder=root, ChannelMap=1:9, ...
    RelativePositions=-4:4, CandidateMask=true, NumSplits=5);

verifyEqual(testCase, audit.Status, "Error");
verifyThat(testCase, audit.Message, ...
    matlab.unittest.constraints.ContainsSubstring( ...
    "QuickTuningDiameter:DeadChannel"));

clear cleanup
removeTestFolder(root);
end


function testDeadNonstimContactCanBeSkipped(testCase)
root = string(tempname);
mkdir(root);
cleanup = onCleanup(@() removeTestFolder(root));
unitTable = makeUnitTableAndCache(root, 2);

audit = ComputeQuickTuningWindowDiameter(unitTable, ...
    JimCacheFolder=root, ClayCacheFolder=root, ChannelMap=1:9, ...
    RelativePositions=-4:4, CandidateMask=true, NumSplits=20, ...
    AllowDeadChannels=true);

verifyEqual(testCase, audit.Status, "Success");
verifyEqual(testCase, audit.LiveContactCount, 8);
verifyEqual(testCase, audit.DeadContactCount, 1);
verifyEqual(testCase, audit.EvaluatedPairCount, 28);
verifyFalse(testCase, ismember(-3, audit.WindowRelativePositions{1}));
verifyFalse(testCase, any(audit.PairRelativePositions{1} == -3, 'all'));

clear cleanup
removeTestFolder(root);
end


function unitTable = makeUnitTableAndCache(folder, deadChannel)
coherence = [-22 -14 -10 -8 8 10 14 22] ./ 22;
trialCount = 10;
Neuro = struct();
Neuro.CoherenceArray = coherence;
Neuro.All = nan(4, numel(coherence), trialCount, 9);
Neuro.Trials.NumTrials = repmat(trialCount, 4, numel(coherence));
trialNoise = linspace(-0.3, 0.3, trialCount);
for cue = 1:4
    for coherenceIndex = 1:numel(coherence)
        base = 0.5 .* cue + coherence(coherenceIndex) + trialNoise;
        shape = cue .* sign(coherence(coherenceIndex));
        for channel = 1:9
            relativePosition = channel - 5;
            latent = base + 0.35 .* relativePosition .* shape;
            Neuro.All(cue, coherenceIndex, :, channel) = ...
                8 .* channel + (1 + 0.2 .* channel) .* latent;
        end
    end
end
save(fullfile(folder, '20240101.mat'), 'Neuro');

Date = datetime(2024, 1, 1);
Monkey = "Jim";
ROI = "MT";
StimElec = 5;
NChannels = 9;
DeadChannel = {deadChannel};
unitTable = table(Date, Monkey, ROI, StimElec, NChannels, DeadChannel);
end


function removeTestFolder(folder)
if isfolder(folder)
    rmdir(folder, 's');
end
end

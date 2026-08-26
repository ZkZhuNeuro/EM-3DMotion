function tests = TestAuditAdjacentQuickChannelAIFlips
tests = functiontests(localfunctions);
end


function testSignificantOppositePhysicalNeighborFlagsSite(testCase)
[unitTable, cacheFolder] = makeTestInput([]);
cleanup = onCleanup(@() removeTestFolder(cacheFolder));

audit = AuditAdjacentQuickChannelAIFlips(unitTable, ...
    JimCacheFolder=cacheFolder, ClayCacheFolder=cacheFolder, ...
    CandidateMask=true);

verifyEqual(testCase, audit.Status, "Success");
verifyEqual(testCase, audit.StimChannel, 2);
verifyEqual(testCase, audit.Minus1Channel, 4);
verifyEqual(testCase, audit.Plus1Channel, 7);
verifyLessThan(testCase, audit.Minus1CombinedP, 0.05);
verifyTrue(testCase, audit.Minus1SignFlip);
verifyFalse(testCase, audit.Plus1SignFlip);
verifyTrue(testCase, audit.ExcludeForAIFlip);
end


function testDeadOppositeNeighborDoesNotFlagSite(testCase)
[unitTable, cacheFolder] = makeTestInput(4);
cleanup = onCleanup(@() removeTestFolder(cacheFolder));

audit = AuditAdjacentQuickChannelAIFlips(unitTable, ...
    JimCacheFolder=cacheFolder, ClayCacheFolder=cacheFolder, ...
    CandidateMask=true);

verifyEqual(testCase, audit.Minus1Status, "DeadChannel");
verifyFalse(testCase, audit.Minus1Significant);
verifyFalse(testCase, audit.ExcludeForAIFlip);
end


function testNoncandidateDoesNotRequireCache(testCase)
[unitTable, cacheFolder] = makeTestInput([]);
cleanup = onCleanup(@() removeTestFolder(cacheFolder));
delete(fullfile(cacheFolder, '20260102.mat'));

audit = AuditAdjacentQuickChannelAIFlips(unitTable, ...
    JimCacheFolder=cacheFolder, ClayCacheFolder=cacheFolder, ...
    CandidateMask=false);

verifyEqual(testCase, audit.Status, "NotCandidate");
verifyFalse(testCase, audit.ExcludeForAIFlip);
end


function testRadiusTwoFindsFlipMissedByImmediateNeighbors(testCase)
[unitTable, cacheFolder] = makeTestInput([]);
cleanup = onCleanup(@() removeTestFolder(cacheFolder));
aiValues = unitTable.AI{1};
aiValues(1, 4) = 0.3;  % relative -1, agrees
aiValues(1, 7) = 0.2;  % relative +1, agrees
aiValues(1, 6) = 0.25; % relative -2, agrees
aiValues(1, 5) = -0.4; % relative +2, flips
unitTable.AI{1} = aiValues;

cacheFile = fullfile(cacheFolder, '20260102.mat');
loaded = load(cacheFile, 'Neuro');
Neuro = loaded.Neuro;
for coherenceIndex = 1:numel(Neuro.CoherenceArray)
    direction = sign(Neuro.CoherenceArray(coherenceIndex));
    for channel = [5, 6]
        response = squeeze(Neuro.All(1, coherenceIndex, :, channel));
        Neuro.All(1, coherenceIndex, :, channel) = ...
            response + 4 .* direction;
    end
end
save(cacheFile, 'Neuro');

radius1 = AuditAdjacentQuickChannelAIFlips(unitTable, ...
    JimCacheFolder=cacheFolder, ClayCacheFolder=cacheFolder, ...
    NeighborRadius=1, CandidateMask=true);
radius2 = AuditAdjacentQuickChannelAIFlips(unitTable, ...
    JimCacheFolder=cacheFolder, ClayCacheFolder=cacheFolder, ...
    NeighborRadius=2, CandidateMask=true);

verifyFalse(testCase, radius1.ExcludeForAIFlip);
verifyTrue(testCase, radius2.ExcludeForAIFlip);
verifyEqual(testCase, radius2.Minus2Channel, 6);
verifyEqual(testCase, radius2.Plus2Channel, 5);
verifyTrue(testCase, radius2.Plus2Significant);
verifyTrue(testCase, radius2.Plus2SignFlip);
verifyEqual(testCase, radius2.SignificantAdjacentCount, 4);
end


function [unitTable, cacheFolder] = makeTestInput(deadChannel)
cacheFolder = string(tempname);
mkdir(cacheFolder);
coherence = [-22 -14 -10 -8 8 10 14 22] ./ 22;
trialCount = 20;
channelCount = 16;
Neuro = struct();
Neuro.CoherenceArray = coherence;
Neuro.All = nan(4, numel(coherence), trialCount, channelCount);
Neuro.Trials.NumTrials = repmat(trialCount, 4, numel(coherence));
noise = linspace(-0.3, 0.3, trialCount);
for cue = 1:4
    for coherenceIndex = 1:numel(coherence)
        direction = sign(coherence(coherenceIndex));
        base = 20 + 2 .* abs(coherence(coherenceIndex));
        for channel = 1:channelCount
            response = base + noise + 0.01 .* channel;
            if cue == 1 && channel == 2
                response = response + 4 .* direction;
            elseif cue == 1 && channel == 4
                response = response - 4 .* direction;
            elseif cue == 1 && channel == 7
                response = response + 3 .* direction;
            end
            Neuro.All(cue, coherenceIndex, :, channel) = response;
        end
    end
end
save(fullfile(cacheFolder, '20260102.mat'), 'Neuro');

aiValues = zeros(4, channelCount);
aiValues(1, 2) = 0.4;
aiValues(1, 4) = -0.3;
aiValues(1, 7) = 0.2;
Date = datetime(2026, 1, 2);
Monkey = "Jim";
ROI = "MT";
StimElec = 2;
NChannels = channelCount;
AI = {aiValues};
DeadChannel = {deadChannel};
unitTable = table(Date, Monkey, ROI, StimElec, NChannels, AI, DeadChannel);
end


function removeTestFolder(folder)
if isfolder(folder)
    rmdir(folder, 's');
end
end

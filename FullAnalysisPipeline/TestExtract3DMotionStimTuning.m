function TestExtract3DMotionStimTuning()
%TESTEXTRACT3DMOTIONSTIMTUNING Small deterministic extractor regression test.

testFolder = tempname;
mkdir(testFolder);
cleanup = onCleanup(@() rmdir(testFolder, 's'));

TrialInfo(1) = makeTrial(0, false, 1, 4002, 13636, ...
    [1.0 1.5 2.0], [0.5 1.2 NaN]);
TrialInfo(2) = makeTrial(10, false, 1, 4002, 13636, ...
    [11.2 NaN NaN], [11.1 11.9 NaN]);
TrialInfo(3) = makeTrial(20, true, 1, 4002, 13636, ...
    [21.1 21.8 NaN], [NaN NaN NaN]);
TrialInfo(4) = makeTrial(30, false, 2, 4000, 10000, ...
    [31.4 NaN NaN], [31.3 NaN NaN]);
Config = struct('ScrDistmm', 570);

tInfoName = 'Synthetic_01Jan2024_3DMotionStim_MUA_TInfo.mat';
selIndexName = 'Synthetic_01Jan2024_3DMotionStim_MUA_SelIndex.mat';
save(fullfile(testFolder, tInfoName), 'TrialInfo', 'Config');
EditSel = ones(1, numel(TrialInfo));
save(fullfile(testFolder, selIndexName), 'EditSel', 'Config');

[Neuro, TrialSummary, summary] = Extract3DMotionStimTuning( ...
    testFolder, {tInfoName, selIndexName}, ...
    ApplyEyeCheck=false, ProgressInterval=0);

positiveIndex = find(Neuro.Coherence == 0.36, 1);
zeroIndex = find(Neuro.WithZero.Coherence == 0, 1);
assert(size(Neuro.Means, 2) == 12);
assert(numel(Neuro.CoherenceArray) == 12 && ...
    ~any(Neuro.CoherenceArray == 0));
assert(size(Neuro.WithZero.NoStim.Means, 2) == 13);
assert(Neuro.Trials.NumTrials(1, positiveIndex) == 2);
assert(Neuro.Stim.Trials.NumTrials(1, positiveIndex) == 1);
assert(Neuro.WithZero.NoStim.Trials.NumTrials(2, zeroIndex) == 1);
assert(abs(Neuro.Means(1, positiveIndex, 1, 1) - 2) < 1e-12);
assert(abs(Neuro.Means(1, positiveIndex, 2, 1) - 1.5) < 1e-12);
assert(abs(Neuro.SEM(1, positiveIndex, 1, 1) - 1) < 1e-12);
assert(summary.NoStimTrialCount == 3);
assert(summary.StimTrialCount == 1);
assert(summary.QuickCompatibleNoStimTrialCount == 2);
assert(summary.QuickCompatibleStimTrialCount == 1);
assert(summary.ZeroCoherenceTrialCount == 1);
assert(summary.ExcludedTrialCount == 0);
assert(isequal(TrialSummary.ElectricalStim, [false; false; true; false]));

% The authoritative YYYYMMDD folder must override a copied date embedded in
% a filename, and the legacy 20-May-2022 eye-check exception must be kept.
legacySkipFolder = fullfile(testFolder, '20220520');
mkdir(legacySkipFolder);
wrongDateTInfo = 'Synthetic_23Mar2024_3DMotionStim_MUA_TInfo.mat';
wrongDateSel = 'Synthetic_23Mar2024_3DMotionStim_MUA_SelIndex.mat';
save(fullfile(legacySkipFolder, wrongDateTInfo), 'TrialInfo', 'Config');
save(fullfile(legacySkipFolder, wrongDateSel), 'EditSel', 'Config');
[~, ~, skipSummary] = Extract3DMotionStimTuning( ...
    legacySkipFolder, {wrongDateTInfo, wrongDateSel}, ...
    ApplyEyeCheck=true, ProgressInterval=0);
assert(skipSummary.EyeCheck.IntentionallySkipped);
assert(contains(skipSummary.EyeCheck.Status, 'legacy Quick exception'));

fprintf('TestExtract3DMotionStimTuning passed.\n');
end


function trial = makeTrial(startTime, isStim, condition, directionCode, ...
    coherenceCode, channel1Spikes, channel2Spikes)
events = [111 2001 directionCode coherenceCode 8000 + condition 118 130 6001 112];
eventTimes = startTime + [0 0.1 0.2 0.3 0.4 1 2 2.2 3];
if isStim
    events = [events(1:5) 222 events(6:end)];
    eventTimes = [eventTimes(1:5) startTime + 0.5 eventTimes(6:end)];
end

unitT = nan(2, 1, 3);
unitT(1, 1, :) = channel1Spikes;
unitT(2, 1, :) = channel2Spikes;
trial = struct( ...
    'UnitT', unitT, ...
    'StartTimeStamp', startTime, ...
    'EventT', eventTimes, ...
    'EID', events);
end

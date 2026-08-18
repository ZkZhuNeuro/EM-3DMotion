function tests = TestBuildUnitTableStimTunings
%TESTBUILDUNITTABLESTIMTUNINGS End-to-end synthetic population test.
tests = functiontests(localfunctions);
end


function testV73OversizedFieldUsesSlimStaging(testCase)
root = string(tempname);
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's'));
sessionFolder = fullfile(root, '20240103');
mkdir(sessionFolder);

[TrialInfo, Config, EditSel] = makeSyntheticTrials();
for trialIndex = 1:numel(TrialInfo)
    % These fields mimic the large arrays that make a full TrialInfo load
    % expensive. The test forces the production staging branch with a
    % one-byte direct-load limit, so the fixture itself stays compact.
    TrialInfo(trialIndex).UnitSDF = zeros(3, 1, 20000);
    TrialInfo(trialIndex).LFP = zeros(3, 20000);
end
tInfoName = 'Synthetic_03Jan2024_MUA_3DMotionStim_TInfo.mat';
selName = 'Synthetic_03Jan2024_MUA_3DMotionStim_SelIndex.mat';
tInfoFile = fullfile(sessionFolder, tInfoName);
selIndexFile = fullfile(sessionFolder, selName);
save(tInfoFile, 'TrialInfo', 'Config', '-v7.3');
save(selIndexFile, 'EditSel', 'Config');

Date = datetime(2024, 1, 3);
Paths = {char(sessionFolder)};
Monkey = {'Jim'};
StimElec = 1;
NChannels = 2;
unit_table_gof = table(Date, Paths, Monkey, StimElec, NChannels);
inputFile = fullfile(root, 'unit_table_gof.mat');
save(inputFile, 'unit_table_gof');
outputFolder = fullfile(root, 'StimOutput');

result = BuildUnitTableStimTunings( ...
    inputFile, outputFolder, ApplyEyeCheck=false, ...
    MaxDirectTrialInfoBytes=1, Resume=false);

verifyEqual(testCase, result.stim_tuning_status(1), "Success");
summary = result.stim_tuning_extraction_summary{1};
verifyTrue(testCase, summary.MemorySafeSlimInput.Used);
verifyGreaterThan(testCase, ...
    summary.MemorySafeSlimInput.OriginalTrialInfoBytes, 1);
verifyEqual(testCase, ...
    summary.MemorySafeSlimInput.RetainedFields, ...
    ["EID", "EventT", "UnitT"]);
verifyEqual(testCase, summary.TInfoFile, string(tInfoFile));
verifyEqual(testCase, summary.SelIndexFile, string(selIndexFile));

trialData = load(result.stim_tuning_trial_FR_file(1), 'StimTrialFR');
verifyEqual(testCase, trialData.StimTrialFR.Source.TInfoFile, ...
    string(tInfoFile));
verifyEqual(testCase, ...
    trialData.StimTrialFR.ExtractionSummary.TInfoFile, ...
    string(tInfoFile));
clear cleanup
end


function testThreeTuningsAndSeparateTrialFR(testCase)
root = string(tempname);
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's'));
sessionOne = fullfile(root, '20240101');
sessionTwo = fullfile(root, '20240102');
mkdir(sessionOne);
mkdir(sessionTwo);

[TrialInfo, Config, EditSel] = makeSyntheticTrials();
tInfoName = 'Synthetic_01Jan2024_MUA_3DMotionStim_TInfo.mat';
selName = 'Synthetic_01Jan2024_MUA_3DMotionStim_SelIndex.mat';
save(fullfile(sessionOne, tInfoName), 'TrialInfo', 'Config');
save(fullfile(sessionOne, selName), 'EditSel', 'Config');

Date = [datetime(2024, 1, 1); datetime(2024, 1, 2)];
Paths = {char(sessionOne); char(sessionTwo)};
Monkey = {'Jim'; 'Clay'};
StimElec = [1; 1];
NChannels = [2; 2];
unit_table_gof = table(Date, Paths, Monkey, StimElec, NChannels);
inputFile = fullfile(root, 'unit_table_gof.mat');
save(inputFile, 'unit_table_gof');
outputFolder = fullfile(root, 'StimOutput');

[result, manifest] = BuildUnitTableStimTunings( ...
    inputFile, outputFolder, ApplyEyeCheck=false, ...
    Resume=true, CheckpointEvery=1);

verifyEqual(testCase, result.stim_tuning_status(1), "Success");
verifyEqual(testCase, result.stim_tuning_status(2), "MissingStimPair");
coherence = result.stim_tuning_coherence{1};
positiveIndex = find(coherence == 0.36, 1);
verifyNotEmpty(testCase, positiveIndex);
verifySize(testCase, result.stim_tuning_mean_noStim{1}, [4 13 2]);
summary = result.stim_tuning_extraction_summary{1};
verifyEqual(testCase, summary.OriginalNumChannels, 3);
verifyEqual(testCase, summary.NumChannels, 2);
verifyTrue(testCase, summary.ChannelSelection.Applied);
verifyEqual(testCase, ...
    summary.ChannelSelection.RetainedAcquisitionIndices, 1:2);
verifyEqual(testCase, ...
    summary.ChannelSelection.DroppedTrailingAcquisitionIndices, 3);
verifyEqual(testCase, ...
    result.stim_tuning_mean_noStim{1}(1, positiveIndex, 1), 3, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, ...
    result.stim_tuning_mean_stim{1}(1, positiveIndex, 1), 12, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, ...
    result.stim_tuning_mean_merged{1}(1, positiveIndex, 1), 7.5, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, ...
    result.stim_tuning_SEM_noStim{1}(1, positiveIndex, 1), 1, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, ...
    result.stim_tuning_n_noStim{1}(1, positiveIndex), 2);
verifyEqual(testCase, ...
    result.stim_tuning_n_stim{1}(1, positiveIndex), 2);
verifyEqual(testCase, ...
    result.stim_tuning_n_merged{1}(1, positiveIndex), 4);

trialFile = result.stim_tuning_trial_FR_file(1);
verifyTrue(testCase, isfile(trialFile));
trialData = load(trialFile, 'StimTrialFR');
verifySize(testCase, trialData.StimTrialFR.FiringRateHz, [5 2]);
verifyEqual(testCase, height(trialData.StimTrialFR.TrialSummary), 5);
verifyFalse(testCase, isfield(trialData.StimTrialFR, 'Neuro'));
verifyFalse(testCase, isfield(trialData.StimTrialFR, 'Tuning'));
verifyEqual(testCase, manifest.Status(1), "Success");
verifyEqual(testCase, height(manifest), 2);

saved = load(fullfile(outputFolder, 'unit_table_stim.mat'), ...
    'unit_table_stim', 'SessionManifest');
verifyEqual(testCase, saved.unit_table_stim.stim_tuning_status, ...
    result.stim_tuning_status);
verifyEqual(testCase, height(saved.SessionManifest), 2);
verifyTrue(testCase, isfile(fullfile(outputFolder, ...
    'StimTuningSessionManifest.csv')));

trialInfoBeforeResume = dir(trialFile);
resumed = BuildUnitTableStimTunings(inputFile, outputFolder, ...
    ApplyEyeCheck=false, Resume=true, CheckpointEvery=1);
trialInfoAfterResume = dir(trialFile);
verifyEqual(testCase, resumed.stim_tuning_status(1), "Success");
verifyEqual(testCase, trialInfoAfterResume.bytes, trialInfoBeforeResume.bytes);
verifyEqual(testCase, trialInfoAfterResume.datenum, ...
    trialInfoBeforeResume.datenum);

% Simulate a process ending after the atomic trial-FR save but before the
% population-table checkpoint. The next run must rebuild the table row from
% that trial file instead of extracting the source recording again.
stateFile = fullfile(outputFolder, 'unit_table_stim.mat');
interrupted = load(stateFile, 'unit_table_stim', 'SessionManifest', ...
    'PipelineMetadata');
interrupted.unit_table_stim.stim_tuning_status(1) = "Pending";
interrupted.unit_table_stim.stim_tuning_mean_noStim{1} = [];
unit_table_stim = interrupted.unit_table_stim; %#ok<NASGU>
SessionManifest = interrupted.SessionManifest; %#ok<NASGU>
PipelineMetadata = interrupted.PipelineMetadata; %#ok<NASGU>
save(stateFile, 'unit_table_stim', 'SessionManifest', 'PipelineMetadata', ...
    '-v7.3');
trialInfoBeforeRecovery = dir(trialFile);
recovered = BuildUnitTableStimTunings(inputFile, outputFolder, ...
    ApplyEyeCheck=false, Resume=true, CheckpointEvery=1, Rows=1);
trialInfoAfterRecovery = dir(trialFile);
verifyEqual(testCase, recovered.stim_tuning_status(1), "Success");
verifyTrue(testCase, startsWith( ...
    recovered.stim_tuning_message(1), "Recovered tuning"));
verifyEqual(testCase, ...
    recovered.stim_tuning_mean_merged{1}(1, positiveIndex, 1), 7.5, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, trialInfoAfterRecovery.datenum, ...
    trialInfoBeforeRecovery.datenum);
clear cleanup
end


function [TrialInfo, Config, EditSel] = makeSyntheticTrials()
TrialInfo(1) = makeTrial(0, false, 1, 4002, 13636, 2, 1);
TrialInfo(2) = makeTrial(10, false, 1, 4002, 13636, 4, 2);
TrialInfo(3) = makeTrial(20, true, 1, 4002, 13636, 10, 5);
TrialInfo(4) = makeTrial(30, true, 1, 4002, 13636, 14, 7);
TrialInfo(5) = makeTrial(40, false, 2, 4000, 10000, 3, 2);
Config = struct('ScrDistmm', 570);
EditSel = ones(1, numel(TrialInfo));
end


function trial = makeTrial(startTime, isStim, condition, directionCode, ...
    coherenceCode, channelOneCount, channelTwoCount)
events = [111 2001 directionCode coherenceCode 8000 + condition ...
    118 130 6001 112];
eventTimes = startTime + [0 0.1 0.2 0.3 0.4 1 2 2.2 3];
if isStim
    events = [events(1:5) 222 events(6:end)];
    eventTimes = [eventTimes(1:5) startTime + 0.5 eventTimes(6:end)];
end
maxSpikes = max(channelOneCount, channelTwoCount);
unitT = nan(3, 1, maxSpikes);
unitT(1, 1, 1:channelOneCount) = linspace( ...
    startTime + 1.05, startTime + 1.95, channelOneCount);
unitT(2, 1, 1:channelTwoCount) = linspace( ...
    startTime + 1.05, startTime + 1.95, channelTwoCount);
unitT(3, 1, :) = unitT(1, 1, :);
trial = struct('UnitT', unitT, 'StartTimeStamp', startTime, ...
    'EventT', eventTimes, 'EID', events);
end

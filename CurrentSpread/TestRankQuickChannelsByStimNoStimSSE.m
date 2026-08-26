function tests = TestRankQuickChannelsByStimNoStimSSE
%TESTRANKQUICKCHANNELSBYSTIMNOSTIMSSE Synthetic regression tests.
tests = functiontests(localfunctions);
end


function testRecomputesWholeChannelZAndFindsMinimumSSE(testCase)
temporaryDirectory = string(tempname);
mkdir(temporaryDirectory);
cleanup = onCleanup(@() rmdir(temporaryDirectory, 's'));

stimCoherence = [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22] ./ 22;
quickColumns = [1:6 8:13];
reference = [ ...
    1 2 4 7 6 9 8 11 10 14 13 16 18; ...
    18 15 14 12 10 11 8 7 6 5 3 4 1; ...
    2 5 3 7 6 10 9 13 11 15 14 19 17; ...
    4 3 7 5 9 8 12 10 14 13 17 15 20];
stimMean = repmat(reference, [1 1 3]);
% Channel 2 preserves within-cue shapes but adds cue-specific offsets. It
% would tie under cue-wise standardization. Channel 3 is one affine
% transform of the complete matrix and must be the whole-channel winner.
quickMean = nan(4, 12, 3);
quickMean(:, :, 1) = fliplr(reference(:, quickColumns));
quickMean(:, :, 2) = 2 .* reference(:, quickColumns) + ...
    [80; -80; 40; -40];
quickMean(:, :, 3) = 4 .* reference(:, quickColumns) + 10;

% A deliberately stale saved array favors channel 1. The analysis must
% ignore it and recompute from tuning_mean on the shared grid.
quickZ = nan(4, 12, 3);
quickZ(:, :, 1) = zscore(reference(:, quickColumns), 0, 2);
quickZ(:, :, 2) = fliplr(quickZ(:, :, 1));
quickZ(:, :, 3) = fliplr(quickZ(:, :, 1));

Date = datetime(2024, 4, 16);
Monkey = "Jim";
StimElec = 2;
NChannels = 3;
tuning_mean = {quickMean};
tuning_z = {quickZ};
stim_tuning_mean_noStim = {stimMean};
stim_tuning_coherence = {stimCoherence};
stim_tuning_channel_map = {[2 1 3]};
stim_tuning_condition_names = ...
    {["Combined", "MonoL", "MonoR", "Binocular"]};
stim_tuning_status = "Success";
unit_table_stim = table(Date, Monkey, StimElec, NChannels, ...
    tuning_mean, tuning_z, stim_tuning_mean_noStim, ...
    stim_tuning_coherence, stim_tuning_channel_map, ...
    stim_tuning_condition_names, stim_tuning_status);
stateFile = fullfile(temporaryDirectory, 'unit_table_stim.mat');
save(stateFile, 'unit_table_stim');

[sessions, channels] = RankQuickChannelsByStimNoStimSSE( ...
    stateFile, SaveOutputs=false, MakePlots=false);

verifyEqual(testCase, sessions.Status, "Success");
verifyEqual(testCase, sessions.SharedCoherenceCount, 8);
verifyEqual(testCase, sessions.ReferenceValueCount, 32);
verifyEqual(testCase, sessions.BestChannel, 3);
verifyEqual(testCase, sessions.BestSSE, 0, 'AbsTol', 1e-12);
verifyEqual(testCase, channels.Rank(channels.QuickChannel == 3), 1);
verifyGreaterThan(testCase, channels.SSE(channels.QuickChannel == 2), 0);
verifyGreaterThan(testCase, channels.SSE(channels.QuickChannel == 1), 0);
clear cleanup
end


function testIncompleteQuickMeanChannelIsNotRanked(testCase)
temporaryDirectory = string(tempname);
mkdir(temporaryDirectory);
cleanup = onCleanup(@() rmdir(temporaryDirectory, 's'));

coherence = [-22 -14 -10 -8 8 10 14 22] ./ 22;
reference = repmat(1:8, 4, 1) + (0:3)';
stimMean = repmat(reference, [1 1 2]);
quickMean = repmat(reference, [1 1 2]);
quickMean(1, 1, 1) = NaN;

Date = datetime(2025, 1, 2);
Monkey = "Clay";
StimElec = 1;
NChannels = 2;
tuning_mean = {quickMean};
stim_tuning_mean_noStim = {stimMean};
stim_tuning_coherence = {coherence};
stim_tuning_channel_map = {[1 2]};
stim_tuning_condition_names = ...
    {["Combined", "MonoL", "MonoR", "Binocular"]};
stim_tuning_status = "SuccessWithEyeCheckWarning";
unit_table_stim = table(Date, Monkey, StimElec, NChannels, tuning_mean, ...
    stim_tuning_mean_noStim, stim_tuning_coherence, ...
    stim_tuning_channel_map, stim_tuning_condition_names, ...
    stim_tuning_status);
stateFile = fullfile(temporaryDirectory, 'unit_table_stim.mat');
save(stateFile, 'unit_table_stim');

[sessions, channels] = RankQuickChannelsByStimNoStimSSE( ...
    stateFile, SaveOutputs=false, MakePlots=false);

verifyEqual(testCase, sessions.BestChannel, 2);
verifyFalse(testCase, channels.IsComplete(channels.QuickChannel == 1));
verifyTrue(testCase, isnan(channels.Rank(channels.QuickChannel == 1)));
clear cleanup
end

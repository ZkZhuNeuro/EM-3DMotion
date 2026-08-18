function tests = TestCompareStimTuningToQuickChannels
%TESTCOMPARESTIMTUNINGTOQUICKCHANNELS Synthetic fixed-grid regression test.
tests = functiontests(localfunctions);
end


function testAffineEquivalentChannelWins(testCase)
temporaryDirectory = string(tempname);
mkdir(temporaryDirectory);
cleanup = onCleanup(@() rmdir(temporaryDirectory, 's'));

coherence = [-22 -14 -10 -8 8 10 14 22] ./ 22;
stimMean = [ ...
    1 2 4 6 8 9 11 14; ...
    14 12 11 9 7 5 4 2; ...
    2 3 3 5 8 8 10 13; ...
    4 7 5 8 9 12 11 15];

Neuro = struct();
Neuro.Means = reshape(stimMean, [4 8 1 1]);
Neuro.NoStim.Means = Neuro.Means;
Neuro.CoherenceArray = coherence;
Neuro.ConditionNames = ["Combined", "MonoL", "MonoR", "Binocular"];
Neuro.ChannelMap = 1:3;
stimFile = fullfile(temporaryDirectory, 'synthetic_stim.mat');
save(stimFile, 'Neuro');

quickMean = nan(4, 8, 3);
quickMean(:, :, 1) = fliplr(stimMean);
quickMean(:, :, 2) = 3 .* stimMean + [10; -4; 6; 20];
quickMean(:, :, 3) = stimMean + [ ...
    3 -1 2 -2 1 -3 4 -4; ...
    -2 3 -1 4 -3 1 -4 2; ...
    4 -2 3 -1 2 -4 1 -3; ...
    -1 4 -3 2 -4 3 -2 1];
tuning_mean = {quickMean};
tuning_z = {zscore(quickMean, 0, 2)};
Monkey = "Jim";
Date = datetime(2024, 4, 16);
StimElec = 1;
unit_table_gof = table(Monkey, Date, StimElec, tuning_mean, tuning_z);
tableFile = fullfile(temporaryDirectory, 'synthetic_unit_table_gof.mat');
save(tableFile, 'unit_table_gof');

[comparison, figures] = CompareStimTuningToQuickChannels( ...
    stimFile, tableFile, UnitTableRow=1, StimulationChannel=1, ...
    MakePlots=false, SaveOutputs=false);

verifyEqual(testCase, comparison.BestChannel, 2);
verifyEqual(testCase, comparison.BestSSE, 0, 'AbsTol', 1e-12);
verifyEqual(testCase, comparison.ExpectedCellCount, 32);
verifyEqual(testCase, comparison.ChannelSummaryByChannel.PairedValueCount, ...
    repmat(32, 3, 1));
verifyLessThan(testCase, ...
    max(comparison.ChannelSummaryByChannel.StoredZMaxAbsDifference), ...
    1e-12);
verifyEmpty(testCase, figures.AllChannels);
clear cleanup
end


function testIncompleteChannelIsNotRanked(testCase)
temporaryDirectory = string(tempname);
mkdir(temporaryDirectory);
cleanup = onCleanup(@() rmdir(temporaryDirectory, 's'));

coherence = [-22 -14 -10 -8 8 10 14 22] ./ 22;
stimMean = repmat(1:8, 4, 1) + (0:3)';
Neuro.Means = reshape(stimMean, [4 8 1 1]);
Neuro.CoherenceArray = coherence;
Neuro.ConditionNames = ["Combined", "MonoL", "MonoR", "Binocular"];
stimFile = fullfile(temporaryDirectory, 'synthetic_stim.mat');
save(stimFile, 'Neuro');

quick = repmat(stimMean, [1 1 2]);
quick(1, 1, 1) = NaN;
tuning_mean = {quick};
StimElec = 1;
unit_table_gof = table(StimElec, tuning_mean);
tableFile = fullfile(temporaryDirectory, 'synthetic_unit_table_gof.mat');
save(tableFile, 'unit_table_gof');

comparison = CompareStimTuningToQuickChannels( ...
    stimFile, tableFile, UnitTableRow=1, StimulationChannel=1, ...
    MakePlots=false, SaveOutputs=false);

verifyFalse(testCase, comparison.ChannelSummaryByChannel.IsComplete(1));
verifyTrue(testCase, isnan(comparison.ChannelSummaryByChannel.SSE(1)));
verifyEqual(testCase, comparison.BestChannel, 2);
clear cleanup
end

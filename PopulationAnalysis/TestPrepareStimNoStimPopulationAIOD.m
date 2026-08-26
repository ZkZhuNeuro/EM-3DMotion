function tests = TestPrepareStimNoStimPopulationAIOD
%TESTPREPARESTIMNOSTIMPOPULATIONAIOD Table-level source-selection tests.
tests = functiontests(localfunctions);
end


function testAddsStimIndicesWithoutChangingQuickFields(testCase)
[meanTuning, semTuning, countTuning, coherence] = makeTuning();

Date = [datetime(2024, 1, 2); datetime(2024, 1, 3)];
Monkey = ["Jim"; "Clay"];
StimElec = [2; 1];
NChannels = [2; 2];
stim_tuning_status = ["Success"; "Pending"];
stim_tuning_mean_noStim = {meanTuning; meanTuning};
stim_tuning_SEM_noStim = {semTuning; semTuning};
stim_tuning_n_noStim = {countTuning; countTuning};
stim_tuning_coherence = {coherence; coherence};
stim_tuning_condition_names = { ...
    ["Combined", "MonoL", "MonoR", "Binocular"]; ...
    ["Combined", "MonoL", "MonoR", "Binocular"]};
AI = {ones(4, 2); 2 .* ones(4, 2)};
OD_max = {0.8; -0.9};
unit_table_stim = table(Date, Monkey, StimElec, NChannels, stim_tuning_status, ...
    stim_tuning_mean_noStim, stim_tuning_SEM_noStim, ...
    stim_tuning_n_noStim, stim_tuning_coherence, ...
    stim_tuning_condition_names, AI, OD_max);

[prepared, audit] = ...
    PrepareStimNoStimPopulationAIOD(unit_table_stim);
[expectedAI, expectedOD] = CalculateStimNoStimAIOD( ...
    meanTuning, semTuning, countTuning, coherence, 2);

verifyEqual(testCase, prepared.AI, AI);
verifyEqual(testCase, prepared.OD_max, OD_max);
verifyEqual(testCase, prepared.stim_noStim_index_status(1), "Success");
verifyEqual(testCase, prepared.stim_noStim_index_status(2), ...
    "SkippedInputStatus");
verifyEqual(testCase, prepared.stim_noStim_AI{1}, expectedAI, ...
    'AbsTol', 1e-12);
verifyTrue(testCase, all(isnan(prepared.stim_noStim_AI{2})));
verifyEqual(testCase, prepared.stim_noStim_OD_max(1), expectedOD, ...
    'AbsTol', 1e-12);
verifyTrue(testCase, isnan(prepared.stim_noStim_OD_max(2)));
verifyEqual(testCase, audit.IndexStatus, ...
    ["Success"; "SkippedInputStatus"]);
verifyEqual(testCase, audit.ValidPairs_Combined, [6; 0]);
end


function testRejectsUnexpectedCueOrderPerRow(testCase)
[meanTuning, semTuning, countTuning, coherence] = makeTuning();

Date = datetime(2024, 1, 2);
Monkey = "Jim";
StimElec = 2;
NChannels = 2;
stim_tuning_status = "Success";
stim_tuning_mean_noStim = {meanTuning};
stim_tuning_SEM_noStim = {semTuning};
stim_tuning_n_noStim = {countTuning};
stim_tuning_coherence = {coherence};
stim_tuning_condition_names = ...
    {["Combined", "MonoR", "MonoL", "Binocular"]};
unit_table_stim = table(Date, Monkey, StimElec, NChannels, stim_tuning_status, ...
    stim_tuning_mean_noStim, stim_tuning_SEM_noStim, ...
    stim_tuning_n_noStim, stim_tuning_coherence, ...
    stim_tuning_condition_names);

[prepared, audit] = ...
    PrepareStimNoStimPopulationAIOD(unit_table_stim);

verifyEqual(testCase, prepared.stim_noStim_index_status, ...
    "CalculationError");
verifyTrue(testCase, contains(audit.Message, ...
    "StimNoStimPopulationAIOD:UnexpectedCueOrder"));
verifyTrue(testCase, all(isnan(prepared.stim_noStim_AI{1})));
end


function testFlagsFiniteAIWithIncompletePairSupport(testCase)
[meanTuning, semTuning, countTuning, coherence] = makeTuning();
missingPositiveColumn = find(coherence > 0, 1, 'first');
meanTuning(4, missingPositiveColumn, 2) = NaN;
semTuning(4, missingPositiveColumn, 2) = NaN;
countTuning(4, missingPositiveColumn, 2) = 0;

Date = datetime(2024, 1, 2);
Monkey = "Jim";
StimElec = 2;
NChannels = 2;
stim_tuning_status = "Success";
stim_tuning_mean_noStim = {meanTuning};
stim_tuning_SEM_noStim = {semTuning};
stim_tuning_n_noStim = {countTuning};
stim_tuning_coherence = {coherence};
stim_tuning_condition_names = ...
    {["Combined", "MonoL", "MonoR", "Binocular"]};
unit_table_stim = table(Date, Monkey, StimElec, NChannels, ...
    stim_tuning_status, stim_tuning_mean_noStim, ...
    stim_tuning_SEM_noStim, stim_tuning_n_noStim, ...
    stim_tuning_coherence, stim_tuning_condition_names);

[prepared, audit] = ...
    PrepareStimNoStimPopulationAIOD(unit_table_stim);

verifyEqual(testCase, prepared.stim_noStim_index_status, ...
    "PartialSupport");
verifyEqual(testCase, audit.ValidPairs_Stereo, 5);
verifyTrue(testCase, isfinite(prepared.stim_noStim_AI{1}(4)));
end


function testMissingSourceColumnFailsBeforeRows(testCase)
unit_table_stim = table(datetime(2024, 1, 2), "Jim", 1, ...
    'VariableNames', {'Date', 'Monkey', 'StimElec'});
verifyError(testCase, @() PrepareStimNoStimPopulationAIOD( ...
    unit_table_stim), 'StimNoStimPopulationAIOD:MissingVariables');
end


function [meanTuning, semTuning, countTuning, coherence] = makeTuning()
coherence = [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22] ./ 22;
meanTuning = nan(4, 13, 2);
semTuning = repmat(0.5, 4, 13, 2);
countTuning = repmat(4, 4, 13, 2);
for channel = 1:2
    for cue = 1:4
        meanTuning(cue, :, channel) = ...
            20 + cue + channel + (1:13) .* (cue - 2.5);
    end
end
end

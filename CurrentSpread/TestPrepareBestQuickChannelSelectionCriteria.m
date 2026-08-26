function tests = TestPrepareBestQuickChannelSelectionCriteria
%TESTPREPAREBESTQUICKCHANNELSELECTIONCRITERIA Synthetic cache regression test.
tests = functiontests(localfunctions);
end


function testRecomputesPAndZAtSelectedChannel(testCase)
temporaryDirectory = string(tempname);
mkdir(temporaryDirectory);
cleanup = onCleanup(@() rmdir(temporaryDirectory, 's'));

coherence = [-22 -14 -10 -8 -4 -2 2 4 8 10 14 22] ./ 22;
trialCount = 5;
Neuro.Means = nan(4, 12, 2);
Neuro.All = nan(4, 12, trialCount, 2);
Neuro.Trials.NumTrials = repmat(trialCount, 4, 12);
for channel = 1:2
    for cue = 1:4
        directionGain = (channel - 1) * (cue + 3) * 3;
        for coherenceIndex = 1:12
            values = 20 + abs(coherence(coherenceIndex)) + ...
                directionGain * sign(coherence(coherenceIndex)) + ...
                linspace(-0.2, 0.2, trialCount);
            Neuro.All(cue, coherenceIndex, :, channel) = values;
            Neuro.Means(cue, coherenceIndex, channel) = mean(values);
        end
    end
end
Neuro.CoherenceArray = coherence;
Monocularity.Max = [-0.1 0.2];
save(fullfile(temporaryDirectory, '20240102.mat'), ...
    'Neuro', 'Monocularity');

Date = datetime(2024, 1, 2);
Monkey = "Jim";
NChannels = 2;
best_quick_channel = 2;
p_AI = {[0.8; 0.8; 0.8; 0.8]};
Z3D_v_Z2D = {5};
tuningMean13 = nan(4, 13, 2);
tuningMean13(:, [1:6 8:13], :) = Neuro.Means;
tuning_mean = {tuningMean13};
unitTable = table(Date, Monkey, NChannels, best_quick_channel, ...
    p_AI, Z3D_v_Z2D, tuning_mean);

[prepared, audit] = PrepareBestQuickChannelSelectionCriteria( ...
    unitTable, JimCacheFolder=temporaryDirectory, ...
    ClayCacheFolder=temporaryDirectory);

verifyEqual(testCase, audit.Status, "Success");
verifyLessThan(testCase, prepared.p_AI{1}(2), 0.05);
verifyLessThan(testCase, prepared.p_AI{1}(3), 0.05);
verifyEqual(testCase, prepared.p_AI{1}, prepared.best_quick_p_AI{1});
verifyEqual(testCase, prepared.Z3D_v_Z2D{1}, ...
    prepared.best_quick_Z3D_v_Z2D(1));
verifyTrue(testCase, audit.BestChannelTuningGatePass);
verifyTrue(testCase, audit.TuningGateChanged);
verifyEqual(testCase, audit.MaxQuickTuningDifference, 0, ...
    'AbsTol', 1e-12);

unitTable.best_quick_OD_dominant_eye = "R";
[preparedSelectedEye, auditSelectedEye] = ...
    PrepareBestQuickChannelSelectionCriteria(unitTable, ...
    JimCacheFolder=temporaryDirectory, ...
    ClayCacheFolder=temporaryDirectory, ...
    DominantEyeMethod="SelectedOD");
verifyEqual(testCase, auditSelectedEye.Status, "Success");
verifyEqual(testCase, auditSelectedEye.DominantEyeMethod, "SelectedOD");
verifyEqual(testCase, auditSelectedEye.SelectedDominantEye, "R");
verifyEqual(testCase, ...
    preparedSelectedEye.best_quick_selection_dominant_eye, "R");
clear cleanup
end

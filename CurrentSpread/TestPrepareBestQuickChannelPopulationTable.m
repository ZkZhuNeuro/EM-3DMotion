function tests = TestPrepareBestQuickChannelPopulationTable
%TESTPREPAREBESTQUICKCHANNELPOPULATIONTABLE Synthetic regression tests.
tests = functiontests(localfunctions);
end


function testSelectedQuickAIAndODReplacePopulationReadout(testCase)
StimElec = [2; 1];
NChannels = [3; 3];
AI = {reshape(1:12, 4, 3); reshape(21:32, 4, 3)};
OD_max = {0.1; -0.2};
OD_max_all = {[0.3 0.1 -0.8]; [-0.5 0.2 0.7]};
OD_max_eye = {'L'; 'R'};
tuning_mean = {makeQuickTuning([0.3 0.1 -0.8]); ...
    makeQuickTuning([-0.5 0.2 0.7])};
p_AI = {[1 0.01 0.02 1]; [1 0.03 0.04 1]};
Z3D_v_Z2D = {-2; 3};
unitTable = table(StimElec, NChannels, AI, OD_max, OD_max_all, ...
    OD_max_eye, tuning_mean, p_AI, Z3D_v_Z2D);

UnitTableRow = [1; 2];
BestChannel = [3; 2];
BestSSE = [0.4; 0.7];
Status = ["Success"; "Success"];
summary = table(UnitTableRow, BestChannel, BestSSE, Status);

[prepared, audit] = PrepareBestQuickChannelPopulationTable( ...
    unitTable, summary, "SSE", "BestSSE");

verifyEqual(testCase, prepared.StimElec, StimElec);
verifyEqual(testCase, prepared.AI{1}(:, 2), unitTable.AI{1}(:, 3));
verifyEqual(testCase, prepared.AI{2}(:, 1), unitTable.AI{2}(:, 2));
verifyEqual(testCase, prepared.OD_max, {-0.8; 0.2});
verifyEqual(testCase, prepared.OD_max_eye, {'R'; 'L'});
verifyEqual(testCase, prepared.p_AI, p_AI);
verifyEqual(testCase, prepared.Z3D_v_Z2D, Z3D_v_Z2D);
verifyEqual(testCase, prepared.best_quick_channel, BestChannel);
verifyEqual(testCase, prepared.best_quick_AI, ...
    {unitTable.AI{1}(:, 3); unitTable.AI{2}(:, 2)});
verifyEqual(testCase, prepared.best_quick_OD_max, [-0.8; 0.2], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, audit.Status, repmat("Success", 2, 1));
verifyEqual(testCase, audit.SelectionMetric, BestSSE);
verifyEqual(testCase, audit.ODRecalculationResidual, zeros(2, 1), ...
    'AbsTol', 1e-12);
end


function testFailedSelectionCannotFallBackToStimChannel(testCase)
StimElec = 2;
NChannels = 3;
AI = {reshape(1:12, 4, 3)};
OD_max = {0.1};
OD_max_all = {[0.3 0.1 -0.8]};
tuning_mean = {makeQuickTuning([0.3 0.1 -0.8])};
unitTable = table(StimElec, NChannels, AI, OD_max, OD_max_all, ...
    tuning_mean);

UnitTableRow = 1;
BestChannel = NaN;
BestPearsonR = NaN;
Status = "Error";
summary = table(UnitTableRow, BestChannel, BestPearsonR, Status);

[prepared, audit] = PrepareBestQuickChannelPopulationTable( ...
    unitTable, summary, "Correlation", "BestPearsonR");

verifyTrue(testCase, all(isnan(prepared.AI{1}(:, StimElec))));
verifyTrue(testCase, isnan(prepared.OD_max{1}));
verifyEqual(testCase, audit.Status, "SelectionNotSuccessful");
end


function testStoredODMismatchDoesNotOverrideQuickTuning(testCase)
StimElec = 1;
NChannels = 2;
AI = {reshape(1:8, 4, 2)};
OD_max = {0.2};
OD_max_all = {[0.2 0.9]};
tuning_mean = {makeQuickTuning([0.2 -0.4])};
unitTable = table(StimElec, NChannels, AI, OD_max, OD_max_all, ...
    tuning_mean);

UnitTableRow = 1;
BestChannel = 2;
BestSSE = 1;
Status = "Success";
summary = table(UnitTableRow, BestChannel, BestSSE, Status);

[prepared, audit] = PrepareBestQuickChannelPopulationTable( ...
    unitTable, summary, "SSE", "BestSSE");

verifyEqual(testCase, prepared.best_quick_OD_max, -0.4, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, prepared.OD_max, {-0.4}, 'AbsTol', 1e-12);
verifyEqual(testCase, audit.StoredSelectedODMaxAll, 0.9);
verifyEqual(testCase, audit.ODRecalculationResidual, -1.3, ...
    'AbsTol', 1e-12);
verifyTrue(testCase, contains(audit.Message, ...
    "Using tuning_mean-derived OD"));
end


function testLSQODUsesClosestPerspectiveAndAbsoluteModelWeight(testCase)
StimElec = 1;
NChannels = 1;
AI = {reshape(1:4, 4, 1)};
OD_max = {0};
OD_max_all = {0};
OD_max_eye = {'N'};
tuning = nan(4, 13, 1);
combined = 10:22;
left = combined + 0.1;
right = 2 .* combined;
tuning(1, :, 1) = combined;
tuning(2, :, 1) = left;
tuning(3, :, 1) = right;
tuning(4, :, 1) = combined + 2;
tuning_mean = {tuning};
unitTable = table(StimElec, NChannels, AI, OD_max, OD_max_all, ...
    OD_max_eye, tuning_mean);

UnitTableRow = 1;
BestChannel = 1;
BestSSE = 0;
Status = "Success";
summary = table(UnitTableRow, BestChannel, BestSSE, Status);

[prepared, audit] = PrepareBestQuickChannelPopulationTable( ...
    unitTable, summary, "SSE", "BestSSE", "LSQ");

support = [1:6 8:13];
leftError = sum((combined(support) - left(support)) .^ 2);
rightError = sum((combined(support) - right(support)) .^ 2);
expectedMagnitude = abs(leftError - rightError) ./ ...
    (leftError + rightError);

verifyEqual(testCase, prepared.OD_max{1}, expectedMagnitude, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, prepared.OD_max_eye{1}, 'L');
verifyEqual(testCase, prepared.best_quick_OD_magnitude, ...
    expectedMagnitude, 'AbsTol', 1e-12);
verifyEqual(testCase, prepared.best_quick_OD_signed_for_eye, ...
    expectedMagnitude, 'AbsTol', 1e-12);
verifyEqual(testCase, prepared.best_quick_OD_dominant_eye, "L");
verifyLessThan(testCase, prepared.best_quick_OD_lsq_raw, 0);
verifyLessThan(testCase, prepared.best_quick_OD_max, 0);
verifyTrue(testCase, prepared.best_quick_OD_dominance_changed_from_max);
verifyEqual(testCase, audit.SelectedODMagnitudeForModel, ...
    expectedMagnitude, 'AbsTol', 1e-12);
verifyEqual(testCase, audit.SelectedODDominantEye, "L");
end


function tuning = makeQuickTuning(odValues)
coherenceCount = 13;
channelCount = numel(odValues);
tuning = nan(4, coherenceCount, channelCount);
for channel = 1:channelCount
    rightMaximum = 10;
    leftMaximum = rightMaximum .* ...
        (1 + odValues(channel)) ./ (1 - odValues(channel));
    tuning(1, :, channel) = 5 + (1:coherenceCount);
    tuning(2, :, channel) = linspace(1, leftMaximum, coherenceCount);
    tuning(3, :, channel) = linspace(1, rightMaximum, coherenceCount);
    tuning(4, :, channel) = 3 + (1:coherenceCount);
end
end

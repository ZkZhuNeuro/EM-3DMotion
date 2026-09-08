function tests = TestCalculateStimChannelPopulationReference
%TESTCALCULATESTIMCHANNELPOPULATIONREFERENCE Verify fixed-StimElec inputs.
tests = functiontests(localfunctions);
end


function setupOnce(testCase)
currentSpreadFolder = fileparts(mfilename('fullpath'));
commonFolder = fullfile(currentSpreadFolder, '02_gaussian', ...
    'interactive_population', 'common');
addpath(commonFolder);
testCase.TestData.CommonFolder = commonFolder;
end


function teardownOnce(testCase)
rmpath(testCase.TestData.CommonFolder);
end


function testCorrelationMatchesStimChannelFisherZDefinition(testCase)
unitTable = makeUnitTable();

actual = calculateStimChannelPopulationReference( ...
    unitTable, 1, "Correlation");

combined = [1 2 4 3 6];
left = [1.2 2.1 3.8 3.2 5.9];
right = [6 2 5 1 4];
expectedOD = atanh(corr(combined', left')) - ...
    atanh(corr(combined', right'));
verifyEqual(testCase, actual.StimChannel, 2);
verifyEqual(testCase, actual.AI, [0.2 0.4 0.6 0.8], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, actual.OD, expectedOD, 'AbsTol', 1e-12);
verifyEqual(testCase, actual.Z3DMinusZ2D, -2.5);
verifyEqual(testCase, actual.CommonSupportCount, 5);
verifyTrue(testCase, actual.Valid);
end


function testCommonFiniteSupportMatchesPopulationPath(testCase)
unitTable = makeUnitTable();
tuning = unitTable.tuning_mean{1};
tuning(1, 5, 2) = NaN;
tuning(2, 5, 2) = 1e6;
unitTable.tuning_mean{1} = tuning;

actual = calculateStimChannelPopulationReference( ...
    unitTable, 1, "Correlation");

combined = [1 2 4 3];
left = [1.2 2.1 3.8 3.2];
right = [6 2 5 1];
expectedOD = atanh(corr(combined', left')) - ...
    atanh(corr(combined', right'));
verifyEqual(testCase, actual.OD, expectedOD, 'AbsTol', 1e-12);
verifyEqual(testCase, actual.CommonSupportCount, 4);
end


function testReferenceUsesStoredClassAndAI(testCase)
unitTable = makeUnitTable();

actual = calculateStimChannelPopulationReference( ...
    unitTable, 2, "Correlation");

verifyEqual(testCase, actual.StimChannel, 1);
verifyEqual(testCase, actual.AI, [-0.1 -0.2 -0.3 -0.4], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, actual.Z3DMinusZ2D, 3.25);
verifyTrue(testCase, actual.Valid);
end


function unitTable = makeUnitTable()
StimElec = [2; 1];
AI = cell(2, 1);
AI{1} = [0.1 0.2 0.3; 0.2 0.4 0.6; ...
    0.3 0.6 0.9; 0.4 0.8 1.2];
AI{2} = [-0.1 0.1; -0.2 0.2; -0.3 0.3; -0.4 0.4];
tuning_mean = cell(2, 1);
tuning_mean{1} = zeros(4, 5, 3);
tuning_mean{1}(1, :, 2) = [1 2 4 3 6];
tuning_mean{1}(2, :, 2) = [1.2 2.1 3.8 3.2 5.9];
tuning_mean{1}(3, :, 2) = [6 2 5 1 4];
tuning_mean{2} = zeros(4, 5, 2);
tuning_mean{2}(1, :, 1) = [1 2 4 3 6];
tuning_mean{2}(2, :, 1) = [6 2 5 1 4];
tuning_mean{2}(3, :, 1) = [1.2 2.1 3.8 3.2 5.9];
Z3D_v_Z2D = [-2.5; 3.25];
unitTable = table(StimElec, AI, tuning_mean, Z3D_v_Z2D);
end

function tests = TestCalculateGaussianMetaOD
%TESTCALCULATEGAUSSIANMETAOD Verify maximum and correlation definitions.
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


function testCorrelationODSignAndMagnitude(testCase)
raw = nan(4, 4, 2);
raw(1, :, 1) = [1 2 3 4];
raw(2, :, 1) = [1 2 3 4];
raw(3, :, 1) = [4 3 2 1];
raw(1, :, 2) = [1 2 3 4];
raw(2, :, 2) = [4 3 2 1];
raw(3, :, 2) = [1 2 3 4];
counts = ones(4, 4);

actual = calculateGaussianMetaOD(raw, counts, "Correlation");

expected = 2 .* atanh(1 - eps);
verifyEqual(testCase, actual, [expected -expected], 'AbsTol', 1e-10);
end


function testCorrelationUsesCommonFiniteSupport(testCase)
raw = nan(4, 5);
raw(1, :) = [1 2 3 4 NaN];
raw(2, :) = [1 2 3 4 100];
raw(3, :) = [4 3 2 1 -100];
counts = ones(4, 5);

actual = calculateGaussianMetaOD(raw, counts, "Correlation");

expected = 2 .* atanh(1 - eps);
verifyEqual(testCase, actual, expected, 'AbsTol', 1e-10);
end


function testCorrelationRejectsConstantCurve(testCase)
raw = nan(4, 4);
raw(1, :) = [1 2 3 4];
raw(2, :) = [5 5 5 5];
raw(3, :) = [4 3 2 1];
counts = ones(4, 4);

actual = calculateGaussianMetaOD(raw, counts, "Correlation");

verifyTrue(testCase, isnan(actual));
end


function testMaximumODPreservesExistingDefinition(testCase)
raw = nan(4, 4);
raw(1, :) = [1 2 3 4];
raw(2, :) = [1 3 5 2];
raw(3, :) = [1 2 3 3];
counts = ones(4, 4);

actual = calculateGaussianMetaOD(raw, counts, "Max");

verifyEqual(testCase, actual, (5 - 3) / (5 + 3), ...
    'AbsTol', 1e-12);
end


function testRMSEODSignAndMagnitude(testCase)
raw = nan(4, 4, 2);
raw(1, :, 1) = [1 2 3 4];
raw(2, :, 1) = [1 2 3 4];
raw(3, :, 1) = [4 3 2 1];
raw(1, :, 2) = [1 2 3 4];
raw(2, :, 2) = [4 3 2 1];
raw(3, :, 2) = [1 2 3 4];
counts = ones(4, 4);

actual = calculateGaussianMetaOD(raw, counts, "RMSE");

verifyEqual(testCase, actual, [1 -1], 'AbsTol', 1e-12);
end


function testPartialCorrelationODSign(testCase)
combined = [1 2 4 3 5 7];
left = combined + [0.1 -0.1 0.2 -0.2 0.1 -0.1];
right = [7 2 5 1 4 3];
raw = nan(4, numel(combined), 2);
raw(1, :, 1) = combined;
raw(2, :, 1) = left;
raw(3, :, 1) = right;
raw(1, :, 2) = combined;
raw(2, :, 2) = right;
raw(3, :, 2) = left;
counts = ones(4, numel(combined));

actual = calculateGaussianMetaOD(raw, counts, "PartialCorrelation");

verifyGreaterThan(testCase, actual(1), 0);
verifyLessThan(testCase, actual(2), 0);
verifyEqual(testCase, actual(1), -actual(2), 'AbsTol', 1e-10);
end

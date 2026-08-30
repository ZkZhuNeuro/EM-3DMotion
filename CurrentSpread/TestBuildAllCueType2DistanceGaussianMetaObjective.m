function tests = TestBuildAllCueType2DistanceGaussianMetaObjective
%TESTBUILDALLCUETYPE2DISTANCEGAUSSIANMETAOBJECTIVE Synthetic objective tests.
tests = functiontests(localfunctions);
end


function setupOnce(~)
projectFolder = fileparts(mfilename('fullpath'));
interactiveFolder = fullfile(projectFolder, '02_gaussian', ...
    'interactive_population');
addpath(fullfile(interactiveFolder, 'common'), ...
    fullfile(interactiveFolder, 'type2_distance'));
end


function testCueWiseMeansAndOrthogonalDistance(testCase)
testFolder = string(tempname);
mkdir(testFolder);
cleanup = onCleanup(@() removeTestFolder(testFolder));
cacheFile = fullfile(testFolder, 'synthetic_cache.mat');
outputFolder = fullfile(testFolder, 'output');

cache = makeSyntheticCache();
save(cacheFile, 'cache');
result = BuildAllCueType2DistanceGaussianMetaObjective( ...
    CacheFile=cacheFile, OutputFolder=outputFolder, FigureVisible=false);

expectedPerCue = [0 1 0.5; 1 0 0.5; 1 0 0.5; 1 0 0.5];
verifyEqual(testCase, result.PerCueMeanSquaredDistance, ...
    expectedPerCue, 'AbsTol', 1e-12);
verifyEqual(testCase, result.SumFourCueMeanSquaredDistance, ...
    [3; 1; 2], 'AbsTol', 1e-12);
verifyEqual(testCase, result.BestIndex, 2);
verifyEqual(testCase, result.BestSigma, 1);
verifyEqual(testCase, result.BestPerCuePointCount, [4; 1; 1; 1]);
verifyTrue(testCase, isfile(fullfile(outputFolder, ...
    'AllCueType2DistanceGaussianMetaObjective.csv')));
verifyTrue(testCase, isfile(fullfile(outputFolder, ...
    'AllCueType2DistanceGaussianMetaOptimization.mat')));
end


function cache = makeSyntheticCache()
numSessions = 4;
numConditions = 4;
numSigmas = 3;
cache = struct();
cache.SigmaValues = [0.1 1 10];
cache.PointAI = zeros(numSessions, numConditions, numSigmas);
cache.PointBias = nan(numSessions, numConditions, numSigmas);
cache.PointValid = false(numSessions, numConditions, numSigmas);

cache.PointBias(:, 1, 1) = 0;
cache.PointValid(:, 1, 1) = true;
cache.PointBias(1, 2:4, 1) = 1;
cache.PointValid(1, 2:4, 1) = true;

cache.PointBias(:, 1, 2) = 1;
cache.PointValid(:, 1, 2) = true;
cache.PointBias(1, 2:4, 2) = 0;
cache.PointValid(1, 2:4, 2) = true;

cache.PointBias(1, :, 3) = 1;
cache.PointValid(1, :, 3) = true;

cache.ConditionColors = lines(4);
cache.Statistics = struct();
cache.Statistics.WeightedSlope = [zeros(4, 2), ones(4, 1)];
cache.Statistics.WeightedIntercept = zeros(4, numSigmas);
cache.Statistics.N2DSessions = [4; 4; 1];
cache.Statistics.N3DSessions = zeros(numSigmas, 1);
end


function removeTestFolder(folder)
if isfolder(folder)
    rmdir(folder, 's');
end
end

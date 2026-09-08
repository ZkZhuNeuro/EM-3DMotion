function tests = TestGaussianChannelBiasPrediction
%TESTGAUSSIANCHANNELBIASPREDICTION Channel-first model regression tests.
tests = functiontests(localfunctions);
end


function setupOnce(testCase)
folder = fullfile(fileparts(mfilename('fullpath')), '02_gaussian', ...
    'interactive_population', 'channel_prediction');
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
end


function testViewerUsesFullWidthAndResizes(testCase)
folder = string(tempname);
mkdir(folder);
folderCleanup = onCleanup(@() removeTestFolder(folder));
objective = struct();
objective.SchemaVersion = 2;
objective.CueFrame = "ChannelLocalDomNonDom";
objective.Area = "MT";
objective.UnitType = "2D";
objective.ODDefinition = "Max";
objective.SessionCount = 2;
objective.EffectiveChannels = ones(2, 3);
objective.SigmaValues = [0.01; 0.7; 10];
objective.BestSigma = 0.7;
objective.MeanCVMSE = [0.3; 0.2; 0.4];
objective.PerCueMeanCVMSE = repmat([0.3 0.2 0.4], 4, 1);
objective.PerCueMeanCVR2 = repmat([0.1 0.3 -0.2], 4, 1);
objective.ConditionNames = ["Dominant", "Combined", "Stereo", "NonDominant"];
objective.Observed = [-1; 0.5; -0.8; 0.3; -0.4; 0.6; -0.2; 0.9];
objective.HeldOutPrediction = objective.Observed .* [0.6 0.9 0.4];
objective.ObservationMap = table(repelem((1:4)', 2), ...
    repmat(["Jim"; "Clay"], 4, 1), repmat([0.4; -0.6], 4, 1), ...
    'VariableNames', {'ConditionIndex', 'Monkey', 'BehaviorReferenceSignedOD'});
gaussian_channel_bias_prediction = objective;
objectiveFile = fullfile(folder, 'objective.mat');
save(objectiveFile, 'gaussian_channel_bias_prediction');
viewer = ExploreGaussianChannelBiasPrediction( ...
    ObjectiveFile=objectiveFile, Visible="off");
figureCleanup = onCleanup(@() delete(viewer.Figure));

axesHandles = findall(viewer.Figure, 'Type', 'axes');
verifyNumElements(testCase, axesHandles, 3);
plotGrid = viewer.PopulationAxes.Parent;
verifyEqual(testCase, plotGrid.ColumnWidth, {'3x', '1.15x'});
verifyEqual(testCase, viewer.PopulationAxes.Layout.Row, 1);
verifyEqual(testCase, viewer.PopulationAxes.Layout.Column, 1);
verifyEqual(testCase, viewer.ControlGrid.Layout.Row, 2);
verifyEqual(testCase, viewer.ControlGrid.Layout.Column, [1 2]);
verifyEqual(testCase, viewer.Slider.Parent, viewer.ControlGrid);
verifyEqual(testCase, viewer.Slider.Layout.Column, [1 4]);
windowSizes = [1540 930; 1100 740];
for index = 1:size(windowSizes, 1)
    viewer.Figure.Position = [40 40 windowSizes(index, :)];
    drawnow
    for axesIndex = 1:numel(axesHandles)
        bounds = getpixelposition(axesHandles(axesIndex));
        verifyGreaterThan(testCase, bounds(3), 200, ...
            'Each plot must receive a usable width, not a pixel-sized column.');
        verifyGreaterThan(testCase, bounds(4), 90);
    end
end
viewer.SetSigma(10);
verifyEqual(testCase, viewer.Slider.Value, 3);
verifyEqual(testCase, viewer.PopulationAxes.Legend.String(1:4), ...
    cellstr(objective.ConditionNames));
verifyEqual(testCase, viewer.ScatterHandles(1, 1).YData, ...
    objective.Observed(1));
verifyEqual(testCase, viewer.ScatterHandles(4, 2).YData, ...
    objective.Observed(8));
viewer.DotSizeSlider.ValueChangedFcn(viewer.DotSizeSlider, struct('Value', 75));
settings = viewer.GetDisplaySettings();
verifyEqual(testCase, settings.MarkerSize, 75);
verifyEqual(testCase, viewer.ScatterHandles(1, 1).SizeData, 75);
end


function testViewerRejectsOldPhysicalEyeResults(testCase)
folder = string(tempname);
mkdir(folder);
cleanup = onCleanup(@() removeTestFolder(folder));
gaussian_channel_bias_prediction = struct('SchemaVersion', 1);
objectiveFile = fullfile(folder, 'old.mat');
save(objectiveFile, 'gaussian_channel_bias_prediction');
verifyError(testCase, @() ExploreGaussianChannelBiasPrediction( ...
    ObjectiveFile=objectiveFile, Visible="off"), ...
    'GaussianChannelPrediction:ObjectiveRequiresRebuild');
end


function testLocalEyeAssignmentOccursBeforeAveraging(testCase)
channelAI = zeros(1, 4, 2);
channelAI(1, :, 1) = [1 2 3 4];
channelAI(1, :, 2) = [5 6 7 8];
signedOD = [0.5 -0.25];
eligible = true(1, 2);
positions = [0 0];
behavior = [10 20 30 40];
behaviorValid = true(1, 4);

[design, observed, map, weights] = buildGaussianChannelPredictionDesign( ...
    channelAI, signedOD, eligible, positions, behavior, behaviorValid, 0.5, 1);

verifyEqual(testCase, weights, [0.5 0.5], 'AbsTol', 1e-12);
domRow = find(map.ConditionIndex == 1);
nonDomRow = find(map.ConditionIndex == 4);
% Dominant pools channel 1's left eye and channel 2's right eye.
verifyEqual(testCase, design(domRow, 1:3), ...
    [1 4.5 1.375], 'AbsTol', 1e-12);
verifyEqual(testCase, design(domRow, 4:12), zeros(1, 9), ...
    'AbsTol', 1e-12);
% NonDominant pools channel 1's right eye and channel 2's left eye.
verifyEqual(testCase, design(nonDomRow, 10:12), ...
    [1 4.5 1.5], 'AbsTol', 1e-12);
verifyEqual(testCase, design(nonDomRow, 1:9), zeros(1, 9), ...
    'AbsTol', 1e-12);
verifyEqual(testCase, observed, [20; 10; 40; 30]);
verifyEqual(testCase, map.BehaviorSourceCueIndex, [2; 1; 4; 3]);
% Behavior reference is independent of the contributing channel dominance.
[rightDesign, rightObserved] = buildGaussianChannelPredictionDesign( ...
    channelAI, signedOD, eligible, positions, behavior, behaviorValid, -0.5, 1);
verifyEqual(testCase, rightDesign, design);
verifyEqual(testCase, rightObserved, [30; 10; 40; 20]);
% Exchanging all physical eye labels must leave the local-condition model
% and targets unchanged when OD signs are exchanged consistently.
[swappedDesign, swappedObserved] = buildGaussianChannelPredictionDesign( ...
    channelAI(:, [1 3 2 4], :), -signedOD, eligible, positions, ...
    behavior(:, [1 3 2 4]), behaviorValid, -0.5, 1);
verifyEqual(testCase, swappedDesign, design);
verifyEqual(testCase, swappedObserved, observed);
end


function testIneligibleChannelsAreExcludedAndWeightsRenormalized(testCase)
channelAI = reshape(1:12, 1, 4, 3);
signedOD = [0.4 -0.3 0.2];
eligible = [false true false];
positions = [-1 0 1];
behavior = zeros(1, 4);
behaviorValid = true(1, 4);

[~, ~, ~, weightsNarrow] = buildGaussianChannelPredictionDesign( ...
    channelAI, signedOD, eligible, positions, behavior, behaviorValid, 0.4, 0.1);
[~, ~, ~, weightsWide] = buildGaussianChannelPredictionDesign( ...
    channelAI, signedOD, eligible, positions, behavior, behaviorValid, 0.4, 10);

verifyEqual(testCase, weightsNarrow, [0 1 0], 'AbsTol', 1e-12);
verifyEqual(testCase, weightsWide, [0 1 0], 'AbsTol', 1e-12);
end


function testSigmaAndBetaRecoverChannelFirstGenerator(testCase)
[channelAI, signedOD, eligible, positions, behavior, behaviorValid, ...
    trueSigma, trueBeta, generated, behaviorOD] = generatedProblem();

result = fitGaussianChannelBiasModel( ...
    channelAI, signedOD, eligible, positions, behavior, behaviorValid, ...
    behaviorOD, [0.2 0.7 2.5], NumRepeats=2, NumFolds=5, RandomSeed=9);

verifyEqual(testCase, result.BestSigma, trueSigma, 'AbsTol', 1e-12);
verifyLessThan(testCase, result.BestCVMSE, 1e-20);
verifyEqual(testCase, result.BestFullBeta, trueBeta, 'AbsTol', 1e-9);
verifyEqual(testCase, result.BestFullPrediction, generated, ...
    'AbsTol', 1e-6);
verifyEqual(testCase, result.CueFrame, "ChannelLocalDomNonDom");
verifyEqual(testCase, result.MetricConditionNames, ...
    ["Dominant", "Combined", "Stereo", "NonDominant"]);
verifyEqual(testCase, result.MeanCVMSE, ...
    mean(result.PerCueMeanCVMSE, 1)', 'AbsTol', 1e-12);
end


function testObjectiveWritesAuditableArtifacts(testCase)
[channelAI, signedOD, eligible, positions, behavior, behaviorValid, ...
    trueSigma, ~, ~, behaviorOD] = generatedProblem();
numSessions = size(channelAI, 1);
folder = string(tempname);
mkdir(folder);
cleanup = onCleanup(@() removeTestFolder(folder));
cache = struct();
cache.SchemaVersion = 5;
cache.OutputFolder = folder;
cache.Area = "MT";
cache.ODDefinition = "Max";
cache.TuningAlpha = 0.05;
cache.SigmaValues = [0.2 0.7 2.5];
cache.SourceRows = (101:100 + numSessions)';
cache.Monkey = repmat("Jim", numSessions, 1);
cache.Date = repmat(datetime(2026, 1, 1), numSessions, 1);
cache.SessionStatus = repmat("Success", numSessions, 1);
cache.StimZ3DMinusZ2D = -ones(numSessions, 1);
cache.StimReferenceOD = behaviorOD;
cache.BehaviorByPhysicalCue = behavior;
cache.BehaviorValidByPhysicalCue = behaviorValid;
cache.ChannelNumbers = repmat(1:size(channelAI, 3), numSessions, 1);
cache.StimChannel = ones(numSessions, 1);
cache.StimChannelSourceP = 0.01 .* ones(numSessions, 4);
cache.ChannelAvailable = true(numSessions, size(channelAI, 3));
cache.ChannelRelativePositions = positions;
cache.ChannelAI = single(channelAI);
cache.ChannelSignedOD = single(signedOD);
cache.ChannelTuningP = single(0.01 .* ...
    ones(numSessions, 4, size(channelAI, 3)));
cache.ChannelEligibleForPrediction = eligible;
cacheFile = fullfile(folder, 'cache.mat');
save(cacheFile, 'cache');
outputFolder = fullfile(folder, 'result');

result = BuildGaussianChannelBiasPredictionObjective( ...
    CacheFile=cacheFile, OutputFolder=outputFolder, UnitType="2D", ...
    FigureVisible=false, FitMethod="CV", ...
    NumRepeats=2, NumFolds=5, RandomSeed=9);

verifyEqual(testCase, result.BestSigma, trueSigma, 'AbsTol', 1e-12);
verifyEqual(testCase, height(result.BetaTable), 12);
verifyEqual(testCase, height(result.PointTable), numSessions .* 4);
verifyTrue(testCase, ismember('CVMSE_Dominant', ...
    result.SigmaTable.Properties.VariableNames));
verifyFalse(testCase, ismember('CVMSE_MonoL', ...
    result.SigmaTable.Properties.VariableNames));
verifyTrue(testCase, ismember('WeightedContribution_NonDominant', ...
    result.WeightTable.Properties.VariableNames));
verifyTrue(testCase, isfile(fullfile(outputFolder, ...
    'GaussianChannelBiasPredictionOptimization.mat')));
verifyTrue(testCase, isfile(fullfile(outputFolder, ...
    'GaussianChannelBiasPredictionWeights.csv')));
verifyTrue(testCase, isfile(fullfile(outputFolder, ...
    'GaussianChannelBiasHeldOutPrediction.png')));
viewer = ExploreGaussianChannelBiasPrediction( ...
    ObjectiveFile=fullfile(outputFolder, ...
    'GaussianChannelBiasPredictionOptimization.mat'), ...
    Visible="off", InitialSigma=0.2);
viewer.SetSigma(trueSigma);
verifyTrue(testCase, isvalid(viewer.Figure));
close(viewer.Figure);
end


function [channelAI, signedOD, eligible, positions, behavior, ...
    behaviorValid, trueSigma, trueBeta, generated, behaviorOD] = generatedProblem()
rng(41);
numSessions = 60;
numPositions = 3;
channelAI = randn(numSessions, 4, numPositions);
signedOD = 0.15 + 0.8 .* rand(numSessions, numPositions);
negative = rand(numSessions, numPositions) < 0.5;
signedOD(negative) = -signedOD(negative);
signedOD(1:2:end, 1) = abs(signedOD(1:2:end, 1));
signedOD(2:2:end, 1) = -abs(signedOD(2:2:end, 1));
behaviorOD = signedOD(:, 1);
eligible = true(numSessions, numPositions);
positions = repmat([0 1 2], numSessions, 1);
behaviorValid = true(numSessions, 4);
placeholderBehavior = zeros(numSessions, 4);
trueSigma = 0.7;
trueBeta = [ ...
    0.2  0.8  0.35; ...
   -0.1  0.5 -0.20; ...
    0.05 0.3  0.15; ...
   -0.2 -0.6  0.25];
[design, ~, map] = buildGaussianChannelPredictionDesign( ...
    channelAI, signedOD, eligible, positions, placeholderBehavior, ...
    behaviorValid, behaviorOD, trueSigma);
generated = design * reshape(trueBeta', [], 1);
behavior = nan(numSessions, 4);
for row = 1:height(map)
    behavior(map.SessionIndex(row), map.BehaviorSourceCueIndex(row)) = ...
        generated(row);
end
end


function removeTestFolder(folder)
if isfolder(folder)
    rmdir(folder, 's');
end
end

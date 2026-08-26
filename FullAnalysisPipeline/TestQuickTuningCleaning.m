function tests = TestQuickTuningCleaning
%TESTQUICKTUNINGCLEANING Regression tests for Quick-tuning MAD cleaning.
tests = functiontests(localfunctions);
end


function testChannelSpecificOutlierRemoval(testCase)
trialCounts = 9 .* ones(4, 12);
firingRateHz = nan(4, 12, 9, 2);
ordinaryValues = [48 49 50 50 51 52 49 50 51];
for cue = 1:4
    for coherence = 1:12
        firingRateHz(cue, coherence, :, 1) = ...
            ordinaryValues + cue + coherence / 10;
        firingRateHz(cue, coherence, :, 2) = ...
            ordinaryValues + 20 + cue + coherence / 10;
    end
end
firingRateHz(2, 4, 9, 1) = 300;

result = CleanQuickBinnedResponses( ...
    firingRateHz, trialCounts, Threshold=3.5, MinimumTrials=5);

verifyTrue(testCase, result.OutlierMask(2, 4, 9, 1));
verifyFalse(testCase, result.OutlierMask(2, 4, 9, 2));
verifyEqual(testCase, result.Audit.OutlierObservationCount, 1);
verifyEqual(testCase, result.Audit.TrialWithAnyOutlierCount, 1);
verifyEqual(testCase, result.OriginalCount(2, 4, 1), 9);
verifyEqual(testCase, result.CleanedCount(2, 4, 1), 8);
verifyEqual(testCase, result.CleanedCount(2, 4, 2), 9);
verifyLessThan(testCase, result.CleanedMean(2, 4, 1), ...
    result.OriginalMean(2, 4, 1));
end


function testMinimumTrialAndZeroMADPolicies(testCase)
trialCounts = 4;
firingRateHz = reshape( ...
    [50 51 49 300; 50 51 49 300]', 1, 1, 4, 2);
result = CleanQuickBinnedResponses( ...
    firingRateHz, trialCounts, Threshold=3.5, MinimumTrials=5);
verifyEqual(testCase, result.Audit.OutlierObservationCount, 0);
verifyEqual(testCase, result.Audit.InsufficientTrialCellCount, 2);

trialCounts = 8;
firingRateHz = reshape( ...
    repmat([50 50 50 50 50 50 50 300]', 1, 2), 1, 1, 8, 2);
result = CleanQuickBinnedResponses( ...
    firingRateHz, trialCounts, Threshold=3.5, MinimumTrials=5);
verifyEqual(testCase, result.Audit.OutlierObservationCount, 0);
verifyEqual(testCase, result.Audit.ZeroMADCellCount, 2);
verifyEqual(testCase, result.Audit.Settings.ZeroMADPolicy, ...
    "retain all observations");
end


function testBuildTwoDResult(testCase)
trialCounts = 7 .* ones(8, 2, 3);
firingRateHz = nan(8, 2, 3, 7, 2);
ordinaryValues = [19 20 21 20 22 18 20];
for direction = 1:8
    for speed = 1:2
        for condition = 1:3
            for channel = 1:2
                firingRateHz(direction, speed, condition, :, channel) = ...
                    ordinaryValues + direction + speed + condition + channel;
            end
        end
    end
end
firingRateHz(5, 2, 3, 7, 2) = 250;
Neuro = struct('All', firingRateHz, ...
    'Trials', struct('NumTrials', trialCounts));

result = BuildQuickTuningCleaningResult( ...
    Neuro, "2DQuick", 2, Threshold=3.5, MinimumTrials=5);

verifySize(testCase, result.OriginalMean, [8 2 3 2]);
verifySize(testCase, result.CleanedMean, [8 2 3 2]);
verifySize(testCase, result.FiringRateOutlierMask, [8 2 3 7 2]);
verifyTrue(testCase, result.FiringRateOutlierMask(5, 2, 3, 7, 2));
verifyEqual(testCase, result.CleanedCount(5, 2, 3, 2), 6);
verifyEqual(testCase, result.Axes.DirectionDegrees, 0:45:315);
verifyEqual(testCase, result.Axes.SpeedDegreesPerSecond, ...
    [4.166667 12.5], 'AbsTol', 1e-8);
end


function testBuildZeroInclusiveThreeDResult(testCase)
Neuro = makeSyntheticNeuro([4 13], 7, 2);
result = BuildQuickTuningCleaningResult( ...
    Neuro, "3DQuick", 2, MinimumTrials=5);

verifySize(testCase, result.OriginalMean, [4 13 2]);
verifySize(testCase, result.CleanedMean, [4 13 2]);
verifyEqual(testCase, result.Axes.Coherence(7), 0);
verifyEqual(testCase, result.Axes.Coherence, ...
    [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22] ./ 22, ...
    'AbsTol', 1e-12);
end


function testDiscoverTaskPairs(testCase)
folder = string(tempname);
mkdir(folder);
cleanup = onCleanup(@() removeTestFolder(folder));

threeDStem = "Jim_Example_3DMotionQuick_MUA";
rapidStem = "Jim_Example_2DMotionQuick_MUA";
lateralStem = "Jim_Example_LateralMotion_MUA";
makeEmptyMAT(fullfile(folder, threeDStem + "_TInfo.mat"));
makeEmptyMAT(fullfile(folder, threeDStem + "_SelIndex.mat"));
makeEmptyMAT(fullfile(folder, rapidStem + "_TInfo.mat"));
makeEmptyMAT(fullfile(folder, rapidStem + "_SelIndex.mat"));
makeEmptyMAT(fullfile(folder, lateralStem + "_TInfo.mat"));
makeEmptyMAT(fullfile(folder, lateralStem + "_SelIndex.mat"));

late = DiscoverQuickTuningFiles(folder, ...
    threeDStem + "_TInfo.mat", datetime(2024, 1, 1));
verifyEqual(testCase, late.ThreeD.Extractor, ...
    "Offline_3DMotion_NoSaccade_v1_081421");
verifyEqual(testCase, late.TwoD.Variant, "2DMotionQuick");
verifyEqual(testCase, late.TwoD.Extractor, ...
    "Offline_Rapid2D_v1_051822");

early = DiscoverQuickTuningFiles(folder, ...
    threeDStem + "_TInfo.mat", datetime(2021, 1, 1));
verifyEqual(testCase, early.TwoD.Variant, "LateralMotion");
verifyEqual(testCase, early.TwoD.Extractor, ...
    "Offline_LateralMotion_Separate");
clear cleanup
removeTestFolder(folder);
end


function testComparisonFigures(testCase)
outputFolder = string(tempname);
mkdir(outputFolder);
cleanup = onCleanup(@() removeTestFolder(outputFolder));
sessionInfo = struct('Row', 1, 'Monkey', "Test", ...
    'DateLabel', "2024-01-01", 'DateFileText', "20240101", ...
    'StimChannel', 1);

threeDNeuro = makeSyntheticNeuro([4 12], 7, 2);
threeDResult = BuildQuickTuningCleaningResult( ...
    threeDNeuro, "3DQuick", 2, MinimumTrials=5);
files3D = PlotQuickTuningCleaningComparison( ...
    threeDResult, sessionInfo, outputFolder);
verifyNumElements(testCase, files3D, 1);
verifyTrue(testCase, isfile(files3D(1)));

twoDNeuro = makeSyntheticNeuro([8 2 3], 7, 2);
twoDResult = BuildQuickTuningCleaningResult( ...
    twoDNeuro, "2DQuick", 2, MinimumTrials=5);
files2D = PlotQuickTuningCleaningComparison( ...
    twoDResult, sessionInfo, outputFolder);
verifyNumElements(testCase, files2D, 2);
verifyTrue(testCase, all(isfile(files2D)));
clear cleanup
removeTestFolder(outputFolder);
end


function Neuro = makeSyntheticNeuro(cellSize, trialCount, channelCount)
storageSize = [cellSize trialCount channelCount];
values = nan(storageSize);
cellCount = prod(cellSize);
values = reshape(values, cellCount, trialCount, channelCount);
ordinaryValues = 20 + [0 1 -1 2 -2 1 0];
for cellIndex = 1:cellCount
    for channel = 1:channelCount
        values(cellIndex, :, channel) = ...
            ordinaryValues + cellIndex / 10 + channel;
    end
end
values = reshape(values, storageSize);
Neuro = struct('All', values, ...
    'Trials', struct('NumTrials', trialCount .* ones(cellSize)));
end


function makeEmptyMAT(path)
placeholder = true;
save(path, 'placeholder');
end


function removeTestFolder(folder)
if isfolder(folder)
    rmdir(folder, 's');
end
end

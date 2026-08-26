function tests = TestQuickAIComparison
%TESTQUICKAICOMPARISON Tests for original-versus-cleaned Quick AI plots.
tests = functiontests(localfunctions);
end


function testLegacyAIDefinition(testCase)
[meanTuning, semTuning, countTuning, coherence] = ...
    makeTuningInputs(10, 12);
[AI, details] = CalculateQuickTuningAI( ...
    meanTuning, semTuning, countTuning, coherence);

verifyEqual(testCase, AI, (2 / 3) .* ones(4, 2), ...
    'AbsTol', 1e-12);
verifyEqual(testCase, details.ValidPairCount, 6 .* ones(4, 2));
verifyEqual(testCase, details.CoherencePairMagnitudes, 1:6);
end


function testZeroCoherenceIsIgnored(testCase)
[meanTuning, semTuning, countTuning, ~] = ...
    makeTuningInputs(10, 12);
meanTuning = cat(2, meanTuning(:, 1:6, :), ...
    1e6 .* ones(4, 1, 2), meanTuning(:, 7:12, :));
semTuning = cat(2, semTuning(:, 1:6, :), ...
    zeros(4, 1, 2), semTuning(:, 7:12, :));
countTuning = cat(2, countTuning(:, 1:6, :), ...
    100 .* ones(4, 1, 2), countTuning(:, 7:12, :));
coherence = [-6:-1 0 1:6];

AI = CalculateQuickTuningAI( ...
    meanTuning, semTuning, countTuning, coherence);
verifyEqual(testCase, AI, (2 / 3) .* ones(4, 2), ...
    'AbsTol', 1e-12);
end


function testWritesFourCuePlotsAndOverview(testCase)
root = string(tempname);
mkdir(root);
cleanup = onCleanup(@() removeTestFolder(root));
cleanedFile = fullfile(root, 'cleaned.mat');
sourceFile = fullfile(root, 'source.mat');
outputFolder = fullfile(root, 'figures');

sessionCount = 3;
UnitTableRow = (1:sessionCount)';
Monkey = ["Jim"; "Clay"; "Jim"];
Date = datetime(2024, 1, 1) + days(0:sessionCount - 1)';
StimChannel = ones(sessionCount, 1);
Status = repmat("Success", sessionCount, 1);
Message = strings(sessionCount, 1);
OriginalMean = cell(sessionCount, 1);
OriginalSEM = cell(sessionCount, 1);
OriginalCount = cell(sessionCount, 1);
CleanedMean = cell(sessionCount, 1);
CleanedSEM = cell(sessionCount, 1);
CleanedCount = cell(sessionCount, 1);
Axes = cell(sessionCount, 1);
OutlierObservations = (1:sessionCount)';
OutlierTrials = (2:sessionCount + 1)';
OriginalTableMaxAbsDifference = zeros(sessionCount, 1);
AI = cell(sessionCount, 1);

for row = 1:sessionCount
    [originalMean, originalSEM, originalCount, coherence] = ...
        makeTuningInputs(10 + row, 12 + row);
    [cleanedMean, cleanedSEM, cleanedCount] = ...
        makeTuningInputs(10 + row, 13 + row);
    OriginalMean{row} = originalMean;
    OriginalSEM{row} = originalSEM;
    OriginalCount{row} = originalCount;
    CleanedMean{row} = cleanedMean;
    CleanedSEM{row} = cleanedSEM;
    CleanedCount{row} = cleanedCount;
    Axes{row} = struct('Coherence', coherence);
    AI{row} = CalculateQuickTuningAI( ...
        originalMean, originalSEM, originalCount, coherence);
end

unit_table_3DQuick_cleaned = table(UnitTableRow, Monkey, Date, ...
    StimChannel, Status, Message, OriginalMean, OriginalSEM, ...
    OriginalCount, CleanedMean, CleanedSEM, CleanedCount, Axes, ...
    OutlierObservations, OutlierTrials, OriginalTableMaxAbsDifference);
unit_table_gof = table(AI);
save(cleanedFile, 'unit_table_3DQuick_cleaned');
save(sourceFile, 'unit_table_gof');

result = PlotOriginalVsCleanedQuickAI( ...
    cleanedFile, sourceFile, OutputFolder=outputFolder, Resolution=72);

verifyEqual(testCase, height(result.SummaryTable), sessionCount);
verifyEqual(testCase, height(result.LongTable), sessionCount * 4);
verifyEqual(testCase, numel(result.IndividualFigureFiles), 4);
verifyTrue(testCase, all(isfile(result.IndividualFigureFiles)));
verifyTrue(testCase, isfile(result.OverviewFigureFile));
verifyTrue(testCase, isfile(result.ResultMAT));
verifyEqual(testCase, result.MaximumOriginalVsStoredAIDifference, 0, ...
    'AbsTol', 1e-12);
clear cleanup
removeTestFolder(root);
end


function [meanTuning, semTuning, countTuning, coherence] = ...
    makeTuningInputs(awayMean, towardMean)
coherence = [-6:-1 1:6];
meanTuning = nan(4, 12, 2);
for magnitude = 1:6
    meanTuning(:, coherence == -magnitude, :) = awayMean;
    meanTuning(:, coherence == magnitude, :) = towardMean;
end
countTuning = 4 .* ones(size(meanTuning));
semTuning = 0.5 .* ones(size(meanTuning));
end


function removeTestFolder(folder)
if isfolder(folder)
    rmdir(folder, 's');
end
end

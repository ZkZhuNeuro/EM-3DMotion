function tests = TestCalculateStimNoStimAIOD
%TESTCALCULATESTIMNOSTIMAIOD Synthetic regression tests.
tests = functiontests(localfunctions);
end


function testReproducesLegacyAIAndExcludesZeroFromOD(testCase)
[meanTuning, semTuning, countTuning, coherence, pairDifferences] = ...
    makeValidTuning(2);

[AI, odMax, details] = CalculateStimNoStimAIOD( ...
    meanTuning, semTuning, countTuning, coherence, 2);

expectedAI = mean(pairDifferences ./ (abs(pairDifferences) + 1.5), 2);
nonzero = coherence ~= 0;
leftMaximum = max(meanTuning(2, nonzero, 2), [], 'all');
rightMaximum = max(meanTuning(3, nonzero, 2), [], 'all');
expectedOD = (leftMaximum - rightMaximum) / ...
    (leftMaximum + rightMaximum);
verifyEqual(testCase, AI, expectedAI, 'AbsTol', 1e-12);
verifyEqual(testCase, odMax, expectedOD, 'AbsTol', 1e-12);
verifyEqual(testCase, details.ValidAIPairCount, repmat(6, 4, 1));
verifyEqual(testCase, details.DominantEye, "L");
verifyTrue(testCase, details.ZeroCoherenceExcluded);

% Channel 1 and the zero-coherence responses are deliberately extreme.
% Neither may affect acquisition channel 2's metrics.
verifyGreaterThan(testCase, max(meanTuning(:, :, 1), [], 'all'), 9e4);
zeroColumn = coherence == 0;
verifyGreaterThan(testCase, meanTuning(2, zeroColumn, 2), 1e3);
end


function testODUsesCommonCombinedCueSupport(testCase)
[meanTuning, semTuning, countTuning, coherence] = makeValidTuning(1);
nonzero = find(coherence ~= 0);
meanTuning(2, nonzero, 1) = 20;
meanTuning(3, nonzero, 1) = 10;

excludedColumn = nonzero(1);
countTuning(1, excludedColumn, 1) = 0;
meanTuning(2, excludedColumn, 1) = 200;

missingEyeColumn = nonzero(2);
meanTuning(2, missingEyeColumn, 1) = 300;
meanTuning(3, missingEyeColumn, 1) = NaN;

[~, odMax, details] = CalculateStimNoStimAIOD( ...
    meanTuning, semTuning, countTuning, coherence, 1);

verifyEqual(testCase, odMax, 290/310, 'AbsTol', 1e-12);
verifyEqual(testCase, details.LeftMaximum, 300);
verifyEqual(testCase, details.RightMaximum, 10);
verifyEqual(testCase, details.ODLeftFiniteCount, 11);
verifyEqual(testCase, details.ODRightFiniteCount, 10);
end


function testZeroSignalReturnsUndefinedAIAndOD(testCase)
coherence = [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22] ./ 22;
meanTuning = zeros(4, 13, 1);
semTuning = zeros(4, 13, 1);
countTuning = repmat(5, 4, 13, 1);

[AI, odMax, details] = CalculateStimNoStimAIOD( ...
    meanTuning, semTuning, countTuning, coherence, 1);

verifyTrue(testCase, all(isnan(AI)));
verifyTrue(testCase, isnan(odMax));
verifyEqual(testCase, details.DominantEye, "Undefined");
end


function testODSignAndEqualResponseConvention(testCase)
[meanTuning, semTuning, countTuning, coherence] = makeValidTuning(1);
nonzero = coherence ~= 0;
meanTuning(2, nonzero, 1) = 10;
meanTuning(3, nonzero, 1) = 30;
[~, rightOD, rightDetails] = CalculateStimNoStimAIOD( ...
    meanTuning, semTuning, countTuning, coherence, 1);
verifyEqual(testCase, rightOD, -0.5, 'AbsTol', 1e-12);
verifyEqual(testCase, rightDetails.DominantEye, "R");

meanTuning(2, nonzero, 1) = 20;
meanTuning(3, nonzero, 1) = 20;
[~, equalOD, equalDetails] = CalculateStimNoStimAIOD( ...
    meanTuning, semTuning, countTuning, coherence, 1);
verifyEqual(testCase, equalOD, 0, 'AbsTol', 1e-12);
verifyEqual(testCase, equalDetails.DominantEye, "R");
verifyTrue(testCase, equalDetails.ExactODTie);
end


function testRejectsIncompleteCoherenceGrid(testCase)
[meanTuning, semTuning, countTuning, coherence] = makeValidTuning(1);
meanTuning(:, end, :) = [];
semTuning(:, end, :) = [];
countTuning(:, end, :) = [];
coherence(end) = [];

verifyError(testCase, @() CalculateStimNoStimAIOD( ...
    meanTuning, semTuning, countTuning, coherence, 1), ...
    'StimNoStimAIOD:UnexpectedNonzeroCoherenceGrid');
end


function testRejectsOutOfRangeAcquisitionChannel(testCase)
[meanTuning, semTuning, countTuning, coherence] = makeValidTuning(2);
verifyError(testCase, @() CalculateStimNoStimAIOD( ...
    meanTuning, semTuning, countTuning, coherence, 3), ...
    'StimNoStimAIOD:StimulationChannelOutOfRange');
end


function [meanTuning, semTuning, countTuning, coherence, pairDifferences] = ...
    makeValidTuning(channelCount)
coherence = [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22] ./ 22;
meanTuning = nan(4, 13, channelCount);
semTuning = nan(4, 13, channelCount);
countTuning = repmat(9, 4, 13, channelCount);

% Make every non-target channel obviously different from the target.
for channel = 1:channelCount
    meanTuning(:, :, channel) = 1e5 * channel;
    semTuning(:, :, channel) = 1 / 3;
end

targetChannel = channelCount;
positiveColumns = find(coherence > 0);
negativeColumns = find(coherence < 0);
pairDifferences = [1:6; -(1:6); 2 .* (1:6); -2 .* (1:6)];
awayLevels = [18; 30; 10; 24];
for cue = 1:4
    for pairIndex = 1:numel(positiveColumns)
        positiveColumn = positiveColumns(pairIndex);
        negativeColumn = negativeColumns( ...
            abs(abs(coherence(negativeColumns)) - ...
            coherence(positiveColumn)) < 1e-12);
        meanTuning(cue, negativeColumn, targetChannel) = ...
            awayLevels(cue) + 3 .* pairIndex;
        meanTuning(cue, positiveColumn, targetChannel) = ...
            awayLevels(cue) + 3 .* pairIndex + ...
            pairDifferences(cue, pairIndex);
        % SEM * sqrt(9) reconstructs sample SDs 2 (away) and 1 (toward).
        semTuning(cue, negativeColumn, targetChannel) = 2 / 3;
        semTuning(cue, positiveColumn, targetChannel) = 1 / 3;
    end
end
zeroColumn = coherence == 0;
meanTuning(:, zeroColumn, targetChannel) = [5; 1e4; 1; 7];
semTuning(:, zeroColumn, targetChannel) = 1 / 3;
end

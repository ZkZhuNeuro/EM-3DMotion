function tests = TestZScoreTuningWithinChannel
%TESTZSCORETUNINGWITHINCHANNEL Regression tests for normalization scope.
tests = functiontests(localfunctions);
end


function testPoolsAllCuesAndCoherencesWithinChannel(testCase)
values = nan(2, 2, 2);
values(:, :, 1) = [1 1; 10 10];
values(:, :, 2) = [2 4; 8 16];

[zValues, centers, scales] = ZScoreTuningWithinChannel(values);

for channel = 1:2
    channelZ = zValues(:, :, channel);
    verifyEqual(testCase, mean(channelZ, 'all'), 0, 'AbsTol', 1e-12);
    verifyEqual(testCase, std(channelZ, 0, 'all'), 1, ...
        'AbsTol', 1e-12);
end
% The first channel has constant values within each cue. Cue-wise
% normalization would make it entirely NaN; whole-channel normalization
% keeps it finite and preserves the cue offset.
verifyTrue(testCase, all(isfinite(zValues(:, :, 1)), 'all'));
verifyGreaterThan(testCase, ...
    abs(mean(zValues(1, :, 1)) - mean(zValues(2, :, 1))), 1);
verifyEqual(testCase, centers(1), 5.5, 'AbsTol', 1e-12);
verifyEqual(testCase, scales(1), std([1 1 10 10], 0), ...
    'AbsTol', 1e-12);
end


function testMaskAndMissingValuesRemainExcluded(testCase)
values = reshape(1:12, [2 3 2]);
values(1, 2, 1) = NaN;
valid = true(size(values));
valid(2, 3, 2) = false;

zValues = ZScoreTuningWithinChannel(values, valid);

verifyTrue(testCase, isnan(zValues(1, 2, 1)));
verifyTrue(testCase, isnan(zValues(2, 3, 2)));
channelOne = zValues(:, :, 1);
channelTwo = zValues(:, :, 2);
verifyEqual(testCase, mean(channelOne(isfinite(channelOne))), 0, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, mean(channelTwo(isfinite(channelTwo))), 0, ...
    'AbsTol', 1e-12);
end


function testConstantOrSingleValueChannelIsUndefined(testCase)
values = nan(2, 2, 2);
values(:, :, 1) = 7;
values(1, 1, 2) = 3;

[zValues, centers, scales] = ZScoreTuningWithinChannel(values);

verifyTrue(testCase, all(isnan(zValues), 'all'));
verifyTrue(testCase, all(isnan(centers)));
verifyTrue(testCase, all(isnan(scales)));
end

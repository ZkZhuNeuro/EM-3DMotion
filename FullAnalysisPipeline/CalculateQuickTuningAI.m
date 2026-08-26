function [AI, details] = CalculateQuickTuningAI( ...
    meanTuning, semTuning, countTuning, coherence)
%CALCULATEQUICKTUNINGAI Calculate legacy 3D Quick AI for every channel.
%
% Inputs use cue x coherence x channel order. Zero coherence is ignored.
% For each of the six matched coherence magnitudes, AI is
%
%   (towardMean-awayMean) / ...
%   (abs(towardMean-awayMean) + (towardSD+awaySD)/2)
%
% The six pair-specific values are averaged separately for every cue and
% acquisition channel. SEM is converted back to sample SD using SD=SEM*sqrt(N).

arguments
    meanTuning {mustBeNumeric}
    semTuning {mustBeNumeric}
    countTuning {mustBeNumeric}
    coherence (1, :) double {mustBeFinite}
end

meanTuning = double(meanTuning);
semTuning = double(semTuning);
countTuning = double(countTuning);
coherence = double(coherence(:)');

if ~isequal(size(meanTuning), size(semTuning)) || ...
        ~isequal(size(meanTuning), size(countTuning))
    error('QuickAI:TuningSizeMismatch', ...
        'Mean, SEM, and count tuning arrays must have identical sizes.');
end
if size(meanTuning, 1) ~= 4 || size(meanTuning, 2) ~= numel(coherence)
    error('QuickAI:UnexpectedTuningSize', ...
        ['Expected cue x coherence x channel tuning with four cues and ' ...
        '%d coherence columns; found %s.'], ...
        numel(coherence), mat2str(size(meanTuning)));
end
if ndims(meanTuning) > 3
    error('QuickAI:UnexpectedTuningDimensions', ...
        'Tuning arrays must use cue x coherence x channel order.');
end
if any(isinf(countTuning), 'all') || any(countTuning < 0, 'all') || ...
        any(isfinite(countTuning) & countTuning ~= fix(countTuning), 'all')
    error('QuickAI:InvalidCounts', ...
        'Trial counts must be nonnegative integers or NaN.');
end
if numel(unique(coherence)) ~= numel(coherence)
    error('QuickAI:DuplicateCoherence', ...
        'The coherence axis contains duplicate values.');
end

tolerance = max(1e-12, 32 * eps(max(1, max(abs(coherence)))));
positiveColumns = find(coherence > tolerance);
negativeColumns = find(coherence < -tolerance);
if numel(positiveColumns) ~= 6 || numel(negativeColumns) ~= 6
    error('QuickAI:UnexpectedCoherenceGrid', ...
        ['Expected six positive and six negative coherence values; ' ...
        'found %d and %d.'], ...
        numel(positiveColumns), numel(negativeColumns));
end

[pairMagnitudes, order] = sort(coherence(positiveColumns));
positiveColumns = positiveColumns(order);
matchedNegativeColumns = nan(size(positiveColumns));
for pair = 1:numel(pairMagnitudes)
    matches = negativeColumns(abs(abs(coherence(negativeColumns)) - ...
        pairMagnitudes(pair)) <= tolerance);
    if numel(matches) ~= 1
        error('QuickAI:UnmatchedCoherencePair', ...
            'Positive coherence %.12g has %d negative matches.', ...
            pairMagnitudes(pair), numel(matches));
    end
    matchedNegativeColumns(pair) = matches;
end

channelCount = size(meanTuning, 3);
pairCount = numel(pairMagnitudes);
perPairAI = nan(4, pairCount, channelCount);
validPairCount = zeros(4, channelCount);
AI = nan(4, channelCount);

for channel = 1:channelCount
    for cue = 1:4
        towardMean = reshape(meanTuning( ...
            cue, positiveColumns, channel), 1, []);
        awayMean = reshape(meanTuning( ...
            cue, matchedNegativeColumns, channel), 1, []);
        towardCount = reshape(countTuning( ...
            cue, positiveColumns, channel), 1, []);
        awayCount = reshape(countTuning( ...
            cue, matchedNegativeColumns, channel), 1, []);
        towardSD = reshape(semTuning( ...
            cue, positiveColumns, channel), 1, []) .* sqrt(towardCount);
        awaySD = reshape(semTuning( ...
            cue, matchedNegativeColumns, channel), 1, []) .* ...
            sqrt(awayCount);
        towardSD(towardCount < 1) = NaN;
        awaySD(awayCount < 1) = NaN;

        numerator = towardMean - awayMean;
        denominator = abs(numerator) + (towardSD + awaySD) ./ 2;
        valid = isfinite(numerator) & isfinite(denominator) & ...
            denominator > 0;
        perPairAI(cue, valid, channel) = ...
            numerator(valid) ./ denominator(valid);
        validPairCount(cue, channel) = nnz(valid);
        if any(valid)
            AI(cue, channel) = mean(perPairAI(cue, valid, channel));
        end
    end
end

details = struct();
details.CoherencePairMagnitudes = pairMagnitudes;
details.PositiveCoherenceColumns = positiveColumns;
details.NegativeCoherenceColumns = matchedNegativeColumns;
details.PerPairAI = perPairAI;
details.ValidPairCount = validPairCount;
details.ZeroCoherenceExcluded = true;
details.Definition = ...
    "Mean across six matched nonzero coherence pairs of " + ...
    "(toward-away)/(abs(toward-away)+(SDtoward+SDaway)/2)";
end

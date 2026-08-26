function [AI, OD_max, details] = CalculateStimNoStimAIOD( ...
    meanTuning, semTuning, countTuning, coherence, stimulationChannel)
%CALCULATESTIMNOSTIMAIOD Reproduce the Quick-task AI/OD definitions.
%
% [AI, OD_max] = CalculateStimNoStimAIOD(MEAN, SEM, N, COHERENCE, CH)
% calculates the four cue-specific asymmetry indices (AI) and signed
% maximum-response ocular-dominance index (OD_max) for acquisition channel
% CH. Inputs are the non-electrical-stimulation tuning cells produced by
% BuildUnitTableStimTunings:
%
%   cue x coherence x acquisition channel.
%
% The calculation intentionally matches the legacy 3DMotionQuick metrics:
% zero coherence is excluded, all six matched nonzero coherence pairs are
% used for AI, and OD_max is positive for left-eye dominance.

validateattributes(meanTuning, {'numeric'}, {'real', 'nonempty'}, ...
    mfilename, 'meanTuning');
validateattributes(semTuning, {'numeric'}, {'real', 'nonempty'}, ...
    mfilename, 'semTuning');
validateattributes(countTuning, {'numeric'}, {'real', 'nonempty'}, ...
    mfilename, 'countTuning');
validateattributes(coherence, {'numeric'}, ...
    {'real', 'vector', 'nonempty', 'finite'}, mfilename, 'coherence');
validateattributes(stimulationChannel, {'numeric'}, ...
    {'real', 'scalar', 'integer', 'positive', 'finite'}, ...
    mfilename, 'stimulationChannel');

meanTuning = double(meanTuning);
semTuning = double(semTuning);
countTuning = double(countTuning);
coherence = reshape(double(coherence), 1, []);

if ~isequal(size(meanTuning), size(semTuning)) || ...
        ~isequal(size(meanTuning), size(countTuning))
    error('StimNoStimAIOD:TuningSizeMismatch', ...
        'Mean, SEM, and count tuning arrays must have identical sizes.');
end
if size(meanTuning, 1) ~= 4
    error('StimNoStimAIOD:UnexpectedCueCount', ...
        'Expected four cues; found %d.', size(meanTuning, 1));
end
if size(meanTuning, 2) ~= numel(coherence)
    error('StimNoStimAIOD:CoherenceSizeMismatch', ...
        ['The coherence vector has %d values but the tuning arrays ' ...
        'have %d coherence columns.'], ...
        numel(coherence), size(meanTuning, 2));
end
if ndims(meanTuning) > 3
    error('StimNoStimAIOD:UnexpectedTuningDimensions', ...
        'Tuning must be cue x coherence x acquisition channel.');
end
channelCount = size(meanTuning, 3);
if stimulationChannel > channelCount
    error('StimNoStimAIOD:StimulationChannelOutOfRange', ...
        'Stimulation channel %d exceeds the %d available channels.', ...
        stimulationChannel, channelCount);
end
if any(isinf(countTuning(:)) | countTuning(:) < 0 | ...
        (isfinite(countTuning(:)) & countTuning(:) ~= fix(countTuning(:))))
    error('StimNoStimAIOD:InvalidCounts', ...
        'Tuning counts must be nonnegative integers or NaN.');
end
if numel(unique(coherence)) ~= numel(coherence)
    error('StimNoStimAIOD:DuplicateCoherence', ...
        'The coherence vector contains duplicate values.');
end

coherenceTolerance = max(1e-12, ...
    32 * eps(max(1, max(abs(coherence)))));
positiveColumns = find(coherence > coherenceTolerance);
negativeColumns = find(coherence < -coherenceTolerance);
if numel(positiveColumns) ~= 6 || numel(negativeColumns) ~= 6
    error('StimNoStimAIOD:UnexpectedNonzeroCoherenceGrid', ...
        ['Expected six positive and six negative coherence values; ' ...
        'found %d and %d.'], ...
        numel(positiveColumns), numel(negativeColumns));
end

[pairMagnitudes, positiveOrder] = sort(coherence(positiveColumns));
positiveColumns = positiveColumns(positiveOrder);
matchedNegativeColumns = nan(size(positiveColumns));
for pairIndex = 1:numel(pairMagnitudes)
    matches = negativeColumns(abs( ...
        abs(coherence(negativeColumns)) - pairMagnitudes(pairIndex)) <= ...
        coherenceTolerance);
    if numel(matches) ~= 1
        error('StimNoStimAIOD:UnmatchedCoherencePair', ...
            ['Positive coherence %.12g matched %d negative values; ' ...
            'exactly one is required.'], ...
            pairMagnitudes(pairIndex), numel(matches));
    end
    matchedNegativeColumns(pairIndex) = matches;
end

AI = nan(4, 1);
perPairAI = nan(4, numel(pairMagnitudes));
validPairCount = zeros(4, 1);
for cue = 1:4
    towardMean = reshape(meanTuning( ...
        cue, positiveColumns, stimulationChannel), 1, []);
    awayMean = reshape(meanTuning( ...
        cue, matchedNegativeColumns, stimulationChannel), 1, []);
    towardSEM = reshape(semTuning( ...
        cue, positiveColumns, stimulationChannel), 1, []);
    awaySEM = reshape(semTuning( ...
        cue, matchedNegativeColumns, stimulationChannel), 1, []);
    towardCount = reshape(countTuning( ...
        cue, positiveColumns, stimulationChannel), 1, []);
    awayCount = reshape(countTuning( ...
        cue, matchedNegativeColumns, stimulationChannel), 1, []);

    % BuildUnitTableStimTunings stores SEM = sample SD / sqrt(N).
    towardSD = towardSEM .* sqrt(towardCount);
    awaySD = awaySEM .* sqrt(awayCount);
    towardSD(towardCount < 1) = NaN;
    awaySD(awayCount < 1) = NaN;

    numerator = towardMean - awayMean;
    denominator = abs(numerator) + (towardSD + awaySD) ./ 2;
    valid = isfinite(numerator) & isfinite(denominator) & denominator > 0;
    perPairAI(cue, valid) = numerator(valid) ./ denominator(valid);
    validPairCount(cue) = nnz(valid);
    if any(valid)
        AI(cue) = mean(perPairAI(cue, valid));
    end
end

combinedCount = reshape(countTuning( ...
    1, :, stimulationChannel), 1, []);
nonzeroColumns = abs(coherence) > coherenceTolerance & combinedCount > 0;
leftResponse = reshape(meanTuning( ...
    2, nonzeroColumns, stimulationChannel), 1, []);
rightResponse = reshape(meanTuning( ...
    3, nonzeroColumns, stimulationChannel), 1, []);
leftResponse = leftResponse(isfinite(leftResponse));
rightResponse = rightResponse(isfinite(rightResponse));
leftMaximum = NaN;
rightMaximum = NaN;
OD_max = NaN;
if ~isempty(leftResponse)
    leftMaximum = max(leftResponse);
end
if ~isempty(rightResponse)
    rightMaximum = max(rightResponse);
end
odDenominator = leftMaximum + rightMaximum;
if isfinite(odDenominator) && odDenominator ~= 0
    OD_max = (leftMaximum - rightMaximum) ./ odDenominator;
end

dominantEye = "Undefined";
if OD_max > 0
    dominantEye = "L";
elseif isfinite(OD_max)
    % Preserve the population code's legacy OD <= 0 right-eye branch.
    dominantEye = "R";
end

details = struct();
details.StimulationChannel = stimulationChannel;
details.CoherencePairMagnitudes = pairMagnitudes;
details.PositiveCoherenceColumns = positiveColumns;
details.NegativeCoherenceColumns = matchedNegativeColumns;
details.PerPairAI = perPairAI;
details.ValidAIPairCount = validPairCount;
details.LeftMaximum = leftMaximum;
details.RightMaximum = rightMaximum;
details.DominantEye = dominantEye;
details.ExactODTie = OD_max == 0;
details.ODCoherence = coherence(nonzeroColumns);
details.ODLeftFiniteCount = numel(leftResponse);
details.ODRightFiniteCount = numel(rightResponse);
details.ZeroCoherenceExcluded = true;
details.AIConvention = ...
    "Mean across six matched nonzero coherence pairs of " + ...
    "(toward-away)/(abs(toward-away)+(SDtoward+SDaway)/2)";
details.ODConvention = ...
    "(max(MonoL)-max(MonoR))/(max(MonoL)+max(MonoR)); nonzero coherence";
end

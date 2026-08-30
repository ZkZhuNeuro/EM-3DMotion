function features = CalculateThreeChannelMetaFeatures(sessionStats, weights)
%CALCULATETHREECHANNELMETAFEATURES Evaluate AI/OD from weighted meta tuning.
%
% Despite the legacy function name, WEIGHTS may contain any odd centered
% contact window. Each row is constrained to the nonnegative simplex.
% Cue-specific AI is calculated from weighted z-scored meta tuning; signed
% OD uses the same weights on the matching raw-FR meta tuning.

arguments
    sessionStats (:, 1) struct
    weights double
end

if isempty(weights) || ~ismatrix(weights) || ...
        any(~isfinite(weights), 'all') || any(weights < -1e-12, 'all') || ...
        any(abs(sum(weights, 2) - 1) > 1e-10)
    error('WeightedMetaTuning:InvalidWeights', ...
        'Every weight row must be finite, nonnegative, and sum to one.');
end
weights = max(weights, 0);
weights = weights ./ sum(weights, 2);

sessionCount = numel(sessionStats);
weightCount = size(weights, 1);
channelCount = size(weights, 2);
ai = nan(sessionCount, 4, weightCount);
signedOD = nan(sessionCount, weightCount);

for session = 1:sessionCount
    stats = sessionStats(session);
    validateSessionStats(stats);
    if size(stats.ZMean, 3) ~= channelCount
        error('WeightedMetaTuning:WeightChannelMismatch', ...
            'Weight count does not match the cached physical contacts.');
    end
    for weightIndex = 1:weightCount
        w = weights(weightIndex, :)';
        for cue = 1:4
            pairValues = nan(1, numel(stats.PositiveColumns));
            for pairIndex = 1:numel(stats.PositiveColumns)
                towardColumn = stats.PositiveColumns(pairIndex);
                awayColumn = stats.NegativeColumns(pairIndex);
                towardMean = reshape( ...
                    stats.ZMean(cue, towardColumn, :), 1, []) * w;
                awayMean = reshape( ...
                    stats.ZMean(cue, awayColumn, :), 1, []) * w;
                towardSD = weightedSD( ...
                    squeeze(stats.ZCov(cue, towardColumn, :, :)), w);
                awaySD = weightedSD( ...
                    squeeze(stats.ZCov(cue, awayColumn, :, :)), w);
                numerator = towardMean - awayMean;
                denominator = abs(numerator) + (towardSD + awaySD) ./ 2;
                if isfinite(numerator) && isfinite(denominator) && ...
                        denominator > 0
                    pairValues(pairIndex) = numerator ./ denominator;
                end
            end
            if any(isfinite(pairValues))
                ai(session, cue, weightIndex) = ...
                    mean(pairValues, 'omitnan');
            end
        end

        rawMeta = nan(size(stats.RawMean, 1), size(stats.RawMean, 2));
        for cue = 1:size(stats.RawMean, 1)
            for coherenceIndex = 1:size(stats.RawMean, 2)
                values = reshape(stats.RawMean(cue, coherenceIndex, :), [], 1);
                if all(isfinite(values))
                    rawMeta(cue, coherenceIndex) = values(:)' * w;
                end
            end
        end
        valid = isfinite(rawMeta(2, :)) & isfinite(rawMeta(3, :));
        if any(valid)
            leftMaximum = max(rawMeta(2, valid), [], 'omitnan');
            rightMaximum = max(rawMeta(3, valid), [], 'omitnan');
            denominator = leftMaximum + rightMaximum;
            if isfinite(denominator) && abs(denominator) > eps
                signedOD(session, weightIndex) = ...
                    (leftMaximum - rightMaximum) ./ denominator;
            end
        end
    end
end

features = struct();
features.Weights = weights;
features.AI = ai;
features.SignedOD = signedOD;
features.OD = abs(signedOD);
features.ChannelCount = channelCount;
features.Definition = [ ...
    "AI: weighted z-scored meta tuning with matched coherence pairs"; ...
    "OD: same-weight raw-FR meta tuning, normalized max-response OD"];
end


function value = weightedSD(covariance, weights)
value = nan;
channelCount = numel(weights);
if ~isequal(size(covariance), [channelCount channelCount]) || ...
        any(~isfinite(covariance), 'all')
    return
end
variance = weights' * covariance * weights;
if isfinite(variance) && variance >= -1e-12
    value = sqrt(max(variance, 0));
end
end


function validateSessionStats(stats)
required = {'ZMean', 'ZCov', 'RawMean', 'PositiveColumns', ...
    'NegativeColumns'};
missing = required(~isfield(stats, required));
channelCount = size(stats.ZMean, 3);
if ~isempty(missing) || size(stats.ZMean, 1) < 4 || channelCount < 1 || ...
        size(stats.RawMean, 1) < 3 || ...
        size(stats.RawMean, 3) ~= channelCount || ...
        size(stats.ZCov, 3) ~= channelCount || ...
        size(stats.ZCov, 4) ~= channelCount || ...
        numel(stats.PositiveColumns) ~= numel(stats.NegativeColumns)
    error('WeightedMetaTuning:InvalidSessionStats', ...
        'Session sufficient statistics are incomplete or malformed.');
end
end

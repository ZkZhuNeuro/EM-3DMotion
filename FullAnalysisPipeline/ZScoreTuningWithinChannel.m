function [zValues, channelCenter, channelScale] = ...
    ZScoreTuningWithinChannel(meanValues, validMask)
%ZSCORETUNINGWITHINCHANNEL Standardize each complete channel tuning matrix.
%
% Z = ZScoreTuningWithinChannel(MEANVALUES) treats dimensions 1 and 2 as
% cue and coherence and dimension 3 as acquisition channel. Each channel is
% standardized once across all of its finite cue-by-coherence values using
% the sample standard deviation (N-1).
%
% Z = ZScoreTuningWithinChannel(MEANVALUES, VALIDMASK) additionally excludes
% cells for which VALIDMASK is false. Excluded cells remain NaN.

if nargin < 2 || isempty(validMask)
    validMask = true(size(meanValues));
end
if ~isnumeric(meanValues)
    error('WholeChannelZScore:InvalidValues', ...
        'meanValues must be numeric.');
end
if ~isequal(size(validMask), size(meanValues))
    error('WholeChannelZScore:MaskSizeMismatch', ...
        'validMask must have the same size as meanValues.');
end

meanValues = double(meanValues);
validMask = logical(validMask) & isfinite(meanValues);
zValues = nan(size(meanValues));
channelCount = size(meanValues, 3);
channelCenter = nan(1, channelCount);
channelScale = nan(1, channelCount);

for channel = 1:channelCount
    values = meanValues(:, :, channel);
    valid = validMask(:, :, channel);
    if nnz(valid) < 2
        continue
    end

    center = mean(values(valid));
    scale = std(values(valid), 0);
    if ~isfinite(scale) || scale <= 0
        continue
    end

    standardized = nan(size(values));
    standardized(valid) = (values(valid) - center) ./ scale;
    zValues(:, :, channel) = standardized;
    channelCenter(channel) = center;
    channelScale(channel) = scale;
end
end

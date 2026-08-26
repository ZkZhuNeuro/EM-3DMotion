function result = CleanQuickBinnedResponses( ...
    firingRateHz, cellTrialCounts, options)
%CLEANQUICKBINNEDRESPONSES Apply channel-specific MAD filtering to Quick FRs.
%
% firingRateHz must use the layout:
%   cell dimensions x trial slot x channel x unit
%
% For 3D Quick, the cell dimensions are cue x coherence. For 2D Quick,
% they are direction x speed x eye condition. Outlier detection is performed
% independently in every cell x channel x unit combination. Only the flagged
% observation is excluded; the same trial remains available to other channels.

arguments
    firingRateHz {mustBeNumeric}
    cellTrialCounts {mustBeNumeric}
    options.Enabled (1, 1) logical = true
    options.Threshold (1, 1) double {mustBeFinite, mustBePositive} = 3.5
    options.MinimumTrials (1, 1) double ...
        {mustBeInteger, mustBePositive} = 5
end

cellTrialCounts = double(cellTrialCounts);
if isempty(cellTrialCounts) || any(~isfinite(cellTrialCounts), 'all') || ...
        any(cellTrialCounts < 0, 'all') || ...
        any(cellTrialCounts ~= fix(cellTrialCounts), 'all')
    error('QuickTuningCleaning:InvalidTrialCounts', ...
        'cellTrialCounts must contain finite nonnegative integers.');
end

cellSize = size(cellTrialCounts);
cellDimensionCount = ndims(cellTrialCounts);
trialDimension = cellDimensionCount + 1;
responseSize = size(firingRateHz);
if numel(responseSize) < trialDimension + 1 || ...
        ~isequal(responseSize(1:cellDimensionCount), cellSize)
    error('QuickTuningCleaning:ResponseSizeMismatch', ...
        ['firingRateHz leading dimensions must match cellTrialCounts and ' ...
        'must include trial-slot and channel dimensions.']);
end

maximumTrials = responseSize(trialDimension);
channelCount = responseSize(trialDimension + 1);
if any(cellTrialCounts > maximumTrials, 'all')
    error('QuickTuningCleaning:TrialCountExceedsStorage', ...
        'A cell trial count exceeds the firing-rate trial-slot dimension.');
end
if numel(responseSize) >= trialDimension + 2
    unitCount = prod(responseSize(trialDimension + 2:end));
else
    unitCount = 1;
end

cellCount = numel(cellTrialCounts);
firingRateHz = reshape(double(firingRateHz), ...
    [cellCount maximumTrials channelCount unitCount]);
countsFlat = reshape(cellTrialCounts, cellCount, 1);
outlierMask = false(size(firingRateHz));
originalMean = nan(cellCount, channelCount, unitCount);
originalSEM = nan(cellCount, channelCount, unitCount);
originalCount = zeros(cellCount, channelCount, unitCount);
cleanedMean = nan(cellCount, channelCount, unitCount);
cleanedSEM = nan(cellCount, channelCount, unitCount);
cleanedCount = zeros(cellCount, channelCount, unitCount);

testedCellCount = 0;
insufficientTrialCellCount = 0;
zeroMADCellCount = 0;
eligibleObservationCount = 0;
maximumAbsoluteModifiedZ = NaN;
consistencyConstant = 0.674489750196082;

for cellIndex = 1:cellCount
    trialCount = countsFlat(cellIndex);
    trialSlots = 1:trialCount;
    for channel = 1:channelCount
        for unit = 1:unitCount
            values = reshape(firingRateHz( ...
                cellIndex, trialSlots, channel, unit), [], 1);
            finite = isfinite(values);
            finiteCount = nnz(finite);
            originalCount(cellIndex, channel, unit) = finiteCount;
            [originalMean(cellIndex, channel, unit), ...
                originalSEM(cellIndex, channel, unit)] = ...
                summarizeValues(values(finite));

            flagged = false(size(values));
            if options.Enabled
                if finiteCount < options.MinimumTrials
                    insufficientTrialCellCount = ...
                        insufficientTrialCellCount + 1;
                else
                    testedCellCount = testedCellCount + 1;
                    eligibleObservationCount = ...
                        eligibleObservationCount + finiteCount;
                    center = median(values(finite));
                    rawMAD = median(abs(values(finite) - center));
                    if ~isfinite(rawMAD) || rawMAD <= 0
                        zeroMADCellCount = zeroMADCellCount + 1;
                    else
                        scores = nan(size(values));
                        scores(finite) = consistencyConstant .* ...
                            (values(finite) - center) ./ rawMAD;
                        flagged = finite & abs(scores) > options.Threshold;
                        cellMaximum = max(abs(scores(finite)));
                        if ~isfinite(maximumAbsoluteModifiedZ) || ...
                                cellMaximum > maximumAbsoluteModifiedZ
                            maximumAbsoluteModifiedZ = cellMaximum;
                        end
                    end
                end
            end

            outlierMask(cellIndex, trialSlots(flagged), channel, unit) = true;
            retained = finite & ~flagged;
            cleanedCount(cellIndex, channel, unit) = nnz(retained);
            [cleanedMean(cellIndex, channel, unit), ...
                cleanedSEM(cellIndex, channel, unit)] = ...
                summarizeValues(values(retained));
        end
    end
end

curveSize = [cellSize channelCount unitCount];
storageSize = [cellSize maximumTrials channelCount unitCount];
outlierMask = reshape(outlierMask, storageSize);
trialWithAnyOutlier = reshape(any(outlierMask, ...
    [cellDimensionCount + 2, cellDimensionCount + 3]), ...
    [cellSize maximumTrials]);

settings = struct( ...
    'Method', "modified Z-score using median and raw MAD", ...
    'Grouping', "Task cell x Channel x Unit", ...
    'Enabled', options.Enabled, ...
    'Threshold', options.Threshold, ...
    'MinimumTrials', options.MinimumTrials, ...
    'ConsistencyConstant', consistencyConstant, ...
    'ZeroMADPolicy', "retain all observations", ...
    'InsufficientTrialPolicy', "retain all observations");

audit = struct();
audit.Settings = settings;
audit.OutlierObservationCount = nnz(outlierMask);
audit.TrialWithAnyOutlierCount = nnz(trialWithAnyOutlier);
audit.TestedCellCount = testedCellCount;
audit.InsufficientTrialCellCount = insufficientTrialCellCount;
audit.ZeroMADCellCount = zeroMADCellCount;
audit.EligibleObservationCount = eligibleObservationCount;
audit.MaximumAbsoluteModifiedZ = maximumAbsoluteModifiedZ;
audit.TrialWithAnyOutlier = trialWithAnyOutlier;

result = struct();
result.OriginalMean = reshape(originalMean, curveSize);
result.OriginalSEM = reshape(originalSEM, curveSize);
result.OriginalCount = reshape(originalCount, curveSize);
result.CleanedMean = reshape(cleanedMean, curveSize);
result.CleanedSEM = reshape(cleanedSEM, curveSize);
result.CleanedCount = reshape(cleanedCount, curveSize);
result.OutlierMask = outlierMask;
result.Audit = audit;
end


function [meanValue, semValue] = summarizeValues(values)
count = numel(values);
if count == 0
    meanValue = NaN;
    semValue = NaN;
    return
end
meanValue = mean(values);
if count == 1
    semValue = 0;
else
    semValue = std(values, 0) ./ sqrt(count);
end
end

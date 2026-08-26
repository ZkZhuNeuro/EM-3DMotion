function QuickResult = BuildQuickTuningCleaningResult( ...
    Neuro, taskName, expectedChannelCount, options)
%BUILDQUICKTUNINGCLEANINGRESULT Clean one extracted Quick tuning session.

arguments
    Neuro (1, 1) struct
    taskName (1, 1) string {mustBeMember(taskName, ["3DQuick", "2DQuick"])}
    expectedChannelCount (1, 1) double ...
        {mustBeInteger, mustBePositive}
    options.Enabled (1, 1) logical = true
    options.Threshold (1, 1) double {mustBeFinite, mustBePositive} = 3.5
    options.MinimumTrials (1, 1) double ...
        {mustBeInteger, mustBePositive} = 5
end

if ~isfield(Neuro, 'All') || ~isfield(Neuro, 'Trials') || ...
        ~isfield(Neuro.Trials, 'NumTrials')
    error('QuickTuningCleaning:InvalidNeuro', ...
        'Neuro must contain All and Trials.NumTrials.');
end

switch taskName
    case "3DQuick"
        coherenceCount = size(Neuro.Trials.NumTrials, 2);
        switch coherenceCount
            case 12
                coherence = ...
                    [-22 -14 -10 -8 -4 -2 2 4 8 10 14 22] ./ 22;
            case 13
                coherence = ...
                    [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22] ./ 22;
            otherwise
                error('QuickTuningCleaning:Unexpected3DCoherenceCount', ...
                    ['3D Quick Trials.NumTrials must contain 12 or 13 ' ...
                    'coherence columns; found %d.'], coherenceCount);
        end
        cellSize = [4 coherenceCount];
        trialDimension = 3;
        axesInfo = struct( ...
            'Coherence', coherence, ...
            'ConditionNames', ["Combined", "MonoL", "MonoR", "Binocular"]);
    case "2DQuick"
        cellSize = [8 2 3];
        trialDimension = 4;
        axesInfo = struct( ...
            'DirectionDegrees', 0:45:315, ...
            'SpeedDegreesPerSecond', [4.166667 12.5], ...
            'ConditionNames', ["Left", "Right", "Both"]);
end

cellTrialCounts = double(Neuro.Trials.NumTrials);
if ~isequal(size(cellTrialCounts), cellSize)
    error('QuickTuningCleaning:UnexpectedCellSize', ...
        '%s Trials.NumTrials must have size %s; found %s.', ...
        taskName, mat2str(cellSize), mat2str(size(cellTrialCounts)));
end

firingRateHz = double(Neuro.All);
responseSize = size(firingRateHz);
channelDimension = trialDimension + 1;
if numel(responseSize) < channelDimension
    error('QuickTuningCleaning:MissingChannelDimension', ...
        '%s Neuro.All does not contain a channel dimension.', taskName);
end
sourceChannelCount = responseSize(channelDimension);
if sourceChannelCount < expectedChannelCount
    error('QuickTuningCleaning:TooFewChannels', ...
        '%s contains %d channels but the table expects %d.', ...
        taskName, sourceChannelCount, expectedChannelCount);
end
if sourceChannelCount > expectedChannelCount
    indices = repmat({':'}, 1, ndims(firingRateHz));
    indices{channelDimension} = 1:expectedChannelCount;
    firingRateHz = firingRateHz(indices{:});
end

cleaning = CleanQuickBinnedResponses( ...
    firingRateHz, cellTrialCounts, Enabled=options.Enabled, ...
    Threshold=options.Threshold, ...
    MinimumTrials=options.MinimumTrials);

curveSize = size(cleaning.OriginalMean);
unitDimension = numel(cellSize) + 2;
if numel(curveSize) >= unitDimension
    unitCount = curveSize(unitDimension);
else
    unitCount = 1;
end

QuickResult = struct();
QuickResult.Task = taskName;
QuickResult.Axes = axesInfo;
QuickResult.ChannelMap = defaultChannelMap(expectedChannelCount);
QuickResult.NumChannels = expectedChannelCount;
QuickResult.NumUnits = unitCount;
QuickResult.CellTrialCounts = cellTrialCounts;
QuickResult.OriginalMean = unitOne(cleaning.OriginalMean, cellSize, ...
    expectedChannelCount, unitCount);
QuickResult.OriginalSEM = unitOne(cleaning.OriginalSEM, cellSize, ...
    expectedChannelCount, unitCount);
QuickResult.OriginalCount = unitOne(cleaning.OriginalCount, cellSize, ...
    expectedChannelCount, unitCount);
QuickResult.CleanedMean = unitOne(cleaning.CleanedMean, cellSize, ...
    expectedChannelCount, unitCount);
QuickResult.CleanedSEM = unitOne(cleaning.CleanedSEM, cellSize, ...
    expectedChannelCount, unitCount);
QuickResult.CleanedCount = unitOne(cleaning.CleanedCount, cellSize, ...
    expectedChannelCount, unitCount);
QuickResult.FiringRateHz = firingRateHz;
QuickResult.FiringRateOutlierMask = cleaning.OutlierMask;
QuickResult.OutlierAudit = cleaning.Audit;
QuickResult.SourceChannelCount = sourceChannelCount;
QuickResult.RetainedChannelIndices = 1:expectedChannelCount;
QuickResult.DroppedChannelIndices = ...
    (expectedChannelCount + 1):sourceChannelCount;
end


function values = unitOne(values, cellSize, channelCount, unitCount)
values = reshape(values, [cellSize channelCount unitCount]);
indices = repmat({':'}, 1, numel(cellSize) + 2);
indices{end} = 1;
values = values(indices{:});
values = reshape(values, [cellSize channelCount]);
end


function channelMap = defaultChannelMap(channelCount)
edgeMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10];
if channelCount == numel(edgeMap)
    channelMap = edgeMap;
else
    channelMap = 1:channelCount;
end
end

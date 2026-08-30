function audit = ComputeQuickTuningWindowDiameter(unitTable, options)
%COMPUTEQUICKTUNINGWINDOWDIAMETER Full-curve diameter across a channel window.
%
% Every requested physical contact is standardized once across common-valid
% Quick-task trials from all cues and coherences. Cross-validated squared
% Euclidean tuning distance is calculated for every unique channel pair.
% WindowDiameterSquared is the largest split-averaged pair distance.

arguments
    unitTable table
    options.JimCacheFolder (1, 1) string = "C:\Jim\StimData"
    options.ClayCacheFolder (1, 1) string = "C:\Clay\StimData"
    options.ChannelMap (1, :) double ...
        {mustBeInteger, mustBePositive} = ...
        [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]
    options.RelativePositions (1, :) double ...
        {mustBeInteger} = -4:4
    options.CandidateMask (:, 1) logical = false(0, 1)
    options.NumSplits (1, 1) double ...
        {mustBeInteger, mustBePositive} = 200
    options.MinTrialsPerCondition (1, 1) double ...
        {mustBeInteger, mustBeGreaterThanOrEqual( ...
        options.MinTrialsPerCondition, 2)} = 2
    options.RandomSeed (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 1
end

relativePositions = options.RelativePositions;
if isempty(relativePositions) || ~ismember(0, relativePositions) || ...
        any(diff(relativePositions) ~= 1)
    error('QuickTuningDiameter:InvalidRelativePositions', ...
        'RelativePositions must be consecutive, increasing, and include zero.');
end
requireVariables(unitTable, ["Date", "Monkey", "ROI", "StimElec", ...
    "NChannels"]);
rowCount = height(unitTable);
candidateMask = options.CandidateMask;
if isempty(candidateMask)
    candidateMask = true(rowCount, 1);
elseif numel(candidateMask) ~= rowCount
    error('QuickTuningDiameter:CandidateMaskSize', ...
        'CandidateMask must contain one value per unit-table row.');
end

contactCount = numel(relativePositions);
pairIndices = nchoosek(1:contactCount, 2);
pairCount = size(pairIndices, 1);
tableRow = (1:rowCount)';
monkey = strings(rowCount, 1);
recordingDate = normalizeDateColumn(unitTable.Date);
roi = strings(rowCount, 1);
stimChannel = nan(rowCount, 1);
stimProbePosition = nan(rowCount, 1);
windowChannels = repmat({nan(1, contactCount)}, rowCount, 1);
channelCenter = repmat({nan(1, contactCount)}, rowCount, 1);
channelScale = repmat({nan(1, contactCount)}, rowCount, 1);
conditionCount = zeros(rowCount, 1);
conditionCountByCue = repmat({zeros(1, 4)}, rowCount, 1);
minimumTrialCount = zeros(rowCount, 1);
pairDistanceSquared = repmat({nan(1, pairCount)}, rowCount, 1);
distanceMatrixSquared = repmat( ...
    {nan(contactCount, contactCount)}, rowCount, 1);
windowDiameterSquared = nan(rowCount, 1);
windowDiameter = nan(rowCount, 1);
diameterLeftRelativePosition = nan(rowCount, 1);
diameterRightRelativePosition = nan(rowCount, 1);
diameterLeftChannel = nan(rowCount, 1);
diameterRightChannel = nan(rowCount, 1);
diameterPhysicalSpan = nan(rowCount, 1);
diameterPairSplitSelectionFraction = nan(rowCount, 1);
meanPairDistanceSquared = nan(rowCount, 1);
endpointDistanceSquared = nan(rowCount, 1);
maxStimDistanceSquared = nan(rowCount, 1);
maxStimDistanceRelativePosition = nan(rowCount, 1);
cacheFile = strings(rowCount, 1);
status = repmat("Pending", rowCount, 1);
message = strings(rowCount, 1);

stimWindowIndex = find(relativePositions == 0, 1);
for row = 1:rowCount
    monkey(row) = getRowText(unitTable.Monkey, row);
    roi(row) = getRowText(unitTable.ROI, row);
    if ~candidateMask(row)
        status(row) = "NotCandidate";
        continue
    end
    try
        stimChannel(row) = numericScalar(unitTable.StimElec, row);
        declaredChannelCount = numericScalar(unitTable.NChannels, row);
        stimPosition = find(options.ChannelMap == stimChannel(row), 1);
        if isempty(stimPosition)
            error('QuickTuningDiameter:UnmappedStimChannel', ...
                'Stimulation channel is absent from ChannelMap.');
        end
        stimProbePosition(row) = stimPosition;
        requestedPositions = stimPosition + relativePositions;
        if requestedPositions(1) < 1 || ...
                requestedPositions(end) > numel(options.ChannelMap)
            error('QuickTuningDiameter:OutsideProbe', ...
                ['The stimulation contact does not have the complete ' ...
                '%d:%d physical-contact window.'], ...
                relativePositions(1), relativePositions(end));
        end
        channels = options.ChannelMap(requestedPositions);
        windowChannels{row} = channels;

        folder = selectCacheFolder(monkey(row), ...
            options.JimCacheFolder, options.ClayCacheFolder);
        cacheFile(row) = fullfile(folder, ...
            string(recordingDate(row), 'yyyyMMdd') + ".mat");
        if ~isfile(cacheFile(row))
            error('QuickTuningDiameter:MissingCache', ...
                'Quick cache does not exist: %s', cacheFile(row));
        end
        loaded = load(cacheFile(row), 'Neuro');
        if ~isfield(loaded, 'Neuro')
            error('QuickTuningDiameter:MissingNeuro', ...
                'Quick cache does not contain Neuro.');
        end
        Neuro = loaded.Neuro;
        validateNeuro(Neuro);
        availableChannelCount = min(declaredChannelCount, ...
            size(Neuro.All, 4));
        if any(channels > availableChannelCount)
            error('QuickTuningDiameter:UnavailableChannel', ...
                ['Required channels %s exceed the available channel ' ...
                'count of %d.'], mat2str(channels), availableChannelCount);
        end
        deadChannels = getDeadChannels(unitTable, row);
        deadRequired = intersect(channels, deadChannels, 'stable');
        if ~isempty(deadRequired)
            error('QuickTuningDiameter:DeadChannel', ...
                'Required channel(s) marked dead: %s.', ...
                mat2str(deadRequired));
        end

        [blocks, countsByCue, centers, scales, minCount] = ...
            buildStandardizedConditionBlocks(Neuro, channels, ...
            options.MinTrialsPerCondition);
        conditionCount(row) = numel(blocks);
        conditionCountByCue{row} = countsByCue;
        minimumTrialCount(row) = minCount;
        channelCenter{row} = centers;
        channelScale{row} = scales;

        streamSeed = mod(options.RandomSeed + row - 1, 2^32 - 1);
        stream = RandStream('mt19937ar', 'Seed', streamSeed);
        [pairDistances, pairBySplit] = estimatePairDistances( ...
            blocks, pairIndices, options.NumSplits, stream);
        matrix = zeros(contactCount, contactCount);
        for pair = 1:pairCount
            left = pairIndices(pair, 1);
            right = pairIndices(pair, 2);
            matrix(left, right) = pairDistances(pair);
            matrix(right, left) = pairDistances(pair);
        end
        pairDistanceSquared{row} = pairDistances;
        distanceMatrixSquared{row} = matrix;
        [diameter, diameterIndex] = max(pairDistances);
        leftIndex = pairIndices(diameterIndex, 1);
        rightIndex = pairIndices(diameterIndex, 2);
        windowDiameterSquared(row) = diameter;
        windowDiameter(row) = sqrt(max(diameter, 0));
        diameterLeftRelativePosition(row) = relativePositions(leftIndex);
        diameterRightRelativePosition(row) = relativePositions(rightIndex);
        diameterLeftChannel(row) = channels(leftIndex);
        diameterRightChannel(row) = channels(rightIndex);
        diameterPhysicalSpan(row) = rightIndex - leftIndex;
        [~, splitMaximumIndex] = max(pairBySplit, [], 2);
        diameterPairSplitSelectionFraction(row) = ...
            mean(splitMaximumIndex == diameterIndex);
        meanPairDistanceSquared(row) = mean(pairDistances);
        endpointDistanceSquared(row) = matrix(1, end);
        stimDistances = matrix(stimWindowIndex, :);
        stimDistances(stimWindowIndex) = -Inf;
        [maxStimDistanceSquared(row), farthestIndex] = ...
            max(stimDistances);
        maxStimDistanceRelativePosition(row) = ...
            relativePositions(farthestIndex);
        status(row) = "Success";
    catch ME
        status(row) = "Error";
        message(row) = string(ME.identifier) + ": " + string(ME.message);
    end
end

windowRelativePositions = repmat({relativePositions}, rowCount, 1);
pairRelativePositions = repmat( ...
    {[relativePositions(pairIndices(:, 1))', ...
    relativePositions(pairIndices(:, 2))']}, rowCount, 1);
numSplits = repmat(options.NumSplits, rowCount, 1);
audit = table(tableRow, monkey, recordingDate, roi, candidateMask, ...
    stimChannel, stimProbePosition, windowRelativePositions, ...
    windowChannels, channelCenter, channelScale, conditionCount, ...
    conditionCountByCue, minimumTrialCount, numSplits, ...
    pairRelativePositions, pairDistanceSquared, distanceMatrixSquared, ...
    windowDiameterSquared, windowDiameter, ...
    diameterLeftRelativePosition, diameterRightRelativePosition, ...
    diameterLeftChannel, diameterRightChannel, diameterPhysicalSpan, ...
    diameterPairSplitSelectionFraction, meanPairDistanceSquared, ...
    endpointDistanceSquared, maxStimDistanceSquared, ...
    maxStimDistanceRelativePosition, cacheFile, status, message, ...
    'VariableNames', {'TableRow', 'Monkey', 'Date', 'ROI', ...
    'CandidateForAnalysis', 'StimChannel', 'StimProbePosition', ...
    'WindowRelativePositions', 'WindowChannels', 'ChannelZCenter', ...
    'ChannelZScale', 'ConditionCount', 'ConditionCountByCue', ...
    'MinimumTrialCount', 'NumSplits', 'PairRelativePositions', ...
    'PairDistanceSquared', 'DistanceMatrixSquared', ...
    'WindowDiameterSquared', 'WindowDiameter', ...
    'DiameterLeftRelativePosition', 'DiameterRightRelativePosition', ...
    'DiameterLeftChannel', 'DiameterRightChannel', ...
    'DiameterPhysicalSpan', 'DiameterPairSplitSelectionFraction', ...
    'MeanPairDistanceSquared', 'EndpointDistanceSquared', ...
    'MaxStimDistanceSquared', 'MaxStimDistanceRelativePosition', ...
    'CacheFile', 'Status', 'Message'});
audit.Properties.Description = ...
    "Cross-validated full Quick-task tuning diameter across a complete physical-contact window.";
end


function [blocks, countsByCue, centers, scales, minCount] = ...
    buildStandardizedConditionBlocks(Neuro, channels, minimumTrials)
cueCount = size(Neuro.All, 1);
coherenceCount = size(Neuro.All, 2);
if cueCount ~= 4
    error('QuickTuningDiameter:UnexpectedCueCount', ...
        'Expected four Quick-task cues; found %d.', cueCount);
end
blocks = cell(0, 1);
cueIndex = zeros(0, 1);
trialCounts = zeros(0, 1);
for cue = 1:cueCount
    for coherenceIndex = 1:coherenceCount
        trialCount = Neuro.Trials.NumTrials(cue, coherenceIndex);
        if ~isscalar(trialCount) || ~isfinite(trialCount) || trialCount < 1
            continue
        end
        trialCount = min(floor(trialCount), size(Neuro.All, 3));
        values = reshape(Neuro.All(cue, coherenceIndex, ...
            1:trialCount, channels), trialCount, numel(channels));
        values = double(values(all(isfinite(values), 2), :));
        if size(values, 1) < minimumTrials
            continue
        end
        blocks{end + 1, 1} = values; %#ok<AGROW>
        cueIndex(end + 1, 1) = cue; %#ok<AGROW>
        trialCounts(end + 1, 1) = size(values, 1); %#ok<AGROW>
    end
end
countsByCue = accumarray(cueIndex, 1, [cueCount, 1])';
if isempty(blocks) || any(countsByCue == 0)
    error('QuickTuningDiameter:InsufficientConditions', ...
        ['Every cue must have at least one condition with %d common-valid ' ...
        'trials across the requested channels.'], minimumTrials);
end
pooled = vertcat(blocks{:});
centers = mean(pooled, 1);
scales = std(pooled, 0, 1);
if any(~isfinite(scales) | scales <= eps(max(abs(centers), 1)))
    error('QuickTuningDiameter:ConstantChannel', ...
        'At least one required channel has a nonfinite or constant response.');
end
for index = 1:numel(blocks)
    blocks{index} = (blocks{index} - centers) ./ scales;
end
minCount = min(trialCounts);
end


function [pairDistances, pairBySplit] = estimatePairDistances( ...
    blocks, pairIndices, numSplits, stream)
conditionCount = numel(blocks);
contactCount = size(blocks{1}, 2);
pairCount = size(pairIndices, 1);
pairBySplit = nan(numSplits, pairCount);
for split = 1:numSplits
    tuningA = nan(conditionCount, contactCount);
    tuningB = nan(conditionCount, contactCount);
    for condition = 1:conditionCount
        values = blocks{condition};
        order = randperm(stream, size(values, 1));
        countA = floor(numel(order) / 2);
        tuningA(condition, :) = mean(values(order(1:countA), :), 1);
        tuningB(condition, :) = mean(values(order(countA + 1:end), :), 1);
    end
    differenceA = tuningA(:, pairIndices(:, 2)) - ...
        tuningA(:, pairIndices(:, 1));
    differenceB = tuningB(:, pairIndices(:, 2)) - ...
        tuningB(:, pairIndices(:, 1));
    pairBySplit(split, :) = mean(differenceA .* differenceB, 1);
end
pairDistances = mean(pairBySplit, 1);
end


function validateNeuro(Neuro)
if ~isstruct(Neuro) || ~isfield(Neuro, 'All') || ...
        ~isfield(Neuro, 'Trials') || ...
        ~isfield(Neuro.Trials, 'NumTrials') || ...
        ndims(Neuro.All) ~= 4 || ...
        size(Neuro.Trials.NumTrials, 1) < size(Neuro.All, 1) || ...
        size(Neuro.Trials.NumTrials, 2) < size(Neuro.All, 2)
    error('QuickTuningDiameter:InvalidNeuro', ...
        'Cached Neuro structure is incomplete.');
end
end


function channels = getDeadChannels(unitTable, row)
channels = [];
if ~ismember('DeadChannel', unitTable.Properties.VariableNames)
    return
end
value = getRowValue(unitTable.DeadChannel, row);
while iscell(value) && isscalar(value)
    value = value{1};
end
if isempty(value)
    return
elseif isnumeric(value)
    channels = double(value(:)');
elseif isstring(value) || ischar(value) || iscategorical(value)
    channels = str2double(regexp(char(string(value)), '\d+', 'match'));
elseif iscell(value)
    numericValues = value(cellfun(@isnumeric, value));
    if ~isempty(numericValues)
        channels = double(cell2mat(numericValues(:)'));
    end
end
channels = unique(channels(isfinite(channels) & channels >= 1));
end


function folder = selectCacheFolder(monkey, jimFolder, clayFolder)
if strcmpi(monkey, "Jim")
    folder = jimFolder;
elseif strcmpi(monkey, "Clay")
    folder = clayFolder;
else
    error('QuickTuningDiameter:UnknownMonkey', ...
        'Unsupported monkey name: %s.', monkey);
end
end


function dates = normalizeDateColumn(values)
if isdatetime(values)
    dates = dateshift(values(:), 'start', 'day');
elseif isnumeric(values)
    if all(isnan(values) | values > 1e7)
        dates = datetime(string(values(:)), 'InputFormat', 'yyyyMMdd');
    else
        dates = datetime(values(:), 'ConvertFrom', 'datenum');
    end
elseif iscell(values)
    dates = NaT(numel(values), 1);
    for index = 1:numel(values)
        dates(index) = normalizeDateColumn(values(index));
    end
else
    dates = datetime(string(values(:)), 'InputFormat', 'yyyyMMdd');
end
dates.Format = 'yyyyMMdd';
end


function requireVariables(inputTable, required)
missing = setdiff(required, string(inputTable.Properties.VariableNames));
if ~isempty(missing)
    error('QuickTuningDiameter:MissingVariables', ...
        'Missing required variable(s): %s.', join(missing, ', '));
end
end


function value = numericScalar(column, row)
value = getRowValue(column, row);
while iscell(value) && isscalar(value)
    value = value{1};
end
value = double(value);
if ~isscalar(value) || ~isfinite(value) || value < 1 || value ~= fix(value)
    error('QuickTuningDiameter:ExpectedPositiveInteger', ...
        'Expected one positive integer at table row %d.', row);
end
end


function value = getRowText(column, row)
value = getRowValue(column, row);
while iscell(value) && isscalar(value)
    value = value{1};
end
value = string(value);
end


function value = getRowValue(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
end

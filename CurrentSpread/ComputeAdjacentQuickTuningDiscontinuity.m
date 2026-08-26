function audit = ComputeAdjacentQuickTuningDiscontinuity(unitTable, options)
%COMPUTEADJACENTQUICKTUNINGDISCONTINUITY Full-curve five-contact change.
%
% For the five physical contacts (-2,-1,stim,+1,+2), each channel is
% standardized once across all common-valid Quick-task trials. The tuning
% vector contains every available cue-by-coherence mean. Repeated balanced
% trial splits estimate the cross-validated squared Euclidean distance for
% each of the four adjacent contact pairs:
%
%   mean((tuning_right_A - tuning_left_A) .* ...
%        (tuning_right_B - tuning_left_B))
%
% The cross-product of independent partitions removes the positive noise
% bias of an ordinary squared distance. Values can be slightly negative
% when the true change is near zero and must not be truncated before group
% averaging. AverageAdjacentJumpSquared is the mean of all four physical
% gaps; MaxAdjacentJumpSquared is their maximum.

arguments
    unitTable table
    options.JimCacheFolder (1, 1) string = "C:\Jim\StimData"
    options.ClayCacheFolder (1, 1) string = "C:\Clay\StimData"
    options.ChannelMap (1, :) double ...
        {mustBeInteger, mustBePositive} = ...
        [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]
    options.CandidateMask (:, 1) logical = false(0, 1)
    options.NumSplits (1, 1) double ...
        {mustBeInteger, mustBePositive} = 200
    options.MinTrialsPerCondition (1, 1) double ...
        {mustBeInteger, mustBeGreaterThanOrEqual( ...
        options.MinTrialsPerCondition, 2)} = 2
    options.RandomSeed (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 1
end

requireVariables(unitTable, ["Date", "Monkey", "ROI", "StimElec", ...
    "NChannels"]);
rowCount = height(unitTable);
candidateMask = options.CandidateMask;
if isempty(candidateMask)
    candidateMask = true(rowCount, 1);
elseif numel(candidateMask) ~= rowCount
    error('AdjacentTuningDistance:CandidateMaskSize', ...
        'CandidateMask must contain one value per unit-table row.');
end

tableRow = (1:rowCount)';
monkey = strings(rowCount, 1);
recordingDate = normalizeDateColumn(unitTable.Date);
roi = strings(rowCount, 1);
stimChannel = nan(rowCount, 1);
stimProbePosition = nan(rowCount, 1);
minus2Channel = nan(rowCount, 1);
minus1Channel = nan(rowCount, 1);
plus1Channel = nan(rowCount, 1);
plus2Channel = nan(rowCount, 1);
fiveChannels = repmat({nan(1, 5)}, rowCount, 1);
channelCenter = repmat({nan(1, 5)}, rowCount, 1);
channelScale = repmat({nan(1, 5)}, rowCount, 1);
conditionCount = zeros(rowCount, 1);
conditionCountByCue = repmat({zeros(1, 4)}, rowCount, 1);
minimumTrialCount = zeros(rowCount, 1);
minus2ToMinus1JumpSquared = nan(rowCount, 1);
minus1ToStimJumpSquared = nan(rowCount, 1);
stimToPlus1JumpSquared = nan(rowCount, 1);
plus1ToPlus2JumpSquared = nan(rowCount, 1);
adjacentJumpSquared = repmat({nan(1, 4)}, rowCount, 1);
cueAdjacentJumpSquared = repmat({nan(4, 4)}, rowCount, 1);
cueAverageAdjacentJumpSquared = repmat({nan(1, 4)}, rowCount, 1);
cueMaxAdjacentJumpSquared = repmat({nan(1, 4)}, rowCount, 1);
averageAdjacentJumpSquared = nan(rowCount, 1);
maxAdjacentJumpSquared = nan(rowCount, 1);
maxJumpEdge = strings(rowCount, 1);
cacheFile = strings(rowCount, 1);
status = repmat("Pending", rowCount, 1);
message = strings(rowCount, 1);

edgeLabels = ["-2 to -1", "-1 to 0", "0 to +1", "+1 to +2"];
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
            error('AdjacentTuningDistance:UnmappedStimChannel', ...
                'Stimulation channel is absent from ChannelMap.');
        end
        stimProbePosition(row) = stimPosition;
        requestedPositions = stimPosition + (-2:2);
        if requestedPositions(1) < 1 || ...
                requestedPositions(end) > numel(options.ChannelMap)
            error('AdjacentTuningDistance:OutsideProbe', ...
                ['The stimulation contact does not have two physical ' ...
                'contacts on both sides.']);
        end
        channels = options.ChannelMap(requestedPositions);
        fiveChannels{row} = channels;
        minus2Channel(row) = channels(1);
        minus1Channel(row) = channels(2);
        plus1Channel(row) = channels(4);
        plus2Channel(row) = channels(5);

        folder = selectCacheFolder(monkey(row), ...
            options.JimCacheFolder, options.ClayCacheFolder);
        cacheFile(row) = fullfile(folder, ...
            string(recordingDate(row), 'yyyyMMdd') + ".mat");
        if ~isfile(cacheFile(row))
            error('AdjacentTuningDistance:MissingCache', ...
                'Quick cache does not exist: %s', cacheFile(row));
        end
        loaded = load(cacheFile(row), 'Neuro');
        if ~isfield(loaded, 'Neuro')
            error('AdjacentTuningDistance:MissingNeuro', ...
                'Quick cache does not contain Neuro.');
        end
        Neuro = loaded.Neuro;
        validateNeuro(Neuro);
        availableChannelCount = min(declaredChannelCount, ...
            size(Neuro.All, 4));
        if any(channels > availableChannelCount)
            error('AdjacentTuningDistance:UnavailableChannel', ...
                ['Required channels %s exceed the available channel ' ...
                'count of %d.'], mat2str(channels), availableChannelCount);
        end
        deadChannels = getDeadChannels(unitTable, row);
        deadRequired = intersect(channels, deadChannels, 'stable');
        if ~isempty(deadRequired)
            error('AdjacentTuningDistance:DeadChannel', ...
                'Required channel(s) marked dead: %s.', ...
                mat2str(deadRequired));
        end

        [blocks, cueIndex, countsByCue, centers, scales, minCount] = ...
            buildStandardizedConditionBlocks(Neuro, channels, ...
            options.MinTrialsPerCondition);
        conditionCount(row) = numel(blocks);
        conditionCountByCue{row} = countsByCue;
        minimumTrialCount(row) = minCount;
        channelCenter{row} = centers;
        channelScale{row} = scales;

        streamSeed = mod(options.RandomSeed + row - 1, 2^32 - 1);
        stream = RandStream('mt19937ar', 'Seed', streamSeed);
        [edgeJumps, cueEdgeJumps] = estimateDistances( ...
            blocks, cueIndex, options.NumSplits, stream);
        adjacentJumpSquared{row} = edgeJumps;
        cueAdjacentJumpSquared{row} = cueEdgeJumps;
        cueAverageAdjacentJumpSquared{row} = ...
            mean(cueEdgeJumps, 2, 'omitmissing')';
        cueMaxAdjacentJumpSquared{row} = ...
            max(cueEdgeJumps, [], 2, 'omitmissing')';
        minus2ToMinus1JumpSquared(row) = edgeJumps(1);
        minus1ToStimJumpSquared(row) = edgeJumps(2);
        stimToPlus1JumpSquared(row) = edgeJumps(3);
        plus1ToPlus2JumpSquared(row) = edgeJumps(4);
        averageAdjacentJumpSquared(row) = mean(edgeJumps);
        [maxAdjacentJumpSquared(row), maxIndex] = max(edgeJumps);
        maxJumpEdge(row) = edgeLabels(maxIndex);
        status(row) = "Success";
    catch ME
        status(row) = "Error";
        message(row) = string(ME.identifier) + ": " + string(ME.message);
    end
end

numSplits = repmat(options.NumSplits, rowCount, 1);
minTrialsRequired = repmat(options.MinTrialsPerCondition, rowCount, 1);
audit = table(tableRow, monkey, recordingDate, roi, candidateMask, ...
    stimChannel, stimProbePosition, minus2Channel, minus1Channel, ...
    plus1Channel, plus2Channel, fiveChannels, channelCenter, channelScale, ...
    conditionCount, conditionCountByCue, minimumTrialCount, ...
    numSplits, minTrialsRequired, ...
    minus2ToMinus1JumpSquared, minus1ToStimJumpSquared, ...
    stimToPlus1JumpSquared, plus1ToPlus2JumpSquared, ...
    adjacentJumpSquared, cueAdjacentJumpSquared, ...
    cueAverageAdjacentJumpSquared, cueMaxAdjacentJumpSquared, ...
    averageAdjacentJumpSquared, maxAdjacentJumpSquared, maxJumpEdge, ...
    cacheFile, status, message, ...
    'VariableNames', {'TableRow', 'Monkey', 'Date', 'ROI', ...
    'CandidateForAnalysis', 'StimChannel', 'StimProbePosition', ...
    'Minus2Channel', 'Minus1Channel', 'Plus1Channel', 'Plus2Channel', ...
    'FiveChannels', 'ChannelZCenter', 'ChannelZScale', ...
    'ConditionCount', 'ConditionCountByCue', 'MinimumTrialCount', ...
    'NumSplits', 'MinimumTrialsRequired', ...
    'Minus2ToMinus1JumpSquared', 'Minus1ToStimJumpSquared', ...
    'StimToPlus1JumpSquared', 'Plus1ToPlus2JumpSquared', ...
    'AdjacentJumpSquared', 'CueAdjacentJumpSquared', ...
    'CueAverageAdjacentJumpSquared', 'CueMaxAdjacentJumpSquared', ...
    'AverageAdjacentJumpSquared', 'MaxAdjacentJumpSquared', ...
    'MaxJumpEdge', 'CacheFile', 'Status', 'Message'});
audit.Properties.Description = ...
    "Cross-validated full Quick-task tuning change across five physical contacts. " + ...
    "All cue-by-coherence conditions are equally weighted after each channel " + ...
    "is standardized across common-valid trials. Squared distances may be " + ...
    "negative because the estimator is noise-unbiased.";
end


function [blocks, cueIndex, countsByCue, centers, scales, minCount] = ...
    buildStandardizedConditionBlocks(Neuro, channels, minimumTrials)
cueCount = size(Neuro.All, 1);
coherenceCount = size(Neuro.All, 2);
if cueCount ~= 4
    error('AdjacentTuningDistance:UnexpectedCueCount', ...
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
    error('AdjacentTuningDistance:InsufficientConditions', ...
        ['Every cue must have at least one condition with %d common-valid ' ...
        'trials across all five channels.'], minimumTrials);
end
pooled = vertcat(blocks{:});
centers = mean(pooled, 1);
scales = std(pooled, 0, 1);
if any(~isfinite(scales) | scales <= eps(max(abs(centers), 1)))
    error('AdjacentTuningDistance:ConstantChannel', ...
        'At least one required channel has a nonfinite or constant response.');
end
for index = 1:numel(blocks)
    blocks{index} = (blocks{index} - centers) ./ scales;
end
minCount = min(trialCounts);
end


function [edgeJumps, cueEdgeJumps] = estimateDistances( ...
    blocks, cueIndex, numSplits, stream)
conditionCount = numel(blocks);
edgeBySplit = nan(numSplits, 4);
cueEdgeBySplit = nan(numSplits, 4, 4);
for split = 1:numSplits
    tuningA = nan(conditionCount, 5);
    tuningB = nan(conditionCount, 5);
    for condition = 1:conditionCount
        values = blocks{condition};
        order = randperm(stream, size(values, 1));
        countA = floor(numel(order) / 2);
        tuningA(condition, :) = mean(values(order(1:countA), :), 1);
        tuningB(condition, :) = mean(values(order(countA + 1:end), :), 1);
    end
    differenceProduct = diff(tuningA, 1, 2) .* diff(tuningB, 1, 2);
    edgeBySplit(split, :) = mean(differenceProduct, 1);
    for cue = 1:4
        cueEdgeBySplit(split, cue, :) = mean( ...
            differenceProduct(cueIndex == cue, :), 1);
    end
end
edgeJumps = mean(edgeBySplit, 1);
cueEdgeJumps = squeeze(mean(cueEdgeBySplit, 1));
end


function validateNeuro(Neuro)
if ~isstruct(Neuro) || ~isfield(Neuro, 'All') || ...
        ~isfield(Neuro, 'Trials') || ...
        ~isfield(Neuro.Trials, 'NumTrials') || ...
        ndims(Neuro.All) ~= 4 || ...
        size(Neuro.Trials.NumTrials, 1) < size(Neuro.All, 1) || ...
        size(Neuro.Trials.NumTrials, 2) < size(Neuro.All, 2)
    error('AdjacentTuningDistance:InvalidNeuro', ...
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
    error('AdjacentTuningDistance:UnknownMonkey', ...
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
    error('AdjacentTuningDistance:MissingVariables', ...
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
    error('AdjacentTuningDistance:ExpectedPositiveInteger', ...
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

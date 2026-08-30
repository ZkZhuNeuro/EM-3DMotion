function cache = BuildThreeChannelMetaTuningCache( ...
    unitTable, deltaBias, validBiasFit, options)
%BUILDTHREECHANNELMETATUNINGCACHE Cache centered-window Quick-tuning statistics.
%
% The function name is retained for compatibility; NeighborRadius controls
% an arbitrary odd centered contact window.
% A centered physical-contact window is required for every retained session.
% Each channel is standardized once across all valid Quick trials, cues, and
% coherences. Per-cue/coherence means and covariance matrices are retained so
% arbitrary population-level weights can be evaluated quickly.

arguments
    unitTable table
    deltaBias double
    validBiasFit logical
    options.Areas (1, :) string = ["MT", "FST"]
    options.UnitTypes (1, :) string = ["2D", "3D"]
    options.JimCacheFolder (1, 1) string = "C:\Jim\StimData"
    options.ClayCacheFolder (1, 1) string = "C:\Clay\StimData"
    options.NeighborRadius (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 1
    options.ChannelMap (1, :) double ...
        {mustBeInteger, mustBePositive} = ...
        [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]
end

required = ["Date", "ROI", "Monkey", "NChannels", "StimElec", ...
    "DeadChannel", "p_AI", "AI", "OD_max", "Z3D_v_Z2D"];
missing = setdiff(required, string(unitTable.Properties.VariableNames));
if ~isempty(missing)
    error('WeightedMetaTuning:MissingVariables', ...
        'unitTable is missing variable(s): %s.', strjoin(missing, ', '));
end
rowCount = height(unitTable);
relativePositions = -options.NeighborRadius:options.NeighborRadius;
contactCount = numel(relativePositions);
if size(deltaBias, 1) ~= rowCount || size(deltaBias, 2) < 4 || ...
        ~isequal(size(deltaBias), size(validBiasFit))
    error('WeightedMetaTuning:BiasSizeMismatch', ...
        'deltaBias and validBiasFit must match the unit-table rows and cues.');
end

areas = upper(strtrim(options.Areas));
unitTypes = upper(strtrim(options.UnitTypes));
candidate = false(rowCount, 1);
status = repmat("NotCandidate", rowCount, 1);
message = strings(rowCount, 1);
cacheFile = strings(rowCount, 1);
area = strings(rowCount, 1);
unitType = strings(rowCount, 1);
monkey = strings(rowCount, 1);
date = strings(rowCount, 1);
stimChannel = nan(rowCount, 1);
channels = repmat({nan(1, contactCount)}, rowCount, 1);
channelCenters = repmat({nan(1, contactCount)}, rowCount, 1);
channelScales = repmat({nan(1, contactCount)}, rowCount, 1);
storedStimAI = repmat({nan(4, 1)}, rowCount, 1);
originalOD = nan(rowCount, 1);
behaviorByCondition = repmat({nan(1, 4)}, rowCount, 1);
sourceCueByCondition = repmat({nan(1, 4)}, rowCount, 1);
statsByRow = repmat(emptySessionStats(), rowCount, 1);

for row = 1:rowCount
    area(row) = upper(rowText(unitTable.ROI, row));
    monkey(row) = rowText(unitTable.Monkey, row);
    date(row) = rowText(unitTable.Date, row);
    if ~ismember(area(row), areas)
        continue
    end
    pAI = rowNumericArray(unitTable.p_AI, row);
    if numel(pAI) < 3 || ~isfinite(pAI(2)) || ~isfinite(pAI(3)) || ...
            pAI(2) >= 0.05 || pAI(3) >= 0.05
        continue
    end
    zDifference = rowNumericScalar(unitTable.Z3D_v_Z2D, row);
    if zDifference < 0
        unitType(row) = "2D";
    elseif zDifference > 0
        unitType(row) = "3D";
    else
        continue
    end
    if ~ismember(unitType(row), unitTypes)
        continue
    end
    originalOD(row) = rowNumericScalar(unitTable.OD_max, row);
    if ~isfinite(originalOD(row))
        continue
    end

    aiValues = rowNumericArray(unitTable.AI, row);
    stimChannel(row) = rowNumericScalar(unitTable.StimElec, row);
    if size(aiValues, 1) >= 4 && ...
            stimChannel(row) >= 1 && stimChannel(row) <= size(aiValues, 2)
        storedStimAI{row} = aiValues(1:4, stimChannel(row));
    end
    if originalOD(row) > 0
        conditionToCue = [2 1 4 3];
    else
        conditionToCue = [3 1 4 2];
    end
    sourceCueByCondition{row} = conditionToCue;
    thisBehavior = nan(1, 4);
    for condition = 1:4
        cue = conditionToCue(condition);
        if validBiasFit(row, cue) && isfinite(deltaBias(row, cue))
            thisBehavior(condition) = deltaBias(row, cue);
        end
    end
    behaviorByCondition{row} = thisBehavior;
    if ~any(isfinite(thisBehavior))
        continue
    end
    candidate(row) = true;
    status(row) = "Pending";

    try
        stimulationPosition = find( ...
            options.ChannelMap == stimChannel(row), 1);
        if isempty(stimulationPosition)
            error('WeightedMetaTuning:UnmappedStimChannel', ...
                'The stimulation channel is absent from ChannelMap.');
        end
        requestedPositions = stimulationPosition + relativePositions;
        if requestedPositions(1) < 1 || ...
                requestedPositions(end) > numel(options.ChannelMap)
            error('WeightedMetaTuning:OutsideProbe', ...
                'The stimulation contact lacks the requested neighbor window.');
        end
        requestedChannels = options.ChannelMap(requestedPositions);
        channels{row} = requestedChannels;
        declaredChannelCount = rowNumericScalar(unitTable.NChannels, row);
        deadChannels = rowNumericArray(unitTable.DeadChannel, row);

        folder = selectCacheFolder(monkey(row), ...
            options.JimCacheFolder, options.ClayCacheFolder);
        recordingDate = normalizeDate(unitTable.Date, row);
        cacheFile(row) = fullfile(folder, ...
            string(recordingDate, 'yyyyMMdd') + ".mat");
        if ~isfile(cacheFile(row))
            error('WeightedMetaTuning:MissingCache', ...
                'Quick cache does not exist: %s', cacheFile(row));
        end
        loaded = load(cacheFile(row), 'Neuro');
        if ~isfield(loaded, 'Neuro')
            error('WeightedMetaTuning:MissingNeuro', ...
                'Quick cache does not contain Neuro.');
        end
        Neuro = loaded.Neuro;
        validateNeuro(Neuro);
        availableChannelCount = min(declaredChannelCount, size(Neuro.All, 4));
        if any(requestedChannels > availableChannelCount)
            error('WeightedMetaTuning:UnavailableChannel', ...
                'At least one required physical channel is unavailable.');
        end
        deadRequired = intersect(requestedChannels, deadChannels, 'stable');
        if ~isempty(deadRequired)
            error('WeightedMetaTuning:DeadChannel', ...
                'Required dead channel(s): %s.', mat2str(deadRequired));
        end

        centers = nan(1, contactCount);
        scales = nan(1, contactCount);
        for channelIndex = 1:contactCount
            values = validChannelObservations( ...
                Neuro, requestedChannels(channelIndex));
            if numel(values) < 2
                error('WeightedMetaTuning:TooFewChannelObservations', ...
                    'A required channel has fewer than two finite trials.');
            end
            centers(channelIndex) = mean(values);
            scales(channelIndex) = std(values, 0);
            if ~isfinite(scales(channelIndex)) || scales(channelIndex) <= eps
                error('WeightedMetaTuning:ConstantChannel', ...
                    'A required channel has zero or nonfinite variance.');
            end
        end
        channelCenters{row} = centers;
        channelScales{row} = scales;

        coherence = getNeuroCoherence(Neuro);
        [positiveColumns, negativeColumns] = ...
            matchedCoherenceColumns(coherence);
        coherenceCount = size(Neuro.All, 2);
        zMean = nan(4, coherenceCount, contactCount);
        zCov = nan(4, coherenceCount, contactCount, contactCount);
        rawMean = nan(4, coherenceCount, contactCount);
        counts = zeros(4, coherenceCount);
        for cue = 1:4
            for coherenceIndex = 1:coherenceCount
                trialCount = boundedTrialCount(Neuro.Trials.NumTrials, ...
                    cue, coherenceIndex, size(Neuro.All, 3));
                if trialCount < 2
                    continue
                end
                raw = reshape(double(Neuro.All(cue, coherenceIndex, ...
                    1:trialCount, requestedChannels)), ...
                    trialCount, contactCount);
                complete = all(isfinite(raw), 2);
                raw = raw(complete, :);
                if size(raw, 1) < 2
                    continue
                end
                standardized = (raw - centers) ./ scales;
                rawMean(cue, coherenceIndex, :) = mean(raw, 1);
                zMean(cue, coherenceIndex, :) = mean(standardized, 1);
                zCov(cue, coherenceIndex, :, :) = cov(standardized, 0);
                counts(cue, coherenceIndex) = size(raw, 1);
            end
        end
        thisStats = emptySessionStats();
        thisStats.SourceRow = row;
        thisStats.Date = date(row);
        thisStats.Area = area(row);
        thisStats.UnitType = unitType(row);
        thisStats.Monkey = monkey(row);
        thisStats.StimChannel = stimChannel(row);
        thisStats.Channels = requestedChannels;
        thisStats.ChannelCenters = centers;
        thisStats.ChannelScales = scales;
        thisStats.StoredStimAI = storedStimAI{row};
        thisStats.OriginalSignedOD = originalOD(row);
        thisStats.Behavior = thisBehavior;
        thisStats.SourceCueByCondition = conditionToCue;
        thisStats.Coherence = coherence;
        thisStats.PositiveColumns = positiveColumns;
        thisStats.NegativeColumns = negativeColumns;
        thisStats.ZMean = zMean;
        thisStats.ZCov = zCov;
        thisStats.RawMean = rawMean;
        thisStats.Counts = counts;
        thisStats.CacheFile = cacheFile(row);
        statsByRow(row) = thisStats;
        status(row) = "Success";
    catch ME
        status(row) = "Error";
        message(row) = string(ME.identifier) + ": " + string(ME.message);
    end
end

success = status == "Success";
sessionStats = statsByRow(success);
sessionTable = table( ...
    [sessionStats.SourceRow]', string({sessionStats.Date})', ...
    string({sessionStats.Area})', string({sessionStats.UnitType})', ...
    string({sessionStats.Monkey})', [sessionStats.StimChannel]', ...
    {sessionStats.Channels}', [sessionStats.OriginalSignedOD]', ...
    {sessionStats.Behavior}', {sessionStats.SourceCueByCondition}', ...
    string({sessionStats.CacheFile})', ...
    'VariableNames', {'SourceRow', 'Date', 'Area', 'UnitType', 'Monkey', ...
    'StimChannel', 'Channels', 'OriginalSignedOD', 'Behavior', ...
    'SourceCueByCondition', 'CacheFile'});

audit = table((1:rowCount)', date, area, unitType, monkey, candidate, ...
    stimChannel, channels, channelCenters, channelScales, storedStimAI, ...
    originalOD, behaviorByCondition, sourceCueByCondition, cacheFile, ...
    status, message, success, ...
    'VariableNames', {'SourceRow', 'Date', 'Area', 'UnitType', 'Monkey', ...
    'Candidate', 'StimChannel', 'Channels', 'ChannelCenters', ...
    'ChannelScales', 'StoredStimAI', 'OriginalSignedOD', 'Behavior', ...
    'SourceCueByCondition', 'CacheFile', 'Status', 'Message', 'Success'});

cache = struct();
cache.Analysis = sprintf('%d-channel weighted z-scored Quick meta tuning', ...
    contactCount);
cache.SessionStats = sessionStats;
cache.SessionTable = sessionTable;
cache.Audit = audit;
cache.ChannelMap = options.ChannelMap;
cache.RelativePositions = relativePositions;
cache.NeighborRadius = options.NeighborRadius;
cache.ConditionNames = ["Dominant", "Combined", "Stereo", "NonDominant"];
cache.SourceRowCount = rowCount;
cache.SessionCount = numel(sessionStats);
cache.ZScoreDefinition = ...
    "Each channel standardized once across all valid Quick trials/cues/coherences";
cache.AIDefinition = ...
    "All available matched nonzero coherence pairs on weighted z meta tuning";
cache.ODDefinition = ...
    "Normalized maximum-response OD on same-weight raw-FR meta tuning";
end


function output = emptySessionStats()
output = struct('SourceRow', nan, 'Date', "", 'Area', "", ...
    'UnitType', "", 'Monkey', "", 'StimChannel', nan, ...
    'Channels', nan(1, 0), 'ChannelCenters', nan(1, 0), ...
    'ChannelScales', nan(1, 0), 'StoredStimAI', nan(4, 1), ...
    'OriginalSignedOD', nan, 'Behavior', nan(1, 4), ...
    'SourceCueByCondition', nan(1, 4), 'Coherence', nan(1, 0), ...
    'PositiveColumns', nan(1, 0), 'NegativeColumns', nan(1, 0), ...
    'ZMean', nan(4, 0, 0), 'ZCov', nan(4, 0, 0, 0), ...
    'RawMean', nan(4, 0, 0), 'Counts', zeros(4, 0), ...
    'CacheFile', "");
end


function values = validChannelObservations(Neuro, channel)
values = zeros(0, 1);
for cue = 1:min(4, size(Neuro.All, 1))
    for coherenceIndex = 1:size(Neuro.All, 2)
        trialCount = boundedTrialCount(Neuro.Trials.NumTrials, cue, ...
            coherenceIndex, size(Neuro.All, 3));
        if trialCount == 0
            continue
        end
        block = reshape(double(Neuro.All(cue, coherenceIndex, ...
            1:trialCount, channel)), [], 1);
        values = [values; block(isfinite(block))]; %#ok<AGROW>
    end
end
end


function [positiveColumns, negativeColumns] = matchedCoherenceColumns(coherence)
coherence = double(coherence(:)');
tolerance = max(1e-12, 32 * eps(max(1, max(abs(coherence)))));
positiveColumns = find(coherence > tolerance);
availableNegative = find(coherence < -tolerance);
[magnitudes, order] = sort(coherence(positiveColumns));
positiveColumns = positiveColumns(order);
negativeColumns = nan(size(positiveColumns));
keep = false(size(positiveColumns));
for index = 1:numel(magnitudes)
    match = availableNegative(abs(abs(coherence(availableNegative)) - ...
        magnitudes(index)) <= tolerance);
    if isscalar(match)
        negativeColumns(index) = match;
        keep(index) = true;
    end
end
positiveColumns = positiveColumns(keep);
negativeColumns = negativeColumns(keep);
if isempty(positiveColumns)
    error('WeightedMetaTuning:NoMatchedCoherencePairs', ...
        'No matched positive/negative coherence pairs were found.');
end
end


function count = boundedTrialCount(trialCounts, cue, coherenceIndex, capacity)
if cue > size(trialCounts, 1) || coherenceIndex > size(trialCounts, 2)
    count = 0;
    return
end
count = double(trialCounts(cue, coherenceIndex));
if ~isscalar(count) || ~isfinite(count) || count <= 0
    count = 0;
else
    count = min(capacity, floor(count));
end
end


function coherence = getNeuroCoherence(Neuro)
if isfield(Neuro, 'CoherenceArray') && ...
        numel(Neuro.CoherenceArray) == size(Neuro.All, 2)
    coherence = double(Neuro.CoherenceArray(:)');
    return
end
switch size(Neuro.All, 2)
    case 8
        numerator = [-22 -14 -10 -8 8 10 14 22];
    case 12
        numerator = [-22 -14 -10 -8 -4 -2 2 4 8 10 14 22];
    case 13
        numerator = [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22];
    otherwise
        error('WeightedMetaTuning:UnknownCoherenceGrid', ...
            'Expected 8, 12, or 13 coherence values; found %d.', ...
            size(Neuro.All, 2));
end
coherence = numerator ./ 22;
end


function validateNeuro(Neuro)
if ~isfield(Neuro, 'All') || ~isfield(Neuro, 'Trials') || ...
        ~isfield(Neuro.Trials, 'NumTrials') || ndims(Neuro.All) ~= 4 || ...
        size(Neuro.All, 1) < 4 || size(Neuro.Trials.NumTrials, 1) < 4
    error('WeightedMetaTuning:InvalidNeuro', ...
        'Cached Neuro structure is incomplete.');
end
end


function folder = selectCacheFolder(monkey, jimFolder, clayFolder)
if strcmpi(monkey, "Jim")
    folder = jimFolder;
elseif strcmpi(monkey, "Clay")
    folder = clayFolder;
else
    error('WeightedMetaTuning:UnknownMonkey', ...
        'Unknown monkey label: %s.', monkey);
end
end


function value = normalizeDate(column, row)
if isdatetime(column)
    value = column(row);
elseif iscell(column)
    value = datetime(column{row});
else
    value = datetime(column(row));
end
end


function value = rowNumericScalar(column, row)
values = rowNumericArray(column, row);
if isempty(values)
    value = nan;
else
    value = double(values(1));
end
end


function values = rowNumericArray(column, row)
if iscell(column)
    values = column{row};
elseif isnumeric(column) || islogical(column)
    values = column(row, :);
else
    values = [];
end
if isempty(values) || ~(isnumeric(values) || islogical(values))
    values = nan(1, 0);
else
    values = double(values);
end
end


function value = rowText(column, row)
if iscell(column)
    value = string(column{row});
elseif isdatetime(column)
    value = string(column(row));
elseif isstring(column) || iscategorical(column)
    value = string(column(row));
elseif ischar(column)
    value = string(column(row, :));
else
    value = string(column(row));
end
value = strtrim(value(1));
end

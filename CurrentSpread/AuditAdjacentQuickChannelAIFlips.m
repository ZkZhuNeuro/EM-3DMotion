function audit = AuditAdjacentQuickChannelAIFlips(unitTable, options)
%AUDITADJACENTQUICKCHANNELAIFLIPS Find local combined-cue AI sign conflicts.
%
% A stimulation site is flagged when either immediately adjacent physical
% probe contact has significant combined-cue direction tuning (raw p below
% TuningAlpha) and a combined-cue AI whose sign is opposite to the AI at
% the stimulation channel. Missing, dead, unavailable, and nonsignificant
% adjacent contacts are audited but do not trigger exclusion.

arguments
    unitTable table
    options.JimCacheFolder (1, 1) string = "C:\Jim\StimData"
    options.ClayCacheFolder (1, 1) string = "C:\Clay\StimData"
    options.TuningAlpha (1, 1) double ...
        {mustBeGreaterThan(options.TuningAlpha, 0), ...
        mustBeLessThan(options.TuningAlpha, 1)} = 0.05
    options.ChannelMap (1, :) double ...
        {mustBeInteger, mustBePositive} = ...
        [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]
    options.NeighborRadius (1, 1) double ...
        {mustBeInteger, mustBeMember(options.NeighborRadius, [1, 2])} = 1
    options.CandidateMask (:, 1) logical = false(0, 1)
end

requireVariables(unitTable, ["Date", "Monkey", "StimElec", ...
    "NChannels", "AI"]);
rowCount = height(unitTable);
candidateMask = options.CandidateMask;
if isempty(candidateMask)
    candidateMask = true(rowCount, 1);
elseif numel(candidateMask) ~= rowCount
    error('AdjacentAIFlip:CandidateMaskSize', ...
        'CandidateMask must contain one value per unit-table row.');
end

tableRow = (1:rowCount)';
monkey = strings(rowCount, 1);
recordingDate = normalizeDateColumn(unitTable.Date);
roi = repmat("", rowCount, 1);
stimChannel = nan(rowCount, 1);
stimProbePosition = nan(rowCount, 1);
stimCombinedAI = nan(rowCount, 1);
minus2Channel = nan(rowCount, 1);
minus2CombinedAI = nan(rowCount, 1);
minus2CombinedP = nan(rowCount, 1);
minus2Significant = false(rowCount, 1);
minus2SignFlip = false(rowCount, 1);
minus2Status = repmat("NotRequested", rowCount, 1);
minus1Channel = nan(rowCount, 1);
minus1CombinedAI = nan(rowCount, 1);
minus1CombinedP = nan(rowCount, 1);
minus1Significant = false(rowCount, 1);
minus1SignFlip = false(rowCount, 1);
minus1Status = repmat("Not evaluated", rowCount, 1);
plus1Channel = nan(rowCount, 1);
plus1CombinedAI = nan(rowCount, 1);
plus1CombinedP = nan(rowCount, 1);
plus1Significant = false(rowCount, 1);
plus1SignFlip = false(rowCount, 1);
plus1Status = repmat("Not evaluated", rowCount, 1);
plus2Channel = nan(rowCount, 1);
plus2CombinedAI = nan(rowCount, 1);
plus2CombinedP = nan(rowCount, 1);
plus2Significant = false(rowCount, 1);
plus2SignFlip = false(rowCount, 1);
plus2Status = repmat("NotRequested", rowCount, 1);
significantAdjacentCount = zeros(rowCount, 1);
oppositeSignificantAdjacentCount = zeros(rowCount, 1);
excludeForAIFlip = false(rowCount, 1);
cacheFile = strings(rowCount, 1);
status = repmat("Pending", rowCount, 1);
message = strings(rowCount, 1);

for row = 1:rowCount
    monkey(row) = getRowText(unitTable.Monkey, row);
    if ismember('ROI', unitTable.Properties.VariableNames)
        roi(row) = getRowText(unitTable.ROI, row);
    end
    if ~candidateMask(row)
        status(row) = "NotCandidate";
        continue
    end

    try
        stimChannel(row) = numericScalar(unitTable.StimElec, row);
        declaredChannelCount = numericScalar(unitTable.NChannels, row);
        aiValues = numericArray(unitTable.AI, row);
        if size(aiValues, 1) < 1 || ...
                stimChannel(row) > size(aiValues, 2)
            error('AdjacentAIFlip:InvalidAI', ...
                'Combined-cue AI is unavailable at the stimulation channel.');
        end
        stimCombinedAI(row) = double(aiValues(1, stimChannel(row)));

        cacheFolder = selectCacheFolder(monkey(row), ...
            options.JimCacheFolder, options.ClayCacheFolder);
        cacheFile(row) = fullfile(cacheFolder, ...
            string(recordingDate(row), 'yyyyMMdd') + ".mat");
        if ~isfile(cacheFile(row))
            error('AdjacentAIFlip:MissingCache', ...
                'Quick cache does not exist: %s', cacheFile(row));
        end
        loaded = load(cacheFile(row), 'Neuro');
        if ~isfield(loaded, 'Neuro')
            error('AdjacentAIFlip:MissingNeuro', ...
                'Quick cache does not contain Neuro.');
        end
        Neuro = loaded.Neuro;
        validateNeuro(Neuro);

        availableChannelCount = min([declaredChannelCount, ...
            size(aiValues, 2), size(Neuro.All, 4)]);
        if stimChannel(row) < 1 || stimChannel(row) ~= fix(stimChannel(row)) || ...
                stimChannel(row) > availableChannelCount
            error('AdjacentAIFlip:InvalidStimChannel', ...
                'Stimulation channel is outside the available channel range.');
        end
        stimPosition = find( ...
            options.ChannelMap == stimChannel(row), 1);
        if isempty(stimPosition)
            error('AdjacentAIFlip:UnmappedStimChannel', ...
                'Stimulation channel is absent from ChannelMap.');
        end
        stimProbePosition(row) = stimPosition;

        deadChannels = getDeadChannels(unitTable, row);
        coherence = getNeuroCoherence(Neuro);
        if options.NeighborRadius >= 2
            [minus2Channel(row), minus2CombinedAI(row), ...
                minus2CombinedP(row), minus2Significant(row), ...
                minus2SignFlip(row), minus2Status(row)] = evaluateNeighbor( ...
                -2, stimProbePosition(row), stimCombinedAI(row), aiValues, ...
                Neuro, coherence, availableChannelCount, deadChannels, ...
                options.ChannelMap, options.TuningAlpha);
        end
        [minus1Channel(row), minus1CombinedAI(row), ...
            minus1CombinedP(row), minus1Significant(row), ...
            minus1SignFlip(row), minus1Status(row)] = evaluateNeighbor( ...
            -1, stimProbePosition(row), stimCombinedAI(row), aiValues, ...
            Neuro, coherence, availableChannelCount, deadChannels, ...
            options.ChannelMap, options.TuningAlpha);
        [plus1Channel(row), plus1CombinedAI(row), ...
            plus1CombinedP(row), plus1Significant(row), ...
            plus1SignFlip(row), plus1Status(row)] = evaluateNeighbor( ...
            1, stimProbePosition(row), stimCombinedAI(row), aiValues, ...
            Neuro, coherence, availableChannelCount, deadChannels, ...
            options.ChannelMap, options.TuningAlpha);
        if options.NeighborRadius >= 2
            [plus2Channel(row), plus2CombinedAI(row), ...
                plus2CombinedP(row), plus2Significant(row), ...
                plus2SignFlip(row), plus2Status(row)] = evaluateNeighbor( ...
                2, stimProbePosition(row), stimCombinedAI(row), aiValues, ...
                Neuro, coherence, availableChannelCount, deadChannels, ...
                options.ChannelMap, options.TuningAlpha);
        end

        significantAdjacentCount(row) = ...
            double(minus2Significant(row)) + ...
            double(minus1Significant(row)) + ...
            double(plus1Significant(row)) + ...
            double(plus2Significant(row));
        oppositeSignificantAdjacentCount(row) = ...
            double(minus2SignFlip(row)) + double(minus1SignFlip(row)) + ...
            double(plus1SignFlip(row)) + double(plus2SignFlip(row));
        excludeForAIFlip(row) = ...
            oppositeSignificantAdjacentCount(row) > 0;
        status(row) = "Success";
    catch ME
        status(row) = "Error";
        message(row) = string(ME.identifier) + ": " + string(ME.message);
    end
end

neighborRadius = repmat(options.NeighborRadius, rowCount, 1);
audit = table(tableRow, monkey, recordingDate, roi, candidateMask, ...
    neighborRadius, ...
    stimChannel, stimProbePosition, stimCombinedAI, ...
    minus2Channel, minus2CombinedAI, minus2CombinedP, ...
    minus2Significant, minus2SignFlip, minus2Status, ...
    minus1Channel, minus1CombinedAI, minus1CombinedP, ...
    minus1Significant, minus1SignFlip, minus1Status, ...
    plus1Channel, plus1CombinedAI, plus1CombinedP, ...
    plus1Significant, plus1SignFlip, plus1Status, ...
    plus2Channel, plus2CombinedAI, plus2CombinedP, ...
    plus2Significant, plus2SignFlip, plus2Status, ...
    significantAdjacentCount, oppositeSignificantAdjacentCount, ...
    excludeForAIFlip, cacheFile, status, message, ...
    'VariableNames', {'TableRow', 'Monkey', 'Date', 'ROI', ...
    'CandidateForPopulation', 'NeighborRadius', ...
    'StimChannel', 'StimProbePosition', ...
    'StimCombinedAI', 'Minus2Channel', 'Minus2CombinedAI', ...
    'Minus2CombinedP', 'Minus2Significant', 'Minus2SignFlip', ...
    'Minus2Status', ...
    'Minus1Channel', 'Minus1CombinedAI', ...
    'Minus1CombinedP', 'Minus1Significant', 'Minus1SignFlip', ...
    'Minus1Status', 'Plus1Channel', 'Plus1CombinedAI', ...
    'Plus1CombinedP', 'Plus1Significant', 'Plus1SignFlip', ...
    'Plus1Status', 'Plus2Channel', 'Plus2CombinedAI', ...
    'Plus2CombinedP', 'Plus2Significant', 'Plus2SignFlip', ...
    'Plus2Status', 'SignificantAdjacentCount', ...
    'OppositeSignificantAdjacentCount', 'ExcludeForAIFlip', ...
    'CacheFile', 'Status', 'Message'});
audit.Properties.Description = sprintf([ ...
    'Physical-neighbor combined-cue AI consistency audit using %d ' ...
    'contact(s) on each side. ExcludeForAIFlip is true when at least ' ...
    'one live evaluated contact ' ...
    'has raw combined-cue direction-tuning p < %.6g and AI sign opposite ' ...
    'to the stimulation channel.'], options.NeighborRadius, ...
    options.TuningAlpha);
end


function [channel, combinedAI, combinedP, significant, signFlip, status] = ...
    evaluateNeighbor(relativePosition, stimPosition, stimAI, aiValues, ...
    Neuro, coherence, availableChannelCount, deadChannels, channelMap, alpha)
channel = NaN;
combinedAI = NaN;
combinedP = NaN;
significant = false;
signFlip = false;
probePosition = stimPosition + relativePosition;
if probePosition < 1 || probePosition > numel(channelMap)
    status = "OutsideProbe";
    return
end
channel = channelMap(probePosition);
if channel > availableChannelCount
    status = "UnavailableChannel";
    return
end
if ismember(channel, deadChannels)
    status = "DeadChannel";
    return
end
combinedAI = double(aiValues(1, channel));
combinedP = computeCombinedTuningPValue(Neuro, channel, coherence);
significant = isfinite(combinedP) && combinedP < alpha;
signFlip = significant && isfinite(stimAI) && isfinite(combinedAI) && ...
    stimAI ~= 0 && combinedAI ~= 0 && sign(stimAI) ~= sign(combinedAI);
status = "Evaluated";
end


function pValue = computeCombinedTuningPValue(Neuro, channel, coherence)
pValue = NaN;
rows = table();
cue = 1;
maximumIndex = min([numel(coherence), size(Neuro.All, 2), ...
    size(Neuro.Trials.NumTrials, 2)]);
for coherenceIndex = 1:maximumIndex
    trialCount = Neuro.Trials.NumTrials(cue, coherenceIndex);
    if ~isfinite(trialCount) || trialCount <= 0
        continue
    end
    trialCount = min(trialCount, size(Neuro.All, 3));
    firingRate = squeeze(Neuro.All( ...
        cue, coherenceIndex, 1:trialCount, channel));
    firingRate = firingRate(isfinite(firingRate));
    if isempty(firingRate)
        continue
    end
    coherenceColumn = repelem( ...
        coherence(coherenceIndex), numel(firingRate), 1);
    rows = [rows; table(firingRate(:), coherenceColumn(:), ...
        'VariableNames', {'FR', 'Coherence'})]; %#ok<AGROW>
end
if height(rows) < 4 || std(rows.FR) <= eps
    return
end
try
    rows.Abs_Coherence = abs(rows.Coherence);
    rows.Direction = sign(rows.Coherence);
    model = fitlm(rows, 'FR ~ Abs_Coherence + Direction');
    result = anova(model);
    pValue = result.pValue(2);
catch
    pValue = NaN;
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
        error('AdjacentAIFlip:UnknownCoherenceGrid', ...
            'Expected 8, 12, or 13 Quick coherence values; found %d.', ...
            size(Neuro.All, 2));
end
coherence = numerator ./ 22;
end


function validateNeuro(Neuro)
required = {'All', 'Trials'};
missing = required(~isfield(Neuro, required));
if ~isempty(missing) || ~isfield(Neuro.Trials, 'NumTrials') || ...
        ndims(Neuro.All) ~= 4 || size(Neuro.All, 1) < 1 || ...
        size(Neuro.Trials.NumTrials, 1) < 1
    error('AdjacentAIFlip:InvalidNeuro', ...
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
    tokens = regexp(char(string(value)), '\d+', 'match');
    channels = str2double(tokens);
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
    error('AdjacentAIFlip:UnknownMonkey', 'Unknown monkey: %s', monkey);
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
else
    dates = dateshift(datetime(string(values(:))), 'start', 'day');
end
end


function requireVariables(tableData, required)
missing = setdiff(required, string(tableData.Properties.VariableNames));
if ~isempty(missing)
    error('AdjacentAIFlip:MissingVariables', ...
        'Missing required variable(s): %s', join(missing, ', '));
end
end


function value = numericArray(column, row)
value = getRowValue(column, row);
while iscell(value) && isscalar(value)
    value = value{1};
end
if ~isnumeric(value)
    error('AdjacentAIFlip:ExpectedNumericValue', ...
        'Expected numeric data at row %d.', row);
end
value = double(value);
end


function value = numericScalar(column, row)
value = numericArray(column, row);
if ~isscalar(value)
    error('AdjacentAIFlip:ExpectedNumericScalar', ...
        'Expected a numeric scalar at row %d.', row);
end
end


function value = getRowText(column, row)
value = getRowValue(column, row);
while iscell(value) && isscalar(value)
    value = value{1};
end
value = string(value);
if ~isscalar(value)
    value = join(value, ",");
end
end


function value = getRowValue(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
end

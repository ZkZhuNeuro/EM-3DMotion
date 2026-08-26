function audit = AuditAdjacentQuickChannelODFlips(unitTable, options)
%AUDITADJACENTQUICKCHANNELODFLIPS Find local dominant-eye reversals.
%
% A site is flagged when at least one live physical neighbor within the
% requested radius has a nonzero OD_max_all sign opposite to the
% stimulation contact. Missing, dead, unavailable, zero, and nonfinite OD
% contacts are audited but do not trigger exclusion.

arguments
    unitTable table
    options.ChannelMap (1, :) double ...
        {mustBeInteger, mustBePositive} = ...
        [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]
    options.NeighborRadius (1, 1) double ...
        {mustBeInteger, mustBeMember(options.NeighborRadius, [1, 2])} = 2
    options.CandidateMask (:, 1) logical = false(0, 1)
end

required = ["Date", "Monkey", "StimElec", "NChannels", "OD_max_all"];
missing = setdiff(required, string(unitTable.Properties.VariableNames));
if ~isempty(missing)
    error('AdjacentODFlip:MissingVariables', ...
        'Missing required variable(s): %s.', join(missing, ', '));
end

rowCount = height(unitTable);
candidateMask = options.CandidateMask;
if isempty(candidateMask)
    candidateMask = true(rowCount, 1);
elseif numel(candidateMask) ~= rowCount
    error('AdjacentODFlip:CandidateMaskSize', ...
        'CandidateMask must contain one value per unit-table row.');
end

tableRow = (1:rowCount)';
monkey = strings(rowCount, 1);
recordingDate = normalizeDateColumn(unitTable.Date);
roi = repmat("", rowCount, 1);
stimChannel = nan(rowCount, 1);
stimProbePosition = nan(rowCount, 1);
stimOD = nan(rowCount, 1);

offsets = [-2, -1, 1, 2];
channels = nan(rowCount, numel(offsets));
od = nan(rowCount, numel(offsets));
signFlip = false(rowCount, numel(offsets));
neighborStatus = repmat("NotRequested", rowCount, numel(offsets));
evaluatedNeighborCount = zeros(rowCount, 1);
oppositeODNeighborCount = zeros(rowCount, 1);
excludeForODFlip = false(rowCount, 1);
allRequestedNeighborsEvaluated = false(rowCount, 1);
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
        odValues = numericArray(unitTable.OD_max_all, row);
        odValues = odValues(:)';
        availableChannelCount = min(declaredChannelCount, numel(odValues));
        validateChannel(stimChannel(row), availableChannelCount, ...
            'stimulation channel');
        thisStimPosition = find( ...
            options.ChannelMap == stimChannel(row), 1);
        if isempty(thisStimPosition)
            error('AdjacentODFlip:UnmappedStimChannel', ...
                'Stimulation channel is absent from ChannelMap.');
        end
        stimProbePosition(row) = thisStimPosition;
        stimOD(row) = double(odValues(stimChannel(row)));
        if ~isfinite(stimOD(row)) || stimOD(row) == 0
            error('AdjacentODFlip:InvalidStimOD', ...
                'Stimulation-contact OD_max_all is zero or nonfinite.');
        end

        deadChannels = getDeadChannels(unitTable, row);
        requested = abs(offsets) <= options.NeighborRadius;
        for index = find(requested)
            [channels(row, index), od(row, index), ...
                signFlip(row, index), neighborStatus(row, index)] = ...
                evaluateNeighbor(offsets(index), stimProbePosition(row), ...
                stimOD(row), odValues, availableChannelCount, deadChannels, ...
                options.ChannelMap);
        end
        evaluated = requested & neighborStatus(row, :) == "Evaluated";
        evaluatedNeighborCount(row) = sum(evaluated);
        oppositeODNeighborCount(row) = sum(signFlip(row, requested));
        excludeForODFlip(row) = oppositeODNeighborCount(row) > 0;
        allRequestedNeighborsEvaluated(row) = all(evaluated(requested));
        status(row) = "Success";
    catch ME
        status(row) = "Error";
        message(row) = string(ME.identifier) + ": " + string(ME.message);
    end
end

neighborRadius = repmat(options.NeighborRadius, rowCount, 1);
audit = table(tableRow, monkey, recordingDate, roi, candidateMask, ...
    neighborRadius, stimChannel, stimProbePosition, stimOD, ...
    channels(:, 1), od(:, 1), signFlip(:, 1), neighborStatus(:, 1), ...
    channels(:, 2), od(:, 2), signFlip(:, 2), neighborStatus(:, 2), ...
    channels(:, 3), od(:, 3), signFlip(:, 3), neighborStatus(:, 3), ...
    channels(:, 4), od(:, 4), signFlip(:, 4), neighborStatus(:, 4), ...
    evaluatedNeighborCount, oppositeODNeighborCount, ...
    allRequestedNeighborsEvaluated, excludeForODFlip, status, message, ...
    'VariableNames', {'TableRow', 'Monkey', 'Date', 'ROI', ...
    'CandidateForAudit', 'NeighborRadius', 'StimChannel', ...
    'StimProbePosition', 'StimOD', ...
    'Minus2Channel', 'Minus2OD', 'Minus2ODSignFlip', 'Minus2Status', ...
    'Minus1Channel', 'Minus1OD', 'Minus1ODSignFlip', 'Minus1Status', ...
    'Plus1Channel', 'Plus1OD', 'Plus1ODSignFlip', 'Plus1Status', ...
    'Plus2Channel', 'Plus2OD', 'Plus2ODSignFlip', 'Plus2Status', ...
    'EvaluatedNeighborCount', 'OppositeODNeighborCount', ...
    'AllRequestedNeighborsEvaluated', 'ExcludeForODFlip', ...
    'Status', 'Message'});
audit.Properties.Description = sprintf([ ...
    'OD_max_all dominant-eye continuity over %d contact(s) on each side. ' ...
    'ExcludeForODFlip is true when any evaluated live neighbor has a ' ...
    'nonzero OD sign opposite to the stimulation contact.'], ...
    options.NeighborRadius);
end


function [channel, od, signFlip, status] = evaluateNeighbor( ...
        offset, stimPosition, stimOD, odValues, availableChannelCount, ...
        deadChannels, channelMap)
channel = NaN;
od = NaN;
signFlip = false;
probePosition = stimPosition + offset;
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
od = double(odValues(channel));
if ~isfinite(od)
    status = "NonfiniteOD";
    return
end
if od == 0
    status = "ZeroOD";
    return
end
signFlip = sign(od) ~= sign(stimOD);
status = "Evaluated";
end


function validateChannel(channel, availableChannelCount, label)
if ~isscalar(channel) || ~isfinite(channel) || channel < 1 || ...
        channel ~= fix(channel) || channel > availableChannelCount
    error('AdjacentODFlip:InvalidChannel', ...
        '%s is outside the available channel range.', label);
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


function value = numericScalar(column, row)
value = numericArray(column, row);
if ~isscalar(value)
    error('AdjacentODFlip:ExpectedScalar', ...
        'Expected one numeric scalar at row %d.', row);
end
value = double(value);
end


function value = numericArray(column, row)
value = getRowValue(column, row);
while iscell(value) && isscalar(value)
    value = value{1};
end
if ~isnumeric(value)
    error('AdjacentODFlip:ExpectedNumeric', ...
        'Expected numeric data at row %d.', row);
end
value = double(value);
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

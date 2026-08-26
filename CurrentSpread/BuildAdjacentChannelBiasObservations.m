function observations = BuildAdjacentChannelBiasObservations( ...
    unitTable, deltaBias, validBiasFit, options)
%BUILDADJACENTCHANNELBIASOBSERVATIONS Assemble cue-specific model rows.
%
% Each output row is one session/cue observation. Channel offsets are physical
% probe positions, not numeric channel differences. Dominant and non-dominant
% cue identities follow the sign of OD_max at the stimulation channel, matching
% RunPopulationAnalysis_ODweighted.

arguments
    unitTable table
    deltaBias double
    validBiasFit logical
    options.Areas (1, :) string = ["MT", "FST"]
    options.UnitTypes (1, :) string = ["2D", "3D"]
    options.Conditions (1, :) string = ...
        ["Dominant", "Combined", "Stereo", "NonDominant"]
    options.NeighborRadius (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 1
    options.ChannelMap (1, :) double ...
        {mustBeInteger, mustBePositive} = ...
        [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]
end

requiredVariables = ["Date", "ROI", "Monkey", "NChannels", ...
    "StimElec", "DeadChannel", "p_AI", "AI", "OD_max", ...
    "Z3D_v_Z2D"];
missingVariables = setdiff(requiredVariables, ...
    string(unitTable.Properties.VariableNames));
if ~isempty(missingVariables)
    error('AdjacentChannelModel:MissingVariables', ...
        'unitTable is missing required variable(s): %s.', ...
        strjoin(missingVariables, ', '));
end

rowCount = height(unitTable);
if size(deltaBias, 1) ~= rowCount || size(deltaBias, 2) < 4 || ...
        ~isequal(size(deltaBias), size(validBiasFit))
    error('AdjacentChannelModel:BiasSizeMismatch', ...
        ['deltaBias and validBiasFit must have one row per unit-table row ' ...
        'and at least four cue columns.']);
end

areas = upper(strtrim(options.Areas));
unitTypes = upper(strtrim(options.UnitTypes));
conditions = canonicalConditionNames(options.Conditions);
relativePositions = -options.NeighborRadius:options.NeighborRadius;
observationCapacity = rowCount * numel(conditions);

date = strings(observationCapacity, 1);
area = strings(observationCapacity, 1);
monkey = strings(observationCapacity, 1);
unitType = strings(observationCapacity, 1);
condition = strings(observationCapacity, 1);
conditionIndex = nan(observationCapacity, 1);
sourceCueIndex = nan(observationCapacity, 1);
unitTableRow = nan(observationCapacity, 1);
originalRecIdx = nan(observationCapacity, 1);
stimulationChannel = nan(observationCapacity, 1);
stimulationProbePosition = nan(observationCapacity, 1);
odRaw = nan(observationCapacity, 1);
absOD = nan(observationCapacity, 1);
z3DMinusZ2D = nan(observationCapacity, 1);
pAILeft = nan(observationCapacity, 1);
pAIRight = nan(observationCapacity, 1);
bias = nan(observationCapacity, 1);
actualChannel = nan(observationCapacity, numel(relativePositions));
channelAI = nan(observationCapacity, numel(relativePositions));
availabilityStatus = strings(observationCapacity, numel(relativePositions));

writeIndex = 0;
for row = 1:rowCount
    thisArea = upper(strtrim(rowText(unitTable.ROI, row)));
    if ~ismember(thisArea, areas)
        continue
    end

    pAI = rowNumericArray(unitTable.p_AI, row);
    if numel(pAI) < 3 || ~isfinite(pAI(2)) || ~isfinite(pAI(3)) || ...
            pAI(2) >= 0.05 || pAI(3) >= 0.05
        continue
    end

    zValue = rowNumericScalar(unitTable.Z3D_v_Z2D, row);
    if zValue < 0
        thisUnitType = "2D";
    elseif zValue > 0
        thisUnitType = "3D";
    else
        continue
    end
    if ~ismember(thisUnitType, unitTypes)
        continue
    end

    odValue = rowNumericScalar(unitTable.OD_max, row);
    if ~isfinite(odValue)
        continue
    elseif odValue > 0
        conditionToCue = [2 1 4 3];
    else
        conditionToCue = [3 1 4 2];
    end

    stimChannel = rowNumericScalar(unitTable.StimElec, row);
    stimProbeIndex = find(options.ChannelMap == stimChannel, 1);
    if isempty(stimProbeIndex)
        continue
    end

    aiValues = rowNumericArray(unitTable.AI, row);
    declaredChannelCount = rowNumericScalar(unitTable.NChannels, row);
    deadChannels = rowNumericArray(unitTable.DeadChannel, row);

    for requestedCondition = conditions
        canonicalIndex = find(["Dominant", "Combined", "Stereo", ...
            "NonDominant"] == requestedCondition, 1);
        cueIndex = conditionToCue(canonicalIndex);
        if cueIndex > size(deltaBias, 2) || ...
                ~validBiasFit(row, cueIndex) || ...
                ~isfinite(deltaBias(row, cueIndex))
            continue
        end

        writeIndex = writeIndex + 1;
        date(writeIndex) = rowText(unitTable.Date, row);
        area(writeIndex) = thisArea;
        monkey(writeIndex) = rowText(unitTable.Monkey, row);
        unitType(writeIndex) = thisUnitType;
        condition(writeIndex) = requestedCondition;
        conditionIndex(writeIndex) = canonicalIndex;
        sourceCueIndex(writeIndex) = cueIndex;
        unitTableRow(writeIndex) = row;
        originalRecIdx(writeIndex) = optionalNumericScalar( ...
            unitTable, 'OriginalRecIdx', row);
        stimulationChannel(writeIndex) = stimChannel;
        stimulationProbePosition(writeIndex) = stimProbeIndex;
        odRaw(writeIndex) = odValue;
        absOD(writeIndex) = abs(odValue);
        z3DMinusZ2D(writeIndex) = zValue;
        pAILeft(writeIndex) = pAI(2);
        pAIRight(writeIndex) = pAI(3);
        bias(writeIndex) = deltaBias(row, cueIndex);

        for positionIndex = 1:numel(relativePositions)
            [actualChannel(writeIndex, positionIndex), ...
                channelAI(writeIndex, positionIndex), ...
                availabilityStatus(writeIndex, positionIndex)] = ...
                channelAtRelativePosition(aiValues, cueIndex, ...
                stimProbeIndex, relativePositions(positionIndex), ...
                declaredChannelCount, deadChannels, options.ChannelMap);
        end
    end
end

keep = 1:writeIndex;
observations = table(date(keep), area(keep), monkey(keep), ...
    unitType(keep), condition(keep), conditionIndex(keep), ...
    sourceCueIndex(keep), unitTableRow(keep), originalRecIdx(keep), ...
    stimulationChannel(keep), stimulationProbePosition(keep), ...
    odRaw(keep), absOD(keep), z3DMinusZ2D(keep), pAILeft(keep), ...
    pAIRight(keep), bias(keep), ...
    'VariableNames', {'Date', 'Area', 'Monkey', 'UnitType', 'Condition', ...
    'ConditionIndex', 'SourceCueIndex', 'UnitTableRow', ...
    'OriginalRecIdx', 'StimulationChannel', ...
    'StimulationProbePosition', 'ODRaw', 'OD', 'Z3DMinusZ2D', ...
    'PAILeft', 'PAIRight', 'Bias'});

for positionIndex = 1:numel(relativePositions)
    tag = relativePositionTag(relativePositions(positionIndex));
    observations.(['Channel_' tag]) = ...
        actualChannel(keep, positionIndex);
    observations.(['AI_' tag]) = channelAI(keep, positionIndex);
    observations.(['Status_' tag]) = ...
        availabilityStatus(keep, positionIndex);
end

observations.Properties.Description = sprintf([ ...
    'Cue-specific adjacent-channel model observations. Physical offsets %s ' ...
    'use channel map %s. Cohort requires MonoL and MonoR p_AI < 0.05; ' ...
    '2D/3D uses the sign of Z3D_v_Z2D; Bias is NoStim minus Stim.'], ...
    mat2str(relativePositions), mat2str(options.ChannelMap));
end


function conditions = canonicalConditionNames(inputConditions)
canonical = ["Dominant", "Combined", "Stereo", "NonDominant"];
conditions = strings(size(inputConditions));
for index = 1:numel(inputConditions)
    normalized = lower(regexprep(strtrim(inputConditions(index)), ...
        '[^a-zA-Z]', ''));
    matchIndex = find(lower(canonical) == normalized, 1);
    if isempty(matchIndex)
        error('AdjacentChannelModel:UnknownCondition', ...
            'Unknown condition "%s".', inputConditions(index));
    end
    conditions(index) = canonical(matchIndex);
end
conditions = unique(conditions, 'stable');
end


function [channel, ai, status] = channelAtRelativePosition( ...
    aiValues, cueIndex, stimProbeIndex, relativePosition, ...
    declaredChannelCount, deadChannels, channelMap)
channel = nan;
ai = nan;
status = "available";

probeIndex = stimProbeIndex + relativePosition;
if probeIndex < 1 || probeIndex > numel(channelMap)
    status = "outside probe";
    return
end

channel = channelMap(probeIndex);
if ~isfinite(declaredChannelCount) || channel > declaredChannelCount || ...
        cueIndex > size(aiValues, 1) || channel > size(aiValues, 2)
    status = "unavailable channel";
    return
end
if ismember(channel, deadChannels)
    status = "dead channel";
    return
end

value = aiValues(cueIndex, channel);
if ~isfinite(value)
    status = "nonfinite AI";
    return
end
ai = double(value);
end


function tag = relativePositionTag(relativePosition)
if relativePosition < 0
    tag = sprintf('m%02d', abs(relativePosition));
elseif relativePosition > 0
    tag = sprintf('p%02d', relativePosition);
else
    tag = 'zero';
end
end


function value = optionalNumericScalar(inputTable, variableName, row)
if ~ismember(variableName, inputTable.Properties.VariableNames)
    value = nan;
else
    value = rowNumericScalar(inputTable.(variableName), row);
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
elseif iscategorical(column) || isstring(column)
    value = string(column(row));
elseif ischar(column)
    value = string(column(row, :));
elseif isnumeric(column)
    value = string(column(row, :));
else
    value = string(column(row));
end
value = strtrim(value(1));
end

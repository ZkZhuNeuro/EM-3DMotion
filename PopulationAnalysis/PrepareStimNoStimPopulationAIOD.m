function [unit_table_stim, audit] = ...
    PrepareStimNoStimPopulationAIOD(unit_table_stim)
%PREPARESTIMNOSTIMPOPULATIONAIOD Add Stim-task NoStim AI and OD columns.
%
% This function leaves the inherited 3DMotionQuick AI and OD_max columns
% unchanged. It appends two population-analysis source columns calculated
% from the stimulation electrode's non-electrical-stimulation tuning:
%
%   stim_noStim_AI      - four cues in Combined/MonoL/MonoR/Stereo order;
%   stim_noStim_OD_max  - signed OD, positive for left-eye dominance.
%
% Rows without a successful stimulation-tuning extraction receive NaNs so
% the population analysis cannot silently fall back to Quick-task values.

if ~istable(unit_table_stim)
    error('StimNoStimPopulationAIOD:InputNotTable', ...
        'Input must be the unit_table_stim table.');
end

requiredVariables = [ ...
    "Date", "Monkey", "StimElec", "NChannels", "stim_tuning_status", ...
    "stim_tuning_mean_noStim", "stim_tuning_SEM_noStim", ...
    "stim_tuning_n_noStim", "stim_tuning_coherence", ...
    "stim_tuning_condition_names"];
missingVariables = setdiff(requiredVariables, ...
    string(unit_table_stim.Properties.VariableNames));
if ~isempty(missingVariables)
    error('StimNoStimPopulationAIOD:MissingVariables', ...
        'unit_table_stim is missing required variable(s): %s', ...
        join(missingVariables, ', '));
end

rowCount = height(unit_table_stim);
unit_table_stim.stim_noStim_AI = repmat({nan(4, 1)}, rowCount, 1);
unit_table_stim.stim_noStim_OD_max = nan(rowCount, 1);
unit_table_stim.stim_noStim_index_status = ...
    repmat("Pending", rowCount, 1);
unit_table_stim.stim_noStim_index_message = strings(rowCount, 1);

tableRow = (1:rowCount)';
monkey = strings(rowCount, 1);
recordingDate = normalizeDateColumn(unit_table_stim.Date);
stimElec = nan(rowCount, 1);
nChannels = nan(rowCount, 1);
inputStatus = strings(rowCount, 1);
indexStatus = strings(rowCount, 1);
message = strings(rowCount, 1);
AI_Combined = nan(rowCount, 1);
AI_MonoL = nan(rowCount, 1);
AI_MonoR = nan(rowCount, 1);
AI_Stereo = nan(rowCount, 1);
OD_max = nan(rowCount, 1);
dominantEye = repmat("Undefined", rowCount, 1);
validPairs_Combined = zeros(rowCount, 1);
validPairs_MonoL = zeros(rowCount, 1);
validPairs_MonoR = zeros(rowCount, 1);
validPairs_Stereo = zeros(rowCount, 1);
odSupportCount = zeros(rowCount, 1);
odLeftFiniteCount = zeros(rowCount, 1);
odRightFiniteCount = zeros(rowCount, 1);

for row = 1:rowCount
    monkey(row) = getRowText(unit_table_stim.Monkey, row);
    stimElec(row) = getRowScalar(unit_table_stim.StimElec, row);
    nChannels(row) = getRowScalar(unit_table_stim.NChannels, row);
    inputStatus(row) = string(unit_table_stim.stim_tuning_status(row));

    if ~startsWith(inputStatus(row), "Success")
        indexStatus(row) = "SkippedInputStatus";
        message(row) = "Input stimulation tuning status: " + ...
            inputStatus(row);
        continue
    end

    try
        meanTuning = getCellValue( ...
            unit_table_stim.stim_tuning_mean_noStim, row);
        semTuning = getCellValue( ...
            unit_table_stim.stim_tuning_SEM_noStim, row);
        countTuning = getCellValue( ...
            unit_table_stim.stim_tuning_n_noStim, row);
        coherence = getCellValue( ...
            unit_table_stim.stim_tuning_coherence, row);
        conditionNames = getCellValue( ...
            unit_table_stim.stim_tuning_condition_names, row);
        validateCueOrder(conditionNames);
        if size(meanTuning, 3) ~= nChannels(row)
            error('StimNoStimPopulationAIOD:ChannelCountMismatch', ...
                ['Tuning has %d acquisition channels but NChannels ' ...
                'declares %d.'], size(meanTuning, 3), nChannels(row));
        end
        [rowAI, rowOD, details] = CalculateStimNoStimAIOD( ...
            meanTuning, semTuning, countTuning, coherence, stimElec(row));

        unit_table_stim.stim_noStim_AI{row} = rowAI;
        unit_table_stim.stim_noStim_OD_max(row) = rowOD;
        AI_Combined(row) = rowAI(1);
        AI_MonoL(row) = rowAI(2);
        AI_MonoR(row) = rowAI(3);
        AI_Stereo(row) = rowAI(4);
        OD_max(row) = rowOD;
        dominantEye(row) = details.DominantEye;
        validPairs_Combined(row) = details.ValidAIPairCount(1);
        validPairs_MonoL(row) = details.ValidAIPairCount(2);
        validPairs_MonoR(row) = details.ValidAIPairCount(3);
        validPairs_Stereo(row) = details.ValidAIPairCount(4);
        odSupportCount(row) = numel(details.ODCoherence);
        odLeftFiniteCount(row) = details.ODLeftFiniteCount;
        odRightFiniteCount(row) = details.ODRightFiniteCount;

        fullAISupport = all(details.ValidAIPairCount == ...
            numel(details.CoherencePairMagnitudes));
        fullODSupport = details.ODLeftFiniteCount == ...
            numel(details.ODCoherence) && ...
            details.ODRightFiniteCount == numel(details.ODCoherence);
        if isfinite(rowOD) && all(isfinite(rowAI)) && ...
                fullAISupport && fullODSupport
            indexStatus(row) = "Success";
        elseif isfinite(rowOD) && any(isfinite(rowAI))
            indexStatus(row) = "PartialSupport";
            message(row) = sprintf( ...
                ['Finite cue AIs=%d/4; AI pairs=[%s]/6; ' ...
                'OD finite bins L/R/support=%d/%d/%d.'], ...
                nnz(isfinite(rowAI)), num2str(details.ValidAIPairCount(:)'), ...
                details.ODLeftFiniteCount, details.ODRightFiniteCount, ...
                numel(details.ODCoherence));
        else
            indexStatus(row) = "InvalidIndices";
            message(row) = ...
                "No finite OD or no finite cue-specific AI was available.";
        end
    catch ME
        indexStatus(row) = "CalculationError";
        message(row) = string(ME.identifier) + ": " + string(ME.message);
    end
end

unit_table_stim.stim_noStim_index_status = indexStatus;
unit_table_stim.stim_noStim_index_message = message;

audit = table(tableRow, monkey, recordingDate, stimElec, nChannels, inputStatus, ...
    indexStatus, message, AI_Combined, AI_MonoL, AI_MonoR, AI_Stereo, ...
    OD_max, dominantEye, validPairs_Combined, validPairs_MonoL, ...
    validPairs_MonoR, validPairs_Stereo, odSupportCount, ...
    odLeftFiniteCount, odRightFiniteCount, ...
    'VariableNames', {'TableRow', 'Monkey', 'Date', 'StimElec', ...
    'NChannels', 'InputStatus', 'IndexStatus', 'Message', 'AI_Combined', 'AI_MonoL', ...
    'AI_MonoR', 'AI_Stereo', 'OD_max', 'DominantEye', ...
    'ValidPairs_Combined', 'ValidPairs_MonoL', 'ValidPairs_MonoR', ...
    'ValidPairs_Stereo', 'ODSupportCount', 'ODLeftFiniteCount', ...
    'ODRightFiniteCount'});
audit.Properties.Description = ...
    ['Stim-task non-electrical-stimulation AI/OD source audit. ' ...
    'Quick-task p_AI and Z3D_v_Z2D remain the population selection fields.'];
end


function value = getCellValue(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
end


function value = getRowText(column, row)
if iscell(column)
    value = string(column{row});
else
    value = string(column(row));
end
end


function value = getRowScalar(column, row)
value = getCellValue(column, row);
if iscell(value) && isscalar(value)
    value = value{1};
end
if isstring(value) || ischar(value) || iscategorical(value)
    value = str2double(string(value));
end
value = double(value);
end


function dates = normalizeDateColumn(values)
if iscell(values)
    values = string(values);
end
if isdatetime(values)
    dates = dateshift(values, 'start', 'day');
elseif isnumeric(values)
    if all(isnan(values) | values > 1e7)
        dates = datetime(string(values), 'InputFormat', 'yyyyMMdd');
    else
        dates = datetime(values, 'ConvertFrom', 'datenum');
    end
    dates = dateshift(dates, 'start', 'day');
else
    dates = dateshift(datetime(string(values)), 'start', 'day');
end
end


function validateCueOrder(conditionNames)
conditionNames = lower(strip(string(conditionNames)));
conditionNames = regexprep(conditionNames(:), '[^a-z0-9]', '');
valid = numel(conditionNames) == 4 && ...
    conditionNames(1) == "combined" && ...
    conditionNames(2) == "monol" && ...
    conditionNames(3) == "monor" && ...
    ismember(conditionNames(4), ["binocular", "stereo"]);
if ~valid
    error('StimNoStimPopulationAIOD:UnexpectedCueOrder', ...
        ['Expected Combined, MonoL, MonoR, and Binocular/Stereo; ' ...
        'found: %s.'], join(conditionNames, ', '));
end
end

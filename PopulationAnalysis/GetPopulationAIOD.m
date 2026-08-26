function [aiValues, odMax] = ...
    GetPopulationAIOD(unitTable, row, tuningSource)
%GETPOPULATIONAIOD Select Quick or StimNoStim AI/OD for one GOF row.

if ~istable(unitTable)
    error('PopulationAnalysis:InputNotTable', ...
        'unitTable must be a table.');
end
validateattributes(row, {'numeric'}, ...
    {'scalar', 'integer', 'positive', '<=', height(unitTable)}, ...
    mfilename, 'row');
tuningSource = validatestring(tuningSource, {'Quick', 'StimNoStim'});

switch tuningSource
    case 'Quick'
        requireVariables(unitTable, ["StimElec", "AI", "OD_max"]);
        stimulationChannel = numericScalar(unitTable.StimElec, row);
        aiMatrix = getCellValue(unitTable.AI, row);
        if ~isnumeric(aiMatrix) || stimulationChannel > size(aiMatrix, 2)
            error('PopulationAnalysis:InvalidQuickAI', ...
                'Quick AI or StimElec is invalid at row %d.', row);
        end
        aiValues = double(aiMatrix(:, stimulationChannel));
        odMax = numericScalar(unitTable.OD_max, row);
    case 'StimNoStim'
        requireVariables(unitTable, ...
            ["stim_noStim_AI", "stim_noStim_OD_max"]);
        aiValues = getCellValue(unitTable.stim_noStim_AI, row);
        odMax = numericScalar(unitTable.stim_noStim_OD_max, row);
end

aiValues = double(aiValues(:));
odMax = double(odMax);
end


function requireVariables(tableData, required)
missing = setdiff(required, string(tableData.Properties.VariableNames));
if ~isempty(missing)
    error('PopulationAnalysis:MissingAIODVariables', ...
        'Missing AI/OD variable(s): %s', join(missing, ', '));
end
end


function value = getCellValue(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
end


function value = numericScalar(column, row)
value = getCellValue(column, row);
if iscell(value) && isscalar(value)
    value = value{1};
end
if isstring(value) || ischar(value) || iscategorical(value)
    value = str2double(string(value));
end
if ~isnumeric(value) || ~isscalar(value)
    error('PopulationAnalysis:ExpectedNumericScalar', ...
        'Expected a numeric scalar at table row %d.', row);
end
value = double(value);
end

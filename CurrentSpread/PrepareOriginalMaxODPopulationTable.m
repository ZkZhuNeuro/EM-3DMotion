function prepared = PrepareOriginalMaxODPopulationTable(unitTable)
%PREPAREORIGINALMAXODPOPULATIONTABLE Normalize original stimulation readout.
%
% Produces the compact schema consumed by RunUnifiedPopulationFromPreparedTable.
% AI is read from the original stimulation acquisition channel and signed
% OD is the stored original maximum-response OD_max.

arguments
    unitTable table
end

required = ["ROI", "Monkey", "Hole", "StimElec", "AI", "OD_max", ...
    "p_AI", "Z3D_v_Z2D", "Behav_bias_N", "Behav_bias_S", ...
    "Behav_goodfit_N", "Behav_goodfit_S"];
missing = setdiff(required, string(unitTable.Properties.VariableNames));
if ~isempty(missing)
    error('OriginalMaxODPrepared:MissingVariables', ...
        'Missing required variable(s): %s.', join(missing, ', '));
end

rowCount = height(unitTable);
keep = ["ROI", "Monkey", "Hole", "p_AI", "Z3D_v_Z2D", ...
    "Behav_bias_N", "Behav_bias_S", "Behav_goodfit_N", ...
    "Behav_goodfit_S"];
if ismember('Date', unitTable.Properties.VariableNames)
    keep = ["Date", keep];
end
prepared = unitTable(:, cellstr(keep));
prepared.SourceTableRow = (1:rowCount)';
prepared = movevars(prepared, 'SourceTableRow', 'Before', 1);
prepared.analysis_AI = repmat({nan(4, 1)}, rowCount, 1);
prepared.analysis_OD_signed = nan(rowCount, 1);
prepared.analysis_source_valid = false(rowCount, 1);
prepared.Analysis = repmat("OriginalMaxOD", rowCount, 1);

for row = 1:rowCount
    stimChannel = numericScalar(unitTable.StimElec, row);
    aiMatrix = numericArray(unitTable.AI, row);
    signedOD = numericScalar(unitTable.OD_max, row);
    if ~isfinite(stimChannel) || stimChannel ~= fix(stimChannel) || ...
            stimChannel < 1 || stimChannel > size(aiMatrix, 2) || ...
            size(aiMatrix, 1) < 4
        continue
    end
    selectedAI = double(aiMatrix(1:4, stimChannel));
    prepared.analysis_AI{row} = selectedAI;
    prepared.analysis_OD_signed(row) = signedOD;
    prepared.analysis_source_valid(row) = ...
        all(isfinite(selectedAI)) && isfinite(signedOD) && signedOD ~= 0;
end
end


function value = numericScalar(column, row)
value = numericArray(column, row);
if ~isscalar(value)
    error('OriginalMaxODPrepared:ExpectedScalar', ...
        'Expected a numeric scalar at row %d.', row);
end
value = double(value);
end


function value = numericArray(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
while iscell(value) && isscalar(value)
    value = value{1};
end
if ~isnumeric(value)
    error('OriginalMaxODPrepared:ExpectedNumeric', ...
        'Expected numeric data at row %d.', row);
end
value = double(value);
end

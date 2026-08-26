function [unit_table_stim, stim_file, pipeline_metadata, load_audit] = ...
    LoadUnitTableStimForPopulation(stim_file)
%LOADUNITTABLESTIMFORPOPULATION Load the authoritative Stim tuning table.
%
% The stimulation-task population analysis uses unit_table_stim directly;
% it does not refresh or join against unit_table_gof or the recording
% workbooks. Only rows with a Success* tuning status are returned; all
% artifact rows and their inclusion decisions remain in load_audit.

if nargin < 1 || isempty(stim_file)
    stim_file = 'C:\EM\StimTuningAnalysis\unit_table_stim.mat';
end
if ~(ischar(stim_file) || (isstring(stim_file) && isscalar(stim_file)))
    error('stim_file must be a character vector or string scalar.');
end
stim_file = char(stim_file);
if ~isfile(stim_file)
    error('unit_table_stim file not found: %s', stim_file);
end

file_variables = string({whos('-file', stim_file).name});
if ~ismember("unit_table_stim", file_variables)
    error('PopulationAnalysis:MissingStimTable', ...
        'The file "%s" does not contain table unit_table_stim.', ...
        stim_file);
end

loaded = load(stim_file, 'unit_table_stim');
if ~istable(loaded.unit_table_stim)
    error('PopulationAnalysis:StimTableNotTable', ...
        'The variable unit_table_stim in "%s" is not a table.', ...
        stim_file);
end
unit_table_stim = loaded.unit_table_stim;

if ~ismember('stim_tuning_status', ...
        unit_table_stim.Properties.VariableNames)
    error('PopulationAnalysis:MissingStimTuningStatus', ...
        'unit_table_stim is missing stim_tuning_status.');
end

pipeline_metadata = struct();
if ismember("PipelineMetadata", file_variables)
    metadata_input = load(stim_file, 'PipelineMetadata');
    pipeline_metadata = metadata_input.PipelineMetadata;
end

table_row = (1:height(unit_table_stim))';
status = strip(string(unit_table_stim.stim_tuning_status));
is_success = ~ismissing(status) & startsWith(status, "Success");
monkey = getAuditText(unit_table_stim, 'Monkey');
recording_date = getAuditDate(unit_table_stim);
load_audit = table(table_row, monkey, recording_date, status, is_success, ...
    'VariableNames', {'ArtifactTableRow', 'Monkey', 'Date', ...
    'StimTuningStatus', 'Included'});
load_audit.Properties.Description = ...
    ['Status audit for the authoritative unit_table_stim population ' ...
    'input. No current-GOF or workbook join was performed.'];

if ~any(is_success)
    error('PopulationAnalysis:NoCompletedStimTuningRows', ...
        ['unit_table_stim has no rows with a Success* tuning status. ' ...
        'Finish at least one row with RunAllUnitTableStimTunings first.']);
end

excluded_count = nnz(~is_success);
if excluded_count > 0
    warning('PopulationAnalysis:IncompleteStimTuningRowsExcluded', ...
        ['Using %d completed row(s) directly from unit_table_stim; ' ...
        '%d non-Success* row(s) were excluded. Inspect ' ...
        'population_results.stim_table_load_audit.'], ...
        nnz(is_success), excluded_count);
end

unit_table_stim.stim_tuning_artifact_table_row = table_row;
unit_table_stim = unit_table_stim(is_success, :);
end


function values = getAuditText(table_data, variable_name)
if ismember(variable_name, table_data.Properties.VariableNames)
    values = string(table_data.(variable_name));
    values = values(:);
else
    values = repmat("", height(table_data), 1);
end
end


function values = getAuditDate(table_data)
if ~ismember('Date', table_data.Properties.VariableNames)
    values = NaT(height(table_data), 1);
    return
end

input_values = table_data.Date;
if isdatetime(input_values)
    values = input_values(:);
elseif isnumeric(input_values)
    if all(isnan(input_values) | input_values > 1e7)
        values = datetime(string(input_values(:)), ...
            'InputFormat', 'yyyyMMdd');
    else
        values = datetime(input_values(:), 'ConvertFrom', 'datenum');
    end
else
    values = datetime(string(input_values(:)));
end
values = dateshift(values, 'start', 'day');
end

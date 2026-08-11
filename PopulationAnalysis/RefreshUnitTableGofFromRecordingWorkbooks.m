function [unit_table_gof, audit] = RefreshUnitTableGofFromRecordingWorkbooks( ...
    unit_table_gof, clay_workbook, jim_workbook)
% Refresh session selection and recording metadata from current workbooks.

if nargin < 2 || isempty(clay_workbook)
    clay_workbook = ...
        'P:\Clay\NeuroData\RecordingRecord_Stimulation.xlsx';
end
if nargin < 3 || isempty(jim_workbook)
    jim_workbook = ...
        'P:\Jim\NeuroData\RecordingRecord_Stimulation_final.xlsx';
end

required_table_variables = {'Monkey', 'Date', 'ROI', 'Hole', 'Depth', ...
    'Offset', 'Guide', 'StimLoc', 'NChannels', 'StimElec', ...
    'ROI_review', 'DeadChannel'};
missing_table_variables = setdiff(required_table_variables, ...
    unit_table_gof.Properties.VariableNames);
if ~isempty(missing_table_variables)
    error('unit_table_gof is missing recording fields: %s.', ...
        strjoin(missing_table_variables, ', '));
end

sources = {
    'Clay', char(clay_workbook);
    'Jim', char(jim_workbook)
};

row_count = height(unit_table_gof);
keep_row = false(row_count, 1);
workbook_path = strings(row_count, 1);
workbook_row = nan(row_count, 1);
missing_sessions = table();

for source_index = 1:size(sources, 1)
    monkey = string(sources{source_index, 1});
    source_file = sources{source_index, 2};
    if ~isfile(source_file)
        error('Recording workbook not found: %s', source_file);
    end

    recording_table = readtable(source_file, ...
        'VariableNamingRule', 'preserve');
    assert_workbook_columns(recording_table, source_file);

    recording_dates = normalize_dates(recording_table.Date);
    recording_roi = upper(strip(string(recording_table.ROI)));
    is_selected = strcmpi(strip(string(recording_table.MUAStim)), 'Y') & ...
        ismember(recording_roi, ["MT", "FST"]) & ~isnat(recording_dates);
    selected_rows = find(is_selected);
    selected_dates = recording_dates(selected_rows);

    if numel(unique(selected_dates)) ~= numel(selected_dates)
        error('%s has duplicate selected stimulation dates for %s.', ...
            source_file, monkey);
    end

    table_rows = find(strcmpi(strip(string(unit_table_gof.Monkey)), monkey));
    table_dates = normalize_dates(unit_table_gof.Date(table_rows));
    [matched, selected_index] = ismember(table_dates, selected_dates);
    matched_table_rows = table_rows(matched);
    matched_workbook_rows = selected_rows(selected_index(matched));

    keep_row(matched_table_rows) = true;
    workbook_path(matched_table_rows) = string(source_file);
    workbook_row(matched_table_rows) = matched_workbook_rows + 1;

    for match_index = 1:numel(matched_table_rows)
        table_row = matched_table_rows(match_index);
        source_row = matched_workbook_rows(match_index);

        unit_table_gof.ROI{table_row} = char(recording_roi(source_row));
        unit_table_gof.Hole(table_row, :) = parse_numeric_row( ...
            recording_table.Hole(source_row), 2, 'Hole');
        unit_table_gof.Depth(table_row) = parse_numeric_row( ...
            recording_table.Depth(source_row), 1, 'Depth');
        unit_table_gof.Offset(table_row, :) = parse_numeric_row( ...
            recording_table.Offset(source_row), 3, 'Offset');
        unit_table_gof.Guide(table_row) = parse_numeric_row( ...
            recording_table.('Guide Tube')(source_row), 1, 'Guide Tube');
        unit_table_gof.StimLoc(table_row, :) = parse_numeric_row( ...
            recording_table.('Stimulus Location')(source_row), 2, ...
            'Stimulus Location');
        unit_table_gof.NChannels(table_row) = parse_numeric_row( ...
            recording_table.Channels(source_row), 1, 'Channels');
        unit_table_gof.StimElec(table_row) = parse_numeric_row( ...
            recording_table.StimElec(source_row), 1, 'StimElec');

        roi_review = get_optional_text(recording_table, source_row, ...
            'Area_Ari_20230805');
        if strlength(roi_review) == 0
            roi_review = recording_roi(source_row);
        end
        unit_table_gof.ROI_review{table_row} = char(roi_review);
        unit_table_gof.DeadChannel{table_row} = get_optional_numeric_row( ...
            recording_table, source_row, 'DeadChannel');
    end

    missing_selected = ~ismember(selected_dates, table_dates);
    missing_rows = selected_rows(missing_selected);
    if ~isempty(missing_rows)
        new_missing = table( ...
            repmat(monkey, numel(missing_rows), 1), ...
            recording_dates(missing_rows), ...
            recording_roi(missing_rows), ...
            missing_rows + 1, ...
            repmat(string(source_file), numel(missing_rows), 1), ...
            'VariableNames', {'Monkey', 'Date', 'ROI', ...
            'WorkbookRow', 'WorkbookPath'});
        missing_sessions = [missing_sessions; new_missing]; %#ok<AGROW>
    end
end

removed_rows = unit_table_gof(~keep_row, {'Monkey', 'Date', 'ROI'});
unit_table_gof = unit_table_gof(keep_row, :);
unit_table_gof.RecordingWorkbookPath = workbook_path(keep_row);
unit_table_gof.RecordingWorkbookRow = workbook_row(keep_row);

audit = struct();
audit.ClayWorkbook = char(clay_workbook);
audit.JimWorkbook = char(jim_workbook);
audit.InputRowCount = row_count;
audit.OutputRowCount = height(unit_table_gof);
audit.RemovedRows = removed_rows;
audit.MissingSessions = missing_sessions;
end


function assert_workbook_columns(recording_table, source_file)
required = {'Date', 'ROI', 'MUAStim', 'Hole', 'Depth', 'Offset', ...
    'Guide Tube', 'Stimulus Location', 'Channels', 'StimElec'};
missing = setdiff(required, recording_table.Properties.VariableNames);
if ~isempty(missing)
    error('%s is missing required columns: %s.', ...
        source_file, strjoin(missing, ', '));
end
end


function dates = normalize_dates(values)
if isdatetime(values)
    dates = dateshift(values, 'start', 'day');
elseif isnumeric(values)
    dates = dateshift(datetime(values, 'ConvertFrom', 'excel'), ...
        'start', 'day');
else
    dates = dateshift(datetime(strip(string(values))), 'start', 'day');
end
end


function values = parse_numeric_row(value, expected_count, field_name)
if iscell(value)
    value = value{1};
end
if isnumeric(value)
    values = double(value(:).');
else
    text = regexprep(char(string(value)), '[\[\]]', '');
    values = sscanf(strrep(text, ',', ' '), '%f').';
end
if numel(values) ~= expected_count
    error('%s must contain %d numeric value(s); found %d.', ...
        field_name, expected_count, numel(values));
end
end


function value = get_optional_text(recording_table, row, variable_name)
value = "";
if ~ismember(variable_name, recording_table.Properties.VariableNames)
    return
end
raw_value = recording_table.(variable_name)(row);
if iscell(raw_value)
    raw_value = raw_value{1};
end
if ~isempty(raw_value) && ~ismissing(string(raw_value))
    value = strip(string(raw_value));
end
end


function values = get_optional_numeric_row(recording_table, row, variable_name)
values = [];
if ~ismember(variable_name, recording_table.Properties.VariableNames)
    return
end
raw_value = recording_table.(variable_name)(row);
if iscell(raw_value)
    raw_value = raw_value{1};
end
if isempty(raw_value) || ismissing(string(raw_value)) || ...
        strlength(strip(string(raw_value))) == 0
    return
end
if isnumeric(raw_value)
    values = double(raw_value(:).');
else
    text = regexprep(char(string(raw_value)), '[\[\]]', '');
    values = sscanf(strrep(text, ',', ' '), '%f').';
end
end

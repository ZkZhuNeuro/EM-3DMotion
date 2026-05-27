%% Compare saved MIDTable against prior unit_table
% Edit the two file paths below if needed, then run this script.

midtable_file = 'C:\EM\PopulationAnalysis\MIDTable_20260513.mat';
unittable_file = 'C:\EM\PopulationAnalysis\UnitTable_updating.mat';

mid_info = load_first_table_from_mat(midtable_file, {'MIDTable'});
unit_info = load_first_table_from_mat(unittable_file, {'unit_table', 'unit_table_gof'});

MIDTable = mid_info.Table;
unit_table = unit_info.Table;

key_columns = choose_session_key_columns(MIDTable, unit_table);

mid_keys = build_row_keys(MIDTable, key_columns);
unit_keys = build_row_keys(unit_table, key_columns);

[mid_unique_keys, mid_first_idx, mid_group_idx] = unique(mid_keys, 'stable');
[unit_unique_keys, unit_first_idx, unit_group_idx] = unique(unit_keys, 'stable');

[mid_only_keys, mid_only_unique_idx] = setdiff(mid_unique_keys, unit_unique_keys, 'stable');
[unit_only_keys, unit_only_unique_idx] = setdiff(unit_unique_keys, mid_unique_keys, 'stable');
[shared_keys, mid_shared_unique_idx, unit_shared_unique_idx] = intersect(mid_unique_keys, unit_unique_keys, 'stable');

mid_only_rows = build_session_summary_table(MIDTable, mid_unique_keys, mid_first_idx, mid_group_idx, mid_only_unique_idx);
unit_only_rows = build_session_summary_table(unit_table, unit_unique_keys, unit_first_idx, unit_group_idx, unit_only_unique_idx);

common_variables = intersect(MIDTable.Properties.VariableNames, unit_table.Properties.VariableNames, 'stable');
mid_only_variables = setdiff(MIDTable.Properties.VariableNames, unit_table.Properties.VariableNames, 'stable');
unit_only_variables = setdiff(unit_table.Properties.VariableNames, MIDTable.Properties.VariableNames, 'stable');

comparison_results = struct();
comparison_results.midtable_file = midtable_file;
comparison_results.unittable_file = unittable_file;
comparison_results.midtable_variable = mid_info.VariableName;
comparison_results.unittable_variable = unit_info.VariableName;
comparison_results.key_columns = key_columns;
comparison_results.n_midtable_rows = height(MIDTable);
comparison_results.n_unittable_rows = height(unit_table);
comparison_results.n_midtable_unique_sessions = numel(mid_unique_keys);
comparison_results.n_unittable_unique_sessions = numel(unit_unique_keys);
comparison_results.n_shared_sessions = numel(shared_keys);
comparison_results.mid_only_keys = mid_only_keys;
comparison_results.unit_only_keys = unit_only_keys;
comparison_results.mid_only_rows = mid_only_rows;
comparison_results.unit_only_rows = unit_only_rows;
comparison_results.common_variables = common_variables;
comparison_results.mid_only_variables = mid_only_variables;
comparison_results.unit_only_variables = unit_only_variables;
comparison_results.mid_shared_unique_indices = mid_shared_unique_idx;
comparison_results.unit_shared_unique_indices = unit_shared_unique_idx;

disp(' ')
disp('Comparison summary')
fprintf('MIDTable rows: %d\n', height(MIDTable));
fprintf('unit_table rows: %d\n', height(unit_table));
fprintf('MIDTable unique sessions: %d\n', numel(mid_unique_keys));
fprintf('unit_table unique sessions: %d\n', numel(unit_unique_keys));
fprintf('Shared sessions: %d\n', numel(shared_keys));
fprintf('MIDTable-only sessions: %d\n', numel(mid_only_unique_idx));
fprintf('unit_table-only sessions: %d\n', numel(unit_only_unique_idx));

disp(' ')
disp('Session key columns used for matching:')
disp(key_columns')

disp(' ')
fprintf('Variables only in %s:\n', mid_info.VariableName);
disp(mid_only_variables')

disp(' ')
fprintf('Variables only in %s:\n', unit_info.VariableName);
disp(unit_only_variables')

disp(' ')
disp('MIDTable-only sessions:')
disp(mid_only_rows)

disp(' ')
disp('unit_table-only sessions:')
disp(unit_only_rows)

assignin('base', 'MIDTable_compare_results', comparison_results);
assignin('base', 'MIDTable_only_sessions', mid_only_rows);
assignin('base', 'unit_table_only_sessions', unit_only_rows);
assignin('base', 'MIDTable_only_variables', mid_only_variables);
assignin('base', 'unit_table_only_variables', unit_only_variables);


function out = load_first_table_from_mat(mat_file, preferred_names)
data = load(mat_file);
field_names = fieldnames(data);

selected_name = '';
for i = 1:numel(preferred_names)
    if isfield(data, preferred_names{i}) && istable(data.(preferred_names{i}))
        selected_name = preferred_names{i};
        break
    end
end

if isempty(selected_name)
    for i = 1:numel(field_names)
        if istable(data.(field_names{i}))
            selected_name = field_names{i};
            break
        end
    end
end

if isempty(selected_name)
    error('No table variable was found in %s.', mat_file);
end

out = struct();
out.File = mat_file;
out.VariableName = selected_name;
out.Table = data.(selected_name);
end


function key_columns = choose_session_key_columns(mid_tbl, unit_tbl)
shared_names = intersect(mid_tbl.Properties.VariableNames, unit_tbl.Properties.VariableNames, 'stable');

if ismember('Monkey', shared_names) && ismember('Date', shared_names)
    key_columns = {'Monkey', 'Date'};
elseif ismember('Date', shared_names)
    key_columns = {'Date'};
else
    error('Could not find Date as a shared column between the two tables.');
end
end


function row_keys = build_row_keys(tbl, key_columns)
n_rows = height(tbl);
row_keys = strings(n_rows, 1);

for i_row = 1:n_rows
    pieces = strings(1, numel(key_columns));
    for i_col = 1:numel(key_columns)
        value = tbl.(key_columns{i_col})(i_row, :);
        pieces(i_col) = key_columns{i_col} + "=" + normalize_value(value);
    end
    row_keys(i_row) = strjoin(pieces, " | ");
end
end


function out_tbl = build_session_summary_table(tbl, unique_keys, first_idx, group_idx, keep_unique_idx)
if isempty(keep_unique_idx)
    out_tbl = table();
    return
end

session_row_idx = first_idx(keep_unique_idx);
session_counts = arrayfun(@(k) sum(group_idx == k), keep_unique_idx);

out_tbl = tbl(session_row_idx, :);
out_tbl.SessionKey = unique_keys(keep_unique_idx);
out_tbl.NumRowsForSession = session_counts(:);
end


function out = normalize_value(value)
if iscell(value)
    if isempty(value)
        out = "<empty>";
    elseif numel(value) == 1
        out = normalize_value(value{1});
    else
        parts = strings(1, numel(value));
        for i = 1:numel(value)
            parts(i) = normalize_value(value{i});
        end
        out = "[" + strjoin(parts, ",") + "]";
    end
    return
end

if isstring(value)
    if isempty(value)
        out = "<empty>";
    elseif isscalar(value)
        out = value;
    else
        out = "[" + strjoin(value, ",") + "]";
    end
    return
end

if ischar(value)
    out = string(value);
    return
end

if isdatetime(value)
    if isempty(value) || any(isnat(value))
        out = "<NaT>";
    elseif isscalar(value)
        out = string(datestr(value, 'yyyy-mm-dd HH:MM:SS'));
    else
        parts = arrayfun(@(x) string(datestr(x, 'yyyy-mm-dd HH:MM:SS')), value, 'UniformOutput', true);
        out = "[" + strjoin(parts, ",") + "]";
    end
    return
end

if isnumeric(value) || islogical(value)
    if isempty(value)
        out = "<empty>";
    elseif isscalar(value)
        if isnan(value)
            out = "NaN";
        else
            out = string(mat2str(value, 12));
        end
    else
        out = string(mat2str(value, 12));
    end
    return
end

try
    out = string(value);
catch
    out = "<unhandled>";
end
end

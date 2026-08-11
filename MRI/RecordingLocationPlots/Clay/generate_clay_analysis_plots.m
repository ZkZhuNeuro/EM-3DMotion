% Generate one recording-location PNG for every Clay stimulation session
% included by the current analysis criteria.

output_dir = 'C:\EM\RecordingLocationPlots\Clay';
workbook_path = 'P:\Clay\NeuroData\RecordingRecord_Stimulation.xlsx';
script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);
addpath(fullfile(fileparts(script_dir), 'common'));
addpath('P:\MRI\Grid_Mapping');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

OrigPoint_Voxel = [127, 208, 68];
MasterPlotOptions
Img_nii_file = 'P:\MRI\R14008_GridScan\R14008_T1W_brain_Org2AvgGrid.nii.gz';
ROI_nii_file = 'P:\MRI\R14008_GridScan\R14008_LEV00_ROIs_org2Grid.nii.gz';
ROI_intensity = [46, 38, 25, 24];
color_mat = [0 0.5 0.5; 1 1 0; plotOptions.AreaColors.MT; ...
    plotOptions.AreaColors.FST];

tb = readtable(workbook_path, 'VariableNamingRule', 'preserve');
recording_dates = normalizeDateColumnLocal(getTableColumnLocal(tb, 'Date'));
roi_values = normalizeTextColumnLocal(getTableColumnLocal(tb, 'ROI'));
[row_indices, inclusion_audit] = getWorkbookRowsFromUnitTableGof(tb, 'Clay');

if exist('workbookRowsToPlot', 'var') && ~isempty(workbookRowsToPlot)
    requested_table_rows = workbookRowsToPlot(:) - 1;
    row_indices = row_indices(ismember(row_indices, requested_table_rows));
elseif numel(row_indices) ~= 102
    error('Expected 102 unit_table_gof Clay sessions, but found %d.', numel(row_indices));
end

struct_nii = load_nii(Img_nii_file);
roi_nii = load_nii(ROI_nii_file);
old_visibility = get(groot, 'defaultFigureVisible');
visibility_cleanup = onCleanup(@() set(groot, 'defaultFigureVisible', old_visibility)); %#ok<NASGU>
set(groot, 'defaultFigureVisible', 'off');

generated_files = strings(numel(row_indices), 1);
failed_rows = [];
failed_messages = strings(0, 1);

for i = 1:numel(row_indices)
    row_idx = row_indices(i);
    workbook_row = row_idx + 1;
    fig = gobjects(0);
    try
        session_date = recording_dates(row_idx);
        roi_label = char(roi_values(row_idx));
        hole = parseNumericVectorLocal(getValueAtRowLocal( ...
            getTableColumnLocal(tb, 'Hole'), row_idx));
        guide_tube_mm = parseScalarDoubleLocal(getValueAtRowLocal( ...
            getTableColumnLocal(tb, 'GuideTube'), row_idx));
        recording_depth_mm = parseScalarDoubleLocal(getValueAtRowLocal( ...
            getTableColumnLocal(tb, 'Depth'), row_idx));
        offset_mm = parseNumericVectorLocal(getValueAtRowLocal( ...
            getTableColumnLocal(tb, 'Offset'), row_idx));

        if numel(hole) ~= 2 || any(~isfinite(hole))
            error('Invalid hole coordinate in workbook row %d.', workbook_row);
        end
        if ~isfinite(guide_tube_mm) || ~isfinite(recording_depth_mm)
            error('Invalid guide/depth value in workbook row %d.', workbook_row);
        end
        if numel(offset_mm) ~= 3 || any(~isfinite(offset_mm))
            error('Invalid offset vector in workbook row %d.', workbook_row);
        end

        total_depth_mm = guide_tube_mm + recording_depth_mm;
        [image_slice, roi_slice, ml_index, depth_voxel] = prepareSessionPlotDataLocal( ...
            struct_nii.img, roi_nii.img, OrigPoint_Voxel, hole, total_depth_mm, offset_mm);

        fig = figure('Color', 'w', 'Visible', 'off', 'Position', [100, 100, 1000, 800]);
        imshow(image_slice, 'InitialMagnification', 1000);
        hold on;
        for r = 1:length(ROI_intensity)
            slice_roi = roi_slice == ROI_intensity(r);
            color_layer = cat(3, ...
                ones(size(image_slice)) .* color_mat(r, 1), ...
                ones(size(image_slice)) .* color_mat(r, 2), ...
                ones(size(image_slice)) .* color_mat(r, 3));
            h_roi = imshow(color_layer, 'InitialMagnification', 500);
            set(h_roi, 'AlphaData', 1 * slice_roi);
        end
        scatter(ml_index, depth_voxel, 15, 'go', 'filled', 'MarkerEdgeColor', 'k');
        legend('off');

        [brain_rows, brain_cols] = find(image_slice ~= 255);
        if hole(1) > 0
            xlim([min(brain_cols), 256 / 2]);
        else
            xlim([256 / 2, max(brain_cols)]);
        end
        ylim([min(brain_rows), max(brain_rows)]);
        title(sprintf(['Clay %s | %s | Hole <%d,%d> | Guide %.2g + Depth %.3g mm ' ...
            '| Offset [%g,%g,%g] mm'], datestr(session_date, 'yyyy-mm-dd'), roi_label, ...
            hole(1), hole(2), guide_tube_mm, recording_depth_mm, ...
            offset_mm(1), offset_mm(2), offset_mm(3)), ...
            'FontSize', 8, 'Interpreter', 'none');
        hold off;

        output_name = sprintf('Clay_%s_%s_Hole_%d-%d.png', ...
            roi_label, datestr(session_date, 'yyyy-mm-dd'), hole(1), hole(2));
        output_file = fullfile(output_dir, output_name);
        exportgraphics(fig, output_file, 'Resolution', 300);
        close(fig);
        generated_files(i) = string(output_file);

        if mod(i, 10) == 0 || i == numel(row_indices)
            fprintf('Generated %d/%d plots.\n', i, numel(row_indices));
        end
    catch ME
        if ~isempty(fig) && isgraphics(fig)
            close(fig);
        end
        failed_rows(end + 1, 1) = workbook_row; %#ok<SAGROW>
        failed_messages(end + 1, 1) = string(ME.message); %#ok<SAGROW>
        fprintf(2, 'Failed workbook row %d: %s\n', workbook_row, ME.message);
    end
end

if ~isempty(failed_rows)
    for i = 1:numel(failed_rows)
        fprintf(2, 'Row %d failure: %s\n', failed_rows(i), failed_messages(i));
    end
    error('%d of %d included sessions failed to plot.', numel(failed_rows), numel(row_indices));
end

fprintf('Successfully generated %d included-session plots in %s\n', ...
    numel(generated_files), output_dir);

% Remove obsolete generated session figures when an included session's ROI
% label changes in the workbook. Preserve non-session files and subfolders.
existing_plots = dir(fullfile(output_dir, 'Clay_*_Hole_*.png'));
generated_files_lower = lower(generated_files);
removed_count = 0;
for i = 1:numel(existing_plots)
    existing_file = string(fullfile(existing_plots(i).folder, existing_plots(i).name));
    if ~any(lower(existing_file) == generated_files_lower)
        delete(existing_file);
        removed_count = removed_count + 1;
    end
end
fprintf('Removed %d obsolete generated session plots.\n', removed_count);

function column_data = getTableColumnLocal(tb, requested_name)
variable_names = tb.Properties.VariableNames;
normalized_variables = normalizeVariableNamesLocal(variable_names);
normalized_request = normalizeVariableNamesLocal({requested_name});
match_idx = find(strcmp(normalized_variables, normalized_request{1}), 1, 'first');
if isempty(match_idx)
    error('Column "%s" was not found in the recording table.', requested_name);
end
column_data = tb.(variable_names{match_idx});
end

function normalized = normalizeVariableNamesLocal(names)
normalized = regexprep(lower(string(names)), '[^a-z0-9]', '');
normalized = cellstr(normalized);
end

function value = getValueAtRowLocal(column_data, row_idx)
if iscell(column_data)
    value = column_data{row_idx};
else
    value = column_data(row_idx, :);
end
end

function text_values = normalizeTextColumnLocal(column_data)
if iscell(column_data)
    text_values = strings(numel(column_data), 1);
    for i = 1:numel(column_data)
        value = column_data{i};
        if isempty(value) || (isnumeric(value) && all(isnan(value(:))))
            text_values(i) = "";
        else
            text_values(i) = strtrim(string(value));
        end
    end
else
    text_values = strtrim(string(column_data));
    text_values(ismissing(text_values)) = "";
end
end

function dates = normalizeDateColumnLocal(column_data)
if isdatetime(column_data)
    dates = column_data;
    return
end
if isnumeric(column_data)
    dates = datetime(column_data, 'ConvertFrom', 'excel');
    return
end
text_values = normalizeTextColumnLocal(column_data);
dates = NaT(size(text_values));
for i = 1:numel(text_values)
    if strlength(text_values(i)) == 0
        continue
    end
    try
        dates(i) = datetime(text_values(i));
    catch
    end
end
end

function values = parseNumericVectorLocal(value)
if isnumeric(value)
    values = double(value(:).');
    return
end
text_value = char(strtrim(string(value)));
number_tokens = regexp(text_value, '[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?', 'match');
values = str2double(number_tokens);
values = double(values(:).');
end

function value = parseScalarDoubleLocal(raw_value)
if isnumeric(raw_value)
    value = double(raw_value(1));
else
    value = str2double(string(raw_value));
end
end

function [image_slice, roi_slice, ml_index, depth_voxel] = ...
        prepareSessionPlotDataLocal(struct_volume, roi_volume, origin_voxel, hole, total_depth_mm, offset_mm)
ap_voxel = origin_voxel(3) - ((29 - hole(2)) * 0.8) * 2;
ap_index = round(ap_voxel + 1);
if ap_index < 1 || ap_index > size(struct_volume, 3)
    error('MRI slice index %d is outside the structural volume.', ap_index);
end

if hole(2) < 5 || hole(2) > 35
    error('Hole Y coordinate %g is outside the supported range.', hole(2));
end
if mod(hole(2), 2) == 1
    edge_offset = 1.4;
else
    edge_offset = 1.8;
end
if hole(1) > 0
    ml_voxel = origin_voxel(1) - ((hole(1) - 1) * 0.8 + edge_offset) * 2;
else
    ml_voxel = origin_voxel(1) + ((abs(hole(1)) - 1) * 0.8 + edge_offset) * 2;
end
ml_index = ml_voxel + 1 + 2 * offset_mm(1);
depth_voxel = 256 - (origin_voxel(2) - 2 * total_depth_mm) + 2 * offset_mm(3);

image_slice = struct_volume(:, :, ap_index);
image_slice = fliplr(imrotate(image_slice, 90));
if ~isinteger(image_slice)
    image_slice = mat2gray(image_slice);
end
image_slice(image_slice == 0) = 255;

roi_slice = double(roi_volume(:, :, ap_index));
roi_slice = fliplr(imrotate(roi_slice, 90));
end

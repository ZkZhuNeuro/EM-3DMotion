% Project all analysis-included Clay recording locations onto every
% consecutive coronal MRI slice spanning the included grid Y rows, with
% separate MT and FST figures. This includes MRI slices that fall between
% two grid rows.

output_dir = 'C:\EM\RecordingLocationPlots\Clay\ProjectedByY';
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
if numel(row_indices) ~= 102
    error('Expected 102 unit_table_gof Clay sessions, but found %d.', numel(row_indices));
end

n_recordings = numel(row_indices);
holes = nan(n_recordings, 2);
offsets_mm = nan(n_recordings, 3);
guide_mm = nan(n_recordings, 1);
depth_mm = nan(n_recordings, 1);
included_roi = strings(n_recordings, 1);

hole_column = getTableColumnLocal(tb, 'Hole');
offset_column = getTableColumnLocal(tb, 'Offset');
guide_column = getTableColumnLocal(tb, 'GuideTube');
depth_column = getTableColumnLocal(tb, 'Depth');
for i = 1:n_recordings
    row_idx = row_indices(i);
    holes(i, :) = parseNumericVectorLocal(getValueAtRowLocal(hole_column, row_idx));
    offsets_mm(i, :) = parseNumericVectorLocal(getValueAtRowLocal(offset_column, row_idx));
    guide_mm(i) = parseScalarDoubleLocal(getValueAtRowLocal(guide_column, row_idx));
    depth_mm(i) = parseScalarDoubleLocal(getValueAtRowLocal(depth_column, row_idx));
    included_roi(i) = upper(roi_values(row_idx));
end

if any(~isfinite(holes), 'all') || any(~isfinite(offsets_mm), 'all') || ...
        any(~isfinite(guide_mm)) || any(~isfinite(depth_mm))
    error('One or more included rows have invalid hole, offset, guide, or depth values.');
end

unique_y_rows = unique(holes(:, 2));
if numel(unique_y_rows) ~= 9 || ~isequal(unique_y_rows(:).', 20:28)
    error('Expected unique included Y rows 20:28, but found: %s', mat2str(unique_y_rows(:).'));
end

row_ap_voxels = round(OrigPoint_Voxel(3) - ((29 - unique_y_rows) * 0.8) * 2);
all_ap_voxels = min(row_ap_voxels):max(row_ap_voxels);
hidden_ap_voxels = setdiff(all_ap_voxels, row_ap_voxels);
fprintf('Grid rows map to AP voxels: %s\n', mat2str(row_ap_voxels(:).'));
fprintf('Intermediate AP voxels: %s\n', mat2str(hidden_ap_voxels(:).'));

struct_nii = load_nii(Img_nii_file);
roi_nii = load_nii(ROI_nii_file);
old_visibility = get(groot, 'defaultFigureVisible');
visibility_cleanup = onCleanup(@() set(groot, 'defaultFigureVisible', old_visibility)); %#ok<NASGU>
set(groot, 'defaultFigureVisible', 'off');

areas = ["MT", "FST"];
generated_count = 0;
generated_files = strings(numel(all_ap_voxels) * numel(areas), 1);
for ap_voxel = all_ap_voxels
    [image_slice, roi_slice] = prepareCoronalSliceLocal( ...
        struct_nii.img, roi_nii.img, ap_voxel);
    [brain_rows, brain_cols] = find(image_slice ~= 255);

    exact_row_idx = find(row_ap_voxels == ap_voxel, 1, 'first');
    if ~isempty(exact_row_idx)
        slice_context = sprintf('grid Y %d', unique_y_rows(exact_row_idx));
        filename_context = sprintf('Y%02d', unique_y_rows(exact_row_idx));
    else
        posterior_idx = find(row_ap_voxels < ap_voxel, 1, 'last');
        anterior_idx = find(row_ap_voxels > ap_voxel, 1, 'first');
        posterior_y = unique_y_rows(posterior_idx);
        anterior_y = unique_y_rows(anterior_idx);
        slice_context = sprintf('hidden between grid Y %d and %d', ...
            posterior_y, anterior_y);
        filename_context = sprintf('BetweenY%02d-Y%02d', posterior_y, anterior_y);
    end

    for area = areas
        % The Y row selects the coronal MRI slice only. Project every
        % analysis-included recording from the requested area onto it.
        area_mask = included_roi == area;
        area_holes = holes(area_mask, :);
        area_offsets = offsets_mm(area_mask, :);
        area_total_depth = guide_mm(area_mask) + depth_mm(area_mask);
        [ml_index, depth_voxel] = computeRecordingCoordinatesLocal( ...
            area_holes, area_total_depth, area_offsets, OrigPoint_Voxel);

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

        if ~isempty(ml_index)
            scatter(ml_index, depth_voxel, 20, [0 1 0], 'filled', ...
                'MarkerEdgeColor', 'k', 'LineWidth', 0.75);
        end

        legend('off');
        xlim([min(brain_cols), 256 / 2]);
        ylim([min(brain_rows), max(brain_rows)]);
        title({sprintf('Clay %s | MRI slice index %d (AP voxel %d)', ...
            area, ap_voxel + 1, ap_voxel), ...
            sprintf('%s | all %d included locations', slice_context, nnz(area_mask))}, ...
            'FontSize', 8, 'Interpreter', 'none');
        hold off;

        output_name = sprintf('Clay_%s_APVoxel%03d_%s_ProjectedLocations.png', ...
            area, ap_voxel, filename_context);
        output_file = fullfile(output_dir, output_name);
        exportgraphics(fig, output_file, 'Resolution', 300);
        close(fig);
        generated_count = generated_count + 1;
        generated_files(generated_count) = string(output_file);
    end
    fprintf('Generated MT and FST projections for AP voxel %d (%s).\n', ...
        ap_voxel, slice_context);
end

expected_count = numel(all_ap_voxels) * numel(areas);
if generated_count ~= expected_count
    error('Expected %d projected plots, but generated %d.', expected_count, generated_count);
end

% Remove older generated projections that are no longer part of the current
% consecutive-slice series.
existing_plots = dir(fullfile(output_dir, 'Clay_*_ProjectedLocations.png'));
generated_files_lower = lower(generated_files);
removed_count = 0;
for i = 1:numel(existing_plots)
    existing_file = string(fullfile(existing_plots(i).folder, existing_plots(i).name));
    if ~any(lower(existing_file) == generated_files_lower)
        delete(existing_file);
        removed_count = removed_count + 1;
    end
end

fprintf(['Successfully generated %d projected plots across %d consecutive MRI ' ...
    'slices in %s\n'], generated_count, numel(all_ap_voxels), output_dir);
fprintf('Removed %d obsolete projected plots.\n', removed_count);

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
elseif isnumeric(column_data)
    dates = datetime(column_data, 'ConvertFrom', 'excel');
else
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
end

function values = parseNumericVectorLocal(value)
if isnumeric(value)
    values = double(value(:).');
    return
end
text_value = char(strtrim(string(value)));
number_tokens = regexp(text_value, '[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?', 'match');
values = double(str2double(number_tokens));
values = values(:).';
end

function value = parseScalarDoubleLocal(raw_value)
if isnumeric(raw_value)
    value = double(raw_value(1));
else
    value = str2double(string(raw_value));
end
end

function [image_slice, roi_slice] = prepareCoronalSliceLocal( ...
        struct_volume, roi_volume, ap_voxel)
ap_index = ap_voxel + 1;
if ap_index < 1 || ap_index > size(struct_volume, 3)
    error('MRI slice index %d is outside the structural volume.', ap_index);
end
image_slice = struct_volume(:, :, ap_index);
image_slice = fliplr(imrotate(image_slice, 90));
if ~isinteger(image_slice)
    image_slice = mat2gray(image_slice);
end
image_slice(image_slice == 0) = 255;
roi_slice = double(roi_volume(:, :, ap_index));
roi_slice = fliplr(imrotate(roi_slice, 90));
end

function [ml_index, depth_voxel] = computeRecordingCoordinatesLocal( ...
        holes, total_depth_mm, offsets_mm, origin_voxel)
n = size(holes, 1);
ml_index = nan(n, 1);
depth_voxel = nan(n, 1);
for i = 1:n
    hole = holes(i, :);
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
    ml_index(i) = ml_voxel + 1 + 2 * offsets_mm(i, 1);
    depth_voxel(i) = 256 - (origin_voxel(2) - 2 * total_depth_mm(i)) + ...
        2 * offsets_mm(i, 3);
end
end

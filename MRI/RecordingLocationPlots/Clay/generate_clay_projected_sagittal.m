% Project all analysis-included Clay recording locations onto every
% consecutive sagittal MRI slice spanning the occupied ML positions, with
% separate MT and FST figures. This includes MRI slices with no recording
% position that fall between occupied slices.

output_dir = 'C:\EM\RecordingLocationPlots\Clay\ProjectedSagittal';
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
if nnz(included_roi == "MT") ~= 40 || nnz(included_roi == "FST") ~= 62
    error('Expected 40 MT and 62 FST unit_table_gof sessions, but found %d and %d.', ...
        nnz(included_roi == "MT"), nnz(included_roi == "FST"));
end

grid_ml_voxels = nan(n_recordings, 1);
for i = 1:n_recordings
    grid_ml_voxels(i) = computeMLVoxelLocal(holes(i, :), offsets_mm(i, :), OrigPoint_Voxel);
end
% Coronal display coordinates are mirrored relative to the first NIfTI
% dimension after the established imrotate/fliplr convention. Convert the
% plotted grid ML coordinate to the MRI ML voxel used for sagittal slicing.
rounded_grid_ml_voxels = round(grid_ml_voxels);
rounded_ml_voxels = 255 - rounded_grid_ml_voxels;
occupied_ml_voxels = unique(rounded_ml_voxels);
all_ml_voxels = min(occupied_ml_voxels):max(occupied_ml_voxels);
hidden_ml_voxels = setdiff(all_ml_voxels, occupied_ml_voxels);
fprintf('Occupied MRI ML voxels: %s\n', mat2str(occupied_ml_voxels(:).'));
fprintf('Intermediate MRI ML voxels: %s\n', mat2str(hidden_ml_voxels(:).'));

struct_nii = load_nii(Img_nii_file);
roi_nii = load_nii(ROI_nii_file);
old_visibility = get(groot, 'defaultFigureVisible');
visibility_cleanup = onCleanup(@() set(groot, 'defaultFigureVisible', old_visibility)); %#ok<NASGU>
set(groot, 'defaultFigureVisible', 'off');

areas = ["MT", "FST"];
generated_count = 0;
generated_files = strings(numel(all_ml_voxels), 1);
for ml_voxel = all_ml_voxels
    [image_slice, roi_slice] = prepareSagittalSliceLocal( ...
        struct_nii.img, roi_nii.img, ml_voxel);
    [brain_rows, brain_cols] = find(image_slice ~= 255);

    exact_mask = rounded_ml_voxels == ml_voxel;
    if any(exact_mask)
        x_values = unique(holes(exact_mask, 1));
        x_text = strjoin(cellstr(string(x_values(:).')), ',');
        slice_context = sprintf('recorded grid X %s', x_text);
        filename_context = sprintf('GridX%s', strrep(x_text, ',', '-'));
    else
        lower_ml = max(occupied_ml_voxels(occupied_ml_voxels < ml_voxel));
        upper_ml = min(occupied_ml_voxels(occupied_ml_voxels > ml_voxel));
        lower_x = unique(holes(rounded_ml_voxels == lower_ml, 1));
        upper_x = unique(holes(rounded_ml_voxels == upper_ml, 1));
        lower_x_text = strjoin(cellstr(string(lower_x(:).')), ',');
        upper_x_text = strjoin(cellstr(string(upper_x(:).')), ',');
        slice_context = sprintf(['hidden between ML voxels %d and %d ' ...
            '(grid X %s to %s)'], lower_ml, upper_ml, lower_x_text, upper_x_text);
        filename_context = sprintf('HiddenBetweenML%03d-%03d', lower_ml, upper_ml);
    end

    fig = figure('Color', 'w', 'Visible', 'off', 'Position', [100, 100, 1000, 800]);
    imshow(image_slice, 'InitialMagnification', 1000);
    hold on;
    for r = 1:length(ROI_intensity)
        slice_roi = roi_slice == ROI_intensity(r);
        color_layer = cat(3, ...
            ones(size(image_slice)) .* color_mat(r, 1), ...
            ones(size(image_slice)) .* color_mat(r, 2), ...
            ones(size(image_slice)) .* color_mat(r, 3));
        h_roi = imshow(color_layer, 'InitialMagnification', 750);
        set(h_roi, 'AlphaData', 1 * slice_roi);
    end

    dot_handles = gobjects(numel(areas), 1);
    for area_idx = 1:numel(areas)
        area = areas(area_idx);
        area_mask = included_roi == area;
        area_holes = holes(area_mask, :);
        area_offsets = offsets_mm(area_mask, :);
        area_total_depth = guide_mm(area_mask) + depth_mm(area_mask);
        [ap_voxel, depth_voxel] = computeSagittalCoordinatesLocal( ...
            area_holes, area_total_depth, area_offsets, OrigPoint_Voxel);

        dot_color = color_mat(area_idx + 2, :);
        dot_handles(area_idx) = scatter(ap_voxel, depth_voxel, 8, dot_color, 'filled', ...
            'MarkerEdgeColor', dot_color .* 0.55, 'LineWidth', 0.5, ...
            'MarkerFaceAlpha', 0.75, 'MarkerEdgeAlpha', 0.85);
    end

    legend(dot_handles, cellstr(areas), 'Location', 'southeast', 'Box', 'off', ...
        'FontSize', 6, 'AutoUpdate', 'off');
    xlim([min(brain_cols), max(brain_cols)]);
    ylim([min(brain_rows), max(brain_rows)]);
    title({sprintf('Clay MT + FST | sagittal MRI slice index %d (ML voxel %d)', ...
        ml_voxel + 1, ml_voxel), ...
        sprintf('%s | MT %d + FST %d included locations', slice_context, ...
        nnz(included_roi == "MT"), nnz(included_roi == "FST"))}, ...
        'FontSize', 8, 'Interpreter', 'none');
    hold off;

    output_name = sprintf('Clay_MT-FST_MLVoxel%03d_%s_SagittalProjectedLocations.png', ...
        ml_voxel, filename_context);
    output_file = fullfile(output_dir, output_name);
    exportgraphics(fig, output_file, 'Resolution', 300);
    close(fig);
    generated_count = generated_count + 1;
    generated_files(generated_count) = string(output_file);
    fprintf('Generated combined MT and FST sagittal projection for ML voxel %d (%s).\n', ...
        ml_voxel, slice_context);
end

expected_count = numel(all_ml_voxels);
if generated_count ~= expected_count
    error('Expected %d sagittal plots, but generated %d.', expected_count, generated_count);
end

existing_plots = dir(fullfile(output_dir, 'Clay_*_SagittalProjectedLocations.png'));
generated_files_lower = lower(generated_files);
removed_count = 0;
for i = 1:numel(existing_plots)
    existing_file = string(fullfile(existing_plots(i).folder, existing_plots(i).name));
    if ~any(lower(existing_file) == generated_files_lower)
        delete(char(existing_file));
        removed_count = removed_count + 1;
    end
end

fprintf(['Successfully generated %d sagittal projections across %d consecutive ' ...
    'MRI slices in %s\n'], generated_count, numel(all_ml_voxels), output_dir);
fprintf('Removed %d obsolete sagittal projections.\n', removed_count);

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

function ml_voxel = computeMLVoxelLocal(hole, offset_mm, origin_voxel)
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
ml_voxel = ml_voxel + 2 * offset_mm(1);
end

function [image_slice, roi_slice] = prepareSagittalSliceLocal( ...
        struct_volume, roi_volume, ml_voxel)
ml_index = ml_voxel + 1;
if ml_index < 1 || ml_index > size(struct_volume, 1)
    error('MRI slice index %d is outside the structural volume.', ml_index);
end
image_slice = squeeze(struct_volume(ml_index, :, :));
image_slice = fliplr(imrotate(image_slice, 180));
if ~isinteger(image_slice)
    image_slice = mat2gray(image_slice);
end
image_slice(image_slice == 0) = 255;
roi_slice = double(squeeze(roi_volume(ml_index, :, :)));
roi_slice = fliplr(imrotate(roi_slice, 180));
end

function [ap_voxel, depth_voxel] = computeSagittalCoordinatesLocal( ...
        holes, total_depth_mm, offsets_mm, origin_voxel)
ap_voxel = origin_voxel(3) - ((29 - holes(:, 2)) * 0.8) * 2 + ...
    2 * offsets_mm(:, 2);
depth_voxel = 256 - (origin_voxel(2) - 2 * total_depth_mm) + ...
    2 * offsets_mm(:, 3);
end

% Project all analysis-included Clay recording locations onto every
% consecutive sagittal MRI slice spanning the occupied ML positions, with
% separate MT and FST figures. This includes MRI slices with no recording
% position that fall between occupied slices.

if ~exist('claySagittalTargetMLVoxels', 'var'), claySagittalTargetMLVoxels = []; end
if ~exist('claySagittalCropPadding', 'var'), claySagittalCropPadding = [12, 18]; end
if ~exist('claySagittalCropSpan', 'var'), claySagittalCropSpan = []; end
if ~exist('claySagittalCropShift', 'var'), claySagittalCropShift = [0, 0]; end
if ~exist('claySagittalFilenameSuffix', 'var'), claySagittalFilenameSuffix = ''; end
if ~exist('claySagittalExportSVG', 'var'), claySagittalExportSVG = false; end
if ~exist('claySagittalExportPDF', 'var'), claySagittalExportPDF = false; end
if ~exist('claySagittalExportDimensionsPoints', 'var')
    claySagittalExportDimensionsPoints = [];
end
if ~exist('claySagittalRasterDimensionsPixels', 'var')
    claySagittalRasterDimensionsPixels = [];
end

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
% Sagittal views show MSTd, MSTl, MT, and FST, in that order.
Sagittal_dot_colors = [0.00, 0.45, 0.95; 0.00, 0.70, 0.20];
Sagittal_dot_size = 32; % Four times the area gives twice the diameter.

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
    included_roi(i) = inclusion_audit.WorkbookROI(i);
end

if any(~isfinite(holes), 'all') || any(~isfinite(offsets_mm), 'all') || ...
        any(~isfinite(guide_mm)) || any(~isfinite(depth_mm))
    error('One or more included rows have invalid hole, offset, guide, or depth values.');
end
if nnz(included_roi == "MT") ~= inclusion_audit.WorkbookMTCount || ...
        nnz(included_roi == "FST") ~= inclusion_audit.WorkbookFSTCount
    error('Clay ROI counts do not match the workbook: found %d MT and %d FST.', ...
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
full_sagittal_run = isempty(claySagittalTargetMLVoxels);
if ~full_sagittal_run
    requested_ml_voxels = unique(round(claySagittalTargetMLVoxels(:).'));
    if any(~ismember(requested_ml_voxels, all_ml_voxels))
        error('Requested Clay sagittal ML voxels are outside %d:%d: %s', ...
            min(all_ml_voxels), max(all_ml_voxels), mat2str(requested_ml_voxels));
    end
    all_ml_voxels = requested_ml_voxels;
end
assert(numel(claySagittalCropPadding) == 2 && ...
    all(isfinite(claySagittalCropPadding)) && all(claySagittalCropPadding >= 0), ...
    'claySagittalCropPadding must contain nonnegative [x y] padding.');
if ~isempty(claySagittalExportDimensionsPoints)
    assert(numel(claySagittalExportDimensionsPoints) == 2 && ...
        all(isfinite(claySagittalExportDimensionsPoints)) && ...
        all(claySagittalExportDimensionsPoints > 0), ...
        'claySagittalExportDimensionsPoints must contain positive [width height].');
end

struct_nii = load_nii(Img_nii_file);
roi_nii = load_nii(ROI_nii_file);
old_visibility = get(groot, 'defaultFigureVisible');
visibility_cleanup = onCleanup(@() set(groot, 'defaultFigureVisible', old_visibility)); %#ok<NASGU>
set(groot, 'defaultFigureVisible', 'off');

areas = ["MT", "FST"];
[all_ap_voxels_plot, all_depth_voxels_plot] = computeSagittalCoordinatesLocal( ...
    holes, guide_mm + depth_mm, offsets_mm, OrigPoint_Voxel);
[sagittal_x_limits, sagittal_y_limits] = computeSagittalCropLocal( ...
    roi_nii.img, all_ml_voxels, ROI_intensity, ...
    all_ap_voxels_plot, all_depth_voxels_plot, ...
    claySagittalCropPadding(1), claySagittalCropPadding(2));
required_x_limits = sagittal_x_limits;
required_y_limits = sagittal_y_limits;
slice_size = size(squeeze(roi_nii.img(all_ml_voxels(1) + 1, :, :)));
if ~isempty(claySagittalCropSpan)
    assert(numel(claySagittalCropSpan) == 2 && ...
        all(isfinite(claySagittalCropSpan)) && all(claySagittalCropSpan > 0), ...
        'claySagittalCropSpan must contain positive [x y] spans.');
    sagittal_x_limits = enforceCropSpanLocal(sagittal_x_limits, ...
        claySagittalCropSpan(1), slice_size(2));
    sagittal_y_limits = enforceCropSpanLocal(sagittal_y_limits, ...
        claySagittalCropSpan(2), slice_size(1));
end
assert(numel(claySagittalCropShift) == 2 && ...
    all(isfinite(claySagittalCropShift)), ...
    'claySagittalCropShift must contain finite [x y] offsets.');
sagittal_x_limits = shiftCropLimitsLocal(sagittal_x_limits, ...
    claySagittalCropShift(1), slice_size(2), required_x_limits);
sagittal_y_limits = shiftCropLimitsLocal(sagittal_y_limits, ...
    claySagittalCropShift(2), slice_size(1), required_y_limits);
fprintf('Clay sagittal crop: x=%s, y=%s\n', ...
    mat2str(sagittal_x_limits), mat2str(sagittal_y_limits));
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
    overlayROIsVectorLocal(roi_slice, ROI_intensity, color_mat);

    dot_handles = gobjects(numel(areas), 1);
    for area_idx = 1:numel(areas)
        area = areas(area_idx);
        area_mask = included_roi == area;
        dot_color = Sagittal_dot_colors(area_idx, :);
        dot_handles(area_idx) = scatter(all_ap_voxels_plot(area_mask), ...
            all_depth_voxels_plot(area_mask), Sagittal_dot_size, dot_color, 'filled', ...
            'MarkerEdgeColor', 'k', 'LineWidth', 0.5, ...
            'MarkerFaceAlpha', 0.90, 'MarkerEdgeAlpha', 1);
    end

    legend(dot_handles, cellstr(areas), 'Location', 'northeast', 'Box', 'off', ...
        'FontSize', 6, 'AutoUpdate', 'off');
    xlim(sagittal_x_limits);
    ylim(sagittal_y_limits);
    title({sprintf('Clay MT + FST | sagittal MRI slice index %d (ML voxel %d)', ...
        ml_voxel + 1, ml_voxel), ...
        sprintf('%s | MT %d + FST %d included locations', slice_context, ...
        nnz(included_roi == "MT"), nnz(included_roi == "FST"))}, ...
        'FontSize', 8, 'Interpreter', 'none');
    hold off;

    output_name = sprintf('Clay_MT-FST_MLVoxel%03d_%s_SagittalProjectedLocations%s.png', ...
        ml_voxel, filename_context, char(string(claySagittalFilenameSuffix)));
    output_file = fullfile(output_dir, output_name);
    export_options = sagittalExportOptionsLocal( ...
        claySagittalExportDimensionsPoints, false);
    exportgraphics(fig, output_file, export_options{:});
    if ~isempty(claySagittalRasterDimensionsPixels)
        normalizeRasterCanvasLocal(output_file, ...
            claySagittalRasterDimensionsPixels);
    end
    if claySagittalExportSVG
        svg_file = replace(output_file, '.png', '.svg');
        export_options = sagittalExportOptionsLocal( ...
            claySagittalExportDimensionsPoints, true);
        exportgraphics(fig, svg_file, export_options{:});
    end
    if claySagittalExportPDF
        pdf_file = replace(output_file, '.png', '.pdf');
        export_options = sagittalExportOptionsLocal( ...
            claySagittalExportDimensionsPoints, true);
        exportgraphics(fig, pdf_file, export_options{:});
    end
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

removed_count = 0;
if full_sagittal_run
    existing_plots = dir(fullfile(output_dir, 'Clay_*_SagittalProjectedLocations.png'));
    generated_files_lower = lower(generated_files);
    for i = 1:numel(existing_plots)
        existing_file = string(fullfile(existing_plots(i).folder, existing_plots(i).name));
        if ~any(lower(existing_file) == generated_files_lower)
            delete(char(existing_file));
            removed_count = removed_count + 1;
        end
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

function [x_limits, y_limits] = computeSagittalCropLocal( ...
        roi_volume, ml_voxels, roi_intensity, dot_x, dot_y, x_padding, y_padding)
content_x = double(dot_x(:));
content_y = double(dot_y(:));
slice_size = [];
for ml_voxel = ml_voxels
    ml_index = ml_voxel + 1;
    roi_slice = double(squeeze(roi_volume(ml_index, :, :)));
    roi_slice = fliplr(imrotate(roi_slice, 180));
    slice_size = size(roi_slice);
    [roi_rows, roi_cols] = find(ismember(roi_slice, roi_intensity));
    content_x = [content_x; double(roi_cols)]; %#ok<AGROW>
    content_y = [content_y; double(roi_rows)]; %#ok<AGROW>
end
content_x = content_x(isfinite(content_x));
content_y = content_y(isfinite(content_y));
assert(~isempty(content_x) && ~isempty(content_y) && ~isempty(slice_size), ...
    'Cannot determine the Clay sagittal crop from empty dots and ROI masks.');
x_limits = [max(0.5, floor(min(content_x)) - x_padding), ...
    min(slice_size(2) + 0.5, ceil(max(content_x)) + x_padding)];
y_limits = [max(0.5, floor(min(content_y)) - y_padding), ...
    min(slice_size(1) + 0.5, ceil(max(content_y)) + y_padding)];
end

function overlayROIsVectorLocal(roi_slice, roi_intensity, color_mat)
% Draw each occupied ROI voxel as a vector rectangle. The structural MRI
% remains rasterized, while ROI shapes stay editable in SVG/PDF exports.
for r = 1:length(roi_intensity)
    [rows, cols] = find(roi_slice == roi_intensity(r));
    if isempty(rows), continue; end
    x_vertices = [cols.' - 0.5; cols.' + 0.5; cols.' + 0.5; cols.' - 0.5];
    y_vertices = [rows.' - 0.5; rows.' - 0.5; rows.' + 0.5; rows.' + 0.5];
    patch(x_vertices, y_vertices, color_mat(r, :), ...
        'EdgeColor', 'none', 'FaceAlpha', 1);
end
end

function limits = enforceCropSpanLocal(limits, target_span, dimension_size)
required_span = diff(limits);
assert(target_span + eps(target_span) >= required_span, ...
    'Requested crop span %.3f is smaller than required content span %.3f.', ...
    target_span, required_span);
limits = mean(limits) + [-0.5, 0.5] .* target_span;
if limits(1) < 0.5
    limits = limits + (0.5 - limits(1));
end
if limits(2) > dimension_size + 0.5
    limits = limits - (limits(2) - dimension_size - 0.5);
end
end

function limits = shiftCropLimitsLocal(limits, shift, dimension_size, required_limits)
limits = limits + shift;
assert(limits(1) >= 0.5 && limits(2) <= dimension_size + 0.5, ...
    'Shifted crop extends outside the MRI slice.');
assert(limits(1) <= required_limits(1) && limits(2) >= required_limits(2), ...
    'Shifted crop would exclude at least one dot or requested ROI voxel.');
end

function options = sagittalExportOptionsLocal(dimensions_points, vector_output)
if vector_output
    options = {'ContentType', 'vector'};
else
    options = {'Resolution', 300};
end
if ~isempty(dimensions_points)
    if vector_output
        export_dimensions = dimensions_points;
        export_units = 'points';
    else
        export_dimensions = round(dimensions_points .* 300 ./ 72);
        export_units = 'pixels';
    end
    options = [options, {'Width', export_dimensions(1), ...
        'Height', export_dimensions(2), 'Units', export_units, ...
        'Padding', 0, 'PreserveAspectRatio', 'on'}];
end
end

function normalizeRasterCanvasLocal(file_path, target_dimensions)
assert(numel(target_dimensions) == 2 && all(target_dimensions > 0), ...
    'Raster target dimensions must contain positive [width height].');
image_data = imread(file_path);
source_height = size(image_data, 1);
source_width = size(image_data, 2);
target_width = round(target_dimensions(1));
target_height = round(target_dimensions(2));
assert(source_width <= target_width && source_height <= target_height, ...
    'Exported PNG is larger than its requested normalized canvas.');
if source_width == target_width && source_height == target_height
    return;
end
if isfloat(image_data)
    white_value = cast(1, 'like', image_data);
else
    white_value = intmax(class(image_data));
end
canvas = repmat(white_value, target_height, target_width, size(image_data, 3));
row_start = floor((target_height - source_height) / 2) + 1;
col_start = floor((target_width - source_width) / 2) + 1;
canvas(row_start:(row_start + source_height - 1), ...
    col_start:(col_start + source_width - 1), :) = image_data;
imwrite(canvas, file_path);
end

function [ap_voxel, depth_voxel] = computeSagittalCoordinatesLocal( ...
        holes, total_depth_mm, offsets_mm, origin_voxel)
ap_voxel = origin_voxel(3) - ((29 - holes(:, 2)) * 0.8) * 2 + ...
    2 * offsets_mm(:, 2);
depth_voxel = 256 - (origin_voxel(2) - 2 * total_depth_mm) + ...
    2 * offsets_mm(:, 3);
end

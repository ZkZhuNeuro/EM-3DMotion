% Project all analysis-included Clay recording locations onto every
% consecutive coronal MRI slice spanning the included grid Y rows, with
% separate MT and FST figures. This includes MRI slices that fall between
% two grid rows.

if ~exist('clayCoronalTargetAPVoxels', 'var'), clayCoronalTargetAPVoxels = []; end
if ~exist('clayCoronalOutputDir', 'var'), clayCoronalOutputDir = ''; end
if ~exist('clayCoronalDotColors', 'var'), clayCoronalDotColors = [0 1 0; 0 1 0]; end
if ~exist('clayCoronalDotSize', 'var'), clayCoronalDotSize = 20; end
if ~exist('clayCoronalXLimits', 'var'), clayCoronalXLimits = []; end
if ~exist('clayCoronalYLimits', 'var'), clayCoronalYLimits = []; end
if ~exist('clayCoronalShowTitle', 'var'), clayCoronalShowTitle = true; end
if ~exist('clayCoronalVectorROIs', 'var'), clayCoronalVectorROIs = false; end
if ~exist('clayCoronalExportPDF', 'var'), clayCoronalExportPDF = false; end
if ~exist('clayCoronalCombinedPDF', 'var'), clayCoronalCombinedPDF = ''; end
if ~exist('clayCoronalFilenameSuffix', 'var'), clayCoronalFilenameSuffix = ''; end
if ~exist('clayCoronalExportDimensionsPoints', 'var')
    clayCoronalExportDimensionsPoints = [];
end
if ~exist('clayCoronalRasterDimensionsPixels', 'var')
    clayCoronalRasterDimensionsPixels = [];
end
if strlength(string(clayCoronalOutputDir)) == 0
    output_dir = 'C:\EM\RecordingLocationPlots\Clay\ProjectedByY';
else
    output_dir = char(string(clayCoronalOutputDir));
end
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
    included_roi(i) = inclusion_audit.WorkbookROI(i);
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
if ~isempty(clayCoronalTargetAPVoxels)
    assert(numel(clayCoronalTargetAPVoxels) == numel(areas), ...
        'clayCoronalTargetAPVoxels must provide one AP voxel per area.');
    clayCoronalTargetAPVoxels = round(clayCoronalTargetAPVoxels(:).');
end
assert(isequal(size(clayCoronalDotColors), [2, 3]), ...
    'clayCoronalDotColors must be a 2-by-3 [MT; FST] RGB matrix.');
generated_count = 0;
generated_files = strings(numel(all_ap_voxels) * numel(areas), 1);
for ap_voxel = all_ap_voxels
    if ~isempty(clayCoronalTargetAPVoxels) && ...
            ~any(clayCoronalTargetAPVoxels == ap_voxel)
        continue;
    end
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

    for area_idx = 1:numel(areas)
        area = areas(area_idx);
        if ~isempty(clayCoronalTargetAPVoxels) && ...
                ap_voxel ~= clayCoronalTargetAPVoxels(area_idx)
            continue;
        end
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
        if clayCoronalVectorROIs
            overlayROIsVectorLocal(roi_slice, ROI_intensity, color_mat);
        else
            for r = 1:length(ROI_intensity)
                slice_roi = roi_slice == ROI_intensity(r);
                color_layer = cat(3, ...
                    ones(size(image_slice)) .* color_mat(r, 1), ...
                    ones(size(image_slice)) .* color_mat(r, 2), ...
                    ones(size(image_slice)) .* color_mat(r, 3));
                h_roi = imshow(color_layer, 'InitialMagnification', 500);
                set(h_roi, 'AlphaData', 1 * slice_roi);
            end
        end

        if ~isempty(ml_index)
            scatter(ml_index, depth_voxel, clayCoronalDotSize, ...
                clayCoronalDotColors(area_idx, :), 'filled', ...
                'MarkerEdgeColor', 'k', 'LineWidth', 0.75);
        end

        legend('off');
        if isempty(clayCoronalXLimits)
            xlim([min(brain_cols), 256 / 2]);
        else
            assert(numel(clayCoronalXLimits) == 2 && ...
                all(isfinite(clayCoronalXLimits)) && ...
                diff(clayCoronalXLimits) > 0, ...
                'clayCoronalXLimits must contain increasing finite limits.');
            assert(all(ml_index >= clayCoronalXLimits(1) & ...
                ml_index <= clayCoronalXLimits(2)), ...
                'Requested coronal x crop excludes at least one plotted location.');
            xlim(clayCoronalXLimits);
        end
        if isempty(clayCoronalYLimits)
            ylim([min(brain_rows), max(brain_rows)]);
        else
            assert(numel(clayCoronalYLimits) == 2 && ...
                all(isfinite(clayCoronalYLimits)) && ...
                diff(clayCoronalYLimits) > 0, ...
                'clayCoronalYLimits must contain increasing finite limits.');
            assert(all(depth_voxel >= clayCoronalYLimits(1) & ...
                depth_voxel <= clayCoronalYLimits(2)), ...
                'Requested coronal y crop excludes at least one plotted location.');
            ylim(clayCoronalYLimits);
        end
        if clayCoronalShowTitle
            title({sprintf('Clay %s | MRI slice index %d (AP voxel %d)', ...
                area, ap_voxel + 1, ap_voxel), ...
                sprintf('%s | all %d included locations', slice_context, nnz(area_mask))}, ...
                'FontSize', 8, 'Interpreter', 'none');
        end
        hold off;

        output_name = sprintf('Clay_%s_APVoxel%03d_%s_ProjectedLocations%s.png', ...
            area, ap_voxel, filename_context, ...
            char(string(clayCoronalFilenameSuffix)));
        output_file = fullfile(output_dir, output_name);
        export_options = coronalExportOptionsLocal( ...
            clayCoronalExportDimensionsPoints, false);
        exportgraphics(fig, output_file, export_options{:});
        if ~isempty(clayCoronalRasterDimensionsPixels)
            normalizeRasterCanvasLocal(output_file, ...
                clayCoronalRasterDimensionsPixels);
        end
        if clayCoronalExportPDF
            pdf_file = replace(output_file, '.png', '.pdf');
            export_options = coronalExportOptionsLocal( ...
                clayCoronalExportDimensionsPoints, true);
            exportgraphics(fig, pdf_file, export_options{:});
        end
        if strlength(string(clayCoronalCombinedPDF)) > 0
            combined_pdf = char(string(clayCoronalCombinedPDF));
            combined_dir = fileparts(combined_pdf);
            if ~exist(combined_dir, 'dir'), mkdir(combined_dir); end
            export_options = coronalExportOptionsLocal( ...
                clayCoronalExportDimensionsPoints, true);
            exportgraphics(fig, combined_pdf, export_options{:}, ...
                'Append', generated_count > 0);
        end
        close(fig);
        generated_count = generated_count + 1;
        generated_files(generated_count) = string(output_file);
    end
    if isempty(clayCoronalTargetAPVoxels)
        generated_areas = areas;
    else
        generated_areas = areas(clayCoronalTargetAPVoxels == ap_voxel);
    end
    fprintf('Generated %s projection(s) for AP voxel %d (%s).\n', ...
        strjoin(cellstr(generated_areas), ' and '), ap_voxel, slice_context);
end

if isempty(clayCoronalTargetAPVoxels)
    expected_count = numel(all_ap_voxels) * numel(areas);
else
    expected_count = numel(areas);
end
if generated_count ~= expected_count
    error('Expected %d projected plots, but generated %d.', expected_count, generated_count);
end

% Remove older generated projections that are no longer part of the current
% consecutive-slice series.
removed_count = 0;
if isempty(clayCoronalTargetAPVoxels)
    existing_plots = dir(fullfile(output_dir, sprintf( ...
        'Clay_*_ProjectedLocations%s.png', ...
        char(string(clayCoronalFilenameSuffix)))));
    generated_files_lower = lower(generated_files);
    for i = 1:numel(existing_plots)
        existing_file = string(fullfile(existing_plots(i).folder, existing_plots(i).name));
        if ~any(lower(existing_file) == generated_files_lower)
            delete(existing_file);
            removed_count = removed_count + 1;
        end
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

function overlayROIsVectorLocal(roi_slice, roi_intensity, color_mat)
for r = 1:length(roi_intensity)
    [rows, cols] = find(roi_slice == roi_intensity(r));
    if isempty(rows), continue; end
    x_vertices = [cols.' - 0.5; cols.' + 0.5; cols.' + 0.5; cols.' - 0.5];
    y_vertices = [rows.' - 0.5; rows.' - 0.5; rows.' + 0.5; rows.' + 0.5];
    patch(x_vertices, y_vertices, color_mat(r, :), ...
        'EdgeColor', 'none', 'FaceAlpha', 1);
end
end

function options = coronalExportOptionsLocal(dimensions_points, vector_output)
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

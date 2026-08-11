% Generate Jim recording-location plots from the current stimulation
% workbook using the same analysis inclusion rules as the current pipeline.
% Outputs include one figure per session plus all-slice coronal and sagittal
% MT/FST projections.

if ~exist('generateSessionPlots', 'var'), generateSessionPlots = true; end
if ~exist('generateCoronalPlots', 'var'), generateCoronalPlots = true; end
if ~exist('generateSagittalPlots', 'var'), generateSagittalPlots = true; end
if ~exist('jimSessionWorkbookRows', 'var'), jimSessionWorkbookRows = []; end
if ~exist('jimCoronalAreas', 'var'), jimCoronalAreas = ["MT", "FST"]; end

output_root = 'C:\EM\RecordingLocationPlots\Jim';
coronal_dir = fullfile(output_root, 'ProjectedByY');
sagittal_dir = fullfile(output_root, 'ProjectedSagittal');
workbook_path = 'P:\Jim\NeuroData\RecordingRecord_Stimulation_final.xlsx';
script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);
addpath(fullfile(fileparts(script_dir), 'common'));
addpath('P:\MRI\Grid_Mapping');
if ~exist(output_root, 'dir'), mkdir(output_root); end
if ~exist(coronal_dir, 'dir'), mkdir(coronal_dir); end
if ~exist(sagittal_dir, 'dir'), mkdir(sagittal_dir); end

OrigPoint_Voxel = [127, 208, 68];
MasterPlotOptions
Img_nii_file = 'P:\MRI\R12059_GridScan\anaGrid\R12059_T1W_brain_Org2AvgGrid.nii.gz';
ROI_nii_file = 'P:\MRI\R12059_GridScan\anaGrid\R12059_allROIs_LVE00_Both_org2Grid_updated.nii.gz';
Sagittal_ROI_nii_file = 'P:\MRI\R12059_GridScan\anaGrid\R12059_allROIs_LVE00_Left_org2Grid_updated.nii.gz';
% Jim LVE00 left-hemisphere labels:
% 51=MSTda, 46=MSTm, 28=MT, 24=FST, 69=MSTdp, 57=V3A.
% Label 60 is MSTdp in the right hemisphere and must not be used here.
ROI_intensity = [51, 46, 28, 24, 69, 57];
color_mat = [0 0.5 0.5; 1 1 0; plotOptions.AreaColors.MT; ...
    plotOptions.AreaColors.FST; 0.75 0.5 0.25; 0.75 0.5 0.25];

tb = readtable(workbook_path, 'VariableNamingRule', 'preserve');
recording_dates = normalizeDateColumnLocal(getTableColumnLocal(tb, 'Date'));
roi_values = normalizeTextColumnLocal(getTableColumnLocal(tb, 'ROI'));
[row_indices, inclusion_audit] = getWorkbookRowsFromUnitTableGof(tb, 'Jim');
if numel(row_indices) ~= 149
    error('Expected 149 unit_table_gof Jim sessions, but found %d.', numel(row_indices));
end

n_recordings = numel(row_indices);
holes = nan(n_recordings, 2);
offsets_mm = nan(n_recordings, 3);
guide_mm = nan(n_recordings, 1);
depth_mm = nan(n_recordings, 1);
included_roi = strings(n_recordings, 1);
included_dates = NaT(n_recordings, 1);
workbook_rows = row_indices + 1;

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
    included_dates(i) = recording_dates(row_idx);
end

if any(~isfinite(holes), 'all') || any(~isfinite(offsets_mm), 'all') || ...
        any(~isfinite(guide_mm)) || any(~isfinite(depth_mm))
    error('One or more included rows have invalid hole, offset, guide, or depth values.');
end
if nnz(included_roi == "MT") ~= 54 || nnz(included_roi == "FST") ~= 95
    error('Expected 54 MT and 95 FST unit_table_gof sessions, but found %d and %d.', ...
        nnz(included_roi == "MT"), nnz(included_roi == "FST"));
end

ml_voxels = nan(n_recordings, 1);
for i = 1:n_recordings
    ml_voxels(i) = computeMLVoxelLocal(holes(i, :), offsets_mm(i, :), OrigPoint_Voxel);
end
% Positive grid-hole coordinates appear on the left side of the established
% coronal display, so coronal plotting uses this coordinate directly. The
% NIfTI first dimension is reversed relative to that display and is mirrored
% separately below when selecting sagittal MRI and ROI slices.
coronal_display_ml = ml_voxels;
ap_voxels = OrigPoint_Voxel(3) - ((29 - holes(:, 2)) * 0.8) * 2 + ...
    2 * offsets_mm(:, 2);
depth_voxels = 256 - (OrigPoint_Voxel(2) - 2 * (guide_mm + depth_mm)) + ...
    2 * offsets_mm(:, 3);

struct_nii = load_nii(Img_nii_file);
roi_nii = load_nii(ROI_nii_file);
sagittal_roi_nii = load_nii(Sagittal_ROI_nii_file);
if ~isequal(size(struct_nii.img), size(sagittal_roi_nii.img))
    error('Jim structural MRI and left-hemisphere sagittal ROI mask are not on the same voxel grid.');
end
old_visibility = get(groot, 'defaultFigureVisible');
visibility_cleanup = onCleanup(@() set(groot, 'defaultFigureVisible', old_visibility)); %#ok<NASGU>
set(groot, 'defaultFigureVisible', 'off');

if generateSessionPlots
    full_session_generation = isempty(jimSessionWorkbookRows);
    if full_session_generation
        session_recording_indices = (1:n_recordings).';
    else
        session_recording_indices = find(ismember(workbook_rows, jimSessionWorkbookRows(:)));
        if isempty(session_recording_indices)
            error('None of the requested workbook rows are analysis-included Jim sessions.');
        end
    end
    generated_session_files = strings(numel(session_recording_indices), 1);
    for j = 1:numel(session_recording_indices)
        i = session_recording_indices(j);
        [image_slice, roi_slice] = prepareCoronalSliceLocal( ...
            struct_nii.img, roi_nii.img, round(ap_voxels(i)), true);
        [brain_rows, brain_cols] = find(image_slice ~= 255);

        fig = figure('Color', 'w', 'Visible', 'off', 'Position', [100, 100, 1000, 800]);
        imshow(image_slice, 'InitialMagnification', 1000);
        hold on;
        overlayROIsLocal(image_slice, roi_slice, ROI_intensity, color_mat, 1000);
        scatter(coronal_display_ml(i), depth_voxels(i), 15, [0 1 0], 'filled', ...
            'MarkerEdgeColor', 'k', 'LineWidth', 0.75);
        legend('off');
        if coronal_display_ml(i) >= 256 / 2
            xlim([256 / 2, max(brain_cols)]);
        else
            xlim([min(brain_cols), 256 / 2]);
        end
        ylim([min(brain_rows), max(brain_rows)]);
        title(sprintf(['Jim %s | %s | Hole <%d,%d> | Guide %.3g + Depth %.3g mm ' ...
            '| Offset [%g,%g,%g] mm'], datestr(included_dates(i), 'yyyy-mm-dd'), ...
            included_roi(i), holes(i, 1), holes(i, 2), guide_mm(i), depth_mm(i), ...
            offsets_mm(i, 1), offsets_mm(i, 2), offsets_mm(i, 3)), ...
            'FontSize', 8, 'Interpreter', 'none');
        hold off;

        output_name = sprintf('Jim_%s_%s_Hole_%d-%d.png', included_roi(i), ...
            datestr(included_dates(i), 'yyyy-mm-dd'), holes(i, 1), holes(i, 2));
        output_file = fullfile(output_root, output_name);
        exportgraphics(fig, output_file, 'Resolution', 300);
        close(fig);
        generated_session_files(j) = string(output_file);
        if mod(j, 10) == 0 || j == numel(session_recording_indices)
            fprintf('Generated %d/%d Jim session plots.\n', j, numel(session_recording_indices));
        end
    end

    if full_session_generation
        cleanupGeneratedFilesLocal(output_root, 'Jim_*_Hole_*.png', generated_session_files);
    end
end

areas = ["MT", "FST"];
if generateCoronalPlots
    coronal_areas = upper(strip(string(jimCoronalAreas(:).')));
    if isempty(coronal_areas) || any(~ismember(coronal_areas, areas))
        error('jimCoronalAreas must contain MT, FST, or both.');
    end
    coronal_areas = unique(coronal_areas, 'stable');
    rounded_ap_voxels = round(ap_voxels);
    occupied_ap_voxels = unique(rounded_ap_voxels);
    all_ap_voxels = min(occupied_ap_voxels):max(occupied_ap_voxels);
    hidden_ap_voxels = setdiff(all_ap_voxels, occupied_ap_voxels);
    fprintf('Jim occupied AP voxels: %s\n', mat2str(occupied_ap_voxels(:).'));
    fprintf('Jim intermediate AP voxels: %s\n', mat2str(hidden_ap_voxels(:).'));
    generated_coronal_files = strings(numel(all_ap_voxels) * numel(coronal_areas), 1);
    generated_count = 0;
    for ap_voxel = all_ap_voxels
        [image_slice, roi_slice] = prepareCoronalSliceLocal( ...
            struct_nii.img, roi_nii.img, ap_voxel, true);
        [brain_rows, brain_cols] = find(image_slice ~= 255);
        exact_mask = rounded_ap_voxels == ap_voxel;
        if any(exact_mask)
            y_values = unique(holes(exact_mask, 2));
            y_text = strjoin(cellstr(string(y_values(:).')), ',');
            slice_context = sprintf('recorded grid Y %s', y_text);
            filename_context = sprintf('GridY%s', strrep(y_text, ',', '-'));
        else
            lower_ap = max(occupied_ap_voxels(occupied_ap_voxels < ap_voxel));
            upper_ap = min(occupied_ap_voxels(occupied_ap_voxels > ap_voxel));
            lower_y = unique(holes(rounded_ap_voxels == lower_ap, 2));
            upper_y = unique(holes(rounded_ap_voxels == upper_ap, 2));
            slice_context = sprintf('hidden between grid Y %s and %s', ...
                strjoin(cellstr(string(lower_y(:).')), ','), ...
                strjoin(cellstr(string(upper_y(:).')), ','));
            filename_context = sprintf('HiddenBetweenAP%03d-%03d', lower_ap, upper_ap);
        end

        for area = coronal_areas
            area_mask = included_roi == area;
            fig = figure('Color', 'w', 'Visible', 'off', 'Position', [100, 100, 1000, 800]);
            imshow(image_slice, 'InitialMagnification', 1000);
            hold on;
            overlayROIsLocal(image_slice, roi_slice, ROI_intensity, color_mat, 1000);
            scatter(coronal_display_ml(area_mask), depth_voxels(area_mask), 20, ...
                [0 1 0], 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.75);
            legend('off');
            xlim([min(brain_cols), 256 / 2]);
            ylim([min(brain_rows), max(brain_rows)]);
            title({sprintf('Jim %s | MRI slice index %d (AP voxel %d)', ...
                area, ap_voxel + 1, ap_voxel), ...
                sprintf('%s | all %d included locations', slice_context, nnz(area_mask))}, ...
                'FontSize', 8, 'Interpreter', 'none');
            hold off;
            output_name = sprintf('Jim_%s_APVoxel%03d_%s_ProjectedLocations.png', ...
                area, ap_voxel, filename_context);
            output_file = fullfile(coronal_dir, output_name);
            exportgraphics(fig, output_file, 'Resolution', 300);
            close(fig);
            generated_count = generated_count + 1;
            generated_coronal_files(generated_count) = string(output_file);
        end
        fprintf('Generated Jim %s coronal projection(s) for AP voxel %d.\n', ...
            strjoin(cellstr(coronal_areas), ' and '), ap_voxel);
    end
    for area = coronal_areas
        area_token = string(filesep) + "Jim_" + area + "_";
        area_generated = generated_coronal_files(contains( ...
            generated_coronal_files, area_token));
        cleanupGeneratedFilesLocal(coronal_dir, ...
            sprintf('Jim_%s_*_ProjectedLocations.png', area), area_generated);
    end
end

if generateSagittalPlots
    % Mirror coronal display coordinates into the NIfTI first dimension.
    % High NIfTI ML indices are Jim's left hemisphere, as verified against
    % the dedicated left-only and right-only ROI volumes.
    rounded_display_ml_voxels = round(ml_voxels);
    rounded_ml_voxels = (size(struct_nii.img, 1) - 1) - rounded_display_ml_voxels;
    if any(rounded_ml_voxels <= OrigPoint_Voxel(1))
        error(['Jim sagittal MRI ML voxels must remain on the left hemisphere ' ...
            '(above midsagittal voxel %d), but found: %s'], ...
            OrigPoint_Voxel(1), mat2str(unique(rounded_ml_voxels( ...
            rounded_ml_voxels <= OrigPoint_Voxel(1))).'));
    end
    occupied_ml_voxels = unique(rounded_ml_voxels);
    all_ml_voxels = min(occupied_ml_voxels):max(occupied_ml_voxels);
    hidden_ml_voxels = setdiff(all_ml_voxels, occupied_ml_voxels);
    fprintf('Jim occupied sagittal ML voxels: %s\n', mat2str(occupied_ml_voxels(:).'));
    fprintf('Jim intermediate sagittal ML voxels: %s\n', mat2str(hidden_ml_voxels(:).'));
    generated_sagittal_files = strings(numel(all_ml_voxels), 1);
    generated_count = 0;
    for ml_voxel = all_ml_voxels
        [image_slice, roi_slice] = prepareSagittalSliceLocal( ...
            struct_nii.img, sagittal_roi_nii.img, ml_voxel);
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
            slice_context = sprintf('hidden between ML voxels %d and %d', lower_ml, upper_ml);
            filename_context = sprintf('HiddenBetweenML%03d-%03d', lower_ml, upper_ml);
        end

        fig = figure('Color', 'w', 'Visible', 'off', 'Position', [100, 100, 1000, 800]);
        imshow(image_slice, 'InitialMagnification', 1000);
        hold on;
        overlayROIsLocal(image_slice, roi_slice, ROI_intensity, color_mat, 750);
        dot_handles = gobjects(numel(areas), 1);
        for area_idx = 1:numel(areas)
            area = areas(area_idx);
            area_mask = included_roi == area;
            % Distinguish recording sites using the same MT/FST colors as
            % the corresponding atlas ROIs.
            dot_color = color_mat(area_idx + 2, :);
            dot_handles(area_idx) = scatter(ap_voxels(area_mask), depth_voxels(area_mask), ...
                8, dot_color, 'filled', 'MarkerEdgeColor', dot_color .* 0.55, ...
                'LineWidth', 0.5, 'MarkerFaceAlpha', 0.75, 'MarkerEdgeAlpha', 0.85);
        end
        legend(dot_handles, cellstr(areas), 'Location', 'southeast', 'Box', 'off', ...
            'FontSize', 6, 'AutoUpdate', 'off');
        xlim([min(brain_cols), max(brain_cols)]);
        ylim([min(brain_rows), max(brain_rows)]);
        title({sprintf('Jim MT + FST | left sagittal MRI slice index %d (MRI ML voxel %d)', ...
            ml_voxel + 1, ml_voxel), ...
            sprintf('%s | MT %d + FST %d included locations', slice_context, ...
            nnz(included_roi == "MT"), nnz(included_roi == "FST"))}, ...
            'FontSize', 8, 'Interpreter', 'none');
        hold off;
        output_name = sprintf('Jim_MT-FST_MLVoxel%03d_%s_SagittalProjectedLocations.png', ...
            ml_voxel, filename_context);
        output_file = fullfile(sagittal_dir, output_name);
        exportgraphics(fig, output_file, 'Resolution', 300);
        close(fig);
        generated_count = generated_count + 1;
        generated_sagittal_files(generated_count) = string(output_file);
        fprintf('Generated combined Jim MT and FST sagittal projection for ML voxel %d.\n', ml_voxel);
    end
    cleanupGeneratedFilesLocal(sagittal_dir, ...
        'Jim_*_SagittalProjectedLocations.png', generated_sagittal_files);
end

fprintf('Jim recording-location plotting completed.\n');

function column_data = getTableColumnLocal(tb, requested_name)
variable_names = tb.Properties.VariableNames;
normalized_variables = regexprep(lower(string(variable_names)), '[^a-z0-9]', '');
normalized_request = regexprep(lower(string(requested_name)), '[^a-z0-9]', '');
match_idx = find(normalized_variables == normalized_request, 1, 'first');
if isempty(match_idx), error('Column "%s" was not found.', requested_name); end
column_data = tb.(variable_names{match_idx});
end

function value = getValueAtRowLocal(column_data, row_idx)
if iscell(column_data), value = column_data{row_idx}; else, value = column_data(row_idx, :); end
end

function text_values = normalizeTextColumnLocal(column_data)
text_values = strings(numel(column_data), 1);
for i = 1:numel(column_data)
    value = getValueAtRowLocal(column_data, i);
    if isempty(value) || (isnumeric(value) && all(isnan(value(:))))
        text_values(i) = "";
    else
        text_values(i) = strtrim(string(value));
    end
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
        if strlength(text_values(i)) == 0, continue; end
        try, dates(i) = datetime(text_values(i)); catch, end
    end
end
end

function values = parseNumericVectorLocal(value)
if isnumeric(value), values = double(value(:).'); return; end
tokens = regexp(char(strtrim(string(value))), ...
    '[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?', 'match');
values = double(str2double(tokens));
values = values(:).';
end

function value = parseScalarDoubleLocal(raw_value)
if isnumeric(raw_value), value = double(raw_value(1)); else, value = str2double(string(raw_value)); end
end

function ml_voxel = computeMLVoxelLocal(hole, offset_mm, origin_voxel)
if mod(hole(2), 2) == 1, edge_offset = 1.4; else, edge_offset = 1.8; end
if hole(1) > 0
    ml_voxel = origin_voxel(1) - ((hole(1) - 1) * 0.8 + edge_offset) * 2;
else
    ml_voxel = origin_voxel(1) + ((abs(hole(1)) - 1) * 0.8 + edge_offset) * 2;
end
ml_voxel = ml_voxel + 2 * offset_mm(1);
end

function [image_slice, roi_slice] = prepareCoronalSliceLocal( ...
        struct_volume, roi_volume, ap_voxel, shift_roi)
ap_index = ap_voxel + 1;
if ap_index < 1 || ap_index > size(struct_volume, 3)
    error('MRI AP slice index %d is outside the structural volume.', ap_index);
end
image_slice = struct_volume(:, :, ap_index);
image_slice = fliplr(imrotate(image_slice, 90));
if ~isinteger(image_slice), image_slice = mat2gray(image_slice); end
image_slice(image_slice == 0) = 255;
roi_slice = double(roi_volume(:, :, ap_index));
roi_slice = fliplr(imrotate(roi_slice, 90));
if shift_roi, roi_slice = circshift(roi_slice, 1, 2); end
end

function [image_slice, roi_slice] = prepareSagittalSliceLocal( ...
        struct_volume, roi_volume, ml_voxel)
ml_index = ml_voxel + 1;
if ml_index < 1 || ml_index > size(struct_volume, 1)
    error('MRI ML slice index %d is outside the structural volume.', ml_index);
end
image_slice = squeeze(struct_volume(ml_index, :, :));
image_slice = fliplr(imrotate(image_slice, 180));
if ~isinteger(image_slice), image_slice = mat2gray(image_slice); end
image_slice(image_slice == 0) = 255;
roi_slice = double(squeeze(roi_volume(ml_index, :, :)));
roi_slice = fliplr(imrotate(roi_slice, 180));
end

function overlayROIsLocal(image_slice, roi_slice, roi_intensity, color_mat, magnification)
for r = 1:length(roi_intensity)
    slice_roi = roi_slice == roi_intensity(r);
    color_layer = cat(3, ones(size(image_slice)) .* color_mat(r, 1), ...
        ones(size(image_slice)) .* color_mat(r, 2), ...
        ones(size(image_slice)) .* color_mat(r, 3));
    h_roi = imshow(color_layer, 'InitialMagnification', magnification);
    set(h_roi, 'AlphaData', 1 * slice_roi);
end
end

function cleanupGeneratedFilesLocal(folder_path, pattern, generated_files)
existing = dir(fullfile(folder_path, pattern));
generated_lower = lower(generated_files);
removed_count = 0;
for i = 1:numel(existing)
    existing_file = string(fullfile(existing(i).folder, existing(i).name));
    if ~any(lower(existing_file) == generated_lower)
        delete(char(existing_file));
        removed_count = removed_count + 1;
    end
end
fprintf('Removed %d obsolete generated files from %s.\n', removed_count, folder_path);
end

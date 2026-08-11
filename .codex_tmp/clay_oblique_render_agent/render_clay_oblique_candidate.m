% Render the exact best plane saved by search_clay_oblique_plane.m.
%
% Coordinate convention
% ---------------------
% Every point in this script is a one-based MATLAB volume subscript
% [dimension-1, dimension-2, dimension-3].  The saved plane is therefore
% used without a 0/1-based offset:
%
%     dot(p - best.center, best.normal) = 0.
%
% The in-plane horizontal basis is the projection of +dimension-3 (AP)
% onto the oblique plane.  The vertical basis is cross(normal, horizontal).
% Consequently, as the plane tends to a sagittal plane with normal [1 0 0],
% horizontal tends to +dimension-3 (AP to the right) and vertical tends to
% -dimension-2 (ventral down), matching the established Clay sagittal view.

clearvars;
close all;

repo_root = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion';
output_dir = fullfile(repo_root, '.codex_tmp', 'clay_oblique_render_agent');
search_file = fullfile(repo_root, '.codex_tmp', 'clay_smoke', ...
    'clay_oblique_search_unique.mat');
structural_file = 'P:\MRI\R14008_GridScan\R14008_T1W_brain_Org2AvgGrid.nii.gz';
roi_file = 'P:\MRI\R14008_GridScan\R14008_LEV00_ROIs_org2Grid.nii.gz';
output_file = fullfile(output_dir, 'Clay_MT-FST_ObliqueBest_UniqueSites.png');
log_file = fullfile(output_dir, 'render_clay_oblique_candidate.log');

if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

assert(isfile(search_file), 'Search result was not found: %s', search_file);
addpath('P:\MRI\Grid_Mapping');

saved = load(search_file, 'best', 'points', 'labels', ...
    'session_points', 'session_labels');
best = saved.best;
points = double(saved.points);
labels = upper(strip(string(saved.labels(:))));

assert(size(points, 2) == 3 && size(points, 1) == numel(labels), ...
    'Saved unique-site points and labels have incompatible sizes.');
assert(all(isfinite(points), 'all'), 'Saved coordinates contain nonfinite values.');

structural_nii = load_nii(structural_file);
roi_nii = load_nii(roi_file);
structural = double(structural_nii.img);
roi = double(roi_nii.img);
assert(isequal(size(structural), size(roi)), ...
    'Structural and ROI volumes have different matrix sizes.');

normal = double(best.normal(:).');
normal = normal ./ norm(normal);
center = double(best.center(:).');
if normal(1) < 0
    % A plane is unchanged when its normal is negated.  Use the sign whose
    % sagittal limit is +dimension-1 so AP-right and ventral-down can both
    % be maintained by a right-handed in-plane basis.
    normal = -normal;
end

% AP-right basis.  This construction has a well-defined sagittal limit:
% normal -> [1 0 0], horizontal -> [0 0 1], vertical -> [0 -1 0].
ap_axis = [0, 0, 1];
horizontal = ap_axis - dot(ap_axis, normal) .* normal;
assert(norm(horizontal) > 1e-8, ...
    'Candidate normal is too close to the AP axis for this display basis.');
horizontal = horizontal ./ norm(horizontal);
vertical = cross(normal, horizontal);
vertical = vertical ./ norm(vertical);
assert(dot(vertical, [0, -1, 0]) > 0, ...
    'Display basis did not preserve the ventral-down sagittal limit.');

% Bound the sampling rectangle by projecting all eight one-based volume
% corners into the plane.  A 0.5-voxel grid gives smoother oblique masks
% while retaining the search result's native voxel-coordinate geometry.
volume_size = size(structural);
[c1, c2, c3] = ndgrid([1, volume_size(1)], [1, volume_size(2)], ...
    [1, volume_size(3)]);
corners = [c1(:), c2(:), c3(:)];
corner_delta = corners - center;
horizontal_extent = corner_delta * horizontal.';
vertical_extent = corner_delta * vertical.';
sample_step = 0.5;
horizontal_values = floor(min(horizontal_extent)):sample_step:ceil(max(horizontal_extent));
vertical_values = floor(min(vertical_extent)):sample_step:ceil(max(vertical_extent));
[horizontal_grid, vertical_grid] = meshgrid(horizontal_values, vertical_values);

query_1 = center(1) + horizontal_grid .* horizontal(1) + vertical_grid .* vertical(1);
query_2 = center(2) + horizontal_grid .* horizontal(2) + vertical_grid .* vertical(2);
query_3 = center(3) + horizontal_grid .* horizontal(3) + vertical_grid .* vertical(3);

% interpn accepts coordinates in MATLAB subscript order, unlike interp3's
% x/y convention.  No coordinate receives an extra +1 here.
structural_slice = interpn(structural, query_1, query_2, query_3, ...
    'linear', NaN);
roi_slice = interpn(roi, query_1, query_2, query_3, 'nearest', 0);

valid_brain = isfinite(structural_slice) & structural_slice > 0;
assert(any(valid_brain, 'all'), 'The selected plane did not intersect nonzero MRI data.');

% Robust grayscale windowing, implemented locally to avoid a toolbox
% dependency on percentile helpers.
brain_values = sort(structural_slice(valid_brain));
n_values = numel(brain_values);
low_value = brain_values(max(1, round(0.01 * n_values)));
high_value = brain_values(min(n_values, round(0.995 * n_values)));
if high_value <= low_value
    low_value = min(brain_values);
    high_value = max(brain_values);
end
gray_slice = (structural_slice - low_value) ./ max(eps, high_value - low_value);
gray_slice = min(max(gray_slice, 0), 1);
gray_slice(~valid_brain) = 1;
rgb_slice = repmat(gray_slice, 1, 1, 3);

mt_label = 25;
fst_label = 24;
mt_color = [226, 100, 0] ./ 255;
fst_color = [135, 2, 214] ./ 255;
atlas_alpha = 0.50;
rgb_slice = blendMask(rgb_slice, roi_slice == mt_label, mt_color, atlas_alpha);
rgb_slice = blendMask(rgb_slice, roi_slice == fst_label, fst_color, atlas_alpha);

% Project the exact saved unique coordinate-label sites onto the candidate
% plane, then express them in the same AP-right/ventral-down basis.
signed_distance = (points - center) * normal.';
projected_points = points - signed_distance .* normal;
point_delta = projected_points - center;
point_horizontal = point_delta * horizontal.';
point_vertical = point_delta * vertical.';

rounded_projected = round(projected_points);
valid_index = all(rounded_projected >= 1, 2) & ...
    rounded_projected(:, 1) <= volume_size(1) & ...
    rounded_projected(:, 2) <= volume_size(2) & ...
    rounded_projected(:, 3) <= volume_size(3);
sampled_labels = zeros(size(labels));
sampled_labels(valid_index) = roi(sub2ind(volume_size, ...
    rounded_projected(valid_index, 1), rounded_projected(valid_index, 2), ...
    rounded_projected(valid_index, 3)));
is_mt = labels == "MT";
is_fst = labels == "FST";
mt_correct = nnz(is_mt & sampled_labels == mt_label);
fst_correct = nnz(is_fst & sampled_labels == fst_label);

% Crop to the nonzero brain intersection, while retaining enough margin to
% show nearby atlas and point locations.
[brain_rows, brain_columns] = find(valid_brain);
margin_pixels = round(8 / sample_step);
row_limits = [max(1, min(brain_rows) - margin_pixels), ...
    min(size(valid_brain, 1), max(brain_rows) + margin_pixels)];
column_limits = [max(1, min(brain_columns) - margin_pixels), ...
    min(size(valid_brain, 2), max(brain_columns) + margin_pixels)];
x_limits = horizontal_values(column_limits);
y_limits = vertical_values(row_limits);

old_visibility = get(groot, 'defaultFigureVisible');
visibility_cleanup = onCleanup(@() set(groot, 'defaultFigureVisible', old_visibility)); %#ok<NASGU>
set(groot, 'defaultFigureVisible', 'off');
figure_handle = figure('Color', 'w', 'Visible', 'off', ...
    'Position', [60, 60, 1320, 980], 'Renderer', 'opengl');
axes_handle = axes(figure_handle);
image(axes_handle, horizontal_values, vertical_values, rgb_slice);
set(axes_handle, 'YDir', 'reverse');
axis(axes_handle, 'image');
hold(axes_handle, 'on');

% Thin atlas outlines make containment readable even beneath colored dots.
contour(axes_handle, horizontal_values, vertical_values, ...
    double(roi_slice == mt_label), [0.5, 0.5], ...
    'Color', mt_color .* 0.60, 'LineWidth', 0.8);
contour(axes_handle, horizontal_values, vertical_values, ...
    double(roi_slice == fst_label), [0.5, 0.5], ...
    'Color', fst_color .* 0.60, 'LineWidth', 0.8);

% A white halo keeps each point distinct from the same-color atlas mask.
scatter(axes_handle, point_horizontal(is_mt), point_vertical(is_mt), 54, ...
    'w', 'filled', 'MarkerEdgeColor', 'w', 'LineWidth', 0.5);
mt_handle = scatter(axes_handle, point_horizontal(is_mt), point_vertical(is_mt), ...
    29, mt_color, 'filled', 'MarkerEdgeColor', mt_color .* 0.42, ...
    'LineWidth', 0.7, 'MarkerFaceAlpha', 0.88, 'MarkerEdgeAlpha', 0.95);
scatter(axes_handle, point_horizontal(is_fst), point_vertical(is_fst), 54, ...
    'w', 'filled', 'MarkerEdgeColor', 'w', 'LineWidth', 0.5);
fst_handle = scatter(axes_handle, point_horizontal(is_fst), point_vertical(is_fst), ...
    29, fst_color, 'filled', 'MarkerEdgeColor', fst_color .* 0.42, ...
    'LineWidth', 0.7, 'MarkerFaceAlpha', 0.88, 'MarkerEdgeAlpha', 0.95);

xlim(axes_handle, x_limits);
ylim(axes_handle, y_limits);
axes_handle.Visible = 'off';
title(axes_handle, { ...
    'Clay MT + FST | optimized oblique MRI section', ...
    sprintf(['unique sites: MT %d/%d in MT atlas, FST %d/%d in FST atlas ' ...
        '| max projection %.2f vox'], mt_correct, nnz(is_mt), ...
        fst_correct, nnz(is_fst), max(abs(signed_distance)))}, ...
    'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none', ...
    'Visible', 'on');
legend(axes_handle, [mt_handle, fst_handle], {'MT recording', 'FST recording'}, ...
    'Location', 'southeast', 'Box', 'off', 'FontSize', 11, ...
    'AutoUpdate', 'off');

exportgraphics(figure_handle, output_file, 'Resolution', 300);
close(figure_handle);

log_id = fopen(log_file, 'w');
assert(log_id >= 0, 'Could not open render log: %s', log_file);
log_cleanup = onCleanup(@() fclose(log_id)); %#ok<NASGU>
fprintf(log_id, 'Saved: %s\n', output_file);
fprintf(log_id, 'Volume size: %s\n', mat2str(volume_size));
fprintf(log_id, 'Plane center (one-based subscripts): %s\n', mat2str(center, 9));
fprintf(log_id, 'Plane normal: %s\n', mat2str(normal, 9));
fprintf(log_id, 'Horizontal basis (AP-right limit): %s\n', mat2str(horizontal, 9));
fprintf(log_id, 'Vertical basis (ventral-down limit): %s\n', mat2str(vertical, 9));
fprintf(log_id, 'Unique-site score: MT %d/%d, FST %d/%d, total %d/%d\n', ...
    mt_correct, nnz(is_mt), fst_correct, nnz(is_fst), ...
    mt_correct + fst_correct, numel(labels));
fprintf(log_id, 'Projection distance: mean %.4f vox, max %.4f vox\n', ...
    mean(abs(signed_distance)), max(abs(signed_distance)));

function rgb = blendMask(rgb, mask, color, alpha)
for channel = 1:3
    plane = rgb(:, :, channel);
    plane(mask) = (1 - alpha) .* plane(mask) + alpha .* color(channel);
    rgb(:, :, channel) = plane;
end
end

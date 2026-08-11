repo_root = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion';
audit_log = fullfile(repo_root, '.codex_tmp', 'clay_smoke', 'clay_oblique_input_audit.log');
diary(audit_log);
diary_cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
addpath(fullfile(repo_root, '.codex_tmp', 'clay_smoke'));
addpath('P:\MRI\Grid_Mapping');

workbook_path = 'P:\Clay\NeuroData\RecordingRecord_Stimulation.xlsx';
roi_path = 'P:\MRI\R14008_GridScan\R14008_LEV00_ROIs_org2Grid.nii.gz';
struct_path = 'P:\MRI\R14008_GridScan\R14008_T1W_brain_Org2AvgGrid.nii.gz';
origin = [127, 208, 68];

tb = readtable(workbook_path, 'VariableNamingRule', 'preserve');
[rows, audit] = getWorkbookRowsFromUnitTableGof(tb, 'Clay');

holes = nan(numel(rows), 2);
offsets = nan(numel(rows), 3);
guide = nan(numel(rows), 1);
depth = nan(numel(rows), 1);
labels = upper(string(tb.ROI(rows)));
hole_column = getColumn(tb, 'Hole');
offset_column = getColumn(tb, 'Offset');
guide_column = getColumn(tb, 'GuideTube');
depth_column = getColumn(tb, 'Depth');
for i = 1:numel(rows)
    holes(i, :) = parseVector(valueAt(hole_column, rows(i)));
    offsets(i, :) = parseVector(valueAt(offset_column, rows(i)));
    guide(i) = parseScalar(valueAt(guide_column, rows(i)));
    depth(i) = parseScalar(valueAt(depth_column, rows(i)));
end

grid_ml = nan(numel(rows), 1);
for i = 1:numel(rows)
    if mod(holes(i, 2), 2) == 1
        edge_offset = 1.4;
    else
        edge_offset = 1.8;
    end
    if holes(i, 1) > 0
        grid_ml(i) = origin(1) - ((holes(i, 1) - 1) * 0.8 + edge_offset) * 2;
    else
        grid_ml(i) = origin(1) + ((abs(holes(i, 1)) - 1) * 0.8 + edge_offset) * 2;
    end
    grid_ml(i) = grid_ml(i) + 2 * offsets(i, 1);
end

% One-based coordinates in the unrotated NIfTI array.
points = [256 - grid_ml, ...
    origin(2) - 2 * (guide + depth) - 2 * offsets(:, 3) + 1, ...
    origin(3) - ((29 - holes(:, 2)) * 0.8) * 2 + 2 * offsets(:, 2) + 1];

struct_nii = load_nii(struct_path);
roi_nii = load_nii(roi_path);
roi = double(roi_nii.img);

point_labels = interpn(roi, points(:, 1), points(:, 2), points(:, 3), 'nearest', 0);
current_plane = points;
current_plane(:, 1) = 165; % MATLAB index for ML voxel 164.
current_labels = interpn(roi, current_plane(:, 1), current_plane(:, 2), current_plane(:, 3), 'nearest', 0);

fprintf('Structural size: %s class=%s range=[%g %g]\n', mat2str(size(struct_nii.img)), ...
    class(struct_nii.img), min(struct_nii.img(:)), max(struct_nii.img(:)));
fprintf('ROI size: %s unique labels: %s\n', mat2str(size(roi)), ...
    mat2str(unique(roi(:)).'));
fprintf('Rows=%d MT=%d FST=%d\n', numel(rows), nnz(labels == "MT"), nnz(labels == "FST"));
fprintf('Point coordinate min: %s\n', mat2str(min(points, [], 1), 5));
fprintf('Point coordinate max: %s\n', mat2str(max(points, [], 1), 5));
fprintf('Point coordinate mean: %s\n', mat2str(mean(points, 1), 5));
fprintf('True 3-D sampling: MT in MT=%d/%d, FST in FST=%d/%d\n', ...
    nnz(point_labels(labels == "MT") == 25), nnz(labels == "MT"), ...
    nnz(point_labels(labels == "FST") == 24), nnz(labels == "FST"));
fprintf('Current sagittal plane x=165: MT in MT=%d/%d, FST in FST=%d/%d\n', ...
    nnz(current_labels(labels == "MT") == 25), nnz(labels == "MT"), ...
    nnz(current_labels(labels == "FST") == 24), nnz(labels == "FST"));
fprintf('Current labels by group MT: %s\n', mat2str(groupcounts(categorical(point_labels(labels == "MT"))).'));
fprintf('Current labels by group FST: %s\n', mat2str(groupcounts(categorical(point_labels(labels == "FST"))).'));

centered = points - mean(points, 1);
[~, s, v] = svd(centered, 0);
fprintf('Point PCA singular values: %s\n', mat2str(diag(s).', 5));
fprintf('Point PCA directions (columns):\n');
disp(v);

for value = [25, 24]
    [a, b, c] = ind2sub(size(roi), find(roi == value));
    fprintf('ROI %d bbox min=%s max=%s count=%d\n', value, ...
        mat2str(min([a b c], [], 1)), mat2str(max([a b c], [], 1)), numel(a));
end

function values = parseVector(raw)
if isnumeric(raw)
    values = double(raw(:).');
else
    tokens = regexp(char(string(raw)), '[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?', 'match');
    values = str2double(tokens);
end
end

function value = parseScalar(raw)
if iscell(raw), raw = raw{1}; end
if isnumeric(raw), value = double(raw(1)); else, value = str2double(string(raw)); end
end

function column = getColumn(tb, requested)
names = tb.Properties.VariableNames;
normalized = regexprep(lower(string(names)), '[^a-z0-9]', '');
target = regexprep(lower(string(requested)), '[^a-z0-9]', '');
idx = find(normalized == target, 1, 'first');
assert(~isempty(idx), 'Missing column %s. Available: %s', requested, strjoin(names, ', '));
column = tb.(names{idx});
end

function value = valueAt(column, row)
if iscell(column), value = column{row}; else, value = column(row, :); end
end

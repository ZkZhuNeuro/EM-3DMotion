repo_root = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion';
log_path = fullfile(repo_root, '.codex_tmp', 'clay_smoke', 'clay_oblique_search.log');
diary(log_path);
cleanup_diary = onCleanup(@() diary('off')); %#ok<NASGU>
addpath(fullfile(repo_root, '.codex_tmp', 'clay_smoke'));
addpath('P:\MRI\Grid_Mapping');

[points, labels] = loadClayPoints();
session_points = points;
session_labels = labels;
roi_nii = load_nii('P:\MRI\R14008_GridScan\R14008_LEV00_ROIs_org2Grid.nii.gz');
roi = double(roi_nii.img);
target = zeros(size(labels));
target(labels == "MT") = 25;
target(labels == "FST") = 24;
[site_rows, ~, ~] = unique([round(points, 4), double(target)], 'rows');
points = site_rows(:, 1:3);
target = site_rows(:, 4);
labels = strings(size(target));
labels(target == 25) = "MT";
labels(target == 24) = "FST";
mu = mean(points, 1);
max_distance_vox = 5;

current = evaluateCandidate([1 0 0], 165 - mu(1), points, labels, target, roi);
fprintf('Current x=165: %d/%d MT, %d/%d FST, total %d, max distance %.3f vox\n', ...
    current.mtCorrect, current.mtTotal, current.fstCorrect, current.fstTotal, ...
    current.totalCorrect, current.maxDistance);

best_sag = emptyCandidate();
for plane_x = 160:0.05:171
    candidate = evaluateCandidate([1 0 0], plane_x - mu(1), points, labels, target, roi);
    if candidate.maxDistance <= max_distance_vox && isBetter(candidate, best_sag)
        best_sag = candidate;
    end
end
fprintf('Best translated sagittal: x=%.3f, %d/%d MT, %d/%d FST, total %d, max %.3f\n', ...
    mu(1) + best_sag.offset, best_sag.mtCorrect, best_sag.mtTotal, ...
    best_sag.fstCorrect, best_sag.fstTotal, best_sag.totalCorrect, best_sag.maxDistance);

best = emptyCandidate();
top = repmat(emptyCandidate(), 20, 1);
for tilt_deg = 0:2:90
    tilt = deg2rad(tilt_deg);
    if tilt_deg == 0
        azimuth_values = 0;
    else
        azimuth_values = 0:3:357;
    end
    for azimuth_deg = azimuth_values
        azimuth = deg2rad(azimuth_deg);
        normal = [cos(tilt), sin(tilt) * cos(azimuth), sin(tilt) * sin(azimuth)];
        along = (points - mu) * normal.';
        lower_t = max(along) - max_distance_vox;
        upper_t = min(along) + max_distance_vox;
        if lower_t > upper_t
            continue
        end
        offsets = unique([lower_t:0.25:upper_t, upper_t]); %#ok<NBRAK>
        for offset = offsets
            candidate = evaluateCandidate(normal, offset, points, labels, target, roi);
            candidate.tiltDeg = tilt_deg;
            candidate.azimuthDeg = azimuth_deg;
            if isBetter(candidate, best)
                best = candidate;
            end
            top = insertTop(top, candidate);
        end
    end
end
fprintf('Coarse best: tilt %.3f azimuth %.3f offset %.3f; MT %d/%d FST %d/%d total %d max %.3f mean %.3f\n', ...
    best.tiltDeg, best.azimuthDeg, best.offset, best.mtCorrect, best.mtTotal, ...
    best.fstCorrect, best.fstTotal, best.totalCorrect, best.maxDistance, best.meanDistance);

coarse_best = best;
for tilt_deg = max(0, coarse_best.tiltDeg - 3):0.25:min(90, coarse_best.tiltDeg + 3)
    tilt = deg2rad(tilt_deg);
    for azimuth_deg = coarse_best.azimuthDeg - 4:0.25:coarse_best.azimuthDeg + 4
        azimuth = deg2rad(mod(azimuth_deg, 360));
        normal = [cos(tilt), sin(tilt) * cos(azimuth), sin(tilt) * sin(azimuth)];
        along = (points - mu) * normal.';
        lower_t = max(along) - max_distance_vox;
        upper_t = min(along) + max_distance_vox;
        if lower_t > upper_t
            continue
        end
        center_offset = min(max(coarse_best.offset, lower_t), upper_t);
        for offset = max(lower_t, center_offset - 1):0.05:min(upper_t, center_offset + 1)
            candidate = evaluateCandidate(normal, offset, points, labels, target, roi);
            candidate.tiltDeg = tilt_deg;
            candidate.azimuthDeg = mod(azimuth_deg, 360);
            if isBetter(candidate, best)
                best = candidate;
            end
            top = insertTop(top, candidate);
        end
    end
end

fprintf('Refined best: normal=%s center=%s tilt %.3f azimuth %.3f offset %.3f\n', ...
    mat2str(best.normal, 8), mat2str(mu + best.offset * best.normal, 8), ...
    best.tiltDeg, best.azimuthDeg, best.offset);
fprintf('Refined counts: MT %d/%d (%.1f%%), FST %d/%d (%.1f%%), total %d/%d (%.1f%%), balanced %.4f\n', ...
    best.mtCorrect, best.mtTotal, 100 * best.mtCorrect / best.mtTotal, ...
    best.fstCorrect, best.fstTotal, 100 * best.fstCorrect / best.fstTotal, ...
    best.totalCorrect, numel(labels), 100 * best.totalCorrect / numel(labels), best.balancedAccuracy);
fprintf('Projection distances: mean %.3f vox (%.3f mm), max %.3f vox (%.3f mm)\n', ...
    best.meanDistance, 0.5 * best.meanDistance, best.maxDistance, 0.5 * best.maxDistance);

session_target = 25 * (session_labels == "MT") + 24 * (session_labels == "FST");
session_best = evaluateCandidate(best.normal, dot(best.center - mean(session_points, 1), best.normal), ...
    session_points, session_labels, session_target, roi);
fprintf('Session evaluation of unique-site optimum: MT %d/%d FST %d/%d total %d/%d\n', ...
    session_best.mtCorrect, session_best.mtTotal, session_best.fstCorrect, ...
    session_best.fstTotal, session_best.totalCorrect, numel(session_labels));
save(fullfile(repo_root, '.codex_tmp', 'clay_smoke', 'clay_oblique_search_unique.mat'), ...
    'best', 'best_sag', 'current', 'top', 'points', 'labels', 'mu', ...
    'session_best', 'session_points', 'session_labels');

function candidate = evaluateCandidate(normal, offset, points, labels, target, roi)
normal = normal / norm(normal);
mu = mean(points, 1);
signed_distance = (points - mu) * normal.' - offset;
projected = points - signed_distance .* normal;
indices = round(projected);
valid = all(indices >= 1, 2) & indices(:, 1) <= size(roi, 1) & ...
    indices(:, 2) <= size(roi, 2) & indices(:, 3) <= size(roi, 3);
sampled = zeros(size(target));
sampled(valid) = roi(sub2ind(size(roi), indices(valid, 1), indices(valid, 2), indices(valid, 3)));
correct = sampled == target;
mt = labels == "MT";
fst = labels == "FST";
candidate = struct();
candidate.normal = normal;
candidate.offset = offset;
candidate.center = mu + offset * normal;
candidate.tiltDeg = acosd(max(-1, min(1, normal(1))));
candidate.azimuthDeg = mod(atan2d(normal(3), normal(2)), 360);
candidate.mtCorrect = nnz(correct & mt);
candidate.mtTotal = nnz(mt);
candidate.fstCorrect = nnz(correct & fst);
candidate.fstTotal = nnz(fst);
candidate.totalCorrect = nnz(correct);
candidate.balancedAccuracy = 0.5 * (candidate.mtCorrect / candidate.mtTotal + ...
    candidate.fstCorrect / candidate.fstTotal);
candidate.minClassAccuracy = min(candidate.mtCorrect / candidate.mtTotal, ...
    candidate.fstCorrect / candidate.fstTotal);
candidate.meanDistance = mean(abs(signed_distance));
candidate.maxDistance = max(abs(signed_distance));
candidate.sampledLabels = sampled;
candidate.projectedPoints = projected;
end

function tf = isBetter(a, b)
if ~isfinite(b.balancedAccuracy)
    tf = true;
    return
end
keys_a = [a.balancedAccuracy, a.minClassAccuracy, a.totalCorrect, ...
    -a.meanDistance, -a.maxDistance];
keys_b = [b.balancedAccuracy, b.minClassAccuracy, b.totalCorrect, ...
    -b.meanDistance, -b.maxDistance];
tf = false;
for i = 1:numel(keys_a)
    if keys_a(i) > keys_b(i) + 1e-12, tf = true; return; end
    if keys_a(i) < keys_b(i) - 1e-12, return; end
end
end

function top = insertTop(top, candidate)
if ~isBetter(candidate, top(end)), return; end
top(end) = candidate;
for i = numel(top)-1:-1:1
    if isBetter(top(i+1), top(i))
        tmp = top(i);
        top(i) = top(i+1);
        top(i+1) = tmp;
    else
        break
    end
end
end

function candidate = emptyCandidate()
candidate = struct('normal', [nan nan nan], 'offset', nan, 'center', [nan nan nan], ...
    'tiltDeg', nan, 'azimuthDeg', nan, 'mtCorrect', 0, 'mtTotal', 1, ...
    'fstCorrect', 0, 'fstTotal', 1, 'totalCorrect', 0, ...
    'balancedAccuracy', -inf, 'minClassAccuracy', -inf, ...
    'meanDistance', inf, 'maxDistance', inf, 'sampledLabels', [], ...
    'projectedPoints', []);
end

function [points, labels] = loadClayPoints()
workbook_path = 'P:\Clay\NeuroData\RecordingRecord_Stimulation.xlsx';
tb = readtable(workbook_path, 'VariableNamingRule', 'preserve');
[rows, ~] = matchWorkbookRows(tb, 'Clay');
origin = [127, 208, 68];
labels = upper(strip(string(valueColumn(tb, 'ROI', rows))));
hole_column = getColumn(tb, 'Hole');
offset_column = getColumn(tb, 'Offset');
guide_column = getColumn(tb, 'GuideTube');
depth_column = getColumn(tb, 'Depth');
holes = nan(numel(rows), 2);
offsets = nan(numel(rows), 3);
guide = nan(numel(rows), 1);
depth = nan(numel(rows), 1);
for i = 1:numel(rows)
    holes(i, :) = parseVector(valueAt(hole_column, rows(i)));
    offsets(i, :) = parseVector(valueAt(offset_column, rows(i)));
    guide(i) = parseScalar(valueAt(guide_column, rows(i)));
    depth(i) = parseScalar(valueAt(depth_column, rows(i)));
end
grid_ml = nan(numel(rows), 1);
for i = 1:numel(rows)
    if mod(holes(i, 2), 2) == 1, edge_offset = 1.4; else, edge_offset = 1.8; end
    if holes(i, 1) > 0
        grid_ml(i) = origin(1) - ((holes(i, 1) - 1) * 0.8 + edge_offset) * 2;
    else
        grid_ml(i) = origin(1) + ((abs(holes(i, 1)) - 1) * 0.8 + edge_offset) * 2;
    end
    grid_ml(i) = grid_ml(i) + 2 * offsets(i, 1);
end
points = [256 - grid_ml, ...
    origin(2) - 2 * (guide + depth) - 2 * offsets(:, 3) + 1, ...
    origin(3) - ((29 - holes(:, 2)) * 0.8) * 2 + 2 * offsets(:, 2) + 1];
end

function column = getColumn(tb, requested)
names = tb.Properties.VariableNames;
normalized = regexprep(lower(string(names)), '[^a-z0-9]', '');
target = regexprep(lower(string(requested)), '[^a-z0-9]', '');
idx = find(normalized == target, 1, 'first');
assert(~isempty(idx), 'Missing column %s.', requested);
column = tb.(names{idx});
end

function values = valueColumn(tb, requested, rows)
column = getColumn(tb, requested);
if iscell(column), values = column(rows); else, values = column(rows, :); end
end

function value = valueAt(column, row)
if iscell(column), value = column{row}; else, value = column(row, :); end
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
if isnumeric(raw), value = double(raw(1)); else, value = str2double(string(raw)); end
end

function [rows, audit] = matchWorkbookRows(tb, monkey_name)
loaded = load('C:\EM\BehaviorFitting\unit_table_gof.mat', 'unit_table_gof');
gof = loaded.unit_table_gof;
workbook_dates = normalizeDates(getColumn(tb, 'Date'));
workbook_roi = upper(strip(string(getColumn(tb, 'ROI'))));
gof_dates = normalizeDates(gof.Date);
gof_monkey = upper(strip(string(gof.Monkey)));
gof_roi = upper(strip(string(gof.ROI)));
mask = gof_monkey == upper(string(monkey_name)) & ismember(gof_roi, ["MT", "FST"]) & ~isnat(gof_dates);
keys = string(gof_dates(mask), 'yyyy-MM-dd') + "|" + gof_roi(mask);
workbook_keys = string(workbook_dates, 'yyyy-MM-dd') + "|" + workbook_roi;
assert(numel(unique(keys)) == numel(keys), 'Duplicate unit_table_gof Date-ROI keys.');
rows = nan(numel(keys), 1);
for i = 1:numel(keys)
    match = find(workbook_keys == keys(i));
    assert(numel(match) == 1, 'Expected one workbook match for %s.', keys(i));
    rows(i) = match;
end
rows = sort(rows);
audit = table(keys, 'VariableNames', {'Key'});
end

function dates = normalizeDates(values)
if isdatetime(values)
    dates = dateshift(values, 'start', 'day');
elseif isnumeric(values)
    dates = dateshift(datetime(values, 'ConvertFrom', 'excel'), 'start', 'day');
else
    text_values = strip(string(values));
    dates = NaT(size(text_values));
    formats = {'MM/dd/yyyy','M/d/yyyy','yyyy-MM-dd','dd-MMM-yyyy'};
    for i = 1:numel(text_values)
        for j = 1:numel(formats)
            try
                dates(i) = datetime(text_values(i), 'InputFormat', formats{j});
                break
            catch
            end
        end
    end
end
end

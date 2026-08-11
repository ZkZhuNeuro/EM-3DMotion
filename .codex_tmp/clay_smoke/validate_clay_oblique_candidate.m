repo_root = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion';
log_path = fullfile(repo_root, '.codex_tmp', 'clay_smoke', 'clay_oblique_validation.log');
diary(log_path);
cleanup_diary = onCleanup(@() diary('off')); %#ok<NASGU>
addpath('P:\MRI\Grid_Mapping');

loaded = load(fullfile(repo_root, '.codex_tmp', 'clay_smoke', 'clay_oblique_search.mat'));
best = loaded.best;
points = loaded.points;
labels = loaded.labels;
mu = loaded.mu;
roi_nii = load_nii('P:\MRI\R14008_GridScan\R14008_LEV00_ROIs_org2Grid.nii.gz');
roi = double(roi_nii.img);
target = 25 * (labels == "MT") + 24 * (labels == "FST");

[unique_xyz, ~, xyz_group] = unique(round(points, 4), 'rows');
conflict_count = 0;
for g = 1:size(unique_xyz, 1)
    if numel(unique(labels(xyz_group == g))) > 1
        conflict_count = conflict_count + 1;
    end
end
label_sites = unique([round(points, 4), double(target)], 'rows');
site_points = label_sites(:, 1:3);
site_target = label_sites(:, 4);
site_labels = strings(size(site_target));
site_labels(site_target == 25) = "MT";
site_labels(site_target == 24) = "FST";

fprintf('Unique XYZ coordinates: %d; unique coordinate-label sites: %d; conflicting XYZ: %d\n', ...
    size(unique_xyz, 1), size(label_sites, 1), conflict_count);
session_eval = evaluate(best.normal, best.offset, points, labels, target, roi, mu);
site_eval = evaluate(best.normal, best.offset, site_points, site_labels, site_target, roi, mu);
fprintf('Best session score: MT %d/%d FST %d/%d total %d/%d\n', ...
    session_eval.mtCorrect, session_eval.mtTotal, session_eval.fstCorrect, ...
    session_eval.fstTotal, session_eval.totalCorrect, numel(labels));
fprintf('Best unique-site score: MT %d/%d FST %d/%d total %d/%d\n', ...
    site_eval.mtCorrect, site_eval.mtTotal, site_eval.fstCorrect, ...
    site_eval.fstTotal, site_eval.totalCorrect, numel(site_labels));

tilt0 = acosd(best.normal(1));
az0 = mod(atan2d(best.normal(3), best.normal(2)), 360);
records = [];
record_index = 0;
for dtilt = -2:0.5:2
    tilt = deg2rad(tilt0 + dtilt);
    for daz = -2:0.5:2
        az = deg2rad(az0 + daz);
        normal = [cos(tilt), sin(tilt) * cos(az), sin(tilt) * sin(az)];
        for doffset = -2:0.25:2
            candidate = evaluate(normal, best.offset + doffset, points, labels, target, roi, mu);
            record_index = record_index + 1;
            records(record_index, :) = [dtilt, daz, doffset, candidate.mtCorrect, ...
                candidate.fstCorrect, candidate.totalCorrect, candidate.balancedAccuracy, ...
                candidate.maxDistance]; %#ok<SAGROW>
        end
    end
end

near = abs(records(:, 1)) <= 1 & abs(records(:, 2)) <= 1 & abs(records(:, 3)) <= 1;
fprintf('Perturbations within +/-1 deg and +/-0.5 mm (offset +/-1 voxel):\n');
fprintf('  total correct min/median/max = %.0f / %.1f / %.0f\n', ...
    min(records(near, 6)), median(records(near, 6)), max(records(near, 6)));
fprintf('  MT correct min/median/max = %.0f / %.1f / %.0f\n', ...
    min(records(near, 4)), median(records(near, 4)), max(records(near, 4)));
fprintf('  FST correct min/median/max = %.0f / %.1f / %.0f\n', ...
    min(records(near, 5)), median(records(near, 5)), max(records(near, 5)));

% Find the locally robust center: maximize the worst total over +/-0.5 deg
% and +/-0.5 mm, then the mean total, then balanced accuracy at center.
best_robust = struct('normal', best.normal, 'offset', best.offset, 'worst', -inf, ...
    'mean', -inf, 'centerEval', session_eval);
for dtilt0 = -2:0.25:2
    for daz0 = -2:0.25:2
        for doffset0 = -1:0.25:1
            totals = [];
            for dtilt = [-0.5, 0, 0.5]
                tilt = deg2rad(tilt0 + dtilt0 + dtilt);
                for daz = [-0.5, 0, 0.5]
                    az = deg2rad(az0 + daz0 + daz);
                    normal = [cos(tilt), sin(tilt) * cos(az), sin(tilt) * sin(az)];
                    for doffset = [-1, 0, 1]
                        ev = evaluate(normal, best.offset + doffset0 + doffset, ...
                            points, labels, target, roi, mu);
                        totals(end + 1) = ev.totalCorrect; %#ok<SAGROW>
                    end
                end
            end
            tilt = deg2rad(tilt0 + dtilt0);
            az = deg2rad(az0 + daz0);
            normal = [cos(tilt), sin(tilt) * cos(az), sin(tilt) * sin(az)];
            center_eval = evaluate(normal, best.offset + doffset0, points, labels, target, roi, mu);
            key = [min(totals), mean(totals), center_eval.balancedAccuracy, center_eval.totalCorrect];
            old_key = [best_robust.worst, best_robust.mean, ...
                best_robust.centerEval.balancedAccuracy, best_robust.centerEval.totalCorrect];
            if lexGreater(key, old_key)
                best_robust.normal = normal;
                best_robust.offset = best.offset + doffset0;
                best_robust.worst = min(totals);
                best_robust.mean = mean(totals);
                best_robust.centerEval = center_eval;
            end
        end
    end
end
fprintf('Robust center normal=%s offset=%.3f worst=%d mean=%.2f\n', ...
    mat2str(best_robust.normal, 8), best_robust.offset, best_robust.worst, best_robust.mean);
fprintf('Robust center counts: MT %d/%d FST %d/%d total %d/%d; max dist %.3f vox\n', ...
    best_robust.centerEval.mtCorrect, best_robust.centerEval.mtTotal, ...
    best_robust.centerEval.fstCorrect, best_robust.centerEval.fstTotal, ...
    best_robust.centerEval.totalCorrect, numel(labels), best_robust.centerEval.maxDistance);
save(fullfile(repo_root, '.codex_tmp', 'clay_smoke', 'clay_oblique_validation.mat'), ...
    'best_robust', 'records', 'site_eval', 'session_eval', 'label_sites');

function ev = evaluate(normal, offset, points, labels, target, roi, mu)
normal = normal / norm(normal);
d = (points - mu) * normal.' - offset;
q = points - d .* normal;
idx = round(q);
valid = all(idx >= 1, 2) & idx(:, 1) <= size(roi, 1) & ...
    idx(:, 2) <= size(roi, 2) & idx(:, 3) <= size(roi, 3);
sampled = zeros(size(target));
sampled(valid) = roi(sub2ind(size(roi), idx(valid, 1), idx(valid, 2), idx(valid, 3)));
correct = sampled == target;
mt = labels == "MT";
fst = labels == "FST";
ev.mtCorrect = nnz(correct & mt);
ev.mtTotal = nnz(mt);
ev.fstCorrect = nnz(correct & fst);
ev.fstTotal = nnz(fst);
ev.totalCorrect = nnz(correct);
ev.balancedAccuracy = 0.5 * (ev.mtCorrect / ev.mtTotal + ev.fstCorrect / ev.fstTotal);
ev.meanDistance = mean(abs(d));
ev.maxDistance = max(abs(d));
end

function tf = lexGreater(a, b)
tf = false;
for i = 1:numel(a)
    if a(i) > b(i) + 1e-12, tf = true; return; end
    if a(i) < b(i) - 1e-12, return; end
end
end

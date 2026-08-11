function results = optimize_mtfst_oblique_section(cfg)
%OPTIMIZE_MTFST_OBLIQUE_SECTION Find and plot an MT/FST oblique plane.
%
% The existing sagittal summary projects every included recording location
% onto one anatomical slice. This function instead searches over plane
% orientation and translation. A recording is scored by the atlas label at
% its orthogonal projection onto the candidate plane. The search is run on
% unique recording sites so repeated sessions do not receive extra weight.
%
% Two planes are saved:
%   1. Highest-match: the best candidate found by the deterministic search.
%   2. Recommended robust: a nearby plane selected for stability to
%      +/-0.5 degree rotations and +/-0.5 mm translations. The nominal
%      plane always satisfies the configured distance constraint. A plane
%      whose entire perturbation neighborhood also satisfies it is preferred;
%      otherwise the neighborhood is used to measure, not veto, stability.
%
% All point coordinates remain continuous and one-based in the reoriented
% arrays matching the historical load_nii orientation. Structural MRI is
% interpolated linearly; categorical atlas labels use nearest-neighbor
% sampling. Monkey-specific paths, labels, counts, and output names are
% supplied by a thin wrapper in that monkey's plotting directory.

cfg = validateAnalysisConfig(cfg);
output_dir = cfg.outputDirectory;
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

data = loadRecordingData(cfg);
[structural, atlas, voxel_size_mm, volume_metadata] = loadVolumes(cfg);
cfg.voxelSizeMm = voxel_size_mm;
cfg.volumeMetadata = volume_metadata;
cfg.structuralWindow = computeStructuralWindow(structural);
validateInputs(data, structural, atlas, cfg);

site_data = collapseToUniqueSites(data, cfg);
actual_session = evaluateNativeLocations(data.points, data.labels, data.targetAtlas, atlas);
actual_sites = evaluateNativeLocations(site_data.points, site_data.labels, ...
    site_data.targetAtlas, atlas);

[maximum_site_plane, translated_sagittal_site_plane] = searchPlanes( ...
    site_data.points, site_data.labels, site_data.targetAtlas, atlas, cfg);
robust_site_plane = selectRobustPlane(maximum_site_plane, site_data.points, ...
    site_data.labels, site_data.targetAtlas, atlas, cfg);

site_mean = mean(site_data.points, 1);
current_center = site_mean;
current_center(1) = cfg.currentSagittalIndex;
current_site_plane = evaluatePlane([1, 0, 0], current_center, ...
    site_data.points, site_data.labels, site_data.targetAtlas, atlas);

maximum_session_plane = evaluatePlane(maximum_site_plane.normal, ...
    maximum_site_plane.center, data.points, data.labels, data.targetAtlas, atlas);
robust_session_plane = evaluatePlane(robust_site_plane.normal, ...
    robust_site_plane.center, data.points, data.labels, data.targetAtlas, atlas);
current_session_plane = evaluatePlane(current_site_plane.normal, ...
    current_site_plane.center, data.points, data.labels, data.targetAtlas, atlas);
translated_sagittal_session_plane = evaluatePlane( ...
    translated_sagittal_site_plane.normal, translated_sagittal_site_plane.center, ...
    data.points, data.labels, data.targetAtlas, atlas);

metrics = buildMetricsTable(actual_session, actual_sites, current_session_plane, ...
    current_site_plane, translated_sagittal_session_plane, ...
    translated_sagittal_site_plane, maximum_session_plane, maximum_site_plane, ...
    robust_session_plane, robust_site_plane, cfg);
audit = buildPointAudit(data, atlas, current_session_plane, maximum_session_plane, ...
    robust_session_plane, cfg);

writeOutputs(output_dir, metrics, audit, data, site_data, actual_session, ...
    actual_sites, current_session_plane, current_site_plane, ...
    translated_sagittal_session_plane, translated_sagittal_site_plane, ...
    maximum_session_plane, maximum_site_plane, robust_session_plane, ...
    robust_site_plane, cfg);

makeSinglePlaneFigure(structural, atlas, data, maximum_session_plane, cfg, ...
    sprintf('%s - highest-match oblique candidate', cfg.monkeyName), ...
    sprintf('%s_MaximumMatchObliqueSection', cfg.filePrefix), output_dir);
makeSinglePlaneFigure(structural, atlas, data, robust_session_plane, cfg, ...
    sprintf('%s - recommended robust oblique section', cfg.monkeyName), ...
    sprintf('%s_RecommendedRobustObliqueSection', cfg.filePrefix), output_dir);
makeComparisonFigure(structural, atlas, data, current_session_plane, ...
    robust_session_plane, cfg, output_dir);

results = struct();
results.outputDirectory = output_dir;
results.metrics = metrics;
results.pointAudit = audit;
results.maximumMatchPlane = maximum_session_plane;
results.recommendedPlane = robust_session_plane;
results.recommendedUniqueSitePlane = robust_site_plane;
results.currentSagittalPlane = current_session_plane;
results.translatedSagittalPlane = translated_sagittal_session_plane;
results.actualAtlasAgreement = actual_session;

fprintf('\n%s recommended robust plane\n', cfg.monkeyName);
fprintf('  normal [ML DV AP] = %s\n', mat2str(robust_session_plane.normal, 8));
fprintf('  center [i j k]    = %s\n', mat2str(robust_session_plane.center, 8));
fprintf('  MT                 = %d/%d (%.1f%%)\n', ...
    robust_session_plane.mtCorrect, robust_session_plane.mtTotal, ...
    100 * robust_session_plane.mtCorrect / robust_session_plane.mtTotal);
fprintf('  FST                = %d/%d (%.1f%%)\n', ...
    robust_session_plane.fstCorrect, robust_session_plane.fstTotal, ...
    100 * robust_session_plane.fstCorrect / robust_session_plane.fstTotal);
fprintf('  total              = %d/%d (%.1f%%)\n', ...
    robust_session_plane.totalCorrect, numel(data.labels), ...
    100 * robust_session_plane.totalCorrect / numel(data.labels));
fprintf('  mean/max distance  = %.3f / %.3f mm\n', ...
    robust_session_plane.meanDistance * cfg.voxelSizeMm, ...
    robust_session_plane.maxDistance * cfg.voxelSizeMm);
fprintf('  robustness distance mode = %s (%d/%d perturbations within %.3f mm)\n', ...
    robust_site_plane.robustDistanceConstraintMode, ...
    robust_site_plane.robustNeighborhoodWithinConstraintCount, ...
    robust_site_plane.robustNeighborhoodCount, cfg.maxProjectionDistanceMm);
fprintf('  perturbation worst distance/excess = %.3f / %.3f mm\n', ...
    robust_site_plane.robustNeighborhoodWorstMaxDistance * cfg.voxelSizeMm, ...
    robust_site_plane.robustNeighborhoodWorstDistanceExcess * cfg.voxelSizeMm);
fprintf('Outputs written to %s\n', output_dir);
end

function cfg = validateAnalysisConfig(cfg)
assert(isstruct(cfg) && isscalar(cfg), 'cfg must be a scalar struct.');
required = {'outputDirectory', 'monkeyName', 'filePrefix', 'workbookPath', ...
    'structuralPath', 'atlasPath', 'originVoxelZeroBased', ...
    'nativeFirstDimension', 'uprightReferencePlaneNormal', ...
    'mtAtlasLabel', 'fstAtlasLabel', ...
    'expectedSessionCount', 'expectedMtCount', 'expectedFstCount', ...
    'currentSagittalIndex', 'mtColor', 'fstColor', ...
    'maxProjectionDistanceMm', 'sliceSpacingVox', 'roiAlpha', ...
    'slabHalfThicknessMm', 'outputResolution', 'voxelSizeMm'};
missing = required(~isfield(cfg, required));
assert(isempty(missing), 'Missing optimizer configuration field(s): %s', ...
    strjoin(missing, ', '));

cfg.monkeyName = char(string(cfg.monkeyName));
cfg.filePrefix = char(string(cfg.filePrefix));
cfg.outputDirectory = char(string(cfg.outputDirectory));
if ~isfield(cfg, 'recordingHemisphere')
    cfg.recordingHemisphere = '';
end
cfg.recordingHemisphere = upper(char(string(cfg.recordingHemisphere)));
assert(any(strcmp(cfg.recordingHemisphere, {'', 'L', 'R'})), ...
    'recordingHemisphere must be empty, ''L'', or ''R''.');
cfg.uprightReferencePlaneNormal = ...
    double(cfg.uprightReferencePlaneNormal(:).');
assert(numel(cfg.originVoxelZeroBased) == 3, ...
    'originVoxelZeroBased must contain [ML DV AP].');
assert(numel(cfg.uprightReferencePlaneNormal) == 3 && ...
    norm(cfg.uprightReferencePlaneNormal) > 0, ...
    'uprightReferencePlaneNormal must be a nonzero [ML DV AP] vector.');
cfg.uprightReferencePlaneNormal = cfg.uprightReferencePlaneNormal / ...
    norm(cfg.uprightReferencePlaneNormal);
assert(cfg.expectedSessionCount == cfg.expectedMtCount + cfg.expectedFstCount, ...
    'Expected MT and FST counts do not sum to the expected session count.');
end

function data = loadRecordingData(cfg)
tb = readtable(cfg.workbookPath, 'VariableNamingRule', 'preserve');
[rows, inclusion_audit] = getWorkbookRowsFromUnitTableGof(tb, cfg.monkeyName);

n = numel(rows);
holes = nan(n, 2);
offsets = nan(n, 3);
guide = nan(n, 1);
depth = nan(n, 1);

hole_column = getTableColumn(tb, 'Hole');
offset_column = getTableColumn(tb, 'Offset');
guide_column = getTableColumn(tb, 'GuideTube');
depth_column = getTableColumn(tb, 'Depth');
roi_column = getTableColumn(tb, 'ROI');
date_column = getTableColumn(tb, 'Date');

for i = 1:n
    holes(i, :) = parseNumericVector(valueAtRow(hole_column, rows(i)));
    offsets(i, :) = parseNumericVector(valueAtRow(offset_column, rows(i)));
    guide(i) = parseScalar(valueAtRow(guide_column, rows(i)));
    depth(i) = parseScalar(valueAtRow(depth_column, rows(i)));
end

labels_all = upper(strip(normalizeTextColumn(roi_column)));
dates_all = normalizeDateColumn(date_column);
labels = labels_all(rows);
dates = dates_all(rows);
assert(n == cfg.expectedSessionCount && ...
    nnz(labels == "MT") == cfg.expectedMtCount && ...
    nnz(labels == "FST") == cfg.expectedFstCount, ...
    'Expected %d %s sessions (%d MT, %d FST); found %d (%d MT, %d FST).', ...
    cfg.expectedSessionCount, cfg.monkeyName, cfg.expectedMtCount, ...
    cfg.expectedFstCount, n, nnz(labels == "MT"), nnz(labels == "FST"));

grid_ml = nan(n, 1);
for i = 1:n
    grid_ml(i) = computeGridMlVoxel(holes(i, :), offsets(i, :), ...
        cfg.originVoxelZeroBased);
end

% Continuous, one-based subscripts in the reoriented load_nii arrays.
points = [cfg.nativeFirstDimension - grid_ml, ...
    cfg.originVoxelZeroBased(2) - 2 * (guide + depth) - 2 * offsets(:, 3) + 1, ...
    cfg.originVoxelZeroBased(3) - 2 * 0.8 * (29 - holes(:, 2)) + ...
        2 * offsets(:, 2) + 1];

target = nan(n, 1);
target(labels == "MT") = cfg.mtAtlasLabel;
target(labels == "FST") = cfg.fstAtlasLabel;

data = struct();
data.table = tb;
data.workbookRows = rows;
data.excelRows = rows + 1;
data.inclusionAudit = inclusion_audit;
data.dates = dates;
data.labels = labels;
data.targetAtlas = target;
data.holes = holes;
data.offsetsMm = offsets;
data.guideMm = guide;
data.depthMm = depth;
data.totalDepthMm = guide + depth;
data.points = points;
end

function [structural, atlas, voxel_size_mm, metadata] = loadVolumes(cfg)
struct_info = niftiinfo(cfg.structuralPath);
atlas_info = niftiinfo(cfg.atlasPath);
struct_spacing = double(struct_info.PixelDimensions(1:3));
atlas_spacing = double(atlas_info.PixelDimensions(1:3));
assert(all(abs(struct_spacing - atlas_spacing) < 1e-6), ...
    'Structural and atlas voxel spacing differ.');
assert(max(struct_spacing) - min(struct_spacing) < 1e-6, ...
    'This optimizer expects isotropic voxels; found %s mm.', mat2str(struct_spacing));
assert(isequal(struct_info.ImageSize(1:3), atlas_info.ImageSize(1:3)), ...
    'Structural and atlas NIfTI dimensions differ.');
assert(max(abs(struct_info.Transform.T - atlas_info.Transform.T), [], 'all') < 1e-6, ...
    'Structural and atlas NIfTI transforms differ.');

% The historical recording-location workflows use load_nii, which reorients
% these files by
% flipping raw NIfTI dimension 1. Apply that operation explicitly so results
% do not depend on whichever external NIfTI toolbox happens to be on path.
structural = flip(single(niftiread(struct_info)), 1);
atlas = flip(double(niftiread(atlas_info)), 1);
voxel_size_mm = mean(struct_spacing);
metadata.reader = 'MATLAB niftiread followed by flip(volume,1)';
metadata.rawTransform = struct_info.Transform.T;
metadata.rawImageSize = struct_info.ImageSize(1:3);
metadata.pixelDimensionsMm = struct_spacing;
metadata.structuralDescription = string(struct_info.Description);
metadata.atlasDescription = string(atlas_info.Description);
end

function validateInputs(data, structural, atlas, cfg)
assert(isequal(size(structural), size(atlas)), ...
    'Structural and atlas volumes must have identical dimensions.');
assert(size(structural, 1) == cfg.nativeFirstDimension, ...
    ['The configured ML mirror assumes a %d-voxel first dimension, but ' ...
    'the volume has %d.'], cfg.nativeFirstDimension, size(structural, 1));
assert(all(isfinite(data.points), 'all'), 'Recording coordinates contain NaN or Inf.');
assert(all(data.points >= 1, 'all') && ...
    all(data.points(:, 1) <= size(atlas, 1)) && ...
    all(data.points(:, 2) <= size(atlas, 2)) && ...
    all(data.points(:, 3) <= size(atlas, 3)), ...
    'At least one recording coordinate lies outside the atlas volume.');
assert(any(atlas(:) == cfg.mtAtlasLabel) && any(atlas(:) == cfg.fstAtlasLabel), ...
    'MT or FST atlas label is missing from the ROI volume.');
end

function site_data = collapseToUniqueSites(data, cfg)
rows = unique([round(data.points, 4), data.targetAtlas], 'rows');
site_data.points = rows(:, 1:3);
site_data.targetAtlas = rows(:, 4);
site_data.labels = strings(size(rows, 1), 1);
site_data.labels(site_data.targetAtlas == cfg.mtAtlasLabel) = "MT";
site_data.labels(site_data.targetAtlas == cfg.fstAtlasLabel) = "FST";

[unique_xyz, ~, xyz_group] = unique(round(data.points, 4), 'rows');
for i = 1:size(unique_xyz, 1)
    assert(isscalar(unique(data.labels(xyz_group == i))), ...
        'A unique coordinate has conflicting MT/FST workbook labels.');
end
site_data.uniqueCoordinateCount = size(unique_xyz, 1);
end

function evaluation = evaluateNativeLocations(points, labels, target, atlas)
sampled = sampleAtlasNearest(atlas, points);
correct = sampled == target;
evaluation = summarizeClassification(labels, correct);
evaluation.sampledLabels = sampled;
evaluation.projectedPoints = points;
evaluation.signedDistance = zeros(size(target));
evaluation.meanDistance = 0;
evaluation.maxDistance = 0;
evaluation.normal = [nan, nan, nan];
evaluation.center = [nan, nan, nan];
evaluation.tiltDeg = nan;
evaluation.azimuthDeg = nan;
evaluation.balancedAccuracy = 0.5 * (evaluation.mtCorrect / evaluation.mtTotal + ...
    evaluation.fstCorrect / evaluation.fstTotal);
evaluation.minClassAccuracy = min(evaluation.mtCorrect / evaluation.mtTotal, ...
    evaluation.fstCorrect / evaluation.fstTotal);
end

function [best, best_sagittal] = searchPlanes(points, labels, target, atlas, cfg)
mu = mean(points, 1);
max_distance_vox = cfg.maxProjectionDistanceMm / cfg.voxelSizeMm;

best_sagittal = emptyPlane();
sagittal_range = [floor(min(points(:, 1))), ceil(max(points(:, 1)))];
for plane_i = sagittal_range(1):0.05:sagittal_range(2)
    center = mu;
    center(1) = plane_i;
    candidate = evaluatePlane([1, 0, 0], center, points, labels, target, atlas);
    % This is a descriptive sagittal baseline, not an admissible oblique
    % candidate. It remains defined even when the monkey's ML span is wider
    % than twice the oblique-plane distance constraint (as it is for Jim).
    if isBetterExact(candidate, best_sagittal)
        best_sagittal = candidate;
    end
end
assert(isfinite(best_sagittal.balancedAccuracy), ...
    'No translated sagittal baseline was evaluated.');

best = emptyPlane();
for tilt_deg = 0:2:90
    if tilt_deg == 0
        azimuth_values = 0;
    else
        azimuth_values = 0:3:357;
    end
    tilt = deg2rad(tilt_deg);
    for azimuth_deg = azimuth_values
        azimuth = deg2rad(azimuth_deg);
        normal = [cos(tilt), sin(tilt) * cos(azimuth), ...
            sin(tilt) * sin(azimuth)];
        along = (points - mu) * normal.';
        lower_offset = max(along) - max_distance_vox;
        upper_offset = min(along) + max_distance_vox;
        if lower_offset > upper_offset
            continue
        end
        offsets = unique([lower_offset:0.25:upper_offset, upper_offset]);
        for offset = offsets
            center = mu + offset * normal;
            candidate = evaluatePlane(normal, center, points, labels, target, atlas);
            if isBetterExact(candidate, best)
                best = candidate;
            end
        end
    end
end

assert(isfinite(best.balancedAccuracy), ...
    ['No oblique plane satisfied the %.3f-mm maximum projection-distance ' ...
    'constraint.'], cfg.maxProjectionDistanceMm);
coarse = best;
coarse_offset = dot(coarse.center - mu, coarse.normal);
for tilt_deg = max(0, coarse.tiltDeg - 3):0.25:min(90, coarse.tiltDeg + 3)
    tilt = deg2rad(tilt_deg);
    for azimuth_deg = coarse.azimuthDeg - 4:0.25:coarse.azimuthDeg + 4
        azimuth = deg2rad(mod(azimuth_deg, 360));
        normal = [cos(tilt), sin(tilt) * cos(azimuth), ...
            sin(tilt) * sin(azimuth)];
        along = (points - mu) * normal.';
        lower_offset = max(along) - max_distance_vox;
        upper_offset = min(along) + max_distance_vox;
        if lower_offset > upper_offset
            continue
        end
        center_offset = min(max(coarse_offset, lower_offset), upper_offset);
        for offset = max(lower_offset, center_offset - 1):0.05: ...
                min(upper_offset, center_offset + 1)
            center = mu + offset * normal;
            candidate = evaluatePlane(normal, center, points, labels, target, atlas);
            if isBetterExact(candidate, best)
                best = candidate;
            end
        end
    end
end
end

function robust = selectRobustPlane(maximum, points, labels, target, atlas, cfg)
mu = mean(points, 1);
tilt0 = maximum.tiltDeg;
azimuth0 = maximum.azimuthDeg;
offset0 = dot(maximum.center - mu, maximum.normal);
max_distance_vox = cfg.maxProjectionDistanceMm / cfg.voxelSizeMm;
distance_tolerance_vox = 1e-9;
translation_perturbation_vox = 0.5 / cfg.voxelSizeMm;

strict_robust = initializeRobustPlane();
fallback_robust = initializeRobustPlane();

for center_tilt_delta = -2:0.25:2
    for center_azimuth_delta = -2:0.25:2
        for center_offset_delta = -1:0.25:1
            center_tilt = tilt0 + center_tilt_delta;
            center_azimuth = azimuth0 + center_azimuth_delta;
            center_offset = offset0 + center_offset_delta;
            center_normal = sphericalNormal(center_tilt, center_azimuth);
            center = mu + center_offset * center_normal;
            center_eval = evaluatePlane(center_normal, center, points, labels, target, atlas);
            if center_eval.maxDistance > max_distance_vox + distance_tolerance_vox
                continue
            end

            % The published/nominal center is distance-constrained above.
            % Perturbations are sensitivity samples: score every one and
            % record any distance-limit excursion rather than rejecting the
            % otherwise admissible nominal plane.
            min_class_values = nan(27, 1);
            balanced_values = nan(27, 1);
            total_values = nan(27, 1);
            max_distance_values = nan(27, 1);
            index = 0;
            for tilt_delta = [-0.5, 0, 0.5]
                for azimuth_delta = [-0.5, 0, 0.5]
                    perturbed_normal = sphericalNormal(center_tilt + tilt_delta, ...
                        center_azimuth + azimuth_delta);
                    for offset_delta = [-translation_perturbation_vox, 0, ...
                            translation_perturbation_vox]
                        perturbed_center = mu + (center_offset + offset_delta) * perturbed_normal;
                        ev = evaluatePlane(perturbed_normal, perturbed_center, ...
                            points, labels, target, atlas);
                        index = index + 1;
                        min_class_values(index) = ev.minClassAccuracy;
                        balanced_values(index) = ev.balancedAccuracy;
                        total_values(index) = ev.totalCorrect;
                        max_distance_values(index) = ev.maxDistance;
                    end
                end
            end

            base_key = [min(min_class_values), median(balanced_values), ...
                min(balanced_values), mean(total_values), ...
                center_eval.minClassAccuracy, center_eval.balancedAccuracy, ...
                center_eval.totalCorrect, -center_eval.meanDistance];
            within_distance = max_distance_values <= ...
                max_distance_vox + distance_tolerance_vox;
            fallback_key = [base_key, nnz(within_distance), ...
                -max(max_distance_values), -median(max_distance_values)];

            if ~isfinite(fallback_robust.robustWorstMinClassAccuracy)
                old_fallback_key = -inf(size(fallback_key));
            else
                old_fallback_key = fallback_robust.robustKey;
            end
            if lexicographicallyGreater(fallback_key, old_fallback_key)
                fallback_robust = attachRobustStatistics(center_eval, ...
                    fallback_key, min_class_values, balanced_values, ...
                    total_values, max_distance_values, max_distance_vox, ...
                    distance_tolerance_vox, 'nominal-plane-only');
            end

            if all(within_distance)
                if ~isfinite(strict_robust.robustWorstMinClassAccuracy)
                    old_strict_key = -inf(size(base_key));
                else
                    old_strict_key = strict_robust.robustKey;
                end
                if lexicographicallyGreater(base_key, old_strict_key)
                    strict_robust = attachRobustStatistics(center_eval, ...
                        base_key, min_class_values, balanced_values, ...
                        total_values, max_distance_values, max_distance_vox, ...
                        distance_tolerance_vox, 'entire-neighborhood');
                end
            end
        end
    end
end

if isfinite(strict_robust.robustWorstMinClassAccuracy)
    robust = strict_robust;
else
    assert(isfinite(fallback_robust.robustWorstMinClassAccuracy), ...
        'No nominal robust-plane candidate satisfied the distance constraint.');
    robust = fallback_robust;
    warning('MTFSTOblique:NominalOnlyRobustDistanceConstraint', ...
        ['No candidate kept every robustness perturbation inside the %.3f-mm ' ...
        'distance limit. The recommended nominal plane still satisfies the ' ...
        'limit; perturbed planes were used to measure label stability.'], ...
        cfg.maxProjectionDistanceMm);
end
end

function robust = initializeRobustPlane()
robust = emptyPlane();
robust.robustWorstMinClassAccuracy = -inf;
robust.robustMedianBalancedAccuracy = -inf;
end

function robust = attachRobustStatistics(center_eval, key, min_class_values, ...
        balanced_values, total_values, max_distance_values, ...
        max_distance_vox, distance_tolerance_vox, constraint_mode)
robust = center_eval;
robust.robustKey = key;
robust.robustWorstMinClassAccuracy = min(min_class_values);
robust.robustMedianBalancedAccuracy = median(balanced_values);
robust.robustWorstBalancedAccuracy = min(balanced_values);
robust.robustMeanTotalCorrect = mean(total_values);
robust.robustWorstTotalCorrect = min(total_values);
robust.robustNeighborhoodWorstMaxDistance = max(max_distance_values);
robust.robustNeighborhoodMedianMaxDistance = median(max_distance_values);
robust.robustNeighborhoodWithinConstraintCount = ...
    nnz(max_distance_values <= max_distance_vox + distance_tolerance_vox);
robust.robustNeighborhoodCount = numel(max_distance_values);
robust.robustNeighborhoodWithinConstraintFraction = ...
    robust.robustNeighborhoodWithinConstraintCount / ...
    robust.robustNeighborhoodCount;
robust.robustNeighborhoodWorstDistanceExcess = ...
    max(0, robust.robustNeighborhoodWorstMaxDistance - max_distance_vox);
robust.robustNeighborhoodDistanceConstraintSatisfied = ...
    robust.robustNeighborhoodWithinConstraintCount == ...
    robust.robustNeighborhoodCount;
robust.robustDistanceConstraintMode = constraint_mode;
end

function normal = sphericalNormal(tilt_deg, azimuth_deg)
tilt = deg2rad(tilt_deg);
azimuth = deg2rad(mod(azimuth_deg, 360));
normal = [cos(tilt), sin(tilt) * cos(azimuth), sin(tilt) * sin(azimuth)];
normal = normal / norm(normal);
end

function candidate = evaluatePlane(normal, center, points, labels, target, atlas)
normal = normal / norm(normal);
if normal(1) < 0
    normal = -normal;
end
signed_distance = (points - center) * normal.';
projected = points - signed_distance .* normal;
sampled = sampleAtlasNearest(atlas, projected);
correct = sampled == target;

candidate = summarizeClassification(labels, correct);
candidate.normal = normal;
candidate.center = center;
candidate.signedDistance = signed_distance;
candidate.projectedPoints = projected;
candidate.sampledLabels = sampled;
candidate.meanDistance = mean(abs(signed_distance));
candidate.maxDistance = max(abs(signed_distance));
candidate.tiltDeg = acosd(max(-1, min(1, normal(1))));
candidate.azimuthDeg = mod(atan2d(normal(3), normal(2)), 360);
candidate.balancedAccuracy = 0.5 * (candidate.mtCorrect / candidate.mtTotal + ...
    candidate.fstCorrect / candidate.fstTotal);
candidate.minClassAccuracy = min(candidate.mtCorrect / candidate.mtTotal, ...
    candidate.fstCorrect / candidate.fstTotal);
end

function sampled = sampleAtlasNearest(atlas, points)
indices = round(points);
valid = all(indices >= 1, 2) & indices(:, 1) <= size(atlas, 1) & ...
    indices(:, 2) <= size(atlas, 2) & indices(:, 3) <= size(atlas, 3);
sampled = zeros(size(points, 1), 1);
sampled(valid) = atlas(sub2ind(size(atlas), indices(valid, 1), ...
    indices(valid, 2), indices(valid, 3)));
end

function summary = summarizeClassification(labels, correct)
mt = labels == "MT";
fst = labels == "FST";
summary.mtCorrect = nnz(correct & mt);
summary.mtTotal = nnz(mt);
summary.fstCorrect = nnz(correct & fst);
summary.fstTotal = nnz(fst);
summary.totalCorrect = nnz(correct);
summary.total = numel(labels);
end

function candidate = emptyPlane()
candidate = struct('normal', [nan, nan, nan], 'center', [nan, nan, nan], ...
    'signedDistance', [], 'projectedPoints', [], 'sampledLabels', [], ...
    'meanDistance', inf, 'maxDistance', inf, 'tiltDeg', nan, ...
    'azimuthDeg', nan, 'mtCorrect', 0, 'mtTotal', 1, 'fstCorrect', 0, ...
    'fstTotal', 1, 'totalCorrect', 0, 'total', 1, ...
    'balancedAccuracy', -inf, 'minClassAccuracy', -inf);
end

function tf = isBetterExact(a, b)
key_a = [a.minClassAccuracy, a.balancedAccuracy, a.totalCorrect, ...
    -a.meanDistance, -a.maxDistance];
key_b = [b.minClassAccuracy, b.balancedAccuracy, b.totalCorrect, ...
    -b.meanDistance, -b.maxDistance];
tf = lexicographicallyGreater(key_a, key_b);
end

function tf = lexicographicallyGreater(a, b)
tf = false;
for i = 1:numel(a)
    if a(i) > b(i) + 1e-12
        tf = true;
        return
    elseif a(i) < b(i) - 1e-12
        return
    end
end
end

function metrics = buildMetricsTable(actual_session, actual_sites, ...
        current_session, current_sites, translated_session, translated_sites, ...
        maximum_session, maximum_sites, robust_session, robust_sites, cfg)
names = ["Native 3-D atlas sampling"; "Current sagittal projection"; ...
    "Best translated sagittal"; "Highest-match oblique candidate"; ...
    "Recommended robust oblique"];
session_values = {actual_session; current_session; translated_session; ...
    maximum_session; robust_session};
site_values = {actual_sites; current_sites; translated_sites; maximum_sites; robust_sites};

n = numel(names);
metrics = table(names, 'VariableNames', {'View'});
metrics.SessionMTCorrect = nan(n, 1);
metrics.SessionMTTotal = nan(n, 1);
metrics.SessionFSTCorrect = nan(n, 1);
metrics.SessionFSTTotal = nan(n, 1);
metrics.SessionTotalCorrect = nan(n, 1);
metrics.SessionTotal = nan(n, 1);
metrics.UniqueSiteMTCorrect = nan(n, 1);
metrics.UniqueSiteMTTotal = nan(n, 1);
metrics.UniqueSiteFSTCorrect = nan(n, 1);
metrics.UniqueSiteFSTTotal = nan(n, 1);
metrics.UniqueSiteTotalCorrect = nan(n, 1);
metrics.UniqueSiteTotal = nan(n, 1);
metrics.SessionBalancedAccuracy = nan(n, 1);
metrics.UniqueSiteBalancedAccuracy = nan(n, 1);
metrics.RobustWorstUniqueSiteClassAccuracy = nan(n, 1);
metrics.RobustMedianUniqueSiteBalancedAccuracy = nan(n, 1);
metrics.RobustNeighborhoodWithinDistanceCount = nan(n, 1);
metrics.RobustNeighborhoodTotalCount = nan(n, 1);
metrics.RobustNeighborhoodWithinDistanceFraction = nan(n, 1);
metrics.RobustNeighborhoodDistanceConstraintSatisfied = nan(n, 1);
metrics.RobustNeighborhoodMedianMaxDistanceMm = nan(n, 1);
metrics.RobustNeighborhoodWorstMaxDistanceMm = nan(n, 1);
metrics.RobustNeighborhoodWorstDistanceExcessMm = nan(n, 1);
metrics.RobustDistanceConstraintMode = strings(n, 1);
metrics.MeanProjectionDistanceMm = nan(n, 1);
metrics.MaxProjectionDistanceMm = nan(n, 1);
metrics.TiltFromSagittalDeg = nan(n, 1);
metrics.AzimuthAroundMLDeg = nan(n, 1);
metrics.NormalML = nan(n, 1);
metrics.NormalDV = nan(n, 1);
metrics.NormalAP = nan(n, 1);
metrics.CenterI = nan(n, 1);
metrics.CenterJ = nan(n, 1);
metrics.CenterK = nan(n, 1);

for i = 1:n
    session = session_values{i};
    sites = site_values{i};
    metrics.SessionMTCorrect(i) = session.mtCorrect;
    metrics.SessionMTTotal(i) = session.mtTotal;
    metrics.SessionFSTCorrect(i) = session.fstCorrect;
    metrics.SessionFSTTotal(i) = session.fstTotal;
    metrics.SessionTotalCorrect(i) = session.totalCorrect;
    metrics.SessionTotal(i) = session.total;
    metrics.UniqueSiteMTCorrect(i) = sites.mtCorrect;
    metrics.UniqueSiteMTTotal(i) = sites.mtTotal;
    metrics.UniqueSiteFSTCorrect(i) = sites.fstCorrect;
    metrics.UniqueSiteFSTTotal(i) = sites.fstTotal;
    metrics.UniqueSiteTotalCorrect(i) = sites.totalCorrect;
    metrics.UniqueSiteTotal(i) = sites.total;
    metrics.SessionBalancedAccuracy(i) = session.balancedAccuracy;
    metrics.UniqueSiteBalancedAccuracy(i) = sites.balancedAccuracy;
    if i > 1
        metrics.MeanProjectionDistanceMm(i) = session.meanDistance * cfg.voxelSizeMm;
        metrics.MaxProjectionDistanceMm(i) = session.maxDistance * cfg.voxelSizeMm;
        metrics.TiltFromSagittalDeg(i) = session.tiltDeg;
        metrics.AzimuthAroundMLDeg(i) = session.azimuthDeg;
        metrics.NormalML(i) = session.normal(1);
        metrics.NormalDV(i) = session.normal(2);
        metrics.NormalAP(i) = session.normal(3);
        metrics.CenterI(i) = session.center(1);
        metrics.CenterJ(i) = session.center(2);
        metrics.CenterK(i) = session.center(3);
    end
end
metrics.RobustWorstUniqueSiteClassAccuracy(end) = ...
    robust_sites.robustWorstMinClassAccuracy;
metrics.RobustMedianUniqueSiteBalancedAccuracy(end) = ...
    robust_sites.robustMedianBalancedAccuracy;
metrics.RobustNeighborhoodWithinDistanceCount(end) = ...
    robust_sites.robustNeighborhoodWithinConstraintCount;
metrics.RobustNeighborhoodTotalCount(end) = ...
    robust_sites.robustNeighborhoodCount;
metrics.RobustNeighborhoodWithinDistanceFraction(end) = ...
    robust_sites.robustNeighborhoodWithinConstraintFraction;
metrics.RobustNeighborhoodDistanceConstraintSatisfied(end) = double( ...
    robust_sites.robustNeighborhoodDistanceConstraintSatisfied);
metrics.RobustNeighborhoodMedianMaxDistanceMm(end) = ...
    robust_sites.robustNeighborhoodMedianMaxDistance * cfg.voxelSizeMm;
metrics.RobustNeighborhoodWorstMaxDistanceMm(end) = ...
    robust_sites.robustNeighborhoodWorstMaxDistance * cfg.voxelSizeMm;
metrics.RobustNeighborhoodWorstDistanceExcessMm(end) = ...
    robust_sites.robustNeighborhoodWorstDistanceExcess * cfg.voxelSizeMm;
metrics.RobustDistanceConstraintMode(end) = ...
    string(robust_sites.robustDistanceConstraintMode);
end

function audit = buildPointAudit(data, atlas, current, maximum, robust, cfg)
actual_labels = sampleAtlasNearest(atlas, data.points);
[basis_u, basis_v] = planeBasis(robust.normal, ...
    cfg.uprightReferencePlaneNormal);
relative = data.points - robust.center;
u_mm = (relative * basis_u.') * cfg.voxelSizeMm;
v_mm = (relative * basis_v.') * cfg.voxelSizeMm;

[~, ~, site_group] = unique(round(data.points, 4), 'rows');
multiplicity = accumarray(site_group, 1);

audit = table();
audit.WorkbookTableRow = data.workbookRows;
audit.ExcelRow = data.excelRows;
audit.Date = data.dates;
audit.AssignedROI = data.labels;
audit.HoleX = data.holes(:, 1);
audit.HoleY = data.holes(:, 2);
audit.GuideTubeMm = data.guideMm;
audit.DepthMm = data.depthMm;
audit.TotalDepthMm = data.totalDepthMm;
audit.OffsetMLMm = data.offsetsMm(:, 1);
audit.OffsetAPMm = data.offsetsMm(:, 2);
audit.OffsetDVMm = data.offsetsMm(:, 3);
audit.NativeI = data.points(:, 1);
audit.NativeJ = data.points(:, 2);
audit.NativeK = data.points(:, 3);
audit.TargetAtlasLabel = data.targetAtlas;
audit.NativeAtlasLabel = actual_labels;
audit.NativeCorrect = actual_labels == data.targetAtlas;
audit.CurrentSagittalAtlasLabel = current.sampledLabels;
audit.CurrentSagittalCorrect = current.sampledLabels == data.targetAtlas;
audit.MaximumMatchAtlasLabel = maximum.sampledLabels;
audit.MaximumMatchCorrect = maximum.sampledLabels == data.targetAtlas;
audit.MaximumProjectedI = maximum.projectedPoints(:, 1);
audit.MaximumProjectedJ = maximum.projectedPoints(:, 2);
audit.MaximumProjectedK = maximum.projectedPoints(:, 3);
audit.RecommendedAtlasLabel = robust.sampledLabels;
audit.RecommendedCorrect = robust.sampledLabels == data.targetAtlas;
audit.RecommendedProjectedI = robust.projectedPoints(:, 1);
audit.RecommendedProjectedJ = robust.projectedPoints(:, 2);
audit.RecommendedProjectedK = robust.projectedPoints(:, 3);
audit.RecommendedUmm = u_mm;
audit.RecommendedVmm = v_mm;
audit.RecommendedSignedDistanceMm = robust.signedDistance * cfg.voxelSizeMm;
audit.RecommendedAbsoluteDistanceMm = abs(robust.signedDistance) * cfg.voxelSizeMm;
audit.WithinOneMmSlab = abs(robust.signedDistance) * cfg.voxelSizeMm <= ...
    cfg.slabHalfThicknessMm;
audit.SiteMultiplicity = multiplicity(site_group);
end

function writeOutputs(output_dir, metrics, audit, data, site_data, ...
        actual_session, actual_sites, current_session, current_sites, ...
        translated_session, translated_sites, maximum_session, maximum_sites, ...
        robust_session, robust_sites, cfg)
writetable(metrics, fullfile(output_dir, ...
    sprintf('%s_ObliquePlaneMetrics.csv', cfg.filePrefix)));
writetable(audit, fullfile(output_dir, ...
    sprintf('%s_ObliquePointAudit.csv', cfg.filePrefix)));
save(fullfile(output_dir, sprintf('%s_ObliqueResults.mat', cfg.filePrefix)), ...
    'metrics', 'audit', ...
    'data', 'site_data', 'actual_session', 'actual_sites', ...
    'current_session', 'current_sites', 'translated_session', ...
    'translated_sites', 'maximum_session', 'maximum_sites', ...
    'robust_session', 'robust_sites', 'cfg');

summary_path = fullfile(output_dir, ...
    sprintf('%s_ObliqueSummary.txt', cfg.filePrefix));
fid = fopen(summary_path, 'w');
assert(fid >= 0, 'Could not open summary file for writing: %s', summary_path);
cleanup_file = onCleanup(@() fclose(fid));
fprintf(fid, '%s MT/FST oblique-section optimization\n', cfg.monkeyName);
fprintf(fid, 'Generated: %s\n\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
fprintf(fid, 'Volume reader: %s\n', cfg.volumeMetadata.reader);
fprintf(fid, 'Raw NIfTI transform: %s\n\n', ...
    mat2str(cfg.volumeMetadata.rawTransform, 8));
fprintf(fid, 'Upright reference-plane normal [ML DV AP]: %s\n\n', ...
    mat2str(cfg.uprightReferencePlaneNormal, 8));
fprintf(fid, 'Important interpretation\n');
fprintf(fid, ['The oblique view was optimized using the MT/FST workbook labels. ' ...
    'Use it as a label-optimized visualization, not independent anatomical ' ...
    'validation of those labels. The trace of the MRI native midsagittal ' ...
    'plane is vertical in every rendered panel (dorsal up, ventral down).\n\n']);
fprintf(fid, 'Current sagittal projection (array i = %.0f)\n', cfg.currentSagittalIndex);
fprintf(fid, '  MT %d/%d; FST %d/%d; total %d/%d\n\n', ...
    current_session.mtCorrect, current_session.mtTotal, ...
    current_session.fstCorrect, current_session.fstTotal, ...
    current_session.totalCorrect, current_session.total);
fprintf(fid, 'Native 3-D atlas sampling\n');
fprintf(fid, '  MT %d/%d; FST %d/%d; total %d/%d\n\n', ...
    actual_session.mtCorrect, actual_session.mtTotal, ...
    actual_session.fstCorrect, actual_session.fstTotal, ...
    actual_session.totalCorrect, actual_session.total);
fprintf(fid, 'Highest-match oblique candidate (deterministic grid search)\n');
printPlaneSummary(fid, maximum_session, cfg);
fprintf(fid, '\nRecommended robust oblique plane\n');
printPlaneSummary(fid, robust_session, cfg);
fprintf(fid, '  robust worst unique-site class accuracy = %.1f%%\n', ...
    100 * robust_sites.robustWorstMinClassAccuracy);
fprintf(fid, '  robust median unique-site balanced accuracy = %.1f%%\n', ...
    100 * robust_sites.robustMedianBalancedAccuracy);
fprintf(fid, '  robustness distance mode = %s\n', ...
    robust_sites.robustDistanceConstraintMode);
fprintf(fid, '  perturbations within %.3f-mm distance limit = %d/%d\n', ...
    cfg.maxProjectionDistanceMm, ...
    robust_sites.robustNeighborhoodWithinConstraintCount, ...
    robust_sites.robustNeighborhoodCount);
fprintf(fid, '  perturbation median/worst max distance = %.3f / %.3f mm\n', ...
    robust_sites.robustNeighborhoodMedianMaxDistance * cfg.voxelSizeMm, ...
    robust_sites.robustNeighborhoodWorstMaxDistance * cfg.voxelSizeMm);
fprintf(fid, '  perturbation worst distance excess = %.3f mm\n', ...
    robust_sites.robustNeighborhoodWorstDistanceExcess * cfg.voxelSizeMm);
fprintf(fid, ['  The maximum projection-distance limit is a hard constraint ' ...
    'on the reported nominal plane. Perturbed planes are sensitivity ' ...
    'samples; distance-limit coverage and excess are reported above.\n']);
fprintf(fid, '\nUnique coordinate-label sites: %d (%d MT, %d FST)\n', ...
    site_data.uniqueCoordinateCount, nnz(site_data.labels == "MT"), ...
    nnz(site_data.labels == "FST"));
fprintf(fid, ['Figures plot all %d sessions without jitter; repeated ' ...
    'coordinates therefore overplot. Optimization weights each of the %d ' ...
    'unique coordinate-label sites once.\n'], numel(data.labels), ...
    site_data.uniqueCoordinateCount);
end

function printPlaneSummary(fid, plane, cfg)
fprintf(fid, '  normal [ML DV AP] = %s\n', mat2str(plane.normal, 8));
fprintf(fid, '  center [i j k]    = %s\n', mat2str(plane.center, 8));
fprintf(fid, '  tilt/azimuth      = %.3f / %.3f degrees\n', ...
    plane.tiltDeg, plane.azimuthDeg);
fprintf(fid, '  MT %d/%d; FST %d/%d; total %d/%d\n', ...
    plane.mtCorrect, plane.mtTotal, plane.fstCorrect, plane.fstTotal, ...
    plane.totalCorrect, plane.total);
fprintf(fid, '  mean/max |distance| = %.3f / %.3f mm\n', ...
    plane.meanDistance * cfg.voxelSizeMm, plane.maxDistance * cfg.voxelSizeMm);
[basis_u, basis_v] = planeBasis(plane.normal, ...
    cfg.uprightReferencePlaneNormal);
fprintf(fid, '  display horizontal [ML DV AP] = %s\n', mat2str(basis_u, 8));
fprintf(fid, '  display vertical   [ML DV AP] = %s\n', mat2str(basis_v, 8));
end

function makeSinglePlaneFigure(structural, atlas, data, plane, cfg, ...
        figure_title, file_stem, output_dir)
fig = figure('Color', 'w', 'Visible', 'off', 'Units', 'inches', ...
    'Position', [1, 1, 10.4, 5.6]);
cleanup_fig = onCleanup(@() close(fig));
ax = axes(fig, 'Position', [0.04, 0.16, 0.64, 0.77]);
renderPlaneAxes(ax, structural, atlas, data, plane, cfg, figure_title, true);
locator_ax = axes(fig, 'Position', [0.72, 0.28, 0.25, 0.50]);
renderHorizontalLocator(locator_ax, structural, plane, data.points, cfg);
exportFigureSet(fig, output_dir, file_stem, cfg.outputResolution);
end

function renderHorizontalLocator(ax, structural, plane, recording_points, cfg)
% Show the horizontal MRI nearest the oblique-plane center and draw the
% part of the exact plane-intersection line in the recording hemisphere.
j_index = min(max(round(plane.center(2)), 1), size(structural, 2));
horizontal_slice = squeeze(structural(:, j_index, :)).'; % rows AP, cols ML
brain_pixels = horizontal_slice > 0;
[brain_rows, brain_cols] = find(brain_pixels);
assert(~isempty(brain_rows), ...
    'Horizontal locator slice %d contains no brain voxels.', j_index);

padding_vox = ceil(4 / cfg.voxelSizeMm);
row_min = max(1, min(brain_rows) - padding_vox);
row_max = min(size(horizontal_slice, 1), max(brain_rows) + padding_vox);
col_min = max(1, min(brain_cols) - padding_vox);
col_max = min(size(horizontal_slice, 2), max(brain_cols) + padding_vox);
horizontal_slice = horizontal_slice(row_min:row_max, col_min:col_max);

i_values = col_min:col_max;
k_values = row_min:row_max;
x_mm = (i_values - plane.center(1)) * cfg.voxelSizeMm;
y_mm = (k_values - plane.center(3)) * cfg.voxelSizeMm;
display_slice = normalizeStructuralSlice(horizontal_slice, cfg.structuralWindow);
imagesc(ax, x_mm, y_mm, display_slice);
colormap(ax, gray(256));
set(ax, 'YDir', 'normal', 'XDir', 'normal');
axis(ax, 'image');
hold(ax, 'on');

% Coordinates are continuous one-based indices, whereas the configured
% grid origin is zero-based. Infer which index side contains the actual
% recording sites and never draw the locator line in the other hemisphere.
midline_i = cfg.originVoxelZeroBased(1) + 1;
recording_side_sign = sign(median(recording_points(:, 1)) - midline_i);
assert(recording_side_sign ~= 0, ...
    'Cannot determine the recording hemisphere from the recording points.');

% When the anatomical hemisphere is known, use a neurological display:
% anatomical left is on the left of the page and right is on the right.
if ~isempty(cfg.recordingHemisphere)
    recording_is_low_index = recording_side_sign < 0;
    low_index_is_left = ...
        (cfg.recordingHemisphere == 'L' && recording_is_low_index) || ...
        (cfg.recordingHemisphere == 'R' && ~recording_is_low_index);
    if ~low_index_is_left
        set(ax, 'XDir', 'reverse');
    end
end

normal = plane.normal / norm(plane.normal);
horizontal_denominator = normal(1)^2 + normal(3)^2;
line_color = [0.00, 0.42, 0.82];
if horizontal_denominator > 1e-10
    delta_j = j_index - plane.center(2);
    line_i0 = plane.center(1) - ...
        normal(2) * delta_j * normal(1) / horizontal_denominator;
    line_k0 = plane.center(3) - ...
        normal(2) * delta_j * normal(3) / horizontal_denominator;
    line_direction = [normal(3), -normal(1)]; % [i, k]
    line_extent = 2 * max(size(structural));
    parameter = linspace(-line_extent, line_extent, 2001);
    line_i = line_i0 + parameter * line_direction(1);
    line_k = line_k0 + parameter * line_direction(2);
    visible = line_i >= col_min & line_i <= col_max & ...
        line_k >= row_min & line_k <= row_max & ...
        recording_side_sign * (line_i - midline_i) >= 0;
    plot(ax, (line_i(visible) - plane.center(1)) * cfg.voxelSizeMm, ...
        (line_k(visible) - plane.center(3)) * cfg.voxelSizeMm, ...
        '-', 'Color', line_color, 'LineWidth', 2.2);
else
    text(ax, mean(x_mm), mean(y_mm), ...
        'Oblique plane is parallel to this view', ...
        'HorizontalAlignment', 'center', 'FontName', 'Arial', ...
        'FontSize', 7, 'Color', line_color, 'BackgroundColor', 'w');
end

text(ax, 0.5, 0.98, 'A', 'Units', 'normalized', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
    'FontName', 'Arial', 'FontSize', 8, 'FontWeight', 'bold', ...
    'Color', [0.08, 0.08, 0.08], 'BackgroundColor', 'w', 'Margin', 1);
text(ax, 0.5, 0.02, 'P', 'Units', 'normalized', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
    'FontName', 'Arial', 'FontSize', 8, 'FontWeight', 'bold', ...
    'Color', [0.08, 0.08, 0.08], 'BackgroundColor', 'w', 'Margin', 1);
if ~isempty(cfg.recordingHemisphere)
    text(ax, 0.02, 0.5, 'L', 'Units', 'normalized', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
        'FontName', 'Arial', 'FontSize', 8, 'FontWeight', 'bold', ...
        'Color', [0.08, 0.08, 0.08], 'BackgroundColor', 'w', 'Margin', 1);
    text(ax, 0.98, 0.5, 'R', 'Units', 'normalized', ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
        'FontName', 'Arial', 'FontSize', 8, 'FontWeight', 'bold', ...
        'Color', [0.08, 0.08, 0.08], 'BackgroundColor', 'w', 'Margin', 1);
end
title(ax, {'Horizontal locator'; ...
    sprintf('DV index %d; blue = section in recording hemisphere', j_index)}, ...
    'FontName', 'Arial', 'FontSize', 8, 'FontWeight', 'normal', ...
    'Interpreter', 'none');
axis(ax, 'off');
hold(ax, 'off');
end

function makeComparisonFigure(structural, atlas, data, current, robust, cfg, output_dir)
fig = figure('Color', 'w', 'Visible', 'off', 'Units', 'inches', ...
    'Position', [1, 1, 12.2, 5.3]);
cleanup_fig = onCleanup(@() close(fig));
layout = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile(layout);
renderPlaneAxes(ax1, structural, atlas, data, current, cfg, ...
    'A  Current sagittal projection', false);
ax2 = nexttile(layout);
renderPlaneAxes(ax2, structural, atlas, data, robust, cfg, ...
    'B  Recommended robust oblique projection', false);
exportFigureSet(fig, output_dir, ...
    sprintf('%s_CurrentVsRecommendedOblique', cfg.filePrefix), ...
    cfg.outputResolution);
end

function renderPlaneAxes(ax, structural, atlas, data, plane, cfg, title_text, show_legend)
[slice, roi_slice, u_mm, v_mm, point_u_mm, point_v_mm, basis_u, basis_v] = ...
    reslicePlane(structural, atlas, plane, data.points, cfg);
% Classification uses the exact projected 3-D coordinates stored in
% plane.sampledLabels. Do not resample the already rasterized atlas image at
% marker positions: for categorical labels, a marker within a fraction of a
% voxel of a boundary can legitimately differ from its nearest display pixel.

display_slice = normalizeStructuralSlice(slice, cfg.structuralWindow);
imagesc(ax, u_mm, v_mm, display_slice);
colormap(ax, gray(256));
set(ax, 'YDir', 'reverse');
axis(ax, 'image');
hold(ax, 'on');

mt_mask = roi_slice == cfg.mtAtlasLabel;
fst_mask = roi_slice == cfg.fstAtlasLabel;
mt_display_mask = imgaussfilt(double(mt_mask), 0.8, 'Padding', 'replicate');
fst_display_mask = imgaussfilt(double(fst_mask), 0.8, 'Padding', 'replicate');
overlayMask(ax, u_mm, v_mm, mt_display_mask, cfg.mtColor, cfg.roiAlpha);
overlayMask(ax, u_mm, v_mm, fst_display_mask, cfg.fstColor, cfg.roiAlpha);
if any(mt_mask, 'all')
    contour(ax, u_mm, v_mm, mt_display_mask, [0.5, 0.5], ...
        'Color', cfg.mtColor * 0.72, 'LineWidth', 1.1);
end
if any(fst_mask, 'all')
    contour(ax, u_mm, v_mm, fst_display_mask, [0.5, 0.5], ...
        'Color', cfg.fstColor * 0.72, 'LineWidth', 1.1);
end

plotRecordingGroup(ax, point_u_mm, point_v_mm, data.labels == "MT", ...
    cfg.mtColor, 'o');
plotRecordingGroup(ax, point_u_mm, point_v_mm, data.labels == "FST", ...
    cfg.fstColor, 'd');

title_lines = {title_text; sprintf(['MT %d/%d in MT; FST %d/%d in FST | ' ...
    'mean/max plane distance %.2f/%.2f mm'], plane.mtCorrect, plane.mtTotal, ...
    plane.fstCorrect, plane.fstTotal, plane.meanDistance * cfg.voxelSizeMm, ...
    plane.maxDistance * cfg.voxelSizeMm)};
title(ax, title_lines, 'FontName', 'Arial', ...
    'FontWeight', 'normal', 'FontSize', 10, 'Interpreter', 'none');

addScaleBar(ax, 5);
addOrientationLabels(ax, basis_u, basis_v);
axis(ax, 'off');

if show_legend
    roi_mt = patch(ax, nan, nan, cfg.mtColor, 'FaceAlpha', cfg.roiAlpha, ...
        'EdgeColor', cfg.mtColor * 0.72);
    roi_fst = patch(ax, nan, nan, cfg.fstColor, 'FaceAlpha', cfg.roiAlpha, ...
        'EdgeColor', cfg.fstColor * 0.72);
    dot_mt = scatter(ax, nan, nan, 32, cfg.mtColor, 'o', 'filled', ...
        'MarkerEdgeColor', cfg.mtColor * 0.45);
    dot_fst = scatter(ax, nan, nan, 32, cfg.fstColor, 'd', 'filled', ...
        'MarkerEdgeColor', cfg.fstColor * 0.45);
    legend(ax, [roi_mt, roi_fst, dot_mt, dot_fst], ...
        {'MT atlas', 'FST atlas', 'MT recording', 'FST recording'}, ...
        'Location', 'southoutside', 'Orientation', 'horizontal', ...
        'NumColumns', 2, 'Box', 'off', 'FontName', 'Arial', ...
        'FontSize', 7, 'AutoUpdate', 'off');
end
hold(ax, 'off');
end

function [slice, roi_slice, u_mm, v_mm, point_u_mm, point_v_mm, basis_u, basis_v] = ...
        reslicePlane(structural, atlas, plane, points, cfg)
[basis_u, basis_v] = planeBasis(plane.normal, ...
    cfg.uprightReferencePlaneNormal);

brain = structural > 0;
i_range = find(squeeze(any(any(brain, 2), 3)));
j_range = find(squeeze(any(any(brain, 1), 3)));
k_range = find(squeeze(any(any(brain, 1), 2)));
bounds = [min(i_range), max(i_range); min(j_range), max(j_range); ...
    min(k_range), max(k_range)];
corners = allCorners(bounds);
relative_corners = corners - plane.center;
corner_u = relative_corners * basis_u.';
corner_v = relative_corners * basis_v.';

relative_points = points - plane.center;
point_u = relative_points * basis_u.';
point_v = relative_points * basis_v.';

padding_vox = 4 / cfg.voxelSizeMm;
padding_pixels = ceil(padding_vox / cfg.sliceSpacingVox);
u_values = floor(min([corner_u; point_u]) - padding_vox):cfg.sliceSpacingVox: ...
    ceil(max([corner_u; point_u]) + padding_vox);
v_values = floor(min([corner_v; point_v]) - padding_vox):cfg.sliceSpacingVox: ...
    ceil(max([corner_v; point_v]) + padding_vox);
[u_grid, v_grid] = meshgrid(u_values, v_values);

query_i = plane.center(1) + u_grid * basis_u(1) + v_grid * basis_v(1);
query_j = plane.center(2) + u_grid * basis_u(2) + v_grid * basis_v(2);
query_k = plane.center(3) + u_grid * basis_u(3) + v_grid * basis_v(3);
slice = interpn(structural, query_i, query_j, query_k, 'linear', 0);
roi_slice = interpn(atlas, query_i, query_j, query_k, 'nearest', 0);

% Crop the safe corner-based reslice to the actual brain plus all points.
brain_pixels = slice > 0;
[brain_rows, brain_cols] = find(brain_pixels);
point_cols = interp1(u_values, 1:numel(u_values), point_u, 'nearest', 'extrap');
point_rows = interp1(v_values, 1:numel(v_values), point_v, 'nearest', 'extrap');
row_min = max(1, floor(min([brain_rows; point_rows]) - padding_pixels));
row_max = min(size(slice, 1), ceil(max([brain_rows; point_rows]) + padding_pixels));
col_min = max(1, floor(min([brain_cols; point_cols]) - padding_pixels));
col_max = min(size(slice, 2), ceil(max([brain_cols; point_cols]) + padding_pixels));
slice = slice(row_min:row_max, col_min:col_max);
roi_slice = roi_slice(row_min:row_max, col_min:col_max);
u_values = u_values(col_min:col_max);
v_values = v_values(row_min:row_max);

u_mm = u_values * cfg.voxelSizeMm;
v_mm = v_values * cfg.voxelSizeMm;
point_u_mm = point_u * cfg.voxelSizeMm;
point_v_mm = point_v * cfg.voxelSizeMm;
end

function [basis_u, basis_v] = planeBasis(normal, upright_reference_normal)
normal = normal / norm(normal);
ap_axis = [0, 0, 1];
upright_reference_normal = upright_reference_normal / ...
    norm(upright_reference_normal);
ventral_axis = [0, -1, 0];

% Make the trace of the native midsagittal plane vertical. This is the
% intersection of the configured MRI reference plane (the native sagittal
% plane for Clay and Jim) with the rendered oblique plane. It follows the
% anatomical midline instead of merely projecting the array DV vector.
basis_v = cross(upright_reference_normal, normal);
if norm(basis_v) < 1e-6
    % The rendered plane is itself sagittal, so use its native ventral axis.
    basis_v = ventral_axis - dot(ventral_axis, normal) * normal;
end
basis_v = basis_v / norm(basis_v);
if dot(basis_v, ventral_axis) < 0
    basis_v = -basis_v;
end

basis_u = cross(basis_v, normal);
basis_u = basis_u / norm(basis_u);
% Keep anterior to the right without changing the midsagittal trace.
if dot(basis_u, ap_axis) < 0
    basis_u = -basis_u;
end
end

function corners = allCorners(bounds)
[i, j, k] = ndgrid(bounds(1, :), bounds(2, :), bounds(3, :));
corners = [i(:), j(:), k(:)];
end

function window = computeStructuralWindow(structural)
positive = sort(structural(structural > 0));
assert(~isempty(positive), 'Structural MRI has no positive voxels.');
window = double([positive(max(1, round(0.01 * numel(positive)))), ...
    positive(max(1, round(0.995 * numel(positive))))]);
assert(window(2) > window(1), 'Structural MRI intensity window is degenerate.');
end

function display_slice = normalizeStructuralSlice(slice, window)
low = window(1);
high = window(2);
display_slice = (double(slice) - low) / (high - low);
display_slice = min(max(display_slice, 0), 1);
display_slice(slice <= 0) = 1;
end

function overlayMask(ax, x, y, mask, color, alpha_value)
rgb = zeros([size(mask), 3]);
for channel = 1:3
    rgb(:, :, channel) = color(channel);
end
handle = image(ax, [x(1), x(end)], [y(1), y(end)], rgb);
set(handle, 'AlphaData', alpha_value * double(mask));
end

function plotRecordingGroup(ax, u, v, group, color, marker)
if any(group)
    scatter(ax, u(group), v(group), 28, color, marker, 'filled', ...
        'MarkerEdgeColor', color * 0.42, 'LineWidth', 0.55, ...
        'MarkerFaceAlpha', 0.88, 'MarkerEdgeAlpha', 0.95);
end
end

function addScaleBar(ax, length_mm)
limits_x = xlim(ax);
limits_y = ylim(ax);
x0 = limits_x(1) + 0.055 * diff(limits_x);
y0 = limits_y(1) + 0.06 * diff(limits_y);
plot(ax, [x0, x0 + length_mm], [y0, y0], 'k-', 'LineWidth', 2.2);
text(ax, x0 + length_mm / 2, y0 + 0.018 * diff(limits_y), ...
    sprintf('%g mm', length_mm), 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', 'FontName', 'Arial', 'FontSize', 7, ...
    'Color', 'k');
end

function addOrientationLabels(ax, basis_u, basis_v)
limits_x = xlim(ax);
limits_y = ylim(ax);
range_x = diff(limits_x);
range_y = diff(limits_y);
mid_x = mean(limits_x);
mid_y = mean(limits_y);
ap_component = dot(basis_u, [0, 0, 1]);
ventral_component = dot(basis_v, [0, -1, 0]);
if ap_component >= 0
    left_label = 'P';
    right_label = 'A';
else
    left_label = 'A';
    right_label = 'P';
end
if ventral_component >= 0
    top_label = 'D';
    bottom_label = 'V';
else
    top_label = 'V';
    bottom_label = 'D';
end
style = {'FontName', 'Arial', 'FontSize', 8, 'FontWeight', 'bold', ...
    'Color', [0.08, 0.08, 0.08], 'BackgroundColor', 'w', 'Margin', 1};
% At a degenerate orientation an axis can have no AP or DV component; do
% not print an anatomical label whose direction is then undefined.
if abs(ap_component) >= 1e-6
    text(ax, limits_x(1) + 0.012 * range_x, mid_y, left_label, ...
        'HorizontalAlignment', 'left', style{:});
    text(ax, limits_x(2) - 0.012 * range_x, mid_y, right_label, ...
        'HorizontalAlignment', 'right', style{:});
end
if abs(ventral_component) >= 1e-6
    text(ax, mid_x, limits_y(1) + 0.012 * range_y, top_label, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', style{:});
    text(ax, mid_x, limits_y(2) - 0.012 * range_y, bottom_label, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', style{:});
end
end

function exportFigureSet(fig, output_dir, stem, resolution)
png_path = fullfile(output_dir, [stem, '.png']);
pdf_path = fullfile(output_dir, [stem, '.pdf']);
fig_path = fullfile(output_dir, [stem, '.fig']);
exportgraphics(fig, png_path, 'Resolution', resolution);
exportgraphics(fig, pdf_path, 'ContentType', 'vector');
savefig(fig, fig_path);
end

function ml_voxel = computeGridMlVoxel(hole, offset_mm, origin)
if mod(hole(2), 2) == 1
    edge_offset = 1.4;
else
    edge_offset = 1.8;
end
if hole(1) > 0
    ml_voxel = origin(1) - ((hole(1) - 1) * 0.8 + edge_offset) * 2;
else
    ml_voxel = origin(1) + ((abs(hole(1)) - 1) * 0.8 + edge_offset) * 2;
end
ml_voxel = ml_voxel + 2 * offset_mm(1);
end

function column = getTableColumn(tb, requested_name)
names = tb.Properties.VariableNames;
normalized_names = regexprep(lower(string(names)), '[^a-z0-9]', '');
normalized_request = regexprep(lower(string(requested_name)), '[^a-z0-9]', '');
index = find(normalized_names == normalized_request, 1, 'first');
assert(~isempty(index), 'Workbook column "%s" was not found.', requested_name);
column = tb.(names{index});
end

function value = valueAtRow(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
end

function values = parseNumericVector(raw)
if isnumeric(raw)
    values = double(raw(:).');
else
    tokens = regexp(char(strtrim(string(raw))), ...
        '[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?', 'match');
    values = str2double(tokens);
end
end

function value = parseScalar(raw)
if isnumeric(raw)
    value = double(raw(1));
else
    value = str2double(string(raw));
end
end

function text_values = normalizeTextColumn(column)
if iscell(column)
    text_values = strings(numel(column), 1);
    for i = 1:numel(column)
        value = column{i};
        if isempty(value) || (isnumeric(value) && all(isnan(value(:))))
            text_values(i) = "";
        else
            text_values(i) = strtrim(string(value));
        end
    end
else
    text_values = strtrim(string(column));
    text_values(ismissing(text_values)) = "";
end
end

function dates = normalizeDateColumn(column)
if isdatetime(column)
    dates = dateshift(column, 'start', 'day');
elseif isnumeric(column)
    dates = dateshift(datetime(column, 'ConvertFrom', 'excel'), 'start', 'day');
else
    text_values = normalizeTextColumn(column);
    dates = NaT(size(text_values));
    formats = {'MM/dd/yyyy', 'M/d/yyyy', 'yyyy-MM-dd', 'dd-MMM-yyyy'};
    for i = 1:numel(text_values)
        if strlength(text_values(i)) == 0
            continue
        end
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

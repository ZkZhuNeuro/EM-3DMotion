if ~exist('NeuroRespUnitTable', 'var')
    if isfile('C:\LoData\NeuroRespUnitTable_Monocularity.mat')
        tmp = load('C:\LoData\NeuroRespUnitTable_Monocularity.mat', 'NeuroRespUnitTable');
        NeuroRespUnitTable = tmp.NeuroRespUnitTable;
    elseif isfile('C:\LoData\NeuroRespUnitTable.mat')
        tmp = load('C:\LoData\NeuroRespUnitTable.mat', 'NeuroRespUnitTable');
        NeuroRespUnitTable = tmp.NeuroRespUnitTable;
    else
        error(['NeuroRespUnitTable was not found in the workspace and no fallback file was found in C:\LoData. ', ...
            'Run Build3DNeuroRespUnitTable first.']);
    end
end

if ~exist('LateralMotionRawFRTable', 'var')
    if isfile('C:\LoData\LateralMotionRawFRTable.mat')
        tmp = load('C:\LoData\LateralMotionRawFRTable.mat', 'LateralMotionRawFRTable');
        LateralMotionRawFRTable = tmp.LateralMotionRawFRTable;
    else
        error('LateralMotionRawFRTable was not found in the workspace or on disk.');
    end
end

if ~exist('AllMonkeyMIDTable', 'var')
    if isfile('C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\OD_2D3DCompare\AllMonkeyMIDTable.mat')
        tmp = load('C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\OD_2D3DCompare\AllMonkeyMIDTable.mat', 'AllMonkeyMIDTable');
        AllMonkeyMIDTable = tmp.AllMonkeyMIDTable;
    else
        error('AllMonkeyMIDTable was not found in the workspace or on disk.');
    end
end

if ~ismember('Monocularity_2D_Max', LateralMotionRawFRTable.Properties.VariableNames)
    error(['LateralMotionRawFRTable does not contain Monocularity_2D_Max. ', ...
        'Run SaveAndCompareLateralODFromRawFR first so the raw-derived 2D OD is saved into the table.']);
end
if ~ismember('RawFR_ByConditionDirectionSpeed', LateralMotionRawFRTable.Properties.VariableNames)
    error(['LateralMotionRawFRTable does not contain RawFR_ByConditionDirectionSpeed. ', ...
        'Run LateralMotionRawFRPipeline first.']);
end

requiredSigVars = {'sig_Anova2_MonoL', 'sig_Anova2_MonoR'};
for i_var = 1:numel(requiredSigVars)
    if ~ismember(requiredSigVars{i_var}, AllMonkeyMIDTable.Properties.VariableNames)
        error('AllMonkeyMIDTable does not contain %s.', requiredSigVars{i_var});
    end
end
if ~ismember('Z3D_v_Z2D', AllMonkeyMIDTable.Properties.VariableNames)
    error('AllMonkeyMIDTable does not contain Z3D_v_Z2D.');
end

if ismember('Monocularity_3D_Max', NeuroRespUnitTable.Properties.VariableNames)
    monocularity3DVar = 'Monocularity_3D_Max';
elseif ismember('Monocularity_max', NeuroRespUnitTable.Properties.VariableNames)
    monocularity3DVar = 'Monocularity_max';
else
    error(['NeuroRespUnitTable does not contain Monocularity_3D_Max or Monocularity_max. ', ...
        'Run ComputeMonocularityMaxFromNeuroRespUnitTable first if needed.']);
end

output_dir = 'C:\LoData\OD_compare2D3D';
if ~isfolder(output_dir)
    mkdir(output_dir);
end

roi_labels_3d = normalize_roi_labels(NeuroRespUnitTable.ROI);
roi_labels_2d = normalize_roi_labels(LateralMotionRawFRTable.ROI);
roi_labels_mid = normalize_roi_labels(AllMonkeyMIDTable.ROI);
monkey_labels_3d = normalize_monkey_labels(NeuroRespUnitTable);
monkey_labels_2d = normalize_monkey_labels(LateralMotionRawFRTable);
monkey_labels_mid = normalize_monkey_labels(AllMonkeyMIDTable);
disp('Using saved Monocularity_2D_Max from LateralMotionRawFRTable...')
Monocularity2D_FromRawFR = LateralMotionRawFRTable.Monocularity_2D_Max;
disp('Preparing raw lateral tuning significance by speed...')
if ismember('BothTunedRaw_Speed1', LateralMotionRawFRTable.Properties.VariableNames) ...
        && ismember('BothTunedRaw_Speed2', LateralMotionRawFRTable.Properties.VariableNames)
    LateralTunedMask = [logical(LateralMotionRawFRTable.BothTunedRaw_Speed1), ...
        logical(LateralMotionRawFRTable.BothTunedRaw_Speed2)];
else
    LateralTunedMask = compute_lateral_tuned_mask(LateralMotionRawFRTable);
end
sigMask = logical(AllMonkeyMIDTable.sig_Anova2_MonoL) & logical(AllMonkeyMIDTable.sig_Anova2_MonoR);
zPref = AllMonkeyMIDTable.Z3D_v_Z2D;
pref3DMask = zPref > 0;
pref2DMask = zPref < 0;

if height(AllMonkeyMIDTable) ~= height(NeuroRespUnitTable) || height(AllMonkeyMIDTable) ~= height(LateralMotionRawFRTable)
    error(['AllMonkeyMIDTable, NeuroRespUnitTable, and LateralMotionRawFRTable must have the same number of rows ', ...
        'for row-wise filtering with sig_Anova2_MonoL and sig_Anova2_MonoR.']);
end

if numel(roi_labels_3d) == numel(roi_labels_2d) && ~isequal(roi_labels_3d, roi_labels_2d)
    warning('ROI labels are not in the same row order across the 3D and 2D tables. Analysis will be matched within each ROI only.');
end
if numel(roi_labels_3d) == numel(roi_labels_mid) && ~isequal(roi_labels_3d, roi_labels_mid)
    warning('ROI labels are not in the same row order across NeuroRespUnitTable and AllMonkeyMIDTable.');
end
if numel(monkey_labels_3d) == numel(monkey_labels_2d) && ~isequal(monkey_labels_3d, monkey_labels_2d)
    warning('Monkey labels are not in the same row order across the 3D and 2D tables.');
end
if numel(monkey_labels_3d) == numel(monkey_labels_mid) && ~isequal(monkey_labels_3d, monkey_labels_mid)
    warning('Monkey labels are not in the same row order across NeuroRespUnitTable and AllMonkeyMIDTable.');
end

analysisGroups = struct( ...
    'Monkey', {'All', 'All', 'All', 'All', 'Jim', 'Jim', 'Jim', 'Jim', 'Clay', 'Clay', 'Clay', 'Clay'}, ...
    'ROI', {'MT', 'MT', 'FST', 'FST', 'MT', 'MT', 'FST', 'FST', 'MT', 'MT', 'FST', 'FST'}, ...
    'Preference', {'3D', '2D', '3D', '2D', '3D', '2D', '3D', '2D', '3D', '2D', '3D', '2D'}, ...
    'Mask', { ...
        roi_labels_mid == "MT" & sigMask & pref3DMask, ...
        roi_labels_mid == "MT" & sigMask & pref2DMask, ...
        roi_labels_mid == "FST" & sigMask & pref3DMask, ...
        roi_labels_mid == "FST" & sigMask & pref2DMask, ...
        monkey_labels_mid == "JIM" & roi_labels_mid == "MT" & sigMask & pref3DMask, ...
        monkey_labels_mid == "JIM" & roi_labels_mid == "MT" & sigMask & pref2DMask, ...
        monkey_labels_mid == "JIM" & roi_labels_mid == "FST" & sigMask & pref3DMask, ...
        monkey_labels_mid == "JIM" & roi_labels_mid == "FST" & sigMask & pref2DMask, ...
        monkey_labels_mid == "CLAY" & roi_labels_mid == "MT" & sigMask & pref3DMask, ...
        monkey_labels_mid == "CLAY" & roi_labels_mid == "MT" & sigMask & pref2DMask, ...
        monkey_labels_mid == "CLAY" & roi_labels_mid == "FST" & sigMask & pref3DMask, ...
        monkey_labels_mid == "CLAY" & roi_labels_mid == "FST" & sigMask & pref2DMask});

ROIAnalysisResults = cell2table(cell(0, 6), ...
    'VariableNames', {'Monkey', 'ROI', 'Preference', 'N', 'h', 'p'});

for i_group = 1:numel(analysisGroups)
    monkey_this = string(analysisGroups(i_group).Monkey);
    roi_this = string(analysisGroups(i_group).ROI);
    pref_this = string(analysisGroups(i_group).Preference);
    idx_this = analysisGroups(i_group).Mask(:);

    idx_3d = idx_this;
    idx_2d = idx_this;

    OD_3D = NeuroRespUnitTable.(monocularity3DVar)(idx_3d);
    OD_2D = Monocularity2D_FromRawFR(idx_2d, :);

    if isempty(OD_3D) || isempty(OD_2D)
        warning('No rows found for monkey %s, ROI %s, preference %s. Skipping this group.', ...
            monkey_this, roi_this, pref_this);
        continue
    end

    if size(OD_2D, 1) ~= numel(OD_3D)
        error('Monkey %s, ROI %s, preference %s has %d rows in NeuroRespUnitTable but %d rows in LateralMotionRawFRTable.', ...
            monkey_this, roi_this, pref_this, numel(OD_3D), size(OD_2D, 1));
    end

    tuned_this = LateralTunedMask(idx_2d, :);
    result_this = run_roi_analysis(monkey_this, roi_this, pref_this, OD_3D, OD_2D, tuned_this, monocularity3DVar, output_dir);
    ROIAnalysisResults = [ROIAnalysisResults; ...
        {char(result_this.Monkey), char(result_this.ROI), char(result_this.Preference), result_this.N, result_this.h, result_this.p}]; %#ok<AGROW>
end

disp(ROIAnalysisResults)

function roi_labels = normalize_roi_labels(roi_column)
roi_labels = upper(strtrim(string(roi_column)));
end

function monkey_labels = normalize_monkey_labels(T)
if ismember('Monkey', T.Properties.VariableNames)
    monkey_labels = upper(strtrim(string(T.Monkey)));
    return
end

monkey_labels = strings(height(T), 1);
if ismember('Names', T.Properties.VariableNames)
    names = string(T.Names(:, 1));
    monkey_labels(startsWith(upper(names), "JIM")) = "JIM";
    monkey_labels(startsWith(upper(names), "CLAY")) = "CLAY";
end
end

function result = run_roi_analysis(monkey_name, roi_name, pref_name, OD_3D, OD_2D, tunedMask, monocularity3DVar, output_dir)
if isvector(OD_2D)
    OD_2D = OD_2D(:);
end

if size(OD_2D, 1) ~= numel(OD_3D)
    error('Monkey %s, ROI %s, preference %s has mismatched 2D and 3D lengths.', ...
        monkey_name, roi_name, pref_name);
end

n_cols = size(OD_2D, 2);
h_values = NaN(1, n_cols);
p_values = NaN(1, n_cols);
valid_counts = NaN(1, n_cols);
AbsOD_3D = abs(OD_3D);
AbsOD_2D = abs(OD_2D);

signed_scatter_fig = figure('Visible', 'off', 'Name', sprintf('%s, %s ROI, %s-pref: 2D vs 3D', ...
    monkey_name, roi_name, pref_name));
tl_signed_scatter = tiledlayout(n_cols, 1, 'TileSpacing', 'compact');
title(tl_signed_scatter, sprintf('%s, %s ROI, %s-pref: 2D OD vs 3D OD', ...
    monkey_name, roi_name, pref_name))

for i_col = 1:n_cols
    valid = isfinite(OD_3D) & isfinite(OD_2D(:, i_col)) & logical(tunedMask(:, i_col));

    nexttile
    if any(valid)
        scatter(OD_2D(valid, i_col), OD_3D(valid), 36, 'filled');
        hold on
        lims = [min([OD_2D(valid, i_col); OD_3D(valid)]), ...
            max([OD_2D(valid, i_col); OD_3D(valid)])];
        if all(isfinite(lims)) && lims(1) < lims(2)
            plot(lims, lims, 'k--', 'LineWidth', 1);
            xlim(lims);
            ylim(lims);
        end
        xline(0, ':', 'Color', [0.4 0.4 0.4]);
        yline(0, ':', 'Color', [0.4 0.4 0.4]);
        hold off
    else
        text(0.5, 0.5, 'No valid data', 'HorizontalAlignment', 'center');
    end
    xlabel(sprintf('2D OD Column %d', i_col))
    ylabel('3D OD')
    title(sprintf('Column %d: n = %d', i_col, sum(valid)))
    grid on
    axis square
end

scatter_fig = figure('Visible', 'off', 'Name', sprintf('%s, %s ROI, %s-pref: |2D| vs |3D|', ...
    monkey_name, roi_name, pref_name));
tl_scatter = tiledlayout(n_cols, 1, 'TileSpacing', 'compact');
title(tl_scatter, sprintf('%s, %s ROI, %s-pref: |2D OD| vs |3D OD|', ...
    monkey_name, roi_name, pref_name))

for i_col = 1:n_cols
    valid = isfinite(AbsOD_3D) & isfinite(AbsOD_2D(:, i_col)) & logical(tunedMask(:, i_col));

    nexttile
    if any(valid)
        scatter(AbsOD_2D(valid, i_col), AbsOD_3D(valid), 36, 'filled');
        hold on
        lims = [min([AbsOD_2D(valid, i_col); AbsOD_3D(valid)]), ...
            max([AbsOD_2D(valid, i_col); AbsOD_3D(valid)])];
        if all(isfinite(lims)) && lims(1) < lims(2)
            plot(lims, lims, 'k--', 'LineWidth', 1);
            xlim(lims);
            ylim(lims);
        end
        hold off
    else
        text(0.5, 0.5, 'No valid data', 'HorizontalAlignment', 'center');
    end
    xlabel(sprintf('|2D OD| Column %d', i_col))
    ylabel('|3D OD|')
    title(sprintf('Column %d: n = %d', i_col, sum(valid)))
    grid on
    axis square
end

hist_fig = figure('Visible', 'off', 'Name', sprintf('%s, %s ROI, %s-pref: |3D| - |2D|', monkey_name, roi_name, pref_name));
tl = tiledlayout(n_cols, 1, 'TileSpacing', 'compact');
title(tl, sprintf('%s, %s ROI, %s-pref: |3D OD| - |2D OD| histograms', monkey_name, roi_name, pref_name))

for i_col = 1:n_cols
    delta_this = AbsOD_3D - AbsOD_2D(:, i_col);
    valid = isfinite(delta_this) & logical(tunedMask(:, i_col));
    valid_counts(i_col) = sum(valid);
    if any(valid)
        [p_values(i_col), h_values(i_col)] = signrank(AbsOD_3D(valid), AbsOD_2D(valid, i_col));
        med_val = median(delta_this(valid), 'omitnan');
    else
        h_values(i_col) = nan;
        p_values(i_col) = nan;
        med_val = nan;
    end

    nexttile
    histogram(delta_this(valid))
    hold on
    if isfinite(med_val)
        xline(med_val, 'r--', 'LineWidth', 1.5);
    end
    hold off
    xlabel(sprintf('|3D OD| - |2D OD| Column %d', i_col))
    ylabel('Count')
    title(sprintf('Column %d: n = %d, h = %d, p = %.4g, median = %.4g', ...
        i_col, valid_counts(i_col), h_values(i_col), p_values(i_col), med_val))
end

save_group_figures(signed_scatter_fig, scatter_fig, hist_fig, output_dir, monkey_name, roi_name, pref_name);
close(signed_scatter_fig);
close(scatter_fig);
close(hist_fig);

fprintf('\n%s, %s ROI, %s-pref, absolute OD comparison\n', monkey_name, roi_name, pref_name);
disp(table((1:n_cols)', valid_counts', h_values', p_values', ...
    'VariableNames', {'Column', 'N', 'h', 'p'}))

result = struct( ...
    'Monkey', monkey_name, ...
    'ROI', roi_name, ...
    'Preference', pref_name, ...
    'N', valid_counts, ...
    'h', h_values, ...
    'p', p_values);
end

function save_group_figures(signed_scatter_fig, scatter_fig, hist_fig, output_dir, monkey_name, roi_name, pref_name)
base_name = make_safe_name(sprintf('%s_%s_%s_pref', monkey_name, roi_name, pref_name));
exportgraphics(signed_scatter_fig, fullfile(output_dir, [base_name, '_scatter_signed.png']), 'Resolution', 300);
exportgraphics(scatter_fig, fullfile(output_dir, [base_name, '_scatter.png']), 'Resolution', 300);
exportgraphics(hist_fig, fullfile(output_dir, [base_name, '_hist.png']), 'Resolution', 300);
end

function safe_name = make_safe_name(raw_name)
safe_name = regexprep(char(raw_name), '[^a-zA-Z0-9_]', '_');
end

function tunedMask = compute_lateral_tuned_mask(T)
nRows = height(T);
tunedMask = false(nRows, 2);

for i = 1:nRows
    raw2D = T.RawFR_ByConditionDirectionSpeed{i};
    condCodes = T.ConditionCodesUsed{i};
    anovaP = compute_lateral_raw_anova(raw2D, condCodes);
    tunedMask(i, :) = anovaP < 0.05;
end
end

function anovaP = compute_lateral_raw_anova(raw2D, condCodes)
anovaP = nan(1, 2);

if isempty(raw2D)
    return
end

bothIdx = get_both_condition_index(condCodes, size(raw2D, 1));
if isnan(bothIdx)
    return
end

nSpeeds = min(size(raw2D, 3), 2);
for s = 1:nSpeeds
    anovaData = [];
    labels = [];
    for d = 1:size(raw2D, 2)
        vals = raw2D{bothIdx, d, s};
        if isempty(vals)
            continue
        end
        vals = vals(:);
        vals = vals(isfinite(vals));
        if isempty(vals)
            continue
        end
        anovaData = [anovaData; vals]; %#ok<AGROW>
        labels = [labels; repmat(d, numel(vals), 1)]; %#ok<AGROW>
    end

    if numel(unique(labels)) >= 2 && numel(anovaData) > numel(unique(labels))
        anovaP(s) = anova1(anovaData, labels, 'off');
    end
end
end

function bothIdx = get_both_condition_index(condCodes, nConditions)
bothIdx = nan;

if ~isempty(condCodes)
    bothMatch = find(condCodes == 8003, 1, 'first');
    if ~isempty(bothMatch)
        bothIdx = bothMatch;
        return
    end
end

if nConditions >= 3
    bothIdx = 3;
end
end

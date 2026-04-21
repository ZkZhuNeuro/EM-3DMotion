%% Correlate Abs Combined AI With Abs OD Difference
% For each OD comparison category and speed column, plot:
%   x = abs(3D OD) - abs(2D OD)
%   y = abs(Combined_AI)
% and compute a Spearman correlation.
%
% Categories match OD_2D3DCompare.m:
%   - All / Jim / Clay
%   - MT / FST
%   - 3D-pref / 2D-pref
%
% Filtering matches the OD comparison code:
%   - sig_Anova2_MonoL & sig_Anova2_MonoR
%   - significant lateral tuning at that speed from raw binocular FR

clearvars -except NeuroRespUnitTable LateralMotionRawFRTable AllMonkeyMIDTable

disp('Loading NeuroRespUnitTable...')
if ~exist('NeuroRespUnitTable', 'var')
    if isfile('C:\LoData\NeuroRespUnitTable_Monocularity.mat')
        tmp = load('C:\LoData\NeuroRespUnitTable_Monocularity.mat', 'NeuroRespUnitTable');
        NeuroRespUnitTable = tmp.NeuroRespUnitTable;
    elseif isfile('C:\LoData\NeuroRespUnitTable.mat')
        tmp = load('C:\LoData\NeuroRespUnitTable.mat', 'NeuroRespUnitTable');
        NeuroRespUnitTable = tmp.NeuroRespUnitTable;
    else
        error('NeuroRespUnitTable was not found in the workspace or in C:\LoData.');
    end
end

disp('Loading LateralMotionRawFRTable...')
if ~exist('LateralMotionRawFRTable', 'var')
    if isfile('C:\LoData\LateralMotionRawFRTable.mat')
        tmp = load('C:\LoData\LateralMotionRawFRTable.mat', 'LateralMotionRawFRTable');
        LateralMotionRawFRTable = tmp.LateralMotionRawFRTable;
    else
        error('LateralMotionRawFRTable was not found in the workspace or in C:\LoData.');
    end
end

disp('Loading AllMonkeyMIDTable...')
if ~exist('AllMonkeyMIDTable', 'var')
    midPath = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\OD_2D3DCompare\AllMonkeyMIDTable.mat';
    if isfile(midPath)
        tmp = load(midPath, 'AllMonkeyMIDTable');
        AllMonkeyMIDTable = tmp.AllMonkeyMIDTable;
    else
        error('AllMonkeyMIDTable was not found at %s.', midPath);
    end
end

requiredMIDVars = {'sig_Anova2_MonoL', 'sig_Anova2_MonoR', 'Z3D_v_Z2D', 'Combined_AI', 'Date', 'ROI', 'Unit'};
required2DVars = {'Monocularity_2D_Max', 'RawFR_ByConditionDirectionSpeed', 'ConditionCodesUsed', 'Date', 'ROI', 'Unit'};
check_required_vars(AllMonkeyMIDTable, requiredMIDVars, 'AllMonkeyMIDTable');
check_required_vars(LateralMotionRawFRTable, required2DVars, 'LateralMotionRawFRTable');

if ismember('Monocularity_3D_Max', NeuroRespUnitTable.Properties.VariableNames)
    od3D = NeuroRespUnitTable.Monocularity_3D_Max;
elseif ismember('Monocularity_max', NeuroRespUnitTable.Properties.VariableNames)
    od3D = NeuroRespUnitTable.Monocularity_max;
else
    error(['NeuroRespUnitTable does not contain Monocularity_3D_Max or Monocularity_max. ', ...
        'Run ComputeMonocularityMaxFromNeuroRespUnitTable first if needed.']);
end

if height(AllMonkeyMIDTable) ~= height(NeuroRespUnitTable) || height(AllMonkeyMIDTable) ~= height(LateralMotionRawFRTable)
    error('AllMonkeyMIDTable, NeuroRespUnitTable, and LateralMotionRawFRTable must have the same number of rows.');
end

disp('Verifying Date / ROI / Unit row alignment...')
verify_row_alignment(NeuroRespUnitTable, LateralMotionRawFRTable, AllMonkeyMIDTable);

output_dir = 'C:\LoData\OD_compare2D3D_AbsCombinedAI_Corr';
if ~isfolder(output_dir)
    mkdir(output_dir);
end

od2D = LateralMotionRawFRTable.Monocularity_2D_Max;
absCombinedAI = abs(AllMonkeyMIDTable.Combined_AI);
roi_labels = normalize_roi_labels(AllMonkeyMIDTable.ROI);
monkey_labels = normalize_monkey_labels(AllMonkeyMIDTable);
sigMask = logical(AllMonkeyMIDTable.sig_Anova2_MonoL) & logical(AllMonkeyMIDTable.sig_Anova2_MonoR);
pref3DMask = AllMonkeyMIDTable.Z3D_v_Z2D > 0;
pref2DMask = AllMonkeyMIDTable.Z3D_v_Z2D < 0;

if ismember('BothTunedRaw_Speed1', LateralMotionRawFRTable.Properties.VariableNames) ...
        && ismember('BothTunedRaw_Speed2', LateralMotionRawFRTable.Properties.VariableNames)
    lateralTunedMask = [logical(LateralMotionRawFRTable.BothTunedRaw_Speed1), ...
        logical(LateralMotionRawFRTable.BothTunedRaw_Speed2)];
else
    lateralTunedMask = compute_lateral_tuned_mask(LateralMotionRawFRTable);
end

analysisGroups = struct( ...
    'Monkey', {'All', 'All', 'All', 'All', 'Jim', 'Jim', 'Jim', 'Jim', 'Clay', 'Clay', 'Clay', 'Clay'}, ...
    'ROI', {'MT', 'MT', 'FST', 'FST', 'MT', 'MT', 'FST', 'FST', 'MT', 'MT', 'FST', 'FST'}, ...
    'Preference', {'3D', '2D', '3D', '2D', '3D', '2D', '3D', '2D', '3D', '2D', '3D', '2D'}, ...
    'Mask', { ...
        roi_labels == "MT" & sigMask & pref3DMask, ...
        roi_labels == "MT" & sigMask & pref2DMask, ...
        roi_labels == "FST" & sigMask & pref3DMask, ...
        roi_labels == "FST" & sigMask & pref2DMask, ...
        monkey_labels == "JIM" & roi_labels == "MT" & sigMask & pref3DMask, ...
        monkey_labels == "JIM" & roi_labels == "MT" & sigMask & pref2DMask, ...
        monkey_labels == "JIM" & roi_labels == "FST" & sigMask & pref3DMask, ...
        monkey_labels == "JIM" & roi_labels == "FST" & sigMask & pref2DMask, ...
        monkey_labels == "CLAY" & roi_labels == "MT" & sigMask & pref3DMask, ...
        monkey_labels == "CLAY" & roi_labels == "MT" & sigMask & pref2DMask, ...
        monkey_labels == "CLAY" & roi_labels == "FST" & sigMask & pref3DMask, ...
        monkey_labels == "CLAY" & roi_labels == "FST" & sigMask & pref2DMask});

ResultsTable = table();

for i_group = 1:numel(analysisGroups)
    monkeyThis = string(analysisGroups(i_group).Monkey);
    roiThis = string(analysisGroups(i_group).ROI);
    prefThis = string(analysisGroups(i_group).Preference);
    baseMask = analysisGroups(i_group).Mask(:);

    for i_col = 1:size(od2D, 2)
        valid = baseMask ...
            & isfinite(od3D) ...
            & isfinite(od2D(:, i_col)) ...
            & isfinite(absCombinedAI) ...
            & logical(lateralTunedMask(:, i_col));

        xVals = abs(od3D(valid)) - abs(od2D(valid, i_col));
        yVals = absCombinedAI(valid);

        if numel(xVals) >= 3 && numel(unique(xVals)) >= 2 && numel(unique(yVals)) >= 2
            [rhoVal, pVal] = corr(xVals, yVals, 'Type', 'Spearman', 'Rows', 'complete');
        else
            rhoVal = nan;
            pVal = nan;
        end

        fig = figure('Visible', 'off', ...
            'Name', sprintf('%s, %s ROI, %s-pref, Speed %d: Abs Combined AI vs Abs OD difference', ...
            monkeyThis, roiThis, prefThis, i_col));
        if ~isempty(xVals)
            scatter(xVals, yVals, 36, 'filled');
            hold on
            xline(0, ':', 'Color', [0.4 0.4 0.4]);
            hold off
        else
            text(0.5, 0.5, 'No valid data', 'HorizontalAlignment', 'center');
        end
        grid on
        xlabel('|3D OD| - |2D OD|')
        ylabel('|Combined AI|')
        title(sprintf('%s, %s ROI, %s-pref, Speed %d, rho = %.4g, p = %.4g, n = %d', ...
            monkeyThis, roiThis, prefThis, i_col, rhoVal, pVal, numel(xVals)))

        savePath = fullfile(output_dir, make_safe_name(sprintf( ...
            'AbsCombinedAI_vs_AbsODDiff_%s_%s_%s_pref_Speed%d.png', ...
            monkeyThis, roiThis, prefThis, i_col)));
        exportgraphics(fig, savePath, 'Resolution', 300);
        close(fig);

        ResultsTable = [ResultsTable; ...
            table(monkeyThis, roiThis, prefThis, i_col, numel(xVals), rhoVal, pVal, ...
            median_or_nan(xVals), median_or_nan(yVals), ...
            'VariableNames', {'Monkey', 'ROI', 'Preference', 'SpeedColumn', 'N', ...
            'SpearmanRho', 'SpearmanP', 'MedianAbsODDiff', 'MedianAbsCombinedAI'})]; %#ok<AGROW>
    end
end

save(fullfile(output_dir, 'AbsCombinedAI_vs_AbsODDiff.mat'), 'ResultsTable', '-v7.3');
disp('Saved abs Combined_AI correlation results:')
disp(ResultsTable)

function check_required_vars(T, requiredVars, tableName)
missingVars = requiredVars(~ismember(requiredVars, T.Properties.VariableNames));
if ~isempty(missingVars)
    error('%s is missing required variable(s): %s', tableName, strjoin(missingVars, ', '));
end
end

function verify_row_alignment(T3D, T2D, TMID)
dateMatch = isequal(T3D.Date, T2D.Date) && isequal(T3D.Date, TMID.Date);
roiMatch = isequal(string(T3D.ROI), string(T2D.ROI)) && isequal(string(T3D.ROI), string(TMID.ROI));
unitMatch = isequal(T3D.Unit, T2D.Unit) && isequal(T3D.Unit, TMID.Unit);

if ~(dateMatch && roiMatch && unitMatch)
    error(['Date / ROI / Unit rows do not align across NeuroRespUnitTable, ', ...
        'LateralMotionRawFRTable, and AllMonkeyMIDTable.']);
end
end

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

function safe_name = make_safe_name(raw_name)
safe_name = regexprep(char(raw_name), '[^a-zA-Z0-9_\.]', '_');
end

function out = median_or_nan(vals)
if isempty(vals)
    out = nan;
else
    out = median(vals, 'omitnan');
end
end

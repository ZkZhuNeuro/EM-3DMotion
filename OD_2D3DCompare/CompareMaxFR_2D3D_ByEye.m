%% Compare Maximal Mean FR Between 3D and 2D By Eye
% Loads NeuroRespUnitTable, LateralMotionRawFRTable, and AllMonkeyMIDTable.
% For each neuron, first z-scores FR using the combined raw-FR pool from:
%   - 3D first 4 cues across coherence/repeats
%   - 2D first 3 conditions across direction/speed/trials
% Then computes:
%   - z-scored 3D Left-eye max mean FR from cue 2
%   - z-scored 3D Right-eye max mean FR from cue 3
%   - z-scored 2D Left-eye max mean FR from the left-eye condition
%   - z-scored 2D Right-eye max mean FR from the right-eye condition
% separately for each available 2D speed.
%
% Filtering and grouping match OD_2D3DCompare.m:
%   - include only neurons with sig_Anova2_MonoL & sig_Anova2_MonoR
%   - split into combined plus monkey-specific groups:
%       All/Jim/Clay x MT/FST x 3D-pref/2D-pref
%   - include each neuron/speed only if raw lateral tuning is significant
%     by one-way ANOVA across directions in the binocular condition

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

required3DVars = {'NeuroResp', 'Date', 'ROI', 'Unit'};
required2DVars = {'RawFR_ByConditionDirectionSpeed', 'ConditionCodesUsed', 'Date', 'ROI', 'Unit'};
requiredMIDVars = {'sig_Anova2_MonoL', 'sig_Anova2_MonoR', 'Z3D_v_Z2D', 'Date', 'ROI', 'Unit'};

check_required_vars(NeuroRespUnitTable, required3DVars, 'NeuroRespUnitTable');
check_required_vars(LateralMotionRawFRTable, required2DVars, 'LateralMotionRawFRTable');
check_required_vars(AllMonkeyMIDTable, requiredMIDVars, 'AllMonkeyMIDTable');

if height(NeuroRespUnitTable) ~= height(LateralMotionRawFRTable) || ...
        height(NeuroRespUnitTable) ~= height(AllMonkeyMIDTable)
    error(['NeuroRespUnitTable, LateralMotionRawFRTable, and AllMonkeyMIDTable must have the same ', ...
        'number of rows for row-wise comparison.']);
end

disp('Verifying Date / ROI / Unit row alignment across tables...')
verify_row_alignment(NeuroRespUnitTable, LateralMotionRawFRTable, AllMonkeyMIDTable);

nRows = height(NeuroRespUnitTable);
disp(['Computing z-scored max FR values for ', num2str(nRows), ' neurons...'])

LeftMax_3D = nan(nRows, 1);
RightMax_3D = nan(nRows, 1);
LeftMax_2D_Speed1 = nan(nRows, 1);
RightMax_2D_Speed1 = nan(nRows, 1);
LeftMax_2D_Speed2 = nan(nRows, 1);
RightMax_2D_Speed2 = nan(nRows, 1);
ZScoreMu = nan(nRows, 1);
ZScoreSigma = nan(nRows, 1);
BothAnovaRaw_Speed1 = nan(nRows, 1);
BothAnovaRaw_Speed2 = nan(nRows, 1);

for i = 1:nRows
    resp3D = NeuroRespUnitTable.NeuroResp{i};
    raw2D = LateralMotionRawFRTable.RawFR_ByConditionDirectionSpeed{i};
    condCodes = LateralMotionRawFRTable.ConditionCodesUsed{i};
    [zMu, zSigma] = compute_neuron_zscore_params(resp3D, raw2D);
    ZScoreMu(i) = zMu;
    ZScoreSigma(i) = zSigma;
    anovaP = compute_lateral_raw_anova(raw2D, condCodes);
    BothAnovaRaw_Speed1(i) = anovaP(1);
    BothAnovaRaw_Speed2(i) = anovaP(2);

    [LeftMax_3D(i), RightMax_3D(i)] = extract_3d_eye_maxima_zscored(resp3D, zMu, zSigma);
    [left2D, right2D] = extract_2d_eye_maxima_zscored(raw2D, condCodes, zMu, zSigma);

    if numel(left2D) >= 1
        LeftMax_2D_Speed1(i) = left2D(1);
        RightMax_2D_Speed1(i) = right2D(1);
    end
    if numel(left2D) >= 2
        LeftMax_2D_Speed2(i) = left2D(2);
        RightMax_2D_Speed2(i) = right2D(2);
    end

    if mod(i, 100) == 0 || i == nRows
        disp(['  Processed ', num2str(i), '/', num2str(nRows)])
    end
end

MaxFRComparisonTable = table();
MaxFRComparisonTable.RowIndex = (1:nRows)';
MaxFRComparisonTable.Date = NeuroRespUnitTable.Date;
MaxFRComparisonTable.Monkey = normalize_monkey_labels(NeuroRespUnitTable);
MaxFRComparisonTable.ROI = string(NeuroRespUnitTable.ROI);
MaxFRComparisonTable.Unit = NeuroRespUnitTable.Unit;
MaxFRComparisonTable.Z3D_v_Z2D = AllMonkeyMIDTable.Z3D_v_Z2D;
MaxFRComparisonTable.sig_Anova2_MonoL = logical(AllMonkeyMIDTable.sig_Anova2_MonoL);
MaxFRComparisonTable.sig_Anova2_MonoR = logical(AllMonkeyMIDTable.sig_Anova2_MonoR);
MaxFRComparisonTable.IncludeMask = MaxFRComparisonTable.sig_Anova2_MonoL & MaxFRComparisonTable.sig_Anova2_MonoR;
MaxFRComparisonTable.Preference = strings(nRows, 1);
MaxFRComparisonTable.Preference(AllMonkeyMIDTable.Z3D_v_Z2D > 0) = "3D";
MaxFRComparisonTable.Preference(AllMonkeyMIDTable.Z3D_v_Z2D < 0) = "2D";
MaxFRComparisonTable.ZScoreMu = ZScoreMu;
MaxFRComparisonTable.ZScoreSigma = ZScoreSigma;
MaxFRComparisonTable.BothAnovaRaw_Speed1 = BothAnovaRaw_Speed1;
MaxFRComparisonTable.BothAnovaRaw_Speed2 = BothAnovaRaw_Speed2;
MaxFRComparisonTable.BothTunedRaw_Speed1 = BothAnovaRaw_Speed1 < 0.05;
MaxFRComparisonTable.BothTunedRaw_Speed2 = BothAnovaRaw_Speed2 < 0.05;
MaxFRComparisonTable.LeftMax_3D = LeftMax_3D;
MaxFRComparisonTable.RightMax_3D = RightMax_3D;
MaxFRComparisonTable.LeftMax_2D_Speed1 = LeftMax_2D_Speed1;
MaxFRComparisonTable.RightMax_2D_Speed1 = RightMax_2D_Speed1;
MaxFRComparisonTable.LeftMax_2D_Speed2 = LeftMax_2D_Speed2;
MaxFRComparisonTable.RightMax_2D_Speed2 = RightMax_2D_Speed2;
MaxFRComparisonTable.LeftDelta_3Dminus2D_Speed1 = LeftMax_3D - LeftMax_2D_Speed1;
MaxFRComparisonTable.RightDelta_3Dminus2D_Speed1 = RightMax_3D - RightMax_2D_Speed1;
MaxFRComparisonTable.LeftDelta_3Dminus2D_Speed2 = LeftMax_3D - LeftMax_2D_Speed2;
MaxFRComparisonTable.RightDelta_3Dminus2D_Speed2 = RightMax_3D - RightMax_2D_Speed2;

sigMask = MaxFRComparisonTable.IncludeMask;
monkeyLabels = upper(strtrim(string(MaxFRComparisonTable.Monkey)));
roiLabels = upper(strtrim(string(MaxFRComparisonTable.ROI)));
pref3DMask = MaxFRComparisonTable.Z3D_v_Z2D > 0;
pref2DMask = MaxFRComparisonTable.Z3D_v_Z2D < 0;

analysisGroups = struct( ...
    'Monkey', {'All', 'All', 'All', 'All', 'Jim', 'Jim', 'Jim', 'Jim', 'Clay', 'Clay', 'Clay', 'Clay'}, ...
    'ROI', {'MT', 'MT', 'FST', 'FST', 'MT', 'MT', 'FST', 'FST', 'MT', 'MT', 'FST', 'FST'}, ...
    'Preference', {'3D', '2D', '3D', '2D', '3D', '2D', '3D', '2D', '3D', '2D', '3D', '2D'}, ...
    'Mask', { ...
        roiLabels == "MT" & sigMask & pref3DMask, ...
        roiLabels == "MT" & sigMask & pref2DMask, ...
        roiLabels == "FST" & sigMask & pref3DMask, ...
        roiLabels == "FST" & sigMask & pref2DMask, ...
        monkeyLabels == "JIM" & roiLabels == "MT" & sigMask & pref3DMask, ...
        monkeyLabels == "JIM" & roiLabels == "MT" & sigMask & pref2DMask, ...
        monkeyLabels == "JIM" & roiLabels == "FST" & sigMask & pref3DMask, ...
        monkeyLabels == "JIM" & roiLabels == "FST" & sigMask & pref2DMask, ...
        monkeyLabels == "CLAY" & roiLabels == "MT" & sigMask & pref3DMask, ...
        monkeyLabels == "CLAY" & roiLabels == "MT" & sigMask & pref2DMask, ...
        monkeyLabels == "CLAY" & roiLabels == "FST" & sigMask & pref3DMask, ...
        monkeyLabels == "CLAY" & roiLabels == "FST" & sigMask & pref2DMask});

SummaryResults = table();
disp('Running grouped comparisons with Wilcoxon signed-rank tests...')

for i_group = 1:numel(analysisGroups)
    mask = analysisGroups(i_group).Mask(:);
    monkeyThis = string(analysisGroups(i_group).Monkey);
    roiThis = string(analysisGroups(i_group).ROI);
    prefThis = string(analysisGroups(i_group).Preference);

    groupTable = MaxFRComparisonTable(mask, :);
    if isempty(groupTable)
        warning('No neurons found for monkey %s, ROI %s, preference %s.', monkeyThis, roiThis, prefThis);
        continue
    end

    disp(['  ', char(monkeyThis), ', ', char(roiThis), ', ', char(prefThis), ...
        '-pref: n = ', num2str(height(groupTable))])

    SummaryResults = [SummaryResults; ...
        build_summary_rows(groupTable, monkeyThis, roiThis, prefThis, 'Left', 'Speed1', 'LeftMax_3D', 'LeftMax_2D_Speed1', 'BothTunedRaw_Speed1'); ...
        build_summary_rows(groupTable, monkeyThis, roiThis, prefThis, 'Right', 'Speed1', 'RightMax_3D', 'RightMax_2D_Speed1', 'BothTunedRaw_Speed1'); ...
        build_summary_rows(groupTable, monkeyThis, roiThis, prefThis, 'Left', 'Speed2', 'LeftMax_3D', 'LeftMax_2D_Speed2', 'BothTunedRaw_Speed2'); ...
        build_summary_rows(groupTable, monkeyThis, roiThis, prefThis, 'Right', 'Speed2', 'RightMax_3D', 'RightMax_2D_Speed2', 'BothTunedRaw_Speed2')]; %#ok<AGROW>

    make_group_plots(groupTable, monkeyThis, roiThis, prefThis);
end

outputPath = 'C:\LoData\MaxFRComparison_2D3D_ByEye.mat';
save(outputPath, 'MaxFRComparisonTable', 'SummaryResults', '-v7.3');
disp(['Saved results to ', outputPath])
disp('SummaryResults:')
disp(SummaryResults)

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

function monkeyLabels = normalize_monkey_labels(T)
if ismember('Monkey', T.Properties.VariableNames)
    monkeyLabels = string(T.Monkey);
    return
end

monkeyLabels = strings(height(T), 1);
if ismember('Names', T.Properties.VariableNames)
    names = string(T.Names(:, 1));
    monkeyLabels(startsWith(upper(names), "JIM")) = "Jim";
    monkeyLabels(startsWith(upper(names), "CLAY")) = "Clay";
end
end

function [leftMax, rightMax] = extract_3d_eye_maxima(resp3D)
leftMax = nan;
rightMax = nan;

if isempty(resp3D) || ndims(resp3D) < 2 || size(resp3D, 1) < 3
    return
end

leftResp = squeeze(resp3D(2, :, :));
rightResp = squeeze(resp3D(3, :, :));

leftMean = average_last_dim(leftResp);
rightMean = average_last_dim(rightResp);

leftMax = max(leftMean(:), [], 'omitnan');
rightMax = max(rightMean(:), [], 'omitnan');
end

function [zMu, zSigma] = compute_neuron_zscore_params(resp3D, raw2D)
raw3DVec = [];
raw2DVec = [];

if ~isempty(resp3D) && ndims(resp3D) >= 3
    nCues3D = min(size(resp3D, 1), 4);
    raw3DVec = resp3D(1:nCues3D, :, :);
    raw3DVec = raw3DVec(:);
end

if ~isempty(raw2D)
    nCond2D = min(size(raw2D, 1), 3);
    nSpeed2D = min(size(raw2D, 3), 2);
    raw2DVec = collect_raw_2d_values(raw2D(1:nCond2D, :, 1:nSpeed2D));
end

allVals = [raw3DVec(:); raw2DVec(:)];
allVals = allVals(isfinite(allVals));

if isempty(allVals)
    zMu = nan;
    zSigma = nan;
    return
end

zMu = mean(allVals, 'omitnan');
zSigma = std(allVals, 'omitnan');
if ~isfinite(zSigma) || zSigma == 0
    zSigma = nan;
end
end

function [leftMax, rightMax] = extract_3d_eye_maxima_zscored(resp3D, zMu, zSigma)
leftMaxBySpeed = nan(1, 2);
rightMaxBySpeed = nan(1, 2);

leftMax = nan;
rightMax = nan;

if isempty(resp3D) || ndims(resp3D) < 2 || size(resp3D, 1) < 3 || ~isfinite(zMu) || ~isfinite(zSigma)
    return
end

leftResp = squeeze(resp3D(2, :, :));
rightResp = squeeze(resp3D(3, :, :));

leftMean = average_last_dim(leftResp);
rightMean = average_last_dim(rightResp);

leftMean = (leftMean - zMu) ./ zSigma;
rightMean = (rightMean - zMu) ./ zSigma;

leftMax = max(leftMean(:), [], 'omitnan');
rightMax = max(rightMean(:), [], 'omitnan');
end

function [leftMaxBySpeed, rightMaxBySpeed] = extract_2d_eye_maxima_zscored(raw2D, condCodes, zMu, zSigma)
leftMaxBySpeed = nan(1, 2);
rightMaxBySpeed = nan(1, 2);

if isempty(raw2D) || ~isfinite(zMu) || ~isfinite(zSigma)
    return
end

[leftIdx, rightIdx] = get_left_right_condition_indices(condCodes, size(raw2D, 1));
if isnan(leftIdx) || isnan(rightIdx)
    return
end

nSpeeds = min(size(raw2D, 3), 2);
for s = 1:nSpeeds
    leftMean = compute_zscored_2d_mean(raw2D(leftIdx, :, s), zMu, zSigma);
    rightMean = compute_zscored_2d_mean(raw2D(rightIdx, :, s), zMu, zSigma);
    leftMaxBySpeed(s) = max(leftMean(:), [], 'omitnan');
    rightMaxBySpeed(s) = max(rightMean(:), [], 'omitnan');
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

function meanResp = average_last_dim(resp)
if isvector(resp)
    meanResp = resp(:);
else
    meanResp = nanmean(resp, ndims(resp));
end
end

function rawVals = collect_raw_2d_values(rawCellBlock)
rawVals = [];
for i = 1:numel(rawCellBlock)
    vals = rawCellBlock{i};
    if isempty(vals)
        continue
    end
    vals = vals(:);
    vals = vals(isfinite(vals));
    rawVals = [rawVals; vals]; %#ok<AGROW>
end
end

function meanResp = compute_zscored_2d_mean(rawCellSlice, zMu, zSigma)
nDirs = size(rawCellSlice, 2);
meanResp = nan(1, nDirs);

for d = 1:nDirs
    vals = rawCellSlice{1, d};
    if isempty(vals)
        continue
    end
    vals = vals(:);
    vals = vals(isfinite(vals));
    if isempty(vals)
        continue
    end
    zVals = (vals - zMu) ./ zSigma;
    meanResp(d) = mean(zVals, 'omitnan');
end
end

function [leftIdx, rightIdx] = get_left_right_condition_indices(condCodes, nConditions)
leftIdx = nan;
rightIdx = nan;

if ~isempty(condCodes)
    leftMatch = find(condCodes == 8001, 1, 'first');
    rightMatch = find(condCodes == 8002, 1, 'first');
    if ~isempty(leftMatch)
        leftIdx = leftMatch;
    end
    if ~isempty(rightMatch)
        rightIdx = rightMatch;
    end
end

if isnan(leftIdx) && nConditions >= 1
    leftIdx = 1;
end
if isnan(rightIdx) && nConditions >= 2
    rightIdx = 2;
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

function outRow = build_summary_rows(groupTable, monkeyName, roiName, prefName, eyeName, speedName, var3D, var2D, sigVar)
x3D = groupTable.(var3D);
x2D = groupTable.(var2D);
sigMask = logical(groupTable.(sigVar));
valid = isfinite(x3D) & isfinite(x2D) & sigMask;

if any(valid)
    [p, h] = signrank(x3D(valid), x2D(valid));
    mean3D = mean(x3D(valid), 'omitnan');
    mean2D = mean(x2D(valid), 'omitnan');
    meanDelta = mean(x3D(valid) - x2D(valid), 'omitnan');
else
    h = nan;
    p = nan;
    mean3D = nan;
    mean2D = nan;
    meanDelta = nan;
end

outRow = table( ...
    string(monkeyName), ...
    string(roiName), ...
    string(prefName), ...
    string(eyeName), ...
    string(speedName), ...
    sum(valid), ...
    mean3D, ...
    mean2D, ...
    meanDelta, ...
    h, ...
    p, ...
    'VariableNames', {'Monkey', 'ROI', 'Preference', 'Eye', 'Speed', 'N', 'Mean3D', 'Mean2D', 'MeanDelta_3Dminus2D', 'h', 'p'});
end

function make_group_plots(groupTable, monkeyName, roiName, prefName)
figure('Name', sprintf('%s, %s ROI, %s-pref: Max FR histograms', monkeyName, roiName, prefName));
tl = tiledlayout(2, 2, 'TileSpacing', 'compact');
title(tl, sprintf('%s, %s ROI, %s-pref: 3D - 2D max FR', monkeyName, roiName, prefName))

plot_eye_panel(groupTable.LeftMax_3D, groupTable.LeftMax_2D_Speed1, groupTable.BothTunedRaw_Speed1, 'Left eye, Speed 1');
plot_eye_panel(groupTable.RightMax_3D, groupTable.RightMax_2D_Speed1, groupTable.BothTunedRaw_Speed1, 'Right eye, Speed 1');
plot_eye_panel(groupTable.LeftMax_3D, groupTable.LeftMax_2D_Speed2, groupTable.BothTunedRaw_Speed2, 'Left eye, Speed 2');
plot_eye_panel(groupTable.RightMax_3D, groupTable.RightMax_2D_Speed2, groupTable.BothTunedRaw_Speed2, 'Right eye, Speed 2');
end

function plot_eye_panel(x3D, x2D, sigMask, panelTitle)
nexttile
valid = isfinite(x3D) & isfinite(x2D) & logical(sigMask);
deltaVals = x3D - x2D;

if any(valid)
    histogram(deltaVals(valid))
    hold on
    pVal = signrank(x3D(valid), x2D(valid));
    medVal = median(deltaVals(valid), 'omitnan');
    xline(medVal, 'r--', 'LineWidth', 1.5);
    hold off
    title(sprintf('%s, p = %.4g, median = %.4g', panelTitle, pVal, medVal))
else
    text(0.5, 0.5, 'No valid data', 'HorizontalAlignment', 'center')
    title(panelTitle)
end
grid on
xlabel('3D - 2D max mean FR')
ylabel('Count')
end

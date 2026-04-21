%% Plot Raw 3D OD Histograms By Monkey
% Compares raw 3D OD between Jim and Clay within 4 categories:
%   - MT, 3D-pref
%   - MT, 2D-pref
%   - FST, 3D-pref
%   - FST, 2D-pref
%
% Uses the 3D OD saved in NeuroRespUnitTable and the preference split from
% AllMonkeyMIDTable.Z3D_v_Z2D. Histograms are overlaid for Jim and Clay and
% saved to C:\LoData\OD_compare2D3D.

clearvars -except NeuroRespUnitTable AllMonkeyMIDTable

bin_width = 0.05;

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

if ismember('Monocularity_3D_Max', NeuroRespUnitTable.Properties.VariableNames)
    odVar = 'Monocularity_3D_Max';
elseif ismember('Monocularity_max', NeuroRespUnitTable.Properties.VariableNames)
    odVar = 'Monocularity_max';
else
    error(['NeuroRespUnitTable does not contain Monocularity_3D_Max or Monocularity_max. ', ...
        'Run ComputeMonocularityMaxFromNeuroRespUnitTable first if needed.']);
end

requiredMIDVars = {'Z3D_v_Z2D', 'Date', 'ROI', 'Unit'};
missingMIDVars = requiredMIDVars(~ismember(requiredMIDVars, AllMonkeyMIDTable.Properties.VariableNames));
if ~isempty(missingMIDVars)
    error('AllMonkeyMIDTable is missing required variable(s): %s', strjoin(missingMIDVars, ', '));
end

if height(NeuroRespUnitTable) ~= height(AllMonkeyMIDTable)
    error('NeuroRespUnitTable and AllMonkeyMIDTable must have the same number of rows.');
end

disp('Verifying Date / ROI / Unit row alignment...')
if ~isequal(NeuroRespUnitTable.Date, AllMonkeyMIDTable.Date) || ...
        ~isequal(string(NeuroRespUnitTable.ROI), string(AllMonkeyMIDTable.ROI)) || ...
        ~isequal(NeuroRespUnitTable.Unit, AllMonkeyMIDTable.Unit)
    error('Date / ROI / Unit rows do not align between NeuroRespUnitTable and AllMonkeyMIDTable.');
end

output_dir = 'C:\LoData\OD_compare2D3D';
if ~isfolder(output_dir)
    mkdir(output_dir);
end

monkeyLabels = normalize_monkey_labels(NeuroRespUnitTable);
roiLabels = upper(strtrim(string(NeuroRespUnitTable.ROI)));
od3D = NeuroRespUnitTable.(odVar);
pref3DMask = AllMonkeyMIDTable.Z3D_v_Z2D > 0;
pref2DMask = AllMonkeyMIDTable.Z3D_v_Z2D < 0;

analysisGroups = struct( ...
    'ROI', {'MT', 'MT', 'FST', 'FST'}, ...
    'Preference', {'3D', '2D', '3D', '2D'}, ...
    'Mask', { ...
        roiLabels == "MT" & pref3DMask, ...
        roiLabels == "MT" & pref2DMask, ...
        roiLabels == "FST" & pref3DMask, ...
        roiLabels == "FST" & pref2DMask});

SummaryTable = table();

for i_group = 1:numel(analysisGroups)
    roiThis = string(analysisGroups(i_group).ROI);
    prefThis = string(analysisGroups(i_group).Preference);
    mask = analysisGroups(i_group).Mask(:);

    jimVals = od3D(mask & monkeyLabels == "JIM");
    clayVals = od3D(mask & monkeyLabels == "CLAY");

    jimVals = jimVals(isfinite(jimVals));
    clayVals = clayVals(isfinite(clayVals));

    fig = figure('Visible', 'off', ...
        'Name', sprintf('Raw 3D OD: %s ROI, %s-pref', roiThis, prefThis));
    hold on
    hJim = gobjects(1);
    hClay = gobjects(1);
    if ~isempty(jimVals)
        hJim = histogram(jimVals, 'Normalization', 'probability', ...
            'FaceColor', [0.2 0.45 0.8], 'FaceAlpha', 0.45, ...
            'BinWidth', bin_width);
        xline(median(jimVals, 'omitnan'), '--', 'Color', [0.2 0.45 0.8], 'LineWidth', 1.5);
    end
    if ~isempty(clayVals)
        hClay = histogram(clayVals, 'Normalization', 'probability', ...
            'FaceColor', [0.85 0.33 0.1], 'FaceAlpha', 0.45, ...
            'BinWidth', bin_width);
        xline(median(clayVals, 'omitnan'), '--', 'Color', [0.85 0.33 0.1], 'LineWidth', 1.5);
    end
    hold off

    if ~isempty(jimVals) && ~isempty(clayVals)
        pRankSum = ranksum(jimVals, clayVals);
    else
        pRankSum = nan;
    end

    grid on
    xlabel(strrep(odVar, '_', ' '))
    ylabel('Probability')
    title(sprintf('Raw 3D OD: %s ROI, %s-pref, ranksum p = %.4g', roiThis, prefThis, pRankSum))

    legend_handles = gobjects(0);
    legend_labels = {};
    if isgraphics(hJim)
        legend_handles(end + 1) = hJim; %#ok<AGROW>
        legend_labels{end + 1} = sprintf('Jim (n = %d)', numel(jimVals)); %#ok<AGROW>
    end
    if isgraphics(hClay)
        legend_handles(end + 1) = hClay; %#ok<AGROW>
        legend_labels{end + 1} = sprintf('Clay (n = %d)', numel(clayVals)); %#ok<AGROW>
    end
    if ~isempty(legend_handles)
        legend(legend_handles, legend_labels, 'Location', 'best')
    end

    savePath = fullfile(output_dir, make_safe_name(sprintf('Raw3DOD_%s_%s_pref_hist.png', roiThis, prefThis)));
    exportgraphics(fig, savePath, 'Resolution', 300);
    close(fig);

    SummaryTable = [SummaryTable; ...
        table(roiThis, prefThis, "Jim", numel(jimVals), median_or_nan(jimVals), pRankSum, ...
            'VariableNames', {'ROI', 'Preference', 'Monkey', 'N', 'Median3DOD', 'RankSumP'}); ...
        table(roiThis, prefThis, "Clay", numel(clayVals), median_or_nan(clayVals), pRankSum, ...
            'VariableNames', {'ROI', 'Preference', 'Monkey', 'N', 'Median3DOD', 'RankSumP'})]; %#ok<AGROW>
end

summaryPath = fullfile(output_dir, 'Raw3DOD_ByMonkey_Summary.mat');
save(summaryPath, 'SummaryTable', '-v7.3');

disp(['Saved histograms and summary to ', output_dir])
disp(SummaryTable)

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

function Analysis = analyze_session_ms_y_stim(varargin)
%ANALYZE_SESSION_MS_Y_STIM Test vertical MS differences within each session.
%
% For every recording session, fit the simple linear model
%
%   MeanMSYDeg ~ IsStim
%
% The IsStim coefficient is exactly the trial-average Stim-minus-NonStim
% vertical microsaccade displacement in degrees. The analysis uses the same
% usable MS-containing trial rows as the trialwise choice analyses.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'TrialCSV', ...
    ['C:\EM\Microsac\population_merged_12ms_no_smoothing\' ...
    'population_analysis\trialwise_ms_choice\' ...
    'trialwise_ms_choice_trials.csv'], ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'OutputDir', ...
    ['C:\EM\Microsac\population_merged_12ms_no_smoothing\' ...
    'population_analysis\session_ms_y_stim'], ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'MakePlot', true, ...
    @(x) islogical(x) && isscalar(x));
addParameter(parser, 'MinTotalTrials', 30, ...
    @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(parser, 'MinTrialsPerCondition', 10, ...
    @(x) isnumeric(x) && isscalar(x) && x >= 0);
parse(parser, varargin{:});
options = parser.Results;

trialFile = char(options.TrialCSV);
outputDir = char(options.OutputDir);
assert(isfile(trialFile), 'Trial CSV not found: %s', trialFile);
if ~isfolder(outputDir)
    mkdir(outputDir);
end

trials = readtable(trialFile, 'TextType', 'string', ...
    'VariableNamingRule', 'preserve');
required = {'UnitTableRow', 'Date', 'Monkey', 'ROI', 'IsStim', ...
    'MeanMSYDeg', 'UsableForModel'};
assert(all(ismember(required, trials.Properties.VariableNames)), ...
    'The trial table is missing required variables.');

valid = logical(trials.UsableForModel) & ...
    isfinite(trials.UnitTableRow) & isfinite(trials.MeanMSYDeg);
trials = trials(valid, :);
trials.IsStim = logical(trials.IsStim);

sessionRows = unique(trials.UnitTableRow, 'stable');
nSessions = numel(sessionRows);
rows = repmat(makeSessionRow(), nSessions, 1);

for iSession = 1:nSessions
    sessionRow = sessionRows(iSession);
    data = trials(trials.UnitTableRow == sessionRow, :);
    row = makeSessionRow();
    row.UnitTableRow = sessionRow;
    row.Date = string(data.Date(1));
    row.Monkey = string(data.Monkey(1));
    row.ROI = string(data.ROI(1));
    row.Group = row.Monkey + "-" + row.ROI;
    row.NTrials = height(data);
    row.NNonStim = nnz(~data.IsStim);
    row.NStim = nnz(data.IsStim);
    row.NonStimMeanMSYDeg = mean(data.MeanMSYDeg(~data.IsStim));
    row.StimMeanMSYDeg = mean(data.MeanMSYDeg(data.IsStim));
    row.DeltaMSYDeg = row.StimMeanMSYDeg - row.NonStimMeanMSYDeg;
    row.SessionSDMSYDeg = std(data.MeanMSYDeg);
    row.DeltaMSY_Z = row.DeltaMSYDeg / row.SessionSDMSYDeg;

    if row.NTrials < options.MinTotalTrials || ...
            row.NNonStim < options.MinTrialsPerCondition || ...
            row.NStim < options.MinTrialsPerCondition || ...
            ~isfinite(row.SessionSDMSYDeg) || row.SessionSDMSYDeg <= 0
        row.Status = "SkippedInsufficientData";
        rows(iSession) = row;
        continue
    end

    data.IsStimNumeric = double(data.IsStim);
    model = fitlm(data, 'MeanMSYDeg ~ IsStimNumeric');
    coefficient = model.Coefficients('IsStimNumeric', :);
    row.DeltaMSYDeg = coefficient.Estimate;
    row.SE = coefficient.SE;
    row.TStatistic = coefficient.tStat;
    row.DF = model.DFE;
    row.P = coefficient.pValue;
    critical = tinv(0.975, row.DF);
    row.CILower95 = row.DeltaMSYDeg - critical * row.SE;
    row.CIUpper95 = row.DeltaMSYDeg + critical * row.SE;
    row.Status = "Complete";

    [~, welchP, welchCI] = ttest2( ...
        data.MeanMSYDeg(data.IsStim), ...
        data.MeanMSYDeg(~data.IsStim), ...
        'Vartype', 'unequal');
    row.WelchP = welchP;
    row.WelchCI95 = welchCI;
    row.WelchCILower95 = welchCI(1);
    row.WelchCIUpper95 = welchCI(2);
    rows(iSession) = row;
end

SessionTable = struct2table(rows, 'AsArray', true);
complete = SessionTable.Status == "Complete" & isfinite(SessionTable.P);
SessionTable.P_FDR_All = nan(height(SessionTable), 1);
SessionTable.P_Holm_All = nan(height(SessionTable), 1);
SessionTable.P_FDR_All(complete) = benjaminiHochberg(SessionTable.P(complete));
SessionTable.P_Holm_All(complete) = holmBonferroni(SessionTable.P(complete));
SessionTable.P_FDR_Group = nan(height(SessionTable), 1);
SessionTable.P_Holm_Group = nan(height(SessionTable), 1);

groupLabels = ["Jim-MT"; "Jim-FST"; "Clay-MT"; "Clay-FST"];
groupRows = repmat(makeGroupRow(), numel(groupLabels), 1);
for iGroup = 1:numel(groupLabels)
    mask = complete & SessionTable.Group == groupLabels(iGroup);
    SessionTable.P_FDR_Group(mask) = ...
        benjaminiHochberg(SessionTable.P(mask));
    SessionTable.P_Holm_Group(mask) = ...
        holmBonferroni(SessionTable.P(mask));

    values = SessionTable.DeltaMSYDeg(mask);
    group = makeGroupRow();
    group.Group = groupLabels(iGroup);
    group.NSessions = nnz(mask);
    group.NTrials = sum(SessionTable.NTrials(mask));
    group.MeanDeltaMSYDeg = mean(values);
    group.MedianDeltaMSYDeg = median(values);
    group.SDDeltaMSYDeg = std(values);
    group.SE_MeanDeltaMSYDeg = group.SDDeltaMSYDeg / sqrt(group.NSessions);
    group.MeanDeltaCILower95 = group.MeanDeltaMSYDeg - ...
        tinv(0.975, group.NSessions - 1) * group.SE_MeanDeltaMSYDeg;
    group.MeanDeltaCIUpper95 = group.MeanDeltaMSYDeg + ...
        tinv(0.975, group.NSessions - 1) * group.SE_MeanDeltaMSYDeg;
    [~, group.MeanDeltaP] = ttest(values, 0);
    group.NPositive = nnz(values > 0);
    group.NNegative = nnz(values < 0);
    group.NRawP05 = nnz(SessionTable.P(mask) < 0.05);
    group.NFDRAll05 = nnz(SessionTable.P_FDR_All(mask) < 0.05);
    group.NHolmAll05 = nnz(SessionTable.P_Holm_All(mask) < 0.05);
    group.NFDRGroup05 = nnz(SessionTable.P_FDR_Group(mask) < 0.05);
    group.NHolmGroup05 = nnz(SessionTable.P_Holm_Group(mask) < 0.05);
    groupRows(iGroup) = group;
end
GroupSummary = struct2table(groupRows, 'AsArray', true);

outputFiles = struct;
outputFiles.Mat = fullfile(outputDir, 'session_ms_y_stim_results.mat');
outputFiles.SessionCSV = fullfile(outputDir, ...
    'session_ms_y_stim_results.csv');
outputFiles.GroupCSV = fullfile(outputDir, ...
    'session_ms_y_stim_group_summary.csv');
outputFiles.Figure = fullfile(outputDir, ...
    'session_ms_y_stim_effects.png');
writetable(SessionTable, outputFiles.SessionCSV);
writetable(GroupSummary, outputFiles.GroupCSV);

if options.MakePlot
    makeSessionFigure(SessionTable, groupLabels, outputFiles.Figure);
else
    outputFiles.Figure = "";
end

Analysis = struct;
Analysis.Question = ...
    "Within each session, does stimulation change trial-average vertical MS?";
Analysis.Model = "MeanMSYDeg ~ IsStim";
Analysis.Effect = "Stim minus NonStim mean vertical MS displacement (degrees)";
Analysis.Sample = ...
    "Usable MS-containing trials; >=30 total and >=10 per condition per session";
Analysis.MultipleComparisonPrimary = ...
    "Benjamini-Hochberg FDR and Holm correction across all complete sessions";
Analysis.SessionTable = SessionTable;
Analysis.GroupSummary = GroupSummary;
Analysis.OutputFiles = outputFiles;
save(outputFiles.Mat, 'Analysis', '-v7.3');
end


function row = makeSessionRow()
row = struct( ...
    'UnitTableRow', NaN, 'Date', "", 'Monkey', "", 'ROI', "", ...
    'Group', "", 'NTrials', NaN, 'NNonStim', NaN, 'NStim', NaN, ...
    'NonStimMeanMSYDeg', NaN, 'StimMeanMSYDeg', NaN, ...
    'DeltaMSYDeg', NaN, 'SessionSDMSYDeg', NaN, 'DeltaMSY_Z', NaN, ...
    'SE', NaN, 'TStatistic', NaN, 'DF', NaN, 'P', NaN, ...
    'CILower95', NaN, 'CIUpper95', NaN, ...
    'WelchP', NaN, 'WelchCI95', [NaN, NaN], ...
    'WelchCILower95', NaN, 'WelchCIUpper95', NaN, 'Status', "");
end


function row = makeGroupRow()
row = struct( ...
    'Group', "", 'NSessions', NaN, 'NTrials', NaN, ...
    'MeanDeltaMSYDeg', NaN, 'MedianDeltaMSYDeg', NaN, ...
    'SDDeltaMSYDeg', NaN, 'SE_MeanDeltaMSYDeg', NaN, ...
    'MeanDeltaCILower95', NaN, 'MeanDeltaCIUpper95', NaN, ...
    'MeanDeltaP', NaN, 'NPositive', NaN, 'NNegative', NaN, ...
    'NRawP05', NaN, 'NFDRAll05', NaN, 'NHolmAll05', NaN, ...
    'NFDRGroup05', NaN, 'NHolmGroup05', NaN);
end


function adjustedP = benjaminiHochberg(p)
p = p(:);
adjustedP = nan(size(p));
valid = isfinite(p);
values = p(valid);
if isempty(values)
    return
end
[sorted, order] = sort(values);
m = numel(sorted);
adjusted = sorted .* m ./ (1:m)';
adjusted = flipud(cummin(flipud(adjusted)));
adjusted = min(adjusted, 1);
restored = nan(m, 1);
restored(order) = adjusted;
adjustedP(valid) = restored;
end


function adjustedP = holmBonferroni(p)
p = p(:);
adjustedP = nan(size(p));
valid = isfinite(p);
values = p(valid);
if isempty(values)
    return
end
[sorted, order] = sort(values);
m = numel(sorted);
adjusted = sorted .* (m:-1:1)';
adjusted = cummax(adjusted);
adjusted = min(adjusted, 1);
restored = nan(m, 1);
restored(order) = adjusted;
adjustedP(valid) = restored;
end


function makeSessionFigure(sessionTable, groupLabels, outputFile)
fig = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [100, 100, 1300, 850]);
layout = tiledlayout(fig, 2, 2, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, ['Within-session vertical MS effect of stimulation: ' ...
    'MeanMSYDeg ~ IsStim']);

for iGroup = 1:numel(groupLabels)
    ax = nexttile(layout);
    mask = sessionTable.Group == groupLabels(iGroup) & ...
        sessionTable.Status == "Complete";
    data = sortrows(sessionTable(mask, :), 'DeltaMSYDeg');
    x = (1:height(data))';
    lower = data.DeltaMSYDeg - data.CILower95;
    upper = data.CIUpper95 - data.DeltaMSYDeg;
    hold(ax, 'on');
    errorbar(ax, x, data.DeltaMSYDeg, lower, upper, '.', ...
        'Color', [0.72, 0.75, 0.78], 'LineWidth', 0.8, 'CapSize', 0);
    scatter(ax, x, data.DeltaMSYDeg, 20, [0.38, 0.43, 0.48], 'filled');
    raw = data.P < 0.05;
    fdr = data.P_FDR_All < 0.05;
    holm = data.P_Holm_All < 0.05;
    scatter(ax, x(raw), data.DeltaMSYDeg(raw), 28, ...
        [0.93, 0.55, 0.20], 'filled');
    scatter(ax, x(fdr), data.DeltaMSYDeg(fdr), 38, ...
        [0.78, 0.18, 0.20], 'filled');
    scatter(ax, x(holm), data.DeltaMSYDeg(holm), 50, ...
        [0.45, 0.16, 0.58], 'd', 'filled');
    yline(ax, 0, ':k');
    yline(ax, mean(data.DeltaMSYDeg), '--', ...
        'Color', [0.16, 0.43, 0.70]);
    title(ax, sprintf('%s: %d sessions; raw/FDR/Holm = %d/%d/%d', ...
        groupLabels(iGroup), height(data), nnz(raw), nnz(fdr), nnz(holm)));
    xlabel(ax, 'Sessions sorted by effect');
    ylabel(ax, 'Stim - NonStim MS_y (deg)');
    grid(ax, 'on');
    box(ax, 'off');
end

exportgraphics(fig, outputFile, 'Resolution', 220);
close(fig);
end

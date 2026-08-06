function PlotResults = plot_grouped_simple_ms_choice_scatter(varargin)
%PLOT_GROUPED_SIMPLE_MS_CHOICE_SCATTER Plot MS_y versus binary choice.
%
% The plot uses the same trials and within-session standardized MeanMSY_Z
% predictor as analyze_grouped_ms_choice. Choice values receive small,
% reproducible vertical jitter for display only; model data are unchanged.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'TrialwiseResultsFile', ...
    ['C:\EM\Microsac\population_merged_12ms_no_smoothing\' ...
    'population_analysis\trialwise_ms_choice\' ...
    'trialwise_ms_choice_results.mat'], ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'OutputDir', ...
    ['C:\EM\Microsac\population_merged_12ms_no_smoothing\' ...
    'population_analysis\grouped_monkey_roi_ms_choice\simple_scatter'], ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'MarkerSize', 9, ...
    @(x) isscalar(x) && isfinite(x) && x > 0);
addParameter(parser, 'MarkerAlpha', 0.025, ...
    @(x) isscalar(x) && x > 0 && x <= 1);
addParameter(parser, 'ChoiceJitter', 0.055, ...
    @(x) isscalar(x) && x >= 0 && x <= 0.2);
addParameter(parser, 'RandomSeed', 31415, ...
    @(x) isscalar(x) && isfinite(x) && mod(x, 1) == 0);
parse(parser, varargin{:});
options = parser.Results;

resultsFile = char(options.TrialwiseResultsFile);
outputDir = char(options.OutputDir);
assert(isfile(resultsFile), 'Trialwise result MAT not found: %s', resultsFile);
if ~isfolder(outputDir)
    mkdir(outputDir);
end
saved = load(resultsFile, 'Analysis');
assert(isfield(saved, 'Analysis') && isfield(saved.Analysis, 'TrialTable'), ...
    'Input MAT must contain Analysis.TrialTable.');
trials = saved.Analysis.TrialTable;
valid = trials.UsableForModel & ismember(trials.Choice, [0, 1]) & ...
    isfinite(trials.MeanMSYDeg);
trials = standardizeYWithinSession(trials(valid, :));
trials = trials(isfinite(trials.MeanMSY_Z), :);

groupMonkey = ["Jim"; "Jim"; "Clay"; "Clay"];
groupROI = ["MT"; "FST"; "MT"; "FST"];
groupNames = groupMonkey + "-" + groupROI;
groupData = cell(4, 1);
allX = [];
for iGroup = 1:4
    mask = strcmpi(trials.Monkey, groupMonkey(iGroup)) & ...
        strcmpi(trials.ROI, groupROI(iGroup));
    groupData{iGroup} = trials(mask, :);
    allX = [allX; groupData{iGroup}.MeanMSY_Z]; %#ok<AGROW>
end
xLimits = [min(allX), max(allX)];
xPadding = max(0.15, 0.02 * diff(xLimits));
xLimits = xLimits + [-xPadding, xPadding];

nonStimColor = [0.18 0.45 0.78];
stimColor = [0.90 0.35 0.12];
rng(options.RandomSeed, 'twister');
groupJitter = cell(4, 1);
for iGroup = 1:4
    n = height(groupData{iGroup});
    groupJitter{iGroup} = (2 * rand(n, 1) - 1) * options.ChoiceJitter;
end

combinedFile = fullfile(outputDir, ...
    'grouped_simple_ms_y_choice_scatter_all.png');
fig = figure('Color', 'w', 'Visible', 'off', ...
    'Position', [100 100 1300 900]);
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
for iGroup = 1:4
    ax = nexttile(layout);
    plotChoiceScatter(ax, groupData{iGroup}, groupJitter{iGroup}, ...
        groupNames(iGroup), xLimits, nonStimColor, stimColor, options, true);
end
title(layout, sprintf(['Simple-model predictor versus binary choice ' ...
    '(vertical jitter = %.3g; alpha = %.3g)'], ...
    options.ChoiceJitter, options.MarkerAlpha));
exportgraphics(fig, combinedFile, 'Resolution', 200);
close(fig);

individualFiles = strings(4, 1);
for iGroup = 1:4
    individualFiles(iGroup) = fullfile(outputDir, ...
        lower(groupNames(iGroup)) + "_simple_ms_y_choice_scatter.png");
    fig = figure('Color', 'w', 'Visible', 'off', ...
        'Position', [100 100 950 650]);
    ax = axes(fig);
    plotChoiceScatter(ax, groupData{iGroup}, groupJitter{iGroup}, ...
        groupNames(iGroup), xLimits, nonStimColor, stimColor, options, true);
    exportgraphics(fig, individualFiles(iGroup), 'Resolution', 200);
    close(fig);
end

GroupCounts = table(groupNames, cellfun(@height, groupData), ...
    cellfun(@(x) nnz(~x.IsStim), groupData), ...
    cellfun(@(x) nnz(x.IsStim), groupData), ...
    'VariableNames', {'Group', 'NTrials', 'NNonStim', 'NStim'});
PlotResults = struct;
PlotResults.Parameters = options;
PlotResults.XLimits = xLimits;
PlotResults.GroupCounts = GroupCounts;
PlotResults.OutputFiles = struct('Combined', string(combinedFile), ...
    'Individual', individualFiles);
fprintf('Grouped simple-model scatter plots saved to %s\n', outputDir);
end


function trials = standardizeYWithinSession(trials)
[group, ~] = findgroups(trials.UnitTableRow);
center = splitapply(@(x) mean(x, 'omitmissing'), ...
    trials.MeanMSYDeg, group);
scale = splitapply(@(x) std(x, 'omitmissing'), ...
    trials.MeanMSYDeg, group);
trials.MeanMSY_Z = (trials.MeanMSYDeg - center(group)) ./ scale(group);
end


function plotChoiceScatter(ax, data, jitter, groupName, xLimits, ...
        nonStimColor, stimColor, options, showLegend)
hold(ax, 'on');
nonStim = ~data.IsStim;
stim = data.IsStim;
scatter(ax, data.MeanMSY_Z(nonStim), ...
    data.Choice(nonStim) + jitter(nonStim), options.MarkerSize, ...
    nonStimColor, 'filled', 'MarkerFaceAlpha', options.MarkerAlpha, ...
    'MarkerEdgeAlpha', 0, 'HandleVisibility', 'off');
scatter(ax, data.MeanMSY_Z(stim), ...
    data.Choice(stim) + jitter(stim), options.MarkerSize, ...
    stimColor, 'filled', 'MarkerFaceAlpha', options.MarkerAlpha, ...
    'MarkerEdgeAlpha', 0, 'HandleVisibility', 'off');
scatter(ax, NaN, NaN, 38, nonStimColor, 'filled', ...
    'DisplayName', sprintf('NonStim (n = %d)', nnz(nonStim)));
scatter(ax, NaN, NaN, 38, stimColor, 'filled', ...
    'DisplayName', sprintf('Stim (n = %d)', nnz(stim)));
xline(ax, 0, ':', 'Color', [0.35 0.35 0.35], ...
    'HandleVisibility', 'off');
xlim(ax, xLimits);
ylim(ax, [-0.12, 1.12]);
yticks(ax, [0, 1]);
yticklabels(ax, {'Choice 0', 'Choice 1'});
xlabel(ax, 'MeanMSY_Z (within-session SD)');
ylabel(ax, 'Binary choice (display jitter only)');
title(ax, sprintf('%s: %s trials', groupName, ...
    char(string(height(data)))));
grid(ax, 'on');
box(ax, 'on');
if showLegend
    legend(ax, 'Location', 'best');
end
end

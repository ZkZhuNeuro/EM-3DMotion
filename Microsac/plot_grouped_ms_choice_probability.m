function PlotResults = plot_grouped_ms_choice_probability(varargin)
%PLOT_GROUPED_MS_CHOICE_PROBABILITY Plot binned and fitted choice probability.
%
% Produces session-stratified simple-model probability curves and 95% CI
% effect summaries for the four monkey/ROI groups.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'TrialwiseResultsFile', ...
    ['C:\EM\Microsac\population_merged_12ms_no_smoothing\' ...
    'population_analysis\trialwise_ms_choice\' ...
    'trialwise_ms_choice_results.mat'], ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'GroupedResultsFile', ...
    ['C:\EM\Microsac\population_merged_12ms_no_smoothing\' ...
    'population_analysis\grouped_monkey_roi_ms_choice\' ...
    'grouped_ms_choice_results.mat'], ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'OutputDir', ...
    ['C:\EM\Microsac\population_merged_12ms_no_smoothing\' ...
    'population_analysis\grouped_monkey_roi_ms_choice\probability_plots'], ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'BinCount', 12, ...
    @(x) isscalar(x) && x >= 6 && mod(x, 1) == 0);
parse(parser, varargin{:});
options = parser.Results;

trialwiseFile = char(options.TrialwiseResultsFile);
groupedFile = char(options.GroupedResultsFile);
outputDir = char(options.OutputDir);
assert(isfile(trialwiseFile), 'Trialwise result MAT not found: %s', trialwiseFile);
assert(isfile(groupedFile), 'Grouped result MAT not found: %s', groupedFile);
if ~isfolder(outputDir)
    mkdir(outputDir);
end
trialwiseSaved = load(trialwiseFile, 'Analysis');
groupedSaved = load(groupedFile, 'GroupedAnalysis');
trials = trialwiseSaved.Analysis.TrialTable;
GroupedAnalysis = groupedSaved.GroupedAnalysis;
summary = GroupedAnalysis.GroupSummaryTable;

valid = trials.UsableForModel & ismember(trials.Choice, [0, 1]) & ...
    isfinite(trials.SignedCoherence) & isfinite(trials.MeanMSXDeg) & ...
    isfinite(trials.MeanMSYDeg);
trials = standardizeMSWithinSession(trials(valid, :));
trials = trials(isfinite(trials.MeanMSX_Z) & ...
    isfinite(trials.MeanMSY_Z), :);

nonStimColor = [0.18 0.45 0.78];
stimColor = [0.90 0.35 0.12];
combinedFile = fullfile(outputDir, ...
    'grouped_simple_ms_y_choice_probability.png');
individualFiles = strings(4, 1);
fig = figure('Color', 'w', 'Visible', 'off', ...
    'Position', [100 100 1350 900]);
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');

for iGroup = 1:height(summary)
    data = trials(strcmpi(trials.Monkey, summary.Monkey(iGroup)) & ...
        strcmpi(trials.ROI, summary.ROI(iGroup)), :);
    model = GroupedAnalysis.Models.Simple{iGroup};
    assert(height(data) == model.NumObservations, ...
        'Reconstructed data do not match model observations for %s.', ...
        summary.Group(iGroup));
    ax = nexttile(layout);
    plotProbabilityPanel(ax, data, model, summary(iGroup, :), ...
        nonStimColor, stimColor, options.BinCount, true);

    individualFiles(iGroup) = fullfile(outputDir, ...
        lower(summary.Group(iGroup)) + "_simple_ms_y_choice_probability.png");
    individualFig = figure('Color', 'w', 'Visible', 'off', ...
        'Position', [100 100 950 680]);
    individualAxis = axes(individualFig);
    plotProbabilityPanel(individualAxis, data, model, summary(iGroup, :), ...
        nonStimColor, stimColor, options.BinCount, true);
    exportgraphics(individualFig, individualFiles(iGroup), 'Resolution', 200);
    close(individualFig);
end
title(layout, ['Observed and session-stratified fitted choice probability ' ...
    'for the simple MS model']);
exportgraphics(fig, combinedFile, 'Resolution', 200);
close(fig);

effectFile = fullfile(outputDir, ...
    'grouped_ms_y_effects_95ci.png');
makeEffectSummaryFigure(summary, effectFile, nonStimColor, stimColor);

PlotResults = struct;
PlotResults.Parameters = options;
PlotResults.OutputFiles = struct('CombinedProbability', string(combinedFile), ...
    'IndividualProbability', individualFiles, ...
    'EffectSummary', string(effectFile));
fprintf('Grouped probability and effect figures saved to %s\n', outputDir);
end


function trials = standardizeMSWithinSession(trials)
[group, ~] = findgroups(trials.UnitTableRow);
meanX = splitapply(@(x) mean(x, 'omitmissing'), trials.MeanMSXDeg, group);
meanY = splitapply(@(x) mean(x, 'omitmissing'), trials.MeanMSYDeg, group);
scaleX = splitapply(@(x) std(x, 'omitmissing'), trials.MeanMSXDeg, group);
scaleY = splitapply(@(x) std(x, 'omitmissing'), trials.MeanMSYDeg, group);
trials.MeanMSX_Z = (trials.MeanMSXDeg - meanX(group)) ./ scaleX(group);
trials.MeanMSY_Z = (trials.MeanMSYDeg - meanY(group)) ./ scaleY(group);
end


function plotProbabilityPanel(ax, data, model, summaryRow, ...
        nonStimColor, stimColor, binCount, showLegend)
hold(ax, 'on');
x = data.MeanMSY_Z;
edges = quantile(x, linspace(0, 1, binCount + 1));
edges = unique(edges);
edges(1) = -Inf;
edges(end) = Inf;
bin = discretize(x, edges);
conditions = {~data.IsStim, data.IsStim};
colors = [nonStimColor; stimColor];
conditionNames = ["NonStim", "Stim"];

for iCondition = 1:2
    xMean = nan(numel(edges) - 1, 1);
    probability = nan(numel(edges) - 1, 1);
    lower = nan(numel(edges) - 1, 1);
    upper = nan(numel(edges) - 1, 1);
    for iBin = 1:(numel(edges) - 1)
        mask = conditions{iCondition} & bin == iBin;
        if nnz(mask) == 0
            continue
        end
        xMean(iBin) = mean(x(mask));
        successes = sum(data.Choice(mask));
        [probability(iBin), lower(iBin), upper(iBin)] = ...
            wilsonInterval(successes, nnz(mask));
    end
    errorbar(ax, xMean, probability, probability - lower, upper - probability, ...
        'o', 'LineStyle', 'none', 'Color', colors(iCondition, :), ...
        'MarkerFaceColor', colors(iCondition, :), 'MarkerSize', 5, ...
        'CapSize', 3, 'HandleVisibility', 'off');
end

fittedProbability = min(max(model.Fitted.Response, eps), 1 - eps);
linearPredictor = log(fittedProbability ./ (1 - fittedProbability));
slopes = [summaryRow.SimpleNonStimSlope, summaryRow.SimpleStimSlope];
xLimits = quantile(x, [0.005, 0.995]);
xGrid = linspace(xLimits(1), xLimits(2), 250)';
for iCondition = 1:2
    mask = conditions{iCondition};
    baselinePredictor = linearPredictor(mask) - slopes(iCondition) .* x(mask);
    probabilityGrid = mean(1 ./ (1 + exp(-(baselinePredictor' + ...
        slopes(iCondition) .* xGrid))), 2);
    plot(ax, xGrid, probabilityGrid, '-', 'Color', colors(iCondition, :), ...
        'LineWidth', 2.2, 'DisplayName', conditionNames(iCondition) + ...
        " fitted");
end

xline(ax, 0, ':', 'Color', [0.35 0.35 0.35], ...
    'HandleVisibility', 'off');
xlim(ax, xLimits);
ylim(ax, [0, 1]);
xlabel(ax, 'MeanMSY_Z (within-session SD)');
ylabel(ax, 'P(Choice = 1)');
title(ax, {sprintf('%s: binned observations (95%% CI) and fitted curves', ...
    summaryRow.Group), sprintf(['average MS slope p = %.3g (Holm %.3g); ' ...
    'MS x Stim p = %.3g (Holm %.3g)'], ...
    summaryRow.SimpleAverageSlopeP, summaryRow.SimpleAverageSlopeP_Holm, ...
    summaryRow.SimpleInteractionP, summaryRow.SimpleInteractionP_Holm)});
grid(ax, 'on');
box(ax, 'on');
if showLegend
    legend(ax, 'Location', 'best');
end
end


function [proportion, lower, upper] = wilsonInterval(successes, n)
z = 1.95996398454005;
proportion = successes / n;
denominator = 1 + z^2 / n;
center = (proportion + z^2 / (2 * n)) / denominator;
halfWidth = z * sqrt(proportion * (1 - proportion) / n + ...
    z^2 / (4 * n^2)) / denominator;
lower = max(0, center - halfWidth);
upper = min(1, center + halfWidth);
end


function makeEffectSummaryFigure(summary, outputFile, nonStimColor, stimColor)
labels = categorical(summary.Group, summary.Group, 'Ordinal', true);
simpleColor = [0.35 0.35 0.35];
adjustedColor = [0.55 0.20 0.65];
fig = figure('Color', 'w', 'Visible', 'off', ...
    'Position', [100 100 1250 850]);
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');

ax = nexttile(layout);
hold(ax, 'on');
plotTwoEstimates(ax, summary.SimpleAverageSlope, ...
    summary.SimpleAverageSlopeSE, summary.AdjustedAverageSlope, ...
    summary.AdjustedAverageSlopeSE, simpleColor, adjustedColor, labels);
ylabel(ax, 'Average MS_y slope (log odds / SD)');
title(ax, 'Does MS_y predict choice? (95% CI)');
legend(ax, {'Simple', 'Adjusted'}, 'Location', 'best');

ax = nexttile(layout);
hold(ax, 'on');
plotTwoEstimates(ax, summary.SimpleInteraction, ...
    summary.SimpleInteractionSE, summary.AdjustedInteraction, ...
    summary.AdjustedInteractionSE, simpleColor, adjustedColor, labels);
ylabel(ax, 'MS_y x Stim coefficient');
title(ax, 'Is the MS_y effect modulated by Stim? (95% CI)');
legend(ax, {'Simple', 'Adjusted'}, 'Location', 'best');

ax = nexttile(layout);
hold(ax, 'on');
plotTwoEstimates(ax, summary.SimpleNonStimSlope, ...
    summary.SimpleNonStimSlopeSE, summary.SimpleStimSlope, ...
    summary.SimpleStimSlopeSE, nonStimColor, stimColor, labels);
ylabel(ax, 'Simple-model MS_y slope');
title(ax, 'Simple model by stimulation condition (95% CI)');
legend(ax, {'NonStim', 'Stim'}, 'Location', 'best');

ax = nexttile(layout);
hold(ax, 'on');
plotTwoEstimates(ax, summary.AdjustedNonStimSlope, ...
    summary.AdjustedNonStimSlopeSE, summary.AdjustedStimSlope, ...
    summary.AdjustedStimSlopeSE, nonStimColor, stimColor, labels);
ylabel(ax, 'Adjusted-model MS_y slope');
title(ax, 'Adjusted model by stimulation condition (95% CI)');
legend(ax, {'NonStim', 'Stim'}, 'Location', 'best');

title(layout, ['Grouped MS_y effects on choice: estimates and ' ...
    '95% confidence intervals']);
exportgraphics(fig, outputFile, 'Resolution', 200);
close(fig);
end


function plotTwoEstimates(ax, estimate1, se1, estimate2, se2, ...
        color1, color2, labels)
errorbar(ax, (1:4) - 0.10, estimate1, 1.96 .* se1, 'o', ...
    'Color', color1, 'MarkerFaceColor', color1, 'LineWidth', 1.2);
errorbar(ax, (1:4) + 0.10, estimate2, 1.96 .* se2, 'o', ...
    'Color', color2, 'MarkerFaceColor', color2, 'LineWidth', 1.2);
yline(ax, 0, ':', 'HandleVisibility', 'off');
set(ax, 'XTick', 1:4, 'XTickLabel', labels);
xlim(ax, [0.5, 4.5]);
grid(ax, 'on');
box(ax, 'on');
end

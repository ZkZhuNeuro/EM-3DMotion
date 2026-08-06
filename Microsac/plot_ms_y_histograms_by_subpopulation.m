function HistogramResults = plot_ms_y_histograms_by_subpopulation(varargin)
%PLOT_MS_Y_HISTOGRAMS_BY_SUBPOPULATION Plot session-level MS_y distributions.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'LongTableFile', ...
    'C:\EM\Microsac\ms_behavior_bias\ms_behavior_bias_long_table.csv', ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'OutputDir', ...
    'C:\EM\Microsac\ms_behavior_bias_by_monkey_roi', ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'BinCount', 12, ...
    @(x) isscalar(x) && x >= 5 && mod(x, 1) == 0);
parse(parser, varargin{:});
options = parser.Results;

longTableFile = char(options.LongTableFile);
outputDir = char(options.OutputDir);
assert(isfile(longTableFile), 'Long table not found: %s', longTableFile);
if ~isfolder(outputDir)
    mkdir(outputDir);
end

longTable = readtable(longTableFile, 'TextType', 'string');
requiredVariables = {'BehaviorRow', 'SessionKey', 'Monkey', 'ROI', ...
    'CueIndex', 'condition', 'MS_y'};
assert(all(ismember(requiredVariables, longTable.Properties.VariableNames)), ...
    'The long table is missing required variables.');

% MS_y is repeated across four cues; cue 1 gives one row per session-condition.
valuesTable = longTable(longTable.CueIndex == 1, ...
    {'BehaviorRow', 'SessionKey', 'Monkey', 'ROI', 'condition', 'MS_y'});
valuesTable = valuesTable(isfinite(valuesTable.MS_y), :);
valuesTable.condition = categorical(valuesTable.condition, ...
    ["NonStim", "Stim"]);

groupMonkey = ["Jim"; "Jim"; "Clay"; "Clay"];
groupROI = ["MT"; "FST"; "MT"; "FST"];
groupName = groupMonkey + "_" + groupROI;
nGroups = numel(groupName);
summaryRows = repmat(makeSummaryRow(), nGroups * 2, 1);

outputFiles = struct;
outputFiles.PNG = fullfile(outputDir, ...
    'ms_y_histograms_by_subpopulation.png');
outputFiles.FIG = fullfile(outputDir, ...
    'ms_y_histograms_by_subpopulation.fig');
outputFiles.SummaryCSV = fullfile(outputDir, ...
    'ms_y_histogram_summary.csv');
outputFiles.ValuesCSV = fullfile(outputDir, ...
    'ms_y_session_condition_values.csv');

figureHandle = figure('Color', 'w', 'Position', [100, 100, 1180, 820]);
layout = tiledlayout(figureHandle, 2, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
colors = [0.18, 0.20, 0.23; 0.78, 0.18, 0.16];

for iGroup = 1:nGroups
    groupMask = strcmpi(valuesTable.Monkey, groupMonkey(iGroup)) & ...
        strcmpi(valuesTable.ROI, groupROI(iGroup));
    groupTable = valuesTable(groupMask, :);
    nonStim = groupTable.MS_y(groupTable.condition == 'NonStim');
    stim = groupTable.MS_y(groupTable.condition == 'Stim');
    pooled = [nonStim; stim];
    edges = makeBinEdges(pooled, options.BinCount);

    axisHandle = nexttile(layout);
    hold(axisHandle, 'on');
    histogram(axisHandle, nonStim, edges, 'Normalization', 'probability', ...
        'FaceColor', colors(1, :), 'EdgeColor', colors(1, :), ...
        'FaceAlpha', 0.52, 'LineWidth', 0.7, 'DisplayName', 'NonStim');
    histogram(axisHandle, stim, edges, 'Normalization', 'probability', ...
        'FaceColor', colors(2, :), 'EdgeColor', colors(2, :), ...
        'FaceAlpha', 0.48, 'LineWidth', 0.7, 'DisplayName', 'Stim');
    xline(axisHandle, 0, ':', 'Color', [0.25, 0.25, 0.25], ...
        'LineWidth', 1.2, 'HandleVisibility', 'off');
    xline(axisHandle, median(nonStim), '-', 'Color', colors(1, :), ...
        'LineWidth', 1.8, 'HandleVisibility', 'off');
    xline(axisHandle, median(stim), '-', 'Color', colors(2, :), ...
        'LineWidth', 1.8, 'HandleVisibility', 'off');
    negativeNonStim = 100 * mean(nonStim < 0);
    negativeStim = 100 * mean(stim < 0);
    title(axisHandle, {char(strrep(groupName(iGroup), "_", " ")), ...
        sprintf('Negative: NonStim %.1f%%, Stim %.1f%%', ...
        negativeNonStim, negativeStim)});
    xlabel(axisHandle, 'MS_y: mean vertical displacement (deg)');
    ylabel(axisHandle, 'Probability per bin');
    grid(axisHandle, 'on');
    box(axisHandle, 'off');
    axisHandle.Toolbar.Visible = 'off';
    if iGroup == 1
        legend(axisHandle, 'Location', 'best');
    end

    summaryRows(2 * iGroup - 1) = summarizeValues(groupName(iGroup), ...
        groupMonkey(iGroup), groupROI(iGroup), "NonStim", nonStim);
    summaryRows(2 * iGroup) = summarizeValues(groupName(iGroup), ...
        groupMonkey(iGroup), groupROI(iGroup), "Stim", stim);
end

title(layout, ['Distribution of session-average microsaccade ' ...
    'vertical displacement']);
exportgraphics(figureHandle, outputFiles.PNG, 'Resolution', 220);
savefig(figureHandle, outputFiles.FIG);
close(figureHandle);

SummaryTable = struct2table(summaryRows, 'AsArray', true);
writetable(SummaryTable, outputFiles.SummaryCSV);
writetable(valuesTable, outputFiles.ValuesCSV);

HistogramResults = struct;
HistogramResults.Description = ["One MS_y value per session and condition. ", ...
    "Solid colored lines mark condition medians; dotted line marks zero."];
HistogramResults.ValuesTable = valuesTable;
HistogramResults.SummaryTable = SummaryTable;
HistogramResults.OutputFiles = outputFiles;
save(fullfile(outputDir, 'ms_y_histogram_results.mat'), ...
    'HistogramResults', '-v7.3');

disp(SummaryTable);
fprintf('Histogram saved to %s\n', outputFiles.PNG);
end


function edges = makeBinEdges(values, binCount)
minimum = min(values);
maximum = max(values);
if minimum == maximum
    padding = max(abs(minimum) * 0.05, 1e-4);
else
    padding = 0.025 * (maximum - minimum);
end
edges = linspace(minimum - padding, maximum + padding, binCount + 1);
end


function row = makeSummaryRow()
row = struct('Subpopulation', "", 'Monkey', "", 'ROI', "", ...
    'Condition', "", 'N', NaN, 'NegativeCount', NaN, ...
    'NegativePercent', NaN, 'MeanMS_yDeg', NaN, ...
    'MedianMS_yDeg', NaN, 'MinimumMS_yDeg', NaN, ...
    'MaximumMS_yDeg', NaN);
end


function row = summarizeValues(groupName, monkey, roi, condition, values)
row = makeSummaryRow();
row.Subpopulation = groupName;
row.Monkey = monkey;
row.ROI = roi;
row.Condition = condition;
row.N = numel(values);
row.NegativeCount = nnz(values < 0);
row.NegativePercent = 100 * mean(values < 0);
row.MeanMS_yDeg = mean(values);
row.MedianMS_yDeg = median(values);
row.MinimumMS_yDeg = min(values);
row.MaximumMS_yDeg = max(values);
end

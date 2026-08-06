function HistogramResults = plot_population_ms_metric_histograms(varargin)
%PLOT_POPULATION_MS_METRIC_HISTOGRAMS Plot four MS metrics by subpopulation.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'DirectionStatsFile', "", ...
    @(x) ischar(x) || (isstring(x) && isscalar(x)));
addParameter(parser, 'SummaryFile', "", ...
    @(x) ischar(x) || (isstring(x) && isscalar(x)));
addParameter(parser, 'OutputDir', "", ...
    @(x) ischar(x) || (isstring(x) && isscalar(x)));
addParameter(parser, 'BinCount', 12, ...
    @(x) isscalar(x) && x >= 5 && mod(x, 1) == 0);
parse(parser, varargin{:});
options = parser.Results;

directionStatsFile = char(options.DirectionStatsFile);
summaryFile = char(options.SummaryFile);
outputDir = char(options.OutputDir);
assert(isfile(directionStatsFile), ...
    'Direction-statistics file not found: %s', directionStatsFile);
assert(isfile(summaryFile), 'Summary file not found: %s', summaryFile);
if ~isfolder(outputDir)
    mkdir(outputDir);
end

directions = readtable(directionStatsFile, 'TextType', 'string');
summaries = readtable(summaryFile, 'TextType', 'string');
directionKey = string(directions.UnitTableRow) + "|" + ...
    lower(strip(string(directions.TrialType)));
summaryKey = string(summaries.UnitTableRow) + "|" + ...
    lower(strip(string(summaries.TrialType)));
assert(numel(unique(directionKey)) == height(directions), ...
    'Direction table has duplicate session-condition rows.');
assert(numel(unique(summaryKey)) == height(summaries), ...
    'Summary table has duplicate session-condition rows.');
[found, summaryRows] = ismember(directionKey, summaryKey);
assert(all(found), 'At least one direction row was absent from the summary table.');

MetricValuesTable = table(directions.UnitTableRow, directions.Date, ...
    string(directions.Monkey), string(directions.ROI), ...
    categorical(string(directions.TrialType), ["NonStim", "Stim"]), ...
    directions.EventCount, directions.MeanDisplacementYDeg, ...
    directions.MeanDisplacementXDeg, summaries.MeanRateHz(summaryRows), ...
    summaries.MeanAmplitudeDeg(summaryRows), ...
    'VariableNames', {'UnitTableRow', 'Date', 'Monkey', 'ROI', ...
    'Condition', 'EventCount', 'MS_y', 'MS_x', 'MS_FrequencyHz', ...
    'MS_MagnitudeDeg'});

metrics = struct( ...
    'Variable', {'MS_y', 'MS_x', 'MS_FrequencyHz', 'MS_MagnitudeDeg'}, ...
    'FileStem', {'vertical_displacement', 'horizontal_displacement', ...
    'frequency', 'magnitude'}, ...
    'Title', {'Vertical displacement', 'Horizontal displacement', ...
    'Microsaccade frequency', 'Microsaccade magnitude'}, ...
    'XLabel', {'Mean vertical displacement, MS_y (deg)', ...
    'Mean horizontal displacement, MS_x (deg)', ...
    'Mean microsaccade frequency (Hz)', ...
    'Mean microsaccade magnitude (deg)'}, ...
    'ShowNegative', {true, true, false, false});
groupMonkey = ["Jim"; "Jim"; "Clay"; "Clay"];
groupROI = ["MT"; "FST"; "MT"; "FST"];
groupName = groupMonkey + "_" + groupROI;
conditionNames = ["NonStim", "Stim"];
colors = [0.18, 0.20, 0.23; 0.78, 0.18, 0.16];
summaryRowsAll = repmat(makeMetricSummaryRow(), 0, 1);
outputFiles = struct;

for iMetric = 1:numel(metrics)
    metric = metrics(iMetric);
    figureHandle = figure('Visible', 'off', 'Color', 'w', ...
        'Position', [100, 100, 1180, 820]);
    layout = tiledlayout(figureHandle, 2, 2, 'TileSpacing', 'compact', ...
        'Padding', 'compact');
    title(layout, metric.Title + " by monkey and ROI");
    for iGroup = 1:numel(groupName)
        groupMask = strcmpi(MetricValuesTable.Monkey, groupMonkey(iGroup)) & ...
            strcmpi(MetricValuesTable.ROI, groupROI(iGroup));
        groupTable = MetricValuesTable(groupMask, :);
        nonStim = groupTable.(metric.Variable)( ...
            groupTable.Condition == 'NonStim');
        stim = groupTable.(metric.Variable)(groupTable.Condition == 'Stim');
        nonStim = nonStim(isfinite(nonStim));
        stim = stim(isfinite(stim));
        edges = makeMetricBinEdges([nonStim; stim], options.BinCount);

        ax = nexttile(layout);
        hold(ax, 'on');
        histogram(ax, nonStim, edges, 'Normalization', 'probability', ...
            'FaceColor', colors(1, :), 'EdgeColor', colors(1, :), ...
            'FaceAlpha', 0.52, 'LineWidth', 0.7, 'DisplayName', 'NonStim');
        histogram(ax, stim, edges, 'Normalization', 'probability', ...
            'FaceColor', colors(2, :), 'EdgeColor', colors(2, :), ...
            'FaceAlpha', 0.48, 'LineWidth', 0.7, 'DisplayName', 'Stim');
        xline(ax, median(nonStim), '-', 'Color', colors(1, :), ...
            'LineWidth', 1.8, 'HandleVisibility', 'off');
        xline(ax, median(stim), '-', 'Color', colors(2, :), ...
            'LineWidth', 1.8, 'HandleVisibility', 'off');
        if metric.ShowNegative || min(edges) <= 0
            xline(ax, 0, ':', 'Color', [0.25, 0.25, 0.25], ...
                'LineWidth', 1.2, 'HandleVisibility', 'off');
        end
        if metric.ShowNegative
            detail = sprintf('Negative: NonStim %.1f%%, Stim %.1f%%', ...
                100 * mean(nonStim < 0), 100 * mean(stim < 0));
        else
            detail = sprintf('N: NonStim %d, Stim %d', ...
                numel(nonStim), numel(stim));
        end
        title(ax, {char(strrep(groupName(iGroup), "_", " ")), detail});
        xlabel(ax, metric.XLabel);
        ylabel(ax, 'Probability per bin');
        grid(ax, 'on');
        box(ax, 'off');
        ax.Toolbar.Visible = 'off';
        if iGroup == 1
            legend(ax, 'Location', 'best');
        end

        for iCondition = 1:2
            if iCondition == 1
                values = nonStim;
            else
                values = stim;
            end
            summaryRowsAll(end + 1, 1) = summarizeMetric( ...
                metric.Variable, groupName(iGroup), groupMonkey(iGroup), ...
                groupROI(iGroup), conditionNames(iCondition), values); %#ok<AGROW>
        end
    end
    pngFile = fullfile(outputDir, ...
        ['ms_' metric.FileStem '_histograms_by_subpopulation.png']);
    figFile = fullfile(outputDir, ...
        ['ms_' metric.FileStem '_histograms_by_subpopulation.fig']);
    exportgraphics(figureHandle, pngFile, 'Resolution', 220);
    savefig(figureHandle, figFile);
    close(figureHandle);
    outputFiles.(metric.Variable + "PNG") = pngFile;
    outputFiles.(metric.Variable + "FIG") = figFile;
end

MetricSummaryTable = struct2table(summaryRowsAll, 'AsArray', true);
outputFiles.ValuesCSV = fullfile(outputDir, ...
    'population_ms_session_condition_metrics.csv');
outputFiles.SummaryCSV = fullfile(outputDir, ...
    'population_ms_metric_histogram_summary.csv');
writetable(MetricValuesTable, outputFiles.ValuesCSV);
writetable(MetricSummaryTable, outputFiles.SummaryCSV);

HistogramResults = struct;
HistogramResults.MetricValuesTable = MetricValuesTable;
HistogramResults.MetricSummaryTable = MetricSummaryTable;
HistogramResults.OutputFiles = outputFiles;
save(fullfile(outputDir, 'population_ms_metric_histograms.mat'), ...
    'HistogramResults', '-v7.3');
end


function edges = makeMetricBinEdges(values, binCount)
values = values(isfinite(values));
assert(~isempty(values), 'No finite values were available for a histogram.');
minimum = min(values);
maximum = max(values);
if minimum == maximum
    padding = max(abs(minimum) * 0.05, 1e-4);
else
    padding = 0.025 * (maximum - minimum);
end
edges = linspace(minimum - padding, maximum + padding, binCount + 1);
end


function row = makeMetricSummaryRow()
row = struct('Metric', "", 'Subpopulation', "", 'Monkey', "", ...
    'ROI', "", 'Condition', "", 'N', NaN, 'NegativeCount', NaN, ...
    'NegativePercent', NaN, 'Mean', NaN, 'Median', NaN, ...
    'Minimum', NaN, 'Maximum', NaN);
end


function row = summarizeMetric(metric, group, monkey, roi, condition, values)
row = makeMetricSummaryRow();
row.Metric = metric;
row.Subpopulation = group;
row.Monkey = monkey;
row.ROI = roi;
row.Condition = condition;
row.N = numel(values);
row.NegativeCount = nnz(values < 0);
row.NegativePercent = 100 * mean(values < 0);
row.Mean = mean(values);
row.Median = median(values);
row.Minimum = min(values);
row.Maximum = max(values);
end

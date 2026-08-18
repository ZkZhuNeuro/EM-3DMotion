function OutputPaths = MakeFSTPDIAndBODIPaperFigure( ...
        LoResultTable, EMResultTable, StatisticsTable, outputBase)
%MAKEFSTPDIANDBODIPAPERFIGURE Create paper-ready Lo-versus-EM panels.

arguments
    LoResultTable table
    EMResultTable table
    StatisticsTable table
    outputBase (1, 1) string
end

outputDirectory = fileparts(outputBase);
if strlength(outputDirectory) > 0 && ~isfolder(outputDirectory)
    mkdir(outputDirectory);
end

fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'inches', ...
    'Position', [1, 1, 7.25, 3.55]);
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
title(layout, 'FST 3D pattern-tuning indices: Lo versus EM', ...
    'FontName', 'Arial', 'FontSize', 11, 'FontWeight', 'bold');

allValues = [ ...
    LoResultTable.PDI(LoResultTable.Valid_PDI); ...
    EMResultTable.PDI(EMResultTable.Valid_PDI); ...
    LoResultTable.BODI(LoResultTable.Valid_BODI); ...
    EMResultTable.BODI(EMResultTable.Valid_BODI)];
yLower = min(-0.30, floor((min(allValues) - 0.03) * 10) / 10);
yUpper = max(0.72, ceil((max(allValues) + 0.18) * 10) / 10);

plot_metric(nexttile(layout), LoResultTable, EMResultTable, ...
    StatisticsTable, "PDI", "A", yLower, yUpper);
plot_metric(nexttile(layout), LoResultTable, EMResultTable, ...
    StatisticsTable, "BODI", "B", yLower, yUpper);

OutputPaths = struct();
OutputPaths.PNG = outputBase + ".png";
OutputPaths.PDF = outputBase + ".pdf";
OutputPaths.SVG = outputBase + ".svg";
exportgraphics(fig, OutputPaths.PNG, 'Resolution', 600, ...
    'BackgroundColor', 'white');
exportgraphics(fig, OutputPaths.PDF, 'ContentType', 'vector', ...
    'BackgroundColor', 'white');
exportgraphics(fig, OutputPaths.SVG, 'ContentType', 'vector', ...
    'BackgroundColor', 'white');
end

function plot_metric(ax, LoResultTable, EMResultTable, StatisticsTable, ...
        metricName, panelLetter, yLower, yUpper)
row = StatisticsTable.Metric == metricName;
if nnz(row) ~= 1
    error('MakeFSTPDIAndBODIPaperFigure:StatisticsLookup', ...
        'Expected exactly one %s statistics row.', metricName);
end
stats = StatisticsTable(row, :);
lo = valid_values(LoResultTable, metricName);
em = valid_values(EMResultTable, metricName);
loColor = [0, 114, 178] / 255;
emColor = [213, 94, 0] / 255;

hold(ax, 'on');
plot_distribution(ax, lo, 1, loColor, 'o');
plot_distribution(ax, em, 2, emColor, 's');
yline(ax, 0, '--', 'Color', [0.25, 0.25, 0.25], ...
    'LineWidth', 0.9, 'HandleVisibility', 'off');

ax.XLim = [0.55, 2.45];
ax.YLim = [yLower, yUpper];
ax.XTick = [1, 2];
ax.XTickLabel = {sprintf('Lo (n = %d)', numel(lo)), ...
    sprintf('EM (n = %d)', numel(em))};
ax.FontName = 'Arial';
ax.FontSize = 8.5;
ax.LineWidth = 0.8;
ax.TickDir = 'out';
ax.Box = 'off';
ax.YGrid = 'on';
ax.GridAlpha = 0.12;
ylabel(ax, 'Index value');

if metricName == "PDI"
    definition = 'perspective vs lateral';
else
    definition = 'combined vs stereoscopic';
end
title(ax, sprintf('%s  %s (%s)', panelLetter, metricName, definition), ...
    'FontName', 'Arial', 'FontSize', 9.5, 'FontWeight', 'bold');

comparisonText = sprintf([ ...
    '\\Delta mean = %+.3f; g = %+.2f [%+.2f, %+.2f]\n' ...
    'Cliff''s \\delta = %+.2f [%+.2f, %+.2f]; p_{adj} = %s'], ...
    stats.MeanDifference_EM_Minus_Lo, stats.HedgesG_EM_Minus_Lo, ...
    stats.HedgesG_CI95_Lower, stats.HedgesG_CI95_Upper, ...
    stats.CliffsDelta_EM_Minus_Lo, stats.CliffsDelta_CI95_Lower, ...
    stats.CliffsDelta_CI95_Upper, format_p_value(stats.PValue_Bonferroni));
text(ax, 1.5, yUpper - 0.035 * (yUpper - yLower), comparisonText, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
    'FontName', 'Arial', 'FontSize', 7.5, 'Interpreter', 'tex', ...
    'BackgroundColor', 'white', 'Margin', 2, 'EdgeColor', [0.82, 0.82, 0.82]);
hold(ax, 'off');
end

function plot_distribution(ax, values, xCenter, color, marker)
n = numel(values);
goldenRatioConjugate = (sqrt(5) - 1) / 2;
jitter = 0.16 * (2 * mod((1:n)' * goldenRatioConjugate, 1) - 1);
scatter(ax, xCenter + jitter, values, 18, color, marker, 'filled', ...
    'MarkerFaceAlpha', 0.46, 'MarkerEdgeColor', 'none');

quartiles = prctile(values, [25, 75]);
valueMedian = median(values);
valueMean = mean(values);
valueSEM = std(values) / sqrt(n);
criticalT = tinv(0.975, n - 1);
meanCI = valueMean + [-1, 1] * criticalT * valueSEM;
plot(ax, [xCenter, xCenter], quartiles, '-', 'Color', color, ...
    'LineWidth', 7);
plot(ax, [xCenter - 0.13, xCenter + 0.13], ...
    [valueMedian, valueMedian], '-', 'Color', [0.08, 0.08, 0.08], ...
    'LineWidth', 1.8);
errorbar(ax, xCenter + 0.20, valueMean, valueMean - meanCI(1), ...
    meanCI(2) - valueMean, 'd', 'Color', color * 0.72, ...
    'MarkerFaceColor', 'white', 'MarkerEdgeColor', color * 0.72, ...
    'MarkerSize', 4.5, 'LineWidth', 1.05, 'CapSize', 5);
end

function values = valid_values(T, metricName)
validName = "Valid_" + metricName;
values = T.(metricName)(T.(validName) & isfinite(T.(metricName)));
end

function label = format_p_value(pValue)
if ~isfinite(pValue)
    label = 'NaN';
elseif pValue < 0.001
    label = sprintf('%.2e', pValue);
else
    label = sprintf('%.3f', pValue);
end
end

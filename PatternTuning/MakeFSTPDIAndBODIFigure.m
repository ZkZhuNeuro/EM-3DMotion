function MakeFSTPDIAndBODIFigure(T, zeroTests, outputPath, figureTitle, options)
%MAKEFSTPDIANDBODIFIGURE Plot pooled PDI and BODI histograms.

arguments
    T table
    zeroTests table
    outputPath (1, 1) string
    figureTitle (1, 1) string
    options.PDIEdges double = []
    options.BODIEdges double = []
end

if isempty(options.PDIEdges)
    pdiEdges = histogram_edges(T.PDI(T.Valid_PDI), 0.1);
else
    pdiEdges = options.PDIEdges;
end
if isempty(options.BODIEdges)
    bodiEdges = histogram_edges(T.BODI(T.Valid_BODI), 0.1);
else
    bodiEdges = options.BODIEdges;
end

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 1100, 480]);
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, figureTitle, 'Interpreter', 'none');

plot_histogram(layout, T, zeroTests, "PDI", pdiEdges, [0.20, 0.45, 0.70]);
plot_histogram(layout, T, zeroTests, "BODI", bodiEdges, [0.25, 0.58, 0.48]);
exportgraphics(fig, outputPath, 'Resolution', 180);
end

function plot_histogram(layout, T, zeroTests, metricName, edges, color)
nexttile(layout);
validName = "Valid_" + metricName;
values = T.(metricName)(T.(validName) & isfinite(T.(metricName)));
histogram(values, edges, 'Normalization', 'probability', ...
    'FaceColor', color, 'EdgeColor', color * 0.72, ...
    'FaceAlpha', 0.72, 'LineWidth', 0.8);
xline(0, 'k--', 'LineWidth', 1.2);
xlim([edges(1), edges(end)]);
xlabel(metricName);
ylabel('Proportion of neurons');
row = zeroTests.Metric == metricName;
title({sprintf('%s: mean %.3f, median %.3f', metricName, ...
    mean(values, 'omitnan'), median(values, 'omitnan')), ...
    sprintf('Rank-sum vs 0: p=%s; Bonferroni p=%s', ...
    format_p_value(zeroTests.PValue(row)), ...
    format_p_value(zeroTests.PValue_Bonferroni(row)))});
box off;
end

function edges = histogram_edges(values, binWidth)
values = values(isfinite(values));
if isempty(values)
    edges = [-binWidth, 0, binWidth];
    return
end
lowerEdge = floor(min([values; 0]) / binWidth) * binWidth;
upperEdge = ceil(max([values; 0]) / binWidth) * binWidth;
if upperEdge <= lowerEdge
    upperEdge = lowerEdge + binWidth;
end
edges = lowerEdge:binWidth:upperEdge;
end

function label = format_p_value(pValue)
if isempty(pValue) || ~isfinite(pValue)
    label = 'NaN';
elseif pValue < 0.001
    label = sprintf('%.2e', pValue);
else
    label = sprintf('%.3f', pValue);
end
end

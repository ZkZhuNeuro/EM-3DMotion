function MakeFSTBODIFigure(T, zeroTests, outputPath, figureTitle)
%MAKEFSTBODIFIGURE Plot the one-value-per-neuron 3D-only BODI analysis.

arguments
    T table
    zeroTests table
    outputPath (1, 1) string
    figureTitle (1, 1) string
end

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 1150, 500]);
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, figureTitle, 'Interpreter', 'none');

nexttile(layout);
valid = T.Valid_BODI & isfinite(T.BODI);
edges = histogram_edges(T.BODI(valid), 0.1);
plot_preference_histogram(T.BODI, valid, T.CombinedCuePreference, edges);
xline(0, 'k--', 'LineWidth', 1.2, 'HandleVisibility', 'off');
xlim([edges(1), edges(end)]);
xlabel('BODI');
ylabel('Proportion within preference group');
title({sprintf('BODI: mean %.3f, median %.3f', ...
    mean(T.BODI(valid), 'omitnan'), median(T.BODI(valid), 'omitnan')), ...
    zero_test_subtitle(zeroTests)});
box off;

nexttile(layout);
hold on;
preferences = ["Toward", "Away"];
for preference = preferences
    mask = valid & T.CombinedCuePreference == preference;
    scatter(T.Stereo_FR(mask), T.Combined_FR(mask), 44, 'filled', ...
        'MarkerFaceColor', preference_color(preference), ...
        'MarkerFaceAlpha', 0.65, ...
        'DisplayName', sprintf('%s (n=%d)', preference, nnz(mask)));
end
allValues = [T.Stereo_FR(valid); T.Combined_FR(valid); 0];
lowerLimit = min(allValues);
upperLimit = max(allValues);
padding = max((upperLimit - lowerLimit) * 0.04, 0.5);
limits = [lowerLimit - padding, upperLimit + padding];
plot(limits, limits, 'k--', 'LineWidth', 1.1, 'HandleVisibility', 'off');
xlim(limits);
ylim(limits);
axis square;
xlabel('Stereoscopic firing rate (cue 4)');
ylabel('Combined firing rate (cue 1)');
title('Preferred-endpoint combined versus stereoscopic response');
legend('Location', 'best');
box off;
hold off;

exportgraphics(fig, outputPath, 'Resolution', 180);
end

function label = zero_test_subtitle(results)
towardP = results.PValue(results.Preference == "Toward");
awayP = results.PValue(results.Preference == "Away");
label = sprintf('Rank-sum vs 0: toward p=%s; away p=%s', ...
    format_p_value(towardP), format_p_value(awayP));
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

function plot_preference_histogram(values, valid, preference, edges)
values = values(valid);
preference = preference(valid);
hold on;
for target = ["Toward", "Away"]
    mask = preference == target;
    if any(mask)
        histogram(values(mask), edges, 'Normalization', 'probability', ...
            'FaceColor', preference_color(target), ...
            'EdgeColor', preference_color(target), ...
            'FaceAlpha', 0.42, 'EdgeAlpha', 0.78, ...
            'DisplayName', sprintf('%s (n=%d)', target, nnz(mask)));
    end
end
legend('Location', 'best');
hold off;
end

function color = preference_color(preference)
if preference == "Toward"
    color = [0.84, 0.28, 0.20];
else
    color = [0.18, 0.47, 0.72];
end
end

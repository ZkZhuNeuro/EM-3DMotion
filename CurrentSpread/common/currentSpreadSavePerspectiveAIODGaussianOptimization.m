function figureHandles = currentSpreadSavePerspectiveAIODGaussianOptimization( ...
        result, outputDir)
%CURRENTSPREADSAVEPERSPECTIVEAIODGAUSSIANOPTIMIZATION Save plots and tables.

arguments
    result (1, 1) struct
    outputDir (1, :) char
end

if ~isfolder(outputDir)
    mkdir(outputDir);
end

channelColor = [0.05 0.35 0.70];
frColor = [0.72 0.20 0.22];
dominantColor = [254 191 15] ./ 255;
nonDominantColor = [110 205 221] ./ 255;
alphaFloor = 0.18;
odForFullOpacity = 0.20;

optimizationFigure = figure('Color', 'w', ...
    'Name', 'perspective_ai_od_sigma_optimization', ...
    'Position', [100 80 1250 850]);
layout = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
curveAxes = nexttile(layout, [1 2]);
hold(curveAxes, 'on')
plotCurve(curveAxes, result.channel, channelColor);
plotCurve(curveAxes, result.fr, frColor);
yline(curveAxes, result.methods(1).selectionCVR2, '--', ...
    'Color', [0.2 0.2 0.2], 'LineWidth', 1.5, ...
    'DisplayName', sprintf('Original baseline (CV R^2 = %.3f)', ...
    result.methods(1).selectionCVR2));
set(curveAxes, 'XScale', 'log', 'FontSize', 12, 'LineWidth', 1)
grid(curveAxes, 'on')
box(curveAxes, 'off')
xlabel(curveAxes, 'Gaussian \sigma (channel positions)')
ylabel(curveAxes, 'Selection cross-validated R^2')
title(curveAxes, 'Perspective-cue AI-by-OD sigma selection')
legend(curveAxes, 'Location', 'bestoutside')

plotWeights(nexttile(layout), result, result.channel, channelColor, ...
    'Channel-AI best Gaussian weights');
plotWeights(nexttile(layout), result, result.fr, frColor, ...
    'FR meta-tuning best Gaussian weights');
sgtitle(layout, sprintf([ ...
    'Jim MT 2D: Merged Delta Bias ~ AI + AI:OD; %d x %d-fold ' ...
    'session-grouped CV (N = %d)'], result.numRepeats, result.numFolds, ...
    result.sessionCount), 'FontWeight', 'bold');

optimizationBase = 'perspective_ai_od_sigma_optimization';
savefig(optimizationFigure, fullfile(outputDir, [optimizationBase '.fig']));
exportgraphics(optimizationFigure, ...
    fullfile(outputDir, [optimizationBase '.png']), 'Resolution', 300);

scatterFigure = figure('Color', 'w', ...
    'Name', 'perspective_ai_od_optimized_scatter', ...
    'Position', [50 100 2100 720]);
scatterLayout = tiledlayout(1, 3, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
xPlot = linspace(-1, 1, 200);

for methodIndex = 1:numel(result.methods)
    method = result.methods(methodIndex);
    points = method.pointTable;
    axesHandle = nexttile(scatterLayout);
    hold(axesHandle, 'on')
    plot(axesHandle, [-1 1], [0 0], 'k--', 'HandleVisibility', 'off');
    plot(axesHandle, [0 0], [-2.2 2.2], 'k--', 'HandleVisibility', 'off');
    fitHandle = plot(axesHandle, xPlot, ...
        method.weightedIntercept + method.weightedSlope .* xPlot, ...
        '-', 'Color', [0.15 0.15 0.15], 'LineWidth', 2.5, ...
        'DisplayName', 'Descriptive OD-weighted AI-only fit');

    dominant = points.EyeCondition == "Dominant";
    nonDominant = points.EyeCondition == "NonDominant";
    dominantScatter = scatter(axesHandle, points.AI(dominant), ...
        points.MergedEyeDeltaBias(dominant), 48, dominantColor, 'o', ...
        'filled', 'MarkerEdgeColor', dominantColor, 'LineWidth', 1.2, ...
        'DisplayName', 'Dominant eye');
    dominantScatter.AlphaData = opacityFromOD( ...
        points.OD(dominant), alphaFloor, odForFullOpacity);
    dominantScatter.MarkerFaceAlpha = 'flat';
    dominantScatter.MarkerEdgeAlpha = 'flat';
    dominantScatter.AlphaDataMapping = 'none';

    nonDominantScatter = scatter(axesHandle, points.AI(nonDominant), ...
        points.MergedEyeDeltaBias(nonDominant), 48, nonDominantColor, 'o', ...
        'filled', 'MarkerEdgeColor', nonDominantColor, 'LineWidth', 1.2, ...
        'DisplayName', 'Non-dominant eye (bias negated)');
    nonDominantScatter.AlphaData = opacityFromOD( ...
        points.OD(nonDominant), alphaFloor, odForFullOpacity);
    nonDominantScatter.MarkerFaceAlpha = 'flat';
    nonDominantScatter.MarkerEdgeAlpha = 'flat';
    nonDominantScatter.AlphaDataMapping = 'none';

    if methodIndex == 1
        firstAxes = axesHandle;
        legendHandles = [fitHandle, dominantScatter, nonDominantScatter];
    end
    xlim(axesHandle, [-1 1])
    ylim(axesHandle, [-2.2 2.2])
    axis(axesHandle, 'square')
    box(axesHandle, 'on')
    grid(axesHandle, 'off')
    xticks(axesHandle, -1:0.5:1)
    xticklabels(axesHandle, {'-1', 'Away', '0', 'Towards', '1'})
    yticks(axesHandle, -2:1:2)
    yticklabels(axesHandle, {'-2', 'Away', '0', 'Towards', '2'})
    ytickangle(axesHandle, 90)
    set(axesHandle, 'FontSize', 13, 'LineWidth', 1, 'ALim', [0 1])
    xlabel(axesHandle, 'Asymmetry Index')
    if methodIndex == 1
        ylabel(axesHandle, 'Merged-eye Delta Bias')
    end
    title(axesHandle, method.name, 'Interpreter', 'none')
    if isfinite(method.sigma)
        if method.sigmaAtGridBoundary
            sigmaText = sprintf( ...
                'best tested sigma = %.3g (grid boundary; near uniform)', ...
                method.sigma);
        else
            sigmaText = sprintf('perspective-optimal sigma = %.3g', ...
                method.sigma);
        end
        subtitleText = {sprintf('%s; OD-sign eye swaps = %d', ...
            sigmaText, method.dominanceFlipCount), ...
            sprintf(['selection CV R^2 = %.3f; ' ...
            'nested selection-pipeline R^2 = %.3f'], ...
            method.selectionCVR2, method.nestedSelectionCVR2), ...
            sprintf('descriptive post-selection AI-by-OD p = %.3g', ...
            method.pAIxOD)};
    else
        subtitleText = {'stimulation-electrode baseline', ...
            sprintf('CV R^2 = %.3f; descriptive AI-by-OD p = %.3g', ...
            method.selectionCVR2, method.pAIxOD)};
    end
    subtitle(axesHandle, subtitleText, 'FontSize', 10.5)
end

legendHandle = legend(firstAxes, legendHandles, ...
    {'Descriptive OD-weighted AI-only fit', 'Dominant eye', ...
    'Non-dominant eye (bias negated)'}, 'Orientation', 'horizontal');
legendHandle.Layout.Tile = 'south';
sgtitle(scatterLayout, sprintf([ ...
    'Perspective-cue optimization of Delta Bias ~ AI + AI:OD ' ...
    '(opacity spans %.2f-1; full at |OD| >= %.2f; N = %d)'], ...
    alphaFloor, odForFullOpacity, result.sessionCount), ...
    'FontWeight', 'bold');

scatterBase = 'perspective_ai_od_optimized_scatter';
savefig(scatterFigure, fullfile(outputDir, [scatterBase '.fig']));
exportgraphics(scatterFigure, fullfile(outputDir, [scatterBase '.png']), ...
    'Resolution', 300);

writetable(result.summaryTable, ...
    fullfile(outputDir, 'perspective_ai_od_optimization_summary.csv'));
writetable(result.pointTable, ...
    fullfile(outputDir, 'perspective_ai_od_optimization_points.csv'));
writetable(result.channel.table, ...
    fullfile(outputDir, 'channel_ai_sigma_results.csv'));
writetable(result.fr.table, ...
    fullfile(outputDir, 'fr_meta_tuning_sigma_results.csv'));
writetable(weightTable(result, result.channel), ...
    fullfile(outputDir, 'channel_ai_best_weights.csv'));
writetable(weightTable(result, result.fr), ...
    fullfile(outputDir, 'fr_meta_tuning_best_weights.csv'));
writetable(nestedSelectionTable(result.channel), ...
    fullfile(outputDir, 'channel_ai_nested_selected_sigmas.csv'));
writetable(nestedSelectionTable(result.fr), ...
    fullfile(outputDir, 'fr_meta_tuning_nested_selected_sigmas.csv'));
save(fullfile(outputDir, 'perspective_ai_od_gaussian_optimization.mat'), ...
    'result');

figureHandles = [optimizationFigure; scatterFigure];
end

function plotCurve(axesHandle, method, color)
x = method.sigmaValues;
y = method.meanR2;
sem = method.semR2;
fill(axesHandle, [x; flipud(x)], [y-sem; flipud(y+sem)], color, ...
    'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
if method.bestAtGridBoundary
    bestLabel = sprintf('%s (best tested sigma = %.3g; boundary)', ...
        shortMethodName(method.name), method.bestSigma);
else
    bestLabel = sprintf('%s (best sigma = %.3g)', ...
        shortMethodName(method.name), method.bestSigma);
end
plot(axesHandle, x, y, 'o-', 'Color', color, ...
    'MarkerFaceColor', color, 'LineWidth', 2, 'MarkerSize', 4, ...
    'DisplayName', bestLabel);
plot(axesHandle, method.bestSigma, method.bestSelectionCVR2, 'o', ...
    'MarkerSize', 10, 'MarkerFaceColor', [1 1 1], ...
    'MarkerEdgeColor', color, 'LineWidth', 2, 'HandleVisibility', 'off');
end

function plotWeights(axesHandle, result, method, color, titleText)
plot(axesHandle, result.positionOffset, method.bestWeights, 'o-', ...
    'Color', color, 'MarkerFaceColor', color, 'LineWidth', 2, ...
    'MarkerSize', 5);
grid(axesHandle, 'on')
box(axesHandle, 'off')
ylim(axesHandle, [0, 1.10 .* max(method.bestWeights)])
xticks(axesHandle, result.positionOffset)
xlabel(axesHandle, 'Position relative to stimulation electrode')
ylabel(axesHandle, 'Normalized Gaussian weight')
title(axesHandle, titleText)
subtitle(axesHandle, sprintf( ...
    'sigma = %.3g; effective channels = %.2f', ...
    method.bestSigma, method.bestEffectiveChannels))
end

function value = opacityFromOD(od, alphaFloor, odForFullOpacity)
scaledOD = max(0, min(1, od ./ odForFullOpacity));
value = alphaFloor + (1 - alphaFloor) .* scaledOD;
end

function output = shortMethodName(name)
if contains(name, 'channel AI')
    output = 'Channel AI';
else
    output = 'FR meta-tuning';
end
end

function output = weightTable(result, method)
output = table(result.positionOffset, method.bestWeights, ...
    'VariableNames', {'RelativeChannelPosition', 'GaussianWeight'});
end

function output = nestedSelectionTable(method)
[repeatIndex, outerFold] = ndgrid( ...
    1:size(method.nestedSelectedSigma, 1), ...
    1:size(method.nestedSelectedSigma, 2));
output = table(repeatIndex(:), outerFold(:), ...
    method.nestedSelectedSigma(:), ...
    'VariableNames', {'Repeat', 'OuterFold', 'SelectedSigma'});
end

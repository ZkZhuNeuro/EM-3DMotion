function figureHandle = currentSpreadSavePerspectiveAIODComparison(result, outputDir)
%CURRENTSPREADSAVEPERSPECTIVEAIODCOMPARISON Save the three-panel scatter plot.

arguments
    result (1, 1) struct
    outputDir (1, :) char
end

if ~isfolder(outputDir)
    mkdir(outputDir);
end

dominantColor = [254 191 15] ./ 255;
nonDominantColor = [110 205 221] ./ 255;
xPlot = linspace(-1, 1, 200);

figureHandle = figure('Color', 'w', ...
    'Name', 'original_vs_optimized_ai_od_scatter', ...
    'Position', [50 100 2100 680]);
layout = tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

for methodIndex = 1:numel(result.methods)
    method = result.methods(methodIndex);
    points = method.pointTable;
    axesHandle = nexttile(layout);
    hold(axesHandle, 'on')
    plot(axesHandle, [-1 1], [0 0], 'k--', 'HandleVisibility', 'off');
    plot(axesHandle, [0 0], [-2.2 2.2], 'k--', 'HandleVisibility', 'off');
    fitHandle = plot(axesHandle, xPlot, ...
        method.weightedIntercept + method.weightedSlope .* xPlot, ...
        '-', 'Color', [0.15 0.15 0.15], 'LineWidth', 2.5, ...
        'DisplayName', 'OD-weighted fit');

    dominant = points.EyeCondition == "Dominant";
    nonDominant = points.EyeCondition == "NonDominant";
    dominantScatter = scatter(axesHandle, points.AI(dominant), ...
        points.MergedEyeDeltaBias(dominant), 48, dominantColor, 'o', ...
        'filled', 'MarkerEdgeColor', dominantColor, 'LineWidth', 1.2, ...
        'DisplayName', 'Dominant eye');
    dominantOD = max(0, min(1, points.OD(dominant)));
    dominantScatter.AlphaData = 0.40 + 0.60 .* dominantOD;
    dominantScatter.MarkerFaceAlpha = 'flat';
    dominantScatter.MarkerEdgeAlpha = 'flat';
    dominantScatter.AlphaDataMapping = 'none';

    nonDominantScatter = scatter(axesHandle, points.AI(nonDominant), ...
        points.MergedEyeDeltaBias(nonDominant), 48, nonDominantColor, 'o', ...
        'filled', 'MarkerEdgeColor', nonDominantColor, 'LineWidth', 1.2, ...
        'DisplayName', 'Non-dominant eye (bias negated)');
    nonDominantOD = max(0, min(1, points.OD(nonDominant)));
    nonDominantScatter.AlphaData = 0.40 + 0.60 .* nonDominantOD;
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
        subtitleText = {sprintf( ...
            'combined-cue sigma = %.3g; OD-sign eye swaps = %d', ...
            method.sigma, method.dominanceFlipCount), ...
            sprintf('perspective CV R^2 = %.3f; AI-by-OD p = %.3g', ...
            method.crossValidatedR2, method.pAIxOD)};
    else
        subtitleText = {'stimulation-electrode baseline', ...
            sprintf('perspective CV R^2 = %.3f; AI-by-OD p = %.3g', ...
            method.crossValidatedR2, method.pAIxOD)};
    end
    subtitle(axesHandle, subtitleText, 'FontSize', 11)
end

legendHandle = legend(firstAxes, legendHandles, ...
    {'OD-weighted fit', 'Dominant eye', ...
    'Non-dominant eye (bias negated)'}, ...
    'Orientation', 'horizontal');
legendHandle.Layout.Tile = 'south';
sgtitle(layout, sprintf(['Jim MT 2D perspective cues: AI versus Delta Bias ' ...
    '(opacity scales with |OD|; minimum 0.40; sigma optimized on combined cue; N = %d)'], ...
    result.sessionCount), ...
    'FontWeight', 'bold');

baseName = 'original_vs_optimized_ai_od_scatter';
savefig(figureHandle, fullfile(outputDir, [baseName '.fig']));
exportgraphics(figureHandle, fullfile(outputDir, [baseName '.png']), ...
    'Resolution', 300);
writetable(result.summaryTable, fullfile(outputDir, [baseName '_summary.csv']));
writetable(result.pointTable, fullfile(outputDir, [baseName '_points.csv']));
save(fullfile(outputDir, [baseName '.mat']), 'result');
end

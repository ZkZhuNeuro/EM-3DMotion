function figureHandles = currentSpreadSaveFilteredMetaFRAIODOptimization( ...
        result, outputDir)
%CURRENTSPREADSAVEFILTEREDMETAFRAIODOPTIMIZATION Save audit, plots, and tables.

arguments
    result (1, 1) struct
    outputDir (1, :) char
end

if ~isfolder(outputDir)
    mkdir(outputDir);
end

originalColor = [0.25 0.25 0.25];
uniformColor = [0.25 0.55 0.30];
optimizedColor = [0.72 0.20 0.22];
dominantColor = [254 191 15] ./ 255;
nonDominantColor = [110 205 221] ./ 255;
alphaFloor = 0.25;
odForFullOpacity = 0.20;

auditFigure = figure('Color', 'w', 'Name', ...
    'filtered_meta_fr_dataset_audit', 'Position', [70 70 1450 900]);
auditLayout = tiledlayout(2, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');

flowAxes = nexttile(auditLayout);
flow = result.flowTable;
barh(flowAxes, 1:height(flow), flow.Count, ...
    'FaceColor', optimizedColor, 'EdgeColor', 'none');
for row = 1:height(flow)
    text(flowAxes, flow.Count(row) + max(flow.Count) .* 0.015, ...
        row, sprintf('%d', flow.Count(row)), 'FontWeight', 'bold', ...
        'VerticalAlignment', 'middle');
end
yticks(flowAxes, 1:height(flow))
yticklabels(flowAxes, flow.Stage)
set(flowAxes, 'YDir', 'reverse')
xlim(flowAxes, [0, max(flow.Count) .* 1.12])
xlabel(flowAxes, 'Recordings')
title(flowAxes, 'Fixed-cohort construction')
box(flowAxes, 'off')
grid(flowAxes, 'on')

channelAxes = nexttile(auditLayout);
audit = result.sessionAudit;
mt = audit.ROI == "MT" & audit.TunedBothChannelCount > 0;
fst = audit.ROI == "FST" & audit.TunedBothChannelCount > 0;
hold(channelAxes, 'on')
if any(mt)
    histogram(channelAxes, audit.TunedBothChannelCount(mt), ...
        'BinEdges', 0.5:1:16.5, 'FaceColor', uniformColor, ...
        'FaceAlpha', 0.65, 'EdgeColor', 'none', 'DisplayName', 'MT');
end
if any(fst)
    histogram(channelAxes, audit.TunedBothChannelCount(fst), ...
        'BinEdges', 0.5:1:16.5, 'FaceColor', optimizedColor, ...
        'FaceAlpha', 0.55, 'EdgeColor', 'none', 'DisplayName', 'FST');
end
xlabel(channelAxes, 'Channels significant in both eyes')
ylabel(channelAxes, 'Recordings')
title(channelAxes, 'Retained channels among recordings with any')
if any(mt) && any(fst)
    legend(channelAxes, 'Location', 'best')
end
box(channelAxes, 'off')

pAxes = nexttile(auditLayout);
channels = result.channelAudit;
validP = channels.ValidChannel & isfinite(channels.P_Left) & ...
    isfinite(channels.P_Right);
notRetained = validP & ~channels.TunedBoth;
retained = validP & channels.TunedBoth;
scatter(pAxes, -log10(max(channels.P_Left(notRetained), realmin)), ...
    -log10(max(channels.P_Right(notRetained), realmin)), 16, ...
    [0.60 0.60 0.60], 'filled', 'MarkerFaceAlpha', 0.22, ...
    'MarkerEdgeAlpha', 0.22, 'DisplayName', 'Excluded channel');
hold(pAxes, 'on')
scatter(pAxes, -log10(max(channels.P_Left(retained), realmin)), ...
    -log10(max(channels.P_Right(retained), realmin)), 30, ...
    optimizedColor, 'filled', 'MarkerFaceAlpha', 0.72, ...
    'MarkerEdgeColor', [0.35 0.05 0.06], 'MarkerEdgeAlpha', 0.75, ...
    'DisplayName', 'Retained in meta tuning');
threshold = -log10(result.tuningAlpha);
xline(pAxes, threshold, '--k', 'HandleVisibility', 'off')
yline(pAxes, threshold, '--k', 'HandleVisibility', 'off')
xlabel(pAxes, '-log_{10}(left-eye direction p)')
ylabel(pAxes, '-log_{10}(right-eye direction p)')
title(pAxes, sprintf('Per-channel tuning screen (raw p < %.2g in both)', ...
    result.tuningAlpha))
legend(pAxes, 'Location', 'best')
box(pAxes, 'on')

zAxes = nexttile(auditLayout);
finiteZ = audit.UniformMetaTunedBoth & ...
    isfinite(audit.UniformMetaZ3DMinusZ2D);
mtZ = finiteZ & audit.ROI == "MT";
fstZ = finiteZ & audit.ROI == "FST";
allZ = audit.UniformMetaZ3DMinusZ2D(finiteZ);
if isempty(allZ)
    edges = -1:0.1:1;
else
    edgeLimit = max(1, ceil(max(abs(allZ))));
    edges = linspace(-edgeLimit, edgeLimit, 31);
end
hold(zAxes, 'on')
if any(mtZ)
    histogram(zAxes, audit.UniformMetaZ3DMinusZ2D(mtZ), 'BinEdges', edges, ...
        'FaceColor', uniformColor, 'FaceAlpha', 0.65, 'EdgeColor', 'none', ...
        'DisplayName', 'MT');
end
if any(fstZ)
    histogram(zAxes, audit.UniformMetaZ3DMinusZ2D(fstZ), 'BinEdges', edges, ...
        'FaceColor', optimizedColor, 'FaceAlpha', 0.55, 'EdgeColor', 'none', ...
        'DisplayName', 'FST');
end
xline(zAxes, 0, '--k', '2D | 3D', 'LabelVerticalAlignment', 'bottom', ...
    'HandleVisibility', 'off')
xlabel(zAxes, 'Uniform-meta Z_{3D} - Z_{2D}')
ylabel(zAxes, 'Recordings')
title(zAxes, 'Meta-tuning classification after channel cleaning')
if any(mtZ) && any(fstZ)
    legend(zAxes, 'Location', 'best')
end
box(zAxes, 'off')

sgtitle(auditLayout, sprintf([ ...
    '%s recordings: channel tuning first, then fixed uniform-meta 2D gate ' ...
    '(final N = %d of %d)'], char(result.candidateLabel), result.sessionCount, ...
    result.candidateCount), ...
    'FontWeight', 'bold');
saveFigurePair(auditFigure, outputDir, 'filtered_meta_fr_dataset_audit');

optimizationFigure = figure('Color', 'w', 'Name', ...
    'filtered_meta_fr_sigma_optimization', 'Position', [90 80 1400 850]);
optimizationLayout = tiledlayout(2, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
curveAxes = nexttile(optimizationLayout, [1 2]);
hold(curveAxes, 'on')
plotCurve(curveAxes, result.optimized, optimizedColor);
yline(curveAxes, result.original.selectionCVR2, '--', ...
    'Color', originalColor, 'LineWidth', 1.5, ...
    'DisplayName', sprintf('Original electrode (CV R^2 = %.3f)', ...
    result.original.selectionCVR2));
yline(curveAxes, result.uniform.selectionCVR2, '-.', ...
    'Color', uniformColor, 'LineWidth', 1.8, ...
    'DisplayName', sprintf('Uniform cleaned meta (CV R^2 = %.3f)', ...
    result.uniform.selectionCVR2));
set(curveAxes, 'XScale', 'log', 'FontSize', 12, 'LineWidth', 1)
grid(curveAxes, 'on')
box(curveAxes, 'off')
xlabel(curveAxes, 'Gaussian \sigma (channel positions)')
ylabel(curveAxes, 'Selection cross-validated R^2')
title(curveAxes, 'Fixed-cohort optimization of perspective Delta Bias ~ AI + AI:OD')
legend(curveAxes, 'Location', 'bestoutside')

weightAxes = nexttile(optimizationLayout);
plot(weightAxes, result.positionOffset, result.optimized.bestWeights, ...
    'o-', 'Color', optimizedColor, 'MarkerFaceColor', optimizedColor, ...
    'LineWidth', 2, 'MarkerSize', 5);
xline(weightAxes, 0, ':', 'Color', [0.35 0.35 0.35], ...
    'HandleVisibility', 'off')
xlabel(weightAxes, 'Position relative to stimulation electrode')
ylabel(weightAxes, 'Mean realized contribution')
title(weightAxes, 'Best Gaussian after channel exclusion')
subtitle(weightAxes, sprintf('sigma = %.3g; median effective channels = %.2f', ...
    result.optimized.bestSigma, ...
    result.optimized.bestMedianEffectiveChannels))
grid(weightAxes, 'on')
box(weightAxes, 'off')

effectiveAxes = nexttile(optimizationLayout);
semilogx(effectiveAxes, result.sigmaValues, ...
    result.optimized.medianEffectiveChannels, 'o-', ...
    'Color', optimizedColor, 'MarkerFaceColor', optimizedColor, ...
    'LineWidth', 2, 'MarkerSize', 4);
hold(effectiveAxes, 'on')
semilogx(effectiveAxes, result.sigmaValues, ...
    result.optimized.meanEffectiveChannels, '-', ...
    'Color', [0.35 0.35 0.35], 'LineWidth', 1.3);
xlabel(effectiveAxes, 'Gaussian \sigma (channel positions)')
ylabel(effectiveAxes, 'Effective retained channels')
title(effectiveAxes, 'Session-specific renormalized weights')
legend(effectiveAxes, {'Median', 'Mean'}, 'Location', 'best')
grid(effectiveAxes, 'on')
box(effectiveAxes, 'off')

sgtitle(optimizationLayout, sprintf([ ...
    'Clean FR meta tuning; %d x %d-fold session-grouped CV; N = %d'], ...
    result.numRepeats, result.numFolds, result.sessionCount), ...
    'FontWeight', 'bold');
saveFigurePair(optimizationFigure, outputDir, ...
    'filtered_meta_fr_sigma_optimization');

scatterFigure = figure('Color', 'w', 'Name', ...
    'filtered_meta_fr_original_uniform_optimized_scatter', ...
    'Position', [40 100 2100 760]);
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
        method.weightedIntercept + method.weightedSlope .* xPlot, '-', ...
        'Color', [0.15 0.15 0.15], 'LineWidth', 2.5, ...
        'DisplayName', 'OD-weighted descriptive fit');

    dominant = points.EyeCondition == "Dominant";
    nonDominant = points.EyeCondition == "NonDominant";
    dominantScatter = odScatter(axesHandle, points.AI(dominant), ...
        points.MergedEyeDeltaBias(dominant), points.OD(dominant), ...
        dominantColor, alphaFloor, odForFullOpacity, 'Dominant eye');
    nonDominantScatter = odScatter(axesHandle, points.AI(nonDominant), ...
        points.MergedEyeDeltaBias(nonDominant), points.OD(nonDominant), ...
        nonDominantColor, alphaFloor, odForFullOpacity, ...
        'Non-dominant eye (bias negated)');

    if methodIndex == 1
        firstAxes = axesHandle;
        legendHandles = [fitHandle, dominantScatter, nonDominantScatter];
    end
    xlim(axesHandle, [-1 1])
    ylim(axesHandle, [-2.2 2.2])
    axis(axesHandle, 'square')
    box(axesHandle, 'on')
    xticks(axesHandle, -1:0.5:1)
    xticklabels(axesHandle, {'-1', 'Away', '0', 'Towards', '1'})
    yticks(axesHandle, -2:1:2)
    yticklabels(axesHandle, {'-2', 'Away', '0', 'Towards', '2'})
    ytickangle(axesHandle, 90)
    set(axesHandle, 'FontSize', 12.5, 'LineWidth', 1, 'ALim', [0 1])
    xlabel(axesHandle, 'Asymmetry Index')
    if methodIndex == 1
        ylabel(axesHandle, 'Merged-eye Delta Bias')
    end
    title(axesHandle, method.name, 'Interpreter', 'none')
    if ~isnan(method.sigma)
        if isinf(method.sigma)
            methodLine = sprintf('uniform; median effective channels = %.2f', ...
                method.effectiveChannels);
        else
            methodLine = sprintf('best sigma = %.3g; median effective channels = %.2f', ...
                method.sigma, method.effectiveChannels);
        end
    else
        methodLine = 'stimulation-electrode baseline on same cleaned cohort';
    end
    subtitle(axesHandle, {methodLine, ...
        sprintf('selection CV R^2 = %.3f; nested pipeline R^2 = %.3f', ...
        method.selectionCVR2, method.nestedSelectionCVR2), ...
        sprintf('descriptive AI-by-OD p = %.3g; OD eye swaps = %d', ...
        method.pAIxOD, method.dominanceFlipCount)}, 'FontSize', 10.2)
end

legendHandle = legend(firstAxes, legendHandles, ...
    {'OD-weighted descriptive fit', 'Dominant eye', ...
    'Non-dominant eye (bias negated)'}, 'Orientation', 'horizontal');
legendHandle.Layout.Tile = 'south';
sgtitle(scatterLayout, sprintf([ ...
    '%s clean meta-2D cohort (N = %d): face opacity = %.2f + %.2f ' ...
    '(|OD|/%.2f)^{0.75}, capped at 1; outlines remain visible'], ...
    char(result.candidateLabel), result.sessionCount, alphaFloor, 1-alphaFloor, ...
    odForFullOpacity), ...
    'FontWeight', 'bold');
saveFigurePair(scatterFigure, outputDir, ...
    'filtered_meta_fr_original_uniform_optimized_scatter');

writetable(result.flowTable, fullfile(outputDir, 'dataset_flow.csv'));
writetable(result.roiFlowTable, fullfile(outputDir, 'roi_dataset_flow.csv'));
writetable(result.sessionAudit, fullfile(outputDir, 'session_audit.csv'));
writetable(result.channelAudit, fullfile(outputDir, 'channel_tuning_audit.csv'));
writetable(result.summaryTable, fullfile(outputDir, ...
    'filtered_meta_fr_optimization_summary.csv'));
writetable(result.pointTable, fullfile(outputDir, ...
    'filtered_meta_fr_scatter_points.csv'));
writetable(result.optimized.table, fullfile(outputDir, ...
    'filtered_meta_fr_sigma_results.csv'));
writetable(table(result.positionOffset, result.optimized.bestWeights, ...
    'VariableNames', {'RelativeChannelPosition', 'MeanRealizedWeight'}), ...
    fullfile(outputDir, 'filtered_meta_fr_best_weights.csv'));
writetable(nestedSelectionTable(result.optimized), fullfile(outputDir, ...
    'filtered_meta_fr_nested_selected_sigmas.csv'));
save(fullfile(outputDir, 'filtered_meta_fr_ai_od_optimization.mat'), ...
    'result', '-v7.3');

figureHandles = [auditFigure; optimizationFigure; scatterFigure];
end

function scatterHandle = odScatter(axesHandle, x, y, od, color, ...
        alphaFloor, odForFullOpacity, displayName)
scatterHandle = scatter(axesHandle, x, y, 64, color, 'o', 'filled', ...
    'MarkerEdgeColor', color .* 0.55, 'LineWidth', 1.1, ...
    'DisplayName', displayName);
scatterHandle.AlphaData = opacityFromOD(od, alphaFloor, odForFullOpacity);
scatterHandle.MarkerFaceAlpha = 'flat';
scatterHandle.MarkerEdgeAlpha = 0.72;
scatterHandle.AlphaDataMapping = 'none';
end

function value = opacityFromOD(od, alphaFloor, odForFullOpacity)
scaledOD = max(0, min(1, od ./ odForFullOpacity));
value = alphaFloor + (1 - alphaFloor) .* scaledOD .^ 0.75;
end

function plotCurve(axesHandle, method, color)
x = method.sigmaValues;
y = method.meanR2;
sem = method.semR2;
fill(axesHandle, [x; flipud(x)], [y-sem; flipud(y+sem)], color, ...
    'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
plot(axesHandle, x, y, 'o-', 'Color', color, ...
    'MarkerFaceColor', color, 'LineWidth', 2, 'MarkerSize', 4, ...
    'DisplayName', sprintf('Clean optimized FR meta (best sigma = %.3g)', ...
    method.bestSigma));
plot(axesHandle, method.bestSigma, method.bestSelectionCVR2, 'o', ...
    'MarkerSize', 10, 'MarkerFaceColor', [1 1 1], ...
    'MarkerEdgeColor', color, 'LineWidth', 2, 'HandleVisibility', 'off');
end

function output = nestedSelectionTable(method)
[repeatIndex, outerFold] = ndgrid( ...
    1:size(method.nestedSelectedSigma, 1), ...
    1:size(method.nestedSelectedSigma, 2));
output = table(repeatIndex(:), outerFold(:), ...
    method.nestedSelectedSigma(:), ...
    'VariableNames', {'Repeat', 'OuterFold', 'SelectedSigma'});
end

function saveFigurePair(figureHandle, outputDir, baseName)
savefig(figureHandle, fullfile(outputDir, [baseName '.fig']));
exportgraphics(figureHandle, fullfile(outputDir, [baseName '.png']), ...
    'Resolution', 300);
end

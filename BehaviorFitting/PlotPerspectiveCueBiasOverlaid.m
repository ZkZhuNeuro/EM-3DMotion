clear;

% Overlay dominant- and non-dominant-eye perspective-cue delta-bias
% distributions for each MT/FST x 2D/3D subpopulation. Each eye's Delta_bias
% is aligned to that same eye's AI. A positive plotted value means the two
% signs match; a negative value means they oppose.

dataFile = 'C:\EM\BehaviorFitting\unit_table_gof.mat';
outDir = fullfile('C:\EM', 'BehaviorFitting', 'output', 'pdf', ...
    'PerspectiveCueDeltaBias_alignedOwnEyeAI');

load(dataFile, 'unit_table_gof');

roiList = {'MT', 'FST'};
ndList = {'2D', '3D'};
perspectiveCueIdx = [2, 3];
eyeGroupLabels = {'Dominant eye', 'Non-dominant eye'};
perspectiveCueColors = [0 90 210; 0 145 70] ./ 255;
histEdges = -2.5:0.2:2.5;

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

nRec = height(unit_table_gof);
deltaBias = nan(nRec, 4);
eyeDeltaBias = nan(nRec, 2);
eyeAI = nan(nRec, 2);
for iRec = 1:nRec
    biasThis = unit_table_gof.Delta_bias{iRec};
    nCueThis = min(4, numel(biasThis));
    deltaBias(iRec, 1:nCueThis) = biasThis(1:nCueThis);

    odThis = get_table_scalar(unit_table_gof.OD_max, iRec);
    stimElec = get_table_scalar(unit_table_gof.StimElec, iRec);
    aiThis = unit_table_gof.AI{iRec};
    if odThis > 0
        dominantCueIdx = perspectiveCueIdx(1); % Left eye is dominant.
        nonDominantCueIdx = perspectiveCueIdx(2);
    elseif odThis < 0
        dominantCueIdx = perspectiveCueIdx(2); % Right eye is dominant.
        nonDominantCueIdx = perspectiveCueIdx(1);
    else
        continue
    end
    eyeDeltaBias(iRec, :) = deltaBias(iRec, ...
        [dominantCueIdx, nonDominantCueIdx]);
    if ~isempty(aiThis) && size(aiThis, 1) >= max(perspectiveCueIdx) && ...
            isfinite(stimElec) && stimElec >= 1 && stimElec <= size(aiThis, 2)
        eyeAI(iRec, :) = aiThis( ...
            [dominantCueIdx, nonDominantCueIdx], stimElec).';
    end
end

eyeAISign = sign(eyeAI);
eyeAISign(eyeAISign == 0) = NaN;
alignedDeltaBias = eyeDeltaBias .* eyeAISign;

includeMask = true(nRec, 1);
if ismember('IncludeForAnalysis', unit_table_gof.Properties.VariableNames)
    includeMask = unit_table_gof.IncludeForAnalysis == 1;
end

summaryRows = cell(numel(roiList) * numel(ndList), 10);
iRow = 0;

for iRoi = 1:numel(roiList)
    for iNd = 1:numel(ndList)
        iRow = iRow + 1;
        roiThis = roiList{iRoi};
        ndThis = ndList{iNd};
        idxGroup = includeMask & strcmp(unit_table_gof.ROI, roiThis) & ...
            strcmp(unit_table_gof.ND, ndThis);

        dominantBias = alignedDeltaBias(idxGroup, 1);
        nonDominantBias = alignedDeltaBias(idxGroup, 2);
        pairedValid = isfinite(dominantBias) & isfinite(nonDominantBias);
        oppositeSign = pairedValid & dominantBias .* nonDominantBias < 0;
        nPaired = sum(pairedValid);
        nOpposite = sum(oppositeSign);

        dominantBias = dominantBias(isfinite(dominantBias));
        nonDominantBias = nonDominantBias(isfinite(nonDominantBias));
        medianDominant = median(dominantBias);
        medianNonDominant = median(nonDominantBias);
        oppositePct = 100 * nOpposite / max(nPaired, 1);

        fig = figure('Color', 'w', 'Position', [100 100 900 600]);
        ax = axes(fig);
        ax.Toolbar.Visible = 'off';
        hold(ax, 'on');

        hDominant = histogram(ax, dominantBias, histEdges, ...
            'DisplayStyle', 'bar', 'FaceColor', perspectiveCueColors(1, :), ...
            'FaceAlpha', 0.48, 'EdgeColor', perspectiveCueColors(1, :), ...
            'LineWidth', 0.9);
        hNonDominant = histogram(ax, nonDominantBias, histEdges, ...
            'DisplayStyle', 'bar', 'FaceColor', perspectiveCueColors(2, :), ...
            'FaceAlpha', 0.48, 'EdgeColor', perspectiveCueColors(2, :), ...
            'LineWidth', 0.9);
        xline(ax, 0, 'k--', 'LineWidth', 1.4, 'HandleVisibility', 'off');

        xlim(ax, [histEdges(1), histEdges(end)]);
        yLimits = ylim(ax);
        ylim(ax, [0, max(2.2, 1.19 * yLimits(2))]);
        yLimits = ylim(ax);
        hMedianDominant = plot(ax, medianDominant, 0.965 * yLimits(2), 'v', ...
            'MarkerSize', 10, 'MarkerFaceColor', perspectiveCueColors(1, :), ...
            'MarkerEdgeColor', [0.15 0.15 0.15], 'LineStyle', 'none', ...
            'HandleVisibility', 'off');
        hMedianNonDominant = plot(ax, medianNonDominant, 0.885 * yLimits(2), 'v', ...
            'MarkerSize', 10, 'MarkerFaceColor', perspectiveCueColors(2, :), ...
            'MarkerEdgeColor', [0.15 0.15 0.15], 'LineStyle', 'none', ...
            'HandleVisibility', 'off');

        title(ax, [roiThis ' ' ndThis ' perspective-cue \Delta biases'], ...
            'FontWeight', 'bold');
        xlabel(ax, 'Own-eye-AI-aligned \Delta bias');
        ylabel(ax, 'Recordings');
        box(ax, 'off');
        set(ax, 'FontSize', 13, 'TickDir', 'out', 'LineWidth', 1.2, ...
            'Layer', 'top');

        legend(ax, [hDominant, hNonDominant], ...
            {sprintf('%s (n = %d; median = %.3f)', ...
                eyeGroupLabels{1}, numel(dominantBias), medianDominant), ...
             sprintf('%s (n = %d; median = %.3f)', ...
                eyeGroupLabels{2}, numel(nonDominantBias), ...
                medianNonDominant)}, ...
            'Location', 'eastoutside', 'FontSize', 10, 'Box', 'off');

        fileStem = sprintf( ...
            'PerspectiveCueDeltaBias_alignedOwnEyeAI_%s_%s', ...
            roiThis, ndThis);
        exportgraphics(fig, fullfile(outDir, [fileStem '.png']), ...
            'Resolution', 300);
        exportgraphics(fig, fullfile(outDir, [fileStem '.pdf']), ...
            'ContentType', 'vector');
        savefig(fig, fullfile(outDir, [fileStem '.fig']));
        close(fig);

        summaryRows(iRow, :) = {roiThis, ndThis, numel(dominantBias), ...
            medianDominant, numel(nonDominantBias), medianNonDominant, ...
            nPaired, nOpposite, oppositePct, fileStem};
    end
end

perspectiveCueDeltaBiasSummary = cell2table(summaryRows, 'VariableNames', ...
    {'ROI', 'ND', 'N_Dominant', 'Median_DominantAlignedDeltaBias', ...
     'N_NonDominant', 'Median_NonDominantAlignedDeltaBias', ...
     'N_Paired', 'N_OppositeSigns', 'Pct_OppositeSigns', 'FileStem'});
writetable(perspectiveCueDeltaBiasSummary, ...
    fullfile(outDir, ...
    'PerspectiveCueDeltaBias_alignedOwnEyeAI_summary.csv'));
save(fullfile(outDir, ...
    'PerspectiveCueDeltaBias_alignedOwnEyeAI_summary.mat'), ...
    'perspectiveCueDeltaBiasSummary');

disp(perspectiveCueDeltaBiasSummary);
fprintf('Saved own-eye-AI-aligned perspective-cue histograms to:\n%s\n', ...
    outDir);

function value = get_table_scalar(column, rowIdx)
    if iscell(column)
        value = column{rowIdx};
    else
        value = column(rowIdx);
    end
    if isempty(value) || ~isscalar(value)
        value = NaN;
    end
end

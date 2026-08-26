clear;

% Dominant- and non-dominant-eye perspective-cue delta-bias histograms.
% Each eye's Delta_bias is aligned to that eye's AI. Session-level bootstrap
% significance controls fill style, and medians use significant values only.

dataFile = 'C:\EM\BehaviorFitting\unit_table_gof.mat';
bootstrapFile = 'C:\EM\BehaviorFitting\DeltaBiasBootstrap_zeroTest.mat';
outDir = fullfile('C:\EM', 'BehaviorFitting', 'output', 'pdf', ...
    'PerspectiveCueDeltaBias_alignedOwnEyeAI_Significance');

load(dataFile, 'unit_table_gof');
load(bootstrapFile, 'bootstrapResult');

assert(isequal(bootstrapResult.originalRecIdx(:), ...
    unit_table_gof.OriginalRecIdx(:)), ...
    'Bootstrap results do not match the rows in unit_table_gof.');
assert(all(bootstrapResult.completed(bootstrapResult.includedMask, :), 'all'), ...
    'Bootstrap testing is incomplete for one or more included sessions.');

roiList = {'MT', 'FST'};
ndList = {'2D', '3D'};
perspectiveCueIdx = [2, 3];
eyeGroupLabels = {'Dominant eye', 'Non-dominant eye'};
eyeGroupColors = [0 90 210; 0 145 70] ./ 255;
histEdges = -2.5:0.2:2.5;

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

nRec = height(unit_table_gof);
deltaBias = nan(nRec, 4);
eyeDeltaBias = nan(nRec, 2);
eyeAI = nan(nRec, 2);
eyeSignificant = false(nRec, 2);

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

    cueOrder = [dominantCueIdx, nonDominantCueIdx];
    eyeDeltaBias(iRec, :) = deltaBias(iRec, cueOrder);
    eyeSignificant(iRec, :) = bootstrapResult.significant(iRec, cueOrder);

    if ~isempty(aiThis) && size(aiThis, 1) >= max(perspectiveCueIdx) && ...
            isfinite(stimElec) && stimElec >= 1 && stimElec <= size(aiThis, 2)
        eyeAI(iRec, :) = aiThis(cueOrder, stimElec).';
    end
end

eyeAISign = sign(eyeAI);
eyeAISign(eyeAISign == 0) = NaN;
alignedDeltaBias = eyeDeltaBias .* eyeAISign;

includeMask = true(nRec, 1);
if ismember('IncludeForAnalysis', unit_table_gof.Properties.VariableNames)
    includeMask = unit_table_gof.IncludeForAnalysis == 1;
end

summaryRows = cell(numel(roiList) * numel(ndList) * 2, 7);
iRow = 0;

for iRoi = 1:numel(roiList)
    for iNd = 1:numel(ndList)
        roiThis = roiList{iRoi};
        ndThis = ndList{iNd};
        idxGroup = includeMask & strcmp(unit_table_gof.ROI, roiThis) & ...
            strcmp(unit_table_gof.ND, ndThis);

        fig = figure('Color', 'w', 'Position', [100 100 1050 620]);
        ax = axes(fig);
        ax.Toolbar.Visible = 'off';
        hold(ax, 'on');

        plotHandles = gobjects(2, 2);
        medianSignificant = nan(1, 2);
        nAll = zeros(1, 2);
        nSignificant = zeros(1, 2);

        for iEye = 1:2
            x = alignedDeltaBias(idxGroup, iEye);
            sigThis = eyeSignificant(idxGroup, iEye);
            valid = isfinite(x);
            x = x(valid);
            sigThis = sigThis(valid);

            nAll(iEye) = numel(x);
            nSignificant(iEye) = sum(sigThis);
            significantValues = x(sigThis);
            if ~isempty(significantValues)
                medianSignificant(iEye) = median(significantValues);
            end

            if iEye == 1
                barWidth = 0.98;
            else
                barWidth = 0.72;
            end
            plotHandles(iEye, :) = plot_significance_histogram(ax, x, ...
                sigThis, eyeGroupColors(iEye, :), histEdges, barWidth);

            iRow = iRow + 1;
            summaryRows(iRow, :) = {roiThis, ndThis, eyeGroupLabels{iEye}, ...
                nAll(iEye), nSignificant(iEye), medianSignificant(iEye), ...
                sprintf( ...
                'PerspectiveCueDeltaBias_alignedOwnEyeAI_Significance_%s_%s', ...
                roiThis, ndThis)};
        end

        xline(ax, 0, 'k--', 'LineWidth', 1.4, 'HandleVisibility', 'off');
        xlim(ax, [histEdges(1), histEdges(end)]);
        currentYLimits = ylim(ax);
        ylim(ax, [0, max(2.2, 1.20 * currentYLimits(2))]);
        currentYLimits = ylim(ax);

        for iEye = 1:2
            if isfinite(medianSignificant(iEye))
                medianY = (0.965 - 0.08 * (iEye - 1)) * currentYLimits(2);
                plot(ax, medianSignificant(iEye), medianY, 'v', ...
                    'MarkerSize', 10, ...
                    'MarkerFaceColor', eyeGroupColors(iEye, :), ...
                    'MarkerEdgeColor', [0.15 0.15 0.15], ...
                    'LineStyle', 'none', 'HandleVisibility', 'off');
            end
        end

        title(ax, [roiThis ' ' ndThis ' perspective-cue \Delta biases'], ...
            'FontWeight', 'bold');
        subtitle(ax, ['Filled: significant; open: not significant; ' ...
            'triangles: significant-only medians'], ...
            'FontWeight', 'normal', 'FontSize', 10);
        xlabel(ax, 'Own-eye-AI-aligned \Delta bias');
        ylabel(ax, 'Recordings');
        box(ax, 'off');
        set(ax, 'FontSize', 13, 'TickDir', 'out', 'LineWidth', 1.2, ...
            'Layer', 'top');

        legendHandles = [plotHandles(1, 2), plotHandles(1, 1), ...
            plotHandles(2, 2), plotHandles(2, 1)];
        legendLabels = { ...
            sprintf('Dominant significant (n = %d; median = %.3f)', ...
                nSignificant(1), medianSignificant(1)), ...
            sprintf('Dominant not significant (n = %d)', ...
                nAll(1) - nSignificant(1)), ...
            sprintf('Non-dominant significant (n = %d; median = %.3f)', ...
                nSignificant(2), medianSignificant(2)), ...
            sprintf('Non-dominant not significant (n = %d)', ...
                nAll(2) - nSignificant(2))};
        legend(ax, legendHandles, legendLabels, 'Location', 'eastoutside', ...
            'FontSize', 9.5, 'Box', 'off');

        fileStem = sprintf( ...
            'PerspectiveCueDeltaBias_alignedOwnEyeAI_Significance_%s_%s', ...
            roiThis, ndThis);
        exportgraphics(fig, fullfile(outDir, [fileStem '.png']), ...
            'Resolution', 300);
        exportgraphics(fig, fullfile(outDir, [fileStem '.pdf']), ...
            'ContentType', 'vector');
        savefig(fig, fullfile(outDir, [fileStem '.fig']));
        close(fig);
    end
end

perspectiveCueSignificanceSummary = cell2table(summaryRows, ...
    'VariableNames', {'ROI', 'ND', 'EyeGroup', 'N_All', 'N_Significant', ...
    'MedianSignificantAlignedDeltaBias', 'FileStem'});
writetable(perspectiveCueSignificanceSummary, fullfile(outDir, ...
    'PerspectiveCueDeltaBias_alignedOwnEyeAI_Significance_summary.csv'));
save(fullfile(outDir, ...
    'PerspectiveCueDeltaBias_alignedOwnEyeAI_Significance_summary.mat'), ...
    'perspectiveCueSignificanceSummary');

disp(perspectiveCueSignificanceSummary);
fprintf('Saved significance-coded histograms to:\n%s\n', outDir);

function h = plot_significance_histogram(ax, x, sigMask, color, edges, barWidth)
    centers = edges(1:end-1) + diff(edges) / 2;
    countsNotSignificant = histcounts(x(~sigMask), edges);
    countsSignificant = histcounts(x(sigMask), edges);
    h = bar(ax, centers, ...
        [countsNotSignificant(:), countsSignificant(:)], 'stacked', ...
        'BarWidth', barWidth);

    h(1).FaceColor = 'none';
    h(1).EdgeColor = color;
    h(1).LineWidth = 1.25;

    h(2).FaceColor = color;
    h(2).FaceAlpha = 0.50;
    h(2).EdgeColor = color;
    h(2).LineWidth = 0.9;
end

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

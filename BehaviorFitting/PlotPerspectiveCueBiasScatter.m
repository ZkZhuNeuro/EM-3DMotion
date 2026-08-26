clear;

% Plot raw perspective-cue delta bias against eye-specific AI x |OD| for
% each MT/FST x 2D/3D subpopulation. Dominant- and non-dominant-eye data are
% overlaid without sign-flipping the delta bias.

dataFile = 'C:\EM\BehaviorFitting\unit_table_gof.mat';
outDir = fullfile('C:\EM', 'BehaviorFitting', 'output', 'pdf', ...
    'PerspectiveCueDeltaBias_vs_EyeSpecificAIabsOD');

load(dataFile, 'unit_table_gof');

roiList = {'MT', 'FST'};
ndList = {'2D', '3D'};
perspectiveCueIdx = [2, 3];
eyeGroupLabels = {'Dominant eye', 'Non-dominant eye'};
perspectiveCueColors = [0 90 210; 0 145 70] ./ 255;
perspectiveCueMarkers = {'o', 's'};
yLimits = [-2.5, 2.5];

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

nRec = height(unit_table_gof);
deltaBias = nan(nRec, 4);
eyeDeltaBias = nan(nRec, 2);
eyeAIxAbsOD = nan(nRec, 2);

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
        eyeAI = aiThis([dominantCueIdx, nonDominantCueIdx], stimElec).';
        eyeAIxAbsOD(iRec, :) = eyeAI * abs(odThis);
    end
end

includeMask = true(nRec, 1);
if ismember('IncludeForAnalysis', unit_table_gof.Properties.VariableNames)
    includeMask = unit_table_gof.IncludeForAnalysis == 1;
end

includeMatrix = repmat(includeMask, 1, 2);
finiteIncludedX = eyeAIxAbsOD(includeMatrix & isfinite(eyeAIxAbsOD));
if isempty(finiteIncludedX)
    xLimitAbs = 0.5;
else
    xLimitAbs = max(0.1, ceil(10 * max(abs(finiteIncludedX))) / 10);
end
xLimits = [-xLimitAbs, xLimitAbs];

summaryRows = cell(numel(roiList) * numel(ndList) * ...
    numel(eyeGroupLabels), 7);
iRow = 0;

for iRoi = 1:numel(roiList)
    for iNd = 1:numel(ndList)
        roiThis = roiList{iRoi};
        ndThis = ndList{iNd};
        idxGroup = includeMask & strcmp(unit_table_gof.ROI, roiThis) & ...
            strcmp(unit_table_gof.ND, ndThis);

        fig = figure('Color', 'w', 'Position', [100 100 900 620]);
        ax = axes(fig);
        ax.Toolbar.Visible = 'off';
        hold(ax, 'on');
        scatterHandles = gobjects(1, numel(eyeGroupLabels));
        legendLabels = cell(1, numel(eyeGroupLabels));

        for iEye = 1:numel(eyeGroupLabels)
            x = eyeAIxAbsOD(idxGroup, iEye);
            y = eyeDeltaBias(idxGroup, iEye);
            valid = isfinite(x) & isfinite(y);
            x = x(valid);
            y = y(valid);

            scatterHandles(iEye) = scatter(ax, x, y, 48, ...
                perspectiveCueMarkers{iEye}, 'filled', ...
                'MarkerFaceColor', perspectiveCueColors(iEye, :), ...
                'MarkerEdgeColor', perspectiveCueColors(iEye, :), ...
                'MarkerFaceAlpha', 0.58, 'MarkerEdgeAlpha', 0.9, ...
                'LineWidth', 0.8);
            legendLabels{iEye} = sprintf('%s (n = %d)', ...
                eyeGroupLabels{iEye}, numel(x));

            if numel(x) >= 3 && range(x) > 0 && range(y) > 0
                [rMat, pMat] = corrcoef(x, y);
                pearsonR = rMat(1, 2);
                pearsonP = pMat(1, 2);
            else
                pearsonR = NaN;
                pearsonP = NaN;
            end

            iRow = iRow + 1;
            summaryRows(iRow, :) = {roiThis, ndThis, ...
                eyeGroupLabels{iEye}, numel(x), pearsonR, pearsonP, ...
                sprintf( ...
                'PerspectiveCueDeltaBias_vs_EyeSpecificAIabsOD_%s_%s', ...
                roiThis, ndThis)};
        end

        xline(ax, 0, 'k--', 'LineWidth', 1.2, 'HandleVisibility', 'off');
        yline(ax, 0, 'k--', 'LineWidth', 1.2, 'HandleVisibility', 'off');
        xlim(ax, xLimits);
        ylim(ax, yLimits);
        title(ax, [roiThis ' ' ndThis ' perspective cues'], ...
            'FontWeight', 'bold');
        xlabel(ax, 'Eye-specific AI \times |OD|');
        ylabel(ax, 'Raw \Delta bias');
        box(ax, 'off');
        set(ax, 'FontSize', 13, 'TickDir', 'out', 'LineWidth', 1.2, ...
            'Layer', 'top');
        legend(ax, scatterHandles, legendLabels, 'Location', 'eastoutside', ...
            'FontSize', 10, 'Box', 'off');

        fileStem = sprintf( ...
            'PerspectiveCueDeltaBias_vs_EyeSpecificAIabsOD_%s_%s', ...
            roiThis, ndThis);
        exportgraphics(fig, fullfile(outDir, [fileStem '.png']), ...
            'Resolution', 300);
        exportgraphics(fig, fullfile(outDir, [fileStem '.pdf']), ...
            'ContentType', 'vector');
        savefig(fig, fullfile(outDir, [fileStem '.fig']));
        close(fig);
    end
end

perspectiveCueScatterSummary = cell2table(summaryRows, 'VariableNames', ...
    {'ROI', 'ND', 'EyeGroup', 'N', 'PearsonR', 'PearsonP', 'FileStem'});
writetable(perspectiveCueScatterSummary, ...
    fullfile(outDir, ...
    'PerspectiveCueDeltaBias_vs_EyeSpecificAIabsOD_summary.csv'));
save(fullfile(outDir, ...
    'PerspectiveCueDeltaBias_vs_EyeSpecificAIabsOD_summary.mat'), ...
    'perspectiveCueScatterSummary');

disp(perspectiveCueScatterSummary);
fprintf('Shared x-axis range: [%.1f, %.1f]\n', xLimits(1), xLimits(2));
fprintf('Saved perspective-cue scatter plots to:\n%s\n', outDir);

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

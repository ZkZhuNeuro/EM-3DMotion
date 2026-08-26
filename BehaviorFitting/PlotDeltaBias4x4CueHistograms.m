clear;

% Four-by-four delta-bias histogram figures requested for the MT/FST 2D/3D
% subpopulations. Each cue is aligned to the sign of its own AI. Individual
% session significance is taken from the saved within-coherence bootstrap:
% significant sessions are filled and non-significant sessions are open.
% Median triangles and median zero tests use significant sessions only.

dataFile = 'C:\EM\PopulationAnalysis\unit_table_gof.mat';
bootstrapFile = 'C:\EM\BehaviorFitting\DeltaBiasBootstrap_zeroTest.mat';
outDir = fullfile('C:\EM', 'BehaviorFitting', 'output', 'pdf', ...
    'DeltaBias_4x4_CueHistograms');

dataLoaded = load(dataFile, 'unit_table_gof');
bootstrapLoaded = load(bootstrapFile, 'bootstrapResult');
unitTable = dataLoaded.unit_table_gof;
bootstrapResult = bootstrapLoaded.bootstrapResult;

assert(isequal(bootstrapResult.originalRecIdx(:), ...
    unitTable.OriginalRecIdx(:)), ...
    'Bootstrap results do not match the rows in the current unit table.');
assert(all(bootstrapResult.completed(bootstrapResult.includedMask, :), 'all'), ...
    'Bootstrap testing is incomplete for one or more included sessions.');

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

subpopulationROI = {'MT', 'MT', 'FST', 'FST'};
subpopulationND = {'2D', '3D', '2D', '3D'};
subpopulationLabels = {'MT 2D', 'MT 3D', 'FST 2D', 'FST 3D'};

fixedCueLabels = {'Combined', 'Left eye', 'Right eye', 'Stereo'};
dominanceCueLabels = {'Combined', 'Dominant eye', ...
    'Non-dominant eye', 'Stereo'};
fixedCueColors = [45, 45, 45; 0, 90, 210; 0, 145, 70; ...
    190, 0, 165] ./ 255;
% Match the PopulationAnalysis condition palette exactly: combined black,
% dominant yellow, non-dominant light blue, and stereo magenta.
dominanceCueColors = [0, 0, 0; 254, 191, 15; 110, 205, 221; ...
    234, 0, 233] ./ 255;

histEdges = -2.5:0.2:2.5;
xLimits = [histEdges(1), histEdges(end)];
nRecordings = height(unitTable);
nCues = 4;

deltaBias = nan(nRecordings, nCues);
cueAI = nan(nRecordings, nCues);

for recordingIndex = 1:nRecordings
    biasThis = unitTable.Delta_bias{recordingIndex};
    numberOfAvailableCues = min(nCues, numel(biasThis));
    deltaBias(recordingIndex, 1:numberOfAvailableCues) = ...
        biasThis(1:numberOfAvailableCues);

    aiThis = unitTable.AI{recordingIndex};
    stimElectrode = get_table_scalar(unitTable.StimElec, recordingIndex);
    if ~isempty(aiThis) && size(aiThis, 1) >= nCues && ...
            isfinite(stimElectrode) && stimElectrode >= 1 && ...
            stimElectrode <= size(aiThis, 2)
        cueAI(recordingIndex, :) = aiThis(1:nCues, stimElectrode).';
    end
end

% Positive values indicate that the behavioral delta bias and the AI for the
% same cue point in the same direction.
cueAISign = sign(cueAI);
cueAISign(cueAISign == 0) = NaN;
fixedAlignedBias = deltaBias .* cueAISign;
fixedSignificant = logical(bootstrapResult.significant);

dominanceAlignedBias = nan(nRecordings, nCues);
dominanceSignificant = false(nRecordings, nCues);
dominanceAlignedBias(:, [1, 4]) = fixedAlignedBias(:, [1, 4]);
dominanceSignificant(:, [1, 4]) = fixedSignificant(:, [1, 4]);

for recordingIndex = 1:nRecordings
    odValue = get_table_scalar(unitTable.OD_max, recordingIndex);
    if odValue > 0
        dominanceCueOrder = [2, 3]; % Left is dominant, right is non-dominant.
    elseif odValue < 0
        dominanceCueOrder = [3, 2]; % Right is dominant, left is non-dominant.
    else
        continue
    end
    dominanceAlignedBias(recordingIndex, 2:3) = ...
        fixedAlignedBias(recordingIndex, dominanceCueOrder);
    dominanceSignificant(recordingIndex, 2:3) = ...
        fixedSignificant(recordingIndex, dominanceCueOrder);
end

includeMask = logical(bootstrapResult.includedMask(:));
if ismember('IncludeForAnalysis', unitTable.Properties.VariableNames)
    includeMask = includeMask & unitTable.IncludeForAnalysis == 1;
end

sourceInfo = dir(dataFile);
analysisMetadata = struct();
analysisMetadata.dataFile = dataFile;
analysisMetadata.dataFileTimestamp = sourceInfo.date;
analysisMetadata.bootstrapFile = bootstrapFile;
analysisMetadata.bootstrapAlpha = bootstrapResult.alpha;
analysisMetadata.histogramEdges = histEdges;
analysisMetadata.alignmentRule = ...
    'Each delta bias is multiplied by the sign of the AI for the same cue.';
analysisMetadata.medianRule = ...
    'Medians and median sign tests use bootstrap-significant sessions only.';

dominanceSummary = make_histogram_figure(dominanceAlignedBias, ...
    dominanceSignificant, dominanceCueLabels, dominanceCueColors, unitTable, ...
    includeMask, subpopulationROI, subpopulationND, ...
    subpopulationLabels, histEdges, xLimits, outDir, ...
    'DeltaBias_4x4_DominantNonDominant', ...
    'Delta bias by dominant/non-dominant cue');

fixedEyeSummary = make_histogram_figure(fixedAlignedBias, ...
    fixedSignificant, fixedCueLabels, fixedCueColors, unitTable, includeMask, ...
    subpopulationROI, subpopulationND, subpopulationLabels, ...
    histEdges, xLimits, outDir, 'DeltaBias_4x4_LeftRight', ...
    'Delta bias by left/right cue');

writetable(dominanceSummary, fullfile(outDir, ...
    'DeltaBias_4x4_DominantNonDominant_summary.csv'));
writetable(fixedEyeSummary, fullfile(outDir, ...
    'DeltaBias_4x4_LeftRight_summary.csv'));
save(fullfile(outDir, 'DeltaBias_4x4_CueHistograms_summary.mat'), ...
    'dominanceSummary', 'fixedEyeSummary', 'analysisMetadata');

disp(dominanceSummary);
disp(fixedEyeSummary);
fprintf('Saved 4x4 cue histograms to:\n%s\n', outDir);

function summaryTable = make_histogram_figure(alignedBias, significanceMask, ...
        cueLabels, cueColors, unitTable, includeMask, subpopulationROI, ...
        subpopulationND, subpopulationLabels, histEdges, xLimits, outDir, ...
        fileStem, figureTitle)
    numberOfRows = numel(cueLabels);
    numberOfColumns = numel(subpopulationLabels);
    numberOfPanels = numberOfRows * numberOfColumns;

    panelData = cell(numberOfRows, numberOfColumns);
    panelSignificance = cell(numberOfRows, numberOfColumns);
    panelN = zeros(numberOfRows, numberOfColumns);
    panelNSignificant = zeros(numberOfRows, numberOfColumns);
    panelMedian = nan(numberOfRows, numberOfColumns);
    panelP = nan(numberOfRows, numberOfColumns);
    panelMaxCount = zeros(numberOfRows, numberOfColumns);
    panelOutsideRange = zeros(numberOfRows, numberOfColumns);

    for columnIndex = 1:numberOfColumns
        groupMask = includeMask & ...
            strcmp(unitTable.ROI, subpopulationROI{columnIndex}) & ...
            strcmp(unitTable.ND, subpopulationND{columnIndex});

        for rowIndex = 1:numberOfRows
            values = alignedBias(groupMask, rowIndex);
            isSignificant = significanceMask(groupMask, rowIndex);
            valid = isfinite(values);
            values = values(valid);
            isSignificant = isSignificant(valid);

            panelData{rowIndex, columnIndex} = values;
            panelSignificance{rowIndex, columnIndex} = isSignificant;
            panelN(rowIndex, columnIndex) = numel(values);
            panelNSignificant(rowIndex, columnIndex) = sum(isSignificant);
            panelOutsideRange(rowIndex, columnIndex) = ...
                sum(values < histEdges(1) | values > histEdges(end));

            significantValues = values(isSignificant);
            if ~isempty(significantValues)
                panelMedian(rowIndex, columnIndex) = median(significantValues);
                panelP(rowIndex, columnIndex) = signtest(significantValues, 0, ...
                    'Tail', 'both', 'Method', 'exact');
            end

            counts = histcounts(values, histEdges);
            if ~isempty(counts)
                panelMaxCount(rowIndex, columnIndex) = max(counts);
            end
        end
    end

    panelQ = bh_fdr(panelP);
    columnYTop = zeros(1, numberOfColumns);
    columnYTicks = cell(1, numberOfColumns);
    for columnIndex = 1:numberOfColumns
        maximumCount = max(panelMaxCount(:, columnIndex));
        columnYTop(columnIndex) = max(2, ceil(1.28 * maximumCount));
        tickStep = max(1, ceil(columnYTop(columnIndex) / 4));
        columnYTicks{columnIndex} = ...
            0:tickStep:columnYTop(columnIndex);
    end

    figureHandle = figure('Color', 'w', 'Position', [50, 50, 1800, 1380]);
    layoutHandle = tiledlayout(figureHandle, numberOfRows, numberOfColumns, ...
        'TileSpacing', 'compact', 'Padding', 'compact');
    axesHandles = gobjects(numberOfRows, numberOfColumns);

    for rowIndex = 1:numberOfRows
        for columnIndex = 1:numberOfColumns
            axesHandle = nexttile(layoutHandle, ...
                (rowIndex - 1) * numberOfColumns + columnIndex);
            axesHandles(rowIndex, columnIndex) = axesHandle;
            axesHandle.Toolbar.Visible = 'off';
            hold(axesHandle, 'on');

            values = panelData{rowIndex, columnIndex};
            isSignificant = panelSignificance{rowIndex, columnIndex};
            plot_significance_histogram(axesHandle, values, isSignificant, ...
                cueColors(rowIndex, :), histEdges);
            xline(axesHandle, 0, '--', 'Color', [0.12, 0.12, 0.12], ...
                'LineWidth', 1.0, 'HandleVisibility', 'off');

            xlim(axesHandle, xLimits);
            ylim(axesHandle, [0, columnYTop(columnIndex)]);
            yticks(axesHandle, columnYTicks{columnIndex});
            xticks(axesHandle, -2:1:2);

            medianValue = panelMedian(rowIndex, columnIndex);
            if isfinite(medianValue)
                medianY = 0.91 * columnYTop(columnIndex);
                plot(axesHandle, medianValue, medianY, 'v', ...
                    'MarkerSize', 7.5, ...
                    'MarkerFaceColor', cueColors(rowIndex, :), ...
                    'MarkerEdgeColor', [0.12, 0.12, 0.12], ...
                    'LineWidth', 0.8, 'LineStyle', 'none', ...
                    'HandleVisibility', 'off');
                if panelQ(rowIndex, columnIndex) < 0.05
                    text(axesHandle, medianValue, 0.985 * columnYTop(columnIndex), ...
                        '*', 'HorizontalAlignment', 'center', ...
                        'VerticalAlignment', 'top', 'FontSize', 11, ...
                        'FontWeight', 'bold', 'Clipping', 'on');
                end
            end

            if isfinite(medianValue)
                testText = sprintf(['n=%d; sig=%d\nmedian=%.3f\n' ...
                    'p=%.3g; q=%.3g'], ...
                    panelN(rowIndex, columnIndex), ...
                    panelNSignificant(rowIndex, columnIndex), medianValue, ...
                    panelP(rowIndex, columnIndex), ...
                    panelQ(rowIndex, columnIndex));
            else
                testText = sprintf('n=%d; sig=0\nmedian/test: n/a', ...
                    panelN(rowIndex, columnIndex));
            end
            text(axesHandle, 0.97, 0.90, testText, 'Units', 'normalized', ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
                'FontSize', 8.0, 'Color', [0.15, 0.15, 0.15]);

            if rowIndex == 1
                title(axesHandle, subpopulationLabels{columnIndex}, ...
                    'FontWeight', 'bold', 'FontSize', 12);
            end
            if rowIndex == numberOfRows
                xlabel(axesHandle, 'Own-cue-AI-aligned \Delta bias');
            else
                axesHandle.XTickLabel = [];
            end
            if columnIndex == 1
                ylabel(axesHandle, sprintf('%s\nRecordings', cueLabels{rowIndex}), ...
                    'FontWeight', 'normal');
            end

            box(axesHandle, 'off');
            set(axesHandle, 'FontSize', 9.5, 'TickDir', 'out', ...
                'LineWidth', 0.9, 'Layer', 'top');
        end
    end

    % Same x limits and the same y scale down each column keep every zero
    % line at the same horizontal position within that column.
    for columnIndex = 1:numberOfColumns
        linkaxes(axesHandles(:, columnIndex), 'xy');
    end

    sgtitle(layoutHandle, sprintf(['%s\nFilled: session bias significant; ' ...
        'open: not significant; triangles: significant-only medians; ' ...
        'p: two-sided sign test; *: median FDR q < 0.05'], figureTitle), ...
        'FontWeight', 'bold', 'FontSize', 14);

    drawnow;
    exportgraphics(figureHandle, fullfile(outDir, [fileStem, '.png']), ...
        'Resolution', 300);
    exportgraphics(figureHandle, fullfile(outDir, [fileStem, '.pdf']), ...
        'ContentType', 'vector');
    savefig(figureHandle, fullfile(outDir, [fileStem, '.fig']));
    close(figureHandle);

    rowIndexColumn = zeros(numberOfPanels, 1);
    columnIndexColumn = zeros(numberOfPanels, 1);
    roiColumn = strings(numberOfPanels, 1);
    ndColumn = strings(numberOfPanels, 1);
    cueColumn = strings(numberOfPanels, 1);
    nColumn = zeros(numberOfPanels, 1);
    nSignificantColumn = zeros(numberOfPanels, 1);
    medianColumn = nan(numberOfPanels, 1);
    pColumn = nan(numberOfPanels, 1);
    qColumn = nan(numberOfPanels, 1);
    outsideRangeColumn = zeros(numberOfPanels, 1);

    summaryIndex = 0;
    for rowIndex = 1:numberOfRows
        for columnIndex = 1:numberOfColumns
            summaryIndex = summaryIndex + 1;
            rowIndexColumn(summaryIndex) = rowIndex;
            columnIndexColumn(summaryIndex) = columnIndex;
            roiColumn(summaryIndex) = subpopulationROI{columnIndex};
            ndColumn(summaryIndex) = subpopulationND{columnIndex};
            cueColumn(summaryIndex) = cueLabels{rowIndex};
            nColumn(summaryIndex) = panelN(rowIndex, columnIndex);
            nSignificantColumn(summaryIndex) = ...
                panelNSignificant(rowIndex, columnIndex);
            medianColumn(summaryIndex) = panelMedian(rowIndex, columnIndex);
            pColumn(summaryIndex) = panelP(rowIndex, columnIndex);
            qColumn(summaryIndex) = panelQ(rowIndex, columnIndex);
            outsideRangeColumn(summaryIndex) = ...
                panelOutsideRange(rowIndex, columnIndex);
        end
    end

    summaryTable = table(rowIndexColumn, columnIndexColumn, roiColumn, ...
        ndColumn, cueColumn, nColumn, nSignificantColumn, medianColumn, ...
        pColumn, qColumn, qColumn < 0.05, outsideRangeColumn, ...
        'VariableNames', {'PanelRow', 'PanelColumn', 'ROI', 'ND', 'Cue', 'N_All', ...
        'N_Significant', 'MedianSignificantAlignedDeltaBias', ...
        'MedianSignTestP', 'MedianFDR_Q', 'MedianSignificantFDR', ...
        'N_OutsideHistogramRange'});
end

function h = plot_significance_histogram(axesHandle, values, ...
        significanceMask, color, edges)
    centers = edges(1:end-1) + diff(edges) / 2;
    countsNotSignificant = histcounts(values(~significanceMask), edges);
    countsSignificant = histcounts(values(significanceMask), edges);
    h = bar(axesHandle, centers, ...
        [countsNotSignificant(:), countsSignificant(:)], 'stacked', ...
        'BarWidth', 0.98);

    h(1).FaceColor = 'none';
    h(1).EdgeColor = color;
    h(1).LineWidth = 1.0;
    h(2).FaceColor = color;
    h(2).EdgeColor = color;
    h(2).LineWidth = 0.75;
end

function value = get_table_scalar(column, rowIndex)
    if iscell(column)
        value = column{rowIndex};
    else
        value = column(rowIndex);
    end
    if isempty(value) || ~isscalar(value)
        value = NaN;
    end
end

function qValues = bh_fdr(pValues)
    qValues = nan(size(pValues));
    valid = isfinite(pValues);
    p = pValues(valid);
    if isempty(p)
        return
    end
    [pSorted, sortIndex] = sort(p(:));
    numberOfTests = numel(pSorted);
    qSorted = pSorted .* numberOfTests ./ (1:numberOfTests)';
    for index = numberOfTests - 1:-1:1
        qSorted(index) = min(qSorted(index), qSorted(index + 1));
    end
    qSorted = min(qSorted, 1);
    q = nan(numberOfTests, 1);
    q(sortIndex) = qSorted;
    qValues(valid) = q;
end

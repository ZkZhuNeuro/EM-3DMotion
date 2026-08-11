clear;

dataFile = 'C:\EM\BehaviorFitting\unit_table_gof.mat';
bootstrapFile = 'C:\EM\BehaviorFitting\DeltaBiasBootstrap_zeroTest.mat';
outDir = fullfile(fileparts(dataFile), 'DeltaBias_alignedCombinedAI');

load(dataFile, 'unit_table_gof');
load(bootstrapFile, 'bootstrapResult');

cueLabels = {'Combined', 'Left', 'Right', 'Stereo'};
cueColors = [0 0 0; ...
    0 0 255; ...
    5 150 5; ...
    234 0 233] ./ 255;
roiList = {'MT', 'FST'};
ndList = {'2D', '3D'};
histEdges = -2.5:0.1:2.5;

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

nRec = height(unit_table_gof);
deltaBias = nan(nRec, 4);
combinedAI = nan(nRec, 1);

for i_rec = 1:nRec
    biasThis = unit_table_gof.Delta_bias{i_rec};
    nCueThis = min(4, numel(biasThis));
    deltaBias(i_rec, 1:nCueThis) = biasThis(1:nCueThis);

    aiThis = unit_table_gof.AI{i_rec};
    stimElec = unit_table_gof.StimElec(i_rec);
    if ~isempty(aiThis) && size(aiThis, 1) >= 1 && ...
            isfinite(stimElec) && stimElec >= 1 && stimElec <= size(aiThis, 2)
        combinedAI(i_rec) = aiThis(1, stimElec);
    end
end

% Orient every cue's delta bias to the combined-cue AI of that recording.
% Positive: bias and combined AI point in the same direction.
% Negative: bias and combined AI point in opposite directions.
combinedAISign = sign(combinedAI);
combinedAISign(combinedAISign == 0) = NaN; % AI = 0 has no defined direction.
alignedDeltaBias = deltaBias .* combinedAISign;

assert(isequal(bootstrapResult.originalRecIdx(:), unit_table_gof.OriginalRecIdx(:)), ...
    'Bootstrap results do not match the rows in unit_table_gof.');
assert(all(bootstrapResult.completed(bootstrapResult.includedMask, :), 'all'), ...
    'Bootstrap testing is incomplete for one or more included sessions.');
sigDeltaBias = bootstrapResult.significant;

%% Test whether the median aligned bias differs from zero in each histogram
nROI = numel(roiList);
nND = numel(ndList);
nCue = numel(cueLabels);
medianBias = nan(nROI, nND, nCue);
medianP = nan(nROI, nND, nCue);
medianN = zeros(nROI, nND, nCue);

for i_roi = 1:nROI
    for i_nd = 1:nND
        idxGroup = strcmp(unit_table_gof.ROI, roiList{i_roi}) & ...
            strcmp(unit_table_gof.ND, ndList{i_nd});
        for i_cue = 1:nCue
            x = alignedDeltaBias(idxGroup, i_cue);
            x = x(isfinite(x));
            medianN(i_roi, i_nd, i_cue) = numel(x);
            if ~isempty(x)
                medianBias(i_roi, i_nd, i_cue) = median(x);
                medianP(i_roi, i_nd, i_cue) = signtest(x, 0, ...
                    'Tail', 'both', 'Method', 'exact');
            end
        end
    end
end

medianQ = bh_fdr(medianP);

nTests = nROI * nND * nCue;
roiColumn = strings(nTests, 1);
ndColumn = strings(nTests, 1);
cueColumn = strings(nTests, 1);
nColumn = zeros(nTests, 1);
medianColumn = nan(nTests, 1);
pColumn = nan(nTests, 1);
qColumn = nan(nTests, 1);
i_test = 0;
for i_roi = 1:nROI
    for i_nd = 1:nND
        for i_cue = 1:nCue
            i_test = i_test + 1;
            roiColumn(i_test) = roiList{i_roi};
            ndColumn(i_test) = ndList{i_nd};
            cueColumn(i_test) = cueLabels{i_cue};
            nColumn(i_test) = medianN(i_roi, i_nd, i_cue);
            medianColumn(i_test) = medianBias(i_roi, i_nd, i_cue);
            pColumn(i_test) = medianP(i_roi, i_nd, i_cue);
            qColumn(i_test) = medianQ(i_roi, i_nd, i_cue);
        end
    end
end

medianBiasTests = table(roiColumn, ndColumn, cueColumn, nColumn, ...
    medianColumn, pColumn, qColumn, pColumn < 0.05, qColumn < 0.05, ...
    'VariableNames', {'ROI', 'ND', 'Cue', 'N', 'MedianAlignedDeltaBias', ...
    'SignTestP', 'FDR_Q', 'SignificantRaw', 'SignificantFDR'});
writetable(medianBiasTests, fullfile(outDir, 'MedianBias_zeroTests.csv'));
save(fullfile(outDir, 'MedianBias_zeroTests.mat'), 'medianBiasTests');

for i_roi = 1:numel(roiList)
    for i_nd = 1:numel(ndList)
        roiThis = roiList{i_roi};
        ndThis = ndList{i_nd};
        idxGroup = strcmp(unit_table_gof.ROI, roiThis) & ...
            strcmp(unit_table_gof.ND, ndThis);

        fig = figure('Color', 'w', 'Position', [100 100 1200 850]);
        tl = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

        for i_cue = 1:4
            ax = nexttile(tl);
            hold(ax, 'on');

            x = alignedDeltaBias(idxGroup, i_cue);
            sigThis = sigDeltaBias(idxGroup, i_cue);
            valid = isfinite(x);
            x = x(valid);
            sigThis = sigThis(valid);

            plot_significance_histogram(ax, x, sigThis, ...
                cueColors(i_cue, :), histEdges);
            xline(ax, 0, 'k--', 'LineWidth', 1.3);

            nSame = sum(x > 0);
            nOpposite = sum(x < 0);
            nNonzero = nSame + nOpposite;
            samePct = 100 * nSame / max(nNonzero, 1);
            nSignificant = sum(sigThis);
            medianThis = medianBias(i_roi, i_nd, i_cue);
            medianPThis = medianP(i_roi, i_nd, i_cue);
            medianQThis = medianQ(i_roi, i_nd, i_cue);

            title(ax, sprintf('%s (n = %d)', cueLabels{i_cue}, numel(x)), ...
                'FontWeight', 'normal');
            xlabel(ax, 'AI-aligned \Delta bias');
            ylabel(ax, 'Recordings');
            xlim(ax, [histEdges(1), histEdges(end)]);
            box(ax, 'off');
            set(ax, 'FontSize', 12, 'TickDir', 'out', 'LineWidth', 1.1);

            if isempty(x)
                annotationText = 'No finite values';
            else
                annotationText = sprintf(['Same direction: %d/%d (%.1f%%)\n' ...
                    'Bootstrap p < %.2f: %d/%d\n' ...
                    'Median = %.3f; sign-test p = %.3g\nFDR q = %.3g'], ...
                    nSame, nNonzero, samePct, bootstrapResult.alpha, ...
                    nSignificant, numel(x), medianThis, medianPThis, medianQThis);
            end
            text(ax, 0.04, 0.95, annotationText, ...
                'Units', 'normalized', 'VerticalAlignment', 'top', ...
                'FontSize', 10, 'BackgroundColor', 'w', 'Margin', 3);
        end

        sgtitle(tl, sprintf(['%s %s: delta bias aligned to combined-cue AI\n' ...
            'Colored: 95%% bootstrap CI excludes zero; white: CI includes zero'], ...
            roiThis, ndThis), 'FontWeight', 'bold');

        fileStem = sprintf('DeltaBias_alignedCombinedAI_%s_%s', roiThis, ndThis);
        exportgraphics(fig, fullfile(outDir, [fileStem '.png']), 'Resolution', 300);
        savefig(fig, fullfile(outDir, [fileStem '.fig']));
        close(fig);
    end
end

%% Standalone combined-cue histogram for each ROI x 2D/3D subpopulation
combinedCueIdx = 1;
combinedHistEdges = -1:0.1:1.5;

for i_roi = 1:numel(roiList)
    for i_nd = 1:numel(ndList)
        roiThis = roiList{i_roi};
        ndThis = ndList{i_nd};
        idxGroup = strcmp(unit_table_gof.ROI, roiThis) & ...
            strcmp(unit_table_gof.ND, ndThis);

        x = alignedDeltaBias(idxGroup, combinedCueIdx);
        sigThis = sigDeltaBias(idxGroup, combinedCueIdx);
        valid = isfinite(x);
        x = x(valid);
        sigThis = sigThis(valid);

        nSame = sum(x > 0);
        nOpposite = sum(x < 0);
        nNonzero = nSame + nOpposite;
        samePct = 100 * nSame / max(nNonzero, 1);
        nSignificant = sum(sigThis);
        medianThis = medianBias(i_roi, i_nd, combinedCueIdx);
        medianPThis = medianP(i_roi, i_nd, combinedCueIdx);
        medianQThis = medianQ(i_roi, i_nd, combinedCueIdx);

        fig = figure('Color', 'w', 'Position', [100 100 720 580]);
        ax = axes(fig);
        ax.Toolbar.Visible = 'off';
        hold(ax, 'on');
        hCombined = plot_significance_histogram(ax, x, sigThis, ...
            cueColors(combinedCueIdx, :), combinedHistEdges);
        xline(ax, 0, 'k--', 'LineWidth', 1.5);

        title(ax, sprintf('%s %s combined cue', roiThis, ndThis), ...
            'FontWeight', 'bold');
        xlabel(ax, 'AI-aligned \Delta bias');
        ylabel(ax, 'Recordings');
        xlim(ax, [-1, 1.5]);
        yLimits = ylim(ax);
        ylim(ax, [0, max(2.2, 1.15 * yLimits(2))]);
        yLimits = ylim(ax);
        hMedian = plot(ax, medianThis, 0.965 * yLimits(2), 'v', ...
            'MarkerSize', 10, 'MarkerFaceColor', [0.85 0.1 0.1], ...
            'MarkerEdgeColor', [0.2 0.2 0.2], 'LineStyle', 'none');
        box(ax, 'off');
        set(ax, 'FontSize', 13, 'TickDir', 'out', 'LineWidth', 1.2);
        legend(ax, [hCombined(:); hMedian], ...
            {'Not significant', 'Bootstrap p < 0.05', 'Median'}, ...
            'Location', 'northeast', 'FontSize', 10, 'Box', 'off');

        annotationText = sprintf(['n = %d\nSame direction: %d/%d (%.1f%%)\n' ...
            'Bootstrap p < %.2f: %d/%d\nMedian = %.3f; sign-test p = %.3g\n' ...
            'FDR q = %.3g'], ...
            numel(x), nSame, nNonzero, samePct, bootstrapResult.alpha, ...
            nSignificant, numel(x), medianThis, medianPThis, medianQThis);
        text(ax, 0.04, 0.94, annotationText, ...
            'Units', 'normalized', 'VerticalAlignment', 'top', ...
            'FontSize', 11, 'BackgroundColor', 'w', 'Margin', 4);

        fileStem = sprintf('DeltaBias_alignedCombinedAI_%s_%s_CombinedOnly', ...
            roiThis, ndThis);
        exportgraphics(fig, fullfile(outDir, [fileStem '.png']), 'Resolution', 300);
        exportgraphics(fig, fullfile(outDir, [fileStem '.pdf']), ...
            'ContentType', 'vector');
        savefig(fig, fullfile(outDir, [fileStem '.fig']));
        close(fig);
    end
end

fprintf('Saved aligned delta-bias histograms to:\n%s\n', outDir);

function h = plot_significance_histogram(ax, x, sigMask, cueColor, edges)
    centers = edges(1:end-1) + diff(edges) / 2;
    countsNotSig = histcounts(x(~sigMask), edges);
    countsSig = histcounts(x(sigMask), edges);

    h = bar(ax, centers, [countsNotSig(:), countsSig(:)], 'stacked', ...
        'BarWidth', 1);
    h(1).FaceColor = [1 1 1];
    h(1).EdgeColor = [0.25 0.25 0.25];
    h(1).LineWidth = 0.8;
    h(1).DisplayName = 'Not significant';
    h(2).FaceColor = cueColor;
    h(2).EdgeColor = [0.25 0.25 0.25];
    h(2).LineWidth = 0.8;
    h(2).DisplayName = 'Bootstrap p < 0.05';
end

function qValues = bh_fdr(pValues)
    qValues = nan(size(pValues));
    valid = isfinite(pValues);
    p = pValues(valid);
    [pSorted, sortIdx] = sort(p(:));
    n = numel(pSorted);
    qSorted = pSorted .* n ./ (1:n)';
    for i = n-1:-1:1
        qSorted(i) = min(qSorted(i), qSorted(i + 1));
    end
    qSorted = min(qSorted, 1);
    q = nan(n, 1);
    q(sortIdx) = qSorted;
    qValues(valid) = q;
end

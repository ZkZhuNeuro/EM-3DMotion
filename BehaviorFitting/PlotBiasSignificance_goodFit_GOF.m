clear;

load('C:\EM\BehaviorFitting\unit_table_gof.mat', 'unit_table_gof');

cueLabels = {'Combined', 'Left', 'Right', 'Stereo'};
cueColors = [0 0 0; ...
    0 0 255; ...
    5 150 5; ...
    234 0 233] ./ 255;
roiList = {'MT', 'FST'};
ndList = {'2D', '3D', 'MN', 'NA'};
sigAlpha = 0.05;
histEdgesBias = -2.2:0.1:2.2;
histEdgesAUC = 0:0.05:1;

outDirBias = 'C:\EM\BehaviorFitting\BiasSig_goodfit\';
outDirROC  = 'C:\EM\BehaviorFitting\ROC_goodfit\';
if ~exist(outDirBias, 'dir')
    mkdir(outDirBias);
end
if ~exist(outDirROC, 'dir')
    mkdir(outDirROC);
end

nRec = height(unit_table_gof);
Bias = nan(nRec, 4);
SigBias = false(nRec, 4);
GoodFitBoth = false(nRec, 4);
AUC_N = nan(nRec, 4);
AUC_S = nan(nRec, 4);

for i_rec = 1:nRec
    if ~isempty(unit_table_gof.Behav_bias_NminusS{i_rec})
        bias_this = unit_table_gof.Behav_bias_NminusS{i_rec};
        Bias(i_rec, 1:min(4, numel(bias_this))) = bias_this(1:min(4, numel(bias_this)));
    end

    if ~isempty(unit_table_gof.Behav_fullVSnull_p{i_rec})
        p_this = unit_table_gof.Behav_fullVSnull_p{i_rec};
        SigBias(i_rec, 1:min(4, numel(p_this))) = p_this(1:min(4, numel(p_this))) < sigAlpha;
    end

    if ~isempty(unit_table_gof.Behav_goodfit_both{i_rec})
        good_this = logical(unit_table_gof.Behav_goodfit_both{i_rec});
        GoodFitBoth(i_rec, 1:min(4, numel(good_this))) = good_this(1:min(4, numel(good_this)));
    end

    if ~isempty(unit_table_gof.Behav_propTowardMat_N{i_rec})
        propN_this = unit_table_gof.Behav_propTowardMat_N{i_rec};
        for i_cue = 1:min(4, size(propN_this, 1))
            AUC_N(i_rec, i_cue) = compute_ref_auc(propN_this(i_cue, :));
        end
    end

    if ~isempty(unit_table_gof.Behav_propTowardMat_S{i_rec})
        propS_this = unit_table_gof.Behav_propTowardMat_S{i_rec};
        for i_cue = 1:min(4, size(propS_this, 1))
            AUC_S(i_rec, i_cue) = compute_ref_auc(propS_this(i_cue, :));
        end
    end
end

%% Bias histograms for MT and FST separately, without category split
for i_roi = 1:numel(roiList)
    roi_this = roiList{i_roi};
    idx_roi = strcmp(unit_table_gof.ROI, roi_this);

    fig = figure('Color', 'w', 'Position', [100 100 1200 900]);
    tl = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    for i_cue = 1:4
        ax = nexttile; hold(ax, 'on');

        idx_this = idx_roi & GoodFitBoth(:, i_cue) & isfinite(Bias(:, i_cue));
        x = Bias(idx_this, i_cue);
        sigMask = SigBias(idx_this, i_cue);

        plot_sig_hist(ax, x, sigMask, cueColors(i_cue, :), histEdgesBias);

        n = numel(x);
        nSig = sum(sigMask);
        sigPct = 100 * nSig / max(n, 1);

        xline(ax, 0, '--', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.2);
        xlim(ax, [-2.2 2.2]);
        box(ax, 'off');
        set(ax, 'FontSize', 12, 'TickDir', 'out', 'LineWidth', 1.2);

        title(ax, sprintf('%s - %s', roi_this, cueLabels{i_cue}), 'FontWeight', 'normal');
        xlabel(ax, 'Bias (N - S)');
        ylabel(ax, 'Cases');

        if n == 0
            text(ax, 0.04, 0.95, 'n = 0', ...
                'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 11);
        else
            text(ax, 0.04, 0.95, sprintf('n = %d\nsig = %d/%d (%.1f%%)', ...
                n, nSig, n, sigPct), ...
                'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 11);
        end
    end

    sgtitle(tl, sprintf('Good-fit bias significance histograms | %s', roi_this), ...
        'FontWeight', 'bold');

    exportgraphics(fig, fullfile(outDirBias, sprintf('BiasSig_goodFit_%s.png', roi_this)), ...
        'Resolution', 300);
    close(fig);
end

%% ROC comparison for good fits: plot N and S together for each ROI x category
for i_roi = 1:numel(roiList)
    roi_this = roiList{i_roi};
    idx_roi = strcmp(unit_table_gof.ROI, roi_this);

    for i_nd = 1:numel(ndList)
        nd_this = ndList{i_nd};
        idx_nd = strcmp(unit_table_gof.ND, nd_this);

        if ~any(idx_roi & idx_nd)
            continue
        end

        fig = figure('Color', 'w', 'Position', [100 100 1200 900]);
        tl = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

        for i_cue = 1:4
            ax = nexttile; hold(ax, 'on');

            idx_this = idx_roi & idx_nd & GoodFitBoth(:, i_cue);
            aucN_this = AUC_N(idx_this, i_cue);
            aucS_this = AUC_S(idx_this, i_cue);
            aucN_this = aucN_this(isfinite(aucN_this));
            aucS_this = aucS_this(isfinite(aucS_this));

            if ~isempty(aucN_this)
                histogram(ax, aucN_this, histEdgesAUC, ...
                    'FaceColor', [0.2 0.45 0.85], 'FaceAlpha', 0.55, ...
                    'EdgeColor', 'none', 'DisplayName', 'N');
            end

            if ~isempty(aucS_this)
                histogram(ax, aucS_this, histEdgesAUC, ...
                    'FaceColor', [0.85 0.2 0.2], 'FaceAlpha', 0.55, ...
                    'EdgeColor', 'none', 'DisplayName', 'S');
            end

            xline(ax, 0.5, '--', 'Color', [0.3 0.3 0.3], 'LineWidth', 1.2);
            xlim(ax, [0 1]);
            box(ax, 'off');
            set(ax, 'FontSize', 12, 'TickDir', 'out', 'LineWidth', 1.2);

            title(ax, sprintf('%s - %s - %s', roi_this, nd_this, cueLabels{i_cue}), ...
                'FontWeight', 'normal');
            xlabel(ax, 'AUC');
            ylabel(ax, 'Cases');
            legend(ax, 'Location', 'northwest');

            nCompare = min(numel(aucN_this), numel(aucS_this));
            text(ax, 0.04, 0.95, sprintf('N = %d\nS = %d', numel(aucN_this), numel(aucS_this)), ...
                'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 11);
        end

        sgtitle(tl, sprintf('Good-fit ROC comparison | %s | %s', roi_this, nd_this), ...
            'FontWeight', 'bold');

        exportgraphics(fig, fullfile(outDirROC, ...
            sprintf('ROC_goodFit_compare_%s_%s.png', roi_this, nd_this)), ...
            'Resolution', 300);
        close(fig);
    end
end

function plot_sig_hist(ax, x, sigMask, sigColor, edges)
centers = edges(1:end-1) + diff(edges) / 2;

if isempty(x)
    bar(ax, centers, zeros(size(centers)), 1, 'FaceColor', [1 1 1], 'EdgeColor', [0 0 0]);
    return
end

cInsig = histcounts(x(~sigMask), edges);
cSig = histcounts(x(sigMask), edges);

h = bar(ax, centers, [cInsig(:) cSig(:)], 'stacked', 'BarWidth', 1);
h(1).FaceColor = [1 1 1];
h(1).EdgeColor = [0 0 0];
h(2).FaceColor = sigColor;
h(2).EdgeColor = [0 0 0];
end

function auc = compute_ref_auc(rowVals)
valid = isfinite(rowVals);
scores = rowVals(valid);

if isempty(scores)
    auc = NaN;
    return
end

auc = mean(scores > 0.5) + 0.5 * mean(scores == 0.5);
end

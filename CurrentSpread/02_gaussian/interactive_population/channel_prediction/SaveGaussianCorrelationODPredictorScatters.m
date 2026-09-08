function result = SaveGaussianCorrelationODPredictorScatters(analyses, options)
%SAVEGAUSSIANCORRELATIONODPREDICTORSCATTERS Compare both predictors and areas.
% Input rows are MT 2D / FST 3D; columns are CombinedAI / DominantAIxOD.
% Each R2 point is one complete outer repeat, not an independent neuron.
arguments
    analyses (2, 2) cell
    options.OutputFolder (1, 1) string = ...
        "C:\EM\CurrentSpread\02_gaussian\InteractiveGaussianMetaPopulation\CorrelationOD\BothPredictors_MT2D_FST3D_SourceStimBothEyes"
    options.FigureVisible (1, 1) logical = false
end
areas = ["MT", "FST"];
types = ["2D", "3D"];
modes = ["CombinedAI", "DominantAIxOD"];
labels = ["Combined AI", "Dominant-eye AI x |OD|"];
colors = [230 126 34; 151 78 163] ./ 255;
pairs = table();
summary = table();
for a = 1:2
    for m = 1:2
        x = analyses{a, m};
        if string(x.Area) ~= areas(a) || string(x.UnitType) ~= types(a) || ...
                string(x.PredictorMode) ~= modes(m) || string(x.ODDefinition) ~= "Correlation" || ...
                string(x.CohortDefinition) ~= "SourceStimBothEyes_ChannelBothEyes_v1"
            error('GaussianCorrelationScatter:InvalidAnalysis', ...
                'Expected source-both-eye Correlation OD analyses in area-by-predictor order.');
        end
        rows = x.Robustness.RepeatMetrics;
        rows = sortrows(rows(rows.Condition == "Equal-cue aggregate", :), 'Repeat');
        if height(rows) < 2 || numel(unique(rows.Repeat)) ~= height(rows) || ...
                any(~isfinite([rows.StimOnlyCVR2; rows.GaussianCVR2]))
            error('GaussianCorrelationScatter:InvalidPairs', 'Expected unique finite outer-repeat pairs.');
        end
        delta = rows.GaussianCVR2 - rows.StimOnlyCVR2;
        pBoth = signrank(rows.GaussianCVR2, rows.StimOnlyCVR2, ...
            'tail', 'both', 'method', 'approximate');
        pGreater = signrank(rows.GaussianCVR2, rows.StimOnlyCVR2, ...
            'tail', 'right', 'method', 'approximate');
        summary = [summary; table(areas(a), types(a), modes(m), x.SessionCount, ...
            height(rows), mean(rows.StimOnlyCVR2), mean(rows.GaussianCVR2), ...
            mean(delta), nnz(delta > 0), pBoth, pGreater, ...
            x.Significance.PImprovementOneSided(1), ...
            'VariableNames', {'Area', 'UnitType', 'PredictorMode', 'NumNeurons', ...
            'NumOuterRepeats', 'MeanStimOnlyR2', 'MeanGaussianR2', 'MeanDeltaR2', ...
            'RepeatsImproved', 'SignedRankPTwoSided', 'SignedRankPGaussianGreater', ...
            'CorrectedCVPImprovement'})]; %#ok<AGROW>
        pairs = [pairs; table(repmat(areas(a), height(rows), 1), ...
            repmat(types(a), height(rows), 1), repmat(modes(m), height(rows), 1), ...
            rows.Repeat, rows.StimOnlyCVR2, rows.GaussianCVR2, delta, ...
            'VariableNames', {'Area', 'UnitType', 'PredictorMode', 'OuterRepeat', ...
            'StimOnlyR2', 'GaussianOptimalR2', 'DeltaR2'})]; %#ok<AGROW>
    end
    c = analyses{a, 1}; d = analyses{a, 2};
    if ~isequal(c.SourceRows, d.SourceRows) || ...
            ~isequal(c.GaussianChannelMask, d.GaussianChannelMask) || ...
            ~isequal(c.Points.Observed, d.Points.Observed) || ...
            ~isequal(c.Points.BehaviorSourceCueIndex, d.Points.BehaviorSourceCueIndex) || ...
            ~isequal(c.Gaussian.FoldAssignments, d.Gaussian.FoldAssignments) || ...
            ~isequal(c.Gaussian.Nested.InnerFoldAssignments, d.Gaussian.Nested.InnerFoldAssignments) || ...
            ~isequal(c.Gaussian.SigmaValues, d.Gaussian.SigmaValues)
        error('GaussianCorrelationScatter:UnmatchedModels', ...
            'Both predictors must share neurons, channels, targets, sigma grid, and inner/outer folds.');
    end
end
outputFolder = string(char(java.io.File(char(options.OutputFolder)).getCanonicalPath()));
repo = string(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
repo = string(char(java.io.File(char(repo)).getCanonicalPath()));
if strcmpi(outputFolder, repo) || startsWith(lower(outputFolder), lower(repo + filesep))
    error('GaussianCorrelationScatter:RepositoryOutput', 'Save generated artifacts outside the repository.');
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
values = [pairs.StimOnlyR2; pairs.GaussianOptimalR2];
limits = [min(values), max(values)];
limits = limits + [-1 1] .* max(0.025, 0.08 .* diff(limits));
f = figure('Visible', 'off', 'Color', 'w', 'Position', [70 50 1380 1160]);
cleanup = onCleanup(@() closeHidden(f, options.FigureVisible));
layout = tiledlayout(f, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
for m = 1:2
    for a = 1:2
        ax = nexttile(layout);
        rows = pairs(pairs.Area == areas(a) & pairs.PredictorMode == modes(m), :);
        stats = summary(summary.Area == areas(a) & summary.PredictorMode == modes(m), :);
        plot(ax, limits, limits, 'k--', 'LineWidth', 1.2); hold(ax, 'on');
        scatter(ax, rows.StimOnlyR2, rows.GaussianOptimalR2, 43, colors(a, :), ...
            'filled', 'MarkerEdgeColor', [0.2 0.2 0.2], 'LineWidth', 0.6);
        xlim(ax, limits); ylim(ax, limits); axis(ax, 'square'); grid(ax, 'on'); box(ax, 'on');
        ax.FontSize = 11;
        title(ax, sprintf('%s %s | %s | N=%d', ...
            areas(a), types(a), labels(m), stats.NumNeurons), 'FontSize', 13);
        subtitle(ax, {sprintf('Mean R^2 %.3f -> %.3f | improved %d/%d', ...
            stats.MeanStimOnlyR2, stats.MeanGaussianR2, stats.RepeatsImproved, stats.NumOuterRepeats); ...
            sprintf('Signed-rank p=%.3g | corrected CV improvement p=%.3g', ...
            stats.SignedRankPTwoSided, stats.CorrectedCVPImprovement)}, 'FontSize', 10);
    end
end
title(layout, 'Correlation-defined OD | original versus Gaussian-optimal prediction', 'FontSize', 17);
subtitle(layout, ['One point per complete outer-CV repeat. Signed-rank tests describe split robustness; ' ...
    'repeats reuse the same neurons.'], 'FontSize', 11);
xlabel(layout, 'Stimulation-channel-only nested-CV R^2');
ylabel(layout, 'Gaussian-optimal nested-CV R^2');
figureFile = fullfile(outputFolder, 'CorrelationOD_OverallR2_BothPredictors_MT2D_FST3D.png');
exportgraphics(f, figureFile, 'Resolution', 220);
savefig(f, fullfile(outputFolder, 'CorrelationOD_OverallR2_BothPredictors_MT2D_FST3D.fig'));
if options.FigureVisible, f.Visible = 'on'; end
writetable(summary, fullfile(outputFolder, 'CorrelationOD_OverallR2_Summary.csv'));
writetable(pairs, fullfile(outputFolder, 'CorrelationOD_OverallR2_Pairs.csv'));
result = struct('Summary', summary, 'Pairs', pairs, 'FigureFile', figureFile, ...
    'OutputFolder', outputFolder, 'ODDefinition', "Correlation");
end

function closeHidden(f, visible)
if ~visible && isgraphics(f), close(f); end
end

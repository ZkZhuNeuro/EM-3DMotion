function result = RunGaussianCorrelationODBetaComparison(options)
%RUNGAUSSIANCORRELATIONODBETACOMPARISON Overlay ordinary cue betas vs sigma.
% Uses the same channel-first solver for both predictors. This is a full-
% sample coefficient diagnostic, not an outer-CV coefficient average.
arguments
    options.CacheRoot (1, 1) string = ...
        "C:\EM\CurrentSpread\02_gaussian\InteractiveGaussianMetaPopulation\CorrelationOD"
    options.OutputFolder (1, 1) string = ""
    options.SigmaValues (1, :) double {mustBeFinite, mustBePositive} = []
end
if strlength(options.OutputFolder) == 0
    options.OutputFolder = fullfile(options.CacheRoot, ...
        'BothPredictors_MT2D_FST3D_SourceStimBothEyes', 'BetaVsSigma');
end
out = string(char(java.io.File(char(options.OutputFolder)).getCanonicalPath()));
repo = string(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
repo = string(char(java.io.File(char(repo)).getCanonicalPath()));
if strcmpi(out, repo) || startsWith(lower(out), lower(repo + filesep))
    error('GaussianBetaComparison:RepositoryOutput', 'Generated outputs must be outside the repository.');
end
areas = ["MT", "FST"];
types = ["2D", "3D"];
modes = ["CombinedAI", "DominantAIxOD"];
cues = ["Dominant", "Combined", "Stereo", "NonDominant"];
fits = cell(2, 2);
curves = cell(2, 2);
cohort = cell(2, 1);
curveTable = table();
for a = 1:2
    cacheFile = fullfile(options.CacheRoot, areas(a), 'GaussianMetaPopulationSigmaCache.mat');
    loaded = load(cacheFile, 'cache'); cache = loaded.cache;
    if string(cache.ODDefinition) ~= "Correlation" || string(cache.Area) ~= areas(a)
        error('GaussianBetaComparison:WrongCache', 'Expected a %s correlation-OD cache.', areas(a));
    end
    first = selectGaussianChannelPredictionCohort(cache, types(a), modes(1));
    second = selectGaussianChannelPredictionCohort(cache, types(a), modes(2));
    if ~isequal(first.SessionMask, second.SessionMask) || ...
            ~isequal(first.ChannelEligible, second.ChannelEligible)
        error('GaussianBetaComparison:UnmatchedCohorts', 'Predictor modes have different eligible neurons or channels.');
    end
    mask = first.SessionMask;
    eligible = first.ChannelEligible(mask, :);
    positions = double(cache.ChannelRelativePositions(mask, :));
    sigma = double(cache.SigmaValues);
    if ~isempty(options.SigmaValues), sigma = options.SigmaValues; end
    cohort{a} = struct('Area', areas(a), 'UnitType', types(a), 'CacheFile', cacheFile, ...
        'SourceRows', double(cache.SourceRows(mask)), 'NeuronCount', nnz(mask), ...
        'ChannelMask', eligible, 'Definition', first.Definition, ...
        'SourceTuningP', first.SourceTuningP(mask, :));
    for m = 1:2
        fprintf('Fitting %s %s %s ordinary beta curves, N=%d...\n', ...
            areas(a), types(a), modes(m), nnz(mask));
        fit = fitGaussianChannelCombinedAIOrdinaryModel( ...
            double(cache.ChannelAI(mask, :, :)), double(cache.ChannelSignedOD(mask, :)), ...
            eligible, positions, double(cache.BehaviorByPhysicalCue(mask, :)), ...
            first.BehaviorValid(mask, :), double(cache.StimReferenceOD(mask)), sigma, ...
            PredictorMode=modes(m));
        if m == 1
            predictor = first.ChannelPredictor(mask, :);
        else
            predictor = second.ChannelPredictor(mask, :);
            assert(isequal(fits{a, 1}.Observed, fit.Observed) && ...
                isequal(fits{a, 1}.ObservationMap, fit.ObservationMap), ...
                'GaussianBetaComparison:UnmatchedTargets', 'Both predictors must fit identical observations.');
        end
        fits{a, m} = fit;
        curves{a, m} = summarizeGaussianChannelBetaCurves(fit, predictor, eligible, positions);
        z = curves{a, m};
        for cue = 1:4
            n = numel(z.SigmaValues);
            curveTable = [curveTable; table(repmat(areas(a), n, 1), ...
                repmat(types(a), n, 1), repmat(modes(m), n, 1), repmat(cues(cue), n, 1), ...
                repmat(z.PerCueCount(cue), n, 1), z.SigmaValues, z.Intercept(cue, :)', ...
                z.Slope(cue, :)', z.PredictorSD(cue, :)', z.ScaleAdjustedSlope(cue, :)', ...
                'VariableNames', {'Area', 'UnitType', 'PredictorMode', 'Cue', 'N', ...
                'Sigma', 'Beta0', 'Beta1', 'PooledPredictorSD', 'Beta1TimesPredictorSD'})]; %#ok<AGROW>
        end
    end
end
if ~isfolder(out), mkdir(out); end
result = struct('ODDefinition', "Correlation", 'FitMethod', "OrdinaryR2", ...
    'Curves', {curves}, 'Cohort', {cohort}, 'CurveTable', curveTable, 'OutputFolder', out);
result.SlopeFigure = plotCurves(curves, cohort, "Slope", ...
    'Slope \beta_1 versus Gaussian sigma', '\beta_1 (\DeltaBias / predictor unit)', ...
    'Raw slopes depend on predictor units; compare scale-adjusted slopes separately.', out);
result.InterceptFigure = plotCurves(curves, cohort, "Intercept", ...
    'Intercept \beta_0 versus Gaussian sigma', '\beta_0 (\DeltaBias)', ...
    'Intercept is predicted bias when the pooled predictor is zero.', out);
result.ScaleAdjustedSlopeFigure = plotCurves(curves, cohort, "ScaleAdjustedSlope", ...
    'Scale-adjusted slope versus Gaussian sigma', '\beta_1 SD(X_\sigma) (\DeltaBias)', ...
    'Predicted bias change per one SD of the pooled predictor, using each cue''s valid neurons.', out);
result.DeltaBiasFigure = plotDeltaBias(fits, cohort, out);
writetable(curveTable, fullfile(out, 'CorrelationOD_BetaVsSigma.csv'));
result.Method = [ ...
    "Ordinary full-sample fits; no CV and no uncertainty bands"; ...
    "Separate beta0 and beta1 for each cue; beta is re-fitted at every sigma"; ...
    "Same neurons, eligible channels, behavioral targets, sigma grid, and least-squares solver for both predictors"; ...
    "Correlation OD = atanh(r(Combined,MonoL)) - atanh(r(Combined,MonoR))"; ...
    "Solid = Combined AI; dashed = dominant-eye AI x absolute local correlation OD"; ...
    "Scale-adjusted slope = beta1 * sample SD of the Gaussian-pooled predictor across valid observations of that cue"; ...
    "Every displayed beta was checked to reproduce the saved full-sample predictions"; ...
    "Circles/triangles mark each model's shared optimal sigma from summed ordinary cue R2"; ...
    "Separate DeltaBias plot: thin lines are individual neuron predictions, thick lines are the across-neuron median"; ...
    "The across-neuron mean prediction is constrained to the observed mean by the fitted intercept, so it is not used as the summary curve"; ...
    "Individual predictions, observed biases, and neuron-to-source-row mappings are saved in the fits and result.Cohort structures"];
writelines(result.Method, fullfile(out, 'BetaVsSigmaManifest.txt'));
save(fullfile(out, 'CorrelationOD_BetaVsSigma.mat'), 'result', 'fits', '-v7.3');
fprintf('Beta comparison saved to %s\n', out);
end

function file = plotCurves(curves, cohort, field, heading, yLabel, note, out)
colors = [230 126 34; 151 78 163] ./ 255;
styles = {'-', '--'}; markers = {'o', '^'};
cues = {'Dominant', 'Combined', 'Stereo', 'NonDominant'};
f = figure('Visible', 'off', 'Color', 'w', 'Position', [70 80 1550 850]);
cleanup = onCleanup(@() close(f));
layout = tiledlayout(f, 2, 4, 'Padding', 'compact', 'TileSpacing', 'compact');
for a = 1:2
    for cue = 1:4
        ax = nexttile(layout); hold(ax, 'on');
        for m = 1:2
            z = curves{a, m};
            values = z.(field)(cue, :);
            plot(ax, z.SigmaValues, values, styles{m}, 'Color', colors(a, :), ...
                'LineWidth', 2.2, 'HandleVisibility', 'off');
            plot(ax, z.BestSigma, values(z.BestIndex), markers{m}, ...
                'Color', colors(a, :), 'MarkerFaceColor', 'w', 'MarkerSize', 7, ...
                'LineWidth', 1.5, 'HandleVisibility', 'off');
        end
        ax.XScale = 'log';
        xlim(ax, [z.SigmaValues(1), z.SigmaValues(end)]);
        yline(ax, 0, ':', 'Color', [0.65 0.65 0.65], 'HandleVisibility', 'off');
        ax.FontSize = 11; grid(ax, 'on'); box(ax, 'on');
        title(ax, sprintf('%s %s | %s | N=%d', cohort{a}.Area, ...
            cohort{a}.UnitType, cues{cue}, z.PerCueCount(cue)), 'FontSize', 12);
        if a == 1 && cue == 1
            h1 = plot(ax, NaN, NaN, '-ok', 'LineWidth', 2, 'MarkerFaceColor', 'w');
            h2 = plot(ax, NaN, NaN, '--^k', 'LineWidth', 2, 'MarkerFaceColor', 'w');
            key = legend(ax, [h1 h2], {'Combined AI', 'Dominant AI x |OD|'}, ...
                'Orientation', 'horizontal', 'FontSize', 12);
            key.Layout.Tile = 'south';
        end
    end
end
title(layout, ['Correlation OD | ' heading ' | ordinary fits'], 'FontSize', 18);
subtitle(layout, {note; 'Solid: Combined AI | dashed: dominant AI x |OD| | markers: each model''s ordinary optimal sigma'}, ...
    'FontSize', 11);
xlabel(layout, 'Gaussian sigma (log scale)', 'FontSize', 14);
ylabel(layout, yLabel, 'FontSize', 14);
file = fullfile(out, 'CorrelationOD_' + field + '_VsSigma_MT2D_FST3D.png');
exportgraphics(f, file, 'Resolution', 220);
savefig(f, replace(file, '.png', '.fig'));
end

function file = plotDeltaBias(fits, cohort, out)
colors = [230 126 34; 151 78 163] ./ 255;
styles = {'-', '--'};
cues = {'Dominant', 'Combined', 'Stereo', 'NonDominant'};
f = figure('Visible', 'off', 'Color', 'w', 'Position', [70 80 1550 850]);
cleanup = onCleanup(@() close(f));
layout = tiledlayout(f, 2, 4, 'Padding', 'compact', 'TileSpacing', 'compact');
for a = 1:2
    allValues = [fits{a, 1}.FullPrediction(:); fits{a, 2}.FullPrediction(:)];
    limits = [min(allValues), max(allValues)];
    limits = limits + [-1 1].*max(0.05, 0.05*diff(limits));
    for cue = 1:4
        ax = nexttile(layout); hold(ax, 'on');
        for m = 1:2
            fit = fits{a, m};
            rows = fit.ObservationMap.ConditionIndex == cue;
            values = fit.FullPrediction(rows, :);
            lightColor = 0.32*colors(a, :)+0.68*[1 1 1];
            plot(ax, fit.SigmaValues, values', styles{m}, ...
                'Color', lightColor, 'LineWidth', 0.5, 'HandleVisibility', 'off');
            plot(ax, fit.SigmaValues, median(values, 1), styles{m}, ...
                'Color', colors(a, :), 'LineWidth', 2.4, 'HandleVisibility', 'off');
        end
        ax.XScale = 'log'; ax.FontSize = 11;
        xlim(ax, [fit.SigmaValues(1), fit.SigmaValues(end)]); ylim(ax, limits);
        yline(ax, 0, ':', 'Color', [0.65 0.65 0.65], 'HandleVisibility', 'off');
        grid(ax, 'on'); box(ax, 'on');
        title(ax, sprintf('%s %s | %s | N=%d', cohort{a}.Area, ...
            cohort{a}.UnitType, cues{cue}, nnz(rows)), 'FontSize', 12);
        if a == 1 && cue == 1
            h1 = plot(ax, NaN, NaN, '-k', 'LineWidth', 2);
            h2 = plot(ax, NaN, NaN, '--k', 'LineWidth', 2);
            key = legend(ax, [h1 h2], {'Combined AI', 'Dominant AI x |OD|'}, ...
                'Orientation', 'horizontal', 'FontSize', 12);
            key.Layout.Tile = 'south';
        end
    end
end
title(layout, 'Correlation OD | predicted \DeltaBias versus Gaussian sigma | ordinary fits', 'FontSize', 18);
subtitle(layout, {'Solid: Combined AI | dashed: dominant AI x |OD|'; ...
    'Thin lines: individual neuron predictions | thick lines: median | fitted predictions, not held-out predictions'}, ...
    'FontSize', 11);
xlabel(layout, 'Gaussian sigma (log scale)', 'FontSize', 14);
ylabel(layout, 'Predicted \DeltaBias', 'FontSize', 14);
file = fullfile(out, 'CorrelationOD_PredictedDeltaBias_VsSigma_MT2D_FST3D.png');
exportgraphics(f, file, 'Resolution', 220);
savefig(f, replace(file, '.png', '.fig'));
end

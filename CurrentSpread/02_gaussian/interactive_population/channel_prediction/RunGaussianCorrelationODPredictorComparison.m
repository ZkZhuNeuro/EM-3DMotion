function result = RunGaussianCorrelationODPredictorComparison(options)
%RUNGAUSSIANCORRELATIONODPREDICTORCOMPARISON Matched MT/FST two-model analysis.
% Reuses the validated correlation-OD neural caches. Max-OD artifacts and
% legacy methods are untouched. All outputs default outside the repository.
arguments
    options.CacheRoot (1, 1) string = ...
        "C:\EM\CurrentSpread\02_gaussian\InteractiveGaussianMetaPopulation\CorrelationOD"
    options.OutputFolder (1, 1) string = ""
    options.NumRepeats (1, 1) double {mustBeInteger, mustBeGreaterThan(options.NumRepeats, 1)} = 100
    options.NumFolds (1, 1) double {mustBeInteger, mustBeGreaterThan(options.NumFolds, 1)} = 5
    options.NumInnerFolds (1, 1) double {mustBeInteger, mustBeGreaterThan(options.NumInnerFolds, 1)} = 5
    options.RandomSeed (1, 1) double {mustBeInteger, mustBeNonnegative} = 1
end
if strlength(options.OutputFolder) == 0
    options.OutputFolder = fullfile(options.CacheRoot, ...
        'BothPredictors_MT2D_FST3D_SourceStimBothEyes');
end
out = string(char(java.io.File(char(options.OutputFolder)).getCanonicalPath()));
repo = string(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
repo = string(char(java.io.File(char(repo)).getCanonicalPath()));
if strcmpi(out, repo) || startsWith(lower(out), lower(repo + filesep))
    error('GaussianCorrelationComparison:RepositoryOutput', 'Outputs must be outside the repository.');
end
areas = ["MT", "FST"];
types = ["2D", "3D"];
modes = ["CombinedAI", "DominantAIxOD"];
analyses = cell(2, 2);
cacheFiles = strings(2, 1);
for a = 1:2
    cacheFile = fullfile(options.CacheRoot, areas(a), 'GaussianMetaPopulationSigmaCache.mat');
    cacheFiles(a) = cacheFile;
    loaded = load(cacheFile, 'cache');
    cache = loaded.cache;
    if string(cache.ODDefinition) ~= "Correlation" || string(cache.Area) ~= areas(a)
        error('GaussianCorrelationComparison:WrongCache', 'Expected %s Correlation OD cache.', areas(a));
    end
    c = selectGaussianChannelPredictionCohort(cache, types(a), "CombinedAI");
    d = selectGaussianChannelPredictionCohort(cache, types(a), "DominantAIxOD");
    if ~isequal(c.SessionMask, d.SessionMask) || ~isequal(c.ChannelEligible, d.ChannelEligible)
        error('GaussianCorrelationComparison:UnmatchedInputs', ...
            'The two predictors do not have identical neuron/channel eligibility.');
    end
    fprintf('%s %s: verified %d source-both-eye neurons with matched channel masks.\n', ...
        areas(a), types(a), nnz(c.SessionMask));
    for m = 1:2
        modelOutput = fullfile(out, areas(a), types(a), ...
            modes(m) + "_GaussianVsStimOnly_CV_Outer" + options.NumRepeats);
        analyses{a, m} = RunGaussianCombinedAIStimChannelCVComparison( ...
            CacheFile=cacheFile, OutputFolder=modelOutput, UnitType=types(a), ...
            PredictorMode=modes(m), NumRepeats=options.NumRepeats, ...
            NumFolds=options.NumFolds, NumInnerFolds=options.NumInnerFolds, ...
            RandomSeed=options.RandomSeed);
    end
end
result = SaveGaussianCorrelationODPredictorScatters(analyses, OutputFolder=out);
result.PredictorCheck = savePredictorCheck(cacheFiles, analyses, out);
result.AnalysisFiles = strings(2, 2);
for a = 1:2
    for m = 1:2
        x = analyses{a, m};
        result.AnalysisFiles(a, m) = fullfile(x.OutputFolder, x.FilePrefix + '.mat');
    end
end
result.Method = [ ...
    "OD = atanh(r(Combined, MonoL)) - atanh(r(Combined, MonoR)) on common finite coherence support"; ...
    "Each channel uses the correlation-OD sign for its dominant AI and the untransformed absolute Fisher-z difference as its multiplier"; ...
    "Observed Dom/NonDom behavior is assigned by stimulation-channel correlation OD"; ...
    "Both predictors share source-both-eye neuron selection, channel masks, behavioral observations, sigma grid, and inner/outer folds"; ...
    "Eight beta coefficients per model: separate intercept and slope for each behavioral cue"; ...
    "Sigma selects minimum inner-CV equal-cue MSE; scatter uses pooled held-out R2 from each outer repeat"; ...
    "Signed-rank p-values describe reused-cohort split robustness; corrected CV inference is reported separately"];
writelines(result.Method, fullfile(out, 'CorrelationOD_ComparisonManifest.txt'));
save(fullfile(out, 'CorrelationOD_BothPredictorsSummary.mat'), 'result');
disp(result.Summary);
disp(result.PredictorCheck.Summary);
end

function result = savePredictorCheck(cacheFiles, analyses, out)
colors = [230 126 34; 151 78 163] ./ 255;
points = table();
summary = table();
f = figure('Visible', 'off', 'Color', 'w', 'Position', [80 90 1330 650]);
cleanup = onCleanup(@() close(f));
layout = tiledlayout(f, 1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
for a = 1:2
    loaded = load(cacheFiles(a), 'cache');
    cache = loaded.cache;
    unitType = analyses{a, 1}.UnitType;
    c = selectGaussianChannelPredictionCohort(cache, unitType, "CombinedAI");
    d = selectGaussianChannelPredictionCohort(cache, unitType, "DominantAIxOD");
    mask = c.ChannelEligible & c.SessionMask;
    [row, col] = find(mask);
    idx = find(mask);
    x = c.ChannelPredictor(idx); y = d.ChannelPredictor(idx);
    stim = c.StimChannelMask(idx);
    rStim = corr(x(stim), y(stim)); rAll = corr(x, y);
    summary = [summary; table(string(cache.Area), string(unitType), nnz(stim), ...
        numel(idx), rStim, rAll, 'VariableNames', ...
        {'Area', 'UnitType', 'NumNeurons', 'NumChannelEntries', 'StimPredictorPearsonR', 'AllChannelPredictorPearsonR'})]; %#ok<AGROW>
    channel = cache.ChannelNumbers(sub2ind(size(mask), row, col));
    points = [points; table(repmat(string(cache.Area), numel(idx), 1), ...
        double(cache.SourceRows(row)), double(channel), stim, x, y, ...
        double(cache.ChannelSignedOD(idx)), 'VariableNames', ...
        {'Area', 'SourceTableRow', 'Channel', 'IsStimulationChannel', 'CombinedAI', ...
        'DominantAIxAbsCorrelationOD', 'SignedCorrelationOD'})]; %#ok<AGROW>
    ax = nexttile(layout); hold(ax, 'on');
    scatter(ax, x(~stim), y(~stim), 21, colors(a, :), 'filled', ...
        'MarkerFaceAlpha', 0.22, 'MarkerEdgeColor', 'none', 'DisplayName', 'Neighboring channels');
    scatter(ax, x(stim), y(stim), 60, colors(a, :), 'filled', ...
        'MarkerEdgeColor', [0.15 0.15 0.15], 'DisplayName', 'Stimulation neurons');
    grid(ax, 'on'); box(ax, 'on'); axis(ax, 'square');
    xlabel(ax, 'Combined AI'); ylabel(ax, 'Dominant-eye AI x |correlation OD|');
    title(ax, sprintf('%s %s | %d neurons', cache.Area, unitType, nnz(stim)));
    subtitle(ax, sprintf('Pearson r: stimulation %.3f | all channels %.3f', rStim, rAll));
    legend(ax, 'Location', 'northwest');
end
title(layout, 'Correlation-defined OD | direct comparison of neural predictors', 'FontSize', 17);
subtitle(layout, 'OD is the Fisher-z correlation difference; |OD| is not clipped or converted to marker opacity.', 'FontSize', 11);
file = fullfile(out, 'CorrelationOD_CombinedAI_vs_DominantAIxOD_MT2D_FST3D.png');
exportgraphics(f, file, 'Resolution', 220);
savefig(f, fullfile(out, 'CorrelationOD_CombinedAI_vs_DominantAIxOD_MT2D_FST3D.fig'));
writetable(summary, fullfile(out, 'CorrelationOD_PredictorCorrelations.csv'));
writetable(points, fullfile(out, 'CorrelationOD_PredictorPoints.csv'));
result = struct('Summary', summary, 'FigureFile', file);
end

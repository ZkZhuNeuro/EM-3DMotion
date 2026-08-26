function result = BuildAllCueR2GaussianMetaObjective(options)
%BUILDALLCUER2GAUSSIANMETAOBJECTIVE Optimize sigma on four population R^2s.
%
% The objective is the unweighted sum of the four MT 2D per-cue repeated
% cross-validated population R-squared values. Every cue uses:
%
%   DeltaBias = beta0 + beta1 * AI + beta2 * (AI .* OD)
%
% There is intentionally no standalone OD main effect.
%
%   J(sigma) = CVR2_Dominant + CVR2_Combined + ...
%              CVR2_Stereo + CVR2_NonDominant.
%
% Population membership, cue ordering, AI, OD, and 2D/3D classification are
% not recalculated here. They are read from the dense Gaussian-meta cache,
% where all of those quantities were already recomputed at every sigma.

arguments
    options.CacheFile (1, 1) string = [ ...
        "C:\EM\CurrentSpread\02_gaussian\" + ...
        "InteractiveGaussianMetaPopulation\" + ...
        "GaussianMetaPopulationSigmaCache.mat"]
    options.OutputFolder (1, 1) string = [ ...
        "C:\EM\CurrentSpread\02_gaussian\" + ...
        "InteractiveGaussianMetaPopulation\AllCueR2Optimization"]
    options.FigureVisible (1, 1) logical = false
    options.NumRepeats (1, 1) double ...
        {mustBeInteger, mustBePositive} = 5
    options.NumFolds (1, 1) double ...
        {mustBeInteger, mustBeGreaterThan(options.NumFolds, 1)} = 5
    options.RandomSeed (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 1
end

if ~isfile(options.CacheFile)
    error('AllCueR2GaussianMeta:MissingCache', ...
        'Gaussian-meta population cache not found: %s', options.CacheFile);
end
loaded = load(options.CacheFile, 'cache');
if ~isfield(loaded, 'cache') || ...
        ~isfield(loaded.cache, 'Statistics') || ...
        ~isfield(loaded.cache.Statistics, 'R2_AIxODWithinCondition')
    error('AllCueR2GaussianMeta:InvalidCache', ...
        'Cache does not contain the four per-cue R-squared curves.');
end
cache = loaded.cache;
sigmaValues = double(cache.SigmaValues(:));
ordinaryPerCueR2 = ...
    double(cache.Statistics.R2_AIxODWithinCondition);
if size(ordinaryPerCueR2, 1) ~= 4 || ...
        size(ordinaryPerCueR2, 2) ~= numel(sigmaValues)
    error('AllCueR2GaussianMeta:InvalidR2Size', ...
        'Expected a 4-by-N per-cue R-squared matrix.');
end

[crossValidatedR2, crossValidatedSEM, r2ByRepeat] = ...
    calculateCrossValidatedCueR2(cache, options.NumRepeats, ...
    options.NumFolds, options.RandomSeed);
validObjective = all(isfinite(crossValidatedR2), 1);
sumFourCueR2 = sum(crossValidatedR2, 1);
sumFourCueR2(~validObjective) = NaN;
if ~any(validObjective)
    error('AllCueR2GaussianMeta:NoFiniteObjective', ...
        'No sigma has four finite per-cue R-squared values.');
end
validIndices = find(validObjective);
[bestValue, relativeIndex] = max(sumFourCueR2(validObjective));
bestIndex = validIndices(relativeIndex);
bestSigma = sigmaValues(bestIndex);

objectiveTable = table(sigmaValues, crossValidatedR2(1, :)', ...
    crossValidatedR2(2, :)', crossValidatedR2(3, :)', ...
    crossValidatedR2(4, :)', ...
    crossValidatedSEM(1, :)', crossValidatedSEM(2, :)', ...
    crossValidatedSEM(3, :)', crossValidatedSEM(4, :)', ...
    sumFourCueR2', (sumFourCueR2 ./ 4)', ...
    ordinaryPerCueR2(1, :)', ordinaryPerCueR2(2, :)', ...
    ordinaryPerCueR2(3, :)', ordinaryPerCueR2(4, :)', ...
    cache.Statistics.N2DSessions(:), ...
    cache.Statistics.N3DSessions(:), ...
    cache.Statistics.NPoints(1, :)', ...
    cache.Statistics.NPoints(2, :)', ...
    cache.Statistics.NPoints(3, :)', ...
    cache.Statistics.NPoints(4, :)', ...
    'VariableNames', {'Sigma', 'CVR2_Dominant', 'CVR2_Combined', ...
    'CVR2_Stereo', 'CVR2_NonDominant', 'CVSEM_Dominant', ...
    'CVSEM_Combined', 'CVSEM_Stereo', 'CVSEM_NonDominant', ...
    'SumFourCueCVR2', 'MeanFourCueCVR2', ...
    'OrdinaryR2_AIPlusAIxOD_Dominant', ...
    'OrdinaryR2_AIPlusAIxOD_Combined', ...
    'OrdinaryR2_AIPlusAIxOD_Stereo', ...
    'OrdinaryR2_AIPlusAIxOD_NonDominant', ...
    'N2DSessions', 'N3DSessions', ...
    'N_Dominant', 'N_Combined', 'N_Stereo', 'N_NonDominant'});

ensureFolder(options.OutputFolder);
writetable(objectiveTable, fullfile(options.OutputFolder, ...
    'AllCueR2GaussianMetaObjective.csv'));

result = struct();
result.CacheFile = options.CacheFile;
result.OutputFolder = options.OutputFolder;
result.ObjectiveDefinition = [ ...
    "CVR2_Dominant + CVR2_Combined + CVR2_Stereo + CVR2_NonDominant"; ...
    "Every cue uses DeltaBias ~ AI + AI:OD, without an OD main effect"; ...
    "Each CVR2 is repeated five-fold held-out performance"; ...
    "Session fold assignments are fixed across sigma and cues"; ...
    "All population inputs and meta-derived assignments come from the dense cache"];
result.SigmaValues = sigmaValues;
result.NumRepeats = options.NumRepeats;
result.NumFolds = options.NumFolds;
result.RandomSeed = options.RandomSeed;
result.ModelFormula = "DeltaBias ~ AI + AI:OD";
result.CrossValidatedR2 = crossValidatedR2;
result.CrossValidatedSEM = crossValidatedSEM;
result.R2ByRepeat = r2ByRepeat;
result.OrdinaryPerCueR2 = ordinaryPerCueR2;
result.SumFourCueCrossValidatedR2 = sumFourCueR2(:);
result.BestIndex = bestIndex;
result.BestSigma = bestSigma;
result.BestSumFourCueCrossValidatedR2 = bestValue;
result.BestPerCueCrossValidatedR2 = crossValidatedR2(:, bestIndex);
result.BestN2DSessions = cache.Statistics.N2DSessions(bestIndex);
result.BestN3DSessions = cache.Statistics.N3DSessions(bestIndex);
result.ObjectiveTable = objectiveTable;
all_cue_r2_optimization = result;
save(fullfile(options.OutputFolder, ...
    'AllCueR2GaussianMetaOptimization.mat'), ...
    'all_cue_r2_optimization', '-v7.3');

previousVisibility = get(groot, 'defaultFigureVisible');
visibilityCleanup = onCleanup( ...
    @() set(groot, 'defaultFigureVisible', previousVisibility));
set(groot, 'defaultFigureVisible', ...
    ternary(options.FigureVisible, 'on', 'off'));
figureHandle = figure('Color', 'w', ...
    'Name', 'All-cue summed-R2 Gaussian-meta objective', ...
    'Position', [120 120 980 650]);
hold on
conditionNames = ["Dominant", "Combined", "Stereo", "NonDominant"];
conditionColors = double(cache.ConditionColors);
for condition = 1:4
    plot(sigmaValues, crossValidatedR2(condition, :), '-', ...
        'Color', conditionColors(condition, :), 'LineWidth', 1.2, ...
        'DisplayName', conditionNames(condition) + " CV R^2");
end
plot(sigmaValues, sumFourCueR2, 'k-', 'LineWidth', 3, ...
    'DisplayName', 'Sum of four cue CV R^2 values');
xline(bestSigma, 'r--', 'LineWidth', 2, ...
    'DisplayName', sprintf('Best sigma = %.6g', bestSigma));
plot(bestSigma, bestValue, 'ro', 'MarkerFaceColor', 'r', ...
    'MarkerSize', 8, 'HandleVisibility', 'off');
set(gca, 'XScale', 'log');
grid on; box on
xlabel('Gaussian \sigma');
ylabel('Cross-validated population R^2 objective');
title(['MT 2D Gaussian-meta optimization: four-cue CV R^2 sum, ' ...
    'DeltaBias ~ AI + AI:OD']);
subtitle(sprintf('Best sigma %.6g; summed CV R^2 %.4f; meta 2D N = %d', ...
    bestSigma, bestValue, result.BestN2DSessions));
legend('Location', 'best');
exportgraphics(figureHandle, fullfile(options.OutputFolder, ...
    'AllCueR2GaussianMetaObjective.png'), 'Resolution', 300);
savefig(figureHandle, fullfile(options.OutputFolder, ...
    'AllCueR2GaussianMetaObjective.fig'));
close(figureHandle);
clear visibilityCleanup

manifest = [ ...
    "All-cue Gaussian-meta R-squared optimization"; ...
    "Objective: " + result.ObjectiveDefinition(1); ...
    "Model: " + result.ModelFormula; ...
    "Best sigma: " + bestSigma; ...
    "Best summed cross-validated R-squared: " + bestValue; ...
    "Per-cue cross-validated R-squared at optimum: " + ...
    join(compose('%.8g', result.BestPerCueCrossValidatedR2), ", "); ...
    "Meta-classified 2D sessions at optimum: " + result.BestN2DSessions; ...
    "Source cache: " + options.CacheFile];
writelines(manifest, fullfile(options.OutputFolder, ...
    'AllCueR2GaussianMetaManifest.txt'));

fprintf(['All-cue summed-CV-R2 optimum: sigma %.12g, objective %.8f, ' ...
    'meta 2D N=%d. Outputs: %s\n'], bestSigma, bestValue, ...
    result.BestN2DSessions, options.OutputFolder);
end


function [meanR2, semR2, r2ByRepeat] = ...
    calculateCrossValidatedCueR2(cache, numRepeats, requestedFolds, seed)
numSessions = size(cache.PointAI, 1);
numSigmas = size(cache.PointAI, 3);
numFolds = min(requestedFolds, numSessions);
r2ByRepeat = nan(numRepeats, 4, numSigmas);
foldsByRepeat = zeros(numSessions, numRepeats);
for repeat = 1:numRepeats
    foldsByRepeat(:, repeat) = balancedFolds( ...
        numSessions, numFolds, seed + repeat - 1);
end

for sigmaIndex = 1:numSigmas
    for condition = 1:4
        valid = cache.PointValid(:, condition, sigmaIndex);
        predictor = double(cache.PointAI(:, condition, sigmaIndex));
        ocularDominance = double(cache.PointOD(:, sigmaIndex));
        behavior = double(cache.PointBias(:, condition, sigmaIndex));
        valid = valid & isfinite(predictor) & ...
            isfinite(ocularDominance) & isfinite(behavior);
        for repeat = 1:numRepeats
            folds = foldsByRepeat(:, repeat);
            prediction = nan(numSessions, 1);
            nullPrediction = nan(numSessions, 1);
            for fold = 1:numFolds
                test = valid & folds == fold;
                train = valid & folds ~= fold;
                beta = fitAIByODModel(predictor(train), ...
                    ocularDominance(train), behavior(train));
                if all(isfinite(beta))
                    prediction(test) = beta(1) + ...
                        beta(2) .* predictor(test) + ...
                        beta(3) .* predictor(test) .* ocularDominance(test);
                end
                if any(train)
                    nullPrediction(test) = mean(behavior(train), 'omitnan');
                end
            end
            r2ByRepeat(repeat, condition, sigmaIndex) = ...
                crossValidatedR2(behavior, prediction, nullPrediction);
        end
    end
end
meanR2 = reshape(mean(r2ByRepeat, 1, 'omitnan'), 4, numSigmas);
semR2 = reshape(std(r2ByRepeat, 0, 1, 'omitnan') ./ sqrt(numRepeats), ...
    4, numSigmas);
end


function beta = fitAIByODModel(predictor, ocularDominance, behavior)
valid = isfinite(predictor) & isfinite(ocularDominance) & ...
    isfinite(behavior);
if nnz(valid) < 4
    beta = [NaN; NaN; NaN];
    return
end
design = [ones(nnz(valid), 1), predictor(valid), ...
    predictor(valid) .* ocularDominance(valid)];
if rank(design) < size(design, 2)
    beta = [NaN; NaN; NaN];
    return
end
beta = design \ behavior(valid);
end


function value = crossValidatedR2(observed, predicted, nullPredicted)
valid = isfinite(observed) & isfinite(predicted) & isfinite(nullPredicted);
modelSSE = sum((observed(valid) - predicted(valid)) .^ 2);
nullSSE = sum((observed(valid) - nullPredicted(valid)) .^ 2);
if nnz(valid) < 3 || nullSSE <= eps
    value = NaN;
else
    value = 1 - modelSSE ./ nullSSE;
end
end


function folds = balancedFolds(numRows, numFolds, seed)
stream = RandStream('mt19937ar', 'Seed', seed);
order = randperm(stream, numRows);
folds = zeros(numRows, 1);
folds(order) = mod(0:numRows-1, numFolds) + 1;
end


function ensureFolder(folder)
if ~isfolder(folder)
    mkdir(folder);
end
end


function value = ternary(condition, trueValue, falseValue)
if condition
    value = trueValue;
else
    value = falseValue;
end
end

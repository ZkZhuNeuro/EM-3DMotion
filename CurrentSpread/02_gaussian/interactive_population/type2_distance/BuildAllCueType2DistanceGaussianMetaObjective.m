function result = BuildAllCueType2DistanceGaussianMetaObjective(options)
%BUILDALLCUETYPE2DISTANCEGAUSSIANMETAOBJECTIVE Minimize four-cue line error.
%
% For every sigma and cue, this function calculates the squared
% perpendicular distance from each displayed population point to that cue's
% cached OD-weighted Type II regression line. It averages the squared
% distances within each cue before summing the four cue means:
%
%   J(sigma) = mean(d_Dominant.^2) + mean(d_Combined.^2) + ...
%              mean(d_Stereo.^2) + mean(d_NonDominant.^2).
%
% Averaging within cue prevents a cue with more included sessions from
% receiving more weight merely because it has more points. The four cue
% means are otherwise equally weighted, and the sigma minimizing J is used.

arguments
    options.CacheFile (1, 1) string = [ ...
        "C:\EM\CurrentSpread\02_gaussian\" + ...
        "InteractiveGaussianMetaPopulation\MT\" + ...
        "GaussianMetaPopulationSigmaCache.mat"]
    options.OutputFolder (1, 1) string = ""
    options.UnitType (1, 1) string ...
        {mustBeMember(options.UnitType, ["2D", "3D"])} = "2D"
    options.FigureVisible (1, 1) logical = false
end

if ~isfile(options.CacheFile)
    error('AllCueType2DistanceGaussianMeta:MissingCache', ...
        'Gaussian-meta population cache not found: %s', options.CacheFile);
end
loaded = load(options.CacheFile, 'cache');
if ~isfield(loaded, 'cache')
    error('AllCueType2DistanceGaussianMeta:InvalidCache', ...
        'Cache file does not contain a cache structure.');
end
cache = loaded.cache;
if isfield(cache, 'ODDefinition')
    odDefinition = string(cache.ODDefinition);
else
    odDefinition = "Max";
end
validateCache(cache);
commonFolder = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'common');
addpath(commonFolder);
selected = selectGaussianMetaUnitTypeData(cache, options.UnitType);
statistics = selected.Statistics;
pointValid = selected.PointValid;
if strlength(options.OutputFolder) == 0
    options.OutputFolder = fullfile(cache.OutputFolder, options.UnitType, ...
        'AllCueType2DistanceOptimization');
end

sigmaValues = double(cache.SigmaValues(:));
numSigmas = numel(sigmaValues);
meanSquaredDistance = nan(4, numSigmas);
sumSquaredDistance = nan(4, numSigmas);
pointCount = zeros(4, numSigmas);

for sigmaIndex = 1:numSigmas
    for condition = 1:4
        valid = pointValid(:, condition, sigmaIndex);
        x = double(cache.PointAI(:, condition, sigmaIndex));
        y = double(cache.PointBias(:, condition, sigmaIndex));
        valid = valid & isfinite(x) & isfinite(y);
        slope = double( ...
            statistics.WeightedSlope(condition, sigmaIndex));
        intercept = double( ...
            statistics.WeightedIntercept(condition, sigmaIndex));
        pointCount(condition, sigmaIndex) = nnz(valid);
        if ~any(valid) || ~all(isfinite([slope, intercept]))
            continue
        end

        squaredDistance = (slope .* x(valid) - y(valid) + intercept) .^ 2 ...
            ./ (slope .^ 2 + 1);
        sumSquaredDistance(condition, sigmaIndex) = ...
            sum(squaredDistance);
        meanSquaredDistance(condition, sigmaIndex) = ...
            mean(squaredDistance);
    end
end

validObjective = all(isfinite(meanSquaredDistance), 1);
sumFourCueMeanSquaredDistance = sum(meanSquaredDistance, 1);
sumFourCueMeanSquaredDistance(~validObjective) = NaN;
if ~any(validObjective)
    error('AllCueType2DistanceGaussianMeta:NoFiniteObjective', ...
        'No sigma has finite mean squared distances for all four cues.');
end
validIndices = find(validObjective);
[bestValue, relativeIndex] = ...
    min(sumFourCueMeanSquaredDistance(validObjective));
bestIndex = validIndices(relativeIndex);
bestSigma = sigmaValues(bestIndex);

conditionTokens = ["Dominant", "Combined", "Stereo", "NonDominant"];
objectiveTable = table(sigmaValues, ...
    sumFourCueMeanSquaredDistance', ...
    mean(meanSquaredDistance, 1)', ...
    statistics.N2DSessions(:), ...
    statistics.N3DSessions(:), ...
    'VariableNames', {'Sigma', 'SumFourCueMeanSquaredDistance', ...
    'MeanFourCueMeanSquaredDistance', 'N2DSessions', 'N3DSessions'});
for condition = 1:4
    token = conditionTokens(condition);
    objectiveTable.("MeanSquaredDistance_" + token) = ...
        meanSquaredDistance(condition, :)';
    objectiveTable.("SumSquaredDistance_" + token) = ...
        sumSquaredDistance(condition, :)';
    objectiveTable.("N_" + token) = pointCount(condition, :)';
    objectiveTable.("Type2Slope_" + token) = ...
        statistics.WeightedSlope(condition, :)';
    objectiveTable.("Type2Intercept_" + token) = ...
        statistics.WeightedIntercept(condition, :)';
end

ensureFolder(options.OutputFolder);
writetable(objectiveTable, fullfile(options.OutputFolder, ...
    'AllCueType2DistanceGaussianMetaObjective.csv'));

result = struct();
result.CacheFile = options.CacheFile;
result.OutputFolder = options.OutputFolder;
result.Area = selected.Area;
result.UnitType = options.UnitType;
result.ODDefinition = odDefinition;
result.ObjectiveDefinition = [ ...
    "For each cue, mean squared perpendicular distance to its displayed OD-weighted Type II line"; ...
    "Objective is the unweighted sum of the four cue-wise means"; ...
    "Each dot has equal objective weight within its cue; OD is used in the displayed line fit"; ...
    "All population inputs and meta-derived assignments come from the dense cache"];
result.SigmaValues = sigmaValues;
result.PerCueMeanSquaredDistance = meanSquaredDistance;
result.PerCueSumSquaredDistance = sumSquaredDistance;
result.PerCuePointCount = pointCount;
result.SumFourCueMeanSquaredDistance = ...
    sumFourCueMeanSquaredDistance(:);
result.BestIndex = bestIndex;
result.BestSigma = bestSigma;
result.BestSumFourCueMeanSquaredDistance = bestValue;
result.BestPerCueMeanSquaredDistance = ...
    meanSquaredDistance(:, bestIndex);
result.BestPerCuePointCount = pointCount(:, bestIndex);
result.BestN2DSessions = statistics.N2DSessions(bestIndex);
result.BestN3DSessions = statistics.N3DSessions(bestIndex);
result.ObjectiveTable = objectiveTable;
all_cue_type2_distance_optimization = result;
save(fullfile(options.OutputFolder, ...
    'AllCueType2DistanceGaussianMetaOptimization.mat'), ...
    'all_cue_type2_distance_optimization', '-v7.3');

previousVisibility = get(groot, 'defaultFigureVisible');
visibilityCleanup = onCleanup( ...
    @() set(groot, 'defaultFigureVisible', previousVisibility));
set(groot, 'defaultFigureVisible', ...
    ternary(options.FigureVisible, 'on', 'off'));
figureHandle = figure('Color', 'w', ...
    'Name', 'All-cue Type II distance Gaussian-meta objective', ...
    'Position', [120 120 980 650]);
hold on
conditionColors = double(cache.ConditionColors);
for condition = 1:4
    plot(sigmaValues, meanSquaredDistance(condition, :), '-', ...
        'Color', conditionColors(condition, :), 'LineWidth', 1.2, ...
        'DisplayName', conditionTokens(condition) + " mean squared distance");
end
plot(sigmaValues, sumFourCueMeanSquaredDistance, 'k-', 'LineWidth', 3, ...
    'DisplayName', 'Sum of four cue means');
xline(bestSigma, 'r--', 'LineWidth', 2, ...
    'DisplayName', sprintf('Best sigma = %.6g', bestSigma));
plot(bestSigma, bestValue, 'ro', 'MarkerFaceColor', 'r', ...
    'MarkerSize', 8, 'HandleVisibility', 'off');
set(gca, 'XScale', 'log');
grid on; box on
xlabel('Gaussian \sigma');
ylabel('Squared perpendicular-distance objective');
title(sprintf([ ...
    '%s %s Gaussian-meta optimization (%s OD): ' ...
    'distance to four Type II lines'], ...
    result.Area, result.UnitType, result.ODDefinition));
subtitle(sprintf(['Best sigma %.6g; summed cue-wise mean squared distance ' ...
    '%.6g; meta %s N = %d'], bestSigma, bestValue, result.UnitType, ...
    selectedSessionCount(result, result.UnitType)));
legend('Location', 'best');
exportgraphics(figureHandle, fullfile(options.OutputFolder, ...
    'AllCueType2DistanceGaussianMetaObjective.png'), 'Resolution', 300);
savefig(figureHandle, fullfile(options.OutputFolder, ...
    'AllCueType2DistanceGaussianMetaObjective.fig'));
close(figureHandle);
clear visibilityCleanup

manifest = [ ...
    "All-cue Gaussian-meta Type II line-distance optimization"; ...
    "Area: " + result.Area; ...
    "Unit type: " + result.UnitType; ...
    "OD definition: " + result.ODDefinition; ...
    "Objective: " + result.ObjectiveDefinition(1); ...
    "Cue aggregation: " + result.ObjectiveDefinition(2); ...
    "Best sigma: " + bestSigma; ...
    "Minimum summed cue-wise mean squared distance: " + bestValue; ...
    "Per-cue means at optimum: " + ...
    join(compose('%.8g', result.BestPerCueMeanSquaredDistance), ", "); ...
    "Per-cue point counts at optimum: " + ...
    join(compose('%d', result.BestPerCuePointCount), ", "); ...
    "Meta-classified sessions at optimum: " + ...
    selectedSessionCount(result, result.UnitType); ...
    "Source cache: " + options.CacheFile];
writelines(manifest, fullfile(options.OutputFolder, ...
    'AllCueType2DistanceGaussianMetaManifest.txt'));

fprintf(['All-cue Type II distance optimum: sigma %.12g, objective %.8g, ' ...
    '%s %s N=%d. Outputs: %s\n'], bestSigma, bestValue, ...
    result.Area, result.UnitType, ...
    selectedSessionCount(result, result.UnitType), options.OutputFolder);
end


function validateCache(cache)
required = ["SigmaValues", "PointAI", "PointBias", "PointValid", ...
    "ConditionColors", "Statistics"];
missing = required(~isfield(cache, required));
if ~isempty(missing)
    error('AllCueType2DistanceGaussianMeta:InvalidCache', ...
        'Cache is missing required field(s): %s', join(missing, ', '));
end
requiredStatistics = ["WeightedSlope", "WeightedIntercept", ...
    "N2DSessions", "N3DSessions"];
missingStatistics = ...
    requiredStatistics(~isfield(cache.Statistics, requiredStatistics));
if ~isempty(missingStatistics)
    error('AllCueType2DistanceGaussianMeta:InvalidCache', ...
        'Cache statistics are missing required field(s): %s', ...
        join(missingStatistics, ', '));
end
numSigmas = numel(cache.SigmaValues);
if size(cache.PointAI, 2) ~= 4 || ...
        size(cache.PointAI, 3) ~= numSigmas || ...
        ~isequal(size(cache.PointBias), size(cache.PointAI)) || ...
        ~isequal(size(cache.PointValid), size(cache.PointAI)) || ...
        ~isequal(size(cache.Statistics.WeightedSlope), [4 numSigmas]) || ...
        ~isequal(size(cache.Statistics.WeightedIntercept), [4 numSigmas])
    error('AllCueType2DistanceGaussianMeta:InvalidCacheSize', ...
        'Cached point or line arrays do not match the four-cue sigma grid.');
end
end


function count = selectedSessionCount(result, unitType)
if unitType == "2D"
    count = result.BestN2DSessions;
else
    count = result.BestN3DSessions;
end
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

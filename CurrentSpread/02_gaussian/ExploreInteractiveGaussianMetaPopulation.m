function app = ExploreInteractiveGaussianMetaPopulation(options)
%EXPLOREINTERACTIVEGAUSSIANMETAPOPULATION Browse cached MT population results.
%
% The slider indexes precomputed results; no meta tuning, classification,
% OD calculation, or population fitting occurs while it is dragged.
%
% Example:
%   ExploreInteractiveGaussianMetaPopulation;

arguments
    options.CacheFile (1, 1) string = [ ...
        "C:\EM\CurrentSpread\02_gaussian\" + ...
        "InteractiveGaussianMetaPopulation\" + ...
        "GaussianMetaPopulationSigmaCache.mat"]
    options.InitialSigma (1, 1) double = NaN
    options.MetricMode (1, 1) string ...
        {mustBeMember(options.MetricMode, ...
        ["PerCueR2", "SumFourCueR2", ...
        "SumFourCueOrdinaryR2", ...
        "SumFourCueMeanSquaredDistance"])} = "PerCueR2"
    options.MetricPerCue double = []
    options.ObjectiveValues double = []
    options.MetricPerCueR2 double = []
    options.SumFourCueR2 double = []
    options.ObjectiveLabel (1, 1) string = "Sum of four cue R^2"
    options.MarkerEdgeAlpha (1, 1) double ...
        {mustBeGreaterThanOrEqual(options.MarkerEdgeAlpha, 0), ...
        mustBeLessThanOrEqual(options.MarkerEdgeAlpha, 1)} = 0.85
    options.Visible (1, 1) string ...
        {mustBeMember(options.Visible, ["on", "off"])} = "on"
    options.Position (1, 4) double = [60 60 1540 900]
end

if ~isfile(options.CacheFile)
    error('GaussianMetaInteractive:MissingCache', ...
        ['Interactive cache not found: %s\nRun ' ...
        'BuildInteractiveGaussianMetaPopulationCache first.'], ...
        options.CacheFile);
end
loaded = load(options.CacheFile, 'cache');
if ~isfield(loaded, 'cache')
    error('GaussianMetaInteractive:InvalidCache', ...
        'Cache file does not contain a cache structure.');
end
cache = loaded.cache;
validateCache(cache);

sigmaValues = double(cache.SigmaValues(:));
numSigmas = numel(sigmaValues);
conditionNames = string(cache.ConditionNames(:));
conditionColors = double(cache.ConditionColors);
monkeyNames = ["Jim", "Clay"];
monkeyMarkers = {'o', 'd'};
isObjectiveMode = options.MetricMode ~= "PerCueR2";
isDistanceMode = ...
    options.MetricMode == "SumFourCueMeanSquaredDistance";
isInteractionR2Mode = options.MetricMode == "SumFourCueR2" || ...
    options.MetricMode == "SumFourCueOrdinaryR2";
metricPerCue = double(cache.Statistics.R2_AI);
if isObjectiveMode && ~isempty(options.MetricPerCue)
    if ~isequal(size(options.MetricPerCue), [4 numSigmas])
        error('GaussianMetaInteractive:InvalidMetricPerCue', ...
            'MetricPerCue must be 4-by-N, with one column per sigma.');
    end
    metricPerCue = double(options.MetricPerCue);
elseif isObjectiveMode && ~isempty(options.MetricPerCueR2)
    if ~isequal(size(options.MetricPerCueR2), [4 numSigmas])
        error('GaussianMetaInteractive:InvalidMetricPerCueR2', ...
            'MetricPerCueR2 must be 4-by-N, with one column per sigma.');
    end
    metricPerCue = double(options.MetricPerCueR2);
end
if isObjectiveMode && ~isempty(options.ObjectiveValues)
    if numel(options.ObjectiveValues) ~= numSigmas
        error('GaussianMetaInteractive:InvalidObjectiveValues', ...
            'ObjectiveValues must contain one value per sigma.');
    end
    objectiveValues = double(options.ObjectiveValues(:)');
elseif isObjectiveMode && ~isempty(options.SumFourCueR2)
    if numel(options.SumFourCueR2) ~= numSigmas
        error('GaussianMetaInteractive:InvalidSumFourCueR2', ...
            'SumFourCueR2 must contain one value per sigma.');
    end
    objectiveValues = double(options.SumFourCueR2(:)');
else
    objectiveValues = sum(metricPerCue, 1);
end
validFourCueObjective = all(isfinite(metricPerCue), 1) & ...
    isfinite(objectiveValues);
objectiveValues(~validFourCueObjective) = NaN;
allCueBestIndex = NaN;
allCueBestSigma = NaN;
allCueBestValue = NaN;
if any(validFourCueObjective)
    validIndices = find(validFourCueObjective);
    if isDistanceMode
        [allCueBestValue, relativeBest] = ...
            min(objectiveValues(validFourCueObjective));
    else
        [allCueBestValue, relativeBest] = ...
            max(objectiveValues(validFourCueObjective));
    end
    allCueBestIndex = validIndices(relativeBest);
    allCueBestSigma = sigmaValues(allCueBestIndex);
end
if isfinite(options.InitialSigma) && options.InitialSigma > 0
    initialSigma = options.InitialSigma;
elseif isObjectiveMode
    initialSigma = allCueBestSigma;
else
    initialSigma = 5.01187233627272;
end
[~, initialIndex] = min(abs(sigmaValues - initialSigma));

figureName = 'MT 2D Gaussian-meta population explorer';
if options.MetricMode == "SumFourCueR2"
    figureName = 'MT 2D all-cue summed-R2 Gaussian-meta explorer';
elseif options.MetricMode == "SumFourCueOrdinaryR2"
    figureName = 'MT 2D all-cue ordinary-R2 Gaussian-meta explorer';
elseif isDistanceMode
    figureName = 'MT 2D all-cue Type II distance Gaussian-meta explorer';
end
figureHandle = uifigure('Name', figureName, ...
    'Color', 'w', 'Visible', char(options.Visible), ...
    'Position', options.Position);
mainGrid = uigridlayout(figureHandle, [2 2]);
mainGrid.RowHeight = {'1x', 108};
mainGrid.ColumnWidth = {'3x', '1.15x'};
mainGrid.Padding = [14 12 14 10];
mainGrid.RowSpacing = 10;
mainGrid.ColumnSpacing = 12;

populationAxes = uiaxes(mainGrid);
populationAxes.Layout.Row = 1;
populationAxes.Layout.Column = 1;
configurePopulationAxes(populationAxes);

rightGrid = uigridlayout(mainGrid, [3 1]);
rightGrid.Layout.Row = 1;
rightGrid.Layout.Column = 2;
rightGrid.RowHeight = {'0.9x', '1.35x', '1.15x'};
rightGrid.Padding = [0 0 0 0];
rightGrid.RowSpacing = 9;

weightAxes = uiaxes(rightGrid);
title(weightAxes, 'Nominal Gaussian profile');
xlabel(weightAxes, 'Relative contact');
ylabel(weightAxes, 'Weight');
grid(weightAxes, 'on');
box(weightAxes, 'on');
weightPositions = -7:7;
weightLine = plot(weightAxes, weightPositions, nan(size(weightPositions)), ...
    'o-', 'LineWidth', 2, 'Color', [0.1 0.35 0.7], ...
    'MarkerFaceColor', [0.1 0.35 0.7]);
xlim(weightAxes, [-7.5 7.5]);

metricAxes = uiaxes(rightGrid);
hold(metricAxes, 'on');
metricLines = gobjects(4, 1);
for metricCondition = 1:4
    metricLines(metricCondition) = plot(metricAxes, sigmaValues, ...
        metricPerCue(metricCondition, :), '-', ...
        'Color', conditionColors(metricCondition, :), 'LineWidth', 1.5, ...
        'DisplayName', conditionNames(metricCondition));
end
objectiveLine = gobjects(0);
optimalCursor = gobjects(0);
if isObjectiveMode
    objectiveLine = plot(metricAxes, sigmaValues, objectiveValues, ...
        'k-', 'LineWidth', 2.8, ...
        'DisplayName', options.ObjectiveLabel);
    optimalCursor = xline(metricAxes, allCueBestSigma, 'r:', ...
        'LineWidth', 2, 'HandleVisibility', 'off');
end
metricCursor = xline(metricAxes, sigmaValues(initialIndex), 'k--', ...
    'LineWidth', 1.5, 'HandleVisibility', 'off');
metricAxes.XScale = 'log';
grid(metricAxes, 'on');
box(metricAxes, 'on');
xlabel(metricAxes, 'Gaussian \sigma');
if isObjectiveMode
    if isDistanceMode
        ylabel(metricAxes, 'Mean squared distance / summed objective');
        title(metricAxes, 'All-cue Type II line-distance objective');
    else
        ylabel(metricAxes, 'Per-cue R^2 / summed objective');
        title(metricAxes, 'All-cue summed-R^2 objective');
    end
    legend(metricAxes, [metricLines; objectiveLine], ...
        [cellstr(conditionNames); {char(options.ObjectiveLabel)}], ...
        'Location', 'best');
else
    ylabel(metricAxes, 'Ordinary population R^2');
    title(metricAxes, 'Cached per-cue fits');
    legend(metricAxes, metricLines, cellstr(conditionNames), ...
        'Location', 'best');
end

statisticsArea = uitextarea(rightGrid, 'Editable', 'off', ...
    'FontName', 'Consolas', 'FontSize', 12, ...
    'BackgroundColor', [0.98 0.98 0.98]);

controlGrid = uigridlayout(mainGrid, [2 4]);
controlGrid.Layout.Row = 2;
controlGrid.Layout.Column = [1 2];
controlGrid.RowHeight = {30, 48};
controlGrid.ColumnWidth = {155, '1x', 145, 170};
controlGrid.Padding = [0 0 0 0];
controlGrid.RowSpacing = 3;

sigmaLabel = uilabel(controlGrid, 'Text', 'Gaussian sigma', ...
    'FontWeight', 'bold', 'FontSize', 13, ...
    'HorizontalAlignment', 'right');
sigmaLabel.Layout.Row = 1;
sigmaLabel.Layout.Column = 1;
currentSigmaLabel = uilabel(controlGrid, 'Text', '', ...
    'FontWeight', 'bold', 'FontSize', 14);
currentSigmaLabel.Layout.Row = 1;
currentSigmaLabel.Layout.Column = 2;
indexLabel = uilabel(controlGrid, 'Text', '', ...
    'HorizontalAlignment', 'right');
indexLabel.Layout.Row = 1;
indexLabel.Layout.Column = 3;
countLabel = uilabel(controlGrid, 'Text', '', ...
    'HorizontalAlignment', 'right');
countLabel.Layout.Row = 1;
countLabel.Layout.Column = 4;

slider = uislider(controlGrid, 'Limits', [1 numSigmas], ...
    'Value', initialIndex);
slider.Layout.Row = 2;
slider.Layout.Column = [1 4];
tickIndices = unique(round(linspace(1, numSigmas, 9)));
slider.MajorTicks = tickIndices;
slider.MajorTickLabels = cellstr(compose('%.3g', sigmaValues(tickIndices)));

hold(populationAxes, 'on');
xPlot = linspace(-1, 1, 101);
fitLines = gobjects(4, 1);
scatterHandles = gobjects(4, 2);
for initialCondition = 1:4
    fitLines(initialCondition) = plot( ...
        populationAxes, xPlot, nan(size(xPlot)), ...
        '-', 'Color', conditionColors(initialCondition, :), ...
        'LineWidth', 2.5, ...
        'DisplayName', conditionNames(initialCondition));
    for initialMonkey = 1:2
        scatterHandles(initialCondition, initialMonkey) = scatter( ...
            populationAxes, nan, nan, 42, ...
            conditionColors(initialCondition, :), ...
            monkeyMarkers{initialMonkey}, 'filled', ...
            'MarkerEdgeColor', conditionColors(initialCondition, :), ...
            'LineWidth', 1.25, 'HandleVisibility', 'off');
        scatterHandles(initialCondition, initialMonkey).MarkerFaceAlpha = 'flat';
        scatterHandles(initialCondition, initialMonkey).MarkerEdgeAlpha = ...
            options.MarkerEdgeAlpha;
    end
end
jimLegend = scatter(populationAxes, nan, nan, 42, 'k', 'o', 'filled', ...
    'DisplayName', 'Jim');
clayLegend = scatter(populationAxes, nan, nan, 42, 'k', 'd', 'filled', ...
    'DisplayName', 'Clay');
legend(populationAxes, [fitLines; jimLegend; clayLegend], ...
    [cellstr(conditionNames); {'Jim'; 'Clay'}], ...
    'Location', 'eastoutside');

lastIndex = NaN;
slider.ValueChangingFcn = @(~, event) updateDisplay(round(event.Value));
slider.ValueChangedFcn = @(~, event) updateDisplay(round(event.Value));
updateDisplay(initialIndex);

app = struct();
app.Figure = figureHandle;
app.PopulationAxes = populationAxes;
app.WeightAxes = weightAxes;
app.MetricAxes = metricAxes;
app.Slider = slider;
app.CacheFile = options.CacheFile;
app.MetricMode = options.MetricMode;
app.ObjectiveValues = objectiveValues;
app.MetricPerCue = metricPerCue;
app.SumFourCueR2 = objectiveValues;
app.MetricPerCueR2 = metricPerCue;
app.AllCueBestIndex = allCueBestIndex;
app.AllCueBestSigma = allCueBestSigma;
app.AllCueBestValue = allCueBestValue;
app.AllCueOptimalCursor = optimalCursor;

    function updateDisplay(index)
        index = max(1, min(numSigmas, round(index)));
        if isequal(index, lastIndex)
            return
        end
        lastIndex = index;
        sigma = sigmaValues(index);
        od = double(cache.PointOD(:, index));
        for displayCondition = 1:4
            for displayMonkey = 1:2
                valid = cache.PointValid(:, displayCondition, index) & ...
                    strcmpi(string(cache.Monkey), monkeyNames(displayMonkey));
                x = double(cache.PointAI(valid, displayCondition, index));
                y = double(cache.PointBias(valid, displayCondition, index));
                alpha = od(valid);
                alpha = min(max(alpha, 0), 1);
                set(scatterHandles(displayCondition, displayMonkey), ...
                    'XData', x, 'YData', y, 'AlphaData', alpha);
            end
            slope = cache.Statistics.WeightedSlope(displayCondition, index);
            intercept = cache.Statistics.WeightedIntercept(displayCondition, index);
            if isfinite(slope) && isfinite(intercept)
                fitLines(displayCondition).YData = intercept + slope .* xPlot;
            else
                fitLines(displayCondition).YData = nan(size(xPlot));
            end
        end

        nominalWeights = exp(-(weightPositions .^ 2) ./ (2 .* sigma ^ 2));
        nominalWeights = nominalWeights ./ sum(nominalWeights);
        weightLine.YData = nominalWeights;
        weightAxes.YLim = [0 max(0.08, 1.12 * max(nominalWeights))];
        metricCursor.Value = sigma;

        n2D = cache.Statistics.N2DSessions(index);
        n3D = cache.Statistics.N3DSessions(index);
        title(populationAxes, sprintf([ ...
            'MT 2D Gaussian-meta population | sigma %.5g | ' ...
            'meta-classified 2D N=%d'], sigma, n2D), ...
            'FontSize', 17);
        if isObjectiveMode
            if isDistanceMode
                subtitle(populationAxes, sprintf([ ...
                    'Current objective = %.5g | ' ...
                    'minimum sigma %.6g (sum = %.5g)'], ...
                    objectiveValues(index), allCueBestSigma, ...
                    allCueBestValue));
            else
                subtitle(populationAxes, sprintf([ ...
                    'Current objective = %.4f | ' ...
                    'optimum sigma %.6g (sum = %.4f)'], ...
                    objectiveValues(index), allCueBestSigma, ...
                    allCueBestValue));
            end
        else
            subtitle(populationAxes, '');
        end
        currentSigmaLabel.Text = sprintf('%.8g', sigma);
        indexLabel.Text = sprintf('grid %d / %d', index, numSigmas);
        countLabel.Text = sprintf('2D %d | 3D %d', n2D, n3D);
        statisticsArea.Value = buildStatisticsText(index, sigma);
        slider.Value = index;
        drawnow limitrate nocallbacks
    end

    function lines = buildStatisticsText(index, sigma)
        effective = median(double(cache.EffectiveChannels(:, index)), ...
            'omitnan');
        lines = [ ...
            string(sprintf('sigma = %.7g', sigma)); ...
            string(sprintf('median effective channels = %.2f', effective)); ...
            string(sprintf('meta 2D / 3D = %d / %d', ...
            cache.Statistics.N2DSessions(index), ...
            cache.Statistics.N3DSessions(index)))];
        if isObjectiveMode
            lines = [lines; ...
                string(sprintf('four-cue objective = %.5f', ...
                objectiveValues(index))); ...
                string(sprintf('best sigma = %.7g | best sum = %.5f', ...
                allCueBestSigma, allCueBestValue))];
            if isInteractionR2Mode
                lines = [lines; "model = DeltaBias ~ AI + AI:OD"];
            end
        end
        if isDistanceMode
            metricHeader = "MeanSqD";
            pHeader = "p(AI)";
        elseif options.MetricMode == "SumFourCueR2"
            metricHeader = "CVR2";
            pHeader = "p(AI:OD)";
        elseif options.MetricMode == "SumFourCueOrdinaryR2"
            metricHeader = "R2";
            pHeader = "p(AI:OD)";
        else
            metricHeader = "R2";
            pHeader = "p(AI)";
        end
        lines = [lines; ""; ...
            "Cue             N   wSlope    " + metricHeader + ...
            "      " + pHeader];
        for statCondition = 1:4
            if isInteractionR2Mode
                displayedPValue = ...
                    cache.Statistics.P_AIxODWithinCondition( ...
                    statCondition, index);
            else
                displayedPValue = cache.Statistics.P_AI(statCondition, index);
            end
            lines(end + 1, 1) = sprintf('%-13s %3d  %+7.3f  %6.3f  %.3g', ...
                conditionNames(statCondition), ...
                cache.Statistics.NPoints(statCondition, index), ...
                cache.Statistics.WeightedSlope(statCondition, index), ...
                metricPerCue(statCondition, index), ...
                displayedPValue); %#ok<AGROW>
        end
        lines = [lines; ""; ...
            sprintf('Merged eyes: N=%d units=%d', ...
            cache.Statistics.MergedNPoints(index), ...
            cache.Statistics.MergedNUnits(index)); ...
            sprintf('AI + AI:OD R2 = %.3f', ...
            cache.Statistics.MergedR2(index)); ...
            sprintf('p(AI) = %.3g | p(AI:OD) = %.3g', ...
            cache.Statistics.MergedP_AI(index), ...
            cache.Statistics.MergedP_AIxOD(index))];
    end
end


function configurePopulationAxes(axesHandle)
hold(axesHandle, 'on');
plot(axesHandle, [-1 1], [0 0], 'k--', 'HandleVisibility', 'off');
plot(axesHandle, [0 0], [-2.2 2.2], 'k--', 'HandleVisibility', 'off');
xlim(axesHandle, [-1 1]);
ylim(axesHandle, [-2.2 2.2]);
axesHandle.XTick = -1:0.5:1;
axesHandle.XTickLabel = {'-1', 'Away', '0', 'Towards', '1'};
axesHandle.YTick = -2:1:2;
axesHandle.YTickLabel = {'-2', 'Away', '0', 'Towards', '2'};
xlabel(axesHandle, 'Gaussian-meta asymmetry index', 'FontSize', 15);
ylabel(axesHandle, 'Delta Bias', 'FontSize', 15);
axesHandle.FontSize = 14;
axesHandle.LineWidth = 1;
box(axesHandle, 'on');
grid(axesHandle, 'off');
axis(axesHandle, 'square');
end


function validateCache(cache)
required = ["SchemaVersion", "SigmaValues", "Monkey", ...
    "PointAI", "PointBias", "PointOD", "PointValid", ...
    "EffectiveChannels", "ConditionNames", "ConditionColors", ...
    "Statistics"];
missing = required(~isfield(cache, required));
if ~isempty(missing)
    error('GaussianMetaInteractive:InvalidCache', ...
        'Cache is missing required field(s): %s', join(missing, ', '));
end
numSigmas = numel(cache.SigmaValues);
if size(cache.PointAI, 3) ~= numSigmas || ...
        size(cache.PointBias, 3) ~= numSigmas || ...
        size(cache.PointValid, 3) ~= numSigmas
    error('GaussianMetaInteractive:InvalidCacheSize', ...
        'Cached point arrays do not match SigmaValues.');
end
end

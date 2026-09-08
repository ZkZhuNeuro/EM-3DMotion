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
    options.UnitType (1, 1) string ...
        {mustBeMember(options.UnitType, ["2D", "3D"])} = "2D"
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
    options.MarkerEdgeAlpha (1, 1) double = NaN
    options.MarkerSize (1, 1) double ...
        {mustBeGreaterThanOrEqual(options.MarkerSize, 8), ...
        mustBeLessThanOrEqual(options.MarkerSize, 200)} = 42
    options.MarkerEdgeWidth (1, 1) double ...
        {mustBeGreaterThanOrEqual(options.MarkerEdgeWidth, 0.25), ...
        mustBeLessThanOrEqual(options.MarkerEdgeWidth, 5)} = 1.25
    options.MarkerFaceMode (1, 1) string ...
        {mustBeMember(options.MarkerFaceMode, ["Color", "Grayscale"])} = ...
        "Color"
    options.MarkerFaceAlphaFloor (1, 1) double = NaN
    options.MarkerFaceAlphaCeiling (1, 1) double ...
        {mustBeGreaterThanOrEqual(options.MarkerFaceAlphaCeiling, 0), ...
        mustBeLessThanOrEqual(options.MarkerFaceAlphaCeiling, 1)} = 1
    options.ReserveSelectionRow (1, 1) logical = false
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
isCorrelationOD = isfield(cache, 'ODDefinition') && ...
    string(cache.ODDefinition) == "Correlation";
if isnan(options.MarkerFaceAlphaFloor)
    options.MarkerFaceAlphaFloor = 0;
end
if isnan(options.MarkerEdgeAlpha)
    if isCorrelationOD
        options.MarkerEdgeAlpha = 0.95;
    else
        options.MarkerEdgeAlpha = 0.85;
    end
end
if options.MarkerFaceAlphaFloor < 0 || ...
        options.MarkerFaceAlphaFloor > 1 || ...
        options.MarkerEdgeAlpha < 0 || options.MarkerEdgeAlpha > 1
    error('GaussianMetaInteractive:MarkerAlphaRange', ...
        'Marker alpha values must be between zero and one.');
end
if options.MarkerFaceAlphaFloor > options.MarkerFaceAlphaCeiling
    error('GaussianMetaInteractive:MarkerAlphaRange', ...
        'MarkerFaceAlphaFloor cannot exceed MarkerFaceAlphaCeiling.');
end
selected = selectGaussianMetaUnitTypeData(cache, options.UnitType);
pointValid = selected.PointValid;
statistics = selected.Statistics;
areaName = selected.Area;
if isfield(cache, 'ODDefinition')
    odDefinition = string(cache.ODDefinition);
else
    odDefinition = "Max";
end
odLabel = odDefinition + " OD";

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
metricPerCue = double(statistics.R2_AI);
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

figureName = sprintf('%s %s Gaussian-meta population explorer (%s)', ...
    areaName, options.UnitType, odLabel);
if options.MetricMode == "SumFourCueR2"
    figureName = sprintf( ...
        '%s %s all-cue summed-R2 Gaussian-meta explorer (%s)', ...
        areaName, options.UnitType, odLabel);
elseif options.MetricMode == "SumFourCueOrdinaryR2"
    figureName = sprintf( ...
        '%s %s all-cue ordinary-R2 Gaussian-meta explorer (%s)', ...
        areaName, options.UnitType, odLabel);
elseif isDistanceMode
    figureName = sprintf( ...
        '%s %s all-cue Type II distance Gaussian-meta explorer (%s)', ...
        areaName, options.UnitType, odLabel);
end
figureHandle = uifigure('Name', figureName, ...
    'Color', 'w', 'Visible', char(options.Visible), ...
    'Position', options.Position);
mainGrid = uigridlayout(figureHandle, [2 2]);
if options.ReserveSelectionRow
    mainGrid.RowHeight = {'1x', 208};
else
    mainGrid.RowHeight = {'1x', 174};
end
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

if options.ReserveSelectionRow
    controlGrid = uigridlayout(mainGrid, [4 4]);
    controlGrid.RowHeight = {28, 26, 48, 84};
    labelRow = 2;
    sliderRow = 3;
    appearanceRow = 4;
else
    controlGrid = uigridlayout(mainGrid, [3 4]);
    controlGrid.RowHeight = {26, 48, 84};
    labelRow = 1;
    sliderRow = 2;
    appearanceRow = 3;
end
controlGrid.Layout.Row = 2;
controlGrid.Layout.Column = [1 2];
controlGrid.ColumnWidth = {155, '1x', 145, 170};
controlGrid.Padding = [0 0 0 0];
controlGrid.RowSpacing = 3;

sigmaLabel = uilabel(controlGrid, 'Text', 'Gaussian sigma', ...
    'FontWeight', 'bold', 'FontSize', 13, ...
    'HorizontalAlignment', 'right');
sigmaLabel.Layout.Row = labelRow;
sigmaLabel.Layout.Column = 1;
currentSigmaLabel = uilabel(controlGrid, 'Text', '', ...
    'FontWeight', 'bold', 'FontSize', 14);
currentSigmaLabel.Layout.Row = labelRow;
currentSigmaLabel.Layout.Column = 2;
indexLabel = uilabel(controlGrid, 'Text', '', ...
    'HorizontalAlignment', 'right');
indexLabel.Layout.Row = labelRow;
indexLabel.Layout.Column = 3;
countLabel = uilabel(controlGrid, 'Text', '', ...
    'HorizontalAlignment', 'right');
countLabel.Layout.Row = labelRow;
countLabel.Layout.Column = 4;

slider = uislider(controlGrid, 'Limits', [1 numSigmas], ...
    'Value', initialIndex);
slider.Layout.Row = sliderRow;
slider.Layout.Column = [1 4];
tickIndices = unique(round(linspace(1, numSigmas, 9)));
slider.MajorTicks = tickIndices;
slider.MajorTickLabels = cellstr(compose('%.3g', sigmaValues(tickIndices)));

appearanceGrid = uigridlayout(controlGrid, [1 4]);
appearanceGrid.Layout.Row = appearanceRow;
appearanceGrid.Layout.Column = [1 4];
appearanceGrid.ColumnWidth = {'1x', '1x', '1x', 190};
appearanceGrid.Padding = [0 0 0 0];
appearanceGrid.ColumnSpacing = 14;

[dotSizeGroup, dotSizeLabel] = makeAppearanceGroup( ...
    appearanceGrid, 1, sprintf('Dot size: %.0f', options.MarkerSize));
dotSizeSlider = uislider(dotSizeGroup, 'Limits', [8 200], ...
    'Value', options.MarkerSize, ...
    'MajorTicks', [8 50 100 150 200], ...
    'Tooltip', 'Change the area of every population dot');
dotSizeSlider.Layout.Row = 2;

[edgeAlphaGroup, edgeAlphaLabel] = makeAppearanceGroup( ...
    appearanceGrid, 2, sprintf( ...
    'Edge transparency: %.2f', 1 - options.MarkerEdgeAlpha));
edgeTransparencySlider = uislider(edgeAlphaGroup, 'Limits', [0 1], ...
    'Value', 1 - options.MarkerEdgeAlpha, ...
    'MajorTicks', [0 0.25 0.5 0.75 1], ...
    'Tooltip', '0 is opaque; 1 is transparent');
edgeTransparencySlider.Layout.Row = 2;

[edgeWidthGroup, edgeWidthLabel] = makeAppearanceGroup( ...
    appearanceGrid, 3, sprintf( ...
    'Edge width: %.2f', options.MarkerEdgeWidth));
edgeWidthSlider = uislider(edgeWidthGroup, 'Limits', [0.25 5], ...
    'Value', options.MarkerEdgeWidth, ...
    'MajorTicks', [0.25 1 2 3 4 5], ...
    'Tooltip', 'Change the outline width of every population dot');
edgeWidthSlider.Layout.Row = 2;

[faceModeGroup, ~] = makeAppearanceGroup( ...
    appearanceGrid, 4, 'Dot face fill');
faceModeDropDown = uidropdown(faceModeGroup, ...
    'Items', {'Condition color', 'Grayscale'}, ...
    'ItemsData', {'Color', 'Grayscale'}, ...
    'Value', char(options.MarkerFaceMode), ...
    'Tooltip', 'Choose colored or grayscale dot faces');
faceModeDropDown.Layout.Row = 2;

hold(populationAxes, 'on');
xPlot = linspace(-1, 1, 101);
fitLines = gobjects(4, 1);
scatterHandles = gobjects(4, 2);
markerSize = options.MarkerSize;
markerEdgeAlpha = options.MarkerEdgeAlpha;
markerEdgeWidth = options.MarkerEdgeWidth;
markerFaceMode = options.MarkerFaceMode;
for initialCondition = 1:4
    fitLines(initialCondition) = plot( ...
        populationAxes, xPlot, nan(size(xPlot)), ...
        '-', 'Color', conditionColors(initialCondition, :), ...
        'LineWidth', 2.5, ...
        'DisplayName', conditionNames(initialCondition));
    for initialMonkey = 1:2
        scatterHandles(initialCondition, initialMonkey) = scatter( ...
            populationAxes, nan, nan, markerSize, ...
            conditionColors(initialCondition, :), ...
            monkeyMarkers{initialMonkey}, 'filled', ...
            'MarkerEdgeColor', conditionColors(initialCondition, :), ...
            'LineWidth', markerEdgeWidth, 'HandleVisibility', 'off');
        scatterHandles(initialCondition, initialMonkey).MarkerFaceAlpha = 'flat';
        scatterHandles(initialCondition, initialMonkey).MarkerEdgeAlpha = ...
            markerEdgeAlpha;
    end
end
jimLegend = scatter(populationAxes, nan, nan, markerSize, 'k', 'o', 'filled', ...
    'DisplayName', 'Jim');
clayLegend = scatter(populationAxes, nan, nan, markerSize, 'k', 'd', 'filled', ...
    'DisplayName', 'Clay');
legend(populationAxes, [fitLines; jimLegend; clayLegend], ...
    [cellstr(conditionNames); {'Jim'; 'Clay'}], ...
    'Location', 'eastoutside');

dotSizeSlider.ValueChangingFcn = @(~, event) ...
    setDotSize(event.Value);
dotSizeSlider.ValueChangedFcn = @(~, event) ...
    setDotSize(event.Value);
edgeTransparencySlider.ValueChangingFcn = @(~, event) ...
    setEdgeTransparency(event.Value);
edgeTransparencySlider.ValueChangedFcn = @(~, event) ...
    setEdgeTransparency(event.Value);
edgeWidthSlider.ValueChangingFcn = @(~, event) ...
    setEdgeWidth(event.Value);
edgeWidthSlider.ValueChangedFcn = @(~, event) ...
    setEdgeWidth(event.Value);
faceModeDropDown.ValueChangedFcn = @(source, ~) ...
    setFaceMode(string(source.Value));
applyMarkerStyle();

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
app.ControlGrid = controlGrid;
app.CacheFile = options.CacheFile;
app.Area = areaName;
app.UnitType = options.UnitType;
app.MetricMode = options.MetricMode;
app.ObjectiveValues = objectiveValues;
app.MetricPerCue = metricPerCue;
app.SumFourCueR2 = objectiveValues;
app.MetricPerCueR2 = metricPerCue;
app.DotSizeSlider = dotSizeSlider;
app.EdgeTransparencySlider = edgeTransparencySlider;
app.EdgeWidthSlider = edgeWidthSlider;
app.FaceModeDropDown = faceModeDropDown;
app.GetDisplaySettings = @getDisplaySettings;
app.AllCueBestIndex = allCueBestIndex;
app.AllCueBestSigma = allCueBestSigma;
app.AllCueBestValue = allCueBestValue;
app.AllCueOptimalCursor = optimalCursor;

    function settings = getDisplaySettings()
        settings = struct( ...
            'MarkerSize', markerSize, ...
            'MarkerEdgeAlpha', markerEdgeAlpha, ...
            'MarkerEdgeWidth', markerEdgeWidth, ...
            'MarkerFaceMode', markerFaceMode);
    end

    function setDotSize(value)
        markerSize = max(8, min(200, double(value)));
        dotSizeLabel.Text = sprintf('Dot size: %.0f', markerSize);
        for condition = 1:4
            for monkey = 1:2
                scatterHandles(condition, monkey).SizeData = markerSize;
            end
        end
        jimLegend.SizeData = markerSize;
        clayLegend.SizeData = markerSize;
        drawnow limitrate nocallbacks
    end

    function setEdgeTransparency(value)
        transparency = max(0, min(1, double(value)));
        markerEdgeAlpha = 1 - transparency;
        edgeAlphaLabel.Text = sprintf( ...
            'Edge transparency: %.2f', transparency);
        for condition = 1:4
            for monkey = 1:2
                scatterHandles(condition, monkey).MarkerEdgeAlpha = ...
                    markerEdgeAlpha;
            end
        end
        jimLegend.MarkerEdgeAlpha = markerEdgeAlpha;
        clayLegend.MarkerEdgeAlpha = markerEdgeAlpha;
        drawnow limitrate nocallbacks
    end

    function setEdgeWidth(value)
        markerEdgeWidth = max(0.25, min(5, double(value)));
        edgeWidthLabel.Text = sprintf( ...
            'Edge width: %.2f', markerEdgeWidth);
        for condition = 1:4
            for monkey = 1:2
                scatterHandles(condition, monkey).LineWidth = ...
                    markerEdgeWidth;
            end
        end
        jimLegend.LineWidth = markerEdgeWidth;
        clayLegend.LineWidth = markerEdgeWidth;
        drawnow limitrate nocallbacks
    end

    function setFaceMode(value)
        markerFaceMode = validatestring(value, ["Color", "Grayscale"]);
        markerFaceMode = string(markerFaceMode);
        applyMarkerStyle();
        drawnow limitrate nocallbacks
    end

    function applyMarkerStyle()
        for condition = 1:4
            faceColor = conditionColors(condition, :);
            if markerFaceMode == "Grayscale"
                luminance = faceColor * [0.2126; 0.7152; 0.0722];
                faceColor = repmat(luminance, 1, 3);
            end
            for monkey = 1:2
                set(scatterHandles(condition, monkey), ...
                    'CData', faceColor, 'MarkerFaceColor', 'flat', ...
                    'SizeData', markerSize, ...
                    'MarkerEdgeAlpha', markerEdgeAlpha, ...
                    'LineWidth', markerEdgeWidth);
            end
        end
        set([jimLegend, clayLegend], ...
            'SizeData', markerSize, ...
            'MarkerEdgeAlpha', markerEdgeAlpha, ...
            'LineWidth', markerEdgeWidth);
    end

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
                valid = pointValid(:, displayCondition, index) & ...
                    strcmpi(string(cache.Monkey), monkeyNames(displayMonkey));
                x = double(cache.PointAI(valid, displayCondition, index));
                y = double(cache.PointBias(valid, displayCondition, index));
                alpha = od(valid);
                if isCorrelationOD
                    alpha = 1 - exp(-alpha);
                end
                alpha = min(max(alpha, 0), 1);
                alpha = options.MarkerFaceAlphaFloor + ...
                    (options.MarkerFaceAlphaCeiling - ...
                    options.MarkerFaceAlphaFloor) .* alpha;
                set(scatterHandles(displayCondition, displayMonkey), ...
                    'XData', x, 'YData', y, 'AlphaData', alpha);
            end
            slope = statistics.WeightedSlope(displayCondition, index);
            intercept = statistics.WeightedIntercept(displayCondition, index);
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

        n2D = statistics.N2DSessions(index);
        n3D = statistics.N3DSessions(index);
        if options.UnitType == "2D"
            selectedCount = n2D;
        else
            selectedCount = n3D;
        end
        title(populationAxes, sprintf([ ...
            '%s %s Gaussian-meta population | %s | sigma %.5g | ' ...
            'meta-classified %s N=%d'], areaName, options.UnitType, ...
            odLabel, sigma, options.UnitType, selectedCount), ...
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
            "OD definition = " + odDefinition; ...
            string(sprintf('median effective channels = %.2f', effective)); ...
            string(sprintf('meta 2D / 3D = %d / %d', ...
            statistics.N2DSessions(index), ...
            statistics.N3DSessions(index)))];
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
                    statistics.P_AIxODWithinCondition( ...
                    statCondition, index);
            else
                displayedPValue = statistics.P_AI(statCondition, index);
            end
            lines(end + 1, 1) = sprintf('%-13s %3d  %+7.3f  %6.3f  %.3g', ...
                conditionNames(statCondition), ...
                statistics.NPoints(statCondition, index), ...
                statistics.WeightedSlope(statCondition, index), ...
                metricPerCue(statCondition, index), ...
                displayedPValue); %#ok<AGROW>
        end
        if options.UnitType == "2D"
            lines = [lines; ""; ...
                sprintf('Merged eyes: N=%d units=%d', ...
                statistics.MergedNPoints(index), ...
                statistics.MergedNUnits(index)); ...
                sprintf('AI + AI:OD R2 = %.3f', ...
                statistics.MergedR2(index)); ...
                sprintf('p(AI) = %.3g | p(AI:OD) = %.3g', ...
                statistics.MergedP_AI(index), ...
                statistics.MergedP_AIxOD(index))];
        else
            lines = [lines; ""; ...
                "Merged-eye summary is not reported for meta 3D sessions."];
        end
    end
end


function [group, label] = makeAppearanceGroup(parent, column, labelText)
group = uigridlayout(parent, [2 1]);
group.Layout.Row = 1;
group.Layout.Column = column;
group.RowHeight = {22, '1x'};
group.Padding = [5 0 5 0];
group.RowSpacing = 2;
label = uilabel(group, 'Text', labelText, ...
    'FontWeight', 'bold', 'HorizontalAlignment', 'center');
label.Layout.Row = 1;
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

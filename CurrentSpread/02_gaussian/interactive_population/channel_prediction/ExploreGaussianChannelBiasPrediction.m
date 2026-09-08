function app = ExploreGaussianChannelBiasPrediction(options)
%EXPLOREGAUSSIANCHANNELBIASPREDICTION Browse condition-aligned predictions.
% Matches the legacy population layout: population upper left, Gaussian
% profile/error/statistics on the right, and sigma/appearance controls below.

arguments
    options.ObjectiveFile (1, 1) string
    options.InitialSigma (1, 1) double = NaN
    options.MarkerSize (1, 1) double = 42
    options.MarkerEdgeWidth (1, 1) double = 1.25
    options.MarkerEdgeAlpha (1, 1) double = 0.85
    options.MarkerFaceAlphaFloor (1, 1) double ...
        {mustBeGreaterThanOrEqual(options.MarkerFaceAlphaFloor, 0), ...
        mustBeLessThanOrEqual(options.MarkerFaceAlphaFloor, 1)} = 0
    options.MarkerFaceMode (1, 1) string ...
        {mustBeMember(options.MarkerFaceMode, ["Color", "Grayscale"])} = ...
        "Color"
    options.ReserveSelectionRow (1, 1) logical = true
    options.Visible (1, 1) string ...
        {mustBeMember(options.Visible, ["on", "off"])} = "on"
    options.Position (1, 4) double = [60 60 1540 930]
end

if ~isfile(options.ObjectiveFile)
    error('GaussianChannelPrediction:MissingObjective', ...
        'Channel-first objective not found: %s', options.ObjectiveFile);
end
loaded = load(options.ObjectiveFile, 'gaussian_channel_bias_prediction');
if ~isfield(loaded, 'gaussian_channel_bias_prediction')
    error('GaussianChannelPrediction:InvalidObjective', ...
        'Objective file does not contain channel-first results.');
end
result = loaded.gaussian_channel_bias_prediction;
hasSourceCohort = isfield(result, 'CohortDefinition') && ...
    string(result.CohortDefinition) == "SourceStimBothEyes_ChannelBothEyes_v1";
if hasSourceCohort
    gateLabel = "Neuron gate: source MonoL AND MonoR p_AI < " + result.TuningAlpha;
else
    gateLabel = "Legacy cohort: rebuild for source both-eye gate";
end
isOrdinary = isfield(result, 'FitMethod') && ...
    string(result.FitMethod) == "OrdinaryR2" && ...
    isfield(result, 'PredictorMode') && ...
    ismember(string(result.PredictorMode), ["CombinedAI", "DominantAIxOD"]);
isCueCV = isfield(result, 'CueFrame') && ...
    string(result.CueFrame) == "ChannelLocalDomNonDom";
if ~isfield(result, 'SchemaVersion') || result.SchemaVersion < 2 || ...
        (~isOrdinary && ~isCueCV)
    error('GaussianChannelPrediction:ObjectiveRequiresRebuild', ...
        ['This objective uses the old physical-eye calculation. Rebuild ' ...
        'with BuildGaussianChannelBiasPredictionObjective, or reopen ' ...
        'ExploreGaussianMetaPopulationApp to rebuild automatically.']);
end
if isOrdinary
    if string(result.PredictorMode) == "DominantAIxOD"
        predictorLabel = "Dominant AI x |OD|";
        metricPredictorLabel = "Dom AI x |OD|";
        predictorFormula = "AI_dominant*|local OD|";
    else
        predictorLabel = "Combined AI";
        metricPredictorLabel = predictorLabel;
        predictorFormula = "AI_combined";
    end
    predictionValues = result.FullPrediction;
    perCueMetric = result.PerCueFullR2;
    objectiveValues = result.SumFourCueOrdinaryR2;
    objectiveLabel = 'Sum ordinary R^2';
    predictionLabel = 'Fitted predicted \DeltaBias (ordinary fit)';
else
    predictionValues = result.HeldOutPrediction;
    perCueMetric = result.PerCueMeanCVMSE;
    objectiveValues = result.MeanCVMSE;
    objectiveLabel = 'Mean CV MSE';
    predictionLabel = 'Held-out predicted \DeltaBias';
end

conditionNames = ["Dominant", "Combined", "Stereo", "NonDominant"];
conditionColors = [254 191 15; 0 0 0; 234 0 233; 110 205 221] ./ 255;
if ~isequal(string(result.ConditionNames(:)'), conditionNames)
    error('GaussianChannelPrediction:ConditionOrder', ...
        'Expected Dominant, Combined, Stereo, NonDominant condition order.');
end
sigmaValues = double(result.SigmaValues(:));
numSigmas = numel(sigmaValues);
if ~isfinite(options.InitialSigma)
    options.InitialSigma = result.BestSigma;
end
[~, initialIndex] = min(abs(sigmaValues - options.InitialSigma));
monkeyNames = ["Jim", "Clay"];
monkeyMarkers = {'o', 'd'};
pointMonkey = string(result.ObservationMap.Monkey);
pointOD = abs(double(result.ObservationMap.BehaviorReferenceSignedOD));
isCorrelationOD = string(result.ODDefinition) == "Correlation";

figureHandle = uifigure('Color', 'w', 'Visible', char(options.Visible), ...
    'Position', options.Position, ...
    'Name', 'Gaussian channel-first bias prediction');
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
hold(populationAxes, 'on');
identityLine = plot(populationAxes, [-1 1], [-1 1], 'k--', ...
    'LineWidth', 1.2, 'HandleVisibility', 'off');
xline(populationAxes, 0, 'k:', 'HandleVisibility', 'off');
yline(populationAxes, 0, 'k:', 'HandleVisibility', 'off');
xlabel(populationAxes, predictionLabel, 'FontSize', 15);
ylabel(populationAxes, 'Observed \DeltaBias', 'FontSize', 15);
populationAxes.FontSize = 14;
populationAxes.LineWidth = 1;
box(populationAxes, 'on');
grid(populationAxes, 'off');
axis(populationAxes, 'square');

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
grid(weightAxes, 'on'); box(weightAxes, 'on');
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
        perCueMetric(metricCondition, :), '-', ...
        'Color', conditionColors(metricCondition, :), 'LineWidth', 1.5, ...
        'DisplayName', conditionNames(metricCondition));
end
objectiveLine = plot(metricAxes, sigmaValues, objectiveValues, ...
    'k-', 'LineWidth', 2.8, 'DisplayName', objectiveLabel);
optimalCursor = xline(metricAxes, result.BestSigma, 'r:', ...
    'LineWidth', 2, 'HandleVisibility', 'off');
metricCursor = xline(metricAxes, sigmaValues(initialIndex), 'k--', ...
    'LineWidth', 1.5, 'HandleVisibility', 'off');
metricAxes.XScale = 'log';
grid(metricAxes, 'on'); box(metricAxes, 'on');
xlabel(metricAxes, 'Gaussian \sigma');
if isOrdinary
    ylabel(metricAxes, 'Ordinary R^2 / summed objective');
    title(metricAxes, metricPredictorLabel + ": ordinary R^2");
else
    ylabel(metricAxes, 'Held-out MSE');
    title(metricAxes, 'Dom/NonDom prediction error');
end
legend(metricAxes, [metricLines; objectiveLine], ...
    [cellstr(conditionNames(:)); {objectiveLabel}], 'Location', 'best');
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
slider = uislider(controlGrid, 'Limits', [1 max(2, numSigmas)], ...
    'Value', initialIndex);
slider.Layout.Row = sliderRow;
slider.Layout.Column = [1 4];
tickIndices = unique(round(linspace(1, numSigmas, 9)));
slider.MajorTicks = tickIndices;
slider.MajorTickLabels = cellstr(compose('%.3g', sigmaValues(tickIndices)));
if numSigmas == 1
    slider.Enable = 'off';
end

appearanceGrid = uigridlayout(controlGrid, [1 4]);
appearanceGrid.Layout.Row = appearanceRow;
appearanceGrid.Layout.Column = [1 4];
appearanceGrid.ColumnWidth = {'1x', '1x', '1x', 190};
appearanceGrid.Padding = [0 0 0 0];
appearanceGrid.ColumnSpacing = 14;
[dotSizeGroup, dotSizeLabel] = makeAppearanceGroup( ...
    appearanceGrid, 1, '');
dotSizeSlider = uislider(dotSizeGroup, 'Limits', [8 200], ...
    'Value', options.MarkerSize, 'MajorTicks', [8 50 100 150 200]);
dotSizeSlider.Layout.Row = 2;
[edgeAlphaGroup, edgeAlphaLabel] = makeAppearanceGroup( ...
    appearanceGrid, 2, '');
edgeTransparencySlider = uislider(edgeAlphaGroup, 'Limits', [0 1], ...
    'Value', 1 - options.MarkerEdgeAlpha, ...
    'MajorTicks', [0 0.25 0.5 0.75 1], ...
    'Tooltip', '0 is opaque; 1 is transparent');
edgeTransparencySlider.Layout.Row = 2;
[edgeWidthGroup, edgeWidthLabel] = makeAppearanceGroup( ...
    appearanceGrid, 3, '');
edgeWidthSlider = uislider(edgeWidthGroup, 'Limits', [0.25 5], ...
    'Value', options.MarkerEdgeWidth, 'MajorTicks', [0.25 1 2 3 4 5]);
edgeWidthSlider.Layout.Row = 2;
[faceModeGroup, ~] = makeAppearanceGroup( ...
    appearanceGrid, 4, 'Dot face fill');
faceModeDropDown = uidropdown(faceModeGroup, ...
    'Items', {'Condition color', 'Grayscale'}, ...
    'ItemsData', {'Color', 'Grayscale'}, ...
    'Value', char(options.MarkerFaceMode));
faceModeDropDown.Layout.Row = 2;

markerSize = options.MarkerSize;
markerEdgeAlpha = options.MarkerEdgeAlpha;
markerEdgeWidth = options.MarkerEdgeWidth;
markerFaceMode = options.MarkerFaceMode;
scatterHandles = gobjects(4, 2);
conditionLegend = gobjects(4, 1);
for initialCondition = 1:4
    for initialMonkey = 1:2
        scatterHandles(initialCondition, initialMonkey) = scatter( ...
            populationAxes, nan, nan, markerSize, ...
            conditionColors(initialCondition, :), ...
            monkeyMarkers{initialMonkey}, 'filled', ...
            'MarkerEdgeColor', conditionColors(initialCondition, :), ...
            'MarkerFaceAlpha', 'flat', 'AlphaData', 0, ...
            'HandleVisibility', 'off');
    end
    conditionLegend(initialCondition) = plot(populationAxes, nan, nan, ...
        '-', 'Color', conditionColors(initialCondition, :), ...
        'LineWidth', 2.5, 'DisplayName', conditionNames(initialCondition));
end
jimLegend = scatter(populationAxes, nan, nan, markerSize, 'k', 'o', 'filled');
clayLegend = scatter(populationAxes, nan, nan, markerSize, 'k', 'd', 'filled');
legend(populationAxes, [conditionLegend; jimLegend; clayLegend], ...
    [cellstr(conditionNames(:)); {'Jim'; 'Clay'}], 'Location', 'eastoutside');

dotSizeSlider.ValueChangingFcn = @(~, event) setDotSize(event.Value);
dotSizeSlider.ValueChangedFcn = @(~, event) setDotSize(event.Value);
edgeTransparencySlider.ValueChangingFcn = @(~, event) ...
    setEdgeTransparency(event.Value);
edgeTransparencySlider.ValueChangedFcn = @(~, event) ...
    setEdgeTransparency(event.Value);
edgeWidthSlider.ValueChangingFcn = @(~, event) setEdgeWidth(event.Value);
edgeWidthSlider.ValueChangedFcn = @(~, event) setEdgeWidth(event.Value);
faceModeDropDown.ValueChangedFcn = @(source, ~) ...
    setFaceMode(string(source.Value));
slider.ValueChangingFcn = @(~, event) updateDisplay(round(event.Value));
slider.ValueChangedFcn = @(~, event) updateDisplay(round(event.Value));
applyMarkerStyle();
updateDisplay(initialIndex);

app = struct();
app.Figure = figureHandle;
app.PopulationAxes = populationAxes;
app.WeightAxes = weightAxes;
app.MetricAxes = metricAxes;
app.ControlGrid = controlGrid;
app.Slider = slider;
app.StatisticsArea = statisticsArea;
app.ScatterHandles = scatterHandles;
app.DotSizeSlider = dotSizeSlider;
app.EdgeTransparencySlider = edgeTransparencySlider;
app.EdgeWidthSlider = edgeWidthSlider;
app.FaceModeDropDown = faceModeDropDown;
app.AllCueOptimalCursor = optimalCursor;
app.Result = result;
app.GetDisplaySettings = @getDisplaySettings;
app.SetSigma = @setSigma;

    function settings = getDisplaySettings()
        settings = struct('MarkerSize', markerSize, ...
            'MarkerEdgeAlpha', markerEdgeAlpha, ...
            'MarkerEdgeWidth', markerEdgeWidth, ...
            'MarkerFaceMode', markerFaceMode);
    end

    function setDotSize(value)
        markerSize = max(8, min(200, double(value)));
        applyMarkerStyle();
    end

    function setEdgeTransparency(value)
        markerEdgeAlpha = 1 - max(0, min(1, double(value)));
        applyMarkerStyle();
    end

    function setEdgeWidth(value)
        markerEdgeWidth = max(0.25, min(5, double(value)));
        applyMarkerStyle();
    end

    function setFaceMode(value)
        markerFaceMode = string(value);
        applyMarkerStyle();
    end

    function applyMarkerStyle()
        for styleCondition = 1:4
            faceColor = conditionColors(styleCondition, :);
            if markerFaceMode == "Grayscale"
                faceColor = repmat(faceColor * [0.2126; 0.7152; 0.0722], 1, 3);
            end
            set(scatterHandles(styleCondition, :), ...
                'CData', faceColor, 'MarkerFaceColor', 'flat', ...
                'SizeData', markerSize, 'LineWidth', markerEdgeWidth, ...
                'MarkerEdgeAlpha', markerEdgeAlpha);
        end
        set([jimLegend clayLegend], 'SizeData', markerSize, ...
            'LineWidth', markerEdgeWidth, 'MarkerEdgeAlpha', markerEdgeAlpha);
        dotSizeLabel.Text = sprintf('Dot size: %.0f', markerSize);
        edgeAlphaLabel.Text = sprintf( ...
            'Edge transparency: %.2f', 1 - markerEdgeAlpha);
        edgeWidthLabel.Text = sprintf('Edge width: %.2f', markerEdgeWidth);
        drawnow limitrate nocallbacks
    end

    function setSigma(sigma)
        [~, index] = min(abs(sigmaValues - sigma));
        updateDisplay(index);
    end

    function updateDisplay(index)
        index = max(1, min(numSigmas, round(index)));
        sigma = sigmaValues(index);
        prediction = double(predictionValues(:, index));
        observed = double(result.Observed);
        finiteAll = isfinite(prediction) & isfinite(observed);
        limit = max(abs([prediction(finiteAll); observed(finiteAll)]), ...
            [], 'omitnan');
        if isempty(limit) || ~isfinite(limit) || limit <= 0
            limit = 1;
        end
        limit = 1.08 .* limit;
        for displayCondition = 1:4
            for displayMonkey = 1:2
                use = finiteAll & ...
                    result.ObservationMap.ConditionIndex == displayCondition & ...
                    strcmpi(pointMonkey, monkeyNames(displayMonkey));
                alpha = pointOD(use);
                if isCorrelationOD
                    alpha = 1 - exp(-alpha);
                end
                alpha = min(max(alpha, 0), 1);
                alpha = options.MarkerFaceAlphaFloor + ...
                    (1 - options.MarkerFaceAlphaFloor) .* alpha;
                set(scatterHandles(displayCondition, displayMonkey), ...
                    'XData', prediction(use), 'YData', observed(use), ...
                    'AlphaData', alpha);
            end
        end
        populationAxes.XLim = [-limit limit];
        populationAxes.YLim = [-limit limit];
        identityLine.XData = [-limit limit];
        identityLine.YData = [-limit limit];
        nominalWeights = exp(-(weightPositions .^ 2) ./ (2 .* sigma ^ 2));
        nominalWeights = nominalWeights ./ sum(nominalWeights);
        weightLine.YData = nominalWeights;
        weightAxes.YLim = [0 max(0.08, 1.12 * max(nominalWeights))];
        metricCursor.Value = sigma;
        title(populationAxes, sprintf( ...
            '%s %s channel-first population | %s OD | sigma %.5g', ...
            result.Area, result.UnitType, result.ODDefinition, sigma), ...
            'FontSize', 17);
        if isOrdinary
            subtitle(populationAxes, sprintf( ...
                '%s | sum ordinary R^2 %.4f | best sigma %.5g', ...
                predictorLabel, objectiveValues(index), result.BestSigma));
        else
            subtitle(populationAxes, sprintf( ...
                'Dom/NonDom CV MSE %.4g | minimum sigma %.5g | identity line', ...
                objectiveValues(index), result.BestSigma));
        end
        currentSigmaLabel.Text = sprintf('%.8g', sigma);
        indexLabel.Text = sprintf('grid %d / %d', index, numSigmas);
        if hasSourceCohort
            countLabel.Text = sprintf('%d tuned sites', result.SessionCount);
        else
            countLabel.Text = sprintf('%d legacy sites', result.SessionCount);
        end
        statisticsArea.Value = buildStatisticsText(index);
        slider.Value = index;
        drawnow limitrate nocallbacks
    end

    function lines = buildStatisticsText(index)
        effective = median(double(result.EffectiveChannels(:, index)), 'omitnan');
        lines = [ ...
            string(sprintf('sigma = %.7g', sigmaValues(index))); ...
            "OD definition = " + result.ODDefinition; ...
            gateLabel; ...
            string(sprintf('median effective channels = %.2f', effective)); ...
            string(sprintf('%s = %.5g', objectiveLabel, objectiveValues(index))); ...
            string(sprintf('best sigma = %.7g', result.BestSigma)); ...
            ""];
        if isOrdinary
            lines = [lines; "Ordinary fit; no CV"; ...
                "Condition       N      R2      MSE"];
        else
            lines = [lines; "Condition       N    CV MSE    CV R2"];
        end
        for statCondition = 1:4
            count = nnz(result.ObservationMap.ConditionIndex == statCondition);
            if isOrdinary
                lines(end + 1, 1) = sprintf('%-13s %3d  %7.4f  %7.4f', ...
                    conditionNames(statCondition), count, ...
                    result.PerCueFullR2(statCondition, index), ...
                    result.PerCueFullMSE(statCondition, index)); %#ok<AGROW>
            else
                lines(end + 1, 1) = sprintf('%-13s %3d  %7.4f  %+7.3f', ...
                    conditionNames(statCondition), count, ...
                    result.PerCueMeanCVMSE(statCondition, index), ...
                    result.PerCueMeanCVR2(statCondition, index)); %#ok<AGROW>
            end
        end
        if isOrdinary
            beta = reshape(result.FullBeta(:, index), 2, 4)';
            lines = [lines; ""; "Condition       beta0     beta1"];
            for betaCondition = 1:4
                lines(end + 1, 1) = sprintf('%-13s %+8.4f %+8.4f', ...
                    conditionNames(betaCondition), ...
                    beta(betaCondition, 1), beta(betaCondition, 2)); %#ok<AGROW>
            end
            lines = [lines; ""; ...
                "Each channel: beta0(c) + beta1(c)*" + predictorFormula; ...
                "Same neural predictor feeds every behavioral cue"; ...
                "Independent intercept/slope fit per cue"];
        else
            lines = [lines; ""; "Channels: each channel's own Dom/NonDom"; ...
                "bias = beta0 + betaAI*AI + betaAIxOD*AI*|OD|"];
        end
        lines = [lines; ...
            "Behavior: stimulation-channel Dom/NonDom"; ...
            "Dot opacity: stimulation-channel |OD|"];
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

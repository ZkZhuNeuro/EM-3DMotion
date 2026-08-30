function outputFiles = SaveAdjacentChannelBiasModelComparison( ...
    result, outputFolder, options)
%SAVEADJACENTCHANNELBIASMODELCOMPARISON Export tables and requested figures.

arguments
    result (1, 1) struct
    outputFolder (1, 1) string
    options.FigureVisible (1, 1) logical = false
end

if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

outputFiles = strings(0, 1);
outputFiles(end + 1, 1) = writeTable(result.GroupSummary, outputFolder, ...
    'AdjacentChannel_GroupModelComparison.csv');
outputFiles(end + 1, 1) = writeTable(result.ModelSummary, outputFolder, ...
    'AdjacentChannel_ModelFits.csv');
outputFiles(end + 1, 1) = writeTable(result.CoefficientSummary, outputFolder, ...
    'AdjacentChannel_Coefficients.csv');
outputFiles(end + 1, 1) = writeTable(result.ObservationTable, outputFolder, ...
    'AdjacentChannel_ObservationAudit.csv');

visible = "off";
if options.FigureVisible
    visible = "on";
end
r2Figure = plotR2Comparison(result, visible);
outputFiles = [outputFiles; exportFigureSet(r2Figure, outputFolder, ...
    'AdjacentChannel_BaselineVsAugmented_R2')];
close(r2Figure)

areaUnitPairs = unique(result.GroupSummary(:, {'Area', 'UnitType'}), ...
    'rows', 'stable');
for pairIndex = 1:height(areaUnitPairs)
    area = string(areaUnitPairs.Area(pairIndex));
    unitType = string(areaUnitPairs.UnitType(pairIndex));
    coefficientFigure = plotCoefficientSilhouettes( ...
        result, area, unitType, visible);
    if isempty(coefficientFigure)
        continue
    end
    fileStem = sprintf( ...
        'AdjacentChannel_CoefficientSilhouettes_%s_%s', area, unitType);
    outputFiles = [outputFiles; exportFigureSet( ...
        coefficientFigure, outputFolder, fileStem)]; %#ok<AGROW>
    close(coefficientFigure)
end

resultsFile = fullfile(outputFolder, ...
    'AdjacentChannelBiasModelComparisonResults.mat');
outputFiles(end + 1, 1) = string(resultsFile);
save(resultsFile, 'result', 'outputFiles', '-v7.3')
end


function file = writeTable(input, outputFolder, fileName)
file = string(fullfile(outputFolder, fileName));
writetable(input, file);
end


function fig = plotR2Comparison(result, visible)
successful = result.GroupSummary.Status == "Success";
summary = result.GroupSummary(successful, :);
if isempty(summary)
    error('AdjacentChannelModel:NoSuccessfulGroups', ...
        'No successful group fits are available for the R-squared plot.');
end

conditionNames = ["Dominant", "Combined", "Stereo", "NonDominant"];
conditionColors = [254 191 15; 0 0 0; 234 0 233; 110 205 221] ./ 255;
fig = figure('Color', 'w', 'Visible', visible, ...
    'Position', [60 60 1540 760], ...
    'Name', 'Adjacent channel baseline versus augmented R-squared');
layout = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');

ordinaryAxes = nexttile(layout);
plotR2Panel(ordinaryAxes, summary, ...
    summary.BaselineOrdinaryR2, summary.AdjacentOrdinaryR2, ...
    'Ordinary in-sample R^2', conditionNames, conditionColors);

cvAxes = nexttile(layout);
plotR2Panel(cvAxes, summary, ...
    summary.BaselineMeanCVR2, summary.AdjacentMeanCVR2, ...
    'Repeated held-out R^2', conditionNames, conditionColors);

comparisonTitle = [ ...
    "Does adding adjacent-channel AI improve prediction?"; ...
    "Baseline: STIM only; augmented: " + ...
    strjoin(channelAxisLabels(result.RelativePositions), ', ')];
title(layout, comparisonTitle, ...
    'FontName', 'Arial', 'FontSize', 17, 'FontWeight', 'bold')
end


function plotR2Panel(ax, summary, x, y, titleText, ...
    conditionNames, conditionColors)
hold(ax, 'on')
finite = isfinite(x) & isfinite(y);
if ~any(finite)
    axis(ax, 'off')
    text(ax, 0.5, 0.5, 'No finite R^2 values', ...
        'HorizontalAlignment', 'center')
    return
end

values = [x(finite); y(finite)];
lower = min(values);
upper = max(values);
if contains(titleText, 'Ordinary')
    lower = min(0, lower);
    upper = max(1, upper);
else
    lower = min(0, lower);
    upper = max(0, upper);
end
span = max(upper - lower, 0.2);
limits = [lower - 0.08 * span, upper + 0.08 * span];
plot(ax, limits, limits, '--', 'Color', [0.45 0.45 0.45], ...
    'LineWidth', 1.2, 'HandleVisibility', 'off')

for row = 1:height(summary)
    if ~finite(row)
        continue
    end
    conditionIndex = find(conditionNames == ...
        string(summary.Condition(row)), 1);
    marker = populationMarker( ...
        string(summary.Area(row)), string(summary.UnitType(row)));
    scatter(ax, x(row), y(row), 78, conditionColors(conditionIndex, :), ...
        marker, 'filled', 'MarkerEdgeColor', [0.2 0.2 0.2], ...
        'LineWidth', 0.75, 'HandleVisibility', 'off')
end

presentConditions = conditionNames(ismember( ...
    conditionNames, string(summary.Condition)));
populationNames = ["MT 2D", "MT 3D", "FST 2D", "FST 3D"];
populationAreas = ["MT", "MT", "FST", "FST"];
populationTypes = ["2D", "3D", "2D", "3D"];
summaryPopulations = string(summary.Area) + " " + string(summary.UnitType);
presentPopulations = ismember(populationNames, summaryPopulations);
legendCount = numel(presentConditions) + nnz(presentPopulations);
legendHandles = gobjects(legendCount, 1);
legendLabels = strings(legendCount, 1);
legendIndex = 0;
for condition = presentConditions
    conditionIndex = find(conditionNames == condition, 1);
    legendIndex = legendIndex + 1;
    legendHandles(legendIndex) = scatter(ax, nan, nan, 70, ...
        conditionColors(conditionIndex, :), 'o', 'filled', ...
        'MarkerEdgeColor', [0.2 0.2 0.2]);
    legendLabels(legendIndex) = "Cue: " + condition;
end
for populationIndex = 1:numel(populationNames)
    if ~presentPopulations(populationIndex)
        continue
    end
    legendIndex = legendIndex + 1;
    legendHandles(legendIndex) = scatter(ax, nan, nan, 70, ...
        [0.55 0.55 0.55], populationMarker( ...
        populationAreas(populationIndex), populationTypes(populationIndex)), ...
        'filled', 'MarkerEdgeColor', [0.2 0.2 0.2]);
    legendLabels(legendIndex) = "Population: " + ...
        populationNames(populationIndex);
end
legend(ax, legendHandles, cellstr(legendLabels), ...
    'Location', 'northwest', 'NumColumns', 2, 'Box', 'off', ...
    'FontName', 'Arial', 'FontSize', 8.5)

xlabel(ax, 'Baseline: Bias ~ AI_{STIM}', ...
    'FontName', 'Arial', 'FontSize', 13)
    ylabel(ax, 'Adjacent-channel model R^2', ...
    'FontName', 'Arial', 'FontSize', 13)
title(ax, titleText, 'FontName', 'Arial', 'FontSize', 15, ...
    'FontWeight', 'bold')
subtitle(ax, 'Above the diagonal favors the adjacent-channel model', ...
    'FontName', 'Arial', 'FontSize', 10)
xlim(ax, limits)
ylim(ax, limits)
axis(ax, 'square')
grid(ax, 'on')
box(ax, 'on')
set(ax, 'FontName', 'Arial', 'FontSize', 11, 'LineWidth', 1)
end


function marker = populationMarker(area, unitType)
if area == "MT" && unitType == "2D"
    marker = 'o';
elseif area == "MT" && unitType == "3D"
    marker = '^';
elseif area == "FST" && unitType == "2D"
    marker = 's';
else
    marker = 'd';
end
end


function fig = plotCoefficientSilhouettes(result, area, unitType, visible)
groups = result.Groups;
selected = arrayfun(@(group) group.Area == area && ...
    group.UnitType == unitType && group.Status == "Success", groups);
groups = groups(selected);
if isempty(groups)
    fig = [];
    return
end

conditionOrder = ["Dominant", "Combined", "Stereo", "NonDominant"];
[~, order] = ismember(string({groups.Condition}), conditionOrder);
[~, sortIndex] = sort(order);
groups = groups(sortIndex);
conditionsToPlot = conditionOrder(ismember( ...
    conditionOrder, string({groups.Condition})));

allValues = nan(0, 1);
for groupIndex = 1:numel(groups)
    beta = groups(groupIndex).AugmentedCV.BetaSamples(:, 2:end);
    allValues = [allValues; beta(:); ...
        groups(groupIndex).AugmentedFit.Estimate(2:end)]; %#ok<AGROW>
end
allValues = allValues(isfinite(allValues));
if isempty(allValues)
    fig = [];
    return
end
valueInterval = prctile(allValues, [1 99]);
if diff(valueInterval) <= eps
    valueInterval = valueInterval + [-1 1];
end
padding = 0.12 * diff(valueInterval);
sharedYLim = valueInterval + [-padding padding];

plotCount = numel(conditionsToPlot);
if plotCount == 1
    figurePosition = [80 80 980 780];
    tileRows = 1;
    tileColumns = 1;
elseif plotCount == 2
    figurePosition = [80 80 1500 760];
    tileRows = 1;
    tileColumns = 2;
else
    figurePosition = [80 30 1560 1080];
    tileRows = 2;
    tileColumns = 2;
end

fig = figure('Color', 'w', 'Visible', visible, ...
    'Position', figurePosition, ...
    'Name', sprintf('%s %s adjacent-channel coefficient silhouettes', ...
    area, unitType));
layout = tiledlayout(fig, tileRows, tileColumns, 'TileSpacing', 'loose', ...
    'Padding', 'loose');
colors = lines(numel(result.RelativePositions));

for conditionIndex = 1:numel(conditionsToPlot)
    ax = nexttile(layout);
    matching = find(arrayfun(@(group) ...
        group.Condition == conditionsToPlot(conditionIndex), groups), 1);

    group = groups(matching);
    samples = group.AugmentedCV.BetaSamples(:, 2:end);
    fullEstimate = group.AugmentedFit.Estimate(2:end);
    hold(ax, 'on')
    yline(ax, 0, '--', 'Color', [0.4 0.4 0.4], ...
        'LineWidth', 1.1, 'HandleVisibility', 'off')
    plotViolinSilhouettes(ax, samples, fullEstimate, colors)
    xticks(ax, 1:numel(result.RelativePositions))
    xticklabels(ax, channelAxisLabels(result.RelativePositions))
    if tileRows > 1 && conditionIndex <= tileColumns
        xticklabels(ax, strings(size(result.RelativePositions)))
    end
    xlim(ax, [0.45 numel(result.RelativePositions) + 0.55])
    ylim(ax, sharedYLim)
    ylabel(ax, 'Regression coefficient (\beta)', ...
        'FontName', 'Arial', 'FontSize', 12)
    title(ax, conditionsToPlot(conditionIndex), ...
        'FontName', 'Arial', 'FontSize', 13, 'FontWeight', 'bold')
    subtitle(ax, sprintf( ...
        'n = %d; \\DeltaR^2 = %.3f; mean \\DeltaCV R^2 = %.3f', ...
        group.N, group.AugmentedFit.OrdinaryR2 - ...
        group.BaselineFit.OrdinaryR2, group.MeanDeltaCVR2), ...
        'FontName', 'Arial', 'FontSize', 9)
    grid(ax, 'on')
    box(ax, 'on')
    set(ax, 'FontName', 'Arial', 'FontSize', 11, 'LineWidth', 1)
end

title(layout, sprintf( ...
    '%s %s coefficient silhouettes', area, unitType), ...
    'FontName', 'Arial', 'FontSize', 15, ...
    'FontWeight', 'bold')
xlabel(layout, ['Physical channel position relative to stimulation contact ' ...
    '(violin = CV training folds; diamond = full fit)'], ...
    'FontName', 'Arial', 'FontSize', 12)
end


function plotViolinSilhouettes(ax, samples, fullEstimate, colors)
predictorCount = size(samples, 2);
for predictorIndex = 1:predictorCount
    values = samples(:, predictorIndex);
    values = values(isfinite(values));
    if isempty(values)
        continue
    end

    if numel(unique(values)) >= 3 && std(values) > eps
        [density, support] = ksdensity(values, 'NumPoints', 120);
        density = 0.34 .* density ./ max(density);
        patch(ax, [predictorIndex - density, ...
            fliplr(predictorIndex + density)], ...
            [support, fliplr(support)], colors(predictorIndex, :), ...
            'FaceAlpha', 0.34, 'EdgeColor', colors(predictorIndex, :), ...
            'LineWidth', 0.9, 'HandleVisibility', 'off')
    else
        plot(ax, [predictorIndex - 0.18 predictorIndex + 0.18], ...
            [values(1) values(1)], '-', ...
            'Color', colors(predictorIndex, :), 'LineWidth', 6, ...
            'HandleVisibility', 'off')
    end

    quantiles = prctile(values, [2.5 25 50 75 97.5]);
    plot(ax, [predictorIndex predictorIndex], ...
        quantiles([1 5]), '-', 'Color', [0.2 0.2 0.2], ...
        'LineWidth', 1.1, 'HandleVisibility', 'off')
    plot(ax, [predictorIndex predictorIndex], ...
        quantiles([2 4]), '-', 'Color', [0.1 0.1 0.1], ...
        'LineWidth', 4, 'HandleVisibility', 'off')
    plot(ax, predictorIndex, quantiles(3), 'o', ...
        'MarkerFaceColor', 'w', 'MarkerEdgeColor', [0.1 0.1 0.1], ...
        'MarkerSize', 5, 'LineWidth', 1, 'HandleVisibility', 'off')
    plot(ax, predictorIndex, fullEstimate(predictorIndex), 'd', ...
        'MarkerFaceColor', colors(predictorIndex, :), ...
        'MarkerEdgeColor', [0.05 0.05 0.05], 'MarkerSize', 8, ...
        'LineWidth', 1, 'HandleVisibility', 'off')
end
end


function labels = channelAxisLabels(relativePositions)
labels = strings(size(relativePositions));
for index = 1:numel(relativePositions)
    position = relativePositions(index);
    if position < 0
        labels(index) = "CH" + position;
    elseif position > 0
        labels(index) = "CH+" + position;
    else
        labels(index) = "STIM";
    end
end
end


function files = exportFigureSet(fig, outputFolder, fileStem)
pngFile = fullfile(outputFolder, [char(fileStem), '.png']);
pdfFile = fullfile(outputFolder, [char(fileStem), '.pdf']);
figFile = fullfile(outputFolder, [char(fileStem), '.fig']);
drawnow
pause(0.15)
exportgraphics(fig, pngFile, 'Resolution', 300)
exportgraphics(fig, pdfFile, 'ContentType', 'vector')
savefig(fig, figFile)
files = string({pngFile; pdfFile; figFile});
end

function figureHandles = currentSpreadSaveRelativeChannelBiasPrediction( ...
    result, outputDir)
%CURRENTSPREADSAVERELATIVECHANNELBIASPREDICTION Save population-style scatters.

arguments
    result (1, 1) struct
    outputDir (1, :) char
end

if ~isfolder(outputDir)
    mkdir(outputDir);
end

positions = result.relativePositions;
numPositions = numel(positions);
colors = positionColors(numPositions);
figureHandles = gobjects(numPositions + 2, 1);
yLimit = symmetricLimit(result.behavior, 0.9);

for positionIndex = 1:numPositions
    valid = result.validByPosition(:, positionIndex);
    x = result.channelAI(valid, positionIndex);
    y = result.behavior(valid);
    stats = result.fullFitStatistics(positionIndex);
    cv = result.fullCrossValidation{positionIndex};

    figureHandle = figure('Color', 'w', 'Visible', 'off', ...
        'Name', ['population_scatter_' positionTag(positions(positionIndex))]);
    axesHandle = axes('Parent', figureHandle);
    drawPopulationScatter(axesHandle, x, y, stats, cv, ...
        positions(positionIndex), colors(positionIndex, :), yLimit);
    title(axesHandle, sprintf('Jim MT 2D: %s', ...
        positionLabel(positions(positionIndex))), 'Interpreter', 'none')
    subtitle(axesHandle, ...
        'Behav_bias_NminusS ~ combined-cue channel AI', ...
        'Interpreter', 'none')

    baseName = ['population_scatter_' positionTag(positions(positionIndex))];
    savefig(figureHandle, fullfile(outputDir, [baseName '.fig']));
    exportgraphics(figureHandle, fullfile(outputDir, [baseName '.png']), ...
        'Resolution', 300);
    figureHandles(positionIndex) = figureHandle;
end

comparisonFigure = figure('Color', 'w', 'Visible', 'off', ...
    'Name', 'population_scatter_matched_comparison');
layout = tiledlayout(comparisonFigure, 1, numPositions, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
matchedY = result.behavior(result.matchedSelection);
for positionIndex = 1:numPositions
    axesHandle = nexttile(layout);
    matchedX = result.channelAI(result.matchedSelection, positionIndex);
    drawPopulationScatter(axesHandle, matchedX, matchedY, ...
        result.matchedFitStatistics(positionIndex), ...
        result.matchedCrossValidation{positionIndex}, ...
        positions(positionIndex), colors(positionIndex, :), yLimit);
    title(axesHandle, positionLabel(positions(positionIndex)), ...
        'Interpreter', 'none')
    if positionIndex > 1
        ylabel(axesHandle, '')
    end
end
title(layout, sprintf(['Matched-session population comparison (N = %d): ' ...
    'Behav_bias_NminusS ~ channel AI'], result.matchedSessionCount), ...
    'Interpreter', 'none')
comparisonBaseName = 'population_scatter_matched_comparison';
savefig(comparisonFigure, fullfile(outputDir, [comparisonBaseName '.fig']));
exportgraphics(comparisonFigure, ...
    fullfile(outputDir, [comparisonBaseName '.png']), 'Resolution', 300);
figureHandles(numPositions + 1) = comparisonFigure;

predictionFigure = figure('Color', 'w', 'Visible', 'off', ...
    'Name', 'heldout_prediction_matched_comparison');
layout = tiledlayout(predictionFigure, 1, numPositions, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
predictionValues = NaN(result.matchedSessionCount * numPositions, 1);
for positionIndex = 1:numPositions
    rows = (positionIndex - 1) * result.matchedSessionCount + ...
        (1:result.matchedSessionCount);
    predictionValues(rows) = ...
        result.matchedCrossValidation{positionIndex}.meanHeldOutPrediction;
end
predictionLimit = symmetricLimit([matchedY; predictionValues], 0.5);
for positionIndex = 1:numPositions
    axesHandle = nexttile(layout);
    prediction = result.matchedCrossValidation{positionIndex}.meanHeldOutPrediction;
    hold(axesHandle, 'on')
    plot(axesHandle, [-predictionLimit predictionLimit], ...
        [-predictionLimit predictionLimit], 'k--', 'LineWidth', 1)
    xline(axesHandle, 0, 'k:', 'HandleVisibility', 'off')
    yline(axesHandle, 0, 'k:', 'HandleVisibility', 'off')
    scatter(axesHandle, prediction, matchedY, 52, ...
        colors(positionIndex, :), 'o', 'filled', ...
        'MarkerEdgeColor', 'w', 'LineWidth', 0.75)
    axis(axesHandle, 'square')
    xlim(axesHandle, [-predictionLimit predictionLimit])
    ylim(axesHandle, [-predictionLimit predictionLimit])
    grid(axesHandle, 'on')
    box(axesHandle, 'on')
    xlabel(axesHandle, 'Mean held-out predicted DeltaBias')
    if positionIndex == 1
        ylabel(axesHandle, 'Observed DeltaBias')
    end
    title(axesHandle, positionLabel(positions(positionIndex)), ...
        'Interpreter', 'none')
    cv = result.matchedCrossValidation{positionIndex};
    text(axesHandle, -0.92 * predictionLimit, 0.90 * predictionLimit, ...
        sprintf('Mean CV R^2 = %.3f', cv.meanR2), ...
        'VerticalAlignment', 'top', 'FontSize', 10, ...
        'BackgroundColor', 'w', 'Margin', 3)
end
title(layout, sprintf(['Held-out bias predictions on the same %d sessions; ' ...
    '%d x %d-fold CV'], result.matchedSessionCount, ...
    result.numRepeats, result.numFolds))
predictionBaseName = 'heldout_prediction_matched_comparison';
savefig(predictionFigure, fullfile(outputDir, [predictionBaseName '.fig']));
exportgraphics(predictionFigure, ...
    fullfile(outputDir, [predictionBaseName '.png']), 'Resolution', 300);
figureHandles(numPositions + 2) = predictionFigure;

writetable(result.sessionTable, ...
    fullfile(outputDir, 'relative_channel_session_data.csv'));
writetable(result.fullModelTable, ...
    fullfile(outputDir, 'relative_channel_model_summary_all_available.csv'));
writetable(result.matchedModelTable, ...
    fullfile(outputDir, 'relative_channel_model_summary_matched.csv'));
save(fullfile(outputDir, 'relative_channel_bias_prediction.mat'), 'result');
end


function drawPopulationScatter(axesHandle, x, y, statistics, cv, ...
    relativePosition, color, yLimit)
hold(axesHandle, 'on')
xline(axesHandle, 0, 'k--', 'HandleVisibility', 'off')
yline(axesHandle, 0, 'k--', 'HandleVisibility', 'off')
scatter(axesHandle, x, y, 52, color, 'o', 'filled', ...
    'MarkerEdgeColor', 'w', 'LineWidth', 0.75)
xGrid = linspace(-1, 1, 200)';
fitLine = statistics.Intercept + statistics.Slope .* xGrid;
plot(axesHandle, xGrid, fitLine, '-', 'Color', color, 'LineWidth', 2.5)
axis(axesHandle, 'square')
xlim(axesHandle, [-1 1])
ylim(axesHandle, [-yLimit yLimit])
xticks(axesHandle, -1:0.5:1)
xticklabels(axesHandle, {'-1', 'Away', '0', 'Towards', '1'})
grid(axesHandle, 'on')
box(axesHandle, 'on')
xlabel(axesHandle, sprintf('Combined-cue AI (relative %+d)', relativePosition))
ylabel(axesHandle, 'DeltaBias: Behav_bias_NminusS', 'Interpreter', 'none')
text(axesHandle, -0.95, 0.92 * yLimit, sprintf( ...
    'N = %d\nSlope = %.3f\np = %.4g\nOrdinary R^2 = %.3f\nMean CV R^2 = %.3f', ...
    statistics.N, statistics.Slope, statistics.SlopePValue, ...
    statistics.OrdinaryR2, cv.meanR2), ...
    'VerticalAlignment', 'top', 'FontSize', 10, ...
    'BackgroundColor', 'w', 'Margin', 3)
set(axesHandle, 'FontSize', 11, 'LineWidth', 1)
end


function colors = positionColors(numPositions)
baseColors = [0.10 0.10 0.10; 0.85 0.33 0.10; 0.05 0.35 0.70; ...
    0.47 0.67 0.19; 0.49 0.18 0.56];
if numPositions <= size(baseColors, 1)
    colors = baseColors(1:numPositions, :);
else
    colors = lines(numPositions);
end
end


function value = symmetricLimit(values, minimumValue)
maximum = max(abs(values), [], 'all', 'omitnan');
value = max(minimumValue, ceil(maximum .* 10) ./ 10);
if ~(isfinite(value) && value > 0)
    value = minimumValue;
end
end


function label = positionLabel(relativePosition)
if relativePosition == 0
    label = 'Stimulation channel (relative 0)';
else
    label = sprintf('Relative %+d channel', relativePosition);
end
end


function tag = positionTag(relativePosition)
if relativePosition < 0
    tag = sprintf('relative_minus%02d', abs(relativePosition));
elseif relativePosition > 0
    tag = sprintf('relative_plus%02d', relativePosition);
else
    tag = 'stimulation_channel';
end
end

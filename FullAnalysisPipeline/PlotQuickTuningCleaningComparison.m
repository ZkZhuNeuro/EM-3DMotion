function figureFiles = PlotQuickTuningCleaningComparison( ...
    QuickResult, sessionInfo, outputFolder, options)
%PLOTQUICKTUNINGCLEANINGCOMPARISON Plot original and cleaned Quick tunings.

arguments
    QuickResult (1, 1) struct
    sessionInfo (1, 1) struct
    outputFolder (1, 1) string
    options.FigureVisible (1, 1) logical = false
    options.SaveFIG (1, 1) logical = false
    options.Overwrite (1, 1) logical = false
end

if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
visibility = "off";
if options.FigureVisible
    visibility = "on";
end

switch string(QuickResult.Task)
    case "3DQuick"
        speedIndices = NaN;
    case "2DQuick"
        speedIndices = 1:numel( ...
            QuickResult.Axes.SpeedDegreesPerSecond);
    otherwise
        error('QuickTuningCleaningFigures:UnknownTask', ...
            'Unsupported task: %s', string(QuickResult.Task));
end

figureFiles = strings(numel(speedIndices), 1);
for figureIndex = 1:numel(speedIndices)
    speedIndex = speedIndices(figureIndex);
    suffix = "";
    if isfinite(speedIndex)
        suffix = sprintf('_Speed%d', speedIndex);
    end
    baseName = makeBaseName(sessionInfo, QuickResult.Task, suffix);
    pngFile = fullfile(outputFolder, baseName + ".png");
    figFile = fullfile(outputFolder, baseName + ".fig");
    figureFiles(figureIndex) = pngFile;
    if isfile(pngFile) && (~options.SaveFIG || isfile(figFile)) && ...
            ~options.Overwrite
        continue
    end

    figureHandle = figure('Color', 'w', 'Visible', visibility, ...
        'Position', [30 70 3600 1050], ...
        'Name', char(baseName), 'MenuBar', 'none', 'ToolBar', 'none');
    cleanup = onCleanup(@() closeFigure(figureHandle));
    leftPanel = uipanel(figureHandle, 'Units', 'normalized', ...
        'Position', [0.005 0.03 0.492 0.91], 'BorderType', 'none');
    rightPanel = uipanel(figureHandle, 'Units', 'normalized', ...
        'Position', [0.503 0.03 0.492 0.91], 'BorderType', 'none');

    yLimits = calculateSharedLimits(QuickResult, speedIndex);
    plotPanel(leftPanel, QuickResult, false, speedIndex, ...
        yLimits, sessionInfo);
    plotPanel(rightPanel, QuickResult, true, speedIndex, ...
        yLimits, sessionInfo);
    annotation(figureHandle, 'textbox', [0.01 0.945 0.98 0.05], ...
        'String', makeFigureTitle(QuickResult, sessionInfo, speedIndex), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontWeight', 'bold', 'FontSize', 12, ...
        'EdgeColor', 'none', 'Interpreter', 'none');

    exportapp(figureHandle, pngFile);
    if options.SaveFIG
        savefig(figureHandle, figFile);
    end
    clear cleanup
    closeFigure(figureHandle);
end
end


function plotPanel(panel, result, useCleaned, speedIndex, ...
    yLimits, sessionInfo)
if useCleaned
    meanValues = result.CleanedMean;
    semValues = result.CleanedSEM;
    countValues = result.CleanedCount;
    panelTitle = "Cleaned (MAD outliers excluded)";
else
    meanValues = result.OriginalMean;
    semValues = result.OriginalSEM;
    countValues = result.OriginalCount;
    panelTitle = "Original (all selected trials)";
end

channelCount = result.NumChannels;
rowCount = 2;
columnCount = ceil(channelCount / rowCount);
layout = tiledlayout(panel, rowCount, columnCount, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, panelTitle, 'FontWeight', 'bold');

switch string(result.Task)
    case "3DQuick"
        colors = [0 0 0; 0 0 1; 0.02 0.59 0.02; 0.92 0 0.91];
        xValues = result.Axes.Coherence;
        conditionNames = result.Axes.ConditionNames;
    case "2DQuick"
        colors = [0 0 1; 0.02 0.59 0.02; 0 0 0];
        xValues = [result.Axes.DirectionDegrees 360];
        conditionNames = result.Axes.ConditionNames;
end

legendHandles = gobjects(numel(conditionNames), 1);
for probePosition = 1:channelCount
    acquisitionChannel = result.ChannelMap(probePosition);
    axesHandle = nexttile(layout, probePosition);
    hold(axesHandle, 'on');
    for condition = 1:numel(conditionNames)
        if result.Task == "3DQuick"
            y = reshape(meanValues(condition, :, acquisitionChannel), 1, []);
            sem = reshape(semValues(condition, :, acquisitionChannel), 1, []);
            present = reshape( ...
                countValues(condition, :, acquisitionChannel), 1, []) > 0 & ...
                isfinite(y);
        else
            y = reshape(meanValues(:, speedIndex, condition, ...
                acquisitionChannel), 1, []);
            sem = reshape(semValues(:, speedIndex, condition, ...
                acquisitionChannel), 1, []);
            present = reshape(countValues(:, speedIndex, condition, ...
                acquisitionChannel), 1, []) > 0 & isfinite(y);
            closedIndex = [1:numel(y) 1];
            y = y(closedIndex);
            sem = sem(closedIndex);
            present = present(closedIndex);
        end
        y(~present) = NaN;
        legendHandles(condition) = plot(axesHandle, xValues, y, '-o', ...
            'Color', colors(condition, :), ...
            'MarkerFaceColor', colors(condition, :), ...
            'MarkerSize', 3, 'LineWidth', 1.1);
        errorMask = present & isfinite(sem);
        if any(errorMask)
            errorbar(axesHandle, xValues(errorMask), y(errorMask), ...
                sem(errorMask), 'LineStyle', 'none', ...
                'Color', colors(condition, :), 'CapSize', 2, ...
                'HandleVisibility', 'off');
        end
    end

    ylim(axesHandle, yLimits(acquisitionChannel, :));
    grid(axesHandle, 'on');
    axesHandle.GridAlpha = 0.12;
    axesHandle.FontSize = 7;
    box(axesHandle, 'on');
    if result.Task == "3DQuick"
        xlim(axesHandle, [min(xValues) max(xValues)]);
        xticks(axesHandle, [-1 -0.5 0 0.5 1]);
        if probePosition > columnCount
            xlabel(axesHandle, 'Signed coherence');
        end
    else
        xlim(axesHandle, [0 360]);
        xticks(axesHandle, 0:90:360);
        if probePosition > columnCount
            xlabel(axesHandle, 'Direction (deg)');
        end
    end
    if probePosition == 1 || probePosition == columnCount + 1
        ylabel(axesHandle, 'Mean firing rate (Hz)');
    end

    isStimChannel = isfield(sessionInfo, 'StimChannel') && ...
        isfinite(sessionInfo.StimChannel) && ...
        acquisitionChannel == sessionInfo.StimChannel;
    if isStimChannel
        title(axesHandle, sprintf('Pos %d | Ch %d | STIM', ...
            probePosition, acquisitionChannel), ...
            'Color', [0.85 0.33 0.10], 'FontWeight', 'bold', ...
            'FontSize', 8);
        axesHandle.XColor = [0.85 0.33 0.10];
        axesHandle.YColor = [0.85 0.33 0.10];
    else
        title(axesHandle, sprintf('Pos %d | Ch %d', ...
            probePosition, acquisitionChannel), 'FontSize', 8);
    end
end

legendHandle = legend(legendHandles, cellstr(conditionNames), ...
    'Orientation', 'horizontal', 'FontSize', 8);
legendHandle.Layout.Tile = 'south';
end


function yLimits = calculateSharedLimits(result, speedIndex)
if result.Task == "3DQuick"
    originalMean = result.OriginalMean;
    originalSEM = result.OriginalSEM;
    cleanedMean = result.CleanedMean;
    cleanedSEM = result.CleanedSEM;
else
    originalMean = result.OriginalMean(:, speedIndex, :, :);
    originalSEM = result.OriginalSEM(:, speedIndex, :, :);
    cleanedMean = result.CleanedMean(:, speedIndex, :, :);
    cleanedSEM = result.CleanedSEM(:, speedIndex, :, :);
end
channelDimension = ndims(originalMean);
yLimits = nan(result.NumChannels, 2);
for channel = 1:result.NumChannels
    indices = repmat({':'}, 1, channelDimension);
    indices{channelDimension} = channel;
    originalChannelMean = originalMean(indices{:});
    originalChannelSEM = originalSEM(indices{:});
    cleanedChannelMean = cleanedMean(indices{:});
    cleanedChannelSEM = cleanedSEM(indices{:});
    values = [originalChannelMean(:) - originalChannelSEM(:); ...
        originalChannelMean(:) + originalChannelSEM(:); ...
        cleanedChannelMean(:) - cleanedChannelSEM(:); ...
        cleanedChannelMean(:) + cleanedChannelSEM(:)];
    values = values(isfinite(values));
    if isempty(values)
        yLimits(channel, :) = [0 1];
        continue
    end
    lower = min(values);
    upper = max(values);
    span = upper - lower;
    if ~isfinite(span) || span <= 0
        span = max(1, abs(upper));
    end
    yLimits(channel, :) = ...
        [lower - 0.05 * span, upper + 0.05 * span];
end
end


function titleText = makeFigureTitle(result, sessionInfo, speedIndex)
audit = result.OutlierAudit;
speedText = "";
if isfinite(speedIndex)
    speedText = sprintf(' | speed %.3g deg/s', ...
        result.Axes.SpeedDegreesPerSecond(speedIndex));
end
titleText = sprintf([ ...
    'Row %03d | %s | %s | %s%s | %d/%d trial observations affected | ' ...
    '%d channel/unit observations excluded | modified-Z > %.2f, min n = %d'], ...
    sessionInfo.Row, char(sessionInfo.Monkey), char(sessionInfo.DateLabel), ...
    char(result.Task), char(speedText), ...
    audit.TrialWithAnyOutlierCount, sum(result.CellTrialCounts, 'all'), ...
    audit.OutlierObservationCount, audit.Settings.Threshold, ...
    audit.Settings.MinimumTrials);
end


function baseName = makeBaseName(sessionInfo, taskName, suffix)
safeMonkey = regexprep(char(sessionInfo.Monkey), ...
    '[^A-Za-z0-9_-]', '_');
safeDate = regexprep(char(sessionInfo.DateFileText), ...
    '[^A-Za-z0-9_-]', '_');
baseName = string(sprintf('Row%03d_%s_%s_%s_OriginalVsCleaned%s', ...
    sessionInfo.Row, safeMonkey, safeDate, char(taskName), char(suffix)));
end


function closeFigure(figureHandle)
if ~isempty(figureHandle) && all(isgraphics(figureHandle))
    close(figureHandle);
end
end

clear;
clc;

inputMat = fullfile(pwd, 'LoRF_unit_table.mat');
plotDir = 'C:\LoData\RF\EllipseFitPreview_FromFunction';
logFile = fullfile(plotDir, 'FitLoRF_EllipseFromUnitTableUsingFunction.log');

ellipseConfidence90 = 0.90;
ellipseConfidence68 = 0.68;
minClusterSize = 3;
aspectRatioPenaltyStart = 2.5;
aspectRatioPenaltyWeight = 100;

windowWidth = 1920; %(pixels)
windowHeight = 1080; %(pixels)
viewingDistance = 570; %(mm)
ScreenWidth = 635; %(mm)
mm2deg = @(x) atand(x ./ viewingDistance);
pix2deg = @(x) mm2deg(x ./ windowWidth * ScreenWidth);
WindowCenter = [windowWidth, windowHeight] / 2;

makePreviewPlots = true;
unitIndices = [];

if ~exist(plotDir, 'dir')
    mkdir(plotDir);
end
if exist(logFile, 'file')
    delete(logFile);
end

logMessage(logFile, 'Loading table from %s', inputMat);
S = load(inputMat);
RF_table = getTableFromMatStruct(S);
hasFRbyTrial = ismember('FRbyTrial', RF_table.Properties.VariableNames);
hasBaseline = ismember('Baseline', RF_table.Properties.VariableNames);
if ~hasBaseline
    error('RF_table must contain a Baseline column for TempTable-style thresholding.');
end
if ~hasFRbyTrial
    error('RF_table must contain an FRbyTrial column for TempTable-style thresholding.');
end

if isempty(unitIndices)
    unitIndices = 1:height(RF_table);
end

for idx = unitIndices
    logMessage(logFile, 'Fitting unit %d/%d with FitLoRF_EllipseFromRFMap', idx, height(RF_table));

    try
        rawRFmap = tableCell(RF_table.rawRFmap, idx);
        uniXPos = tableCell(RF_table.uniXPos, idx);
        uniYPos = tableCell(RF_table.uniYPos, idx);
        baselineFR = tableCell(RF_table.Baseline, idx);
        FRbyTrial = tableCell(RF_table.FRbyTrial, idx);
        fitArgs = { ...
            'FRbyTrial', FRbyTrial, ...
            'minClusterSize', minClusterSize, ...
            'aspectRatioPenaltyStart', aspectRatioPenaltyStart, ...
            'aspectRatioPenaltyWeight', aspectRatioPenaltyWeight};

        fit90 = FitLoRF_EllipseFromRFMap( ...
            rawRFmap, uniXPos, uniYPos, baselineFR, ...
            'confidence', ellipseConfidence90, ...
            fitArgs{:});

        fit68 = FitLoRF_EllipseFromRFMap( ...
            rawRFmap, uniXPos, uniYPos, baselineFR, ...
            'ThresholdMap', fit90.thresholdMap, ...
            'confidence', ellipseConfidence68, ...
            fitArgs{:});

        if makePreviewPlots
            savePreviewPlotFromFits( ...
                idx, fit90.rawFRmap, uniXPos, uniYPos, fit90, fit68, ...
                plotDir, WindowCenter, pix2deg);
        end

        logMessage(logFile, 'Unit %d status: %s', idx, fit90.status);
    catch ME
        logMessage(logFile, 'Unit %d failed: %s', idx, ME.message);
    end
end

logMessage(logFile, 'Done');

function logMessage(logFile, message, varargin)
fid = fopen(logFile, 'a');
if fid < 0
    return
end
fprintf(fid, [datestr(now, 'yyyy-mm-dd HH:MM:SS'), ' - ', message, '\n'], varargin{:});
fclose(fid);
end

function T = getTableFromMatStruct(S)
names = fieldnames(S);
preferredNames = {'unit_table', 'RF_table'};
for i = 1:numel(preferredNames)
    if isfield(S, preferredNames{i}) && istable(S.(preferredNames{i}))
        T = S.(preferredNames{i});
        return
    end
end
for i = 1:numel(names)
    if istable(S.(names{i}))
        T = S.(names{i});
        return
    end
end
error('No MATLAB table found in the input MAT file.');
end

function x = tableCell(col, idx)
if iscell(col)
    x = col{idx};
else
    x = col(idx, :);
end
end

function savePreviewPlotFromFits(idx, rawRFmap, uniXPos, uniYPos, fit90, fit68, plotDir, WindowCenter, pix2deg)
fig = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters', ...
    'Position', [100 100 1800 520]);

rawRFmap = ensureRFMapMatrix(rawRFmap, uniXPos, uniYPos);
thresholdPassMask = fit90.thresholdMap > 0 & ~isnan(fit90.thresholdMap);
excludedMask = thresholdPassMask & ~fit90.cleanMask;
fitMask = fit90.cleanMask;

xDegAxis = pix2deg(uniXPos(:)' - WindowCenter(1));
yDegAxis = pix2deg(WindowCenter(2) - uniYPos(:)');
[xDegSorted, xOrder] = sort(xDegAxis, 'ascend');
[yDegSorted, yOrder] = sort(yDegAxis, 'ascend');
xLimits = localAxisLimits(xDegSorted);
yLimits = localAxisLimits(yDegSorted);

rawRFmapPlot = rawRFmap(yOrder, xOrder);
thresholdClassMap = zeros(size(rawRFmap), 'double');
thresholdClassMap(excludedMask) = 1;
thresholdClassMap(fitMask) = 2;
thresholdClassMapPlot = thresholdClassMap(yOrder, xOrder);

[ellipse90Xdeg, ellipse90Ydeg] = ellipsePixToDeg(fit90.x, fit90.y, WindowCenter, pix2deg);
[ellipse68Xdeg, ellipse68Ydeg] = ellipsePixToDeg(fit68.x, fit68.y, WindowCenter, pix2deg);

tileObj = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
imagesc(ax1, xDegSorted, yDegSorted, rawRFmapPlot);
set(ax1, 'YDir', 'normal');
axis(ax1, 'equal');
axis(ax1, 'tight');
colormap(ax1, 'parula');
colorbar(ax1);
hold(ax1, 'on');
if fit90.fitOK
    plot(ax1, ellipse90Xdeg, ellipse90Ydeg, 'w-', 'LineWidth', 2);
end
title(ax1, sprintf('Unit %d RF heatmap + 90%% ellipse', idx), 'Interpreter', 'none');
xlabel(ax1, 'x (deg)');
ylabel(ax1, 'y (deg)');
xlim(ax1, xLimits);
ylim(ax1, yLimits);

ax2 = nexttile;
imagesc(ax2, xDegSorted, yDegSorted, rawRFmapPlot);
set(ax2, 'YDir', 'normal');
axis(ax2, 'equal');
axis(ax2, 'tight');
colormap(ax2, 'parula');
colorbar(ax2);
hold(ax2, 'on');
if fit68.fitOK
    plot(ax2, ellipse68Xdeg, ellipse68Ydeg, 'w-', 'LineWidth', 2);
end
title(ax2, 'RF heatmap + 68% ellipse', 'Interpreter', 'none');
xlabel(ax2, 'x (deg)');
ylabel(ax2, 'y (deg)');
xlim(ax2, xLimits);
ylim(ax2, yLimits);

ax3 = nexttile;
imagesc(ax3, xDegSorted, yDegSorted, thresholdClassMapPlot);
set(ax3, 'YDir', 'normal');
axis(ax3, 'equal');
axis(ax3, 'tight');
colormap(ax3, [0.15 0.15 0.15; 0.98 0.85 0.20; 0.95 0.35 0.2]);
colorbar(ax3, 'Ticks', [0 1 2], 'TickLabels', {'Fail', 'Excluded', 'Fitted'});
title(ax3, 'Threshold pass map', 'Interpreter', 'none');
xlabel(ax3, 'x (deg)');
ylabel(ax3, 'y (deg)');
xlim(ax3, xLimits);
ylim(ax3, yLimits);

sgtitle(tileObj, sprintf('Unit %d RF ellipse fit (%s)', idx, fit90.status), ...
    'Interpreter', 'none');
outName = fullfile(plotDir, sprintf('RF_EllipseFit_Unit%04d.png', idx));
print(fig, outName, '-dpng', '-painters', '-r200');
close(fig);
end

function rawRFmap = ensureRFMapMatrix(rawRFmap, uniXPos, uniYPos)
if iscell(rawRFmap)
    rawRFmap = rawRFmap{1};
end
if isvector(rawRFmap) && numel(rawRFmap) == numel(uniXPos) * numel(uniYPos)
    rawRFmap = reshape(rawRFmap, numel(uniYPos), numel(uniXPos));
end
if ~ismatrix(rawRFmap) || size(rawRFmap, 1) ~= numel(uniYPos) || size(rawRFmap, 2) ~= numel(uniXPos)
    error('rawRFmap size must match [numel(uniYPos) x numel(uniXPos)].');
end
end

function [xDeg, yDeg] = ellipsePixToDeg(xPix, yPix, WindowCenter, pix2deg)
if isempty(xPix) || isempty(yPix)
    xDeg = [];
    yDeg = [];
    return
end
xDeg = pix2deg(xPix - WindowCenter(1));
yDeg = pix2deg(WindowCenter(2) - yPix);
end

function limits = localAxisLimits(axisValues)
axisValues = axisValues(:)';
if numel(axisValues) >= 2
    edgePadding = median(diff(axisValues), 'omitnan') / 2;
    if ~isfinite(edgePadding) || edgePadding <= 0
        edgePadding = 0;
    end
else
    edgePadding = 0.5;
end
limits = [min(axisValues) - edgePadding, max(axisValues) + edgePadding];
end

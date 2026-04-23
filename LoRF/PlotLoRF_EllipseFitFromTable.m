clear; clc;

%% Plot every RF from the fitted LoRF temp table.
% This script only reads the saved table and makes figures. It does not fit
% ellipses and does not rerun RF extraction.

inputMat = 'C:\LoData\RF\unit_table_temp_with_ellipse.mat';
plotDir = 'C:\LoData\RF\EllipseFitPreview';
logFile = fullfile(plotDir, 'PlotLoRF_EllipseFitFromTable.log');

unitIndices = [];        % Example: [1 3 10]. Leave [] to plot all rows.

windowWidth = 1920; %(pixels)
windowHeight = 1080; %(pixels)
viewingDistance = 570; %(mm)
ScreenWidth = 635; %(mm)
mm2deg = @(x) atand(x./viewingDistance);
pix2mm = @(x) x.*ScreenWidth./windowWidth;
pix2deg = @(x) mm2deg(pix2mm(x));
WindowCenter = [windowWidth/2, windowHeight/2];

if ~exist(plotDir, 'dir')
    mkdir(plotDir);
end
if exist(logFile, 'file')
    delete(logFile);
end
logMessage(logFile, 'Loading %s', inputMat);

S = load(inputMat);
RF_table = getTableFromMatStruct(S);

if isempty(unitIndices)
    unitIndices = 1:height(RF_table);
end

for idx = unitIndices
    logMessage(logFile, 'Plotting unit %d/%d', idx, height(RF_table));
    try
        rawRFmap = tableCell(RF_table.rawRFmap, idx);
        uniXPos = tableCell(RF_table.uniXPos, idx);
        uniYPos = tableCell(RF_table.uniYPos, idx);
        meanXYpos = tableCell(RF_table.meanXYpos, idx);

        rawRFmap = ensureRFMapMatrix(rawRFmap, uniXPos, uniYPos);
        rawRF = flipud(rawRFmap);

        fig = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'opengl');
        imagesc(rawRF);
        colormap('parula');
        colorbar;
        axis xy equal tight;
        hold on;

        xTickPix = round(linspace(1, size(rawRF, 2), 10));
        yTickPix = round(linspace(1, size(rawRF, 1), 10));
        xTickLabels = makeDegreeTickLabels(pix2deg( ...
            linspace(min(uniXPos), max(uniXPos), 10) - WindowCenter(1)));
        yTickLabels = fliplr(makeDegreeTickLabels(pix2deg( ...
            WindowCenter(2) - linspace(min(uniYPos), max(uniYPos), 10))));

        set(gca, 'XTick', xTickPix, 'YTick', yTickPix);
        set(gca, 'XTickLabel', xTickLabels, 'YTickLabel', yTickLabels);
        xlabel('x (deg)');
        ylabel('y (deg)');

        if hasGoodEllipse(RF_table, idx)
            [xPlot, yPlot] = ellipsePixToPlotCoords(RF_table, idx, meanXYpos, rawRFmap);
            plot(xPlot, yPlot, 'Color', [0 0 0], 'LineWidth', 2);

            centerPix = tableCell(RF_table.EllipseCenter_pix, idx);
            [xCenterPlot, yCenterPlot] = pointPixToPlotCoords(centerPix(1), centerPix(2), meanXYpos, rawRFmap);
            plot(xCenterPlot, yCenterPlot, 'ko', 'MarkerFaceColor', 'w', 'MarkerSize', 4);
        end

        plotFixationLines(meanXYpos, rawRFmap, WindowCenter);

        title(makeTitle(RF_table, idx), 'Interpreter', 'none');

        outName = fullfile(plotDir, sprintf('LoRF_RF_Unit%04d.png', idx));
        drawnow;
        print(fig, outName, '-dpng', '-r200');
        close(fig);
        close all hidden;
        logMessage(logFile, 'Saved %s', outName);
    catch ME
        logMessage(logFile, 'Unit %d failed: %s', idx, ME.message);
        if exist('fig', 'var') && isgraphics(fig)
            close(fig);
        end
        close all hidden;
    end
end

logMessage(logFile, 'Finished plotting %d units.', numel(unitIndices));

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

function rawRFmap = ensureRFMapMatrix(rawRFmap, uniXPos, uniYPos)
if iscell(rawRFmap)
    rawRFmap = rawRFmap{1};
end
if isvector(rawRFmap) && numel(rawRFmap) == numel(uniXPos) * numel(uniYPos)
    rawRFmap = reshape(rawRFmap, numel(uniYPos), numel(uniXPos));
end
end

function labels = makeDegreeTickLabels(deg)
labels = compose('%.1f', round(deg, 1));
end

function tf = hasGoodEllipse(RF_table, idx)
tf = ismember('EllipseFit', RF_table.Properties.VariableNames) && ...
    logical(RF_table.EllipseFit(idx)) && ...
    ismember('EllipseX_pix', RF_table.Properties.VariableNames) && ...
    ~isempty(tableCell(RF_table.EllipseX_pix, idx)) && ...
    ~isempty(tableCell(RF_table.EllipseY_pix, idx));
end

function [xPlot, yPlot] = ellipsePixToPlotCoords(RF_table, idx, meanXYpos, rawRFmap)
xPix = tableCell(RF_table.EllipseX_pix, idx);
yPix = tableCell(RF_table.EllipseY_pix, idx);
[xPlot, yPlot] = pointPixToPlotCoords(xPix, yPix, meanXYpos, rawRFmap);
end

function [xPlot, yPlot] = pointPixToPlotCoords(xPix, yPix, meanXYpos, rawRFmap)
xGrid = reshape(meanXYpos(:, 1), size(rawRFmap, 1), size(rawRFmap, 2));
yGrid = reshape(meanXYpos(:, 2), size(rawRFmap, 1), size(rawRFmap, 2));

Fx = griddedInterpolant({1:size(rawRFmap, 1), 1:size(rawRFmap, 2)}, xGrid, 'linear', 'nearest');
Fy = griddedInterpolant({1:size(rawRFmap, 1), 1:size(rawRFmap, 2)}, yGrid, 'linear', 'nearest');

[~, xGridIdx] = min(abs(xGrid(1, :) - xPix(:)), [], 2);
[~, yGridIdx] = min(abs(yGrid(:, 1)' - yPix(:)), [], 2);

% Refine the index estimate for regularly spaced RF grids.
xPlot = interp1(xGrid(1, :), 1:size(rawRFmap, 2), xPix, 'linear', 'extrap');
yOriginal = interp1(yGrid(:, 1), 1:size(rawRFmap, 1), yPix, 'linear', 'extrap');
yPlot = size(rawRFmap, 1) + 1 - yOriginal;

badX = ~isfinite(xPlot);
badY = ~isfinite(yPlot);
xPlot(badX) = xGridIdx(badX);
yPlot(badY) = size(rawRFmap, 1) + 1 - yGridIdx(badY);
end

function plotFixationLines(meanXYpos, rawRFmap, WindowCenter)
xGrid = reshape(meanXYpos(:, 1), size(rawRFmap, 1), size(rawRFmap, 2));
yGrid = reshape(meanXYpos(:, 2), size(rawRFmap, 1), size(rawRFmap, 2));

xMid = interp1(xGrid(1, :), 1:size(rawRFmap, 2), WindowCenter(1), 'linear', 'extrap');
yMidOriginal = interp1(yGrid(:, 1), 1:size(rawRFmap, 1), WindowCenter(2), 'linear', 'extrap');
yMid = size(rawRFmap, 1) + 1 - yMidOriginal;

if isfinite(xMid)
    plot([xMid xMid], [0.5 size(rawRFmap, 1) + 0.5], 'Color', [1 1 1], 'LineWidth', 1);
end
if isfinite(yMid)
    plot([0.5 size(rawRFmap, 2) + 0.5], [yMid yMid], 'Color', [1 1 1], 'LineWidth', 1);
end
end

function titleText = makeTitle(RF_table, idx)
parts = {sprintf('Unit %d', idx)};
if ismember('Date', RF_table.Properties.VariableNames)
    parts{end + 1} = char(string(RF_table.Date(idx)));
end
if ismember('ROI', RF_table.Properties.VariableNames)
    parts{end + 1} = char(string(RF_table.ROI(idx)));
end
if ismember('EllipseStatus', RF_table.Properties.VariableNames)
    parts{end + 1} = char(string(RF_table.EllipseStatus{idx}));
end
titleText = strjoin(parts, ' | ');
end

function logMessage(logFile, message, varargin)
fid = fopen(logFile, 'a');
if fid < 0
    return
end
fprintf(fid, [datestr(now, 'yyyy-mm-dd HH:MM:SS'), ' - ', message, '\n'], varargin{:});
fclose(fid);
end

clear; clc;

inputMat = 'C:\EM\RF_data\RF_table_MUAStim_JimClay.mat';
outputMat = 'C:\EM\RF_data\RF_table_MUAStim_JimClay_with_ellipse.mat';
logFile = 'C:\EM\RF_data\FitEllipse_MUAStim_JimClay.log';
plotDir = 'C:\EM\RF_data\SessionRFPlots';

rfAnalysisPath = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\RF_analysis';
loRfPath = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\LoRF';
addpath(rfAnalysisPath);
addpath(loRfPath);

ellipseConfidence68 = 0.68;
ellipseConfidence90 = 0.90;
alpha = 0.05;
minClusterSize = 2;
aspectRatioPenaltyStart = 2.5;
aspectRatioPenaltyWeight = 100;

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
logMessage(logFile, 'Starting MUA ellipse fit from %s', inputMat);

S = load(inputMat);
RF_table = getTableFromMatStruct(S);

RF_table.EllipseFit = cell(height(RF_table), 1);
RF_table.EllipseStatus = cell(height(RF_table), 1);
RF_table.ThresholdMap = cell(height(RF_table), 1);
RF_table.CleanMask = cell(height(RF_table), 1);
RF_table.EllipseCenter_pix = cell(height(RF_table), 1);
RF_table.EllipseX_pix = cell(height(RF_table), 1);
RF_table.EllipseY_pix = cell(height(RF_table), 1);
RF_table.EllipseCenter_deg = cell(height(RF_table), 1);
RF_table.EllipseX_deg = cell(height(RF_table), 1);
RF_table.EllipseY_deg = cell(height(RF_table), 1);
RF_table.EllipseArea_deg2 = cell(height(RF_table), 1);
RF_table.Ellipse68Center_pix = cell(height(RF_table), 1);
RF_table.Ellipse68X_pix = cell(height(RF_table), 1);
RF_table.Ellipse68Y_pix = cell(height(RF_table), 1);
RF_table.Ellipse68Center_deg = cell(height(RF_table), 1);
RF_table.Ellipse68X_deg = cell(height(RF_table), 1);
RF_table.Ellipse68Y_deg = cell(height(RF_table), 1);
RF_table.Ellipse68Area_deg2 = cell(height(RF_table), 1);

for iSession = 1:height(RF_table)
    sessionChannelNums = getSessionChannelNums(RF_table, iSession);
    nChannels = numel(sessionChannelNums);
    logMessage(logFile, 'Fitting ellipses for session %d/%d with %d channel(s)', ...
        iSession, height(RF_table), nChannels);
    fprintf('Processing session %d/%d: %s %s (%d channel%s)\n', ...
        iSession, height(RF_table), ...
        getSessionMonkey(RF_table, iSession), ...
        getSessionDateText(RF_table, iSession), ...
        nChannels, pluralSuffix(nChannels));

    ellipseFitVec = false(nChannels, 1);
    ellipseStatus = repmat({''}, nChannels, 1);
    thresholdMapCell = cell(nChannels, 1);
    cleanMaskCell = cell(nChannels, 1);
    ellipseCenter_pix = cell(nChannels, 1);
    ellipseX_pix = cell(nChannels, 1);
    ellipseY_pix = cell(nChannels, 1);
    ellipseCenter_deg = cell(nChannels, 1);
    ellipseX_deg = cell(nChannels, 1);
    ellipseY_deg = cell(nChannels, 1);
    ellipseArea_deg2 = nan(nChannels, 1);
    ellipse68Center_pix = cell(nChannels, 1);
    ellipse68X_pix = cell(nChannels, 1);
    ellipse68Y_pix = cell(nChannels, 1);
    ellipse68Center_deg = cell(nChannels, 1);
    ellipse68X_deg = cell(nChannels, 1);
    ellipse68Y_deg = cell(nChannels, 1);
    ellipse68Area_deg2 = nan(nChannels, 1);

    sessionRawRF = RF_table.rawRFmap{iSession};
    sessionUniXPos = RF_table.uniXPos{iSession};
    sessionUniYPos = RF_table.uniYPos{iSession};
    sessionFRbyTrial = RF_table.FRbyTrial{iSession};
    sessionBaseline = RF_table.Baseline{iSession};

    for iChannel = 1:nChannels
        channelNum = sessionChannelNums(iChannel);
        try
            rawRFmap = sessionRawRF{iChannel};
            uniXPos = sessionUniXPos{iChannel};
            uniYPos = sessionUniYPos{iChannel};
            FRbyTrial = sessionFRbyTrial{iChannel};
            baselineFR = sessionBaseline{iChannel};

            fit90 = FitLoRF_EllipseFromRFMap( ...
                rawRFmap, uniXPos, uniYPos, baselineFR, ...
                'FRbyTrial', FRbyTrial, ...
                'confidence', ellipseConfidence90, ...
                'alpha', alpha, ...
                'minClusterSize', minClusterSize, ...
                'aspectRatioPenaltyStart', aspectRatioPenaltyStart, ...
                'aspectRatioPenaltyWeight', aspectRatioPenaltyWeight);

            fit68 = FitLoRF_EllipseFromRFMap( ...
                rawRFmap, uniXPos, uniYPos, baselineFR, ...
                'ThresholdMap', fit90.thresholdMap, ...
                'confidence', ellipseConfidence68, ...
                'alpha', alpha, ...
                'minClusterSize', minClusterSize, ...
                'aspectRatioPenaltyStart', aspectRatioPenaltyStart, ...
                'aspectRatioPenaltyWeight', aspectRatioPenaltyWeight);

            thresholdMapCell{iChannel} = fit90.thresholdMap;
            cleanMaskCell{iChannel} = fit90.cleanMask;
            ellipseStatus{iChannel} = fit90.status;

            if fit90.fitOK
                ellipseFitVec(iChannel) = true;
                ellipseCenter_pix{iChannel} = fit90.center;
                ellipseX_pix{iChannel} = fit90.x;
                ellipseY_pix{iChannel} = fit90.y;

                xCenterDeg = pix2deg(fit90.center(1) - WindowCenter(1));
                yCenterDeg = pix2deg(WindowCenter(2) - fit90.center(2));
                xDeg = pix2deg(fit90.x - WindowCenter(1));
                yDeg = pix2deg(WindowCenter(2) - fit90.y);

                ellipseCenter_deg{iChannel} = [xCenterDeg, yCenterDeg];
                ellipseX_deg{iChannel} = xDeg;
                ellipseY_deg{iChannel} = yDeg;
                ellipseArea_deg2(iChannel) = polyarea(xDeg, yDeg);
            end

            if fit68.fitOK
                xCenterDeg68 = pix2deg(fit68.center(1) - WindowCenter(1));
                yCenterDeg68 = pix2deg(WindowCenter(2) - fit68.center(2));
                xDeg68 = pix2deg(fit68.x - WindowCenter(1));
                yDeg68 = pix2deg(WindowCenter(2) - fit68.y);

                ellipse68Center_pix{iChannel} = fit68.center;
                ellipse68X_pix{iChannel} = fit68.x;
                ellipse68Y_pix{iChannel} = fit68.y;
                ellipse68Center_deg{iChannel} = [xCenterDeg68, yCenterDeg68];
                ellipse68X_deg{iChannel} = xDeg68;
                ellipse68Y_deg{iChannel} = yDeg68;
                ellipse68Area_deg2(iChannel) = polyarea(xDeg68, yDeg68);
            end

            logMessage(logFile, 'Session %d channel %02d status: %s', ...
                iSession, channelNum, ellipseStatus{iChannel});
        catch ME
            ellipseStatus{iChannel} = ['Failed: ', ME.message];
            logMessage(logFile, 'Session %d channel %02d failed: %s', ...
                iSession, channelNum, ME.message);
        end
    end

    RF_table.EllipseFit{iSession} = ellipseFitVec;
    RF_table.EllipseStatus{iSession} = ellipseStatus;
    RF_table.ThresholdMap{iSession} = thresholdMapCell;
    RF_table.CleanMask{iSession} = cleanMaskCell;
    RF_table.EllipseCenter_pix{iSession} = ellipseCenter_pix;
    RF_table.EllipseX_pix{iSession} = ellipseX_pix;
    RF_table.EllipseY_pix{iSession} = ellipseY_pix;
    RF_table.EllipseCenter_deg{iSession} = ellipseCenter_deg;
    RF_table.EllipseX_deg{iSession} = ellipseX_deg;
    RF_table.EllipseY_deg{iSession} = ellipseY_deg;
    RF_table.EllipseArea_deg2{iSession} = ellipseArea_deg2;
    RF_table.Ellipse68Center_pix{iSession} = ellipse68Center_pix;
    RF_table.Ellipse68X_pix{iSession} = ellipse68X_pix;
    RF_table.Ellipse68Y_pix{iSession} = ellipse68Y_pix;
    RF_table.Ellipse68Center_deg{iSession} = ellipse68Center_deg;
    RF_table.Ellipse68X_deg{iSession} = ellipse68X_deg;
    RF_table.Ellipse68Y_deg{iSession} = ellipse68Y_deg;
    RF_table.Ellipse68Area_deg2{iSession} = ellipse68Area_deg2;

    try
        saveSessionRFGridFigure( ...
            RF_table, iSession, sessionChannelNums, sessionRawRF, sessionUniXPos, sessionUniYPos, ...
            thresholdMapCell, cleanMaskCell, ellipseX_deg, ellipseY_deg, ...
            ellipse68X_deg, ellipse68Y_deg, ellipseStatus, WindowCenter, pix2deg, plotDir);
    catch ME
        logMessage(logFile, 'Session %d overview figure failed: %s', iSession, ME.message);
    end
end

unit_table = RF_table;
save(outputMat, 'unit_table', 'RF_table', '-v7.3');
logMessage(logFile, 'Saved fitted session table to %s', outputMat);

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
for iName = 1:numel(preferredNames)
    if isfield(S, preferredNames{iName}) && istable(S.(preferredNames{iName}))
        T = S.(preferredNames{iName});
        return
    end
end
for iName = 1:numel(names)
    if istable(S.(names{iName}))
        T = S.(names{iName});
        return
    end
end
error('No MATLAB table found in the input MAT file.');
end

function channelNums = getSessionChannelNums(RF_table, iSession)
if ismember('ChannelNums', RF_table.Properties.VariableNames)
    channelNums = RF_table.ChannelNums{iSession};
else
    nChannels = numel(RF_table.rawRFmap{iSession});
    channelNums = (1:nChannels)';
end
channelNums = channelNums(:);
end

function monkeyText = getSessionMonkey(RF_table, iSession)
if ismember('Monkey', RF_table.Properties.VariableNames)
    value = RF_table.Monkey{iSession};
    if isstring(value)
        monkeyText = char(value);
    else
        monkeyText = char(string(value));
    end
else
    monkeyText = 'UnknownMonkey';
end
end

function dateText = getSessionDateText(RF_table, iSession)
rawDate = RF_table.Date(iSession);
if iscell(rawDate)
    rawDate = rawDate{1};
end

if isdatetime(rawDate)
    dateText = datestr(rawDate, 'yyyymmdd');
elseif isnumeric(rawDate)
    dateText = datestr(rawDate, 'yyyymmdd');
else
    dateText = char(string(rawDate));
end
end

function suffix = pluralSuffix(count)
if count == 1
    suffix = '';
else
    suffix = 's';
end
end

function saveSessionRFGridFigure(RF_table, iSession, sessionChannelNums, sessionRawRF, sessionUniXPos, sessionUniYPos, ...
    thresholdMapCell, cleanMaskCell, ellipseX_deg, ellipseY_deg, ellipse68X_deg, ellipse68Y_deg, ...
    ellipseStatus, WindowCenter, pix2deg, plotDir)
fig = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters', ...
    'Position', [50 50 2200 1100]);

classColormap = [0.15 0.15 0.15; 0.98 0.85 0.20; 0.95 0.35 0.20];
nChannels = numel(sessionChannelNums);

for iChannel = 1:nChannels
    heatIdx = getHeatSubplotIndex(iChannel);
    rfIdx = heatIdx + 8;

    rawRFmap = sessionRawRF{iChannel};
    uniXPos = sessionUniXPos{iChannel};
    uniYPos = sessionUniYPos{iChannel};
    xDegAxis = pix2deg(uniXPos(:)' - WindowCenter(1));
    yDegAxis = pix2deg(WindowCenter(2) - uniYPos(:)');
    [xDegSorted, xOrder] = sort(xDegAxis, 'ascend');
    [yDegSorted, yOrder] = sort(yDegAxis, 'ascend');

    rawRFmapPlot = reorderRFMap(rawRFmap, xOrder, yOrder);
    thresholdMap = thresholdMapCell{iChannel};
    cleanMask = cleanMaskCell{iChannel};

    thresholdClassMapPlot = [];
    if ~isempty(thresholdMap)
        thresholdPassMask = thresholdMap > 0 & ~isnan(thresholdMap);
        excludedMask = thresholdPassMask & ~cleanMask;
        fitMask = cleanMask;
        thresholdClassMap = zeros(size(thresholdMap), 'double');
        thresholdClassMap(excludedMask) = 1;
        thresholdClassMap(fitMask) = 2;
        thresholdClassMapPlot = thresholdClassMap(yOrder, xOrder);
    end

    axHeat = subplot(4, 8, heatIdx); hold(axHeat, 'on');
    imagesc(axHeat, xDegSorted, yDegSorted, rawRFmapPlot);
    set(axHeat, 'YDir', 'normal');
    axis(axHeat, 'equal');
    axis(axHeat, 'tight');
    box(axHeat, 'off');
    grid(axHeat, 'on');
    colormap(axHeat, 'parula');
    plotAxisCross(axHeat);
    if ~isempty(ellipseX_deg{iChannel}) && ~isempty(ellipseY_deg{iChannel})
        plot(axHeat, ellipseX_deg{iChannel}, ellipseY_deg{iChannel}, '-', 'Color', [1 1 1], 'LineWidth', 1.3);
    end
    if ~isempty(ellipse68X_deg{iChannel}) && ~isempty(ellipse68Y_deg{iChannel})
        plot(axHeat, ellipse68X_deg{iChannel}, ellipse68Y_deg{iChannel}, '-', 'Color', [1 0.35 0.1], 'LineWidth', 1.1);
    end
    title(axHeat, sprintf('Ch%02d Heat', sessionChannelNums(iChannel)), 'Interpreter', 'none', 'FontSize', 10);
    set(axHeat, 'FontSize', 8);

    axRF = subplot(4, 8, rfIdx); hold(axRF, 'on');
    if isempty(thresholdClassMapPlot)
        imagesc(axRF, xDegSorted, yDegSorted, zeros(size(rawRFmapPlot)));
        colormap(axRF, classColormap);
        caxis(axRF, [0 2]);
    else
        imagesc(axRF, xDegSorted, yDegSorted, thresholdClassMapPlot);
        colormap(axRF, classColormap);
        caxis(axRF, [0 2]);
    end
    set(axRF, 'YDir', 'normal');
    axis(axRF, 'equal');
    axis(axRF, 'tight');
    box(axRF, 'off');
    grid(axRF, 'on');
    plotAxisCross(axRF);
    if ~isempty(ellipseX_deg{iChannel}) && ~isempty(ellipseY_deg{iChannel})
        plot(axRF, ellipseX_deg{iChannel}, ellipseY_deg{iChannel}, '-', 'Color', [1 1 1], 'LineWidth', 1.3);
    end
    if ~isempty(ellipse68X_deg{iChannel}) && ~isempty(ellipse68Y_deg{iChannel})
        plot(axRF, ellipse68X_deg{iChannel}, ellipse68Y_deg{iChannel}, '-', 'Color', [0.15 0.85 1], 'LineWidth', 1.1);
    end
    title(axRF, sprintf('Ch%02d RF: %s', sessionChannelNums(iChannel), shortenStatus(ellipseStatus{iChannel})), ...
        'Interpreter', 'none', 'FontSize', 9);
    set(axRF, 'FontSize', 8);
end

sessionTitle = sprintf('%s %s %s | Session %d', ...
    getSessionMonkey(RF_table, iSession), ...
    getSessionDateText(RF_table, iSession), ...
    getSessionROIText(RF_table, iSession), iSession);
sgtitle(fig, sessionTitle, 'Interpreter', 'none', 'FontSize', 14, 'FontWeight', 'bold');

roiDir = fullfile(plotDir, sanitizeFileComponent(getSessionROIText(RF_table, iSession)));
if ~exist(roiDir, 'dir')
    mkdir(roiDir);
end
outName = fullfile(roiDir, sprintf('RFSession_%s_%s_%s.png', ...
    sanitizeFileComponent(getSessionMonkey(RF_table, iSession)), ...
    sanitizeFileComponent(getSessionDateText(RF_table, iSession)), ...
    sanitizeFileComponent(getSessionROIText(RF_table, iSession))));
print(fig, outName, '-dpng', '-painters', '-r200');
close(fig);
end

function subplotIdx = getHeatSubplotIndex(channelIndex)
subplotIdx = channelIndex + 8 * floor((channelIndex - 1) / 8);
end

function reorderedMap = reorderRFMap(rawRFmap, xOrder, yOrder)
reorderedMap = rawRFmap(yOrder, xOrder);
end

function plotAxisCross(ax)
xline(ax, 0, ':', 'Color', [1 1 1] * 0.7, 'LineWidth', 0.75);
yline(ax, 0, ':', 'Color', [1 1 1] * 0.7, 'LineWidth', 0.75);
end

function textOut = shortenStatus(textIn)
textOut = char(string(textIn));
textOut = strtrim(textOut);
if isempty(textOut)
    textOut = 'NA';
    return
end
if numel(textOut) > 22
    textOut = [textOut(1:19), '...'];
end
end

function roiText = getSessionROIText(RF_table, iSession)
if ismember('ROI', RF_table.Properties.VariableNames)
    rawValue = RF_table.ROI(iSession, :);
    if iscell(rawValue)
        rawValue = rawValue{1};
    end
    roiText = strtrim(char(string(rawValue)));
else
    roiText = 'UnknownROI';
end
end

function textOut = sanitizeFileComponent(textIn)
textOut = char(string(textIn));
textOut = regexprep(textOut, '[\\/:*?"<>|]+', '_');
textOut = regexprep(textOut, '\s+', '_');
if isempty(textOut)
    textOut = 'NA';
end
end

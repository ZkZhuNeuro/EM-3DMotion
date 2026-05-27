clear; clc;

inputMat = 'C:\EM\RF_data\RF_table_MUAStim_JimClay_with_ellipse.mat';
outputDir = 'C:\EM\RF_data\PopulationSummary';
logFile = fullfile(outputDir, 'PlotMUAStim_EllipsePopulationSummary.log');

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end
if exist(logFile, 'file')
    delete(logFile);
end

logMessage(logFile, 'Loading %s', inputMat);
S = load(inputMat);
RF_table = getTableFromMatStruct(S);
verifyPopulationFields(RF_table, inputMat);

channelEntries = buildChannelEntryList(RF_table);
[xResolutionDeg, yResolutionDeg] = computeRFResolutionDeg(RF_table, channelEntries);
leftThresholdDeg = -xResolutionDeg;

logMessage(logFile, 'Estimated RF resolution across all sessions: x=%.4f deg, y=%.4f deg', ...
    xResolutionDeg, yResolutionDeg);
fprintf('Estimated RF resolution: x=%.4f deg, y=%.4f deg\n', xResolutionDeg, yResolutionDeg);
fprintf('Left-hemisphere threshold: x <= %.4f deg\n', leftThresholdDeg);

roiNames = {'MT', 'FST'};
for iRoi = 1:numel(roiNames)
    roiName = roiNames{iRoi};
    roiEntries = filterChannelEntriesByROI(RF_table, channelEntries, roiName);
    if isempty(roiEntries)
        logMessage(logFile, '%s: no entries found.', roiName);
        fprintf('\n%s:\nNo entries found.\n', roiName);
        continue
    end

    roiSummary68 = savePopulationCumulativeFigure( ...
        RF_table, roiEntries, 68, leftThresholdDeg, ...
        fullfile(outputDir, sprintf('MUAStim_%s_Ellipse68_PopulationCumulative.png', roiName)));
    roiSummary90 = savePopulationCumulativeFigure( ...
        RF_table, roiEntries, 90, leftThresholdDeg, ...
        fullfile(outputDir, sprintf('MUAStim_%s_Ellipse90_PopulationCumulative.png', roiName)));
    regressionSummary = saveHoleYEccentricityRegression( ...
        RF_table, roiEntries, 68, ...
        fullfile(outputDir, sprintf('MUAStim_%s_Ellipse68_HoleY_vs_Eccentricity.png', roiName)));

    logMessage(logFile, '%s summary:', roiName);
    logPopulationSummary(logFile, sprintf('%s Ellipse68', roiName), leftThresholdDeg, roiSummary68);
    logPopulationSummary(logFile, sprintf('%s Ellipse90', roiName), leftThresholdDeg, roiSummary90);
    logMessage(logFile, '%s HoleY vs eccentricity (68%% center): n=%d, r=%.4f, p=%.4g', ...
        roiName, regressionSummary.nPoints, regressionSummary.rValue, regressionSummary.pValue);

    fprintf('\n%s:\n', roiName);
    printPopulationSummary('Ellipse68', leftThresholdDeg, roiSummary68);
    printPopulationSummary('Ellipse90', leftThresholdDeg, roiSummary90);
    fprintf('%s HoleY vs eccentricity (68%% center): n=%d, r=%.4f, p=%.4g\n', ...
        roiName, regressionSummary.nPoints, regressionSummary.rValue, regressionSummary.pValue);

    monkeyNames = getUniqueMonkeyNames(RF_table);
    for iMonkey = 1:numel(monkeyNames)
        monkeyName = monkeyNames{iMonkey};
        monkeyEntries = filterChannelEntriesByMonkeyAndROI(RF_table, roiEntries, monkeyName, roiName);
        if isempty(monkeyEntries)
            continue
        end

        monkeySummary68 = savePopulationCumulativeFigure( ...
            RF_table, monkeyEntries, 68, leftThresholdDeg, ...
            fullfile(outputDir, sprintf('MUAStim_%s_%s_Ellipse68_PopulationCumulative.png', roiName, monkeyName)));
        monkeySummary90 = savePopulationCumulativeFigure( ...
            RF_table, monkeyEntries, 90, leftThresholdDeg, ...
            fullfile(outputDir, sprintf('MUAStim_%s_%s_Ellipse90_PopulationCumulative.png', roiName, monkeyName)));

        fprintf('%s - %s only:\n', roiName, monkeyName);
        printPopulationSummary('Ellipse68', leftThresholdDeg, monkeySummary68);
        printPopulationSummary('Ellipse90', leftThresholdDeg, monkeySummary90);

        logMessage(logFile, '%s %s-only summary:', roiName, monkeyName);
        logPopulationSummary(logFile, sprintf('%s %s Ellipse68', roiName, monkeyName), leftThresholdDeg, monkeySummary68);
        logPopulationSummary(logFile, sprintf('%s %s Ellipse90', roiName, monkeyName), leftThresholdDeg, monkeySummary90);
    end
end

function summary = savePopulationCumulativeFigure(RF_table, channelEntries, ellipseType, leftThresholdDeg, figurePath)
fig = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters', ...
    'Position', [100 100 760 600]);
ax = axes(fig);
hold(ax, 'on');
box(ax, 'off');
grid(ax, 'on');
axis(ax, 'equal');
xlabel(ax, 'x (deg)');
ylabel(ax, 'y (deg)');
xline(ax, 0, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1);
yline(ax, 0, ':', 'Color', [0.4 0.4 0.4], 'LineWidth', 1);
xline(ax, leftThresholdDeg, '--', 'Color', [0.85 0.2 0.2], 'LineWidth', 1.2);

allX = [];
allY = [];
ellipseCount = 0;
ellipseLeftCount = 0;
centerCount = 0;
centerLeftCount = 0;
fixationCoverCount = 0;

for iEntry = 1:size(channelEntries, 1)
    sessionIdx = channelEntries(iEntry, 1);
    channelIdx = channelEntries(iEntry, 2);

    if ~hasEllipseFit(RF_table, sessionIdx, channelIdx, ellipseType)
        continue
    end

    [xDeg, yDeg] = getEllipseOutline(RF_table, sessionIdx, channelIdx, ellipseType);
    [xDeg, yDeg] = cleanOutline(xDeg, yDeg);
    if isempty(xDeg)
        continue
    end

    plot(ax, xDeg, yDeg, 'Color', [0 0 0 0.12], 'LineWidth', 0.8);
    allX = [allX; xDeg]; %#ok<AGROW>
    allY = [allY; yDeg]; %#ok<AGROW>
    ellipseCount = ellipseCount + 1;
    ellipseLeftCount = ellipseLeftCount + double(outlineReachesLeftLine(xDeg, leftThresholdDeg));
    fixationCoverCount = fixationCoverCount + double(outlineCoversPoint(xDeg, yDeg, 0, 0));

    if hasEllipseCenter(RF_table, sessionIdx, channelIdx, ellipseType)
        centerDeg = getEllipseCenter(RF_table, sessionIdx, channelIdx, ellipseType);
        centerCount = centerCount + 1;
        centerLeftCount = centerLeftCount + double(centerDeg(1) <= leftThresholdDeg);
    end
end

setAxesLimits(ax, allX, allY);
title(ax, sprintf('%d%% ellipse fits | reach x<=%.3f deg: %d/%d (%.1f%%)', ...
    ellipseType, leftThresholdDeg, ellipseLeftCount, ellipseCount, ...
    100 * safeProportion(ellipseLeftCount, ellipseCount)), 'Interpreter', 'none');

print(fig, figurePath, '-dpng', '-r220');
close(fig);

summary = struct( ...
    'ellipseCountLeft', ellipseLeftCount, ...
    'ellipseCountTotal', ellipseCount, ...
    'ellipsePropLeft', safeProportion(ellipseLeftCount, ellipseCount), ...
    'centerCountLeft', centerLeftCount, ...
    'centerCountTotal', centerCount, ...
    'centerPropLeft', safeProportion(centerLeftCount, centerCount), ...
    'fixationCoverCount', fixationCoverCount, ...
    'fixationCoverProp', safeProportion(fixationCoverCount, ellipseCount));
end

function summary = saveHoleYEccentricityRegression(RF_table, channelEntries, ellipseType, figurePath)
holeY = [];
eccDeg = [];

for iEntry = 1:size(channelEntries, 1)
    sessionIdx = channelEntries(iEntry, 1);
    channelIdx = channelEntries(iEntry, 2);
    if ~hasEllipseCenter(RF_table, sessionIdx, channelIdx, ellipseType)
        continue
    end

    yHole = getHoleSecondElement(RF_table, sessionIdx);
    if ~isfinite(yHole)
        continue
    end

    centerDeg = getEllipseCenter(RF_table, sessionIdx, channelIdx, ellipseType);
    eccVal = hypot(centerDeg(1), centerDeg(2));
    if ~isfinite(eccVal)
        continue
    end

    holeY(end + 1, 1) = yHole; %#ok<AGROW>
    eccDeg(end + 1, 1) = eccVal; %#ok<AGROW>
end

fig = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters', ...
    'Position', [120 120 700 560]);
ax = axes(fig);
hold(ax, 'on');
box(ax, 'off');
grid(ax, 'on');
scatter(ax, holeY, eccDeg, 28, 'filled', ...
    'MarkerFaceColor', [0.15 0.35 0.75], ...
    'MarkerFaceAlpha', 0.75);
xlabel(ax, 'Hole Y');
ylabel(ax, 'RF eccentricity (deg)');
title(ax, sprintf('Hole Y vs RF eccentricity (%d%% ellipse centers)', ellipseType), 'Interpreter', 'none');

if numel(holeY) >= 2
    coeffs = polyfit(holeY, eccDeg, 1);
    xFit = linspace(min(holeY), max(holeY), 100);
    yFit = polyval(coeffs, xFit);
    plot(ax, xFit, yFit, '-', 'Color', [0.85 0.2 0.2], 'LineWidth', 1.8);
    [rValue, pValue] = corr(holeY, eccDeg, 'Rows', 'complete');
else
    rValue = NaN;
    pValue = NaN;
end

annotationText = sprintf('n = %d\nr = %.3f\np = %.3g', numel(holeY), rValue, pValue);
text(ax, 0.03, 0.97, annotationText, 'Units', 'normalized', ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
    'BackgroundColor', 'w', 'Margin', 4);

print(fig, figurePath, '-dpng', '-r220');
close(fig);

summary = struct('nPoints', numel(holeY), 'rValue', rValue, 'pValue', pValue);
end

function channelEntries = buildChannelEntryList(RF_table)
channelEntries = zeros(0, 2);
for iSession = 1:height(RF_table)
    if ismember('ChannelNums', RF_table.Properties.VariableNames)
        channelNums = RF_table.ChannelNums{iSession};
        nChannels = numel(channelNums);
    else
        nChannels = numel(RF_table.rawRFmap{iSession});
    end
    newRows = [repmat(iSession, nChannels, 1), (1:nChannels)'];
    channelEntries = [channelEntries; newRows]; %#ok<AGROW>
end
end

function monkeyNames = getUniqueMonkeyNames(RF_table)
if ~ismember('Monkey', RF_table.Properties.VariableNames)
    monkeyNames = {};
    return
end

monkeyNames = cell(height(RF_table), 1);
for iSession = 1:height(RF_table)
    value = RF_table.Monkey{iSession};
    monkeyNames{iSession} = char(string(value));
end
monkeyNames = unique(monkeyNames, 'stable');
monkeyNames = monkeyNames(~cellfun(@isempty, monkeyNames));
end

function filteredEntries = filterChannelEntriesByMonkey(RF_table, channelEntries, monkeyName)
keepMask = false(size(channelEntries, 1), 1);
for iEntry = 1:size(channelEntries, 1)
    sessionIdx = channelEntries(iEntry, 1);
    sessionMonkey = char(string(RF_table.Monkey{sessionIdx}));
    keepMask(iEntry) = strcmpi(sessionMonkey, monkeyName);
end
filteredEntries = channelEntries(keepMask, :);
end

function filteredEntries = filterChannelEntriesByROI(RF_table, channelEntries, roiName)
keepMask = false(size(channelEntries, 1), 1);
for iEntry = 1:size(channelEntries, 1)
    sessionIdx = channelEntries(iEntry, 1);
    sessionROI = getSessionROI(RF_table, sessionIdx);
    keepMask(iEntry) = strcmpi(sessionROI, roiName);
end
filteredEntries = channelEntries(keepMask, :);
end

function filteredEntries = filterChannelEntriesByMonkeyAndROI(RF_table, channelEntries, monkeyName, roiName)
keepMask = false(size(channelEntries, 1), 1);
for iEntry = 1:size(channelEntries, 1)
    sessionIdx = channelEntries(iEntry, 1);
    sessionMonkey = char(string(RF_table.Monkey{sessionIdx}));
    sessionROI = getSessionROI(RF_table, sessionIdx);
    keepMask(iEntry) = strcmpi(sessionMonkey, monkeyName) && strcmpi(sessionROI, roiName);
end
filteredEntries = channelEntries(keepMask, :);
end

function roiText = getSessionROI(RF_table, sessionIdx)
if ~ismember('ROI', RF_table.Properties.VariableNames)
    roiText = '';
    return
end

roiVal = RF_table.ROI(sessionIdx, :);
if iscell(roiVal)
    roiVal = roiVal{1};
end
roiText = strtrim(char(string(roiVal)));
end

function [xResolutionDeg, yResolutionDeg] = computeRFResolutionDeg(RF_table, channelEntries)
xSteps = [];
ySteps = [];

for iEntry = 1:size(channelEntries, 1)
    sessionIdx = channelEntries(iEntry, 1);
    channelIdx = channelEntries(iEntry, 2);

    sessionUniXPos = RF_table.uniXPos{sessionIdx};
    sessionUniYPos = RF_table.uniYPos{sessionIdx};
    uniXPos = sessionUniXPos{channelIdx};
    uniYPos = sessionUniYPos{channelIdx};
    xDegAxis = getStoredOrComputedDegAxis(RF_table, sessionIdx, channelIdx, 'XPos_deg', uniXPos, false);
    yDegAxis = getStoredOrComputedDegAxis(RF_table, sessionIdx, channelIdx, 'YPos_deg', uniYPos, true);

    xSteps = [xSteps; positiveAxisSteps(xDegAxis)]; %#ok<AGROW>
    ySteps = [ySteps; positiveAxisSteps(yDegAxis)]; %#ok<AGROW>
end

if isempty(xSteps)
    error('Could not estimate RF x-axis resolution in degrees from the saved table.');
end

xResolutionDeg = median(xSteps, 'omitnan');
if isempty(ySteps)
    yResolutionDeg = xResolutionDeg;
else
    yResolutionDeg = median(ySteps, 'omitnan');
end
end

function degAxis = getStoredOrComputedDegAxis(RF_table, sessionIdx, channelIdx, varName, pixAxis, flipSign)
degAxis = [];
if ismember(varName, RF_table.Properties.VariableNames)
    try
        sessionDegAxis = RF_table.(varName){sessionIdx};
        degAxis = sessionDegAxis{channelIdx};
    catch
        degAxis = [];
    end
end

if isempty(degAxis)
    windowWidth = 1920;
    windowHeight = 1080;
    viewingDistance = 570;
    screenWidth = 635;
    mm2deg = @(x) atand(x./viewingDistance);
    pix2mm = @(x) x.*screenWidth./windowWidth;
    pix2deg = @(x) mm2deg(pix2mm(x));
    windowCenter = [windowWidth/2, windowHeight/2];
    if flipSign
        degAxis = pix2deg(windowCenter(2) - pixAxis(:)');
    else
        degAxis = pix2deg(pixAxis(:)' - windowCenter(1));
    end
end

degAxis = degAxis(:)';
end

function steps = positiveAxisSteps(axisVals)
axisVals = axisVals(:);
axisVals = axisVals(isfinite(axisVals));
axisVals = unique(axisVals, 'sorted');
if numel(axisVals) < 2
    steps = [];
    return
end
steps = diff(axisVals);
steps = steps(steps > 0);
end

function tf = hasEllipseFit(RF_table, sessionIdx, channelIdx, ellipseType)
if ellipseType == 68
    requiredVars = {'EllipseFit', 'Ellipse68X_deg', 'Ellipse68Y_deg'};
else
    requiredVars = {'EllipseFit', 'EllipseX_deg', 'EllipseY_deg'};
end
if ~all(ismember(requiredVars, RF_table.Properties.VariableNames))
    tf = false;
    return
end

sessionFit = RF_table.EllipseFit{sessionIdx};
if channelIdx > numel(sessionFit) || ~logical(sessionFit(channelIdx))
    tf = false;
    return
end

if ellipseType == 68
    sessionX = RF_table.Ellipse68X_deg{sessionIdx};
    sessionY = RF_table.Ellipse68Y_deg{sessionIdx};
else
    sessionX = RF_table.EllipseX_deg{sessionIdx};
    sessionY = RF_table.EllipseY_deg{sessionIdx};
end

xDeg = sessionX{channelIdx};
yDeg = sessionY{channelIdx};
tf = isnumeric(xDeg) && isnumeric(yDeg) && ~isempty(xDeg) && ~isempty(yDeg);
end

function tf = hasEllipseCenter(RF_table, sessionIdx, channelIdx, ellipseType)
if ellipseType == 68
    requiredVars = {'Ellipse68Center_deg'};
else
    requiredVars = {'EllipseCenter_deg'};
end
if ~all(ismember(requiredVars, RF_table.Properties.VariableNames))
    tf = false;
    return
end

centerDeg = getEllipseCenter(RF_table, sessionIdx, channelIdx, ellipseType);
tf = isnumeric(centerDeg) && numel(centerDeg) >= 2 && all(isfinite(centerDeg(1:2)));
end

function [xDeg, yDeg] = getEllipseOutline(RF_table, sessionIdx, channelIdx, ellipseType)
if ellipseType == 68
    xDeg = RF_table.Ellipse68X_deg{sessionIdx}{channelIdx};
    yDeg = RF_table.Ellipse68Y_deg{sessionIdx}{channelIdx};
else
    xDeg = RF_table.EllipseX_deg{sessionIdx}{channelIdx};
    yDeg = RF_table.EllipseY_deg{sessionIdx}{channelIdx};
end
end

function centerDeg = getEllipseCenter(RF_table, sessionIdx, channelIdx, ellipseType)
if ellipseType == 68
    centerDeg = RF_table.Ellipse68Center_deg{sessionIdx}{channelIdx};
else
    centerDeg = RF_table.EllipseCenter_deg{sessionIdx}{channelIdx};
end
end

function [xDeg, yDeg] = cleanOutline(xDeg, yDeg)
xDeg = xDeg(:);
yDeg = yDeg(:);
good = isfinite(xDeg) & isfinite(yDeg);
xDeg = xDeg(good);
yDeg = yDeg(good);
end

function tf = outlineReachesLeftLine(xDeg, lineDeg)
xDeg = xDeg(:);
xDeg = xDeg(isfinite(xDeg));
if isempty(xDeg)
    tf = false;
    return
end
tf = min(xDeg) <= lineDeg;
end

function tf = outlineCoversPoint(xDeg, yDeg, xPoint, yPoint)
if isempty(xDeg) || isempty(yDeg)
    tf = false;
    return
end

xDeg = xDeg(:);
yDeg = yDeg(:);
good = isfinite(xDeg) & isfinite(yDeg);
xDeg = xDeg(good);
yDeg = yDeg(good);
if numel(xDeg) < 3
    tf = false;
    return
end

if xDeg(1) ~= xDeg(end) || yDeg(1) ~= yDeg(end)
    xDeg(end + 1) = xDeg(1); %#ok<AGROW>
    yDeg(end + 1) = yDeg(1); %#ok<AGROW>
end

tf = inpolygon(xPoint, yPoint, xDeg, yDeg);
end

function holeY = getHoleSecondElement(RF_table, sessionIdx)
holeY = NaN;
if ~ismember('Hole', RF_table.Properties.VariableNames)
    return
end

holeVal = RF_table.Hole(sessionIdx, :);
if iscell(holeVal)
    holeVal = holeVal{1};
end

if isnumeric(holeVal)
    holeVal = holeVal(:)';
    if numel(holeVal) >= 2 && isfinite(holeVal(2))
        holeY = holeVal(2);
    end
elseif isstring(holeVal) || ischar(holeVal)
    parsedVal = str2num(char(holeVal)); %#ok<ST2NM>
    if isnumeric(parsedVal)
        parsedVal = parsedVal(:)';
        if numel(parsedVal) >= 2 && isfinite(parsedVal(2))
            holeY = parsedVal(2);
        end
    end
end
end

function setAxesLimits(ax, xVals, yVals)
if isempty(xVals) || isempty(yVals)
    xlim(ax, [-20 20]);
    ylim(ax, [-20 20]);
    return
end
xPad = max(0.5, 0.05 * range(xVals));
yPad = max(0.5, 0.05 * range(yVals));
xlim(ax, [min(xVals) - xPad, max(xVals) + xPad]);
ylim(ax, [min(yVals) - yPad, max(yVals) + yPad]);
end

function p = safeProportion(countVal, totalVal)
if totalVal <= 0
    p = NaN;
else
    p = countVal / totalVal;
end
end

function logPopulationSummary(logFile, label, leftThresholdDeg, summary)
logMessage(logFile, '%s reach x<=%g deg: %d/%d (%.2f%%)', ...
    label, leftThresholdDeg, summary.ellipseCountLeft, summary.ellipseCountTotal, ...
    100 * summary.ellipsePropLeft);
logMessage(logFile, '%s center x<=%g deg: %d/%d (%.2f%%)', ...
    label, leftThresholdDeg, summary.centerCountLeft, summary.centerCountTotal, ...
    100 * summary.centerPropLeft);
logMessage(logFile, '%s covers (0,0): %d/%d (%.2f%%)', ...
    label, summary.fixationCoverCount, summary.ellipseCountTotal, ...
    100 * summary.fixationCoverProp);
end

function printPopulationSummary(label, leftThresholdDeg, summary)
fprintf('%s reach x<=%g deg: %d/%d (%.2f%%)\n', ...
    label, leftThresholdDeg, summary.ellipseCountLeft, summary.ellipseCountTotal, ...
    100 * summary.ellipsePropLeft);
fprintf('%s center x<=%g deg: %d/%d (%.2f%%)\n', ...
    label, leftThresholdDeg, summary.centerCountLeft, summary.centerCountTotal, ...
    100 * summary.centerPropLeft);
fprintf('%s covers (0,0): %d/%d (%.2f%%)\n', ...
    label, summary.fixationCoverCount, summary.ellipseCountTotal, ...
    100 * summary.fixationCoverProp);
end

function verifyPopulationFields(RF_table, inputMat)
requiredVars = {'EllipseFit', 'EllipseX_deg', 'EllipseY_deg', 'Ellipse68X_deg', 'Ellipse68Y_deg'};
if ~all(ismember(requiredVars, RF_table.Properties.VariableNames))
    error(['Saved ellipse table is missing required population-analysis fields. ', ...
        'Loaded file: %s'], inputMat);
end
end

function T = getTableFromMatStruct(S)
names = fieldnames(S);
preferredNames = {'RF_table', 'unit_table'};
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

function logMessage(logFile, message, varargin)
fid = fopen(logFile, 'a');
if fid < 0
    return
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, [datestr(now, 'yyyy-mm-dd HH:MM:SS'), ' - ', message, '\n'], varargin{:});
end

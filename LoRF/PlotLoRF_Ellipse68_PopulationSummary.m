clear; 

%% Population summary of saved 68% ellipse fits.
% This script reads the saved ellipse-fit table and generates only the
% population-level cumulative overlap figure for the saved 68% ellipses.

inputMat = 'C:\LoData\RF\LoRF_unit_table_with_ellipse.mat';
outputDir = 'C:\LoData\RF\OldVsNewFitComparison';
figurePath = fullfile(outputDir, 'LoRF_Ellipse68_PopulationCumulative.png');
regressionFigurePath = fullfile(outputDir, 'LoRF_Ellipse68_HoleY_vs_Eccentricity.png');
logFile = fullfile(outputDir, 'PlotLoRF_Ellipse68_PopulationAnalysis.log');

unitIndices = [];

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

if isempty(unitIndices)
    unitIndices = 1:height(RF_table);
end

[xResolutionDeg, yResolutionDeg] = computeRFResolutionDeg(RF_table, unitIndices);
crossingLineDeg = xResolutionDeg;

summary = savePopulationCumulativeFigure(RF_table, unitIndices, figurePath, crossingLineDeg);
regressionSummary = saveHoleYEccentricityRegression(RF_table, unitIndices, regressionFigurePath);
logMessage(logFile, 'Saved population cumulative figure to %s', figurePath);
logMessage(logFile, 'Saved Hole-Y eccentricity regression figure to %s', regressionFigurePath);
logMessage(logFile, 'Estimated RF resolution: x=%.4f deg, y=%.4f deg', ...
    xResolutionDeg, yResolutionDeg);
logMessage(logFile, 'Ellipse68 reach x>=%g deg: %d/%d (%.2f%%)', ...
    crossingLineDeg, summary.ellipseCountCross, summary.ellipseCountTotal, 100 * summary.ellipsePropCross);
logMessage(logFile, 'Ellipse68 center x>=%g deg: %d/%d (%.2f%%)', ...
    crossingLineDeg, summary.centerCountCross, summary.centerCountTotal, 100 * summary.centerPropCross);
logMessage(logFile, 'Ellipse68 covers (0,0): %d/%d (%.2f%%)', ...
    summary.fixationCoverCount, summary.ellipseCountTotal, 100 * summary.fixationCoverProp);
logMessage(logFile, 'HoleY vs eccentricity: n=%d, r=%.4f, p=%.4g', ...
    regressionSummary.nPoints, regressionSummary.rValue, regressionSummary.pValue);
fprintf('Estimated RF resolution: x=%.4f deg, y=%.4f deg\n', xResolutionDeg, yResolutionDeg);
fprintf('Ellipse68 reach x>=%g deg: %d/%d (%.2f%%)\n', ...
    crossingLineDeg, summary.ellipseCountCross, summary.ellipseCountTotal, 100 * summary.ellipsePropCross);
fprintf('Ellipse68 center x>=%g deg: %d/%d (%.2f%%)\n', ...
    crossingLineDeg, summary.centerCountCross, summary.centerCountTotal, 100 * summary.centerPropCross);
fprintf('Ellipse68 covers (0,0): %d/%d (%.2f%%)\n', ...
    summary.fixationCoverCount, summary.ellipseCountTotal, 100 * summary.fixationCoverProp);
fprintf('HoleY vs eccentricity: n=%d, r=%.4f, p=%.4g\n', ...
    regressionSummary.nPoints, regressionSummary.rValue, regressionSummary.pValue);

function summary = savePopulationCumulativeFigure(RF_table, unitIndices, figurePath, crossingLineDeg)
fig = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters', ...
    'Position', [100 100 700 560]);
tileObj = tiledlayout(fig, 1, 1, 'Padding', 'compact', 'TileSpacing', 'compact');

axNew = nexttile(tileObj, 1);
hold(axNew, 'on');
box(axNew, 'off');
grid(axNew, 'on');
axis(axNew, 'equal');
xlabel(axNew, 'x (deg)');
ylabel(axNew, 'y (deg)');
xline(axNew, 0, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1);
yline(axNew, 0, ':', 'Color', [0.4 0.4 0.4], 'LineWidth', 1);
xline(axNew, crossingLineDeg, '--', 'Color', [0.85 0.2 0.2], 'LineWidth', 1.2);

allNewX = [];
allNewY = [];
newCount = 0;
newCrossCount = 0;
centerCount = 0;
centerCrossCount = 0;
fixationCoverCount = 0;

for idx = unitIndices
    if hasEllipse68Fit(RF_table, idx)
        xDeg = tableCell(RF_table.Ellipse68X_deg, idx);
        yDeg = tableCell(RF_table.Ellipse68Y_deg, idx);
        [xDeg, yDeg] = cleanOutline(xDeg, yDeg);
        if ~isempty(xDeg)
            plot(axNew, xDeg, yDeg, 'Color', [0 0 0 0.12], 'LineWidth', 0.8);
            allNewX = [allNewX; xDeg]; %#ok<AGROW>
            allNewY = [allNewY; yDeg]; %#ok<AGROW>
            newCount = newCount + 1;
            newCrossCount = newCrossCount + double(outlineReachesVerticalLine(xDeg, crossingLineDeg));
            fixationCoverCount = fixationCoverCount + double(outlineCoversPoint(xDeg, yDeg, 0, 0));

            if hasEllipse68Center(RF_table, idx)
                centerDeg = tableCell(RF_table.Ellipse68Center_deg, idx);
                centerCount = centerCount + 1;
                centerCrossCount = centerCrossCount + double(centerDeg(1) >= crossingLineDeg);
            end
        end
    end
end

setAxesLimits(axNew, allNewX, allNewY);
title(axNew, sprintf('68%% ellipse fits | reach x=%g deg: %d/%d (%.1f%%)', ...
    crossingLineDeg, newCrossCount, newCount, 100 * safeProportion(newCrossCount, newCount)), ...
    'Interpreter', 'none');

sgtitle(tileObj, 'Population cumulative 68% RF ellipses', 'Interpreter', 'none');

print(fig, figurePath, '-dpng', '-r220');
close(fig);

summary = struct( ...
    'ellipseCountCross', newCrossCount, ...
    'ellipseCountTotal', newCount, ...
    'ellipsePropCross', safeProportion(newCrossCount, newCount), ...
    'centerCountCross', centerCrossCount, ...
    'centerCountTotal', centerCount, ...
    'centerPropCross', safeProportion(centerCrossCount, centerCount), ...
    'fixationCoverCount', fixationCoverCount, ...
    'fixationCoverProp', safeProportion(fixationCoverCount, newCount));
end

function summary = saveHoleYEccentricityRegression(RF_table, unitIndices, figurePath)
holeY = [];
eccDeg = [];

for idx = unitIndices
    if ~hasEllipse68Center(RF_table, idx)
        continue
    end

    yHole = getHoleSecondElement(RF_table, idx);
    if ~isfinite(yHole)
        continue
    end

    centerDeg = tableCell(RF_table.Ellipse68Center_deg, idx);
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
title(ax, 'Hole Y vs RF eccentricity', 'Interpreter', 'none');

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

function [xDeg, yDeg] = cleanOutline(xDeg, yDeg)
xDeg = xDeg(:);
yDeg = yDeg(:);
good = isfinite(xDeg) & isfinite(yDeg);
xDeg = xDeg(good);
yDeg = yDeg(good);
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

function tf = hasEllipse68Fit(RF_table, idx)
requiredVars = {'EllipseFit', 'Ellipse68X_deg', 'Ellipse68Y_deg'};
if ~all(ismember(requiredVars, RF_table.Properties.VariableNames))
    tf = false;
    return
end
if ~logical(RF_table.EllipseFit(idx))
    tf = false;
    return
end
xDeg = tableCell(RF_table.Ellipse68X_deg, idx);
yDeg = tableCell(RF_table.Ellipse68Y_deg, idx);
tf = isnumeric(xDeg) && isnumeric(yDeg) && ~isempty(xDeg) && ~isempty(yDeg);
end

function tf = hasEllipse68Center(RF_table, idx)
requiredVars = {'Ellipse68Center_deg'};
if ~all(ismember(requiredVars, RF_table.Properties.VariableNames))
    tf = false;
    return
end
centerDeg = tableCell(RF_table.Ellipse68Center_deg, idx);
tf = isnumeric(centerDeg) && numel(centerDeg) >= 2 && all(isfinite(centerDeg(1:2)));
end

function holeY = getHoleSecondElement(RF_table, idx)
holeY = NaN;
if ~ismember('Hole', RF_table.Properties.VariableNames)
    return
end

holeVal = RF_table.Hole(idx, :);
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

function [xResolutionDeg, yResolutionDeg] = computeRFResolutionDeg(RF_table, unitIndices)
xSteps = [];
ySteps = [];

for idx = unitIndices
    if ~ismember('uniXPos', RF_table.Properties.VariableNames) || ...
            ~ismember('uniYPos', RF_table.Properties.VariableNames)
        continue
    end

    uniXPos = tableCell(RF_table.uniXPos, idx);
    uniYPos = tableCell(RF_table.uniYPos, idx);
    xDegAxis = getStoredOrComputedDegAxis(RF_table, idx, 'XPos_deg', uniXPos, false);
    yDegAxis = getStoredOrComputedDegAxis(RF_table, idx, 'YPos_deg', uniYPos, true);

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

function degAxis = getStoredOrComputedDegAxis(RF_table, idx, varName, pixAxis, flipSign)
degAxis = [];
if ismember(varName, RF_table.Properties.VariableNames)
    try
        degAxis = tableCell(RF_table.(varName), idx);
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

function tf = outlineReachesVerticalLine(xDeg, lineDeg)
xDeg = xDeg(:);
xDeg = xDeg(isfinite(xDeg));
if isempty(xDeg)
    tf = false;
    return
end
tf = max(xDeg) >= lineDeg;
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

function p = safeProportion(countVal, totalVal)
if totalVal <= 0
    p = NaN;
else
    p = countVal / totalVal;
end
end

function verifyPopulationFields(RF_table, inputMat)
requiredVars = {'EllipseFit', 'Ellipse68X_deg', 'Ellipse68Y_deg'};
if ~all(ismember(requiredVars, RF_table.Properties.VariableNames))
    error(['Saved comparison table is missing required population-analysis fields. ', ...
        'Loaded file: %s'], inputMat);
end
end

function T = getTableFromMatStruct(S)
names = fieldnames(S);
preferredNames = {'RF_table', 'unit_table'};
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

function logMessage(logFile, message, varargin)
fid = fopen(logFile, 'a');
if fid < 0
    return
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, [datestr(now, 'yyyy-mm-dd HH:MM:SS'), ' - ', message, '\n'], varargin{:});
end

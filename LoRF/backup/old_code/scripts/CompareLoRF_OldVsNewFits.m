clear; clc;

%% Compare rotated-Gaussian RF fitting against the current 68% ellipse fit.
% This script:
% 1) loads the current LoRF ellipse-fit table,
% 2) builds a mean-FR map for each RF and fits that map with the rotated
%    Gaussian method from the visual-latency RF code, without thresholding
%    or connected-component filtering,
% 3) saves the added rotated-Gaussian fit fields into a separate MAT file.
%
% Population-level plotting is handled separately by
% PlotLoRF_Ellipse68_PopulationSummary.m.

if ~exist('inputMat', 'var') || isempty(inputMat)
    inputMat = 'C:\LoData\RF\LoRF_unit_table_with_ellipse.mat';
end
if ~exist('outputMat', 'var') || isempty(outputMat)
    outputMat = 'C:\LoData\RF\LoRF_unit_table_with_old_gaussian_compare.mat';
end
if ~exist('outputDir', 'var') || isempty(outputDir)
    outputDir = 'C:\LoData\RF\OldVsNewFitComparison';
end
if ~exist('unitIndices', 'var')
    unitIndices = [];
end

logFile = fullfile(outputDir, 'CompareLoRF_OldVsNewFits.log');

rfAnalysisPath = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\RF_analysis';
addpath(rfAnalysisPath);
expectedGaussianFitFile = fullfile(rfAnalysisPath, 'Fit2DGaussian_Subplot.m');

windowWidth = 1920; %(pixels)
windowHeight = 1080; %(pixels)
viewingDistance = 570; %(mm)
screenWidth = 635; %(mm)
mm2deg = @(x) atand(x./viewingDistance);
pix2mm = @(x) x.*screenWidth./windowWidth;
pix2deg = @(x) mm2deg(pix2mm(x));
windowCenter = [windowWidth/2, windowHeight/2];

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end
outputMatDir = fileparts(outputMat);
if ~isempty(outputMatDir) && ~exist(outputMatDir, 'dir')
    mkdir(outputMatDir);
end
if exist(logFile, 'file')
    delete(logFile);
end

logMessage(logFile, 'Using outputDir %s', outputDir);
logMessage(logFile, 'Using outputMat %s', outputMat);

logMessage(logFile, 'Loading %s', inputMat);
verifyGaussianHelpers(expectedGaussianFitFile, logFile);

logMessage(logFile, 'Using input MAT %s', inputMat);
S = load(inputMat);
RF_table = getTableFromMatStruct(S);
verifyEllipse68Fields(RF_table, inputMat);

if isempty(unitIndices)
    unitIndices = 1:height(RF_table);
end

nUnits = height(RF_table);
logMessage(logFile, 'Preparing to process %d units', numel(unitIndices));

RF_table.OldGaussianFitOK = false(nUnits, 1);
RF_table.OldGaussianStatus = repmat({''}, nUnits, 1);
RF_table.OldGaussianFitParams = cell(nUnits, 1);
RF_table.OldGaussianFitWithin = cell(nUnits, 1);
RF_table.OldGaussianCenter_pix = cell(nUnits, 1);
RF_table.OldGaussianEllipseX_pix = cell(nUnits, 1);
RF_table.OldGaussianEllipseY_pix = cell(nUnits, 1);
RF_table.OldGaussianCenter_deg = cell(nUnits, 1);
RF_table.OldGaussianEllipseX_deg = cell(nUnits, 1);
RF_table.OldGaussianEllipseY_deg = cell(nUnits, 1);
RF_table.OldGaussianCorr = nan(nUnits, 1);
RF_table.OldGaussianCorrP = nan(nUnits, 1);
RF_table.OldGaussianCenterInGrid = false(nUnits, 1);
RF_table.OldGaussianAccepted = false(nUnits, 1);

for idx = unitIndices
    disp(idx)
    try
        uniXPos = tableCell(RF_table.uniXPos, idx);
        uniYPos = tableCell(RF_table.uniYPos, idx);
        meanXYpos = tableCell(RF_table.meanXYpos, idx);
        rawRFmap = tableCell(RF_table.rawRFmap, idx);
        unitDate = [];
        if ismember('Date', RF_table.Properties.VariableNames)
            try
                unitDate = RF_table.Date(idx);
            catch
                unitDate = [];
            end
        end

        rawRFmap = ensureRFMapMatrix(rawRFmap, uniXPos, uniYPos);
        meanFRmap = buildMeanFRMap(RF_table, idx, rawRFmap, uniXPos, uniYPos);
        meanFRmapForFit = fillNanByNeighbors(meanFRmap);

        oldFit = fitOldGaussian(meanFRmapForFit, uniXPos, uniYPos, meanXYpos, unitDate, pix2deg, pix2mm, windowCenter, viewingDistance);
        RF_table.OldGaussianFitOK(idx) = oldFit.ok;
        RF_table.OldGaussianStatus{idx} = oldFit.status;
        RF_table.OldGaussianFitParams{idx} = oldFit.params;
        RF_table.OldGaussianFitWithin{idx} = oldFit.within;
        RF_table.OldGaussianCenter_pix{idx} = oldFit.center_pix;
        RF_table.OldGaussianEllipseX_pix{idx} = oldFit.x_pix;
        RF_table.OldGaussianEllipseY_pix{idx} = oldFit.y_pix;
        RF_table.OldGaussianCenter_deg{idx} = oldFit.center_deg;
        RF_table.OldGaussianEllipseX_deg{idx} = oldFit.x_deg;
        RF_table.OldGaussianEllipseY_deg{idx} = oldFit.y_deg;
        RF_table.OldGaussianCorr(idx) = oldFit.corr_r;
        RF_table.OldGaussianCorrP(idx) = oldFit.corr_p;
        RF_table.OldGaussianCenterInGrid(idx) = oldFit.center_in_grid;
        RF_table.OldGaussianAccepted(idx) = oldFit.accepted;

        if mod(idx, 25) == 0 || idx == unitIndices(end)
            logMessage(logFile, 'Finished %d/%d requested units', find(unitIndices == idx, 1, 'last'), numel(unitIndices));
        end
    catch ME
        RF_table.OldGaussianFitOK(idx) = false;
        RF_table.OldGaussianStatus{idx} = ['Failed: ', ME.message];
        warning('CompareLoRF_OldVsNewFits:UnitFailed', ...
            'Unit %d failed: %s', idx, ME.message);
        logMessage(logFile, 'Unit %d failed: %s', idx, ME.message);
    end
end

unit_table = RF_table;
save(outputMat, 'unit_table', 'RF_table', 'unitIndices', '-v7.3');
logMessage(logFile, 'Saved comparison table to %s', outputMat);

function meanFRmap = buildMeanFRMap(RF_table, idx, fallbackMap, uniXPos, uniYPos)
meanFRmap = fallbackMap;

if ~ismember('FRbyTrial', RF_table.Properties.VariableNames)
    return
end

FRbyTrial = tableCell(RF_table.FRbyTrial, idx);
if isempty(FRbyTrial) || ~iscell(FRbyTrial)
    return
end

meanFR = nan(size(FRbyTrial));
for iLoc = 1:numel(FRbyTrial)
    FRloc = FRbyTrial{iLoc};
    if isempty(FRloc)
        meanFR(iLoc) = NaN;
    else
        meanFR(iLoc) = mean(FRloc, 'omitnan');
    end
end

if numel(meanFR) == numel(uniXPos) * numel(uniYPos)
    meanFRmap = reshape(meanFR, numel(uniYPos), numel(uniXPos));
end
end

function oldFit = fitOldGaussian(rawRFmapForFit, uniXPos, uniYPos, meanXYpos, unitDate, pix2deg, pix2mm, windowCenter, viewingDistance)
oldFit = struct( ...
    'ok', false, ...
    'status', '', ...
    'params', [], ...
    'within', [], ...
    'center_pix', [], ...
    'x_pix', [], ...
    'y_pix', [], ...
    'center_deg', [], ...
    'x_deg', [], ...
    'y_deg', [], ...
    'corr_r', NaN, ...
    'corr_p', NaN, ...
    'center_in_grid', false, ...
    'accepted', false);

try
    legacyFit = fitVisualLatencyGaussian(rawRFmapForFit, uniXPos, uniYPos, meanXYpos, unitDate, pix2deg, pix2mm, windowCenter, viewingDistance);

    oldFit.ok = legacyFit.fitIdx == 1;
    oldFit.status = legacyFit.status;
    oldFit.params = legacyFit.params;
    oldFit.within = [];
    oldFit.center_pix = legacyFit.center_pix;
    oldFit.x_pix = legacyFit.x_pix;
    oldFit.y_pix = legacyFit.y_pix;
    oldFit.center_deg = legacyFit.center_deg;
    oldFit.x_deg = legacyFit.x_deg;
    oldFit.y_deg = legacyFit.y_deg;
    oldFit.corr_r = legacyFit.corr_r;
    oldFit.corr_p = legacyFit.corr_p;
    oldFit.center_in_grid = legacyFit.center_in_grid;
    oldFit.accepted = legacyFit.accepted;
    oldFit.ok = legacyFit.accepted;
catch ME
    oldFit.status = ['Gaussian failed: ', ME.message];
end
end

function legacyFit = fitVisualLatencyGaussian(rawRFmap, uniXPos, uniYPos, meanXYpos, unitDate, pix2deg, pix2mm, windowCenter, viewingDistance)
legacyFit = struct( ...
    'fitIdx', 0, ...
    'status', '', ...
    'params', [], ...
    'center_pix', [], ...
    'x_pix', [], ...
    'y_pix', [], ...
    'center_deg', [], ...
    'x_deg', [], ...
    'y_deg', [], ...
    'corr_r', NaN, ...
    'corr_p', NaN, ...
    'center_in_grid', false, ...
    'accepted', false);

[sizey, sizex] = size(rawRFmap);
[x, y] = meshgrid(1:sizex, 1:sizey);
xStep = uniXPos(2) - uniXPos(1);
yStep = uniYPos(2) - uniYPos(1);

gaussian2D = @(xv, yv, p) p(1) + p(2) .* exp(-(1/2) .* ...
    (p(3) .* (xv - p(6)) .^ 2 + p(4) .* (xv - p(6)) .* (yv - p(7)) + p(5) .* (yv - p(7)) .^ 2));

[cx, cy] = centerofmass(rawRFmap);
if isequalDatetime(unitDate, datetime('01-Apr-2023'))
    cx = 4; cy = 9;
elseif isequalDatetime(unitDate, datetime('08-Feb-2023'))
    cx = 3; cy = 10;
elseif isequalDatetime(unitDate, datetime('22-Apr-2023'))
    cx = 5; cy = 11;
end

DC_0 = mean(rawRFmap, "all", "omitnan");
p0 = [DC_0 1 1 0.5 1 cx cy];
lb = [0 0 0 -10 0 0 0];
ub = [200 100 10 10 10 30 30];
xy(:, :, 1) = x;
xy(:, :, 2) = y;
objective = @(p) sum((gaussian2D(xy(:, :, 1), xy(:, :, 2), p) - rawRFmap).^2, 'all', 'omitnan');
nonlcon = @(p) deal([ ...
    -p(3); ...                     % A > 0
    -p(5); ...                     % C > 0
    p(4)^2 - 4 * p(3) * p(5) + 1e-8 ... % B^2 < 4AC
    ], []);
opts = optimoptions(@fmincon, ...
    'Algorithm', 'interior-point', ...
    'MaxFunctionEvaluations', 1e6, ...
    'MaxIterations', 1e4, ...
    'OptimalityTolerance', 1e-10, ...
    'StepTolerance', 1e-10, ...
    'Display', 'off');
p_fit = fmincon(objective, p0, [], [], [], [], lb, ub, nonlcon, opts);

A = p_fit(3);
B = p_fit(4);
C = p_fit(5);
h = p_fit(6);
k = p_fit(7);

if ~(isfinite(A) && isfinite(B) && isfinite(C) && A > 0 && C > 0 && (B^2 < 4 * A * C))
    legacyFit.status = 'Rejected: quadratic form is not elliptical';
    legacyFit.params = p_fit;
    return
end

z_fit = gaussian2D(x, y, p_fit);
[r_new, p_new] = corr(reshape(rawRFmap, [], 1), reshape(z_fit, [], 1), 'Rows', 'complete');
legacyFit.corr_r = r_new;
legacyFit.corr_p = p_new;

center_pix = [(h - 1) .* xStep + uniXPos(1), (k - 1) .* yStep + uniYPos(1)];
xBounds = [min(uniXPos(:)), max(uniXPos(:))];
yBounds = [min(uniYPos(:)), max(uniYPos(:))];
center_in_grid = center_pix(1) >= xBounds(1) && center_pix(1) <= xBounds(2) && ...
    center_pix(2) >= yBounds(1) && center_pix(2) <= yBounds(2);
legacyFit.center_in_grid = center_in_grid;

if ~isfinite(r_new) || ~isfinite(p_new) || p_new >= 0.05
    legacyFit.status = sprintf('Rejected: corr p=%.3g, r=%.3f', p_new, r_new);
    legacyFit.params = p_fit;
    return
end
if ~center_in_grid
    legacyFit.status = sprintf('Rejected: center outside sampled grid, r=%.3f, p=%.3g', r_new, p_new);
    legacyFit.params = p_fit;
    return
end

x_curve = linspace(min(x, [], 'all'), max(x, [], 'all'), 10000);
discriminant = B^2 .* (x_curve - h) .^ 2 - 4 .* C .* (A .* (x_curve - h) .^ 2 - 1);
keep = discriminant >= 0 & isfinite(discriminant);
if ~any(keep)
    legacyFit.status = 'VisualLatency fit produced no ellipse curve';
    legacyFit.params = p_fit;
    return
end

x_curve = x_curve(keep);
y_curve_positive = (-B .* (x_curve - h) + sqrt(B^2 .* (x_curve - h) .^ 2 - 4 .* C .* (A .* (x_curve - h) .^ 2 - 1))) ./ (2 .* C) + k;
y_curve_negative = (-B .* (x_curve - h) - sqrt(B^2 .* (x_curve - h) .^ 2 - 4 .* C .* (A .* (x_curve - h) .^ 2 - 1))) ./ (2 .* C) + k;
x_curve_pix = (x_curve - 1) .* xStep + uniXPos(1);
y_curve_positive_pix = (y_curve_positive - 1) .* yStep + uniYPos(1);
y_curve_negative_pix = (y_curve_negative - 1) .* yStep + uniYPos(1);

legacyFit.fitIdx = 1;
legacyFit.accepted = true;
legacyFit.status = sprintf('OK: r=%.3f, p=%.3g', r_new, p_new);
legacyFit.params = p_fit;
legacyFit.center_pix = center_pix;
legacyFit.center_deg = [ ...
    round(atand(pix2mm(legacyFit.center_pix(1) - windowCenter(1)) ./ viewingDistance), 2), ...
    round(atand(pix2mm(windowCenter(2) - legacyFit.center_pix(2)) ./ viewingDistance), 2)];

curveXPix = [x_curve_pix, fliplr(x_curve_pix), x_curve_pix(1)];
curveYPix = [y_curve_positive_pix, fliplr(y_curve_negative_pix), y_curve_positive_pix(1)];
inside = curveXPix >= xBounds(1) & curveXPix <= xBounds(2) & ...
    curveYPix >= yBounds(1) & curveYPix <= yBounds(2);
legacyFit.x_pix = curveXPix(inside);
legacyFit.y_pix = curveYPix(inside);
if isempty(legacyFit.x_pix)
    legacyFit.accepted = false;
    legacyFit.fitIdx = 0;
    legacyFit.status = 'Rejected: ellipse outside sampled grid';
    return
end
legacyFit.x_deg = pix2deg(legacyFit.x_pix - windowCenter(1));
legacyFit.y_deg = pix2deg(windowCenter(2) - legacyFit.y_pix);
end

function tf = isequalDatetime(a, b)
tf = false;
if isempty(a) || ~isdatetime(a)
    return
end
tf = isequal(a, b);
end

function rawRFmap = ensureRFMapMatrix(rawRFmap, uniXPos, uniYPos)
if iscell(rawRFmap)
    rawRFmap = rawRFmap{1};
end
if isvector(rawRFmap) && numel(rawRFmap) == numel(uniXPos) * numel(uniYPos)
    rawRFmap = reshape(rawRFmap, numel(uniYPos), numel(uniXPos));
end
end

function Z = fillNanByNeighbors(rawRFmap)
Z = rawRFmap;
nanMask = isnan(Z);
if ~any(nanMask, 'all')
    return
end

validMask = ~nanMask;
Z0 = Z;
Z0(nanMask) = 0;
kernel = ones(3, 3);
neighborSum = conv2(Z0, kernel, 'same') - Z0;
neighborCount = conv2(double(validMask), kernel, 'same') - double(validMask);
neighborMean = neighborSum ./ neighborCount;
fillable = nanMask & neighborCount > 0;
Z(fillable) = neighborMean(fillable);
Z(isnan(Z)) = 0;
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

function verifyGaussianHelpers(expectedGaussianFitFile, logFile)
resolvedFitFile = which('Fit2DGaussian_Subplot');

if isempty(resolvedFitFile)
    error('Fit2DGaussian_Subplot.m is not on the MATLAB path.');
end

logMessage(logFile, 'Resolved Fit2DGaussian_Subplot to %s', resolvedFitFile);

if ~strcmpi(resolvedFitFile, expectedGaussianFitFile)
    error('Fit2DGaussian_Subplot resolved to the wrong file: %s', resolvedFitFile);
end
end

function verifyEllipse68Fields(RF_table, inputMat)
requiredVars = {'EllipseFit', 'Ellipse68Center_deg', 'Ellipse68X_deg', 'Ellipse68Y_deg'};
if ~all(ismember(requiredVars, RF_table.Properties.VariableNames))
    error(['Input table is missing 68%% ellipse fields. Re-run ', ...
        'FitLoRF_EllipseFromTempTable.m to populate Ellipse68* columns first. ', ...
        'Loaded file: %s'], inputMat);
end
end

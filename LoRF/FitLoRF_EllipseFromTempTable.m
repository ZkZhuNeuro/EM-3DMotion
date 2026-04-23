clear; clc;

%% Fit RF ellipses from an already-built LoRF unit table.
% This script is for quick iteration on a subset of units. It does not
% rerun waveform/event decoding and does not modify GetRFData_fromwfexp_LoData.

inputMat = 'C:\LoData\RF\unit_table_temp.mat';
outputMat = 'C:\LoData\RF\unit_table_temp_with_ellipse.mat';
plotDir = 'C:\LoData\RF\EllipseFitPreview';
logFile = 'C:\LoData\RF\FitLoRF_EllipseFromTempTable.log';

rfAnalysisPath = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\RF_analysis';
addpath(rfAnalysisPath);

maxUnitsToFit = [];       % Use [] to run all units after the script looks good.
unitIndices = [];        % Example: [1 5 12]. Leave [] to use 1:maxUnitsToFit.
makePreviewPlots = true;
runGaussianFit = false;  % Optional RF_analysis fmincon fit; slower and less stable.

alpha = 0.05;
ellipseConfidence = 0.90;
minClusterSize = 3;

windowWidth = 1920; %(pixels)
windowHeight = 1080; %(pixels)
viewingDistance = 570; %(mm)
ScreenWidth = 635; %(mm)
mm2deg = @(x) atand(x./viewingDistance);
pix2mm = @(x) x.*ScreenWidth./windowWidth;
pix2deg = @(x) mm2deg(pix2mm(x));
WindowCenter = [windowWidth/2, windowHeight/2];

if makePreviewPlots && ~exist(plotDir, 'dir')
    mkdir(plotDir);
end

if exist(logFile, 'file')
    delete(logFile);
end
logMessage(logFile, 'Starting LoRF ellipse fit from %s', inputMat);

S = load(inputMat);
RF_table = getTableFromMatStruct(S);

if isempty(unitIndices)
    if isempty(maxUnitsToFit)
        unitIndices = 1:height(RF_table);
    else
        unitIndices = 1:min(maxUnitsToFit, height(RF_table));
    end
end

RF_table.EllipseFit = false(height(RF_table), 1);
RF_table.EllipseStatus = repmat({''}, height(RF_table), 1);
RF_table.ThresholdMap = cell(height(RF_table), 1);
RF_table.CleanMask = cell(height(RF_table), 1);
RF_table.EllipseCenter_pix = cell(height(RF_table), 1);
RF_table.EllipseX_pix = cell(height(RF_table), 1);
RF_table.EllipseY_pix = cell(height(RF_table), 1);
RF_table.EllipseCenter_deg = cell(height(RF_table), 1);
RF_table.EllipseX_deg = cell(height(RF_table), 1);
RF_table.EllipseY_deg = cell(height(RF_table), 1);
RF_table.EllipseArea_deg2 = nan(height(RF_table), 1);
RF_table.GaussianFitParams = cell(height(RF_table), 1);
RF_table.GaussianFitWithin = cell(height(RF_table), 1);
RF_table.GaussianCenter_pix = cell(height(RF_table), 1);
RF_table.GaussianEllipseX_pix = cell(height(RF_table), 1);
RF_table.GaussianEllipseY_pix = cell(height(RF_table), 1);
RF_table.GaussianCenter_deg = cell(height(RF_table), 1);
RF_table.GaussianEllipseX_deg = cell(height(RF_table), 1);
RF_table.GaussianEllipseY_deg = cell(height(RF_table), 1);

for idx = unitIndices
    logMessage(logFile, 'Fitting RF ellipse for unit %d/%d', idx, height(RF_table));

    try
        rawRFmap = tableCell(RF_table.rawRFmap, idx);
        uniXPos = tableCell(RF_table.uniXPos, idx);
        uniYPos = tableCell(RF_table.uniYPos, idx);
        meanXYpos = tableCell(RF_table.meanXYpos, idx);

        rawRFmap = ensureRFMapMatrix(rawRFmap, uniXPos, uniYPos);
        rawRFmapFilled = fillNanByNeighbors(rawRFmap);

        [thresholdMap, meanFRThreshold] = thresholdRFByBaseline( ...
            RF_table, idx, rawRFmap, alpha);
        RF_table.ThresholdMap{idx} = thresholdMap;

        [cleanMask, status] = largestThresholdCluster(thresholdMap, minClusterSize);
        RF_table.CleanMask{idx} = cleanMask;
        RF_table.EllipseStatus{idx} = status;

        if any(cleanMask, 'all')
            ellipseFit = covarianceEllipseFromMask( ...
                cleanMask, meanXYpos, uniXPos, uniYPos, ellipseConfidence);

            RF_table.EllipseFit(idx) = true;
            RF_table.EllipseCenter_pix{idx} = ellipseFit.center_pix;
            RF_table.EllipseX_pix{idx} = ellipseFit.x_pix;
            RF_table.EllipseY_pix{idx} = ellipseFit.y_pix;

            xCenterDeg = pix2deg(ellipseFit.center_pix(1) - WindowCenter(1));
            yCenterDeg = pix2deg(WindowCenter(2) - ellipseFit.center_pix(2));
            xDeg = pix2deg(ellipseFit.x_pix - WindowCenter(1));
            yDeg = pix2deg(WindowCenter(2) - ellipseFit.y_pix);

            RF_table.EllipseCenter_deg{idx} = [xCenterDeg, yCenterDeg];
            RF_table.EllipseX_deg{idx} = xDeg;
            RF_table.EllipseY_deg{idx} = yDeg;
            RF_table.EllipseArea_deg2(idx) = polyarea(xDeg, yDeg);
        end

        if runGaussianFit
            try
                evalc('[p_fit, within] = Fit2DGaussian_RF(rawRFmapFilled, uniXPos, uniYPos, meanXYpos);');
                [x_center_pix, y_center_pix, x_pix, y_pix] = ...
                    DrawEllipseRF_fromGaussian2D(p_fit, rawRFmapFilled, RF_table, idx);

                RF_table.GaussianFitParams{idx} = p_fit;
                RF_table.GaussianFitWithin{idx} = within;
                RF_table.GaussianCenter_pix{idx} = [x_center_pix, y_center_pix];
                RF_table.GaussianEllipseX_pix{idx} = x_pix;
                RF_table.GaussianEllipseY_pix{idx} = y_pix;
                RF_table.GaussianCenter_deg{idx} = [ ...
                    pix2deg(x_center_pix - WindowCenter(1)), ...
                    pix2deg(WindowCenter(2) - y_center_pix)];
                RF_table.GaussianEllipseX_deg{idx} = pix2deg(x_pix - WindowCenter(1));
                RF_table.GaussianEllipseY_deg{idx} = pix2deg(WindowCenter(2) - y_pix);
            catch ME
                RF_table.EllipseStatus{idx} = [RF_table.EllipseStatus{idx}, ...
                    '; Gaussian failed: ', ME.message];
            end
        end

        if makePreviewPlots
            savePreviewPlot(RF_table, idx, rawRFmapFilled, cleanMask, plotDir);
        end

        logMessage(logFile, 'Unit %d status: %s', idx, RF_table.EllipseStatus{idx});
    catch ME
        RF_table.EllipseStatus{idx} = ['Failed: ', ME.message];
        logMessage(logFile, 'Unit %d failed: %s', idx, ME.message);
    end
end

unit_table = RF_table;
save(outputMat, 'unit_table', 'RF_table', 'unitIndices', '-v7.3');
logMessage(logFile, 'Saved fitted table to %s', outputMat);

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

function rawRFmap = ensureRFMapMatrix(rawRFmap, uniXPos, uniYPos)
if iscell(rawRFmap)
    rawRFmap = rawRFmap{1};
end
if isvector(rawRFmap) && numel(rawRFmap) == numel(uniXPos) * numel(uniYPos)
    rawRFmap = reshape(rawRFmap, numel(uniYPos), numel(uniXPos));
end
end

function [thresholdMap, meanFRThreshold] = thresholdRFByBaseline(RF_table, idx, rawRFmap, alpha)
if ~ismember('FRbyTrial', RF_table.Properties.VariableNames) || ...
        ~ismember('Baseline', RF_table.Properties.VariableNames)
    thresholdMap = rawRFmap;
    thresholdMap(isnan(thresholdMap)) = 0;
    thresholdMap = thresholdMap > mean(thresholdMap, 'all', 'omitnan');
    meanFRThreshold = thresholdMap(:);
    return
end

FRbyTrial = tableCell(RF_table.FRbyTrial, idx);
BaselineFR = tableCell(RF_table.Baseline, idx);

if isempty(FRbyTrial) || isempty(BaselineFR)
    thresholdMap = rawRFmap > mean(rawRFmap, 'all', 'omitnan');
    meanFRThreshold = thresholdMap(:);
    return
end

meanFRThreshold = nan(size(FRbyTrial));
for iLoc = 1:numel(FRbyTrial)
    FR_loc = FRbyTrial{iLoc};
    if isempty(FR_loc)
        meanFRThreshold(iLoc) = 0;
    else
        p_loc = ranksum(BaselineFR, FR_loc);
        if p_loc < alpha / numel(FRbyTrial)
            meanFRThreshold(iLoc) = mean(FR_loc, 'omitnan');
        else
            meanFRThreshold(iLoc) = 0;
        end
    end
end

thresholdMap = reshape(meanFRThreshold, size(rawRFmap));
thresholdMap(isnan(thresholdMap)) = 0;
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

function [cleanMask, status] = largestThresholdCluster(thresholdMap, minClusterSize)
binaryMap = thresholdMap > 0 & ~isnan(thresholdMap);
cleanMask = false(size(binaryMap));
status = 'No significant RF bins';

if ~any(binaryMap, 'all')
    return
end

CC = bwconncomp(binaryMap, 4);
clusterSizes = cellfun(@numel, CC.PixelIdxList);
keepIdx = find(clusterSizes >= minClusterSize);

if isempty(keepIdx)
    status = 'No cluster met minClusterSize';
    return
end

[~, maxI] = max(clusterSizes(keepIdx));
bestIdx = keepIdx(maxI);
cleanMask(CC.PixelIdxList{bestIdx}) = true;
status = 'OK';
end

function ellipseFit = covarianceEllipseFromMask(cleanMask, meanXYpos, uniXPos, uniYPos, confidence)
xVal = reshape(meanXYpos(:, 1), numel(uniYPos), numel(uniXPos));
yVal = reshape(meanXYpos(:, 2), numel(uniYPos), numel(uniXPos));

xPeak = sum(xVal(cleanMask)) / nnz(cleanMask);
yPeak = sum(yVal(cleanMask)) / nnz(cleanMask);

xy = [xVal(cleanMask) - xPeak, yVal(cleanMask) - yPeak];
if size(xy, 1) < 2
    error('Not enough RF bins in cluster to estimate covariance ellipse.');
end

scale = sqrt(chi2inv(confidence, 2));
Cov = cov(xy);
[eigenVectors, eigenValues] = eig(Cov);

radians = linspace(0, 2*pi, 100);
circle = [cos(radians); sin(radians)];
scaledEigenValues = sqrt(eigenValues) * scale;
ellipse = eigenVectors * scaledEigenValues * circle + [xPeak; yPeak];

ellipseFit.center_pix = [xPeak, yPeak];
ellipseFit.x_pix = ellipse(1, :);
ellipseFit.y_pix = ellipse(2, :);
end

function savePreviewPlot(RF_table, idx, rawRFmap, cleanMask, plotDir)
fig = figure('Visible', 'off');
imagesc(rawRFmap);
axis image;
colormap('parula');
colorbar;
hold on;

if any(cleanMask, 'all')
    contour(cleanMask, [1 1], 'w', 'LineWidth', 1.5);
end

if ~isempty(RF_table.GaussianFitWithin{idx})
    contour(RF_table.GaussianFitWithin{idx}, [1 1], 'k', 'LineWidth', 1.5);
end

title(sprintf('Unit %d RF ellipse fit', idx), 'Interpreter', 'none');
outName = fullfile(plotDir, sprintf('RF_EllipseFit_Unit%04d.png', idx));
print(fig, outName, '-dpng', '-painters', '-r200');
close(fig);
end

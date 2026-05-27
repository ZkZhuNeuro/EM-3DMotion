clear; clc;

%% Fit RF ellipses from the Clay LoRF unit table.
% This script mirrors the LoRF ellipse fitting workflow on the Clay output
% table. It does not rerun waveform/event decoding.

if ~exist('inputMat', 'var') || isempty(inputMat)
    inputMat = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\LoRF\LoRF_unit_table_clay.mat';
end
if ~exist('outputMat', 'var') || isempty(outputMat)
    outputMat = 'C:\LoData\RF\LoRF_unit_table_clay_with_ellipse.mat';
end
if ~exist('plotDir', 'var') || isempty(plotDir)
    plotDir = 'C:\LoData\RF\EllipseFitPreview_Clay';
end
if ~exist('logFile', 'var') || isempty(logFile)
    logFile = 'C:\LoData\RF\FitLoRF_EllipseFromClayTable.log';
end
if ~exist('paperTablePath', 'var') || isempty(paperTablePath)
    paperTablePath = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\LoRF\LoRFTable.mat';
end

rfAnalysisPath = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\RF_analysis';
addpath(rfAnalysisPath);

if ~exist('maxUnitsToFit', 'var')
    maxUnitsToFit = [];       % Use [] to run all units after the script looks good.
end
if ~exist('unitIndices', 'var')
    unitIndices = [];        % Example: [1 5 12]. Leave [] to use 1:maxUnitsToFit.
end
if ~exist('makePreviewPlots', 'var')
    makePreviewPlots = true;
end
if ~exist('runGaussianFit', 'var')
    runGaussianFit = false;  % Optional RF_analysis fmincon fit; slower and less stable.
end

alpha = 0.05;
ellipseConfidence68 = 0.68;
ellipseConfidence90 = 0.90;
minClusterSize = 3;
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

if makePreviewPlots && ~exist(plotDir, 'dir')
    mkdir(plotDir);
end

if exist(logFile, 'file')
    delete(logFile);
end
logMessage(logFile, 'Starting LoRF ellipse fit from %s', inputMat);

S = load(inputMat);
RF_table = getTableFromMatStruct(S);
paperFilter = loadPaperNeuronFilterFromStruct(paperTablePath, 'Clay');
paperMatchedRowIndices = findPaperMatchingUnits(RF_table, paperFilter, 'Clay');

logMessage(logFile, 'Paper-matched Clay units selected for fitting: %d/%d', ...
    numel(paperMatchedRowIndices), height(RF_table));
fprintf('Clay paper-matched units selected for fitting: %d/%d\n', ...
    numel(paperMatchedRowIndices), height(RF_table));

RF_table = RF_table(paperMatchedRowIndices, :);
sourceRowIndices = paperMatchedRowIndices;

if isempty(unitIndices)
    if isempty(maxUnitsToFit)
        unitIndices = 1:height(RF_table);
    else
        unitIndices = 1:min(maxUnitsToFit, height(RF_table));
    end
end
unitIndices = unitIndices(:)';

logMessage(logFile, 'Clay RF_table trimmed to %d paper-matched rows.', height(RF_table));
fprintf('Clay RF_table trimmed to %d paper-matched rows.\n', height(RF_table));

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
RF_table.Ellipse68Center_pix = cell(height(RF_table), 1);
RF_table.Ellipse68X_pix = cell(height(RF_table), 1);
RF_table.Ellipse68Y_pix = cell(height(RF_table), 1);
RF_table.Ellipse68Center_deg = cell(height(RF_table), 1);
RF_table.Ellipse68X_deg = cell(height(RF_table), 1);
RF_table.Ellipse68Y_deg = cell(height(RF_table), 1);
RF_table.Ellipse68Area_deg2 = nan(height(RF_table), 1);
RF_table.GaussianFitParams = cell(height(RF_table), 1);
RF_table.GaussianFitWithin = cell(height(RF_table), 1);
RF_table.GaussianCenter_pix = cell(height(RF_table), 1);
RF_table.GaussianEllipseX_pix = cell(height(RF_table), 1);
RF_table.GaussianEllipseY_pix = cell(height(RF_table), 1);
RF_table.GaussianCenter_deg = cell(height(RF_table), 1);
RF_table.GaussianEllipseX_deg = cell(height(RF_table), 1);
RF_table.GaussianEllipseY_deg = cell(height(RF_table), 1);

for iUnit = 1:numel(unitIndices)
    idx = unitIndices(iUnit);
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
            maskedFRmap = thresholdMap;
            maskedFRmap(~cleanMask) = 0;
            maskedFRmap(~isfinite(maskedFRmap)) = 0;
            ellipseFit90 = covarianceEllipseFromWeightedMap( ...
                maskedFRmap, meanXYpos, uniXPos, uniYPos, ellipseConfidence90, ...
                aspectRatioPenaltyStart, aspectRatioPenaltyWeight);
            ellipseFit68 = covarianceEllipseFromWeightedMap( ...
                maskedFRmap, meanXYpos, uniXPos, uniYPos, ellipseConfidence68, ...
                aspectRatioPenaltyStart, aspectRatioPenaltyWeight);

            RF_table.EllipseFit(idx) = true;
            RF_table.EllipseCenter_pix{idx} = ellipseFit90.center_pix;
            RF_table.EllipseX_pix{idx} = ellipseFit90.x_pix;
            RF_table.EllipseY_pix{idx} = ellipseFit90.y_pix;

            xCenterDeg = pix2deg(ellipseFit90.center_pix(1) - WindowCenter(1));
            yCenterDeg = pix2deg(WindowCenter(2) - ellipseFit90.center_pix(2));
            xDeg = pix2deg(ellipseFit90.x_pix - WindowCenter(1));
            yDeg = pix2deg(WindowCenter(2) - ellipseFit90.y_pix);

            RF_table.EllipseCenter_deg{idx} = [xCenterDeg, yCenterDeg];
            RF_table.EllipseX_deg{idx} = xDeg;
            RF_table.EllipseY_deg{idx} = yDeg;
            RF_table.EllipseArea_deg2(idx) = polyarea(xDeg, yDeg);

            xCenterDeg68 = pix2deg(ellipseFit68.center_pix(1) - WindowCenter(1));
            yCenterDeg68 = pix2deg(WindowCenter(2) - ellipseFit68.center_pix(2));
            xDeg68 = pix2deg(ellipseFit68.x_pix - WindowCenter(1));
            yDeg68 = pix2deg(WindowCenter(2) - ellipseFit68.y_pix);

            RF_table.Ellipse68Center_pix{idx} = ellipseFit68.center_pix;
            RF_table.Ellipse68X_pix{idx} = ellipseFit68.x_pix;
            RF_table.Ellipse68Y_pix{idx} = ellipseFit68.y_pix;
            RF_table.Ellipse68Center_deg{idx} = [xCenterDeg68, yCenterDeg68];
            RF_table.Ellipse68X_deg{idx} = xDeg68;
            RF_table.Ellipse68Y_deg{idx} = yDeg68;
            RF_table.Ellipse68Area_deg2(idx) = polyarea(xDeg68, yDeg68);
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
            savePreviewPlot(RF_table, idx, rawRFmapFilled, cleanMask, plotDir, WindowCenter, pix2deg);
        end

        logMessage(logFile, 'Unit %d status: %s', idx, RF_table.EllipseStatus{idx});
    catch ME
        RF_table.EllipseStatus{idx} = ['Failed: ', ME.message];
        logMessage(logFile, 'Unit %d failed: %s', idx, ME.message);
    end
end

unit_table = RF_table;
save(outputMat, 'unit_table', 'RF_table', 'unitIndices', 'sourceRowIndices', '-v7.3');
logMessage(logFile, 'Saved fitted table to %s', outputMat);
logMessage(logFile, 'Included Clay paper-matched units (before fit quality): %d', numel(unitIndices));
fprintf('Included Clay paper-matched units (before fit quality): %d\n', numel(unitIndices));

function logMessage(logFile, message, varargin)
fid = fopen(logFile, 'a');
if fid < 0
    return
end
fprintf(fid, [datestr(now, 'yyyy-mm-dd HH:MM:SS'), ' - ', message, '\n'], varargin{:});
fclose(fid);
end

function unitIndices = findPaperMatchingUnits(RF_table, paperFilter, monkeyName)
unitIndices = [];
for idx = 1:height(RF_table)
    if shouldKeepPaperNeuronStruct(paperFilter, RF_table, idx, monkeyName)
        unitIndices(end + 1, 1) = idx; %#ok<AGROW>
    end
end

if isempty(unitIndices)
    warning('No units matched the paper filter. Falling back to all rows.');
    unitIndices = (1:height(RF_table))';
end
end

function keep = shouldKeepPaperNeuronStruct(paperFilter, RF_table, idx, monkeyName)
if ~paperFilter.enabled
    keep = true;
    return
end

ttNum = getScalarFieldValue(RF_table, idx, {'TTNum', 'Tetrode'});
internalUnitID = getScalarFieldValue(RF_table, idx, {'InternalUnitID', 'i_unit', 'UnitIndex', 'UnitID'});
if ~isfinite(ttNum) || ~isfinite(internalUnitID)
    keep = false;
    return
end

dateKey = formatDateKey(tableCell(RF_table.Date, idx));
keyWithDate = canonicalNeuronKey(monkeyName, dateKey, ttNum, internalUnitID);
keep = ismember(keyWithDate, paperFilter.unitKeys);
end

function paperFilter = loadPaperNeuronFilterFromStruct(matPath, monkeyName)
paperFilter = struct('enabled', false, 'unitKeys', {{}});

if exist(matPath, 'file') ~= 2
    warning('Paper filter table was not found: %s', matPath);
    return
end

S = load(matPath);
if ~isfield(S, 'AllRFTable')
    warning('AllRFTable was not found in %s.', matPath);
    return
end

T = S.AllRFTable;
requiredFields = {'Date', 'ROI', 'Names', 'Tetrode', 'Unit'};
for iField = 1:numel(requiredFields)
    if ~hasNamedField(T, requiredFields{iField})
        warning('AllRFTable is missing field %s.', requiredFields{iField});
        return
    end
end

names = normalizeTextField(getNamedField(T, 'Names'));
roi = normalizeTextField(getNamedField(T, 'ROI'));
paperMonkey = lower(strtrim(monkeyName));
unitKeys = {};

for iRow = 1:numel(names)
    rowName = names(iRow);
    if ~startsWith(lower(strtrim(rowName)), extractBefore(paperMonkey, 2))
        continue
    end
    if ~strcmpi(strtrim(roi(iRow)), 'FST')
        continue
    end

    dateKey = formatDateKey(getIndexedFieldValue(T, 'Date', iRow));
    ttNum = getNumericElement(getNamedField(T, 'Tetrode'), iRow);
    paperUnitNum = getNumericElement(getNamedField(T, 'Unit'), iRow);
    internalUnitID = paperUnitNum - 1;
    if ~isfinite(ttNum) || ~isfinite(paperUnitNum) || ~isfinite(internalUnitID) || internalUnitID < 1
        continue
    end

    unitKeys{end + 1} = canonicalNeuronKey(monkeyName, dateKey, ttNum, internalUnitID); %#ok<AGROW>
end

paperFilter.enabled = true;
paperFilter.unitKeys = unique(unitKeys);
end

function key = canonicalNeuronKey(monkeyName, dateKey, ttNum, unitNum)
key = sprintf('%s|%s|tt%02d|unit%02d', lower(strtrim(monkeyName)), dateKey, ttNum, unitNum);
end

function tf = hasNamedField(T, fieldName)
if istable(T)
    tf = ismember(fieldName, T.Properties.VariableNames);
else
    tf = isfield(T, fieldName);
end
end

function value = getNamedField(T, fieldName)
if istable(T)
    value = T.(fieldName);
else
    value = T.(fieldName);
end
end

function value = getIndexedFieldValue(T, fieldName, idx)
fieldValue = getNamedField(T, fieldName);
if iscell(fieldValue)
    value = fieldValue{idx};
else
    value = fieldValue(idx, :);
end
end

function value = getScalarFieldValue(T, idx, candidateVars)
value = NaN;
for iVar = 1:numel(candidateVars)
    if ismember(candidateVars{iVar}, T.Properties.VariableNames)
        rawValue = tableCell(T.(candidateVars{iVar}), idx);
        value = scalarNumeric(rawValue);
        if isfinite(value)
            return
        end
    end
end
end

function value = getNumericElement(fieldValue, idx)
if iscell(fieldValue)
    rawValue = fieldValue{idx};
else
    rawValue = fieldValue(idx, :);
end
value = scalarNumeric(rawValue);
end

function value = scalarNumeric(rawValue)
value = NaN;
if iscell(rawValue)
    if isempty(rawValue)
        return
    end
    rawValue = rawValue{1};
end
if isnumeric(rawValue) && isscalar(rawValue) && isfinite(rawValue)
    value = double(rawValue);
elseif ischar(rawValue) || isstring(rawValue)
    parsedValue = str2double(string(rawValue));
    if isfinite(parsedValue)
        value = parsedValue;
    end
end
end

function out = normalizeTextField(value)
out = strings(numel(value), 1);
if iscell(value)
    for i = 1:numel(value)
        out(i) = stringifyScalar(value{i});
    end
else
    for i = 1:numel(value)
        out(i) = stringifyScalar(value(i));
    end
end
end

function s = stringifyScalar(value)
if isstring(value)
    if isscalar(value)
        s = value;
    else
        s = strjoin(value(:)', " ");
    end
    return
end
if ischar(value)
    s = string(value);
    return
end
if iscell(value)
    if isempty(value)
        s = "";
        return
    end
    parts = strings(numel(value), 1);
    for i = 1:numel(value)
        parts(i) = stringifyScalar(value{i});
    end
    s = strjoin(parts(parts ~= ""), " ");
    return
end
if isnumeric(value) || islogical(value)
    if isempty(value)
        s = "";
    elseif isscalar(value)
        s = string(value);
    else
        s = strjoin(string(value(:)'), " ");
    end
    return
end
try
    s = string(value);
catch
    s = strtrim(string(evalc('disp(value)')));
end
end

function dateKey = formatDateKey(dateValue)
dateKey = '';
try
    if iscell(dateValue)
        dateValue = dateValue{1};
    end
    if isdatetime(dateValue)
        dateKey = datestr(dateValue, 'yyyymmdd');
    elseif isnumeric(dateValue)
        dateKey = datestr(dateValue, 'yyyymmdd');
    else
        textValue = char(string(dateValue));
        if ~isempty(textValue)
            try
                dateKey = datestr(datetime(textValue), 'yyyymmdd');
            catch
                tok = regexp(textValue, '(\d{8})', 'tokens', 'once');
                if ~isempty(tok)
                    dateKey = tok{1};
                end
            end
        end
    end
catch
end
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
hasFRbyTrial = ismember('FRbyTrial', RF_table.Properties.VariableNames);
hasBaseline = ismember('Baseline', RF_table.Properties.VariableNames);

if ~hasFRbyTrial || ~hasBaseline
    thresholdMap = rawRFmap;
    thresholdMap(~isfinite(thresholdMap)) = 0;
    simpleThreshold = mean(rawRFmap, 'all', 'omitnan');

    if hasBaseline
        BaselineFR = tableCell(RF_table.Baseline, idx);
        meanBaselineFR = mean(BaselineFR, 'omitnan');
        if isfinite(meanBaselineFR)
            thresholdMap(thresholdMap <= meanBaselineFR) = 0;
        end
    end

    thresholdMap(thresholdMap <= simpleThreshold) = 0;
    meanFRThreshold = thresholdMap(:);
    return
end

FRbyTrial = tableCell(RF_table.FRbyTrial, idx);
BaselineFR = tableCell(RF_table.Baseline, idx);

if isempty(FRbyTrial) || isempty(BaselineFR)
    thresholdMap = rawRFmap;
    thresholdMap(~isfinite(thresholdMap)) = 0;
    simpleThreshold = mean(rawRFmap, 'all', 'omitnan');
    meanBaselineFR = mean(BaselineFR, 'omitnan');
    if isfinite(meanBaselineFR)
        thresholdMap(thresholdMap <= meanBaselineFR) = 0;
    end
    thresholdMap(thresholdMap <= simpleThreshold) = 0;
    meanFRThreshold = thresholdMap(:);
    return
end

nLoc = numel(FRbyTrial);
meanBaselineFR = mean(BaselineFR, 'omitnan');
pVals = nan(size(FRbyTrial));
meanFRThreshold = nan(size(FRbyTrial));
positiveEffect = false(size(FRbyTrial));

for iLoc = 1:nLoc
    FR_loc = FRbyTrial{iLoc};
    if isempty(FR_loc)
        meanFRThreshold(iLoc) = 0;
        pVals(iLoc) = NaN;
    else
        meanFR_loc = mean(FR_loc, 'omitnan');
        positiveEffect(iLoc) = isfinite(meanFR_loc) && isfinite(meanBaselineFR) && meanFR_loc > meanBaselineFR;
        pVals(iLoc) = ranksum(FR_loc, BaselineFR, 'tail', 'right');
        meanFRThreshold(iLoc) = meanFR_loc;
    end
end

passFdr = false(size(FRbyTrial));
validP = isfinite(pVals);
if any(validP)
    passFdr(validP) = benjaminiHochbergMask(pVals(validP), alpha);
end

keepMask = passFdr & positiveEffect;
meanFRThreshold(~keepMask) = 0;

thresholdMap = reshape(meanFRThreshold, size(rawRFmap));
thresholdMap(isnan(thresholdMap)) = 0;
end

function keep = benjaminiHochbergMask(pVals, alpha)
pVals = pVals(:);
keep = false(size(pVals));

[sortedP, sortIdx] = sort(pVals, 'ascend');
m = numel(sortedP);
thresholds = alpha * (1:m)' / m;
pass = sortedP <= thresholds;
if ~any(pass)
    return
end

maxIdx = find(pass, 1, 'last');
keep(sortIdx(1:maxIdx)) = true;
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

function ellipseFit = covarianceEllipseFromWeightedMap(weightMap, meanXYpos, uniXPos, uniYPos, confidence, aspectRatioPenaltyStart, aspectRatioPenaltyWeight)
xVal = reshape(meanXYpos(:, 1), numel(uniYPos), numel(uniXPos));
yVal = reshape(meanXYpos(:, 2), numel(uniYPos), numel(uniXPos));

validMask = isfinite(weightMap) & weightMap > 0;
if nnz(validMask) < 2
    error('Not enough RF bins in cluster to estimate weighted covariance ellipse.');
end

weights = weightMap(validMask);
totalWeight = sum(weights, 'omitnan');
if ~isfinite(totalWeight) || totalWeight <= 0
    error('RF weights within the retained cluster are not usable for ellipse fitting.');
end

x = xVal(validMask);
y = yVal(validMask);
normalizedWeights = weights(:) ./ totalWeight;

[peakRow, peakCol] = find(weightMap == max(weightMap(:)), 1, 'first');
cx0 = xVal(peakRow, peakCol);
cy0 = yVal(peakRow, peakCol);

[xWeightedMean, yWeightedMean, cov0] = weightedMoments(x, y, normalizedWeights);
[eigenVectors0, eigenValues0] = eig(cov0);
[sortedEigenValues, sortIdx] = sort(max(diag(eigenValues0), eps), 'descend');
eigenVectors0 = eigenVectors0(:, sortIdx);
theta0 = atan2(eigenVectors0(2, 1), eigenVectors0(1, 1));

xy0 = [x - xWeightedMean, y - yWeightedMean];
invCov0 = pinv(cov0);
d20 = sum((xy0 * invCov0) .* xy0, 2);
scale0 = sqrt(max(weightedQuantile(d20, normalizedWeights, confidence), eps));
a0 = max(sqrt(sortedEigenValues(1)) * scale0, 1);
b0 = max(sqrt(sortedEigenValues(2)) * scale0, 1);

spanX = max(x) - min(x);
spanY = max(y) - min(y);
spanArea = max(spanX * spanY, eps);

params0 = [cx0, cy0, log(a0), log(b0), theta0];
objective = @(params) ellipseCoverageObjective( ...
    params, x, y, normalizedWeights, confidence, spanArea, ...
    aspectRatioPenaltyStart, aspectRatioPenaltyWeight);
options = optimset('Display', 'off', 'MaxIter', 2000, 'MaxFunEvals', 4000);
paramsOpt = fminsearch(objective, params0, options);

[xPeak, yPeak, aOpt, bOpt, thetaOpt] = unpackEllipseParams(paramsOpt);
baseRadius2 = ellipseRadius2(x, y, xPeak, yPeak, aOpt, bOpt, thetaOpt);
finalScale = sqrt(max(weightedQuantile(baseRadius2, normalizedWeights, confidence), eps));
aFinal = aOpt * finalScale;
bFinal = bOpt * finalScale;

radians = linspace(0, 2*pi, 100);
ellipse = localEllipsePoints(xPeak, yPeak, aFinal, bFinal, thetaOpt, radians);

ellipseFit.center_pix = [xPeak, yPeak];
ellipseFit.x_pix = ellipse(1, :);
ellipseFit.y_pix = ellipse(2, :);
end

function objective = ellipseCoverageObjective(params, x, y, normalizedWeights, targetCoverage, spanArea, aspectRatioPenaltyStart, aspectRatioPenaltyWeight)
[cx, cy, a, b, theta] = unpackEllipseParams(params);
radius2 = ellipseRadius2(x, y, cx, cy, a, b, theta);
coverageRadius2 = max(weightedQuantile(radius2, normalizedWeights, targetCoverage), eps);
effectiveScale = sqrt(coverageRadius2);
effectiveA = a * effectiveScale;
effectiveB = b * effectiveScale;
areaNorm = (pi * effectiveA * effectiveB) / spanArea;
aspectRatio = max(a, b) / max(min(a, b), sqrt(eps));
aspectPenalty = aspectRatioPenaltyWeight * max(log(aspectRatio / aspectRatioPenaltyStart), 0).^2;
objective = areaNorm + aspectPenalty;
end

function [cx, cy, a, b, theta] = unpackEllipseParams(params)
cx = params(1);
cy = params(2);
a = max(exp(params(3)), sqrt(eps));
b = max(exp(params(4)), sqrt(eps));
theta = params(5);
end

function radius2 = ellipseRadius2(x, y, cx, cy, a, b, theta)
dx = x - cx;
dy = y - cy;
cosTheta = cos(theta);
sinTheta = sin(theta);
u = (cosTheta * dx + sinTheta * dy) ./ a;
v = (-sinTheta * dx + cosTheta * dy) ./ b;
radius2 = u.^2 + v.^2;
end

function ellipse = localEllipsePoints(cx, cy, a, b, theta, radians)
circleX = a * cos(radians);
circleY = b * sin(radians);
rotation = [cos(theta), -sin(theta); sin(theta), cos(theta)];
ellipse = rotation * [circleX; circleY] + [cx; cy];
end

function [xMean, yMean, Cov] = weightedMoments(x, y, normalizedWeights)
xMean = sum(normalizedWeights .* x, 'omitnan');
yMean = sum(normalizedWeights .* y, 'omitnan');
xy = [x - xMean, y - yMean];
Cov = xy' * (xy .* normalizedWeights);
Cov = (Cov + Cov.') / 2;

diagMean = mean(diag(Cov), 'omitnan');
if ~isfinite(diagMean) || diagMean <= 0
    diagMean = 1;
end
Cov = Cov + eye(2) * diagMean * 1e-6;
end

function q = weightedQuantile(values, weights, p)
values = values(:);
weights = weights(:);
validMask = isfinite(values) & isfinite(weights) & weights > 0;
values = values(validMask);
weights = weights(validMask);

if isempty(values)
    q = NaN;
    return
end

[sortedValues, sortIdx] = sort(values, 'ascend');
sortedWeights = weights(sortIdx);
cumulativeWeights = cumsum(sortedWeights) ./ sum(sortedWeights);
q = sortedValues(find(cumulativeWeights >= p, 1, 'first'));
end

function savePreviewPlot(RF_table, idx, rawRFmap, cleanMask, plotDir, WindowCenter, pix2deg)
fig = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters', ...
    'Position', [100 100 1800 520]);
uniXPos = tableCell(RF_table.uniXPos, idx);
uniYPos = tableCell(RF_table.uniYPos, idx);
xDegAxis = pix2deg(uniXPos(:)' - WindowCenter(1));
yDegAxis = pix2deg(WindowCenter(2) - uniYPos(:)');
[xDegSorted, xOrder] = sort(xDegAxis, 'ascend');
[yDegSorted, yOrder] = sort(yDegAxis, 'ascend');
xLimits = localAxisLimits(xDegSorted);
yLimits = localAxisLimits(yDegSorted);

thresholdMap = RF_table.ThresholdMap{idx};
if isempty(thresholdMap)
    thresholdPassMask = false(size(rawRFmap));
else
    thresholdPassMask = thresholdMap > 0 & ~isnan(thresholdMap);
end
rawRFmapPlot = rawRFmap(yOrder, xOrder);
excludedMask = (thresholdPassMask & ~cleanMask);
fitMask = cleanMask;
thresholdClassMap = zeros(size(rawRFmap), 'double');
thresholdClassMap(excludedMask) = 1;
thresholdClassMap(fitMask) = 2;
thresholdClassMapPlot = thresholdClassMap(yOrder, xOrder);

tileObj = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
imagesc(ax1, xDegSorted, yDegSorted, rawRFmapPlot);
set(ax1, 'YDir', 'normal');
axis(ax1, 'equal');
axis(ax1, 'tight');
colormap(ax1, 'parula');
colorbar(ax1);
hold(ax1, 'on');

if RF_table.EllipseFit(idx) && ~isempty(RF_table.EllipseX_deg{idx}) && ~isempty(RF_table.EllipseY_deg{idx})
    plot(ax1, RF_table.EllipseX_deg{idx}, RF_table.EllipseY_deg{idx}, ...
        'w-', 'LineWidth', 2);
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

if RF_table.EllipseFit(idx) && ~isempty(RF_table.Ellipse68X_deg{idx}) && ~isempty(RF_table.Ellipse68Y_deg{idx})
    plot(ax2, RF_table.Ellipse68X_deg{idx}, RF_table.Ellipse68Y_deg{idx}, ...
        'w-', 'LineWidth', 2);
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

sgtitle(tileObj, sprintf('Unit %d RF ellipse fit (%s)', idx, RF_table.EllipseStatus{idx}), ...
    'Interpreter', 'none');
outName = fullfile(plotDir, sprintf('RF_EllipseFit_Unit%04d.png', idx));
print(fig, outName, '-dpng', '-painters', '-r200');
close(fig);
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

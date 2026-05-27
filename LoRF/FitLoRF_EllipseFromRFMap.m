function fitResult = FitLoRF_EllipseFromRFMap(rawFR, xPos, yPos, baselineFR, varargin)
% FitLoRF_EllipseFromRFMap
% Fit an RF ellipse directly from sampled firing rates and XY positions.
%
% This function uses the same thresholding and fitting logic as
% FitLoRF_EllipseFromTempTable.m:
% 1) threshold each sampled location with one-sided ranksum against baseline,
% 2) require mean FR > mean baseline FR,
% 3) apply Benjamini-Hochberg FDR correction,
% 4) keep only the largest 4-connected cluster,
% 5) fit the weighted ellipse from the retained FR values.
%
% Inputs
%   rawFR      : RF map as either
%                - a 2D map [numel(yPos) x numel(xPos)], or
%                - a vector of sampled FR values
%   xPos       : x-axis vector, x sample vector, or x grid
%   yPos       : y-axis vector, y sample vector, or y grid
%   baselineFR : baseline FR values across trials (required)
%
% Name-value options
%   'FRbyTrial'                : trial-wise FR cell array, one location per cell
%   'ThresholdMap'             : precomputed threshold map to reuse directly
%   'confidence'               : ellipse coverage fraction (default 0.68)
%   'alpha'                    : FDR alpha (default 0.05)
%   'minClusterSize'           : minimum cluster size (default 3)
%   'aspectRatioPenaltyStart'  : penalty onset ratio (default 2.5)
%   'aspectRatioPenaltyWeight' : penalty weight (default 100)
%
% Notes
%   To match the TempTable thresholding exactly, provide FRbyTrial.
%   If FRbyTrial is omitted, you must provide ThresholdMap explicitly.

if nargin < 4
    error('baselineFR is a required input.');
end

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'FRbyTrial', [], @(x) isempty(x) || iscell(x));
addParameter(parser, 'ThresholdMap', [], @(x) isempty(x) || isnumeric(x));
addParameter(parser, 'confidence', 0.68, @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 1);
addParameter(parser, 'alpha', 0.05, @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 1);
addParameter(parser, 'minClusterSize', 3, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(parser, 'aspectRatioPenaltyStart', 2.5, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(parser, 'aspectRatioPenaltyWeight', 100, @(x) isnumeric(x) && isscalar(x) && x >= 0);
parse(parser, varargin{:});
opts = parser.Results;

[rawFRmap, xGrid, yGrid] = normalizeRFInputs(rawFR, xPos, yPos);
[thresholdMap, thresholdSource] = buildThresholdMap(rawFRmap, baselineFR, opts);
[cleanMask, status] = largestThresholdCluster(thresholdMap, opts.minClusterSize);

fitResult = struct( ...
    'fitOK', false, ...
    'status', status, ...
    'confidence', opts.confidence, ...
    'thresholdSource', thresholdSource, ...
    'rawFRmap', rawFRmap, ...
    'thresholdMap', thresholdMap, ...
    'cleanMask', cleanMask, ...
    'weightMap', zeros(size(rawFRmap)), ...
    'xGrid', xGrid, ...
    'yGrid', yGrid, ...
    'center', [NaN, NaN], ...
    'x', [], ...
    'y', [], ...
    'area', NaN);

if ~any(cleanMask, 'all')
    return
end

weightMap = thresholdMap;
weightMap(~cleanMask) = 0;
weightMap(~isfinite(weightMap)) = 0;

ellipseFit = fitEllipseFromWeightedMap( ...
    weightMap, xGrid, yGrid, opts.confidence, ...
    opts.aspectRatioPenaltyStart, opts.aspectRatioPenaltyWeight);

fitResult.fitOK = true;
fitResult.status = 'OK';
fitResult.weightMap = weightMap;
fitResult.center = ellipseFit.center;
fitResult.x = ellipseFit.x;
fitResult.y = ellipseFit.y;
fitResult.area = polyarea(ellipseFit.x, ellipseFit.y);
end

function [rawFRmap, xGrid, yGrid] = normalizeRFInputs(rawFR, xPos, yPos)
if iscell(rawFR)
    rawFR = rawFR{1};
end

if ismatrix(rawFR) && ~isvector(rawFR)
    [rawFRmap, xGrid, yGrid] = normalizeMatrixInputs(rawFR, xPos, yPos);
    return
end

if ~isvector(rawFR) || ~isvector(xPos) || ~isvector(yPos)
    error(['Inputs must be either: ', ...
        '(1) rawFR map + x-axis vector + y-axis vector, or ', ...
        '(2) rawFR vector + x sample vector + y sample vector.']);
end

rawFR = rawFR(:);
xPos = xPos(:);
yPos = yPos(:);
if numel(rawFR) ~= numel(xPos) || numel(rawFR) ~= numel(yPos)
    error('rawFR, xPos, and yPos vectors must have the same number of samples.');
end

[rawFRmap, xGrid, yGrid] = gridSampleVectors(rawFR, xPos, yPos);
end

function [rawFRmap, xGrid, yGrid] = normalizeMatrixInputs(rawFRmap, xPos, yPos)
mapSize = size(rawFRmap);

if isvector(xPos) && isvector(yPos)
    if numel(xPos) ~= mapSize(2) || numel(yPos) ~= mapSize(1)
        error('For RF-map input, xPos and yPos lengths must match rawFR dimensions.');
    end
    [xGrid, yGrid] = meshgrid(xPos(:)', yPos(:)');
    return
end

if isequal(size(xPos), mapSize) && isequal(size(yPos), mapSize)
    xGrid = xPos;
    yGrid = yPos;
    return
end

error(['For RF-map input, provide either axis vectors matching map size or ', ...
    'x/y grids with the same size as rawFR.']);
end

function [rawFRmap, xGrid, yGrid] = gridSampleVectors(rawFR, xPos, yPos)
xUnique = unique(xPos, 'sorted');
yUnique = unique(yPos, 'sorted');

if numel(xUnique) * numel(yUnique) ~= numel(rawFR)
    error(['Sample vectors do not form a complete rectangular grid. ', ...
        'Please supply rawFR as a 2D map with axis vectors, or full x/y grids.']);
end

rawFRmap = nan(numel(yUnique), numel(xUnique));
xGrid = repmat(xUnique(:)', numel(yUnique), 1);
yGrid = repmat(yUnique(:), 1, numel(xUnique));

for iSample = 1:numel(rawFR)
    xIdx = find(xUnique == xPos(iSample), 1, 'first');
    yIdx = find(yUnique == yPos(iSample), 1, 'first');
    if isempty(xIdx) || isempty(yIdx)
        error('Failed to map sample positions onto a rectangular grid.');
    end
    if isfinite(rawFRmap(yIdx, xIdx))
        error(['Duplicate x/y sample positions detected. ', ...
            'Please average duplicates before calling this function.']);
    end
    rawFRmap(yIdx, xIdx) = rawFR(iSample);
end
end

function [thresholdMap, thresholdSource] = buildThresholdMap(rawFRmap, baselineFR, opts)
if ~isempty(opts.ThresholdMap)
    thresholdMap = opts.ThresholdMap;
    if ~isequal(size(thresholdMap), size(rawFRmap))
        error('ThresholdMap must match the size of rawFRmap.');
    end
    thresholdMap(~isfinite(thresholdMap)) = 0;
    thresholdSource = 'Precomputed';
    return
end

if isempty(opts.FRbyTrial)
    error(['FRbyTrial is required to reproduce the TempTable thresholding. ', ...
        'If you already computed the thresholding, pass it as ''ThresholdMap''.']);
end

thresholdMap = thresholdRFByBaseline(rawFRmap, opts.FRbyTrial, baselineFR, opts.alpha);
thresholdSource = 'RanksumFDR';
end

function thresholdMap = thresholdRFByBaseline(rawRFmap, FRbyTrial, BaselineFR, alpha)
nLoc = numel(FRbyTrial);
if nLoc ~= numel(rawRFmap)
    error('FRbyTrial must have one entry per sampled RF location.');
end

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
thresholdMap(~isfinite(thresholdMap)) = 0;
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

maxI = find(pass, 1, 'last');
keep(sortIdx(1:maxI)) = true;
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

function ellipseFit = fitEllipseFromWeightedMap(weightMap, xGrid, yGrid, confidence, aspectRatioPenaltyStart, aspectRatioPenaltyWeight)
validMask = isfinite(weightMap) & weightMap > 0;
if nnz(validMask) < 2
    error('Not enough RF bins in cluster to estimate weighted ellipse.');
end

weights = weightMap(validMask);
totalWeight = sum(weights, 'omitnan');
if ~isfinite(totalWeight) || totalWeight <= 0
    error('RF weights within the retained cluster are not usable for ellipse fitting.');
end

x = xGrid(validMask);
y = yGrid(validMask);
normalizedWeights = weights(:) ./ totalWeight;

[peakRow, peakCol] = find(weightMap == max(weightMap(:)), 1, 'first');
cx0 = xGrid(peakRow, peakCol);
cy0 = yGrid(peakRow, peakCol);

[xWeightedMean, yWeightedMean, cov0] = weightedMoments(x, y, normalizedWeights);
[eigenVectors0, eigenValues0] = eig(cov0);
[sortedEigenValues, sortIdx] = sort(max(diag(eigenValues0), eps), 'descend');
eigenVectors0 = eigenVectors0(:, sortIdx);
theta0 = atan2(eigenVectors0(2, 1), eigenVectors0(1, 1));

xy0 = [x - xWeightedMean, y - yWeightedMean];
invCov0 = pinv(cov0);
d20 = sum((xy0 * invCov0) .* xy0, 2);
scale0 = sqrt(max(weightedQuantile(d20, normalizedWeights, confidence), eps));
spanX = max(x) - min(x);
spanY = max(y) - min(y);
defaultAxis = max([spanX, spanY, 1]) / 10;
defaultAxis = max(defaultAxis, sqrt(eps));
if numel(sortedEigenValues) < 2
    sortedEigenValues(2) = sortedEigenValues(1);
end
baseA = sqrt(max(sortedEigenValues(1), eps));
baseB = sqrt(max(sortedEigenValues(2), eps));
if ~isfinite(baseA) || baseA <= 0
    baseA = defaultAxis;
end
if ~isfinite(baseB) || baseB <= 0
    baseB = defaultAxis;
end
if ~isfinite(scale0) || scale0 <= 0
    scale0 = 1;
end

a0 = max(baseA * scale0, defaultAxis);
b0 = max(baseB * scale0, defaultAxis);

spanArea = max(spanX * spanY, eps);
params0 = [cx0, cy0, log(a0), log(b0), theta0];
objective = @(params) ellipseCoverageObjective( ...
    params, x, y, normalizedWeights, confidence, spanArea, ...
    aspectRatioPenaltyStart, aspectRatioPenaltyWeight);
options = optimset('Display', 'off', 'MaxIter', 2000, 'MaxFunEvals', 4000);
paramsOpt = fminsearch(objective, params0, options);

[cx, cy, aOpt, bOpt, thetaOpt] = unpackEllipseParams(paramsOpt);
baseRadius2 = ellipseRadius2(x, y, cx, cy, aOpt, bOpt, thetaOpt);
finalScale = sqrt(max(weightedQuantile(baseRadius2, normalizedWeights, confidence), eps));
aFinal = aOpt * finalScale;
bFinal = bOpt * finalScale;

radians = linspace(0, 2 * pi, 100);
ellipse = localEllipsePoints(cx, cy, aFinal, bFinal, thetaOpt, radians);

ellipseFit = struct( ...
    'center', [cx, cy], ...
    'x', ellipse(1, :), ...
    'y', ellipse(2, :));
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

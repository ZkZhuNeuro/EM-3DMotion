function summary = PlotClayMTFSTCoronalProjections(outputDir, guideDepth, maxDepth, xlsTables)
% Plot all Clay trajectories projected onto one representative MRI section per area.

if nargin < 1 || isempty(outputDir)
    outputDir = 'C:\EM\MRI\ClayMTFSTCoronalProjections';
end
if nargin < 2 || isempty(guideDepth)
    guideDepth = 10;
end
if nargin < 3 || isempty(maxDepth)
    maxDepth = 35;
end
if nargin < 4 || isempty(xlsTables)
    xlsTables = {
        'P:\Clay\NeuroData\RecordingRecord.xlsx'
        'P:\Clay\NeuroData\RecordingRecord_Stimulation.xlsx'
        };
end
if guideDepth >= maxDepth
    error('guideDepth must be smaller than maxDepth.');
end

% Clay MRI and ROI definitions from Clay_RecordingLocationTemplate.m.
originVoxel = [127, 208, 68];
imageFile = 'P:\MRI\R14008_GridScan\R14008_T1W_brain_Org2AvgGrid.nii.gz';
roiFile = 'P:\MRI\R14008_GridScan\R14008_LEV00_ROIs_org2Grid.nii.gz';
areas = struct( ...
    'name', {'MT', 'FST'}, ...
    'roiCode', {25, 24}, ...
    'color', {[0.850 0.325 0.098], [0.494 0.184 0.556]});

if ischar(xlsTables) || isstring(xlsTables)
    xlsTables = cellstr(string(xlsTables));
end
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

holes = [];
for tableIndex = 1:numel(xlsTables)
    holes = [holes; readHolePairs(xlsTables{tableIndex})]; %#ok<AGROW>
end
holes = unique(holes(holes(:, 1) > 0, :), 'rows');
holes = sortrows(holes, [2 1]);
if isempty(holes)
    error('No valid positive-X Clay holes were found in the supplied tables.');
end

structNii = load_nii(imageFile);
roiNii = load_nii(roiFile);
trajectoryX = holeToMlIndex(holes, originVoxel);
depthRange = depthToVoxel([guideDepth, maxDepth], originVoxel);

summary = table('Size', [numel(areas), 7], ...
    'VariableTypes', {'string', 'double', 'double', 'double', 'string', 'string', 'string'}, ...
    'VariableNames', {'Area', 'RoiCode', 'MriSliceIndex', 'TrajectoryCount', 'TrajectoryColor', 'FigureFile', 'SourceTables'});
sourceTableLabel = strjoin(string(xlsTables), ' | ');

for areaIndex = 1:numel(areas)
    area = areas(areaIndex);
    mriSliceIndex = findRepresentativeSlice(roiNii.img, area.roiCode);
    imageSlice = extractStructuralSlice(structNii.img, mriSliceIndex);
    roiSlice = extractRoiSlice(roiNii.img, mriSliceIndex);

    fig = figure('Color', 'w', 'Visible', 'off');
    imshow(imageSlice, 'InitialMagnification', 1000);
    hold on;

    targetRoi = roiSlice == area.roiCode;
    roiLayer = cat(3, ...
        ones(size(imageSlice)) * area.color(1), ...
        ones(size(imageSlice)) * area.color(2), ...
        ones(size(imageSlice)) * area.color(3));
    roiHandle = imshow(roiLayer, 'InitialMagnification', 500);
    set(roiHandle, 'AlphaData', 0.8 * targetRoi);
    legendMarker = plot(NaN, NaN, 's', ...
        'MarkerFaceColor', area.color, 'MarkerEdgeColor', area.color);

    for trajectoryIndex = 1:numel(trajectoryX)
        plot([trajectoryX(trajectoryIndex), trajectoryX(trajectoryIndex)], depthRange, ...
            '-', 'Color', area.color, 'LineWidth', 1.5);
    end

    [imageRows, imageColumns] = find(imageSlice ~= 255);
    xlim([min(imageColumns), 256 / 2]);
    ylim([min(imageRows), max(imageRows)]);
    legend(legendMarker, area.name, 'Location', 'southoutside');
    title(sprintf('Clay %s projection | MRI coronal index %d | %d trajectories | depth %.1f to %.1f', ...
        area.name, mriSliceIndex, numel(trajectoryX), guideDepth, maxDepth), 'FontSize', 12);
    hold off;

    figureFile = fullfile(outputDir, sprintf('Clay_%s_CoronalProjection.png', area.name));
    exportgraphics(fig, figureFile, 'Resolution', 300);
    close(fig);

    summary.Area(areaIndex) = string(area.name);
    summary.RoiCode(areaIndex) = area.roiCode;
    summary.MriSliceIndex(areaIndex) = mriSliceIndex;
    summary.TrajectoryCount(areaIndex) = numel(trajectoryX);
    summary.TrajectoryColor(areaIndex) = sprintf('RGB(%.3f, %.3f, %.3f)', area.color);
    summary.FigureFile(areaIndex) = string(figureFile);
    summary.SourceTables(areaIndex) = sourceTableLabel;
end

writetable(summary, fullfile(outputDir, 'Clay_MTFST_CoronalProjectionSummary.csv'));
end

function holes = readHolePairs(xlsTable)
raw = readcell(xlsTable);
header = matlab.lang.makeValidName(string(raw(1, :)));
holeColumn = find(header == "Hole", 1);
if isempty(holeColumn)
    error('Unable to locate a Hole column in %s.', xlsTable);
end

holeText = string(raw(2:end, holeColumn));
holes = nan(numel(holeText), 2);
for rowIndex = 1:numel(holeText)
    value = strtrim(holeText(rowIndex));
    if ismissing(value) || strlength(value) == 0 || strcmpi(value, "missing")
        continue
    end
    pair = str2num(char(value)); %#ok<ST2NM>
    if numel(pair) ~= 2
        error('Unexpected Hole entry in %s at row %d: %s', xlsTable, rowIndex + 1, value);
    end
    holes(rowIndex, :) = reshape(pair, 1, 2);
end
holes = holes(all(~isnan(holes), 2), :);
end

function sliceIndex = findRepresentativeSlice(roiVolume, roiCode)
roiCounts = squeeze(sum(sum(roiVolume == roiCode, 1), 2));
[maxCount, sliceIndex] = max(roiCounts);
if maxCount == 0
    error('ROI code %d is absent from the Clay atlas.', roiCode);
end
end

function mlIndex = holeToMlIndex(holes, originVoxel)
mlVoxel = nan(size(holes, 1), 1);
for holeIndex = 1:size(holes, 1)
    x = holes(holeIndex, 1);
    y = holes(holeIndex, 2);
    if y < 5 || y > 35
        error('Hole Y value %g is outside the supported range.', y);
    end
    if mod(y, 2) == 1
        edgeOffset = 1.4;
    else
        edgeOffset = 1.8;
    end
    mlVoxel(holeIndex) = originVoxel(1) - ((x - 1) * 0.8 + edgeOffset) * 2;
end
mlIndex = mlVoxel + 1;
end

function depthVoxel = depthToVoxel(depthMm, originVoxel)
depthVoxel = 256 - (originVoxel(2) - 2 * depthMm);
end

function sliceImage = extractStructuralSlice(volume, sliceIndex)
validateSliceIndex(volume, sliceIndex);
sliceImage = fliplr(imrotate(volume(:, :, sliceIndex), 90));
if ~isinteger(sliceImage)
    sliceImage = mat2gray(sliceImage);
end
sliceImage(sliceImage == 0) = 255;
end

function sliceRoi = extractRoiSlice(volume, sliceIndex)
validateSliceIndex(volume, sliceIndex);
sliceRoi = fliplr(imrotate(double(volume(:, :, sliceIndex)), 90));
end

function validateSliceIndex(volume, sliceIndex)
if sliceIndex < 1 || sliceIndex > size(volume, 3)
    error('Slice index %d is outside the MRI volume bounds.', sliceIndex);
end
end

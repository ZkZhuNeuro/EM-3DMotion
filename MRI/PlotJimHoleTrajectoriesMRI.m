function summary = PlotJimHoleTrajectoriesMRI(outputDir, guideDepth, maxDepth, xls_table)
% Plot all unique Jim recording holes as vertical MRI trajectories grouped by coronal slice.

if nargin < 1 || isempty(outputDir)
    outputDir = fullfile(pwd, 'JimHoleTrajectoryFigures');
end
if nargin < 2 || isempty(guideDepth)
    guideDepth = 25;
end
if nargin < 3 || isempty(maxDepth)
    maxDepth = 50;
end
if nargin < 4 || isempty(xls_table)
    xls_table = 'P:\Jim\NeuroData\RecordingRecord_MinusMissing.xlsx';
end
if guideDepth >= maxDepth
    error('guideDepth must be smaller than maxDepth.');
end

OrigPoint_Voxel = [127, 208, 68];
MasterPlotOptions

Img_nii_file = 'P:\MRI\R12059_GridScan\anaGrid\R12059_T1W_brain_Org2AvgGrid.nii.gz';
ROI_nii_file = 'P:\MRI\R12059_GridScan\anaGrid\R12059_allROIs_LVE00_Both_org2Grid_updated.nii.gz';
ROI_intensity = [51, 46, 28, 24];
ROI_labels = {'MSTd', 'MSTl', 'MT', 'FST'};
color_mat = [0 0.5 0.5; 1 1 0; plotOptions.AreaColors.MT; plotOptions.AreaColors.FST];

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

tb = loadRecordingTableLocal(xls_table);
holes = parseHoleColumn(tb.Hole);
holes = holes(holes(:, 1) > 0, :);
holes = unique(holes, 'rows');
holes = sortrows(holes, [2 1]);

if isempty(holes)
    error('No valid hole coordinates were found in %s.', xls_table);
end

AP_holes = unique(holes(:, 2));
guideVoxel = depthToVoxel(guideDepth, OrigPoint_Voxel);
maxVoxel = depthToVoxel(maxDepth, OrigPoint_Voxel);

structNii = load_nii(Img_nii_file);
roiNii = load_nii(ROI_nii_file);

summary = table('Size', [numel(AP_holes), 5], ...
    'VariableTypes', {'double', 'double', 'string', 'string', 'string'}, ...
    'VariableNames', {'Y', 'HoleCount', 'XHoles', 'FigureFile', 'SourceTable'});

for s = 1:numel(AP_holes)
    slice = AP_holes(s);
    sliceHoles = holes(holes(:, 2) == slice, :);
    mlIndex = holeToMlIndex(sliceHoles, OrigPoint_Voxel);
    apIndex = round(apHoleToIndex(slice, OrigPoint_Voxel));

    imageSlice = extractStructuralCoronalSlice(structNii.img, apIndex);
    roiSlice = extractRoiCoronalSlice(roiNii.img, apIndex);

    f = figure('Color', 'w', 'Visible', 'off');
    imshow(imageSlice, 'InitialMagnification', 1000);
    hold on;

    roiLegendPoints = gobjects(length(ROI_intensity), 1);
    for r = 1:length(ROI_intensity)
        sliceROI = roiSlice == ROI_intensity(r);
        colorLayer = cat(3, ...
            ones(size(imageSlice)) .* color_mat(r, 1), ...
            ones(size(imageSlice)) .* color_mat(r, 2), ...
            ones(size(imageSlice)) .* color_mat(r, 3));
        hRoi = imshow(colorLayer, 'InitialMagnification', 500);
        set(hRoi, 'AlphaData', 1 * sliceROI);
        roiLegendPoints(r) = plot(NaN, NaN, 's', ...
            'MarkerFaceColor', color_mat(r, :), ...
            'MarkerEdgeColor', color_mat(r, :));
    end

    for i = 1:numel(mlIndex)
        plot([mlIndex(i), mlIndex(i)], [guideVoxel, maxVoxel], ...
            'g-', 'LineWidth', 1.5);
    end

    [I, J] = find(imageSlice ~= 255);
    if all(sliceHoles(:, 1) < 0)
        xlim([256 / 2, max(J)]);
    elseif all(sliceHoles(:, 1) > 0)
        xlim([min(J), 256 / 2]);
    else
        xlim([min(J), max(J)]);
    end
    ylim([min(I), max(I)]);
    legend(roiLegendPoints, ROI_labels, 'Location', 'southoutside');
    title(sprintf('Jim MRI coronal slice Y = %d | %d trajectories | depth %.1f to %.1f', ...
        slice, size(sliceHoles, 1), guideDepth, maxDepth), 'FontSize', 12);
    hold off;

    outFile = fullfile(outputDir, sprintf('Jim_HoleTrajectories_Y%02d.png', slice));
    exportgraphics(f, outFile, 'Resolution', 300);
    close(f);

    summary.Y(s) = slice;
    summary.HoleCount(s) = size(sliceHoles, 1);
    summary.XHoles(s) = strjoin(string(sliceHoles(:, 1).'), ', ');
    summary.FigureFile(s) = string(outFile);
    summary.SourceTable(s) = string(xls_table);
end

writetable(summary, fullfile(outputDir, 'Jim_HoleTrajectorySummary.csv'));
end

function tb = loadRecordingTableLocal(xls_table)
try
    opts = detectImportOptions(xls_table, 'Sheet', 'Sheet1');
catch
    opts = detectImportOptions(xls_table);
end

opts.VariableNamesRange = 'A1';
opts.DataRange = 'A2';
tb = readtable(xls_table, opts);

if ~ismember("Hole", string(tb.Properties.VariableNames))
    raw = readcell(xls_table);
    header = raw(1, :);
    header = matlab.lang.makeValidName(string(header));
    if any(header == "Hole")
        data = raw(2:end, :);
        tb = cell2table(data, 'VariableNames', cellstr(header));
    else
        error('Unable to locate a Hole column in %s.', xls_table);
    end
end
end

function holes = parseHoleColumn(holeColumn)
holeStrings = string(holeColumn);
holes = nan(numel(holeStrings), 2);

for i = 1:numel(holeStrings)
    holeText = strtrim(holeStrings(i));
    if strlength(holeText) == 0 || strcmpi(holeText, "missing")
        continue
    end

    parsedHole = str2num(char(holeText)); %#ok<ST2NM>
    if numel(parsedHole) ~= 2
        error('Unexpected Hole entry at row %d: %s', i + 1, holeText);
    end
    holes(i, :) = reshape(parsedHole, 1, 2);
end

holes = holes(all(~isnan(holes), 2), :);
end

function apIndex = apHoleToIndex(apHole, originVoxel)
apVoxel = originVoxel(3) - ((29 - apHole) * 0.8) * 2;
apIndex = apVoxel + 1;
end

function mlIndex = holeToMlIndex(hole, originVoxel)
mlVoxel = nan(size(hole, 1), 1);
for i = 1:size(hole, 1)
    h = hole(i, :);
    if h(2) < 5 || h(2) > 35
        error('Hole Y value %g is outside the supported range.', h(2));
    end

    if mod(h(2), 2) == 1
        edgeOffset = 1.4;
    else
        edgeOffset = 1.8;
    end

    if h(1) > 0
        mlVoxel(i) = originVoxel(1) - ((h(1) - 1) * 0.8 + edgeOffset) * 2;
    else
        mlVoxel(i) = originVoxel(1) + ((abs(h(1)) - 1) * 0.8 + edgeOffset) * 2;
    end
end

mlIndex = mlVoxel + 1;
end

function depthVoxel = depthToVoxel(depthMm, originVoxel)
depthVoxel = 256 - (originVoxel(2) - 2 * depthMm);
end

function sliceImage = extractStructuralCoronalSlice(volume, apIndex)
validateSliceIndex(volume, apIndex);
sliceImage = volume(:, :, apIndex);
sliceImage = fliplr(imrotate(sliceImage, 90));

if ~isinteger(sliceImage)
    sliceImage = mat2gray(sliceImage);
end

sliceImage(sliceImage == 0) = 255;
end

function sliceRoi = extractRoiCoronalSlice(volume, apIndex)
validateSliceIndex(volume, apIndex);
sliceRoi = double(volume(:, :, apIndex));
sliceRoi = fliplr(imrotate(sliceRoi, 90));
end

function validateSliceIndex(volume, apIndex)
if apIndex < 1 || apIndex > size(volume, 3)
    error('Slice index %d is outside the MRI volume bounds.', apIndex);
end
end

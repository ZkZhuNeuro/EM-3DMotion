% Within the analysis-covered AP range, these slices maximize the pixel
% area of the corresponding MT (label 25) and FST (label 24) ROI masks.
clayCoronalTargetAPVoxels = [57, 66];
clayCoronalOutputDir = 'C:\EM\RecordingLocationPlots\Clay\SelectedCoronal';
clayCoronalDotColors = [0.00, 0.45, 0.95; 0.00, 0.70, 0.20];
clayCoronalDotSize = 32;
clayCoronalVectorROIs = true;
clayCoronalExportPDF = true;
clayCoronalFilenameSuffix = '_SelectedCoronal';
clayCoronalExportDimensionsPoints = [300, 400];
clayCoronalRasterDimensionsPixels = [1251, 1668];
run(fullfile(fileparts(mfilename('fullpath')), ...
    'generate_clay_projected_by_y.m'));

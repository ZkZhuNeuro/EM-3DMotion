generateSessionPlots = false;
generateCoronalPlots = true;
generateSagittalPlots = false;
jimSessionWorkbookRows = [];
jimCoronalAreas = ["MT", "FST"];
% Within the analysis-covered AP range, these slices maximize the pixel
% area of the corresponding MT (label 28) and FST (label 24) ROI masks.
jimCoronalTargetAPVoxels = [52, 65];
jimCoronalOutputDir = 'C:\EM\RecordingLocationPlots\Jim\SelectedCoronal';
jimCoronalDotColors = [0.00, 0.45, 0.95; 0.00, 0.70, 0.20];
jimCoronalDotSize = 32;
jimCoronalFourROIsOnly = true;
jimCoronalVectorROIs = true;
jimCoronalExportPDF = true;
jimCoronalFilenameSuffix = '_SelectedCoronal';
jimCoronalExportDimensionsPoints = [300, 400];
jimCoronalRasterDimensionsPixels = [1251, 1668];
run(fullfile(fileparts(mfilename('fullpath')), ...
    'generate_jim_recording_location_plots.m'));

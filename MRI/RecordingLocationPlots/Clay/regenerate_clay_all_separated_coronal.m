clayCoronalTargetAPVoxels = [];
clayCoronalOutputDir = 'C:\EM\RecordingLocationPlots\Clay\SeparatedCoronal';
clayCoronalDotColors = [0.00, 0.45, 0.95; 0.00, 0.70, 0.20];
clayCoronalDotSize = 32;
clayCoronalVectorROIs = true;
clayCoronalExportPDF = false;
clayCoronalCombinedPDF = fullfile(clayCoronalOutputDir, ...
    'Clay_AllSeparatedCoronalSections.pdf');
clayCoronalFilenameSuffix = '_SeparatedCoronal';
clayCoronalExportDimensionsPoints = [300, 400];
clayCoronalRasterDimensionsPixels = [1251, 1668];
run(fullfile(fileparts(mfilename('fullpath')), ...
    'generate_clay_projected_by_y.m'));

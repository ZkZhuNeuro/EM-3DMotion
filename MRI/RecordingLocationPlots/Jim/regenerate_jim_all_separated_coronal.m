generateSessionPlots = false;
generateCoronalPlots = true;
generateSagittalPlots = false;
jimSessionWorkbookRows = [];
jimCoronalAreas = ["MT", "FST"];
jimCoronalTargetAPVoxels = [];
jimCoronalOutputDir = 'C:\EM\RecordingLocationPlots\Jim\SeparatedCoronal';
jimCoronalDotColors = [0.00, 0.45, 0.95; 0.00, 0.70, 0.20];
jimCoronalDotSize = 32;
jimCoronalFourROIsOnly = true;
jimCoronalVectorROIs = true;
jimCoronalExportPDF = false;
jimCoronalCombinedPDF = fullfile(jimCoronalOutputDir, ...
    'Jim_AllSeparatedCoronalSections.pdf');
jimCoronalFilenameSuffix = '_SeparatedCoronal';
jimCoronalExportDimensionsPoints = [300, 400];
jimCoronalRasterDimensionsPixels = [1251, 1668];
run(fullfile(fileparts(mfilename('fullpath')), ...
    'generate_jim_recording_location_plots.m'));

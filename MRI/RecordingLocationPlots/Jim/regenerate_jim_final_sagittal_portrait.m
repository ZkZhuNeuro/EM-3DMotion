generateSessionPlots = false;
generateCoronalPlots = false;
generateSagittalPlots = true;
jimSessionWorkbookRows = [];
jimSagittalTargetMLVoxels = 162;
jimSagittalCropPadding = [4, 4];
jimSagittalCropSpan = [36, 48];
jimSagittalCropShift = [0, -4];
jimSagittalFilenameSuffix = '_Portrait3x4';
jimSagittalExportDimensionsPoints = [300, 400];
jimSagittalRasterDimensionsPixels = [1251, 1668];
jimSagittalExportSVG = false;
jimSagittalExportPDF = true;
run(fullfile(fileparts(mfilename('fullpath')), ...
    'generate_jim_recording_location_plots.m'));

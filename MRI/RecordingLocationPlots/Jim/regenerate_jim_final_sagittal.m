generateSessionPlots = false;
generateCoronalPlots = false;
generateSagittalPlots = true;
jimSessionWorkbookRows = [];
jimSagittalTargetMLVoxels = 162;
jimSagittalCropPadding = [4, 4];
jimSagittalCropSpan = [36, 36];
jimSagittalCropShift = [0, 0];
jimSagittalFilenameSuffix = '';
jimSagittalExportDimensionsPoints = [300, 320];
jimSagittalRasterDimensionsPixels = [1251, 1334];
jimSagittalExportSVG = false; % MATLAB SVG clips the embedded MRI in Illustrator.
jimSagittalExportPDF = true;
run(fullfile(fileparts(mfilename('fullpath')), ...
    'generate_jim_recording_location_plots.m'));

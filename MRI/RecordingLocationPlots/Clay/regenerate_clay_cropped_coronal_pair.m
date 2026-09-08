% Recreate the requested coronal panels with one common MRI-coordinate crop.
% MT uses AP voxel 56 and FST uses the user-selected AP voxel 62 slide.
clayCoronalTargetAPVoxels = [56, 62];
clayCoronalOutputDir = 'C:\EM\RecordingLocationPlots\Clay\CroppedCoronal';
clayCoronalDotColors = [0.00, 0.45, 0.95; 0.00, 0.70, 0.20];
clayCoronalDotSize = 32;
clayCoronalXLimits = [75, 114];
clayCoronalYLimits = [78, 136];
clayCoronalShowTitle = false;
clayCoronalVectorROIs = true;
clayCoronalExportPDF = true;
clayCoronalCombinedPDF = '';
clayCoronalFilenameSuffix = '_Cropped';
clayCoronalExportDimensionsPoints = [300, 400];
clayCoronalRasterDimensionsPixels = [];
run(fullfile(fileparts(mfilename('fullpath')), ...
    'generate_clay_projected_by_y.m'));

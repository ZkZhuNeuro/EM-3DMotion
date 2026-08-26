claySagittalTargetMLVoxels = 165;
claySagittalCropPadding = [4, 4];
claySagittalCropSpan = [36, 48];
claySagittalCropShift = [0, -4];
claySagittalFilenameSuffix = '_Portrait3x4';
claySagittalExportDimensionsPoints = [300, 400];
claySagittalRasterDimensionsPixels = [1251, 1668];
claySagittalExportSVG = false;
claySagittalExportPDF = true;
run(fullfile(fileparts(mfilename('fullpath')), ...
    'generate_clay_projected_sagittal.m'));

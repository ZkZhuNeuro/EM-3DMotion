claySagittalTargetMLVoxels = 165;
claySagittalCropPadding = [4, 4];
claySagittalCropSpan = [36, 36];
claySagittalCropShift = [0, 0];
claySagittalFilenameSuffix = '';
claySagittalExportDimensionsPoints = [300, 320];
claySagittalRasterDimensionsPixels = [1251, 1334];
claySagittalExportSVG = false; % MATLAB SVG clips the embedded MRI in Illustrator.
claySagittalExportPDF = true;
run(fullfile(fileparts(mfilename('fullpath')), ...
    'generate_clay_projected_sagittal.m'));

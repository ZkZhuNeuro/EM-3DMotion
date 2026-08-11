function results = optimize_jim_mtfst_oblique_section(output_dir)
%OPTIMIZE_JIM_MTFST_OBLIQUE_SECTION Configure the shared optimizer for Jim.
%
% Jim's recordings are in the left hemisphere, so this workflow deliberately
% uses the dedicated left-only ROI atlas rather than the bilateral atlas used
% by the coronal recording-location plots.

if nargin < 1 || isempty(output_dir)
    output_dir = 'C:\EM\RecordingLocationPlots\Jim\OptimizedOblique';
end

this_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(fileparts(this_dir), 'common'));

cfg = struct();
cfg.outputDirectory = output_dir;
cfg.monkeyName = 'Jim';
cfg.filePrefix = 'Jim_MT-FST';
cfg.workbookPath = ...
    'P:\Jim\NeuroData\RecordingRecord_Stimulation_final.xlsx';
cfg.structuralPath = ...
    'P:\MRI\R12059_GridScan\anaGrid\R12059_T1W_brain_Org2AvgGrid.nii.gz';
cfg.atlasPath = ...
    ['P:\MRI\R12059_GridScan\anaGrid\' ...
    'R12059_allROIs_LVE00_Left_org2Grid_updated.nii.gz'];
cfg.originVoxelZeroBased = [127, 208, 68];
cfg.nativeFirstDimension = 256;
cfg.uprightReferencePlaneNormal = [1, 0, 0]; % Native midsagittal plane.
cfg.recordingHemisphere = 'L';
cfg.mtAtlasLabel = 28;
cfg.fstAtlasLabel = 24;
cfg.expectedSessionCount = 149;
cfg.expectedMtCount = 54;
cfg.expectedFstCount = 95;
% Jim's occupied MRI ML voxels are 156:168 (zero-based). Use their central
% slice for the fixed sagittal comparison; translated-sagittal search bounds
% are derived from the continuous included recording coordinates.
cfg.currentSagittalIndex = 163; % One-based index = MRI ML voxel 162.

cfg.mtColor = [226, 100, 0] ./ 255;
cfg.fstColor = [135, 2, 214] ./ 255;
cfg.maxProjectionDistanceMm = 2.5;
cfg.sliceSpacingVox = 0.25;
cfg.roiAlpha = 0.34;
cfg.slabHalfThicknessMm = 1.0;
cfg.outputResolution = 600;
cfg.voxelSizeMm = 0.5;

results = optimize_mtfst_oblique_section(cfg);
end

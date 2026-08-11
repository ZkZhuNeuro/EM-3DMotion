function results = optimize_clay_mtfst_oblique_section(output_dir)
%OPTIMIZE_CLAY_MTFST_OBLIQUE_SECTION Configure the shared optimizer for Clay.
%
% Clay's MT/FST atlas and recordings are in the left hemisphere. Declaring
% that convention keeps the locator line on the recording side and displays
% anatomical left on the left of the horizontal locator.

if nargin < 1 || isempty(output_dir)
    output_dir = 'C:\EM\RecordingLocationPlots\Clay\OptimizedOblique';
end

this_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(fileparts(this_dir), 'common'));

cfg = struct();
cfg.outputDirectory = output_dir;
cfg.monkeyName = 'Clay';
cfg.filePrefix = 'Clay_MT-FST';
cfg.workbookPath = 'P:\Clay\NeuroData\RecordingRecord_Stimulation.xlsx';
cfg.structuralPath = ...
    'P:\MRI\R14008_GridScan\R14008_T1W_brain_Org2AvgGrid.nii.gz';
cfg.atlasPath = ...
    'P:\MRI\R14008_GridScan\R14008_LEV00_ROIs_org2Grid.nii.gz';
cfg.originVoxelZeroBased = [127, 208, 68];
cfg.nativeFirstDimension = 256;
cfg.uprightReferencePlaneNormal = [1, 0, 0]; % Native midsagittal plane.
cfg.recordingHemisphere = 'L';
cfg.mtAtlasLabel = 25;
cfg.fstAtlasLabel = 24;
cfg.expectedSessionCount = 102;
cfg.expectedMtCount = 40;
cfg.expectedFstCount = 62;
cfg.currentSagittalIndex = 165; % One-based index = MRI ML voxel 164.

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

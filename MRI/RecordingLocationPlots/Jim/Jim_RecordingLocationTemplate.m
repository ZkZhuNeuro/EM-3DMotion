addpath(fileparts(fileparts(fileparts(mfilename('fullpath')))));
OrigPoint_Voxel = [127, 208, 68];
MasterPlotOptions
Img_nii = 'P:\MRI\R12059_GridScan\anaGrid\R12059_T1W_brain_Org2AvgGrid.nii.gz'; %uigetfile({'*.*'},'Select a structural image');
% LVE
ROI_nii_file = 'P:\MRI\R12059_GridScan\anaGrid\R12059_allROIs_LVE00_Both_org2Grid_updated.nii.gz'; %uigetfile({'*.*'},'Select an ROI image file');
ROI_intensity = [51, 46, 28, 24, 69, 57]; % Left: MSTda, MSTm, MT, FST, MSTdp, V3A
% FVE
% ROI_nii_file = 'P:\MRI\R12059_GridScan\anaGrid\R12059_allROIs_FVE91_Right_org2Grid_updated.nii.gz';
% ROI_intensity = [107,77,68,47];

color_mat = [0 0.5 0.5; 1 1 0; plotOptions.AreaColors.MT; plotOptions.AreaColors.FST; 0.75 0.5 0.25; 0.75 0.5 0.25]; % Right
% color_mat = [0 0.5 0.5; 1 1 0; 0 0 0; 1 1 1; 1 0 0; 0 1 0]; % Red, green for V3A, CIP - NS
intensity_labels = [];
hole = [21, 21];
guide = 25.0;
PlotRecordingLocationMRI(OrigPoint_Voxel, Img_nii, ROI_nii_file, hole, guide, 1, ROI_intensity, color_mat, intensity_labels)

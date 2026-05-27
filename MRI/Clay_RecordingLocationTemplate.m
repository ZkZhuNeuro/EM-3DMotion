OrigPoint_Voxel = [127, 208, 68];
MasterPlotOptions
% Img_nii = 'P:\MRI\R12059_GridScan\anaGrid\R12059_T1W_brain_Org2AvgGrid.nii.gz'; %uigetfile({'*.*'},'Select a structural image');
Img_nii = 'P:\MRI\R14008_GridScan\R14008_T1W_brain_Org2AvgGrid.nii.gz'; %uigetfile({'*.*'},'Select a structural image');
% LVE
% ROI_nii_file = 'P:\MRI\R12059_GridScan\anaGrid\R12059_allROIs_LVE00_Both_org2Grid_updated.nii.gz'; %uigetfile({'*.*'},'Select an ROI image file');
ROI_nii_file = 'P:\MRI\R14008_GridScan\R14008_LEV00_ROIs_org2Grid.nii.gz'; %uigetfile({'*.*'},'Select an ROI image file');

ROI_intensity = [46,38,25,24]; % Left hemisphere ROI: 46-MSTd, 38-MSTl, 25-MT, 24-FST
% FVE
% ROI_nii_file = 'P:\MRI\R12059_GridScan\anaGrid\R12059_allROIs_FVE91_Right_org2Grid_updated.nii.gz';
% ROI_intensity = [107,77,68,176];

color_mat = [0 0.5 0.5; 1 1 0; plotOptions.AreaColors.MT; plotOptions.AreaColors.FST; 0.75 0.5 0.25; 0.75 0.5 0.25;]; % Right
intensity_labels = [];
hole = [23,27];
guide = 23;
PlotRecordingLocationMRI(OrigPoint_Voxel, Img_nii, ROI_nii_file, hole, guide, 1, ROI_intensity, color_mat, intensity_labels)
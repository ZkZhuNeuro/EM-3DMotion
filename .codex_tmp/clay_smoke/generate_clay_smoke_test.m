% Smoke test generated from Clay_RecordingLocationTemplate.m and
% RecordingRecord_Stimulation.xlsx, Sheet1 row 2 (2024-07-09).

output_dir = 'C:\EM\RecordingLocationPlots\Clay';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
addpath('P:\MRI\Grid_Mapping');

OrigPoint_Voxel = [127, 208, 68];
MasterPlotOptions
Img_nii = 'P:\MRI\R14008_GridScan\R14008_T1W_brain_Org2AvgGrid.nii.gz';
ROI_nii_file = 'P:\MRI\R14008_GridScan\R14008_LEV00_ROIs_org2Grid.nii.gz';

ROI_intensity = [46, 38, 25, 24];
color_mat = [0 0.5 0.5; 1 1 0; plotOptions.AreaColors.MT; ...
    plotOptions.AreaColors.FST; 0.75 0.5 0.25; 0.75 0.5 0.25];
intensity_labels = [];

session_date = datetime(2024, 7, 9);
hole = [24, 22];
guide_tube_mm = 23;
recording_depth_mm = 12;
total_depth_mm = guide_tube_mm + recording_depth_mm;
tetrode = 1;

set(groot, 'defaultFigureVisible', 'off');
fig = figure('Visible', 'off');
PlotRecordingLocationMRI(OrigPoint_Voxel, Img_nii, ROI_nii_file, hole, ...
    total_depth_mm, tetrode, ROI_intensity, color_mat, intensity_labels, ...
    fig, [0, 0, 0]);

fig.Color = 'w';
fig.Position = [100, 100, 1000, 800];
title(gca, sprintf(['Clay %s | Hole <%d,%d> | Guide %.1f mm + ' ...
    'Depth %.1f mm'], string(session_date, 'yyyy-MM-dd'), hole(1), hole(2), ...
    guide_tube_mm, recording_depth_mm), 'FontSize', 12, 'Interpreter', 'none');

output_file = fullfile(output_dir, 'Clay_2024-07-09_Hole_24-22.png');
exportgraphics(fig, output_file, 'Resolution', 300);
close(fig);
fprintf('Saved smoke-test plot: %s\n', output_file);

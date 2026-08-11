addpath('P:\MRI\Grid_Mapping');

structPath = 'P:\MRI\R12059_GridScan\anaGrid\R12059_T1W_brain_Org2AvgGrid.nii.gz';
leftRoiPath = 'P:\MRI\R12059_GridScan\anaGrid\R12059_allROIs_LVE00_Left_org2Grid_updated.nii.gz';
rightRoiPath = 'P:\MRI\R12059_GridScan\anaGrid\R12059_allROIs_LVE00_Right_org2Grid_updated.nii.gz';

structVolume = load_nii(structPath).img;
leftRoi = load_nii(leftRoiPath).img;
rightRoi = load_nii(rightRoiPath).img;
assert(isequal(size(structVolume), size(leftRoi), size(rightRoi)), ...
    'Jim structural and hemisphere-specific ROI volumes must share one voxel grid.');

displayMlVoxels = 87:99;
directIndices = displayMlVoxels + 1;
mirroredMlVoxels = (size(structVolume, 1) - 1) - displayMlVoxels;
mirroredIndices = mirroredMlVoxels + 1;

directLeft = nnz(leftRoi(directIndices, :, :));
directRight = nnz(rightRoi(directIndices, :, :));
mirroredLeft = nnz(leftRoi(mirroredIndices, :, :));
mirroredRight = nnz(rightRoi(mirroredIndices, :, :));

reportPath = fullfile(fileparts(mfilename('fullpath')), ...
    'jim_sagittal_hemisphere_audit.txt');
fid = fopen(reportPath, 'w');
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, 'DISPLAY_ML_VOXELS=%s\n', mat2str(displayMlVoxels));
fprintf(fid, 'MIRRORED_MRI_ML_VOXELS=%s\n', mat2str(mirroredMlVoxels));
fprintf(fid, 'DIRECT_LEFT_ROI_VOXELS=%d\n', directLeft);
fprintf(fid, 'DIRECT_RIGHT_ROI_VOXELS=%d\n', directRight);
fprintf(fid, 'MIRRORED_LEFT_ROI_VOXELS=%d\n', mirroredLeft);
fprintf(fid, 'MIRRORED_RIGHT_ROI_VOXELS=%d\n', mirroredRight);

assert(mirroredLeft > 0 && mirroredRight == 0, ...
    'Mirrored Jim sagittal slices did not isolate the left ROI volume.');
assert(directRight > 0 && directLeft == 0, ...
    'Direct Jim sagittal slices did not isolate the right ROI volume as expected.');

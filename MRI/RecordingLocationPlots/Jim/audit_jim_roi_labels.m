addpath('P:\MRI\Grid_Mapping');

atlasPath = 'P:\MRI\R12059_GridScan\anaGrid\R12059_allROIs_LVE00_Both_org2Grid_updated.nii.gz';
roiDir = 'P:\MRI\R12059_GridScan\anaGrid\LT_ROIs';
atlas = double(load_nii(atlasPath).img);
roiFiles = {
    'MSTda_L', 'R12059_MSTda_LVE00_Left_org2Grid_updated.nii.gz';
    'MSTdp_L', 'R12059_MSTdp_LVE00_Left_org2Grid_updated.nii.gz';
    'MSTm_L',  'R12059_MSTm_LVE00_Left_org2Grid_updated.nii.gz';
    'MT_L',    'R12059_MT_LVE00_Left_org2Grid_updated.nii.gz';
    'MSTda_R', 'R12059_MSTda_LVE00_Right_org2Grid_updated.nii.gz';
    'MSTdp_R', 'R12059_MSTdp_LVE00_Right_org2Grid_updated.nii.gz';
    'MSTm_R',  'R12059_MSTm_LVE00_Right_org2Grid_updated.nii.gz';
    'MT_R',    'R12059_MT_LVE00_Right_org2Grid_updated.nii.gz'};

outPath = fullfile(fileparts(mfilename('fullpath')), 'jim_roi_label_audit.txt');
fid = fopen(outPath, 'w');
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, 'ATLAS=%s\n', atlasPath);
fprintf(fid, 'ATLAS_VALUES=%s\n', mat2str(unique(atlas(:)).'));
targetValues = [24, 28, 46, 51, 57, 60, 69];
for value = targetValues
    [x, y, z] = ind2sub(size(atlas), find(atlas == value));
    fprintf(fid, 'LABEL=%d|VOXELS=%d|X=%d:%d|Y=%d:%d|Z=%d:%d\n', ...
        value, numel(x), min(x), max(x), min(y), max(y), min(z), max(z));
end
for i = 1:size(roiFiles, 1)
    label = roiFiles{i, 1};
    roiPath = fullfile(roiDir, roiFiles{i, 2});
    roi = double(load_nii(roiPath).img);
    mask = roi ~= 0;
    roiValues = unique(roi(mask));
    atlasValues = atlas(mask);
    atlasValues = atlasValues(atlasValues ~= 0);
    [values, ~, groups] = unique(atlasValues);
    counts = accumarray(groups, 1);
    [counts, order] = sort(counts, 'descend');
    values = values(order);
    fprintf(fid, '%s|ROI_NONZERO_VALUES=%s|MASK_VOXELS=%d|ATLAS_OVERLAP=', ...
        label, mat2str(roiValues.'), nnz(mask));
    for j = 1:min(numel(values), 12)
        fprintf(fid, '%g:%d', values(j), counts(j));
        if j < min(numel(values), 12), fprintf(fid, ','); end
    end
    fprintf(fid, '\n');
end

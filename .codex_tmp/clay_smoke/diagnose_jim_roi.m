addpath('P:\MRI\Grid_Mapping');
roi_file = 'P:\MRI\R12059_GridScan\anaGrid\R12059_allROIs_FVE91_Right_org2Grid_updated.nii.gz';
roi_nii = load_nii(roi_file);
roi_values = [107, 77, 68, 47];

coronal = nan(19, 6);
for ap_voxel = 50:68
    roi_slice = double(roi_nii.img(:, :, ap_voxel + 1));
    roi_slice = fliplr(imrotate(roi_slice, 90));
    roi_slice = circshift(roi_slice, 1, 2);
    mask = ismember(roi_slice, roi_values);
    [rows, cols] = find(mask);
    if isempty(cols)
        bounds = [NaN, NaN, NaN, NaN];
    else
        bounds = [min(cols), max(cols), min(rows), max(rows)];
    end
    coronal(ap_voxel - 49, :) = [ap_voxel, nnz(mask), bounds];
end

sagittal = zeros(0, 2);
for ml_voxel = 70:185
    roi_slice = double(squeeze(roi_nii.img(ml_voxel + 1, :, :)));
    count = nnz(ismember(roi_slice, roi_values));
    if count > 0
        sagittal(end + 1, :) = [ml_voxel, count]; %#ok<SAGROW>
    end
end

audit.coronal = coronal;
audit.sagittalNonzero = sagittal;
output_path = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\.codex_tmp\clay_smoke\jim_roi_diagnostic.json';
fid = fopen(output_path, 'w');
fprintf(fid, '%s', jsonencode(audit));
fclose(fid);

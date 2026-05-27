filePath = 'P:\Clay\NeuroData\20210803\Clay_FST_03August2021_TT1_mrg_Sorted-02_SparseNoise_1_1.mat';
outFile = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\LoRF\tmp_clay_mat_inspect.txt';
S = load(filePath);
fid = fopen(outFile, 'w');
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fields = fieldnames(S);
fprintf(fid, 'Top-level fields:\n');
for i = 1:numel(fields)
    name = fields{i};
    value = S.(name);
    fprintf(fid, '- %s | class=%s | size=%s\n', name, class(value), mat2str(size(value)));
    if isnumeric(value) && ismatrix(value)
        sampleRows = min(5, size(value,1));
        sampleCols = min(6, size(value,2));
        fprintf(fid, '  first rows/cols:\n');
        for r = 1:sampleRows
            fprintf(fid, '   ');
            fprintf(fid, '%g ', value(r,1:sampleCols));
            fprintf(fid, '\n');
        end
    elseif isstruct(value)
        subFields = fieldnames(value);
        fprintf(fid, '  subfields: %s\n', strjoin(subFields', ', '));
    end
end

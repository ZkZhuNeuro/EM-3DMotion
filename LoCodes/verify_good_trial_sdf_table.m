inputPath = 'C:/LoData/MotionData_ByStim_NeuroResp_ByNeuron_WithGoodTrialSDF_smoketest.mat';
outputPath = 'C:/Users/zzhu329/Documents/GitHub/EM-3DMotion/LoCodes/good_trial_sdf_verify.txt';

S = load(inputPath, 'NeuroRespByNeuronTable');
T = S.NeuroRespByNeuronTable;

filled = ~cellfun(@isempty, T.GoodTrialSDF);
fid = fopen(outputPath, 'w');
cleanupObj = onCleanup(@() fclose(fid));

fprintf(fid, 'Rows: %d\n', height(T));
fprintf(fid, 'Rows with GoodTrialSDF: %d\n', nnz(filled));
fprintf(fid, 'Variables: %s\n', strjoin(T.Properties.VariableNames, ', '));

firstFilled = find(filled, 1, 'first');
if ~isempty(firstFilled)
    fprintf(fid, 'First filled row: %d\n', firstFilled);
    fprintf(fid, 'GoodTrialSDF size: %s\n', mat2str(size(T.GoodTrialSDF{firstFilled})));
    fprintf(fid, 'GoodTrialInfo size: %s\n', mat2str(size(T.GoodTrialInfo{firstFilled})));
    fprintf(fid, 'GoodTrialSDFSource: %s\n', T.GoodTrialSDFSource(firstFilled));
end

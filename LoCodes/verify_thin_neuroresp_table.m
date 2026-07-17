S = load('C:/LoData/MotionData_ByStim_NeuroResp_ByNeuron_Thin.mat', 'NeuroRespByNeuronTable');
T = S.NeuroRespByNeuronTable;

fid = fopen('C:/Users/zzhu329/Documents/GitHub/EM-3DMotion/LoCodes/thin_neuroresp_table_verify.txt', 'w');
cleanupObj = onCleanup(@() fclose(fid));

fprintf(fid, 'Rows: %d\n', height(T));
fprintf(fid, 'Columns: %d\n', width(T));
fprintf(fid, 'Variables: %s\n', strjoin(T.Properties.VariableNames, ', '));

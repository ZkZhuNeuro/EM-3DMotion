logPath = 'C:/Users/zzhu329/Documents/GitHub/EM-3DMotion/LoCodes/save_motiondata_neuroresp_by_neuron_log.txt';
fid = fopen(logPath, 'w');
cleanupObj = onCleanup(@() fclose(fid));

try
    fprintf(fid, 'Started: %s\n', datestr(now));
    tableOut = SaveMotionDataNeuroRespByNeuronTable( ...
        'C:/LoData/MotionData_ByStim.mat', ...
        'C:/LoData/TempData.mat', ...
        'C:/LoData/MotionData_ByStim_NeuroResp_ByNeuron.mat', ...
        'C:/LoData/NeuroResp.mat');
    fprintf(fid, 'Completed: %s\n', datestr(now));
    fprintf(fid, 'Rows: %d\n', height(tableOut));
    fprintf(fid, 'Variables: %s\n', strjoin(tableOut.Properties.VariableNames, ', '));
    fprintf(fid, 'First NeuroResp size: %s\n', mat2str(size(tableOut.NeuroResp{1})));
    fprintf(fid, 'Last NeuroResp size: %s\n', mat2str(size(tableOut.NeuroResp{end})));
catch ME
    fprintf(fid, 'ERROR: %s\n', ME.message);
    for kk = 1:numel(ME.stack)
        fprintf(fid, '  at %s:%d\n', ME.stack(kk).file, ME.stack(kk).line);
    end
    rethrow(ME);
end

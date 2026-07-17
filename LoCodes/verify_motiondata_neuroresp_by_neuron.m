inputPath = 'C:/LoData/MotionData_ByStim_NeuroResp_ByNeuron.mat';
outputPath = 'C:/Users/zzhu329/Documents/GitHub/EM-3DMotion/LoCodes/motiondata_neuroresp_by_neuron_verify.txt';

fid = fopen(outputPath, 'w');
cleanupObj = onCleanup(@() fclose(fid));

S = load(inputPath, 'NeuroRespByNeuronTable');
T = S.NeuroRespByNeuronTable;

fprintf(fid, 'Rows: %d\n', height(T));
fprintf(fid, 'Variables: %s\n', strjoin(T.Properties.VariableNames, ', '));
fprintf(fid, 'First row: Monkey=%s ROI=%s TT=%g Unit=%g Size=%s\n', ...
    T.Monkey(1), T.ROI(1), T.TT(1), T.Unit(1), mat2str(size(T.NeuroResp{1})));
fprintf(fid, 'Last row: Monkey=%s ROI=%s TT=%g Unit=%g Size=%s\n', ...
    T.Monkey(end), T.ROI(end), T.TT(end), T.Unit(end), mat2str(size(T.NeuroResp{end})));

badShape = false(height(T), 1);
emptyRepeats = false(height(T), 1);
for i = 1:height(T)
    resp = T.NeuroResp{i};
    badShape(i) = size(resp, 1) ~= 4 || size(resp, 2) ~= 13;
    emptyRepeats(i) = size(resp, 3) > 0 && any(squeeze(all(all(isnan(resp), 1), 2)));
end

fprintf(fid, 'Bad shape rows: %d\n', sum(badShape));
fprintf(fid, 'Rows with all-NaN repeats remaining: %d\n', sum(emptyRepeats));

[unitSources, ~, srcIdx] = unique(T.UnitSource);
for i = 1:numel(unitSources)
    fprintf(fid, 'UnitSource %s: %d rows\n', unitSources(i), sum(srcIdx == i));
end

[monkeys, ~, monkeyIdx] = unique(T.Monkey);
for i = 1:numel(monkeys)
    fprintf(fid, 'Monkey %s: %d rows\n', monkeys(i), sum(monkeyIdx == i));
end

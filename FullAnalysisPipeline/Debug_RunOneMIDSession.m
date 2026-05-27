clearvars
cd(fileparts(mfilename('fullpath')))

sessionLimitPerMonkey = 1;
run('BuildMIDTable_MUAStim_JimClay.m');

fid = fopen('midtable_debug_summary.txt', 'w');
fprintf(fid, 'MIDTable rows: %d\n', height(MIDTable));
fprintf(fid, 'Skipped rows: %d\n\n', height(SkippedSessions));

for i = 1:height(MIDTable)
    fprintf(fid, 'Row %d\n', i);
    fprintf(fid, '  Monkey: %s\n', MIDTable.Monkey{i});
    fprintf(fid, '  Date: %s\n', datestr(MIDTable.Date(i), 'yyyy-mm-dd'));
    fprintf(fid, '  ROI: %s\n', MIDTable.ROI{i});
    fprintf(fid, '  StimElec: %g\n', MIDTable.StimElec(i));
    fprintf(fid, '  FolderPath: %s\n', MIDTable.FolderPath{i});
    fprintf(fid, '  Paths: %s\n', MIDTable.Paths{i});
    fprintf(fid, '  StimPair: %s | %s\n', MIDTable.Names{i,1}, MIDTable.Names{i,2});
    fprintf(fid, '  QuickPair: %s | %s\n', MIDTable.QuickNames{i,1}, MIDTable.QuickNames{i,2});
    fprintf(fid, '  2DTag: %s\n', MIDTable.Analysis2DTag{i});
    fprintf(fid, '  2DPair: %s | %s\n\n', MIDTable.Names_2D{i,1}, MIDTable.Names_2D{i,2});
end

if ~isempty(SkippedSessions)
    fprintf(fid, 'Skipped detail\n');
    for i = 1:height(SkippedSessions)
        fprintf(fid, '  %s %s row %d: %s\n', ...
            SkippedSessions.Monkey{i}, ...
            datestr(SkippedSessions.Date(i), 'yyyy-mm-dd'), ...
            SkippedSessions.WorkbookRow(i), ...
            SkippedSessions.Reason{i});
    end
end
fclose(fid);

rec = 1;
fid = fopen('midtable_pipeline_debug.txt', 'w');
try
    pipelineOutput = evalc('[AI, CI, R, Monocularity, Eye, Eye_AI, delta_bias, Neuro, LFP_Data, BehaviorData, sensits] = Stimulation_ClusteringIndexPipeline(MIDTable.Monkey{rec}, MIDTable.Paths(rec), MIDTable.Names(rec,:), MIDTable.QuickNames(rec,:), MIDTable.Names_2D(rec,:), MIDTable.StimElec(rec));'); %#ok<NASGU>
    fprintf(fid, 'Pipeline run succeeded for row %d\n', rec);
    fprintf(fid, 'Monkey: %s\n', MIDTable.Monkey{rec});
    fprintf(fid, 'Date: %s\n', datestr(MIDTable.Date(rec), 'yyyy-mm-dd'));
    fprintf(fid, 'AI size: %s\n', mat2str(size(AI)));
    fprintf(fid, 'CI size: %s\n', mat2str(size(CI)));
    fprintf(fid, 'delta_bias size: %s\n', mat2str(size(delta_bias)));
    fprintf(fid, 'NoStim fit size: %s\n', mat2str(size(BehaviorData.NoStim.pFitVals)));
    fprintf(fid, 'Stim fit size: %s\n\n', mat2str(size(BehaviorData.Stim.pFitVals)));
    fprintf(fid, 'Captured output:\n%s\n', pipelineOutput);
catch ME
    fprintf(fid, 'Pipeline run failed for row %d\n\n', rec);
    fprintf(fid, '%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
end
fclose(fid);

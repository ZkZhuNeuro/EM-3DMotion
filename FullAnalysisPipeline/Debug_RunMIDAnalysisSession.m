clearvars -except targetSessionIndex
cd(fileparts(mfilename('fullpath')))

if ~exist('targetSessionIndex', 'var')
    targetSessionIndex = 1;
end

sessionLimitPerMonkey = inf;
run('BuildMIDTable_MUAStim_JimClay.m');

reportPath = fullfile(pwd, sprintf('debug_mid_analysis_session_%03d.txt', targetSessionIndex));
fid = fopen(reportPath, 'w');

try
    if targetSessionIndex < 1 || targetSessionIndex > height(MIDTable)
        error('Requested targetSessionIndex %d is outside 1:%d.', targetSessionIndex, height(MIDTable));
    end

    rec = targetSessionIndex;
    fprintf(fid, 'Target session index: %d\n', rec);
    fprintf(fid, 'Monkey: %s\n', MIDTable.Monkey{rec});
    fprintf(fid, 'Date: %s\n', datestr(MIDTable.Date(rec), 'yyyy-mm-dd'));
    fprintf(fid, 'ROI: %s\n', MIDTable.ROI{rec});
    fprintf(fid, 'StimElec: %g\n', MIDTable.StimElec(rec));
    fprintf(fid, 'FolderPath: %s\n', MIDTable.FolderPath{rec});
    fprintf(fid, 'Paths: %s\n', MIDTable.Paths{rec});
    fprintf(fid, 'StimPair: %s | %s\n', MIDTable.Names{rec,1}, MIDTable.Names{rec,2});
    fprintf(fid, 'QuickPair: %s | %s\n', MIDTable.QuickNames{rec,1}, MIDTable.QuickNames{rec,2});
    fprintf(fid, '2DPair: %s | %s\n\n', MIDTable.Names_2D{rec,1}, MIDTable.Names_2D{rec,2});
    fprintf(fid, 'which Stimulation_ClusteringIndexPipeline: %s\n', which('Stimulation_ClusteringIndexPipeline'));
    fprintf(fid, 'which Offline_3DMotion_NoSaccade_v1_081421: %s\n', which('Offline_3DMotion_NoSaccade_v1_081421'));
    fprintf(fid, 'which Offline_3DMotion_Stimulation_v2_081421: %s\n\n', which('Offline_3DMotion_Stimulation_v2_081421'));
    fclose(fid);

    fid = fopen(reportPath, 'a');
    fprintf(fid, 'Starting quick 3D stage...\n');
    fclose(fid);

    [~, Neuro3D, ~] = Offline_3DMotion_NoSaccade_v1_081421(MIDTable.Paths(rec), MIDTable.QuickNames(rec,:), false); %#ok<NASGU>
    fid = fopen(reportPath, 'a');
    fprintf(fid, 'Quick 3D stage: Success\n');
    fprintf(fid, 'Neuro3D.Means size: %s\n\n', mat2str(size(Neuro3D.Means)));
    fprintf(fid, 'Starting 2D stage...\n');
    fclose(fid);

    if startsWith(MIDTable.Analysis2DTag{rec}, 'Lateral')
        [~, Neuro2D] = Offline_LateralMotion_Separate(MIDTable.Paths(rec), MIDTable.Names_2D(rec,:), false); %#ok<NASGU>
    else
        [~, Neuro2D] = Offline_Rapid2D_v1_051822(MIDTable.Paths(rec), MIDTable.Names_2D(rec,:), false); %#ok<NASGU>
    end
    fid = fopen(reportPath, 'a');
    fprintf(fid, '2D stage: Success\n');
    fprintf(fid, 'Neuro2D.Means size: %s\n\n', mat2str(size(Neuro2D.Means)));
    fprintf(fid, 'Starting stimulation stage...\n');
    fclose(fid);

    [~, LFP_Data, BehaviorData] = Offline_3DMotion_Stimulation_v2_081421(MIDTable.Paths(rec), MIDTable.Names(rec,:), false); %#ok<NASGU>
    fid = fopen(reportPath, 'a');
    fprintf(fid, 'Stimulation stage: Success\n');
    fprintf(fid, 'Behavior NoStim pFit size: %s\n', mat2str(size(BehaviorData.NoStim.pFitVals)));
    fprintf(fid, 'Behavior Stim pFit size: %s\n\n', mat2str(size(BehaviorData.Stim.pFitVals)));
    fprintf(fid, 'Starting clustering stage...\n');
    fclose(fid);

    [CI, AI, Monocularity, Eye, Eye_AI] = ClusteringIndex_v1_082321(Neuro3D, LFP_Data, MIDTable.StimElec(rec)); %#ok<NASGU>
    fid = fopen(reportPath, 'a');
    fprintf(fid, 'Clustering stage: Success\n');
    fprintf(fid, 'AI size: %s\n', mat2str(size(AI)));
    fprintf(fid, 'CI size: %s\n', mat2str(size(CI)));
catch ME
    fprintf(fid, 'Pipeline status: Failed\n\n');
    fprintf(fid, '%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
end

fclose(fid);

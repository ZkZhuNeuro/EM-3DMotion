function [AI, CI, R, Monocularity, Eye, Eye_AI, delta_bias, Neuro, LFP_Data, BehaviorData, sensits] = Stimulation_ClusteringIndexPipeline_new02062024(PathName,StimFiles,QuickFiles,Files2D,stim_elec)

colorsteps = [0 0 0;...
    0 0 255;...
    5 150 5;...
    234 0 233;
    0 100 255;...
    0 255 100]./255;

conditionNames = {'Combined','Dominant','Non-Dom','Stereo'};
ChannelMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]; % Edge Design Dorsal-->Ventral
recording_date = extractBetween(PathName,'\','\');
recording_date = recording_date{end};
if iscell(PathName)
    PathName = PathName{:};
end
%% This pipeline seems to be working - the clustering index however need works
% for general analysis, until you get the CI working, you can form a
% wrapper that performs these sets of functions for each recording session.

% e.g., use a GenerateFileTable function
% Loop and index into the appropriate files for each session,
% then pass the file names into the corresponding functions,
% and build a data structure for each session. Make it general.
% Then you can have your plotting functions.
% Make sure that your neural data is in a format that can be used by
% existing functions (e.g., having an AllData struct, MIDTable, etc.

st = tic;
reanalyze = 1;
save_location = 'E:\Jim\StimData';
saved_files = dir([save_location,'\*.mat']);
if ~isempty(saved_files)
    saved_files = extractBefore(extractfield(saved_files,'name'),'.mat');
else
    saved_files = {};
end
if reanalyze || ~ismember(recording_date,saved_files) % Can't load data if it hasn't been saved
    %% reanalyze the data?
    
    % Get 3D Tuning from rappid 3D tuning
    fprintf('\nExtracting 3D Tuning...\n')
    [~, Neuro,~] = Offline_3DMotion_NoSaccade_v1_081421(PathName,QuickFiles);
    f = gcf;
    f.Position = [387, 288, 1054, 407];
    f.PaperOrientation = 'landscape';
    saveas(f,[PathName,'3DTuning.pdf']);
    close all;
    
    fprintf('\nExtracting 2D Tuning...\n')
    % Get 2D Tuning from rappid 2D/3D tuning
    if datetime(str2num(recording_date(1:4)),str2num(recording_date(5:6)),str2num(recording_date(7:8))) < datetime('5/12/2022')
        [~, Neuro.Neuro2D] = Offline_LateralMotion_Separate(PathName,Files2D);
    else
        [~, Neuro.Neuro2D] = Offline_Rapid2D_v1_051822(PathName,Files2D);
    end
    
    % Save the 2D motion tuning figures
    f = gcf;
    f.Position = [387, 288, 1054, 407];
    f.PaperOrientation = 'landscape';
    saveas(f,[PathName,'2DTuning_13.pdf']);
    close(f)
    f = gcf;
    f.Position = [387, 288, 1054, 407];
    saveas(f,[PathName,'2DTuning_4.pdf']);
    close(f)
    
    % Get LFP data from stimulation experiment and behavioral fits
    fprintf('\nExtracting Stimulation Data...\n')
    [~, LFP_Data,BehaviorData] = Offline_3DMotion_Stimulation_v2_081421(PathName,StimFiles);
    % close all;
    
    % Get clustering index
    fprintf('\nCalculating Properties...\n')
    [CI, AI, Monocularity, Eye, Eye_AI] = ClusteringIndex_v1_082321(Neuro,LFP_Data,stim_elec); % AI(condition x channel#); NOTE CHANNEL NUMBER HAS NOTHING TO DO WITH LOCATION ON THE EL, just an index
    % Save the AI over distance plot
    f = gcf;
    saveas(f,[PathName,'AI_Distance.pdf']);
    
    valid_coherence = find(Neuro.Trials.NumTrials(1,:)>0);
    for c = 1:size(AI,2)
        % Get correlations
        R.Comb(c) = corr(squeeze(Neuro.Means(1,valid_coherence,stim_elec))', squeeze(Neuro.Means(1,valid_coherence,c))');
        R.MonoL(c) = corr(squeeze(Neuro.Means(2,valid_coherence,stim_elec))', squeeze(Neuro.Means(2,valid_coherence,c))');
        R.MonoR(c) = corr(squeeze(Neuro.Means(3,valid_coherence,stim_elec))', squeeze(Neuro.Means(3,valid_coherence,c))');
        R.Stereo(c) = corr(squeeze(Neuro.Means(4,valid_coherence,stim_elec))', squeeze(Neuro.Means(4,valid_coherence,c))');
        if strcmp(Eye(stim_elec),'R')
            R.Dom(c) = R.MonoR(c);
            R.NonDom(c) = R.MonoL(c);
        else
            R.Dom(c) = R.MonoL(c);
            R.NonDom(c) = R.MonoR(c);
        end
        R.All(c) = corr([squeeze(Neuro.Means(1,valid_coherence,stim_elec)), squeeze(Neuro.Means(2,valid_coherence,stim_elec)), squeeze(Neuro.Means(3,valid_coherence,stim_elec)), squeeze(Neuro.Means(4,valid_coherence,stim_elec))]',...
            [squeeze(Neuro.Means(1,valid_coherence,c)), squeeze(Neuro.Means(2,valid_coherence,c)), squeeze(Neuro.Means(3,valid_coherence,c)), squeeze(Neuro.Means(4,valid_coherence,c))]');
    end
    
    % A negative bias means towards bias
    delta_bias = BehaviorData.NoStim.pFitVals(1,:)-BehaviorData.Stim.pFitVals(1,:); % positive deltas indicate "towards" report shift, just like positive AI values will indicate a towards pref.
    sensits.NoStim = 1./BehaviorData.NoStim.pFitVals(2,:);
    sensits.Stim = 1./BehaviorData.Stim.pFitVals(2,:);
    sensits.delta = (1./BehaviorData.NoStim.pFitVals(2,:))-(1./BehaviorData.Stim.pFitVals(2,:));
    %%
    figure; hold on;
    for c = 1:length(delta_bias)
        if strcmp(Eye(stim_elec),'R') && (c == 2 || c ==3) % right eye dominant
            if c == 2
                plot(AI(3,stim_elec),delta_bias(3),'o','MarkerFaceColor',colorsteps(c,:),'MarkerEdgeColor',colorsteps(c,:));
            else
                plot(AI(2,stim_elec),delta_bias(2),'o','MarkerFaceColor',colorsteps(c,:),'MarkerEdgeColor',colorsteps(c,:));
            end
        else
            plot(AI(c,stim_elec),delta_bias(c),'o','MarkerFaceColor',colorsteps(c,:),'MarkerEdgeColor',colorsteps(c,:));
        end
    end
    xlabel('AI at stim electrode')
    xticks([-1,-0.5,0,0.5,1]);
    xticklabels({'-1','Away','0','Toward','1'})
    yticks([-1,-0.5,0,0.5,1])
    yticklabels({'-1','Away','0','Toward','1'})
    ylabel('Delta Bias')
    axis square;
    xlim([-1,1]);
    ylim([-1,1]);
    plot([0, 0], [-1,1],'--k')
    plot([-1,1],[0, 0], '--k');
    legend(conditionNames,'Location','northeastoutside');
    f = gcf;
    saveas(f,[PathName,'AIvBias.pdf']);
    
    
    %% Save the data here
    fprintf('\nSaving Data...\n')
    save(fullfile(save_location,[recording_date,'.mat']), 'Neuro', 'LFP_Data', 'BehaviorData', 'CI', 'AI', 'Monocularity', 'Eye', 'Eye_AI', 'R', 'delta_bias', 'sensits');
else
    %% Load the data instead
    fprintf('\nLoading Data...\n')
    load(fullfile(save_location,[recording_date,'.mat']));
end
fprintf('\n%i min\n',round(toc(st)/60),2);
end

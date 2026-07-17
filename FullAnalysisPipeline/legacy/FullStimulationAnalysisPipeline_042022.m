%% Main Analyses
clear all

colorsteps = [0 0 0;...
    0 0 255;...
    5 150 5;...
    234 0 233;
    0 100 255;...
    0 255 100]./255;
 
conditionNames = {'Combined','MonoL','MonoR','Stereo'};
CoherenceArray = [-22 -14 -10 -8 -4 -2 2 4 8 10 14 22]./22;
ChannelMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]; % Edge Design Dorsal-->Ventral
xRange = -1:0.01:1;
% Define distance between channels
Distance = 0:50:50*(length(ChannelMap)-1); % 50 micrometers apart
cell_column = ['MUAStim']; % Will find all cells with stimulus in RF
monkeys = ["Jim"];
areas = ["MT", "FST"];

%% Initialize variables and get excel sheet with session information
MT_RFTable = table();
FST_RFTable = table();
MT_MIDTable = table();
FST_MIDTable = table();
MT_QuickTable = table();
FST_QuickTable = table();
MT_LateralMotionTable = table();
FST_LateralMotionTable = table();

for m = 1:size(monkeys,2)
    if strcmp(monkeys(m),'Jim')
        xls_table = 'P:\Jim\NeuroData\RecordingRecord_Stimulation_20240515.xlsx';
        path_options = {'P:\Jim\NeuroData\','C:\Jim\In_Processing\'};
        exclusion_criteria = [{'ROI','MT/FST'}; {'ROI','MT?'};{'ROI','FST?'};{'MUAStim',''}; {'MUAStim','N'}];
        
    elseif strcmp(monkeys(m),'Clay')
        xls_table = 'P:\Clay\NeuroData\RecordingRecord.xlsx';
        path_options = {'C:\Clay\In_Processing\','P:\Clay\NeuroData\'};
        exclusion_criteria = [{'InRF','N'}; {'ROI','MT/FST'}; {'Hemisphere','Right'}; {'ROI','MT?'}; {'WF',''};{'WF','N'}; {'RF','N'}; {'RF',''}; {'ROI','FST?'}];
        
    end
    % MT tables
    if any(strcmp(areas,'MT'))
        inclusion_criteria = [{'MUAStim','Y'}];
        %         [tmp_RFTable, ~] = GenerateStimulationFileTable(xls_table, path_options,...
        %             cell_column,inclusion_criteria,exclusion_criteria,'SparseNoise_Raw.mat');
        
        [tmp_MT_MIDTable] = GenerateStimulationFileTable(xls_table, path_options,...
            cell_column,inclusion_criteria,exclusion_criteria,'3DMotionStim');
        
        [tmp_MT_QuickTable] = GenerateStimulationFileTable(xls_table, path_options,...
            cell_column,inclusion_criteria,exclusion_criteria,'3DMotionQuick');
        
        exclusion_criteria(end+1,:) = {'Separate2D',''};
        [tmp_MT_LateralMotionTable] = GenerateStimulationFileTable(xls_table, path_options,...
            cell_column,inclusion_criteria,exclusion_criteria,'LateralMotion');
        if ~isempty(tmp_MT_LateralMotionTable)
            tmp_MT_QuickTable.Names_2D(1:size(tmp_MT_LateralMotionTable,1),:) = tmp_MT_LateralMotionTable.Names;
        end
        
        exclusion_criteria{end,2} = 'Y';
        [tmp_MT_2DMotionTable] = GenerateStimulationFileTable(xls_table, path_options,...
            cell_column,inclusion_criteria,exclusion_criteria,'2DMotion');
        if ~isempty(tmp_MT_LateralMotionTable)
            tmp_MT_QuickTable.Names_2D(size(tmp_MT_LateralMotionTable,1)+1:end,:) = tmp_MT_2DMotionTable.Names;
        else
            tmp_MT_QuickTable.Names_2D = tmp_MT_2DMotionTable.Names;
        end
        
        
        %         MT_RFTable = [MT_RFTable; tmp_RFTable];
        MT_MIDTable = [MT_MIDTable; tmp_MT_MIDTable];
        MT_QuickTable = [MT_QuickTable; tmp_MT_QuickTable];
    end
end

RFTable = [MT_RFTable; FST_RFTable];
MIDTable = [MT_MIDTable; FST_MIDTable];
QuickTable = [MT_QuickTable; FST_QuickTable];
LateralMotionTable = [MT_LateralMotionTable; FST_LateralMotionTable];
MIDTable.QuickNames = QuickTable.Names;
MIDTable.Names_2D = QuickTable.Names_2D;

clear file_table_MT_2D file_table_FST_2D file_table_MT_3D file_table_FST_3D MT_RFTable FST_RFTable MT_MIDTable FST_MIDTable MT_LateralMotionTable FST_LateralMotionTable


%% Now you should be able to run your analyses
% for rec = 76:77
for rec = 2
    fprintf('\nAnalyzing session %d/%d\n', rec, size(MIDTable,1))
    [AI(rec,:,:), CI(rec,:), R(rec,:), Monocularity(rec), Eye(rec,:), Eye_AI(rec,:), delta_bias(rec,:), Neuro(rec), LFP_Data(rec), BehaviorData(rec), Sensits(rec)] =...
        Stimulation_ClusteringIndexPipeline(monkeys, MIDTable.Paths(rec), MIDTable.Names(rec,:), MIDTable.QuickNames(rec,:), MIDTable.Names_2D(rec,:), MIDTable.StimElec(rec));
    
    close all
end

%% Important plots on a session-by session basis
% 1) tuning at the stimulation site
% 2) behavioral performance in non-stimulation trials
% 3) behavioral performance for stimulation trials
% 4) Clustering plots are useful
rec_map = winter(size(MIDTable,1));
for rec = 31:size(MIDTable,1)
    % Calculate Anovas at the stimulation site
    for cond = 1:4
        valid_coherence = find(Neuro(rec).Trials.NumTrials(1,:)>0);
        anova_table=table();
        for c = 1:length(CoherenceArray)
            temp_tbl = table();
            if ismember(c,valid_coherence)
                temp = squeeze(Neuro(rec).All(cond,c,1:Neuro(rec).Trials.NumTrials(cond,c),MIDTable.StimElec(rec)));
                coh = repelem(CoherenceArray(c),length(temp),1);
                temp_tbl = array2table([temp(:),coh(:)],'VariableNames',{'FR','Coherence'});
            end
            anova_table = [anova_table; temp_tbl];
        end
        anova_table.Abs_Coherence = abs(anova_table.Coherence);
        anova_table.Direction = sign(anova_table.Coherence);
        lm = fitlm(anova_table,'FR ~ Abs_Coherence + Direction');
        anova_results = anova(lm);
        MIDTable.(['anova2_',conditionNames{cond}])(rec) = anova_results.pValue(2);
    end
    MIDTable.wCI(rec) = sum(CI(rec,:).*R(rec).All);
    MIDTable.wCI_Combined(rec) = sum(CI(rec,:).*R(rec).Comb);
    MIDTable.wCI_MonoL(rec) = sum(CI(rec,:).*R(rec).MonoL);
    MIDTable.wCI_MonoR(rec) = sum(CI(rec,:).*R(rec).MonoR);
    MIDTable.wCI_Stereo(rec) = sum(CI(rec,:).*R(rec).Stereo);
    MIDTable.Combined_AI(rec) = AI(rec,1,MIDTable.StimElec(rec));
    MIDTable.MonoL_AI(rec) = AI(rec,2,MIDTable.StimElec(rec));
    MIDTable.MonoR_AI(rec) = AI(rec,3,MIDTable.StimElec(rec));
    MIDTable.Stereo_AI(rec) = AI(rec,4,MIDTable.StimElec(rec));
    MIDTable.Monocularity(rec) = Monocularity(rec).Max(MIDTable.StimElec(rec));
    MIDTable.Monocularity_AI(rec) = Monocularity(rec).AI(MIDTable.StimElec(rec));
    MIDTable.Monocularity_AI_2D(rec) = Monocularity(rec).AI_2D(MIDTable.StimElec(rec)); % Aligned in 2D retinal coordinates
    MIDTable.Monocularity_mean(rec) = Monocularity(rec).Mean(MIDTable.StimElec(rec));
    MIDTable.Eye(rec) = Eye(rec,MIDTable.StimElec(rec));
    MIDTable.Delta_Mu_Combined(rec) = delta_bias(rec,1);
    MIDTable.Delta_Mu_MonoL(rec) = delta_bias(rec,2);
    MIDTable.Delta_Mu_MonoR(rec) = delta_bias(rec,3);
    MIDTable.Delta_Mu_Stereo(rec) = delta_bias(rec,4);
    MIDTable.Combined_Sensit_NoStim(rec) = 1./BehaviorData(rec).NoStim.pFitVals(2,1);
    MIDTable.Combined_Sensit_Stim(rec) = 1./BehaviorData(rec).Stim.pFitVals(2,1);
    MIDTable.MonoL_Sensit_NoStim(rec) = 1./BehaviorData(rec).NoStim.pFitVals(2,1);
    MIDTable.MonoL_Sensit_Stim(rec) = 1./BehaviorData(rec).Stim.pFitVals(2,1);
    MIDTable.MonoR_Sensit_NoStim(rec) = 1./BehaviorData(rec).NoStim.pFitVals(2,1);
    MIDTable.MonoR_Sensit_Stim(rec) = 1./BehaviorData(rec).Stim.pFitVals(2,1);
    MIDTable.Stereo_Sensit_NoStim(rec) = 1./BehaviorData(rec).NoStim.pFitVals(2,1);
    MIDTable.Stereo_Sensit_Stim(rec) = 1./BehaviorData(rec).Stim.pFitVals(2,1);
    
    MIDTable.Delta_Sensit_Combined(rec) = (1./BehaviorData(rec).NoStim.pFitVals(2,1)) - (1./BehaviorData(rec).Stim.pFitVals(2,1));
    MIDTable.Delta_Sensit_MonoL(rec) = (1./BehaviorData(rec).NoStim.pFitVals(2,2)) - (1./BehaviorData(rec).Stim.pFitVals(2,2));
    MIDTable.Delta_Sensit_MonoR(rec) = (1./BehaviorData(rec).NoStim.pFitVals(2,3)) - (1./BehaviorData(rec).Stim.pFitVals(2,3));
    MIDTable.Delta_Sensit_Stereo(rec) = (1./BehaviorData(rec).NoStim.pFitVals(2,4)) - (1./BehaviorData(rec).Stim.pFitVals(2,4));
    
    if  strcmp(MIDTable.Eye(rec),'R') %weighted_monocularity(rec)>0
        MIDTable.Dominant_AI(rec) = MIDTable.MonoR_AI(rec);
        MIDTable.Non_Dominant_AI(rec) = MIDTable.MonoL_AI(rec);
        MIDTable.Dominant_Delta(rec) = MIDTable.Delta_Mu_MonoR(rec);
        MIDTable.Non_Dominant_Delta(rec) = MIDTable.Delta_Mu_MonoL(rec);
        MIDTable.wCI_Dominant(rec) = MIDTable.wCI_MonoR(rec);
        MIDTable.wCI_NonDominant(rec) = MIDTable.wCI_MonoL(rec);
    else
        MIDTable.Dominant_AI(rec) = MIDTable.MonoL_AI(rec);
        MIDTable.Non_Dominant_AI(rec) = MIDTable.MonoR_AI(rec);
        MIDTable.Dominant_Delta(rec) = MIDTable.Delta_Mu_MonoL(rec);
        MIDTable.Non_Dominant_Delta(rec) = MIDTable.Delta_Mu_MonoR(rec);
        MIDTable.wCI_Dominant(rec) = MIDTable.wCI_MonoL(rec);
        MIDTable.wCI_NonDominant(rec) = MIDTable.wCI_MonoR(rec);
    end
    
    % Stim eccentricity
    MIDTable.Stim_Ecc(rec) = sqrt(sum(MIDTable.StimLoc(rec,:).^2));
    
    figure; hold on;
    
    % Clustering and AI values over distance
    stim_idx = find(ChannelMap == MIDTable.StimElec(rec));
    set(gcf,'renderer','Painters')
    subplot(2,2,1); hold on;
    AI_over_distance(ChannelMap,Distance,stim_idx,squeeze(CI(rec,:)),squeeze(AI(rec,:,:)),R(rec))
    
    % Tuning at stimulation site
    subplot(2,2,2); hold on;
    plot3DMotionTuning_Stim(Neuro(rec),MIDTable.StimElec(rec))
    title(['Date: ', datestr(MIDTable.Date(rec)), ' Channel: ', num2str(MIDTable.StimElec(rec))]);
    
    text(1.02,1,{['AI: ', num2str(round(MIDTable.Combined_AI(rec),2))]},'Color',colorsteps(1,:),'Units','Normalized','FontWeight','bold');
    text(1.02,0.9,{['AI: ', num2str(round(MIDTable.MonoL_AI(rec),2))]},'Color',colorsteps(2,:),'Units','Normalized','FontWeight','bold');
    text(1.02,0.8,{['AI: ', num2str(round(MIDTable.MonoR_AI(rec),2))]},'Color',colorsteps(3,:),'Units','Normalized','FontWeight','bold');
    text(1.02,0.7,{['AI: ', num2str(round(MIDTable.Stereo_AI(rec),2))]},'Color',colorsteps(4,:),'Units','Normalized','FontWeight','bold');
    
    % Behavior
    subplot(2,2,3); hold on;
    pFitResult = BehaviorData(rec).NoStim.pFitResult;
    plotBehavior_Stim(pFitResult)
    title('Non-Stimulation Trials');
    
    % Stimulation Trials
    pFitResult = BehaviorData(rec).Stim.pFitResult;
    subplot(2,2,4); hold on;
    plotBehavior_Stim(pFitResult)
    title('Stimulation Trials');
    
    text(1.02,1,{['\Delta\mu: ', num2str(round(MIDTable.Delta_Mu_Combined(rec),2))]},'Color',colorsteps(1,:),'Units','Normalized','FontWeight','bold');
    text(1.02,0.9,{['\Delta\mu: ', num2str(round(MIDTable.Delta_Mu_MonoL(rec),2))]},'Color',colorsteps(2,:),'Units','Normalized','FontWeight','bold');
    text(1.02,0.8,{['\Delta\mu: ', num2str(round(MIDTable.Delta_Mu_MonoR(rec),2))]},'Color',colorsteps(3,:),'Units','Normalized','FontWeight','bold');
    text(1.02,0.7,{['\Delta\mu: ', num2str(round(MIDTable.Delta_Mu_Stereo(rec),2))]},'Color',colorsteps(4,:),'Units','Normalized','FontWeight','bold');
    text(1.02,0.6,{[Eye(rec,MIDTable.StimElec(rec)), ' Eye Dom.']});
    f = gcf;
    f.Position = [680,344,821,634];
    saveas(f,[MIDTable.Paths{rec},'Summary.pdf']);
end

%% Calculate Z correlations for plotting based on 2D/3D quadrant
ZCorrelations_2Dv3D
ZCorrelations_OD
    % Post Analysis
    % Bootstrap the behavioral data to get confidence intevals on the bias and
    % sensitivities
    % bootstraps = 100;
    % for rec = 1:size(MIDTable,1)
    %    fprintf('\nBootstrapping session %d/%d\n', rec, size(MIDTable,1))
    %    [StimCI(rec).CI, NoStimCI(rec).CI] = BootstrapStimBehavior(BehaviorData(rec).NonStimTrials, BehaviorData(rec).StimTrials, bootstraps);
    % end

AllROI_MIDTable = MIDTable;
AllROI_AI = AI;
AllROI_delta_bias = delta_bias;
AllROI_Eye = Eye;
%% Summary plots
% Do this for each ROI separately
areas = unique(AllROI_MIDTable.ROI);
% for ith_area = 1:length(areas)
%     % Regardless of classification
%     MIDTable = AllROI_MIDTable(strcmp(AllROI_MIDTable.ROI,areas(ith_area)),:);
%     AI=AllROI_AI(strcmp(AllROI_MIDTable.ROI,areas(ith_area)),:,:);
%     delta_bias=AllROI_delta_bias(strcmp(AllROI_MIDTable.ROI,areas(ith_area)),:);
%     Eye = AllROI_Eye(strcmp(AllROI_MIDTable.ROI,areas(ith_area)),:);
%     
    CreateBiasTable
    StimulationRegressionModels  
    
    % For each classification
    % 2D Neurons
    criteria = AllROI_MIDTable.Z3D_v_Z2D < 0;
    MIDTable = AllROI_MIDTable(criteria,:);
    AI=AllROI_AI(criteria,:,:);
    delta_bias=AllROI_delta_bias(criteria,:);
    Eye = AllROI_Eye(criteria,:);
    
    % Separately plot Delta Mu v AI stim for each cue type and color based on
    % wCI
    DeltaMu_v_AIStim_Separate
    
    % Different version all on one plot
    DeltaMu_v_AIStim_All
    
    % 3D neurons
    criteria = AllROI_MIDTable.Z3D_v_Z2D > 0;
    MIDTable = AllROI_MIDTable(criteria,:);
    AI=AllROI_AI(criteria,:,:);
    delta_bias=AllROI_delta_bias(criteria,:);
    Eye = AllROI_Eye(criteria,:);
    
    % Separately plot Delta Mu v AI stim for each cue type and color based on
    % wCI
    DeltaMu_v_AIStim_Separate
    
    % Different version all on one plot
    DeltaMu_v_AIStim_All
       
% end
MIDTable = AllROI_MIDTable;
AI=AllROI_AI;
delta_bias=AllROI_delta_bias;
Eye = AllROI_Eye;

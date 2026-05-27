%% Main Analyses
clear all

colorsteps = [0 0 0;...
    0 0 255;...
    5 150 5;...
    234 0 233;
    0 100 255;...
    0 255 100]./255;

colorsteps_dom = [0 0 0;...
    254 191 15;...
    110 205 221; ...
    234 0 233]./255;

conditionNames = {'Combined','Dominant','Non-Dom','Stereo'};
CoherenceArray = [-22 -14 -10 -8 -4 -2 2 4 8 10 14 22]./22;
ChannelMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]; % Edge Design Dorsal-->Ventral
xRange = -1:0.01:1;
% Define distance between channels
Distance = 0:50:50*(length(ChannelMap)-1); % 50 micrometers apart

MIDTable = table();
MIDTable.Monkey = input('Monkey = ');
[MIDTable.QuickNames, MIDTable.Paths] = uigetfile({'*_3D*.mat' }, 'Select Quick 3D Motion Files',pwd, 'MultiSelect', 'on');
[MIDTable.Names_2D, ~] = uigetfile({'*_2D*.mat' }, 'Select Quick 2D Motion Files',pwd, 'MultiSelect', 'on');
[MIDTable.Names, ~] = uigetfile({'*_3D*.mat' }, 'Select Stimulation 3D Motion Files',pwd, 'MultiSelect', 'on');
MIDTable.StimElec = input('Stim Electrode = ');
MIDTable.NChannels = 16;

for rec = 1:size(MIDTable,1) 
    %% Run analyses
    fprintf('\nAnalyzing session %d/%d\n', rec, size(MIDTable,1))
    [AI(rec,:,:), CI(rec,:), R(rec), Monocularity(rec,:), Eye(rec,:), Eye_AI(rec,:), delta_bias(rec,:), Neuro(rec), LFP_Data(rec), BehaviorData(rec)] =...
        Stimulation_ClusteringIndexPipeline(MIDTable.Monkey(rec,:), MIDTable.Paths(rec,:), MIDTable.Names(rec,:), MIDTable.QuickNames(rec,:), MIDTable.Names_2D(rec,:), MIDTable.StimElec(rec));
    
    stim_idx = find(ChannelMap == MIDTable.StimElec(rec));

    %% Calculate wCI
    weighted_monocularity(rec) = mean(Monocularity.Max(rec,:).*CI(rec,:));
    if strcmp(Eye(rec,stim_idx),'R')
        wCI(rec,1) = mean(sign(AI(rec,1,stim_idx)).*R(rec).Comb.*CI(rec,:));
        wCI(rec,2) = mean(sign(AI(rec,3,stim_idx)).*R(rec).Dom.*CI(rec,:));
        wCI(rec,3) = mean(sign(AI(rec,2,stim_idx)).*R(rec).NonDom.*CI(rec,:));
        wCI(rec,4) = mean(sign(AI(rec,4,stim_idx)).*R(rec).Stereo.*CI(rec,:));
        
        wAI(rec,1) = mean(squeeze(AI(rec,1,:))'.*CI(rec,:));
        wAI(rec,2) = mean(squeeze(AI(rec,3,:))'.*CI(rec,:));
        wAI(rec,3) = mean(squeeze(AI(rec,2,:))'.*CI(rec,:));
        wAI(rec,4) = mean(squeeze(AI(rec,4,:))'.*CI(rec,:));
    else
        wCI(rec,1) = mean(sign(AI(rec,1,stim_idx)).*R(rec).Comb.*CI(rec,:));
        wCI(rec,2) = mean(sign(AI(rec,2,stim_idx)).*R(rec).Dom.*CI(rec,:));
        wCI(rec,3) = mean(sign(AI(rec,3,stim_idx)).*R(rec).NonDom.*CI(rec,:));
        wCI(rec,4) = mean(sign(AI(rec,4,stim_idx)).*R(rec).Stereo.*CI(rec,:));
        
        wAI(rec,1) = mean(squeeze(AI(rec,1,:))'.*CI(rec,:));
        wAI(rec,2) = mean(squeeze(AI(rec,2,:))'.*CI(rec,:));
        wAI(rec,3) = mean(squeeze(AI(rec,3,:))'.*CI(rec,:));
        wAI(rec,4) = mean(squeeze(AI(rec,4,:))'.*CI(rec,:));
    end
end




%% Important plots on a session-by session basis
% 1) tuning at the stimulation site
% 2) behavioral performance in non-stimulation trials
% 3) behavioral performance for stimulation trials
% 4) Clustering plots are useful
b_ax = figure;
rec_map = jet(4);
for rec = 1:size(MIDTable,1)
    stim_idx = find(ChannelMap == MIDTable.StimElec(rec));
    figure; hold on;
    
    % Clustering and AI values over distance
    subplot(2,2,1); hold on;
    for c = 1:MIDTable.NChannels % for each channel
        p = find(ChannelMap == c);
        relative_dist(c) = Distance(p)-Distance(stim_idx);
    end
    [sorted_dist,inds] = sort(relative_dist);
    sorted_auc = squeeze(CI(rec,inds));
    plot(sorted_dist,sorted_auc,'-ro')
    xlabel('Distance from Stim Elec.');
    ylabel('AUC(red) or AI');
    ylim([-1,1]);
    for c = 1:size(AI,2)
        plot(sorted_dist, squeeze(AI(rec,c,inds)),'-o','Color',colorsteps(c,:),'MarkerFaceColor',colorsteps(c,:),'MarkerEdgeColor',colorsteps(c,:));
    end
    
    % Tuning at stimulation site
    subplot(2,2,2); hold on;
    tempCh = squeeze(Neuro(rec).Means(:,:,MIDTable.StimElec(rec)));
    fr = plot(CoherenceArray,tempCh,'-o');
    hold on;
    box on;
    title(['Channel: ', num2str(MIDTable.StimElec(rec))]);
    ylabel('Firing Rate');
    xlabel('Coherence');
    for cond=1:4
        fr(cond).Color = colorsteps(cond,:);
        fr(cond).MarkerFaceColor = colorsteps(cond,:);
        fr(cond).MarkerEdgeColor = colorsteps(cond,:);
    end
    axis square;
    
    % Behavior
    subplot(2,2,3); hold on;
    pFitResult = BehaviorData(rec).NoStim.pFitResult;
    for cond = 1:4
        plotOptions.dataColor = colorsteps(cond,:);
        plotOptions.lineColor = colorsteps(cond,:);
        pfitPlot(cond) = plotPsych(pFitResult(cond),plotOptions);
    end
    title('Non-Stimulation Trials');
    line(xRange, ones(length(xRange),1)*0.5,'LineStyle','--','Color',[0 0 0]);
    line(zeros(length(xRange),1),[0:0.5:100],'LineStyle','--','Color',[0 0 0]);
    xlabel('Coherence');
    ylabel('Proportion Chose Towards');
    xlim([-1,1]);
    axis square;
    
    % Stimulation Trials
    pFitResult = BehaviorData(rec).Stim.pFitResult;
    subplot(2,2,4); hold on;
    for cond = 1:4 %length(ConditionArray)-4
        plotOptions.dataColor = colorsteps(cond,:);
        plotOptions.lineColor = colorsteps(cond,:);
        pfitPlot(cond) = plotPsych(pFitResult(cond),plotOptions);
    end
    title('Stimulation Trials');
    line(xRange, ones(length(xRange),1)*0.5,'LineStyle','--','Color',[0 0 0]);
    line(zeros(length(xRange),1),[0:0.5:100],'LineStyle','--','Color',[0 0 0]);
    xlabel('Coherence');
    ylabel('Proportion Chose Towards');
    xlim([-1,1]);
    axis square;
    
end

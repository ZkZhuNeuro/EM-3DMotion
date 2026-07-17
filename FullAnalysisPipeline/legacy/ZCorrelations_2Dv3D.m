%% 2Dv3D Predictions: Partial correlations
%{
2D Prediction: The non-dominant eye is negatively correlated with
combined: 2D retinal (flipped) correlation with combined cues

3D Prediction: The non-dominant eye is positvely correlated with combined:
3D world correlation with combined
%}

%% Calculate the correlations
ChannelTable = table();
for u = 1:size(MIDTable,1)
    % We do this for every channel, but take the stim electrode for major
    % plots
    valid_coherence = find(Neuro(u).Trials.NumTrials(1,:)>0);
    temp = table();
    for ch = 1:size(Neuro(u).Means,3)
        
        % 2D prediction is an alignment based on leftward/rightward
        % Specifically, that the left eye aligns with the flipped right eye
        temp.Pred2DCorr(ch) = corr(Neuro(u).Means(2,valid_coherence,ch)', flipud(Neuro(u).Means(3,valid_coherence,ch)'));
        
        % The 3D prediction is that the left and right eye align in world
        % coordinates (as is)
        temp.Pred3DCorr(ch) = corr(Neuro(u).Means(2,valid_coherence,ch)', Neuro(u).Means(3,valid_coherence,ch)');
        
        if Monocularity(u).Max(ch)>0 % right eye dominant
            % The correlation between the predictions is based on the dominant eye here
            % responses with the right eye flipped
            temp.Pred2Dv3DCorr(ch) = corr(Neuro(u).Means(3,valid_coherence,ch)', flipud(Neuro(u).Means(3,valid_coherence,ch)'));
        else
            % The correlation between the predictions is based on the dominant eye here
            % responses with the left eye flipped
            temp.Pred2Dv3DCorr(ch) = corr(Neuro(u).Means(2,valid_coherence,ch)', flipud(Neuro(u).Means(2,valid_coherence,ch)'));
        end
        temp.ROI(ch) = MIDTable.ROI(u);
        [~, ~, temp.Z_2D(ch), temp.Z_3D(ch)] = partial_corr_custom(temp.Pred2DCorr(ch), temp.Pred3DCorr(ch), temp.Pred2Dv3DCorr(ch), length(valid_coherence));
        temp.Z3D_v_Z2D(ch) = temp.Z_3D(ch) - temp.Z_2D(ch);
        if temp.Z_3D(ch)<1.28 && temp.Z_2D(ch)<1.28
            temp.Z_quad(ch) = 1;
        elseif temp.Z3D_v_Z2D(ch)>1.28
            temp.Z_quad(ch) = 2;
        elseif temp.Z3D_v_Z2D(ch)<-1.28
            temp.Z_quad(ch) = 4;
        else
            temp.Z_quad(ch) = 1;
        end
        if ch == MIDTable.StimElec(u)
            MIDTable.Pred2DCorr(u) = temp.Pred2DCorr(ch);
            MIDTable.Pred3DCorr(u) = temp.Pred3DCorr(ch);
            MIDTable.Pred2Dv3DCorr(u) = temp.Pred2Dv3DCorr(ch);
            MIDTable.Z_2D(u) = temp.Z_2D(ch);
            MIDTable.Z_3D(u) = temp.Z_3D(ch);
            MIDTable.Z3D_v_Z2D(u) = temp.Z3D_v_Z2D(ch);
            MIDTable.Z_quad(u) = temp.Z_quad(ch);
        end
    end
    ChannelTable = [ChannelTable; temp];
end

%% Figures for all channels
figure; 
subplot(1,2,1); hold on;
title({'MT All Channels Z-Correlations'});
for u = 1:size(ChannelTable,1)
    if strcmp(ChannelTable.ROI(u),'MT')
        switch ChannelTable.Z_quad(u)
            case 2 % 3D
                scatter(ChannelTable.Z_2D(u), ChannelTable.Z_3D(u), 60, [0 113 188]/255,'filled','MarkerEdgeColor','w');
                
            case 1 % unclassified
                scatter(ChannelTable.Z_2D(u), ChannelTable.Z_3D(u), 60, 'k','filled','MarkerEdgeColor','w');
                
            case 4 % 2D
                scatter(ChannelTable.Z_2D(u), ChannelTable.Z_3D(u), 60,[187 20 0]/255,'filled','MarkerEdgeColor','w');
                
        end
    end
end
lims = [min([get(gca,'XLim'),get(gca,'YLim')]), max([get(gca,'XLim'),get(gca,'YLim')])];
xlim(lims);
ylim(lims);
axis square;
box on;
xlabel('Z_2_D');
ylabel('Z_3_D');

x = 1.28:0.1:lims(2);
plot(x,-1.28 + x,'-k');
plot([1.28,1.28],[lims(1), 0],'-k');
x = 0:0.1:lims(2);
plot(x,1.28 + x,'-k');
plot([lims(1), 0],[1.28,1.28],'-k');

subplot(1,2,2); hold on;
title({'FST All Channels Z-Correlations'});
for u = 1:size(ChannelTable,1)
    if strcmp(ChannelTable.ROI(u),'FST') 
        switch ChannelTable.Z_quad(u)
            case 2 % 3D
                scatter(ChannelTable.Z_2D(u), ChannelTable.Z_3D(u), 60, [0 113 188]/255,'filled','MarkerEdgeColor','w');
                
            case 1 % unclassified
                scatter(ChannelTable.Z_2D(u), ChannelTable.Z_3D(u), 60, 'k','filled','MarkerEdgeColor','w');
                
            case 4 % 2D
                scatter(ChannelTable.Z_2D(u), ChannelTable.Z_3D(u), 60,[187 20 0]/255,'filled','MarkerEdgeColor','w');
                
        end
    end
end
% lims = [min([get(gca,'XLim'),get(gca,'YLim')]), max([get(gca,'XLim'),get(gca,'YLim')])];
xlim(lims);
ylim(lims);
axis square;
box on;
xlabel('Z_2_D');
ylabel('Z_3_D');

x = 1.28:0.1:lims(2);
plot(x,-1.28 + x,'-k');
plot([1.28,1.28],[lims(1), 0],'-k');
x = 0:0.1:lims(2);
plot(x,1.28 + x,'-k');
plot([lims(1), 0],[1.28,1.28],'-k');
%% Figures for stim channels
criteria = MIDTable.anova2_Combined>0;
figure; 
subplot(1,2,1); hold on;
title({'MT Z-Scored Partial Correlations'});
for u = 1:size(MIDTable,1)
    if strcmp(MIDTable.ROI(u),'MT') && criteria(u)
        switch MIDTable.Z_quad(u)
            case 2 % 3D
                scatter(MIDTable.Z_2D(u), MIDTable.Z_3D(u), 60, [0 113 188]/255,'filled','MarkerEdgeColor','w');
                
            case 1 % unclassified
                scatter(MIDTable.Z_2D(u), MIDTable.Z_3D(u), 60, 'k','filled','MarkerEdgeColor','w');
                
            case 4 % 2D
                scatter(MIDTable.Z_2D(u), MIDTable.Z_3D(u), 60,[187 20 0]/255,'filled','MarkerEdgeColor','w');
                
        end
    end
end
lims = [min([get(gca,'XLim'),get(gca,'YLim')]), max([get(gca,'XLim'),get(gca,'YLim')])];
xlim(lims);
ylim(lims);
axis square;
box on;
xlabel('Z_2_D');
ylabel('Z_3_D');

x = 1.28:0.1:lims(2);
plot(x,-1.28 + x,'-k');
plot([1.28,1.28],[lims(1), 0],'-k');
x = 0:0.1:lims(2);
plot(x,1.28 + x,'-k');
plot([lims(1), 0],[1.28,1.28],'-k');

subplot(1,2,2); hold on;
title({'FST Z-Scored Partial Correlations'});
for u = 1:size(MIDTable,1)
    if strcmp(MIDTable.ROI(u),'FST') && criteria(u)
        switch MIDTable.Z_quad(u)
            case 2 % 3D
                scatter(MIDTable.Z_2D(u), MIDTable.Z_3D(u), 60, [0 113 188]/255,'filled','MarkerEdgeColor','w');
                
            case 1 % unclassified
                scatter(MIDTable.Z_2D(u), MIDTable.Z_3D(u), 60, 'k','filled','MarkerEdgeColor','w');
                
            case 4 % 2D
                scatter(MIDTable.Z_2D(u), MIDTable.Z_3D(u), 60,[187 20 0]/255,'filled','MarkerEdgeColor','w');
                
        end
    end
end
% lims = [min([get(gca,'XLim'),get(gca,'YLim')]), max([get(gca,'XLim'),get(gca,'YLim')])];
xlim(lims);
ylim(lims);
axis square;
box on;
xlabel('Z_2_D');
ylabel('Z_3_D');

x = 1.28:0.1:lims(2);
plot(x,-1.28 + x,'-k');
plot([1.28,1.28],[lims(1), 0],'-k');
x = 0:0.1:lims(2);
plot(x,1.28 + x,'-k');
plot([lims(1), 0],[1.28,1.28],'-k');

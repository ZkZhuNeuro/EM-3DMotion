%% Ocular Dominance Partial correlations
%{
% Partial correlation between combined-cue tuning and left vs. right eye
perspective cues. Returns Z transformed corrleations and their difference
%}

%% Calculate the correlations
for u = 1:size(MIDTable,1)
    
    valid_coherence = find(Neuro(u).Trials.NumTrials(1,:)>0);
    left = Neuro(u).Neuro2D.Means(:,:,1,MIDTable.StimElec(u))';
    right = Neuro(u).Neuro2D.Means(:,:,2,MIDTable.StimElec(u))';
    both = Neuro(u).Neuro2D.Means(:,:,3,MIDTable.StimElec(u))';
    
    left_3D = Neuro(u).Means(2,valid_coherence,MIDTable.StimElec(u));
    right_3D = Neuro(u).Means(3,valid_coherence,MIDTable.StimElec(u));
    both_3D = Neuro(u).Means(1,valid_coherence,MIDTable.StimElec(u));
    
%     left = [left(:); left_3D'];
%     right = [right(:); right_3D'];
%     both = [both(:); both_3D'];
    
    % Correlate right w/combined
    MIDTable.corr_CvR(u) = corr(both(:), right(:));
    % Correlate left w/combined
    MIDTable.corr_CvL(u) = corr(both(:), left(:));
    % Correlate left w/right
    MIDTable.corr_LvR(u) = corr(left(:), right(:));
    
    
%     % Correlate right w/combined
%     MIDTable.corr_CvR(u) = corr(Neuro(u).Means(1,valid_coherence,MIDTable.StimElec(u))', Neuro(u).Means(3,valid_coherence,MIDTable.StimElec(u))');
%     % Correlate left w/combined
%     MIDTable.corr_CvL(u) = corr(Neuro(u).Means(1,valid_coherence,MIDTable.StimElec(u))', Neuro(u).Means(2,valid_coherence,MIDTable.StimElec(u))');
%     % Correlate left w/right
%     MIDTable.corr_LvR(u) = corr(Neuro(u).Means(3,valid_coherence,MIDTable.StimElec(u))', Neuro(u).Means(2,valid_coherence,MIDTable.StimElec(u))');
    
    [~, ~, MIDTable.Z_CvR(u), MIDTable.Z_CvL(u)] = partial_corr_custom(MIDTable.corr_CvR(u), MIDTable.corr_CvL(u), MIDTable.corr_LvR(u), length(left));
    
    MIDTable.Z_CvR_v_Z_CvL(u) = MIDTable.Z_CvR(u) - MIDTable.Z_CvL(u);
    if MIDTable.Z_CvR(u)<1.28 && MIDTable.Z_CvL(u)<1.28
        MIDTable.Z_OD_quad(u) = 1;
    elseif MIDTable.Z_CvR_v_Z_CvL(u)>1.28
        MIDTable.Z_OD_quad(u) = 2;
    elseif MIDTable.Z_CvR_v_Z_CvL(u)<-1.28
        MIDTable.Z_OD_quad(u) = 4;
    else
        MIDTable.Z_OD_quad(u) = 1;
    end
end

%% Figures for stim channels
criteria = MIDTable.anova2_Combined>0;
figure; 
subplot(1,2,1); hold on;
title({'MT Z-Scored Partial Correlations'});
for u = 1:size(MIDTable,1)
    if strcmp(MIDTable.ROI(u),'MT') && criteria(u)
        switch MIDTable.Z_OD_quad(u)
            case 2 % 3D
                scatter(MIDTable.Z_CvL(u), MIDTable.Z_CvR(u), 60, [0 113 188]/255,'filled','MarkerEdgeColor','w');
                
            case 1 % unclassified
                scatter(MIDTable.Z_CvL(u), MIDTable.Z_CvR(u), 60, 'k','filled','MarkerEdgeColor','w');
                
            case 4 % 2D
                scatter(MIDTable.Z_CvL(u), MIDTable.Z_CvR(u), 60,[187 20 0]/255,'filled','MarkerEdgeColor','w');
                
        end
    end
end
lims = [min([get(gca,'XLim'),get(gca,'YLim')]), max([get(gca,'XLim'),get(gca,'YLim')])];
xlim(lims);
ylim(lims);
axis square;
box on;
xlabel('Z_L');
ylabel('Z_R');

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
        switch MIDTable.Z_OD_quad(u)
            case 2 % 3D
                scatter(MIDTable.Z_CvL(u), MIDTable.Z_CvR(u), 60, [0 113 188]/255,'filled','MarkerEdgeColor','w');
                
            case 1 % unclassified
                scatter(MIDTable.Z_CvL(u), MIDTable.Z_CvR(u), 60, 'k','filled','MarkerEdgeColor','w');
                
            case 4 % 2D
                scatter(MIDTable.Z_CvL(u), MIDTable.Z_CvR(u), 60,[187 20 0]/255,'filled','MarkerEdgeColor','w');
                
        end
    end
end
% lims = [min([get(gca,'XLim'),get(gca,'YLim')]), max([get(gca,'XLim'),get(gca,'YLim')])];
xlim(lims);
ylim(lims);
axis square;
box on;
xlabel('Z_L');
ylabel('Z_R');

x = 1.28:0.1:lims(2);
plot(x,-1.28 + x,'-k');
plot([1.28,1.28],[lims(1), 0],'-k');
x = 0:0.1:lims(2);
plot(x,1.28 + x,'-k');
plot([lims(1), 0],[1.28,1.28],'-k');

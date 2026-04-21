%% Scatter
Temp1to2 = [MIDTable.Left_Mu_Wrapped, MIDTable.Right_Mu_Wrapped]';
figure; hold on;
subplot(1,2,1); hold on;
title('MT Preferred Speed')
plot([0 max(Temp1to2(:))],[0 max(Temp1to2(:))],'--k');
permed_units = randperm(size(MIDTable,1),size(MIDTable,1)); % To plot randomly rather than systematically
for ith_perm = 1:size(MIDTable,1)
    ith_unit = permed_units(ith_perm);
    criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT');
    if criteria(ith_unit)
        switch MIDTable.Z_quad(ith_unit)
            case 2
                scatter(Temp1to2(1,ith_unit),Temp1to2(2,ith_unit), 60, [0 113 188]/255, plotOptions.MonkeySymbols.(MIDTable.Monkey{ith_unit}),'filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
%             criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4;
            case 4
                scatter(Temp1to2(1,ith_unit),Temp1to2(2,ith_unit), 60, [187 20 0]/255, plotOptions.MonkeySymbols.(MIDTable.Monkey{ith_unit}),'filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
            case 1
%             criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 1;
                scatter(Temp1to2(1,ith_unit),Temp1to2(2,ith_unit), 60, 'k', plotOptions.MonkeySymbols.(MIDTable.Monkey{ith_unit}),'filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
        end
    end
end



% criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 2 & strcmp(MIDTable.Monkey,'Jim');
% scatter(Temp1to2(1,criteria),Temp1to2(2,criteria), 60, [0 113 188]/255, plotOptions.MonkeySymbols.Jim,'filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
% criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4 & strcmp(MIDTable.Monkey,'Jim');
% scatter(Temp1to2(1,criteria),Temp1to2(2,criteria), 60, [187 20 0]/255, plotOptions.MonkeySymbols.Jim,'filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
% criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 1 & strcmp(MIDTable.Monkey,'Jim');
% scatter(Temp1to2(1,criteria),Temp1to2(2,criteria), 60, 'k', plotOptions.MonkeySymbols.Jim,'filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
% 
% criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 2 & strcmp(MIDTable.Monkey,'Clay');
% scatter(Temp1to2(1,criteria),Temp1to2(2,criteria), 60, [0 113 188]/255, plotOptions.MonkeySymbols.Clay,'filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
% criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4 & strcmp(MIDTable.Monkey,'Clay');
% scatter(Temp1to2(1,criteria),Temp1to2(2,criteria), 60, [187 20 0]/255, plotOptions.MonkeySymbols.Clay,'filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
% criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 1 & strcmp(MIDTable.Monkey,'Clay');
% scatter(Temp1to2(1,criteria),Temp1to2(2,criteria), 60, 'k', plotOptions.MonkeySymbols.Clay,'filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)

xlabel('Left \mu');
ylabel('Right \mu');
plot([0:495],[0:495]+180,'--k')
plot([0:495],[0:495]-180,'--k')
axis square; box on;
xlim([0,495]);
ylim([0,495]);
xticks(0:45:495);
yticks(0:45:495);

subplot(1,2,2); hold on;
title('FST Preferred Speed')
plot([0 max(Temp1to2(:))],[0 max(Temp1to2(:))],'--k');
for ith_perm = 1:size(MIDTable,1)
    ith_unit = permed_units(ith_perm);
    criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST');
    if criteria(ith_unit)
        switch MIDTable.Z_quad(ith_unit)
            case 2
                scatter(Temp1to2(1,ith_unit),Temp1to2(2,ith_unit), 60, [0 113 188]/255, plotOptions.MonkeySymbols.(MIDTable.Monkey{ith_unit}),'filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
%             criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4;
            case 4
                scatter(Temp1to2(1,ith_unit),Temp1to2(2,ith_unit), 60, [187 20 0]/255, plotOptions.MonkeySymbols.(MIDTable.Monkey{ith_unit}),'filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
            case 1
%             criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 1;
                scatter(Temp1to2(1,ith_unit),Temp1to2(2,ith_unit), 60, 'k', plotOptions.MonkeySymbols.(MIDTable.Monkey{ith_unit}),'filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
        end
    end
end

% criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 2 & strcmp(MIDTable.Monkey,'Jim');
% scatter(Temp1to2(1,criteria),Temp1to2(2,criteria), 60, [0 113 188]/255,'filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
% criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 4 & strcmp(MIDTable.Monkey,'Jim');
% scatter(Temp1to2(1,criteria),Temp1to2(2,criteria), 60, [187 20 0]/255,'filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
% criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 1 & strcmp(MIDTable.Monkey,'Jim');
% scatter(Temp1to2(1,criteria),Temp1to2(2,criteria), 60, 'k','filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
% 
% criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 2 & strcmp(MIDTable.Monkey,'Clay');
% scatter(Temp1to2(1,criteria),Temp1to2(2,criteria), 60, [0 113 188]/255,'filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
% criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 4 & strcmp(MIDTable.Monkey,'Clay');
% scatter(Temp1to2(1,criteria),Temp1to2(2,criteria), 60, [187 20 0]/255,'filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
% criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 1 & strcmp(MIDTable.Monkey,'Clay');
% scatter(Temp1to2(1,criteria),Temp1to2(2,criteria), 60, 'k','filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
xlabel('Left \mu');
ylabel('Right \mu');
plot([0,0],[max(Temp1to2(:)),max(Temp1to2(:))],'--k');
plot([0:495],[0:495]+180,'--k')
plot([0:495],[0:495]-180,'--k')
axis square; box on;
xlim([0,495]);
ylim([0,495]);
xticks(0:45:495);
yticks(0:45:495);

%% Histograms - STACKED
bins = -190:20:190;
figure; hold on;
subplot(1,2,1); hold on;
title('MT')
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & (MIDTable.Z_quad == 2 | MIDTable.Z_quad == 4 |  MIDTable.Z_quad == 1); % All Neurons colored blue
histogram(Temp1to2(1,criteria) - Temp1to2(2,criteria),'FaceColor',[0 113 188]/255,'BinEdges',bins,'FaceAlpha',1,'EdgeColor','w')
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & (MIDTable.Z_quad == 4 |  MIDTable.Z_quad == 1);
histogram(Temp1to2(1,criteria) - Temp1to2(2,criteria),'FaceColor',[187 20 0]/255,'BinEdges',bins,'FaceAlpha',1,'EdgeColor','w')
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 1;
histogram(Temp1to2(1,criteria) - Temp1to2(2,criteria),'FaceColor','k','BinEdges',bins,'FaceAlpha',1,'EdgeColor','w')
axis square;
xlim([-190,190])
ylim([0,65]);

subplot(1,2,2); hold on;
title('FST')
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST') & (MIDTable.Z_quad == 2 | MIDTable.Z_quad == 4 |  MIDTable.Z_quad == 1);
histogram(Temp1to2(1,criteria) - Temp1to2(2,criteria),'FaceColor',[0 113 188]/255,'BinEdges',bins,'FaceAlpha',1,'EdgeColor','w')
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST') & (MIDTable.Z_quad == 4 |  MIDTable.Z_quad == 1);
histogram(Temp1to2(1,criteria) - Temp1to2(2,criteria),'FaceColor',[187 20 0]/255,'BinEdges',bins,'FaceAlpha',1,'EdgeColor','w')
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 1;
histogram(Temp1to2(1,criteria) - Temp1to2(2,criteria),'FaceColor','k','BinEdges',bins,'FaceAlpha',1,'EdgeColor','w')
axis square;
xlim([-190,190])
ylim([0,65]);


%% Stats

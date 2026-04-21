%% MT
criteria = MIDTable.sig_Anova_CLR;
% There are 6 data points with very high leverage. Remove them, but predict
% out to the same bounds as the normal model
lm = fitlm(MIDTable.LR_diff_mag(criteria & strcmp(MIDTable.ROI,'MT')),MIDTable.Z3D_v_Z2D(criteria & strcmp(MIDTable.ROI,'MT')))
% lm = fitlm(MIDTable(criteria & strcmp(MIDTable.ROI,'MT'),:), 'Z3D_v_Z2D ~ LR_diff_mag')
x = linspace(0,180,180)';
[ypred,yCI] = predict(lm,x);
figure; subplot(1,2,1); hold on;
h = plot(x,ypred,'-k');
xconf = [x; flipud(x)]';         
yconf = [yCI(:,1); flipud(yCI(:,2))]';
f = fill(xconf,yconf,'k','FaceAlpha',0.2,'LineStyle','none');
permed_units = randperm(size(MIDTable,1),size(MIDTable,1)); % To plot randomly rather than systematically
for ith_perm = 1:size(MIDTable,1)
    ith_unit = permed_units(ith_perm);
    criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT');
    if criteria(ith_unit)
        switch MIDTable.Z_quad(ith_unit)
            case 2
                scatter(MIDTable.LR_diff_mag(ith_unit),MIDTable.Z3D_v_Z2D(ith_unit), 60, [0 113 188]/255, plotOptions.MonkeySymbols.(MIDTable.Monkey{ith_unit}),'filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
%             criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4;
            case 4
                scatter(MIDTable.LR_diff_mag(ith_unit),MIDTable.Z3D_v_Z2D(ith_unit), 60, [187 20 0]/255, plotOptions.MonkeySymbols.(MIDTable.Monkey{ith_unit}),'filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
            case 1
%             criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 1;
                scatter(MIDTable.LR_diff_mag(ith_unit),MIDTable.Z3D_v_Z2D(ith_unit), 60, 'k', plotOptions.MonkeySymbols.(MIDTable.Monkey{ith_unit}),'filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
        end
    end
end
xticks([0:45:180]);
yticks([-10:5:10]);
xlim([0,180])
ylim([floor(min(MIDTable.Z3D_v_Z2D)), 10]);
legend('off');
axis square;
box on;
title('MT');

% Type II regression fits
% criteria = MIDTable.sig_Anova_CLR;
% [B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.LR_diff_mag(strcmp(MIDTable.ROI,'MT') & criteria),...
%     MIDTable.Z3D_v_Z2D(strcmp(MIDTable.ROI,'MT') & criteria))
% regress_line = x.*B(2) + B(1);
% plot(x,regress_line,'--y')

%% FST
criteria = MIDTable.sig_Anova_CLR;
lm = fitlm(MIDTable.LR_diff_mag(criteria & strcmp(MIDTable.ROI,'FST')),MIDTable.Z3D_v_Z2D(criteria & strcmp(MIDTable.ROI,'FST')))
% lm = fitlm(MIDTable(criteria & strcmp(MIDTable.ROI,'FST') & MIDTable.LR_diff_mag<95,:), 'Z3D_v_Z2D ~ LR_diff_mag') % sig regardless criteria
x = linspace(0,180,180)';
[ypred,yCI] = predict(lm,x);
subplot(1,2,2); hold on;
h = plot(lm);
h(1).Marker = 'none';
h(2).Color = 'k';
xconf = [x; flipud(x)]';         
yconf = [yCI(:,1); flipud(yCI(:,2))]';
f = fill(xconf,yconf,'k','FaceAlpha',0.2,'LineStyle','none');
h(3).Color = 'none';
h(4).Color = 'none';
permed_units = randperm(size(MIDTable,1),size(MIDTable,1)); % To plot randomly rather than systematically
for ith_perm = 1:size(MIDTable,1)
    ith_unit = permed_units(ith_perm);
    criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST');
    if criteria(ith_unit)
        switch MIDTable.Z_quad(ith_unit)
            case 2
                scatter(MIDTable.LR_diff_mag(ith_unit),MIDTable.Z3D_v_Z2D(ith_unit), 60, [0 113 188]/255, plotOptions.MonkeySymbols.(MIDTable.Monkey{ith_unit}),'filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
%             criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4;
            case 4
                scatter(MIDTable.LR_diff_mag(ith_unit),MIDTable.Z3D_v_Z2D(ith_unit), 60, [187 20 0]/255, plotOptions.MonkeySymbols.(MIDTable.Monkey{ith_unit}),'filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
            case 1
%             criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 1;
                scatter(MIDTable.LR_diff_mag(ith_unit),MIDTable.Z3D_v_Z2D(ith_unit), 60, 'k', plotOptions.MonkeySymbols.(MIDTable.Monkey{ith_unit}),'filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
        end
    end
end
legend('off');
xticks([0:45:180]);
yticks([-10:5:10]);
xlim([0,180]);
ylim([floor(min(MIDTable.Z3D_v_Z2D)), 10]);
axis square;
box on;
title('FST');

% criteria = MIDTable.sig_Anova_CLR;
% [B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.LR_diff_mag(strcmp(MIDTable.ROI,'FST') & criteria),...
%     MIDTable.Z3D_v_Z2D(strcmp(MIDTable.ROI,'FST') & criteria))
% regress_line = x.*B(2) + B(1);
% plot(x,regress_line,'--y')
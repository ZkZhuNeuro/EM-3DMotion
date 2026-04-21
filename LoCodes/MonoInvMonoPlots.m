%% Plot the monocular correlation against the inverse monocular correlation

%% Plot options

%% Plots
both_speed = LateralMotionTable.PrefSpeed(:,3); % identifies whether speed 1 or 2 is preferred
both_ind = sub2ind([length(both_speed),2],[1:length(both_speed)]',both_speed); % which index does this correspond to?
bino_eye = LateralMotionTable.both_anova_one_way(both_ind)<0.05; % Whether the neuron had significant tuning for that speed
MIDTable.Both_Mu =  LateralMotionTable.Both_Mu(both_ind); % what is the mu of the von-mises fit?

% Change angles to be only within 0 to 90
MIDTable.Obliqueness(MIDTable.Both_Mu >= 0 & MIDTable.Both_Mu < 90) = MIDTable.Both_Mu(MIDTable.Both_Mu >= 0 & MIDTable.Both_Mu < 90);
MIDTable.Obliqueness(MIDTable.Both_Mu >= 90 & MIDTable.Both_Mu < 180) = 90 - mod(MIDTable.Both_Mu(MIDTable.Both_Mu >= 90 & MIDTable.Both_Mu < 180),90);
MIDTable.Obliqueness(MIDTable.Both_Mu >= 180 & MIDTable.Both_Mu < 270) = mod(MIDTable.Both_Mu(MIDTable.Both_Mu >= 180 & MIDTable.Both_Mu < 270),90);
MIDTable.Obliqueness(MIDTable.Both_Mu >= 270 & MIDTable.Both_Mu < 360) = 90 - mod(MIDTable.Both_Mu(MIDTable.Both_Mu >= 270 & MIDTable.Both_Mu < 360),90);
% You could just use the absolute value of the sine as well...
MIDTable.Abs_Combined_AI = abs(MIDTable.Combined_AI);
MIDTable.Abs_Bino_AI = abs(MIDTable.Bino_AI);
MIDTable.Sine_Both_Mu = sind(MIDTable.Both_Mu);
MIDTable.Cosine_Both_Mu = cosd(MIDTable.Both_Mu);

bins = -1.5:0.05:1.5;
figure('Position',[300 300 700 700]);
main_sub = gca; hold on;
main_sub.Position = [0.15, 0.15, 0.55, 0.55];
axis square;

% (1) Plot all cells
plot([-1,1],[0,0],'--k');
plot([0,0],[-1,1],'--k');
% Quadrant colors
patch([0 1 1 0], [-1 -1 0 0],'g','FaceAlpha',0.2);
patch([0 1 1 0], [0 0 1 1],'y','FaceAlpha',0.2);
patch([-1 0 0 -1], [0 0 1 1],'r','FaceAlpha',0.2);
% plot([0.01 0.99 0.99 0.01 0.01], [-0.99 -0.99 -0.01 -0.01 -0.99], '-g')
% plot([0.01 0.99 0.99 0.01 0.01], [-0.99 -0.99 -0.01 -0.01 -0.99] +1, '-y')
% plot([0.01 0.99 0.99 0.01 0.01]-1, [-0.99 -0.99 -0.01 -0.01 -0.99] +1, '-r')

% Inset plots
patch([-0.9 -0.7 -0.7 -0.9], [-0.3 -0.3 -0.1 -0.1],'r','FaceAlpha',0.2);
patch([-0.9 -0.7 -0.7 -0.9], [-0.6 -0.6 -0.4 -0.4],'y','FaceAlpha',0.2);
patch([-0.9 -0.7 -0.7 -0.9], [-0.9 -0.9 -0.7 -0.7],'g','FaceAlpha',0.2);

plot([-0.9 -0.7]+0.3, [-0.3 -0.3],'-k'); plot([-0.9 -0.9]+0.3, [-0.3 -0.1],'-k');
plot([-0.9 -0.7]+0.3, [-0.3 -0.3]-0.3,'-k'); plot([-0.9 -0.9]+0.3, [-0.3 -0.1]-0.3,'-k');
plot([-0.9 -0.7]+0.3, [-0.3 -0.3]-0.6,'-k'); plot([-0.9 -0.9]+0.3, [-0.3 -0.1]-0.6,'-k');

x = 0:0.1:2;
xplot = x.*0.1 + -0.6;
func = @(k) k.^1.5;
y = (func(x))/max(func(x))*0.2 - 0.3;
yellow = ((4*(x-1).^2)/max((x+1).^2))*0.2 - 0.6;
% Red
plot(xplot,y,'-','Color',colorsteps(2,:));
plot(fliplr(xplot),y,'-','Color',colorsteps(3,:));
% Yellow
plot(xplot,yellow+0.02,'-','Color',colorsteps(2,:));
plot(xplot,yellow+0.07,'-','Color',colorsteps(3,:));
% Green
plot(xplot,y-0.6,'-','Color',colorsteps(2,:));
plot(xplot,y-0.6+0.05,'-','Color',colorsteps(3,:));

xlim([-1,1]);
ylim([-1,1]);

box on;

xlabel('3D World Motion Correlation');
ylabel('2D Retinal Motion Correlation');
xticks(-1:0.5:1);
yticks(-1:0.5:1);
xticklabels({'-1','-0.5','0','0.5','1'}');
yticklabels({'-1','-0.5','0','0.5','1'}');
legend('off')

nbins = numel(-1:0.05:1); % for marginal histograms

% X marginal histogram
% x_marg = axes('Position',[main_sub.Position(1), main_sub.Position(1)+main_sub.Position(4)+0.02, main_sub.Position(3), 0.1]); hold on;
% a(1) = histogram(MIDTable.monocular_corr_coef(strcmp(MIDTable.ROI,'MT') & MIDTable.sig_Anova_CLR),'BinWidth',0.05,'BinLimits',[-1,1],'Normalization','probability','FaceColor',plotOptions.AreaColors.MT,'EdgeColor','w');
% a(2) = histogram(MIDTable.monocular_corr_coef(strcmp(MIDTable.ROI,'FST') & MIDTable.sig_Anova_CLR),'BinWidth',0.05,'BinLimits',[-1,1],'Normalization','probability','FaceColor',plotOptions.AreaColors.FST,'EdgeColor','w');
% set(gca,'xticklabel',{[]})
% xlim([-1,1]);
% ylabel('Proportion Neurons');

% Y marginal histogram
% y_marg = axes('Position',[main_sub.Position(1)+main_sub.Position(3)+0.02, main_sub.Position(2), 0.1, main_sub.Position(4)]); hold on;
% a(1) = histogram(MIDTable.inv_monocular_corr_coef(strcmp(MIDTable.ROI,'MT') & MIDTable.sig_Anova_CLR),'BinWidth',0.05,'BinLimits',[-1,1],'Normalization','probability','FaceColor',plotOptions.AreaColors.MT,'EdgeColor','w');
% a(2) = histogram(MIDTable.inv_monocular_corr_coef(strcmp(MIDTable.ROI,'FST') & MIDTable.sig_Anova_CLR),'BinWidth',0.05,'BinLimits',[-1,1],'Normalization','probability','FaceColor',plotOptions.AreaColors.FST,'EdgeColor','w');
% set(gca,'xticklabel',{[]})
% xlim([-1,1]);
% ylabel('Proportion Neurons');
% set(gca,'view',[90 -90])

% Loop through each unit to assign proper monkey symbol and area color
clear s
axes(main_sub); hold on;
for u = 1:size(MIDTable,1)
    s = [MIDTable.sig_Anova2_Combined(u), MIDTable.sig_Anova2_MonoL(u), MIDTable.sig_Anova2_MonoR(u)];
    if all(s)
        p = scatter(MIDTable.monocular_corr_coef(u), MIDTable.inv_monocular_corr_coef(u), 50, plotOptions.AreaColors.(MIDTable.ROI{u}), plotOptions.MonkeySymbols.(MIDTable.Monkey{u}),'filled','MarkerFaceAlpha',0.6);
        row = dataTipTextRow('U',{MIDTable.Label{u}});
        p.DataTipTemplate.DataTipRows(end+1) = row;
    elseif s(1)
        p = scatter(MIDTable.monocular_corr_coef(u), MIDTable.inv_monocular_corr_coef(u), 50, plotOptions.AreaColors.(MIDTable.ROI{u}), plotOptions.MonkeySymbols.(MIDTable.Monkey{u}));
        row = dataTipTextRow('U',{MIDTable.Label{u}});
        p.DataTipTemplate.DataTipRows(end+1) = row;
    end
end

% Optional plotting of lateral motion prefs
if sum(~isnan(MIDTable.Both_Mu)) > 0 % only run if we did 2D analysis
    % Show circular means and variances for each quadrantrant
    quadrant(1).ind = find(MIDTable.monocular_corr_coef<0 & MIDTable.inv_monocular_corr_coef>0 & MIDTable.sig_Anova_CLR);
    MIDTable.quadrant(MIDTable.monocular_corr_coef>0 & MIDTable.inv_monocular_corr_coef>0) = 1; % THIS IS THE CORRECT QUADRANT-the others are technically wrong by convention but plotted correctly
    MIDTable.quadrant(MIDTable.monocular_corr_coef>0 & MIDTable.inv_monocular_corr_coef<0) = 2;
    MIDTable.quadrant(MIDTable.monocular_corr_coef<0 & MIDTable.inv_monocular_corr_coef<0) = 3;
    MIDTable.quadrant(MIDTable.monocular_corr_coef<0 & MIDTable.inv_monocular_corr_coef>0) = 4;
    quadrant(2).ind = find(MIDTable.monocular_corr_coef>0 & MIDTable.inv_monocular_corr_coef>0 & MIDTable.sig_Anova_CLR);
    quadrant(3).ind = find(MIDTable.monocular_corr_coef<0 & MIDTable.inv_monocular_corr_coef<0 & MIDTable.sig_Anova_CLR);
    quadrant(4).ind = find(MIDTable.monocular_corr_coef>0 & MIDTable.inv_monocular_corr_coef<0 & MIDTable.sig_Anova_CLR);
    
    quadrant(1).mean = mean(MIDTable.Obliqueness(quadrant(1).ind),'omitnan');
    quadrant(2).mean = mean(MIDTable.Obliqueness(quadrant(2).ind),'omitnan');
    quadrant(3).mean = mean(MIDTable.Obliqueness(quadrant(3).ind),'omitnan');
    quadrant(4).mean = mean(MIDTable.Obliqueness(quadrant(4).ind),'omitnan');
    
    quadrant(1).median = median(MIDTable.Obliqueness(quadrant(1).ind),'omitnan');
    quadrant(2).median = median(MIDTable.Obliqueness(quadrant(2).ind),'omitnan');
    quadrant(3).median = median(MIDTable.Obliqueness(quadrant(3).ind),'omitnan');
    quadrant(4).median = median(MIDTable.Obliqueness(quadrant(4).ind),'omitnan');
    
    quadrant(1).std = std(MIDTable.Obliqueness(quadrant(1).ind),'omitnan');
    quadrant(2).std = std(MIDTable.Obliqueness(quadrant(2).ind),'omitnan');
    quadrant(3).std = std(MIDTable.Obliqueness(quadrant(3).ind),'omitnan');
    quadrant(4).std = std(MIDTable.Obliqueness(quadrant(4).ind),'omitnan');
    %
%             annotation('textbox',[0.3 0.6 0.2 0.2],'String',{['M = ' num2str(quadrant(1).mean)], ['S = ' num2str(quadrant(1).std)]},'FitBoxToText','on');
%             annotation('textbox',[0.6 0.6 0.2 0.2],'String',{['M = ' num2str(quadrant(2).mean)], ['S = ' num2str(quadrant(2).std)]},'FitBoxToText','on');
%             annotation('textbox',[0.3 0.3 0.2 0.2],'String',{['M = ' num2str(quadrant(3).mean)], ['S = ' num2str(quadrant(3).std)]},'FitBoxToText','on');
%             annotation('textbox',[0.6 0.3 0.2 0.2],'String',{['M = ' num2str(quadrant(4).mean)], ['S = ' num2str(quadrant(4).std)]},'FitBoxToText','on');
end

%% Rose plots
figure;
polarhistogram(deg2rad(MIDTable.Obliqueness(MIDTable.quadrant == 1 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'MT'))),'BinWidth',deg2rad(9),'Normalization','probability','FaceColor',plotOptions.AreaColors.MT,'EdgeColor','w')
hold on;
polarhistogram(deg2rad(MIDTable.Obliqueness(MIDTable.quadrant == 1 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'FST'))),'BinWidth',deg2rad(9),'Normalization','probability','FaceColor',plotOptions.AreaColors.FST,'EdgeColor','w')
title('Yellow')

figure;
polarhistogram(deg2rad(MIDTable.Obliqueness(MIDTable.quadrant == 4 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'MT'))),'BinWidth',deg2rad(9),'Normalization','probability','FaceColor',plotOptions.AreaColors.MT,'EdgeColor','w')
hold on;
polarhistogram(deg2rad(MIDTable.Obliqueness(MIDTable.quadrant == 4 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'FST'))),'BinWidth',deg2rad(9),'Normalization','probability','FaceColor',plotOptions.AreaColors.FST,'EdgeColor','w')
title('Red')

figure;
polarhistogram(deg2rad(MIDTable.Obliqueness(MIDTable.quadrant == 2 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'MT'))),'BinWidth',deg2rad(9),'Normalization','probability','FaceColor',plotOptions.AreaColors.MT,'EdgeColor','w')
hold on;
polarhistogram(deg2rad(MIDTable.Obliqueness(MIDTable.quadrant == 2 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'FST'))),'BinWidth',deg2rad(9),'Normalization','probability','FaceColor',plotOptions.AreaColors.FST,'EdgeColor','w')
title('Green')

% means for yellow and red quadrants
mean(MIDTable.Obliqueness(MIDTable.quadrant == 1 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'MT')))
mean(MIDTable.Obliqueness(MIDTable.quadrant == 1 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'FST')))
mean(MIDTable.Obliqueness(MIDTable.quadrant == 1 & MIDTable.sig_Anova_CLR & bino_eye))

mean(MIDTable.Obliqueness(MIDTable.quadrant == 2 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'MT')))
mean(MIDTable.Obliqueness(MIDTable.quadrant == 2 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'FST')))
mean(MIDTable.Obliqueness(MIDTable.quadrant == 2 & MIDTable.sig_Anova_CLR & bino_eye))

mean(MIDTable.Obliqueness(MIDTable.quadrant == 4 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'MT')))
mean(MIDTable.Obliqueness(MIDTable.quadrant == 4 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'FST')))
mean(MIDTable.Obliqueness(MIDTable.quadrant == 4 & MIDTable.sig_Anova_CLR & bino_eye))

% proportions with 2D selectivity
sum(MIDTable.quadrant == 1 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'MT'))/sum(MIDTable.quadrant == 1 & MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT'))
sum(MIDTable.quadrant == 1 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'FST'))/sum(MIDTable.quadrant == 1 & MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST'))
sum(MIDTable.quadrant == 1 & MIDTable.sig_Anova_CLR & bino_eye)/sum(MIDTable.quadrant == 1 & MIDTable.sig_Anova_CLR)

sum(MIDTable.quadrant == 2 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'MT'))/sum(MIDTable.quadrant == 2 & MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT'))
sum(MIDTable.quadrant == 2 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'FST'))/sum(MIDTable.quadrant == 2 & MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST'))
sum(MIDTable.quadrant == 2 & MIDTable.sig_Anova_CLR & bino_eye)/sum(MIDTable.quadrant == 2 & MIDTable.sig_Anova_CLR)

sum(MIDTable.quadrant == 4 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'MT'))/sum(MIDTable.quadrant == 4 & MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT'))
sum(MIDTable.quadrant == 4 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'FST'))/sum(MIDTable.quadrant == 4 & MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST'))
sum(MIDTable.quadrant == 4 & MIDTable.sig_Anova_CLR & bino_eye)/sum(MIDTable.quadrant == 4 & MIDTable.sig_Anova_CLR)

% are the means significantly different from eachother?
% Yellow vs red
ranksum(MIDTable.Obliqueness(MIDTable.quadrant == 1 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'MT')),...
    MIDTable.Obliqueness(MIDTable.quadrant == 4 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'MT')))
ranksum(MIDTable.Obliqueness(MIDTable.quadrant == 1 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'FST')),...
    MIDTable.Obliqueness(MIDTable.quadrant == 4 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'FST')))
ranksum(MIDTable.Obliqueness(MIDTable.quadrant == 1 & MIDTable.sig_Anova_CLR & bino_eye),...
    MIDTable.Obliqueness(MIDTable.quadrant == 4 & MIDTable.sig_Anova_CLR & bino_eye))

% Yellow vs red & green combined
ranksum(MIDTable.Obliqueness(MIDTable.quadrant == 1 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'MT')),...
    MIDTable.Obliqueness(MIDTable.quadrant ~= 1 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'MT')))
ranksum(MIDTable.Obliqueness(MIDTable.quadrant == 1 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'FST')),...
    MIDTable.Obliqueness(MIDTable.quadrant ~= 1 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'FST')))
ranksum(MIDTable.Obliqueness(MIDTable.quadrant == 1 & MIDTable.sig_Anova_CLR & bino_eye),...
    MIDTable.Obliqueness(MIDTable.quadrant ~= 1 & MIDTable.sig_Anova_CLR & bino_eye))

figure; hold on;
subplot(1,4,1);
histogram(MIDTable.Obliqueness(MIDTable.quadrant == 1 & MIDTable.sig_Anova_CLR & bino_eye),'BinWidth',10,'normalization','probability','FaceColor','y')
subplot(1,4,2);
histogram(MIDTable.Obliqueness(MIDTable.quadrant == 2 & MIDTable.sig_Anova_CLR & bino_eye),'BinWidth',10,'normalization','probability','FaceColor','g')
subplot(1,4,3);
histogram(MIDTable.Obliqueness(MIDTable.quadrant == 4 & MIDTable.sig_Anova_CLR & bino_eye),'BinWidth',10,'normalization','probability','FaceColor','r')
subplot(1,4,4);
histogram(MIDTable.Obliqueness(MIDTable.quadrant ~= 1 & MIDTable.sig_Anova_CLR & bino_eye),'BinWidth',10,'normalization','probability','FaceColor','k')

% are the means significantly different from 45 deg
p = signtest(MIDTable.Obliqueness(MIDTable.quadrant == 1 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'MT')), 45)
p = signtest(MIDTable.Obliqueness(MIDTable.quadrant == 2 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'MT')), 45)
p = signtest(MIDTable.Obliqueness(MIDTable.quadrant == 4 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'MT')), 45)
p = signtest(MIDTable.Obliqueness(MIDTable.quadrant == 1 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'FST')), 45)
p = signtest(MIDTable.Obliqueness(MIDTable.quadrant == 2 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'FST')), 45)
p = signtest(MIDTable.Obliqueness(MIDTable.quadrant == 4 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'FST')), 45)
p = signtest(MIDTable.Obliqueness(MIDTable.quadrant == 1 & MIDTable.sig_Anova_CLR & bino_eye), 45)
p = signtest(MIDTable.Obliqueness(MIDTable.quadrant == 2 & MIDTable.sig_Anova_CLR & bino_eye), 45)
p = signtest(MIDTable.Obliqueness(MIDTable.quadrant == 4 & MIDTable.sig_Anova_CLR & bino_eye), 45)

lm = fitlm(MIDTable(MIDTable.sig_Anova2_Combined & bino_eye & MIDTable.quadrant ~= 3,:),'Obliqueness ~ quadrant');
[a1_oblique_p,~,a1_oblique_stats] = anova1(MIDTable.Obliqueness(MIDTable.sig_Anova2_Combined & bino_eye & MIDTable.quadrant ~= 3 & strcmp(MIDTable.ROI,'MT')),MIDTable.quadrant(MIDTable.sig_Anova2_Combined & bino_eye & MIDTable.quadrant ~= 3 & strcmp(MIDTable.ROI,'MT')))
multcompare(a1_oblique_stats)
[a1_oblique_p,~,a1_oblique_stats] = anova1(MIDTable.Obliqueness(MIDTable.sig_Anova2_Combined & bino_eye & MIDTable.quadrant ~= 3 & strcmp(MIDTable.ROI,'FST')),MIDTable.quadrant(MIDTable.sig_Anova2_Combined & bino_eye & MIDTable.quadrant ~= 3 & strcmp(MIDTable.ROI,'FST')))
multcompare(a1_oblique_stats)

ranksum(MIDTable.Monocularity_Mag(MIDTable.quadrant == 1 & MIDTable.sig_Anova_CLR), MIDTable.Monocularity_Mag(MIDTable.quadrant ~= 1 & MIDTable.sig_Anova_CLR))

% DI comparisons
% MIDTable.DI_LRvUD = (LateralMotionTable.DI_LR_both(both_ind)-LateralMotionTable.DI_UD_both(both_ind))./(LateralMotionTable.DI_LR_both(both_ind)+LateralMotionTable.DI_UD_both(both_ind));
% 
% figure; subplot(3,1,1); hold on;
% a(1) = histogram(MIDTable.DI_LRvUD(MIDTable.quadrant == 1 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'MT')),'BinWidth',0.1,'BinLimits',[-1,1],'Normalization','probability','FaceColor',plotOptions.AreaColors.MT,'EdgeColor','w');
% a(2) = histogram(MIDTable.DI_LRvUD(MIDTable.quadrant == 1 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'FST')),'BinWidth',0.1,'BinLimits',[-1,1],'Normalization','probability','FaceColor',plotOptions.AreaColors.FST,'EdgeColor','w');
% title('Yellow');
% 
% subplot(3,1,2); hold on;
% a(1) = histogram(MIDTable.DI_LRvUD(MIDTable.quadrant == 4 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'MT')),'BinWidth',0.1,'BinLimits',[-1,1],'Normalization','probability','FaceColor',plotOptions.AreaColors.MT,'EdgeColor','w');
% a(2) = histogram(MIDTable.DI_LRvUD(MIDTable.quadrant == 4 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'FST')),'BinWidth',0.1,'BinLimits',[-1,1],'Normalization','probability','FaceColor',plotOptions.AreaColors.FST,'EdgeColor','w');
% title('Red');
% 
% subplot(3,1,3); hold on;
% a(1) = histogram(MIDTable.DI_LRvUD(MIDTable.quadrant == 2 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'MT')),'BinWidth',0.1,'BinLimits',[-1,1],'Normalization','probability','FaceColor',plotOptions.AreaColors.MT,'EdgeColor','w');
% a(2) = histogram(MIDTable.DI_LRvUD(MIDTable.quadrant == 2 & MIDTable.sig_Anova_CLR & bino_eye & strcmp(MIDTable.ROI,'FST')),'BinWidth',0.1,'BinLimits',[-1,1],'Normalization','probability','FaceColor',plotOptions.AreaColors.FST,'EdgeColor','w');
% title('Green');




%% calculate type II error dist
% This would be a top corner histogram measuring geometric distance from neg. identity line
vec = [-1,1;1 -1];
p_MT = proj(vec,[MIDTable.monocular_corr_coef(strcmp(MIDTable.ROI,'MT') & MIDTable.sig_Anova_CLR), MIDTable.inv_monocular_corr_coef(strcmp(MIDTable.ROI,'MT') & MIDTable.sig_Anova_CLR)]);
p_FST = proj(vec,[MIDTable.monocular_corr_coef(strcmp(MIDTable.ROI,'FST') & MIDTable.sig_Anova_CLR), MIDTable.inv_monocular_corr_coef(strcmp(MIDTable.ROI,'FST') & MIDTable.sig_Anova_CLR)]);
d_MT = -sign(p_MT(:,1)).*sqrt(p_MT(:,1).^2 + p_MT(:,2).^2);
d_FST = -sign(p_FST(:,1)).*sqrt(p_FST(:,1).^2 + p_FST(:,2).^2);
d_MT = d_MT./sqrt(2);
d_FST = d_FST./sqrt(2);

% d_MT = point2line([1,0],MIDTable.monocular_corr_coef(strcmp(MIDTable.ROI,'MT') & MIDTable.sig_Anova_CLR), MIDTable.inv_monocular_corr_coef(strcmp(MIDTable.ROI,'MT') & MIDTable.sig_Anova_CLR));
% d_FST = point2line([1,0],MIDTable.monocular_corr_coef(strcmp(MIDTable.ROI,'FST') & MIDTable.sig_Anova_CLR), MIDTable.inv_monocular_corr_coef(strcmp(MIDTable.ROI,'FST') & MIDTable.sig_Anova_CLR));
figure; hold on;
a(1) = histogram(-d_MT,'BinWidth',0.1,'BinLimits',[-1,1],'Normalization','probability','FaceColor',plotOptions.AreaColors.MT,'EdgeColor','w');
a(2) = histogram(-d_FST,'BinWidth',0.1,'BinLimits',[-1,1],'Normalization','probability','FaceColor',plotOptions.AreaColors.FST,'EdgeColor','w');
xlabel('2D <-- Distance from Identity --> 3D');
ylabel('Proportion of Neurons');
xlim([-1,1]);

%% Histogram of monocular correlation
% figure; hold on;
% histogram(MIDTable.monocular_corr_coef(strcmp(MIDTable.ROI,'MT') & MIDTable.sig_Anova2_Combined),'BinWidth',0.05,'BinLimits',[-1,1],'Normalization','probability','FaceColor',plotOptions.AreaColors.MT,'EdgeColor','w')
% histogram(MIDTable.monocular_corr_coef(strcmp(MIDTable.ROI,'FST') & MIDTable.sig_Anova2_Combined),'BinWidth',0.05,'BinLimits',[-1,1],'Normalization','probability','FaceColor',plotOptions.AreaColors.FST,'EdgeColor','w')
% legend({'MT','FST'});

%% AI
% if ~exist('l_r_ai_all') || ~ishandle(l_r_ai_all)
%     l_r_ai_all = figure; hold on; set(gcf,'Tag','l_r_ai_all');
%     % Quadrant colors
%     patch([0 1 1 0], [-1 -1 0 0],'r','FaceAlpha',0.3);
%     patch([0 1 1 0], [0 0 1 1],'g','FaceAlpha',0.3);
%     patch([-1 0 0 -1], [0 0 1 1],'r','FaceAlpha',0.3);
%     patch([-1 0 0 -1], [-1 -1 0 0],'g','FaceAlpha',0.3);
% else
%     figure(l_r_ai_all);
% end
% hold on;
% 
% colormap('gray');
% p(1) = scatter(MIDTable.MonoL_AI(~MIDTable.sig_Anova2_Combined), MIDTable.MonoR_AI(~MIDTable.sig_Anova2_Combined), 50, abs(MIDTable.Combined_AI(~MIDTable.sig_Anova2_Combined)),plotOptions.MonkeySymbols.(MIDTable.Monkey{1})); % Significant in both
% p(2) = scatter(MIDTable.MonoL_AI(MIDTable.sig_Anova2_Combined), MIDTable.MonoR_AI(MIDTable.sig_Anova2_Combined), 50, abs(MIDTable.Combined_AI(MIDTable.sig_Anova2_Combined)),'filled',plotOptions.MonkeySymbols.(MIDTable.Monkey{1})); % Significant in both
% lims = axis;
% axis square;
% box on;
% plot([-1,1],[0,0],'--k');
% plot([0,0],[-1,1],'--k');
% xticks(-1:0.5:1);
% yticks(-1:0.5:1);
% xticklabels({'-1','-0.5','0','0.5','1'}');
% yticklabels({'-1','-0.5','0','0.5','1'}');
% xlabel('Left Eye AI');
% ylabel('Right Eye AI');
% p(1).DataTipTemplate.DataTipRows(end+1) = dataTipTextRow('U',MIDTable.Label(~MIDTable.sig_Anova2_Combined));
% p(2).DataTipTemplate.DataTipRows(end+1) = dataTipTextRow('U',MIDTable.Label(MIDTable.sig_Anova2_Combined));
% cb = colorbar;
% cb.Label.String = '| Combined AI |';
% 
% set(gcf,'Position',[100 100 700 400]);
%%
function [ProjPoint] = proj(vector, q)
p0 = vector(1,:);
p1 = vector(2,:);
a = [-q(:,1).*(p1(1)-p0(1)) - q(:,2).*(p1(2)-p0(2)), ...
    repmat(-p0(2).*(p1(1)-p0(1)) + p0(1).*(p1(2)-p0(2)),size(q,1),1)];
b = [p1(1) - p0(1), p1(2) - p0(2);...
    p0(2) - p1(2), p1(1) - p0(1)];
ProjPoint = -(b\a')';
end
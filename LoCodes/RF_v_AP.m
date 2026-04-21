% Make a color map for each area based on anatomical location
RFData.AP = MIDTable.Hole(:,2);
RFData.ML = abs(MIDTable.Hole(:,1)); % take abs to make it independent of hemisphere
RFData.APxML = table2array(rowfun(@(x) norm(x),table(RFTable.Hole)));
Jim_MT = strcmp(RFTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Jim');
Jim_FST = strcmp(RFTable.ROI,'FST')& strcmp(MIDTable.Monkey,'Jim');
% Holes for each possibility of area and measurment type (AP,ML,norm)
Jim_MT_AP = unique(RFData.AP(Jim_MT));
Jim_FST_AP = unique(RFData.AP(Jim_FST));
% Now get a colormap based on these values
Jim_MT_AP_map = cool(length(Jim_MT_AP));
Jim_FST_AP_map = spring(length(Jim_FST_AP));
Clay_MT = strcmp(RFTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Clay');
Clay_FST = strcmp(RFTable.ROI,'FST')& strcmp(MIDTable.Monkey,'Clay');
Clay_MT_AP = unique(RFData.AP(Clay_MT));
Clay_FST_AP = unique(RFData.AP(Clay_FST));
% Now get a colormap based on these values
Clay_MT_AP_map = cool(length(Clay_MT_AP));
Clay_FST_AP_map = spring(length(Clay_FST_AP));

f_MT = figure; hold on;
f_MT.Renderer = 'Painters';
colormap('cool');
subplt = @(m,n,p) subtightplot(m,n,p,0.07,[0.05 0.05],[0.05 0.05]);
% f_FST = figure; hold on;
% colormap(FST_map);

% Permute the plotting so that you don't get arbitary recording day
% clusters
permuted_units = randperm(size(RFData,1),size(RFData,1));
for i = 1:size(RFData,1)
    u = permuted_units(i);
    if strcmp(RFTable.ROI(u),'MT')
        %         figure(f_MT); hold on;
        if strcmp(MIDTable.Monkey(u),'Jim')
            subplt(1,2,1); hold on;
            p = scatter(RFData.Eccentricity_Deg(u), RFData.SqrtRFArea(u), 30, Jim_MT_AP_map(find(Jim_MT_AP == abs(RFTable.Hole(u,2))),:), plotOptions.MonkeySymbols.(MIDTable.Monkey{u}),'filled','MarkerEdgeColor','k');
        else
            subplt(1,2,1); hold on;
            p = scatter(RFData.Eccentricity_Deg(u), RFData.SqrtRFArea(u), 30, Clay_MT_AP_map(find(Clay_MT_AP == abs(RFTable.Hole(u,2))),:), plotOptions.MonkeySymbols.(MIDTable.Monkey{u}),'filled','MarkerEdgeColor','k');        
        end
    else
        %         figure(f_FST); hold on;
        subplt(1,2,2); hold on;
        if strcmp(MIDTable.Monkey(u),'Jim')
            subplt(1,2,2); hold on;
            p = scatter(RFData.Eccentricity_Deg(u), RFData.SqrtRFArea(u), 30, Jim_FST_AP_map(find(Jim_FST_AP == abs(RFTable.Hole(u,2))),:), plotOptions.MonkeySymbols.(MIDTable.Monkey{u}),'filled','MarkerEdgeColor','k');
        else
            subplt(1,2,2); hold on;
            p = scatter(RFData.Eccentricity_Deg(u), RFData.SqrtRFArea(u), 30, Clay_FST_AP_map(find(Clay_FST_AP == abs(RFTable.Hole(u,2))),:), plotOptions.MonkeySymbols.(MIDTable.Monkey{u}),'filled','MarkerEdgeColor','k');
            
        end
    end
    row = dataTipTextRow('U',{MIDTable.Label{u}});
    p.DataTipTemplate.DataTipRows(end+1) = row;
end
clear s
figure(f_MT);

s(1) = subplt(1,2,1); hold on
colormap(s(1),cool(1000));
title('MT: AP');
c = colorbar('TickLabels',{'P,','A'});
c.Ticks = c.Ticks([1,end]);
c.Label.String = [{'Closer to FST-->'}];

s(2) = subplt(1,2,2); hold on;
colormap(s(2),spring(1000));
title('FST: AP');
c = colorbar('TickLabels',{'P,','A'});
c.Ticks = c.Ticks([1,end]);
c.Label.String = [{'<--Closer to MT'}];

% Fit lines for each location
for n_area = 1:size(areas,2)
    
    a = areas(n_area);
    figure(f_MT);
    
    %     if strcmp(a,"MT")
    %         figure(f_MT); hold on;
    %     else
    %         figure(f_FST); hold on;
    %     end
    lims = axis;
    x = [min(lims):0.1:max(lims)];
    areaTable = AllMonkeyMIDTable(strcmp(a,AllMonkeyMIDTable.ROI),:);
    areaRFTable = AllRFTable(strcmp(a,AllMonkeyMIDTable.ROI),:);
    areaRFData = AllRFData(strcmp(a,AllMonkeyMIDTable.ROI),:);
    [B(2),B(1)] = regress_perp(areaRFData.Eccentricity_Deg,areaRFData.SqrtRFArea);
    regress_line = x.*B(2) + B(1);
    legend_label = [char(a) ' \surd A = ' num2str(round(B(2),2)) '*E + ' num2str(round(B(1),2))];
    axes(s(n_area)); hold on;
    l = plot(x,regress_line','-','LineWidth',2,'Color',plotOptions.AreaColors.(a));
    plot([min(lims) max(lims)], [min(lims) max(lims)], '--k');
    axis([0 max(lims) 0 max(lims)]);
    xlabel('Eccentricity (deg)');
    ylabel('\surd Area','Interpreter','tex');
    axis square;
    box on;
    legend(l,legend_label);
end

%% Run separately for each area & monkey
Jim_MT = RFData(strcmp(RFTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Jim'),:);
Jim_FST = RFData(strcmp(RFTable.ROI,'FST')& strcmp(MIDTable.Monkey,'Jim'),:);
Clay_MT = RFData(strcmp(RFTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Clay'),:);
Clay_FST = RFData(strcmp(RFTable.ROI,'FST')& strcmp(MIDTable.Monkey,'Clay'),:);
% RF_size ~ Ecc + area + random monkey'
fprintf(2,'\nJim MT\n')
anova(fitlme(Jim_MT,'SqrtRFArea ~ Eccentricity_Deg'))
fprintf(2,'\nJim FST\n')
anova(fitlme(Jim_FST,'SqrtRFArea ~ Eccentricity_Deg'))

fprintf(2,'\nClay MT\n')
anova(fitlme(Clay_MT,'SqrtRFArea ~ Eccentricity_Deg'))
fprintf(2,'\nClay FST\n')
anova(fitlme(Clay_FST,'SqrtRFArea ~ Eccentricity_Deg'))

% RF_size ~ AP + area + random monkey
fprintf(2,'\nJim MT\n')
anova(fitlme(Jim_MT,'SqrtRFArea ~ AP'))
fprintf(2,'\nJim FST\n')
anova(fitlme(Jim_FST,'SqrtRFArea ~ AP'))

fprintf(2,'\nClay MT\n')
anova(fitlme(Clay_MT,'SqrtRFArea ~ AP'))
fprintf(2,'\nClay FST\n')
anova(fitlme(Clay_FST,'SqrtRFArea ~ AP'))



%% Run separately for each area
RFData.Monkey = strcmp(MIDTable.Monkey,'Clay');
RFData.Monkey = RFData.Monkey - 0.5;
MT = RFData(strcmp(RFTable.ROI,'MT'),:);
FST = RFData(strcmp(RFTable.ROI,'FST'),:);
RFData.AreaCode = strcmp(MIDTable.ROI,'FST');
RFData.AreaCode = RFData.AreaCode - 0.5;

%% Run for all areas
fprintf(2,'Interaction Model')
lm = fitlme(RFData,'SqrtRFArea ~ Eccentricity_Deg*AreaCode')
anova(lm)
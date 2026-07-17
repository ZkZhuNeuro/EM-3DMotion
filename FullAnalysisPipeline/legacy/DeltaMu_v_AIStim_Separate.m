b_ax = figure;
quad_colors = [0 0 0;... % Unclassified
    0 113 188;... % 3D
    NaN NaN NaN;... % not applicable
    187 20 0]/255; % 2D

colors_Z3D = [zeros(1000,1), linspace(0, 113, 1000)', linspace(0, 188, 1000)']./255;
colors_Z2D = flipud([linspace(0, 187, 1000)', linspace(0, 20, 1000)', zeros(1000,1)]./255);
colors_Z3DvsZ2D = [colors_Z2D; colors_Z3D];

plotOptions.AreaSymbols.MT = 'd';
plotOptions.AreaSymbols.FST = 'o';

criteria = MIDTable.anova2_Combined< 0.05;
for rec = 1:size(MIDTable,1)
    figure(b_ax); hold on;
    if criteria(rec)
        for c = 1:size(delta_bias,2)
            %         if MIDTable.Z_CvR_v_Z_CvL(rec)>0 && (c == 2 || c ==3)
            %         if weighted_monocularity(rec)>0 && (c == 2 || c ==3)
            if  strcmp(Eye(rec,MIDTable.StimElec(rec)),'R') && (c == 2 || c ==3) % right eye dominant
                if c == 2 % Left eye condition - plot in non-dominant subplot
                    subplot(2,2,3); hold on;
                    sc = scatter(AI(rec,c,MIDTable.StimElec(rec)),delta_bias(rec,c),40,abs(MIDTable.Monocularity(rec)),'filled','MarkerEdgeColor','none'); %quad_colors(MIDTable.Z_quad(rec),:));
%                     sc.MarkerFaceAlpha = abs(MIDTable.Z3D_v_Z2D(rec))./max(abs(MIDTable.Z3D_v_Z2D));
                    sc.MarkerEdgeAlpha = 1;
                    sc.Marker = plotOptions.AreaSymbols.(MIDTable.ROI{rec});
                else % right eye condition - plot in dominant subplot
                    subplot(2,2,2); hold on;
                    sc = scatter(AI(rec,c,MIDTable.StimElec(rec)),delta_bias(rec,c),40,abs(MIDTable.Monocularity(rec)),'filled','MarkerEdgeColor','none'); %quad_colors(MIDTable.Z_quad(rec),:));
%                     sc.MarkerFaceAlpha = abs(MIDTable.Z3D_v_Z2D(rec))./max(abs(MIDTable.Z3D_v_Z2D));
                    sc.MarkerEdgeAlpha = 1;
                    sc.Marker = plotOptions.AreaSymbols.(MIDTable.ROI{rec});
                end
            else
                subplot(2,2,c); hold on;
                if c == 1
                    sc = scatter(AI(rec,c,MIDTable.StimElec(rec)),delta_bias(rec,c),40,abs(MIDTable.Monocularity(rec)),'filled','MarkerEdgeColor','none'); %quad_colors(MIDTable.Z_quad(rec),:));
%                     sc.MarkerFaceAlpha = abs(MIDTable.Z3D_v_Z2D(rec))./max(abs(MIDTable.Z3D_v_Z2D));
                    sc.MarkerEdgeAlpha = 1;
                    sc.Marker = plotOptions.AreaSymbols.(MIDTable.ROI{rec});
                elseif c == 2
                    sc = scatter(AI(rec,c,MIDTable.StimElec(rec)),delta_bias(rec,c),40,abs(MIDTable.Monocularity(rec)),'filled','MarkerEdgeColor','none'); %quad_colors(MIDTable.Z_quad(rec),:));
%                     sc.MarkerFaceAlpha = abs(MIDTable.Z3D_v_Z2D(rec))./max(abs(MIDTable.Z3D_v_Z2D));
                    sc.MarkerEdgeAlpha = 1;
                    sc.Marker = plotOptions.AreaSymbols.(MIDTable.ROI{rec});
                elseif c == 3
                    sc = scatter(AI(rec,c,MIDTable.StimElec(rec)),delta_bias(rec,c),40,abs(MIDTable.Monocularity(rec)),'filled','MarkerEdgeColor','none'); %quad_colors(MIDTable.Z_quad(rec),:));
%                     sc.MarkerFaceAlpha = abs(MIDTable.Z3D_v_Z2D(rec))./max(abs(MIDTable.Z3D_v_Z2D));
                    sc.MarkerEdgeAlpha = 1;
                    sc.Marker = plotOptions.AreaSymbols.(MIDTable.ROI{rec});
                elseif c == 4
                    sc = scatter(AI(rec,c,MIDTable.StimElec(rec)),delta_bias(rec,c),40,abs(MIDTable.Monocularity(rec)),'filled','MarkerEdgeColor','none'); %quad_colors(MIDTable.Z_quad(rec),:));
%                     sc.MarkerFaceAlpha = abs(MIDTable.Z3D_v_Z2D(rec))./max(abs(MIDTable.Z3D_v_Z2D));   %abs(MIDTable.Monocularity(rec))/max(abs(MIDTable.Monocularity));
                    sc.MarkerEdgeAlpha = 1;
                    sc.Marker = plotOptions.AreaSymbols.(MIDTable.ROI{rec});
                end
                
                %             plot(AI(rec,c,MIDTable.StimElec(rec)),delta_bias(rec,c),'o','MarkerFaceColor',colorsteps(c,:),'MarkerEdgeColor',rec_map(rec,:),'LineWidth',2,'MarkerSize',10);
            end
            row = dataTipTextRow('wCI: ',{num2str(round(sc.CData,2))});
            sc.DataTipTemplate.DataTipRows(end+1) = row;
            row = dataTipTextRow('D: ',{datestr(MIDTable.Date(rec))});
            sc.DataTipTemplate.DataTipRows(end+1) = row;
        end
    end
end

%% Type II Regression
criteria = MIDTable.anova2_Combined < 0.05;
x = [-1:0.1:1];
% Fit and plot type II regression lines
[B(2),B(1)] = regress_perp(MIDTable.Combined_AI(criteria), MIDTable.Delta_Mu_Combined(criteria));
regress_line = x.*B(2) + B(1);
subplot(2,2,1); hold on;
plot(x,regress_line,'-','Color',colorsteps(1,:));

[B(2),B(1)] = regress_perp(MIDTable.Dominant_AI(criteria), MIDTable.Dominant_Delta(criteria));
regress_line = x.*B(2) + B(1);
subplot(2,2,2); hold on;
plot(x,regress_line,'-','Color',colorsteps(2,:));

[B(2),B(1)] = regress_perp(MIDTable.Non_Dominant_AI(criteria), MIDTable.Non_Dominant_Delta(criteria));
regress_line = x.*B(2) + B(1);
subplot(2,2,3); hold on;
plot(x,regress_line,'-','Color',colorsteps(3,:));

[B(2),B(1)] = regress_perp(MIDTable.Stereo_AI(criteria), MIDTable.Delta_Mu_Stereo(criteria));
regress_line = x.*B(2) + B(1);
subplot(2,2,4); hold on;
plot(x,regress_line,'-','Color',colorsteps(4,:));

%% Plot labels
subplot(2,2,1); hold on;
% colormap('cool')
% c = colorbar();
% caxis([-0.4, 0.4]);
% c.Limits = [-0.4, 0.4];
% c.Label.String = 'Cue wCI';
title('Combined');
xlabel('Stim Electrode AI')
ylabel('Delta Bias')
axis square;
box on;
xlim([-1,1]);
ylim([-max(abs(delta_bias(:))),max(abs(delta_bias(:)))]);
plot([0, 0], [-1.5,1.5],'--k')
plot([-1,1],[0, 0], '--k');
c = colorbar();
% if MIDTable.Z3D_v_Z2D(1)>0
%     colormap(colors_Z3D);
%     c.Limits = [0,max(abs(MIDTable.Z3D_v_Z2D))];
% 
% else
%     colormap(colors_Z2D);
%     c.Limits = [-max(abs(MIDTable.Z3D_v_Z2D)),0];
% 
% end
% colormap(colors_Z3DvsZ2D);

subplot(2,2,2); hold on;
% colormap('cool')
% c = colorbar();
% caxis([-0.4, 0.4]);
% % c.Limits = [-0.4, 0.4];
% c.Label.String = 'Cue wCI';
title('Dominant');
xlabel('Stim Electrode AI')
ylabel('Delta Bias')
axis square;
box on;
xlim([-1,1]);
ylim([-max(abs(delta_bias(:))),max(abs(delta_bias(:)))]);
plot([0, 0], [-max(abs(delta_bias(:))),max(abs(delta_bias(:)))],'--k')
plot([-1,1],[0, 0], '--k');
c = colorbar();
% if MIDTable.Z3D_v_Z2D(1)>0
%     colormap(colors_Z3D);
%     c.Limits = [0,max(abs(MIDTable.Z3D_v_Z2D))];
% 
% else
%     colormap(colors_Z2D);
%     c.Limits = [-max(abs(MIDTable.Z3D_v_Z2D)),0];
% 
% end
% colormap(colors_Z3DvsZ2D);

subplot(2,2,3); hold on;
% colormap('cool')
% c = colorbar();
% caxis([-0.4, 0.4]);
% % c.Limits = [-0.4, 0.4];
% c.Label.String = 'Cue wCI';
title('Non-Dominant');
xlabel('Stim Electrode AI')
ylabel('Delta Bias')
axis square;
box on;
xlim([-1,1]);
ylim([-max(abs(delta_bias(:))),max(abs(delta_bias(:)))]);
plot([0, 0], [-max(abs(delta_bias(:))),max(abs(delta_bias(:)))],'--k')
plot([-1,1],[0, 0], '--k');
c = colorbar();
% if MIDTable.Z3D_v_Z2D(1)>0
%     colormap(colors_Z3D);
%     c.Limits = [0,max(abs(MIDTable.Z3D_v_Z2D))];
% 
% else
%     colormap(colors_Z2D);
%     c.Limits = [-max(abs(MIDTable.Z3D_v_Z2D)),0];
% 
% end
% colormap(colors_Z3DvsZ2D);

subplot(2,2,4); hold on;
% colormap('cool')
% c = colorbar();
% caxis([-0.4, 0.4]);
% % c.Limits = [-0.4, 0.4];
% c.Label.String = 'Cue wCI';
title('Stereoscopic');
xlabel('Stim Electrode AI')
ylabel('Delta Bias')
axis square;
box on;
xlim([-1,1]);
ylim([-max(abs(delta_bias(:))),max(abs(delta_bias(:)))]);
plot([0, 0], [-max(abs(delta_bias(:))),max(abs(delta_bias(:)))],'--k')
plot([-1,1],[0, 0], '--k');
c = colorbar();
% if MIDTable.Z3D_v_Z2D(1)>0
%     colormap(colors_Z3D);
%     c.Limits = [0,max(abs(MIDTable.Z3D_v_Z2D))];
% 
% else
%     colormap(colors_Z2D);
%     c.Limits = [-max(abs(MIDTable.Z3D_v_Z2D)),0];
% 
% end
% colormap(colors_Z3DvsZ2D);

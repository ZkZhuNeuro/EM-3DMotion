%% Important plots on a session-by session basis
% 1) tuning at the stimulation site
% 2) behavioral performance in non-stimulation trials
% 3) behavioral performance for stimulation trials
% 4) Clustering plots are useful
b_ax = figure;
rec_map = winter(size(MIDTable,1));
BiasTable = table(); %cell2table(cell(0,5),'VariableNames', {'AI','DeltaBias','Condition','wCI','ROI'});
for rec = 1:size(MIDTable,1)
    figure(b_ax); hold on;
    if MIDTable.anova2_Combined(rec) < 0.05
        for c = 1:size(delta_bias,2)
            if  strcmp(Eye(rec,MIDTable.StimElec(rec)),'R') && (c == 2 || c ==3) % weighted_monocularity(rec)>0 && (c == 2 || c ==3) right eye dominant
                if c == 2 % Left eye condition - plot in non-dominant subplot
                    %                 subplot(2,2,3); hold on;
                    sc = scatter(AI(rec,c,MIDTable.StimElec(rec)),delta_bias(rec,c),40,colorsteps(3,:),'filled');
                    %                 plot(AI(rec,3,MIDTable.StimElec(rec)),delta_bias(rec,3),'o','MarkerFaceColor',colorsteps(c,:),'MarkerEdgeColor',rec_map(rec,:),'LineWidth',2,'MarkerSize',10);
                else % right eye condition - plot in dominant subplot
                    %                 subplot(2,2,2); hold on;
                    sc = scatter(AI(rec,c,MIDTable.StimElec(rec)),delta_bias(rec,c),40,colorsteps(2,:),'filled');
                    %                 plot(AI(rec,2,MIDTable.StimElec(rec)),delta_bias(rec,2),'o','MarkerFaceColor',colorsteps(c,:),'MarkerEdgeColor',rec_map(rec,:),'LineWidth',2,'MarkerSize',10);
                end
            else
                %             subplot(2,2,c); hold on;
                if c == 1
                    sc = scatter(AI(rec,c,MIDTable.StimElec(rec)),delta_bias(rec,c),40,colorsteps(1,:),'filled');
                elseif c == 2
                    sc = scatter(AI(rec,c,MIDTable.StimElec(rec)),delta_bias(rec,c),40,colorsteps(2,:),'filled');
                elseif c == 3
                    sc = scatter(AI(rec,c,MIDTable.StimElec(rec)),delta_bias(rec,c),40,colorsteps(3,:),'filled');
                elseif c == 4
                    sc = scatter(AI(rec,c,MIDTable.StimElec(rec)),delta_bias(rec,c),40,colorsteps(4,:),'filled');
                end
                
                %             plot(AI(rec,c,MIDTable.StimElec(rec)),delta_bias(rec,c),'o','MarkerFaceColor',colorsteps(c,:),'MarkerEdgeColor',rec_map(rec,:),'LineWidth',2,'MarkerSize',10);
            end
            %         row = dataTipTextRow('wCI: ',{num2str(round(sc.CData,2))});
            %         sc.DataTipTemplate.DataTipRows(end+1) = row;
            row = dataTipTextRow('D: ',{datestr(MIDTable.Date(rec))});
            sc.DataTipTemplate.DataTipRows(end+1) = row;
            
        end
    end
end
xlabel('Stim Electrode AI')
ylabel('Delta Bias')
box on;
axis square;
xlim([-1,1]);
ylim([-1.5,1.5]);
plot([0, 0], [-1.5,1.5],'--k')
plot([-1,1],[0, 0], '--k');

%% Fits
    x = [-1:0.1:1];
    % Fit and plot type II regression lines
%     [B(2),B(1)] = regress_perp(MIDTable.Combined_AI, MIDTable.Delta_Mu_Combined);
%     regress_line = x.*B(2) + B(1);
%     plot(x,regress_line,'-','Color',colorsteps(1,:));
%     
%     [B(2),B(1)] = regress_perp(MIDTable.Dominant_AI, MIDTable.Dominant_Delta);
%     regress_line = x.*B(2) + B(1);
%     plot(x,regress_line,'-','Color',colorsteps(2,:));
%     
%     [B(2),B(1)] = regress_perp(MIDTable.Non_Dominant_AI, MIDTable.Non_Dominant_Delta);
%     regress_line = x.*B(2) + B(1);
%     plot(x,regress_line,'-','Color',colorsteps(3,:));
%     
%     [B(2),B(1)] = regress_perp(MIDTable.Stereo_AI, MIDTable.Delta_Mu_Stereo);
%     regress_line = x.*B(2) + B(1);
%     plot(x,regress_line,'-','Color',colorsteps(4,:));


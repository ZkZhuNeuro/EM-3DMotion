clear; close all
[unit_table, unit_table_gof_file] = LoadLatestUnitTableGof();
delta_bias_sigmoid = CalculateSigmoidFitBiases(unit_table, 4);
fprintf('Using unit_table_gof: %s\n', unit_table_gof_file);

colorsteps = [254 191 15;...
    0 0 0;...
    234 0 233;...
    110 205 221]./255;

% unit_table(88, :) = [];
%%
n_FST = 0;
for rec = 1:size(unit_table, 1)
    if unit_table.p_AI{rec}(2) < 0.05 && unit_table.p_AI{rec}(3) < 0.05 && strcmp(cell2mat(unit_table.ROI(rec)), 'FST')
        n_FST = n_FST + 1; 
        ch = unit_table.StimElec(rec);
        MIDTable.Delta_bias{:, n_FST} = delta_bias_sigmoid(rec, :);
        MIDTable.AI{n_FST} = unit_table.AI{rec}(:, ch);
        MIDTable.OD_max{n_FST} = unit_table.OD_max{rec};
        MIDTable.Z3D_v_Z2D{n_FST} = unit_table.Z3D_v_Z2D{rec};
        if strcmp(unit_table.Monkey{rec}, 'Jim')
            MIDTable.Monkey{n_FST} = 1;
        elseif strcmp(unit_table.Monkey{rec}, 'Clay')
            MIDTable.Monkey{n_FST} = 2;
        else
            error('Wrong monkey name!')
        end
%         MIDTable.wAI{n_FST} = unit_table.wAI{rec};
        if unit_table.OD_max{rec} > 0
            MIDTable.OD_max_eye{n_FST} = 'L';
        else
            MIDTable.OD_max_eye{n_FST} = 'R';
        end
    end
end

%%
BiasTable_max = table();

for rec = 1:size(MIDTable.Delta_bias, 2)
    if MIDTable.OD_max_eye{rec} == 'L'
        BiasTable_max = [BiasTable_max; ...
            array2table([MIDTable.AI{rec}(2), MIDTable.OD_max{rec}, 1, MIDTable.Z3D_v_Z2D{rec}, MIDTable.Delta_bias{rec}(2), rec, MIDTable.Monkey{rec}; ... % Dom
            MIDTable.AI{rec}(1), MIDTable.OD_max{rec}, 2, MIDTable.Z3D_v_Z2D{rec}, MIDTable.Delta_bias{rec}(1), rec, MIDTable.Monkey{rec}; ... % Comb
            MIDTable.AI{rec}(4), MIDTable.OD_max{rec}, 3, MIDTable.Z3D_v_Z2D{rec}, MIDTable.Delta_bias{rec}(4), rec, MIDTable.Monkey{rec}; ... % Stereo
            MIDTable.AI{rec}(3), MIDTable.OD_max{rec}, 4, MIDTable.Z3D_v_Z2D{rec}, MIDTable.Delta_bias{rec}(3), rec, MIDTable.Monkey{rec}], ... % NonDom
            'VariableNames', {'AI','OD_raw','Condition','z2D3D','Bias', 'Session', 'Monkey'})];
    else
        BiasTable_max = [BiasTable_max; ...
            array2table([MIDTable.AI{rec}(3), MIDTable.OD_max{rec}, 1, MIDTable.Z3D_v_Z2D{rec}, MIDTable.Delta_bias{rec}(3), rec, MIDTable.Monkey{rec}; ... % Dom
            MIDTable.AI{rec}(1), MIDTable.OD_max{rec}, 2, MIDTable.Z3D_v_Z2D{rec}, MIDTable.Delta_bias{rec}(1), rec, MIDTable.Monkey{rec}; ... % Comb
            MIDTable.AI{rec}(4), MIDTable.OD_max{rec}, 3, MIDTable.Z3D_v_Z2D{rec}, MIDTable.Delta_bias{rec}(4), rec, MIDTable.Monkey{rec}; ... % Stereo
            MIDTable.AI{rec}(2), MIDTable.OD_max{rec}, 4, MIDTable.Z3D_v_Z2D{rec}, MIDTable.Delta_bias{rec}(2), rec, MIDTable.Monkey{rec}], ... % NonDom
            'VariableNames', {'AI','OD_raw','Condition','z2D3D','Bias', 'Session', 'Monkey'})];
    end
end

BiasTable_max.OD = abs(BiasTable_max.OD_raw);

BiasTable_max.Coded_Condition = zeros(size(BiasTable_max,1),1);
BiasTable_max.Coded_Condition(BiasTable_max.Condition == 1 | BiasTable_max.Condition == 2 | BiasTable_max.Condition == 3) = 1; % Contrast code that sums to 0 and specifically compares non-dominant with others
BiasTable_max.Coded_Condition(BiasTable_max.Condition == 4) = -3;

BiasTable_max.Coded_Condition_Simple(BiasTable_max.Condition == 4) = -1;
BiasTable_max.Coded_Condition_Simple(BiasTable_max.Condition == 1) = 1;

BiasTable_max.AbsBias = abs(BiasTable_max.Bias);
BiasTable_max.AbsAI = abs(BiasTable_max.AI);
for i_row  = 1:size(BiasTable_max, 1)
    if BiasTable_max.Condition(i_row) == 4 && BiasTable_max.z2D3D(i_row) < 0
        BiasTable_max.FlipBias(i_row) = -BiasTable_max.Bias(i_row);
    else
        BiasTable_max.FlipBias(i_row) = BiasTable_max.Bias(i_row);
    end
end


%% 
criteria = BiasTable_max.z2D3D < 0 & (BiasTable_max.Condition == 1 | BiasTable_max.Condition == 4) & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
fprintf(2,['\n\n', ' AI*OD\n\n'])
lm_1 = fitlm(temp_table,'FlipBias ~ AI + AI:OD');
anova(lm_1)

%%
criteria = BiasTable_max.z2D3D < 0;
temp_table = BiasTable_max(criteria,:);
fprintf(2,['\n\n', ' AI\n\n'])
lm_1 = fitlm(temp_table,'FlipBias ~ AI');
anova(lm_1)
% plotInteraction(lm_1, 'OD', 'AI', 'predictions')

%%
criteria = BiasTable_max.z2D3D < 0 & BiasTable_max.Condition == 1 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
fprintf(2,['\n\n', ' AI\n\n'])
lm_1 = fitlm(temp_table,'Bias ~ AI');
anova(lm_1)

%%
criteria = BiasTable_max.z2D3D < 0 & BiasTable_max.Condition == 2 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
fprintf(2,['\n\n', ' AI\n\n'])
lm_1 = fitlm(temp_table,'Bias ~ AI');
anova(lm_1)

%%
criteria = BiasTable_max.z2D3D < 0 & BiasTable_max.Condition == 3 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
fprintf(2,['\n\n', ' AI\n\n'])
lm_1 = fitlm(temp_table,'Bias ~ AI');
anova(lm_1)

%%
criteria = BiasTable_max.z2D3D < 0 & BiasTable_max.Condition == 4 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
fprintf(2,['\n\n', ' AI\n\n'])
lm_1 = fitlm(temp_table,'Bias ~ AI');
anova(lm_1)

%%
criteria = BiasTable_max.z2D3D < 0 & BiasTable_max.Condition == 1 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
fprintf(2,['\n\n', ' AI\n\n'])
lm_1 = fitlm(temp_table,'Bias ~ AI + AI:OD');
anova(lm_1)

%%
criteria = BiasTable_max.z2D3D < 0 & BiasTable_max.Condition == 2 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
fprintf(2,['\n\n', ' AI\n\n'])
lm_1 = fitlm(temp_table,'Bias ~ AI + AI:OD');
anova(lm_1)

%%
criteria = BiasTable_max.z2D3D < 0 & BiasTable_max.Condition == 3 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
fprintf(2,['\n\n', ' AI\n\n'])
lm_1 = fitlm(temp_table,'Bias ~ AI + AI:OD');
anova(lm_1)

%%
criteria = BiasTable_max.z2D3D < 0 & BiasTable_max.Condition == 4 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
fprintf(2,['\n\n', ' AI\n\n'])
lm_1 = fitlm(temp_table,'Bias ~ AI + AI:OD');
anova(lm_1)

%%
criteria = BiasTable_max.z2D3D < 0 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
fprintf(2,['\n\n', ' AI\n\n'])
lm_1 = fitlme(temp_table,'Bias ~ AI * Coded_Condition + (1 + AI|Coded_Condition)');
anova(lm_1)

%%

%% 
criteria = BiasTable_max.z2D3D > 0 & (BiasTable_max.Condition == 1 | BiasTable_max.Condition == 4) & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
fprintf(2,['\n\n', ' AI*OD\n\n'])
lm_1 = fitlm(temp_table,'FlipBias ~ AI + AI:OD');
anova(lm_1)


%%
criteria = BiasTable_max.z2D3D > 0 & BiasTable_max.Condition == 1 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
fprintf(2,['\n\n', ' AI\n\n'])
lm_1 = fitlm(temp_table,'Bias ~ AI');
anova(lm_1)

%%
criteria = BiasTable_max.z2D3D > 0 & BiasTable_max.Condition == 2 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
fprintf(2,['\n\n', ' AI\n\n'])
lm_1 = fitlm(temp_table,'Bias ~ AI');
anova(lm_1)

%%
criteria = BiasTable_max.z2D3D > 0 & BiasTable_max.Condition == 3 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
fprintf(2,['\n\n', ' AI\n\n'])
lm_1 = fitlm(temp_table,'Bias ~ AI');
anova(lm_1)

%%
criteria = BiasTable_max.z2D3D > 0 & BiasTable_max.Condition == 4 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
fprintf(2,['\n\n', ' AI\n\n'])
lm_1 = fitlm(temp_table,'Bias ~ AI');
anova(lm_1)

%%
criteria = BiasTable_max.z2D3D > 0 & BiasTable_max.Condition == 1 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
fprintf(2,['\n\n', ' AI\n\n'])
lm_1 = fitlm(temp_table,'Bias ~ AI + AI:OD');
anova(lm_1)

%%
criteria = BiasTable_max.z2D3D > 0 & BiasTable_max.Condition == 2 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
fprintf(2,['\n\n', ' AI\n\n'])
lm_1 = fitlm(temp_table,'Bias ~ AI + AI:OD');
anova(lm_1)

%%
criteria = BiasTable_max.z2D3D > 0 & BiasTable_max.Condition == 3 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
fprintf(2,['\n\n', ' AI\n\n'])
lm_1 = fitlm(temp_table,'Bias ~ AI + AI:OD');
anova(lm_1)

%%
criteria = BiasTable_max.z2D3D > 0 & BiasTable_max.Condition == 4 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
fprintf(2,['\n\n', ' AI\n\n'])
lm_1 = fitlm(temp_table,'Bias ~ AI + AI:OD');
anova(lm_1)

%%
criteria = BiasTable_max.z2D3D > 0 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
fprintf(2,['\n\n', ' AI\n\n'])
lm_1 = fitlme(temp_table,'Bias ~ AI * Coded_Condition + (1 + AI|Coded_Condition)');
anova(lm_1)

%%
criteria = BiasTable_max.z2D3D < 0 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
fprintf(2,['\n\n', ' AI\n\n'])
lm_1 = fitlm(temp_table,'FlipBias ~ AI');
anova(lm_1)
% plotInteraction(lm_1, 'OD', 'AI', 'predictions')

%%
criteria = BiasTable_max.z2D3D > 0 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
fprintf(2,['\n\n', ' AI\n\n'])
lm_1 = fitlm(temp_table,'FlipBias ~ AI');
anova(lm_1)
% plotInteraction(lm_1, 'OD', 'AI', 'predictions')

%%
figure(1)
hold on
plot([-1, 1], [0, 0], 'k--')
plot([0, 0], [-2.2, 2.2], 'k--')
title('FST 2D neurons','fontsize',18)
xlabel('Asymmetry Index','fontsize',18)
% ylabel('Delta Bias','fontsize',18)
axis square
xticks([-1, 0, 1])
a = get(gca,'XTickLabel');
set(gca,'XTickLabel',a,'fontsize',18)
b = get(gca,'YTickLabel');
set(gca,'YTickLabel',b,'fontsize',18)
box on
xlim([-1 1])
ylim([-2.2 2.2])
xticks(-1:0.5:1)
xticklabels({'-1', 'Away', '0', 'Towards', '1'})
xtickangle(0)
yticks(-2:1:2)
yticklabels({'-2', 'Away', '0', 'Towards', '2'})
ytickangle(90)
set(gca,'linewidth',1)

%%
figure(2)
hold on
plot([-1, 1], [0, 0], 'k--')
plot([0, 0], [-3, 3], 'k--')
title('FST 3D neurons','fontsize',18)
xlabel('Asymmetry Index','fontsize',18)
% ylabel('Delta Bias','fontsize',18)
axis square
xticks([-1, 0, 1])
a = get(gca,'XTickLabel');
set(gca,'XTickLabel',a,'fontsize',18)
b = get(gca,'YTickLabel');
set(gca,'YTickLabel',b,'fontsize',18)
box on
xlim([-1 1])
ylim([-3 3])
xticks(-1:0.5:1)
xticklabels({'-1', 'Away', '0', 'Towards', '1'})
xtickangle(0)
yticks(-3:1.5:3)
yticklabels({'-3', 'Away', '0', 'Towards', '3'})
ytickangle(90)
set(gca,'linewidth',1)

%%
x_plot = [-1:0.1:1];
%% LSQ 2D Dominant
criteria = BiasTable_max.z2D3D < 0 & BiasTable_max.Condition == 1 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
x = temp_table.AI;
y = temp_table.Bias;
w = temp_table.OD;
[slope, intercept] = type2_reg_weighted_matrix(x, y, w);
figure(1)
hold on;
plot(x_plot, intercept + x_plot*slope,'-','Color',colorsteps(1,:),'LineWidth',2.5);

criteria = BiasTable_max.z2D3D < 0 & BiasTable_max.Condition == 1 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
s = scatter(temp_table.AI, temp_table.Bias, 40, ...
            colorsteps(1, :), 'filled', 'MarkerEdgeColor',colorsteps(1, :),'LineWidth',1.5);
s.AlphaData = temp_table.OD;

s.MarkerFaceAlpha = 'flat';
%% LSQ 3D Dominant
criteria = BiasTable_max.z2D3D > 0 & BiasTable_max.Condition == 1 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
x = temp_table.AI;
y = temp_table.Bias;
w = temp_table.OD;
[slope, intercept] = type2_reg_weighted_matrix(x, y, w);
figure(2)
hold on;
plot(x_plot, intercept + x_plot*slope,'-','Color',colorsteps(1,:),'LineWidth',2.5);

criteria = BiasTable_max.z2D3D > 0 & BiasTable_max.Condition == 1 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
s = scatter(temp_table.AI, temp_table.Bias, 40, ...
            colorsteps(1, :), 'filled', 'MarkerEdgeColor',colorsteps(1, :),'LineWidth',1.5);
s.AlphaData = temp_table.OD;

s.MarkerFaceAlpha = 'flat';

%% LSQ 2D Combine
criteria = BiasTable_max.z2D3D < 0 & BiasTable_max.Condition == 2 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
x = temp_table.AI;
y = temp_table.Bias;
w = temp_table.OD;
[slope, intercept] = type2_reg_weighted_matrix(x, y, w);
figure(1)
hold on;
plot(x_plot, intercept + x_plot*slope,'-','Color',colorsteps(2,:),'LineWidth',2.5);

criteria = BiasTable_max.z2D3D < 0 & BiasTable_max.Condition == 2 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
s = scatter(temp_table.AI, temp_table.Bias, 40, ...
            colorsteps(2, :), 'filled', 'MarkerEdgeColor',colorsteps(2, :),'LineWidth',1.5);
s.AlphaData = temp_table.OD;

s.MarkerFaceAlpha = 'flat';
%% LSQ 3D Combine
criteria = BiasTable_max.z2D3D > 0 & BiasTable_max.Condition == 2 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
x = temp_table.AI;
y = temp_table.Bias;
w = temp_table.OD;
[slope, intercept] = type2_reg_weighted_matrix(x, y, w);
figure(2)
hold on;
plot(x_plot, intercept + x_plot*slope,'-','Color',colorsteps(2,:),'LineWidth',2.5);

criteria = BiasTable_max.z2D3D > 0 & BiasTable_max.Condition == 2 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
s = scatter(temp_table.AI, temp_table.Bias, 40, ...
            colorsteps(2, :), 'filled', 'MarkerEdgeColor',colorsteps(2, :),'LineWidth',1.5);
s.AlphaData = temp_table.OD;

s.MarkerFaceAlpha = 'flat';

%% LSQ 2D Stereo
criteria = BiasTable_max.z2D3D < 0 & BiasTable_max.Condition == 3 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
x = temp_table.AI;
y = temp_table.Bias;
w = temp_table.OD;
[slope, intercept] = type2_reg_weighted_matrix(x, y, w);
figure(1)
hold on;
plot(x_plot, intercept + x_plot*slope,'-','Color',colorsteps(3,:),'LineWidth',2.5);

criteria = BiasTable_max.z2D3D < 0 & BiasTable_max.Condition == 3 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
s = scatter(temp_table.AI, temp_table.Bias, 40, ...
            colorsteps(3, :), 'filled', 'MarkerEdgeColor',colorsteps(3, :),'LineWidth',1.5);
s.AlphaData = temp_table.OD;

s.MarkerFaceAlpha = 'flat';

%% LSQ 3D Stereo
criteria = BiasTable_max.z2D3D > 0 & BiasTable_max.Condition == 3 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
x = temp_table.AI;
y = temp_table.Bias;
w = temp_table.OD;
[slope, intercept] = type2_reg_weighted_matrix(x, y, w);
figure(2)
hold on;
plot(x_plot, intercept + x_plot*slope,'-','Color',colorsteps(3,:),'LineWidth',2.5);

criteria = BiasTable_max.z2D3D > 0 & BiasTable_max.Condition == 3 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
s = scatter(temp_table.AI, temp_table.Bias, 40, ...
            colorsteps(3, :), 'filled', 'MarkerEdgeColor',colorsteps(3, :),'LineWidth',1.5);
s.AlphaData = temp_table.OD;

s.MarkerFaceAlpha = 'flat';

%% LSQ 2D Non
criteria = BiasTable_max.z2D3D < 0 & BiasTable_max.Condition == 4 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
x = temp_table.AI;
y = temp_table.Bias;
w = temp_table.OD;
[slope, intercept] = type2_reg_weighted_matrix(x, y, w);
figure(1)
hold on;
plot(x_plot, intercept + x_plot*slope,'-','Color',colorsteps(4,:),'LineWidth',2.5);

criteria = BiasTable_max.z2D3D < 0 & BiasTable_max.Condition == 4 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
s = scatter(temp_table.AI, temp_table.Bias, 40, ...
            colorsteps(4, :), 'filled', 'MarkerEdgeColor',colorsteps(4, :),'LineWidth',1.5);
s.AlphaData = temp_table.OD;

s.MarkerFaceAlpha = 'flat';

%% LSQ 3D Non
criteria = BiasTable_max.z2D3D > 0 & BiasTable_max.Condition == 4 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
x = temp_table.AI;
y = temp_table.Bias;
w = temp_table.OD;
[slope, intercept] = type2_reg_weighted_matrix(x, y, w);
figure(2)
hold on;
plot(x_plot, intercept + x_plot*slope,'-','Color',colorsteps(4,:),'LineWidth',2.5);

criteria = BiasTable_max.z2D3D > 0 & BiasTable_max.Condition == 4 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
s = scatter(temp_table.AI, temp_table.Bias, 40, ...
            colorsteps(4, :), 'filled', 'MarkerEdgeColor',colorsteps(4, :),'LineWidth',1.5);
s.AlphaData = temp_table.OD;

s.MarkerFaceAlpha = 'flat';

clear; close all
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'common'));
[paths, outputDir] = currentSpreadInit(mfilename('fullpath'));
load(paths.unitTableDiscontinue)

colorsteps = [254 191 15;...
    0 0 0;...
    234 0 233;...
    110 205 221]./255;


%%
n_MT = 0;
for rec = 1:size(unit_table, 1)
    if strcmp(cell2mat(unit_table.ROI(rec)), 'MT')
        n_MT = n_MT + 1; 
        ch = unit_table.StimElec(rec);
        MIDTable.Delta_bias{:, n_MT} = unit_table.Delta_bias{rec};
        MIDTable.AI{n_MT} = unit_table.AI{rec}(:, ch);
        MIDTable.OD_max{n_MT} = unit_table.OD_max{rec};
        MIDTable.Z3D_v_Z2D{n_MT} = unit_table.Z3D_v_Z2D{rec};
        MIDTable.discontinue{n_MT} = mean(unit_table.disc_std(rec, :));
        if strcmp(unit_table.Monkey{rec}, 'Jim')
            MIDTable.Monkey{n_MT} = 1;
        elseif strcmp(unit_table.Monkey{rec}, 'Clay')
            MIDTable.Monkey{n_MT} = 2;
        else
            error('Wrong monkey name!')
        end
%         MIDTable.wAI{n_MT} = unit_table.wAI{rec};
        if unit_table.OD_max{rec} > 0
            MIDTable.OD_max_eye{n_MT} = 'L';
        else
            MIDTable.OD_max_eye{n_MT} = 'R';
        end
    end
end

%%
BiasTable_max = table();

for rec = 1:size(MIDTable.Delta_bias, 2)
    if MIDTable.OD_max_eye{rec} == 'L'
        BiasTable_max = [BiasTable_max; ...
            array2table([MIDTable.AI{rec}(2), MIDTable.OD_max{rec}, 1, MIDTable.Z3D_v_Z2D{rec}, MIDTable.Delta_bias{rec}(2), rec, MIDTable.Monkey{rec}, MIDTable.discontinue{rec};... % Dom
            MIDTable.AI{rec}(1), MIDTable.OD_max{rec}, 2, MIDTable.Z3D_v_Z2D{rec}, MIDTable.Delta_bias{rec}(1), rec, MIDTable.Monkey{rec}, MIDTable.discontinue{rec}; ... % Comb
            MIDTable.AI{rec}(4), MIDTable.OD_max{rec}, 3, MIDTable.Z3D_v_Z2D{rec}, MIDTable.Delta_bias{rec}(4), rec, MIDTable.Monkey{rec}, MIDTable.discontinue{rec}; ... % Stereo
            MIDTable.AI{rec}(3), MIDTable.OD_max{rec}, 4, MIDTable.Z3D_v_Z2D{rec}, MIDTable.Delta_bias{rec}(3), rec, MIDTable.Monkey{rec}, MIDTable.discontinue{rec}], ... % NonDom
            'VariableNames', {'AI','OD_raw','Condition','z2D3D','Bias', 'Session', 'Monkey', 'discontinue'})];
    else
        BiasTable_max = [BiasTable_max; ...
            array2table([MIDTable.AI{rec}(3), MIDTable.OD_max{rec}, 1, MIDTable.Z3D_v_Z2D{rec}, MIDTable.Delta_bias{rec}(3), rec, MIDTable.Monkey{rec}, MIDTable.discontinue{rec}; ... % Dom
            MIDTable.AI{rec}(1), MIDTable.OD_max{rec}, 2, MIDTable.Z3D_v_Z2D{rec}, MIDTable.Delta_bias{rec}(1), rec, MIDTable.Monkey{rec}, MIDTable.discontinue{rec}; ... % Comb
            MIDTable.AI{rec}(4), MIDTable.OD_max{rec}, 3, MIDTable.Z3D_v_Z2D{rec}, MIDTable.Delta_bias{rec}(4), rec, MIDTable.Monkey{rec}, MIDTable.discontinue{rec}; ... % Stereo
            MIDTable.AI{rec}(2), MIDTable.OD_max{rec}, 4, MIDTable.Z3D_v_Z2D{rec}, MIDTable.Delta_bias{rec}(2), rec, MIDTable.Monkey{rec}, MIDTable.discontinue{rec}], ... % NonDom
            'VariableNames', {'AI','OD_raw','Condition','z2D3D','Bias', 'Session', 'Monkey', 'discontinue'})];
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
figure(1)
hold on
plot([-1, 1], [0, 0], 'k--')
plot([0, 0], [-2.2, 2.2], 'k--')
title('MT 2D neurons','fontsize',18)
xlabel('AIxODM','fontsize',18)
ylabel('Delta Bias','fontsize',18)
axis square
xticks([-1, 0, 1])
a = get(gca,'XTickLabel');
set(gca,'XTickLabel',a,'fontsize',18)
b = get(gca,'YTickLabel');
set(gca,'YTickLabel',b,'fontsize',18)
box on
xlim([-0.4 0.4])
ylim([-2.2 2.2])
xticks(-0.4:0.2:0.4)
xticklabels({'-0.4', 'Away', '0', 'Towards', '0.4'})
xtickangle(0)
yticks(-2:1:2)
yticklabels({'-2', 'Away', '0', 'Towards', '2'})
ytickangle(90)

%%
x_plot = [-1:0.1:1];
criteria = BiasTable_max.z2D3D < 0 & BiasTable_max.Condition == 1;
temp_table = BiasTable_max(criteria,:);

x = temp_table.AI .* temp_table.OD;
x = [x, ones(size(x, 1), 1)];

slope = NaN(4, 1);
intercept = NaN(4, 1);
d_bias = NaN(4, length(x));
d_bias_AI = NaN(4, length(x));
[slope(1), intercept(1), d_bias(1, :), d_bias_AI(1, :)] = plot_2D(x, 1, BiasTable_max, colorsteps, x_plot);
[slope(2), intercept(2), d_bias(2, :), d_bias_AI(2, :)] = plot_2D(x, 2, BiasTable_max, colorsteps, x_plot);
[slope(3), intercept(3), d_bias(3, :), d_bias_AI(3, :)] = plot_2D(x, 3, BiasTable_max, colorsteps, x_plot);
[slope(4), intercept(4), d_bias(4, :), d_bias_AI(4, :)] = plot_2D(x, 4, BiasTable_max, colorsteps, x_plot);

%%
X = x(:, 1); 
d_bias_dom = d_bias(1, :);
d_bias_nondom = d_bias(2, :);
[r, p] = corr([d_bias_dom'; d_bias_nondom'], [temp_table.discontinue; temp_table.discontinue])

%%
d_bias_AI_dom = d_bias_AI(1, :);
d_bias_AI_nondom = d_bias_AI(2, :);
[r, p] = corr(d_bias_AI_dom', temp_table.discontinue)

%%
d = sumPointLineDistance([temp_table.AI, temp_table.Bias], slope(1), intercept(1));
[r, p] = corr(d.^2, temp_table.discontinue)
figure(); scatter(temp_table.discontinue, d.^2)
%%
idx_wrong = xor(temp_table.AI > 0, temp_table.Bias > 0);
g1 = repmat({'wrong'},length(temp_table.discontinue(idx_wrong)),1);
g2 = repmat({'correct'},length(temp_table.discontinue(~idx_wrong)),1);
figure(); 
% boxplot([temp_table.discontinue(idx_wrong); temp_table.discontinue(~idx_wrong)], [g1; g2])
violinplot([zeros(size(temp_table.discontinue(idx_wrong))); ones(size(temp_table.discontinue(~idx_wrong)))], ...
    [temp_table.discontinue(idx_wrong); temp_table.discontinue(~idx_wrong)])
[h, p] = ttest2(temp_table.discontinue(idx_wrong), temp_table.discontinue(~idx_wrong))
figure(); hold on
histogram(temp_table.discontinue(idx_wrong), 0:0.1:1)
histogram(temp_table.discontinue(~idx_wrong), 0:0.1:1)

currentSpreadSaveResults(outputDir);

%%

function [slope, intercept, d_bias, d_bias_AI] = plot_2D(x, cond, BiasTable_max, colorsteps, x_plot)

criteria = BiasTable_max.z2D3D < 0 & BiasTable_max.Condition == cond;
temp_table = BiasTable_max(criteria,:);

y = temp_table.Bias;
beta = x \ y;
slope = beta(1); 
intercept = beta(2); 
figure(1)
hold on;
plot(x_plot, intercept + x_plot*slope,'-','Color',colorsteps(cond,:),'LineWidth',2.5);

criteria = BiasTable_max.z2D3D < 0 & BiasTable_max.Condition == cond & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
y2 = temp_table.Bias;
criteria = BiasTable_max.z2D3D < 0 & BiasTable_max.Condition == 1 & BiasTable_max.Monkey == 1;
temp_table = BiasTable_max(criteria,:);
x2 = temp_table.AI .* temp_table.OD;
s = scatter(x2, y2, 40, ...
            colorsteps(cond, :), 'filled', 'MarkerEdgeColor',colorsteps(cond, :),'LineWidth',1.5);
s.AlphaData = temp_table.discontinue;

s.MarkerFaceAlpha = 'flat';

d_bias = y - (x(:, 1) .* slope + intercept); 
d_bias(x(:, 1) < 0) = -d_bias(x(:, 1) < 0);

[slope_AI, intercept_AI] = type2_reg_weighted_matrix(temp_table.AI, temp_table.Bias, temp_table.OD);

d_bias_AI = y - (temp_table.AI .* slope_AI + intercept_AI);
d_bias_AI(temp_table.AI < 0) = -d_bias_AI(temp_table.AI < 0);
end

%%
function d = sumPointLineDistance(points, m, b)
    % points: Nx2 matrix [x y]
    x = points(:,1);
    y = points(:,2);

    d = abs(m*x - y + b) ./ sqrt(m^2 + 1);  % perpendicular distances
    
end

clear;
colorsteps = [0 0 0;...
    0 0 255;...
    5 150 5;...
    234 0 233]/255;
%%
load("C:\EM\BehaviorFitting\unit_table_lapseHardCap_06.mat")

lapse_06_left = NaN(size(unit_table, 1), 4);
lapse_06_right = NaN(size(unit_table, 1), 4);
Bias_06 = NaN(size(unit_table, 1), 4);
for i_rec = 1:size(unit_table, 1)
    for i_cue = 1:4
        lapse_06_left(i_rec, i_cue) = unit_table.Behave_S{i_rec}{i_cue}.Fit(4);
        lapse_06_right(i_rec, i_cue) = unit_table.Behave_S{i_rec}{i_cue}.Fit(3);
        Bias_06(i_rec, i_cue) = unit_table.Behave_N{i_rec}{i_cue}.Fit(1) ...
            - unit_table.Behave_S{i_rec}{i_cue}.Fit(1);
    end
end

clear unit_table

%%
load("C:\EM\BehaviorFitting\unit_table_lapseHardCap_10.mat")

lapse_10_left = NaN(size(unit_table, 1), 4);
lapse_10_right = NaN(size(unit_table, 1), 4);
Bias_10 = NaN(size(unit_table, 1), 4);
for i_rec = 1:size(unit_table, 1)
    for i_cue = 1:4
        lapse_10_left(i_rec, i_cue) = unit_table.Behave_S{i_rec}{i_cue}.Fit(4);
        lapse_10_right(i_rec, i_cue) = unit_table.Behave_S{i_rec}{i_cue}.Fit(3);
        Bias_10(i_rec, i_cue) = unit_table.Behave_N{i_rec}{i_cue}.Fit(1) ...
            - unit_table.Behave_S{i_rec}{i_cue}.Fit(1);
    end
end

clear unit_table

%%
load("C:\EM\BehaviorFitting\unit_table_lapseHardCap_00.mat")

lapse_00_left = NaN(size(unit_table, 1), 4);
lapse_00_right = NaN(size(unit_table, 1), 4);
Bias_00 = NaN(size(unit_table, 1), 4);
for i_rec = 1:size(unit_table, 1)
    for i_cue = 1:4
        lapse_00_left(i_rec, i_cue) = unit_table.Behave_S{i_rec}{i_cue}.Fit(4);
        lapse_00_right(i_rec, i_cue) = unit_table.Behave_S{i_rec}{i_cue}.Fit(3);
        Bias_00(i_rec, i_cue) = unit_table.Behave_N{i_rec}{i_cue}.Fit(1) ...
            - unit_table.Behave_S{i_rec}{i_cue}.Fit(1);
    end
end

%%
figure()
hold on
for i_cue = 1:4
    scatter(lapse_06_left(:, i_cue), lapse_10_left(:, i_cue), 'MarkerEdgeColor', colorsteps(i_cue,:));
end
axis square
xlabel('06 lapse leftside')
ylabel('10 lapse leftside')
ylim([0 0.1])
plot([0 0.5], [0 0.5], 'k')

figure()
hold on
for i_cue = 1:4
    scatter(lapse_06_right(:, i_cue), lapse_10_right(:, i_cue), 'MarkerEdgeColor', colorsteps(i_cue,:));
end
axis square
xlabel('06 lapse leftside')
ylabel('10 lapse leftside')
ylim([0 0.1])
plot([0 0.5], [0 0.5], 'k')

%%
figure()
hold on
for i_cue = 1:4
    scatter(Bias_06(:, i_cue), Bias_10(:, i_cue), 'MarkerEdgeColor', colorsteps(i_cue,:));
end
axis square
xlabel('06 biases')
ylabel('10 biases')

%%
figure()
hold on
for i_cue = 1:4
    scatter(Bias_06(:, i_cue), Bias_00(:, i_cue), 'MarkerEdgeColor', colorsteps(i_cue,:));
end
axis square
xlabel('06 biases')
ylabel('00 biases')
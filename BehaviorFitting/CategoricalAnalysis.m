load("P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\BehaviorFitting\unit_table_ridgeAll.mat")
table_ridge = unit_table; 
load("P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\BehaviorFitting\unit_table_behavModel.mat")
unit_table.Behav_mdl_full_ridgeB1B2B3 = table_ridge.Behav_mdl_full_ridgeB1B2B3;

%%
ROI = NaN(size(unit_table, 1), 1);
Z2D3D = NaN(size(unit_table, 1), 1);
Sig_tuning = NaN(size(unit_table, 1), 4);
Bias = NaN(size(unit_table, 1), 4);
b2 = NaN(size(unit_table, 1), 4);
Sig_Bias = NaN(size(unit_table, 1), 4);
Sig_all = NaN(size(unit_table, 1), 1); 
AI = NaN(size(unit_table, 1), 4);
OD = NaN(size(unit_table, 1), 1);
AIOD = NaN(size(unit_table, 1), 1);
for i_rec = 1:size(unit_table, 1)
    if strcmp(unit_table.ROI{i_rec}, 'MT')
        ROI(i_rec) = 0; % Assign a value for MT ROI
    elseif strcmp(unit_table.ROI{i_rec}, 'FST')
        ROI(i_rec) = 1; % Assign a value for FST ROI
    end
    
    Z2D3D(i_rec) = unit_table.Z3D_v_Z2D{i_rec} > 0;

    Sig_tuning(i_rec, :) = unit_table.p_AI{i_rec} < 0.05;

    Bias(i_rec, :) = unit_table.Delta_bias{i_rec}; 

    b2_1 = unit_table.Behav_mdl_full_ridgeB1B2B3{i_rec}{1}.b(3);
    b2_2 = unit_table.Behav_mdl_full_ridgeB1B2B3{i_rec}{2}.b(3);
    b2_3 = unit_table.Behav_mdl_full_ridgeB1B2B3{i_rec}{3}.b(3);
    b2_4 = unit_table.Behav_mdl_full_ridgeB1B2B3{i_rec}{4}.b(3);
    b2(i_rec, :) = [b2_1, b2_2, b2_3, b2_4];

    Sig_Bias(i_rec, :) = unit_table.Behav_fullVSnull_p{i_rec} < 0.05;

    Sig_all(i_rec) = any(Sig_tuning(i_rec, :)); % Determine if any significant tuning is present

    StimElec = unit_table.StimElec(i_rec);
    AI(i_rec, :) = unit_table.AI{i_rec}(:, StimElec);

    OD(i_rec) = unit_table.OD_max{i_rec};

    if unit_table.OD_max{i_rec} < 0
        AIOD(i_rec) = AI(i_rec, 3) * abs(unit_table.OD_max{i_rec});
    else
        AIOD(i_rec) = AI(i_rec, 2) * abs(unit_table.OD_max{i_rec});
    end
end

ROI_tbl = array2table(ROI, 'VariableNames', {'ROI'});
Z2D3D_tbl = array2table(Z2D3D, 'VariableNames', {'Z2D3D'});
Sig_tuning_tbl = array2table(Sig_tuning, 'VariableNames', {'Sig_tuning_C', 'Sig_tuning_L', 'Sig_tuning_R', 'Sig_tuning_S'});
Bias_tbl = array2table(Bias, 'VariableNames', {'Bias_C', 'Bias_L', 'Bias_R', 'Bias_S'});
b2_tbl = array2table(b2, 'VariableNames', {'b2_C', 'b2_L', 'b2_R', 'b2_S'});
Sig_Bias_tbl = array2table(Sig_Bias, 'VariableNames', {'Sig_Bias_C', 'Sig_Bias_L', 'Sig_Bias_R', 'Sig_Bias_S'});
Sig_all_tbl = array2table(Sig_all, 'VariableNames', {'Sig_all'});
AI_tbl = array2table(AI, 'VariableNames', {'AI_C', 'AI_L', 'AI_R', 'AI_S'});
OD_tbl = array2table(OD, 'VariableNames', {'OD'});
AIOD_tbl = array2table(AIOD, 'VariableNames', {'AIOD'});

Data = [ROI_tbl, Z2D3D_tbl, Sig_tuning_tbl, Bias_tbl, b2_tbl, Sig_Bias_tbl, Sig_all_tbl, AI_tbl, OD_tbl, AIOD_tbl]; 

%% MT EM bias plot
% mask = Data{:,'ROI'} == 0;
% bias_MT_C = [Data{mask, 'Bias_C'}, Data{mask, 'Sig_Bias_C'}];
% bias_MT_L = [Data{mask, 'Bias_L'}, Data{mask, 'Sig_Bias_L'}];
% bias_MT_R = [Data{mask, 'Bias_R'}, Data{mask, 'Sig_Bias_R'}];
% bias_MT_S = [Data{mask, 'Bias_S'}, Data{mask, 'Sig_Bias_S'}];
% 
% amt_MT_C = sum(bias_MT_C(:, 2)) / size(bias_MT_C, 1);
% amt_MT_L = sum(bias_MT_L(:, 2)) / size(bias_MT_L, 1);
% amt_MT_R = sum(bias_MT_R(:, 2)) / size(bias_MT_R, 1);
% amt_MT_S = sum(bias_MT_S(:, 2)) / size(bias_MT_S, 1);
% 
% figure()
% subplot(2, 2, 1)
% plotCateg_hist(bias_MT_C)
% title(['Combined ', num2str(amt_MT_C * 100, 4), '%'])
% subplot(2, 2, 2)
% plotCateg_hist(bias_MT_L)
% title(['Left ', num2str(amt_MT_L * 100, 4), '%'])
% subplot(2, 2, 3)
% plotCateg_hist(bias_MT_R)
% title(['Right ', num2str(amt_MT_R * 100, 4), '%'])
% subplot(2, 2, 4)
% plotCateg_hist(bias_MT_S)
% title(['Stereo ', num2str(amt_MT_S * 100, 4), '%'])

%% MT EM b2 plot
mask = Data{:,'ROI'} == 0;
b2_MT_C = [Data{mask, 'b2_C'}, Data{mask, 'Sig_Bias_C'}];
b2_MT_L = [Data{mask, 'b2_L'}, Data{mask, 'Sig_Bias_L'}];
b2_MT_R = [Data{mask, 'b2_R'}, Data{mask, 'Sig_Bias_R'}];
b2_MT_S = [Data{mask, 'b2_S'}, Data{mask, 'Sig_Bias_S'}];

amt_MT_C = sum(b2_MT_C(:, 2)) / size(b2_MT_C, 1);
amt_MT_L = sum(b2_MT_L(:, 2)) / size(b2_MT_L, 1);
amt_MT_R = sum(b2_MT_R(:, 2)) / size(b2_MT_R, 1);
amt_MT_S = sum(b2_MT_S(:, 2)) / size(b2_MT_S, 1);

figure()
subplot(2, 2, 1)
plotCateg_hist(b2_MT_C)
title(['Combined ', num2str(amt_MT_C * 100, 4), '%'])
subplot(2, 2, 2)
plotCateg_hist(b2_MT_L)
title(['Left ', num2str(amt_MT_L * 100, 4), '%'])
subplot(2, 2, 3)
plotCateg_hist(b2_MT_R)
title(['Right ', num2str(amt_MT_R * 100, 4), '%'])
subplot(2, 2, 4)
plotCateg_hist(b2_MT_S)
title(['Stereo ', num2str(amt_MT_S * 100, 4), '%'])

%% FST EM bias plot
% mask = Data{:,'ROI'} == 1;
% bias_FST_C = [Data{mask, 'Bias_C'}, Data{mask, 'Sig_Bias_C'}];
% bias_FST_L = [Data{mask, 'Bias_L'}, Data{mask, 'Sig_Bias_L'}];
% bias_FST_R = [Data{mask, 'Bias_R'}, Data{mask, 'Sig_Bias_R'}];
% bias_FST_S = [Data{mask, 'Bias_S'}, Data{mask, 'Sig_Bias_S'}];
% 
% amt_FST_C = sum(bias_FST_C(:, 2)) / size(bias_FST_C, 1);
% amt_FST_L = sum(bias_FST_L(:, 2)) / size(bias_FST_L, 1);
% amt_FST_R = sum(bias_FST_R(:, 2)) / size(bias_FST_R, 1);
% amt_FST_S = sum(bias_FST_S(:, 2)) / size(bias_FST_S, 1);
% 
% figure()
% subplot(2, 2, 1)
% plotCateg_hist(bias_FST_C)
% title(['Combined ', num2str(amt_FST_C * 100, 4), '%'])
% subplot(2, 2, 2)
% plotCateg_hist(bias_FST_L)
% title(['Left ', num2str(amt_FST_L * 100, 4), '%'])
% subplot(2, 2, 3)
% plotCateg_hist(bias_FST_R)
% title(['Right ', num2str(amt_FST_R * 100, 4), '%'])
% subplot(2, 2, 4)
% plotCateg_hist(bias_FST_S)
% title(['Stereo ', num2str(amt_FST_S * 100, 4), '%'])

%% FST EM b2 plot
mask = Data{:,'ROI'} == 1;
b2_FST_C = [Data{mask, 'b2_C'}, Data{mask, 'Sig_Bias_C'}];
b2_FST_L = [Data{mask, 'b2_L'}, Data{mask, 'Sig_Bias_L'}];
b2_FST_R = [Data{mask, 'b2_R'}, Data{mask, 'Sig_Bias_R'}];
b2_FST_S = [Data{mask, 'b2_S'}, Data{mask, 'Sig_Bias_S'}];

amt_FST_C = sum(b2_FST_C(:, 2)) / size(b2_FST_C, 1);
amt_FST_L = sum(b2_FST_L(:, 2)) / size(b2_FST_L, 1);
amt_FST_R = sum(b2_FST_R(:, 2)) / size(b2_FST_R, 1);
amt_FST_S = sum(b2_FST_S(:, 2)) / size(b2_FST_S, 1);

figure()
subplot(2, 2, 1)
plotCateg_hist(b2_FST_C)
title(['Combined ', num2str(amt_FST_C * 100, 4), '%'])
subplot(2, 2, 2)
plotCateg_hist(b2_FST_L)
title(['Left ', num2str(amt_FST_L * 100, 4), '%'])
subplot(2, 2, 3)
plotCateg_hist(b2_FST_R)
title(['Right ', num2str(amt_FST_R * 100, 4), '%'])
subplot(2, 2, 4)
plotCateg_hist(b2_FST_S)
title(['Stereo ', num2str(amt_FST_S * 100, 4), '%'])

%% MT EM 2D b2 plot
mask = Data{:,'ROI'} == 0 & Data{:,'Z2D3D'} == 0 & Data{:,'Sig_tuning_L'} == 1 & Data{:,'Sig_tuning_R'} == 1;
b2_MT_C = [Data{mask, 'b2_C'}, Data{mask, 'Sig_Bias_C'}];
b2_MT_L = [Data{mask, 'b2_L'}, Data{mask, 'Sig_Bias_L'}];
b2_MT_R = [Data{mask, 'b2_R'}, Data{mask, 'Sig_Bias_R'}];
b2_MT_S = [Data{mask, 'b2_S'}, Data{mask, 'Sig_Bias_S'}];

amt_MT_C = sum(b2_MT_C(:, 2)) / size(b2_MT_C, 1);
amt_MT_L = sum(b2_MT_L(:, 2)) / size(b2_MT_L, 1);
amt_MT_R = sum(b2_MT_R(:, 2)) / size(b2_MT_R, 1);
amt_MT_S = sum(b2_MT_S(:, 2)) / size(b2_MT_S, 1);

figure()
subplot(2, 2, 1)
plotCateg_hist(b2_MT_C)
title(['Combined ', num2str(amt_MT_C * 100, 4), '%'])
subplot(2, 2, 2)
plotCateg_hist(b2_MT_L)
title(['Left ', num2str(amt_MT_L * 100, 4), '%'])
subplot(2, 2, 3)
plotCateg_hist(b2_MT_R)
title(['Right ', num2str(amt_MT_R * 100, 4), '%'])
subplot(2, 2, 4)
plotCateg_hist(b2_MT_S)
title(['Stereo ', num2str(amt_MT_S * 100, 4), '%'])

%% FST EM 2D b2 plot
mask = Data{:,'ROI'} == 1 & Data{:,'Z2D3D'} == 0 & Data{:,'Sig_tuning_L'} == 1 & Data{:,'Sig_tuning_R'} == 1;
b2_FST_C = [Data{mask, 'b2_C'}, Data{mask, 'Sig_Bias_C'}];
b2_FST_L = [Data{mask, 'b2_L'}, Data{mask, 'Sig_Bias_L'}];
b2_FST_R = [Data{mask, 'b2_R'}, Data{mask, 'Sig_Bias_R'}];
b2_FST_S = [Data{mask, 'b2_S'}, Data{mask, 'Sig_Bias_S'}];

amt_FST_C = sum(b2_FST_C(:, 2)) / size(b2_FST_C, 1);
amt_FST_L = sum(b2_FST_L(:, 2)) / size(b2_FST_L, 1);
amt_FST_R = sum(b2_FST_R(:, 2)) / size(b2_FST_R, 1);
amt_FST_S = sum(b2_FST_S(:, 2)) / size(b2_FST_S, 1);

figure()
subplot(2, 2, 1)
plotCateg_hist(b2_FST_C)
title(['Combined ', num2str(amt_FST_C * 100, 4), '%'])
subplot(2, 2, 2)
plotCateg_hist(b2_FST_L)
title(['Left ', num2str(amt_FST_L * 100, 4), '%'])
subplot(2, 2, 3)
plotCateg_hist(b2_FST_R)
title(['Right ', num2str(amt_FST_R * 100, 4), '%'])
subplot(2, 2, 4)
plotCateg_hist(b2_FST_S)
title(['Stereo ', num2str(amt_FST_S * 100, 4), '%'])

%% FST EM 3D b2 plot
mask = Data{:,'ROI'} == 1 & Data{:,'Z2D3D'} == 1 & Data{:,'Sig_tuning_L'} == 1 & Data{:,'Sig_tuning_R'} == 1;
b2_FST_C = [Data{mask, 'b2_C'}, Data{mask, 'Sig_Bias_C'}];
b2_FST_L = [Data{mask, 'b2_L'}, Data{mask, 'Sig_Bias_L'}];
b2_FST_R = [Data{mask, 'b2_R'}, Data{mask, 'Sig_Bias_R'}];
b2_FST_S = [Data{mask, 'b2_S'}, Data{mask, 'Sig_Bias_S'}];

amt_FST_C = sum(b2_FST_C(:, 2)) / size(b2_FST_C, 1);
amt_FST_L = sum(b2_FST_L(:, 2)) / size(b2_FST_L, 1);
amt_FST_R = sum(b2_FST_R(:, 2)) / size(b2_FST_R, 1);
amt_FST_S = sum(b2_FST_S(:, 2)) / size(b2_FST_S, 1);

figure()
subplot(2, 2, 1)
plotCateg_hist(b2_FST_C)
title(['Combined ', num2str(amt_FST_C * 100, 4), '%'])
subplot(2, 2, 2)
plotCateg_hist(b2_FST_L)
title(['Left ', num2str(amt_FST_L * 100, 4), '%'])
subplot(2, 2, 3)
plotCateg_hist(b2_FST_R)
title(['Right ', num2str(amt_FST_R * 100, 4), '%'])
subplot(2, 2, 4)
plotCateg_hist(b2_FST_S)
title(['Stereo ', num2str(amt_FST_S * 100, 4), '%'])

%% MT 2D AIOD vs b2
mask = Data{:,'ROI'} == 0 & Data{:,'Z2D3D'} == 0 & Data{:,'Sig_tuning_L'} == 1 & Data{:,'Sig_tuning_R'} == 1;
MT2D = Data(mask, :);
lm_MT2D_C = fitlm(MT2D, 'b2_C ~ Sig_Bias_C * AIOD');
anova(lm_MT2D_C)
lm_MT2D_L = fitlm(MT2D, 'b2_L ~ Sig_Bias_L * AIOD');
anova(lm_MT2D_L)
lm_MT2D_R = fitlm(MT2D, 'b2_R ~ Sig_Bias_R * AIOD');
anova(lm_MT2D_R)
lm_MT2D_S = fitlm(MT2D, 'b2_S ~ Sig_Bias_S * AIOD');
anova(lm_MT2D_S)

figure(); 
subplot(221); hold on
scatter(MT2D.AIOD(MT2D{:,'Sig_Bias_C'} == 0), MT2D.b2_C(MT2D{:,'Sig_Bias_C'} == 0))
scatter(MT2D.AIOD(MT2D{:,'Sig_Bias_C'} == 1), MT2D.b2_C(MT2D{:,'Sig_Bias_C'} == 1))

subplot(222); hold on
scatter(MT2D.AIOD(MT2D{:,'Sig_Bias_L'} == 0), MT2D.b2_L(MT2D{:,'Sig_Bias_L'} == 0))
scatter(MT2D.AIOD(MT2D{:,'Sig_Bias_L'} == 1), MT2D.b2_L(MT2D{:,'Sig_Bias_L'} == 1))

subplot(223); hold on
scatter(MT2D.AIOD(MT2D{:,'Sig_Bias_R'} == 0), MT2D.b2_R(MT2D{:,'Sig_Bias_R'} == 0))
scatter(MT2D.AIOD(MT2D{:,'Sig_Bias_R'} == 1), MT2D.b2_R(MT2D{:,'Sig_Bias_R'} == 1))

subplot(224); hold on
scatter(MT2D.AIOD(MT2D{:,'Sig_Bias_S'} == 0), MT2D.b2_S(MT2D{:,'Sig_Bias_S'} == 0))
scatter(MT2D.AIOD(MT2D{:,'Sig_Bias_S'} == 1), MT2D.b2_S(MT2D{:,'Sig_Bias_S'} == 1))

%% MT 2D sig vs insig AIOD
mask = Data{:,'ROI'} == 0 & Data{:,'Z2D3D'} == 0 & Data{:,'Sig_tuning_L'} == 1 & Data{:,'Sig_tuning_R'} == 1;
MT2D = Data(mask, :);

figure(); 

subplot(221); hold on
x = abs(MT2D.AIOD(MT2D{:,'Sig_Bias_C'} == 0));
y = abs(MT2D.AIOD(MT2D{:,'Sig_Bias_C'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['MT 2D Combined, p = ', num2str(p, 2)])

subplot(222); hold on
x = abs(MT2D.AIOD(MT2D{:,'Sig_Bias_L'} == 0));
y = abs(MT2D.AIOD(MT2D{:,'Sig_Bias_L'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['MT 2D Left, p = ', num2str(p, 2)])

subplot(223); hold on
x = abs(MT2D.AIOD(MT2D{:,'Sig_Bias_R'} == 0));
y = abs(MT2D.AIOD(MT2D{:,'Sig_Bias_R'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['MT 2D Right, p = ', num2str(p, 2)])

subplot(224); hold on
x = abs(MT2D.AIOD(MT2D{:,'Sig_Bias_S'} == 0));
y = abs(MT2D.AIOD(MT2D{:,'Sig_Bias_S'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['MT 2D Stereo, p = ', num2str(p, 2)])

%% FST 2D sig vs insig AIOD
mask = Data{:,'ROI'} == 1 & Data{:,'Z2D3D'} == 0 & Data{:,'Sig_tuning_L'} == 1 & Data{:,'Sig_tuning_R'} == 1;
FST2D = Data(mask, :);

figure(); 

subplot(221); hold on
x = abs(FST2D.AIOD(FST2D{:,'Sig_Bias_C'} == 0));
y = abs(FST2D.AIOD(FST2D{:,'Sig_Bias_C'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['FST 2D Combined, p = ', num2str(p, 2)])

subplot(222); hold on
x = abs(FST2D.AIOD(FST2D{:,'Sig_Bias_L'} == 0));
y = abs(FST2D.AIOD(FST2D{:,'Sig_Bias_L'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['FST 2D Left, p = ', num2str(p, 2)])

subplot(223); hold on
x = abs(FST2D.AIOD(FST2D{:,'Sig_Bias_R'} == 0));
y = abs(FST2D.AIOD(FST2D{:,'Sig_Bias_R'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['FST 2D Right, p = ', num2str(p, 2)])

subplot(224); hold on
x = abs(FST2D.AIOD(FST2D{:,'Sig_Bias_S'} == 0));
y = abs(FST2D.AIOD(FST2D{:,'Sig_Bias_S'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['FST 2D Stereo, p = ', num2str(p, 2)])

%% FST 3D sig vs insig AIOD
mask = Data{:,'ROI'} == 1 & Data{:,'Z2D3D'} == 1 & Data{:,'Sig_tuning_L'} == 1 & Data{:,'Sig_tuning_R'} == 1;
FST3D = Data(mask, :);

figure(); 

subplot(221); hold on
x = abs(FST3D.AIOD(FST3D{:,'Sig_Bias_C'} == 0));
y = abs(FST3D.AIOD(FST3D{:,'Sig_Bias_C'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['FST 3D Combined, p = ', num2str(p, 2)])

subplot(222); hold on
x = abs(FST3D.AIOD(FST3D{:,'Sig_Bias_L'} == 0));
y = abs(FST3D.AIOD(FST3D{:,'Sig_Bias_L'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['FST 3D Left, p = ', num2str(p, 2)])

subplot(223); hold on
x = abs(FST3D.AIOD(FST3D{:,'Sig_Bias_R'} == 0));
y = abs(FST3D.AIOD(FST3D{:,'Sig_Bias_R'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['FST 3D Right, p = ', num2str(p, 2)])

subplot(224); hold on
x = abs(FST3D.AIOD(FST3D{:,'Sig_Bias_S'} == 0));
y = abs(FST3D.AIOD(FST3D{:,'Sig_Bias_S'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['FST 3D Stereo, p = ', num2str(p, 2)])

%% MT 2D sig vs insig AI
mask = Data{:,'ROI'} == 0 & Data{:,'Z2D3D'} == 0 & Data{:,'Sig_tuning_L'} == 1 & Data{:,'Sig_tuning_R'} == 1;
MT2D = Data(mask, :);

figure(); 

subplot(221); hold on
x = abs(MT2D.AI_C(MT2D{:,'Sig_Bias_C'} == 0));
y = abs(MT2D.AI_C(MT2D{:,'Sig_Bias_C'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['MT 2D Combined, p = ', num2str(p, 2)])

subplot(222); hold on
x = abs(MT2D.AI_L(MT2D{:,'Sig_Bias_L'} == 0));
y = abs(MT2D.AI_L(MT2D{:,'Sig_Bias_L'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['MT 2D Left, p = ', num2str(p, 2)])

subplot(223); hold on
x = abs(MT2D.AI_R(MT2D{:,'Sig_Bias_R'} == 0));
y = abs(MT2D.AI_R(MT2D{:,'Sig_Bias_R'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['MT 2D Right, p = ', num2str(p, 2)])

subplot(224); hold on
x = abs(MT2D.AI_S(MT2D{:,'Sig_Bias_S'} == 0));
y = abs(MT2D.AI_S(MT2D{:,'Sig_Bias_S'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['MT 2D Stereo, p = ', num2str(p, 2)])

%% FST 2D sig vs insig AI
mask = Data{:,'ROI'} == 1 & Data{:,'Z2D3D'} == 0 & Data{:,'Sig_tuning_L'} == 1 & Data{:,'Sig_tuning_R'} == 1;
FST2D = Data(mask, :);

figure(); 

subplot(221); hold on
x = abs(FST2D.AI_C(FST2D{:,'Sig_Bias_C'} == 0));
y = abs(FST2D.AI_C(FST2D{:,'Sig_Bias_C'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['FST 2D Combined, p = ', num2str(p, 2)])

subplot(222); hold on
x = abs(FST2D.AI_L(FST2D{:,'Sig_Bias_L'} == 0));
y = abs(FST2D.AI_L(FST2D{:,'Sig_Bias_L'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['FST 2D Left, p = ', num2str(p, 2)])

subplot(223); hold on
x = abs(FST2D.AI_R(FST2D{:,'Sig_Bias_R'} == 0));
y = abs(FST2D.AI_R(FST2D{:,'Sig_Bias_R'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['FST 2D Right, p = ', num2str(p, 2)])

subplot(224); hold on
x = abs(FST2D.AI_S(FST2D{:,'Sig_Bias_S'} == 0));
y = abs(FST2D.AI_S(FST2D{:,'Sig_Bias_S'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['FST 2D Stereo, p = ', num2str(p, 2)])

%% FST 3D sig vs insig AI
mask = Data{:,'ROI'} == 1 & Data{:,'Z2D3D'} == 1 & Data{:,'Sig_tuning_L'} == 1 & Data{:,'Sig_tuning_R'} == 1;
FST3D = Data(mask, :);

figure(); 

subplot(221); hold on
x = abs(FST3D.AI_C(FST3D{:,'Sig_Bias_C'} == 0));
y = abs(FST3D.AI_C(FST3D{:,'Sig_Bias_C'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['FST 3D Combined, p = ', num2str(p, 2)])

subplot(222); hold on
x = abs(FST3D.AI_L(FST3D{:,'Sig_Bias_L'} == 0));
y = abs(FST3D.AI_L(FST3D{:,'Sig_Bias_L'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['FST 3D Left, p = ', num2str(p, 2)])

subplot(223); hold on
x = abs(FST3D.AI_R(FST3D{:,'Sig_Bias_R'} == 0));
y = abs(FST3D.AI_R(FST3D{:,'Sig_Bias_R'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['FST 3D Right, p = ', num2str(p, 2)])

subplot(224); hold on
x = abs(FST3D.AI_S(FST3D{:,'Sig_Bias_S'} == 0));
y = abs(FST3D.AI_S(FST3D{:,'Sig_Bias_S'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['FST 3D Stereo, p = ', num2str(p, 2)])

%% MT 2D sig vs insig OD
mask = Data{:,'ROI'} == 0 & Data{:,'Z2D3D'} == 0 & Data{:,'Sig_tuning_L'} == 1 & Data{:,'Sig_tuning_R'} == 1;
MT2D = Data(mask, :);

figure(); 

subplot(221); hold on
x = abs(MT2D.OD(MT2D{:,'Sig_Bias_C'} == 0));
y = abs(MT2D.OD(MT2D{:,'Sig_Bias_C'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['MT 2D Combined, p = ', num2str(p, 2)])

subplot(222); hold on
x = abs(MT2D.OD(MT2D{:,'Sig_Bias_L'} == 0));
y = abs(MT2D.OD(MT2D{:,'Sig_Bias_L'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['MT 2D Left, p = ', num2str(p, 2)])

subplot(223); hold on
x = abs(MT2D.OD(MT2D{:,'Sig_Bias_R'} == 0));
y = abs(MT2D.OD(MT2D{:,'Sig_Bias_R'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['MT 2D Right, p = ', num2str(p, 2)])

subplot(224); hold on
x = abs(MT2D.OD(MT2D{:,'Sig_Bias_S'} == 0));
y = abs(MT2D.OD(MT2D{:,'Sig_Bias_S'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['MT 2D Stereo, p = ', num2str(p, 2)])

%% FST 2D sig vs insig OD
mask = Data{:,'ROI'} == 1 & Data{:,'Z2D3D'} == 0 & Data{:,'Sig_tuning_L'} == 1 & Data{:,'Sig_tuning_R'} == 1;
FST2D = Data(mask, :);

figure(); 

subplot(221); hold on
x = abs(FST2D.OD(FST2D{:,'Sig_Bias_C'} == 0));
y = abs(FST2D.OD(FST2D{:,'Sig_Bias_C'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['FST 2D Combined, p = ', num2str(p, 2)])

subplot(222); hold on
x = abs(FST2D.OD(FST2D{:,'Sig_Bias_L'} == 0));
y = abs(FST2D.OD(FST2D{:,'Sig_Bias_L'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['FST 2D Left, p = ', num2str(p, 2)])

subplot(223); hold on
x = abs(FST2D.OD(FST2D{:,'Sig_Bias_R'} == 0));
y = abs(FST2D.OD(FST2D{:,'Sig_Bias_R'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['FST 2D Right, p = ', num2str(p, 2)])

subplot(224); hold on
x = abs(FST2D.OD(FST2D{:,'Sig_Bias_S'} == 0));
y = abs(FST2D.OD(FST2D{:,'Sig_Bias_S'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['FST 2D Stereo, p = ', num2str(p, 2)])

%% FST 3D sig vs insig OD
mask = Data{:,'ROI'} == 1 & Data{:,'Z2D3D'} == 1 & Data{:,'Sig_tuning_L'} == 1 & Data{:,'Sig_tuning_R'} == 1;
FST3D = Data(mask, :);

figure(); 

subplot(221); hold on
x = abs(FST3D.OD(FST3D{:,'Sig_Bias_C'} == 0));
y = abs(FST3D.OD(FST3D{:,'Sig_Bias_C'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['FST 3D Combined, p = ', num2str(p, 2)])

subplot(222); hold on
x = abs(FST3D.OD(FST3D{:,'Sig_Bias_L'} == 0));
y = abs(FST3D.OD(FST3D{:,'Sig_Bias_L'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['FST 3D Left, p = ', num2str(p, 2)])

subplot(223); hold on
x = abs(FST3D.OD(FST3D{:,'Sig_Bias_R'} == 0));
y = abs(FST3D.OD(FST3D{:,'Sig_Bias_R'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['FST 3D Right, p = ', num2str(p, 2)])

subplot(224); hold on
x = abs(FST3D.OD(FST3D{:,'Sig_Bias_S'} == 0));
y = abs(FST3D.OD(FST3D{:,'Sig_Bias_S'} == 1));
p = plot_sigVSnonsig_hist(x, y);
title(['FST 3D Stereo, p = ', num2str(p, 2)])
%%
function plotCateg_hist(bias_MT_C)
% M is Nx2: col1 = values, col2 = marks (0/1)
x = bias_MT_C(:,1);
m = bias_MT_C(:,2);

nbins = 40;
edges = linspace(min(x), max(x), nbins+1);

% Counts per bin for each mark, using the SAME edges
c0 = histcounts(x(m==0), edges);
c1 = histcounts(x(m==1), edges);

% Bin centers for plotting bars
centers = edges(1:end-1) + diff(edges)/2;

% Plot stacked bars: first white (mark==0), then black (mark==1)
hold on
h = bar(centers, [c0(:) c1(:)], 'stacked', 'BarWidth', 1);

% Style: white and black
h(1).FaceColor = [1 1 1];   % white
h(1).EdgeColor = [0 0 0];   % black outline helps visibility
h(2).FaceColor = [0 0 0];   % black
h(2).EdgeColor = [0 0 0];

xlabel('Value');
ylabel('Count');
legend({'Insig','Sig'}, 'Location','best');
box on
end

%%
function p = plot_sigVSnonsig_hist(x, y)
histogram(x, 'BinWidth', 0.05)
histogram(y, 'BinWidth', 0.05)
p = ranksum(x, y);

end

function plot_sigVSnonsig_KS(x, y)
[h,p,ksstat] = kstest2(x, y);

fprintf('KS test: h=%d, p=%.3g, D=%.4f\n', h, p, ksstat);

% Plot empirical CDFs on the same figure
cdfplot(x);
cdfplot(y);

% Make them easy to distinguish
ln = findobj(gca,'Type','line');
% cdfplot adds lines; last plotted is typically first in ln, so label robustly:
set(ln(1), 'LineWidth', 2, 'LineStyle','-'); % y
set(ln(2), 'LineWidth', 2, 'LineStyle','-');  % x

grid on;
xlabel('Value');
ylabel('Empirical CDF');
legend({'x','y'}, 'Location','best');

title(sprintf('2-sample KS: D=%.3f, p=%.3g', ksstat, p));
end
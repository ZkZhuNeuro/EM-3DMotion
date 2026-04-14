clear;
load('UnitTable_updating.mat')

load("P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\BehaviorFitting\BehaviorData_Clay.mat")
Clay_nonStim = BehaviorData_nonStim_pFit_all;
Clay_Stim = BehaviorData_Stim_pFit_all;

load("P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\BehaviorFitting\BehaviorData_Jim.mat")
Jim_nonStim = BehaviorData_nonStim_pFit_all;
Jim_Stim = BehaviorData_Stim_pFit_all;

Data_N = [Jim_nonStim; Clay_nonStim];
Data_S = [Jim_Stim;  Clay_Stim];

clear BehaviorData_nonStim_pFit_all BehaviorData_Stim_pFit_all Jim_nonStim Clay_nonStim Jim_Stim Clay_Stim
%%
if ~ismember('Behav_mdl_full', unit_table.Properties.VariableNames)
    unit_table.Behav_mdl_full = cell(height(unit_table), 1);
end
if ~ismember('Behav_mdl_BiasOnly', unit_table.Properties.VariableNames)
    unit_table.Behav_mdl_BiasOnly = cell(height(unit_table), 1);
end
if ~ismember('Behav_mdl_null', unit_table.Properties.VariableNames)
    unit_table.Behav_mdl_null = cell(height(unit_table), 1);
end
if ~ismember('Behav_fullVSnull_p', unit_table.Properties.VariableNames)
    unit_table.Behav_fullVSnull_p = cell(height(unit_table), 1);
end
if ~ismember('Behav_biasOnlyVSnull_p', unit_table.Properties.VariableNames)
    unit_table.Behav_biasOnlyVSnull_p = cell(height(unit_table), 1);
end
% for i_rec = 1
for i_rec = 1:size(unit_table, 1)
    for i_cue = 1:size(Data_N{i_rec}, 2)
% for i_rec = 1
%     for i_cue = 1
        Behav_N = Data_N{i_rec}(i_cue).data;
        Behav_S = Data_S{i_rec}(i_cue).data;

        % build a table for the GLM model
        coh = [Behav_N(:, 1); Behav_S(:, 1)]; % Coherence
        y   = [Behav_N(:, 2); Behav_S(:, 2)]; 
        n   = [Behav_N(:, 3); Behav_S(:, 3)];
        s   = [zeros(numel(Behav_N(:, 1)),1); ones(numel(Behav_S(:, 1)),1)];

        tbl = table(coh, s, y, n);

        % Full model: coh + stim + coh*stim0
        mdl_full = fitglm(tbl, 'y ~ coh + s + coh:s', ...
            'Distribution','binomial', 'BinomialSize', tbl.n);

        % Full model: coh + stim
        mdl_BiasOnly = fitglm(tbl, 'y ~ coh + s', ...
            'Distribution','binomial', 'BinomialSize', tbl.n);

        % Null model: same curve (no stim terms)
        mdl_null = fitglm(tbl, 'y ~ coh', ...
            'Distribution','binomial', 'BinomialSize', tbl.n);

        % Likelihood-ratio (deviance) test: full VS null
        D_fVSn = mdl_null.Deviance - mdl_full.Deviance;
        df_fVSn = mdl_null.DFE - mdl_full.DFE;   % should be 2
        p_fVSn = 1 - chi2cdf(D_fVSn, df_fVSn);

        % Likelihood-ratio (deviance) test: BiasOnly VS null
        D_bVSn = mdl_null.Deviance - mdl_BiasOnly.Deviance;
        df_bVSn = mdl_null.DFE - mdl_BiasOnly.DFE;   % should be 1
        p_bVSn = 1 - chi2cdf(D_bVSn, df_bVSn);

        % fprintf('LRT: D=%.3f, df=%d, p=%.4g\n', D, df, p);
        unit_table.Behav_mdl_full{i_rec}{i_cue} = mdl_full;
        unit_table.Behav_mdl_BiasOnly{i_rec}{i_cue} = mdl_BiasOnly;
        unit_table.Behav_mdl_null{i_rec}{i_cue} = mdl_null;
        unit_table.Behav_fullVSnull_p{i_rec}(i_cue) = p_fVSn;
        unit_table.Behav_biasOnlyVSnull_p{i_rec}(i_cue) = p_bVSn;
    end
end

%% Check population results
Bias_ori = NaN(size(unit_table, 1), 4);
B2_biasOnly = NaN(size(unit_table, 1), 4);
B2_full = NaN(size(unit_table, 1), 4);
p_fVSn = NaN(size(unit_table, 1), 4);
p_bVSn = NaN(size(unit_table, 1), 4);
bias_fVSn = NaN(size(unit_table, 1), 4);

for i_rec = 1:size(unit_table, 1)
    Bias_ori(i_rec, :) = unit_table.Delta_bias{i_rec};
    p_fVSn(i_rec, :) = unit_table.Behav_fullVSnull_p{i_rec};
    p_bVSn(i_rec, :) = unit_table.Behav_biasOnlyVSnull_p{i_rec};
    B2_biasOnly_rec = NaN(1, 4);
    B2_full_rec = NaN(1, 4);
    for i_cue = 1:4
        b0_f = unit_table.Behav_mdl_full{i_rec}{i_cue}.Coefficients{1, 'Estimate'};
        b1_f = unit_table.Behav_mdl_full{i_rec}{i_cue}.Coefficients{'coh', 'Estimate'};
        b2_f = unit_table.Behav_mdl_full{i_rec}{i_cue}.Coefficients{'s', 'Estimate'};
        b3_f = unit_table.Behav_mdl_full{i_rec}{i_cue}.Coefficients{'coh:s', 'Estimate'};
        c_n = -b0_f/b1_f; 
        c_s = -(b0_f + b2_f)/(b1_f + b3_f);
        bias_fVSn(i_rec, i_cue) = c_s - c_n;
        B2_biasOnly_rec(i_cue) = unit_table.Behav_mdl_full{i_rec}{i_cue}.Coefficients{'s', 'Estimate'};
        B2_full_rec(i_cue) = unit_table.Behav_mdl_BiasOnly{i_rec}{i_cue}.Coefficients{'s', 'Estimate'};
    end
    B2_biasOnly(i_rec, :) = B2_biasOnly_rec;
    B2_full(i_rec, :) = B2_full_rec;
end

% figure(); 
% scatter(abs(reshape(Bias_ori, 1, [])), reshape(p_fVSn, 1, []))
% figure(); 
% scatter(abs(reshape(Bias_ori, 1, [])), reshape(p_bVSn, 1, []))
% %%
% figure(); 
% scatter(reshape(Bias_ori, 1, []), reshape(B2_biasOnly, 1, []))
% figure(); 
% scatter(Bias_ori, B2_full)
% figure(); 
% scatter(Bias_ori, bias_fVSn)
figure(); 
scatter(Bias_ori, B2_full, 'filled', 'MarkerFaceAlpha', 0.5)
legend({'Comb', 'Left', 'Right', 'Stereo'})
xlabel('Original biases')
ylabel('b2 from the full GLM')

figure(); 
scatter(Bias_ori, B2_biasOnly, 'filled', 'MarkerFaceAlpha', 0.5)
legend({'Comb', 'Left', 'Right', 'Stereo'})
xlabel('Original biases')
ylabel('b2 from the bias only GLM')

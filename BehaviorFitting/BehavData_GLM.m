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
if ~ismember('Behav_fullVSnull_p', unit_table.Properties.VariableNames)
    unit_table.Behav_fullVSnull_p = cell(height(unit_table), 1);
end
if ~ismember('Behav_yDistAtCoh0', unit_table.Properties.VariableNames)
    unit_table.Behav_yDistAtCoh0 = cell(height(unit_table), 1);
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


        % Likelihood-ratio (deviance) test: full VS null
        D_fVSn = mdl_null.Deviance - mdl_full.Deviance;
        df_fVSn = mdl_null.DFE - mdl_full.DFE;   % should be 2
        p_fVSn = 1 - chi2cdf(D_fVSn, df_fVSn);

        % predicted probabilities at coh = 0
        tbl0 = table([0;0], [0;1], 'VariableNames', {'coh','s'});
        p0 = predict(mdl_full, tbl0);   % p0(1)=s0, p0(2)=s1

        yDistAtCoh0 = p0(2) - p0(1);

        % fprintf('LRT: D=%.3f, df=%d, p=%.4g\n', D, df, p);
        unit_table.Behav_mdl_full{i_rec}{i_cue} = mdl_full;
        unit_table.Behav_fullVSnull_p{i_rec}(i_cue) = p_fVSn;
        unit_table.Behav_yDistAtCoh0{i_rec}(i_cue) = yDistAtCoh0;
    end
end

%% Check population results
Bias_ori = NaN(size(unit_table, 1), 4);
B2_full = NaN(size(unit_table, 1), 4);
B3_full = NaN(size(unit_table, 1), 4);
p_fVSn = NaN(size(unit_table, 1), 4);
yDist = NaN(size(unit_table, 1), 4);

for i_rec = 1:size(unit_table, 1)
    Bias_ori(i_rec, :) = unit_table.Delta_bias{i_rec};
    p_fVSn(i_rec, :) = unit_table.Behav_fullVSnull_p{i_rec};
    B2_full_rec = NaN(1, 4);
    for i_cue = 1:4
        b0_f = unit_table.Behav_mdl_full{i_rec}{i_cue}.Coefficients{1, 'Estimate'};
        b1_f = unit_table.Behav_mdl_full{i_rec}{i_cue}.Coefficients{'coh', 'Estimate'};
        b2_f = unit_table.Behav_mdl_full{i_rec}{i_cue}.Coefficients{'s', 'Estimate'};
        b3_f = unit_table.Behav_mdl_full{i_rec}{i_cue}.Coefficients{'coh:s', 'Estimate'};
        c_n = -b0_f/b1_f; 
        c_s = -(b0_f + b2_f)/(b1_f + b3_f);
        B2_full_rec(i_cue) = unit_table.Behav_mdl_BiasOnly{i_rec}{i_cue}.Coefficients{'s', 'Estimate'};
        yDist(i_rec, i_cue) = unit_table.Behav_yDistAtCoh0{i_rec}(i_cue);
        B3_full(i_rec, i_cue) = b3_f;
    end
    B2_full(i_rec, :) = B2_full_rec;
end

%%
figure();
y_plot = sign(B2_full) .* log(abs(B2_full) + 1);
scatter(Bias_ori, y_plot, 'filled', 'MarkerFaceAlpha', 0.5)

legend({'Comb', 'Left', 'Right', 'Stereo'})
xlabel('Original biases')
ylabel('signed log_{e}(b2)')
axis square

%%
figure();
y_plot = sign(B3_full) .* log(abs(B3_full) + 1);
scatter(Bias_ori, y_plot, 'filled', 'MarkerFaceAlpha', 0.5)

legend({'Comb', 'Left', 'Right', 'Stereo'})
xlabel('Original biases')
ylabel('signed log_{e}(b3)')
axis square

%%
figure(); 
scatter(Bias_ori, yDist, 'filled', 'MarkerFaceAlpha', 0.5)
legend({'Comb', 'Left', 'Right', 'Stereo'})
xlabel('Original biases')
ylabel('yDist from GLM')
axis square

clear;
reanalysis = 0;
individualPlot = 0;

%% load raw behavior data
load("P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\BehaviorFitting\BehaviorData_Clay.mat")
Clay_nonStim = BehaviorData_nonStim_pFit_all;
Clay_Stim = BehaviorData_Stim_pFit_all;

load("P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\BehaviorFitting\BehaviorData_Jim.mat")
Jim_nonStim = BehaviorData_nonStim_pFit_all;
Jim_Stim = BehaviorData_Stim_pFit_all;

Data_N = [Jim_nonStim; Clay_nonStim];
Data_S = [Jim_Stim;  Clay_Stim];

clear BehaviorData_nonStim_pFit_all BehaviorData_Stim_pFit_all Jim_nonStim Clay_nonStim Jim_Stim Clay_Stim

inclusionData = load("C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\BehaviorFitting\inclusion_index.mat");
inclusionFields = fieldnames(inclusionData);
inclusion_idx = [];
for i_field = 1:numel(inclusionFields)
    candidate = inclusionData.(inclusionFields{i_field});
    if islogical(candidate) && isvector(candidate) && numel(candidate) == numel(Data_N)
        inclusion_idx = candidate(:);
        break
    end
end
assert(~isempty(inclusion_idx), 'Could not find a logical inclusion index matching the number of sessions.');
origRecIdx = find(inclusion_idx);
clear inclusionData inclusionFields candidate i_field

n_boot = 1000;

%%
if reanalysis == 1
    load('UnitTable_updating.mat');
    assert(height(unit_table) == numel(inclusion_idx), ...
        'inclusion_idx length does not match UnitTable_updating.mat');
    unit_table = unit_table(inclusion_idx, :);
    Data_N = Data_N(inclusion_idx);
    Data_S = Data_S(inclusion_idx);

    %% add fields if missing
    if ~ismember('Behav_mdl_full', unit_table.Properties.VariableNames)
        unit_table.Behav_mdl_full = cell(height(unit_table), 1);
    end
    if ~ismember('Behav_mdl_null', unit_table.Properties.VariableNames)
        unit_table.Behav_mdl_null = cell(height(unit_table), 1);
    end
    if ~ismember('Behav_fullVSnull_p', unit_table.Properties.VariableNames)
        unit_table.Behav_fullVSnull_p = cell(height(unit_table), 1);
    end
    if ~ismember('Behav_boot_betas', unit_table.Properties.VariableNames)
        unit_table.Behav_boot_betas = cell(height(unit_table), 1);
    end
    if ~ismember('Behav_boot_validN', unit_table.Properties.VariableNames)
        unit_table.Behav_boot_validN = cell(height(unit_table), 1);
    end

    if ~ismember('Behav_mdl_N', unit_table.Properties.VariableNames)
        unit_table.Behav_mdl_N = cell(height(unit_table), 1);
    end
    if ~ismember('Behav_mdl_S', unit_table.Properties.VariableNames)
        unit_table.Behav_mdl_S = cell(height(unit_table), 1);
    end
    if ~ismember('Behav_N_chi2', unit_table.Properties.VariableNames)
        unit_table.Behav_N_chi2 = cell(height(unit_table), 1);
    end
    if ~ismember('Behav_N_chi2_df', unit_table.Properties.VariableNames)
        unit_table.Behav_N_chi2_df = cell(height(unit_table), 1);
    end
    if ~ismember('Behav_N_chi2_p', unit_table.Properties.VariableNames)
        unit_table.Behav_N_chi2_p = cell(height(unit_table), 1);
    end
    if ~ismember('Behav_S_chi2', unit_table.Properties.VariableNames)
        unit_table.Behav_S_chi2 = cell(height(unit_table), 1);
    end
    if ~ismember('Behav_S_chi2_df', unit_table.Properties.VariableNames)
        unit_table.Behav_S_chi2_df = cell(height(unit_table), 1);
    end
    if ~ismember('Behav_S_chi2_p', unit_table.Properties.VariableNames)
        unit_table.Behav_S_chi2_p = cell(height(unit_table), 1);
    end

    for i_rec = 1:size(unit_table, 1)
        n_cues_this_rec = size(Data_N{i_rec}, 2);

        if isempty(unit_table.Behav_mdl_full{i_rec})
            unit_table.Behav_mdl_full{i_rec} = cell(1, n_cues_this_rec);
        end
        if isempty(unit_table.Behav_mdl_null{i_rec})
            unit_table.Behav_mdl_null{i_rec} = cell(1, n_cues_this_rec);
        end
        if isempty(unit_table.Behav_mdl_N{i_rec})
            unit_table.Behav_mdl_N{i_rec} = cell(1, n_cues_this_rec);
        end
        if isempty(unit_table.Behav_mdl_S{i_rec})
            unit_table.Behav_mdl_S{i_rec} = cell(1, n_cues_this_rec);
        end
        if isempty(unit_table.Behav_boot_betas{i_rec})
            unit_table.Behav_boot_betas{i_rec} = cell(1, n_cues_this_rec);
        end

        for i_cue = 1:n_cues_this_rec
            Behav_N = Data_N{i_rec}(i_cue).data;
            Behav_S = Data_S{i_rec}(i_cue).data;

            % -------- Combined table for full/null comparison --------
            coh = [Behav_N(:, 1); Behav_S(:, 1)];
            y   = [Behav_N(:, 2); Behav_S(:, 2)];
            n   = [Behav_N(:, 3); Behav_S(:, 3)];
            s   = [zeros(size(Behav_N, 1), 1); ones(size(Behav_S, 1), 1)];

            tbl = table(coh, s, y, n);
            valid = tbl.n > 0 & tbl.coh ~= 0 & ...
                ~isnan(tbl.coh) & ~isnan(tbl.y) & ~isnan(tbl.n);
            tbl = tbl(valid, :);

            if height(tbl) < 4
                unit_table.Behav_mdl_full{i_rec}{i_cue} = [];
                unit_table.Behav_mdl_null{i_rec}{i_cue} = [];
                unit_table.Behav_fullVSnull_p{i_rec}(i_cue) = NaN;
                unit_table.Behav_boot_betas{i_rec}{i_cue} = nan(n_boot, 4);
                unit_table.Behav_boot_validN{i_rec}(i_cue) = 0;
            else
                mdl_full = fitglm(tbl, 'y ~ coh + s + coh:s', ...
                    'Distribution', 'binomial', 'BinomialSize', tbl.n);

                mdl_null = fitglm(tbl, 'y ~ coh', ...
                    'Distribution', 'binomial', 'BinomialSize', tbl.n);

                D_fVSn = mdl_null.Deviance - mdl_full.Deviance;
                df_fVSn = mdl_null.DFE - mdl_full.DFE;
                p_fVSn = 1 - chi2cdf(D_fVSn, df_fVSn);

                unit_table.Behav_mdl_full{i_rec}{i_cue} = mdl_full;
                unit_table.Behav_mdl_null{i_rec}{i_cue} = mdl_null;
                unit_table.Behav_fullVSnull_p{i_rec}(i_cue) = p_fVSn;

                % -------- Bootstrap on combined model --------
                p_obs = zeros(size(tbl.y));
                valid_rows = tbl.n > 0 & ~isnan(tbl.y) & ~isnan(tbl.n);
                p_obs(valid_rows) = tbl.y(valid_rows) ./ tbl.n(valid_rows);
                p_obs = min(max(p_obs, 0), 1);

                boot_betas = nan(n_boot, 4);

                for i_boot = 1:n_boot
                    tbl_boot = tbl;
                    tbl_boot.y(valid_rows) = binornd(tbl.n(valid_rows), p_obs(valid_rows));

                    try
                        mdl_boot = fitglm(tbl_boot, 'y ~ coh + s + coh:s', ...
                            'Distribution', 'binomial', 'BinomialSize', tbl_boot.n);

                        beta_hat = mdl_boot.Coefficients.Estimate;
                        boot_betas(i_boot, 1:numel(beta_hat)) = beta_hat(:)';
                    catch
                    end
                end

                unit_table.Behav_boot_betas{i_rec}{i_cue} = boot_betas;
                unit_table.Behav_boot_validN{i_rec}(i_cue) = sum(all(~isnan(boot_betas), 2));
            end

            % -------- Pearson GOF for N --------
            tbl_N = table(Behav_N(:,1), Behav_N(:,2), Behav_N(:,3), ...
                'VariableNames', {'coh','y','n'});
            valid_N = tbl_N.n > 0 & tbl_N.coh ~= 0 & ...
                ~isnan(tbl_N.coh) & ~isnan(tbl_N.y) & ~isnan(tbl_N.n);
            tbl_N = tbl_N(valid_N, :);

            if height(tbl_N) >= 3
                mdl_N = fitglm(tbl_N, 'y ~ coh', ...
                    'Distribution', 'binomial', 'BinomialSize', tbl_N.n);
                [chi2_N, df_N, p_N] = pearson_gof_binomial(mdl_N, tbl_N);
            else
                mdl_N = [];
                chi2_N = NaN; df_N = NaN; p_N = NaN;
            end

            unit_table.Behav_mdl_N{i_rec}{i_cue} = mdl_N;
            unit_table.Behav_N_chi2{i_rec}(i_cue) = chi2_N;
            unit_table.Behav_N_chi2_df{i_rec}(i_cue) = df_N;
            unit_table.Behav_N_chi2_p{i_rec}(i_cue) = p_N;

            % -------- Pearson GOF for S --------
            tbl_S = table(Behav_S(:,1), Behav_S(:,2), Behav_S(:,3), ...
                'VariableNames', {'coh','y','n'});
            valid_S = tbl_S.n > 0 & tbl_S.coh ~= 0 & ...
                ~isnan(tbl_S.coh) & ~isnan(tbl_S.y) & ~isnan(tbl_S.n);
            tbl_S = tbl_S(valid_S, :);

            if height(tbl_S) >= 3
                mdl_S = fitglm(tbl_S, 'y ~ coh', ...
                    'Distribution', 'binomial', 'BinomialSize', tbl_S.n);
                [chi2_S, df_S, p_S] = pearson_gof_binomial(mdl_S, tbl_S);
            else
                mdl_S = [];
                chi2_S = NaN; df_S = NaN; p_S = NaN;
            end

            unit_table.Behav_mdl_S{i_rec}{i_cue} = mdl_S;
            unit_table.Behav_S_chi2{i_rec}(i_cue) = chi2_S;
            unit_table.Behav_S_chi2_df{i_rec}(i_cue) = df_S;
            unit_table.Behav_S_chi2_p{i_rec}(i_cue) = p_S;
        end
    end

else
    load("C:\EM\BehaviorFitting\unit_table_GLMAssess.mat")
    assert(height(unit_table) == numel(inclusion_idx), ...
        'inclusion_idx length does not match unit_table_GLMAssess.mat');
    unit_table = unit_table(inclusion_idx, :);
    Data_N = Data_N(inclusion_idx);
    Data_S = Data_S(inclusion_idx);
end

%%
function [X2, df, p] = pearson_gof_binomial(mdl, tbl)
p_hat = predict(mdl, tbl(:, 'coh'));
p_hat = min(max(p_hat, 1e-6), 1 - 1e-6);

y = tbl.y;
n = tbl.n;

X2 = sum((y - n .* p_hat).^2 ./ (n .* p_hat .* (1 - p_hat)));

k = numel(mdl.Coefficients.Estimate);
df = height(tbl) - k;

if df > 0
    p = 1 - chi2cdf(X2, df);
else
    p = NaN;
end
end

%%
%% Bootstrap CI of coh at predicted p = 0.5 from the full model
n_rec = size(unit_table, 1);
n_cues = 4;

Behav_coh50_N_hat     = nan(n_rec, n_cues);
Behav_coh50_S_hat     = nan(n_rec, n_cues);
Behav_coh50_N_CI_low  = nan(n_rec, n_cues);
Behav_coh50_N_CI_high = nan(n_rec, n_cues);
Behav_coh50_S_CI_low  = nan(n_rec, n_cues);
Behav_coh50_S_CI_high = nan(n_rec, n_cues);

Behav_coh50_N_boot = cell(n_rec, n_cues);
Behav_coh50_S_boot = cell(n_rec, n_cues);

for i_rec = 1:n_rec
    if isempty(unit_table.Behav_mdl_full{i_rec}) || isempty(unit_table.Behav_boot_betas{i_rec})
        continue
    end

    n_cues_this = min([n_cues, numel(unit_table.Behav_mdl_full{i_rec}), numel(unit_table.Behav_boot_betas{i_rec})]);

    for i_cue = 1:n_cues_this
        mdl_full = unit_table.Behav_mdl_full{i_rec}{i_cue};
        boot_betas = unit_table.Behav_boot_betas{i_rec}{i_cue};

        if isempty(mdl_full) || isempty(boot_betas)
            continue
        end

        beta_full = mdl_full.Coefficients.Estimate;
        if numel(beta_full) < 4
            continue
        end

        b0 = beta_full(1);
        b1 = beta_full(2);
        b2 = beta_full(3);
        b3 = beta_full(4);

        if abs(b1) > 1e-10
            Behav_coh50_N_hat(i_rec, i_cue) = -b0 / b1;
        end

        if abs(b1 + b3) > 1e-10
            Behav_coh50_S_hat(i_rec, i_cue) = -(b0 + b2) / (b1 + b3);
        end

        if size(boot_betas, 2) < 4
            continue
        end

        valid_boot = all(~isnan(boot_betas(:,1:4)), 2);
        bb = boot_betas(valid_boot, 1:4);

        if isempty(bb)
            continue
        end

        b0b = bb(:,1);
        b1b = bb(:,2);
        b2b = bb(:,3);
        b3b = bb(:,4);

        coh50_N_boot = nan(size(b0b));
        coh50_S_boot = nan(size(b0b));

        idxN = abs(b1b) > 1e-10;
        coh50_N_boot(idxN) = -b0b(idxN) ./ b1b(idxN);

        idxS = abs(b1b + b3b) > 1e-10;
        coh50_S_boot(idxS) = -(b0b(idxS) + b2b(idxS)) ./ (b1b(idxS) + b3b(idxS));

        xN = coh50_N_boot(isfinite(coh50_N_boot));
        xS = coh50_S_boot(isfinite(coh50_S_boot));

        if ~isempty(xN)
            CI_N = prctile(xN, [5 95]);
            Behav_coh50_N_CI_low(i_rec, i_cue)  = CI_N(1);
            Behav_coh50_N_CI_high(i_rec, i_cue) = CI_N(2);
        end

        if ~isempty(xS)
            CI_S = prctile(xS, [5 95]);
            Behav_coh50_S_CI_low(i_rec, i_cue)  = CI_S(1);
            Behav_coh50_S_CI_high(i_rec, i_cue) = CI_S(2);
        end

        Behav_coh50_N_boot{i_rec, i_cue} = coh50_N_boot;
        Behav_coh50_S_boot{i_rec, i_cue} = coh50_S_boot;
    end
end

%% convert chi2 from cells to matrices if needed
if ~exist('Behav_N_chi2', 'var') || ~exist('Behav_S_chi2', 'var')
    Behav_N_chi2 = nan(n_rec, n_cues);
    Behav_S_chi2 = nan(n_rec, n_cues);

    for i_rec = 1:n_rec
        if ~isempty(unit_table.Behav_N_chi2{i_rec})
            n_this = min(n_cues, numel(unit_table.Behav_N_chi2{i_rec}));
            Behav_N_chi2(i_rec, 1:n_this) = unit_table.Behav_N_chi2{i_rec}(1:n_this);
        end
        if ~isempty(unit_table.Behav_S_chi2{i_rec})
            n_this = min(n_cues, numel(unit_table.Behav_S_chi2{i_rec}));
            Behav_S_chi2(i_rec, 1:n_this) = unit_table.Behav_S_chi2{i_rec}(1:n_this);
        end
    end
end

Behav_coh50_N_CI_width = Behav_coh50_N_CI_high - Behav_coh50_N_CI_low;
Behav_coh50_S_CI_width = Behav_coh50_S_CI_high - Behav_coh50_S_CI_low;

%%
poorFitThresh = 2;

overfit_idx_S = Behav_coh50_S_CI_width > poorFitThresh;
overfit_idx = overfit_idx_S; % keep the original variable name for the S condition
overfit_rec = origRecIdx(any(overfit_idx_S, 2));
goodfit_idx_S = isfinite(Behav_coh50_S_CI_width) & ~overfit_idx_S;

overfit_idx_N = Behav_coh50_N_CI_width > poorFitThresh;
overfit_rec_N = origRecIdx(any(overfit_idx_N, 2));
goodfit_idx_N = isfinite(Behav_coh50_N_CI_width) & ~overfit_idx_N;

%% count poor fits
amt_poorFit = sum(overfit_idx_S, 'all');
amt_poorFit_S = amt_poorFit;
amt_poorFit_N = sum(overfit_idx_N, 'all');
amt_goodFit_S = sum(goodfit_idx_S, 'all');
amt_goodFit_N = sum(goodfit_idx_N, 'all');

%% build table for poor-fit S entries
ROI_list = {};
Z3D_v_Z2D_list = [];
rec_list = [];
cue_list = [];
pAI = [];
TuningSig = [];

for i_rec = 1:size(unit_table, 1)
    for i_cue = 1:4
        if overfit_idx_S(i_rec, i_cue) == 1
            ROI_list{end+1,1} = unit_table.ROI{i_rec};
            Z3D_v_Z2D_list(end+1,1) = unit_table.Z3D_v_Z2D{i_rec};
            rec_list(end+1,1) = origRecIdx(i_rec);
            cue_list(end+1,1) = i_cue;
            pAI(end+1, :) = unit_table.p_AI{i_rec};

            if unit_table.p_AI{i_rec}(2) < 0.05 && unit_table.p_AI{i_rec}(3) < 0.05
                TuningSig(end+1, 1) = 2;
            elseif unit_table.p_AI{i_rec}(2) < 0.05 || unit_table.p_AI{i_rec}(3) < 0.05
                TuningSig(end+1, 1) = 1;
            else
                TuningSig(end+1, 1) = 0;
            end
        end
    end
end

poorFitTable = table(rec_list, cue_list, ROI_list, Z3D_v_Z2D_list, TuningSig, ...
    'VariableNames', {'RecIdx', 'CueIdx', 'ROI', 'Z3D_v_Z2D', 'TuningSig'});

disp(poorFitTable)

%% classify poor-fit S entries
n = height(poorFitTable);
Category = strings(n,1);

for i = 1:n
    if poorFitTable.TuningSig(i) == 2
        if poorFitTable.Z3D_v_Z2D(i) < 0
            Category(i) = "2D";
        elseif poorFitTable.Z3D_v_Z2D(i) > 0
            Category(i) = "3D";
        else
            Category(i) = "2D/3D boundary";
        end
    elseif poorFitTable.TuningSig(i) == 1
        Category(i) = "Mono";
    elseif poorFitTable.TuningSig(i) == 0
        Category(i) = "None";
    else
        Category(i) = "Unknown";
    end
end

poorFitTable.Category = Category;

%% build table for poor-fit N entries
ROI_list_N = {};
Z3D_v_Z2D_list_N = [];
rec_list_N = [];
cue_list_N = [];
pAI_N = [];
TuningSig_N = [];

for i_rec = 1:size(unit_table, 1)
    for i_cue = 1:4
        if overfit_idx_N(i_rec, i_cue) == 1
            ROI_list_N{end+1,1} = unit_table.ROI{i_rec};
            Z3D_v_Z2D_list_N(end+1,1) = unit_table.Z3D_v_Z2D{i_rec};
            rec_list_N(end+1,1) = origRecIdx(i_rec);
            cue_list_N(end+1,1) = i_cue;
            pAI_N(end+1, :) = unit_table.p_AI{i_rec};

            if unit_table.p_AI{i_rec}(2) < 0.05 && unit_table.p_AI{i_rec}(3) < 0.05
                TuningSig_N(end+1, 1) = 2;
            elseif unit_table.p_AI{i_rec}(2) < 0.05 || unit_table.p_AI{i_rec}(3) < 0.05
                TuningSig_N(end+1, 1) = 1;
            else
                TuningSig_N(end+1, 1) = 0;
            end
        end
    end
end

poorFitTable_N = table(rec_list_N, cue_list_N, ROI_list_N, Z3D_v_Z2D_list_N, TuningSig_N, ...
    'VariableNames', {'RecIdx', 'CueIdx', 'ROI', 'Z3D_v_Z2D', 'TuningSig'});

disp(poorFitTable_N)

%% classify poor-fit N entries
n_N = height(poorFitTable_N);
Category_N = strings(n_N,1);

for i = 1:n_N
    if poorFitTable_N.TuningSig(i) == 2
        if poorFitTable_N.Z3D_v_Z2D(i) < 0
            Category_N(i) = "2D";
        elseif poorFitTable_N.Z3D_v_Z2D(i) > 0
            Category_N(i) = "3D";
        else
            Category_N(i) = "2D/3D boundary";
        end
    elseif poorFitTable_N.TuningSig(i) == 1
        Category_N(i) = "Mono";
    elseif poorFitTable_N.TuningSig(i) == 0
        Category_N(i) = "None";
    else
        Category_N(i) = "Unknown";
    end
end

poorFitTable_N.Category = Category_N;

%% build table for good-fit S entries
ROI_list_good_S = {};
Z3D_v_Z2D_list_good_S = [];
rec_list_good_S = [];
cue_list_good_S = [];
TuningSig_good_S = [];

for i_rec = 1:size(unit_table, 1)
    for i_cue = 1:4
        if goodfit_idx_S(i_rec, i_cue) == 1
            ROI_list_good_S{end+1,1} = unit_table.ROI{i_rec};
            Z3D_v_Z2D_list_good_S(end+1,1) = unit_table.Z3D_v_Z2D{i_rec};
            rec_list_good_S(end+1,1) = origRecIdx(i_rec);
            cue_list_good_S(end+1,1) = i_cue;

            if unit_table.p_AI{i_rec}(2) < 0.05 && unit_table.p_AI{i_rec}(3) < 0.05
                TuningSig_good_S(end+1, 1) = 2;
            elseif unit_table.p_AI{i_rec}(2) < 0.05 || unit_table.p_AI{i_rec}(3) < 0.05
                TuningSig_good_S(end+1, 1) = 1;
            else
                TuningSig_good_S(end+1, 1) = 0;
            end
        end
    end
end

goodFitTable_S = table(rec_list_good_S, cue_list_good_S, ROI_list_good_S, ...
    Z3D_v_Z2D_list_good_S, TuningSig_good_S, ...
    'VariableNames', {'RecIdx', 'CueIdx', 'ROI', 'Z3D_v_Z2D', 'TuningSig'});

Category_good_S = strings(height(goodFitTable_S),1);
for i = 1:height(goodFitTable_S)
    if goodFitTable_S.TuningSig(i) == 2
        if goodFitTable_S.Z3D_v_Z2D(i) < 0
            Category_good_S(i) = "2D";
        elseif goodFitTable_S.Z3D_v_Z2D(i) > 0
            Category_good_S(i) = "3D";
        else
            Category_good_S(i) = "2D/3D boundary";
        end
    elseif goodFitTable_S.TuningSig(i) == 1
        Category_good_S(i) = "Mono";
    elseif goodFitTable_S.TuningSig(i) == 0
        Category_good_S(i) = "None";
    else
        Category_good_S(i) = "Unknown";
    end
end
goodFitTable_S.Category = Category_good_S;

%% build table for good-fit N entries
ROI_list_good_N = {};
Z3D_v_Z2D_list_good_N = [];
rec_list_good_N = [];
cue_list_good_N = [];
TuningSig_good_N = [];

for i_rec = 1:size(unit_table, 1)
    for i_cue = 1:4
        if goodfit_idx_N(i_rec, i_cue) == 1
            ROI_list_good_N{end+1,1} = unit_table.ROI{i_rec};
            Z3D_v_Z2D_list_good_N(end+1,1) = unit_table.Z3D_v_Z2D{i_rec};
            rec_list_good_N(end+1,1) = origRecIdx(i_rec);
            cue_list_good_N(end+1,1) = i_cue;

            if unit_table.p_AI{i_rec}(2) < 0.05 && unit_table.p_AI{i_rec}(3) < 0.05
                TuningSig_good_N(end+1, 1) = 2;
            elseif unit_table.p_AI{i_rec}(2) < 0.05 || unit_table.p_AI{i_rec}(3) < 0.05
                TuningSig_good_N(end+1, 1) = 1;
            else
                TuningSig_good_N(end+1, 1) = 0;
            end
        end
    end
end

goodFitTable_N = table(rec_list_good_N, cue_list_good_N, ROI_list_good_N, ...
    Z3D_v_Z2D_list_good_N, TuningSig_good_N, ...
    'VariableNames', {'RecIdx', 'CueIdx', 'ROI', 'Z3D_v_Z2D', 'TuningSig'});

Category_good_N = strings(height(goodFitTable_N),1);
for i = 1:height(goodFitTable_N)
    if goodFitTable_N.TuningSig(i) == 2
        if goodFitTable_N.Z3D_v_Z2D(i) < 0
            Category_good_N(i) = "2D";
        elseif goodFitTable_N.Z3D_v_Z2D(i) > 0
            Category_good_N(i) = "3D";
        else
            Category_good_N(i) = "2D/3D boundary";
        end
    elseif goodFitTable_N.TuningSig(i) == 1
        Category_good_N(i) = "Mono";
    elseif goodFitTable_N.TuningSig(i) == 0
        Category_good_N(i) = "None";
    else
        Category_good_N(i) = "Unknown";
    end
end
goodFitTable_N.Category = Category_good_N;

%% count MT/FST x category
ROI_names = ["MT","FST"];
Cat_names = ["2D","3D","Mono","None"];

count_mat = zeros(numel(ROI_names), numel(Cat_names));
count_mat_N = zeros(numel(ROI_names), numel(Cat_names));

for i_roi = 1:numel(ROI_names)
    for i_cat = 1:numel(Cat_names)
        count_mat(i_roi, i_cat) = sum(strcmp(poorFitTable.ROI, ROI_names(i_roi)) & ...
            poorFitTable.Category == Cat_names(i_cat));
        count_mat_N(i_roi, i_cat) = sum(strcmp(poorFitTable_N.ROI, ROI_names(i_roi)) & ...
            poorFitTable_N.Category == Cat_names(i_cat));
    end
end

category_count_table = array2table(count_mat, ...
    'VariableNames', cellstr(Cat_names), ...
    'RowNames', cellstr(ROI_names));

category_count_table_N = array2table(count_mat_N, ...
    'VariableNames', cellstr(Cat_names), ...
    'RowNames', cellstr(ROI_names));

disp(category_count_table)
disp(category_count_table_N)

%% Build long tables with one row per poor-fit rec/cue/coh and PropToward = y ./ n
poorFitBehavTable_S = table('Size', [0 9], ...
    'VariableTypes', {'string','double','double','string','string','double','double','double','double'}, ...
    'VariableNames', {'Condition','RecIdx','CueIdx','ROI','Category','Coh','ChooseTowardN','TrialN','PropToward'});

for i_row = 1:height(poorFitTable)
    i_rec = find(origRecIdx == poorFitTable.RecIdx(i_row), 1);
    i_cue = poorFitTable.CueIdx(i_row);
    data_this = Data_S{i_rec}(i_cue).data;

    valid = data_this(:,3) > 0 & ...
        isfinite(data_this(:,1)) & isfinite(data_this(:,2)) & isfinite(data_this(:,3));

    if ~any(valid)
        continue
    end

    data_this = data_this(valid, :);
    n_rows = size(data_this, 1);

    tmp = table( ...
        repmat("Stim", n_rows, 1), ...
        repmat(poorFitTable.RecIdx(i_row), n_rows, 1), ...
        repmat(i_cue, n_rows, 1), ...
        repmat(string(poorFitTable.ROI(i_row)), n_rows, 1), ...
        repmat(poorFitTable.Category(i_row), n_rows, 1), ...
        data_this(:,1), ...
        data_this(:,2), ...
        data_this(:,3), ...
        data_this(:,2) ./ data_this(:,3), ...
        'VariableNames', poorFitBehavTable_S.Properties.VariableNames);

    poorFitBehavTable_S = [poorFitBehavTable_S; tmp];
end

poorFitBehavTable_S = sortrows(poorFitBehavTable_S, {'RecIdx','CueIdx','Coh'});

poorFitBehavTable_N = table('Size', [0 9], ...
    'VariableTypes', {'string','double','double','string','string','double','double','double','double'}, ...
    'VariableNames', {'Condition','RecIdx','CueIdx','ROI','Category','Coh','ChooseTowardN','TrialN','PropToward'});

for i_row = 1:height(poorFitTable_N)
    i_rec = find(origRecIdx == poorFitTable_N.RecIdx(i_row), 1);
    i_cue = poorFitTable_N.CueIdx(i_row);
    data_this = Data_N{i_rec}(i_cue).data;

    valid = data_this(:,3) > 0 & ...
        isfinite(data_this(:,1)) & isfinite(data_this(:,2)) & isfinite(data_this(:,3));

    if ~any(valid)
        continue
    end

    data_this = data_this(valid, :);
    n_rows = size(data_this, 1);

    tmp = table( ...
        repmat("NonStim", n_rows, 1), ...
        repmat(poorFitTable_N.RecIdx(i_row), n_rows, 1), ...
        repmat(i_cue, n_rows, 1), ...
        repmat(string(poorFitTable_N.ROI(i_row)), n_rows, 1), ...
        repmat(poorFitTable_N.Category(i_row), n_rows, 1), ...
        data_this(:,1), ...
        data_this(:,2), ...
        data_this(:,3), ...
        data_this(:,2) ./ data_this(:,3), ...
        'VariableNames', poorFitBehavTable_N.Properties.VariableNames);

    poorFitBehavTable_N = [poorFitBehavTable_N; tmp];
end

poorFitBehavTable_N = sortrows(poorFitBehavTable_N, {'RecIdx','CueIdx','Coh'});

%% Save poor-fit proportions as N-by-12 matrices
poorFitCoh = [-22 -14 -10 -8 -4 -2 2 4 8 10 14 22] ./ 22;
cohTol = 1e-10;

poorFitRowInfo_S = poorFitTable(:, {'RecIdx','CueIdx','ROI','Category'});
poorFitPropMat_S = nan(height(poorFitTable), numel(poorFitCoh));

for i_row = 1:height(poorFitTable)
    i_rec = find(origRecIdx == poorFitTable.RecIdx(i_row), 1);
    i_cue = poorFitTable.CueIdx(i_row);
    data_this = Data_S{i_rec}(i_cue).data;

    valid = data_this(:,3) > 0 & ...
        isfinite(data_this(:,1)) & isfinite(data_this(:,2)) & isfinite(data_this(:,3)) & ...
        data_this(:,1) ~= 0;

    data_this = data_this(valid, :);

    for i_dat = 1:size(data_this, 1)
        idx_coh = find(abs(poorFitCoh - data_this(i_dat, 1)) < cohTol, 1);
        if ~isempty(idx_coh)
            poorFitPropMat_S(i_row, idx_coh) = data_this(i_dat, 2) ./ data_this(i_dat, 3);
        end
    end
end

poorFitRowInfo_N = poorFitTable_N(:, {'RecIdx','CueIdx','ROI','Category'});
poorFitPropMat_N = nan(height(poorFitTable_N), numel(poorFitCoh));

for i_row = 1:height(poorFitTable_N)
    i_rec = find(origRecIdx == poorFitTable_N.RecIdx(i_row), 1);
    i_cue = poorFitTable_N.CueIdx(i_row);
    data_this = Data_N{i_rec}(i_cue).data;

    valid = data_this(:,3) > 0 & ...
        isfinite(data_this(:,1)) & isfinite(data_this(:,2)) & isfinite(data_this(:,3)) & ...
        data_this(:,1) ~= 0;

    data_this = data_this(valid, :);

    for i_dat = 1:size(data_this, 1)
        idx_coh = find(abs(poorFitCoh - data_this(i_dat, 1)) < cohTol, 1);
        if ~isempty(idx_coh)
            poorFitPropMat_N(i_row, idx_coh) = data_this(i_dat, 2) ./ data_this(i_dat, 3);
        end
    end
end

goodFitRowInfo_S = goodFitTable_S(:, {'RecIdx','CueIdx','ROI','Category'});
goodFitPropMat_S = nan(height(goodFitTable_S), numel(poorFitCoh));

for i_row = 1:height(goodFitTable_S)
    i_rec = find(origRecIdx == goodFitTable_S.RecIdx(i_row), 1);
    i_cue = goodFitTable_S.CueIdx(i_row);
    data_this = Data_S{i_rec}(i_cue).data;

    valid = data_this(:,3) > 0 & ...
        isfinite(data_this(:,1)) & isfinite(data_this(:,2)) & isfinite(data_this(:,3)) & ...
        data_this(:,1) ~= 0;

    data_this = data_this(valid, :);

    for i_dat = 1:size(data_this, 1)
        idx_coh = find(abs(poorFitCoh - data_this(i_dat, 1)) < cohTol, 1);
        if ~isempty(idx_coh)
            goodFitPropMat_S(i_row, idx_coh) = data_this(i_dat, 2) ./ data_this(i_dat, 3);
        end
    end
end

goodFitRowInfo_N = goodFitTable_N(:, {'RecIdx','CueIdx','ROI','Category'});
goodFitPropMat_N = nan(height(goodFitTable_N), numel(poorFitCoh));

for i_row = 1:height(goodFitTable_N)
    i_rec = find(origRecIdx == goodFitTable_N.RecIdx(i_row), 1);
    i_cue = goodFitTable_N.CueIdx(i_row);
    data_this = Data_N{i_rec}(i_cue).data;

    valid = data_this(:,3) > 0 & ...
        isfinite(data_this(:,1)) & isfinite(data_this(:,2)) & isfinite(data_this(:,3)) & ...
        data_this(:,1) ~= 0;

    data_this = data_this(valid, :);

    for i_dat = 1:size(data_this, 1)
        idx_coh = find(abs(poorFitCoh - data_this(i_dat, 1)) < cohTol, 1);
        if ~isempty(idx_coh)
            goodFitPropMat_N(i_row, idx_coh) = data_this(i_dat, 2) ./ data_this(i_dat, 3);
        end
    end
end

%% Quantify how strongly each row stays on one side of 0.5
poorFitBiasPropAbove_S = nan(size(poorFitPropMat_S, 1), 1);
poorFitBiasPropBelow_S = nan(size(poorFitPropMat_S, 1), 1);
poorFitBiasProp_S = nan(size(poorFitPropMat_S, 1), 1);

for i_row = 1:size(poorFitPropMat_S, 1)
    row_vals = poorFitPropMat_S(i_row, :);
    valid = isfinite(row_vals);
    if any(valid)
        poorFitBiasPropAbove_S(i_row) = sum(row_vals(valid) > 0.5) ./ sum(valid);
        poorFitBiasPropBelow_S(i_row) = sum(row_vals(valid) < 0.5) ./ sum(valid);
        poorFitBiasProp_S(i_row) = max(poorFitBiasPropAbove_S(i_row), poorFitBiasPropBelow_S(i_row));
    end
end

poorFitBiasPropAbove_N = nan(size(poorFitPropMat_N, 1), 1);
poorFitBiasPropBelow_N = nan(size(poorFitPropMat_N, 1), 1);
poorFitBiasProp_N = nan(size(poorFitPropMat_N, 1), 1);

for i_row = 1:size(poorFitPropMat_N, 1)
    row_vals = poorFitPropMat_N(i_row, :);
    valid = isfinite(row_vals);
    if any(valid)
        poorFitBiasPropAbove_N(i_row) = sum(row_vals(valid) > 0.5) ./ sum(valid);
        poorFitBiasPropBelow_N(i_row) = sum(row_vals(valid) < 0.5) ./ sum(valid);
        poorFitBiasProp_N(i_row) = max(poorFitBiasPropAbove_N(i_row), poorFitBiasPropBelow_N(i_row));
    end
end

goodFitBiasPropAbove_S = nan(size(goodFitPropMat_S, 1), 1);
goodFitBiasPropBelow_S = nan(size(goodFitPropMat_S, 1), 1);
goodFitBiasProp_S = nan(size(goodFitPropMat_S, 1), 1);

for i_row = 1:size(goodFitPropMat_S, 1)
    row_vals = goodFitPropMat_S(i_row, :);
    valid = isfinite(row_vals);
    if any(valid)
        goodFitBiasPropAbove_S(i_row) = sum(row_vals(valid) > 0.5) ./ sum(valid);
        goodFitBiasPropBelow_S(i_row) = sum(row_vals(valid) < 0.5) ./ sum(valid);
        goodFitBiasProp_S(i_row) = max(goodFitBiasPropAbove_S(i_row), goodFitBiasPropBelow_S(i_row));
    end
end

goodFitBiasPropAbove_N = nan(size(goodFitPropMat_N, 1), 1);
goodFitBiasPropBelow_N = nan(size(goodFitPropMat_N, 1), 1);
goodFitBiasProp_N = nan(size(goodFitPropMat_N, 1), 1);

for i_row = 1:size(goodFitPropMat_N, 1)
    row_vals = goodFitPropMat_N(i_row, :);
    valid = isfinite(row_vals);
    if any(valid)
        goodFitBiasPropAbove_N(i_row) = sum(row_vals(valid) > 0.5) ./ sum(valid);
        goodFitBiasPropBelow_N(i_row) = sum(row_vals(valid) < 0.5) ./ sum(valid);
        goodFitBiasProp_N(i_row) = max(goodFitBiasPropAbove_N(i_row), goodFitBiasPropBelow_N(i_row));
    end
end

poorFitRowInfo_S.BiasPropAbove = poorFitBiasPropAbove_S;
poorFitRowInfo_S.BiasPropBelow = poorFitBiasPropBelow_S;
poorFitRowInfo_S.BiasProp = poorFitBiasProp_S;

poorFitRowInfo_N.BiasPropAbove = poorFitBiasPropAbove_N;
poorFitRowInfo_N.BiasPropBelow = poorFitBiasPropBelow_N;
poorFitRowInfo_N.BiasProp = poorFitBiasProp_N;

goodFitRowInfo_S.BiasPropAbove = goodFitBiasPropAbove_S;
goodFitRowInfo_S.BiasPropBelow = goodFitBiasPropBelow_S;
goodFitRowInfo_S.BiasProp = goodFitBiasProp_S;

goodFitRowInfo_N.BiasPropAbove = goodFitBiasPropAbove_N;
goodFitRowInfo_N.BiasPropBelow = goodFitBiasPropBelow_N;
goodFitRowInfo_N.BiasProp = goodFitBiasProp_N;

%% Add ND labels using the same 2D/3D/MN/NA convention as FitTable
goodFitND_S = strings(height(goodFitRowInfo_S), 1);
for i_row = 1:height(goodFitRowInfo_S)
    i_rec = find(origRecIdx == goodFitRowInfo_S.RecIdx(i_row), 1);
    if unit_table.p_AI{i_rec}(2) < 0.05 && unit_table.p_AI{i_rec}(3) < 0.05
        if unit_table.Z3D_v_Z2D{i_rec} > 0
            goodFitND_S(i_row) = "3D";
        else
            goodFitND_S(i_row) = "2D";
        end
    elseif unit_table.p_AI{i_rec}(2) < 0.05 || unit_table.p_AI{i_rec}(3) < 0.05
        goodFitND_S(i_row) = "MN";
    else
        goodFitND_S(i_row) = "NA";
    end
end
goodFitRowInfo_S.ND = goodFitND_S;

goodFitND_N = strings(height(goodFitRowInfo_N), 1);
for i_row = 1:height(goodFitRowInfo_N)
    i_rec = find(origRecIdx == goodFitRowInfo_N.RecIdx(i_row), 1);
    if unit_table.p_AI{i_rec}(2) < 0.05 && unit_table.p_AI{i_rec}(3) < 0.05
        if unit_table.Z3D_v_Z2D{i_rec} > 0
            goodFitND_N(i_row) = "3D";
        else
            goodFitND_N(i_row) = "2D";
        end
    elseif unit_table.p_AI{i_rec}(2) < 0.05 || unit_table.p_AI{i_rec}(3) < 0.05
        goodFitND_N(i_row) = "MN";
    else
        goodFitND_N(i_row) = "NA";
    end
end
goodFitRowInfo_N.ND = goodFitND_N;

%% ROC-style AUC against a neutral 0.5 reference for poor-fit and good-fit cases
poorFitAUC_S = nan(height(poorFitRowInfo_S), 1);
for i_row = 1:size(poorFitPropMat_S, 1)
    row_vals = poorFitPropMat_S(i_row, :);
    valid = isfinite(row_vals);
    scores = row_vals(valid);

    if ~isempty(scores)
        poorFitAUC_S(i_row) = mean(scores > 0.5) + 0.5 * mean(scores == 0.5);
    end
end

poorFitAUC_N = nan(height(poorFitRowInfo_N), 1);
for i_row = 1:size(poorFitPropMat_N, 1)
    row_vals = poorFitPropMat_N(i_row, :);
    valid = isfinite(row_vals);
    scores = row_vals(valid);

    if ~isempty(scores)
        poorFitAUC_N(i_row) = mean(scores > 0.5) + 0.5 * mean(scores == 0.5);
    end
end

poorFitRowInfo_S.AUC = poorFitAUC_S;
poorFitRowInfo_N.AUC = poorFitAUC_N;

poorFitAIcombined_S = nan(height(poorFitRowInfo_S), 1);
for i_row = 1:height(poorFitRowInfo_S)
    i_rec = find(origRecIdx == poorFitRowInfo_S.RecIdx(i_row), 1);
    ch = unit_table.StimElec(i_rec);
    poorFitAIcombined_S(i_row) = unit_table.AI{i_rec}(1, ch);
end
poorFitRowInfo_S.AI_combinedCue = poorFitAIcombined_S;

%% Find poor-fit cases with moderate AUC (0.2 < AUC < 0.8)
idxPoorAUCmid_S = isfinite(poorFitRowInfo_S.AUC) & ...
    poorFitRowInfo_S.AUC > 0.2 & poorFitRowInfo_S.AUC < 0.8;
idxPoorAUCmid_N = isfinite(poorFitRowInfo_N.AUC) & ...
    poorFitRowInfo_N.AUC > 0.2 & poorFitRowInfo_N.AUC < 0.8;

poorFitAUCmidTable_S = poorFitRowInfo_S(idxPoorAUCmid_S, :);
poorFitAUCmidTable_N = poorFitRowInfo_N(idxPoorAUCmid_N, :);

poorFitAUCmidRec_S = unique(poorFitAUCmidTable_S.RecIdx);
poorFitAUCmidRec_N = unique(poorFitAUCmidTable_N.RecIdx);

disp('Poor-fit Stim rows with 0.2 < AUC < 0.8:')
disp(poorFitAUCmidTable_S)
disp('Poor-fit Stim unique RecIdx with 0.2 < AUC < 0.8:')
disp(poorFitAUCmidRec_S)

disp('Poor-fit Non-stim rows with 0.2 < AUC < 0.8:')
disp(poorFitAUCmidTable_N)
disp('Poor-fit Non-stim unique RecIdx with 0.2 < AUC < 0.8:')
disp(poorFitAUCmidRec_N)

goodFitAUC_S = nan(height(goodFitRowInfo_S), 1);
for i_row = 1:size(goodFitPropMat_S, 1)
    row_vals = goodFitPropMat_S(i_row, :);
    valid = isfinite(row_vals);
    scores = row_vals(valid);

    if ~isempty(scores)
        goodFitAUC_S(i_row) = mean(scores > 0.5) + 0.5 * mean(scores == 0.5);
    end
end

goodFitAUC_N = nan(height(goodFitRowInfo_N), 1);
for i_row = 1:size(goodFitPropMat_N, 1)
    row_vals = goodFitPropMat_N(i_row, :);
    valid = isfinite(row_vals);
    scores = row_vals(valid);

    if ~isempty(scores)
        goodFitAUC_N(i_row) = mean(scores > 0.5) + 0.5 * mean(scores == 0.5);
    end
end

goodFitRowInfo_S.AUC = goodFitAUC_S;
goodFitRowInfo_N.AUC = goodFitAUC_N;

%% Compare poor-fit and good-fit bias proportions
histEdges = 0.3:0.05:1.05;

figure('Color', 'w', 'Position', [100 100 1200 480]);

subplot(1, 2, 1); hold on;
histogram(goodFitBiasProp_S(isfinite(goodFitBiasProp_S)), histEdges, ...
    'FaceColor', [0.4 0.4 0.4], 'FaceAlpha', 0.55, 'EdgeColor', 'none', 'Normalization', 'probability');
histogram(poorFitBiasProp_S(isfinite(poorFitBiasProp_S)), histEdges, ...
    'FaceColor', [0.85 0.2 0.2], 'FaceAlpha', 0.55, 'EdgeColor', 'none', 'Normalization', 'probability');
xlim([0.3 1.0]);
xlabel('Max proportion on one side of 0.5');
ylabel('Count');
title('Stim');
legend({'Good fit', 'Poor fit'}, 'Location', 'northwest');
box off;

[p_propBias, ~] = ranksum(goodFitBiasProp_S, poorFitBiasProp_S);

subplot(1, 2, 2); hold on;
histogram(goodFitBiasProp_N(isfinite(goodFitBiasProp_N)), histEdges, ...
    'FaceColor', [0.4 0.4 0.4], 'FaceAlpha', 0.55, 'EdgeColor', 'none', 'Normalization', 'probability');
histogram(poorFitBiasProp_N(isfinite(poorFitBiasProp_N)), histEdges, ...
    'FaceColor', [0.2 0.45 0.85], 'FaceAlpha', 0.55, 'EdgeColor', 'none', 'Normalization', 'probability');
xlim([0.3 1.0]);
xlabel('Max proportion on one side of 0.5');
ylabel('Count');
title('Non-stim');
legend({'Good fit', 'Poor fit'}, 'Location', 'northwest');
box off;

%% Pool all poor-fit behavior dots across sessions
colorsteps = [0 0 0;...
    0 0 255;...
    5 150 5;...
    234 0 233] ./ 255;
cueLabels = {'Combined', 'Left', 'Right', 'Stereo'};

fig_pool = figure('Color', 'w', 'Position', [100 100 1500 520]);

ax1 = axes('Parent', fig_pool, 'Position', [0.06 0.16 0.28 0.72]); hold(ax1, 'on');
ax1_hist = axes('Parent', fig_pool, 'Position', [0.35 0.16 0.07 0.72]); hold(ax1_hist, 'on');
ax2 = axes('Parent', fig_pool, 'Position', [0.56 0.16 0.28 0.72]); hold(ax2, 'on');
ax2_hist = axes('Parent', fig_pool, 'Position', [0.85 0.16 0.07 0.72]); hold(ax2_hist, 'on');

for i_cue = 1:4
    color_this = colorsteps(i_cue, :);

    % Only poor-fit rec/cue rows are present in poorFitBehavTable_N / poorFitBehavTable_S
    idxN = poorFitBehavTable_N.CueIdx == i_cue;
    scatter(ax1, poorFitBehavTable_N.Coh(idxN), poorFitBehavTable_N.PropToward(idxN), ...
        34, 'filled', ...
        'MarkerFaceColor', color_this, ...
        'MarkerEdgeColor', 'none', ...
        'MarkerFaceAlpha', 0.25, ...
        'DisplayName', cueLabels{i_cue});

    idxS = poorFitBehavTable_S.CueIdx == i_cue;
    scatter(ax2, poorFitBehavTable_S.Coh(idxS), poorFitBehavTable_S.PropToward(idxS), ...
        34, 'filled', ...
        'MarkerFaceColor', color_this, ...
        'MarkerEdgeColor', 'none', ...
        'MarkerFaceAlpha', 0.25, ...
        'DisplayName', cueLabels{i_cue});
end

histogram(ax1_hist, poorFitBehavTable_N.PropToward(isfinite(poorFitBehavTable_N.PropToward)), ...
    'BinEdges', 0:0.05:1, 'Orientation', 'horizontal', ...
    'FaceColor', [0.2 0.45 0.85], 'FaceAlpha', 0.6, 'EdgeColor', 'none');

histogram(ax2_hist, poorFitBehavTable_S.PropToward(isfinite(poorFitBehavTable_S.PropToward)), ...
    'BinEdges', 0:0.05:1, 'Orientation', 'horizontal', ...
    'FaceColor', [0.85 0.2 0.2], 'FaceAlpha', 0.6, 'EdgeColor', 'none');

set([ax1 ax2], 'FontSize', 16, 'TickDir', 'out', 'Box', 'off', 'LineWidth', 2);
xlim(ax1, [-1 1]); xlim(ax2, [-1 1]);
ylim(ax1, [0 1]);  ylim(ax2, [0 1]);
yticks(ax1, 0:0.2:1);
yticks(ax2, 0:0.2:1);
xticks(ax1, -1:0.5:1);
xticks(ax2, -1:0.5:1);
xticklabels(ax1, {'-1', 'Away', '0', 'Towards', '1'});
xticklabels(ax2, {'-1', 'Away', '0', 'Towards', '1'});
axis(ax1, 'square');
axis(ax2, 'square');

set([ax1_hist ax2_hist], 'FontSize', 14, 'TickDir', 'out', 'Box', 'off', 'LineWidth', 2, ...
    'YLim', [0 1], 'YTick', 0:0.2:1);
ax1_hist.YTickLabel = [];
ax2_hist.YTickLabel = [];
xlabel(ax1_hist, 'Count');
xlabel(ax2_hist, 'Count');

xlabel(ax1, 'Coherence');
ylabel(ax1, 'Proportion toward pref');
title(ax1, sprintf('Poor-fit Non-stim cues (n = %d)', height(poorFitRowInfo_N)));
legend(ax1, 'Location', 'northwest');

xlabel(ax2, 'Coherence');
ylabel(ax2, 'Proportion toward pref');
title(ax2, sprintf('Poor-fit Stim cues (n = %d)', height(poorFitRowInfo_S)));
legend(ax2, 'Location', 'northwest');

title(ax1_hist, 'Y marginal');
title(ax2_hist, 'Y marginal');

sgtitle('Accumulated poor-fit behavior across poor-fit rec/cue entries');

%% Plot AUC distributions for poor-fit cases
aucEdges = 0:0.05:1;

figure('Color', 'w', 'Position', [100 100 1200 480]);

subplot(1, 2, 1); hold on;
histogram(poorFitAUC_N(isfinite(poorFitAUC_N)), aucEdges, ...
    'FaceColor', [0.2 0.45 0.85], 'FaceAlpha', 0.65, 'EdgeColor', 'none');
xline(0.5, 'k--', 'LineWidth', 1.5);
xlim([0 1]);
xlabel('AUC');
ylabel('Count');
title(sprintf('Poor-fit Non-stim AUCs (n = %d)', sum(isfinite(poorFitAUC_N))));
box off;

subplot(1, 2, 2); hold on;
histogram(poorFitAUC_S(isfinite(poorFitAUC_S)), aucEdges, ...
    'FaceColor', [0.85 0.2 0.2], 'FaceAlpha', 0.65, 'EdgeColor', 'none');
xline(0.5, 'k--', 'LineWidth', 1.5);
xlim([0 1]);
xlabel('AUC');
ylabel('Count');
title(sprintf('Poor-fit Stim AUCs (n = %d)', sum(isfinite(poorFitAUC_S))));
box off;

%% Plot poor-fit Stim AUC against combined-cue AI
colorsteps = [0 0 0;...
    0 0 255;...
    5 150 5;...
    234 0 233] ./ 255;
cueLabels = {'Combined', 'Left', 'Right', 'Stereo'};

figure('Color', 'w', 'Position', [100 100 700 560]); hold on;
for i_cue = 1:4
    idx = poorFitRowInfo_S.CueIdx == i_cue & ...
        isfinite(poorFitRowInfo_S.AUC) & isfinite(poorFitRowInfo_S.AI_combinedCue);

    scatter(poorFitRowInfo_S.AI_combinedCue(idx), poorFitRowInfo_S.AUC(idx), ...
        45, 'filled', ...
        'MarkerFaceColor', colorsteps(i_cue, :), ...
        'MarkerEdgeColor', 'none', ...
        'MarkerFaceAlpha', 0.7, ...
        'DisplayName', cueLabels{i_cue});
end
plot([-1 1], [0.5 0.5], 'k --')
plot([0 0], [0 1], 'k --')

idx_lm = isfinite(poorFitRowInfo_S.AUC) & isfinite(poorFitRowInfo_S.AI_combinedCue);
x_lm = poorFitRowInfo_S.AI_combinedCue(idx_lm);
y_lm = poorFitRowInfo_S.AUC(idx_lm);

if numel(x_lm) >= 3 && numel(unique(x_lm)) > 1
    tbl_lm = table(x_lm, y_lm, 'VariableNames', {'AI','AUC'});
    lm_auc = fitlm(tbl_lm, 'AUC ~ AI');
    p_auc_ai = lm_auc.Coefficients{'AI', 'pValue'};

    x_fit = linspace(min(x_lm), max(x_lm), 200)';
    y_fit = predict(lm_auc, table(x_fit, 'VariableNames', {'AI'}));
    plot(x_fit, y_fit, '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 2.2, ...
        'DisplayName', sprintf('LM p = %.3g', p_auc_ai));

    text(0.04, 0.95, sprintf('p=%.3g', p_auc_ai), ...
        'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 12, ...
        'BackgroundColor', 'w', 'Margin', 4);
else
    p_auc_ai = NaN;
end

xlabel('AI (Combined cue)')
ylabel('AUC')
title('Poor-fit Stim AUC vs combined-cue AI')
ylim([0 1])
box off
axis square

%% Plot good-fit AUC distributions by ROI x ND x cue for Stim and Non-stim
roi_list = {'MT', 'FST'};
nd_list  = {'2D', '3D', 'MN', 'NA'};
aucEdges = 0:0.05:1;
outDir_rocGood = 'C:\EM\BehaviorFitting\ROC_goodfit\';
if ~exist(outDir_rocGood, 'dir')
    mkdir(outDir_rocGood);
end

%% -------- Plot sessions containing poor fits --------
if individualPlot
    colorsteps = [0 0 0;...
        0 0 255;...
        5 150 5;...
        234 0 233] ./ 255;

    x_plot = (-1:0.01:1)';
    x_plot(abs(x_plot) < 1e-12) = [];

    outDir_poor = fullfile('C:\EM\BehaviorFitting\', 'PoorFitSessions_allCues');
    if ~exist(outDir_poor, 'dir')
        mkdir(outDir_poor);
    end

    [n_rec, n_cues] = size(overfit_idx);

    CoherenceArray_no0 = [-22 -14 -10 -8 -4 -2 2 4 8 10 14 22]./22;
    CoherenceArray_8   = [-22 -14 -10 -8 8 10 14 22]./22;

    for i_rec = 1:n_rec
        if ~any(overfit_idx(i_rec, :) == 1)
            continue
        end

        fig = figure('Color','w', ...
            'Units','pixels', ...
            'Position',[100 100 1800 520]);

        ax0 = subplot(1,3,1); hold(ax0, 'on');
        ax1 = subplot(1,3,2); hold(ax1, 'on');
        ax2 = subplot(1,3,3); hold(ax2, 'on');

        %% Panel 1: neuron tuning
        Ch = unit_table.StimElec(i_rec);
        NeuroMean = unit_table.tuning_mean{i_rec}(:, :, Ch);
        NeuroSEM  = unit_table.tuning_SEM{i_rec}(:, :, Ch);

        nanCols = all(isnan(NeuroSEM), 1);
        NeuroSEM(:, nanCols)  = [];

        if size(NeuroMean,2) == 13
            zeroCol = 7;
            NeuroMean(:, zeroCol) = [];
            NeuroSEM(:, zeroCol)  = [];
        end

        if size(NeuroMean,2) == 12
            CoherenceArray = CoherenceArray_no0;
        elseif size(NeuroMean,2) == 8
            CoherenceArray = CoherenceArray_8;
        else
            warning('Unexpected number of coherence points in rec %d: %d', i_rec, size(NeuroMean,2));
            continue
        end

        axes(ax0); hold(ax0, 'on');
        axis(ax0, 'square');
        xticks(ax0, -1:0.5:1)
        xticklabels(ax0, {'-1', 'Away', '0', 'Towards', '1'})
        xlim(ax0, [-1 1])

        set(ax0, 'FontSize', 18, 'LineWidth', 3, 'Box', 'off')
        title(ax0, 'Neuron tuning curve', 'FontSize', 20)
        ylabel(ax0, 'Firing Rate (spikes/s)', 'FontSize', 20)
        xlabel(ax0, 'Coherence', 'FontSize', 20)

        for cond = 1:4
            fr = errorbar(ax0, CoherenceArray, NeuroMean(cond,:), NeuroSEM(cond,:));
            color = colorsteps(cond, :);
            fr.Color = color;
            fr.Marker = 'o';
            fr.MarkerFaceColor = color;
            fr.MarkerEdgeColor = color;
            fr.MarkerSize = 5;
            fr.LineWidth = 2;
        end

        %% Panel 2 & 3: behavior
        for i_cue = 1:n_cues
            baseColor = colorsteps(i_cue, :);
            isPoor = overfit_idx(i_rec, i_cue) == 1;

            if isPoor
                thisColor = baseColor;
                ptAlpha = 0.5;
                lw = 2.5;
            else
                thisColor = baseColor;
                ptAlpha = 1.0;
                lw = 2.5;
            end

            % Non-stim
            DataN = Data_N{i_rec}(i_cue).data;
            cohN = DataN(:,1);
            PropToward_N = DataN(:,2) ./ DataN(:,3);
            validN = DataN(:,3) > 0 & cohN ~= 0 & ...
                isfinite(cohN) & isfinite(PropToward_N);

            scatter(ax1, cohN(validN), PropToward_N(validN), ...
                40, 'filled', ...
                'MarkerFaceColor', thisColor, ...
                'MarkerEdgeColor', 'none', ...
                'MarkerFaceAlpha', 1, ...
                'MarkerEdgeAlpha', 1);

            try
                mdl_full = unit_table.Behav_mdl_full{i_rec}{i_cue};
                if ~isempty(mdl_full)
                    tbl0 = table(x_plot, zeros(size(x_plot)), ...
                        'VariableNames', {'coh','s'});
                    p0 = predict(mdl_full, tbl0);
                    plot(ax1, x_plot, p0, '-', 'Color', thisColor, 'LineWidth', lw);
                end
            catch
                warning('Could not plot GLM N prediction for rec %d cue %d.', i_rec, i_cue);
            end

            % Stim
            DataS = Data_S{i_rec}(i_cue).data;
            cohS = DataS(:,1);
            PropToward_S = DataS(:,2) ./ DataS(:,3);
            validS = DataS(:,3) > 0 & cohS ~= 0 & ...
                isfinite(cohS) & isfinite(PropToward_S);

            scatter(ax2, cohS(validS), PropToward_S(validS), ...
                40, 'filled', ...
                'MarkerFaceColor', thisColor, ...
                'MarkerEdgeColor', 'none', ...
                'MarkerFaceAlpha', 1, ...
                'MarkerEdgeAlpha', 1);

            try
                mdl_full = unit_table.Behav_mdl_full{i_rec}{i_cue};
                if ~isempty(mdl_full)
                    tbl1 = table(x_plot, ones(size(x_plot)), ...
                        'VariableNames', {'coh','s'});
                    p1 = predict(mdl_full, tbl1);
                    plot(ax2, x_plot, p1, '-', 'Color', [thisColor ptAlpha], 'LineWidth', lw);
                end
            catch
                warning('Could not plot GLM S prediction for rec %d cue %d.', i_rec, i_cue);
            end
        end

        %% Formatting
        title(ax1, sprintf('Rec %d: Non-stim', origRecIdx(i_rec)), 'FontWeight', 'normal');
        title(ax2, sprintf('Rec %d: Stim', origRecIdx(i_rec)), 'FontWeight', 'normal');

        set([ax1 ax2], 'FontSize', 16, 'TickDir', 'out', 'Box', 'off', 'LineWidth', 2);
        xlim(ax1, [-1 1]); xlim(ax2, [-1 1]);
        ylim(ax1, [0 1]);  ylim(ax2, [0 1]);
        yticks(ax1, 0:0.2:1);
        yticks(ax2, 0:0.2:1);
        axis(ax1, 'square');
        axis(ax2, 'square');

        xlabel(ax1, 'coh');
        ylabel(ax1, 'Proportion toward pref');
        xlabel(ax2, 'coh');
        ylabel(ax2, 'Proportion toward pref');

        poorCueList = find(overfit_idx(i_rec,:) == 1);
        sgtitle(sprintf('Rec %d | poor-fit cue(s): %s', ...
            origRecIdx(i_rec), mat2str(poorCueList)), 'FontWeight', 'bold');

        fname = fullfile(outDir_poor, sprintf('poorfitSession_rec_%03d_allCues.png', origRecIdx(i_rec)));
        exportgraphics(fig, fname, 'Resolution', 300);

        close(fig);
    end
end

%% Build FitTable
ROI_list = cell(height(unit_table), 1);
Z3D_v_Z2D_list = NaN(height(unit_table), 1);
rec_list = NaN(height(unit_table), 1);
pAI = NaN(height(unit_table), 4);
TuningSig = NaN(height(unit_table), 1);
AI = NaN(height(unit_table), 4);
OD = NaN(height(unit_table), 1);
CI_S = Behav_coh50_S_CI_width;
ND_Cate = cell(height(unit_table), 1);

for i_rec = 1:size(unit_table, 1)
    ch = unit_table.StimElec(i_rec);

    ROI_list{i_rec,1} = unit_table.ROI{i_rec};
    Z3D_v_Z2D_list(i_rec) = unit_table.Z3D_v_Z2D{i_rec};
    rec_list(i_rec) = origRecIdx(i_rec);
    pAI(i_rec, :) = unit_table.p_AI{i_rec};

    if unit_table.p_AI{i_rec}(2) < 0.05 && unit_table.p_AI{i_rec}(3) < 0.05
        TuningSig(i_rec) = 2;
        if unit_table.Z3D_v_Z2D{i_rec} > 0
            ND_Cate{i_rec,1} = '3D';
        else
            ND_Cate{i_rec,1} = '2D';
        end
    elseif unit_table.p_AI{i_rec}(2) < 0.05 || unit_table.p_AI{i_rec}(3) < 0.05
        TuningSig(i_rec) = 1;
        ND_Cate{i_rec,1} = 'MN';
    else
        TuningSig(i_rec) = 0;
        ND_Cate{i_rec,1} = 'NA';
    end

    AI(i_rec, :) = unit_table.AI{i_rec}(:, ch);
    OD(i_rec) = unit_table.OD_max{i_rec};
end

FitTable = table(rec_list, ROI_list, Z3D_v_Z2D_list, TuningSig, AI, OD, CI_S, ND_Cate, ...
    'VariableNames', {'RecIdx', 'ROI', 'Z3D_v_Z2D', 'TuningSig', 'AI', 'OD', 'CI_S', 'ND'});

%% Save GOF summary table for downstream plotting
unit_table_gof = unit_table;
unit_table_gof.OriginalRecIdx = origRecIdx;
unit_table_gof.ND = ND_Cate;
unit_table_gof.Behav_goodfit_S = num2cell(goodfit_idx_S, 2);
unit_table_gof.Behav_goodfit_N = num2cell(goodfit_idx_N, 2);
unit_table_gof.Behav_goodfit_both = num2cell(goodfit_idx_S & goodfit_idx_N, 2);

Behav_bias_N = nan(height(unit_table), 4);
Behav_bias_S = nan(height(unit_table), 4);
Behav_bias_NminusS = nan(height(unit_table), 4);
Behav_slope_N = nan(height(unit_table), 4);
Behav_slope_S = nan(height(unit_table), 4);
Behav_slope_NminusS = nan(height(unit_table), 4);
Behav_propTowardMat_N = cell(height(unit_table), 1);
Behav_propTowardMat_S = cell(height(unit_table), 1);

for i_rec = 1:height(unit_table)
    propMatN_this = nan(4, numel(poorFitCoh));
    propMatS_this = nan(4, numel(poorFitCoh));

    for i_cue = 1:4
        mdl_full = [];
        if ~isempty(unit_table.Behav_mdl_full{i_rec}) && numel(unit_table.Behav_mdl_full{i_rec}) >= i_cue
            mdl_full = unit_table.Behav_mdl_full{i_rec}{i_cue};
        end

        if isempty(mdl_full)
            continue
        end

        beta_full = mdl_full.Coefficients.Estimate;
        if numel(beta_full) < 4
            continue
        end

        b0 = beta_full(1);
        b1 = beta_full(2);
        b2 = beta_full(3);
        b3 = beta_full(4);

        % Logit slopes from y ~ coh + s + coh:s. With s = 0 for
        % non-stimulation and s = 1 for stimulation, the corresponding
        % coherence slopes are b1 and b1 + b3.
        Behav_slope_N(i_rec, i_cue) = b1;
        Behav_slope_S(i_rec, i_cue) = b1 + b3;
        Behav_slope_NminusS(i_rec, i_cue) = -b3;

        if abs(b1) > 1e-10
            Behav_bias_N(i_rec, i_cue) = -b0 / b1;
        end

        if abs(b1 + b3) > 1e-10
            Behav_bias_S(i_rec, i_cue) = -(b0 + b2) / (b1 + b3);
        end

        if isfinite(Behav_bias_N(i_rec, i_cue)) && isfinite(Behav_bias_S(i_rec, i_cue))
            Behav_bias_NminusS(i_rec, i_cue) = Behav_bias_N(i_rec, i_cue) - Behav_bias_S(i_rec, i_cue);
        end

        dataN_this = Data_N{i_rec}(i_cue).data;
        validN = dataN_this(:,3) > 0 & isfinite(dataN_this(:,1)) & isfinite(dataN_this(:,2)) & ...
            isfinite(dataN_this(:,3)) & dataN_this(:,1) ~= 0;
        dataN_this = dataN_this(validN, :);
        for i_dat = 1:size(dataN_this, 1)
            idx_coh = find(abs(poorFitCoh - dataN_this(i_dat, 1)) < cohTol, 1);
            if ~isempty(idx_coh)
                propMatN_this(i_cue, idx_coh) = dataN_this(i_dat, 2) ./ dataN_this(i_dat, 3);
            end
        end

        dataS_this = Data_S{i_rec}(i_cue).data;
        validS = dataS_this(:,3) > 0 & isfinite(dataS_this(:,1)) & isfinite(dataS_this(:,2)) & ...
            isfinite(dataS_this(:,3)) & dataS_this(:,1) ~= 0;
        dataS_this = dataS_this(validS, :);
        for i_dat = 1:size(dataS_this, 1)
            idx_coh = find(abs(poorFitCoh - dataS_this(i_dat, 1)) < cohTol, 1);
            if ~isempty(idx_coh)
                propMatS_this(i_cue, idx_coh) = dataS_this(i_dat, 2) ./ dataS_this(i_dat, 3);
            end
        end
    end

    Behav_propTowardMat_N{i_rec} = propMatN_this;
    Behav_propTowardMat_S{i_rec} = propMatS_this;
end

unit_table_gof.Behav_bias_N = num2cell(Behav_bias_N, 2);
unit_table_gof.Behav_bias_S = num2cell(Behav_bias_S, 2);
unit_table_gof.Behav_bias_NminusS = num2cell(Behav_bias_NminusS, 2);
unit_table_gof.Behav_slope_N = num2cell(Behav_slope_N, 2);
unit_table_gof.Behav_slope_S = num2cell(Behav_slope_S, 2);
unit_table_gof.Behav_slope_NminusS = num2cell(Behav_slope_NminusS, 2);
unit_table_gof.Behav_propTowardMat_N = Behav_propTowardMat_N;
unit_table_gof.Behav_propTowardMat_S = Behav_propTowardMat_S;
unit_table_gof.Behav_coh_levels = repmat({poorFitCoh}, height(unit_table), 1);

save('C:\EM\BehaviorFitting\unit_table_gof.mat', 'unit_table_gof');

%% Plot 8 figures: 2 ROI x 4 ND categories
% roi_list = {'MT', 'FST'};
% nd_list  = {'2D', '3D', 'MN', 'NA'};
% 
% y_thr = 2;
% y_cap = 2.2;
% dotSize = 45;
% 
% for i_roi = 1:numel(roi_list)
%     for i_nd = 1:numel(nd_list)
%         roi_this = roi_list{i_roi};
%         nd_this  = nd_list{i_nd};
% 
%         disp([roi_this ' | ' nd_this])
% 
%         idx_group = strcmp(FitTable.ROI, roi_this) & strcmp(FitTable.ND, nd_this);
% 
%         if ~any(idx_group)
%             continue
%         end
% 
%         fig = figure('Color','w','Position',[100 100 1200 900]);
%         tl = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
% 
%         for i_cue = 1:4
%             nexttile; hold on;
% 
%             x = abs(FitTable.AI(idx_group, i_cue));
%             y = FitTable.CI_S(idx_group, i_cue);
%             od = abs(FitTable.OD(idx_group));
% 
%             valid = isfinite(x) & isfinite(y) & isfinite(od);
%             x = x(valid);
%             y = y(valid);
%             od = od(valid);
% 
%             if isempty(x)
%                 title(sprintf('Cue %d (n=0)', i_cue));
%                 xlabel('|AI|');
%                 ylabel('CI_S width');
%                 xlim([0 1]);
%                 ylim([0 y_cap+0.05]);
%                 yline(y_thr, 'k--', 'LineWidth', 1.2);
%                 axis square;
%                 box off;
%                 continue
%             end
% 
%             idx_low  = y <= y_thr;
%             idx_high = y >  y_thr;
% 
%             y_plot = y;
%             y_plot(idx_high) = y_cap;
% 
%             if any(idx_low)
%                 scatter(x(idx_low), y_plot(idx_low), dotSize, od(idx_low), ...
%                     'filled', 'MarkerFaceAlpha', 0.75, 'MarkerEdgeColor', 'k');
%             end
% 
%             if any(idx_high)
%                 scatter(x(idx_high), y_plot(idx_high), dotSize+12, od(idx_high), ...
%                     '^', 'filled', 'MarkerFaceAlpha', 0.9, 'MarkerEdgeColor', 'k');
%             end
% 
%             yline(y_thr, 'k--', 'LineWidth', 1.2);
% 
%             p_x  = NaN;
%             p_od = NaN;
%             p_int = NaN;
%             R2 = NaN;
% 
%             if numel(x) >= 4 && numel(unique(x)) > 1 && numel(unique(od)) > 1
%                 tbl_lm = table(y, x, od, 'VariableNames', {'CI_S', 'AIabs', 'OD'});
% 
%                 try
%                     lm = fitlm(tbl_lm, 'CI_S ~ AIabs*OD');
% 
%                     coefNames = lm.CoefficientNames;
%                     coefP = lm.Coefficients.pValue;
% 
%                     idx1 = strcmp(coefNames, 'AIabs');
%                     idx2 = strcmp(coefNames, 'OD');
%                     idx3 = strcmp(coefNames, 'AIabs:OD');
% 
%                     if any(idx1), p_x   = coefP(idx1); end
%                     if any(idx2), p_od  = coefP(idx2); end
%                     if any(idx3), p_int = coefP(idx3); end
% 
%                     R2 = lm.Rsquared.Ordinary;
%                 catch
%                     warning('LM failed for %s | %s | cue %d', roi_this, nd_this, i_cue);
%                 end
%             end
% 
%             xlabel(sprintf('|AI| (Cue %d)', i_cue));
%             ylabel('CI_S width');
%             title(sprintf('Cue %d', i_cue));
%             xlim([0 1]);
% 
%             y_min = min(y(idx_low), [], 'omitnan');
%             if isempty(y_min) || isnan(y_min)
%                 y_min = 0;
%             end
%             ylim([min(0, y_min) y_cap+0.05]);
% 
%             text(0.02, 0.98, sprintf('<=2: n=%d\n>2: n=%d', sum(idx_low), sum(idx_high)), ...
%                 'Units','normalized', 'VerticalAlignment','top', 'FontSize',10);
% 
%             text(0.02, 0.72, sprintf('p_{|AI|}=%.3g\np_{OD}=%.3g\np_{int}=%.3g\nR^2=%.2f', ...
%                 p_x, p_od, p_int, R2), ...
%                 'Units','normalized', 'VerticalAlignment','top', 'FontSize',10, ...
%                 'BackgroundColor','w', 'Margin', 4);
% 
%             axis square;
%             box off;
%         end
% 
%         cb = colorbar;
%         cb.Layout.Tile = 'east';
%         cb.Label.String = '|OD|';
% 
%         title(tl, sprintf('%s | %s | |AI| vs CI_S across cues', roi_this, nd_this));
%     end
% end

%% 

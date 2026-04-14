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

clear BehaviorData_nonStim_pFit_all BehaviorData_nonStim_pFit_all Jim_nonStim Clay_nonStim Jim_Stim Clay_Stim
%%
if ~ismember('Behav_mdl_full_ridgeSlope', unit_table.Properties.VariableNames)
    unit_table.Behav_mdl_full_ridgeSlope = cell(height(unit_table), 1);
end
% for i_rec = 1
for i_rec = 1:size(unit_table, 1)
    disp(['Rec number:', num2str(i_rec), '/', num2str(size(unit_table, 1))])
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
        % --- Ridge + CV on FULL model to stabilize beta2 (penalize only stim main effect) ---
        % Full model: logit(p) = b0 + b1*coh + b2*s + b3*(coh*s)
        X_full = [coh, s, coh.*s];
        K = 5;

        lambda_grid = logspace(-4, 2, 30);
        epsSlope = 1e-4;   % small constant for stability in the barrier

        [out, cv] = fit_full_penalizeStimSlope_CV(X_full, y, n, lambda_grid, K, epsSlope);

        unit_table.Behav_mdl_full_ridgeSlope{i_rec}{i_cue} = out;  % new field name

    end
end

%% Check population results
Bias_ori = NaN(size(unit_table, 1), 4);
B2_full = NaN(size(unit_table, 1), 4);
Bias_full = NaN(size(unit_table, 1), 4);
lambda_all = NaN(size(unit_table, 1), 4);
for i_rec = 1:size(unit_table, 1)
    Bias_ori(i_rec, :) = unit_table.Delta_bias{i_rec};
    for i_cue = 1:4
        b0_f = unit_table.Behav_mdl_full_ridgeSlope{i_rec}{i_cue}.b(1);
        b1_f = unit_table.Behav_mdl_full_ridgeSlope{i_rec}{i_cue}.b(2);
        b2_f = unit_table.Behav_mdl_full_ridgeSlope{i_rec}{i_cue}.b(3);
        b3_f = unit_table.Behav_mdl_full_ridgeSlope{i_rec}{i_cue}.b(4);
        c_n = -b0_f/b1_f;
        c_s = -(b0_f + b2_f)/(b1_f + b3_f);
        Bias_full(i_rec, i_cue) = c_s - c_n;
        B2_full(i_rec, i_cue) = b2_f;
        lambda_all(i_rec, i_cue) = unit_table.Behav_mdl_full_ridgeSlope{i_rec}{i_cue}.lambda;
    end
end
%%
figure();
scatter(Bias_ori, B2_full)
figure();
scatter(Bias_ori, Bias_full)
figure(); 
histogram(lambda_all)
%%
function [out, cv] = fit_full_penalizeStimSlope_CV(X, y, n, lambda_grid, K, epsSlope)
% Penalize stim slope being too small: stimSlope = b1 + b3
% Objective: -logL + lambda / ( (b1+b3)^2 + epsSlope )

    N = size(X,1);
    if N < K, error('N=%d rows is smaller than K=%d folds.', N, K); end

    fold_id = mod(randperm(N), K) + 1;
    dev = nan(numel(lambda_grid), K);

    for il = 1:numel(lambda_grid)
        lam = lambda_grid(il);
        for k = 1:K
            te = (fold_id == k);
            tr = ~te;

            b_tr = fit_full_penalizeStimSlope(X(tr,:), y(tr), n(tr), lam, epsSlope);
            dev(il,k) = binom_deviance(X(te,:), y(te), n(te), b_tr);
        end
    end

    cv.meanDev = mean(dev,2);
    cv.seDev   = std(dev,0,2) / sqrt(K);
    cv.lambda  = lambda_grid(:);

    [~, idxMin] = min(cv.meanDev);
    cv.idxMin = idxMin;

    % You can still do 1SE if you want; but idxMin is fine here
    idx = idxMin;
    lam_star = lambda_grid(idx);

    b_hat = fit_full_penalizeStimSlope(X, y, n, lam_star, epsSlope);

    out.b = b_hat;          % [b0 b1 b2 b3]
    out.lambda = lam_star;
    out.epsSlope = epsSlope;
end


function b_hat = fit_full_penalizeStimSlope(X, y, n, lambda, epsSlope)
% Fit full model with penalty discouraging stim slope ~0.
% stimSlope = b1 + b3. No penalty on b2.

    b0 = [0; 1; 0; 0];
    try
        coh = X(:,1); s = X(:,2); y0 = y; n0 = n;
        tbl0 = table(coh, s, y0, n0);
        mdl0 = fitglm(tbl0, 'y0 ~ coh + s + coh:s', ...
            'Distribution','binomial', 'BinomialSize', tbl0.n0);
        b0 = mdl0.Coefficients.Estimate;
    catch
    end

    fun = @(b) negloglik_plus_stimSlopeBarrier(b, X, y, n, lambda, epsSlope);

    if exist('fminunc','file') == 2
        opts = optimoptions('fminunc', 'Algorithm','quasi-newton', 'Display','off', ...
            'MaxIterations', 800, 'OptimalityTolerance', 1e-6, 'StepTolerance', 1e-8);
        b_hat = fminunc(fun, b0, opts);
    else
        opts = optimset('Display','off','MaxIter',3000,'TolX',1e-8,'TolFun',1e-8);
        b_hat = fminsearch(fun, b0, opts);
    end
end


function J = negloglik_plus_stimSlopeBarrier(b, X, y, n, lambda, epsSlope)
% b = [b0 b1 b2 b3]
% penalty term: lambda / ( (b1+b3)^2 + epsSlope )

    eta = b(1) + X(:,1)*b(2) + X(:,2)*b(3) + X(:,3)*b(4);
    p = sigmoid_clip(eta);

    nll = -sum( y.*log(p) + (n - y).*log(1 - p) );

    stimSlope = b(2) + b(4);   % b1 + b3
    pen = lambda ./ (stimSlope^2 + epsSlope);

    J = nll + pen;
end

function D = binom_deviance(X, y, n, b)
% Deviance proxy for binomial model on held-out data.
% We can use -2 log-likelihood (up to constants), which is enough for CV comparisons.

    eta = b(1) + X(:,1)*b(2) + X(:,2)*b(3) + X(:,3)*b(4);
    p = sigmoid_clip(eta);

    % -2 log-likelihood (without constants)
    D = -2 * sum( y.*log(p) + (n - y).*log(1 - p) );
end


function p = sigmoid_clip(eta)
% Sigmoid with clipping to avoid log(0) issues
    p = 1 ./ (1 + exp(-eta));
    eps0 = 1e-12;
    p = min(max(p, eps0), 1 - eps0);
end
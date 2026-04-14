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
if ~ismember('Behav_mdl_full_ridgeB2', unit_table.Properties.VariableNames)
    unit_table.Behav_mdl_full_ridgeB2 = cell(height(unit_table), 1);
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
        % --- Ridge + CV on FULL model to stabilize beta2 (penalize only stim main effect) ---
        % Full model: logit(p) = b0 + b1*coh + b2*s + b3*(coh*s)
        X_full = [coh, s, coh.*s];   % predictors (no intercept column)
        K = 5;

        lambda_grid = logspace(-4, 2, 30);   % adjust if needed
        [out, cv] = fit_full_selectiveRidge_CV(X_full, y, n, lambda_grid, K);

        % Outputs you want
        b0_ridge_full = out.b(1);
        b1_ridge_full = out.b(2);
        b2_ridge_full = out.b(3);   % selectively regularized
        b3_ridge_full = out.b(4);
        lambda_chosen = out.lambda;
        
        unit_table.Behav_mdl_full_ridgeB2{i_rec}{i_cue} = out;

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
        b0_f = unit_table.Behav_mdl_full_ridgeB2{i_rec}{i_cue}.b(1);
        b1_f = unit_table.Behav_mdl_full_ridgeB2{i_rec}{i_cue}.b(2);
        b2_f = unit_table.Behav_mdl_full_ridgeB2{i_rec}{i_cue}.b(3);
        b3_f = unit_table.Behav_mdl_full_ridgeB2{i_rec}{i_cue}.b(4);
        c_n = -b0_f/b1_f;
        c_s = -(b0_f + b2_f)/(b1_f + b3_f);
        Bias_full(i_rec, i_cue) = c_s - c_n;
        B2_full(i_rec, i_cue) = b2_f;
        lambda_all(i_rec, i_cue) = unit_table.Behav_mdl_full_ridgeB2{i_rec}{i_cue}.lambda;
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
function [out, cv] = fit_full_selectiveRidge_CV(X, y, n, lambda_grid, K)
% Selective ridge CV for FULL logistic/binomial model:
%   logit(p) = b0 + b1*coh + b2*s + b3*(coh*s)
% Input:
%   X : [N x 3] = [coh, s, coh*s]  (NO intercept column)
%   y : [N x 1] successes (#towards)
%   n : [N x 1] trials
%   lambda_grid : vector of candidate lambdas
%   K : number of folds
% Output:
%   out.b      : [b0 b1 b2 b3] with selective ridge on b2 only
%   out.lambda : chosen lambda (1SE rule by default)
%   cv         : struct with mean deviance, se, indices

    N = size(X,1);
    if N < K
        error('N=%d rows is smaller than K=%d folds.', N, K);
    end

    % Random fold assignment over rows (coherence bins)
    fold_id = mod(randperm(N), K) + 1;

    dev = nan(numel(lambda_grid), K);

    for il = 1:numel(lambda_grid)
        lam = lambda_grid(il);

        for k = 1:K
            te = (fold_id == k);
            tr = ~te;

            b_tr = fit_full_selectiveRidge(X(tr,:), y(tr), n(tr), lam);

            % Held-out deviance (up to additive constants)
            dev(il,k) = binom_deviance(X(te,:), y(te), n(te), b_tr);
        end
    end

    cv.meanDev = mean(dev,2);
    cv.seDev   = std(dev,0,2) / sqrt(K);
    cv.lambda  = lambda_grid(:);

    % Choose lambda by 1SE rule (more conservative; recommended)
    [minDev, idxMin] = min(cv.meanDev);
    thresh = minDev + cv.seDev(idxMin);
    idx1SE = find(cv.meanDev <= thresh, 1, 'last'); % largest lambda within 1SE

    cv.idxMin = idxMin;
    cv.idx1SE = idx1SE;

    % idx = idx1SE;  % change to idxMin if you want less shrinkage
    idx = cv.idxMin;
    lam_star = lambda_grid(idx);

    % Refit on ALL data with chosen lambda
    b_hat = fit_full_selectiveRidge(X, y, n, lam_star);

    out.b = b_hat;        % [b0 b1 b2 b3]
    out.lambda = lam_star;
end


function b_hat = fit_full_selectiveRidge(X, y, n, lambda)
% Fit selective ridge on b2 only:
% Minimize:  -log L(b) + lambda * b2^2
% where b = [b0 b1 b2 b3]
%
% Uses fminunc if available; otherwise fminsearch.

    % Initial guess: unpenalized fit via fitglm if available (nice), else zeros
    b0 = [0; 1; 0; 0];
    try
        % Build table for quick starting point (unpenalized)
        coh = X(:,1);
        s   = X(:,2);
        y0  = y;
        n0  = n;
        tbl0 = table(coh, s, y0, n0);
        mdl0 = fitglm(tbl0, 'y0 ~ coh + s + coh:s', ...
            'Distribution','binomial', 'BinomialSize', tbl0.n0);
        b0 = mdl0.Coefficients.Estimate;
    catch
        % keep default
    end

    % Objective function handle
    fun = @(b) negloglik_plus_penalty(b, X, y, n, lambda);

    % Optimize
    if exist('fminunc','file') == 2
        opts = optimoptions('fminunc', ...
            'Algorithm','quasi-newton', ...
            'Display','off', ...
            'MaxIterations', 500, ...
            'OptimalityTolerance', 1e-6, ...
            'StepTolerance', 1e-8);
        b_hat = fminunc(fun, b0, opts);
    else
        % fallback without Optimization Toolbox
        opts = optimset('Display','off','MaxIter',2000,'TolX',1e-8,'TolFun',1e-8);
        b_hat = fminsearch(fun, b0, opts);
    end
end


function J = negloglik_plus_penalty(b, X, y, n, lambda)
% b = [b0 b1 b2 b3]
% X = [coh, s, coh*s]
% penalty only on b2 (3rd element of b)

    eta = b(1) + X(:,1)*b(2) + X(:,2)*b(3) + X(:,3)*b(4);
    p = sigmoid_clip(eta);

    % Binomial negative log-likelihood (dropping constants: nchoosek terms)
    % NLL = -sum( y*log(p) + (n-y)*log(1-p) )
    nll = -sum( y.*log(p) + (n - y).*log(1 - p) );

    % Selective ridge penalty on b2
    pen = lambda * (b(3)^2);

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
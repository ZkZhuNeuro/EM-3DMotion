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
if ~ismember('Behav_mdl_full_ridgeB1B2B3', unit_table.Properties.VariableNames)
    unit_table.Behav_mdl_full_ridgeB1B2B3 = cell(height(unit_table), 1);
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

        lambda2_grid = logspace(-3, 2, 12);   % ridge for b2
        lambdas_grid = logspace(-3, 2, 12);   % barrier for stim slope
        epsSlope = 1e-4;

        [out, cv] = fit_full_twoPenalty_CV(X_full, y, n, lambda2_grid, lambdas_grid, K, epsSlope);

        unit_table.Behav_mdl_full_ridgeB1B2B3{i_rec}{i_cue} = out;  % new field name

    end
end

%% Check population results
Bias_ori = NaN(size(unit_table, 1), 4);
B2_full = NaN(size(unit_table, 1), 4);
Bias_full = NaN(size(unit_table, 1), 4);
lambda2_all = NaN(size(unit_table, 1), 4);
lambda13_all = NaN(size(unit_table, 1), 4);
for i_rec = 1:size(unit_table, 1)
    Bias_ori(i_rec, :) = unit_table.Delta_bias{i_rec};
    for i_cue = 1:4
        b0_f = unit_table.Behav_mdl_full_ridgeB1B2B3{i_rec}{i_cue}.b(1);
        b1_f = unit_table.Behav_mdl_full_ridgeB1B2B3{i_rec}{i_cue}.b(2);
        b2_f = unit_table.Behav_mdl_full_ridgeB1B2B3{i_rec}{i_cue}.b(3);
        b3_f = unit_table.Behav_mdl_full_ridgeB1B2B3{i_rec}{i_cue}.b(4);
        c_n = -b0_f/b1_f;
        c_s = -(b0_f + b2_f)/(b1_f + b3_f);
        Bias_full(i_rec, i_cue) = c_n - c_s;
        B2_full(i_rec, i_cue) = b2_f;
        lambda2_all(i_rec, i_cue) = unit_table.Behav_mdl_full_ridgeB1B2B3{i_rec}{i_cue}.lambda2;
        lambda13_all(i_rec, i_cue) = unit_table.Behav_mdl_full_ridgeB1B2B3{i_rec}{i_cue}.lambdas;
    end
end
%%
figure();
scatter(Bias_ori, B2_full)
figure();
scatter(Bias_ori, Bias_full)

figure(); 
scatter(Bias_ori, B2_full, 'filled', 'MarkerFaceAlpha', 0.5)
legend({'Comb', 'Left', 'Right', 'Stereo'})
xlabel('Original biases')
ylabel('b2 from the full GLM')

figure(); 
scatter(Bias_ori, Bias_full, 'filled', 'MarkerFaceAlpha', 0.5)
legend({'Comb', 'Left', 'Right', 'Stereo'})
xlabel('Original biases')
ylabel('GLM biases')

% figure(); 
% histogram(lambda2_all)
% figure(); 
% histogram(lambda13_all)
%%
function [out, cv] = fit_full_twoPenalty_CV(X, y, n, lambda2_grid, lambdas_grid, K, epsSlope)
% Two-penalty CV for FULL model:
% J(b) = -logL + lambda2*b2^2 + lambdas/( (b1+b3)^2 + epsSlope )
%
% X: [N x 3] = [coh, s, coh*s] (no intercept)
% y,n: binomial counts

    N = size(X,1);
    if N < K, error('N=%d rows < K=%d folds', N, K); end

    fold_id = mod(randperm(N), K) + 1;

    nL2 = numel(lambda2_grid);
    nLs = numel(lambdas_grid);

    dev = nan(nL2, nLs, K);

    % CV grid search
    for i2 = 1:nL2
        lam2 = lambda2_grid(i2);
        for is = 1:nLs
            lams = lambdas_grid(is);

            for k = 1:K
                te = (fold_id == k);
                tr = ~te;

                b_tr = fit_full_twoPenalty(X(tr,:), y(tr), n(tr), lam2, lams, epsSlope);
                dev(i2,is,k) = binom_deviance(X(te,:), y(te), n(te), b_tr);
            end
        end
    end

    meanDev = mean(dev, 3);
    seDev   = std(dev, 0, 3) / sqrt(K);

    % pick minimum mean deviance
    [minVal, linIdx] = min(meanDev(:));
    [i2_best, is_best] = ind2sub(size(meanDev), linIdx);

    cv.meanDev = meanDev;
    cv.seDev   = seDev;
    cv.lambda2_grid = lambda2_grid(:);
    cv.lambdas_grid = lambdas_grid(:);
    cv.best_i2 = i2_best;
    cv.best_is = is_best;
    cv.minDev  = minVal;

    lam2_star = lambda2_grid(i2_best);
    lams_star = lambdas_grid(is_best);

    % refit on all data
    b_hat = fit_full_twoPenalty(X, y, n, lam2_star, lams_star, epsSlope);

    out.b = b_hat;
    out.lambda2 = lam2_star;
    out.lambdas = lams_star;
    out.epsSlope = epsSlope;
end


function b_hat = fit_full_twoPenalty(X, y, n, lambda2, lambdas, epsSlope)
% Fit with two penalties.

    b0 = [0; 1; 0; 0];
    try
        coh = X(:,1); s = X(:,2);
        tbl0 = table(coh, s, y, n);
        mdl0 = fitglm(tbl0, 'y ~ coh + s + coh:s', ...
            'Distribution','binomial', 'BinomialSize', tbl0.n);
        b0 = mdl0.Coefficients.Estimate;
    catch
    end

    fun = @(b) nll_plus_twoPenalty(b, X, y, n, lambda2, lambdas, epsSlope);

    % --- Linear constraints: A*b <= bineq ---
    % b1 >= epsSlope  -> -b1 <= -epsSlope
    % b1 + b3 >= epsSlope -> -(b1+b3) <= -epsSlope
    A = [ 0 -1  0  0;
          0 -1  0 -1 ];
    bineq = [-epsSlope; -epsSlope];

    % (optional) you can set bounds too, but not required
    lb = []; ub = [];

    if exist('fmincon','file') == 2
        opts = optimoptions('fmincon', ...
            'Algorithm','interior-point', ...   % or 'sqp'
            'Display','off', ...
            'MaxIterations', 1000, ...
            'OptimalityTolerance', 1e-6, ...
            'StepTolerance', 1e-8);

        % Warm-start: if b0 violates constraints, project it to feasible
        b0 = make_feasible(b0, epsSlope);

        b_hat = fmincon(fun, b0, A, bineq, [], [], lb, ub, [], opts);

    elseif exist('fminunc','file') == 2
        % fallback (unconstrained)
        opts = optimoptions('fminunc','Algorithm','quasi-newton','Display','off', ...
            'MaxIterations', 800, 'OptimalityTolerance', 1e-6, 'StepTolerance', 1e-8);
        b_hat = fminunc(fun, b0, opts);
    else
        opts = optimset('Display','off','MaxIter',3000,'TolX',1e-8,'TolFun',1e-8);
        b_hat = fminsearch(fun, b0, opts);
    end
end

function b = make_feasible(b, epsSlope)
% Minimal "projection" fix so fmincon starts feasible.
% Only touches b1 and b3.
    b1 = b(2);
    b3 = b(4);

    if b1 < epsSlope
        b1 = epsSlope;
    end
    if (b1 + b3) < epsSlope
        b3 = epsSlope - b1;
    end

    b(2) = b1;
    b(4) = b3;
end

function J = nll_plus_twoPenalty(b, X, y, n, lambda2, lambdas, epsSlope)
% b = [b0 b1 b2 b3]
% penalties: lambda2*b2^2 + lambdas/( (b1+b3)^2 + epsSlope )

    eta = b(1) + X(:,1)*b(2) + X(:,2)*b(3) + X(:,3)*b(4);
    p = sigmoid_clip(eta);

    nll = -sum( y.*log(p) + (n - y).*log(1 - p) );

    pen_b2 = lambda2 * (b(3)^2);

    stimSlope = b(2) + b(4);
    pen_slope = lambdas / (stimSlope^2 + epsSlope);

    J = nll + pen_b2 + pen_slope;
end


function D = binom_deviance(X, y, n, b)
    eta = b(1) + X(:,1)*b(2) + X(:,2)*b(3) + X(:,3)*b(4);
    p = sigmoid_clip(eta);
    D = -2 * sum( y.*log(p) + (n - y).*log(1 - p) );
end


function p = sigmoid_clip(eta)
    p = 1 ./ (1 + exp(-eta));
    eps0 = 1e-12;
    p = min(max(p, eps0), 1 - eps0);
end
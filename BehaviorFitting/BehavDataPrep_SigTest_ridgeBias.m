clear;
load('UnitTable_updating.mat')

load("P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\BehaviorFitting\BehaviorData_Clay.mat")
Clay_nonStim = BehaviorData_nonStim_pFit_all;
Clay_Stim    = BehaviorData_Stim_pFit_all;

load("P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\BehaviorFitting\BehaviorData_Jim.mat")
Jim_nonStim = BehaviorData_nonStim_pFit_all;
Jim_Stim    = BehaviorData_Stim_pFit_all;

Data_N = [Jim_nonStim; Clay_nonStim];
Data_S = [Jim_Stim;  Clay_Stim];

clear BehaviorData_nonStim_pFit_all BehaviorData_Stim_pFit_all ...
      Jim_nonStim Clay_nonStim Jim_Stim Clay_Stim

%% =========================
%  Settings
%  =========================
fieldName = 'Behav_mdl_full_deltaPSEpen';

K = 5;
lambdaDelta_grid = logspace(-2, 5, 20);   % strength of deltaPSE penalty
deltaMax = 1;                          % tolerated abs(deltaPSE)
epsSlope = 1e-4;                          % minimum allowed slope

%% =========================
%  Add output field if needed
%  =========================
if ~ismember(fieldName, unit_table.Properties.VariableNames)
    unit_table.(fieldName) = cell(height(unit_table), 1);
end

%% =========================
%  Fit all recordings / cues
%  =========================
for i_rec = 1:size(unit_table, 1)
    disp(['Rec number: ' num2str(i_rec) '/' num2str(size(unit_table, 1))])

    if isempty(unit_table.(fieldName){i_rec})
        unit_table.(fieldName){i_rec} = cell(1, size(Data_N{i_rec}, 2));
    end

    for i_cue = 1:size(Data_N{i_rec}, 2)

        Behav_N = Data_N{i_rec}(i_cue).data;
        Behav_S = Data_S{i_rec}(i_cue).data;

        % Build model variables
        coh = [Behav_N(:,1); Behav_S(:,1)];
        y   = [Behav_N(:,2); Behav_S(:,2)];
        n   = [Behav_N(:,3); Behav_S(:,3)];
        s   = [zeros(size(Behav_N,1),1); ones(size(Behav_S,1),1)];

        % Full model design matrix (no intercept column)
        % logit(p) = b0 + b1*coh + b2*s + b3*(coh*s)
        X_full = [coh, s, coh.*s];

        [out, cv] = fit_full_deltaPSEPenalty_CV(X_full, y, n, ...
            lambdaDelta_grid, K, epsSlope, deltaMax);

        out.cv = cv;
        unit_table.(fieldName){i_rec}{i_cue} = out;
    end
end

%% =========================
%  Check population results
%  =========================
Bias_ori      = NaN(size(unit_table, 1), 4);
Bias_fit      = NaN(size(unit_table, 1), 4);
B2_full       = NaN(size(unit_table, 1), 4);
lambdaD_all   = NaN(size(unit_table, 1), 4);
PSE_N_all     = NaN(size(unit_table, 1), 4);
PSE_S_all     = NaN(size(unit_table, 1), 4);
slopeN_all    = NaN(size(unit_table, 1), 4);
slopeS_all    = NaN(size(unit_table, 1), 4);

for i_rec = 1:size(unit_table, 1)
    Bias_ori(i_rec, :) = unit_table.Delta_bias{i_rec};

    for i_cue = 1:4
        if isempty(unit_table.(fieldName){i_rec}) || isempty(unit_table.(fieldName){i_rec}{i_cue})
            continue
        end

        b = unit_table.(fieldName){i_rec}{i_cue}.b;
        b0 = b(1); b1 = b(2); b2 = b(3); b3 = b(4);

        c_n = -b0 / b1;
        c_s = -(b0 + b2) / (b1 + b3);

        Bias_fit(i_rec, i_cue)   = c_n - c_s;
        B2_full(i_rec, i_cue)    = b2;
        lambdaD_all(i_rec, i_cue)= unit_table.(fieldName){i_rec}{i_cue}.lambdaDelta;
        PSE_N_all(i_rec, i_cue)  = c_n;
        PSE_S_all(i_rec, i_cue)  = c_s;
        slopeN_all(i_rec, i_cue) = b1;
        slopeS_all(i_rec, i_cue) = b1 + b3;
    end
end

%% =========================
%  Quick plots
%  =========================
cueNames = {'Comb', 'Left', 'Right', 'Stereo'};

figure(); hold on
for i_cue = 1:4
    scatter(Bias_ori(:,i_cue), B2_full(:,i_cue), 36, 'filled', 'MarkerFaceAlpha', 0.5);
end
legend(cueNames, 'Location', 'best')
xlabel('Original biases')
ylabel('b2 from full GLM')
title('Original bias vs b2')

figure(); hold on
for i_cue = 1:4
    scatter(Bias_ori(:,i_cue), Bias_fit(:,i_cue), 36, 'filled', 'MarkerFaceAlpha', 0.5);
end
legend(cueNames, 'Location', 'best')
xlabel('Original biases')
ylabel('Fitted GLM biases')
title('Original bias vs fitted deltaPSE')
axis equal

figure(); hold on
for i_cue = 1:4
    scatter(Bias_ori(:,i_cue), lambdaD_all(:,i_cue), 36, 'filled', 'MarkerFaceAlpha', 0.5);
end
legend(cueNames, 'Location', 'best')
xlabel('Original biases')
ylabel('Chosen lambdaDelta')
title('Original bias vs chosen regularization')

figure();
histogram(lambdaD_all(:))
xlabel('lambdaDelta')
ylabel('Count')
title('Distribution of selected lambdaDelta')

%% =========================
%  Functions
%  =========================

function [out, cv] = fit_full_deltaPSEPenalty_CV(X, y, n, lambdaDelta_grid, K, epsSlope, deltaMax)
% Cross-validated fitting for:
% J(b) = -logL + lambdaDelta * max(|deltaPSE|-deltaMax, 0)^2

    N = size(X,1);
    if N < K
        error('N=%d rows < K=%d folds', N, K);
    end

    fold_id = mod(randperm(N), K) + 1;

    nLam = numel(lambdaDelta_grid);
    dev = nan(nLam, K);

    for iLam = 1:nLam
        lam = lambdaDelta_grid(iLam);

        for k = 1:K
            te = (fold_id == k);
            tr = ~te;

            b_tr = fit_full_deltaPSEPenalty(X(tr,:), y(tr), n(tr), ...
                lam, epsSlope, deltaMax);

            dev(iLam, k) = binom_deviance(X(te,:), y(te), n(te), b_tr);
        end
    end

    meanDev = mean(dev, 2, 'omitnan');
    seDev   = std(dev, 0, 2, 'omitnan') / sqrt(K);

    [minVal, iBest] = min(meanDev);
    lamStar = lambdaDelta_grid(iBest);

    b_hat = fit_full_deltaPSEPenalty(X, y, n, lamStar, epsSlope, deltaMax);

    out.b = b_hat;
    out.lambdaDelta = lamStar;
    out.deltaMax = deltaMax;
    out.epsSlope = epsSlope;
    out.deltaPSE = compute_deltaPSE(b_hat);
    out.PSE_nonStim = -b_hat(1)/b_hat(2);
    out.PSE_Stim    = -(b_hat(1)+b_hat(3)) / (b_hat(2)+b_hat(4));

    cv.meanDev = meanDev;
    cv.seDev = seDev;
    cv.dev = dev;
    cv.lambdaDelta_grid = lambdaDelta_grid(:);
    cv.best_iLam = iBest;
    cv.minDev = minVal;
end

function b_hat = fit_full_deltaPSEPenalty(X, y, n, lambdaDelta, epsSlope, deltaMax)
% Fit full model with direct deltaPSE regularization.

    b0 = [0; 1; 0; 0];

    try
        coh = X(:,1);
        s   = X(:,2);
        tbl0 = table(coh, s, y, n);

        mdl0 = fitglm(tbl0, 'y ~ coh + s + coh:s', ...
            'Distribution', 'binomial', ...
            'BinomialSize', tbl0.n);

        b0 = mdl0.Coefficients.Estimate;
    catch
    end

    b0 = make_feasible(b0, epsSlope);

    fun = @(b) nll_plus_deltaPSEPenalty(b, X, y, n, lambdaDelta, epsSlope, deltaMax);

    % Constraints:
    % b1 >= epsSlope
    % b1 + b3 >= epsSlope
    A = [ 0 -1  0  0;
          0 -1  0 -1 ];
    bineq = [-epsSlope; -epsSlope];

    lb = [];
    ub = [];

    if exist('fmincon', 'file') == 2
        opts = optimoptions('fmincon', ...
            'Algorithm', 'interior-point', ...
            'Display', 'off', ...
            'MaxIterations', 1000, ...
            'OptimalityTolerance', 1e-6, ...
            'StepTolerance', 1e-8);

        b_hat = fmincon(fun, b0, A, bineq, [], [], lb, ub, [], opts);

    elseif exist('fminunc', 'file') == 2
        % fallback, no linear constraints beyond feasible initialization
        opts = optimoptions('fminunc', ...
            'Algorithm', 'quasi-newton', ...
            'Display', 'off', ...
            'MaxIterations', 800, ...
            'OptimalityTolerance', 1e-6, ...
            'StepTolerance', 1e-8);

        b_hat = fminunc(fun, b0, opts);

    else
        opts = optimset('Display', 'off', 'MaxIter', 3000, 'TolX', 1e-8, 'TolFun', 1e-8);
        b_hat = fminsearch(fun, b0, opts);
    end
end

function J = nll_plus_deltaPSEPenalty(b, X, y, n, lambdaDelta, epsSlope, deltaMax)
% Penalized objective:
% J = NLL + lambdaDelta * max(|deltaPSE|-deltaMax, 0)^2

    eta = b(1) + X(:,1)*b(2) + X(:,2)*b(3) + X(:,3)*b(4);
    p = sigmoid_clip(eta);

    nll = -sum(y .* log(p) + (n - y) .* log(1 - p));

    deltaPSE = compute_deltaPSE(b);

    % Thresholded quadratic penalty
    excess = max(abs(deltaPSE) - deltaMax, 0);
    pen_delta = lambdaDelta * excess^2;

    % Optional tiny soft barrier for near-zero slopes
    stimSlope = b(2) + b(4);
    pen_soft = 0;
    if b(2) <= epsSlope
        pen_soft = pen_soft + 1e6 * (epsSlope - b(2))^2;
    end
    if stimSlope <= epsSlope
        pen_soft = pen_soft + 1e6 * (epsSlope - stimSlope)^2;
    end

    J = nll + pen_delta + pen_soft;
end

function deltaPSE = compute_deltaPSE(b)
    b0 = b(1);
    b1 = b(2);
    b2 = b(3);
    b3 = b(4);

    c_n = -b0 / b1;
    c_s = -(b0 + b2) / (b1 + b3);
    deltaPSE = c_n - c_s;
end

function D = binom_deviance(X, y, n, b)
    eta = b(1) + X(:,1)*b(2) + X(:,2)*b(3) + X(:,3)*b(4);
    p = sigmoid_clip(eta);
    D = -2 * sum(y .* log(p) + (n - y) .* log(1 - p));
end

function b = make_feasible(b, epsSlope)
% Minimal feasibility correction for starting point.

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

function p = sigmoid_clip(eta)
    p = 1 ./ (1 + exp(-eta));
    eps0 = 1e-12;
    p = min(max(p, eps0), 1 - eps0);
end
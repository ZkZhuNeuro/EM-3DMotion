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
fieldName = 'Behav_mdl_full_lapse';

epsSlope = 1e-4;      % minimum allowed slope
lapseMax = 0.10;      % max lower/upper lapse

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
        % eta = b0 + b1*coh + b2*s + b3*(coh*s)
        X_full = [coh, s, coh.*s];

        out = fit_full_withLapse(X_full, y, n, epsSlope, lapseMax);
        unit_table.(fieldName){i_rec}{i_cue} = out;
    end
end

%% =========================
%  Check population results
%  =========================
Bias_ori      = NaN(size(unit_table, 1), 4);
Bias_fit      = NaN(size(unit_table, 1), 4);
B2_full       = NaN(size(unit_table, 1), 4);
PSE_N_all     = NaN(size(unit_table, 1), 4);
PSE_S_all     = NaN(size(unit_table, 1), 4);
slopeN_all    = NaN(size(unit_table, 1), 4);
slopeS_all    = NaN(size(unit_table, 1), 4);
gamma_all     = NaN(size(unit_table, 1), 4);
lambda_all    = NaN(size(unit_table, 1), 4);
exitflag_all  = NaN(size(unit_table, 1), 4);

for i_rec = 1:size(unit_table, 1)
    Bias_ori(i_rec, :) = unit_table.Delta_bias{i_rec};

    for i_cue = 1:4
        if isempty(unit_table.(fieldName){i_rec}) || isempty(unit_table.(fieldName){i_rec}{i_cue})
            continue
        end

        out = unit_table.(fieldName){i_rec}{i_cue};
        b = out.b;

        b0 = b(1); b1 = b(2); b2 = b(3); b3 = b(4);

        c_n = -b0 / b1;
        c_s = -(b0 + b2) / (b1 + b3);

        Bias_fit(i_rec, i_cue)    = c_n - c_s;
        B2_full(i_rec, i_cue)     = b2;
        PSE_N_all(i_rec, i_cue)   = c_n;
        PSE_S_all(i_rec, i_cue)   = c_s;
        slopeN_all(i_rec, i_cue)  = b1;
        slopeS_all(i_rec, i_cue)  = b1 + b3;
        gamma_all(i_rec, i_cue)   = out.gamma;
        lambda_all(i_rec, i_cue)  = out.lambda;
        exitflag_all(i_rec, i_cue)= out.exitflag;
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
ylabel('b2 from full GLM + lapse')
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

figure();
histogram(gamma_all(:))
xlabel('Lower lapse \gamma')
ylabel('Count')
title('Distribution of lower lapse')

figure();
histogram(lambda_all(:))
xlabel('Upper lapse \lambda')
ylabel('Count')
title('Distribution of upper lapse')

figure();
histogram(exitflag_all(:))
xlabel('Exit flag')
ylabel('Count')
title('Optimization exit flags')

%% =========================
%  Functions
%  =========================

function out = fit_full_withLapse(X, y, n, epsSlope, lapseMax)
% Fit full model with shared lower/upper lapse:
%
% p = gamma + (1 - gamma - lambda) * sigmoid(eta)
% eta = b0 + b1*coh + b2*s + b3*(coh*s)
%
% Parameters:
% theta = [b0 b1 b2 b3 gamma lambda]

    if exist('fmincon', 'file') ~= 2
        error('This code requires fmincon.');
    end

    % initial guess for [b0 b1 b2 b3]
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

    b0 = make_feasible_slopes(b0, epsSlope);

    % Start with tiny lapse
    theta0 = [b0(:); 0.02; 0.02];

    fun = @(theta) binom_nll_withLapse(X, y, n, theta);

    % Linear constraints on slopes:
    % b1 >= epsSlope
    % b1+b3 >= epsSlope
    %
    % theta = [b0 b1 b2 b3 gamma lambda]
    A = [ 0 -1  0  0  0  0;
          0 -1  0 -1  0  0 ];
    bineq = [-epsSlope; -epsSlope];

    % Bounds:
    % gamma in [0, lapseMax]
    % lambda in [0, lapseMax]
    lb = [-Inf; -Inf; -Inf; -Inf; 0; 0];
    ub = [ Inf;  Inf;  Inf;  Inf; lapseMax; lapseMax];

    opts = optimoptions('fmincon', ...
        'Algorithm', 'interior-point', ...
        'Display', 'off', ...
        'MaxIterations', 1000, ...
        'MaxFunctionEvaluations', 5000, ...
        'OptimalityTolerance', 1e-6, ...
        'ConstraintTolerance', 1e-8, ...
        'StepTolerance', 1e-8);

    [theta_hat, fval, exitflag, output] = fmincon(fun, theta0, A, bineq, [], [], lb, ub, [], opts);

    b = theta_hat(1:4);
    gamma = theta_hat(5);
    lambda = theta_hat(6);

    out.theta = theta_hat;
    out.b = b;
    out.gamma = gamma;
    out.lambda = lambda;
    out.nll = fval;
    out.exitflag = exitflag;
    out.output = output;
    out.epsSlope = epsSlope;
    out.lapseMax = lapseMax;

    out.deltaPSE = compute_deltaPSE(b);
    out.PSE_nonStim = -b(1) / b(2);
    out.PSE_Stim    = -(b(1) + b(3)) / (b(2) + b(4));
    out.slope_nonStim = b(2);
    out.slope_Stim    = b(2) + b(4);

    out.p0_nonStim = psychometric_withLapse(0, b(1), b(2), gamma, lambda);
    out.p0_Stim    = psychometric_withLapse(0, b(1)+b(3), b(2)+b(4), gamma, lambda);
end

function nll = binom_nll_withLapse(X, y, n, theta)
% Negative log-likelihood with lapse
% theta = [b0 b1 b2 b3 gamma lambda]

    b0 = theta(1);
    b1 = theta(2);
    b2 = theta(3);
    b3 = theta(4);
    gamma = theta(5);
    lambda = theta(6);

    eta = b0 + X(:,1)*b1 + X(:,2)*b2 + X(:,3)*b3;
    sig = sigmoid_clip(eta);

    p = gamma + (1 - gamma - lambda) .* sig;
    p = clip_prob(p);

    nll = -sum(y .* log(p) + (n - y) .* log(1 - p));
end

function p = psychometric_withLapse(coh, intercept, slope, gamma, lambda)
    eta = intercept + slope .* coh;
    sig = sigmoid_clip(eta);
    p = gamma + (1 - gamma - lambda) .* sig;
    p = clip_prob(p);
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

function b = make_feasible_slopes(b, epsSlope)
% Minimal feasibility correction for starting point

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
    p = clip_prob(p);
end

function p = clip_prob(p)
    eps0 = 1e-12;
    p = min(max(p, eps0), 1 - eps0);
end
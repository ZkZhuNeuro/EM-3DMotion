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
% Settings
% =========================
fieldName = 'Behav_mdl_full_deltaPSEcap2';
epsSlope  = 1e-4;   % minimum allowed slope
deltaCap  = 2;      % hard cap on abs(deltaPSE)

%% =========================
% Add output field if needed
% =========================
if ~ismember(fieldName, unit_table.Properties.VariableNames)
    unit_table.(fieldName) = cell(height(unit_table), 1);
end

%% =========================
% Fit all recordings / cues
% =========================
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

        out = fit_full_deltaPSECap(X_full, y, n, epsSlope, deltaCap);
        unit_table.(fieldName){i_rec}{i_cue} = out;
    end
end

%% =========================
% Check population results
% =========================
Bias_ori      = NaN(size(unit_table, 1), 4);
Bias_fit      = NaN(size(unit_table, 1), 4);
B2_full       = NaN(size(unit_table, 1), 4);
PSE_N_all     = NaN(size(unit_table, 1), 4);
PSE_S_all     = NaN(size(unit_table, 1), 4);
slopeN_all    = NaN(size(unit_table, 1), 4);
slopeS_all    = NaN(size(unit_table, 1), 4);
exitflag_all  = NaN(size(unit_table, 1), 4);

for i_rec = 1:size(unit_table, 1)
    Bias_ori(i_rec, :) = unit_table.Delta_bias{i_rec};

    for i_cue = 1:4
        if isempty(unit_table.(fieldName){i_rec}) || isempty(unit_table.(fieldName){i_rec}{i_cue})
            continue
        end

        out = unit_table.(fieldName){i_rec}{i_cue};
        b = out.b;

        b0 = b(1);
        b1 = b(2);
        b2 = b(3);
        b3 = b(4);

        c_n = -b0 / b1;
        c_s = -(b0 + b2) / (b1 + b3);

        Bias_fit(i_rec, i_cue)    = c_n - c_s;
        B2_full(i_rec, i_cue)     = b2;
        PSE_N_all(i_rec, i_cue)   = c_n;
        PSE_S_all(i_rec, i_cue)   = c_s;
        slopeN_all(i_rec, i_cue)  = b1;
        slopeS_all(i_rec, i_cue)  = b1 + b3;
        exitflag_all(i_rec, i_cue)= out.exitflag;
    end
end

%% =========================
% Quick plots
% =========================
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
yline( 2, '--k');
yline(-2, '--k');
yline( 0, 'k');
xline( 0, 'k');
axis square


figure();
histogram(Bias_fit(:))
xlabel('Fitted deltaPSE')
ylabel('Count')
title('Distribution of fitted deltaPSE')

figure();
histogram(exitflag_all(:))
xlabel('Exit flag')
ylabel('Count')
title('Optimization exit flags')

%% =========================
% Functions
% =========================

function out = fit_full_deltaPSECap(X, y, n, epsSlope, deltaCap)
% Fit full model with hard constraints:
% 1) b1 >= epsSlope
% 2) b1 + b3 >= epsSlope
% 3) abs(deltaPSE) <= deltaCap

    if exist('fmincon', 'file') ~= 2
        error('This code requires fmincon because abs(deltaPSE) <= deltaCap is a nonlinear constraint.');
    end

    % Initial guess
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

    % Make initial guess feasible for linear constraints
    b0 = make_feasible_slopes(b0, epsSlope);

    % If initial guess violates delta cap, try shrinking b2/b3 a bit
    b0 = make_feasible_deltaCap(b0, deltaCap, epsSlope);

    fun = @(b) binom_nll(X, y, n, b);

    % Linear constraints:
    % b1 >= epsSlope       -> -b1 <= -epsSlope
    % b1+b3 >= epsSlope    -> -(b1+b3) <= -epsSlope
    A = [ 0 -1  0  0;
          0 -1  0 -1 ];
    bineq = [-epsSlope; -epsSlope];

    nonlcon = @(b) deltaPSE_nonlcon(b, deltaCap);

    opts = optimoptions('fmincon', ...
        'Algorithm', 'sqp', ...
        'Display', 'off', ...
        'MaxIterations', 1000, ...
        'MaxFunctionEvaluations', 5000, ...
        'OptimalityTolerance', 1e-6, ...
        'ConstraintTolerance', 1e-8, ...
        'StepTolerance', 1e-8);

    [b_hat, fval, exitflag, output] = fmincon(fun, b0, A, bineq, [], [], [], [], nonlcon, opts);

    % Store outputs
    out.b = b_hat;
    out.nll = fval;
    out.exitflag = exitflag;
    out.output = output;
    out.epsSlope = epsSlope;
    out.deltaCap = deltaCap;

    out.deltaPSE = compute_deltaPSE(b_hat);
    out.PSE_nonStim = -b_hat(1) / b_hat(2);
    out.PSE_Stim    = -(b_hat(1) + b_hat(3)) / (b_hat(2) + b_hat(4));
    out.slope_nonStim = b_hat(2);
    out.slope_Stim    = b_hat(2) + b_hat(4);
end

function nll = binom_nll(X, y, n, b)
% Negative log-likelihood for binomial GLM
% b = [b0 b1 b2 b3]

    eta = b(1) + X(:,1)*b(2) + X(:,2)*b(3) + X(:,3)*b(4);
    p = sigmoid_clip(eta);

    nll = -sum(y .* log(p) + (n - y) .* log(1 - p));
end

function [c, ceq] = deltaPSE_nonlcon(b, deltaCap)
% Nonlinear inequality constraint:
% abs(deltaPSE) <= deltaCap
%
% fmincon expects c(b) <= 0

    deltaPSE = compute_deltaPSE(b);
    c = abs(deltaPSE) - deltaCap;
    ceq = [];
end

function deltaPSE = compute_deltaPSE(b)
% deltaPSE = PSE_nonStim - PSE_Stim

    b0 = b(1);
    b1 = b(2);
    b2 = b(3);
    b3 = b(4);

    c_n = -b0 / b1;
    c_s = -(b0 + b2) / (b1 + b3);

    deltaPSE = c_n - c_s;
end

function b = make_feasible_slopes(b, epsSlope)
% Ensure linear slope constraints are satisfied for initialization

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

function b = make_feasible_deltaCap(b, deltaCap, epsSlope)
% Simple heuristic to improve the starting point if abs(deltaPSE) is too large.
% This is only for initialization; final enforcement is done by fmincon.

    b = make_feasible_slopes(b, epsSlope);

    if abs(compute_deltaPSE(b)) <= deltaCap
        return
    end

    scales = [0.8 0.5 0.25 0.1 0.05 0.01 0];
    for i = 1:numel(scales)
        s = scales(i);
        b_try = b;
        b_try(3) = s * b_try(3);   % shrink b2
        b_try(4) = s * b_try(4);   % shrink b3
        b_try = make_feasible_slopes(b_try, epsSlope);

        if abs(compute_deltaPSE(b_try)) <= deltaCap
            b = b_try;
            return
        end
    end

    % Fallback: zero condition effects
    b(3) = 0;
    b(4) = 0;
    b = make_feasible_slopes(b, epsSlope);
end

function p = sigmoid_clip(eta)
    p = 1 ./ (1 + exp(-eta));
    eps0 = 1e-12;
    p = min(max(p, eps0), 1 - eps0);
end
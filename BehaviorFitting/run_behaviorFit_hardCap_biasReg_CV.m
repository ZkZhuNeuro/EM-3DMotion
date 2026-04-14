clear;
load('UnitTable_updating.mat')

%% =========================
% Load behavior data
% =========================
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
lapseMax   = 0.10;                    % hard cap for lower/upper lapse
deltaMax   = 1;                       % no penalty if |threshold| <= deltaMax
lambdaGrid = [0 0.1 0.3 1 3 10 30 100];
nFolds     = 5;
rngSeed    = 1;

% Parameters from behavioral fitting
options = struct();
options.sigmoidName = 'norm';
lowerBound = 2;
priorWidth = @(x) (x>0 & x<=lowerBound).*(1-cos(pi.*x./lowerBound)) + ...
                  (x>lowerBound & x<=100).*2;
options.priors{2} = priorWidth;

%% =========================
% Add output fields if needed
% =========================
if ~ismember('Behave_N', unit_table.Properties.VariableNames)
    unit_table.Behave_N = cell(height(unit_table), 1);
end

if ~ismember('Behave_S', unit_table.Properties.VariableNames)
    unit_table.Behave_S = cell(height(unit_table), 1);
end

if ~ismember('Behave_regInfo_N', unit_table.Properties.VariableNames)
    unit_table.Behave_regInfo_N = cell(height(unit_table), 1);
end

if ~ismember('Behave_regInfo_S', unit_table.Properties.VariableNames)
    unit_table.Behave_regInfo_S = cell(height(unit_table), 1);
end

if ~ismember('Behave_lambdaCV_N', unit_table.Properties.VariableNames)
    unit_table.Behave_lambdaCV_N = cell(height(unit_table), 1);
end

if ~ismember('Behave_lambdaCV_S', unit_table.Properties.VariableNames)
    unit_table.Behave_lambdaCV_S = cell(height(unit_table), 1);
end

%% Find outliers
Bias_ori = NaN(size(unit_table, 1), 4);
for i_rec = 1:size(unit_table, 1)
    for i_cue = 1:4
        Bias_ori(i_rec, i_cue) = unit_table.Delta_bias{i_rec}(i_cue);
    end
end

outliers = find(abs(Bias_ori) > 2);
outliers = sort(unique(mod(outliers, size(unit_table, 1))));

%% =========================
% Main loop:
% choose lambda separately for each rec x cue x condition,
% then fit full data with that lambda
% =========================
% for i_rec = 1:size(unit_table, 1)
bias_outliers_ori = size(length(outliers), 4);
bias_outliers_ridge = size(length(outliers), 4);
for i_outlier = 1:numel(outliers)
    i_rec = outliers(i_outlier);
    fprintf('\nRec number: %d/%d\n', i_rec, size(unit_table,1));

    for i_cue = 1:4
        fprintf('  cue %d/4\n', i_cue);

        Behav_N = Data_N{i_rec}(i_cue).data;
        Behav_S = Data_S{i_rec}(i_cue).data;

        if isempty(Behav_N)
            fprintf('    N skipped: empty data\n');
        else
            [bestLambda_N, cvSummary_N] = select_lambda_singleFit_CV( ...
                Behav_N, lambdaGrid, nFolds, lapseMax, deltaMax, options, rngSeed);

            fprintf('    N best lambda = %g\n', bestLambda_N);

            result_N0 = psignifit_controlLapse(Behav_N, lapseMax, options);
            [result_N, regInfo_N] = psignifit_singleReg_threshold( ...
                Behav_N, lapseMax, bestLambda_N, deltaMax, options, result_N0);

            result_N.Posterior = [];
            result_N.weight = [];
            result_N.psiHandle = [];

            regInfo_N.cvSummary = cvSummary_N;
            regInfo_N.bestLambda = bestLambda_N;

            unit_table.Behave_N{i_rec}{i_cue} = result_N;
            unit_table.Behave_regInfo_N{i_rec}{i_cue} = regInfo_N;
            unit_table.Behave_lambdaCV_N{i_rec}{i_cue} = cvSummary_N;
        end

        if isempty(Behav_S)
            fprintf('    S skipped: empty data\n');
        else
            [bestLambda_S, cvSummary_S] = select_lambda_singleFit_CV( ...
                Behav_S, lambdaGrid, nFolds, lapseMax, deltaMax, options, rngSeed);

            fprintf('    S best lambda = %g\n', bestLambda_S);

            result_S0 = psignifit_controlLapse(Behav_S, lapseMax, options);
            [result_S, regInfo_S] = psignifit_singleReg_threshold( ...
                Behav_S, lapseMax, bestLambda_S, deltaMax, options, result_S0);

            result_S.Posterior = [];
            result_S.weight = [];
            result_S.psiHandle = [];

            regInfo_S.cvSummary = cvSummary_S;
            regInfo_S.bestLambda = bestLambda_S;

            unit_table.Behave_S{i_rec}{i_cue} = result_S;
            unit_table.Behave_regInfo_S{i_rec}{i_cue} = regInfo_S;
            unit_table.Behave_lambdaCV_S{i_rec}{i_cue} = cvSummary_S;

            bias_outliers_ori(i_rec, i_cue) = unit_table.Delta_bias{i_rec}(i_cue);
            bias_outliers_ridge(i_rec, i_cue) = result_N.Fit(1) - result_S.Fit(1);
        end
    end
end

%% =========================
% Save
% =========================
cd C:\EM\BehaviorFitting
save('unit_table_lapseHardCap10_singleReg_lambdaPerDataset.mat', ...
    'unit_table', '-v7.3')
cd P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\BehaviorFitting

fprintf('\nDone.\n')

%% =========================
% Optional checks
% =========================
colorsteps = [0 0 0;...
    0 0 255;...
    5 150 5;...
    234 0 233]/255;

%%

figure()
hold on
for i_cue = 1:4
    scatter(bias_outliers_ori(outliers, i_cue), bias_outliers_ridge(outliers, i_cue), 'MarkerEdgeColor', colorsteps(i_cue,:));
end
plot([-2.5 2.5], [-2 -2], 'k')
plot([-2.5 2.5], [2 2], 'k')
plot([-2 -2], [-2.5 2.5], 'k')
plot([2 2], [-2.5 2.5], 'k')
axis square
xlabel('Original biases')
ylabel('Checking biases')
%%
lapse_S_left = NaN(size(Data_N, 1), 4);
lapse_S_right = NaN(size(Data_N, 1), 4);
lapse_S_left_fit = NaN(size(Data_N, 1), 4);
lapse_S_right_fit = NaN(size(Data_N, 1), 4);

for i_rec = 1:size(unit_table, 1)
    for i_cue = 1:4
        if ~isempty(Data_S{i_rec}(i_cue).Fit) && ~isempty(unit_table.Behave_S{i_rec}{i_cue})
            lapse_S_left(i_rec, i_cue)      = Data_S{i_rec}(i_cue).Fit(4);
            lapse_S_right(i_rec, i_cue)     = Data_S{i_rec}(i_cue).Fit(3);
            lapse_S_left_fit(i_rec, i_cue)  = unit_table.Behave_S{i_rec}{i_cue}.Fit(4);
            lapse_S_right_fit(i_rec, i_cue) = unit_table.Behave_S{i_rec}{i_cue}.Fit(3);
        end
    end
end

figure()
hold on
for i_cue = 1:4
    scatter(lapse_S_left(:, i_cue), lapse_S_left_fit(:, i_cue), ...
        'MarkerEdgeColor', colorsteps(i_cue,:));
end
axis square
xlabel('Original lapse leftside')
ylabel('Refit lapse leftside')
xlim([0 0.5]); ylim([0 0.5])
plot([0 0.5], [0 0.5], 'k')
plot([0 0.5], [lapseMax lapseMax], 'r--')

figure()
hold on
for i_cue = 1:4
    scatter(lapse_S_right(:, i_cue), lapse_S_right_fit(:, i_cue), ...
        'MarkerEdgeColor', colorsteps(i_cue,:));
end
axis square
xlabel('Original lapse rightside')
ylabel('Refit lapse rightside')
xlim([0 0.5]); ylim([0 0.5])
plot([0 0.5], [0 0.5], 'k')
plot([0 0.5], [lapseMax lapseMax], 'r--')

%% =========================================================
function [bestLambda, out] = select_lambda_singleFit_CV( ...
    dataFull, lambdaGrid, nFolds, lapseCap, deltaMax, options, rngSeed)

    if nargin < 7 || isempty(rngSeed)
        rngSeed = 1;
    end
    rng(rngSeed);

    nLam = numel(lambdaGrid);

    totalTestNLL = zeros(nLam, 1);
    totalTestTrials = zeros(nLam, 1);

    % Same CV splits for all lambdas
    foldData = make_cv_splits_singleDataset(dataFull, nFolds);

    for iLam = 1:nLam
        lambdaThis = lambdaGrid(iLam);
        fprintf('    testing lambda %g (%d/%d)\n', lambdaThis, iLam, nLam);

        lamNLL = 0;
        lamTrials = 0;

        for iFold = 1:nFolds
            trainData = foldData(iFold).trainData;
            testData  = foldData(iFold).testData;

            if sum(trainData(:,3)) == 0
                continue
            end
            if sum(testData(:,3)) == 0
                continue
            end

            result0 = psignifit_controlLapse(trainData, lapseCap, options);
            resultFit = psignifit_singleReg_threshold( ...
                trainData, lapseCap, lambdaThis, deltaMax, options, result0);

            testNLL = psychometric_nll(testData, resultFit.Fit, resultFit.options);

            lamNLL = lamNLL + testNLL;
            lamTrials = lamTrials + sum(testData(:,3));
        end

        totalTestNLL(iLam) = lamNLL;
        totalTestTrials(iLam) = lamTrials;
    end

    meanNLLperTrial = totalTestNLL ./ max(totalTestTrials, 1);

    [~, idxBest] = min(totalTestNLL);
    bestLambda = lambdaGrid(idxBest);

    out = struct();
    out.lambdaGrid = lambdaGrid(:);
    out.totalTestNLL = totalTestNLL;
    out.totalTestTrials = totalTestTrials;
    out.meanNLLperTrial = meanNLLperTrial;
    out.bestLambda = bestLambda;
    out.table = table(lambdaGrid(:), totalTestNLL, totalTestTrials, meanNLLperTrial, ...
        'VariableNames', {'lambdaDelta', 'totalTestNLL', 'totalTestTrials', 'meanNLLperTrial'});
end

%% =========================================================
function foldData = make_cv_splits_singleDataset(dataFull, nFolds)

    foldData = struct('trainData', [], 'testData', []);
    foldData = repmat(foldData, nFolds, 1);

    for iFold = 1:nFolds
        [trainData, testData] = split_one_dataset(dataFull, 1/nFolds);
        foldData(iFold).trainData = trainData;
        foldData(iFold).testData = testData;
    end
end

%% =========================================================
function [trainData, testData] = split_one_dataset(data, testFrac)

    trainData = data;
    testData  = data;

    for i = 1:size(data,1)
        x  = data(i,1);
        k  = data(i,2);
        n  = data(i,3);

        if n <= 0
            trainData(i,:) = [x 0 0];
            testData(i,:)  = [x 0 0];
            continue
        end

        nTest = round(n * testFrac);
        nTest = min(max(nTest, 0), n);

        if nTest == 0
            testK = 0;
        else
            testK = local_hypergeom_sample(n, k, nTest);
        end

        trainK = k - testK;
        trainN = n - nTest;

        trainData(i,:) = [x trainK trainN];
        testData(i,:)  = [x testK nTest];
    end
end

%% =========================================================
function x = local_hypergeom_sample(popN, popK, draws)

    if draws == 0 || popK == 0
        x = 0;
        return
    end
    if popK == popN
        x = draws;
        return
    end

    successes = [true(popK,1); false(popN-popK,1)];
    idx = randperm(popN, draws);
    x = sum(successes(idx));
end

%% =========================================================
function nll = psychometric_nll(data, Fit, options)

    if isempty(data)
        nll = 0;
        return
    end

    x = data(:,1);
    k = data(:,2);
    n = data(:,3);

    p = Fit(4) + (1 - Fit(3) - Fit(4)) .* options.sigmoidHandle(x, Fit(1), Fit(2));
    p = min(max(p, 1e-12), 1 - 1e-12);

    valid = n > 0;
    k = k(valid);
    n = n(valid);
    p = p(valid);

    nll = -sum(k .* log(p) + (n-k) .* log(1-p));
end


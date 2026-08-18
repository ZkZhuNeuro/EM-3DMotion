clear; close all
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'common'));
[paths, outputDir] = currentSpreadInit(mfilename('fullpath'));
load(paths.unitTableUpdating)
load(paths.neuroAll)

colorsteps = [0 0 0;...
    0 0 255;...
    5 150 5;...
    234 0 233;
    0 100 255;...
    0 255 100]./255;

ChannelMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]; % Edge Design Dorsal-->Ventral

idx = strcmp(unit_table.ROI, 'MT') & strcmp(unit_table.Monkey, 'Jim');
unit_table = unit_table(idx, :);
NeuroAll = NeuroAll(idx);

%%
Z = cell(size(NeuroAll));
for i_rec = 1:size(NeuroAll)
    Z_rec = NaN(4, 8, 20, 16);
    for i_ch = 1:size(NeuroAll{i_rec}, 4)
        Neuro_Ch = NeuroAll{i_rec}(:, :, :, i_ch);
        Z_ch = (Neuro_Ch - mean(Neuro_Ch, "all", "omitmissing")) ./ std(Neuro_Ch, [], "all", "omitmissing");
        Z_ch = cat(2, Z_ch(:, [1:4], :), Z_ch(:, [end-3:end], :)); % Take the top 4 coh levels.
        if ismember(i_ch, unit_table.DeadChannel{i_rec})
            Z_ch = NaN(size(Z_ch));
        else
            Z_rec(:, :, :, i_ch) = Z_ch;
        end
    end
    Z{i_rec} = Z_rec;
end

%%
Z_comb_aligned = NaN(8, 20, 31, size(Z, 1));
behav = NaN(size(Z, 1), 1);
for i_rec = 1:size(Z, 1)
    Z_comb_rec = squeeze(Z{i_rec}(1, :, :, :)); 
    Z_comb_rec_aligned_short = Z_comb_rec(:, :, ChannelMap);
    StimCh = unit_table.StimElec(i_rec);
    StimCh_id = find(ChannelMap == StimCh);
    start_id = 17 - StimCh_id; 
    Z_comb_aligned(:, :, [start_id:start_id+15], i_rec) = Z_comb_rec_aligned_short;

    behav(i_rec) = unit_table.Delta_bias{i_rec}(1);
end
%%    
% Use only the first 6 repeats.
trialAmt = 8;
data_ori = Z_comb_aligned(:, 1:trialAmt, 12:16, :);
lambdas = [1e-3 1e-2 1e-1 1 5 10];
cv_err_reps = [];
for i_rep = 1:5
    disp(['Fit lambda. Repeat:', num2str(i_rep)])
    data = NaN(size(data_ori));
    for i_rec = 1:size(data_ori, 4)
        idx_perm = randperm(trialAmt);
        data(:, :, :, i_rec) = data_ori(:, idx_perm, :, i_rec);
    end

    [cv_err, ~] = tune_lambda(data, behav, lambdas);
    cv_err_reps = [cv_err_reps, cv_err];
end
cv_err_reps_mean = mean(cv_err_reps, 2);
[~, idx] = min(cv_err_reps_mean);
best_lambda = lambdas(idx);

%%
w_hat_reps = [];
idx_perm_reps = [];
for i_rep = 1:10
    rng('shuffle')
    disp(['Fit weights. Repeat:', num2str(i_rep)])
    data = NaN(size(data_ori));
    for i_rec = 1:size(data_ori, 4)
        idx_perm = randperm(trialAmt);
        data(:, :, :, i_rec) = data_ori(:, idx_perm, :, i_rec);
    end
    idx_perm_reps = [idx_perm_reps; idx_perm];
    w_hat = optimize_AI_weights(data, behav, best_lambda);
    w_hat_reps = [w_hat_reps, w_hat];
end

currentSpreadSaveResults(outputDir);

%%
function w_hat = optimize_AI_weights(data, behav, lambda)
% data: 8 x 20 x 31 x 56
% behav: 56 x 1

[~, ~, N, ~] = size(data);   % N should be 31 here

% --- initial guess ---
w0 = ones(N,1) / N;          % start from uniform weights

% --- constraints ---
% let's make them nonnegative and sum-to-1 (you can loosen this if you want)
A = [];
b = [];
Aeq = ones(1,N);
beq = 1;
lb = zeros(N,1);
ub = [];

opts = optimoptions('fmincon', ...
    'Display','iter', ...        % show progress
    'Algorithm','sqp');

w_hat = fmincon(@(w) objfun_AI(w, data, behav, lambda), ...
                w0, A, b, Aeq, beq, lb, ub, [], opts);
end

%%
function f = objfun_AI(w, data, behav, lambda)
% w: N x 1
% data: 8 x 20 x N x M
% behav: M x 1

M = size(data, 4);   % number of sessions

% 1) apply weights across neurons to get 8 x 20 x M
% reshape w so it lines up with the 3rd dim
w = w(:);  % ensure column
weighted = sum( data .* reshape(w, 1,1,[],1), 3, 'omitnan');  % 8 x 20 x M

% 2) compute AI per session
AI = zeros(M,1);
for m = 1:M
    R = weighted(:,:,m);     % 8 x 20 for this session
    R1 = R(1:4, :);          % first half
    R2_flip = R(5:8, :);    
    R2 = flipud(R2_flip);% second half
    AI(m) = AI_Calculator(R1, R2);
end

% 3) linear fit: behav ~ 1 + AI
X = AI;
beta = X \ behav;            % 2 x 1
pred = X * beta;             % M x 1
resid = behav - pred;

% 4) objective = SSE of regression
f = sum(resid.^2) + lambda * sum(w.^2);
end



%%
function [cv_err, best_lambda] = tune_lambda(data, behav, lambdas)

M = size(data,4);
foldAmt = size(data,2);
numL = numel(lambdas);
cv_err = zeros(numL,1);

for li = 1:numL
    lambda_w = lambdas(li);
    err_fold = zeros(6,1);   % leave-one-out over 6 repeats

    for test_m = 1:foldAmt
        train_idx = true(foldAmt,1);
        train_idx(test_m) = false;
        % 1) fit w on training sessions
        w_hat = optimize_AI_weights_subset(data, behav, lambda_w, train_idx);

        % 2) compute AI for ALL sessions using this w
        % w_hat = w_hat(:);
        weighted = sum(data .* reshape(w_hat,1,1,[],1), 3, 'omitmissing');  % 8x20xM
        weighted(weighted == 0) = NaN;
        weighted = squeeze(weighted);

        AI_test = zeros(M,1);
        for m = 1:M
            R  = weighted(:,~train_idx,m);
            R1 = R(1:4,:);
            R2_flip = R(5:8,:);
            R2 = flipud(R2_flip);
            AI_test(m) = AI_Calculator(R1, R2);
        end

        % 3) drop NaN sessions (the smallest necessary NaN handling)
        valid = ~isnan(AI_test) & ~isnan(behav);
        AI_test   = AI_test(valid);
        yv    = behav(valid);

        % if too few valid points, make cost large so optimizer avoids this area
        if numel(yv) < 3
            f = 1e9;
            return;
        end
        
        beta  = AI_test \ yv;
        yhat  = AI_test * beta;
        err_fold(test_m) = sum((yv - yhat).^2);
    end
    cv_err(li) = mean(err_fold, 'omitmissing');   % average LOO error for this lambda
    fprintf('lambda=%g, CV error=%g\n', lambda_w, cv_err(li));
end

[~, idx] = min(cv_err);
best_lambda = lambdas(idx);

end
%%
function w_hat = optimize_AI_weights_subset(data, behav, lambda_w, train_idx)
% data: 8x20x31x56
% behav: 56x1
% train_idx: logical 56x1 or vector of indices to use for training

[~,~,N,~] = size(data);
if nargin < 4 || isempty(train_idx)
    train_idx = true(size(behav));
end

w0  = ones(N,1)/N;
A = []; b = [];
Aeq = ones(1,N); beq = 1;
lb = zeros(N,1); ub = [];

opts = optimoptions('fmincon','Display','off','Algorithm','sqp');

w_hat = fmincon(@(w) objfun_AI_subset(w, data, behav, lambda_w, train_idx), ...
                w0, A, b, Aeq, beq, lb, ub, [], opts);
end

%%
function f = objfun_AI_subset(w, data, behav, lambda_w, train_idx)
M = size(data,4);
w = w(:);
weighted = sum(data .* reshape(w,1,1,[],1), 3, 'omitmissing');  % 8x20xM
weighted(weighted == 0) = NaN;

AI = zeros(M,1);
for m = 1:M
    R  = weighted(:,train_idx,m);
    R1 = R(1:4,:);
    R2_flip = R(5:8,:);
    R2 = flipud(R2_flip);
    AI(m) = AI_Calculator(R1, R2);
end

% 3) drop NaN sessions (the smallest necessary NaN handling)
valid = ~isnan(AI) & ~isnan(behav);
AIv   = AI(valid);
yv    = behav(valid);

% if too few valid points, make cost large so optimizer avoids this area
if numel(yv) < 3
    f = 1e9;
    return;
end

Xtr = AIv;
Ytr = yv;
beta  = Xtr \ Ytr;
pred  = Xtr * beta;
resid = Ytr - pred;
sse   = sum(resid.^2);

ridge_term = lambda_w * sum(w.^2);
f = sse + ridge_term;
end




%%
function AI = AI_Calculator(R1, R2)

AI = mean((mean(R1,2,'omitnan') - mean(R2,2,'omitnan'))./(abs(mean(R1,2,'omitnan') - mean(R2,2,'omitnan')) + mean([std(R1,0,2,'omitnan'),std(R2,0,2,'omitnan')],2)),'omitnan'); 

end

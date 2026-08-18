clear
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

idx = [];
for i_rec = 1:size(unit_table, 1)
    if strcmp(unit_table.ROI{i_rec}, 'FST') & strcmp(unit_table.Monkey{i_rec}, 'Jim') ...
            & unit_table.p_AI{i_rec}(2) < 0.05 & unit_table.p_AI{i_rec}(3) < 0.05 & unit_table.Z3D_v_Z2D{i_rec} < 0
        idx(end + 1) = i_rec;
    end
end
unit_table = unit_table(idx, :);
NeuroAll = NeuroAll(idx);


%% Get firing rates across all channels into "Z"
Z = cell(size(NeuroAll));
AI_ref_CombAll = NaN(size(NeuroAll, 1), size(ChannelMap, 2));
AI_ref_Dom = NaN(size(NeuroAll));
AI_ref_NonDom = NaN(size(NeuroAll));
behav_Dom = NaN(size(Z, 1), 1);
behav_NonDom = NaN(size(Z, 1), 1);
OD_ref = NaN(size(Z, 1), 1);
for i_rec = 1:size(NeuroAll, 1)
    Z_rec = NaN(4, 8, 20, 16);
    for i_ch = 1:size(NeuroAll{i_rec}, 4)
        Neuro_Ch = NeuroAll{i_rec}(:, :, :, i_ch);
        % Z_ch = (Neuro_Ch - mean(Neuro_Ch, "all", "omitmissing")) ./ std(Neuro_Ch, [], "all", "omitmissing");
        Z_ch = Neuro_Ch;
        Z_ch = cat(2, Z_ch(:, [1:4], :), Z_ch(:, [end-3:end], :)); % Take the top 4 coh levels.
        if ismember(i_ch, unit_table.DeadChannel{i_rec})
            Z_ch = NaN(size(Z_ch));
        else
            Z_rec(:, :, :, i_ch) = Z_ch;
        end
    end
    Z{i_rec} = Z_rec;
    if unit_table.OD_max{i_rec} > 0
        AI_ref_Dom(i_rec) = unit_table.AI{i_rec}(2, unit_table.StimElec(i_rec));
        AI_ref_NonDom(i_rec) = unit_table.AI{i_rec}(3, unit_table.StimElec(i_rec));
        AI_ref_CombAll(i_rec, :) = unit_table.AI{i_rec}(1, :);
        behav_Dom(i_rec) = unit_table.Delta_bias{i_rec}(2);
        behav_NonDom(i_rec) = unit_table.Delta_bias{i_rec}(3);
    else
        AI_ref_Dom(i_rec) = unit_table.AI{i_rec}(3, unit_table.StimElec(i_rec));
        AI_ref_NonDom(i_rec) = unit_table.AI{i_rec}(2, unit_table.StimElec(i_rec));
        AI_ref_CombAll(i_rec, :) = unit_table.AI{i_rec}(1, :);
        behav_Dom(i_rec) = unit_table.Delta_bias{i_rec}(3);
        behav_NonDom(i_rec) = unit_table.Delta_bias{i_rec}(2);
    end
    OD_ref(i_rec) = unit_table.OD_max{i_rec};
end

%% align stimulation Chs. Get "Z_aligned"
behav_pers = [behav_Dom, behav_NonDom];
Z_aligned = NaN(3, 8, 20, 31, size(Z, 1));
AI_comb_aligned = NaN(size(AI_ref_CombAll, 1), 31);
behav = NaN(size(Z, 1), 1);
for i_rec = 1:size(Z, 1)
    Z_comb_rec = squeeze(Z{i_rec}(1:3, :, :, :));
    Z_comb_rec_aligned_short = Z_comb_rec(:, :, :, ChannelMap);
    AI_comb = AI_ref_CombAll(i_rec, :);
    AI_comb_aligned_short = AI_comb(ChannelMap);

    StimCh = unit_table.StimElec(i_rec);
    StimCh_id = find(ChannelMap == StimCh);
    start_id = 17 - StimCh_id;
    Z_aligned(:, :, :, [start_id:start_id+15], i_rec) = Z_comb_rec_aligned_short;
    AI_comb_aligned(i_rec, [start_id:start_id+15]) = AI_comb_aligned_short;

    Z_StimCh = squeeze(Z_comb_rec(:, :, StimCh));

    behav(i_rec) = unit_table.Delta_bias{i_rec}(1);
end

ch_distribution = sum(~isnan(squeeze(Z_aligned(1, 1, 1, :, :))), 2);

%%
% lambdas = [1e-3 1e-2 1e-1 1 5 10];
% cv_err_reps = [];
% for i_rep = 1
%     disp(['Fit lambda. Repeat:', num2str(i_rep)])
%     % data = NaN(size(Z));
%     % for i_rec = 1:size(Z, 4)
%     %     idx_perm = randperm(trialAmt);
%     %     data(:, :, :, i_rec) = Z(:, idx_perm, :, i_rec);
%     % end
% 
%     [cv_err, ~] = tune_lambda(Z_aligned, behav_Dom, lambdas);
%     cv_err_reps = [cv_err_reps, cv_err];
% end
% cv_err_reps_mean = mean(cv_err_reps, 2);
% [~, idx] = min(cv_err_reps_mean);
% best_lambda = lambdas(idx);
best_lambda = 5;

%%
Pred = ClusterPrediction(squeeze(Z_aligned(1, :, :, :, :)), Z_aligned(2:3, :, :, :, :));

sigma_hat = optimize_AI_weights(Z_aligned, behav_Dom, best_lambda); 

% 1) build weights from sigma
w = gaussian_weights(sigma_hat, 31);   % 31x1

% w = [0 0 0 0 1 0 0 0 0];
X = NaN(size(Pred, 1), 1);
for i_rec = 1:size(Pred, 1)
    X_rec = 0;
    weight_sum = 0;
    for i_clst = 1:size(Pred{i_rec}, 2)
        weight_sum = weight_sum + w(Pred{i_rec}(2, i_clst) + 16);
    end

    for i_clst = 1:size(Pred{i_rec}, 2)
        weight = w(Pred{i_rec}(2, i_clst) + 16) / weight_sum;
        X_rec = X_rec + Pred{i_rec}(1, i_clst) * weight;
    end
    X(i_rec) = X_rec;

end

%%
X_forPlot = [X;X];
x_plot = -1:0.1:1;
figure(); 
subplot(131)
hold on 
scatter(X_forPlot, [behav_Dom; behav_NonDom], 'r')

X_ref_forPlot = AI_ref_Dom .* abs(OD_ref);
X_ref_forPlot = [X_ref_forPlot; X_ref_forPlot];
scatter(X_ref_forPlot, [behav_Dom; behav_NonDom], 'b')

behav_pers = [behav_Dom; behav_NonDom];
for i_rec = 1:size(X_forPlot, 1)
    if xor(X_forPlot(i_rec) > X_ref_forPlot(i_rec), behav_pers(i_rec, 1) > 0)
    plot([X_forPlot(i_rec), X_ref_forPlot(i_rec)], [behav_pers(i_rec, 1), behav_pers(i_rec, 1)], 'Color', 'r')
    else
    plot([X_forPlot(i_rec), X_ref_forPlot(i_rec)], [behav_pers(i_rec, 1), behav_pers(i_rec, 1)], 'Color', 'b')
    end
end

axis square
xlim([-0.25 0.25])
ylim([-2 2])
plot([-6 6], [0 0], 'k')
plot([0 0], [-2 2], 'k')

subplot(132)
hold on 
scatter(X_forPlot, [behav_Dom; behav_NonDom], 'r')
x = [X_forPlot, ones(size(X_forPlot, 1), 1)];
beta = x \ [behav_Dom; behav_NonDom];
slope = beta(1); 
intercept = beta(2); 
plot(x_plot, intercept + x_plot*slope,'-','Color','r','LineWidth',2.5);
axis square
xlim([-0.25 0.25])
ylim([-2 2])
plot([-6 6], [0 0], 'k')
plot([0 0], [-2 2], 'k')

subplot(133)
hold on 
X_ref_forPlot = AI_ref_Dom .* abs(OD_ref);
X_ref_forPlot = [X_ref_forPlot; X_ref_forPlot];
scatter(X_ref_forPlot, [behav_Dom; behav_NonDom], 'b')
x = [X_ref_forPlot, ones(size(X_ref_forPlot, 1), 1)];
beta = x \ [behav_Dom; behav_NonDom];
slope = beta(1); 
intercept = beta(2); 
plot(x_plot, intercept + x_plot*slope,'-','Color','b','LineWidth',2.5);
axis square
xlim([-0.25 0.25])
ylim([-2 2])
plot([-6 6], [0 0], 'k')
plot([0 0], [-2 2], 'k')

%%
X_forPlot = [X;X];
x_plot = -8.5:0.1:8.5;
figure(); 

subplot(121)
hold on 
scatter(X_forPlot, [behav_Dom; behav_NonDom], 'r')
x = [X_forPlot, ones(size(X_forPlot, 1), 1)];
beta = x \ [behav_Dom; behav_NonDom];
slope = beta(1); 
intercept = beta(2); 
plot(x_plot, intercept + x_plot*slope,'-','Color','r','LineWidth',2.5);
axis square
xlim([-8.5 8.5])
ylim([-2 2])
plot([-8.5 8.5], [0 0], 'k')
plot([0 0], [-2 2], 'k')

subplot(122)
hold on 
X_ref_forPlot = AI_ref_Dom .* abs(OD_ref);
X_ref_forPlot = [X_ref_forPlot; X_ref_forPlot];
scatter(X_ref_forPlot, [behav_Dom; behav_NonDom], 'b')
x = [X_ref_forPlot, ones(size(X_ref_forPlot, 1), 1)];
beta = x \ [behav_Dom; behav_NonDom];
slope = beta(1); 
intercept = beta(2); 
plot(x_plot, intercept + x_plot*slope,'-','Color','b','LineWidth',2.5);
axis square
xlim([-0.25 0.25])
ylim([-2 2])
plot([-8.5 8.5], [0 0], 'k')
plot([0 0], [-2 2], 'k')

%%
[r_ref, p_ref] = corr(X_ref_forPlot, [behav_Dom; behav_NonDom])
[r, p] = corr(X_forPlot, [behav_Dom; behav_NonDom])

%%
behav = [behav_Dom; behav_NonDom];
testIdx = [ones(size(X_forPlot)); zeros(size(X_ref_forPlot))];
tbl = array2table([[behav; behav], [X_forPlot; X_ref_forPlot], testIdx], 'VariableNames', {'behav', 'AIOD', 'testIdx'});
lm = fitlm(tbl, 'behav ~ AIOD * testIdx');
anova(lm)

currentSpreadSaveResults(outputDir);

%%
function [cv_err, best_lambda] = tune_lambda(data, behav, lambdas)

M = size(data,5);
foldAmt = size(data,5);
numL = numel(lambdas);
cv_err = zeros(numL,1);

for li = 1:numL
    lambda_w = lambdas(li);
    err_fold = zeros(6,1);   % leave-one-out over 6 repeats

    for test_m = 1:foldAmt-3
        train_idx = true(foldAmt,1);
        train_idx(test_m:test_m+2) = false;
        % 1) fit w on training sessions
        sigma_hat = optimize_AI_weights_subset(data, behav, lambda_w, train_idx);
        % disp(test_m)
        Z_test = squeeze(data(1, :, 1:5, :, ~train_idx));
        Z_test_pers = squeeze(data(2:3, :, 1:5, :, ~train_idx));
        Pred_test = ClusterPrediction(Z_test, Z_test_pers);

        % 1) build weights from sigma
        w = gaussian_weights(sigma_hat, 31);   % 31x1

        % w = [0 0 0 0 1 0 0 0 0];
        for i_rec = 1:size(Pred_test, 1)
            X_rec = 0;
            weight_sum = 0;
            for i_clst = 1:size(Pred_test{i_rec}, 2)
                weight_sum = weight_sum + w(Pred_test{i_rec}(2, i_clst) + 16);
            end

            for i_clst = 1:size(Pred_test{i_rec}, 2)
                weight = w(Pred_test{i_rec}(2, i_clst) + 16) / weight_sum;
                X_rec = X_rec + Pred_test{i_rec}(1, i_clst) * weight;
            end
            X(i_rec) = X_rec;

        end

        beta = X' \ behav(~train_idx);            % 2 x 1
        pred = X' * beta;
        resid = behav(~train_idx) - pred;
        err_fold(test_m) = sum(resid.^2);

    end
    cv_err(li) = mean(err_fold, 'omitmissing');   % average LOO error for this lambda
    fprintf('lambda=%g, CV error=%g\n', lambda_w, cv_err(li));
    disp(sigma_hat)
end

[~, idx] = min(cv_err);
best_lambda = lambdas(idx);

end

%%
function sigma_hat = optimize_AI_weights(data, behav, lambda_w)
% data: 8 x 20 x 31 x 56
% behav: 56 x 1

% --- initial guess ---
sigma0 = 0.1;          % start from uniform weights

opts = optimoptions('fminunc', 'Display','off','Algorithm','quasi-newton');
sigma_hat = fminunc(@(sigma) objfun_AI(sigma, data, behav, lambda_w), sigma0, opts);
end

%%
function f = objfun_AI(sigma, data, behav, lambda_w)
[~, ~, ~, N, M] = size(data);   % N=31, M=56

% weighted = sum(data .* reshape(w,1,1,[],1), 3, 'omitmissing');  % 8x20xM
% weighted(weighted == 0) = NaN;

Z_train = squeeze(data(1, :, 1:5, :, :));
Z_train_pers = squeeze(data(2:3, :, 1:5, :, :));
Pred = ClusterPrediction(Z_train, Z_train_pers);

% 1) build weights from sigma
w = gaussian_weights(sigma, N);   % 31x1

% w = [0 0 0 0 1 0 0 0 0];
X = NaN(size(Pred, 1), 1);
for i_rec = 1:size(Pred, 1)
    X_rec = 0;
    weight_sum = 0;
    for i_clst = 1:size(Pred{i_rec}, 2)
        weight_sum = weight_sum + w(Pred{i_rec}(2, i_clst) + 16);
    end

    for i_clst = 1:size(Pred{i_rec}, 2)
        weight = w(Pred{i_rec}(2, i_clst) + 16) / weight_sum;
        X_rec = X_rec + Pred{i_rec}(1, i_clst) * weight;
    end
    X(i_rec) = X_rec;

end

beta = X \ behav;            % 2 x 1
% disp(beta)
pred = X * beta;
resid = behav - pred;
sse   = sum(resid.^2);

ridge_term = lambda_w * ((1 / sigma).^2);
f = sse + ridge_term;
end

%%
function AI = AI_Calculator(R1, R2)

AI = mean((mean(R1,2,'omitnan') - mean(R2,2,'omitnan'))./(abs(mean(R1,2,'omitnan') - mean(R2,2,'omitnan')) + mean([std(R1,[],2,'omitnan'),std(R2,[],2,'omitnan')],2)),'omitnan');

end

%%
function w = gaussian_weights(sigma, N)
if nargin < 2
    N = 31;
end
center = (N+1)/2;                 % 16 for N=31
x = (1:N)';                       % column
w = exp( -(x - center).^2 ./ (2*sigma^2) );
% normalize so they sum to 1
w = w / sum(w);
end

%%
function Pred = ClusterPrediction(Z_train, Z_train_pers)
%% Get AI for each channel separately
AI_comb_train = NaN(size(Z_train, 4), size(Z_train, 3));
for i_rec = 1:size(Z_train, 4)
    for i_ch = 1:size(Z_train, 3)
        Z_ch = squeeze(Z_train(:, :, i_ch, i_rec));
        RF_away = Z_ch(1:4, :);
        RF_towards = Z_ch(5:8, :);
        RF_towards_flp = flipud(RF_towards);
        AI_comb_train(i_rec, i_ch) = AI_Calculator(RF_towards_flp, RF_away);
    end

    % interpolate the NaN channel
    x = AI_comb_train(i_rec, :);
    idx = find( isnan(x) & ...
        circshift(~isnan(x),1) & ...   % left neighbor
        circshift(~isnan(x),-1));     % right neighbor

    idx(idx == 1 | idx == numel(x)) = []; % remove i = 1 and i = end just in case:
    x(idx) = (x(idx-1) + x(idx+1)) / 2;
    AI_comb_train(i_rec, :) = x;
    clear x
end

AI_left_train = NaN(size(Z_train_pers, 5), size(Z_train_pers, 4));
for i_rec = 1:size(Z_train_pers, 5)
    for i_ch = 1:size(Z_train_pers, 4)
        Z_ch = squeeze(Z_train_pers(1, :, :, i_ch, i_rec));
        RF_away = Z_ch(1:4, :);
        RF_towards = Z_ch(5:8, :);
        RF_towards_flp = flipud(RF_towards);
        AI_left_train(i_rec, i_ch) = AI_Calculator(RF_towards_flp, RF_away);
    end

    % interpolate the NaN channel
    x = AI_left_train(i_rec, :);
    idx = find( isnan(x) & ...
        circshift(~isnan(x),1) & ...   % left neighbor
        circshift(~isnan(x),-1));     % right neighbor

    idx(idx == 1 | idx == numel(x)) = []; % remove i = 1 and i = end just in case:
    x(idx) = (x(idx-1) + x(idx+1)) / 2;
    AI_left_train(i_rec, :) = x;
    clear x
end

AI_right_train = NaN(size(Z_train_pers, 5), size(Z_train_pers, 4));
for i_rec = 1:size(Z_train_pers, 5)
    for i_ch = 1:size(Z_train_pers, 4)
        Z_ch = squeeze(Z_train_pers(2, :, :, i_ch, i_rec));
        RF_away = Z_ch(1:4, :);
        RF_towards = Z_ch(5:8, :);
        RF_towards_flp = flipud(RF_towards);
        AI_right_train(i_rec, i_ch) = AI_Calculator(RF_towards_flp, RF_away);
    end

    % interpolate the NaN channel
    x = AI_right_train(i_rec, :);
    idx = find( isnan(x) & ...
        circshift(~isnan(x),1) & ...   % left neighbor
        circshift(~isnan(x),-1));     % right neighbor

    idx(idx == 1 | idx == numel(x)) = []; % remove i = 1 and i = end just in case:
    x(idx) = (x(idx-1) + x(idx+1)) / 2;
    AI_right_train(i_rec, :) = x;
    clear x
end
%% Find clusters based on combined AI
clusters = cell(size(AI_comb_train, 1), 1);
% Initialize a cell array to store the good groups for each recording
good_groups = cell(size(AI_comb_train, 1), 1);
for i_rec = 1:size(AI_comb_train, 1)
    A = [AI_comb_train(i_rec, :); ...
        AI_left_train(i_rec, :); ...
        AI_right_train(i_rec, :)];


    % Determine group labels: +1, -1, or 0 for NaN
    labels = sign(A);                 % 3 x N
    labels(isnan(A)) = 0;

    % Detect sign changes across columns (any of the 3 rows)
    % Result: 1 x (N-1) logical vector
    change_mask = any(diff(labels, 1, 2) ~= 0, 1);

    % Indices where a split should occur
    change_idx = find(change_mask);

    % Add boundaries
    split_points = [0 change_idx size(A, 2)];

    % Group elements (each group is 3 x K)
    groups = arrayfun(@(i) A(:, split_points(i)+1 : split_points(i+1)), ...
        1:numel(split_points)-1, 'UniformOutput', false);

    clusters{i_rec} = groups;

    % ---- Check for valid (non-NaN) groups with length >= 3 ----
    nonNaN_lengths = cellfun(@(g) ...
        ~any(isnan(g(:))) && size(g, 2) > 1, groups);

    if ~any(nonNaN_lengths)
        error('There is no clustering!')  % exclude these sessions later
    end

    % Store indices of good groups
    is_good_group = nonNaN_lengths;
    good_group_indices = arrayfun(@(i) ...
        split_points(i)+1 : split_points(i+1), ...
        find(is_good_group), ...
        'UniformOutput', false);

    good_groups{i_rec} = good_group_indices;
end

%% Get predictions from clusters
Pred = cell(size(AI_comb_train, 1), 1);
for i_rec = 1:size(AI_comb_train, 1)
    Tuning_rec = NaN(4, size(good_groups{i_rec}, 2));
    Pred_rec = NaN(2, size(good_groups{i_rec}, 2));
    for i_group = 1: size(good_groups{i_rec}, 2)
        ch_clst = good_groups{i_rec}{i_group};
        tuning_sum = sum(Z_train_pers(:, :, :, ch_clst, i_rec), 4, "omitmissing");
        tuning_sum(tuning_sum == 0) = NaN;

        R_Left = squeeze(tuning_sum(1, :, :));     % 8 x 20 for this session
        R2_Left = R_Left(1:4, :);          % first half
        R1_Left_flip = R_Left(5:8, :);
        R1_Left = flipud(R1_Left_flip);% second half
        AI_Left = mean((mean(R1_Left,2,'omitnan') - mean(R2_Left,2,'omitnan'))./...
            (abs(mean(R1_Left,2,'omitnan') - mean(R2_Left,2,'omitnan')) + mean([std(R1_Left,[],2,'omitnan'),std(R2_Left,[],2,'omitnan')],2)),'omitnan');

        R_Right = squeeze(tuning_sum(2, :, :));     % 8 x 20 for this session
        R2_Right = R_Right(1:4, :);
        R1_Right_flip = R_Right(5:8, :);
        R1_Right = flipud(R1_Right_flip);% second half
        AI_Right = mean((mean(R1_Right,2,'omitnan') - mean(R2_Right,2,'omitnan'))./...
            (abs(mean(R1_Right,2,'omitnan') - mean(R2_Right,2,'omitnan')) + mean([std(R1_Right,[],2,'omitnan'),std(R2_Right,[],2,'omitnan')],2)),'omitnan');

        Left = mean(squeeze(tuning_sum(1, :, :)), 2, 'omitmissing');
        Right = mean(squeeze(tuning_sum(2, :, :)), 2, 'omitmissing');
        % OD = (max(Left) - max(Right));
        OD = (max(Left) - max(Right)) ./ (max(Left) + max(Right));

        dist = min(abs(ch_clst - 16));

        if OD > 0
            Pred_rec(1, i_group) = AI_Left * abs(OD);
            Pred_rec(2, i_group) = dist;
        else
            Pred_rec(1, i_group) = AI_Right * abs(OD);
            Pred_rec(2, i_group) = dist;
        end

    end
    Pred{i_rec} = Pred_rec;
end
end

%%
function sigma_hat = optimize_AI_weights_subset(data, behav, lambda_w, train_idx)
% data: 8x20x31x56
% behav: 56x1
% train_idx: logical 56x1 or vector of indices to use for training

[~,~,~,N,~] = size(data);
if nargin < 4 || isempty(train_idx)
    train_idx = true(size(behav));
end

sigma0  = 0.1;
A = []; b = [];
Aeq = 1; beq = 1;
lb = 0; ub = [];

opts = optimoptions('fminunc', 'Display','off','Algorithm','quasi-newton');
sigma_hat = fminunc(@(sigma) objfun_AI_subset(sigma, data, behav, lambda_w, train_idx), sigma0, opts);
end

%%
function f = objfun_AI_subset(sigma, data, behav, lambda_w, train_idx)
[~, ~, ~, N, M] = size(data);   % N=31, M=56

% weighted = sum(data .* reshape(w,1,1,[],1), 3, 'omitmissing');  % 8x20xM
% weighted(weighted == 0) = NaN;

Z_train = squeeze(data(1, :, 1:5, :, train_idx));
Z_train_pers = squeeze(data(2:3, :, 1:5, :, train_idx));
Pred = ClusterPrediction(Z_train, Z_train_pers);

% 1) build weights from sigma
w = gaussian_weights(sigma, N);   % 31x1

% w = [0 0 0 0 1 0 0 0 0];
X = NaN(size(Pred, 1), 1);
for i_rec = 1:size(Pred, 1)
    X_rec = 0;
    weight_sum = 0;
    for i_clst = 1:size(Pred{i_rec}, 2)
        weight_sum = weight_sum + w(Pred{i_rec}(2, i_clst) + 16);
    end

    for i_clst = 1:size(Pred{i_rec}, 2)
        weight = w(Pred{i_rec}(2, i_clst) + 16) / weight_sum;
        X_rec = X_rec + Pred{i_rec}(1, i_clst) * weight;
    end
    X(i_rec) = X_rec;

end

beta = X \ behav(train_idx);            % 2 x 1
% disp(beta)
pred = X * beta;
resid = behav(train_idx) - pred;
sse   = sum(resid.^2);

ridge_term = lambda_w * ((1 / sigma).^2);
f = sse + ridge_term;
% fprintf('lambda=%g, sigma=%.10f, f=%g\n', lambda_w, sigma, f);
end

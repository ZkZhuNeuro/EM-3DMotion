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

idx = [];
for i_rec = 1:size(unit_table, 1)
    if strcmp(unit_table.ROI{i_rec}, 'MT') & strcmp(unit_table.Monkey{i_rec}, 'Jim') ...
            & unit_table.p_AI{i_rec}(2) < 0.05 & unit_table.p_AI{i_rec}(3) < 0.05 & unit_table.Z3D_v_Z2D{i_rec} < 0
        idx(end + 1) = i_rec;
    end
end
unit_table = unit_table(idx, :);
NeuroAll = NeuroAll(idx);

%%
% NeuroAll{1}(1, :, :, :) = ones(13, 20, 16);
% NeuroAll{1}(2, :, :, :) = ones(13, 20, 16) * 2;
% NeuroAll{1}(3, :, :, :) = ones(13, 20, 16) * 3;
% NeuroAll{1}(4, :, :, :) = ones(13, 20, 16) * 4;

%%
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

%%
behav_pers = [behav_Dom, behav_NonDom];
Z_comb_aligned = NaN(2, 8, 20, 31, size(Z, 1));
AI_comb_aligned = NaN(size(AI_ref_CombAll, 1), 31);
behav = NaN(size(Z, 1), 1);
for i_rec = 1:size(Z, 1)
    Z_comb_rec = squeeze(Z{i_rec}(2:3, :, :, :)); 
    Z_comb_rec_aligned_short = Z_comb_rec(:, :, :, ChannelMap);
    AI_comb = AI_ref_CombAll(i_rec, :);
    AI_comb_aligned_short = AI_comb(ChannelMap);

    StimCh = unit_table.StimElec(i_rec);
    StimCh_id = find(ChannelMap == StimCh);
    start_id = 17 - StimCh_id; 
    Z_comb_aligned(:, :, :, [start_id:start_id+15], i_rec) = Z_comb_rec_aligned_short;
    AI_comb_aligned(i_rec, [start_id:start_id+15]) = AI_comb_aligned_short;

    Z_StimCh = squeeze(Z_comb_rec(:, :, StimCh));

    behav(i_rec) = unit_table.Delta_bias{i_rec}(1);
end

ch_distribution = sum(~isnan(squeeze(Z_comb_aligned(1, 1, 1, :, :))), 2);

%%
figure(); hold on
for i_rec = 1:5:size(AI_comb_aligned, 1)
    plot([1:31], AI_comb_aligned(i_rec, :), 'LineWidth', 2)
end
plot([1 31], [0 0], 'k')
plot([16 16], [-1 1], 'k--')
%%
cluters = cell(size(AI_comb_aligned, 1), 1);
% Initialize a cell array to store the good groups for each recording
good_groups = cell(size(AI_comb_aligned, 1), 1);
for i_rec = 1:size(AI_comb_aligned, 1)
    A = AI_comb_aligned(i_rec, :);

    % Determine group labels: +1, -1, or 0 for NaN
    labels = sign(A);
    labels(isnan(A)) = 0;

    % Find where the group label changes
    change_idx = find(diff(labels) ~= 0);

    % Add boundaries
    split_points = [0 change_idx length(A)];

    % Group elements in a cell array
    groups = arrayfun(@(i) A(split_points(i)+1 : split_points(i+1)), ...
        1:numel(split_points)-1, 'UniformOutput', false);
    cluters{i_rec} = groups;


    % Check for any non-NaN groups with length >= 3
    nonNaN_lengths = cellfun(@(g) ~any(isnan(g)) & numel(g) > 2, groups);
    has_long_nonNaN_group = any(nonNaN_lengths);
    if has_long_nonNaN_group < 1
        error('There is no clustering!') % Need to figure out how to exclude these sessions later.
    end

    is_good_group = cellfun(@(g) ~any(isnan(g)) && numel(g) > 2, groups);
    good_group_indices = arrayfun(@(i) split_points(i)+1 : split_points(i+1), ...
                              find(is_good_group), ...
                              'UniformOutput', false);
    good_groups{i_rec} = good_group_indices;
end

%%
Tuning = cell(size(AI_comb_aligned, 1), 1);
Pred = cell(size(AI_comb_aligned, 1), 1);
for i_rec = 1:size(AI_comb_aligned, 1)
    Tuning_rec = NaN(4, size(good_groups{i_rec}, 2));
    Pred_rec = NaN(2, size(good_groups{i_rec}, 2));
    for i_group = 1: size(good_groups{i_rec}, 2)
        ch_clst = good_groups{i_rec}{i_group};
        tuning_sum = sum(Z_comb_aligned(:, :, :, ch_clst, i_rec), 4, "omitmissing");
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
        OD = max(Left) - max(Right);

        dist = min(abs(ch_clst - 16));

        
        Tuning_rec(3, i_group) = OD;
        Tuning_rec(4, i_group) = dist;

        if OD > 0
            Pred_rec(1, i_group) = AI_Left * abs(OD);
            Pred_rec(2, i_group) = dist;
            Tuning_rec(1, i_group) = AI_Left;
            Tuning_rec(2, i_group) = AI_Right;
        else
            Pred_rec(1, i_group) = AI_Right * abs(OD);
            Pred_rec(2, i_group) = dist;
            Tuning_rec(1, i_group) = AI_Right;
            Tuning_rec(2, i_group) = AI_Left;
        end

    end
    Tuning{i_rec} = Tuning_rec;
    Pred{i_rec} = Pred_rec;
end
%%
N = 31;   
M = size(Pred, 1); % N=31, M=56
% sigma_hat = logspace(-3, 0, 100);
sigma_hat = 0.01:0.001:1;

AI_clst = NaN(M, length(sigma_hat));
OD_clst = NaN(M, length(sigma_hat));

for i_sigma = 1:length(sigma_hat)



% 1) build weights from sigma
w = gaussian_weights(sigma_hat(i_sigma), N);   % 31x1

% w = [0 0 0 0 1 0 0 0 0];
X = NaN(M, 1);

for i_rec = 1:M
    X_rec = 0;
    AI_rec = 0;
    OD_rec = 0;
    weight_sum = 0;
    for i_clst = 1:size(Pred{i_rec}, 2)
        weight_sum = weight_sum + w(Pred{i_rec}(2, i_clst) + 16);
    end

    for i_clst = 1:size(Pred{i_rec}, 2)
        weight = w(Pred{i_rec}(2, i_clst) + 16) / weight_sum;
        X_rec = X_rec + Pred{i_rec}(1, i_clst) * weight; 
        AI_rec = AI_rec + Tuning{i_rec}(1, i_clst) * weight;
        OD_rec = OD_rec + abs(Tuning{i_rec}(3, i_clst) * weight);
    end
    X(i_rec) = X_rec; 
    AI_clst(i_rec, i_sigma) = AI_rec; 
    OD_clst(i_rec, i_sigma) = OD_rec; 

end

beta = X \ behav_pers(:, 1);            % 2 x 1
pred = X * beta;             % M x 1

%%
Wrong_fit = sum((sign(X) .* sign(behav_pers(:, 1))) < 0);
Wrong_old = sum((sign(AI_ref_Dom) .* sign(behav_pers(:, 1))) < 0);

end
%%
% tbl = table(AI_ref_Dom, OD_ref, behav_pers(:, 1), 'VariableNames', {'AI', 'OD', 'Bias'});
% % tbl = table(AI_clst, OD_clst, behav_pers(:, 1), 'VariableNames', {'AI', 'OD', 'Bias'});
% lm = fitlm(tbl, 'Bias ~ AI + AI:OD')
%%
figure(); hold on
Old = AI_ref_Dom;
scatter(Old, behav_pers(:, 1), 'k');

cmap = colormap(cool(length(sigma_hat)));
for i_sigma = 1:length(sigma_hat)
    scatter(AI_clst(:, i_sigma), behav_pers(:, 1), 'filled', 'SizeData', 50, 'MarkerFaceColor', cmap(i_sigma, :), 'MarkerFaceAlpha', 0.05)

end

axis square
xlim([-1 1])
ylim([-2 2])
plot([-1 1], [0 0], 'k')
plot([0 0], [-2 2], 'k')

currentSpreadSaveResults(outputDir);

%%
function [sigma_hat, w_hat] = optimize_AI_weights(Pred, behav_pers)
% data: 8 x 20 x 31 x 56
% behav: 56 x 1

N = 31;   % N should be 31 here

% --- initial guess ---
sigma0 = 1;          % start from uniform weights

% --- constraints ---
% let's make them nonnegative and sum-to-1 (you can loosen this if you want)
A = [];
b = [];
Aeq = 1;
beq = 1;
lb = 0;
ub = [];

opts = optimoptions('fmincon', ...
    'Display','iter', ...        % show progress
    'Algorithm','sqp');

sigma_hat = fmincon(@(sigma) objfun_AI(sigma, Pred, behav_pers), ...
                sigma0, A, b, [], [], lb, ub, [], opts);
w_hat = gaussian_weights(sigma_hat, N);
end

%%
function f = objfun_AI(sigma, Pred, behav_pers)
% w: N x 1
% data: 8 x 20 x N x M
% behav: M x 1

N = 31;   
M = size(Pred, 1); % N=31, M=56

% 1) build weights from sigma
w = gaussian_weights(sigma, N);   % 31x1

% w = [0 0 0 0 1 0 0 0 0];
X = NaN(M, 1);
for i_rec = 1:M
    X_rec = 0;
    for i_clst = 1:size(Pred{i_rec}, 2)
        weight = w(Pred{i_rec}(2, i_clst) + 16);
        X_rec = X_rec + Pred{i_rec}(1, i_clst) * weight; 
    end
    X(i_rec) = X_rec; 

end

beta = X \ behav_pers(:, 1);            % 2 x 1
pred = X * beta;             % M x 1
resid = behav_pers(:, 1) - pred;
% resid = sum(xor(sign(behav_pers(:, 1)) + 1, sign(pred) + 1));
% 4) objective = SSE of regression
% f = sum((resid_Dom - 1).^2) + sum((resid_NonDom + 1).^2) + lambda * sum(w.^2);
f = sum(resid.^2);
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


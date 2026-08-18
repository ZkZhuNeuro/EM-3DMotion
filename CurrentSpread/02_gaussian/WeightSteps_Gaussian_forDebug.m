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
% NeuroAll{1}(1, :, :, :) = ones(13, 20, 16);
% NeuroAll{1}(2, :, :, :) = ones(13, 20, 16) * 2;
% NeuroAll{1}(3, :, :, :) = ones(13, 20, 16) * 3;
% NeuroAll{1}(4, :, :, :) = ones(13, 20, 16) * 4;

%%
Z = cell(size(NeuroAll));
AI_ref = NaN(size(NeuroAll));
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
    AI_ref(i_rec) = unit_table.AI{i_rec}(1, unit_table.StimElec(i_rec));
end

%%
Z_comb_aligned = NaN(8, 20, 31, size(Z, 1));
behav = NaN(size(Z, 1), 1);
AI_ref_Z = NaN(size(NeuroAll));
for i_rec = 1:size(Z, 1)
    Z_comb_rec = squeeze(Z{i_rec}(1, :, :, :)); 
    Z_comb_rec_aligned_short = Z_comb_rec(:, :, ChannelMap);
    StimCh = unit_table.StimElec(i_rec);
    StimCh_id = find(ChannelMap == StimCh);
    start_id = 17 - StimCh_id; 
    Z_comb_aligned(:, :, [start_id:start_id+15], i_rec) = Z_comb_rec_aligned_short;

    Z_StimCh = squeeze(Z_comb_rec(:, :, StimCh));
    R2 = Z_StimCh(1:4, :); 
    R1 = flipud(Z_StimCh(5:8, :));
    AI_ref_Z(i_rec) = AI_Calculator(R1, R2);

    behav(i_rec) = unit_table.Delta_bias{i_rec}(1);
end

%%
ch_distribution = sum(~isnan(squeeze(Z_comb_aligned(1, 1, :, :))), 2);

%%
trialAmt = 6;
ch_step = 4; 
data_ori = Z_comb_aligned(:, 1:trialAmt, 16 - ch_step:16 + ch_step, :);
best_lambda = 0;
data = data_ori;

%%
[sigma_hat, w_hat] = optimize_AI_weights(data, behav, best_lambda);

%%
weighted = zeros(size(data, 1),size(data, 2), size(data, 4));
for i_rec = 1:M
    data_rec = squeeze(data(:, :, :, i_rec));
    data_rec(isnan(data_rec)) = 0;
    for i_ch = 1:N
        weighted(:, :, i_rec) = weighted(:, :, i_rec) + data_rec(:, :, i_ch) * w(i_ch);
    end

end
weighted(weighted == 0) = NaN;

% 2) compute AI per session
AI = zeros(size(Z));
for m = 1:M
    R = weighted(:,:,m);     % 8 x 20 for this session
    R2 = R(1:4, :);          % first half
    R1_flip = R(5:8, :);    
    R1 = flipud(R1_flip);% second half
    AI(m) = AI_Calculator(R1, R2);
end

currentSpreadSaveResults(outputDir);

%%
function [sigma_hat, w_hat] = optimize_AI_weights(data, behav, lambda)
% data: 8 x 20 x 31 x 56
% behav: 56 x 1

[~, ~, N, ~] = size(data);   % N should be 31 here

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

sigma_hat = fmincon(@(sigma) objfun_AI(sigma, data, behav, lambda), ...
                sigma0, A, b, [], [], lb, ub, [], opts);
w_hat = gaussian_weights(sigma_hat, N);
end

%%
function f = objfun_AI(sigma, data, behav, lambda)
% w: N x 1
% data: 8 x 20 x N x M
% behav: M x 1

[~, ~, N, M] = size(data);   % N=31, M=56

% 1) build weights from sigma
w = gaussian_weights(sigma, N);   % 31x1

% w = [0 0 0 0 1 0 0 0 0];

% weighted = sum( data .* reshape(w, 1,1,[],1), 3, 'omitnan');  % 8 x 20 x M
% weighted = squeeze(weighted);

weighted = zeros(size(data, 1),size(data, 2), size(data, 4));
for i_rec = 1:M
    data_rec = squeeze(data(:, :, :, i_rec));
    data_rec(isnan(data_rec)) = 0;
    for i_ch = 1:N
        weighted(:, :, i_rec) = weighted(:, :, i_rec) + data_rec(:, :, i_ch) * w(i_ch);
    end

end
weighted(weighted == 0) = NaN;

% 2) compute AI per session
AI = zeros(M,1);
for m = 1:M
    R = weighted(:,:,m);     % 8 x 20 for this session
    R2 = R(1:4, :);          % first half
    R1_flip = R(5:8, :);    
    R1 = flipud(R1_flip);% second half
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

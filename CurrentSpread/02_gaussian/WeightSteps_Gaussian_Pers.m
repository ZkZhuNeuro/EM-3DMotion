clear; 
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
AI_ref_Dom = NaN(size(NeuroAll));
AI_ref_NonDom = NaN(size(NeuroAll));
behav_Dom = NaN(size(Z, 1), 1);
behav_NonDom = NaN(size(Z, 1), 1);
OD_ref = NaN(size(Z, 1), 1);
for i_rec = 1:size(NeuroAll, 1)
    Z_rec = NaN(4, 8, 20, 16);
    for i_ch = 1:size(NeuroAll{i_rec}, 4)
        Neuro_Ch = NeuroAll{i_rec}(:, :, :, i_ch);
        Z_ch = (Neuro_Ch - mean(Neuro_Ch, "all", "omitmissing")) ./ std(Neuro_Ch, [], "all", "omitmissing");
        % Z_ch = Neuro_Ch;
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
    behav_Dom(i_rec) = unit_table.Delta_bias{i_rec}(2);
    behav_NonDom(i_rec) = unit_table.Delta_bias{i_rec}(3);
    else
    AI_ref_Dom(i_rec) = unit_table.AI{i_rec}(3, unit_table.StimElec(i_rec));
    AI_ref_NonDom(i_rec) = unit_table.AI{i_rec}(2, unit_table.StimElec(i_rec));
    behav_Dom(i_rec) = unit_table.Delta_bias{i_rec}(3);
    behav_NonDom(i_rec) = unit_table.Delta_bias{i_rec}(2);
    end
    OD_ref(i_rec) = unit_table.OD_max{i_rec};
end

%%
Z_aligned = NaN(2, 8, 20, 31, size(Z, 1));
behav = NaN(size(Z, 1), 1);
for i_rec = 1:size(Z, 1)
    Z_comb_rec = squeeze(Z{i_rec}(2:3, :, :, :)); 
    Z_comb_rec_aligned_short = Z_comb_rec(:, :, :, ChannelMap);
    StimCh = unit_table.StimElec(i_rec);
    StimCh_id = find(ChannelMap == StimCh);
    start_id = 17 - StimCh_id; 
    Z_aligned(:, :, :, [start_id:start_id+15], i_rec) = Z_comb_rec_aligned_short;

    Z_StimCh = squeeze(Z_comb_rec(:, :, StimCh));

    behav(i_rec) = unit_table.Delta_bias{i_rec}(1);
end

ch_distribution = sum(~isnan(squeeze(Z_aligned(1, 1, 1, :, :))), 2);

%%
trialAmt = 6;
ch_step = 6; 
data_ori = Z_aligned(:, :, 1:trialAmt, 16 - ch_step:16 + ch_step, :);
best_lambda = 0;
data = data_ori;

%%
behav_pers = [behav_Dom, behav_NonDom];
[sigma_hat, w_hat] = optimize_AI_weights(data, behav_pers, best_lambda);

%%
weighted = zeros(size(data, 1), size(data, 2),size(data, 3), size(data, 5));
for i_rec = 1:size(behav, 1)
    data_rec = squeeze(data(:, :, :, :, i_rec));
    data_rec(isnan(data_rec)) = 0;
    for i_ch = 1:size(data, 4)
        weighted(:, :, :, i_rec) = weighted(:, :, :, i_rec) + data_rec(:, :, :, i_ch) * w_hat(i_ch);
    end

end
weighted(weighted == 0) = NaN;

% OD
weighted_OD = NaN(size(weighted));
OD_all = NaN(size(behav));
for i_rec = 1:size(behav, 1)
    temp_1 = weighted(1, :, :, i_rec);
    temp_2 = weighted(2, :, :, i_rec);
    Left = mean(weighted(1, :, :, i_rec), 3, 'omitmissing');
    Right = mean(weighted(2, :, :, i_rec), 3, 'omitmissing');
    % OD = (max(Left) - max(Right)) / (max(Left) + max(Right));
    OD = max(Left) - max(Right);
    OD_all(i_rec) = OD;
    if OD > 0 
        weighted_OD(1, :, :, i_rec) = temp_1;
        weighted_OD(2, :, :, i_rec) = temp_2;
    else
        weighted_OD(1, :, :, i_rec) = temp_2;
        weighted_OD(2, :, :, i_rec) = temp_1;
    end
end



% 2) compute AI per session
AI_Dom = zeros(size(behav));
for m = 1:size(behav, 1)
    R = squeeze(weighted_OD(1, :,:,m));     % 8 x 20 for this session
    R2 = R(1:4, :);          % first half
    R1_flip = R(5:8, :);    
    R1 = flipud(R1_flip);% second half
    AI_Dom(m) = AI_Calculator(R1, R2);
end
X_Dom = AI_Dom;
beta_Dom = X_Dom \ behav;            % 2 x 1
pred_Dom = X_Dom * beta_Dom;             % M x 1
resid_Dom = behav - pred_Dom;

AI_NonDom = zeros(size(behav));
for m = 1:size(behav, 1)
    R = squeeze(weighted_OD(2, :,:,m));     % 8 x 20 for this session
    R2 = R(1:4, :);          % first half
    R1_flip = R(5:8, :);    
    R1 = flipud(R1_flip);% second half
    AI_NonDom(m) = AI_Calculator(R1, R2);
end
X_NonDom = AI_NonDom;
beta_NonDom = X_NonDom \ behav;            % 2 x 1
pred_NonDom = X_NonDom * beta_NonDom;             % M x 1
resid_NonDom = behav - pred_NonDom;

%%
figure(); hold on; 
scatter([AI_ref_Dom .* abs(OD_ref); AI_ref_NonDom .* abs(OD_ref)], [behav_pers(:, 1); -behav_pers(:, 2)])
axis square
xlim([-0.3 0.3])
ylim([-2 2])
plot([-1 1], [0 0], 'k')
plot([0 0], [-2 2], 'k')

[r, p] = corr([AI_ref_Dom .* abs(OD_ref); AI_ref_NonDom .* abs(OD_ref)], [behav_pers(:, 1); -behav_pers(:, 2)]);

%%
figure(); scatter([AI_Dom; AI_NonDom], [behav_pers(:, 1); -behav_pers(:, 2)])
hold on; scatter([AI_ref_Dom; AI_ref_NonDom], [behav_pers(:, 1); -behav_pers(:, 2)])
for i_rec = 1:size(behav, 1)
    if xor(AI_Dom(i_rec) > AI_ref_Dom(i_rec), behav_pers(i_rec, 1) > 0)
    plot([AI_Dom(i_rec), AI_ref_Dom(i_rec)], [behav_pers(i_rec, 1), behav_pers(i_rec, 1)], 'Color', 'r')
    else
    plot([AI_Dom(i_rec), AI_ref_Dom(i_rec)], [behav_pers(i_rec, 1), behav_pers(i_rec, 1)], 'Color', 'b')
    end
end
for i_rec = 1:size(behav, 1)
    if xor(AI_NonDom(i_rec) > AI_ref_NonDom(i_rec), behav_pers(i_rec, 1) < 0)
    plot([AI_NonDom(i_rec), AI_ref_NonDom(i_rec)], [-behav_pers(i_rec, 2), -behav_pers(i_rec, 2)], 'Color', 'r')
    else
    plot([AI_NonDom(i_rec), AI_ref_NonDom(i_rec)], [-behav_pers(i_rec, 2), -behav_pers(i_rec, 2)], 'Color', 'b')
    end
end
axis square
xlim([-1 1])
ylim([-2 2])
plot([-1 1], [0 0], 'k')
plot([0 0], [-2 2], 'k')

%%
figure(); 
x_plot = [-1 1];
x = [AI_Dom; AI_NonDom];
y = [behav_pers(:, 1); -behav_pers(:, 2)];
w = abs([OD_all; OD_all]);
[slope, intercept] = type2_reg_weighted_matrix(x, y, w);
hold on;
plot(x_plot, intercept + x_plot*slope,'-','Color',colorsteps(3,:),'LineWidth',2.5);

s = scatter(x, y, 40, ...
            colorsteps(3, :), 'filled', 'MarkerEdgeColor',colorsteps(3, :),'LineWidth',1.5);
s.AlphaData = w;

s.MarkerFaceAlpha = 'flat';

x_plot = [-1 1];
x = [AI_ref_Dom; AI_ref_NonDom];
y = [behav_pers(:, 1); -behav_pers(:, 2)];
w = abs([OD_ref; OD_ref]);
[slope, intercept] = type2_reg_weighted_matrix(x, y, w);
hold on;
plot(x_plot, intercept + x_plot*slope,'-','Color',colorsteps(2,:),'LineWidth',2.5);

s = scatter(x, y, 40, ...
            colorsteps(2, :), 'filled', 'MarkerEdgeColor',colorsteps(2, :),'LineWidth',1.5);
s.AlphaData = w;

s.MarkerFaceAlpha = 'flat';
axis square
xlim([-1 1])
ylim([-2 2])
plot([-1 1], [0 0], 'k')
plot([0 0], [-2 2], 'k')

%%
figure(); scatter([AI_Dom .* abs(OD_all); AI_NonDom .* abs(OD_all)], [behav_pers(:, 1); -behav_pers(:, 2)])
hold on; scatter([AI_ref_Dom.* abs(OD_ref); AI_ref_NonDom .* abs(OD_ref)], [behav_pers(:, 1); -behav_pers(:, 2)])
for i_rec = 1:size(behav, 1)
    if xor(AI_Dom(i_rec).* abs(OD_all(i_rec)) > AI_ref_Dom(i_rec).* abs(OD_ref(i_rec)), behav_pers(i_rec, 1) > 0)
    plot([AI_Dom(i_rec).* abs(OD_all(i_rec)), AI_ref_Dom(i_rec).* abs(OD_ref(i_rec))], [behav_pers(i_rec, 1), behav_pers(i_rec, 1)], 'Color', 'r')
    else
    plot([AI_Dom(i_rec).* abs(OD_all(i_rec)), AI_ref_Dom(i_rec).* abs(OD_ref(i_rec))], [behav_pers(i_rec, 1), behav_pers(i_rec, 1)], 'Color', 'b')
    end
end
for i_rec = 1:size(behav, 1)
    if xor(AI_NonDom(i_rec).* abs(OD_all(i_rec)) > AI_ref_NonDom(i_rec).* abs(OD_ref(i_rec)), behav_pers(i_rec, 1) < 0)
    plot([AI_NonDom(i_rec).* abs(OD_all(i_rec)), AI_ref_NonDom(i_rec).* abs(OD_ref(i_rec))], [-behav_pers(i_rec, 2), -behav_pers(i_rec, 2)], 'Color', 'r')
    else
    plot([AI_NonDom(i_rec).* abs(OD_all(i_rec)), AI_ref_NonDom(i_rec).* abs(OD_ref(i_rec))], [-behav_pers(i_rec, 2), -behav_pers(i_rec, 2)], 'Color', 'b')
    end
end
axis square
xlim([-1 1])
ylim([-2 2])
plot([-1 1], [0 0], 'k')
plot([0 0], [-2 2], 'k')

%%
[r, p] = corr([AI_Dom .* abs(OD_all); AI_NonDom .* abs(OD_all)], [behav_pers(:, 1); -behav_pers(:, 2)])
[r_ref, p_ref] = corr([AI_ref_Dom.* abs(OD_ref); AI_ref_NonDom .* abs(OD_ref)], [behav_pers(:, 1); -behav_pers(:, 2)])

%%
behav = [behav_pers(:, 1); -behav_pers(:, 2); behav_pers(:, 1); -behav_pers(:, 2)];
X_test = [AI_Dom .* abs(OD_all); AI_NonDom .* abs(OD_all)];
X_ref = [AI_ref_Dom.* abs(OD_ref); AI_ref_NonDom .* abs(OD_ref)];
testIdx = [ones(size(X_test)); zeros(size(X_ref))];
tbl = array2table([behav, [X_test; X_ref], testIdx], 'VariableNames', {'behav', 'AIOD', 'testIdx'});
lm = fitlm(tbl, 'behav ~ AIOD * testIdx');
anova(lm)

currentSpreadSaveResults(outputDir);

%%
function [sigma_hat, w_hat] = optimize_AI_weights(data, behav_pers, lambda)
% data: 8 x 20 x 31 x 56
% behav: 56 x 1

[~, ~, ~, N, ~] = size(data);   % N should be 31 here

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

sigma_hat = fmincon(@(sigma) objfun_AI(sigma, data, behav_pers, lambda), ...
                sigma0, A, b, [], [], lb, ub, [], opts);
w_hat = gaussian_weights(sigma_hat, N);
end

%%
function f = objfun_AI(sigma, data, behav_pers, lambda)
% w: N x 1
% data: 8 x 20 x N x M
% behav: M x 1

[~, ~, ~, N, M] = size(data);   % N=31, M=56

% 1) build weights from sigma
w = gaussian_weights(sigma, N);   % 31x1

% w = [0 0 0 0 1 0 0 0 0];

% weighted = sum( data .* reshape(w, 1,1,[],1), 3, 'omitnan');  % 8 x 20 x M
% weighted = squeeze(weighted);

weighted = zeros(size(data, 1), size(data, 2),size(data, 3), size(data, 5));
for i_rec = 1:M
    data_rec = squeeze(data(:, :, :, :, i_rec));
    data_rec(isnan(data_rec)) = 0;
    for i_ch = 1:N
        weighted(:, :, :, i_rec) = weighted(:, :, :, i_rec) + data_rec(:, :, :, i_ch) * w(i_ch);
    end

end
weighted(weighted == 0) = NaN;

% OD
weighted_OD = NaN(size(weighted));
OD_all = NaN(size(behav_pers, 1), 1);
behav_pers_temp = behav_pers; 
for i_rec = 1:M
    temp_1 = weighted(1, :, :, i_rec);
    temp_2 = weighted(2, :, :, i_rec);
    Left = mean(weighted(1, :, :, i_rec), 3, 'omitmissing');
    Right = mean(weighted(2, :, :, i_rec), 3, 'omitmissing');
    % OD = (max(Left) - max(Right)) / (max(Left) + max(Right));
    OD = (max(Left) - max(Right));
    if OD > 0 
        weighted_OD(1, :, :, i_rec) = temp_1;
        weighted_OD(2, :, :, i_rec) = temp_2;
        behav_pers(i_rec, 1) = behav_pers_temp(i_rec, 1);
        behav_pers(i_rec, 2) = behav_pers_temp(i_rec, 2);
    else
        weighted_OD(1, :, :, i_rec) = temp_2;
        weighted_OD(2, :, :, i_rec) = temp_1;
        behav_pers(i_rec, 1) = behav_pers_temp(i_rec, 2);
        behav_pers(i_rec, 2) = behav_pers_temp(i_rec, 1);
    end
    OD_all(i_rec) = OD; 
end



% 2) compute AI per session
AI_Dom = zeros(M,1);
for m = 1:M
    R = squeeze(weighted_OD(1, :,:,m));     % 8 x 20 for this session
    R2 = R(1:4, :);          % first half
    R1_flip = R(5:8, :);    
    R1 = flipud(R1_flip);% second half
    AI_Dom(m) = AI_Calculator(R1, R2);
end
X_Dom = AI_Dom .* abs(OD_all);
beta_Dom = X_Dom \ behav_pers(:, 1);            % 2 x 1
pred_Dom = X_Dom * beta_Dom;             % M x 1
% resid_Dom = sign(behav_pers(:, 1) .* AI_Dom);
resid_Dom = behav_pers(:, 1) - pred_Dom;

AI_NonDom = zeros(M,1);
for m = 1:M
    R = squeeze(weighted_OD(2, :,:,m));     % 8 x 20 for this session
    R2 = R(1:4, :);          % first half
    R1_flip = R(5:8, :);    
    R1 = flipud(R1_flip);% second half
    AI_NonDom(m) = AI_Calculator(R1, R2);
end
X_NonDom = AI_NonDom .* abs(OD_all);
beta_NonDom = X_NonDom \ behav_pers(:, 2);            % 2 x 1
pred_NonDom = X_NonDom * beta_NonDom;             % M x 1
% resid_NonDom = sign(behav_pers(:, 2) .* AI_NonDom);
resid_NonDom = behav_pers(:, 2) - pred_NonDom;

% 4) objective = SSE of regression
% f = sum((resid_Dom - 1).^2) + sum((resid_NonDom + 1).^2) + lambda * sum(w.^2);
f = sum(resid_Dom.^2) + sum(resid_NonDom.^2) + lambda * sum(w.^2);
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

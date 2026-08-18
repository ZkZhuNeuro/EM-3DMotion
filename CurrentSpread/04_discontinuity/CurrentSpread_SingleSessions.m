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
sigma = 0.1:0.1:10;
AIOD = NaN(size(sigma, 2), size(Z_aligned, 5));
for i_rec = 1:size(Z_aligned, 5)
    Z_rec = squeeze(Z_aligned(:, :, :, :, i_rec));
    AIOD_rec = NaN(size(sigma));
    for i_sigma = 1:length(sigma)
        weights = gaussian_weights(sigma(i_sigma), 31);
        weighted = zeros(size(Z_rec, 1), size(Z_rec, 2), size(Z_rec, 3));
            Z_rec(isnan(Z_rec)) = 0;
            for i_ch = 1:size(Z_rec, 4)
                weighted= weighted + squeeze(Z_rec(:, :, :, i_ch)) * weights(i_ch);
            end

        weighted(weighted == 0) = NaN;

        temp_1 = squeeze(weighted(1, :, :));
        temp_2 = squeeze(weighted(2, :, :));
        Left = mean(weighted(1, :, :), 3, 'omitmissing');
        Right = mean(weighted(2, :, :), 3, 'omitmissing');

        % OD = max(Left) - max(Right);
        OD = (max(Left) - max(Right)) ./ (max(Left) + max(Right));
        if OD > 0
            Dom = temp_1;
            NonDom = temp_2;
        else
            Dom = temp_2;
            NonDom = temp_1;
        end

        R2 = Dom(1:4, :); 
        R1_flip = Dom(5:8, :);    
        R1 = flipud(R1_flip);
        AI = AI_Calculator(R1, R2);
        AI_Dom_rec(i_sigma) = AI;
        AIOD_rec(i_sigma) = AI .* abs(OD);
    end
    AIOD(:, i_rec) = AIOD_rec;
    AI_Dom(:, i_rec) = AI_Dom_rec;
    figure(); hold on
    plot(sigma, AIOD_rec, 'LineWidth', 2)
    plot(sigma, behav_Dom(i_rec)/2.8 * ones(size(sigma)), 'k--')
    plot(sigma, zeros(size(sigma)), 'k')
    xlabel('Sigma')
    ylabel('AIOD')
    lim = max([abs(max(AIOD_rec, [], 'all')*1.1), abs(min(AIOD_rec, [], 'all')*1.1), abs(behav_Dom(i_rec)/2.8*1.1)]);
    ylim([-lim lim])
end

%%
cmap = colormap(cool(length(sigma)));
figure(); hold on
for i_sigma = 1:length(sigma)
    scatter(AI_Dom(i_sigma, :), behav_Dom, 'filled', 'SizeData', 50, 'MarkerFaceColor', cmap(i_sigma, :), 'MarkerFaceAlpha', 0.1)
    plot([-1 1], [0 0], 'k')
    plot([0 0], [-2 2], 'k')
    ylim([-2 2])
    xlim([-1 1])
    axis square
end

figure(); hold on
for i_sigma = 1:length(sigma)
    scatter(AIOD(i_sigma, :), behav_Dom, 'filled', 'SizeData', 50, 'MarkerFaceColor', cmap(i_sigma, :), 'MarkerFaceAlpha', 0.1)
    plot([-1 1], [0 0], 'k')
    plot([0 0], [-2 2], 'k')
    ylim([-2 2])
    xlim([-0.3 0.3])
    axis square
end



gaussian_weights(20, 31)

currentSpreadSaveResults(outputDir);

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

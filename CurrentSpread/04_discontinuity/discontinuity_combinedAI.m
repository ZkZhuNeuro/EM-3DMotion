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
AI_ref_all = NaN(size(NeuroAll, 1), 4, 16);
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

    AI_ref_all(i_rec, 1, :) = unit_table.AI{i_rec}(1, :);
    AI_ref_all(i_rec, 2, :) = unit_table.AI{i_rec}(2, :);
    AI_ref_all(i_rec, 3, :) = unit_table.AI{i_rec}(3, :);
    AI_ref_all(i_rec, 4, :) = unit_table.AI{i_rec}(4, :);
end

%%
behav_pers = [behav_Dom, behav_NonDom];
Z_comb_aligned = NaN(2, 8, 20, 31, size(Z, 1));
AI_comb_aligned = NaN(size(AI_ref_CombAll, 1), 31);
AI_aligned = NaN(size(AI_ref_CombAll, 1), 4, 31);
behav = NaN(size(Z, 1), 1);
for i_rec = 1:size(Z, 1)
    Z_comb_rec = squeeze(Z{i_rec}(2:3, :, :, :));
    Z_comb_rec_aligned_short = Z_comb_rec(:, :, :, ChannelMap);
    AI_comb = AI_ref_CombAll(i_rec, :);
    AI_comb_aligned_short = AI_comb(ChannelMap);

    AI_ref_all(i_rec, :, :) = AI_ref_all(i_rec, :, ChannelMap);

    StimCh = unit_table.StimElec(i_rec);
    StimCh_id = find(ChannelMap == StimCh);
    start_id = 17 - StimCh_id;
    Z_comb_aligned(:, :, :, [start_id:start_id+15], i_rec) = Z_comb_rec_aligned_short;
    AI_comb_aligned(i_rec, [start_id:start_id+15]) = AI_comb_aligned_short;
    AI_aligned(i_rec, :, [start_id:start_id+15]) = AI_ref_all(i_rec, :, :);

    Z_StimCh = squeeze(Z_comb_rec(:, :, StimCh));

    behav(i_rec) = unit_table.Delta_bias{i_rec}(1);
end

ch_distribution = sum(~isnan(squeeze(Z_comb_aligned(1, 1, 1, :, :))), 2);

%%
% figure(); hold on
% for i_rec = 1:5:size(AI_aligned, 1)
%     plot([1:31], squeeze(AI_aligned(i_rec, 1, :)), 'LineWidth', 2)
% end
% plot([1 31], [0 0], 'k')
% plot([16 16], [-1 1], 'k--')

%%
slope_comb = NaN(size(AI_comb_aligned, 1), 1);
for i_rec = 1:size(AI_comb_aligned, 1)
    % step_sin = 2;
    % y = sin(AI_comb_aligned(i_rec, 16-step_sin:16+step_sin)' * pi/2);   % 7-element array
    % % y = AI_comb_aligned(i_rec, 16-step_sin:16+step_sin)';   % 7-element array
    % t = (-step_sin:step_sin)'; % time points: 0,1,2,...6 (7 samples)
    % 
    % t = t(~isnan(y));
    % y = y(~isnan(y));
    % 
    % % Sinusoid model definition:
    % sinModel = @(b, t) b(1)*sin(2*pi*b(2)*t + b(3)) + b(4);
    % % b(1)=Amplitude, b(2)=Frequency, b(3)=Phase, b(4)=Offset
    % 
    % % Initial guess for parameters:
    % b0 = [1, 0.1, 0, mean(y)]; % reasonable starting guesses
    % 
    % lb = [0,     0,    -2*pi,  -Inf];   % A ≥0, freq ≥0, phase unrestricted, offset unrestricted
    % ub = [Inf, 0.25,    2*pi,    Inf];   % freq ≤ 0.5 cycles/sample
    % 
    % 
    % % Fit the model using least-squares
    % opts = optimoptions('lsqcurvefit','Display','off');
    % bFit = lsqcurvefit(sinModel, b0, t, y, lb, ub, opts);
    % 
    % % Generate model fit
    % t_sin = min(t):0.1:max(t); 
    % yFit = sinModel(bFit, t_sin);
    % 
    % % Display fitted parameters
    % A = bFit(1);
    % freq = bFit(2);
    % phase = bFit(3);
    % offset = bFit(4);
    % 
    % slope_comb(i_rec) = abs(2 * pi * freq * A * cos(phase));

    %%
    step_sin = 3;
    y4 = squeeze(AI_aligned(i_rec, :, 16-step_sin:16+step_sin));
    figure(); hold on
    for i_cue = 1:4
    y = y4(i_cue, :);
    % y = AI_comb_aligned(i_rec, 16-step_sin:16+step_sin)';   % 7-element array
    t = (-step_sin:step_sin)'; % time points: 0,1,2,...6 (7 samples)

    t = t(~isnan(y));
    y = y(~isnan(y));

    % Build cubic spline piecewise polynomial model
    pp = spline(t, y);

    % Where do you want the derivative?
    x0 = 0;   % <-- specify your evaluation point

    % Evaluate derivative spline at x0
    ppd = fnder(pp, 1);    % first derivative
    dy_dx = ppval(ppd, x0);
    slope_all(i_rec, i_cue) = abs(dy_dx);

    t_sin = min(t):0.1:max(t); 
    yFit = ppval(pp, t_sin);

    fprintf("Derivative at x = %.3f is %.4f\n", x0, dy_dx);
    %% Plot result

    plot(t, y, '--', 'LineWidth', 1.5, 'Color', colorsteps(i_cue, :))
    plot(t_sin, yFit, '-', 'LineWidth', 1.5, 'Color', colorsteps(i_cue, :))
    % legend('Data','Sinusoid Fit')
    xlabel('Sample'); ylabel('Amplitude')
    title('7-point Sinusoid Fit')
    grid off
    plot([min(t) max(t)], [0 0], 'k')
    plot([0 0], [-1 1], 'k')
    ylim([-1 1])
    title(['slope:', num2str(mean(slope_all(i_rec, :))), ', Bias:', num2str(behav_Dom(i_rec))])
    end
end

%%
unit_table.discontinue = slope_all;

currentSpreadSaveResults(outputDir);

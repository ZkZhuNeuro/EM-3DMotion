clear;
load('P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\BehaviorFitting\UnitTable_Cap2.mat')

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

%%
colorsteps = [0 0 0;...
    0 0 255;...
    5 150 5;...
    234 0 233]/255;

outDir = fullfile('P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\BehaviorFitting\CompareFitting_Cap2');
if ~exist(outDir, 'dir'); mkdir(outDir); end

% ---- loop over recordings ----
% for i_rec = 1
for i_rec = 1:size(unit_table, 1)

    % Create a wide figure suitable for 2 subplots
    fig = figure('Color','w', ...
        'Units','pixels', ...
        'Position',[100 100 1200 520]);   % width x height tuned for 1x2

    % Left: non-stim, Right: stim
    ax1 = subplot(1,2,1); hold(ax1,'on');
    ax2 = subplot(1,2,2); hold(ax2,'on');

    for i_cue = 1:4
        coh = Behav_N(:, 1);

        out = unit_table.Behav_mdl_full_deltaPSEcap2{i_rec}{i_cue};
        b = out.b;

        b0 = b(1);
        b1 = b(2);
        b2 = b(3);
        b3 = b(4);

        % ---- Non-stim ----
        DataN = Data_N{i_rec}(i_cue).data;
        fitPlotPsych_fixedAsym(DataN, colorsteps(i_cue,:), 'Axes', ax1);
        plotPsych_fromLogit(b0, b1, coh, colorsteps(i_cue,:), 'Axes', ax1);

        % ---- Stim ----
        DataS = Data_S{i_rec}(i_cue).data;
        fitPlotPsych_fixedAsym(DataS, colorsteps(i_cue,:), 'Axes', ax2);
        plotPsych_fromLogit(b0 + b2, b1 + b3, coh, colorsteps(i_cue,:), 'Axes', ax2);
    end

    % ---- make both panels consistent & nice ----
    title(ax1, sprintf('Rec %d: Non-stim', i_rec), 'FontWeight','normal');
    title(ax2, sprintf('Rec %d: Stim', i_rec), 'FontWeight','normal');
    set([ax1 ax2], 'FontSize', 16, 'TickDir','out', 'Box','off');
    ylim(ax1, [0 1]); ylim(ax2, [0 1]);
    xlim(ax1, [-1 1]); xlim(ax2, [-1 1]);

    % Optional: same y ticks
    yticks(ax1, 0:0.2:1); yticks(ax2, 0:0.2:1);

    % ---- save PNG ----
    fname = fullfile(outDir, sprintf('rec_%03d_psych.png', i_rec));
    exportgraphics(fig, fname, 'Resolution', 300);  % crisp text/lines

    close(fig);
end
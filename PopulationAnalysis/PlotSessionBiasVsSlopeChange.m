function [fig, session_change_table] = PlotSessionBiasVsSlopeChange(data_file, output_file)
% Plot the session-average bias change against combined-cue slope change.
%
% Each cue is included only when its stimulation and non-stimulation GOF
% flags are both true. Changes follow the existing table convention:
% non-stimulation minus stimulation.
%
% X = abs(mean(Behav_bias_N - Behav_bias_S)) across valid cues.
% Y = (1 ./ sigma_nonStim) - (1 ./ sigma_Stim) for the combined cue.

if nargin < 1 || isempty(data_file)
    data_file = '';
end
if nargin < 2
    output_file = '';
end

[unit_table_gof, data_file, workbook_audit] = ...
    LoadLatestUnitTableGof(data_file);

required_variables = { ...
    'Date', 'Monkey', 'ROI', ...
    'Behav_bias_N', 'Behav_bias_S', ...
    'Behav_goodfit_N', 'Behav_goodfit_S', ...
    'sigma_nonStim', 'sigma_Stim'};
missing_variables = setdiff(required_variables, unit_table_gof.Properties.VariableNames);
if ~isempty(missing_variables)
    error('unit_table_gof is missing: %s.', strjoin(missing_variables, ', '));
end

[bias_change, ~, ~, valid_bias_cue] = ...
    CalculateSigmoidFitBiases(unit_table_gof, 4);
goodfit_nonstim = stack_cue_values(unit_table_gof.Behav_goodfit_N, 4) > 0;
goodfit_stim = stack_cue_values(unit_table_gof.Behav_goodfit_S, 4) > 0;
sigma_nonstim = stack_cue_values(unit_table_gof.sigma_nonStim, 4);
sigma_stim = stack_cue_values(unit_table_gof.sigma_Stim, 4);

slope_change = (1 ./ sigma_nonstim) - (1 ./ sigma_stim);

combined_cue = 1;
valid_combined_slope = goodfit_nonstim(:, combined_cue) & ...
    goodfit_stim(:, combined_cue) & ...
    isfinite(slope_change(:, combined_cue)) & ...
    sigma_nonstim(:, combined_cue) > 0 & sigma_stim(:, combined_cue) > 0;
combined_slope_change = slope_change(:, combined_cue);
combined_slope_change(~valid_combined_slope) = nan;

mean_signed_bias_change = mean(bias_change, 2, 'omitnan');
abs_mean_bias_change = abs(mean_signed_bias_change);
mean_abs_bias_change = mean(abs(bias_change), 2, 'omitnan');
max_abs_bias_change = max(abs(bias_change), [], 2, 'omitnan');
n_valid_bias_cues = sum(valid_bias_cue, 2);

session_change_table = table( ...
    unit_table_gof.Date, ...
    string(unit_table_gof.Monkey), ...
    string(unit_table_gof.ROI), ...
    abs_mean_bias_change, ...
    mean_signed_bias_change, ...
    mean_abs_bias_change, ...
    max_abs_bias_change, ...
    combined_slope_change, ...
    n_valid_bias_cues, ...
    repmat(string(data_file), height(unit_table_gof), 1), ...
    unit_table_gof.RecordingWorkbookPath, ...
    unit_table_gof.RecordingWorkbookRow, ...
    'VariableNames', { ...
    'Date', 'Monkey', 'ROI', ...
    'AbsMeanBiasChange', 'MeanSignedBiasChange', 'MeanAbsBiasChange', ...
    'MaxAbsBiasChange', 'CombinedSlopeChange', 'NValidBiasCues', ...
    'UnitTableGofFile', 'RecordingWorkbookPath', 'RecordingWorkbookRow'});

valid_session = n_valid_bias_cues > 0 & ...
    isfinite(abs_mean_bias_change) & isfinite(combined_slope_change);
if ~any(valid_session)
    error('No sessions have a valid bias and slope change after GOF filtering.');
end

x = abs_mean_bias_change(valid_session);
y = combined_slope_change(valid_session);

fig = figure('Color', 'w', 'Name', 'Session bias vs slope change');
fig.UserData = struct('UnitTableGofFile', data_file, ...
    'WorkbookAudit', workbook_audit);
ax = axes(fig);
hold(ax, 'on');
yline(ax, 0, '--', 'Color', [0.45 0.45 0.45], 'LineWidth', 1);

points = scatter(ax, x, y, 48, 'filled', ...
    'MarkerFaceColor', [0.12 0.47 0.71], ...
    'MarkerEdgeColor', [0.05 0.20 0.32], ...
    'MarkerFaceAlpha', 0.72, ...
    'LineWidth', 0.6);

xlabel(ax, 'Absolute mean bias change across cues, |mean(non-stim - stim)|');
ylabel(ax, 'Combined-cue slope change, non-stim - stim (1/\sigma)');
title(ax, sprintf('Session-level behavior changes (n = %d)', nnz(valid_session)));
grid(ax, 'on');
box(ax, 'on');
set(ax, 'FontSize', 11, 'LineWidth', 1, 'Layer', 'top');
xlim(ax, [0, max(x) * 1.05]);

date_labels = string(unit_table_gof.Date(valid_session), 'yyyy-MM-dd');
monkey_labels = string(unit_table_gof.Monkey(valid_session));
roi_labels = string(unit_table_gof.ROI(valid_session));
points.DataTipTemplate.DataTipRows(1).Label = '|Mean bias change|';
points.DataTipTemplate.DataTipRows(2).Label = 'Combined slope change';
points.DataTipTemplate.DataTipRows(end + 1) = dataTipTextRow('Date', date_labels);
points.DataTipTemplate.DataTipRows(end + 1) = dataTipTextRow('Monkey', monkey_labels);
points.DataTipTemplate.DataTipRows(end + 1) = dataTipTextRow('ROI', roi_labels);
points.DataTipTemplate.DataTipRows(end + 1) = ...
    dataTipTextRow('Valid bias cues', n_valid_bias_cues(valid_session));

if ~isempty(output_file)
    exportgraphics(fig, output_file, 'Resolution', 300);
end

end


function values = stack_cue_values(cell_column, n_cues)
row_count = numel(cell_column);
values = nan(row_count, n_cues);

for row_idx = 1:row_count
    row_values = cell_column{row_idx};
    if isempty(row_values)
        continue
    end

    row_values = double(row_values(:).');
    copy_count = min(numel(row_values), n_cues);
    values(row_idx, 1:copy_count) = row_values(1:copy_count);
end
end

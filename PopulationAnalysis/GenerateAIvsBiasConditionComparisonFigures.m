function [output_files, model_summary] = ...
    GenerateAIvsBiasConditionComparisonFigures()
%GENERATEAIVSBIASCONDITIONCOMPARISONFIGURES Plot AI versus delta bias.
%
% Creates matched overlaid and condition-separated scatter plots for MT/FST
% 2D/3D neurons. The cohort, cue colors, monkey markers, axes, and OD alpha
% encoding match RunPopulationAnalysis_ODweighted. Within each cue condition,
% the requested model is retained in the exported summary:
%
%   Bias ~ OD * AI
%
% The displayed line uses the project's OD-weighted type-II regression
% convention, constrained to pass through the origin:
%
%   Bias = slope * AI
%
% Outputs are written beneath:
%   C:\EM\PopulationAnalysis\output\AIvsBias_ODxAI_ConditionComparison

% The function uses the current stimulation-channel population table:
%   C:\EM\StimChannelAnalysis\unit_table_gof.mat

% See also RunPopulationAnalysis_ODweighted, FITLM.


population_table = 'C:\EM\StimChannelAnalysis\unit_table_gof.mat';
validate_population_table(population_table);

script_folder = fileparts(mfilename('fullpath'));
population_script = fullfile(script_folder, ...
    'RunPopulationAnalysis_ODweighted.m');
output_folder = fullfile('C:\EM', 'PopulationAnalysis', 'output', ...
    'AIvsBias_ODxAI_ConditionComparison');
if ~isfolder(output_folder)
    mkdir(output_folder);
end

areas = {'MT', 'FST'};
unit_types = {'2D', '3D'};
condition_names = {'Dominant', 'Combined', 'Stereo', 'Non-dominant'};
condition_colors = [254 191 15; ...
    0 0 0; ...
    234 0 233; ...
    110 205 221] ./ 255;

output_files = strings(numel(areas) * numel(unit_types) * 4 + 2, 1);
output_index = 0;
model_summary = table();

for area_index = 1:numel(areas)
    selected_area = areas{area_index};
    population_results = run_population_analysis( ...
        population_script, population_table, selected_area);
    close_population_figures(population_results)

    for type_index = 1:numel(unit_types)
        unit_type = unit_types{type_index};
        type_rows = strcmp(string(population_results.bias_table.UnitType), ...
            unit_type);
        plot_table = population_results.bias_table(type_rows, :);
        [line_slopes, mean_od, this_summary] = fit_condition_models( ...
            plot_table, selected_area, unit_type, condition_names);
        model_summary = [model_summary; this_summary]; %#ok<AGROW>

        overlaid_figure = plot_overlaid_conditions( ...
            plot_table, line_slopes, selected_area, unit_type, ...
            condition_names, condition_colors);
        separated_figure = plot_separated_conditions( ...
            plot_table, line_slopes, mean_od, selected_area, unit_type, ...
            condition_names, condition_colors);

        file_stem = sprintf('AI_vs_DeltaBias_ODxAI_%s_%s', ...
            selected_area, unit_type);
        [output_files, output_index] = export_figure_pair( ...
            overlaid_figure, output_folder, ...
            sprintf('%s_Overlaid', file_stem), ...
            output_files, output_index);
        [output_files, output_index] = export_figure_pair( ...
            separated_figure, output_folder, ...
            sprintf('%s_SeparatedByCondition', file_stem), ...
            output_files, output_index);

        close(overlaid_figure)
        close(separated_figure)
    end
end

summary_file = fullfile(output_folder, ...
    'AI_vs_DeltaBias_ODxAI_ModelSummary.csv');
writetable(model_summary, summary_file)
output_index = output_index + 1;
output_files(output_index) = summary_file;

provenance_file = fullfile(output_folder, ...
    'AI_vs_DeltaBias_ODxAI_Provenance.mat');
save(provenance_file, 'model_summary', 'population_table', ...
    'condition_names', 'condition_colors')
output_index = output_index + 1;
output_files(output_index) = provenance_file;
output_files = output_files(1:output_index);

fprintf('Population table: %s\n', population_table)
fprintf('Created %d files in %s\n', numel(output_files), output_folder)
disp(output_files)
end


function validate_population_table(population_table)
if ~isfile(population_table)
    error('AIvsBias:MissingPopulationTable', ...
        'Population table not found: %s', population_table);
end

variables = string({whos('-file', population_table).name});
if ~ismember("unit_table_gof", variables)
    error('AIvsBias:MissingUnitTable', ...
        'The file does not contain unit_table_gof: %s', population_table);
end
end


function results = run_population_analysis( ...
    population_script, data_file, selected_area) %#ok<STOUT,INUSD>
area = selected_area; %#ok<NASGU>
monkey = 'Both'; %#ok<NASGU>
tuning_source = 'Quick'; %#ok<NASGU>
close_existing_figures = false; %#ok<NASGU>
population_analysis_use_supplied_settings = true; %#ok<NASGU>
run(population_script)
end


function close_population_figures(results)
figure_fields = {'fig_2d', 'fig_3d'};
for field_index = 1:numel(figure_fields)
    field_name = figure_fields{field_index};
    if isfield(results, field_name) && isgraphics(results.(field_name))
        close(results.(field_name))
    end
end
end


function [line_slopes, mean_od, summary_table] = fit_condition_models( ...
    plot_table, area, unit_type, condition_names)
condition_count = numel(condition_names);
line_slopes = nan(condition_count, 1);
mean_od = nan(condition_count, 1);
summary_rows = repmat(empty_summary_row(), condition_count, 1);

for condition_index = 1:condition_count
    condition_table = plot_table( ...
        plot_table.Condition == condition_index, :);
    valid_rows = isfinite(condition_table.AI) & ...
        isfinite(condition_table.OD) & ...
        isfinite(condition_table.Bias);
    condition_table = condition_table(valid_rows, :);

    row = empty_summary_row();
    row.Area = string(area);
    row.UnitType = string(unit_type);
    row.Condition = string(condition_names{condition_index});
    row.NPoints = height(condition_table);
    row.NUnits = numel(unique(condition_table.UnitIndex));
    if ~isempty(condition_table)
        row.MeanOD = mean(condition_table.OD);
        mean_od(condition_index) = row.MeanOD;
    end

    [line_slopes(condition_index), type2_point_count] = ...
        get_origin_constrained_type2_slope(condition_table.AI, ...
        condition_table.Bias, condition_table.OD);
    row.Type2NPoints = type2_point_count;
    row.Type2SlopeThroughOrigin = line_slopes(condition_index);
    if isfinite(line_slopes(condition_index))
        row.Type2Intercept = 0;
        row.Type2Status = "Success";
    else
        row.Type2Status = "Insufficient data";
    end

    if height(condition_table) < 4 || ...
            numel(unique(condition_table.AI)) < 2 || ...
            numel(unique(condition_table.OD)) < 2
        row.ModelStatus = "Insufficient data";
        summary_rows(condition_index) = row;
        continue
    end

    try
        model = fitlm(condition_table, 'Bias ~ OD * AI');
        row.ModelStatus = "Success";
        row.R2 = model.Rsquared.Ordinary;
        row.AdjustedR2 = model.Rsquared.Adjusted;
        row.RMSE = model.RMSE;
        [row.Intercept, row.P_Intercept] = ...
            get_coefficient(model, {'(Intercept)'});
        [row.BetaOD, row.P_OD] = get_coefficient(model, {'OD'});
        [row.BetaAI, row.P_AI] = get_coefficient(model, {'AI'});
        [row.BetaODxAI, row.P_ODxAI] = ...
            get_coefficient(model, {'OD:AI', 'AI:OD'});
        row.ModelPredictionInterceptAtMeanOD = row.Intercept + ...
            row.BetaOD * row.MeanOD;
        row.ModelPredictionSlopeAtMeanOD = row.BetaAI + ...
            row.BetaODxAI * row.MeanOD;
    catch model_error
        row.ModelStatus = "Fit failed: " + string(model_error.message);
    end
    summary_rows(condition_index) = row;
end

summary_table = struct2table(summary_rows);
end


function row = empty_summary_row()
row = struct( ...
    'Area', "", ...
    'UnitType', "", ...
    'Condition', "", ...
    'Formula', "Bias ~ OD * AI", ...
    'NPoints', 0, ...
    'NUnits', 0, ...
    'MeanOD', nan, ...
    'Type2Method', "OD-weighted least squares through origin", ...
    'Type2NPoints', 0, ...
    'Type2SlopeThroughOrigin', nan, ...
    'Type2Intercept', nan, ...
    'Type2Status', "Not fit", ...
    'Intercept', nan, ...
    'BetaOD', nan, ...
    'BetaAI', nan, ...
    'BetaODxAI', nan, ...
    'P_Intercept', nan, ...
    'P_OD', nan, ...
    'P_AI', nan, ...
    'P_ODxAI', nan, ...
    'ModelPredictionInterceptAtMeanOD', nan, ...
    'ModelPredictionSlopeAtMeanOD', nan, ...
    'R2', nan, ...
    'AdjustedR2', nan, ...
    'RMSE', nan, ...
    'ModelStatus', "Not fit");
end


function [slope, point_count] = ...
    get_origin_constrained_type2_slope(x, y, weights)
valid_rows = isfinite(x) & isfinite(y) & isfinite(weights) & weights > 0;
x = x(valid_rows);
y = y(valid_rows);
weights = weights(valid_rows);
point_count = numel(x);
slope = nan;

if point_count < 2
    return
end

weighted_xx = sum(weights(:) .* x(:) .^ 2);
if ~isfinite(weighted_xx) || weighted_xx <= eps
    return
end

slope = sum(weights(:) .* x(:) .* y(:)) ./ weighted_xx;
end


function [estimate, p_value] = get_coefficient(model, candidate_names)
estimate = nan;
p_value = nan;
coefficient_names = string(model.Coefficients.Properties.RowNames);
for name_index = 1:numel(candidate_names)
    row_index = find(coefficient_names == candidate_names{name_index}, 1);
    if isempty(row_index)
        continue
    end
    estimate = model.Coefficients.Estimate(row_index);
    p_value = model.Coefficients.pValue(row_index);
    return
end
end


function fig = plot_overlaid_conditions( ...
    plot_table, line_slopes, area, unit_type, ...
    condition_names, condition_colors)
fig = figure('Color', 'w', 'Units', 'inches', ...
    'Position', [0.5, 0.5, 9.4, 6.8], ...
    'Name', sprintf('AI_vs_DeltaBias_ODxAI_%s_%s_Overlaid', ...
    area, unit_type));
ax = axes(fig);
setup_axes(ax, true)

line_handles = gobjects(numel(condition_names), 1);
for condition_index = 1:numel(condition_names)
    condition_table = plot_table( ...
        plot_table.Condition == condition_index, :);
    line_handles(condition_index) = plot_origin_constrained_line( ...
        ax, line_slopes(condition_index), ...
        condition_colors(condition_index, :));
    plot_scatter_by_monkey(ax, condition_table, ...
        condition_colors(condition_index, :));
end

title(ax, sprintf('%s %s neurons: all conditions', area, unit_type), ...
    'FontName', 'Arial', 'FontSize', 20, 'FontWeight', 'bold')
subtitle(ax, 'OD-weighted type-II lines constrained through the origin', ...
    'FontName', 'Arial', 'FontSize', 12)
xlabel(ax, 'Asymmetry index (stimulation-channel tuning)', ...
    'FontName', 'Arial', 'FontSize', 17)
ylabel(ax, '\Delta bias', 'Interpreter', 'tex', ...
    'FontName', 'Arial', 'FontSize', 17)

[jim_handle, clay_handle] = monkey_legend_handles(ax);
legend(ax, [line_handles; jim_handle; clay_handle], ...
    [condition_names, {'Jim', 'Clay'}], ...
    'Location', 'eastoutside', 'Box', 'off', ...
    'FontName', 'Arial', 'FontSize', 13)
end


function fig = plot_separated_conditions( ...
    plot_table, line_slopes, mean_od, area, unit_type, ...
    condition_names, condition_colors)
fig = figure('Color', 'w', 'Units', 'inches', ...
    'Position', [0.5, 0.5, 10.4, 8.6], ...
    'Name', sprintf('AI_vs_DeltaBias_ODxAI_%s_%s_Separated', ...
    area, unit_type));
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');

for condition_index = 1:numel(condition_names)
    ax = nexttile(layout, condition_index);
    setup_axes(ax, false)
    condition_table = plot_table( ...
        plot_table.Condition == condition_index, :);
    plot_origin_constrained_line(ax, line_slopes(condition_index), ...
        condition_colors(condition_index, :));
    plot_scatter_by_monkey(ax, condition_table, ...
        condition_colors(condition_index, :));
    title(ax, sprintf('%s  |  n = %d, mean OD = %.2f', ...
        condition_names{condition_index}, height(condition_table), ...
        mean_od(condition_index)), ...
        'FontName', 'Arial', 'FontSize', 13, 'FontWeight', 'bold')
end

xlabel(layout, 'Asymmetry index (stimulation-channel tuning)', ...
    'FontName', 'Arial', 'FontSize', 17)
ylabel(layout, '\Delta bias', 'Interpreter', 'tex', ...
    'FontName', 'Arial', 'FontSize', 17)
title(layout, sprintf('%s %s neurons: separated by condition', ...
    area, unit_type), ...
    'FontName', 'Arial', 'FontSize', 20, 'FontWeight', 'bold')
subtitle(layout, ['OD-weighted type-II lines constrained through origin; ' ...
    'circle = Jim, diamond = Clay, opacity = OD'], ...
    'FontName', 'Arial', 'FontSize', 12)
end


function setup_axes(ax, use_large_font)
hold(ax, 'on')
plot(ax, [-1, 1], [0, 0], 'k--', 'LineWidth', 0.8, ...
    'HandleVisibility', 'off')
plot(ax, [0, 0], [-2.2, 2.2], 'k--', 'LineWidth', 0.8, ...
    'HandleVisibility', 'off')
axis(ax, 'square')
box(ax, 'on')
xlim(ax, [-1, 1])
ylim(ax, [-2.2, 2.2])
xticks(ax, -1:0.5:1)
xticklabels(ax, {'-1', 'Away', '0', 'Towards', '1'})
yticks(ax, -2:1:2)
yticklabels(ax, {'-2', 'Away', '0', 'Towards', '2'})
xtickangle(ax, 0)
ytickangle(ax, 90)
if use_large_font
    font_size = 15;
else
    font_size = 11;
end
set(ax, 'FontName', 'Arial', 'FontSize', font_size, ...
    'LineWidth', 1)
end


function line_handle = plot_origin_constrained_line(ax, slope, plot_color)
x_plot = linspace(-1, 1, 201)';
if ~isfinite(slope)
    line_handle = plot(ax, nan, nan, '-', 'Color', plot_color, ...
        'LineWidth', 2.5);
    return
end

y_plot = slope .* x_plot;
line_handle = plot(ax, x_plot, y_plot, '-', 'Color', plot_color, ...
    'LineWidth', 2.5);
end


function plot_scatter_by_monkey(ax, condition_table, plot_color)
monkey_names = {'Clay', 'Jim'};
markers = {'d', 'o'};
for monkey_index = 1:numel(monkey_names)
    monkey_rows = strcmp(condition_table.Monkey, ...
        monkey_names{monkey_index});
    monkey_table = condition_table(monkey_rows, :);
    if isempty(monkey_table)
        continue
    end

    scatter_handle = scatter(ax, monkey_table.AI, monkey_table.Bias, ...
        40, plot_color, markers{monkey_index}, 'filled', ...
        'MarkerEdgeColor', plot_color, 'LineWidth', 1.5, ...
        'HandleVisibility', 'off');
    scatter_handle.AlphaData = monkey_table.OD;
    scatter_handle.MarkerFaceAlpha = 'flat';
end
end


function [jim_handle, clay_handle] = monkey_legend_handles(ax)
jim_handle = plot(ax, nan, nan, 'ko', 'MarkerFaceColor', 'k', ...
    'LineStyle', 'none');
clay_handle = plot(ax, nan, nan, 'kd', 'MarkerFaceColor', 'k', ...
    'LineStyle', 'none');
end


function [output_files, output_index] = export_figure_pair( ...
    fig, output_folder, file_stem, output_files, output_index)
assert_type2_lines_pass_origin(fig)
png_file = fullfile(output_folder, [file_stem, '.png']);
fig_file = fullfile(output_folder, [file_stem, '.fig']);
exportgraphics(fig, png_file, 'Resolution', 300, ...
    'BackgroundColor', 'white')
savefig(fig, fig_file)

output_index = output_index + 1;
output_files(output_index) = png_file;
output_index = output_index + 1;
output_files(output_index) = fig_file;
end


function assert_type2_lines_pass_origin(fig)
line_handles = findall(fig, 'Type', 'line');
fit_line_count = 0;
for line_index = 1:numel(line_handles)
    line_handle = line_handles(line_index);
    if ~strcmp(line_handle.LineStyle, '-') || line_handle.LineWidth < 2
        continue
    end
    fit_line_count = fit_line_count + 1;
    x_data = double(line_handle.XData(:));
    y_data = double(line_handle.YData(:));
    [distance_to_zero, zero_index] = min(abs(x_data));
    if distance_to_zero > 1e-12 || ...
            ~isfinite(y_data(zero_index)) || ...
            abs(y_data(zero_index)) > 1e-12
        error('AIvsBias:FitMissesOrigin', ...
            'A displayed type-II line does not pass through the origin.');
    end
end

if fit_line_count ~= 4
    error('AIvsBias:UnexpectedFitLineCount', ...
        'Expected four type-II lines; found %d.', fit_line_count);
end
end

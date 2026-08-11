clear

%% Unified population analysis for MT/FST and Jim/Clay/Both
% Edit the two options below, then run this script.

if ~exist('area', 'var')
    area = 'MT'; % 'MT' or 'FST'
end

if ~exist('monkey', 'var')
    monkey = 'Both'; % 'Both', 'Jim', or 'Clay'
end

if ~exist('data_file', 'var')
    data_file = '';
end

if ~exist('close_existing_figures', 'var')
    close_existing_figures = true;
end

if close_existing_figures
    close all
end

area = validatestring(area, {'MT', 'FST'});
monkey = validatestring(monkey, {'Both', 'Jim', 'Clay'});

[unit_table, data_file, workbook_audit] = ...
    LoadLatestUnitTableGof(data_file);

colorsteps = [254 191 15; ...
    0 0 0; ...
    234 0 233; ...
    110 205 221] ./ 255;

bias_table_all = build_bias_table(unit_table, area);
bias_table = apply_selection_rules(bias_table_all, area, monkey);

if isempty(bias_table)
    error('No units matched area = %s and monkey = %s.', area, monkey);
end

summary_table = build_summary_table(bias_table, area, monkey);
aixod_summary_table = build_aixod_summary_table(bias_table, area, monkey);
[fig_2d, fig_3d] = plot_population_figures(bias_table, area, monkey, colorsteps);

results = struct();
results.data_file = data_file;
results.workbook_audit = workbook_audit;
results.area = area;
results.monkey = monkey;
results.summary_table = summary_table;
results.aixod_summary_table = aixod_summary_table;
results.bias_table = bias_table;
results.fig_2d = fig_2d;
results.fig_3d = fig_3d;

disp(' ')
disp('Summary table:')
disp(summary_table)
disp(' ')
disp('Merged-eye AI x OD summary table:')
disp(aixod_summary_table)

assignin('base', 'population_results', results);
assignin('base', 'population_summary_table', summary_table);
assignin('base', 'population_aixod_summary_table', aixod_summary_table);
assignin('base', 'population_bias_table', bias_table);


function bias_table = build_bias_table(unit_table, area)
condition_names = {'Dominant', 'Combined', 'Stereo', 'NonDominant'};
[delta_bias, bias_nonstim, bias_stim, valid_bias_fit] = ...
    CalculateSigmoidFitBiases(unit_table, 4);

row_count = height(unit_table);
max_rows = row_count * 4;

AI = nan(max_rows, 1);
OD_raw = nan(max_rows, 1);
Condition = nan(max_rows, 1);
z2D3D = nan(max_rows, 1);
Bias = nan(max_rows, 1);
UnitIndex = nan(max_rows, 1);
MonkeyCode = nan(max_rows, 1);
AP = nan(max_rows, 1);
Bias_N = nan(max_rows, 1);
Bias_S = nan(max_rows, 1);
OD_max_eye = strings(max_rows, 1);
Monkey = strings(max_rows, 1);
Area = strings(max_rows, 1);

write_idx = 0;

for rec = 1:row_count
    if ~strcmp(get_table_text(unit_table.ROI(rec)), area)
        continue
    end

    p_ai = unit_table.p_AI{rec};
    if numel(p_ai) < 3 || p_ai(2) >= 0.05 || p_ai(3) >= 0.05
        continue
    end

    ch = unit_table.StimElec(rec);
    ai_values = unit_table.AI{rec}(:, ch);
    od_max = unit_table.OD_max{rec};
    z_value = unit_table.Z3D_v_Z2D{rec};
    monkey_name = get_table_text(unit_table.Monkey(rec));
    monkey_code = monkey_to_code(monkey_name);
    if od_max > 0
        cond_order = [2, 1, 4, 3];
        od_eye = "L";
    else
        cond_order = [3, 1, 4, 2];
        od_eye = "R";
    end

    ap_value = get_ap_value(unit_table, rec);

    for cond = 1:4
        source_idx = cond_order(cond);
        if source_idx > numel(ai_values)
            continue
        end

        if ~valid_bias_fit(rec, source_idx)
            continue
        end

        bias_n_this = bias_nonstim(rec, source_idx);
        bias_s_this = bias_stim(rec, source_idx);

        write_idx = write_idx + 1;

        AI(write_idx) = ai_values(source_idx);
        OD_raw(write_idx) = od_max;
        Condition(write_idx) = cond;
        z2D3D(write_idx) = z_value;
        Bias(write_idx) = delta_bias(rec, source_idx);
        UnitIndex(write_idx) = rec;
        MonkeyCode(write_idx) = monkey_code;
        AP(write_idx) = ap_value;
        Bias_N(write_idx) = bias_n_this;
        Bias_S(write_idx) = bias_s_this;
        OD_max_eye(write_idx) = od_eye;
        Monkey(write_idx) = monkey_name;
        Area(write_idx) = area;
    end
end

bias_table = table( ...
    AI(1:write_idx), ...
    OD_raw(1:write_idx), ...
    Condition(1:write_idx), ...
    z2D3D(1:write_idx), ...
    Bias(1:write_idx), ...
    UnitIndex(1:write_idx), ...
    MonkeyCode(1:write_idx), ...
    AP(1:write_idx), ...
    Bias_N(1:write_idx), ...
    Bias_S(1:write_idx), ...
    OD_max_eye(1:write_idx), ...
    Monkey(1:write_idx), ...
    Area(1:write_idx), ...
    'VariableNames', {'AI', 'OD_raw', 'Condition', 'z2D3D', 'Bias', 'UnitIndex', ...
    'MonkeyCode', 'AP', 'Bias_N', 'Bias_S', 'OD_max_eye', 'Monkey', 'Area'});

bias_table.OD = abs(bias_table.OD_raw);
bias_table.AbsBias = abs(bias_table.Bias);
bias_table.AbsAI = abs(bias_table.AI);
bias_table.ConditionName = categorical(bias_table.Condition, 1:4, condition_names);
bias_table.UnitType = repmat(categorical("Unknown", {'2D', '3D', 'Unknown'}), height(bias_table), 1);
bias_table.UnitType(bias_table.z2D3D < 0) = categorical("2D", {'2D', '3D', 'Unknown'});
bias_table.UnitType(bias_table.z2D3D > 0) = categorical("3D", {'2D', '3D', 'Unknown'});

bias_table.Coded_Condition = zeros(height(bias_table), 1);
bias_table.Coded_Condition(bias_table.Condition == 1 | bias_table.Condition == 2 | bias_table.Condition == 3) = 1;
bias_table.Coded_Condition(bias_table.Condition == 4) = -3;

bias_table.Coded_Condition_Simple = zeros(height(bias_table), 1);
bias_table.Coded_Condition_Simple(bias_table.Condition == 4) = -1;
bias_table.Coded_Condition_Simple(bias_table.Condition == 1) = 1;

bias_table.FlipBias = bias_table.Bias;
bias_table.MergedEyeBias = bias_table.Bias;
flip_rows = bias_table.Condition == 4;
bias_table.MergedEyeBias(flip_rows) = -bias_table.Bias(flip_rows);
bias_table.FlipBias = bias_table.MergedEyeBias;
end


function bias_table = apply_selection_rules(bias_table, area, monkey)
switch monkey
    case 'Both'
        if strcmp(area, 'FST')
            is_clay = strcmp(bias_table.Monkey, "Clay");
            is_jim = strcmp(bias_table.Monkey, "Jim");
            keep_rows = is_clay | (is_jim & bias_table.AP <= 26);
            bias_table = bias_table(keep_rows, :);
        end
    case 'Jim'
        bias_table = bias_table(strcmp(bias_table.Monkey, "Jim"), :);
    case 'Clay'
        bias_table = bias_table(strcmp(bias_table.Monkey, "Clay"), :);
end
end


function summary_table = build_summary_table(bias_table, area, monkey)
condition_names = {'Dominant', 'Combined', 'Stereo', 'NonDominant'};
unit_types = {'2D', '3D'};
row_total = numel(unit_types) * numel(condition_names);

Area = strings(row_total, 1);
MonkeySelection = strings(row_total, 1);
UnitType = strings(row_total, 1);
Condition = strings(row_total, 1);
NPoints = zeros(row_total, 1);
NUnits = zeros(row_total, 1);
MeanAI = nan(row_total, 1);
MeanBias = nan(row_total, 1);
MeanAbsBias = nan(row_total, 1);
MeanOD = nan(row_total, 1);
WeightedSlope = nan(row_total, 1);
WeightedIntercept = nan(row_total, 1);
P_AI = nan(row_total, 1);
R2_AI = nan(row_total, 1);
P_AI_OD = nan(row_total, 1);
P_AIxOD = nan(row_total, 1);
R2_AI_OD = nan(row_total, 1);

write_idx = 0;
for unit_idx = 1:numel(unit_types)
    for cond_idx = 1:numel(condition_names)
        write_idx = write_idx + 1;
        this_rows = strcmp(string(bias_table.UnitType), unit_types{unit_idx}) & ...
            bias_table.Condition == cond_idx;
        temp_table = bias_table(this_rows, :);

        Area(write_idx) = area;
        MonkeySelection(write_idx) = monkey;
        UnitType(write_idx) = unit_types{unit_idx};
        Condition(write_idx) = condition_names{cond_idx};
        NPoints(write_idx) = height(temp_table);
        NUnits(write_idx) = numel(unique(temp_table.UnitIndex));

        if isempty(temp_table)
            continue
        end

        MeanAI(write_idx) = mean(temp_table.AI, 'omitnan');
        MeanBias(write_idx) = mean(temp_table.Bias, 'omitnan');
        MeanAbsBias(write_idx) = mean(temp_table.AbsBias, 'omitnan');
        MeanOD(write_idx) = mean(temp_table.OD, 'omitnan');

        [WeightedSlope(write_idx), WeightedIntercept(write_idx)] = ...
            get_weighted_fit_line(temp_table.AI, temp_table.Bias, temp_table.OD);

        lm_ai = safe_fitlm(temp_table, 'Bias ~ AI');
        if ~isempty(lm_ai)
            P_AI(write_idx) = get_coefficient_pvalue(lm_ai, 'AI');
            R2_AI(write_idx) = lm_ai.Rsquared.Ordinary;
        end

        lm_ai_od = safe_fitlm(temp_table, 'Bias ~ AI + AI:OD');
        if ~isempty(lm_ai_od)
            P_AI_OD(write_idx) = get_coefficient_pvalue(lm_ai_od, 'AI');
            P_AIxOD(write_idx) = get_coefficient_pvalue(lm_ai_od, 'AI:OD');
            R2_AI_OD(write_idx) = lm_ai_od.Rsquared.Ordinary;
        end
    end
end

summary_table = table(Area, MonkeySelection, UnitType, Condition, NPoints, NUnits, ...
    MeanAI, MeanBias, MeanAbsBias, MeanOD, WeightedSlope, WeightedIntercept, ...
    P_AI, R2_AI, P_AI_OD, P_AIxOD, R2_AI_OD, ...
    'VariableNames', {'Area', 'MonkeySelection', 'UnitType', 'Condition', ...
    'NPoints', 'NUnits', 'MeanAI', 'MeanBias', 'MeanAbsBias', 'MeanOD', ...
    'WeightedSlope', 'WeightedIntercept', 'P_AI', 'R2_AI', ...
    'P_AI_withinCondition', 'P_AIxOD_withinCondition', 'R2_AI_withinCondition'});
end


function aixod_summary_table = build_aixod_summary_table(bias_table, area, monkey)
unit_types = {'2D', '3D'};
row_total = numel(unit_types);

Area = strings(row_total, 1);
MonkeySelection = strings(row_total, 1);
UnitType = strings(row_total, 1);
ConditionSet = strings(row_total, 1);
NPoints = zeros(row_total, 1);
NUnits = zeros(row_total, 1);
MeanAI = nan(row_total, 1);
MeanMergedEyeBias = nan(row_total, 1);
MeanOD = nan(row_total, 1);
WeightedSlope = nan(row_total, 1);
WeightedIntercept = nan(row_total, 1);
P_AI = nan(row_total, 1);
P_AIxOD = nan(row_total, 1);
R2 = nan(row_total, 1);

for unit_idx = 1:numel(unit_types)
    this_rows = strcmp(string(bias_table.UnitType), unit_types{unit_idx}) & ...
        (bias_table.Condition == 1 | bias_table.Condition == 4);
    temp_table = bias_table(this_rows, :);

    Area(unit_idx) = area;
    MonkeySelection(unit_idx) = monkey;
    UnitType(unit_idx) = unit_types{unit_idx};
    ConditionSet(unit_idx) = 'Dominant + NonDominant (merged eyes)';
    NPoints(unit_idx) = height(temp_table);
    NUnits(unit_idx) = numel(unique(temp_table.UnitIndex));

    if isempty(temp_table)
        continue
    end

    MeanAI(unit_idx) = mean(temp_table.AI, 'omitnan');
    MeanMergedEyeBias(unit_idx) = mean(temp_table.MergedEyeBias, 'omitnan');
    MeanOD(unit_idx) = mean(temp_table.OD, 'omitnan');

    [WeightedSlope(unit_idx), WeightedIntercept(unit_idx)] = ...
        get_weighted_fit_line(temp_table.AI, temp_table.MergedEyeBias, temp_table.OD);

    lm_ai_od = safe_fitlm(temp_table, 'MergedEyeBias ~ AI + AI:OD');
    if ~isempty(lm_ai_od)
        P_AI(unit_idx) = get_coefficient_pvalue(lm_ai_od, 'AI');
        P_AIxOD(unit_idx) = get_coefficient_pvalue(lm_ai_od, 'AI:OD');
        R2(unit_idx) = lm_ai_od.Rsquared.Ordinary;
    end
end

aixod_summary_table = table(Area, MonkeySelection, UnitType, ConditionSet, ...
    NPoints, NUnits, MeanAI, MeanMergedEyeBias, MeanOD, ...
    WeightedSlope, WeightedIntercept, P_AI, P_AIxOD, R2);
end


function [fig_2d, fig_3d] = plot_population_figures(bias_table, area, monkey, colorsteps)
condition_names = {'Dominant', 'Combined', 'Stereo', 'NonDominant'};
x_plot = -1:0.1:1;

fig_2d = figure('Name', sprintf('%s_%s_2D', area, monkey), 'Color', 'w');
setup_population_axes(fig_2d, area, monkey, '2D');

fig_3d = figure('Name', sprintf('%s_%s_3D', area, monkey), 'Color', 'w');
setup_population_axes(fig_3d, area, monkey, '3D');

line_handles_2d = gobjects(4, 1);
line_handles_3d = gobjects(4, 1);

for cond_idx = 1:4
    temp_2d = bias_table(strcmp(string(bias_table.UnitType), '2D') & bias_table.Condition == cond_idx, :);
    temp_3d = bias_table(strcmp(string(bias_table.UnitType), '3D') & bias_table.Condition == cond_idx, :);

    figure(fig_2d)
    hold on
    [slope, intercept] = get_weighted_fit_line(temp_2d.AI, temp_2d.Bias, temp_2d.OD);
    line_handles_2d(cond_idx) = plot(x_plot, intercept + x_plot .* slope, '-', ...
        'Color', colorsteps(cond_idx, :), 'LineWidth', 2.5);
    plot_scatter_by_monkey(temp_2d, colorsteps(cond_idx, :), monkey)

    figure(fig_3d)
    hold on
    [slope, intercept] = get_weighted_fit_line(temp_3d.AI, temp_3d.Bias, temp_3d.OD);
    line_handles_3d(cond_idx) = plot(x_plot, intercept + x_plot .* slope, '-', ...
        'Color', colorsteps(cond_idx, :), 'LineWidth', 2.5);
    plot_scatter_by_monkey(temp_3d, colorsteps(cond_idx, :), monkey)
end

figure(fig_2d)
add_population_legend(line_handles_2d, condition_names, monkey)

figure(fig_3d)
add_population_legend(line_handles_3d, condition_names, monkey)
end


function setup_population_axes(fig_handle, area, monkey, unit_type)
figure(fig_handle)
hold on

if strcmp(unit_type, '2D')
    y_lim = [-2.2, 2.2];
    y_ticks = -2:1:2;
    y_ticklabels = {'-2', 'Away', '0', 'Towards', '2'};
else
    y_lim = [-2.2, 2.2];
    y_ticks = -2:1:2;
    y_ticklabels = {'-2', 'Away', '0', 'Towards', '2'};
end

plot([-1, 1], [0, 0], 'k--')
plot([0, 0], y_lim, 'k--')
title(build_plot_title(area, monkey, unit_type), 'FontSize', 18)
xlabel('Asymmetry Index', 'FontSize', 18)
ylabel('Delta Bias', 'FontSize', 18)
axis square
box on
xlim([-1 1])
ylim(y_lim)
xticks(-1:0.5:1)
xticklabels({'-1', 'Away', '0', 'Towards', '1'})
yticks(y_ticks)
yticklabels(y_ticklabels)
xtickangle(0)
ytickangle(90)
set(gca, 'FontSize', 18, 'LineWidth', 1)
end


function title_text = build_plot_title(area, monkey, unit_type)
if strcmp(monkey, 'Both')
    title_text = sprintf('%s %s neurons', area, unit_type);
else
    title_text = sprintf('%s %s %s neurons', area, monkey, unit_type);
end
end


function plot_scatter_by_monkey(temp_table, plot_color, monkey_selection)
if isempty(temp_table)
    return
end

if strcmp(monkey_selection, 'Both')
    monkey_names = {'Clay', 'Jim'};
    markers = {'d', 'o'};
else
    monkey_names = {monkey_selection};
    markers = {get_marker_for_monkey(monkey_selection)};
end

for idx = 1:numel(monkey_names)
    this_rows = strcmp(temp_table.Monkey, monkey_names{idx});
    monkey_table = temp_table(this_rows, :);
    if isempty(monkey_table)
        continue
    end

    s = scatter(monkey_table.AI, monkey_table.Bias, 40, plot_color, markers{idx}, ...
        'filled', 'MarkerEdgeColor', plot_color, 'LineWidth', 1.5);
    s.AlphaData = monkey_table.OD;
    s.MarkerFaceAlpha = 'flat';
end
end


function add_population_legend(line_handles, condition_names, monkey_selection)
legend_handles = line_handles;
legend_labels = condition_names;

if strcmp(monkey_selection, 'Both')
    hold on
    jim_handle = plot(nan, nan, 'ko', 'MarkerFaceColor', 'k', 'LineStyle', 'none');
    clay_handle = plot(nan, nan, 'kd', 'MarkerFaceColor', 'k', 'LineStyle', 'none');
    legend_handles = [legend_handles; jim_handle; clay_handle];
    legend_labels = [legend_labels, {'Jim', 'Clay'}];
end

legend(legend_handles, legend_labels, 'Location', 'bestoutside')
end


function marker = get_marker_for_monkey(monkey_name)
switch monkey_name
    case 'Jim'
        marker = 'o';
    case 'Clay'
        marker = 'd';
    otherwise
        marker = 'o';
end
end


function [slope, intercept] = get_weighted_fit_line(x, y, w)
slope = nan;
intercept = nan;

valid_rows = isfinite(x) & isfinite(y) & isfinite(w);
x = x(valid_rows);
y = y(valid_rows);
w = w(valid_rows);

if numel(x) < 2
    return
end

if exist('type2_reg_weighted_matrix', 'file') == 2
    [slope, intercept] = type2_reg_weighted_matrix(x, y, w);
    return
end

design = [x(:), ones(numel(x), 1)];
coeff = lscov(design, y(:), w(:));
slope = coeff(1);
intercept = coeff(2);
end


function lm = safe_fitlm(temp_table, formula_text)
lm = [];
if height(temp_table) < 3
    return
end

try
    lm = fitlm(temp_table, formula_text);
catch
    lm = [];
end
end


function p_value = get_coefficient_pvalue(lm, coefficient_name)
p_value = nan;
if isempty(lm)
    return
end

row_names = lm.Coefficients.Properties.RowNames;
match_idx = find(strcmp(row_names, coefficient_name), 1);
if isempty(match_idx)
    return
end

p_value = lm.Coefficients.pValue(match_idx);
end


function monkey_code = monkey_to_code(monkey_name)
switch monkey_name
    case 'Jim'
        monkey_code = 1;
    case 'Clay'
        monkey_code = 2;
    otherwise
        error('Wrong monkey name: %s', monkey_name)
end
end


function ap_value = get_ap_value(unit_table, rec)
ap_value = nan;

if ismember('Hole', unit_table.Properties.VariableNames)
    hole_value = unit_table.Hole(rec, :);
    if numel(hole_value) >= 2
        ap_value = hole_value(2);
    end
end
end


function text_value = get_table_text(value)
if iscell(value)
    text_value = string(value{1});
elseif isstring(value)
    text_value = string(value(1));
elseif ischar(value)
    text_value = string(value);
else
    text_value = string(value);
end
text_value = char(text_value);
end

clear

%% Compare MT vs FST for 2D sessions only
% Edit options below, then run this script.

if ~exist('monkey', 'var')
    monkey = 'Both'; % 'Both', 'Jim', or 'Clay'
end

if ~exist('data_file', 'var')
    data_file = '';
end

monkey = validatestring(monkey, {'Both', 'Jim', 'Clay'});

[unit_table, data_file, workbook_audit] = ...
    LoadLatestUnitTableGof(data_file);

bias_table_mt = build_bias_table(unit_table, 'MT');
bias_table_fst = build_bias_table(unit_table, 'FST');
bias_table = [bias_table_mt; bias_table_fst];
bias_table = apply_selection_rules_across_roi(bias_table, monkey);
bias_table = bias_table(strcmp(string(bias_table.UnitType), '2D'), :);

if isempty(bias_table)
    error('No 2D rows remained after filtering for monkey = %s.', monkey);
end

bias_table.ROI = categorical(string(bias_table.Area), {'MT', 'FST'});

cue_names = {'Dominant', 'Combined', 'Stereo', 'NonDominant'};

model1_summary = build_per_cue_roi_models(bias_table, cue_names);
model2_result = build_all_cues_flipped_model(bias_table);
model3_result = build_perspective_flipped_model(bias_table);

comparison_results = struct();
comparison_results.data_file = data_file;
comparison_results.workbook_audit = workbook_audit;
comparison_results.monkey = monkey;
comparison_results.bias_table_2d = bias_table;
comparison_results.model1_per_cue = model1_summary;
comparison_results.model2_all_cues = model2_result;
comparison_results.model3_perspective_only = model3_result;

disp(' ')
disp('Model 1: For each cue, Delta Bias ~ AI * ROI')
disp(model1_summary)

disp(' ')
disp('Model 2: All cues together, Flipped Delta Bias ~ AI * ROI')
disp(model2_result.Summary)

disp(' ')
disp('Model 3: Perspective cues only, Flipped Delta Bias ~ AI * OD * ROI')
disp(model3_result.Summary)

assignin('base', 'MT_FST_2D_model_results', comparison_results);
assignin('base', 'MT_FST_2D_bias_table', bias_table);
assignin('base', 'MT_FST_2D_model1_summary', model1_summary);
assignin('base', 'MT_FST_2D_model2_summary', model2_result.Summary);
assignin('base', 'MT_FST_2D_model3_summary', model3_result.Summary);


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
bias_table.MergedEyeBias = bias_table.Bias;
flip_rows = bias_table.Condition == 4;
bias_table.MergedEyeBias(flip_rows) = -bias_table.Bias(flip_rows);
bias_table.FlipBias = bias_table.MergedEyeBias;
end


function bias_table = apply_selection_rules_across_roi(bias_table, monkey)
switch monkey
    case 'Both'
        is_fst = strcmp(bias_table.Area, "FST");
        is_clay = strcmp(bias_table.Monkey, "Clay");
        is_jim = strcmp(bias_table.Monkey, "Jim");
        keep_rows = ~is_fst | is_clay | (is_jim & bias_table.AP <= 26);
        bias_table = bias_table(keep_rows, :);
    case 'Jim'
        bias_table = bias_table(strcmp(bias_table.Monkey, "Jim"), :);
    case 'Clay'
        bias_table = bias_table(strcmp(bias_table.Monkey, "Clay"), :);
end
end


function summary_tbl = build_per_cue_roi_models(bias_table, cue_names)
n_cues = numel(cue_names);

Cue = strings(n_cues, 1);
NPoints = zeros(n_cues, 1);
NUnits = zeros(n_cues, 1);
P_AI = nan(n_cues, 1);
P_ROI = nan(n_cues, 1);
P_AIxROI = nan(n_cues, 1);
R2 = nan(n_cues, 1);

for i_cue = 1:n_cues
    temp_table = bias_table(bias_table.Condition == i_cue, :);
    Cue(i_cue) = cue_names{i_cue};
    NPoints(i_cue) = height(temp_table);
    NUnits(i_cue) = numel(unique(strcat(string(temp_table.Area), "_", string(temp_table.Monkey), "_", string(temp_table.UnitIndex))));

    lm = safe_fitlm(temp_table, 'Bias ~ AI * ROI');
    if isempty(lm)
        continue
    end

    P_AI(i_cue) = get_first_matching_pvalue(lm, {'AI'});
    P_ROI(i_cue) = get_first_matching_pvalue(lm, {'ROI_FST', 'ROI_FST:AI_dummy_never_match', 'ROI_FST'});
    P_AIxROI(i_cue) = get_first_matching_pvalue(lm, {'AI:ROI_FST', 'ROI_FST:AI'});
    R2(i_cue) = lm.Rsquared.Ordinary;
end

summary_tbl = table(Cue, NPoints, NUnits, P_AI, P_ROI, P_AIxROI, R2);
end


function model_result = build_all_cues_flipped_model(bias_table)
temp_table = bias_table;
lm = safe_fitlm(temp_table, 'FlipBias ~ AI * ROI');
model_result = struct();
model_result.Formula = 'FlipBias ~ AI * ROI';
model_result.NPoints = height(temp_table);
model_result.NUnits = numel(unique(strcat(string(temp_table.Area), "_", string(temp_table.Monkey), "_", string(temp_table.UnitIndex))));
model_result.Model = lm;

summary = table();
summary.Formula = "FlipBias ~ AI * ROI";
summary.NPoints = model_result.NPoints;
summary.NUnits = model_result.NUnits;
summary.P_AI = get_first_matching_pvalue(lm, {'AI'});
summary.P_ROI = get_first_matching_pvalue(lm, {'ROI_FST'});
summary.P_AIxROI = get_first_matching_pvalue(lm, {'AI:ROI_FST', 'ROI_FST:AI'});
summary.R2 = get_model_r2(lm);

model_result.Summary = summary;
end


function model_result = build_perspective_flipped_model(bias_table)
temp_table = bias_table(bias_table.Condition == 1 | bias_table.Condition == 4, :);
lm = safe_fitlm(temp_table, 'FlipBias ~ AI * OD * ROI');
model_result = struct();
model_result.Formula = 'FlipBias ~ AI * OD * ROI';
model_result.NPoints = height(temp_table);
model_result.NUnits = numel(unique(strcat(string(temp_table.Area), "_", string(temp_table.Monkey), "_", string(temp_table.UnitIndex))));
model_result.Model = lm;

summary = table();
summary.Formula = "FlipBias ~ AI * OD * ROI";
summary.NPoints = model_result.NPoints;
summary.NUnits = model_result.NUnits;
summary.P_AI = get_first_matching_pvalue(lm, {'AI'});
summary.P_OD = get_first_matching_pvalue(lm, {'OD'});
summary.P_ROI = get_first_matching_pvalue(lm, {'ROI_FST'});
summary.P_AIxOD = get_first_matching_pvalue(lm, {'AI:OD'});
summary.P_AIxROI = get_first_matching_pvalue(lm, {'AI:ROI_FST', 'ROI_FST:AI'});
summary.P_ODxROI = get_first_matching_pvalue(lm, {'OD:ROI_FST', 'ROI_FST:OD'});
summary.P_AIxODxROI = get_first_matching_pvalue(lm, {'AI:OD:ROI_FST', 'AI:ROI_FST:OD', 'OD:ROI_FST:AI'});
summary.R2 = get_model_r2(lm);

model_result.Summary = summary;
end


function p_value = get_first_matching_pvalue(lm, coefficient_names)
p_value = nan;
if isempty(lm)
    return
end

row_names = lm.Coefficients.Properties.RowNames;
for i_name = 1:numel(coefficient_names)
    match_idx = find(strcmp(row_names, coefficient_names{i_name}), 1);
    if ~isempty(match_idx)
        p_value = lm.Coefficients.pValue(match_idx);
        return
    end
end
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


function r2 = get_model_r2(lm)
r2 = nan;
if isempty(lm)
    return
end
r2 = lm.Rsquared.Ordinary;
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

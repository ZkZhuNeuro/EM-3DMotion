function results = RunUnifiedPopulationFromPreparedTable( ...
    preparedTable, area, monkey, analysisName, options)
%RUNUNIFIEDPOPULATIONFROMPREPAREDTABLE Population analysis without reloads.
%
% All analysis variants enter this function through the same normalized
% columns: analysis_AI, analysis_OD_signed, p_AI, and Z3D_v_Z2D. The
% function never refreshes rows from recording workbooks and never applies
% an AP cutoff.

arguments
    preparedTable table
    area (1, 1) string {mustBeMember(area, ["MT", "FST"])}
    monkey (1, 1) string {mustBeMember(monkey, ["Both", "Jim", "Clay"])}
    analysisName (1, 1) string
    options.FigureVisible (1, 1) logical = false
end

requireVariables(preparedTable, ["SourceTableRow", "ROI", "Monkey", ...
    "Hole", "p_AI", "Z3D_v_Z2D", "analysis_AI", ...
    "analysis_OD_signed", "analysis_source_valid", ...
    "Behav_bias_N", "Behav_bias_S", ...
    "Behav_goodfit_N", "Behav_goodfit_S"]);

colorSteps = [254 191 15; 0 0 0; 234 0 233; 110 205 221] ./ 255;
biasTableAll = buildBiasTable(preparedTable, area);
biasTable = applyMonkeySelection(biasTableAll, monkey);
if isempty(biasTable)
    error('UnifiedPopulation:NoUnits', ...
        'No units matched %s/%s for %s.', area, monkey, analysisName);
end

summaryTable = buildConditionSummary(biasTable, area, monkey);
aixodSummaryTable = buildAIxODSummary(biasTable, area, monkey);
[fig2D, fig3D] = plotPopulationFigures( ...
    biasTable, area, monkey, analysisName, colorSteps, ...
    options.FigureVisible);

results = struct();
results.Analysis = analysisName;
results.Area = area;
results.Monkey = monkey;
results.Criteria = [ ...
    "raw MonoL and MonoR p_AI < 0.05 at selected source/channel; " ...
    "Z3D-Z2D sign defines 2D/3D; all AP; Max OD sign assigns eye; " ...
    "abs(OD) enters model and display weights; valid N/S behavior fits"];
results.ModelFormula = "MergedEyeBias ~ AI + AI:OD";
results.BiasTable = biasTable;
results.SummaryTable = summaryTable;
results.AIxODSummaryTable = aixodSummaryTable;
results.Figure2D = fig2D;
results.Figure3D = fig3D;
end


function biasTable = buildBiasTable(unitTable, area)
conditionNames = {'Dominant', 'Combined', 'Stereo', 'NonDominant'};
[deltaBias, biasNonstim, biasStim, validBiasFit] = ...
    calculateSigmoidFitBiases(unitTable, 4);

rowCount = height(unitTable);
maxRows = rowCount * 4;
AI = nan(maxRows, 1);
ODRaw = nan(maxRows, 1);
Condition = nan(maxRows, 1);
z2D3D = nan(maxRows, 1);
Bias = nan(maxRows, 1);
SourceTableRow = nan(maxRows, 1);
MonkeyCode = nan(maxRows, 1);
AP = nan(maxRows, 1);
BiasN = nan(maxRows, 1);
BiasS = nan(maxRows, 1);
ODMaxEye = strings(maxRows, 1);
Monkey = strings(maxRows, 1);
Area = strings(maxRows, 1);
writeIndex = 0;

for row = 1:rowCount
    if ~strcmp(getTableText(unitTable.ROI(row)), area) || ...
            ~logical(unitTable.analysis_source_valid(row))
        continue
    end
    pAI = numericCellValue(unitTable.p_AI, row);
    pAI = double(pAI(:));
    if numel(pAI) < 3 || ~isfinite(pAI(2)) || ~isfinite(pAI(3)) || ...
            pAI(2) >= 0.05 || pAI(3) >= 0.05
        continue
    end
    aiValues = double(numericCellValue(unitTable.analysis_AI, row));
    aiValues = aiValues(:);
    odMax = numericScalar(unitTable.analysis_OD_signed, row);
    zValue = numericScalar(unitTable.Z3D_v_Z2D, row);
    if numel(aiValues) < 4 || any(~isfinite(aiValues(1:4))) || ...
            ~isfinite(odMax) || ~isfinite(zValue) || zValue == 0
        continue
    end

    monkeyName = getTableText(unitTable.Monkey(row));
    if odMax > 0
        conditionOrder = [2, 1, 4, 3];
        odEye = "L";
    else
        conditionOrder = [3, 1, 4, 2];
        odEye = "R";
    end
    apValue = getAPValue(unitTable, row);

    for condition = 1:4
        sourceIndex = conditionOrder(condition);
        if ~validBiasFit(row, sourceIndex)
            continue
        end
        writeIndex = writeIndex + 1;
        AI(writeIndex) = aiValues(sourceIndex);
        ODRaw(writeIndex) = odMax;
        Condition(writeIndex) = condition;
        z2D3D(writeIndex) = zValue;
        Bias(writeIndex) = deltaBias(row, sourceIndex);
        SourceTableRow(writeIndex) = unitTable.SourceTableRow(row);
        MonkeyCode(writeIndex) = monkeyToCode(monkeyName);
        AP(writeIndex) = apValue;
        BiasN(writeIndex) = biasNonstim(row, sourceIndex);
        BiasS(writeIndex) = biasStim(row, sourceIndex);
        ODMaxEye(writeIndex) = odEye;
        Monkey(writeIndex) = monkeyName;
        Area(writeIndex) = area;
    end
end

biasTable = table(AI(1:writeIndex), ODRaw(1:writeIndex), ...
    Condition(1:writeIndex), z2D3D(1:writeIndex), Bias(1:writeIndex), ...
    SourceTableRow(1:writeIndex), MonkeyCode(1:writeIndex), ...
    AP(1:writeIndex), BiasN(1:writeIndex), BiasS(1:writeIndex), ...
    ODMaxEye(1:writeIndex), Monkey(1:writeIndex), Area(1:writeIndex), ...
    'VariableNames', {'AI', 'OD_raw', 'Condition', 'z2D3D', 'Bias', ...
    'SourceTableRow', 'MonkeyCode', 'AP', 'Bias_N', 'Bias_S', ...
    'OD_max_eye', 'Monkey', 'Area'});
biasTable.OD = abs(biasTable.OD_raw);
biasTable.AbsBias = abs(biasTable.Bias);
biasTable.AbsAI = abs(biasTable.AI);
biasTable.ConditionName = categorical( ...
    biasTable.Condition, 1:4, conditionNames);
biasTable.UnitType = repmat( ...
    categorical("Unknown", {'2D', '3D', 'Unknown'}), height(biasTable), 1);
biasTable.UnitType(biasTable.z2D3D < 0) = ...
    categorical("2D", {'2D', '3D', 'Unknown'});
biasTable.UnitType(biasTable.z2D3D > 0) = ...
    categorical("3D", {'2D', '3D', 'Unknown'});
biasTable.MergedEyeBias = biasTable.Bias;
nonDominant = biasTable.Condition == 4;
biasTable.MergedEyeBias(nonDominant) = -biasTable.Bias(nonDominant);
end


function output = applyMonkeySelection(input, monkey)
if monkey == "Both"
    output = input;
else
    output = input(string(input.Monkey) == monkey, :);
end
end


function summary = buildConditionSummary(biasTable, area, monkey)
conditionNames = ["Dominant", "Combined", "Stereo", "NonDominant"];
unitTypes = ["2D", "3D"];
rows = numel(unitTypes) * numel(conditionNames);
AnalysisArea = repmat(area, rows, 1);
MonkeySelection = repmat(monkey, rows, 1);
UnitType = strings(rows, 1);
Condition = strings(rows, 1);
NPoints = zeros(rows, 1);
NUnits = zeros(rows, 1);
MeanAI = nan(rows, 1);
MeanBias = nan(rows, 1);
MeanAbsBias = nan(rows, 1);
MeanOD = nan(rows, 1);
WeightedSlope = nan(rows, 1);
WeightedIntercept = nan(rows, 1);
P_AI = nan(rows, 1);
R2_AI = nan(rows, 1);
P_AI_WithinCondition = nan(rows, 1);
P_AIxOD_WithinCondition = nan(rows, 1);
R2_AI_WithinCondition = nan(rows, 1);
writeIndex = 0;
for typeIndex = 1:numel(unitTypes)
    for conditionIndex = 1:numel(conditionNames)
        writeIndex = writeIndex + 1;
        mask = string(biasTable.UnitType) == unitTypes(typeIndex) & ...
            biasTable.Condition == conditionIndex;
        temp = biasTable(mask, :);
        UnitType(writeIndex) = unitTypes(typeIndex);
        Condition(writeIndex) = conditionNames(conditionIndex);
        NPoints(writeIndex) = height(temp);
        NUnits(writeIndex) = numel(unique(temp.SourceTableRow));
        if isempty(temp)
            continue
        end
        MeanAI(writeIndex) = mean(temp.AI, 'omitnan');
        MeanBias(writeIndex) = mean(temp.Bias, 'omitnan');
        MeanAbsBias(writeIndex) = mean(temp.AbsBias, 'omitnan');
        MeanOD(writeIndex) = mean(temp.OD, 'omitnan');
        [WeightedSlope(writeIndex), WeightedIntercept(writeIndex)] = ...
            weightedFitLine(temp.AI, temp.Bias, temp.OD);
        lmAI = safeFitlm(temp, 'Bias ~ AI');
        if ~isempty(lmAI)
            P_AI(writeIndex) = coefficientPValue(lmAI, 'AI');
            R2_AI(writeIndex) = lmAI.Rsquared.Ordinary;
        end
        lmAIOD = safeFitlm(temp, 'Bias ~ AI + AI:OD');
        if ~isempty(lmAIOD)
            P_AI_WithinCondition(writeIndex) = ...
                coefficientPValue(lmAIOD, 'AI');
            P_AIxOD_WithinCondition(writeIndex) = ...
                coefficientPValue(lmAIOD, 'AI:OD');
            R2_AI_WithinCondition(writeIndex) = lmAIOD.Rsquared.Ordinary;
        end
    end
end
summary = table(AnalysisArea, MonkeySelection, UnitType, Condition, ...
    NPoints, NUnits, MeanAI, MeanBias, MeanAbsBias, MeanOD, ...
    WeightedSlope, WeightedIntercept, P_AI, R2_AI, ...
    P_AI_WithinCondition, P_AIxOD_WithinCondition, ...
    R2_AI_WithinCondition);
end


function summary = buildAIxODSummary(biasTable, area, monkey)
unitTypes = ["2D", "3D"];
AnalysisArea = repmat(area, 2, 1);
MonkeySelection = repmat(monkey, 2, 1);
UnitType = unitTypes(:);
ConditionSet = repmat("Dominant + NonDominant (merged eyes)", 2, 1);
NPoints = zeros(2, 1);
NUnits = zeros(2, 1);
MeanAI = nan(2, 1);
MeanMergedEyeBias = nan(2, 1);
MeanOD = nan(2, 1);
WeightedSlope = nan(2, 1);
WeightedIntercept = nan(2, 1);
P_AI = nan(2, 1);
P_AIxOD = nan(2, 1);
R2 = nan(2, 1);
for index = 1:2
    mask = string(biasTable.UnitType) == unitTypes(index) & ...
        ismember(biasTable.Condition, [1, 4]);
    temp = biasTable(mask, :);
    NPoints(index) = height(temp);
    NUnits(index) = numel(unique(temp.SourceTableRow));
    if isempty(temp)
        continue
    end
    MeanAI(index) = mean(temp.AI, 'omitnan');
    MeanMergedEyeBias(index) = mean(temp.MergedEyeBias, 'omitnan');
    MeanOD(index) = mean(temp.OD, 'omitnan');
    [WeightedSlope(index), WeightedIntercept(index)] = ...
        weightedFitLine(temp.AI, temp.MergedEyeBias, temp.OD);
    lm = safeFitlm(temp, 'MergedEyeBias ~ AI + AI:OD');
    if ~isempty(lm)
        P_AI(index) = coefficientPValue(lm, 'AI');
        P_AIxOD(index) = coefficientPValue(lm, 'AI:OD');
        R2(index) = lm.Rsquared.Ordinary;
    end
end
summary = table(AnalysisArea, MonkeySelection, UnitType, ConditionSet, ...
    NPoints, NUnits, MeanAI, MeanMergedEyeBias, MeanOD, ...
    WeightedSlope, WeightedIntercept, P_AI, P_AIxOD, R2);
end


function [fig2D, fig3D] = plotPopulationFigures( ...
    biasTable, area, monkey, analysisName, colors, visible)
if visible
    visibility = 'on';
else
    visibility = 'off';
end
conditionNames = {'Dominant', 'Combined', 'Stereo', 'NonDominant'};
xPlot = -1:0.1:1;
fig2D = figure('Color', 'w', 'Visible', visibility, ...
    'Name', char(analysisName + " " + area + " 2D"));
setupAxes(fig2D, area, monkey, "2D", analysisName);
fig3D = figure('Color', 'w', 'Visible', visibility, ...
    'Name', char(analysisName + " " + area + " 3D"));
setupAxes(fig3D, area, monkey, "3D", analysisName);
line2D = gobjects(4, 1);
line3D = gobjects(4, 1);
for condition = 1:4
    temp2D = biasTable(string(biasTable.UnitType) == "2D" & ...
        biasTable.Condition == condition, :);
    temp3D = biasTable(string(biasTable.UnitType) == "3D" & ...
        biasTable.Condition == condition, :);
    figure(fig2D); hold on
    [slope, intercept] = weightedFitLine( ...
        temp2D.AI, temp2D.Bias, temp2D.OD);
    line2D(condition) = plot(xPlot, intercept + xPlot .* slope, '-', ...
        'Color', colors(condition, :), 'LineWidth', 2.5);
    plotScatter(temp2D, colors(condition, :), monkey);
    figure(fig3D); hold on
    [slope, intercept] = weightedFitLine( ...
        temp3D.AI, temp3D.Bias, temp3D.OD);
    line3D(condition) = plot(xPlot, intercept + xPlot .* slope, '-', ...
        'Color', colors(condition, :), 'LineWidth', 2.5);
    plotScatter(temp3D, colors(condition, :), monkey);
end
figure(fig2D); addLegend(line2D, conditionNames, monkey);
figure(fig3D); addLegend(line3D, conditionNames, monkey);
end


function setupAxes(fig, area, monkey, unitType, analysisName)
figure(fig); hold on
plot([-1, 1], [0, 0], 'k--');
plot([0, 0], [-2.2, 2.2], 'k--');
title(sprintf('%s | %s %s %s neurons', ...
    analysisName, area, monkey, unitType), 'FontSize', 14, ...
    'Interpreter', 'none');
xlabel('Asymmetry Index', 'FontSize', 15);
ylabel('Delta Bias', 'FontSize', 15);
axis square; box on; xlim([-1, 1]); ylim([-2.2, 2.2]);
xticks(-1:0.5:1); yticks(-2:1:2);
xticklabels({'-1', 'Away', '0', 'Towards', '1'});
yticklabels({'-2', 'Away', '0', 'Towards', '2'});
ytickangle(90);
set(gca, 'FontSize', 14, 'LineWidth', 1);
end


function plotScatter(temp, color, monkeySelection)
if isempty(temp)
    return
end
if monkeySelection == "Both"
    names = ["Jim", "Clay"];
    markers = {'o', 'd'};
else
    names = monkeySelection;
    if monkeySelection == "Clay", markers = {'d'}; else, markers = {'o'}; end
end
for index = 1:numel(names)
    rows = string(temp.Monkey) == names(index);
    if ~any(rows), continue, end
    values = temp(rows, :);
    s = scatter(values.AI, values.Bias, 40, color, markers{index}, ...
        'filled', 'MarkerEdgeColor', color, 'LineWidth', 1.5);
    s.AlphaData = values.OD;
    s.MarkerFaceAlpha = 'flat';
end
end


function addLegend(lines, conditionNames, monkeySelection)
handles = lines;
labels = conditionNames;
if monkeySelection == "Both"
    hold on
    jim = plot(nan, nan, 'ko', 'MarkerFaceColor', 'k', 'LineStyle', 'none');
    clay = plot(nan, nan, 'kd', 'MarkerFaceColor', 'k', 'LineStyle', 'none');
    handles = [handles; jim; clay];
    labels = [labels, {'Jim', 'Clay'}];
end
legend(handles, labels, 'Location', 'bestoutside');
end


function [deltaBias, biasN, biasS, validFit] = ...
    calculateSigmoidFitBiases(unitTable, cueCount)
biasN = stackCueValues(unitTable.Behav_bias_N, height(unitTable), cueCount, nan);
biasS = stackCueValues(unitTable.Behav_bias_S, height(unitTable), cueCount, nan);
goodN = stackCueValues( ...
    unitTable.Behav_goodfit_N, height(unitTable), cueCount, false) > 0;
goodS = stackCueValues( ...
    unitTable.Behav_goodfit_S, height(unitTable), cueCount, false) > 0;
deltaBias = biasN - biasS;
validFit = goodN & goodS & isfinite(biasN) & isfinite(biasS);
deltaBias(~validFit) = nan;
end


function values = stackCueValues(column, rowCount, cueCount, fillValue)
values = repmat(fillValue, rowCount, cueCount);
if iscell(column)
    for row = 1:rowCount
        rowValues = column{row};
        if isempty(rowValues), continue, end
        rowValues = rowValues(:)';
        count = min(numel(rowValues), cueCount);
        values(row, 1:count) = rowValues(1:count);
    end
elseif isnumeric(column) || islogical(column)
    count = min(size(column, 2), cueCount);
    values(:, 1:count) = column(:, 1:count);
else
    error('UnifiedPopulation:UnsupportedBehaviorColumn', ...
        'Unsupported behavioral column type: %s.', class(column));
end
end


function [slope, intercept] = weightedFitLine(x, y, weights)
slope = nan; intercept = nan;
valid = isfinite(x) & isfinite(y) & isfinite(weights);
x = x(valid); y = y(valid); weights = weights(valid);
if numel(x) < 2 || nnz(weights > 0) < 2
    return
end
if exist('type2_reg_weighted_matrix', 'file') == 2
    [slope, intercept] = type2_reg_weighted_matrix(x, y, weights);
else
    design = [x(:), ones(numel(x), 1)];
    coefficients = lscov(design, y(:), max(weights(:), eps));
    slope = coefficients(1);
    intercept = coefficients(2);
end
end


function model = safeFitlm(input, formula)
model = [];
if height(input) < 3
    return
end
try
    model = fitlm(input, formula);
catch
    model = [];
end
end


function value = coefficientPValue(model, name)
value = nan;
row = find(strcmp(model.Coefficients.Properties.RowNames, name), 1);
if ~isempty(row)
    value = model.Coefficients.pValue(row);
end
end


function value = getAPValue(unitTable, row)
value = nan;
hole = numericCellValue(unitTable.Hole, row);
if numel(hole) >= 2
    value = double(hole(2));
end
end


function value = monkeyToCode(monkey)
if strcmp(monkey, 'Jim')
    value = 1;
elseif strcmp(monkey, 'Clay')
    value = 2;
else
    error('UnifiedPopulation:UnknownMonkey', 'Unknown monkey: %s.', monkey);
end
end


function requireVariables(tableData, required)
missing = setdiff(required, string(tableData.Properties.VariableNames));
if ~isempty(missing)
    error('UnifiedPopulation:MissingVariables', ...
        'Missing required variable(s): %s', join(missing, ', '));
end
end


function value = numericCellValue(column, row)
if iscell(column), value = column{row}; else, value = column(row, :); end
if ~isnumeric(value) && ~islogical(value)
    error('UnifiedPopulation:ExpectedNumeric', ...
        'Expected numeric data at row %d.', row);
end
end


function value = numericScalar(column, row)
value = numericCellValue(column, row);
if ~isscalar(value)
    error('UnifiedPopulation:ExpectedScalar', ...
        'Expected a scalar at row %d.', row);
end
value = double(value);
end


function text = getTableText(value)
if iscell(value), text = string(value{1}); else, text = string(value(1)); end
text = char(text);
end

function [perCueSummary, mergedEye2DSummary, modelSummary] = ...
    BuildPopulationModelSummaryByUnitType(biasTable, area, monkey)
%BUILDPOPULATIONMODELSUMMARYBYUNITTYPE Apply the intended model by unit type.
%
% Every cue in both 2D and 3D populations is fit with
%
%   DeltaBias ~ AI
%
% Only the 2D dominant + non-dominant population receives the labeled-line
% merged-eye fit
%
%   MergedEyeDeltaBias ~ AI + AI:OD
%
% No merged-eye model is calculated for 3D units.

arguments
    biasTable table
    area (1, 1) string
    monkey (1, 1) string
end

required = ["AI", "OD", "Bias", "MergedEyeBias", "Condition", ...
    "UnitType", "UnitIndex"];
missing = setdiff(required, string(biasTable.Properties.VariableNames));
if ~isempty(missing)
    error('PopulationModelSummary:MissingVariables', ...
        'Missing bias-table variable(s): %s', join(missing, ', '));
end

conditionNames = ["Dominant", "Combined", "Stereo", "NonDominant"];
unitTypes = ["2D", "3D"];
rows = repmat(emptySummaryRow(), ...
    numel(unitTypes) .* numel(conditionNames), 1);
row = 0;
for unitIndex = 1:numel(unitTypes)
    for conditionIndex = 1:numel(conditionNames)
        row = row + 1;
        selected = strcmp(string(biasTable.UnitType), unitTypes(unitIndex)) & ...
            biasTable.Condition == conditionIndex;
        modelTable = biasTable(selected, :);
        rows(row, 1) = summarizeModel(modelTable, ...
            area, monkey, unitTypes(unitIndex), "Per cue", ...
            conditionNames(conditionIndex), "DeltaBias", ...
            "DeltaBias ~ AI", false);
    end
end
perCueSummary = struct2table(rows);

selected2D = strcmp(string(biasTable.UnitType), "2D") & ...
    ismember(biasTable.Condition, [1, 4]);
mergedRow = summarizeModel(biasTable(selected2D, :), ...
    area, monkey, "2D", "Merged eyes (2D labeled-line)", ...
    "Dominant + NonDominant", "MergedEyeDeltaBias", ...
    "MergedEyeDeltaBias ~ AI + AI:OD", true);
mergedEye2DSummary = struct2table(mergedRow);
modelSummary = [perCueSummary; mergedEye2DSummary];
end


function output = summarizeModel(inputTable, area, monkey, unitType, ...
    modelScope, conditionSet, responseName, formulaText, useMergedModel)
output = emptySummaryRow();
output.Area = area;
output.MonkeySelection = monkey;
output.UnitType = unitType;
output.ModelScope = modelScope;
output.ConditionSet = conditionSet;
output.Response = responseName;
output.Formula = formulaText;

if useMergedModel
    response = inputTable.MergedEyeBias;
    valid = isfinite(inputTable.AI) & isfinite(inputTable.OD) & ...
        isfinite(response);
else
    response = inputTable.Bias;
    valid = isfinite(inputTable.AI) & isfinite(response);
end
modelTable = table(inputTable.AI(valid), inputTable.OD(valid), ...
    response(valid), inputTable.UnitIndex(valid), ...
    'VariableNames', {'AI', 'OD', 'DeltaBias', 'UnitIndex'});
output.NPoints = height(modelTable);
output.NUnits = numel(unique(modelTable.UnitIndex));
if isempty(modelTable)
    return
end
output.MeanAI = mean(modelTable.AI, 'omitnan');
output.MeanDeltaBias = mean(modelTable.DeltaBias, 'omitnan');
output.MeanOD = mean(modelTable.OD, 'omitnan');
if height(modelTable) < 3
    return
end

try
    if useMergedModel
        linearModel = fitlm(modelTable, 'DeltaBias ~ AI + AI:OD');
    else
        linearModel = fitlm(modelTable, 'DeltaBias ~ AI');
    end
catch
    return
end
output.Intercept = coefficientValue(linearModel, '(Intercept)', 'Estimate');
output.AI_Estimate = coefficientValue(linearModel, 'AI', 'Estimate');
output.AI_SE = coefficientValue(linearModel, 'AI', 'SE');
output.P_AI = coefficientValue(linearModel, 'AI', 'pValue');
if useMergedModel
    output.AIxOD_Estimate = ...
        coefficientValue(linearModel, 'AI:OD', 'Estimate');
    output.AIxOD_SE = coefficientValue(linearModel, 'AI:OD', 'SE');
    output.P_AIxOD = coefficientValue(linearModel, 'AI:OD', 'pValue');
end
output.R2 = linearModel.Rsquared.Ordinary;
end


function value = coefficientValue(linearModel, name, variable)
value = NaN;
rowNames = linearModel.Coefficients.Properties.RowNames;
row = find(strcmp(rowNames, name), 1);
if ~isempty(row)
    value = linearModel.Coefficients.(variable)(row);
end
end


function output = emptySummaryRow()
output = struct( ...
    'Area', "", ...
    'MonkeySelection', "", ...
    'UnitType', "", ...
    'ModelScope', "", ...
    'ConditionSet', "", ...
    'Response', "", ...
    'Formula', "", ...
    'NPoints', 0, ...
    'NUnits', 0, ...
    'MeanAI', NaN, ...
    'MeanDeltaBias', NaN, ...
    'MeanOD', NaN, ...
    'Intercept', NaN, ...
    'AI_Estimate', NaN, ...
    'AI_SE', NaN, ...
    'P_AI', NaN, ...
    'AIxOD_Estimate', NaN, ...
    'AIxOD_SE', NaN, ...
    'P_AIxOD', NaN, ...
    'R2', NaN);
end

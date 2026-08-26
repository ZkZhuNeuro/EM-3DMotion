function results = PlotDominantEyeVsCombinedCueAI(options)
%PLOTDOMINANTEYEVSCOMBINEDCUEAI Compare neural AI across cue conditions.
%
% For the established MT/FST population cohort, this function plots the
% signed dominant-eye asymmetry index against the signed combined-cue
% asymmetry index separately for MT 2D, MT 3D, FST 2D, and FST 3D neurons.
% It reports Pearson and Spearman correlations and applies Benjamini-Hochberg
% FDR correction to the four Pearson tests.

arguments
    options.DataFile (1, 1) string = ...
        "C:\EM\PopulationAnalysis\unit_table_gof.mat"
    options.OutputFolder (1, 1) string = fullfile( ...
        "C:\EM", "PopulationAnalysis", "output", ...
        "DominantEyeVsCombinedCueAI")
    options.Monkey (1, 1) string ...
        {mustBeMember(options.Monkey, ["Both", "Jim", "Clay"])} = "Both"
    options.RefreshFromWorkbooks (1, 1) logical = true
    options.FigureVisible (1, 1) logical = false
end

if ~isfile(options.DataFile)
    error('DominantCombinedAI:MissingInput', ...
        'Population input does not exist: %s', options.DataFile);
end

scriptFolder = string(fileparts(mfilename('fullpath')));
addpath(scriptFolder);
if options.RefreshFromWorkbooks
    [unitTable, resolvedDataFile, workbookAudit] = ...
        LoadLatestUnitTableGof(options.DataFile);
else
    loaded = load(options.DataFile, 'unit_table_gof');
    if ~isfield(loaded, 'unit_table_gof') || ...
            ~istable(loaded.unit_table_gof)
        error('DominantCombinedAI:InvalidInput', ...
            '%s does not contain table unit_table_gof.', options.DataFile);
    end
    unitTable = loaded.unit_table_gof;
    resolvedDataFile = char(options.DataFile);
    workbookAudit = struct();
end

required = ["ROI", "Monkey", "StimElec", "AI", "OD_max", ...
    "p_AI", "Z3D_v_Z2D"];
missing = setdiff(required, string(unitTable.Properties.VariableNames));
if ~isempty(missing)
    error('DominantCombinedAI:MissingVariables', ...
        'Input table is missing: %s.', join(missing, ', '));
end

[neuronTable, selectionAudit] = buildNeuronTable(unitTable, options.Monkey);
if isempty(neuronTable)
    error('DominantCombinedAI:NoNeurons', ...
        'No neurons passed the population criteria for monkey = %s.', ...
        options.Monkey);
end

summaryTable = buildCorrelationSummary(neuronTable);
summaryTable.PearsonQ_BH = benjaminiHochberg(summaryTable.PearsonP);

makeFolder(options.OutputFolder);
writetable(neuronTable, fullfile(options.OutputFolder, ...
    'DominantEyeVsCombinedCueAI_Points.csv'));
writetable(selectionAudit, fullfile(options.OutputFolder, ...
    'DominantEyeVsCombinedCueAI_SelectionAudit.csv'));
writetable(summaryTable, fullfile(options.OutputFolder, ...
    'DominantEyeVsCombinedCueAI_Correlations.csv'));

visible = matlab.lang.OnOffSwitchState(options.FigureVisible);
individualFiles = strings(height(summaryTable), 2);
for row = 1:height(summaryTable)
    area = summaryTable.Area(row);
    unitType = summaryTable.UnitType(row);
    points = neuronTable(neuronTable.Area == area & ...
        neuronTable.UnitType == unitType, :);
    fig = figure('Color', 'w', 'Visible', char(visible), ...
        'Name', char(area + " " + unitType + ...
        " dominant-eye AI vs combined-cue AI"), ...
        'Units', 'inches', 'Position', [1, 1, 6.4, 5.8]);
    ax = axes(fig);
    plotSubpopulation(ax, points, summaryTable(row, :), true);
    stem = "DominantEyeAI_vs_CombinedCueAI_" + area + "_" + unitType;
    pngFile = fullfile(options.OutputFolder, stem + ".png");
    figFile = fullfile(options.OutputFolder, stem + ".fig");
    exportgraphics(fig, pngFile, 'Resolution', 300);
    savefig(fig, figFile);
    individualFiles(row, :) = [pngFile, figFile];
    close(fig);
end

compositeFigure = figure('Color', 'w', 'Visible', char(visible), ...
    'Name', 'Dominant-eye AI vs combined-cue AI by subpopulation', ...
    'Units', 'inches', 'Position', [1, 1, 11.5, 9]);
layout = tiledlayout(compositeFigure, 2, 2, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
for row = 1:height(summaryTable)
    area = summaryTable.Area(row);
    unitType = summaryTable.UnitType(row);
    points = neuronTable(neuronTable.Area == area & ...
        neuronTable.UnitType == unitType, :);
    plotSubpopulation(nexttile(layout), points, summaryTable(row, :), ...
        row == 1);
end
title(layout, 'Dominant-eye AI versus combined-cue AI', ...
    'FontWeight', 'normal');
compositePNG = fullfile(options.OutputFolder, ...
    'DominantEyeAI_vs_CombinedCueAI_AllSubpopulations.png');
compositePDF = fullfile(options.OutputFolder, ...
    'DominantEyeAI_vs_CombinedCueAI_AllSubpopulations.pdf');
compositeFIG = fullfile(options.OutputFolder, ...
    'DominantEyeAI_vs_CombinedCueAI_AllSubpopulations.fig');
exportgraphics(compositeFigure, compositePNG, 'Resolution', 300);
exportgraphics(compositeFigure, compositePDF, 'ContentType', 'vector');
savefig(compositeFigure, compositeFIG);
close(compositeFigure);

methods = [ ...
    "# Dominant-eye AI versus combined-cue AI"; ""; ...
    "Input: `" + string(resolvedDataFile) + "`"; ...
    "Monkey selection: " + options.Monkey; ...
    "Workbook refresh: " + string(options.RefreshFromWorkbooks); ""; ...
    "The four subpopulations are MT 2D, MT 3D, FST 2D, and FST 3D."; ...
    "The neural gate is raw MonoL and MonoR p_AI < 0.05 at StimElec."; ...
    "Z3D_v_Z2D < 0 defines 2D and > 0 defines 3D."; ...
    "OD_max > 0 selects MonoL as dominant; OD_max < 0 selects MonoR."; ...
    "Rows with zero/invalid OD or nonfinite AI are excluded."; ...
    "Correlations use signed AI. Pearson is primary; Spearman is reported as a rank-robust check."; ...
    "PearsonQ_BH is Benjamini-Hochberg FDR across the four subpopulations."];
writelines(methods, fullfile(options.OutputFolder, 'README.md'));

results = struct();
results.InputFile = string(resolvedDataFile);
results.Monkey = options.Monkey;
results.RefreshFromWorkbooks = options.RefreshFromWorkbooks;
results.WorkbookAudit = workbookAudit;
results.SelectionAudit = selectionAudit;
results.NeuronTable = neuronTable;
results.CorrelationSummary = summaryTable;
results.IndividualFigureFiles = individualFiles;
results.CompositeFigureFiles = [compositePNG, compositePDF, compositeFIG];
results.OutputFolder = options.OutputFolder;
dominant_combined_ai_results = results; %#ok<NASGU>
save(fullfile(options.OutputFolder, ...
    'DominantEyeVsCombinedCueAI_Results.mat'), ...
    'dominant_combined_ai_results', '-v7.3');

disp('Dominant-eye AI versus combined-cue AI correlations:')
disp(summaryTable)
fprintf('Outputs saved to %s\n', options.OutputFolder);
end


function [neuronTable, audit] = buildNeuronTable(unitTable, monkeySelection)
rowCount = height(unitTable);
SourceTableRow = (1:rowCount)';
Area = strings(rowCount, 1);
Monkey = strings(rowCount, 1);
UnitType = strings(rowCount, 1);
DominantEye = strings(rowCount, 1);
StimElec = nan(rowCount, 1);
ODSigned = nan(rowCount, 1);
CombinedCueAI = nan(rowCount, 1);
DominantEyeAI = nan(rowCount, 1);
Z3DminusZ2D = nan(rowCount, 1);
MonoLP = nan(rowCount, 1);
MonoRP = nan(rowCount, 1);
Included = false(rowCount, 1);
ExclusionReason = strings(rowCount, 1);

for row = 1:rowCount
    Area(row) = normalizeText(unitTable.ROI, row);
    Monkey(row) = normalizeText(unitTable.Monkey, row);
    if ~ismember(Area(row), ["MT", "FST"])
        ExclusionReason(row) = "ROI is not MT/FST";
        continue
    end
    if monkeySelection ~= "Both" && Monkey(row) ~= monkeySelection
        ExclusionReason(row) = "Different monkey";
        continue
    end

    try
        pAI = numericValue(unitTable.p_AI, row);
        pAI = double(pAI(:));
        if numel(pAI) >= 3
            MonoLP(row) = pAI(2);
            MonoRP(row) = pAI(3);
        end
        if numel(pAI) < 3 || any(~isfinite(pAI(2:3))) || ...
                any(pAI(2:3) >= 0.05)
            ExclusionReason(row) = "MonoL/MonoR p_AI gate failed";
            continue
        end

        zValue = numericScalar(unitTable.Z3D_v_Z2D, row);
        Z3DminusZ2D(row) = zValue;
        if ~isfinite(zValue) || zValue == 0
            ExclusionReason(row) = "Undefined 2D/3D class";
            continue
        elseif zValue < 0
            UnitType(row) = "2D";
        else
            UnitType(row) = "3D";
        end

        channel = numericScalar(unitTable.StimElec, row);
        aiMatrix = numericValue(unitTable.AI, row);
        od = numericScalar(unitTable.OD_max, row);
        StimElec(row) = channel;
        ODSigned(row) = od;
        if ~isfinite(channel) || channel ~= fix(channel) || channel < 1 || ...
                channel > size(aiMatrix, 2) || size(aiMatrix, 1) < 3
            ExclusionReason(row) = "Invalid StimElec or AI matrix";
            continue
        end
        if ~isfinite(od) || od == 0
            ExclusionReason(row) = "Undefined dominant eye";
            continue
        end

        CombinedCueAI(row) = double(aiMatrix(1, channel));
        if od > 0
            DominantEye(row) = "L";
            DominantEyeAI(row) = double(aiMatrix(2, channel));
        else
            DominantEye(row) = "R";
            DominantEyeAI(row) = double(aiMatrix(3, channel));
        end
        if ~isfinite(CombinedCueAI(row)) || ~isfinite(DominantEyeAI(row))
            ExclusionReason(row) = "Nonfinite AI";
            continue
        end

        Included(row) = true;
        ExclusionReason(row) = "Included";
    catch ME
        ExclusionReason(row) = "Invalid row: " + string(ME.identifier);
    end
end

audit = table(SourceTableRow, Area, Monkey, UnitType, DominantEye, ...
    StimElec, ODSigned, CombinedCueAI, DominantEyeAI, Z3DminusZ2D, ...
    MonoLP, MonoRP, Included, ExclusionReason);
neuronTable = audit(Included, setdiff(audit.Properties.VariableNames, ...
    {'Included', 'ExclusionReason'}, 'stable'));
end


function summary = buildCorrelationSummary(neuronTable)
areas = ["MT"; "MT"; "FST"; "FST"];
unitTypes = ["2D"; "3D"; "2D"; "3D"];
rowCount = numel(areas);
N = zeros(rowCount, 1);
N_Jim = zeros(rowCount, 1);
N_Clay = zeros(rowCount, 1);
PearsonR = nan(rowCount, 1);
PearsonP = nan(rowCount, 1);
SpearmanRho = nan(rowCount, 1);
SpearmanP = nan(rowCount, 1);
Intercept = nan(rowCount, 1);
Slope = nan(rowCount, 1);
SlopeCI_Low = nan(rowCount, 1);
SlopeCI_High = nan(rowCount, 1);
R2 = nan(rowCount, 1);

for row = 1:rowCount
    selected = neuronTable.Area == areas(row) & ...
        neuronTable.UnitType == unitTypes(row);
    points = neuronTable(selected, :);
    x = points.DominantEyeAI;
    y = points.CombinedCueAI;
    valid = isfinite(x) & isfinite(y);
    x = x(valid);
    y = y(valid);
    pointMonkeys = points.Monkey(valid);
    N(row) = numel(x);
    N_Jim(row) = nnz(pointMonkeys == "Jim");
    N_Clay(row) = nnz(pointMonkeys == "Clay");
    if numel(x) < 3 || numel(unique(x)) < 2 || numel(unique(y)) < 2
        continue
    end
    [PearsonR(row), PearsonP(row)] = corr(x, y, ...
        'Type', 'Pearson', 'Rows', 'complete');
    [SpearmanRho(row), SpearmanP(row)] = corr(x, y, ...
        'Type', 'Spearman', 'Rows', 'complete');
    model = fitlm(x, y);
    Intercept(row) = model.Coefficients.Estimate(1);
    Slope(row) = model.Coefficients.Estimate(2);
    ci = coefCI(model);
    SlopeCI_Low(row) = ci(2, 1);
    SlopeCI_High(row) = ci(2, 2);
    R2(row) = model.Rsquared.Ordinary;
end

Area = areas;
UnitType = unitTypes;
summary = table(Area, UnitType, N, N_Jim, N_Clay, PearsonR, PearsonP, ...
    SpearmanRho, SpearmanP, Intercept, Slope, SlopeCI_Low, ...
    SlopeCI_High, R2);
end


function plotSubpopulation(ax, points, summaryRow, showLegend)
hold(ax, 'on');
axisLimits = [-1, 1];
plot(ax, axisLimits, axisLimits, ':', 'Color', [0.55, 0.55, 0.55], ...
    'LineWidth', 1.2, 'DisplayName', 'Identity');
xline(ax, 0, '--', 'Color', [0.75, 0.75, 0.75], ...
    'HandleVisibility', 'off');
yline(ax, 0, '--', 'Color', [0.75, 0.75, 0.75], ...
    'HandleVisibility', 'off');

monkeys = ["Jim", "Clay"];
markers = {'o', 'd'};
colors = [0.12, 0.47, 0.71; 0.85, 0.33, 0.10];
for index = 1:numel(monkeys)
    selected = points.Monkey == monkeys(index);
    if ~any(selected)
        continue
    end
    scatter(ax, points.DominantEyeAI(selected), ...
        points.CombinedCueAI(selected), 48, colors(index, :), ...
        markers{index}, 'filled', 'MarkerEdgeColor', colors(index, :), ...
        'MarkerFaceAlpha', 0.72, 'DisplayName', char(monkeys(index)));
end

if isfinite(summaryRow.Slope) && isfinite(summaryRow.Intercept)
    xFit = linspace(axisLimits(1), axisLimits(2), 200);
    plot(ax, xFit, summaryRow.Intercept + summaryRow.Slope .* xFit, ...
        '-', 'Color', [0.15, 0.15, 0.15], 'LineWidth', 2, ...
        'DisplayName', 'OLS fit');
end

xlim(ax, axisLimits);
ylim(ax, axisLimits);
axis(ax, 'square');
box(ax, 'on');
grid(ax, 'on');
xticks(ax, -1:0.5:1);
yticks(ax, -1:0.5:1);
xlabel(ax, 'Dominant-eye AI');
ylabel(ax, 'Combined-cue AI');
title(ax, sprintf('%s %s (n = %d)', summaryRow.Area, ...
    summaryRow.UnitType, summaryRow.N), 'FontWeight', 'normal');
subtitle(ax, sprintf('Pearson r = %.3f, p = %s; Spearman rho = %.3f, p = %s', ...
    summaryRow.PearsonR, formatP(summaryRow.PearsonP), ...
    summaryRow.SpearmanRho, formatP(summaryRow.SpearmanP)));
set(ax, 'FontSize', 11, 'LineWidth', 1);
if showLegend
    legend(ax, 'Location', 'southeast');
end
end


function qValues = benjaminiHochberg(pValues)
qValues = nan(size(pValues));
valid = isfinite(pValues);
p = pValues(valid);
if isempty(p)
    return
end
[sortedP, order] = sort(p);
count = numel(sortedP);
adjusted = sortedP .* count ./ (1:count)';
adjusted = flipud(cummin(flipud(adjusted)));
adjusted = min(adjusted, 1);
restored = nan(count, 1);
restored(order) = adjusted;
qValues(valid) = restored;
end


function value = numericValue(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
while iscell(value) && isscalar(value)
    value = value{1};
end
if ~isnumeric(value) && ~islogical(value)
    error('DominantCombinedAI:ExpectedNumeric', ...
        'Expected numeric content at row %d.', row);
end
value = double(value);
end


function value = numericScalar(column, row)
value = numericValue(column, row);
if ~isscalar(value)
    error('DominantCombinedAI:ExpectedScalar', ...
        'Expected a numeric scalar at row %d.', row);
end
end


function value = normalizeText(column, row)
if iscell(column)
    value = string(column{row});
else
    value = string(column(row));
end
value = strtrim(value(1));
end


function text = formatP(value)
if ~isfinite(value)
    text = 'NaN';
elseif value == 0
    text = '<1e-15';
elseif value < 0.001
    text = sprintf('%.2g', value);
else
    text = sprintf('%.3f', value);
end
end


function makeFolder(folder)
if ~isfolder(folder)
    mkdir(folder);
end
end

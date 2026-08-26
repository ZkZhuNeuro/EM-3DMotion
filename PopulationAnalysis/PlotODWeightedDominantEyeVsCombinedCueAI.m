function results = PlotODWeightedDominantEyeVsCombinedCueAI(options)
%PLOTODWEIGHTEDDOMINANTEYEVSCOMBINEDCUEAI Plot AI*|OD| versus Combined AI.
%
% Uses the exact neuron cohort saved by PlotDominantEyeVsCombinedCueAI and
% changes only the x-variable to DominantEyeAI .* abs(ODSigned). Separate
% figures and correlations are produced for MT 2D, MT 3D, FST 2D, and FST
% 3D neurons. The original unweighted output folder is not modified.

arguments
    options.BaseResultsFile (1, 1) string = fullfile( ...
        "C:\EM", "PopulationAnalysis", "output", ...
        "DominantEyeVsCombinedCueAI", ...
        "DominantEyeVsCombinedCueAI_Results.mat")
    options.OutputFolder (1, 1) string = fullfile( ...
        "C:\EM", "PopulationAnalysis", "output", ...
        "ODWeightedDominantEyeVsCombinedCueAI")
    options.FigureVisible (1, 1) logical = false
end

if ~isfile(options.BaseResultsFile)
    error('ODWeightedDominantCombinedAI:MissingBaseResults', ...
        ['Base results do not exist: %s. Run ' ...
        'PlotDominantEyeVsCombinedCueAI first.'], options.BaseResultsFile);
end

loaded = load(options.BaseResultsFile, 'dominant_combined_ai_results');
if ~isfield(loaded, 'dominant_combined_ai_results') || ...
        ~isstruct(loaded.dominant_combined_ai_results) || ...
        ~isfield(loaded.dominant_combined_ai_results, 'NeuronTable')
    error('ODWeightedDominantCombinedAI:InvalidBaseResults', ...
        '%s does not contain the expected neuron table.', ...
        options.BaseResultsFile);
end
baseResults = loaded.dominant_combined_ai_results;
pointTable = baseResults.NeuronTable;
required = ["Area", "UnitType", "Monkey", "ODSigned", ...
    "DominantEyeAI", "CombinedCueAI"];
missing = setdiff(required, string(pointTable.Properties.VariableNames));
if ~isempty(missing)
    error('ODWeightedDominantCombinedAI:MissingVariables', ...
        'The base neuron table is missing: %s.', join(missing, ', '));
end

pointTable.AbsOD = abs(double(pointTable.ODSigned));
pointTable.ODWeightedDominantEyeAI = ...
    double(pointTable.DominantEyeAI) .* pointTable.AbsOD;
valid = isfinite(pointTable.ODWeightedDominantEyeAI) & ...
    isfinite(pointTable.CombinedCueAI);
pointTable = pointTable(valid, :);

summaryTable = buildCorrelationSummary(pointTable);
summaryTable.PearsonQ_BH = benjaminiHochberg(summaryTable.PearsonP);
xLimit = niceSymmetricLimit(pointTable.ODWeightedDominantEyeAI);

makeFolder(options.OutputFolder);
writetable(pointTable, fullfile(options.OutputFolder, ...
    'ODWeightedDominantEyeVsCombinedCueAI_Points.csv'));
writetable(summaryTable, fullfile(options.OutputFolder, ...
    'ODWeightedDominantEyeVsCombinedCueAI_Correlations.csv'));

if options.FigureVisible
    visibility = 'on';
else
    visibility = 'off';
end

individualFiles = strings(height(summaryTable), 2);
for row = 1:height(summaryTable)
    area = summaryTable.Area(row);
    unitType = summaryTable.UnitType(row);
    points = pointTable(pointTable.Area == area & ...
        pointTable.UnitType == unitType, :);
    fig = figure('Color', 'w', 'Visible', visibility, ...
        'Name', char(area + " " + unitType + ...
        " OD-weighted dominant-eye AI vs combined-cue AI"), ...
        'Units', 'inches', 'Position', [1, 1, 6.4, 5.8]);
    ax = axes(fig);
    plotSubpopulation(ax, points, summaryTable(row, :), true, xLimit);
    stem = "ODWeightedDominantEyeAI_vs_CombinedCueAI_" + ...
        area + "_" + unitType;
    pngFile = fullfile(options.OutputFolder, stem + ".png");
    figFile = fullfile(options.OutputFolder, stem + ".fig");
    exportgraphics(fig, pngFile, 'Resolution', 300);
    savefig(fig, figFile);
    individualFiles(row, :) = [pngFile, figFile];
    close(fig);
end

compositeFigure = figure('Color', 'w', 'Visible', visibility, ...
    'Name', 'OD-weighted dominant-eye AI vs combined-cue AI', ...
    'Units', 'inches', 'Position', [1, 1, 11.5, 9]);
layout = tiledlayout(compositeFigure, 2, 2, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
for row = 1:height(summaryTable)
    area = summaryTable.Area(row);
    unitType = summaryTable.UnitType(row);
    points = pointTable(pointTable.Area == area & ...
        pointTable.UnitType == unitType, :);
    plotSubpopulation(nexttile(layout), points, summaryTable(row, :), ...
        row == 1, xLimit);
end
title(layout, 'Dominant-eye AI x |OD| versus combined-cue AI', ...
    'FontWeight', 'normal');
compositePNG = fullfile(options.OutputFolder, ...
    'ODWeightedDominantEyeAI_vs_CombinedCueAI_AllSubpopulations.png');
compositePDF = fullfile(options.OutputFolder, ...
    'ODWeightedDominantEyeAI_vs_CombinedCueAI_AllSubpopulations.pdf');
compositeFIG = fullfile(options.OutputFolder, ...
    'ODWeightedDominantEyeAI_vs_CombinedCueAI_AllSubpopulations.fig');
exportgraphics(compositeFigure, compositePNG, 'Resolution', 300);
exportgraphics(compositeFigure, compositePDF, 'ContentType', 'vector');
savefig(compositeFigure, compositeFIG);
close(compositeFigure);

methods = [ ...
    "# OD-weighted dominant-eye AI versus combined-cue AI"; ""; ...
    "Base result: `" + options.BaseResultsFile + "`"; ...
    "Source population input: `" + string(baseResults.InputFile) + "`"; ...
    "Monkey selection: " + string(baseResults.Monkey); ""; ...
    "This analysis uses the exact saved neuron cohort from the unweighted version."; ...
    "Only the x-variable changes: DominantEyeAI * abs(ODSigned)."; ...
    "The y-variable remains signed CombinedCueAI."; ...
    "Pearson is primary; Spearman is the rank-robust check."; ...
    "PearsonQ_BH is Benjamini-Hochberg FDR across the four subpopulations."; ...
    compose("All panels use the shared x-axis range [%.2f, %.2f].", ...
        -xLimit, xLimit); ...
    "Because abs(OD) is positive, quadrant membership is unchanged from the unweighted version."];
writelines(methods, fullfile(options.OutputFolder, 'README.md'));

results = struct();
results.BaseResultsFile = options.BaseResultsFile;
results.InputFile = string(baseResults.InputFile);
results.Monkey = string(baseResults.Monkey);
results.PointTable = pointTable;
results.CorrelationSummary = summaryTable;
results.SharedXLimit = [-xLimit, xLimit];
results.IndividualFigureFiles = individualFiles;
results.CompositeFigureFiles = [compositePNG, compositePDF, compositeFIG];
results.OutputFolder = options.OutputFolder;
od_weighted_dominant_combined_ai_results = results; %#ok<NASGU>
save(fullfile(options.OutputFolder, ...
    'ODWeightedDominantEyeVsCombinedCueAI_Results.mat'), ...
    'od_weighted_dominant_combined_ai_results', '-v7.3');

disp('Dominant-eye AI x |OD| versus combined-cue AI correlations:')
disp(summaryTable)
fprintf('Outputs saved to %s\n', options.OutputFolder);
end


function summary = buildCorrelationSummary(pointTable)
areas = ["MT"; "MT"; "FST"; "FST"];
unitTypes = ["2D"; "3D"; "2D"; "3D"];
rowCount = numel(areas);
N = zeros(rowCount, 1);
N_Jim = zeros(rowCount, 1);
N_Clay = zeros(rowCount, 1);
Q2_Q4_N = zeros(rowCount, 1);
Q2_Q4_Proportion = nan(rowCount, 1);
Q1_Q3_N = zeros(rowCount, 1);
Q1_Q3_Proportion = nan(rowCount, 1);
OnAxis_N = zeros(rowCount, 1);
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
    selected = pointTable.Area == areas(row) & ...
        pointTable.UnitType == unitTypes(row);
    points = pointTable(selected, :);
    x = points.ODWeightedDominantEyeAI;
    y = points.CombinedCueAI;
    valid = isfinite(x) & isfinite(y);
    x = x(valid);
    y = y(valid);
    pointMonkeys = points.Monkey(valid);
    N(row) = numel(x);
    N_Jim(row) = nnz(pointMonkeys == "Jim");
    N_Clay(row) = nnz(pointMonkeys == "Clay");
    products = x .* y;
    Q2_Q4_N(row) = nnz(products < 0);
    Q1_Q3_N(row) = nnz(products > 0);
    OnAxis_N(row) = nnz(products == 0);
    if N(row) > 0
        Q2_Q4_Proportion(row) = Q2_Q4_N(row) ./ N(row);
        Q1_Q3_Proportion(row) = Q1_Q3_N(row) ./ N(row);
    end
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
summary = table(Area, UnitType, N, N_Jim, N_Clay, ...
    Q2_Q4_N, Q2_Q4_Proportion, Q1_Q3_N, Q1_Q3_Proportion, OnAxis_N, ...
    PearsonR, PearsonP, SpearmanRho, SpearmanP, Intercept, Slope, ...
    SlopeCI_Low, SlopeCI_High, R2);
end


function plotSubpopulation(ax, points, summaryRow, showLegend, xLimit)
hold(ax, 'on');
xLimits = [-xLimit, xLimit];
yLimits = [-1, 1];
plot(ax, xLimits, xLimits, ':', 'Color', [0.55, 0.55, 0.55], ...
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
    scatter(ax, points.ODWeightedDominantEyeAI(selected), ...
        points.CombinedCueAI(selected), 48, colors(index, :), ...
        markers{index}, 'filled', 'MarkerEdgeColor', colors(index, :), ...
        'MarkerFaceAlpha', 0.72, 'DisplayName', char(monkeys(index)));
end

if isfinite(summaryRow.Slope) && isfinite(summaryRow.Intercept)
    xFit = linspace(xLimits(1), xLimits(2), 200);
    plot(ax, xFit, summaryRow.Intercept + summaryRow.Slope .* xFit, ...
        '-', 'Color', [0.15, 0.15, 0.15], 'LineWidth', 2, ...
        'DisplayName', 'OLS fit');
end

xlim(ax, xLimits);
ylim(ax, yLimits);
axis(ax, 'square');
box(ax, 'on');
grid(ax, 'on');
tickLimit = floor(xLimit .* 10) ./ 10;
xticks(ax, -tickLimit:0.1:tickLimit);
yticks(ax, -1:0.5:1);
xlabel(ax, 'Dominant-eye AI x |OD|');
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


function limit = niceSymmetricLimit(values)
values = abs(values(isfinite(values)));
if isempty(values)
    limit = 1;
    return
end
limit = ceil(max(values) .* 1.08 ./ 0.05) .* 0.05;
if ~isfinite(limit) || limit <= 0
    limit = 1;
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

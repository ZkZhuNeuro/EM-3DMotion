function analysis = RunPopulationByAdjacentTuningDiscontinuity(options)
%RUNPOPULATIONBYADJACENTTUNINGDISCONTINUITY Compare low/high max jumps.
%
% Sessions with valid five-contact full-tuning distances are split strictly
% below versus strictly above the median MaxAdjacentJumpSquared. A session
% exactly at the median is retained in the split audit but omitted from both
% groups. Original stimulation-channel Quick AI and maximum-response OD are
% then plotted with the established population conventions. Four 1-by-2
% figures compare the groups side by side for MT 2D, MT 3D, FST 2D, and
% FST 3D neurons.

arguments
    options.DiscontinuityFile (1, 1) string = [ ...
        "C:\EM\StimTuningAnalysis\AdjacentFullTuningDiscontinuity\" + ...
        "AdjacentFullTuningDiscontinuity.mat"]
    options.StateFile (1, 1) string = ...
        "C:\EM\PopulationAnalysis\unit_table_gof.mat"
    options.OutputFolder (1, 1) string = [ ...
        "C:\EM\StimTuningAnalysis\AdjacentFullTuningDiscontinuity\" + ...
        "PopulationMedianSplit"]
    options.Monkey (1, 1) string ...
        {mustBeMember(options.Monkey, ["Both", "Jim", "Clay"])} = "Both"
    options.FigureVisible (1, 1) logical = false
end

if ~isfile(options.DiscontinuityFile)
    error('TuningDiscontinuityPopulation:MissingDiscontinuityFile', ...
        'Discontinuity MAT file does not exist: %s', ...
        options.DiscontinuityFile);
end
if ~isfile(options.StateFile)
    error('TuningDiscontinuityPopulation:MissingStateFile', ...
        'Population state MAT file does not exist: %s', options.StateFile);
end
ensureFolder(options.OutputFolder);
scriptFolder = string(fileparts(mfilename('fullpath')));
projectFolder = string(fileparts(scriptFolder));
addpath(scriptFolder, fullfile(projectFolder, 'PopulationAnalysis'));

loaded = load(options.DiscontinuityFile, ...
    'AdjacentFullTuningDiscontinuity');
if ~isfield(loaded, 'AdjacentFullTuningDiscontinuity') || ...
        ~isfield(loaded.AdjacentFullTuningDiscontinuity, 'Audit')
    error('TuningDiscontinuityPopulation:InvalidDiscontinuityFile', ...
        ['Discontinuity MAT file must contain ' ...
        'AdjacentFullTuningDiscontinuity.Audit.']);
end
discontinuityAnalysis = loaded.AdjacentFullTuningDiscontinuity;
audit = discontinuityAnalysis.Audit;
requireVariables(audit, ["TableRow", "Monkey", "ROI", "Status", ...
    "MaxAdjacentJumpSquared"]);
validDistance = audit.Status == "Success" & ...
    isfinite(audit.MaxAdjacentJumpSquared);
if nnz(validDistance) < 3
    error('TuningDiscontinuityPopulation:InsufficientDistances', ...
        'At least three successful discontinuity estimates are required.');
end
medianMaxJump = median(audit.MaxAdjacentJumpSquared(validDistance));
lowDistance = validDistance & ...
    audit.MaxAdjacentJumpSquared < medianMaxJump;
highDistance = validDistance & ...
    audit.MaxAdjacentJumpSquared > medianMaxJump;
atMedian = validDistance & ...
    audit.MaxAdjacentJumpSquared == medianMaxJump;

[unitTable, resolvedStateFile, workbookAudit] = ...
    LoadLatestUnitTableGof(options.StateFile);
validateAuditMapping(audit, validDistance, unitTable);
preparedPopulationTable = PrepareOriginalMaxODPopulationTable(unitTable);
lowRows = audit.TableRow(lowDistance);
highRows = audit.TableRow(highDistance);
lowPrepared = preparedPopulationTable(ismember( ...
    preparedPopulationTable.SourceTableRow, lowRows), :);
highPrepared = preparedPopulationTable(ismember( ...
    preparedPopulationTable.SourceTableRow, highRows), :);

areas = ["MT", "FST"];
unitTypes = ["2D", "3D"];
populationResults = struct();
conditionSummary = table();
aixodSummary = table();
subpopulationCounts = table();
figureFiles = struct();
for areaIndex = 1:numel(areas)
    area = areas(areaIndex);
    lowResult = RunUnifiedPopulationFromPreparedTable( ...
        lowPrepared, area, options.Monkey, "Max jump below median", ...
        FigureVisible=false);
    highResult = RunUnifiedPopulationFromPreparedTable( ...
        highPrepared, area, options.Monkey, "Max jump above median", ...
        FigureVisible=false);
    closeValidFigures([lowResult.Figure2D, lowResult.Figure3D, ...
        highResult.Figure2D, highResult.Figure3D]);
    lowResult.Figure2D = gobjects(0);
    lowResult.Figure3D = gobjects(0);
    highResult.Figure2D = gobjects(0);
    highResult.Figure3D = gobjects(0);
    populationResults.(char(area)).BelowMedian = lowResult;
    populationResults.(char(area)).AboveMedian = highResult;

    conditionSummary = [conditionSummary; ...
        tagGroup(lowResult.SummaryTable, "Below median"); ...
        tagGroup(highResult.SummaryTable, "Above median")]; %#ok<AGROW>
    aixodSummary = [aixodSummary; ...
        tagGroup(lowResult.AIxODSummaryTable, "Below median"); ...
        tagGroup(highResult.AIxODSummaryTable, "Above median")]; %#ok<AGROW>

    for typeIndex = 1:numel(unitTypes)
        unitType = unitTypes(typeIndex);
        [figureHandle, lowCount, highCount] = ...
            plotPopulationComparison(lowResult.BiasTable, ...
            highResult.BiasTable, area, unitType, options.Monkey, ...
            medianMaxJump, options.FigureVisible);
        baseName = "Population_MaxJumpMedianSplit_" + area + "_" + unitType;
        thisFiles = saveFigureSet( ...
            figureHandle, options.OutputFolder, baseName);
        closeValidFigures(figureHandle);
        figureFiles.(char(area)).(char(unitTypeField(unitType))) = thisFiles;
        subpopulationCounts = [subpopulationCounts; table( ...
            area, unitType, lowCount, highCount, ...
            'VariableNames', {'Area', 'UnitType', ...
            'BelowMedianSessions', 'AboveMedianSessions'})]; %#ok<AGROW>
    end
end

splitAudit = buildSplitAudit(audit, lowDistance, highDistance, atMedian);
writetable(splitAudit, fullfile(options.OutputFolder, ...
    'Population_MaxJumpMedianSplit_SessionAudit.csv'));
writetable(conditionSummary, fullfile(options.OutputFolder, ...
    'Population_MaxJumpMedianSplit_ConditionSummary.csv'));
writetable(aixodSummary, fullfile(options.OutputFolder, ...
    'Population_MaxJumpMedianSplit_AIxODSummary.csv'));
writetable(subpopulationCounts, fullfile(options.OutputFolder, ...
    'Population_MaxJumpMedianSplit_SubpopulationCounts.csv'));

analysis = struct();
analysis.DiscontinuityFile = options.DiscontinuityFile;
analysis.StateFile = resolvedStateFile;
analysis.OutputFolder = options.OutputFolder;
analysis.Monkey = options.Monkey;
analysis.MedianMaxAdjacentJumpSquared = medianMaxJump;
analysis.BelowMedianRows = lowRows;
analysis.AboveMedianRows = highRows;
analysis.AtMedianRows = audit.TableRow(atMedian);
analysis.SplitAudit = splitAudit;
analysis.SubpopulationCounts = subpopulationCounts;
analysis.ConditionSummary = conditionSummary;
analysis.AIxODSummary = aixodSummary;
analysis.PopulationResults = populationResults;
analysis.FigureFiles = figureFiles;
analysis.WorkbookAudit = workbookAudit;
analysis.PopulationReadout = [ ...
    "Original stimulation-channel 3DMotionQuick AI"; ...
    "Original signed maximum-response OD_max"; ...
    "Delta Bias = non-stimulation PSE minus stimulation PSE"; ...
    "Existing p_AI, behavior-fit, 2D/3D, and OD-weighted plot conventions"];
PopulationByTuningDiscontinuity = analysis;
save(fullfile(options.OutputFolder, ...
    'Population_MaxJumpMedianSplit.mat'), ...
    'PopulationByTuningDiscontinuity', '-v7.3');

disp(subpopulationCounts)
fprintf(['Population median split complete: max-jump median %.8g, ' ...
    '%d below, %d above, %d exactly at median. Outputs: %s\n'], ...
    medianMaxJump, nnz(lowDistance), nnz(highDistance), nnz(atMedian), ...
    options.OutputFolder);
end


function [figureHandle, lowCount, highCount] = plotPopulationComparison( ...
    lowBiasTable, highBiasTable, area, unitType, monkey, threshold, visible)
colors = [254 191 15; 0 0 0; 234 0 233; 110 205 221] ./ 255;
conditionNames = {'Dominant', 'Combined', 'Stereo', 'NonDominant'};
if visible
    visibility = 'on';
else
    visibility = 'off';
end
figureHandle = figure('Color', 'w', 'Visible', visibility, ...
    'Position', [100 100 1420 610], ...
    'Name', char("Max-jump median split " + area + " " + unitType));
layout = tiledlayout(figureHandle, 1, 2, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
lowAxes = nexttile(layout);
[~, lowCount] = plotPopulationPanel(lowAxes, lowBiasTable, ...
    unitType, monkey, colors, "Max jump < median");
highAxes = nexttile(layout);
[highLines, highCount] = plotPopulationPanel(highAxes, highBiasTable, ...
    unitType, monkey, colors, "Max jump > median");
linkaxes([lowAxes, highAxes], 'xy');

hold(highAxes, 'on');
legendHandles = highLines;
legendLabels = conditionNames;
if monkey == "Both"
    jim = plot(highAxes, nan, nan, 'ko', 'MarkerFaceColor', 'k', ...
        'LineStyle', 'none');
    clay = plot(highAxes, nan, nan, 'kd', 'MarkerFaceColor', 'k', ...
        'LineStyle', 'none');
    legendHandles = [legendHandles; jim; clay];
    legendLabels = [legendLabels, {'Jim', 'Clay'}];
else
    if monkey == "Clay"
        marker = 'd';
    else
        marker = 'o';
    end
    monkeyHandle = plot(highAxes, nan, nan, ['k' marker], ...
        'MarkerFaceColor', 'k', 'LineStyle', 'none');
    legendHandles = [legendHandles; monkeyHandle];
    legendLabels = [legendLabels, {char(monkey)}];
end
legendHandle = legend(highAxes, legendHandles, legendLabels, ...
    'Location', 'eastoutside');
legendHandle.Layout.Tile = 'east';
title(layout, sprintf( ...
    '%s %s neurons | maximum adjacent tuning-jump median = %.4g', ...
    area, unitType, threshold), 'FontWeight', 'bold');
end


function [lineHandles, sessionCount] = plotPopulationPanel( ...
    axesHandle, biasTable, unitType, monkey, colors, groupLabel)
selected = string(biasTable.UnitType) == unitType;
subpopulation = biasTable(selected, :);
sessionCount = numel(unique(subpopulation.SourceTableRow));
hold(axesHandle, 'on');
plot(axesHandle, [-1 1], [0 0], 'k--');
plot(axesHandle, [0 0], [-2.2 2.2], 'k--');
xPlot = -1:0.1:1;
lineHandles = gobjects(4, 1);
for condition = 1:4
    temp = subpopulation(subpopulation.Condition == condition, :);
    [slope, intercept] = weightedFitLine(temp.AI, temp.Bias, temp.OD);
    lineHandles(condition) = plot(axesHandle, xPlot, ...
        intercept + xPlot .* slope, '-', ...
        'Color', colors(condition, :), 'LineWidth', 2.5);
    plotScatter(axesHandle, temp, colors(condition, :), monkey);
end
title(axesHandle, sprintf('%s\nN = %d sessions', ...
    groupLabel, sessionCount));
xlabel(axesHandle, 'Asymmetry Index');
ylabel(axesHandle, 'Delta Bias');
axis(axesHandle, 'square');
box(axesHandle, 'on');
xlim(axesHandle, [-1 1]);
ylim(axesHandle, [-2.2 2.2]);
xticks(axesHandle, -1:0.5:1);
yticks(axesHandle, -2:1:2);
xticklabels(axesHandle, {'-1', 'Away', '0', 'Towards', '1'});
yticklabels(axesHandle, {'-2', 'Away', '0', 'Towards', '2'});
ytickangle(axesHandle, 90);
set(axesHandle, 'FontSize', 13, 'LineWidth', 1);
end


function plotScatter(axesHandle, input, color, monkeySelection)
if isempty(input)
    return
end
if monkeySelection == "Both"
    monkeyNames = ["Jim", "Clay"];
    markers = {'o', 'd'};
else
    monkeyNames = monkeySelection;
    if monkeySelection == "Clay"
        markers = {'d'};
    else
        markers = {'o'};
    end
end
for index = 1:numel(monkeyNames)
    selected = string(input.Monkey) == monkeyNames(index);
    if ~any(selected)
        continue
    end
    values = input(selected, :);
    scatterHandle = scatter(axesHandle, values.AI, values.Bias, 40, ...
        color, markers{index}, 'filled', 'MarkerEdgeColor', color, ...
        'LineWidth', 1.5);
    scatterHandle.AlphaData = values.OD;
    scatterHandle.MarkerFaceAlpha = 'flat';
end
end


function [slope, intercept] = weightedFitLine(x, y, weights)
slope = nan;
intercept = nan;
valid = isfinite(x) & isfinite(y) & isfinite(weights);
x = x(valid);
y = y(valid);
weights = weights(valid);
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


function output = tagGroup(input, group)
output = input;
output.DiscontinuityGroup = repmat(group, height(output), 1);
output = movevars(output, 'DiscontinuityGroup', 'Before', 1);
end


function output = buildSplitAudit(audit, low, high, atMedian)
output = audit(:, {'TableRow', 'Monkey', 'Date', 'ROI', ...
    'Status', 'AverageAdjacentJumpSquared', ...
    'MaxAdjacentJumpSquared', 'MaxJumpEdge'});
output.DiscontinuityGroup = repmat("Not analyzed", height(output), 1);
output.DiscontinuityGroup(low) = "Below median";
output.DiscontinuityGroup(high) = "Above median";
output.DiscontinuityGroup(atMedian) = "At median (excluded)";
output = movevars(output, 'DiscontinuityGroup', 'After', 'ROI');
end


function validateAuditMapping(audit, validMask, unitTable)
rows = audit.TableRow(validMask);
if any(rows < 1 | rows > height(unitTable) | rows ~= fix(rows))
    error('TuningDiscontinuityPopulation:InvalidTableRow', ...
        'Discontinuity audit contains invalid current unit-table rows.');
end
auditRows = find(validMask);
for index = 1:numel(rows)
    auditRow = auditRows(index);
    tableRow = rows(index);
    if ~strcmpi(getRowText(audit.Monkey, auditRow), ...
            getRowText(unitTable.Monkey, tableRow)) || ...
            ~strcmpi(getRowText(audit.ROI, auditRow), ...
            getRowText(unitTable.ROI, tableRow))
        error('TuningDiscontinuityPopulation:RowMappingChanged', ...
            ['Discontinuity row %d no longer matches the current ' ...
            'unit-table identity. Rerun the discontinuity analysis.'], ...
            tableRow);
    end
end
end


function files = saveFigureSet(figureHandle, outputFolder, baseName)
files = struct();
files.PNG = fullfile(outputFolder, baseName + ".png");
files.PDF = fullfile(outputFolder, baseName + ".pdf");
files.FIG = fullfile(outputFolder, baseName + ".fig");
exportgraphics(figureHandle, files.PNG, 'Resolution', 300);
exportgraphics(figureHandle, files.PDF, 'ContentType', 'vector');
savefig(figureHandle, files.FIG);
end


function closeValidFigures(figures)
figures = figures(isgraphics(figures));
if ~isempty(figures)
    close(figures);
end
end


function field = unitTypeField(unitType)
if unitType == "2D"
    field = "TwoD";
else
    field = "ThreeD";
end
end


function requireVariables(inputTable, required)
missing = setdiff(required, string(inputTable.Properties.VariableNames));
if ~isempty(missing)
    error('TuningDiscontinuityPopulation:MissingVariables', ...
        'Missing required variable(s): %s.', join(missing, ', '));
end
end


function value = getRowText(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
while iscell(value) && isscalar(value)
    value = value{1};
end
value = string(value);
end


function ensureFolder(folder)
if ~isfolder(folder)
    mkdir(folder);
end
end

function analysis = RunMT2DTuningDiameterAIProductScatter(options)
%RUNMT2DTUNINGDIAMETERAIPRODUCTSCATTER Relate tuning spread to AI x DeltaBias.
%
% Each point is one stimulation-channel-defined MT 2D session. The x value
% is the primary -2:+2 Quick-task window-diameter metric: the maximum
% split-averaged cross-validated squared tuning distance between included
% live contacts. The y value is stimulation-channel combined-cue AI times
% combined-cue DeltaBias (Behav_bias_NminusS, non-stimulation minus
% stimulation PSE).

arguments
    options.StateFile (1, 1) string = ...
        "C:\EM\PopulationAnalysis\unit_table_gof.mat"
    options.DiameterResultFile (1, 1) string = [ ...
        "C:\EM\StimTuningAnalysis\" + ...
        "QuickTuningWindowDiameter_Stim2D_Minus2Plus2\" + ...
        "QuickTuningWindowDiameter_Stim2D_Minus2Plus2.mat"]
    options.OutputFolder (1, 1) string = [ ...
        "C:\EM\StimTuningAnalysis\" + ...
        "MT2D_TuningDiameterMinus2Plus2_AI_DeltaBias_Product"]
    options.RequireGoodBehaviorFit (1, 1) logical = true
    options.FigureVisible (1, 1) logical = false
end

validateInputFile(options.StateFile, "state");
validateInputFile(options.DiameterResultFile, "diameter result");
ensureFolder(options.OutputFolder);

scriptFolder = string(fileparts(mfilename('fullpath')));
projectFolder = string(fileparts(scriptFolder));
addpath(fullfile(projectFolder, 'PopulationAnalysis'));
[unitTable, resolvedStateFile, workbookAudit] = ...
    LoadLatestUnitTableGof(options.StateFile);

diameterData = load(options.DiameterResultFile, ...
    'QuickTuningWindowDiameterStim2D');
if ~isfield(diameterData, 'QuickTuningWindowDiameterStim2D')
    error('MT2DTuningDiameterScatter:MissingDiameterResult', ...
        ['Diameter result does not contain ' ...
        'QuickTuningWindowDiameterStim2D: %s'], ...
        options.DiameterResultFile);
end
diameterResult = diameterData.QuickTuningWindowDiameterStim2D;
validateDiameterResult(diameterResult);
audit = diameterResult.Audit;

mtCandidate = audit.CandidateForAnalysis & strcmpi(audit.ROI, "MT");
auditRows = find(mtCandidate);
pointTable = buildPointTable(audit, auditRows, unitTable, ...
    options.RequireGoodBehaviorFit);
included = pointTable.IncludedInScatter;
if nnz(included) < 2
    error('MT2DTuningDiameterScatter:TooFewPoints', ...
        'Only %d valid MT 2D session(s) are available for the scatter.', ...
        nnz(included));
end

stats = calculateStats(pointTable(included, :));
figureHandle = plotScatter(pointTable(included, :), stats, ...
    options.FigureVisible);
baseName = fullfile(options.OutputFolder, ...
    'MT2D_TuningDiameterMinus2Plus2_vs_CombinedCueAIxDeltaBias');
exportgraphics(figureHandle, baseName + ".png", 'Resolution', 300);
exportgraphics(figureHandle, baseName + ".pdf", 'ContentType', 'vector');
savefig(figureHandle, baseName + ".fig");
if ~options.FigureVisible
    close(figureHandle);
end

writetable(pointTable, fullfile(options.OutputFolder, ...
    'MT2D_TuningDiameterMinus2Plus2_AI_DeltaBias_Product_Points.csv'));
writetable(stats, fullfile(options.OutputFolder, ...
    'MT2D_TuningDiameterMinus2Plus2_AI_DeltaBias_Product_Statistics.csv'));

analysis = struct();
analysis.StateFile = string(resolvedStateFile);
analysis.DiameterResultFile = options.DiameterResultFile;
analysis.OutputFolder = options.OutputFolder;
analysis.RelativePositions = diameterResult.RelativePositions;
analysis.RequireGoodBehaviorFit = options.RequireGoodBehaviorFit;
analysis.PointTable = pointTable;
analysis.Statistics = stats;
analysis.WorkbookAudit = workbookAudit;
analysis.XDefinition = [ ...
    "WindowDiameterSquared"; ...
    "Physical positions -2 through +2"; ...
    "Maximum split-averaged cross-validated squared tuning distance"];
analysis.YDefinition = [ ...
    "CombinedCueAI * DeltaBias"; ...
    "CombinedCueAI = AI{row}(1, StimElec)"; ...
    "DeltaBias = Behav_bias_NminusS{row}(1)"];
MT2DTuningDiameterAIProductScatter = analysis;
save(fullfile(options.OutputFolder, ...
    'MT2D_TuningDiameterMinus2Plus2_AI_DeltaBias_Product.mat'), ...
    'MT2DTuningDiameterAIProductScatter', '-v7.3');

disp(stats)
fprintf('MT 2D diameter-product scatter (%d sessions) saved to %s\n', ...
    nnz(included), options.OutputFolder);
end


function validateInputFile(fileName, description)
if ~isfile(fileName)
    error('MT2DTuningDiameterScatter:MissingInput', ...
        'The %s file does not exist: %s', description, fileName);
end
end


function validateDiameterResult(result)
requiredFields = ["Audit", "RelativePositions"];
missing = requiredFields(~isfield(result, requiredFields));
if ~isempty(missing)
    error('MT2DTuningDiameterScatter:InvalidDiameterResult', ...
        'Diameter result is missing field(s): %s.', join(missing, ', '));
end
if ~isequal(double(result.RelativePositions(:))', -2:2)
    error('MT2DTuningDiameterScatter:WrongWindow', ...
        'Expected a -2:+2 diameter result, but found positions %s.', ...
        mat2str(result.RelativePositions));
end
requiredVariables = ["TableRow", "Monkey", "Date", "ROI", ...
    "CandidateForAnalysis", "StimChannel", "Status", ...
    "WindowDiameterSquared", "WindowDiameter"];
missing = setdiff(requiredVariables, ...
    string(result.Audit.Properties.VariableNames));
if ~isempty(missing)
    error('MT2DTuningDiameterScatter:InvalidDiameterAudit', ...
        'Diameter audit is missing variable(s): %s.', join(missing, ', '));
end
end


function output = buildPointTable(audit, auditRows, unitTable, requireGoodFit)
rowCount = numel(auditRows);
DiameterAuditRow = auditRows;
SourceTableRow = nan(rowCount, 1);
Monkey = strings(rowCount, 1);
Date = strings(rowCount, 1);
ROI = strings(rowCount, 1);
StimChannel = nan(rowCount, 1);
DiameterStatus = strings(rowCount, 1);
WindowDiameterSquared = nan(rowCount, 1);
WindowDiameter = nan(rowCount, 1);
CombinedCueAI = nan(rowCount, 1);
DeltaBias = nan(rowCount, 1);
AIxDeltaBias = nan(rowCount, 1);
BehaviorGoodFit = false(rowCount, 1);
IncludedInScatter = false(rowCount, 1);
ExclusionReason = strings(rowCount, 1);

for index = 1:rowCount
    auditRow = auditRows(index);
    Monkey(index) = string(audit.Monkey(auditRow));
    Date(index) = string(audit.Date(auditRow));
    ROI(index) = string(audit.ROI(auditRow));
    StimChannel(index) = audit.StimChannel(auditRow);
    DiameterStatus(index) = string(audit.Status(auditRow));
    WindowDiameterSquared(index) = audit.WindowDiameterSquared(auditRow);
    WindowDiameter(index) = audit.WindowDiameter(auditRow);

    sourceRow = resolveSourceRow(unitTable, audit, auditRow);
    if ~isfinite(sourceRow)
        ExclusionReason(index) = "could not match source-table session";
        continue
    end
    SourceTableRow(index) = sourceRow;
    ai = numericArray(unitTable.AI, sourceRow);
    bias = numericArray(unitTable.Behav_bias_NminusS, sourceRow);
    goodFit = numericArray(unitTable.Behav_goodfit_both, sourceRow);
    stim = StimChannel(index);
    if size(ai, 1) >= 1 && isfinite(stim) && stim >= 1 && ...
            stim <= size(ai, 2)
        CombinedCueAI(index) = ai(1, stim);
    end
    if ~isempty(bias)
        DeltaBias(index) = bias(1);
    end
    if ~isempty(goodFit)
        BehaviorGoodFit(index) = logical(goodFit(1));
    end
    AIxDeltaBias(index) = CombinedCueAI(index) .* DeltaBias(index);

    if DiameterStatus(index) ~= "Success" || ...
            ~isfinite(WindowDiameterSquared(index))
        ExclusionReason(index) = "diameter calculation unsuccessful";
    elseif ~isfinite(CombinedCueAI(index))
        ExclusionReason(index) = "nonfinite combined-cue AI";
    elseif ~isfinite(DeltaBias(index))
        ExclusionReason(index) = "nonfinite combined-cue DeltaBias";
    elseif requireGoodFit && ~BehaviorGoodFit(index)
        ExclusionReason(index) = "combined-cue behavior fit not good";
    else
        IncludedInScatter(index) = true;
        ExclusionReason(index) = "";
    end
end

output = table(DiameterAuditRow, SourceTableRow, Monkey, Date, ROI, ...
    StimChannel, DiameterStatus, WindowDiameterSquared, WindowDiameter, ...
    CombinedCueAI, DeltaBias, AIxDeltaBias, BehaviorGoodFit, ...
    IncludedInScatter, ExclusionReason);
end


function sourceRow = resolveSourceRow(unitTable, audit, auditRow)
sourceRow = NaN;
suggestedRow = audit.TableRow(auditRow);
if isfinite(suggestedRow) && suggestedRow >= 1 && ...
        suggestedRow <= height(unitTable) && ...
        sessionMatches(unitTable, suggestedRow, audit, auditRow)
    sourceRow = suggestedRow;
    return
end

matches = false(height(unitTable), 1);
for row = 1:height(unitTable)
    matches(row) = sessionMatches(unitTable, row, audit, auditRow);
end
matchedRows = find(matches);
if isscalar(matchedRows)
    sourceRow = matchedRows;
end
end


function tf = sessionMatches(unitTable, row, audit, auditRow)
tf = strcmpi(getRowText(unitTable.Monkey, row), ...
        string(audit.Monkey(auditRow))) && ...
    strcmpi(getRowText(unitTable.ROI, row), ...
        string(audit.ROI(auditRow))) && ...
    dateKey(unitTable.Date, row) == dateKey(audit.Date, auditRow);
if tf && isfinite(audit.StimChannel(auditRow))
    stim = numericArray(unitTable.StimElec, row);
    tf = isscalar(stim) && stim == audit.StimChannel(auditRow);
end
end


function key = dateKey(column, row)
value = rowValue(column, row);
if isdatetime(value)
    key = string(value, 'yyyyMMdd');
elseif isnumeric(value)
    key = string(value(1), '%.12g');
else
    key = string(value);
end
end


function value = numericArray(column, row)
value = rowValue(column, row);
value = double(value);
end


function value = getRowText(column, row)
value = string(rowValue(column, row));
end


function value = rowValue(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
while iscell(value) && isscalar(value)
    value = value{1};
end
end


function stats = calculateStats(points)
x = points.WindowDiameterSquared;
y = points.AIxDeltaBias;
[PearsonR, PearsonP] = corr(x, y, 'Rows', 'complete');
coefficients = polyfit(x, y, 1);
Slope = coefficients(1);
Intercept = coefficients(2);
RSquared = PearsonR .^ 2;
N = height(points);
JimN = nnz(strcmpi(points.Monkey, "Jim"));
ClayN = nnz(strcmpi(points.Monkey, "Clay"));
stats = table(N, JimN, ClayN, PearsonR, PearsonP, RSquared, ...
    Slope, Intercept);
end


function figureHandle = plotScatter(points, stats, visible)
if visible
    visibility = 'on';
else
    visibility = 'off';
end
figureHandle = figure('Color', 'w', 'Visible', visibility, ...
    'Position', [100 100 850 650], ...
    'Name', 'MT 2D tuning diameter versus AI x DeltaBias');
axesHandle = axes(figureHandle);
hold(axesHandle, 'on');

monkeys = ["Jim", "Clay"];
colors = [0.12 0.43 0.75; 0.88 0.36 0.16];
markers = {'o', '^'};
scatterHandles = gobjects(1, numel(monkeys));
legendLabels = strings(1, numel(monkeys));
hasMonkey = false(1, numel(monkeys));
for index = 1:numel(monkeys)
    selected = strcmpi(points.Monkey, monkeys(index));
    if ~any(selected)
        continue
    end
    hasMonkey(index) = true;
    scatterHandles(index) = scatter(axesHandle, ...
        points.WindowDiameterSquared(selected), ...
        points.AIxDeltaBias(selected), 54, colors(index, :), ...
        markers{index}, 'filled', 'MarkerFaceAlpha', 0.78, ...
        'MarkerEdgeColor', 'w', 'LineWidth', 0.6);
    legendLabels(index) = sprintf('%s (N = %d)', ...
        monkeys(index), nnz(selected));
end
scatterHandles = scatterHandles(hasMonkey);
legendLabels = legendLabels(hasMonkey);

xLimits = paddedLimits(points.WindowDiameterSquared, 0.06, true);
yLimits = paddedLimits(points.AIxDeltaBias, 0.10, false);
xFit = linspace(xLimits(1), xLimits(2), 200);
yFit = stats.Intercept + stats.Slope .* xFit;
fitHandle = plot(axesHandle, xFit, yFit, '-', ...
    'Color', [0.15 0.15 0.15], 'LineWidth', 1.6);
yline(axesHandle, 0, ':', 'Color', [0.45 0.45 0.45], ...
    'HandleVisibility', 'off');
xlim(axesHandle, xLimits);
ylim(axesHandle, yLimits);

xlabel(axesHandle, [ ...
    'Tuning window diameter, positions -2 to +2 ' ...
    '(maximum CV squared distance)']);
ylabel(axesHandle, 'Combined-cue AI \times DeltaBias');
title(axesHandle, sprintf([ ...
    'MT 2D sessions: tuning diameter versus AI x DeltaBias\n' ...
    'Pearson r = %.3f, p = %.3g, N = %d'], ...
    stats.PearsonR, stats.PearsonP, stats.N));
legend(axesHandle, [scatterHandles, fitHandle], ...
    [cellstr(legendLabels(:)); {'Linear fit'}], 'Location', 'best');
grid(axesHandle, 'on');
axesHandle.Box = 'off';
axesHandle.TickDir = 'out';
axesHandle.FontSize = 11;
end


function limits = paddedLimits(values, fraction, anchorAtZero)
low = min(values, [], 'omitmissing');
high = max(values, [], 'omitmissing');
span = high - low;
if ~(isfinite(span) && span > 0)
    span = max(abs([low, high, 1]));
end
padding = fraction .* span;
limits = [low - padding, high + padding];
if anchorAtZero && low >= 0
    limits(1) = 0;
end
if limits(1) == limits(2)
    limits = limits + [-0.5, 0.5];
end
end


function ensureFolder(folder)
if ~isfolder(folder)
    mkdir(folder);
end
end

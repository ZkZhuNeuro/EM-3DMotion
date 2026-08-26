function analysis = RunAdjacentQuickTuningDiscontinuity(options)
%RUNADJACENTQUICKTUNINGDISCONTINUITY Analyze full-curve five-contact change.
%
% The default cohort matches the five-channel population gate: MT/FST
% sessions with significant MonoL and MonoR Quick-task tuning in the source
% table. The analysis calculates noise-unbiased, cross-validated squared
% tuning distances across the four physical gaps in
% (-2,-1,stim,+1,+2), then plots the distributions of their session-level
% mean and maximum.

arguments
    options.StateFile (1, 1) string = ...
        "C:\EM\PopulationAnalysis\unit_table_gof.mat"
    options.OutputFolder (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\AdjacentFullTuningDiscontinuity"
    options.Areas (1, :) string = ["MT", "FST"]
    options.Monkey (1, 1) string ...
        {mustBeMember(options.Monkey, ["Both", "Jim", "Clay"])} = "Both"
    options.NumSplits (1, 1) double ...
        {mustBeInteger, mustBePositive} = 200
    options.MinTrialsPerCondition (1, 1) double ...
        {mustBeInteger, mustBeGreaterThanOrEqual( ...
        options.MinTrialsPerCondition, 2)} = 2
    options.RandomSeed (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 1
    options.FigureVisible (1, 1) logical = false
    options.JimCacheFolder (1, 1) string = "C:\Jim\StimData"
    options.ClayCacheFolder (1, 1) string = "C:\Clay\StimData"
    options.ChannelMap (1, :) double ...
        {mustBeInteger, mustBePositive} = ...
        [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]
end

if ~isfile(options.StateFile)
    error('AdjacentTuningDiscontinuity:MissingStateFile', ...
        'Input MAT file does not exist: %s', options.StateFile);
end
areas = unique(upper(options.Areas), 'stable');
if isempty(areas) || any(~ismember(areas, ["MT", "FST"]))
    error('AdjacentTuningDiscontinuity:InvalidAreas', ...
        'Areas must contain MT, FST, or both.');
end
ensureFolder(options.OutputFolder);
scriptFolder = string(fileparts(mfilename('fullpath')));
projectFolder = string(fileparts(scriptFolder));
addpath(scriptFolder, fullfile(projectFolder, 'PopulationAnalysis'));

[unitTable, resolvedStateFile, workbookAudit] = ...
    LoadLatestUnitTableGof(options.StateFile);
candidateMask = populationCandidateMask(unitTable, areas, options.Monkey);
audit = ComputeAdjacentQuickTuningDiscontinuity(unitTable, ...
    JimCacheFolder=options.JimCacheFolder, ...
    ClayCacheFolder=options.ClayCacheFolder, ...
    ChannelMap=options.ChannelMap, CandidateMask=candidateMask, ...
    NumSplits=options.NumSplits, ...
    MinTrialsPerCondition=options.MinTrialsPerCondition, ...
    RandomSeed=options.RandomSeed);
successfulMask = audit.Status == "Success" & ...
    isfinite(audit.AverageAdjacentJumpSquared) & ...
    isfinite(audit.MaxAdjacentJumpSquared);
if ~any(successfulMask)
    error('AdjacentTuningDiscontinuity:NoSuccessfulSessions', ...
        'No candidate session had a complete analyzable five-contact set.');
end

scalarAudit = scalarAuditTable(audit);
summaryTable = summarizeDistribution(audit, successfulMask);
breakdownTable = summarizeBreakdown(audit, candidateMask, successfulMask);
writetable(scalarAudit, fullfile(options.OutputFolder, ...
    'AdjacentFullTuningDiscontinuity_SessionAudit.csv'));
writetable(summaryTable, fullfile(options.OutputFolder, ...
    'AdjacentFullTuningDiscontinuity_DistributionSummary.csv'));
writetable(breakdownTable, fullfile(options.OutputFolder, ...
    'AdjacentFullTuningDiscontinuity_CohortBreakdown.csv'));

previousVisibility = get(groot, 'defaultFigureVisible');
visibilityCleanup = onCleanup( ...
    @() set(groot, 'defaultFigureVisible', previousVisibility));
set(groot, 'defaultFigureVisible', ternary( ...
    options.FigureVisible, 'on', 'off'));
histogramFigure = plotDiscontinuityHistograms( ...
    audit(successfulMask, :));
baseName = fullfile(options.OutputFolder, ...
    'AdjacentFullTuningDiscontinuity_Histograms');
exportgraphics(histogramFigure, baseName + ".png", 'Resolution', 300);
exportgraphics(histogramFigure, baseName + ".pdf", ...
    'ContentType', 'vector');
savefig(histogramFigure, baseName + ".fig");
if ~options.FigureVisible
    close(histogramFigure);
end
clear visibilityCleanup

analysis = struct();
analysis.StateFile = resolvedStateFile;
analysis.OutputFolder = options.OutputFolder;
analysis.Areas = areas;
analysis.Monkey = options.Monkey;
analysis.NumSplits = options.NumSplits;
analysis.MinTrialsPerCondition = options.MinTrialsPerCondition;
analysis.RandomSeed = options.RandomSeed;
analysis.CandidateMask = candidateMask;
analysis.SuccessfulMask = successfulMask;
analysis.Audit = audit;
analysis.DistributionSummary = summaryTable;
analysis.CohortBreakdown = breakdownTable;
analysis.WorkbookAudit = workbookAudit;
analysis.Method = [ ...
    "Five physical contacts at offsets -2,-1,0,+1,+2"; ...
    "Every available Quick-task cue-by-coherence condition is equally weighted"; ...
    "Each channel is z-scored once across common-valid trials from all conditions"; ...
    "Adjacent change is cross-validated squared Euclidean tuning distance"; ...
    "Average jump is the mean of four adjacent distances"; ...
    "Maximum jump is the largest of four adjacent distances"; ...
    "Negative estimates are retained because zero-distance estimates are noise-unbiased"];
AdjacentFullTuningDiscontinuity = analysis;
save(fullfile(options.OutputFolder, ...
    'AdjacentFullTuningDiscontinuity.mat'), ...
    'AdjacentFullTuningDiscontinuity', '-v7.3');

disp(summaryTable)
disp(breakdownTable)
fprintf('Adjacent full-tuning discontinuity saved to %s\n', ...
    options.OutputFolder);
end


function figureHandle = plotDiscontinuityHistograms(audit)
averageValues = audit.AverageAdjacentJumpSquared;
maximumValues = audit.MaxAdjacentJumpSquared;
edges = commonHistogramEdges([averageValues; maximumValues]);
figureHandle = figure('Color', 'w', 'Position', [100 100 1120 470]);
layout = tiledlayout(figureHandle, 1, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');

averageAxes = nexttile(layout);
histogram(averageAxes, averageValues, 'BinEdges', edges, ...
    'FaceColor', [0.15 0.45 0.75], 'EdgeColor', 'none');
formatHistogramAxes(averageAxes, averageValues, ...
    'Mean adjacent jump');
ylabel(averageAxes, 'Sessions');

maximumAxes = nexttile(layout);
histogram(maximumAxes, maximumValues, 'BinEdges', edges, ...
    'FaceColor', [0.85 0.35 0.20], 'EdgeColor', 'none');
formatHistogramAxes(maximumAxes, maximumValues, ...
    'Maximum adjacent jump');

xlabel(layout, 'Cross-validated squared tuning distance (z^2 / condition)');
title(layout, sprintf( ...
    'Full Quick-task tuning change across five adjacent contacts (N = %d)', ...
    height(audit)), 'FontWeight', 'bold');
end


function formatHistogramAxes(axesHandle, values, label)
hold(axesHandle, 'on');
medianValue = median(values);
xline(axesHandle, 0, ':', 'Zero', 'Color', [0.25 0.25 0.25], ...
    'LabelVerticalAlignment', 'bottom');
xline(axesHandle, medianValue, '-', ...
    sprintf('Median %.3g', medianValue), ...
    'Color', [0.1 0.1 0.1], 'LineWidth', 1.25, ...
    'LabelVerticalAlignment', 'top');
title(axesHandle, sprintf('%s\nN = %d', label, numel(values)));
grid(axesHandle, 'on');
axesHandle.Box = 'off';
axesHandle.TickDir = 'out';
axesHandle.YGrid = 'on';
axesHandle.XGrid = 'off';
end


function edges = commonHistogramEdges(values)
values = values(isfinite(values));
low = min([0; values]);
high = max([0; values]);
if high <= low
    padding = max(abs(low) * 0.1, 0.1);
    low = low - padding;
    high = high + padding;
end
edges = linspace(low, high, 21);
end


function output = scalarAuditTable(audit)
output = audit(:, {'TableRow', 'Monkey', 'Date', 'ROI', ...
    'CandidateForAnalysis', 'StimChannel', 'StimProbePosition', ...
    'Minus2Channel', 'Minus1Channel', 'Plus1Channel', 'Plus2Channel', ...
    'ConditionCount', 'MinimumTrialCount', 'NumSplits', ...
    'Minus2ToMinus1JumpSquared', 'Minus1ToStimJumpSquared', ...
    'StimToPlus1JumpSquared', 'Plus1ToPlus2JumpSquared', ...
    'AverageAdjacentJumpSquared', 'MaxAdjacentJumpSquared', ...
    'MaxJumpEdge', 'CacheFile', 'Status', 'Message'});
for cue = 1:4
    output.(sprintf('Cue%dAverageJumpSquared', cue)) = ...
        cueCellValue(audit.CueAverageAdjacentJumpSquared, cue);
    output.(sprintf('Cue%dMaxJumpSquared', cue)) = ...
        cueCellValue(audit.CueMaxAdjacentJumpSquared, cue);
end
end


function values = cueCellValue(input, cue)
values = nan(numel(input), 1);
for row = 1:numel(input)
    thisValue = input{row};
    if numel(thisValue) >= cue
        values(row) = thisValue(cue);
    end
end
end


function output = summarizeDistribution(audit, successfulMask)
metric = ["Average adjacent jump"; "Maximum adjacent jump"];
values = {audit.AverageAdjacentJumpSquared(successfulMask); ...
    audit.MaxAdjacentJumpSquared(successfulMask)};
sessionCount = repmat(nnz(successfulMask), 2, 1);
meanValue = nan(2, 1);
standardDeviation = nan(2, 1);
medianValue = nan(2, 1);
quartile25 = nan(2, 1);
quartile75 = nan(2, 1);
minimumValue = nan(2, 1);
maximumValue = nan(2, 1);
for index = 1:2
    thisValue = values{index};
    meanValue(index) = mean(thisValue);
    standardDeviation(index) = std(thisValue);
    medianValue(index) = median(thisValue);
    quartile25(index) = prctile(thisValue, 25);
    quartile75(index) = prctile(thisValue, 75);
    minimumValue(index) = min(thisValue);
    maximumValue(index) = max(thisValue);
end
output = table(metric, sessionCount, meanValue, standardDeviation, ...
    medianValue, quartile25, quartile75, minimumValue, maximumValue, ...
    'VariableNames', {'Metric', 'SessionCount', 'Mean', ...
    'StandardDeviation', 'Median', 'Quartile25', 'Quartile75', ...
    'Minimum', 'Maximum'});
end


function output = summarizeBreakdown(audit, candidateMask, successfulMask)
groups = ["All"; "MT"; "FST"; "Jim"; "Clay"];
output = table();
for index = 1:numel(groups)
    group = groups(index);
    switch group
        case "All"
            groupMask = true(height(audit), 1);
        case {"MT", "FST"}
            groupMask = strcmpi(audit.ROI, group);
        otherwise
            groupMask = strcmpi(audit.Monkey, group);
    end
    candidate = groupMask & candidateMask;
    success = groupMask & successfulMask;
    errors = candidate & audit.Status == "Error";
    row = table(group, nnz(candidate), nnz(success), nnz(errors), ...
        mean(audit.AverageAdjacentJumpSquared(success), 'omitmissing'), ...
        median(audit.AverageAdjacentJumpSquared(success), 'omitmissing'), ...
        mean(audit.MaxAdjacentJumpSquared(success), 'omitmissing'), ...
        median(audit.MaxAdjacentJumpSquared(success), 'omitmissing'), ...
        'VariableNames', {'Group', 'CandidateSessions', ...
        'SuccessfulSessions', 'ErrorSessions', 'MeanAverageJumpSquared', ...
        'MedianAverageJumpSquared', 'MeanMaxJumpSquared', ...
        'MedianMaxJumpSquared'});
    output = [output; row]; %#ok<AGROW>
end
end


function mask = populationCandidateMask(unitTable, areas, monkey)
required = ["ROI", "Monkey", "p_AI"];
missing = setdiff(required, string(unitTable.Properties.VariableNames));
if ~isempty(missing)
    error('AdjacentTuningDiscontinuity:MissingSelectionVariables', ...
        'Missing population-selection variable(s): %s.', join(missing, ', '));
end
mask = false(height(unitTable), 1);
for row = 1:height(unitTable)
    roi = getRowText(unitTable.ROI, row);
    monkeyName = getRowText(unitTable.Monkey, row);
    if ~ismember(upper(roi), areas) || ...
            (monkey ~= "Both" && ~strcmpi(monkeyName, monkey))
        continue
    end
    pValues = numericArray(unitTable.p_AI, row);
    mask(row) = numel(pValues) >= 3 && ...
        all(isfinite(pValues(2:3))) && all(pValues(2:3) < 0.05);
end
end


function value = numericArray(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
while iscell(value) && isscalar(value)
    value = value{1};
end
value = double(value);
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


function output = ternary(condition, trueValue, falseValue)
if condition
    output = trueValue;
else
    output = falseValue;
end
end

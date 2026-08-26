function result = PlotGaussianMetaVsStimSessionTunings(options)
%PLOTGAUSSIANMETAVSSTIMSESSIONTUNINGS Audit stim versus meta classification.
%
% The plotted cohort is the union of sessions passing either the stored
% stimulation-channel monocular tuning criterion or the trial-level
% Gaussian-meta monocular tuning criterion. Each session page shows raw
% Quick tuning curves for the stimulation channel and the matching raw-FR
% Gaussian meta curve. Both panels are labeled 2D, 3D, or No tuning.

arguments
    options.ResultFile (1, 1) string = [ ...
        "C:\EM\StimTuningAnalysis\" + ...
        "GaussianAllChannelMeta_Adjacent4AIContinuity\" + ...
        "GaussianAllChannelMeta_AdjacentAICleanupResults.mat"]
    options.OutputFolder (1, 1) string = ""
    options.SigmaSource (1, 1) string ...
        {mustBeMember(options.SigmaSource, ...
        ["FullFit", "FilteredRefit"])} = "FullFit"
    options.Areas (1, :) string = ["MT", "FST"]
    options.Monkey (1, 1) string ...
        {mustBeMember(options.Monkey, ["Both", "Jim", "Clay"])} = "Both"
    options.TuningAlpha (1, 1) double ...
        {mustBeGreaterThan(options.TuningAlpha, 0), ...
        mustBeLessThan(options.TuningAlpha, 1)} = 0.05
    options.ExcludeDiscontinuous (1, 1) logical = true
    options.FigureVisible (1, 1) logical = false
    options.JimCacheFolder (1, 1) string = "C:\Jim\StimData"
    options.ClayCacheFolder (1, 1) string = "C:\Clay\StimData"
end

if ~isfile(options.ResultFile)
    error('StimMetaTuningPlots:MissingResult', ...
        'Result MAT file does not exist: %s', options.ResultFile);
end
loaded = load(options.ResultFile, 'population_analysis');
sourceAnalysis = loaded.population_analysis;
if options.SigmaSource == "FullFit"
    sigma = sourceAnalysis.FullFit.bestSigma;
    sigmaLabel = "full-cohort fitted";
else
    sigma = sourceAnalysis.FilteredFit.bestSigma;
    sigmaLabel = "continuity-filtered refit";
end
if ~isfinite(sigma) || sigma <= 0
    error('StimMetaTuningPlots:InvalidSigma', ...
        'The selected result does not contain a finite positive sigma.');
end

rootFolder = string(fileparts(options.ResultFile));
if strlength(options.OutputFolder) == 0
    sigmaToken = replace(sprintf('%.4f', sigma), '.', 'p');
    filterToken = ternary(options.ExcludeDiscontinuous, ...
        "ContinuityFiltered", "AllSessions");
    options.OutputFolder = fullfile(rootFolder, ...
        "SessionTuningDiagnostics_StimVsMeta_Sigma" + sigmaToken + ...
        "_" + filterToken);
end
ensureFolder(options.OutputFolder);

scriptFolder = string(fileparts(mfilename('fullpath')));
projectFolder = string(fileparts(scriptFolder));
addpath(scriptFolder, fullfile(projectFolder, 'PopulationAnalysis'));
[unitTable, resolvedStateFile, workbookAudit] = ...
    LoadLatestUnitTableGof(sourceAnalysis.StateFile);

areas = unique(upper(options.Areas), 'stable');
candidateMask = areaMonkeyMask(unitTable, areas, options.Monkey);
excludedMask = ismember((1:height(unitTable))', ...
    sourceAnalysis.ExcludedOriginalRows);
if options.ExcludeDiscontinuous
    candidateMask = candidateMask & ~excludedMask;
end

[~, metaEligible, audit] = BuildEqualFiveChannelMetaQuickAI( ...
    unitTable, JimCacheFolder=options.JimCacheFolder, ...
    ClayCacheFolder=options.ClayCacheFolder, ...
    CandidateMask=candidateMask, WeightingMode="GaussianAll", ...
    GaussianSigma=sigma);

numRows = height(unitTable);
stimPLeft = nan(numRows, 1);
stimPRight = nan(numRows, 1);
stimClass = repmat("No tuning", numRows, 1);
metaClass = repmat("No tuning", numRows, 1);
for row = find(candidateMask)'
    [stimPLeft(row), stimPRight(row)] = storedPerspectivePValues( ...
        unitTable, row);
    stimClass(row) = classifyTuning(stimPLeft(row), ...
        stimPRight(row), audit.OriginalZ3DMinusZ2D(row), ...
        options.TuningAlpha);
    if metaEligible(row)
        metaClass(row) = classifyTuning(audit.MetaPLeft(row), ...
            audit.MetaPRight(row), audit.MetaZ3DMinusZ2D(row), ...
            options.TuningAlpha);
    end
end

includedByStim = candidateMask & stimClass ~= "No tuning";
includedByMeta = candidateMask & metaClass ~= "No tuning";
includedUnion = includedByStim | includedByMeta;
plotRows = find(includedUnion);

combination = stimClass + " -> " + metaClass;
priority = combinationPriority(stimClass, metaClass);
[~, order] = sortrows([priority(plotRows), plotRows], [1 2]);
plotRows = plotRows(order);

outputFile = strings(numRows, 1);
groupFolder = strings(numRows, 1);
pdfFile = fullfile(options.OutputFolder, ...
    'StimVsGaussianMeta_AllIncludedSessions.pdf');
if isfile(pdfFile)
    delete(pdfFile);
end

previousVisibility = get(groot, 'defaultFigureVisible');
visibilityCleanup = onCleanup( ...
    @() set(groot, 'defaultFigureVisible', previousVisibility));
set(groot, 'defaultFigureVisible', ternary( ...
    options.FigureVisible, 'on', 'off'));

for plotIndex = 1:numel(plotRows)
    row = plotRows(plotIndex);
    thisGroup = classificationFolder(stimClass(row), metaClass(row));
    thisFolder = fullfile(options.OutputFolder, thisGroup);
    ensureFolder(thisFolder);
    dateToken = string(audit.Date(row), 'yyyyMMdd');
    baseName = sprintf('%03d_row%03d_%s_%s_%s_stim-%s_meta-%s', ...
        plotIndex, row, sanitizeToken(audit.Monkey(row)), dateToken, ...
        sanitizeToken(audit.ROI(row)), ...
        sanitizeToken(stimClass(row)), sanitizeToken(metaClass(row)));
    outputFile(row) = fullfile(thisFolder, baseName + ".png");
    groupFolder(row) = thisGroup;

    figureHandle = figure('Color', 'w', ...
        'Position', [80 100 1660 690]);
    layout = tiledlayout(figureHandle, 1, 2, ...
        'TileSpacing', 'compact', 'Padding', 'compact');
    stimAxes = nexttile(layout);
    metaAxes = nexttile(layout);
    coherence = audit.Coherence{row};
    plotTuningPanel(stimAxes, coherence, audit.StimMean{row}, ...
        audit.StimSEM{row}, sprintf([ ...
        'Stimulation channel %d: %s\np_L=%s, p_R=%s, Z_{3D}-Z_{2D}=%s'], ...
        audit.StimChannel(row), stimClass(row), ...
        formatNumber(stimPLeft(row)), formatNumber(stimPRight(row)), ...
        formatNumber(audit.OriginalZ3DMinusZ2D(row))));
    plotTuningPanel(metaAxes, coherence, audit.MetaRawMean{row}, ...
        audit.MetaRawSEM{row}, sprintf([ ...
        'Gaussian meta (sigma %.4g): %s\np_L=%s, p_R=%s, Z_{3D}-Z_{2D}=%s'], ...
        sigma, metaClass(row), formatNumber(audit.MetaPLeft(row)), ...
        formatNumber(audit.MetaPRight(row)), ...
        formatNumber(audit.MetaZ3DMinusZ2D(row))));
    synchronizeYLimits(stimAxes, metaAxes);
    legend(metaAxes, 'Location', 'eastoutside');
    continuityText = ternary(excludedMask(row), ...
        "four-neighbor discontinuous", "four-neighbor retained");
    title(layout, sprintf([ ...
        'Row %d | %s | %s | %s | stim %d | %s | %s Gaussian sigma %.4g'], ...
        row, audit.Monkey(row), string(audit.Date(row), 'yyyy-MM-dd'), ...
        audit.ROI(row), audit.StimChannel(row), continuityText, ...
        sigmaLabel, sigma), 'Interpreter', 'none');
    exportgraphics(figureHandle, outputFile(row), 'Resolution', 220);
    exportgraphics(figureHandle, pdfFile, 'Append', plotIndex > 1, ...
        'ContentType', 'vector');
    close(figureHandle);
end
clear visibilityCleanup

summaryTable = buildSummaryTable(unitTable, audit, candidateMask, ...
    excludedMask, metaEligible, stimPLeft, stimPRight, stimClass, ...
    metaClass, includedByStim, includedByMeta, includedUnion, ...
    combination, groupFolder, outputFile, sigma);
writetable(summaryTable, fullfile(options.OutputFolder, ...
    'StimVsGaussianMeta_SessionClassification.csv'));

transitionTable = buildTransitionTable( ...
    stimClass(includedUnion), metaClass(includedUnion));
writetable(transitionTable, fullfile(options.OutputFolder, ...
    'StimVsGaussianMeta_ClassTransitions.csv'));
summaryFigure = saveTransitionFigure(transitionTable, ...
    options.OutputFolder, sigma, nnz(includedUnion));
close(summaryFigure);

definition = [ ...
    "Plotted sessions are the union passing either criterion."; ...
    "Stimulation criterion: stored monocular p_AI(2) and p_AI(3) are both below alpha; stored stimulation Z3D-Z2D sign assigns 2D (<0) or 3D (>0)."; ...
    "Meta criterion: both monocular raw Gaussian-meta trial-level direction p-values are below alpha; raw Gaussian-meta Z3D-Z2D sign assigns 2D (<0) or 3D (>0)."; ...
    "No tuning: either monocular p-value fails, or Z3D-Z2D is zero/nonfinite."; ...
    "Meta AI is not used for these diagnostic classifications."; ...
    "All live channels contribute; Gaussian weights are renormalized within each session."];
writelines(definition, fullfile(options.OutputFolder, ...
    'ClassificationDefinitions.txt'));

result = struct();
result.ResultFile = options.ResultFile;
result.StateFile = resolvedStateFile;
result.OutputFolder = options.OutputFolder;
result.Sigma = sigma;
result.SigmaSource = options.SigmaSource;
result.TuningAlpha = options.TuningAlpha;
result.ExcludeDiscontinuous = options.ExcludeDiscontinuous;
result.CandidateCount = nnz(candidateMask);
result.MetaEligibleCount = nnz(metaEligible);
result.StimCriterionCount = nnz(includedByStim);
result.MetaCriterionCount = nnz(includedByMeta);
result.UnionCount = nnz(includedUnion);
result.SessionSummary = summaryTable;
result.TransitionTable = transitionTable;
result.MetaAudit = audit;
result.WorkbookAudit = workbookAudit;
result.Definition = definition;
session_tuning_diagnostics = result;
save(fullfile(options.OutputFolder, ...
    'StimVsGaussianMeta_SessionTuningDiagnostics.mat'), ...
    'session_tuning_diagnostics', '-v7.3');

fprintf(['Created %d stimulation-versus-meta tuning pages. ' ...
    'Stim criterion: %d; meta criterion: %d; union: %d. Folder: %s\n'], ...
    numel(plotRows), nnz(includedByStim), nnz(includedByMeta), ...
    nnz(includedUnion), options.OutputFolder);
end


function mask = areaMonkeyMask(unitTable, areas, monkey)
mask = ismember(upper(string(unitTable.ROI)), areas);
if monkey ~= "Both"
    mask = mask & strcmpi(string(unitTable.Monkey), monkey);
end
end


function [pLeft, pRight] = storedPerspectivePValues(unitTable, row)
pLeft = NaN;
pRight = NaN;
value = rowValue(unitTable.p_AI, row);
while iscell(value) && isscalar(value)
    value = value{1};
end
if ~isnumeric(value) || isempty(value)
    return
end
value = double(value);
stimChannel = double(unitTable.StimElec(row));
if size(value, 1) >= 3
    column = 1;
    if size(value, 2) >= stimChannel
        column = stimChannel;
    end
    pLeft = value(2, column);
    pRight = value(3, column);
elseif isvector(value) && numel(value) >= 3
    pLeft = value(2);
    pRight = value(3);
end
end


function class = classifyTuning(pLeft, pRight, zDifference, alpha)
if ~(isfinite(pLeft) && isfinite(pRight) && pLeft < alpha && ...
        pRight < alpha && isfinite(zDifference) && zDifference ~= 0)
    class = "No tuning";
elseif zDifference < 0
    class = "2D";
else
    class = "3D";
end
end


function priority = combinationPriority(stimClass, metaClass)
priority = 5 .* ones(size(stimClass));
priority(stimClass ~= "No tuning" & metaClass ~= "No tuning" & ...
    stimClass ~= metaClass) = 1;
priority(stimClass ~= "No tuning" & metaClass == "No tuning") = 2;
priority(stimClass == "No tuning" & metaClass ~= "No tuning") = 3;
priority(stimClass == metaClass & stimClass ~= "No tuning") = 4;
end


function folder = classificationFolder(stimClass, metaClass)
if stimClass ~= "No tuning" && metaClass ~= "No tuning" && ...
        stimClass ~= metaClass
    folder = "01_Disagree_" + stimClass + "_to_" + metaClass;
elseif stimClass ~= "No tuning" && metaClass == "No tuning"
    folder = "02_StimOnly_" + stimClass;
elseif stimClass == "No tuning" && metaClass ~= "No tuning"
    folder = "03_MetaOnly_" + metaClass;
else
    folder = "04_Agree_" + stimClass;
end
end


function plotTuningPanel(axesHandle, coherence, meanTuning, semTuning, panelTitle)
coherence = double(coherence(:)');
meanTuning = double(meanTuning);
semTuning = double(semTuning);
colors = [0 0 0; 0.12 0.47 0.71; 0.90 0.40 0.10; 0.85 0 0.85];
labels = ["Combined", "Mono L", "Mono R", "Stereo"];
hold(axesHandle, 'on');
for cue = 1:min(4, size(meanTuning, 1))
    errorbar(axesHandle, coherence, meanTuning(cue, :), ...
        semTuning(cue, :), 'o-', 'Color', colors(cue, :), ...
        'LineWidth', ternary(cue == 2 || cue == 3, 2.1, 1.35), ...
        'MarkerSize', 4.5, 'DisplayName', labels(cue));
end
xline(axesHandle, 0, '--', 'HandleVisibility', 'off');
yline(axesHandle, 0, ':', 'HandleVisibility', 'off');
grid(axesHandle, 'on');
box(axesHandle, 'off');
xlabel(axesHandle, 'Signed motion coherence');
ylabel(axesHandle, 'Raw firing rate');
title(axesHandle, panelTitle, 'Interpreter', 'tex');
end


function synchronizeYLimits(firstAxes, secondAxes)
firstLimits = ylim(firstAxes);
secondLimits = ylim(secondAxes);
limits = [min(firstLimits(1), secondLimits(1)), ...
    max(firstLimits(2), secondLimits(2))];
if all(isfinite(limits)) && limits(2) > limits(1)
    padding = 0.04 .* diff(limits);
    limits = limits + [-padding padding];
    ylim(firstAxes, limits);
    ylim(secondAxes, limits);
end
end


function output = buildSummaryTable(unitTable, audit, candidateMask, ...
        excludedMask, metaEligible, stimPLeft, stimPRight, stimClass, ...
        metaClass, includedByStim, includedByMeta, includedUnion, ...
        combination, groupFolder, outputFile, sigma)
sourceRow = (1:height(unitTable))';
originalRecIdx = nan(height(unitTable), 1);
if ismember('OriginalRecIdx', unitTable.Properties.VariableNames)
    originalRecIdx = double(unitTable.OriginalRecIdx);
end
output = table(sourceRow, originalRecIdx, audit.Monkey, audit.Date, ...
    audit.ROI, audit.StimChannel, candidateMask, excludedMask, ...
    metaEligible, stimPLeft, stimPRight, ...
    audit.OriginalZ3DMinusZ2D, stimClass, audit.MetaPLeft, ...
    audit.MetaPRight, audit.MetaZ3DMinusZ2D, metaClass, ...
    includedByStim, includedByMeta, includedUnion, combination, ...
    repmat(sigma, height(unitTable), 1), groupFolder, outputFile, ...
    'VariableNames', {'SourceTableRow', 'OriginalRecIdx', 'Monkey', ...
    'Date', 'ROI', 'StimChannel', 'CandidateBeforeTuning', ...
    'FourNeighborDiscontinuous', 'MetaCurveAvailable', 'StimPLeft', ...
    'StimPRight', 'StimZ3DMinusZ2D', 'StimClass', 'MetaPLeft', ...
    'MetaPRight', 'MetaZ3DMinusZ2D', 'MetaClass', ...
    'IncludedByStimCriterion', 'IncludedByMetaCriterion', ...
    'IncludedByEitherCriterion', 'ClassTransition', 'GaussianSigma', ...
    'PlotGroupFolder', 'PlotFile'});
output = output(candidateMask, :);
end


function output = buildTransitionTable(stimClass, metaClass)
classes = ["2D", "3D", "No tuning"];
stimCriterion = strings(0, 1);
metaCriterion = strings(0, 1);
count = zeros(0, 1);
for stimIndex = 1:numel(classes)
    for metaIndex = 1:numel(classes)
        stimCriterion(end + 1, 1) = classes(stimIndex); %#ok<AGROW>
        metaCriterion(end + 1, 1) = classes(metaIndex); %#ok<AGROW>
        count(end + 1, 1) = nnz(stimClass == classes(stimIndex) & ...
            metaClass == classes(metaIndex)); %#ok<AGROW>
    end
end
output = table(stimCriterion, metaCriterion, count, ...
    'VariableNames', {'StimulationClass', 'MetaClass', 'Count'});
end


function figureHandle = saveTransitionFigure(tableData, folder, sigma, n)
classes = ["2D", "3D", "No tuning"];
counts = zeros(3);
for row = 1:height(tableData)
    stim = find(classes == tableData.StimulationClass(row), 1);
    meta = find(classes == tableData.MetaClass(row), 1);
    counts(stim, meta) = tableData.Count(row);
end
figureHandle = figure('Color', 'w', 'Position', [100 100 720 650]);
imagesc(counts);
axis image
colormap(parula);
colorbar;
xticks(1:3); xticklabels(classes);
yticks(1:3); yticklabels(classes);
xlabel('Gaussian-meta criterion');
ylabel('Stimulation-channel criterion');
title(sprintf('Class transitions | sigma %.4g | union N=%d', sigma, n));
for row = 1:3
    for column = 1:3
        text(column, row, string(counts(row, column)), ...
            'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
            'Color', ternary(counts(row, column) > max(counts(:)) / 2, ...
            'w', 'k'));
    end
end
exportgraphics(figureHandle, fullfile(folder, ...
    'StimVsGaussianMeta_ClassTransitions.png'), 'Resolution', 300);
savefig(figureHandle, fullfile(folder, ...
    'StimVsGaussianMeta_ClassTransitions.fig'));
end


function value = formatNumber(value)
if ~isfinite(value)
    value = "NaN";
elseif abs(value) < 0.001 && value ~= 0
    value = string(sprintf('%.2e', value));
else
    value = string(sprintf('%.3f', value));
end
end


function value = sanitizeToken(value)
value = regexprep(char(string(value)), '[^A-Za-z0-9_-]', '');
if isempty(value)
    value = 'NA';
end
end


function value = rowValue(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
end


function ensureFolder(folder)
if ~isfolder(folder)
    mkdir(folder);
end
end


function value = ternary(condition, trueValue, falseValue)
if condition
    value = trueValue;
else
    value = falseValue;
end
end

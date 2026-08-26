function AIComparison = PlotOriginalVsCleanedQuickAI( ...
    cleanedTableFile, sourceTableFile, options)
%PLOTORIGINALVSCLEANEDQUICKAI Compare stimulation-channel AI by cue.
%
% One point is plotted per successful session using that session's
% stimulation channel. Four individual cue figures and a 2-by-2 overview
% are saved with a CSV/MAT record of the plotted values and exclusions.

arguments
    cleanedTableFile (1, 1) string = ...
        "C:\EM\QuickTuningCleaningAnalysis\3DQuick\unit_table_3DQuick_cleaned.mat"
    sourceTableFile (1, 1) string = ...
        "C:\EM\PopulationAnalysis\unit_table_gof.mat"
    options.OutputFolder (1, 1) string = ...
        "C:\EM\QuickTuningCleaningAnalysis\3DQuick\AIComparison_StimChannel"
    options.FigureVisible (1, 1) logical = false
    options.SaveFIG (1, 1) logical = false
    options.Resolution (1, 1) double ...
        {mustBeInteger, mustBePositive} = 180
    options.Overwrite (1, 1) logical = true
end

if ~isfile(cleanedTableFile)
    error('QuickAIComparison:MissingCleanedTable', ...
        'Cleaned 3D Quick table does not exist: %s', cleanedTableFile);
end
if ~isfile(sourceTableFile)
    error('QuickAIComparison:MissingSourceTable', ...
        'Source unit_table_gof does not exist: %s', sourceTableFile);
end
if ~isfolder(options.OutputFolder)
    mkdir(options.OutputFolder);
end

cleanedData = load(cleanedTableFile, 'unit_table_3DQuick_cleaned');
if ~isfield(cleanedData, 'unit_table_3DQuick_cleaned') || ...
        ~istable(cleanedData.unit_table_3DQuick_cleaned)
    error('QuickAIComparison:InvalidCleanedTable', ...
        '%s does not contain unit_table_3DQuick_cleaned.', ...
        cleanedTableFile);
end
cleanedTable = cleanedData.unit_table_3DQuick_cleaned;
clear cleanedData

sourceData = load(sourceTableFile, 'unit_table_gof');
if ~isfield(sourceData, 'unit_table_gof') || ...
        ~istable(sourceData.unit_table_gof)
    error('QuickAIComparison:InvalidSourceTable', ...
        '%s does not contain unit_table_gof.', sourceTableFile);
end
sourceTable = sourceData.unit_table_gof;
clear sourceData
validateTables(cleanedTable, sourceTable);

cueNames = ["Combined", "MonoL", "MonoR", "Binocular"];
sessionCount = height(cleanedTable);
originalAI = nan(sessionCount, 4);
cleanedAI = nan(sessionCount, 4);
storedOriginalAI = nan(sessionCount, 4);
originalPairCount = nan(sessionCount, 4);
cleanedPairCount = nan(sessionCount, 4);
include = false(sessionCount, 1);
exclusionReason = strings(sessionCount, 1);

for tableRow = 1:sessionCount
    sourceRow = double(cleanedTable.UnitTableRow(tableRow));
    if cleanedTable.Status(tableRow) ~= "Success"
        exclusionReason(tableRow) = cleanedTable.Status(tableRow) + ...
            ": " + cleanedTable.Message(tableRow);
        continue
    end
    if sourceRow < 1 || sourceRow > height(sourceTable)
        exclusionReason(tableRow) = "UnitTableRow is outside unit_table_gof";
        continue
    end
    try
        axesInfo = cleanedTable.Axes{tableRow};
        coherence = double(axesInfo.Coherence(:)');
        [originalAllChannels, originalDetails] = ...
            CalculateQuickTuningAI( ...
            cleanedTable.OriginalMean{tableRow}, ...
            cleanedTable.OriginalSEM{tableRow}, ...
            cleanedTable.OriginalCount{tableRow}, coherence);
        [cleanedAllChannels, cleanedDetails] = ...
            CalculateQuickTuningAI( ...
            cleanedTable.CleanedMean{tableRow}, ...
            cleanedTable.CleanedSEM{tableRow}, ...
            cleanedTable.CleanedCount{tableRow}, coherence);
        stimulationChannel = double(cleanedTable.StimChannel(tableRow));
        if stimulationChannel < 1 || ...
                stimulationChannel > size(originalAllChannels, 2)
            error('QuickAIComparison:StimChannelOutOfRange', ...
                'Stimulation channel %d is outside 1:%d.', ...
                stimulationChannel, size(originalAllChannels, 2));
        end
        originalAI(tableRow, :) = ...
            originalAllChannels(:, stimulationChannel)';
        cleanedAI(tableRow, :) = ...
            cleanedAllChannels(:, stimulationChannel)';
        originalPairCount(tableRow, :) = ...
            originalDetails.ValidPairCount(:, stimulationChannel)';
        cleanedPairCount(tableRow, :) = ...
            cleanedDetails.ValidPairCount(:, stimulationChannel)';
        stored = sourceAI(sourceTable, sourceRow, stimulationChannel);
        storedOriginalAI(tableRow, :) = stored(:)';
        include(tableRow) = true;
    catch ME
        exclusionReason(tableRow) = string(ME.identifier) + ": " + ...
            string(ME.message);
    end
end

summaryTable = buildSummaryTable(cleanedTable, include, originalAI, ...
    cleanedAI, storedOriginalAI, originalPairCount, cleanedPairCount);
longTable = buildLongTable(summaryTable, cueNames);
exclusions = cleanedTable(~include, ...
    {'UnitTableRow', 'Monkey', 'Date', 'Status', 'Message'});
exclusions.ExclusionReason = exclusionReason(~include);
statistics = calculateStatistics(longTable, cueNames);

storedDifference = abs(summaryTable.OriginalAI - ...
    summaryTable.StoredOriginalAI);
finiteAllStoredDifference = storedDifference(isfinite(storedDifference));
if isempty(finiteAllStoredDifference)
    maximumAllStoredDifference = NaN;
else
    maximumAllStoredDifference = max(finiteAllStoredDifference);
end
sourceTuningMatches = isfinite( ...
    summaryTable.OriginalTableMaxAbsDifference) & ...
    summaryTable.OriginalTableMaxAbsDifference <= 1e-10;
exactStoredDifference = storedDifference(sourceTuningMatches, :);
exactStoredDifference = exactStoredDifference( ...
    isfinite(exactStoredDifference));
if isempty(exactStoredDifference)
    maximumExactStoredDifference = NaN;
else
    maximumExactStoredDifference = max(exactStoredDifference);
end
if isfinite(maximumExactStoredDifference) && ...
        maximumExactStoredDifference > 1e-10
    warning('QuickAIComparison:StoredOriginalMismatch', ...
        ['For sessions with identical source tuning, recomputed original ' ...
        'AI differs from unit_table_gof.AI by up to %.12g.'], ...
        maximumExactStoredDifference);
end

visibility = "off";
if options.FigureVisible
    visibility = "on";
end
individualFiles = strings(4, 1);
for cue = 1:4
    individualFiles(cue) = fullfile(options.OutputFolder, ...
        sprintf('OriginalVsCleanedAI_Cue%d_%s.png', ...
        cue, cueNames(cue)));
    if options.Overwrite || ~isfile(individualFiles(cue))
        figureHandle = figure('Color', 'w', 'Visible', visibility, ...
            'Position', [100 100 820 720], 'MenuBar', 'none', ...
            'ToolBar', 'none');
        cleanup = onCleanup(@() closeIfValid(figureHandle));
        axesHandle = axes('Parent', figureHandle);
        plotCuePanel(axesHandle, summaryTable, cue, cueNames(cue), ...
            statistics(cue, :), true);
        exportgraphics(figureHandle, individualFiles(cue), ...
            'Resolution', options.Resolution);
        if options.SaveFIG
            savefig(figureHandle, replace(individualFiles(cue), ...
                '.png', '.fig'));
        end
        clear cleanup
        closeIfValid(figureHandle);
    end
end

overviewFile = fullfile(options.OutputFolder, ...
    'OriginalVsCleanedAI_AllFourCues.png');
if options.Overwrite || ~isfile(overviewFile)
    figureHandle = figure('Color', 'w', 'Visible', visibility, ...
        'Position', [50 50 1500 1250], 'MenuBar', 'none', ...
        'ToolBar', 'none');
    cleanup = onCleanup(@() closeIfValid(figureHandle));
    layout = tiledlayout(figureHandle, 2, 2, ...
        'TileSpacing', 'compact', 'Padding', 'compact');
    for cue = 1:4
        axesHandle = nexttile(layout, cue);
        plotCuePanel(axesHandle, summaryTable, cue, cueNames(cue), ...
            statistics(cue, :), cue == 1);
    end
    title(layout, sprintf([ ...
        '3D Quick AI: all trials versus MAD-cleaned | stimulation channel ' ...
        '| %d included sessions | %d excluded'], ...
        height(summaryTable), height(exclusions)), ...
        'FontWeight', 'bold');
    exportgraphics(figureHandle, overviewFile, ...
        'Resolution', options.Resolution);
    if options.SaveFIG
        savefig(figureHandle, replace(overviewFile, '.png', '.fig'));
    end
    clear cleanup
    closeIfValid(figureHandle);
end

summaryCSV = fullfile(options.OutputFolder, ...
    'OriginalVsCleanedAI_BySession.csv');
longCSV = fullfile(options.OutputFolder, ...
    'OriginalVsCleanedAI_Long.csv');
statisticsCSV = fullfile(options.OutputFolder, ...
    'OriginalVsCleanedAI_Statistics.csv');
exclusionsCSV = fullfile(options.OutputFolder, ...
    'OriginalVsCleanedAI_Exclusions.csv');
writetable(flattenSummaryForCSV(summaryTable, cueNames), summaryCSV);
writetable(longTable, longCSV);
writetable(statistics, statisticsCSV);
writetable(exclusions, exclusionsCSV);

AIComparison = struct();
AIComparison.SummaryTable = summaryTable;
AIComparison.LongTable = longTable;
AIComparison.Statistics = statistics;
AIComparison.Exclusions = exclusions;
AIComparison.CueNames = cueNames;
AIComparison.ExactSourceTuningSessionCount = nnz(sourceTuningMatches);
AIComparison.DifferentSourceTuningSessionCount = nnz(~sourceTuningMatches);
AIComparison.MaximumOriginalVsStoredAIDifference = ...
    maximumExactStoredDifference;
AIComparison.MaximumOriginalVsStoredAIDifferenceAllSessions = ...
    maximumAllStoredDifference;
AIComparison.SourceCleanedTable = cleanedTableFile;
AIComparison.SourceUnitTable = sourceTableFile;
AIComparison.IndividualFigureFiles = individualFiles;
AIComparison.OverviewFigureFile = overviewFile;
AIComparison.CreatedAtUTC = datetime('now', 'TimeZone', 'UTC');
resultMAT = fullfile(options.OutputFolder, ...
    'OriginalVsCleanedAI_Results.mat');
AIComparison.ResultMAT = resultMAT;
save(resultMAT, 'AIComparison', '-v7.3');

fprintf('\nOriginal-versus-cleaned Quick AI comparison:\n');
fprintf('  Included sessions: %d\n', height(summaryTable));
fprintf('  Excluded sessions: %d\n', height(exclusions));
fprintf('  Original tuning matches unit_table_gof exactly: %d\n', ...
    nnz(sourceTuningMatches));
fprintf('  Original tuning differs from unit_table_gof: %d\n', ...
    nnz(~sourceTuningMatches));
fprintf(['  Max |recomputed original - stored AI| among exact-tuning ' ...
    'sessions: %.12g\n'], maximumExactStoredDifference);
disp(statistics(:, {'Cue', 'N', 'PearsonR', 'MeanDelta', 'RMSE'}));
fprintf('  Figures and tables: %s\n', options.OutputFolder);
end


function validateTables(cleanedTable, sourceTable)
requiredCleaned = ["UnitTableRow", "Monkey", "Date", "StimChannel", ...
    "Status", "Message", "OriginalMean", "OriginalSEM", ...
    "OriginalCount", "CleanedMean", "CleanedSEM", "CleanedCount", ...
    "Axes", "OutlierObservations", "OutlierTrials", ...
    "OriginalTableMaxAbsDifference"];
missing = setdiff(requiredCleaned, ...
    string(cleanedTable.Properties.VariableNames));
if ~isempty(missing)
    error('QuickAIComparison:MissingCleanedColumns', ...
        'Cleaned table is missing: %s', join(missing, ', '));
end
if ~ismember('AI', sourceTable.Properties.VariableNames)
    error('QuickAIComparison:MissingSourceAI', ...
        'unit_table_gof does not contain AI.');
end
end


function values = sourceAI(sourceTable, row, channel)
if iscell(sourceTable.AI)
    allAI = double(sourceTable.AI{row});
else
    allAI = double(sourceTable.AI(row, :, :));
end
if size(allAI, 1) < 4 || size(allAI, 2) < channel
    values = nan(4, 1);
else
    values = allAI(1:4, channel);
end
end


function tableOut = buildSummaryTable(cleanedTable, include, ...
    originalAI, cleanedAI, storedOriginalAI, originalPairCount, ...
    cleanedPairCount)
tableOut = cleanedTable(include, ...
    {'UnitTableRow', 'Monkey', 'Date', 'StimChannel', ...
    'OutlierObservations', 'OutlierTrials', ...
    'OriginalTableMaxAbsDifference'});
tableOut.OriginalAI = originalAI(include, :);
tableOut.CleanedAI = cleanedAI(include, :);
tableOut.DeltaAI = cleanedAI(include, :) - originalAI(include, :);
tableOut.StoredOriginalAI = storedOriginalAI(include, :);
tableOut.OriginalValidPairCount = originalPairCount(include, :);
tableOut.CleanedValidPairCount = cleanedPairCount(include, :);
end


function longTable = buildLongTable(summaryTable, cueNames)
sessionCount = height(summaryTable);
rowCount = sessionCount * 4;
sessionIndex = repelem((1:sessionCount)', 4);
cueIndex = repmat((1:4)', sessionCount, 1);
linearIndex = sub2ind([sessionCount 4], sessionIndex, cueIndex);
longTable = table();
longTable.UnitTableRow = summaryTable.UnitTableRow(sessionIndex);
longTable.Monkey = summaryTable.Monkey(sessionIndex);
longTable.Date = summaryTable.Date(sessionIndex);
longTable.StimChannel = summaryTable.StimChannel(sessionIndex);
longTable.CueIndex = cueIndex;
longTable.Cue = reshape(cueNames(cueIndex), [], 1);
longTable.OriginalAI = summaryTable.OriginalAI(linearIndex);
longTable.CleanedAI = summaryTable.CleanedAI(linearIndex);
longTable.DeltaAI = summaryTable.DeltaAI(linearIndex);
longTable.StoredOriginalAI = ...
    summaryTable.StoredOriginalAI(linearIndex);
longTable.OriginalValidPairCount = ...
    summaryTable.OriginalValidPairCount(linearIndex);
longTable.CleanedValidPairCount = ...
    summaryTable.CleanedValidPairCount(linearIndex);
longTable.OutlierObservations = ...
    summaryTable.OutlierObservations(sessionIndex);
longTable.OutlierTrials = summaryTable.OutlierTrials(sessionIndex);
longTable.OriginalTableMaxAbsDifference = ...
    summaryTable.OriginalTableMaxAbsDifference(sessionIndex);
if height(longTable) ~= rowCount
    error('QuickAIComparison:InternalLongTableSize', ...
        'Unexpected long-table height.');
end
end


function statistics = calculateStatistics(longTable, cueNames)
statistics = table(cueNames(:), zeros(4, 1), nan(4, 1), ...
    nan(4, 1), nan(4, 1), nan(4, 1), nan(4, 1), nan(4, 1), ...
    'VariableNames', {'Cue', 'N', 'PearsonR', 'MeanDelta', ...
    'MedianDelta', 'MAE', 'RMSE', 'MaxAbsDelta'});
for cue = 1:4
    rows = longTable.CueIndex == cue & ...
        isfinite(longTable.OriginalAI) & isfinite(longTable.CleanedAI);
    x = longTable.OriginalAI(rows);
    y = longTable.CleanedAI(rows);
    delta = y - x;
    statistics.N(cue) = numel(x);
    if numel(x) >= 2
        statistics.PearsonR(cue) = corr(x, y);
    end
    if ~isempty(delta)
        statistics.MeanDelta(cue) = mean(delta);
        statistics.MedianDelta(cue) = median(delta);
        statistics.MAE(cue) = mean(abs(delta));
        statistics.RMSE(cue) = sqrt(mean(delta .^ 2));
        statistics.MaxAbsDelta(cue) = max(abs(delta));
    end
end
end


function plotCuePanel(axesHandle, summaryTable, cue, cueName, stats, ...
    showLegend)
hold(axesHandle, 'on');
plot(axesHandle, [-1 1], [-1 1], '--', ...
    'Color', [0.35 0.35 0.35], 'LineWidth', 1.2, ...
    'DisplayName', 'Identity');
monkeys = string(summaryTable.Monkey);
groups = unique(monkeys, 'stable');
colors = lines(max(numel(groups), 2));
for group = 1:numel(groups)
    rows = monkeys == groups(group) & ...
        isfinite(summaryTable.OriginalAI(:, cue)) & ...
        isfinite(summaryTable.CleanedAI(:, cue));
    scatter(axesHandle, summaryTable.OriginalAI(rows, cue), ...
        summaryTable.CleanedAI(rows, cue), 34, colors(group, :), ...
        'filled', 'MarkerFaceAlpha', 0.65, ...
        'MarkerEdgeColor', 'w', 'LineWidth', 0.4, ...
        'DisplayName', char(groups(group)));
end
xlim(axesHandle, [-1 1]);
ylim(axesHandle, [-1 1]);
xticks(axesHandle, -1:0.5:1);
yticks(axesHandle, -1:0.5:1);
axis(axesHandle, 'square');
grid(axesHandle, 'on');
axesHandle.GridAlpha = 0.15;
box(axesHandle, 'on');
xlabel(axesHandle, 'Original AI (all selected trials)');
ylabel(axesHandle, 'Cleaned AI (MAD-filtered)');
title(axesHandle, {char(cueName), sprintf( ...
    'n = %d | r = %.3f | mean change = %.4f | RMSE = %.4f', ...
    stats.N, stats.PearsonR, stats.MeanDelta, stats.RMSE)}, ...
    'FontWeight', 'bold');
if showLegend
    legend(axesHandle, 'Location', 'best', 'Box', 'off');
end
end


function flat = flattenSummaryForCSV(summaryTable, cueNames)
flat = summaryTable(:, {'UnitTableRow', 'Monkey', 'Date', ...
    'StimChannel', 'OutlierObservations', 'OutlierTrials', ...
    'OriginalTableMaxAbsDifference'});
matrixFields = ["OriginalAI", "CleanedAI", "DeltaAI", ...
    "StoredOriginalAI", "OriginalValidPairCount", ...
    "CleanedValidPairCount"];
for field = matrixFields
    values = summaryTable.(field);
    for cue = 1:4
        variableName = matlab.lang.makeValidName( ...
            field + "_" + cueNames(cue));
        flat.(variableName) = values(:, cue);
    end
end
end


function closeIfValid(figureHandle)
if ~isempty(figureHandle) && isgraphics(figureHandle)
    close(figureHandle);
end
end

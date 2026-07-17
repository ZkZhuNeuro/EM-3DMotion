%% Plot ref/new tuning_mean for sessions with edge-8 differences above 5 Hz

repoRoot = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\FullAnalysisPipeline';
addpath(repoRoot);
outputRoot = 'C:\EM\FullAnalysisPipeline_Outputs_20260604';
comparisonDir = fullfile(outputRoot, 'MIDTable_20260604_UnitTableComparison');
rowReportPath = fullfile(comparisonDir, 'MIDTable_20260604_vs_UnitTable_updating_tuning_mean_row_report.csv');

newPath = resolveMatPath('C:\EM\PopulationAnalysis\MIDTable_20260604');
refPath = resolveMatPath('C:\EM\PopulationAnalysis\UnitTable_updating');
outputDir = fullfile(outputRoot, 'MIDTable_20260604_TuningMeanMismatchPlots_gt5Hz');
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

newData = load(newPath);
refData = load(refPath);
newTable = getUnitTable(newData, newPath);
refTable = getUnitTable(refData, refPath);

knownMissingMask = strcmp(asText(refTable.Monkey), 'Jim') & dateshift(refTable.Date, 'start', 'day') == datetime(2024, 5, 24);
refComparable = refTable(~knownMissingMask, :);

rowReport = readtable(rowReportPath);
plotRows = rowReport(~isnan(rowReport.TuningMeanStimEdge8MaxAbsDiff) & rowReport.TuningMeanStimEdge8MaxAbsDiff > 5, :);

plotSummary = table();
for iPlot = 1:height(plotRows)
    rowIndex = plotRows.RowIndex(iPlot);
    stimElec = newTable.StimElec(rowIndex);

    newTuning = newTable.tuning_mean{rowIndex};
    refTuning = refComparable.tuning_mean{rowIndex};
    newSEM = getOptionalCellValue(newTable, 'tuning_SEM', rowIndex, nan(size(newTuning)));
    refSEM = getOptionalCellValue(refComparable, 'tuning_SEM', rowIndex, nan(size(refTuning)));

    [newEdgeMean, edgeCoherence] = selectEdgeCoherenceSlots(newTuning(:, :, stimElec));
    [refEdgeMean, ~] = selectEdgeCoherenceSlots(refTuning(:, :, stimElec));
    [newEdgeSEM, ~] = selectEdgeCoherenceSlots(newSEM(:, :, stimElec));
    [refEdgeSEM, ~] = selectEdgeCoherenceSlots(refSEM(:, :, stimElec));

    refNeuro = buildPlotNeuro(refEdgeMean, refEdgeSEM);
    newNeuro = buildPlotNeuro(newEdgeMean, newEdgeSEM);

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 560]);
    layout = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    axRef = nexttile;
    plot3DMotionTuning_Stim(refNeuro, 1);
    title(sprintf('Reference | %s %s %s Ch%d', asText(refComparable.Monkey(rowIndex)), ...
        datestr(refComparable.Date(rowIndex), 'yyyy-mm-dd'), asText(refComparable.ROI(rowIndex)), stimElec), ...
        'Interpreter', 'none');
    legend({'Combined','MonoL','MonoR','Stereo'}, 'Location', 'best');

    axNew = nexttile;
    plot3DMotionTuning_Stim(newNeuro, 1);
    title(sprintf('New 20260604 | max diff %.2f Hz', plotRows.TuningMeanStimEdge8MaxAbsDiff(iPlot)), ...
        'Interpreter', 'none');
    legend({'Combined','MonoL','MonoR','Stereo'}, 'Location', 'best');

    syncYLimits([axRef axNew], refEdgeMean, newEdgeMean, refEdgeSEM, newEdgeSEM);
    title(layout, sprintf('Edge coherence bins: %s | difference = new - reference', mat2str(edgeCoherence, 3)), ...
        'Interpreter', 'none');

    pngName = sprintf('%03d_%s_%s_%s_StimElec%02d_maxDiff%.2fHz.png', rowIndex, ...
        asText(newTable.Monkey(rowIndex)), datestr(newTable.Date(rowIndex), 'yyyymmdd'), ...
        asText(newTable.ROI(rowIndex)), stimElec, plotRows.TuningMeanStimEdge8MaxAbsDiff(iPlot));
    pngName = regexprep(pngName, '[^\w\-.]', '_');
    pngPath = fullfile(outputDir, pngName);
    exportgraphics(fig, pngPath, 'Resolution', 200);
    close(fig);

    temp = table();
    temp.RowIndex = rowIndex;
    temp.RefSourceRow = plotRows.RefSourceRow(iPlot);
    temp.Monkey = {asText(newTable.Monkey(rowIndex))};
    temp.Date = newTable.Date(rowIndex);
    temp.ROI = {asText(newTable.ROI(rowIndex))};
    temp.StimElec = stimElec;
    temp.TuningMeanStimEdge8MaxAbsDiff = plotRows.TuningMeanStimEdge8MaxAbsDiff(iPlot);
    temp.PngPath = {pngPath};
    plotSummary = [plotSummary; temp]; %#ok<AGROW>
end

summaryPath = fullfile(outputDir, 'TuningMeanMismatchPlots_gt5Hz_summary.csv');
writetable(plotSummary, summaryPath);
fprintf('Saved %d PNG files to %s\n', height(plotSummary), outputDir);
fprintf('Wrote %s\n', summaryPath);

function matPath = resolveMatPath(pathText)
if exist(pathText, 'file')
    matPath = pathText;
elseif exist([pathText '.mat'], 'file')
    matPath = [pathText '.mat'];
else
    error('Could not find MAT file: %s', pathText);
end
end

function unitTable = getUnitTable(dataStruct, sourcePath)
if isfield(dataStruct, 'unit_table')
    unitTable = dataStruct.unit_table;
    return
end

fieldNames = fieldnames(dataStruct);
for iField = 1:numel(fieldNames)
    value = dataStruct.(fieldNames{iField});
    if istable(value)
        unitTable = value;
        return
    end
end
error('Could not find unit_table or another table variable in %s', sourcePath);
end

function textValue = asText(value)
if iscell(value)
    value = value{1};
end
if isstring(value)
    textValue = char(value);
elseif ischar(value)
    textValue = value;
elseif iscategorical(value)
    textValue = char(value);
else
    textValue = char(string(value));
end
end

function value = getOptionalCellValue(tableValue, varName, rowIndex, defaultValue)
if ismember(varName, tableValue.Properties.VariableNames) && ~isempty(tableValue.(varName){rowIndex})
    value = tableValue.(varName){rowIndex};
else
    value = defaultValue;
end
end

function [edgeValues, edgeCoherence] = selectEdgeCoherenceSlots(values)
nCoherence = size(values, 2);
if nCoherence == 13
    coherenceValues = [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22]./22;
elseif nCoherence == 12
    coherenceValues = [-22 -14 -10 -8 -4 -2 2 4 8 10 14 22]./22;
elseif nCoherence == 8
    coherenceValues = [-22 -14 -10 -8 8 10 14 22]./22;
else
    coherenceValues = 1:nCoherence;
end

edgeIdx = unique([1:min(4, nCoherence), max(1, nCoherence - 3):nCoherence], 'stable');
edgeValues = values(:, edgeIdx);
edgeCoherence = coherenceValues(edgeIdx);
end

function neuroPlot = buildPlotNeuro(edgeMean, edgeSEM)
neuroPlot = struct();
neuroPlot.Means = reshape(edgeMean, size(edgeMean, 1), size(edgeMean, 2), 1);
neuroPlot.SEM = reshape(edgeSEM, size(edgeSEM, 1), size(edgeSEM, 2), 1);
neuroPlot.Trials.NumTrials = ones(size(edgeMean));
end

function syncYLimits(axesHandles, refMean, newMean, refSEM, newSEM)
allValues = [refMean(:); newMean(:); refMean(:) - refSEM(:); refMean(:) + refSEM(:); newMean(:) - newSEM(:); newMean(:) + newSEM(:)];
allValues = allValues(~isnan(allValues));
if isempty(allValues)
    return
end

yMin = min(allValues);
yMax = max(allValues);
padding = max(1, 0.08 * (yMax - yMin));
ylim(axesHandles, [yMin - padding, yMax + padding]);
end

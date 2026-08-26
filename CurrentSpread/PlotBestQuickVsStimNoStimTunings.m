function PlotManifest = PlotBestQuickVsStimNoStimTunings( ...
    stateFile, sseResultsFile, options)
%PLOTBESTQUICKVSSTIMNOSTIMTUNINGS Plot SSE- and correlation-best tunings.
%
% PlotManifest = PlotBestQuickVsStimNoStimTunings()
% creates one three-panel figure per session. The first panel contains the
% 3DMotionQuick tuning_mean curves for the channel selected by minimum SSE,
% the second contains the 3DMotionStim NoStim curves from the stimulation
% channel, and the third contains the Quick channel selected by maximum
% pooled Pearson correlation. Each displayed channel is standardized once
% across all shared cue-by-coherence means, matching both analyses. Only the
% first four and last four Stim coherences and their matching Quick values
% are plotted.
%
% The figure title reports pooled Pearson r and SSE for both selected Quick
% channels, calculated from the finite displayed cells (up to 4 cues x 8
% coherences). All panels share y-limits. Missing or legacy result files are
% generated automatically before plotting.
%
% Default output:
%   C:\EM\StimTuningAnalysis\BestSSEChannelTuningComparisons_WholeChannelZScore

arguments
    stateFile (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\unit_table_stim.mat"
    sseResultsFile (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\QuickVsStimNoStimSSE_WholeChannelZScore\" + ...
        "QuickStimNoStim_SSEResults.mat"
    options.OutputFolder (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\" + ...
        "BestSSEChannelTuningComparisons_WholeChannelZScore"
    options.Rows (1, :) double {mustBeInteger, mustBePositive} = []
    options.FigureVisible (1, 1) logical = false
    options.SaveFIG (1, 1) logical = true
    options.Resolution (1, 1) double {mustBePositive} = 180
    options.Overwrite (1, 1) logical = true
    options.AutoBuildSSEResults (1, 1) logical = true
    options.CorrelationResultsFile (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\QuickVsStimNoStimCorrelation\" + ...
        "QuickStimNoStim_CorrelationResults.mat"
    options.AutoBuildCorrelationResults (1, 1) logical = true
end

if ~isfile(stateFile)
    error('BestTuningPlot:MissingStateFile', ...
        'Input MAT file does not exist: %s', stateFile);
end
if ~isfile(sseResultsFile) && options.AutoBuildSSEResults
    buildWholeChannelSSEResults(stateFile, sseResultsFile);
end
if ~isfile(sseResultsFile)
    error('BestTuningPlot:MissingSSEResults', ...
        ['SSE result MAT file does not exist: %s. Run ' ...
        'RankQuickChannelsByStimNoStimSSE first or enable ' ...
        'AutoBuildSSEResults.'], sseResultsFile);
end
correlationResultsFile = options.CorrelationResultsFile;
if ~isfile(correlationResultsFile) && ...
        options.AutoBuildCorrelationResults
    buildWholeChannelCorrelationResults( ...
        stateFile, correlationResultsFile);
end
if ~isfile(correlationResultsFile)
    error('BestTuningPlot:MissingCorrelationResults', ...
        ['Correlation result MAT file does not exist: %s. Run ' ...
        'CorrelateQuickStimNoStimTunings first or enable ' ...
        'AutoBuildCorrelationResults.'], correlationResultsFile);
end
stateData = load(stateFile, 'unit_table_stim');
resultData = load(sseResultsFile, 'SessionSummary', 'AnalysisMetadata');
corrResultData = load(correlationResultsFile, ...
    'SessionSummary', 'AnalysisMetadata');
if ~hasWholeChannelNormalization(resultData) && ...
        options.AutoBuildSSEResults
    fprintf(['Existing SSE results do not use whole-channel Z-scoring; ' ...
        'rebuilding them now.\n']);
    buildWholeChannelSSEResults(stateFile, sseResultsFile);
    resultData = load(sseResultsFile, ...
        'SessionSummary', 'AnalysisMetadata');
end
if ~hasWholeChannelNormalization(corrResultData) && ...
        options.AutoBuildCorrelationResults
    fprintf(['Existing correlation results do not use whole-channel ' ...
        'Z-scoring; rebuilding them now.\n']);
    buildWholeChannelCorrelationResults( ...
        stateFile, correlationResultsFile);
    corrResultData = load(correlationResultsFile, ...
        'SessionSummary', 'AnalysisMetadata');
end
if ~isfield(stateData, 'unit_table_stim') || ...
        ~istable(stateData.unit_table_stim)
    error('BestTuningPlot:MissingUnitTable', ...
        '%s does not contain unit_table_stim.', stateFile);
end
if ~isfield(resultData, 'SessionSummary') || ...
        ~istable(resultData.SessionSummary)
    error('BestTuningPlot:MissingSessionSummary', ...
        '%s does not contain SessionSummary.', sseResultsFile);
end
if ~isfield(corrResultData, 'SessionSummary') || ...
        ~istable(corrResultData.SessionSummary)
    error('BestTuningPlot:MissingCorrelationSessionSummary', ...
        '%s does not contain SessionSummary.', correlationResultsFile);
end
unitTable = stateData.unit_table_stim;
sseSummary = resultData.SessionSummary;
corrSummary = corrResultData.SessionSummary;
requiredTableVariables = ["Date", "Monkey", "StimElec", "NChannels", ...
    "tuning_mean", "stim_tuning_mean_noStim", ...
    "stim_tuning_coherence", "stim_tuning_channel_map", ...
    "stim_tuning_condition_names"];
missingTableVariables = setdiff(requiredTableVariables, ...
    string(unitTable.Properties.VariableNames));
if ~isempty(missingTableVariables)
    error('BestTuningPlot:MissingTableVariables', ...
        'unit_table_stim is missing variable(s): %s', ...
        join(missingTableVariables, ', '));
end
requiredSummaryVariables = ["UnitTableRow", "Status", "BestChannel", ...
    "BestSSE", "BestRelativePositionToStim", "SharedCoherenceCount", ...
    "ReferenceValueCount"];
missingSummaryVariables = setdiff(requiredSummaryVariables, ...
    string(sseSummary.Properties.VariableNames));
if ~isempty(missingSummaryVariables)
    error('BestTuningPlot:MissingSummaryVariables', ...
        'SSE SessionSummary is missing variable(s): %s', ...
        join(missingSummaryVariables, ', '));
end
requiredCorrelationVariables = ["UnitTableRow", "Status", ...
    "BestChannel", "BestPearsonR", "BestRelativePositionToStim", ...
    "SharedCoherenceCount", "ReferenceValueCount"];
missingCorrelationVariables = setdiff(requiredCorrelationVariables, ...
    string(corrSummary.Properties.VariableNames));
if ~isempty(missingCorrelationVariables)
    error('BestTuningPlot:MissingCorrelationSummaryVariables', ...
        'Correlation SessionSummary is missing variable(s): %s', ...
        join(missingCorrelationVariables, ', '));
end
if height(sseSummary) ~= height(unitTable) || ...
        ~isequal(sseSummary.UnitTableRow, (1:height(unitTable))')
    error('BestTuningPlot:RowAlignmentMismatch', ...
        'SSE SessionSummary is not aligned one-to-one with unit_table_stim.');
end
if height(corrSummary) ~= height(unitTable) || ...
        ~isequal(corrSummary.UnitTableRow, (1:height(unitTable))')
    error('BestTuningPlot:CorrelationRowAlignmentMismatch', ...
        ['Correlation SessionSummary is not aligned one-to-one with ' ...
        'unit_table_stim.']);
end
if any(sseSummary.Status ~= "Success")
    badRows = sseSummary.UnitTableRow(sseSummary.Status ~= "Success");
    error('BestTuningPlot:NonSuccessSSERows', ...
        'SSE results contain non-success rows: %s', mat2str(badRows'));
end
if any(corrSummary.Status ~= "Success")
    badRows = corrSummary.UnitTableRow(corrSummary.Status ~= "Success");
    error('BestTuningPlot:NonSuccessCorrelationRows', ...
        'Correlation results contain non-success rows: %s', ...
        mat2str(badRows'));
end
if any(sseSummary.SharedCoherenceCount ~= 8)
    error('BestTuningPlot:StaleSSEGrid', ...
        'SSE results do not uniformly use the required 8 outer coherences.');
end
if any(corrSummary.SharedCoherenceCount ~= 8)
    error('BestTuningPlot:StaleCorrelationGrid', ...
        ['Correlation results do not uniformly use the required 8 ' ...
        'outer coherences.']);
end
if ~hasWholeChannelNormalization(resultData)
    error('BestTuningPlot:StaleSSENormalization', ...
        ['SSE results do not declare whole-channel Z-scoring. Rerun ' ...
        'RankQuickChannelsByStimNoStimSSE before plotting.']);
end
if ~hasWholeChannelNormalization(corrResultData)
    error('BestTuningPlot:StaleCorrelationNormalization', ...
        ['Correlation results do not declare whole-channel Z-scoring. ' ...
        'Rerun CorrelateQuickStimNoStimTunings before plotting.']);
end

rows = options.Rows;
if isempty(rows)
    rows = 1:height(unitTable);
end
rows = unique(rows, 'stable');
if any(rows > height(unitTable))
    error('BestTuningPlot:RowsOutOfRange', ...
        'Rows contains a value above table height %d.', height(unitTable));
end

pngFolder = fullfile(options.OutputFolder, 'PNG');
figFolder = fullfile(options.OutputFolder, 'FIG');
if ~isfolder(pngFolder)
    mkdir(pngFolder);
end
if options.SaveFIG && ~isfolder(figFolder)
    mkdir(figFolder);
end

manifestRows = cell(numel(rows), 1);
for rowIndex = 1:numel(rows)
    row = rows(rowIndex);
    fprintf('[%d/%d] Plotting row %d...\n', rowIndex, numel(rows), row);
    manifestRows{rowIndex} = plotSession( ...
        unitTable, sseSummary, corrSummary, row, ...
        pngFolder, figFolder, options);
end
PlotManifest = vertcat(manifestRows{:});

manifestCSV = fullfile(options.OutputFolder, ...
    'BestSSEChannelTuningPlotManifest.csv');
manifestMAT = fullfile(options.OutputFolder, ...
    'BestSSEChannelTuningPlotManifest.mat');
writetable(PlotManifest, manifestCSV);
CreatedAt = datetime('now', 'TimeZone', 'UTC');
PlotMetadata = struct( ...
    'StateFile', stateFile, ...
    'SSEResultsFile', sseResultsFile, ...
    'CorrelationResultsFile', correlationResultsFile, ...
    'OutputFolder', options.OutputFolder, ...
    'CreatedAt', CreatedAt, ...
    'SelectionCriterion', ...
    "Minimum SSE and maximum pooled Pearson r after whole-channel " + ...
    "Z-scoring of tuning_mean", ...
    'PanelOrder', ...
    ["SSE-best Quick", "Stim NoStim", "correlation-best Quick"], ...
    'Coherences', [-1 -0.64 -0.45 -0.36 0.36 0.45 0.64 1], ...
    'MaximumMetricCells', 32, ...
    'SaveFIG', options.SaveFIG, ...
    'Resolution', options.Resolution);
if isfield(resultData, 'AnalysisMetadata')
    PlotMetadata.SSEAnalysisMetadata = resultData.AnalysisMetadata;
end
if isfield(corrResultData, 'AnalysisMetadata')
    PlotMetadata.CorrelationAnalysisMetadata = ...
        corrResultData.AnalysisMetadata;
end
save(manifestMAT, 'PlotManifest', 'PlotMetadata');

successCount = nnz(PlotManifest.Status == "Success" | ...
    PlotManifest.Status == "Existing");
fprintf('Saved or verified %d/%d session comparison plots in %s.\n', ...
    successCount, numel(rows), options.OutputFolder);
if successCount ~= numel(rows)
    errorRows = PlotManifest.UnitTableRow(PlotManifest.Status == "Error");
    error('BestTuningPlot:PlotFailures', ...
        'Plotting failed for row(s): %s', mat2str(errorRows'));
end
end


function buildWholeChannelSSEResults(stateFile, sseResultsFile)
[outputFolder, resultName, resultExtension] = fileparts(sseResultsFile);
resultFileName = string(resultName) + string(resultExtension);
expectedFileName = "QuickStimNoStim_SSEResults.mat";
if ~strcmpi(resultFileName, expectedFileName)
    error('BestTuningPlot:UnsupportedAutoBuildPath', ...
        ['Automatic SSE generation requires the result filename %s. ' ...
        'Requested: %s'], expectedFileName, sseResultsFile);
end
if strlength(string(outputFolder)) == 0
    outputFolder = pwd;
end

fprintf(['Whole-channel SSE results are missing; scoring all sessions ' ...
    'before plotting.\nOutput folder: %s\n'], outputFolder);
RankQuickChannelsByStimNoStimSSE(stateFile, ...
    OutputFolder=string(outputFolder), SaveOutputs=true, ...
    MakePlots=false, FigureVisible=false);
if ~isfile(sseResultsFile)
    error('BestTuningPlot:AutoBuildFailed', ...
        'SSE generation finished without creating: %s', sseResultsFile);
end
end


function buildWholeChannelCorrelationResults( ...
    stateFile, correlationResultsFile)
[outputFolder, resultName, resultExtension] = ...
    fileparts(correlationResultsFile);
resultFileName = string(resultName) + string(resultExtension);
expectedFileName = "QuickStimNoStim_CorrelationResults.mat";
if ~strcmpi(resultFileName, expectedFileName)
    error('BestTuningPlot:UnsupportedCorrelationAutoBuildPath', ...
        ['Automatic correlation generation requires the result filename ' ...
        '%s. Requested: %s'], expectedFileName, correlationResultsFile);
end
if strlength(string(outputFolder)) == 0
    outputFolder = pwd;
end

fprintf(['Whole-channel correlation results are missing; scoring all ' ...
    'sessions before plotting.\nOutput folder: %s\n'], outputFolder);
CorrelateQuickStimNoStimTunings(stateFile, ...
    OutputFolder=string(outputFolder), SaveOutputs=true, ...
    MakePlot=false, FigureVisible=false);
if ~isfile(correlationResultsFile)
    error('BestTuningPlot:CorrelationAutoBuildFailed', ...
        'Correlation generation finished without creating: %s', ...
        correlationResultsFile);
end
end


function tf = hasWholeChannelNormalization(resultData)
tf = isfield(resultData, 'AnalysisMetadata') && ...
    isfield(resultData.AnalysisMetadata, 'Normalization') && ...
    contains(string(resultData.AnalysisMetadata.Normalization), ...
    "Each channel z-scored once");
end


function manifestRow = plotSession( ...
    unitTable, sseSummary, corrSummary, row, ...
    pngFolder, figFolder, options)
monkey = getRowText(unitTable.Monkey, row);
recordingDate = unitTable.Date(row);
stimChannel = getRowScalar(unitTable.StimElec, row);
sseBestChannel = double(sseSummary.BestChannel(row));
sseRelativePosition = double( ...
    sseSummary.BestRelativePositionToStim(row));
corrBestChannel = double(corrSummary.BestChannel(row));
corrRelativePosition = double( ...
    corrSummary.BestRelativePositionToStim(row));
savedSSE = double(sseSummary.BestSSE(row));
savedCorrelation = double(corrSummary.BestPearsonR(row));
sseExpectedValueCount = double(sseSummary.ReferenceValueCount(row));
corrExpectedValueCount = double( ...
    corrSummary.ReferenceValueCount(row));
dateText = string(recordingDate, 'yyyyMMdd');
baseName = sprintf('Row%03d_%s_%s_StimCh%02d_BestCh%02d', ...
    row, char(monkey), char(dateText), stimChannel, sseBestChannel);
pngPath = fullfile(pngFolder, baseName + ".png");
figPath = fullfile(figFolder, baseName + ".fig");

sseBestR = NaN;
sseBestSSE = NaN;
sseBestRMSE = NaN;
ssePairedValueCount = NaN;
corrBestR = NaN;
corrBestSSE = NaN;
corrBestRMSE = NaN;
corrPairedValueCount = NaN;
message = "";
figureHandle = gobjects(0);
try
    [quickZ, stimZ, coherence, conditionNames, probePosition] = ...
        getDisplayedTunings(unitTable, row, stimChannel, ...
        [sseBestChannel corrBestChannel]);
    sseQuickZ = quickZ(:, :, 1);
    corrQuickZ = quickZ(:, :, 2);
    [sseBestR, sseBestSSE, sseBestRMSE, ...
        ssePairedValueCount] = comparisonMetrics(sseQuickZ, stimZ);
    [corrBestR, corrBestSSE, corrBestRMSE, ...
        corrPairedValueCount] = comparisonMetrics(corrQuickZ, stimZ);
    if ssePairedValueCount ~= sseExpectedValueCount
        error('BestTuningPlot:IncompleteDisplayedGrid', ...
            'Expected %d finite displayed cells but found %d.', ...
            sseExpectedValueCount, ssePairedValueCount);
    end
    if corrPairedValueCount ~= corrExpectedValueCount
        error('BestTuningPlot:IncompleteCorrelationDisplayedGrid', ...
            ['Expected %d finite correlation-best displayed cells but ' ...
            'found %d.'], corrExpectedValueCount, corrPairedValueCount);
    end
    tolerance = max(1e-10, 1e-10 * abs(savedSSE));
    if abs(sseBestSSE - savedSSE) > tolerance
        error('BestTuningPlot:SSEMismatch', ...
            'Computed SSE %.12g differs from saved best SSE %.12g.', ...
            sseBestSSE, savedSSE);
    end
    correlationTolerance = max(1e-10, ...
        1e-10 * abs(savedCorrelation));
    if abs(corrBestR - savedCorrelation) > correlationTolerance
        error('BestTuningPlot:CorrelationMismatch', ...
            ['Computed correlation %.12g differs from saved best ' ...
            'correlation %.12g.'], corrBestR, savedCorrelation);
    end

    if isfile(pngPath) && (~options.SaveFIG || isfile(figPath)) && ...
            ~options.Overwrite
        status = "Existing";
        message = "Existing output retained";
    else
        figureHandle = makeComparisonFigure( ...
            sseQuickZ, stimZ, corrQuickZ, coherence, ...
            conditionNames, row, monkey, recordingDate, stimChannel, ...
            sseBestChannel, corrBestChannel, probePosition, ...
            sseRelativePosition, corrRelativePosition, ...
            sseBestR, sseBestSSE, sseBestRMSE, ...
            corrBestR, corrBestSSE, corrBestRMSE, ...
            ssePairedValueCount, options.FigureVisible);
        exportgraphics(figureHandle, pngPath, ...
            'Resolution', options.Resolution);
        if options.SaveFIG
            savefig(figureHandle, figPath);
        else
            figPath = "";
        end
        status = "Success";
    end
catch ME
    status = "Error";
    message = string(ME.identifier) + ": " + string(ME.message);
end
closeIfValid(figureHandle);

unitTableRow = row;
sseBestProbePosition = NaN;
corrBestProbePosition = NaN;
stimProbePosition = NaN;
if exist('probePosition', 'var')
    sseBestProbePosition = probePosition(sseBestChannel);
    corrBestProbePosition = probePosition(corrBestChannel);
    stimProbePosition = probePosition(stimChannel);
end
selectionsMatch = sseBestChannel == corrBestChannel;
manifestRow = table(unitTableRow, monkey, recordingDate, stimChannel, ...
    stimProbePosition, sseBestChannel, sseBestProbePosition, ...
    sseRelativePosition, ssePairedValueCount, sseBestR, sseBestSSE, ...
    sseBestRMSE, corrBestChannel, corrBestProbePosition, ...
    corrRelativePosition, corrPairedValueCount, corrBestR, corrBestSSE, ...
    corrBestRMSE, selectionsMatch, pngPath, figPath, status, message, ...
    'VariableNames', {'UnitTableRow', 'Monkey', 'Date', 'StimChannel', ...
    'StimProbePosition', 'BestChannel', 'BestProbePosition', ...
    'BestRelativePositionToStim', 'PairedValueCount', ...
    'PooledPearsonR', 'SSE', 'RMSE', 'CorrelationBestChannel', ...
    'CorrelationBestProbePosition', ...
    'CorrelationBestRelativePositionToStim', ...
    'CorrelationPairedValueCount', 'CorrelationBestPearsonR', ...
    'CorrelationBestSSE', 'CorrelationBestRMSE', 'SelectionsMatch', ...
    'PNGFile', 'FIGFile', 'Status', 'Message'});
end


function [quickZ, stimZ, sharedCoherence, conditionNames, ...
    probePosition] = getDisplayedTunings( ...
    unitTable, row, stimChannel, selectedChannels)
quickMeanAll = double(getCellValue(unitTable.tuning_mean, row));
stimMeanAll = double(getCellValue( ...
    unitTable.stim_tuning_mean_noStim, row));
stimCoherence = double(getCellValue( ...
    unitTable.stim_tuning_coherence, row));
conditionNames = string(getCellValue( ...
    unitTable.stim_tuning_condition_names, row));
channelMap = double(getCellValue( ...
    unitTable.stim_tuning_channel_map, row));
channelCount = getRowScalar(unitTable.NChannels, row);
if size(quickMeanAll, 3) ~= channelCount || ...
        size(stimMeanAll, 3) ~= channelCount
    error('BestTuningPlot:ChannelCountMismatch', ...
        'Tuning arrays do not match NChannels at row %d.', row);
end
if any(selectedChannels < 1 | selectedChannels > channelCount) || ...
        stimChannel < 1 || stimChannel > channelCount
    error('BestTuningPlot:ChannelOutOfRange', ...
        'Selected or stimulation channel is out of range at row %d.', row);
end

quickCoherence = inferQuickCoherence(size(quickMeanAll, 2));
stimCoherence = reshape(stimCoherence, 1, []);
if numel(stimCoherence) < 8 || ...
        numel(stimCoherence) ~= size(stimMeanAll, 2)
    error('BestTuningPlot:InvalidStimCoherence', ...
        'Stim coherence axis is invalid at row %d.', row);
end
stimOuterColumns = [1:4, numel(stimCoherence)-3:numel(stimCoherence)];
stimOuterCoherence = stimCoherence(stimOuterColumns);
[isShared, selectedStimColumns] = ismember( ...
    round(quickCoherence, 2), round(stimOuterCoherence, 2));
quickColumns = 1:numel(isShared);
quickColumns = quickColumns(isShared);
stimColumns = stimOuterColumns(selectedStimColumns(isShared));
sharedCoherence = quickCoherence(isShared);
if numel(sharedCoherence) ~= 8
    error('BestTuningPlot:OuterCoherenceMismatch', ...
        'Expected 8 matching outer coherences at row %d.', row);
end

quickMean = reshape(quickMeanAll(:, quickColumns, selectedChannels), ...
    size(quickMeanAll, 1), 8, numel(selectedChannels));
stimMean = reshape(stimMeanAll(:, stimColumns, stimChannel), ...
    size(stimMeanAll, 1), 8);
quickZ = zScoreEachChannel(quickMean);
stimZ = zScoreEachChannel(stimMean);
if numel(conditionNames) ~= size(quickZ, 1)
    conditionNames = "Cue" + (1:size(quickZ, 1));
else
    conditionNames = reshape(conditionNames, 1, []);
end
channelMap = validateChannelMap(channelMap, channelCount);
probePosition = nan(channelCount, 1);
for position = 1:channelCount
    probePosition(channelMap(position)) = position;
end
end


function [pooledR, sse, rmse, pairedValueCount] = ...
    comparisonMetrics(quickZ, stimZ)
valid = isfinite(quickZ) & isfinite(stimZ);
pairedValueCount = nnz(valid);
residual = quickZ(valid) - stimZ(valid);
sse = sum(residual .^ 2);
rmse = sqrt(sse / pairedValueCount);
pooledR = finiteCorrelation(quickZ(valid), stimZ(valid));
end


function figureHandle = makeComparisonFigure( ...
    sseQuickZ, stimZ, corrQuickZ, coherence, conditionNames, ...
    row, monkey, recordingDate, stimChannel, sseBestChannel, ...
    corrBestChannel, probePosition, sseRelativePosition, ...
    corrRelativePosition, sseBestR, sseBestSSE, sseBestRMSE, ...
    corrBestR, corrBestSSE, corrBestRMSE, pairedValueCount, visible)
visibility = "off";
if visible
    visibility = "on";
end
figureHandle = figure('Color', 'w', 'Visible', visibility, ...
    'Name', 'SSE- and correlation-best Quick versus Stim NoStim tuning', ...
    'Position', [20 100 1980 720]);
layout = tiledlayout(figureHandle, 1, 3, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
colors = cueColors(numel(conditionNames));
allValues = [sseQuickZ(:); stimZ(:); corrQuickZ(:)];
allValues = allValues(isfinite(allValues));
yLimit = max(2, ceil(max(abs(allValues)) * 4) / 4);

axesSSE = nexttile(layout, 1);
plotTuningPanel(axesSSE, sseQuickZ, coherence, conditionNames, ...
    colors, yLimit, sprintf( ...
    '3DMotionQuick | SSE-best ch %d | probe position %d', ...
    sseBestChannel, probePosition(sseBestChannel)), true);

axesStim = nexttile(layout, 2);
plotTuningPanel(axesStim, stimZ, coherence, conditionNames, ...
    colors, yLimit, sprintf( ...
    '3DMotionStim NoStim | stim ch %d | probe position %d', ...
    stimChannel, probePosition(stimChannel)), false);

axesCorrelation = nexttile(layout, 3);
plotTuningPanel(axesCorrelation, corrQuickZ, coherence, ...
    conditionNames, colors, yLimit, sprintf( ...
    '3DMotionQuick | correlation-best ch %d | probe position %d', ...
    corrBestChannel, probePosition(corrBestChannel)), false);

dateLabel = char(string(recordingDate, 'dd-MMM-yyyy'));
title(layout, {sprintf('%s | %s | row %d', ...
    char(monkey), dateLabel, row), ...
    sprintf(['SSE-best: rel %+.0f | r = %.3f | SSE = %.3f | ' ...
    'RMSE = %.3f'], sseRelativePosition, sseBestR, ...
    sseBestSSE, sseBestRMSE), ...
    sprintf(['Correlation-best: rel %+.0f | r = %.3f | SSE = %.3f | ' ...
    'RMSE = %.3f | n = %d'], corrRelativePosition, corrBestR, ...
    corrBestSSE, corrBestRMSE, pairedValueCount)}, ...
    'FontWeight', 'bold');
end


function lineHandles = plotTuningPanel( ...
    axesHandle, zTuning, coherence, conditionNames, colors, yLimit, ...
    panelTitle, showLegend)
hold(axesHandle, 'on');
lineHandles = gobjects(numel(conditionNames), 1);
for cue = 1:numel(conditionNames)
    lineHandles(cue) = plot(axesHandle, coherence, zTuning(cue, :), ...
        '-o', 'Color', colors(cue, :), ...
        'MarkerFaceColor', colors(cue, :), 'MarkerSize', 5, ...
        'LineWidth', 1.8, 'DisplayName', conditionNames(cue));
end
formatTuningAxes(axesHandle, coherence, yLimit);
xlabel(axesHandle, 'Motion coherence');
ylabel(axesHandle, 'Whole-channel z-scored firing rate');
title(axesHandle, panelTitle);
if showLegend
    legend(axesHandle, lineHandles, cellstr(conditionNames), ...
        'Location', 'best');
end
end


function formatTuningAxes(axesHandle, coherence, yLimit)
yline(axesHandle, 0, ':', 'Color', [0.6 0.6 0.6], ...
    'HandleVisibility', 'off');
xline(axesHandle, 0, ':', 'Color', [0.75 0.75 0.75], ...
    'HandleVisibility', 'off');
xlim(axesHandle, [min(coherence) max(coherence)]);
ylim(axesHandle, [-yLimit yLimit]);
xticks(axesHandle, coherence);
xtickformat(axesHandle, '%.2g');
xtickangle(axesHandle, 30);
grid(axesHandle, 'on');
axesHandle.GridAlpha = 0.14;
end


function colors = cueColors(cueCount)
standardColors = [0 0 0; 0 0 255; 5 150 5; 234 0 233] ./ 255;
if cueCount <= size(standardColors, 1)
    colors = standardColors(1:cueCount, :);
else
    colors = lines(cueCount);
end
end


function [r, p] = finiteCorrelation(x, y)
valid = isfinite(x) & isfinite(y);
if nnz(valid) < 3 || std(x(valid), 0) == 0 || ...
        std(y(valid), 0) == 0
    r = NaN;
    p = NaN;
    return
end
[matrixR, matrixP] = corrcoef(x(valid), y(valid));
r = matrixR(1, 2);
p = matrixP(1, 2);
end


function zValues = zScoreEachChannel(meanValues)
zValues = nan(size(meanValues));
for channel = 1:size(meanValues, 3)
    values = meanValues(:, :, channel);
    finiteMask = isfinite(values);
    if nnz(finiteMask) < 2
        continue
    end
    center = mean(values(finiteMask));
    scale = std(values(finiteMask), 0);
    if isfinite(scale) && scale > 0
        standardized = nan(size(values));
        standardized(finiteMask) = ...
            (values(finiteMask) - center) ./ scale;
        zValues(:, :, channel) = standardized;
    end
end
end


function coherence = inferQuickCoherence(coherenceCount)
switch coherenceCount
    case 8
        numerator = [-22 -14 -10 -8 8 10 14 22];
    case 12
        numerator = [-22 -14 -10 -8 -4 -2 2 4 8 10 14 22];
    case 13
        numerator = [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22];
    otherwise
        error('BestTuningPlot:UnknownQuickCoherenceGrid', ...
            'Expected 8, 12, or 13 Quick coherence columns; found %d.', ...
            coherenceCount);
end
coherence = numerator ./ 22;
end


function channelMap = validateChannelMap(channelMap, channelCount)
channelMap = reshape(channelMap, 1, []);
if numel(channelMap) ~= channelCount || ...
        ~isequal(sort(channelMap), 1:channelCount)
    channelMap = 1:channelCount;
end
end


function value = getCellValue(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
end


function value = getRowText(column, row)
if iscell(column)
    value = string(column{row});
else
    value = string(column(row));
end
end


function value = getRowScalar(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row);
end
if iscell(value)
    value = value{1};
end
if isstring(value) || ischar(value) || iscategorical(value)
    value = str2double(string(value));
end
value = double(value);
end


function closeIfValid(figureHandle)
if ~isempty(figureHandle) && all(isgraphics(figureHandle))
    close(figureHandle);
end
end

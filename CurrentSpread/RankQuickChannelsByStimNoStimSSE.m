function [SessionSummary, ChannelSSE, AnalysisMetadata, Figures] = ...
    RankQuickChannelsByStimNoStimSSE(stateFile, options)
%RANKQUICKCHANNELSBYSTIMNOSTIMSSE Rank Quick channels by tuning SSE.
%
% [SessionSummary, ChannelSSE] = RankQuickChannelsByStimNoStimSSE()
% loads unit_table_stim and, for every session, compares the stimulation
% electrode's non-electrical-stimulation tuning from 3DMotionStim with every
% 3DMotionQuick channel in unit_table_stim.tuning_mean.
%
% Only the first four and last four Stim coherence columns and their matching
% Quick columns are compared. Each Quick channel and the Stim reference are
% independently Z-scored once across their complete shared cue-by-coherence
% matrices using the sample standard deviation (N-1). The primary score is
% the unweighted sum of squared errors (SSE) across all cue-by-coherence
% cells; the complete channel with the lowest SSE is the best channel.
%
% Default outputs:
%   C:\EM\StimTuningAnalysis\QuickVsStimNoStimSSE_WholeChannelZScore

arguments
    stateFile (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\unit_table_stim.mat"
    options.OutputFolder (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\QuickVsStimNoStimSSE_WholeChannelZScore"
    options.SaveOutputs (1, 1) logical = true
    options.MakePlots (1, 1) logical = true
    options.FigureVisible (1, 1) logical = false
end

if ~isfile(stateFile)
    error('QuickStimSSE:MissingStateFile', ...
        'Input MAT file does not exist: %s', stateFile);
end
loaded = load(stateFile, 'unit_table_stim');
fileVariables = string({whos('-file', stateFile).name});
if ismember("PipelineMetadata", fileVariables)
    metadataInput = load(stateFile, 'PipelineMetadata');
    loaded.PipelineMetadata = metadataInput.PipelineMetadata;
end
if ~isfield(loaded, 'unit_table_stim') || ...
        ~istable(loaded.unit_table_stim)
    error('QuickStimSSE:MissingTable', ...
        '%s does not contain table unit_table_stim.', stateFile);
end
unitTable = loaded.unit_table_stim;
requiredVariables = ["Date", "Monkey", "StimElec", "NChannels", ...
    "tuning_mean", "stim_tuning_mean_noStim", ...
    "stim_tuning_coherence", "stim_tuning_channel_map", ...
    "stim_tuning_condition_names", "stim_tuning_status"];
missingVariables = setdiff(requiredVariables, ...
    string(unitTable.Properties.VariableNames));
if ~isempty(missingVariables)
    error('QuickStimSSE:MissingVariables', ...
        'unit_table_stim is missing required variable(s): %s', ...
        join(missingVariables, ', '));
end

rowCount = height(unitTable);
sessionRows = cell(rowCount, 1);
channelRows = cell(rowCount, 1);
for row = 1:rowCount
    [sessionRows{row}, channelRows{row}] = scoreSession(unitTable, row);
end
SessionSummary = vertcat(sessionRows{:});
ChannelSSE = vertcat(channelRows{:});

AnalysisMetadata = struct();
AnalysisMetadata.Analysis = ...
    "Whole-channel Quick versus Stim-task NoStim tuning SSE";
AnalysisMetadata.InputFile = stateFile;
AnalysisMetadata.CreatedAt = datetime('now', 'TimeZone', 'UTC');
AnalysisMetadata.QuickTuningSource = ...
    "unit_table_stim.tuning_mean, standardized on the shared grid";
AnalysisMetadata.SharedGridRule = ...
    "First four and last four Stim coherence columns, matched to Quick: " + ...
    "[-1 -0.64 -0.45 -0.36 0.36 0.45 0.64 1]";
AnalysisMetadata.Normalization = ...
    "Each channel z-scored once across the complete shared cue-by-" + ...
    "coherence matrix with sample SD (N-1); cue relationships retained";
AnalysisMetadata.PrimaryMetric = ...
    "Unweighted SSE across the complete shared cue-by-coherence grid";
AnalysisMetadata.Ranking = ...
    "Ascending SSE; complete channels only; channel breaks ties";
AnalysisMetadata.InputPipelineMetadata = struct();
if isfield(loaded, 'PipelineMetadata')
    AnalysisMetadata.InputPipelineMetadata = loaded.PipelineMetadata;
end

Figures = struct('PopulationSummary', gobjects(0), ...
    'BestLocationVsSSE', gobjects(0));
if options.MakePlots
    Figures.PopulationSummary = makePopulationPlot( ...
        SessionSummary, ChannelSSE, options.FigureVisible);
    Figures.BestLocationVsSSE = makeBestLocationScatter( ...
        SessionSummary, options.FigureVisible);
end

if options.SaveOutputs
    if ~isfolder(options.OutputFolder)
        mkdir(options.OutputFolder);
    end
    resultFile = fullfile(options.OutputFolder, ...
        'QuickStimNoStim_SSEResults.mat');
    sessionCSV = fullfile(options.OutputFolder, ...
        'QuickStimNoStim_SSESessionSummary.csv');
    channelCSV = fullfile(options.OutputFolder, ...
        'QuickStimNoStim_ChannelSSE.csv');
    AnalysisMetadata.OutputFolder = options.OutputFolder;
    AnalysisMetadata.ResultFile = resultFile;
    AnalysisMetadata.SessionSummaryCSV = sessionCSV;
    AnalysisMetadata.ChannelSSECSV = channelCSV;
    if ~isempty(Figures.PopulationSummary)
        summaryPNG = fullfile(options.OutputFolder, ...
            'QuickStimNoStim_SSEPopulationSummary.png');
        summaryFIG = fullfile(options.OutputFolder, ...
            'QuickStimNoStim_SSEPopulationSummary.fig');
        exportgraphics(Figures.PopulationSummary, summaryPNG, ...
            'Resolution', 220);
        savefig(Figures.PopulationSummary, summaryFIG);
        AnalysisMetadata.PopulationSummaryPNG = summaryPNG;
        AnalysisMetadata.PopulationSummaryFIG = summaryFIG;
    end
    if ~isempty(Figures.BestLocationVsSSE)
        scatterPNG = fullfile(options.OutputFolder, ...
            'QuickStimNoStim_BestLocationVsSSE.png');
        scatterFIG = fullfile(options.OutputFolder, ...
            'QuickStimNoStim_BestLocationVsSSE.fig');
        exportgraphics(Figures.BestLocationVsSSE, scatterPNG, ...
            'Resolution', 220);
        savefig(Figures.BestLocationVsSSE, scatterFIG);
        AnalysisMetadata.BestLocationVsSSEPNG = scatterPNG;
        AnalysisMetadata.BestLocationVsSSEFIG = scatterFIG;
    end
    save(resultFile, 'SessionSummary', 'ChannelSSE', ...
        'AnalysisMetadata', '-v7.3');
    writetable(SessionSummary, sessionCSV);
    writetable(ChannelSSE, channelCSV);
end

successMask = SessionSummary.Status == "Success";
fprintf(['Scored %d/%d sessions successfully. ' ...
    'Median best SSE = %.3f.\n'], nnz(successMask), rowCount, ...
    median(SessionSummary.BestSSE(successMask), 'omitnan'));
end


function [sessionResult, channelResult] = scoreSession(unitTable, row)
monkey = getRowText(unitTable.Monkey, row);
recordingDate = unitTable.Date(row);
stimChannel = getRowScalar(unitTable.StimElec, row);
declaredChannelCount = getRowScalar(unitTable.NChannels, row);
sourceStatus = string(unitTable.stim_tuning_status(row));
sessionResult = makeEmptySessionRow(row, monkey, recordingDate, ...
    stimChannel, declaredChannelCount, sourceStatus);
channelResult = table();
if ~startsWith(sourceStatus, "Success")
    sessionResult.Status = "SkippedInputStatus";
    sessionResult.Message = "Input status: " + sourceStatus;
    return
end

try
    quickMeanAll = double(getCellValue(unitTable.tuning_mean, row));
    stimMeanAll = double(getCellValue( ...
        unitTable.stim_tuning_mean_noStim, row));
    stimCoherence = double(getCellValue( ...
        unitTable.stim_tuning_coherence, row));
    conditionNames = string(getCellValue( ...
        unitTable.stim_tuning_condition_names, row));
    channelMap = double(getCellValue( ...
        unitTable.stim_tuning_channel_map, row));

    if ndims(quickMeanAll) ~= 3 || ndims(stimMeanAll) ~= 3
        error('QuickStimSSE:InvalidTuningDimensions', ...
            'Quick and Stim mean tunings must be 3-D arrays.');
    end
    cueCount = size(quickMeanAll, 1);
    channelCount = size(quickMeanAll, 3);
    if size(stimMeanAll, 1) ~= cueCount
        error('QuickStimSSE:CueCountMismatch', ...
            'Quick has %d cues and Stim has %d cues.', ...
            cueCount, size(stimMeanAll, 1));
    end
    if size(stimMeanAll, 3) ~= channelCount || ...
            channelCount ~= declaredChannelCount
        error('QuickStimSSE:ChannelCountMismatch', ...
            ['Quick, Stim, and NChannels report %d, %d, and %d ' ...
            'channels, respectively.'], channelCount, ...
            size(stimMeanAll, 3), declaredChannelCount);
    end
    if stimChannel < 1 || stimChannel > channelCount || ...
            stimChannel ~= fix(stimChannel)
        error('QuickStimSSE:InvalidStimChannel', ...
            'StimElec %g is outside channels 1:%d.', ...
            stimChannel, channelCount);
    end
    if numel(conditionNames) ~= cueCount
        conditionNames = "Cue" + (1:cueCount);
    else
        conditionNames = reshape(conditionNames, 1, []);
    end
    channelMap = validateChannelMap(channelMap, channelCount);

    quickCoherence = inferQuickCoherence(size(quickMeanAll, 2));
    stimCoherence = reshape(stimCoherence, 1, []);
    if numel(stimCoherence) ~= size(stimMeanAll, 2)
        error('QuickStimSSE:StimCoherenceSizeMismatch', ...
            'Stim coherence axis and tuning array have different sizes.');
    end
    if numel(stimCoherence) < 8
        error('QuickStimSSE:InsufficientStimCoherence', ...
            'Stim tuning has only %d coherence columns; at least 8 required.', ...
            numel(stimCoherence));
    end
    stimAnalysisColumns = [1:4, numel(stimCoherence)-3:numel(stimCoherence)];
    stimAnalysisCoherence = stimCoherence(stimAnalysisColumns);
    [isShared, selectedStimColumns] = ismember( ...
        round(quickCoherence, 2), round(stimAnalysisCoherence, 2));
    quickColumns = 1:numel(isShared);
    quickColumns = quickColumns(isShared);
    stimColumns = stimAnalysisColumns(selectedStimColumns(isShared));
    sharedCoherence = quickCoherence(isShared);
    if numel(sharedCoherence) ~= 8
        error('QuickStimSSE:OuterCoherenceMismatch', ...
            'Expected 8 matching outer coherence values but found %d.', ...
            numel(sharedCoherence));
    end

    quickSharedMean = quickMeanAll(:, quickColumns, :);
    stimReferenceMean = reshape(stimMeanAll( ...
        :, stimColumns, stimChannel), cueCount, []);
    quickZ = zScoreEachChannel(quickSharedMean);
    stimZ = zScoreEachChannel(stimReferenceMean);
    referenceMask = isfinite(stimZ);
    referenceValueCount = nnz(referenceMask);
    if referenceValueCount < 3
        error('QuickStimSSE:InsufficientReferenceValues', ...
            'Stim reference has only %d finite z-scored values.', ...
            referenceValueCount);
    end

    probePosition = nan(channelCount, 1);
    for position = 1:channelCount
        probePosition(channelMap(position)) = position;
    end
    stimProbePosition = probePosition(stimChannel);
    channel = (1:channelCount)';
    relativePosition = probePosition - stimProbePosition;
    distanceMicrometers = 50 .* relativePosition;
    pairedValueCount = zeros(channelCount, 1);
    isComplete = false(channelCount, 1);
    sse = nan(channelCount, 1);
    rmse = nan(channelCount, 1);
    sseByCue = nan(channelCount, cueCount);

    for candidate = 1:channelCount
        candidateZ = quickZ(:, :, candidate);
        pairedMask = referenceMask & isfinite(candidateZ);
        pairedValueCount(candidate) = nnz(pairedMask);
        isComplete(candidate) = ...
            pairedValueCount(candidate) == referenceValueCount;
        if isComplete(candidate)
            residualSquared = (candidateZ - stimZ) .^ 2;
            sse(candidate) = sum(residualSquared(referenceMask));
            rmse(candidate) = sqrt(sse(candidate) / referenceValueCount);
            for cue = 1:cueCount
                cueMask = referenceMask(cue, :);
                sseByCue(candidate, cue) = ...
                    sum(residualSquared(cue, cueMask));
            end
        end
    end

    rank = nan(channelCount, 1);
    rankable = find(isComplete & isfinite(sse));
    if isempty(rankable)
        error('QuickStimSSE:NoRankableChannels', ...
            'No Quick channel has a complete z-scored tuning matrix.');
    end
    rankingTable = table(rankable, sse(rankable), ...
        'VariableNames', {'Channel', 'SSE'});
    rankingTable = sortrows(rankingTable, ...
        {'SSE', 'Channel'}, {'ascend', 'ascend'});
    rank(rankingTable.Channel) = (1:height(rankingTable))';
    bestChannel = rankingTable.Channel(1);
    isBest = channel == bestChannel;
    isStimChannel = channel == stimChannel;

    unitTableRow = repmat(row, channelCount, 1);
    monkeyColumn = repmat(monkey, channelCount, 1);
    dateColumn = repmat(recordingDate, channelCount, 1);
    stimChannelColumn = repmat(stimChannel, channelCount, 1);
    sharedCoherenceCount = repmat(numel(sharedCoherence), ...
        channelCount, 1);
    referenceCountColumn = repmat(referenceValueCount, ...
        channelCount, 1);
    channelResult = table(unitTableRow, monkeyColumn, dateColumn, ...
        stimChannelColumn, channel, probePosition, relativePosition, ...
        distanceMicrometers, sharedCoherenceCount, ...
        referenceCountColumn, pairedValueCount, isComplete, sse, rmse, ...
        rank, isBest, isStimChannel, 'VariableNames', ...
        {'UnitTableRow', 'Monkey', 'Date', 'StimChannel', ...
        'QuickChannel', 'ProbePosition', 'RelativePositionToStim', ...
        'DistanceToStimMicrometers', 'SharedCoherenceCount', ...
        'ReferenceValueCount', 'PairedValueCount', 'IsComplete', ...
        'SSE', 'RMSE', 'Rank', 'IsBest', 'IsStimChannel'});
    cueVariableNames = matlab.lang.makeUniqueStrings( ...
        "SSE_" + matlab.lang.makeValidName(conditionNames));
    for cue = 1:cueCount
        channelResult.(cueVariableNames(cue)) = sseByCue(:, cue);
    end

    sessionResult.Status = "Success";
    sessionResult.Message = "";
    sessionResult.SharedCoherenceCount = numel(sharedCoherence);
    sessionResult.SharedCoherence = {sharedCoherence};
    sessionResult.ReferenceValueCount = referenceValueCount;
    sessionResult.CompleteChannelCount = nnz(isComplete);
    sessionResult.BestChannel = bestChannel;
    sessionResult.BestProbePosition = probePosition(bestChannel);
    sessionResult.BestRelativePositionToStim = ...
        relativePosition(bestChannel);
    sessionResult.BestDistanceToStimMicrometers = ...
        distanceMicrometers(bestChannel);
    sessionResult.BestSSE = sse(bestChannel);
    sessionResult.BestRMSE = rmse(bestChannel);
    sessionResult.StimChannelSSE = sse(stimChannel);
    sessionResult.StimChannelRank = rank(stimChannel);
    sessionResult.StimChannelIsBest = bestChannel == stimChannel;
catch ME
    sessionResult.Status = "Error";
    sessionResult.Message = string(ME.identifier) + ": " + ...
        string(ME.message);
end
end


function rowTable = makeEmptySessionRow(row, monkey, recordingDate, ...
    stimChannel, channelCount, sourceStatus)
unitTableRow = row;
sharedCoherenceCount = 0;
sharedCoherence = {zeros(1, 0)};
referenceValueCount = 0;
completeChannelCount = 0;
bestChannel = NaN;
bestProbePosition = NaN;
bestRelativePositionToStim = NaN;
bestDistanceToStimMicrometers = NaN;
bestSSE = NaN;
bestRMSE = NaN;
stimChannelSSE = NaN;
stimChannelRank = NaN;
stimChannelIsBest = false;
status = "Pending";
message = "";
rowTable = table(unitTableRow, monkey, recordingDate, stimChannel, ...
    channelCount, sourceStatus, sharedCoherenceCount, sharedCoherence, ...
    referenceValueCount, completeChannelCount, bestChannel, ...
    bestProbePosition, bestRelativePositionToStim, ...
    bestDistanceToStimMicrometers, bestSSE, bestRMSE, stimChannelSSE, ...
    stimChannelRank, stimChannelIsBest, status, message, ...
    'VariableNames', {'UnitTableRow', 'Monkey', 'Date', 'StimChannel', ...
    'ChannelCount', 'InputStatus', 'SharedCoherenceCount', ...
    'SharedCoherence', 'ReferenceValueCount', 'CompleteChannelCount', ...
    'BestChannel', 'BestProbePosition', 'BestRelativePositionToStim', ...
    'BestDistanceToStimMicrometers', 'BestSSE', 'BestRMSE', ...
    'StimChannelSSE', 'StimChannelRank', 'StimChannelIsBest', ...
    'Status', 'Message'});
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


function channelMap = validateChannelMap(channelMap, channelCount)
channelMap = reshape(channelMap, 1, []);
if numel(channelMap) ~= channelCount || ...
        ~isequal(sort(channelMap), 1:channelCount)
    channelMap = 1:channelCount;
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
        error('QuickStimSSE:UnknownQuickCoherenceGrid', ...
            ['Cannot infer the Quick coherence axis from %d columns. ' ...
            'Expected 8, 12, or 13.'], coherenceCount);
end
coherence = numerator ./ 22;
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


function figureHandle = makePopulationPlot( ...
    sessionSummary, channelSSE, visible)
visibility = "off";
if visible
    visibility = "on";
end
successful = sessionSummary.Status == "Success";
figureHandle = figure('Color', 'w', 'Visible', visibility, ...
    'Name', 'Quick versus Stim NoStim SSE summary', ...
    'Position', [80 80 1450 820]);
layout = tiledlayout(figureHandle, 2, 2, ...
    'TileSpacing', 'compact', 'Padding', 'compact');

axesHandle = nexttile(layout);
histogram(axesHandle, sessionSummary.BestSSE(successful), 25, ...
    'FaceColor', [0.12 0.48 0.72], 'EdgeColor', 'none');
xline(axesHandle, median(sessionSummary.BestSSE(successful), ...
    'omitnan'), '--k', 'Median');
xlabel(axesHandle, 'Best SSE');
ylabel(axesHandle, 'Sessions');
title(axesHandle, 'Lowest Quick-channel error');
grid(axesHandle, 'on');

axesHandle = nexttile(layout);
relative = sessionSummary.BestRelativePositionToStim(successful);
relative = relative(isfinite(relative));
positions = min(relative):max(relative);
histogram(axesHandle, relative, ...
    [positions - 0.5, positions(end) + 0.5], ...
    'FaceColor', [0.20 0.62 0.32], 'EdgeColor', 'none');
xticks(axesHandle, positions);
xlabel(axesHandle, 'Best channel position relative to Stim electrode');
ylabel(axesHandle, 'Sessions');
title(axesHandle, 'Location of minimum SSE');
grid(axesHandle, 'on');

axesHandle = nexttile(layout);
scatter(axesHandle, sessionSummary.StimChannelSSE(successful), ...
    sessionSummary.BestSSE(successful), 24, 'filled', ...
    'MarkerFaceAlpha', 0.55);
hold(axesHandle, 'on');
limits = [0 max(sessionSummary.StimChannelSSE(successful), [], 'omitnan')];
plot(axesHandle, limits, limits, '--', 'Color', [0.4 0.4 0.4]);
xlim(axesHandle, limits);
ylim(axesHandle, limits);
axis(axesHandle, 'square');
xlabel(axesHandle, 'Stim-electrode Quick-channel SSE');
ylabel(axesHandle, 'Best Quick-channel SSE');
title(axesHandle, 'Stim electrode versus winning channel');
grid(axesHandle, 'on');

axesHandle = nexttile(layout);
rankable = channelSSE.IsComplete & isfinite(channelSSE.SSE);
boxchart(axesHandle, ...
    categorical(channelSSE.RelativePositionToStim(rankable)), ...
    channelSSE.SSE(rankable), 'BoxFaceColor', [0.56 0.36 0.68], ...
    'MarkerStyle', '.');
xlabel(axesHandle, 'Quick channel position relative to Stim electrode');
ylabel(axesHandle, 'SSE');
title(axesHandle, 'Error by probe position');
grid(axesHandle, 'on');

title(layout, sprintf( ...
    'Whole-channel Quick versus Stim NoStim tuning SSE | %d sessions', ...
    nnz(successful)), 'FontWeight', 'bold');
end


function figureHandle = makeBestLocationScatter(sessionSummary, visible)
visibility = "off";
if visible
    visibility = "on";
end
successful = sessionSummary.Status == "Success" & ...
    isfinite(sessionSummary.BestRelativePositionToStim) & ...
    isfinite(sessionSummary.BestSSE);
plotData = sessionSummary(successful, :);
positions = min(plotData.BestRelativePositionToStim): ...
    max(plotData.BestRelativePositionToStim);
jitteredPosition = plotData.BestRelativePositionToStim;
for position = positions
    rows = find(plotData.BestRelativePositionToStim == position);
    if numel(rows) > 1
        [~, order] = sort(plotData.BestSSE(rows), 'ascend');
        offsets = linspace(-0.27, 0.27, numel(rows))';
        jitteredPosition(rows(order)) = position + offsets;
    end
end

figureHandle = figure('Color', 'w', 'Visible', visibility, ...
    'Name', 'Best channel location versus SSE', ...
    'Position', [140 100 1180 760]);
axesHandle = axes(figureHandle);
hold(axesHandle, 'on');
monkeys = unique(plotData.Monkey, 'stable');
colors = lines(max(2, numel(monkeys)));
for monkeyIndex = 1:numel(monkeys)
    monkeyMask = plotData.Monkey == monkeys(monkeyIndex);
    scatter(axesHandle, jitteredPosition(monkeyMask), ...
        plotData.BestSSE(monkeyMask), 38, colors(monkeyIndex, :), ...
        'filled', 'MarkerFaceAlpha', 0.66, 'MarkerEdgeColor', 'w', ...
        'LineWidth', 0.35, 'DisplayName', monkeys(monkeyIndex));
end
xline(axesHandle, 0, '--', 'Stim electrode', ...
    'Color', [0.25 0.25 0.25], 'LabelVerticalAlignment', 'bottom', ...
    'HandleVisibility', 'off');
xticks(axesHandle, positions);
xlim(axesHandle, [positions(1) - 0.6, positions(end) + 0.6]);
ylim(axesHandle, [0 max(plotData.BestSSE) * 1.04]);
xlabel(axesHandle, ...
    'Best Quick channel position relative to stimulation electrode');
ylabel(axesHandle, 'Minimum SSE');
title(axesHandle, sprintf( ...
    'Best-channel location and z-tuning SSE | %d sessions', ...
    height(plotData)));
legend(axesHandle, 'Location', 'best');
grid(axesHandle, 'on');
axesHandle.GridAlpha = 0.16;
end

function [SessionSummary, ChannelCorrelations, AnalysisMetadata, Figures] = ...
    CorrelateQuickStimNoStimTunings(stateFile, options)
%CORRELATEQUICKSTIMNOSTIMTUNINGS Match Quick tuning to Stim NoStim tuning.
%
% [SessionSummary, ChannelCorrelations] = ...
%     CorrelateQuickStimNoStimTunings()
% loads C:\EM\StimTuningAnalysis\unit_table_stim.mat and, for every table
% row, correlates the stimulation electrode's non-electrical-stimulation
% tuning from the 3DMotionStim task with every channel's tuning from the
% 3DMotionQuick task.
%
% Only coherence values present in both tasks are used. Within every cue,
% the mean firing-rate curve is z-scored across the shared coherence grid.
% The primary Pearson correlation pools those cue-wise z-scores. Thus the
% result tests tuning-shape agreement without allowing firing-rate scale or
% cue-specific baselines to determine the winning channel. A channel is
% ranked only if it has every finite value available in the Stim reference.
%
% Default outputs are written to:
%   C:\EM\StimTuningAnalysis\QuickVsStimNoStimCorrelation
%
% SessionSummary contains the winning Quick channel for each session.
% ChannelCorrelations contains all channel correlations and cue-specific
% correlations, with acquisition channel, physical probe position, and
% distance from the stimulation electrode retained for auditing.

arguments
    stateFile (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\unit_table_stim.mat"
    options.OutputFolder (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\QuickVsStimNoStimCorrelation"
    options.SaveOutputs (1, 1) logical = true
    options.MakePlot (1, 1) logical = true
    options.FigureVisible (1, 1) logical = false
end

if ~isfile(stateFile)
    error('QuickStimCorrelation:MissingStateFile', ...
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
    error('QuickStimCorrelation:MissingTable', ...
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
    error('QuickStimCorrelation:MissingVariables', ...
        'unit_table_stim is missing required variable(s): %s', ...
        join(missingVariables, ', '));
end

rowCount = height(unitTable);
sessionRows = cell(rowCount, 1);
channelRows = cell(rowCount, 1);
for row = 1:rowCount
    [sessionRows{row}, channelRows{row}] = correlateSession(unitTable, row);
end
SessionSummary = vertcat(sessionRows{:});
ChannelCorrelations = vertcat(channelRows{:});

AnalysisMetadata = struct();
AnalysisMetadata.Analysis = ...
    "Quick channel versus Stim-task non-stimulation channel correlation";
AnalysisMetadata.InputFile = stateFile;
AnalysisMetadata.CreatedAt = datetime('now', 'TimeZone', 'UTC');
AnalysisMetadata.SharedGridRule = ...
    "Intersection of rounded (2 decimal) Quick and Stim coherence values";
AnalysisMetadata.Normalization = ...
    "Each cue z-scored across shared coherence with sample SD (N-1)";
AnalysisMetadata.PrimaryMetric = ...
    "Pearson r pooled across all finite cue-wise z-scored values";
AnalysisMetadata.Ranking = ...
    "Descending Pearson r; complete channels only; channel breaks ties";
AnalysisMetadata.InputPipelineMetadata = struct();
if isfield(loaded, 'PipelineMetadata')
    AnalysisMetadata.InputPipelineMetadata = loaded.PipelineMetadata;
end

Figures = struct('PopulationSummary', gobjects(0), ...
    'BestLocationScatter', gobjects(0));
if options.MakePlot
    Figures.PopulationSummary = makePopulationPlot( ...
        SessionSummary, ChannelCorrelations, options.FigureVisible);
    Figures.BestLocationScatter = makeBestLocationScatter( ...
        SessionSummary, options.FigureVisible);
end

if options.SaveOutputs
    if ~isfolder(options.OutputFolder)
        mkdir(options.OutputFolder);
    end
    resultFile = fullfile(options.OutputFolder, ...
        'QuickStimNoStim_CorrelationResults.mat');
    sessionCSV = fullfile(options.OutputFolder, ...
        'QuickStimNoStim_SessionSummary.csv');
    channelCSV = fullfile(options.OutputFolder, ...
        'QuickStimNoStim_ChannelCorrelations.csv');
    AnalysisMetadata.OutputFolder = options.OutputFolder;
    AnalysisMetadata.ResultFile = resultFile;
    AnalysisMetadata.SessionSummaryCSV = sessionCSV;
    AnalysisMetadata.ChannelCorrelationsCSV = channelCSV;
    if ~isempty(Figures.PopulationSummary)
        figurePNG = fullfile(options.OutputFolder, ...
            'QuickStimNoStim_PopulationSummary.png');
        figureFIG = fullfile(options.OutputFolder, ...
            'QuickStimNoStim_PopulationSummary.fig');
        exportgraphics(Figures.PopulationSummary, figurePNG, ...
            'Resolution', 220);
        savefig(Figures.PopulationSummary, figureFIG);
        AnalysisMetadata.PopulationSummaryPNG = figurePNG;
        AnalysisMetadata.PopulationSummaryFIG = figureFIG;
    end
    if ~isempty(Figures.BestLocationScatter)
        scatterPNG = fullfile(options.OutputFolder, ...
            'QuickStimNoStim_BestLocationVsPearsonR.png');
        scatterFIG = fullfile(options.OutputFolder, ...
            'QuickStimNoStim_BestLocationVsPearsonR.fig');
        exportgraphics(Figures.BestLocationScatter, scatterPNG, ...
            'Resolution', 220);
        savefig(Figures.BestLocationScatter, scatterFIG);
        AnalysisMetadata.BestLocationScatterPNG = scatterPNG;
        AnalysisMetadata.BestLocationScatterFIG = scatterFIG;
    end
    save(resultFile, 'SessionSummary', 'ChannelCorrelations', ...
        'AnalysisMetadata', '-v7.3');
    writetable(SessionSummary, sessionCSV);
    writetable(ChannelCorrelations, channelCSV);
end

successMask = SessionSummary.Status == "Success";
fprintf(['Correlated %d/%d sessions successfully. ' ...
    'Median best Pearson r = %.3f.\n'], nnz(successMask), rowCount, ...
    median(SessionSummary.BestPearsonR(successMask), 'omitnan'));
end


function [sessionResult, channelResult] = correlateSession(unitTable, row)
monkey = getRowText(unitTable.Monkey, row);
recordingDate = unitTable.Date(row);
stimChannel = getRowScalar(unitTable.StimElec, row);
declaredChannelCount = getRowScalar(unitTable.NChannels, row);
sourceStatus = string(unitTable.stim_tuning_status(row));

sessionResult = makeEmptySessionRow( ...
    row, monkey, recordingDate, stimChannel, declaredChannelCount, ...
    sourceStatus);
channelResult = table();
if ~startsWith(sourceStatus, "Success")
    sessionResult.Status = "SkippedInputStatus";
    sessionResult.Message = "Input status: " + sourceStatus;
    return
end

try
    quickMean = double(getCellValue(unitTable.tuning_mean, row));
    stimMeanAll = double(getCellValue( ...
        unitTable.stim_tuning_mean_noStim, row));
    stimCoherence = double(getCellValue( ...
        unitTable.stim_tuning_coherence, row));
    conditionNames = string(getCellValue( ...
        unitTable.stim_tuning_condition_names, row));
    channelMap = double(getCellValue( ...
        unitTable.stim_tuning_channel_map, row));

    if ndims(quickMean) ~= 3 || ndims(stimMeanAll) ~= 3
        error('QuickStimCorrelation:InvalidTuningDimensions', ...
            'Quick and Stim mean tuning must be cue x coherence x channel.');
    end
    cueCount = size(quickMean, 1);
    channelCount = size(quickMean, 3);
    if size(stimMeanAll, 1) ~= cueCount
        error('QuickStimCorrelation:CueCountMismatch', ...
            'Quick has %d cues and Stim has %d cues.', ...
            cueCount, size(stimMeanAll, 1));
    end
    if size(stimMeanAll, 3) ~= channelCount || ...
            channelCount ~= declaredChannelCount
        error('QuickStimCorrelation:ChannelCountMismatch', ...
            ['Quick, Stim, and NChannels report %d, %d, and %d ' ...
            'channels, respectively.'], channelCount, ...
            size(stimMeanAll, 3), declaredChannelCount);
    end
    if stimChannel < 1 || stimChannel > channelCount || ...
            stimChannel ~= fix(stimChannel)
        error('QuickStimCorrelation:InvalidStimChannel', ...
            'StimElec %g is outside channels 1:%d.', ...
            stimChannel, channelCount);
    end
    if numel(conditionNames) ~= cueCount
        conditionNames = "Cue" + (1:cueCount);
    else
        conditionNames = reshape(conditionNames, 1, []);
    end
    channelMap = validateChannelMap(channelMap, channelCount);

    quickCoherence = inferQuickCoherence(size(quickMean, 2));
    stimCoherence = reshape(stimCoherence, 1, []);
    if numel(stimCoherence) ~= size(stimMeanAll, 2)
        error('QuickStimCorrelation:StimCoherenceSizeMismatch', ...
            'Stim coherence axis and tuning array have different sizes.');
    end
    [isShared, stimColumns] = ismember( ...
        round(quickCoherence, 2), round(stimCoherence, 2));
    quickColumns = 1:numel(isShared);
    quickColumns = quickColumns(isShared);
    stimColumns = stimColumns(isShared);
    sharedCoherence = quickCoherence(isShared);
    if numel(sharedCoherence) < 3
        error('QuickStimCorrelation:InsufficientSharedCoherence', ...
            'Only %d shared coherence values were found.', ...
            numel(sharedCoherence));
    end

    quickShared = quickMean(:, quickColumns, :);
    stimReference = reshape(stimMeanAll( ...
        :, stimColumns, stimChannel), cueCount, []);
    quickZ = zScoreEachCue(quickShared);
    stimZ = zScoreEachCue(stimReference);
    referenceMask = isfinite(stimZ);
    referenceValueCount = nnz(referenceMask);
    if referenceValueCount < 3
        error('QuickStimCorrelation:InsufficientReferenceValues', ...
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
    pearsonR = nan(channelCount, 1);
    pearsonP = nan(channelCount, 1);
    rawPearsonR = nan(channelCount, 1);
    cueR = nan(channelCount, cueCount);

    for candidate = 1:channelCount
        candidateZ = quickZ(:, :, candidate);
        candidateRaw = quickShared(:, :, candidate);
        pairedMask = referenceMask & isfinite(candidateZ);
        pairedValueCount(candidate) = nnz(pairedMask);
        isComplete(candidate) = ...
            pairedValueCount(candidate) == referenceValueCount;
        if isComplete(candidate)
            [pearsonR(candidate), pearsonP(candidate)] = ...
                finiteCorrelation(stimZ(:), candidateZ(:));
            rawPearsonR(candidate) = finiteCorrelation( ...
                stimReference(:), candidateRaw(:));
            for cue = 1:cueCount
                cueR(candidate, cue) = finiteCorrelation( ...
                    stimZ(cue, :), candidateZ(cue, :));
            end
        end
    end

    rank = nan(channelCount, 1);
    rankable = find(isComplete & isfinite(pearsonR));
    if isempty(rankable)
        error('QuickStimCorrelation:NoRankableChannels', ...
            'No Quick channel has a complete, nonconstant tuning vector.');
    end
    rankingTable = table(rankable, pearsonR(rankable), ...
        'VariableNames', {'Channel', 'PearsonR'});
    rankingTable = sortrows(rankingTable, ...
        {'PearsonR', 'Channel'}, {'descend', 'ascend'});
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
        referenceCountColumn, pairedValueCount, isComplete, pearsonR, ...
        pearsonP, rawPearsonR, rank, isBest, isStimChannel, ...
        'VariableNames', {'UnitTableRow', 'Monkey', 'Date', ...
        'StimChannel', 'QuickChannel', 'ProbePosition', ...
        'RelativePositionToStim', 'DistanceToStimMicrometers', ...
        'SharedCoherenceCount', 'ReferenceValueCount', ...
        'PairedValueCount', 'IsComplete', 'PearsonR', 'PearsonP', ...
        'RawPearsonR', 'Rank', 'IsBest', 'IsStimChannel'});
    cueVariableNames = matlab.lang.makeUniqueStrings( ...
        "PearsonR_" + matlab.lang.makeValidName(conditionNames));
    for cue = 1:cueCount
        channelResult.(cueVariableNames(cue)) = cueR(:, cue);
    end

    stimQuickR = pearsonR(stimChannel);
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
    sessionResult.BestPearsonR = pearsonR(bestChannel);
    sessionResult.BestPearsonP = pearsonP(bestChannel);
    sessionResult.StimChannelPearsonR = stimQuickR;
    sessionResult.StimChannelRank = rank(stimChannel);
    sessionResult.StimChannelIsBest = bestChannel == stimChannel;
catch ME
    sessionResult.Status = "Error";
    sessionResult.Message = string(ME.identifier) + ": " + ...
        string(ME.message);
end
end


function rowTable = makeEmptySessionRow( ...
    row, monkey, recordingDate, stimChannel, channelCount, sourceStatus)
unitTableRow = row;
sharedCoherenceCount = 0;
sharedCoherence = {zeros(1, 0)};
referenceValueCount = 0;
completeChannelCount = 0;
bestChannel = NaN;
bestProbePosition = NaN;
bestRelativePositionToStim = NaN;
bestDistanceToStimMicrometers = NaN;
bestPearsonR = NaN;
bestPearsonP = NaN;
stimChannelPearsonR = NaN;
stimChannelRank = NaN;
stimChannelIsBest = false;
status = "Pending";
message = "";
rowTable = table(unitTableRow, monkey, recordingDate, stimChannel, ...
    channelCount, sourceStatus, sharedCoherenceCount, sharedCoherence, ...
    referenceValueCount, completeChannelCount, bestChannel, ...
    bestProbePosition, bestRelativePositionToStim, ...
    bestDistanceToStimMicrometers, bestPearsonR, bestPearsonP, ...
    stimChannelPearsonR, stimChannelRank, stimChannelIsBest, status, ...
    message, 'VariableNames', {'UnitTableRow', 'Monkey', 'Date', ...
    'StimChannel', 'ChannelCount', 'InputStatus', ...
    'SharedCoherenceCount', 'SharedCoherence', 'ReferenceValueCount', ...
    'CompleteChannelCount', 'BestChannel', 'BestProbePosition', ...
    'BestRelativePositionToStim', 'BestDistanceToStimMicrometers', ...
    'BestPearsonR', 'BestPearsonP', 'StimChannelPearsonR', ...
    'StimChannelRank', 'StimChannelIsBest', 'Status', 'Message'});
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
        error('QuickStimCorrelation:UnknownQuickCoherenceGrid', ...
            ['Cannot infer the Quick coherence axis from %d columns. ' ...
            'Expected 8, 12, or 13.'], coherenceCount);
end
coherence = numerator ./ 22;
end


function zValues = zScoreEachCue(meanValues)
zValues = nan(size(meanValues));
for channel = 1:size(meanValues, 3)
    for cue = 1:size(meanValues, 1)
        values = reshape(meanValues(cue, :, channel), 1, []);
        finiteMask = isfinite(values);
        if nnz(finiteMask) < 2
            continue
        end
        scale = std(values(finiteMask), 0);
        if isfinite(scale) && scale > 0
            zValues(cue, finiteMask, channel) = ...
                (values(finiteMask) - mean(values(finiteMask))) ./ scale;
        end
    end
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


function figureHandle = makePopulationPlot( ...
    sessionSummary, channelCorrelations, visible)
visibility = "off";
if visible
    visibility = "on";
end
figureHandle = figure('Color', 'w', 'Visible', visibility, ...
    'Name', 'Quick versus Stim NoStim tuning correlations', ...
    'Position', [80 80 1450 820]);
layout = tiledlayout(figureHandle, 2, 2, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
successful = sessionSummary.Status == "Success";

axesHandle = nexttile(layout);
histogram(axesHandle, sessionSummary.BestPearsonR(successful), ...
    -1:0.05:1, 'FaceColor', [0.12 0.48 0.72], 'EdgeColor', 'none');
xline(axesHandle, median(sessionSummary.BestPearsonR(successful), ...
    'omitnan'), '--k', 'Median');
xlabel(axesHandle, 'Best pooled Pearson r');
ylabel(axesHandle, 'Sessions');
title(axesHandle, 'Strongest Quick-channel match');
grid(axesHandle, 'on');

axesHandle = nexttile(layout);
relative = sessionSummary.BestRelativePositionToStim(successful);
relative = relative(isfinite(relative));
if isempty(relative)
    histogram(axesHandle, NaN);
else
    positions = min(relative):max(relative);
    histogram(axesHandle, relative, ...
        [positions - 0.5, positions(end) + 0.5], ...
        'FaceColor', [0.20 0.62 0.32], 'EdgeColor', 'none');
    xticks(axesHandle, positions);
end
xlabel(axesHandle, 'Best channel position relative to Stim electrode');
ylabel(axesHandle, 'Sessions');
title(axesHandle, 'Location of the best match');
grid(axesHandle, 'on');

axesHandle = nexttile(layout);
scatter(axesHandle, sessionSummary.StimChannelPearsonR(successful), ...
    sessionSummary.BestPearsonR(successful), 24, 'filled', ...
    'MarkerFaceAlpha', 0.55);
hold(axesHandle, 'on');
plot(axesHandle, [-1 1], [-1 1], '--', 'Color', [0.4 0.4 0.4]);
xlim(axesHandle, [-1 1]);
ylim(axesHandle, [-1 1]);
axis(axesHandle, 'square');
xlabel(axesHandle, 'Quick Stim-electrode channel r');
ylabel(axesHandle, 'Best Quick channel r');
title(axesHandle, 'Stim electrode versus winning channel');
grid(axesHandle, 'on');

axesHandle = nexttile(layout);
rankable = channelCorrelations.IsComplete & ...
    isfinite(channelCorrelations.PearsonR);
boxchart(axesHandle, ...
    categorical(channelCorrelations.RelativePositionToStim(rankable)), ...
    channelCorrelations.PearsonR(rankable), ...
    'BoxFaceColor', [0.56 0.36 0.68], 'MarkerStyle', '.');
xlabel(axesHandle, 'Quick channel position relative to Stim electrode');
ylabel(axesHandle, 'Pooled Pearson r');
title(axesHandle, 'Correlation by probe position');
grid(axesHandle, 'on');

title(layout, sprintf( ...
    '3DMotionQuick versus 3DMotionStim NoStim tuning | %d sessions', ...
    nnz(successful)), 'FontWeight', 'bold');
end


function figureHandle = makeBestLocationScatter(sessionSummary, visible)
visibility = "off";
if visible
    visibility = "on";
end
successful = sessionSummary.Status == "Success" & ...
    isfinite(sessionSummary.BestRelativePositionToStim) & ...
    isfinite(sessionSummary.BestPearsonR);
plotData = sessionSummary(successful, :);
positions = min(plotData.BestRelativePositionToStim): ...
    max(plotData.BestRelativePositionToStim);

% Deterministic horizontal jitter reveals sessions at the same integer
% probe position while preserving their true channel-location category.
jitteredPosition = plotData.BestRelativePositionToStim;
for position = positions
    rows = find(plotData.BestRelativePositionToStim == position);
    if numel(rows) > 1
        [~, order] = sort(plotData.BestPearsonR(rows), 'ascend');
        offsets = linspace(-0.27, 0.27, numel(rows))';
        jitteredPosition(rows(order)) = position + offsets;
    end
end

figureHandle = figure('Color', 'w', 'Visible', visibility, ...
    'Name', 'Best channel location versus Pearson r', ...
    'Position', [140 100 1180 760]);
axesHandle = axes(figureHandle);
hold(axesHandle, 'on');
monkeys = unique(plotData.Monkey, 'stable');
colors = lines(max(2, numel(monkeys)));
for monkeyIndex = 1:numel(monkeys)
    monkeyMask = plotData.Monkey == monkeys(monkeyIndex);
    scatter(axesHandle, jitteredPosition(monkeyMask), ...
        plotData.BestPearsonR(monkeyMask), 38, ...
        colors(monkeyIndex, :), 'filled', ...
        'MarkerFaceAlpha', 0.66, 'MarkerEdgeColor', 'w', ...
        'LineWidth', 0.35, 'DisplayName', monkeys(monkeyIndex));
end
xline(axesHandle, 0, '--', 'Stim electrode', ...
    'Color', [0.25 0.25 0.25], 'LabelVerticalAlignment', 'bottom');
xticks(axesHandle, positions);
xlim(axesHandle, [positions(1) - 0.6, positions(end) + 0.6]);
ylim(axesHandle, [0 1]);
xlabel(axesHandle, ...
    'Best Quick channel position relative to stimulation electrode');
ylabel(axesHandle, 'Best pooled Pearson r');
title(axesHandle, sprintf( ...
    'Best-channel location and tuning correlation | %d sessions', ...
    height(plotData)));
legend(axesHandle, 'Location', 'best');
grid(axesHandle, 'on');
axesHandle.GridAlpha = 0.16;
axesHandle.XMinorGrid = 'off';
end

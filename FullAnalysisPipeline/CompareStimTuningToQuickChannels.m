function [Comparison, Figures] = CompareStimTuningToQuickChannels( ...
    stimTuningFile, unitTableGofFile, options)
%COMPARESTIMTUNINGTOQUICKCHANNELS Match Stim-file tuning to Quick channels.
%
% [Comparison, Figures] = CompareStimTuningToQuickChannels(...)
% compares the stimulation electrode's 3-D motion tuning measured during
% non-electrical-stimulation trials of a 3DMotionStim file with every
% channel's previously saved 3DMotionQuick tuning in unit_table_gof.
%
% Both recordings are first reduced to the same cue/coherence grid. Each
% cue is then z-scored independently across coherence with the sample
% standard deviation (N-1), matching unit_table_gof.tuning_z. The primary
% score is the unweighted sum of squared errors (SSE) across every cell in
% the fixed common grid. A channel is rankable only when all cells are
% finite; this prevents missing cells from producing an artificially small
% SSE.
%
% Required inputs:
%   stimTuningFile  - MAT file produced by Extract3DMotionStimTuning
%   unitTableGofFile - MAT file containing unit_table_gof
%
% Name-value options:
%   UnitTableRow       - explicit row (0 finds by Monkey + RecordingDate)
%   Monkey             - monkey used for row lookup (default "")
%   RecordingDate      - date used for row lookup (default NaT)
%   StimulationChannel - acquisition channel; 0 reads StimElec from table
%   Unit               - MUA/unit index in the Stim result (default 1)
%   OutputDirectory    - output folder (default beside Stim tuning MAT)
%   MakePlots          - create overlay and ranking figures (default true)
%   FigureVisible      - show figures on screen (default false)
%   SaveOutputs        - save MAT/CSV/FIG/PNG outputs (default true)
%
% Comparison.ChannelSummary is sorted by SSE. Comparison.CellComparison
% is a long-form audit table containing the two mean firing rates, their
% z-scores, residual, and squared error for every channel/cue/coherence.

arguments
    stimTuningFile (1, 1) string
    unitTableGofFile (1, 1) string
    options.UnitTableRow (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 0
    options.Monkey (1, 1) string = ""
    options.RecordingDate (1, 1) datetime = NaT
    options.StimulationChannel (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 0
    options.Unit (1, 1) double {mustBeInteger, mustBePositive} = 1
    options.OutputDirectory (1, 1) string = ""
    options.MakePlots (1, 1) logical = true
    options.FigureVisible (1, 1) logical = false
    options.SaveOutputs (1, 1) logical = true
end

if ~isfile(stimTuningFile)
    error('StimQuickComparison:MissingStimTuningFile', ...
        'Stim tuning MAT file not found: %s', stimTuningFile);
end
if ~isfile(unitTableGofFile)
    error('StimQuickComparison:MissingUnitTableFile', ...
        'unit_table_gof MAT file not found: %s', unitTableGofFile);
end

stimData = load(stimTuningFile, 'Neuro');
if ~isfield(stimData, 'Neuro')
    error('StimQuickComparison:MissingNeuro', ...
        'The Stim tuning MAT file does not contain Neuro: %s', ...
        stimTuningFile);
end
Neuro = stimData.Neuro;

tableData = load(unitTableGofFile, 'unit_table_gof');
if ~isfield(tableData, 'unit_table_gof') || ...
        ~istable(tableData.unit_table_gof)
    error('StimQuickComparison:MissingUnitTable', ...
        'The MAT file does not contain table unit_table_gof: %s', ...
        unitTableGofFile);
end
unitTable = tableData.unit_table_gof;

unitTableRow = resolveUnitTableRow(unitTable, options.UnitTableRow, ...
    options.Monkey, options.RecordingDate);
quickMean = getCellArray(unitTable, unitTableRow, 'tuning_mean');
if ~isnumeric(quickMean) || ndims(quickMean) ~= 3
    error('StimQuickComparison:InvalidQuickTuning', ...
        'tuning_mean at row %d must be a cue x coherence x channel array.', ...
        unitTableRow);
end
quickMean = double(quickMean);

conditionCount = size(quickMean, 1);
quickCoherence = inferQuickCoherence(size(quickMean, 2));
conditionNames = getConditionNames(Neuro, conditionCount);

[stimMeanAll, stimCoherence, stimGroupName] = getNoStimMeans(Neuro);
if size(stimMeanAll, 1) ~= conditionCount
    error('StimQuickComparison:CueCountMismatch', ...
        ['Quick tuning has %d cues, but the Stim NoStim tuning has %d. ' ...
        'Cue indices must correspond one-to-one.'], ...
        conditionCount, size(stimMeanAll, 1));
end

stimulationChannel = options.StimulationChannel;
if stimulationChannel == 0
    stimulationChannel = getScalarTableValue( ...
        unitTable, unitTableRow, 'StimElec');
end
if ~isscalar(stimulationChannel) || ~isfinite(stimulationChannel) || ...
        stimulationChannel < 1 || stimulationChannel ~= fix(stimulationChannel)
    error('StimQuickComparison:InvalidStimChannel', ...
        'The stimulation channel must be a positive integer.');
end
if stimulationChannel > size(stimMeanAll, 3)
    error('StimQuickComparison:StimChannelOutOfRange', ...
        'Stim channel %d exceeds the %d channels in Neuro.', ...
        stimulationChannel, size(stimMeanAll, 3));
end
if stimulationChannel > size(quickMean, 3)
    error('StimQuickComparison:QuickStimChannelOutOfRange', ...
        'Stim channel %d exceeds the %d Quick channels.', ...
        stimulationChannel, size(quickMean, 3));
end
if options.Unit > size(stimMeanAll, 4)
    error('StimQuickComparison:UnitOutOfRange', ...
        'Unit %d exceeds the %d units in Neuro.', ...
        options.Unit, size(stimMeanAll, 4));
end

roundedQuickCoherence = round(quickCoherence, 2);
roundedStimCoherence = round(stimCoherence, 2);
[isCommon, stimColumn] = ismember( ...
    roundedQuickCoherence, roundedStimCoherence);
if ~all(isCommon)
    missing = join(string(quickCoherence(~isCommon)), ', ');
    error('StimQuickComparison:MissingStimCoherence', ...
        'Stim tuning is missing Quick coherence value(s): %s', missing);
end

stimMean = reshape(stimMeanAll( ...
    :, stimColumn, stimulationChannel, options.Unit), ...
    [conditionCount numel(stimColumn)]);
quickZ = zScoreEachCue(quickMean);
stimZ = zScoreEachCue(stimMean);

quickStoredZ = [];
if ismember('tuning_z', unitTable.Properties.VariableNames)
    quickStoredZCandidate = getCellArray( ...
        unitTable, unitTableRow, 'tuning_z');
    if isnumeric(quickStoredZCandidate) && ...
            isequal(size(quickStoredZCandidate), size(quickMean))
        quickStoredZ = double(quickStoredZCandidate);
    end
end

channelCount = size(quickMean, 3);
channelMap = getChannelMap(Neuro, channelCount);
probePosition = nan(channelCount, 1);
for mapIndex = 1:numel(channelMap)
    probePosition(channelMap(mapIndex)) = mapIndex;
end
stimProbePosition = probePosition(stimulationChannel);

expectedCellCount = numel(stimZ);
sseByCue = nan(channelCount, conditionCount);
sse = nan(channelCount, 1);
rmse = nan(channelCount, 1);
correlation = nan(channelCount, 1);
pairedValueCount = zeros(channelCount, 1);
storedZMaxAbsDifference = nan(channelCount, 1);
isComplete = false(channelCount, 1);

stimFinite = isfinite(stimZ);
for channel = 1:channelCount
    candidateZ = quickZ(:, :, channel);
    pairedMask = stimFinite & isfinite(candidateZ);
    pairedValueCount(channel) = nnz(pairedMask);
    isComplete(channel) = pairedValueCount(channel) == expectedCellCount;
    if isComplete(channel)
        residual = candidateZ - stimZ;
        squaredResidual = residual .^ 2;
        sseByCue(channel, :) = sum(squaredResidual, 2)';
        sse(channel) = sum(squaredResidual, 'all');
        rmse(channel) = sqrt(mean(squaredResidual, 'all'));
        correlation(channel) = finiteCorrelation(stimZ(:), candidateZ(:));
    end
    if ~isempty(quickStoredZ)
        storedDifference = abs(candidateZ - quickStoredZ(:, :, channel));
        storedZMaxAbsDifference(channel) = max(storedDifference, [], 'all');
    end
end

rank = nan(channelCount, 1);
finiteChannels = find(isfinite(sse));
[~, finiteOrder] = sort(sse(finiteChannels), 'ascend');
rankedChannels = finiteChannels(finiteOrder);
rank(rankedChannels) = (1:numel(rankedChannels))';
if isempty(rankedChannels)
    error('StimQuickComparison:NoCompleteChannels', ...
        ['No Quick channel has all %d finite cue/coherence cells. ' ...
        'Incomplete channels are intentionally not ranked.'], ...
        expectedCellCount);
end
bestChannel = rankedChannels(1);

channel = (1:channelCount)';
relativePositionToStim = probePosition - stimProbePosition;
distanceToStimMicrometers = 50 .* relativePositionToStim;
isBest = channel == bestChannel;
isStimChannel = channel == stimulationChannel;
cueVariableNames = matlab.lang.makeUniqueStrings( ...
    "SSE_" + matlab.lang.makeValidName(conditionNames));
channelSummaryByChannel = table(channel, probePosition, ...
    relativePositionToStim, distanceToStimMicrometers, pairedValueCount, ...
    isComplete, sse, rmse, correlation, rank, isBest, isStimChannel, ...
    storedZMaxAbsDifference, ...
    'VariableNames', {'Channel', 'ProbePosition', ...
    'RelativePositionToStim', 'DistanceToStimMicrometers', ...
    'PairedValueCount', 'IsComplete', 'SSE', 'RMSE', 'PearsonR', ...
    'Rank', 'IsBest', 'IsStimChannel', 'StoredZMaxAbsDifference'});
for cue = 1:conditionCount
    channelSummaryByChannel.(cueVariableNames(cue)) = sseByCue(:, cue);
end
channelSummary = sortrows(channelSummaryByChannel, ...
    {'IsComplete', 'SSE', 'Channel'}, ["descend", "ascend", "ascend"]);

cellComparison = buildCellComparison(quickMean, quickZ, stimMean, stimZ, ...
    quickCoherence, conditionNames, probePosition, ...
    relativePositionToStim);

Comparison = struct();
Comparison.StimTuningFile = stimTuningFile;
Comparison.UnitTableGofFile = unitTableGofFile;
Comparison.UnitTableRow = unitTableRow;
Comparison.StimulationChannel = stimulationChannel;
Comparison.StimulationProbePosition = stimProbePosition;
Comparison.Unit = options.Unit;
Comparison.StimGroup = stimGroupName;
Comparison.ZScoreConvention = ...
    "Within each cue across the common coherence means; sample SD (N-1)";
Comparison.SSEConvention = ...
    "Unweighted sum across the complete fixed cue-by-coherence grid";
Comparison.ConditionNames = conditionNames;
Comparison.Coherence = quickCoherence;
Comparison.ChannelMap = channelMap;
Comparison.StimMeanFR = stimMean;
Comparison.StimZ = stimZ;
Comparison.QuickMeanFR = quickMean;
Comparison.QuickZ = quickZ;
Comparison.ExpectedCellCount = expectedCellCount;
Comparison.BestChannel = bestChannel;
Comparison.BestSSE = sse(bestChannel);
Comparison.ChannelSummary = channelSummary;
Comparison.ChannelSummaryByChannel = channelSummaryByChannel;
Comparison.CellComparison = cellComparison;
Comparison.OutputPaths = struct();

Figures = struct('AllChannels', gobjects(0), ...
    'BestChannel', gobjects(0), 'SSERanking', gobjects(0));
if options.MakePlots
    Figures.AllChannels = plotAllChannelOverlays( ...
        Comparison, options.FigureVisible);
    Figures.BestChannel = plotBestChannelOverlay( ...
        Comparison, options.FigureVisible);
    Figures.SSERanking = plotSSERanking( ...
        Comparison, options.FigureVisible);
end

if options.SaveOutputs
    outputDirectory = options.OutputDirectory;
    if strlength(outputDirectory) == 0
        outputDirectory = string(fileparts(stimTuningFile));
    end
    if ~isfolder(outputDirectory)
        mkdir(outputDirectory);
    end
    baseName = sprintf('StimVsQuick_Row%d_StimCh%d', ...
        unitTableRow, stimulationChannel);
    Comparison.OutputPaths.ResultMAT = fullfile( ...
        outputDirectory, baseName + "_Comparison.mat");
    Comparison.OutputPaths.ChannelSummaryCSV = fullfile( ...
        outputDirectory, baseName + "_ChannelSummary.csv");
    Comparison.OutputPaths.CellComparisonCSV = fullfile( ...
        outputDirectory, baseName + "_CellComparison.csv");
    writetable(Comparison.ChannelSummary, ...
        Comparison.OutputPaths.ChannelSummaryCSV);
    writetable(Comparison.CellComparison, ...
        Comparison.OutputPaths.CellComparisonCSV);

    if options.MakePlots
        [Comparison.OutputPaths.AllChannelsPNG, ...
            Comparison.OutputPaths.AllChannelsFIG] = saveFigurePair( ...
            Figures.AllChannels, outputDirectory, ...
            baseName + "_AllChannelsOverlay");
        [Comparison.OutputPaths.BestChannelPNG, ...
            Comparison.OutputPaths.BestChannelFIG] = saveFigurePair( ...
            Figures.BestChannel, outputDirectory, ...
            baseName + "_BestChannelOverlay");
        [Comparison.OutputPaths.SSERankingPNG, ...
            Comparison.OutputPaths.SSERankingFIG] = saveFigurePair( ...
            Figures.SSERanking, outputDirectory, ...
            baseName + "_SSERanking");
    end
    save(Comparison.OutputPaths.ResultMAT, 'Comparison', '-v7.3');
end

fprintf(['Best Quick match: channel %d (probe position %d, relative %+.0f), ' ...
    'SSE = %.6f across %d cells.\n'], bestChannel, ...
    probePosition(bestChannel), relativePositionToStim(bestChannel), ...
    Comparison.BestSSE, expectedCellCount);
end


function row = resolveUnitTableRow(unitTable, requestedRow, monkey, dateValue)
if requestedRow > 0
    if requestedRow > height(unitTable)
        error('StimQuickComparison:UnitTableRowOutOfRange', ...
            'UnitTableRow %d exceeds table height %d.', ...
            requestedRow, height(unitTable));
    end
    row = requestedRow;
    return
end

if strlength(monkey) == 0 || isnat(dateValue)
    error('StimQuickComparison:MissingRowLookupKeys', ...
        ['Provide UnitTableRow, or provide both Monkey and ' ...
        'RecordingDate for a unique lookup.']);
end
monkeyVariable = findVariable(unitTable, ["Monkey", "Animal"]);
dateVariable = findVariable(unitTable, ...
    ["Date", "RecordingDate", "RecDate", "SessionDate"]);
monkeyValues = string(unitTable.(monkeyVariable));
dateValues = normalizeDates(unitTable.(dateVariable));
targetDate = dateshift(dateValue, 'start', 'day');
matches = strcmpi(strtrim(monkeyValues), strtrim(monkey)) & ...
    dateValues == targetDate;
matchingRows = find(matches);
if numel(matchingRows) ~= 1
    error('StimQuickComparison:NonuniqueUnitTableMatch', ...
        ['Monkey=%s and date=%s matched %d unit_table_gof rows; ' ...
        'provide UnitTableRow explicitly.'], monkey, ...
        string(targetDate, 'yyyy-MM-dd'), numel(matchingRows));
end
row = matchingRows;
end


function variableName = findVariable(unitTable, candidates)
variables = string(unitTable.Properties.VariableNames);
for candidate = candidates
    match = find(strcmpi(variables, candidate), 1);
    if ~isempty(match)
        variableName = char(variables(match));
        return
    end
end
error('StimQuickComparison:MissingTableVariable', ...
    'Could not find any of these table variables: %s', ...
    join(candidates, ', '));
end


function dates = normalizeDates(values)
if iscell(values)
    values = string(values);
end
if isdatetime(values)
    dates = dateshift(values, 'start', 'day');
elseif isnumeric(values)
    if all(isnan(values) | values > 1e7)
        dates = datetime(string(values), 'InputFormat', 'yyyyMMdd');
    else
        dates = datetime(values, 'ConvertFrom', 'datenum');
    end
    dates = dateshift(dates, 'start', 'day');
else
    dates = dateshift(datetime(string(values)), 'start', 'day');
end
end


function value = getCellArray(unitTable, row, variableName)
if ~ismember(variableName, unitTable.Properties.VariableNames)
    error('StimQuickComparison:MissingTableVariable', ...
        'unit_table_gof is missing variable %s.', variableName);
end
column = unitTable.(variableName);
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
end


function value = getScalarTableValue(unitTable, row, variableName)
value = getCellArray(unitTable, row, variableName);
if iscell(value) && isscalar(value)
    value = value{1};
end
if isstring(value) || ischar(value)
    value = str2double(string(value));
end
value = double(value);
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
        error('StimQuickComparison:UnknownQuickCoherenceGrid', ...
            ['Cannot infer the Quick coherence axis from %d columns. ' ...
            'Expected 8, 12, or 13.'], coherenceCount);
end
coherence = numerator ./ 22;
end


function names = getConditionNames(Neuro, conditionCount)
if isfield(Neuro, 'ConditionNames') && ...
        numel(Neuro.ConditionNames) == conditionCount
    names = string(Neuro.ConditionNames(:)');
elseif conditionCount == 4
    names = ["Combined", "MonoL", "MonoR", "Binocular"];
else
    names = "Cue" + (1:conditionCount);
end
end


function [means, coherence, groupName] = getNoStimMeans(Neuro)
if isfield(Neuro, 'WithZero') && isfield(Neuro.WithZero, 'NoStim') && ...
        isfield(Neuro.WithZero.NoStim, 'Means') && ...
        isfield(Neuro, 'CoherenceArrayWithZero')
    means = Neuro.WithZero.NoStim.Means;
    coherence = double(Neuro.CoherenceArrayWithZero(:)');
    groupName = "Neuro.WithZero.NoStim";
elseif isfield(Neuro, 'NoStim') && isfield(Neuro.NoStim, 'Means') && ...
        isfield(Neuro, 'CoherenceArray')
    means = Neuro.NoStim.Means;
    coherence = double(Neuro.CoherenceArray(:)');
    groupName = "Neuro.NoStim";
elseif isfield(Neuro, 'Means') && isfield(Neuro, 'CoherenceArray')
    means = Neuro.Means;
    coherence = double(Neuro.CoherenceArray(:)');
    groupName = "Neuro (top-level NoStim)";
else
    error('StimQuickComparison:MissingNoStimMeans', ...
        'Could not find NoStim Means and its coherence axis in Neuro.');
end
if size(means, 2) ~= numel(coherence)
    error('StimQuickComparison:StimCoherenceSizeMismatch', ...
        'Stim Means has %d columns but its coherence axis has %d values.', ...
        size(means, 2), numel(coherence));
end
end


function zValues = zScoreEachCue(meanValues)
zValues = nan(size(meanValues));
channelCount = size(meanValues, 3);
for channel = 1:channelCount
    for cue = 1:size(meanValues, 1)
        values = reshape(meanValues(cue, :, channel), 1, []);
        finiteMask = isfinite(values);
        if nnz(finiteMask) < 2
            continue
        end
        center = mean(values(finiteMask));
        scale = std(values(finiteMask), 0);
        if isfinite(scale) && scale > 0
            zValues(cue, finiteMask, channel) = ...
                (values(finiteMask) - center) ./ scale;
        end
    end
end
end


function channelMap = getChannelMap(Neuro, channelCount)
defaultMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10];
if isfield(Neuro, 'ChannelMap')
    candidate = double(Neuro.ChannelMap(:)');
else
    candidate = defaultMap;
end
if numel(candidate) == channelCount && ...
        isequal(sort(candidate), 1:channelCount)
    channelMap = candidate;
elseif channelCount == numel(defaultMap)
    channelMap = defaultMap;
else
    channelMap = 1:channelCount;
end
end


function r = finiteCorrelation(x, y)
valid = isfinite(x) & isfinite(y);
if nnz(valid) < 2 || std(x(valid), 0) == 0 || std(y(valid), 0) == 0
    r = NaN;
    return
end
matrix = corrcoef(x(valid), y(valid));
r = matrix(1, 2);
end


function longTable = buildCellComparison( ...
    quickMean, quickZ, stimMean, stimZ, coherence, conditionNames, ...
    probePosition, relativePositionToStim)
channelCount = size(quickMean, 3);
cueCount = size(quickMean, 1);
coherenceCount = size(quickMean, 2);
rowCount = channelCount * cueCount * coherenceCount;
channelColumn = zeros(rowCount, 1);
probeColumn = zeros(rowCount, 1);
relativeColumn = zeros(rowCount, 1);
cueIndexColumn = zeros(rowCount, 1);
cueColumn = strings(rowCount, 1);
coherenceColumn = zeros(rowCount, 1);
stimMeanColumn = nan(rowCount, 1);
quickMeanColumn = nan(rowCount, 1);
stimZColumn = nan(rowCount, 1);
quickZColumn = nan(rowCount, 1);
residualColumn = nan(rowCount, 1);
squaredErrorColumn = nan(rowCount, 1);

row = 0;
for channel = 1:channelCount
    for cue = 1:cueCount
        for coherenceIndex = 1:coherenceCount
            row = row + 1;
            channelColumn(row) = channel;
            probeColumn(row) = probePosition(channel);
            relativeColumn(row) = relativePositionToStim(channel);
            cueIndexColumn(row) = cue;
            cueColumn(row) = conditionNames(cue);
            coherenceColumn(row) = coherence(coherenceIndex);
            stimMeanColumn(row) = stimMean(cue, coherenceIndex);
            quickMeanColumn(row) = quickMean(cue, coherenceIndex, channel);
            stimZColumn(row) = stimZ(cue, coherenceIndex);
            quickZColumn(row) = quickZ(cue, coherenceIndex, channel);
            residualColumn(row) = quickZColumn(row) - stimZColumn(row);
            squaredErrorColumn(row) = residualColumn(row) .^ 2;
        end
    end
end
longTable = table(channelColumn, probeColumn, relativeColumn, ...
    cueIndexColumn, cueColumn, coherenceColumn, stimMeanColumn, ...
    quickMeanColumn, stimZColumn, quickZColumn, residualColumn, ...
    squaredErrorColumn, 'VariableNames', {'Channel', 'ProbePosition', ...
    'RelativePositionToStim', 'CueIndex', 'Cue', 'Coherence', ...
    'StimMeanFR', 'QuickMeanFR', 'StimZ', 'QuickZ', 'Residual', ...
    'SquaredError'});
end


function figureHandle = plotAllChannelOverlays(Comparison, visible)
figureHandle = makeFigure(visible, 'Stim versus Quick: all channels', ...
    [80 40 1760 1080]);
layout = tiledlayout(figureHandle, 4, 4, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
colors = cueColors(numel(Comparison.ConditionNames));
zLimit = commonZLimit(Comparison.StimZ, Comparison.QuickZ);
legendHandles = gobjects(1, numel(Comparison.ConditionNames));
for tile = 1:numel(Comparison.ChannelMap)
    axesHandle = nexttile(layout, tile);
    channel = Comparison.ChannelMap(tile);
    hold(axesHandle, 'on');
    for cue = 1:numel(Comparison.ConditionNames)
        stimCurve = drawTranslucentCurve(axesHandle, Comparison.Coherence, ...
            Comparison.StimZ(cue, :), colors(cue, :), 0.22, 5);
        stimCurve.HandleVisibility = 'off';
    end
    for cue = 1:numel(Comparison.ConditionNames)
        quickCurve = plot(axesHandle, Comparison.Coherence, ...
            Comparison.QuickZ(cue, :, channel), '-o', ...
            'Color', colors(cue, :), ...
            'MarkerFaceColor', colors(cue, :), 'MarkerSize', 3, ...
            'LineWidth', 1.2, 'DisplayName', ...
            Comparison.ConditionNames(cue));
        if tile == 1
            legendHandles(cue) = quickCurve;
        end
    end
    yline(axesHandle, 0, ':', 'Color', [0.7 0.7 0.7], ...
        'HandleVisibility', 'off');
    xlim(axesHandle, [min(Comparison.Coherence) ...
        max(Comparison.Coherence)]);
    ylim(axesHandle, [-zLimit zLimit]);
    xticks(axesHandle, [-1 -0.5 0 0.5 1]);
    grid(axesHandle, 'on');
    axesHandle.GridAlpha = 0.10;
    summaryRow = Comparison.ChannelSummaryByChannel( ...
        Comparison.ChannelSummaryByChannel.Channel == channel, :);
    titleText = string(sprintf('Ch %d | SSE %.2f | #%d', channel, ...
        summaryRow.SSE, summaryRow.Rank));
    if summaryRow.IsStimChannel
        titleText = titleText + " | stim elec";
    end
    title(axesHandle, titleText, 'FontSize', 9, ...
        'FontWeight', 'normal');
    if summaryRow.IsBest
        title(axesHandle, titleText, 'FontSize', 9, 'FontWeight', 'bold');
        axesHandle.LineWidth = 2;
        axesHandle.XColor = [0.05 0.45 0.15];
        axesHandle.YColor = [0.05 0.45 0.15];
    end
    if tile > 12
        xlabel(axesHandle, 'Coherence');
    end
    if mod(tile - 1, 4) == 0
        ylabel(axesHandle, 'Z-scored mean FR');
    end
end
title(layout, {sprintf(['Stim-period NoStim channel %d behind each ' ...
    '3DMotionQuick channel'], Comparison.StimulationChannel), ...
    sprintf(['Thick translucent = Stim reference; opaque circles = Quick; ' ...
    'best channel %d, SSE %.3f'], ...
    Comparison.BestChannel, Comparison.BestSSE)}, ...
    'FontWeight', 'bold');
legendAxes = nexttile(layout, 1);
legendHandle = legend(legendAxes, legendHandles, ...
    cellstr(Comparison.ConditionNames), ...
    'Orientation', 'horizontal', 'FontSize', 8);
legendHandle.Layout.Tile = 'south';
end


function figureHandle = plotBestChannelOverlay(Comparison, visible)
figureHandle = makeFigure(visible, 'Stim versus Quick: best channel', ...
    [160 90 1180 800]);
layout = tiledlayout(figureHandle, 2, 2, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
colors = cueColors(numel(Comparison.ConditionNames));
zLimit = commonZLimit(Comparison.StimZ, ...
    Comparison.QuickZ(:, :, Comparison.BestChannel));
for cue = 1:numel(Comparison.ConditionNames)
    axesHandle = nexttile(layout, cue);
    hold(axesHandle, 'on');
    stimHandle = drawTranslucentCurve(axesHandle, ...
        Comparison.Coherence, Comparison.StimZ(cue, :), ...
        colors(cue, :), 0.25, 7);
    quickHandle = plot(axesHandle, Comparison.Coherence, ...
        Comparison.QuickZ(cue, :, Comparison.BestChannel), '-o', ...
        'Color', colors(cue, :), ...
        'MarkerFaceColor', colors(cue, :), 'MarkerSize', 6, ...
        'LineWidth', 2);
    yline(axesHandle, 0, ':', 'Color', [0.7 0.7 0.7], ...
        'HandleVisibility', 'off');
    xlim(axesHandle, [min(Comparison.Coherence) ...
        max(Comparison.Coherence)]);
    ylim(axesHandle, [-zLimit zLimit]);
    xticks(axesHandle, Comparison.Coherence);
    xtickformat(axesHandle, '%.2g');
    xtickangle(axesHandle, 30);
    grid(axesHandle, 'on');
    axesHandle.GridAlpha = 0.12;
    title(axesHandle, Comparison.ConditionNames(cue));
    xlabel(axesHandle, 'Coherence');
    ylabel(axesHandle, 'Z-scored mean FR');
    legend(axesHandle, [stimHandle quickHandle], ...
        {sprintf('Stim NoStim ch %d', Comparison.StimulationChannel), ...
        sprintf('Quick ch %d', Comparison.BestChannel)}, ...
        'Location', 'best');
end
bestRow = Comparison.ChannelSummaryByChannel( ...
    Comparison.ChannelSummaryByChannel.Channel == ...
    Comparison.BestChannel, :);
title(layout, {sprintf('Best one-to-one tuning match: Quick channel %d', ...
    Comparison.BestChannel), ...
    sprintf('SSE %.3f across %d cells | probe position %d | relative %+.0f', ...
    Comparison.BestSSE, Comparison.ExpectedCellCount, ...
    bestRow.ProbePosition, bestRow.RelativePositionToStim)}, ...
    'FontWeight', 'bold');
end


function figureHandle = plotSSERanking(Comparison, visible)
figureHandle = makeFigure(visible, 'Stim versus Quick: SSE ranking', ...
    [260 100 900 720]);
axesHandle = axes(figureHandle);
summary = Comparison.ChannelSummary;
summary = summary(summary.IsComplete, :);
barHandle = barh(axesHandle, summary.SSE, 0.72, ...
    'FaceColor', [0.25 0.48 0.72], 'EdgeColor', 'none');
barHandle.FaceColor = 'flat';
barHandle.CData = repmat([0.25 0.48 0.72], height(summary), 1);
barHandle.CData(summary.IsBest, :) = repmat( ...
    [0.10 0.60 0.25], nnz(summary.IsBest), 1);
barHandle.CData(summary.IsStimChannel, :) = repmat( ...
    [0.80 0.38 0.12], nnz(summary.IsStimChannel), 1);
axesHandle.YDir = 'reverse';
yticks(axesHandle, 1:height(summary));
labels = "Ch " + string(summary.Channel) + ...
    " (pos " + string(summary.ProbePosition) + ")";
labels(summary.IsBest) = labels(summary.IsBest) + "  BEST";
labels(summary.IsStimChannel) = labels(summary.IsStimChannel) + ...
    "  STIM ELEC";
yticklabels(axesHandle, labels);
xlabel(axesHandle, 'SSE across 4 cues x 8 coherences');
title(axesHandle, sprintf(['3DMotionQuick match to Stim-period NoStim ' ...
    'channel %d tuning'], Comparison.StimulationChannel));
grid(axesHandle, 'on');
axesHandle.XGrid = 'on';
axesHandle.YGrid = 'off';
axesHandle.GridAlpha = 0.15;
for row = 1:height(summary)
    text(axesHandle, summary.SSE(row), row, ...
        sprintf('  %.3f', summary.SSE(row)), ...
        'VerticalAlignment', 'middle', 'FontSize', 9);
end
xlim(axesHandle, [0 max(summary.SSE) * 1.13]);
end


function handle = drawTranslucentCurve( ...
    axesHandle, x, y, color, alpha, lineWidth)
handle = gobjects(0);
x = x(:)';
y = y(:)';
for index = 1:(numel(x) - 1)
    if all(isfinite([x(index:index + 1) y(index:index + 1)]))
        segment = patch(axesHandle, x(index:index + 1), ...
            y(index:index + 1), color, 'FaceColor', 'none', ...
            'EdgeColor', color, 'EdgeAlpha', alpha, ...
            'LineWidth', lineWidth, 'HandleVisibility', 'off');
        if isempty(handle)
            handle = segment;
        end
    end
end
if isempty(handle)
    handle = plot(axesHandle, nan, nan, '-', 'Color', color, ...
        'LineWidth', lineWidth);
end
handle.HandleVisibility = 'on';
scatter(axesHandle, x, y, 28, color, 'filled', ...
    'MarkerFaceAlpha', alpha, 'MarkerEdgeAlpha', alpha, ...
    'HandleVisibility', 'off');
end


function colors = cueColors(cueCount)
standardColors = [0 0 0; 0 0 255; 5 150 5; 234 0 233] ./ 255;
if cueCount <= size(standardColors, 1)
    colors = standardColors(1:cueCount, :);
else
    colors = lines(cueCount);
end
end


function limit = commonZLimit(stimZ, quickZ)
values = abs([stimZ(:); quickZ(:)]);
values = values(isfinite(values));
if isempty(values)
    limit = 3;
else
    limit = max(2.5, ceil(max(values) * 2) / 2);
end
end


function figureHandle = makeFigure(visible, name, position)
if visible
    visibility = 'on';
else
    visibility = 'off';
end
figureHandle = figure('Color', 'w', 'Visible', visibility, ...
    'Name', name, 'Position', position);
end


function [pngPath, figPath] = saveFigurePair( ...
    figureHandle, outputDirectory, baseName)
pngPath = fullfile(outputDirectory, baseName + ".png");
figPath = fullfile(outputDirectory, baseName + ".fig");
exportgraphics(figureHandle, pngPath, 'Resolution', 180);
savefig(figureHandle, figPath);
end

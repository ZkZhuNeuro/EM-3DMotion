function outputIndex = plot_good_trial_raw_eye_traces(tInfoFile, selIndexFile, varargin)
%PLOT_GOOD_TRIAL_RAW_EYE_TRACES Export raw eye-trace figures for good trials.
%
% outputIndex = plot_good_trial_raw_eye_traces(tInfoFile, selIndexFile)
% loads the saved TrialInfo/SelIndex pair, uses the matching microsaccade
% result MAT file when present, and writes one PNG per selected good trial.

parser = inputParser;
parser.FunctionName = mfilename;
addRequired(parser, 'tInfoFile', @(x) ischar(x) || isstring(x));
addRequired(parser, 'selIndexFile', @(x) ischar(x) || isstring(x));
addParameter(parser, 'ResultsFile', "", @(x) ischar(x) || isstring(x));
addParameter(parser, 'OutputDir', "", @(x) ischar(x) || isstring(x));
addParameter(parser, 'PreVisualWindowS', 0.12, @(x) isscalar(x) && x >= 0);
addParameter(parser, 'PostVisualWindowS', 0.12, @(x) isscalar(x) && x >= 0);
addParameter(parser, 'ConvertToDegrees', true, @(x) islogical(x) && isscalar(x));
addParameter(parser, 'Overwrite', true, @(x) islogical(x) && isscalar(x));
addParameter(parser, 'TrialIndices', [], @(x) isempty(x) || isnumeric(x) || islogical(x));
parse(parser, tInfoFile, selIndexFile, varargin{:});
options = parser.Results;

tInfoFile = char(tInfoFile);
selIndexFile = char(selIndexFile);
assert(isfile(tInfoFile), 'TrialInfo file not found: %s', tInfoFile);
assert(isfile(selIndexFile), 'SelIndex file not found: %s', selIndexFile);

if strlength(string(options.OutputDir)) == 0
    outputDir = fullfile(fileparts(tInfoFile), 'Clay_FST_17Feb2026_trial_eye_traces');
else
    outputDir = char(options.OutputDir);
end
if ~isfolder(outputDir)
    mkdir(outputDir);
end

resultsFile = char(options.ResultsFile);
if isempty(resultsFile)
    [~, stem] = fileparts(tInfoFile);
    stem = regexprep(stem, '_TInfo$', '', 'ignorecase');
    resultsFile = fullfile(fileparts(mfilename('fullpath')), 'results_engbert', ...
        [stem '_microsaccades.mat']);
end
assert(isfile(resultsFile), ['Microsaccade results file not found: %s\n' ...
    'Run analyze_microsaccades first or pass ''ResultsFile''.'], resultsFile);

fprintf('Loading raw trial data from %s\n', tInfoFile);
data = load(tInfoFile, 'TrialInfo', 'Config');
selectionData = load(selIndexFile, 'EditSel', 'Selected');
resultsData = load(resultsFile, 'Results');
TrialInfo = data.TrialInfo;
Config = data.Config;
Results = resultsData.Results;

[selection, selectionSource] = getSelection(selectionData);
assert(numel(selection) == numel(TrialInfo), ...
    'Selection length (%d) does not match TrialInfo length (%d).', ...
    numel(selection), numel(TrialInfo));

trialTable = Results.TrialTable;
eventTable = Results.MicrosaccadeTable;
if isempty(eventTable)
    eventTable = table;
end

goodTrialIndex = find(selection(:));
if ~isempty(options.TrialIndices)
    requestedTrials = normalizeTrialIndices(options.TrialIndices, numel(selection));
    goodTrialIndex = intersect(goodTrialIndex, requestedTrials, 'stable');
    assert(~isempty(goodTrialIndex), 'None of the requested TrialIndices are selected good trials.');
end
fprintf('Exporting %d %s trial figures to %s\n', ...
    numel(goodTrialIndex), selectionSource, outputDir);

indexRows = repmat(makeIndexRow(), numel(goodTrialIndex), 1);
unitLabel = 'screen mm';
if options.ConvertToDegrees
    assert(isfield(Config, 'ScrDistmm') && isfinite(Config.ScrDistmm) && Config.ScrDistmm > 0, ...
        'Config.ScrDistmm is required to convert eye position to degrees.');
    unitLabel = 'deg';
end

figureHandle = figure('Visible', 'off', 'Color', 'w', ...
    'Units', 'pixels', 'Position', [100 100 1650 760]);
cleanup = onCleanup(@() closeFigureIfValid(figureHandle)); %#ok<NASGU>

for iTrial = 1:numel(goodTrialIndex)
    trialIndex = goodTrialIndex(iTrial);
    trial = TrialInfo(trialIndex);
    trialRow = trialTable(trialTable.TrialIndex == trialIndex, :);
    if isempty(trialRow)
        trialRow = makeMissingTrialRow(trialIndex);
    end
    trialEvents = selectTrialEvents(eventTable, trialIndex);

    outputFile = fullfile(outputDir, sprintf('trial_%04d_raw_eye_traces.png', trialIndex));
    if ~options.Overwrite && isfile(outputFile)
        indexRows(iTrial) = makeIndexRowFromTrial(trialRow, trialEvents, outputFile);
        continue
    end

    clf(figureHandle);
    plotTrialFigure(figureHandle, trial, trialRow, trialEvents, Config, options, unitLabel);
    exportgraphics(figureHandle, outputFile, 'Resolution', 150);
    indexRows(iTrial) = makeIndexRowFromTrial(trialRow, trialEvents, outputFile);

    if mod(iTrial, 50) == 0 || iTrial == numel(goodTrialIndex)
        fprintf('  %d/%d figures exported\n', iTrial, numel(goodTrialIndex));
    end
end

outputIndex = struct2table(indexRows);
writetable(outputIndex, fullfile(outputDir, 'trial_eye_trace_index.csv'));
fprintf('Done. Index written to %s\n', fullfile(outputDir, 'trial_eye_trace_index.csv'));
end

function plotTrialFigure(figureHandle, trial, trialRow, trialEvents, Config, options, unitLabel)
time = trial.AITs(:);
visualOn = scalarFromTable(trialRow, 'VisualStimOnS');
visualOff = scalarFromTable(trialRow, 'VisualStimOffS');
if ~isfinite(visualOn) || ~isfinite(visualOff) || visualOff <= visualOn
    visualOn = min(time, [], 'omitmissing');
    visualOff = max(time, [], 'omitmissing');
end

xMin = max(min(time, [], 'omitmissing'), visualOn - options.PreVisualWindowS);
xMax = min(max(time, [], 'omitmissing'), visualOff + options.PostVisualWindowS);
sampleMask = time >= xMin & time <= xMax;
plotTime = time(sampleMask) - visualOn;

[leftX, leftY, rightX, rightY] = getRawEyePosition(trial, sampleMask, Config, options);

layout = tiledlayout(figureHandle, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, makeFigureTitle(trialRow, trialEvents), 'FontWeight', 'bold', 'Interpreter', 'none');

colors = struct('Left', [0.10 0.35 0.70], 'Right', [0.05 0.55 0.42], ...
    'MS', [0.94 0.20 0.52], 'Stim', [0.78 0.13 0.13], 'Visual', [0.15 0.15 0.15]);

axisX = nexttile(layout, 1);
plotEyeAxis(axisX, plotTime, leftX, rightX, trialEvents, trialRow, colors, ...
    sprintf('Horizontal position (%s)', unitLabel));

axisY = nexttile(layout, 3);
plotEyeAxis(axisY, plotTime, leftY, rightY, trialEvents, trialRow, colors, ...
    sprintf('Vertical position (%s)', unitLabel));
xlabel(axisY, 'Time from visual stimulus onset (s)');

axis2D = nexttile(layout, 2, [2 1]);
plotTrajectoryAxis(axis2D, plotTime, leftX, leftY, rightX, rightY, trialEvents, colors, unitLabel);

linkaxes([axisX axisY], 'x');
xlim(axisX, [xMin - visualOn, xMax - visualOn]);
end

function plotEyeAxis(axisHandle, time, leftTrace, rightTrace, trialEvents, trialRow, colors, yLabelText)
time = time(:);
leftTrace = leftTrace(:);
rightTrace = rightTrace(:);
hold(axisHandle, 'on');
plot(axisHandle, time, leftTrace, 'Color', colors.Left, 'LineWidth', 0.9, ...
    'DisplayName', 'Left eye');
plot(axisHandle, time, rightTrace, 'Color', colors.Right, 'LineWidth', 0.9, ...
    'DisplayName', 'Right eye');
grid(axisHandle, 'on');
box(axisHandle, 'off');
ylabel(axisHandle, yLabelText);

finiteValues = [leftTrace; rightTrace];
finiteValues = finiteValues(isfinite(finiteValues));
if isempty(finiteValues)
    ylim(axisHandle, [-1 1]);
else
    yPad = max(0.05 * range(finiteValues), 0.05);
    ylim(axisHandle, [min(finiteValues) - yPad, max(finiteValues) + yPad]);
end

drawMicrosaccadeBands(axisHandle, trialEvents, colors.MS);
drawEventLine(axisHandle, 0, colors.Visual, '-', 'Visual on');
visualOff = scalarFromTable(trialRow, 'VisualStimOffS');
visualOn = scalarFromTable(trialRow, 'VisualStimOnS');
if isfinite(visualOn) && isfinite(visualOff)
    drawEventLine(axisHandle, visualOff - visualOn, colors.Visual, ':', 'Visual off');
end
stimRel = scalarFromTable(trialRow, 'ElectricalStimOnRelVisualS');
if isfinite(stimRel)
    drawEventLine(axisHandle, stimRel, colors.Stim, '--', 'E-stim');
end
legend(axisHandle, 'Location', 'eastoutside');
hold(axisHandle, 'off');
end

function plotTrajectoryAxis(axisHandle, time, leftX, leftY, rightX, rightY, trialEvents, colors, unitLabel)
time = time(:);
leftX = leftX(:);
leftY = leftY(:);
rightX = rightX(:);
rightY = rightY(:);

hold(axisHandle, 'on');
plot(axisHandle, leftX, leftY, 'Color', softenColor(colors.Left, 0.35), 'LineWidth', 0.9, ...
    'DisplayName', 'Left eye path');
plot(axisHandle, rightX, rightY, 'Color', softenColor(colors.Right, 0.35), 'LineWidth', 0.9, ...
    'DisplayName', 'Right eye path');
plot(axisHandle, NaN, NaN, '-', 'Color', colors.MS, 'LineWidth', 3, ...
    'DisplayName', 'MS path');

drawMicrosaccadeTrajectorySegments(axisHandle, time, leftX, leftY, rightX, rightY, ...
    trialEvents, colors.MS);
markTrajectoryEndpoint(axisHandle, leftX, leftY, colors.Left, 'Left start', 'o');
markTrajectoryEndpoint(axisHandle, rightX, rightY, colors.Right, 'Right start', 's');

grid(axisHandle, 'on');
box(axisHandle, 'off');
axis(axisHandle, 'equal');
xlabel(axisHandle, sprintf('Horizontal position (%s)', unitLabel));
ylabel(axisHandle, sprintf('Vertical position (%s)', unitLabel));
title(axisHandle, '2D eye path', 'FontWeight', 'bold');
setTrajectoryLimits(axisHandle, leftX, leftY, rightX, rightY);
legend(axisHandle, 'Location', 'southoutside', 'Orientation', 'horizontal');
hold(axisHandle, 'off');
end

function color = softenColor(color, whiteFraction)
color = color .* (1 - whiteFraction) + [1 1 1] .* whiteFraction;
end

function drawMicrosaccadeTrajectorySegments(axisHandle, time, leftX, leftY, rightX, rightY, trialEvents, msColor)
if isempty(trialEvents) || height(trialEvents) == 0
    return
end
for iEvent = 1:height(trialEvents)
    onset = trialEvents.OnsetRelVisualStimS(iEvent);
    offset = trialEvents.OffsetRelVisualStimS(iEvent);
    if ~isfinite(onset) || ~isfinite(offset) || offset <= onset
        continue
    end
    eventMask = time >= onset & time <= offset;
    if nnz(eventMask) < 2
        [~, nearestIndex] = min(abs(time - onset));
        eventMask(max(1, nearestIndex - 1):min(numel(time), nearestIndex + 1)) = true;
    end
    plot(axisHandle, leftX(eventMask), leftY(eventMask), '-', ...
        'Color', msColor, 'LineWidth', 3, 'HandleVisibility', 'off');
    plot(axisHandle, rightX(eventMask), rightY(eventMask), '-', ...
        'Color', msColor, 'LineWidth', 3, 'HandleVisibility', 'off');
end
end

function markTrajectoryEndpoint(axisHandle, x, y, color, labelText, marker)
valid = find(isfinite(x) & isfinite(y), 1, 'first');
if isempty(valid)
    return
end
plot(axisHandle, x(valid), y(valid), marker, 'Color', color, ...
    'MarkerFaceColor', 'w', 'LineWidth', 1.2, 'MarkerSize', 6, ...
    'DisplayName', labelText);
end

function setTrajectoryLimits(axisHandle, leftX, leftY, rightX, rightY)
allX = [leftX; rightX];
allY = [leftY; rightY];
allX = allX(isfinite(allX));
allY = allY(isfinite(allY));
if isempty(allX) || isempty(allY)
    xlim(axisHandle, [-1 1]);
    ylim(axisHandle, [-1 1]);
    return
end
xPad = max(0.07 * range(allX), 0.04);
yPad = max(0.07 * range(allY), 0.04);
xlim(axisHandle, [min(allX) - xPad, max(allX) + xPad]);
ylim(axisHandle, [min(allY) - yPad, max(allY) + yPad]);
end

function drawMicrosaccadeBands(axisHandle, trialEvents, bandColor)
if isempty(trialEvents) || height(trialEvents) == 0
    return
end
yLimits = ylim(axisHandle);
for iEvent = 1:height(trialEvents)
    onset = trialEvents.OnsetRelVisualStimS(iEvent);
    offset = trialEvents.OffsetRelVisualStimS(iEvent);
    if ~isfinite(onset) || ~isfinite(offset) || offset <= onset
        continue
    end
    patch(axisHandle, [onset offset offset onset], ...
        [yLimits(1) yLimits(1) yLimits(2) yLimits(2)], bandColor, ...
        'FaceAlpha', 0.18, 'EdgeColor', 'none', 'HandleVisibility', 'off');
end
children = axisHandle.Children;
patches = findobj(children, 'Type', 'Patch');
lines = findobj(children, 'Type', 'Line');
axisHandle.Children = [lines; patches; setdiff(children, [lines; patches], 'stable')];
end

function drawEventLine(axisHandle, xValue, color, lineStyle, labelText)
if ~isfinite(xValue)
    return
end
xline(axisHandle, xValue, lineStyle, labelText, ...
    'Color', color, 'LineWidth', 1.1, 'LabelVerticalAlignment', 'bottom', ...
    'LabelHorizontalAlignment', 'left', 'HandleVisibility', 'off');
end

function [leftX, leftY, rightX, rightY] = getRawEyePosition(trial, sampleMask, Config, options)
leftX = double(trial.LEyeX(sampleMask));
leftY = double(trial.LEyeY(sampleMask));
rightX = double(trial.REyeX(sampleMask));
rightY = double(trial.REyeY(sampleMask));
leftX = leftX(:);
leftY = leftY(:);
rightX = rightX(:);
rightY = rightY(:);
if options.ConvertToDegrees
    leftX = atan2d(leftX, Config.ScrDistmm);
    leftY = atan2d(leftY, Config.ScrDistmm);
    rightX = atan2d(rightX, Config.ScrDistmm);
    rightY = atan2d(rightY, Config.ScrDistmm);
end
end

function titleText = makeFigureTitle(trialRow, trialEvents)
trialIndex = scalarFromTable(trialRow, 'TrialIndex');
trialType = stringFromTable(trialRow, 'TrialType');
condition = scalarFromTable(trialRow, 'Condition');
coherence = scalarFromTable(trialRow, 'SignedCoherence');
direction = scalarFromTable(trialRow, 'Direction');
response = scalarFromTable(trialRow, 'Response');
msCount = height(trialEvents);
titleText = sprintf(['Trial %04d | %s | stimulus cond %.0f, signed coh %.4g, dir %.0f | ' ...
    'choice/response %.0f | MS count %d'], ...
    trialIndex, trialType, condition, coherence, direction, response, msCount);
end

function trialEvents = selectTrialEvents(eventTable, trialIndex)
if isempty(eventTable) || height(eventTable) == 0 || ~ismember('TrialIndex', eventTable.Properties.VariableNames)
    trialEvents = table;
else
    trialEvents = eventTable(eventTable.TrialIndex == trialIndex, :);
end
end

function value = scalarFromTable(row, variableName)
value = NaN;
if isempty(row) || ~ismember(variableName, row.Properties.VariableNames)
    return
end
raw = row.(variableName);
if iscell(raw)
    raw = raw{1};
end
if isstring(raw) || ischar(raw)
    value = str2double(raw(1));
elseif isnumeric(raw) || islogical(raw)
    value = double(raw(1));
end
end

function value = stringFromTable(row, variableName)
value = "";
if isempty(row) || ~ismember(variableName, row.Properties.VariableNames)
    return
end
raw = row.(variableName);
if iscell(raw)
    raw = raw{1};
end
if isstring(raw)
    value = raw(1);
elseif ischar(raw)
    value = string(raw);
elseif iscategorical(raw)
    value = string(raw(1));
else
    value = string(raw(1));
end
end

function row = makeIndexRowFromTrial(trialRow, trialEvents, outputFile)
row = makeIndexRow();
row.TrialIndex = scalarFromTable(trialRow, 'TrialIndex');
row.FigureFile = string(outputFile);
row.TrialType = stringFromTable(trialRow, 'TrialType');
row.IsStim = scalarFromTable(trialRow, 'IsStim');
row.Condition = scalarFromTable(trialRow, 'Condition');
row.SignedCoherence = scalarFromTable(trialRow, 'SignedCoherence');
row.Direction = scalarFromTable(trialRow, 'Direction');
row.Response = scalarFromTable(trialRow, 'Response');
row.MicrosaccadeCount = height(trialEvents);
row.VisualStimOnS = scalarFromTable(trialRow, 'VisualStimOnS');
row.VisualStimOffS = scalarFromTable(trialRow, 'VisualStimOffS');
row.ElectricalStimOnRelVisualS = scalarFromTable(trialRow, 'ElectricalStimOnRelVisualS');
end

function row = makeIndexRow()
row = struct('TrialIndex', NaN, 'FigureFile', "", 'TrialType', "", ...
    'IsStim', NaN, 'Condition', NaN, 'SignedCoherence', NaN, ...
    'Direction', NaN, 'Response', NaN, 'MicrosaccadeCount', NaN, ...
    'VisualStimOnS', NaN, 'VisualStimOffS', NaN, ...
    'ElectricalStimOnRelVisualS', NaN);
end

function row = makeMissingTrialRow(trialIndex)
row = table(trialIndex, "", NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
    'VariableNames', {'TrialIndex', 'TrialType', 'IsStim', 'Condition', ...
    'SignedCoherence', 'Direction', 'Response', 'MicrosaccadeCount', ...
    'VisualStimOnS', 'VisualStimOffS'});
end

function [selection, source] = getSelection(selectionData)
if isfield(selectionData, 'EditSel')
    selection = logical(selectionData.EditSel(:));
    source = 'EditSel';
elseif isfield(selectionData, 'Selected')
    selection = logical(selectionData.Selected(:));
    source = 'Selected';
else
    error('SelIndex file must contain EditSel or Selected.');
end
end

function trialIndices = normalizeTrialIndices(value, trialCount)
if islogical(value)
    assert(numel(value) == trialCount, ...
        'Logical TrialIndices must match the number of trials (%d).', trialCount);
    trialIndices = find(value(:));
else
    trialIndices = unique(value(:), 'stable');
end
trialIndices = trialIndices(isfinite(trialIndices) & trialIndices >= 1 & ...
    trialIndices <= trialCount & mod(trialIndices, 1) == 0);
end

function closeFigureIfValid(figureHandle)
if isgraphics(figureHandle)
    close(figureHandle);
end
end

function manifest = PlotExampleSessions(analysisFile, options)
%PLOTEXAMPLESESSIONS Export neural-tuning and behavior plots by session.
%
% manifest = PlotExampleSessions(analysisFile)
% manifest = PlotExampleSessions(analysisFile, SessionIndices=[2 7 11])
%
% analysisFile can be a combined output from
% RunStimulationMIDAnalysis_JimClay.m, or a P-drive per-session cache. A
% combined output must contain MIDTable, Neuro, and BehaviorData. A cache
% must contain Neuro and BehaviorData; pass its session metadata using the
% name-value options below. Each output figure contains the stimulating-site
% tuning curve, non-stimulation behavior, and stimulation behavior.

arguments
    analysisFile (1,1) string
    options.SessionIndices (1,:) double {mustBeInteger,mustBePositive} = []
    options.OutputDirectory (1,1) string = ""
    options.Formats (1,:) string = ["png", "pdf"]
    options.Visible (1,1) matlab.lang.OnOffSwitchState = "off"
    options.CloseFigures (1,1) logical = true
    options.WriteManifest (1,1) logical = true
    options.SessionNumber (1,1) double = NaN
    options.StimElectrode (1,1) double = NaN
    options.Monkey (1,1) string = ""
    options.ROI (1,1) string = ""
    options.SessionDate (1,1) datetime = NaT
end

analysisFile = string(whichExistingFile(analysisFile));
if strlength(options.OutputDirectory) == 0
    outputDirectory = fullfile(fileparts(analysisFile), "ExampleSessionPlots");
else
    outputDirectory = options.OutputDirectory;
end
if ~isfolder(outputDirectory)
    mkdir(outputDirectory);
end

formats = lower(erase(options.Formats, "."));
validFormats = ["png", "pdf"];
if any(~ismember(formats, validFormats))
    error('PlotExampleSessions:UnsupportedFormat', ...
        'Formats must contain only "png" and/or "pdf".');
end
formats = unique(formats, 'stable');

contents = whos('-file', analysisFile);
availableVariables = string({contents.name});
requiredVariables = ["Neuro", "BehaviorData"];
missingVariables = requiredVariables(~ismember(requiredVariables, availableVariables));
if ~isempty(missingVariables)
    error('PlotExampleSessions:MissingVariables', ...
        'The MAT file is missing: %s.', strjoin(missingVariables, ', '));
end

variablesToLoad = {'Neuro', 'BehaviorData'};
if ismember("MIDTable", availableVariables)
    variablesToLoad{end+1} = 'MIDTable';
end
data = load(analysisFile, variablesToLoad{:});
if ~isfield(data, 'MIDTable')
    data.MIDTable = makeCacheMetadataTable(analysisFile, data.Neuro, options);
end
validateAnalysisData(data);
nSessions = min([height(data.MIDTable), numel(data.Neuro), numel(data.BehaviorData)]);

if isempty(options.SessionIndices)
    sessionIndices = defaultSessionIndices(data.MIDTable, nSessions);
else
    sessionIndices = options.SessionIndices;
    if any(sessionIndices > nSessions)
        error('PlotExampleSessions:SessionIndexOutOfRange', ...
            'SessionIndices must be between 1 and %d.', nSessions);
    end
end

isUsable = arrayfun(@(idx) sessionHasPlotData(data.Neuro(idx), ...
    data.BehaviorData(idx)), sessionIndices);
skippedIndices = sessionIndices(~isUsable);
sessionIndices = sessionIndices(isUsable);
if ~isempty(skippedIndices)
    warning('PlotExampleSessions:SkippedSessions', ...
        'Skipped sessions without complete tuning/behavior data: %s.', ...
        strjoin(string(skippedIndices), ', '));
end
if isempty(sessionIndices)
    error('PlotExampleSessions:NoUsableSessions', ...
        'No selected sessions contain both tuning and behavior data.');
end

nOutputs = numel(sessionIndices);
if isfinite(options.SessionNumber) && ...
        (fix(options.SessionNumber) ~= options.SessionNumber || ...
         options.SessionNumber < 1 || nOutputs ~= 1)
    error('PlotExampleSessions:InvalidSessionNumber', ...
        'SessionNumber must be a positive integer and requires one selected session.');
end
manifest = table('Size', [nOutputs, 5], ...
    'VariableTypes', {'double','string','double','string','string'}, ...
    'VariableNames', {'SessionIndex','SessionLabel','StimElectrode','PNG','PDF'});

for iOutput = 1:nOutputs
    sessionIndex = sessionIndices(iOutput);
    outputSessionNumber = sessionIndex;
    if isfinite(options.SessionNumber)
        outputSessionNumber = options.SessionNumber;
    end
    row = data.MIDTable(sessionIndex,:);
    stimElectrode = getStimElectrode(row, data.Neuro(sessionIndex));
    sessionLabel = makeSessionLabel(row, outputSessionNumber, stimElectrode);
    fileStem = makeFileStem(row, outputSessionNumber, stimElectrode);

    fig = figure('Color', 'w', 'Visible', char(options.Visible), ...
        'Units', 'pixels', 'Position', [100 100 1450 470], ...
        'Name', char(sessionLabel));
    cleanupFigure = onCleanup(@() closeIfRequested(fig, options.CloseFigures));
    layout = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', ...
        'Padding', 'compact');
    title(layout, sessionLabel, 'Interpreter', 'none', 'FontWeight', 'bold');

    axTuning = nexttile(layout, 1);
    plotTuning(axTuning, data.Neuro(sessionIndex), stimElectrode);
    title(axTuning, sprintf('Tuning (electrode %d)', stimElectrode));

    axNoStim = nexttile(layout, 2);
    plotBehavior(axNoStim, data.BehaviorData(sessionIndex), 'NoStim');
    title(axNoStim, 'Non-stimulation trials');

    axStim = nexttile(layout, 3);
    plotBehavior(axStim, data.BehaviorData(sessionIndex), 'Stim');
    title(axStim, 'Stimulation trials');
    legend(axStim, conditionNames(), 'Location', 'southeast', ...
        'Box', 'off');

    pngPath = "";
    pdfPath = "";
    if ismember("png", formats)
        pngPath = fullfile(outputDirectory, fileStem + ".png");
        exportgraphics(fig, pngPath, 'Resolution', 300);
    end
    if ismember("pdf", formats)
        pdfPath = fullfile(outputDirectory, fileStem + ".pdf");
        exportgraphics(fig, pdfPath, 'ContentType', 'vector');
    end

    manifest.SessionIndex(iOutput) = outputSessionNumber;
    manifest.SessionLabel(iOutput) = sessionLabel;
    manifest.StimElectrode(iOutput) = stimElectrode;
    manifest.PNG(iOutput) = pngPath;
    manifest.PDF(iOutput) = pdfPath;
    clear cleanupFigure
end

if options.WriteManifest
    manifestPath = fullfile(outputDirectory, 'ExampleSessionPlots_manifest.csv');
    writetable(manifest, manifestPath);
end
fprintf('Exported %d example-session figure(s) to %s\n', ...
    height(manifest), outputDirectory);
end

function midTable = makeCacheMetadataTable(analysisFile, neuro, options)
nSessions = numel(neuro);
if nSessions ~= 1
    error('PlotExampleSessions:MissingMIDTable', ...
        ['A MAT file containing multiple Neuro records must also contain ', ...
         'MIDTable.']);
end

sessionDate = options.SessionDate;
if isnat(sessionDate)
    [~, fileStem] = fileparts(analysisFile);
    if ~isempty(regexp(fileStem, '^\d{8}$', 'once'))
        sessionDate = datetime(fileStem, 'InputFormat', 'yyyyMMdd');
    end
end

midTable = table();
midTable.Monkey = {char(options.Monkey)};
midTable.ROI = {char(options.ROI)};
midTable.Date = sessionDate;
midTable.StimElec = options.StimElectrode;
midTable.AnalysisStatus = {'Success'};
end

function existingFile = whichExistingFile(fileName)
existingFile = char(fileName);
if ~isfile(existingFile)
    error('PlotExampleSessions:FileNotFound', ...
        'Analysis MAT file not found: %s', existingFile);
end
end

function validateAnalysisData(data)
if ~istable(data.MIDTable)
    error('PlotExampleSessions:InvalidMIDTable', 'MIDTable must be a table.');
end
if ~isstruct(data.Neuro) || ~isstruct(data.BehaviorData)
    error('PlotExampleSessions:InvalidData', ...
        'Neuro and BehaviorData must be structure arrays.');
end
end

function indices = defaultSessionIndices(midTable, nSessions)
indices = 1:nSessions;
if ismember('AnalysisStatus', midTable.Properties.VariableNames)
    status = string(midTable.AnalysisStatus(1:nSessions));
    success = strcmpi(strtrim(status), 'Success');
    if any(success)
        indices = find(success).';
    end
end
end

function tf = sessionHasPlotData(neuro, behavior)
tf = isfield(neuro, 'Means') && ~isempty(neuro.Means) && ...
    isfield(behavior, 'NoStim') && isfield(behavior, 'Stim') && ...
    behaviorBlockHasData(behavior.NoStim) && behaviorBlockHasData(behavior.Stim);
end

function tf = behaviorBlockHasData(block)
tf = isstruct(block) && ...
    ((isfield(block, 'pFitResult') && ~isempty(block.pFitResult)) || ...
     (isfield(block, 'pFitVals') && ~isempty(block.pFitVals)));
end

function electrode = getStimElectrode(midRow, neuro)
electrode = NaN;
if ismember('StimElec', midRow.Properties.VariableNames)
    electrode = double(midRow.StimElec(1));
end
nElectrodes = size(neuro.Means, 3);
if ~isscalar(electrode) || ~isfinite(electrode) || electrode < 1 || ...
        electrode > nElectrodes || fix(electrode) ~= electrode
    warning('PlotExampleSessions:InvalidStimElectrode', ...
        'Invalid/missing StimElec; plotting electrode 1.');
    electrode = 1;
end
end

function plotTuning(ax, neuro, electrode)
colors = conditionColors();
means = squeeze(neuro.Means(:,:,electrode));
if isvector(means)
    means = means(:).';
elseif size(means,1) ~= 4 && size(means,2) == 4
    means = means.';
end
nConditions = min(4, size(means,1));
nCoherence = size(means,2);
coherence = inferCoherence(nCoherence);

sems = nan(size(means));
if isfield(neuro, 'SEM') && ~isempty(neuro.SEM) && ...
        size(neuro.SEM,3) >= electrode
    sems = squeeze(neuro.SEM(:,:,electrode));
    if isvector(sems)
        sems = sems(:).';
    elseif size(sems,1) ~= size(means,1) && size(sems,2) == size(means,1)
        sems = sems.';
    end
end

hold(ax, 'on');
for condition = 1:nConditions
    valid = isfinite(means(condition,:));
    if isfield(neuro, 'Trials') && isfield(neuro.Trials, 'NumTrials') && ...
            size(neuro.Trials.NumTrials,1) >= condition && ...
            size(neuro.Trials.NumTrials,2) >= nCoherence
        valid = valid & neuro.Trials.NumTrials(condition,1:nCoherence) > 0;
    end
    errorbar(ax, coherence(valid), means(condition,valid), sems(condition,valid), ...
        '-o', 'Color', colors(condition,:), ...
        'MarkerFaceColor', colors(condition,:), ...
        'MarkerEdgeColor', colors(condition,:), ...
        'LineWidth', 1.5, 'MarkerSize', 5, 'CapSize', 5);
end
formatAxes(ax, 'Coherence', 'Firing rate (spikes/s)', [-1 1]);
end

function plotBehavior(ax, behavior, blockName)
colors = conditionColors();
block = behavior.(blockName);
hold(ax, 'on');
yline(ax, 0.5, '--', 'Color', [0.45 0.45 0.45], ...
    'HandleVisibility', 'off');
xline(ax, 0, '--', 'Color', [0.45 0.45 0.45], ...
    'HandleVisibility', 'off');
xCurve = linspace(-1, 1, 501);

for condition = 1:4
    result = getFitResult(block, condition);
    fitValues = getFitValues(block, result, condition, xCurve);
    plot(ax, xCurve, fitValues, '-', 'Color', colors(condition,:), ...
        'LineWidth', 1.8);

    trialData = getTrialData(result);
    if ~isempty(trialData)
        valid = trialData(:,3) > 0 & all(isfinite(trialData),2);
        proportions = trialData(valid,2) ./ trialData(valid,3);
        scatter(ax, trialData(valid,1), proportions, 34, colors(condition,:), ...
            'filled', 'MarkerEdgeColor', 'w', 'LineWidth', 0.5, ...
            'HandleVisibility', 'off');
    end
end
formatAxes(ax, 'Coherence', 'Proportion chose toward', [-1 1]);
ylim(ax, [0 1]);
yticks(ax, 0:0.25:1);
end

function result = getFitResult(block, condition)
result = struct();
if isfield(block, 'pFitResult') && numel(block.pFitResult) >= condition
    result = block.pFitResult(condition);
end
end

function values = getFitValues(block, result, condition, x)
[mu, sigma] = standardFitParameters(block, result, condition);
baseCurve = 0.5 .* (1 + erf((x - mu) ./ (sigma .* sqrt(2))));
lower = 0;
upperLapse = 0;
if isfield(result, 'Fit') && numel(result.Fit) >= 4
    upperLapse = result.Fit(3);
    lower = result.Fit(4);
    if ~isfinite(lower)
        lower = upperLapse;
    end
end
values = lower + (1 - upperLapse - lower) .* baseCurve;
values = min(max(values, 0), 1);
end

function [mu, sigma] = standardFitParameters(block, result, condition)
mu = NaN;
sigma = NaN;
if isfield(block, 'pFitVals') && size(block.pFitVals,1) >= 2 && ...
        size(block.pFitVals,2) >= condition
    mu = block.pFitVals(1,condition);
    sigma = block.pFitVals(2,condition);
end
if (~isfinite(mu) || ~isfinite(sigma) || sigma <= 0) && ...
        isfield(result, 'Fit') && numel(result.Fit) >= 2
    mu = result.Fit(1);
    width = abs(result.Fit(2));
    widthAlpha = 0.05;
    if isfield(result, 'options') && isfield(result.options, 'widthalpha')
        widthAlpha = result.options.widthalpha;
    end
    normalQuantile = sqrt(2) .* erfinv(2 .* (1-widthAlpha) - 1);
    sigma = width ./ (2 .* normalQuantile);
end
if ~isfinite(mu) || ~isfinite(sigma) || sigma <= 0
    error('PlotExampleSessions:InvalidBehaviorFit', ...
        'Could not recover valid psychometric fit parameters.');
end
end

function trialData = getTrialData(result)
trialData = [];
if isfield(result, 'data') && size(result.data,2) >= 3
    trialData = double(result.data(:,1:3));
end
end

function values = inferCoherence(nValues)
switch nValues
    case 12
        values = [-22 -14 -10 -8 -4 -2 2 4 8 10 14 22] ./ 22;
    case 8
        values = [-22 -14 -10 -8 8 10 14 22] ./ 22;
    case 13
        values = [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22] ./ 22;
    otherwise
        warning('PlotExampleSessions:UnknownCoherenceGrid', ...
            'Using an evenly spaced coherence grid for %d values.', nValues);
        values = linspace(-1, 1, nValues);
end
end

function label = makeSessionLabel(row, index, electrode)
parts = "Session " + index;
if ismember('Monkey', row.Properties.VariableNames)
    parts(end+1) = scalarText(row.Monkey);
end
if ismember('ROI', row.Properties.VariableNames)
    parts(end+1) = scalarText(row.ROI);
end
if ismember('Date', row.Properties.VariableNames)
    parts(end+1) = dateText(row.Date);
end
parts(end+1) = "stim electrode " + electrode;
parts = parts(strlength(parts) > 0 & ~ismissing(parts));
label = strjoin(parts, " | ");
end

function stem = makeFileStem(row, index, electrode)
parts = sprintf('%03d', index);
if ismember('Monkey', row.Properties.VariableNames)
    parts = parts + "_" + scalarText(row.Monkey);
end
if ismember('ROI', row.Properties.VariableNames)
    parts = parts + "_" + scalarText(row.ROI);
end
if ismember('Date', row.Properties.VariableNames)
    parts = parts + "_" + dateText(row.Date);
end
parts = parts + sprintf('_stim%02d', electrode);
stem = regexprep(parts, '[^A-Za-z0-9_-]+', '-');
stem = strip(stem, '-');
end

function textValue = scalarText(value)
if iscell(value)
    value = value{1};
end
if ischar(value)
    textValue = string(value);
else
    textValue = string(value(1));
end
textValue = strip(textValue);
end

function textValue = dateText(value)
if iscell(value)
    value = value{1};
end
try
    if isdatetime(value)
        textValue = string(value(1), 'yyyy-MM-dd');
    elseif isnumeric(value)
        textValue = string(datetime(value(1), 'ConvertFrom', 'datenum'), 'yyyy-MM-dd');
    else
        parsedDate = datetime(string(value(1)));
        textValue = string(parsedDate, 'yyyy-MM-dd');
    end
catch
    textValue = scalarText(value);
end
end

function colors = conditionColors()
colors = [0 0 0; 0 0 255; 5 150 5; 234 0 233] ./ 255;
end

function names = conditionNames()
names = {'Combined', 'Monocular left', 'Monocular right', 'Stereo'};
end

function formatAxes(ax, xLabelText, yLabelText, xLimits)
xlabel(ax, xLabelText);
ylabel(ax, yLabelText);
xlim(ax, xLimits);
xticks(ax, -1:0.5:1);
box(ax, 'off');
axis(ax, 'square');
ax.TickDir = 'out';
ax.LineWidth = 1;
ax.FontName = 'Arial';
ax.FontSize = 10;
end

function closeIfRequested(fig, shouldClose)
if shouldClose && isgraphics(fig)
    close(fig);
end
end

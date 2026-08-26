function app = ExploreInteractiveStimChannelPopulation(options)
%EXPLOREINTERACTIVESTIMCHANNELPOPULATION Open the latest clickable population plots.
%
% app = ExploreInteractiveStimChannelPopulation()
%
% Reproduces the four current stimulation-channel population plots (MT/FST
% by 2D/3D) from the explicitly selected population table. Click any
% population dot to open that session's existing tuning and NoStim/Stim
% behavior panel from C:\EM\allSessions.

arguments
    options.DataFile (1, 1) string = ...
        "C:\EM\StimChannelAnalysis\unit_table_gof_uniform_temp.mat"
    options.AnalysisRoot (1, 1) string = "C:\EM\StimTuningAnalysis"
    options.TableName (1, 1) string = ...
        "unit_table_gof_matched_original_stim_channel.mat"
    options.SessionPlotFolder (1, 1) string = "C:\EM\allSessions"
    options.Visible (1, 1) matlab.lang.OnOffSwitchState = "on"
end

scriptFolder = fileparts(mfilename('fullpath'));
repositoryFolder = fileparts(scriptFolder);
populationFolder = fullfile(repositoryFolder, 'PopulationAnalysis');
populationScript = fullfile(populationFolder, ...
    'RunPopulationAnalysis_ODweighted.m');
if ~isfile(populationScript)
    error('InteractiveStimPopulation:MissingPopulationAnalysis', ...
        'Population analysis script not found: %s', populationScript);
end

if strlength(strip(options.DataFile)) > 0
    dataFile = char(options.DataFile);
    if ~isfile(dataFile)
        error('InteractiveStimPopulation:MissingDataFile', ...
            'Requested population table not found: %s', dataFile);
    end
else
    dataFile = findNewestStimChannelTable( ...
        options.AnalysisRoot, options.TableName);
end
validateStimChannelTable(dataFile);
sessionManifest = loadSessionManifest(options.SessionPlotFolder);

pathWasPresent = contains(path, populationFolder, 'IgnoreCase', true);
if ~pathWasPresent
    addpath(populationFolder);
end
pathCleanup = onCleanup(@() restorePath(populationFolder, pathWasPresent));

oldDefaultVisible = get(groot, 'DefaultFigureVisible');
set(groot, 'DefaultFigureVisible', char(options.Visible));
visibilityCleanup = onCleanup(@() set( ...
    groot, 'DefaultFigureVisible', oldDefaultVisible));

[mtResults, unitTable] = runPopulationAnalysis( ...
    populationScript, dataFile, 'MT');
[fstResults, secondUnitTable] = runPopulationAnalysis( ...
    populationScript, dataFile, 'FST');
if height(unitTable) ~= height(secondUnitTable)
    error('InteractiveStimPopulation:InconsistentPopulationTables', ...
        'MT and FST runs returned population tables of different heights.');
end
clear secondUnitTable

figureHandles = [mtResults.fig_2d, mtResults.fig_3d, ...
    fstResults.fig_2d, fstResults.fig_3d];
areaNames = ["MT", "MT", "FST", "FST"];
unitTypes = ["2D", "3D", "2D", "3D"];
resultSets = {mtResults, mtResults, fstResults, fstResults};

attachmentAudit = table();
for figureIndex = 1:numel(figureHandles)
    fig = figureHandles(figureIndex);
    polishPopulationFigure(fig, areaNames(figureIndex), ...
        unitTypes(figureIndex));
    thisAudit = attachPointCallbacks(fig, ...
        resultSets{figureIndex}.bias_table, unitTable, sessionManifest, ...
        options.SessionPlotFolder, areaNames(figureIndex), ...
        unitTypes(figureIndex));
    attachmentAudit = [attachmentAudit; thisAudit]; %#ok<AGROW>
end

unmatchedPoints = attachmentAudit(~attachmentAudit.SessionPlotFound, :);
if ~isempty(unmatchedPoints)
    warning('InteractiveStimPopulation:MissingSessionPlots', ...
        ['%d plotted point(s), representing %d session(s), do not have ' ...
        'a matching tuning/behavior PNG under %s.'], ...
        height(unmatchedPoints), numel(unique(unmatchedPoints.UnitIndex)), ...
        options.SessionPlotFolder);
end

app = struct();
app.Figures = figureHandles;
app.MT = mtResults;
app.FST = fstResults;
app.DataFile = string(dataFile);
app.SessionPlotFolder = options.SessionPlotFolder;
app.SessionManifest = sessionManifest;
app.AttachmentAudit = attachmentAudit;
app.UnmatchedPoints = unmatchedPoints;

fprintf('Interactive stimulation-channel population source:\n%s\n', dataFile);
fprintf(['Attached click-through behavior to %d points across four figures; ' ...
    '%d point(s) lack a session plot.\n'], ...
    height(attachmentAudit), height(unmatchedPoints));

clear visibilityCleanup pathCleanup
end


function dataFile = findNewestStimChannelTable(analysisRoot, tableName)
if ~isfolder(analysisRoot)
    error('InteractiveStimPopulation:MissingAnalysisRoot', ...
        'Analysis root not found: %s', analysisRoot);
end
files = dir(fullfile(analysisRoot, '**', tableName));
if isempty(files)
    error('InteractiveStimPopulation:MissingStimChannelTable', ...
        'No %s artifact was found under %s.', tableName, analysisRoot);
end
[~, newestIndex] = max([files.datenum]);
dataFile = fullfile(files(newestIndex).folder, files(newestIndex).name);
end


function validateStimChannelTable(dataFile)
variables = string({whos('-file', dataFile).name});
if ~ismember("unit_table_gof", variables)
    error('InteractiveStimPopulation:MissingUnitTable', ...
        'The selected artifact does not contain unit_table_gof: %s', dataFile);
end
if ismember("EqualFiveChannelMetaReadout", variables)
    metadata = load(dataFile, 'EqualFiveChannelMetaReadout');
    readout = string(metadata.EqualFiveChannelMetaReadout);
    if ~contains(lower(readout), "original stimulation channel")
        error('InteractiveStimPopulation:WrongReadout', ...
            ['The newest artifact is not labeled as the original ' ...
            'stimulation-channel readout: %s'], dataFile);
    end
end
end


function manifest = loadSessionManifest(sessionPlotFolder)
manifestPath = fullfile(sessionPlotFolder, 'allSessions_manifest.csv');
if ~isfile(manifestPath)
    error('InteractiveStimPopulation:MissingSessionManifest', ...
        'Session-plot manifest not found: %s', manifestPath);
end
manifest = readtable(manifestPath, 'TextType', 'string', ...
    'VariableNamingRule', 'preserve');
required = ["Monkey", "Date", "ROI", "StimElectrode", "PNG"];
missing = setdiff(required, string(manifest.Properties.VariableNames));
if ~isempty(missing)
    error('InteractiveStimPopulation:InvalidSessionManifest', ...
        'Session manifest is missing: %s.', join(missing, ', '));
end
manifest.NormalizedDate = normalizeDates(manifest.Date);
manifest.Monkey = strip(string(manifest.Monkey));
manifest.ROI = strip(string(manifest.ROI));
manifest.PNG = string(manifest.PNG);
manifest.StimElectrode = numericColumn(manifest.StimElectrode);
end


function [results, unitTable] = runPopulationAnalysis( ...
        populationScript, dataFile, selectedArea)
% These initial values make the function contract explicit to Code Analyzer;
% the population script replaces them after its intentional clearvars call.
results = struct();
unit_table = table();
area = selectedArea; %#ok<NASGU>
monkey = 'Both'; %#ok<NASGU>
tuning_source = 'Quick'; %#ok<NASGU>
close_existing_figures = false; %#ok<NASGU>
data_file = dataFile; %#ok<NASGU>
population_analysis_use_supplied_settings = true; %#ok<NASGU>
run(populationScript)
if ~exist('results', 'var') || ~isstruct(results)
    error('InteractiveStimPopulation:MissingPopulationResults', ...
        'Population analysis did not return its results structure.');
end
if ~exist('unit_table', 'var') || ~istable(unit_table)
    error('InteractiveStimPopulation:MissingPopulationTable', ...
        'Population analysis did not leave its input table in the workspace.');
end
unitTable = unit_table;
end


function polishPopulationFigure(fig, area, unitType)
set(fig, 'Color', 'w', ...
    'Name', sprintf('%s %s interactive stimulation-channel population', ...
    area, unitType), 'NumberTitle', 'off');
axesHandles = findall(fig, 'Type', 'axes');
if isempty(axesHandles)
    error('InteractiveStimPopulation:MissingAxes', ...
        'No axes were found in figure %s %s.', area, unitType);
end
ax = axesHandles(1);
set(ax, 'FontName', 'Arial', 'FontSize', 17, 'LineWidth', 1.25);
title(ax, sprintf('%s %s neurons', area, unitType), ...
    'FontName', 'Arial', 'FontSize', 21, 'FontWeight', 'bold');
subtitle(ax, 'Click a dot to open its tuning and behavior panel', ...
    'FontName', 'Arial', 'FontSize', 13, 'FontWeight', 'normal');
xlabel(ax, 'Asymmetry index (stimulation-channel tuning)', ...
    'FontName', 'Arial', 'FontSize', 19);
ylabel(ax, '\Delta bias', 'Interpreter', 'tex', ...
    'FontName', 'Arial', 'FontSize', 19);

legendHandles = findall(fig, 'Type', 'legend');
for index = 1:numel(legendHandles)
    labels = string(legendHandles(index).String);
    labels(labels == "NonDominant") = "Non-dominant";
    set(legendHandles(index), 'String', cellstr(labels), ...
        'FontName', 'Arial', 'FontSize', 16, 'Box', 'off');
end

lineHandles = findall(ax, 'Type', 'line');
set(lineHandles, 'HitTest', 'off', 'PickableParts', 'none');
end


function audit = attachPointCallbacks(fig, biasTable, unitTable, manifest, ...
        sessionPlotFolder, area, unitType)
conditionColors = [254 191 15; 0 0 0; 234 0 233; 110 205 221] ./ 255;
conditionNames = ["Dominant", "Combined", "Stereo", "Non-dominant"];
monkeyNames = ["Jim", "Clay"];
monkeyMarkers = ["o", "d"];

scatterHandles = findall(fig, 'Type', 'Scatter');
matchedHandles = false(size(scatterHandles));
audit = table();

for condition = 1:4
    for monkeyIndex = 1:numel(monkeyNames)
        rows = strcmp(string(biasTable.UnitType), unitType) & ...
            biasTable.Condition == condition & ...
            strcmpi(biasTable.Monkey, monkeyNames(monkeyIndex));
        pointTable = biasTable(rows, :);
        if isempty(pointTable)
            continue
        end

        handleIndex = findMatchingScatter(scatterHandles, matchedHandles, ...
            pointTable, conditionColors(condition, :), ...
            monkeyMarkers(monkeyIndex));
        if isempty(handleIndex)
            error('InteractiveStimPopulation:ScatterMappingFailed', ...
                ['Could not map the %s %s %s %s data to its scatter ' ...
                'object.'], area, unitType, conditionNames(condition), ...
                monkeyNames(monkeyIndex));
        end
        matchedHandles(handleIndex) = true;
        scatterHandle = scatterHandles(handleIndex);

        metadata = buildPointMetadata(pointTable, unitTable, manifest, ...
            sessionPlotFolder, area, unitType, ...
            conditionNames(condition));
        scatterHandle.UserData = struct('PointTable', metadata);
        scatterHandle.ButtonDownFcn = @openClickedSessionPlot;
        scatterHandle.HitTest = 'on';
        scatterHandle.PickableParts = 'visible';
        setScatterDataTips(scatterHandle, metadata);
        audit = [audit; metadata]; %#ok<AGROW>
    end
end
end


function index = findMatchingScatter(handles, alreadyMatched, pointTable, ...
        expectedColor, expectedMarker)
index = [];
expectedX = double(pointTable.AI(:));
expectedY = double(pointTable.Bias(:));
for candidate = 1:numel(handles)
    if alreadyMatched(candidate)
        continue
    end
    handle = handles(candidate);
    x = double(handle.XData(:));
    y = double(handle.YData(:));
    if numel(x) ~= numel(expectedX) || numel(y) ~= numel(expectedY) || ...
            ~markersMatch(handle.Marker, expectedMarker)
        continue
    end
    color = double(handle.CData);
    if size(color, 2) ~= 3 || ...
            norm(color(1, :) - expectedColor, 2) > 1e-10
        continue
    end
    tolerance = 1e-10;
    if all(abs(x - expectedX) <= tolerance | ...
            (isnan(x) & isnan(expectedX))) && ...
            all(abs(y - expectedY) <= tolerance | ...
            (isnan(y) & isnan(expectedY)))
        index = candidate;
        return
    end
end
end


function tf = markersMatch(actualMarker, expectedMarker)
actualMarker = lower(string(actualMarker));
expectedMarker = lower(string(expectedMarker));
if actualMarker == "diamond"
    actualMarker = "d";
end
if expectedMarker == "diamond"
    expectedMarker = "d";
end
tf = actualMarker == expectedMarker;
end


function metadata = buildPointMetadata(pointTable, unitTable, manifest, ...
        sessionPlotFolder, area, unitType, conditionName)
unitIndices = double(pointTable.UnitIndex(:));
pointCount = numel(unitIndices);
Date = NaT(pointCount, 1);
Monkey = strings(pointCount, 1);
ROI = strings(pointCount, 1);
StimElectrode = nan(pointCount, 1);
SessionPlot = strings(pointCount, 1);

for pointIndex = 1:pointCount
    unitIndex = unitIndices(pointIndex);
    if unitIndex < 1 || unitIndex > height(unitTable) || ...
            unitIndex ~= fix(unitIndex)
        error('InteractiveStimPopulation:InvalidUnitIndex', ...
            'Population point has invalid unit-table index %g.', unitIndex);
    end
    Date(pointIndex) = tableDate(unitTable.Date, unitIndex);
    Monkey(pointIndex) = tableText(unitTable.Monkey, unitIndex);
    ROI(pointIndex) = tableText(unitTable.ROI, unitIndex);
    StimElectrode(pointIndex) = tableNumber( ...
        unitTable.StimElec, unitIndex);
    SessionPlot(pointIndex) = findSessionPlot(manifest, ...
        sessionPlotFolder, Date(pointIndex), Monkey(pointIndex), ...
        ROI(pointIndex), StimElectrode(pointIndex));
end

Area = repmat(area, pointCount, 1);
UnitType = repmat(unitType, pointCount, 1);
Condition = repmat(conditionName, pointCount, 1);
AI = double(pointTable.AI(:));
DeltaBias = double(pointTable.Bias(:));
OD = double(pointTable.OD(:));
SessionPlotFound = isfile(SessionPlot);
metadata = table(unitIndices, Area, UnitType, Condition, Monkey, Date, ROI, ...
    StimElectrode, AI, DeltaBias, OD, SessionPlot, SessionPlotFound, ...
    'VariableNames', {'UnitIndex', 'Area', 'UnitType', 'Condition', ...
    'Monkey', 'Date', 'ROI', 'StimElectrode', 'AI', 'DeltaBias', 'OD', ...
    'SessionPlot', 'SessionPlotFound'});
end


function fileName = findSessionPlot(manifest, folder, dateValue, monkey, ...
        roi, stimElectrode)
fileName = "";
if ~isnat(dateValue) && isfinite(stimElectrode)
    matched = manifest.NormalizedDate == dateshift(dateValue, 'start', 'day') & ...
        strcmpi(manifest.Monkey, monkey) & strcmpi(manifest.ROI, roi) & ...
        manifest.StimElectrode == stimElectrode;
    candidateRows = find(matched);
    for row = reshape(candidateRows, 1, [])
        candidate = manifest.PNG(row);
        if isfile(candidate)
            fileName = candidate;
            return
        end
    end

    dateText = string(dateValue, 'yyyy-MM-dd');
    pattern = sprintf('*_%s_%s_%s_stim%02d.png', ...
        monkey, roi, dateText, stimElectrode);
    files = dir(fullfile(folder, pattern));
    if isscalar(files)
        fileName = string(fullfile(files.folder, files.name));
    end
end
end


function setScatterDataTips(scatterHandle, metadata)
try
    sessionLabel = metadata.Monkey + " " + ...
        string(metadata.Date, 'yyyy-MM-dd') + " " + metadata.ROI;
    scatterHandle.DataTipTemplate.DataTipRows = [ ...
        dataTipTextRow('Session', sessionLabel), ...
        dataTipTextRow('Condition', metadata.Condition), ...
        dataTipTextRow('Stim electrode', metadata.StimElectrode), ...
        dataTipTextRow('AI', metadata.AI, '%.3f'), ...
        dataTipTextRow('Delta bias', metadata.DeltaBias, '%.3f'), ...
        dataTipTextRow('|OD|', metadata.OD, '%.3f')];
catch ME
    warning('InteractiveStimPopulation:DataTipSetupFailed', ...
        'Could not customize population data tips: %s', ME.message);
end
end


function openClickedSessionPlot(scatterHandle, event)
metadata = scatterHandle.UserData.PointTable;
if isempty(metadata)
    return
end

x = double(scatterHandle.XData(:));
y = double(scatterHandle.YData(:));
click = double(event.IntersectionPoint(1:2));
ax = ancestor(scatterHandle, 'axes');
xScale = max(diff(ax.XLim), eps);
yScale = max(diff(ax.YLim), eps);
distance = ((x - click(1)) ./ xScale) .^ 2 + ...
    ((y - click(2)) ./ yScale) .^ 2;
[~, pointIndex] = min(distance);
point = metadata(pointIndex, :);

if ~point.SessionPlotFound || ~isfile(point.SessionPlot)
    warning('InteractiveStimPopulation:SessionPlotNotFound', ...
        ['No tuning/behavior plot was found for %s %s %s, stimulation ' ...
        'electrode %d (unit-table row %d).'], ...
        point.Monkey, string(point.Date, 'yyyy-MM-dd'), point.ROI, ...
        point.StimElectrode, point.UnitIndex);
    return
end

tag = sprintf('StimChannelSession_%d', point.UnitIndex);
existing = findall(groot, 'Type', 'figure', 'Tag', tag);
if ~isempty(existing)
    figure(existing(1));
    return
end

[imageData, colorMap, alpha] = imread(point.SessionPlot);
if ~isempty(colorMap)
    imageData = ind2rgb(imageData, colorMap);
end
screen = get(groot, 'ScreenSize');
imageHeight = size(imageData, 1);
imageWidth = size(imageData, 2);
maxWidth = max(800, screen(3) - 160);
maxHeight = max(500, screen(4) - 220);
scale = min([1, maxWidth / imageWidth, maxHeight / imageHeight]);
position = [80, 80, max(800, imageWidth * scale), ...
    max(450, imageHeight * scale)];
name = sprintf('%s %s %s | stim electrode %d', ...
    point.Monkey, string(point.Date, 'yyyy-MM-dd'), point.ROI, ...
    point.StimElectrode);
fig = figure('Color', 'w', 'Name', name, 'NumberTitle', 'off', ...
    'Tag', tag, 'Position', position);
imageAxes = axes(fig, 'Position', [0.01 0.01 0.98 0.98]);
imageHandle = image(imageAxes, imageData);
if ~isempty(alpha)
    imageHandle.AlphaData = alpha;
end
axis(imageAxes, 'image');
axis(imageAxes, 'off');
end


function dates = normalizeDates(values)
if isdatetime(values)
    dates = values(:);
elseif isnumeric(values)
    values = values(:);
    if all(isnan(values) | values > 1e7)
        dates = datetime(string(values), 'InputFormat', 'yyyyMMdd');
    else
        dates = datetime(values, 'ConvertFrom', 'datenum');
    end
else
    dates = datetime(string(values(:)));
end
dates = dateshift(dates, 'start', 'day');
end


function value = tableDate(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
while iscell(value) && isscalar(value)
    value = value{1};
end
value = normalizeDates(value);
value = value(1);
end


function value = tableText(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
while iscell(value) && isscalar(value)
    value = value{1};
end
value = strip(string(value));
value = value(1);
end


function value = tableNumber(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
while iscell(value) && isscalar(value)
    value = value{1};
end
value = double(value);
value = value(1);
end


function values = numericColumn(column)
if isnumeric(column)
    values = double(column(:));
else
    values = str2double(string(column(:)));
end
end


function restorePath(populationFolder, pathWasPresent)
if ~pathWasPresent && contains(path, populationFolder, 'IgnoreCase', true)
    rmpath(populationFolder);
end
end

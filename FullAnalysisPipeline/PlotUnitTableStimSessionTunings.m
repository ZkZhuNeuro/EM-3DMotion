function FigureManifest = PlotUnitTableStimSessionTunings(tableFile, options)
%PLOTUNITTABLESTIMSESSIONTUNINGS Save 16-channel tuning figures by session.
%
% FigureManifest = PlotUnitTableStimSessionTunings() loads the finalized
% unit_table_stim and writes three 2-by-8 figures per session: NoStim, Stim,
% and Merged (all trials pooled). Within each trial group, every cue of each
% channel is Z-scored independently across its valid coherence means, matching
% the unit_table_gof.tuning_z convention. The saved SEM is divided by the same
% cue- and channel-specific standard deviation. Tiles follow the stored
% physical probe order while each title identifies the acquisition channel.
%
% Default input:
%   C:\EM\StimTuningAnalysis\unit_table_stim.mat
%
% Default output:
%   C:\EM\StimTuningAnalysis\TuningFigures_16Channels_ZScore\
%       NoStim\
%       Stim\
%       Merged\
%       StimTuningFigureManifest.csv
%
% Examples:
%   PlotUnitTableStimSessionTunings();
%   PlotUnitTableStimSessionTunings(TrialGroups="NoStim");
%   PlotUnitTableStimSessionTunings(Rows=94, FigureVisible=true);
%   PlotUnitTableStimSessionTunings(SaveFIG=true);
%
% Existing requested files are skipped by default, so rerunning the function
% resumes an interrupted export. Set OverwriteExisting=true to replace them.

arguments
    tableFile (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\unit_table_stim.mat"
    options.OutputFolder (1, 1) string = ""
    options.Rows (1, :) double {mustBeInteger, mustBePositive} = []
    options.TrialGroups (1, :) string = ["NoStim", "Stim", "Merged"]
    options.SavePNG (1, 1) logical = true
    options.SaveFIG (1, 1) logical = false
    options.OverwriteExisting (1, 1) logical = false
    options.FigureVisible (1, 1) logical = false
    options.Resolution (1, 1) double ...
        {mustBeInteger, mustBePositive} = 180
    options.FailFast (1, 1) logical = false
end

if ~options.SavePNG && ~options.SaveFIG
    error('UnitTableStimFigures:NoOutputFormat', ...
        'At least one of SavePNG or SaveFIG must be true.');
end
if ~isfile(tableFile)
    error('UnitTableStimFigures:MissingTableFile', ...
        'Table file does not exist: %s', tableFile);
end

groups = normalizeTrialGroups(options.TrialGroups);
loaded = load(tableFile, 'unit_table_stim');
if ~isfield(loaded, 'unit_table_stim') || ...
        ~istable(loaded.unit_table_stim)
    error('UnitTableStimFigures:MissingTable', ...
        '%s does not contain table unit_table_stim.', tableFile);
end
tableData = loaded.unit_table_stim;
clear loaded
validateTableColumns(tableData);

outputFolder = options.OutputFolder;
if strlength(outputFolder) == 0
    outputFolder = fullfile(fileparts(tableFile), ...
        'TuningFigures_16Channels_ZScore');
end
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
for group = groups
    groupFolder = fullfile(outputFolder, group);
    if ~isfolder(groupFolder)
        mkdir(groupFolder);
    end
end

rowCount = height(tableData);
rows = options.Rows;
if isempty(rows)
    rows = 1:rowCount;
end
rows = unique(rows, 'stable');
if any(rows > rowCount)
    error('UnitTableStimFigures:RowsOutOfRange', ...
        'Rows contains an index greater than table height %d.', rowCount);
end

manifestRowCount = numel(rows) * numel(groups);
UnitTableRow = zeros(manifestRowCount, 1);
Monkey = strings(manifestRowCount, 1);
RecordingDate = strings(manifestRowCount, 1);
TrialGroup = strings(manifestRowCount, 1);
StimChannel = nan(manifestRowCount, 1);
TrialCount = nan(manifestRowCount, 1);
TableStatus = strings(manifestRowCount, 1);
ExportStatus = repmat("Pending", manifestRowCount, 1);
Message = strings(manifestRowCount, 1);
PNGFile = strings(manifestRowCount, 1);
FIGFile = strings(manifestRowCount, 1);
DurationSeconds = nan(manifestRowCount, 1);

for rowPosition = 1:numel(rows)
    row = rows(rowPosition);
    monkey = rowText(tableData.Monkey, row);
    [dateLabel, dateFileText] = formatRecordingDate(tableData.Date(row));
    stimChannel = double(tableData.StimElec(row));
    tableStatus = string(tableData.stim_tuning_status(row));
    baseIndex = (rowPosition - 1) * numel(groups);

    for groupIndex = 1:numel(groups)
        manifestIndex = baseIndex + groupIndex;
        group = groups(groupIndex);
        UnitTableRow(manifestIndex) = row;
        Monkey(manifestIndex) = monkey;
        RecordingDate(manifestIndex) = dateLabel;
        TrialGroup(manifestIndex) = group;
        StimChannel(manifestIndex) = stimChannel;
        TableStatus(manifestIndex) = tableStatus;
        baseName = makeFigureBaseName( ...
            row, monkey, dateFileText, stimChannel, group);
        if options.SavePNG
            PNGFile(manifestIndex) = fullfile( ...
                outputFolder, group, baseName + ".png");
        end
        if options.SaveFIG
            FIGFile(manifestIndex) = fullfile( ...
                outputFolder, group, baseName + ".fig");
        end
    end

    try
        session = readSessionTuning(tableData, row, groups);
        session = zScoreSessionTuning(session);
        sharedYLimits = calculateSharedYLimits(session);
    catch ME
        indices = baseIndex + (1:numel(groups));
        ExportStatus(indices) = "InvalidTableData";
        Message(indices) = string(ME.message);
        warning('UnitTableStimFigures:InvalidRow', ...
            'Row %d was not plotted: %s', row, ME.message);
        if options.FailFast
            rethrow(ME)
        end
        continue
    end

    for groupIndex = 1:numel(groups)
        manifestIndex = baseIndex + groupIndex;
        groupStart = tic;
        group = groups(groupIndex);
        groupData = session.Groups(groupIndex);
        TrialCount(manifestIndex) = sum(groupData.Count, 'all');
        savePNG = options.SavePNG && (options.OverwriteExisting || ...
            ~isfile(PNGFile(manifestIndex)));
        saveFIG = options.SaveFIG && (options.OverwriteExisting || ...
            ~isfile(FIGFile(manifestIndex)));

        if ~savePNG && ~saveFIG
            ExportStatus(manifestIndex) = "SkippedExisting";
            Message(manifestIndex) = ...
                "All requested output files already exist";
            DurationSeconds(manifestIndex) = toc(groupStart);
            fprintf('[%d/%d] Row %d %s: skipped existing files.\n', ...
                rowPosition, numel(rows), row, group);
            continue
        end

        figureHandle = gobjects(0);
        try
            figureHandle = createSessionFigure( ...
                row, monkey, dateLabel, groupData.Name, ...
                options.FigureVisible);
            drawSessionGroupFigure(figureHandle, ...
                row, monkey, dateLabel, stimChannel, tableStatus, ...
                session, groupData, sharedYLimits);
            if savePNG
                atomicExportPNG(figureHandle, PNGFile(manifestIndex), ...
                    options.Resolution);
            end
            if saveFIG
                atomicSaveFIG(figureHandle, FIGFile(manifestIndex));
            end
            ExportStatus(manifestIndex) = "Saved";
            Message(manifestIndex) = "";
            fprintf('[%d/%d] Row %d %s: saved.\n', ...
                rowPosition, numel(rows), row, group);
        catch ME
            ExportStatus(manifestIndex) = "ExportFailed";
            Message(manifestIndex) = string(ME.message);
            warning('UnitTableStimFigures:ExportFailed', ...
                'Row %d %s figure failed: %s', row, group, ME.message);
            if options.FailFast
                closeFigure(figureHandle);
                rethrow(ME)
            end
        end
        closeFigure(figureHandle);
        DurationSeconds(manifestIndex) = toc(groupStart);
    end
end

FigureManifest = table(UnitTableRow, Monkey, RecordingDate, TrialGroup, ...
    StimChannel, TrialCount, TableStatus, ExportStatus, Message, ...
    PNGFile, FIGFile, DurationSeconds);
manifestFile = fullfile(outputFolder, ...
    'StimTuningFigureManifest.csv');
manifestMATFile = fullfile(outputFolder, ...
    'StimTuningFigureManifest.mat');
FigureManifest = mergePreviousManifest(FigureManifest, manifestMATFile);
atomicSaveManifest(FigureManifest, manifestMATFile, manifestFile);

fprintf('\nFigure export summary:\n');
statusNames = unique(FigureManifest.ExportStatus, 'stable');
for status = statusNames(:)'
    fprintf('  %-24s %d\n', status, ...
        nnz(FigureManifest.ExportStatus == status));
end
fprintf('Manifest: %s\n', manifestFile);
end


function groups = normalizeTrialGroups(requestedGroups)
canonical = ["NoStim", "Stim", "Merged"];
groups = strings(size(requestedGroups));
for index = 1:numel(requestedGroups)
    match = find(strcmpi(requestedGroups(index), canonical), 1);
    if isempty(match)
        error('UnitTableStimFigures:InvalidTrialGroup', ...
            'TrialGroups must contain only NoStim, Stim, or Merged.');
    end
    groups(index) = canonical(match);
end
groups = unique(groups, 'stable');
if isempty(groups)
    error('UnitTableStimFigures:NoTrialGroups', ...
        'TrialGroups must not be empty.');
end
end


function validateTableColumns(tableData)
required = ["Date", "Monkey", "StimElec", "NChannels", ...
    "stim_tuning_status", "stim_tuning_coherence", ...
    "stim_tuning_condition_names", "stim_tuning_channel_map", ...
    "stim_tuning_mean_noStim", "stim_tuning_SEM_noStim", ...
    "stim_tuning_n_noStim", "stim_tuning_mean_stim", ...
    "stim_tuning_SEM_stim", "stim_tuning_n_stim", ...
    "stim_tuning_mean_merged", "stim_tuning_SEM_merged", ...
    "stim_tuning_n_merged"];
missing = setdiff(required, string(tableData.Properties.VariableNames));
if ~isempty(missing)
    error('UnitTableStimFigures:MissingColumns', ...
        'unit_table_stim is missing required column(s): %s', ...
        join(missing, ', '));
end
end


function session = readSessionTuning(tableData, row, groups)
session = struct();
session.Coherence = double(tableData.stim_tuning_coherence{row}(:)');
session.ConditionNames = string( ...
    tableData.stim_tuning_condition_names{row}(:)');
session.ChannelOrder = double(tableData.stim_tuning_channel_map{row}(:)');
expectedChannels = double(tableData.NChannels(row));
if isempty(session.Coherence) || any(~isfinite(session.Coherence)) || ...
        any(diff(session.Coherence) <= 0)
    error('UnitTableStimFigures:InvalidCoherence', ...
        'Row %d has an invalid coherence axis.', row);
end
if numel(session.ConditionNames) ~= 4
    error('UnitTableStimFigures:InvalidConditionNames', ...
        'Row %d must contain four condition names.', row);
end
if ~isfinite(expectedChannels) || expectedChannels < 1 || ...
        expectedChannels ~= fix(expectedChannels)
    error('UnitTableStimFigures:InvalidChannelCount', ...
        'Row %d has invalid NChannels.', row);
end
if numel(session.ChannelOrder) ~= expectedChannels || ...
        ~isequal(sort(session.ChannelOrder), 1:expectedChannels)
    error('UnitTableStimFigures:InvalidChannelMap', ...
        ['Row %d channel map must be a permutation of acquisition ' ...
        'channels 1:NChannels.'], row);
end

session.Groups = repmat(struct( ...
    'Name', "", 'DisplayName', "", 'Mean', [], 'SEM', [], ...
    'Count', []), 1, numel(groups));
for groupIndex = 1:numel(groups)
    [meanColumn, semColumn, countColumn, displayName] = ...
        groupColumns(groups(groupIndex));
    meanFR = tableData.(meanColumn){row};
    semFR = tableData.(semColumn){row};
    count = tableData.(countColumn){row};
    expectedSize = [4 numel(session.Coherence) expectedChannels];
    if ~isequal(size(meanFR), expectedSize) || ...
            ~isequal(size(semFR), expectedSize)
        error('UnitTableStimFigures:InvalidCurveSize', ...
            'Row %d %s mean/SEM must have size %s.', ...
            row, groups(groupIndex), mat2str(expectedSize));
    end
    if ~isequal(size(count), expectedSize(1:2))
        error('UnitTableStimFigures:InvalidCountSize', ...
            'Row %d %s count matrix must have size %s.', ...
            row, groups(groupIndex), mat2str(expectedSize(1:2)));
    end
    session.Groups(groupIndex) = struct( ...
        'Name', groups(groupIndex), 'DisplayName', displayName, ...
        'Mean', double(meanFR), 'SEM', double(semFR), ...
        'Count', double(count));
end
end


function [meanColumn, semColumn, countColumn, displayName] = ...
    groupColumns(group)
switch group
    case "NoStim"
        meanColumn = "stim_tuning_mean_noStim";
        semColumn = "stim_tuning_SEM_noStim";
        countColumn = "stim_tuning_n_noStim";
        displayName = "NoStim trials only";
    case "Stim"
        meanColumn = "stim_tuning_mean_stim";
        semColumn = "stim_tuning_SEM_stim";
        countColumn = "stim_tuning_n_stim";
        displayName = "Stim trials only";
    case "Merged"
        meanColumn = "stim_tuning_mean_merged";
        semColumn = "stim_tuning_SEM_merged";
        countColumn = "stim_tuning_n_merged";
        displayName = "Merged - all trials pooled";
end
end


function session = zScoreSessionTuning(session)
% Match unit_table_gof.tuning_z: standardize each cue across coherence.
for groupIndex = 1:numel(session.Groups)
    meanFR = session.Groups(groupIndex).Mean;
    semFR = session.Groups(groupIndex).SEM;
    count = session.Groups(groupIndex).Count;

    for acquisitionChannel = 1:size(meanFR, 3)
        for cue = 1:size(meanFR, 1)
            cueMean = reshape( ...
                meanFR(cue, :, acquisitionChannel), 1, []);
            cueSEM = reshape( ...
                semFR(cue, :, acquisitionChannel), 1, []);
            valid = count(cue, :) > 0 & isfinite(cueMean);
            cueMean(~valid) = NaN;
            cueSEM(~valid) = NaN;

            validValues = cueMean(valid);
            if numel(validValues) < 2
                cueMean(valid) = NaN;
                cueSEM(valid) = NaN;
            else
                cueCenter = mean(validValues);
                cueScale = std(validValues, 0);
                if isfinite(cueScale) && cueScale > 0
                    cueMean(valid) = ...
                        (cueMean(valid) - cueCenter) ./ cueScale;
                    finiteSEM = valid & isfinite(cueSEM);
                    cueSEM(finiteSEM) = cueSEM(finiteSEM) ./ cueScale;
                else
                    % A constant tuning curve has no defined Z-score.
                    cueMean(valid) = NaN;
                    cueSEM(valid) = NaN;
                end
            end

            meanFR(cue, :, acquisitionChannel) = cueMean;
            semFR(cue, :, acquisitionChannel) = cueSEM;
        end
    end

    session.Groups(groupIndex).Mean = meanFR;
    session.Groups(groupIndex).SEM = semFR;
end
end


function yLimits = calculateSharedYLimits(session)
values = 0;
for groupIndex = 1:numel(session.Groups)
    meanFR = session.Groups(groupIndex).Mean;
    semFR = session.Groups(groupIndex).SEM;
    values = [values; meanFR(isfinite(meanFR))]; %#ok<AGROW>
    finiteError = isfinite(meanFR) & isfinite(semFR);
    lower = meanFR(finiteError) - semFR(finiteError);
    upper = meanFR(finiteError) + semFR(finiteError);
    values = [values; lower; upper]; %#ok<AGROW>
end
values = values(isfinite(values));
if isempty(values)
    yLimits = [0 1];
    return
end
lowerLimit = min(values);
upperLimit = max(values);
span = upperLimit - lowerLimit;
if span <= 0
    span = max(1, abs(upperLimit));
end
padding = 0.06 * span;
yLimits = [lowerLimit - padding upperLimit + padding];
if yLimits(1) > 0
    yLimits(1) = 0;
end
end


function figureHandle = createSessionFigure( ...
    row, monkey, dateLabel, groupName, figureVisible)
if figureVisible
    visible = 'on';
else
    visible = 'off';
end
figureName = sprintf('Row %d %s %s %s', ...
    row, monkey, dateLabel, groupName);
figureHandle = figure('Color', 'w', 'Visible', visible, ...
    'Name', figureName, 'Position', [40 60 2200 900]);
end


function drawSessionGroupFigure(figureHandle, ...
    row, monkey, dateLabel, stimChannel, tableStatus, session, ...
    groupData, yLimits)
colors = [0 0 0; 0 0 255; 5 150 5; 234 0 233] ./ 255;
stimHighlight = [0.85 0.33 0.10];
layout = tiledlayout(figureHandle, 2, 8, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
legendHandles = gobjects(1, numel(session.ConditionNames));

for probePosition = 1:numel(session.ChannelOrder)
    axesHandle = nexttile(layout, probePosition);
    acquisitionChannel = session.ChannelOrder(probePosition);
    hold(axesHandle, 'on');
    for cue = 1:numel(session.ConditionNames)
        y = reshape(groupData.Mean(cue, :, acquisitionChannel), 1, []);
        errorValue = reshape( ...
            groupData.SEM(cue, :, acquisitionChannel), 1, []);
        present = groupData.Count(cue, :) > 0 & isfinite(y);
        y(~present) = NaN;
        legendHandles(cue) = plot(axesHandle, session.Coherence, y, ...
            '-o', 'Color', colors(cue, :), ...
            'MarkerFaceColor', colors(cue, :), ...
            'MarkerEdgeColor', colors(cue, :), ...
            'MarkerSize', 3, 'LineWidth', 1.1);
        errorMask = present & isfinite(errorValue);
        if any(errorMask)
            errorbar(axesHandle, session.Coherence(errorMask), ...
                y(errorMask), errorValue(errorMask), ...
                'LineStyle', 'none', 'Color', colors(cue, :), ...
                'CapSize', 3, 'HandleVisibility', 'off');
        end
    end
    yline(axesHandle, 0, ':', 'Color', [0.70 0.70 0.70], ...
        'HandleVisibility', 'off');
    xlim(axesHandle, [session.Coherence(1) session.Coherence(end)]);
    ylim(axesHandle, yLimits);
    xticks(axesHandle, [-1 -0.5 0 0.5 1]);
    xtickformat(axesHandle, '%.1f');
    grid(axesHandle, 'on');
    axesHandle.GridAlpha = 0.10;
    axesHandle.FontSize = 8;
    box(axesHandle, 'on');

    isStimChannel = isfinite(stimChannel) && ...
        acquisitionChannel == stimChannel;
    if isStimChannel
        titleText = sprintf('Pos %d | Ch %d | STIM', ...
            probePosition, acquisitionChannel);
        title(axesHandle, titleText, 'Color', stimHighlight, ...
            'FontWeight', 'bold', 'FontSize', 9);
        axesHandle.XColor = stimHighlight;
        axesHandle.YColor = stimHighlight;
        axesHandle.LineWidth = 1.8;
    else
        title(axesHandle, sprintf('Pos %d | Ch %d', ...
            probePosition, acquisitionChannel), 'FontSize', 9);
    end
    if probePosition > 8
        xlabel(axesHandle, 'Signed coherence');
    end
    if probePosition == 1 || probePosition == 9
        ylabel(axesHandle, 'Z-scored mean FR');
    end
end

trialCount = sum(groupData.Count, 'all');
stimText = formatStimChannel(stimChannel);
titleLines = {sprintf('Row %03d | %s | %s | Stim channel %s', ...
    row, monkey, dateLabel, stimText), ...
    sprintf(['%s | %d trials | cue-wise Z-score +/- scaled SEM | ' ...
    'shared session y-axis'], ...
    groupData.DisplayName, trialCount)};
if tableStatus ~= "Success"
    titleLines{end + 1} = char("Table status: " + tableStatus);
end
title(layout, titleLines, 'FontWeight', 'bold');
legendHandle = legend(legendHandles, cellstr(session.ConditionNames), ...
    'Orientation', 'horizontal', 'FontSize', 8);
legendHandle.Layout.Tile = 'south';
end


function baseName = makeFigureBaseName( ...
    row, monkey, dateText, stimChannel, group)
safeMonkey = regexprep(char(monkey), '[^A-Za-z0-9_-]', '_');
baseName = string(sprintf('Row%03d_%s_%s_StimCh%s_%s', ...
    row, safeMonkey, dateText, formatStimChannel(stimChannel), group));
end


function textValue = formatStimChannel(stimChannel)
if isfinite(stimChannel) && stimChannel == fix(stimChannel)
    textValue = sprintf('%02d', stimChannel);
else
    textValue = 'NA';
end
end


function [dateLabel, dateFileText] = formatRecordingDate(dateValue)
if isdatetime(dateValue) && ~isnat(dateValue)
    dateLabel = string(dateValue, 'yyyy-MM-dd');
    dateFileText = char(string(dateValue, 'yyyyMMdd'));
else
    dateLabel = string(dateValue);
    dateFileText = regexprep(char(dateLabel), '[^0-9A-Za-z_-]', '_');
end
end


function value = rowText(variable, row)
if iscell(variable)
    value = string(variable{row});
else
    value = string(variable(row));
end
end


function atomicExportPNG(figureHandle, destination, resolution)
temporary = string(tempname(fileparts(destination))) + ".png";
cleanup = onCleanup(@() deleteIfPresent(temporary));
exportgraphics(figureHandle, temporary, 'Resolution', resolution);
finalizeTemporaryFile(temporary, destination);
clear cleanup
end


function atomicSaveFIG(figureHandle, destination)
temporary = string(tempname(fileparts(destination))) + ".fig";
cleanup = onCleanup(@() deleteIfPresent(temporary));
savefig(figureHandle, temporary, 'compact');
finalizeTemporaryFile(temporary, destination);
clear cleanup
end


function FigureManifest = mergePreviousManifest( ...
    FigureManifest, manifestMATFile)
if ~isfile(manifestMATFile)
    return
end
try
    previousData = load(manifestMATFile, 'FigureManifest');
    if ~isfield(previousData, 'FigureManifest') || ...
            ~istable(previousData.FigureManifest) || ...
            ~isequal(previousData.FigureManifest.Properties.VariableNames, ...
            FigureManifest.Properties.VariableNames)
        warning('UnitTableStimFigures:InvalidPriorManifest', ...
            'Existing MAT manifest is incompatible and will be replaced.');
        return
    end
    previous = previousData.FigureManifest;
    previousKeys = string(previous.UnitTableRow) + "|" + ...
        previous.TrialGroup;
    [~, uniqueIndex] = unique(previousKeys, 'last');
    previous = previous(sort(uniqueIndex), :);
    previousKeys = string(previous.UnitTableRow) + "|" + ...
        previous.TrialGroup;
    currentKeys = string(FigureManifest.UnitTableRow) + "|" + ...
        FigureManifest.TrialGroup;
    previous(ismember(previousKeys, currentKeys), :) = [];
    FigureManifest = [previous; FigureManifest];
    FigureManifest = sortrows( ...
        FigureManifest, {'UnitTableRow', 'TrialGroup'});
catch ME
    warning('UnitTableStimFigures:PriorManifestReadFailed', ...
        'Could not merge the prior figure manifest: %s', ME.message);
end
end


function atomicSaveManifest(FigureManifest, matFile, csvFile)
temporaryMAT = string(tempname(fileparts(matFile))) + ".mat";
temporaryCSV = string(tempname(fileparts(csvFile))) + ".csv";
matCleanup = onCleanup(@() deleteIfPresent(temporaryMAT));
csvCleanup = onCleanup(@() deleteIfPresent(temporaryCSV));
save(temporaryMAT, 'FigureManifest');
writetable(FigureManifest, temporaryCSV);
finalizeTemporaryFile(temporaryMAT, matFile);
finalizeTemporaryFile(temporaryCSV, csvFile);
clear matCleanup csvCleanup
end


function finalizeTemporaryFile(temporary, destination)
[succeeded, message] = movefile(temporary, destination, 'f');
if ~succeeded
    error('UnitTableStimFigures:FinalizeFailed', ...
        'Could not finalize %s: %s', destination, message);
end
end


function deleteIfPresent(filePath)
if isfile(filePath)
    delete(filePath);
end
end


function closeFigure(figureHandle)
if ~isempty(figureHandle) && all(isgraphics(figureHandle))
    close(figureHandle);
end
end

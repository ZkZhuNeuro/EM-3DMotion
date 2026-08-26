function manifest = PlotRemovedSiteFiveChannelTunings(options)
%PLOTREMOVEDSITEFIVECHANNELTUNINGS Plot radius-2 removed-site Quick tuning.
%
% One 1-by-5 figure is saved per removed site. Panels follow physical probe
% order: relative -2, -1, stimulation channel, +1, and +2. Each panel shows
% the four 3DMotionQuick cue means +/- SEM. Red-framed panels are significant
% combined-cue AI sign conflicts that caused the site to be removed.

arguments
    options.AnalysisFolder (1, 1) string = ...
        ["C:\EM\StimTuningAnalysis\" + ...
        "OriginalMaxOD_Adjacent2EachSide_CombinedAIConsistency_UnitTypeModels"]
    options.OutputFolder (1, 1) string = ""
    options.FigureVisible (1, 1) logical = false
end

if options.OutputFolder == ""
    outputFolder = fullfile(options.AnalysisFolder, ...
        'RemovedSiteFiveChannelTunings');
else
    outputFolder = options.OutputFolder;
end
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

resultFile = fullfile(options.AnalysisFolder, ...
    'OriginalMaxOD_AdjacentAICleanupResults.mat');
if ~isfile(resultFile)
    error('RemovedSiteTuning:MissingAnalysis', ...
        'Analysis result does not exist: %s', resultFile);
end
loadedResult = load(resultFile, 'population_analysis');
if ~isfield(loadedResult, 'population_analysis')
    error('RemovedSiteTuning:MissingResultVariable', ...
        'Result MAT does not contain population_analysis.');
end
analysis = loadedResult.population_analysis;
if analysis.NeighborRadius ~= 2
    error('RemovedSiteTuning:WrongNeighborRadius', ...
        'The input analysis must use two contacts on each side.');
end
audit = analysis.AdjacentChannelAudit;
removed = audit.ExcludeForAIFlip & audit.Status == "Success";
audit = audit(removed, :);
if isempty(audit)
    error('RemovedSiteTuning:NoRemovedSites', ...
        'The analysis contains no removed sites to plot.');
end

loadedInput = load(analysis.OriginalInputFile, 'unit_table_gof');
if ~isfield(loadedInput, 'unit_table_gof')
    error('RemovedSiteTuning:MissingInputTable', ...
        'Original analysis input does not contain unit_table_gof.');
end
unitTable = loadedInput.unit_table_gof;

siteCount = height(audit);
tableRow = audit.TableRow;
monkey = audit.Monkey;
recordingDate = audit.Date;
roi = audit.ROI;
unitType = strings(siteCount, 1);
stimChannel = audit.StimChannel;
channelSequence = strings(siteCount, 1);
flipRelativePositions = strings(siteCount, 1);
pngFile = strings(siteCount, 1);
pdfFile = strings(siteCount, 1);
figFile = strings(siteCount, 1);
status = repmat("Pending", siteCount, 1);
message = strings(siteCount, 1);

for site = 1:siteCount
    figureHandle = gobjects(0);
    try
        row = audit.TableRow(site);
        if row < 1 || row > height(unitTable)
            error('RemovedSiteTuning:InvalidTableRow', ...
                'Audit table row %d is outside the original input table.', row);
        end
        unitType(site) = classifyUnit( ...
            numericScalar(unitTable.Z3D_v_Z2D, row));
        cacheFile = audit.CacheFile(site);
        if ~isfile(cacheFile)
            error('RemovedSiteTuning:MissingCache', ...
                'Quick cache does not exist: %s', cacheFile);
        end
        loadedCache = load(cacheFile, 'Neuro');
        if ~isfield(loadedCache, 'Neuro') || ...
                ~isfield(loadedCache.Neuro, 'Means')
            error('RemovedSiteTuning:MissingNeuroMeans', ...
                'Quick cache does not contain Neuro.Means.');
        end
        Neuro = loadedCache.Neuro;
        means = double(Neuro.Means);
        if isfield(Neuro, 'SEM')
            sem = double(Neuro.SEM);
        else
            sem = nan(size(means));
        end
        coherence = inferQuickCoherence(size(means, 2));

        channels = [audit.Minus2Channel(site), ...
            audit.Minus1Channel(site), audit.StimChannel(site), ...
            audit.Plus1Channel(site), audit.Plus2Channel(site)];
        relativePositions = [-2, -1, 0, 1, 2];
        pValues = [audit.Minus2CombinedP(site), ...
            audit.Minus1CombinedP(site), stimulationCombinedP(unitTable, row), ...
            audit.Plus1CombinedP(site), audit.Plus2CombinedP(site)];
        significant = [audit.Minus2Significant(site), ...
            audit.Minus1Significant(site), false, ...
            audit.Plus1Significant(site), audit.Plus2Significant(site)];
        signFlip = [audit.Minus2SignFlip(site), ...
            audit.Minus1SignFlip(site), false, ...
            audit.Plus1SignFlip(site), audit.Plus2SignFlip(site)];
        aiValues = fiveChannelAI(unitTable, row, channels);
        channelSequence(site) = join(string(channels), ',');
        flipRelativePositions(site) = join( ...
            string(relativePositions(signFlip)), ',');

        figureHandle = makeTuningFigure(means, sem, coherence, ...
            channels, relativePositions, aiValues, pValues, significant, ...
            signFlip, audit, site, unitType(site), options.FigureVisible);
        baseName = sprintf('%03d_%s_%s_%s_%s_five_channel_quick_tuning', ...
            row, char(audit.Monkey(site)), ...
            char(string(audit.Date(site), 'yyyyMMdd')), ...
            char(audit.ROI(site)), char(unitType(site)));
        pngFile(site) = fullfile(outputFolder, baseName + ".png");
        pdfFile(site) = fullfile(outputFolder, baseName + ".pdf");
        figFile(site) = fullfile(outputFolder, baseName + ".fig");
        exportgraphics(figureHandle, pngFile(site), 'Resolution', 300);
        exportgraphics(figureHandle, pdfFile(site), 'ContentType', 'vector');
        savefig(figureHandle, figFile(site));
        status(site) = "Success";
    catch ME
        status(site) = "Error";
        message(site) = string(ME.identifier) + ": " + string(ME.message);
    end
    closeValidFigure(figureHandle);
end

manifest = table(tableRow, monkey, recordingDate, roi, unitType, ...
    stimChannel, channelSequence, flipRelativePositions, ...
    pngFile, pdfFile, figFile, status, message, ...
    'VariableNames', {'TableRow', 'Monkey', 'Date', 'ROI', 'UnitType', ...
    'StimChannel', 'ChannelsRelativeMinus2ToPlus2', ...
    'FlipRelativePositions', 'PNGFile', 'PDFFile', 'FIGFile', ...
    'Status', 'Message'});
writetable(manifest, fullfile(outputFolder, ...
    'RemovedSiteFiveChannelTuningManifest.csv'));
save(fullfile(outputFolder, 'RemovedSiteFiveChannelTunings.mat'), ...
    'manifest', '-v7.3');

errorRows = manifest.Status == "Error";
if any(errorRows)
    warning('RemovedSiteTuning:PlotErrors', ...
        '%d of %d removed-site figures failed; inspect the manifest.', ...
        sum(errorRows), height(manifest));
end
fprintf('Saved %d removed-site 1x5 tuning figure(s) to %s\n', ...
    sum(manifest.Status == "Success"), outputFolder);
end


function figureHandle = makeTuningFigure(means, sem, coherence, ...
    channels, relativePositions, aiValues, pValues, significant, ...
    signFlip, audit, site, unitType, visible)
visibility = "off";
if visible
    visibility = "on";
end
figureHandle = figure('Color', 'w', 'Visible', visibility, ...
    'Position', [20 120 2450 620], ...
    'Name', 'Removed-site five-channel Quick tuning');
layout = tiledlayout(figureHandle, 1, 5, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
cueNames = ["Combined", "MonoL", "MonoR", "Stereo"];
colors = [0 0 0; 0 0 255; 5 150 5; 234 0 233] ./ 255;
[yMinimum, yMaximum] = sharedYLimits(means, sem, channels);

for panel = 1:5
    axesHandle = nexttile(layout, panel);
    hold(axesHandle, 'on');
    channel = channels(panel);
    if ~isfinite(channel) || channel < 1 || channel > size(means, 3)
        axis(axesHandle, 'off');
        text(axesHandle, 0.5, 0.5, 'Channel unavailable', ...
            'HorizontalAlignment', 'center');
        continue
    end
    lineHandles = gobjects(4, 1);
    for cue = 1:4
        cueMean = reshape(means(cue, :, channel), 1, []);
        cueSEM = reshape(sem(cue, :, channel), 1, []);
        lineHandles(cue) = errorbar(axesHandle, coherence, cueMean, cueSEM, ...
            '-o', 'Color', colors(cue, :), ...
            'MarkerFaceColor', colors(cue, :), 'MarkerSize', 4, ...
            'LineWidth', 1.45, 'CapSize', 3, ...
            'DisplayName', cueNames(cue));
    end
    xline(axesHandle, 0, ':', 'Color', [0.6 0.6 0.6], ...
        'HandleVisibility', 'off');
    xlim(axesHandle, [min(coherence), max(coherence)]);
    ylim(axesHandle, [yMinimum, yMaximum]);
    xticks(axesHandle, [-1 -0.5 0 0.5 1]);
    grid(axesHandle, 'on');
    axesHandle.GridAlpha = 0.12;
    axesHandle.FontSize = 10;
    axesHandle.LineWidth = 1.2;
    stateLabel = panelStateLabel(panel, significant(panel), signFlip(panel));
    titleColor = [0.1 0.1 0.1];
    if signFlip(panel)
        axesHandle.XColor = [0.8 0 0];
        axesHandle.YColor = [0.8 0 0];
        axesHandle.LineWidth = 2.4;
        titleColor = [0.8 0 0];
    elseif panel == 3
        axesHandle.XColor = [0.05 0.25 0.7];
        axesHandle.YColor = [0.05 0.25 0.7];
        axesHandle.LineWidth = 2.0;
        titleColor = [0.05 0.25 0.7];
    end
    title(axesHandle, {sprintf('relative %+d | channel %d', ...
        relativePositions(panel), channel), ...
        sprintf('Combined AI = %+.3f | %s', ...
        aiValues(panel), formatPValue(pValues(panel))), stateLabel}, ...
        'FontSize', 11, 'Color', titleColor, 'Interpreter', 'none');
    if panel == 1
        legend(axesHandle, lineHandles, cellstr(cueNames), ...
            'Location', 'best', 'FontSize', 8);
    end
end
xlabel(layout, 'Signed motion coherence', 'FontSize', 13);
ylabel(layout, 'Firing rate (spikes/s), mean +/- SEM', 'FontSize', 13);
dateLabel = char(string(audit.Date(site), 'dd-MMM-yyyy'));
title(layout, sprintf([ ...
    '%s | %s | %s %s | original row %d | stimulation channel %d\n' ...
    'Removed by significant combined-cue AI sign conflict within +/-2 contacts'], ...
    char(audit.Monkey(site)), dateLabel, char(audit.ROI(site)), ...
    char(unitType), audit.TableRow(site), audit.StimChannel(site)), ...
    'FontWeight', 'bold', 'FontSize', 15, 'Interpreter', 'none');
end


function [minimum, maximum] = sharedYLimits(means, sem, channels)
validChannels = channels(isfinite(channels) & channels >= 1 & ...
    channels <= size(means, 3));
values = [];
for channel = validChannels
    channelMean = means(:, :, channel);
    channelSEM = sem(:, :, channel);
    values = [values; channelMean(:) - channelSEM(:); ... %#ok<AGROW>
        channelMean(:) + channelSEM(:)]; %#ok<AGROW>
end
values = values(isfinite(values));
if isempty(values)
    minimum = 0;
    maximum = 1;
    return
end
minimum = min(values);
maximum = max(values);
range = maximum - minimum;
if ~isfinite(range) || range <= eps
    range = max(1, abs(maximum));
end
padding = 0.08 .* range;
minimum = minimum - padding;
maximum = maximum + padding;
end


function values = fiveChannelAI(unitTable, row, channels)
aiMatrix = numericArray(unitTable.AI, row);
values = nan(1, numel(channels));
for index = 1:numel(channels)
    channel = channels(index);
    if isfinite(channel) && channel >= 1 && channel <= size(aiMatrix, 2)
        values(index) = aiMatrix(1, channel);
    end
end
end


function pValue = stimulationCombinedP(unitTable, row)
pValues = numericArray(unitTable.p_AI, row);
if isempty(pValues)
    pValue = NaN;
else
    pValue = pValues(1);
end
end


function label = panelStateLabel(panel, significant, signFlip)
if panel == 3
    label = 'STIMULATION CHANNEL';
elseif signFlip
    label = 'SIGNIFICANT OPPOSITE SIGN';
elseif significant
    label = 'significant, same sign';
else
    label = 'combined tuning not significant';
end
end


function label = formatPValue(value)
if ~isfinite(value)
    label = 'p = NaN';
elseif value < 0.001
    label = sprintf('p = %.2e', value);
else
    label = sprintf('p = %.3f', value);
end
end


function coherence = inferQuickCoherence(count)
switch count
    case 8
        numerator = [-22 -14 -10 -8 8 10 14 22];
    case 12
        numerator = [-22 -14 -10 -8 -4 -2 2 4 8 10 14 22];
    case 13
        numerator = [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22];
    otherwise
        error('RemovedSiteTuning:UnknownCoherenceGrid', ...
            'Expected 8, 12, or 13 Quick coherence values; found %d.', count);
end
coherence = numerator ./ 22;
end


function value = classifyUnit(zValue)
if zValue < 0
    value = "2D";
elseif zValue > 0
    value = "3D";
else
    value = "Unknown";
end
end


function value = numericScalar(column, row)
value = numericArray(column, row);
if ~isscalar(value)
    error('RemovedSiteTuning:ExpectedNumericScalar', ...
        'Expected a numeric scalar at row %d.', row);
end
end


function value = numericArray(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
while iscell(value) && isscalar(value)
    value = value{1};
end
if ~isnumeric(value)
    error('RemovedSiteTuning:ExpectedNumericValue', ...
        'Expected numeric data at row %d.', row);
end
value = double(value);
end


function closeValidFigure(figureHandle)
if ~isempty(figureHandle) && all(isgraphics(figureHandle, 'figure'))
    close(figureHandle);
end
end

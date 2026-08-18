function plotIndex = currentSpreadSaveIncludedSessionChannelTuning( ...
        result, paths, outputDir)
%CURRENTSPREADSAVEINCLUDEDSESSIONCHANNELTUNING Plot all 16 channels per session.
%
% Each included session is saved as a 4-by-4 physical-channel-order figure.
% Dead channels remain blank. Channels excluded by the two-eye tuning screen
% are dashed. Included channels are solid, carry their Gaussian weight in the
% title, and receive a black frame whose opacity reflects normalized weight.

arguments
    result (1, 1) struct
    paths (1, 1) struct
    outputDir (1, :) char
end

sessionOutputDir = fullfile(outputDir, 'included_session_channel_tuning');
if ~isfolder(sessionOutputDir)
    mkdir(sessionOutputDir);
end

unitData = load(paths.unitTableGof, 'unit_table_gof');
unitTableAll = unitData.unit_table_gof;
neuroData = load(paths.neuroAll, 'NeuroAll');

channelMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10];
leftColor = [0.08 0.40 0.75];
rightColor = [0.82 0.20 0.18];
bestSigma = result.optimized.bestSigma;
sourceRows = result.originalRowIndex(:);
numSessions = numel(sourceRows);
pdfPath = fullfile(sessionOutputDir, ...
    'jim_mt_included_session_channel_tuning.pdf');

sourceRowColumn = NaN(numSessions, 1);
originalRecColumn = NaN(numSessions, 1);
stimElecColumn = NaN(numSessions, 1);
retainedCountColumn = NaN(numSessions, 1);
bestSigmaColumn = repmat(bestSigma, numSessions, 1);
pngFileColumn = strings(numSessions, 1);
figFileColumn = strings(numSessions, 1);
pdfPageColumn = (1:numSessions)';

for session = 1:numSessions
    sourceRow = sourceRows(session);
    unitRow = unitTableAll(sourceRow, :);
    originalRec = unitRow.OriginalRecIdx;
    recording = neuroData.NeuroAll{originalRec};
    coherence = coherenceForChannelPlot(recording);
    numChannels = min(16, size(recording, 4));

    audit = result.channelAudit(result.channelAudit.SourceRow == sourceRow, :);
    tunedMask = false(1, 16);
    deadMask = false(1, 16);
    relativePosition = NaN(1, 16);
    for auditRow = 1:height(audit)
        channel = audit.Channel(auditRow);
        if channel < 1 || channel > 16
            continue
        end
        tunedMask(channel) = audit.TunedBoth(auditRow);
        deadMask(channel) = audit.DeadChannel(auditRow);
        relativePosition(channel) = audit.RelativePosition(auditRow);
    end
    tunedMask(numChannels+1:end) = false;
    deadMask(numChannels+1:end) = true;
    channelWeights = gaussianWeightsOverIncludedChannels( ...
        tunedMask, relativePosition, bestSigma);

    meanTuning = NaN(2, size(recording, 2), 16);
    for channel = 1:numChannels
        meanTuning(:, :, channel) = mean( ...
            recording([2, 3], :, :, channel), 3, 'omitnan');
    end
    finiteTuning = meanTuning(:, :, ~deadMask);
    finiteTuning = finiteTuning(isfinite(finiteTuning));
    if isempty(finiteTuning)
        yLimits = [0 1];
    else
        yMinimum = min(finiteTuning);
        yMaximum = max(finiteTuning);
        yRange = yMaximum - yMinimum;
        if yRange <= eps
            yRange = max(1, abs(yMaximum));
        end
        yLimits = [yMinimum - 0.08 .* yRange, yMaximum + 0.08 .* yRange];
    end

    figureHandle = figure('Color', 'w', 'Visible', 'off', ...
        'Name', sprintf('Jim_MT_channel_tuning_source_row_%d', sourceRow), ...
        'Position', [40 40 1700 1300]);
    layout = tiledlayout(figureHandle, 4, 4, 'TileSpacing', 'compact', ...
        'Padding', 'compact');

    for tileIndex = 1:16
        channel = channelMap(tileIndex);
        axesHandle = nexttile(layout, tileIndex);
        if channel > numChannels || deadMask(channel)
            axis(axesHandle, 'off')
            title(axesHandle, sprintf('Ch %d (dead)', channel), ...
                'Color', [0.62 0.62 0.62], 'FontWeight', 'normal', ...
                'FontSize', 9)
            continue
        end

        hold(axesHandle, 'on')
        if tunedMask(channel)
            lineStyle = '-';
            marker = 'o';
            lineWidth = 1.8;
        else
            lineStyle = '--';
            marker = 'none';
            lineWidth = 1.25;
        end
        plot(axesHandle, coherence, squeeze(meanTuning(1, :, channel)), ...
            'Color', leftColor, 'LineStyle', lineStyle, 'Marker', marker, ...
            'MarkerSize', 3.5, 'MarkerFaceColor', leftColor, ...
            'LineWidth', lineWidth);
        plot(axesHandle, coherence, squeeze(meanTuning(2, :, channel)), ...
            'Color', rightColor, 'LineStyle', lineStyle, 'Marker', marker, ...
            'MarkerSize', 3.5, 'MarkerFaceColor', rightColor, ...
            'LineWidth', lineWidth);
        xlim(axesHandle, [-1.05 1.05])
        ylim(axesHandle, yLimits)
        xticks(axesHandle, [-1 0 1])
        box(axesHandle, 'off')
        set(axesHandle, 'FontSize', 8.5, 'LineWidth', 0.75)
        if tileIndex > 12
            xlabel(axesHandle, 'Coherence', 'FontSize', 8.5)
        end
        if mod(tileIndex - 1, 4) == 0
            ylabel(axesHandle, 'Firing rate', 'FontSize', 8.5)
        end

        distance = relativePosition(channel);
        if tunedMask(channel)
            weight = channelWeights(channel);
            titleText = sprintf('Ch %d | d = %+d | w = %.3g', ...
                channel, round(distance), weight);
            maxWeight = max(channelWeights);
            frameAlpha = 0.10 + 0.90 .* sqrt(weight ./ maxWeight);
            addWeightedFrame(axesHandle, frameAlpha);
        else
            titleText = sprintf('Ch %d | d = %+d | excluded', ...
                channel, round(distance));
        end
        title(axesHandle, titleText, 'FontSize', 9, ...
            'FontWeight', 'normal')
    end

    titleLine1 = sprintf([ ...
        'Jim MT cleaned meta-2D | source row %d | OriginalRecIdx %d | ' ...
        'stimulation channel %d'], sourceRow, originalRec, unitRow.StimElec);
    titleLine2 = sprintf([ ...
        'Gaussian sigma = %.3g | blue = left eye, red = right eye | ' ...
        'solid + black frame = included, dashed = excluded | ' ...
        'frame opacity = relative weight'], bestSigma);
    sgtitle(layout, {titleLine1; titleLine2}, 'FontWeight', 'bold');

    baseName = sprintf('session_%02d_source_row_%03d_original_rec_%03d', ...
        session, sourceRow, originalRec);
    pngPath = fullfile(sessionOutputDir, [baseName '.png']);
    figPath = fullfile(sessionOutputDir, [baseName '.fig']);
    exportgraphics(figureHandle, pngPath, 'Resolution', 220);
    savefig(figureHandle, figPath);
    if session == 1
        exportgraphics(figureHandle, pdfPath, 'ContentType', 'vector');
    else
        exportgraphics(figureHandle, pdfPath, 'ContentType', 'vector', ...
            'Append', true);
    end
    close(figureHandle)

    sourceRowColumn(session) = sourceRow;
    originalRecColumn(session) = originalRec;
    stimElecColumn(session) = unitRow.StimElec;
    retainedCountColumn(session) = sum(tunedMask);
    pngFileColumn(session) = string(pngPath);
    figFileColumn(session) = string(figPath);
end

plotIndex = table((1:numSessions)', sourceRowColumn, originalRecColumn, ...
    stimElecColumn, retainedCountColumn, bestSigmaColumn, pdfPageColumn, ...
    pngFileColumn, figFileColumn, ...
    'VariableNames', {'IncludedSession', 'SourceRow', 'OriginalRecIdx', ...
    'StimElec', 'RetainedChannelCount', 'BestSigma', 'PDFPage', ...
    'PNGFile', 'FIGFile'});
writetable(plotIndex, fullfile(sessionOutputDir, 'session_plot_index.csv'));
end

function coherence = coherenceForChannelPlot(recording)
switch size(recording, 2)
    case 12
        coherence = [-22 -14 -10 -8 -4 -2 2 4 8 10 14 22] ./ 22;
    case 13
        coherence = [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22] ./ 22;
    otherwise
        error('CurrentSpread:UnexpectedCoherenceCount', ...
            'Expected 12 or 13 coherence bins, found %d.', size(recording, 2));
end
end

function weights = gaussianWeightsOverIncludedChannels( ...
        tunedMask, relativePosition, sigma)
weights = zeros(1, numel(tunedMask));
includedChannels = find(tunedMask & isfinite(relativePosition));
if isempty(includedChannels)
    return
end
logWeights = -(relativePosition(includedChannels) .^ 2) ./ (2 .* sigma .^ 2);
logWeights = logWeights - max(logWeights);
includedWeights = exp(logWeights);
includedWeights = includedWeights ./ sum(includedWeights);
weights(includedChannels) = includedWeights;
end

function addWeightedFrame(axesHandle, frameAlpha)
xLimits = xlim(axesHandle);
yLimits = ylim(axesHandle);
frame = patch(axesHandle, ...
    'XData', [xLimits(1) xLimits(2) xLimits(2) xLimits(1) xLimits(1)], ...
    'YData', [yLimits(1) yLimits(1) yLimits(2) yLimits(2) yLimits(1)], ...
    'FaceColor', 'none', 'EdgeColor', [0 0 0], ...
    'EdgeAlpha', min(max(frameAlpha, 0), 1), 'LineWidth', 3.2, ...
    'HandleVisibility', 'off', 'Clipping', 'off');
uistack(frame, 'top')
end

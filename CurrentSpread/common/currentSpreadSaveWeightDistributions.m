function figureHandles = currentSpreadSaveWeightDistributions(result, outputDir)
%CURRENTSPREADSAVEWEIGHTDISTRIBUTIONS Plot every fitted spatial-weight profile.
%
% One figure is saved for each centered channel window. Thin gray curves are
% the individual outer-training-fold fits; the blue curve is their mean and
% the shaded band is +/- one standard deviation across those fits.

arguments
    result (1, 1) struct
    outputDir (1, :) char
end

requiredFields = ["method", "methodLabel", "channelsIncluded", ...
    "maxDistanceChannels", "weightsByRepeat", "numRepeats", "numFolds"];
for field = requiredFields
    if ~isfield(result, field)
        error('CurrentSpread:MissingWeightResultField', ...
            'The result structure is missing field "%s".', field);
    end
end

weightOutputDir = fullfile(outputDir, 'weight_distributions');
if ~isfolder(weightOutputDir)
    mkdir(weightOutputDir);
end

numWindows = numel(result.channelsIncluded);
figureHandles = gobjects(numWindows, 1);
allFitTable = table();
allSummaryTable = table();

for windowIndex = 1:numWindows
    radius = result.maxDistanceChannels(windowIndex);
    channelsIncluded = result.channelsIncluded(windowIndex);
    relativePosition = (-radius:radius)';
    numPositions = numel(relativePosition);
    maxFits = result.numRepeats * result.numFolds;
    weightMatrix = NaN(maxFits, numPositions);
    repeatByFit = NaN(maxFits, 1);
    foldByFit = NaN(maxFits, 1);
    fitCount = 0;

    for repeatIndex = 1:result.numRepeats
        foldWeights = result.weightsByRepeat{repeatIndex, windowIndex};
        for foldIndex = 1:numel(foldWeights)
            rawWeights = foldWeights{foldIndex}(:);
            if startsWith(result.method, "shell-")
                if numel(rawWeights) ~= radius + 1
                    error('CurrentSpread:ShellWeightSize', ...
                        'Expected %d distance-shell weights but found %d.', ...
                        radius + 1, numel(rawWeights));
                end
                positionWeights = rawWeights(abs(relativePosition) + 1);
            else
                if numel(rawWeights) ~= numPositions
                    error('CurrentSpread:RelativeWeightSize', ...
                        'Expected %d relative-channel weights but found %d.', ...
                        numPositions, numel(rawWeights));
                end
                positionWeights = rawWeights;
            end

            tolerance = 1e-5;
            if any(~isfinite(rawWeights)) || any(rawWeights < -tolerance)
                error('CurrentSpread:InvalidWeightValues', ...
                    'Weights must be finite and nonnegative.');
            end
            if startsWith(result.method, "shell-")
                normalization = rawWeights(1) + 2 * sum(rawWeights(2:end));
                if any(diff(rawWeights) > tolerance)
                    error('CurrentSpread:NonmonotonicShellWeights', ...
                        'Distance-shell weights must not increase with distance.');
                end
            else
                normalization = sum(rawWeights);
            end
            if abs(normalization - 1) > tolerance
                error('CurrentSpread:UnnormalizedWeights', ...
                    'Expanded channel weights must sum to one.');
            end

            fitCount = fitCount + 1;
            weightMatrix(fitCount, :) = positionWeights(:)';
            repeatByFit(fitCount) = repeatIndex;
            foldByFit(fitCount) = foldIndex;
        end
    end

    weightMatrix = weightMatrix(1:fitCount, :);
    repeatByFit = repeatByFit(1:fitCount);
    foldByFit = foldByFit(1:fitCount);
    meanWeight = mean(weightMatrix, 1, 'omitnan')';
    sdWeight = std(weightMatrix, 0, 1, 'omitnan')';
    semWeight = sdWeight ./ sqrt(fitCount);
    lowerBand = max(0, meanWeight - sdWeight);
    upperBand = min(1, meanWeight + sdWeight);

    figureHandle = figure('Color', 'w', 'Visible', 'off', ...
        'Name', sprintf('weights_%02d_channels', channelsIncluded));
    hold on
    bandHandle = fill([relativePosition; flipud(relativePosition)], ...
        [lowerBand; flipud(upperBand)], [0.25 0.55 0.85], ...
        'FaceAlpha', 0.20, 'EdgeColor', 'none', ...
        'DisplayName', 'CV-fit mean +/- 1 SD');

    individualHandle = gobjects(1);
    for fitIndex = 1:fitCount
        fitHandle = plot(relativePosition, weightMatrix(fitIndex, :), '-', ...
            'Color', [0.72 0.75 0.80], 'LineWidth', 0.75);
        if fitIndex == 1
            individualHandle = fitHandle;
            individualHandle.DisplayName = sprintf( ...
                'Individual CV training fits (N = %d)', fitCount);
        else
            fitHandle.HandleVisibility = 'off';
        end
    end

    meanHandle = plot(relativePosition, meanWeight, 'o-', ...
        'Color', [0.05 0.35 0.70], ...
        'MarkerFaceColor', [0.05 0.35 0.70], ...
        'LineWidth', 2.5, 'MarkerSize', 6, ...
        'DisplayName', 'Mean across CV fits');
    grid on
    box off
    xticks(relativePosition)
    if radius == 0
        xlim([-0.5 0.5])
    else
        xlim([-radius - 0.5, radius + 0.5])
    end
    yMaximum = min(1.02, max(upperBand) * 1.15 + 0.02);
    ylim([0, max(0.10, yMaximum)])
    xlabel('Channel position relative to stimulation channel')
    ylabel('Nominal normalized weight')
    title(result.methodLabel, 'Interpreter', 'none')
    subtitle(sprintf(['%d centered channels; maximum distance = %d; ' ...
        '%d outer-training fits'], channelsIncluded, radius, fitCount))
    legend([individualHandle, bandHandle, meanHandle], ...
        'Location', 'best', 'Box', 'off')

    baseName = sprintf('weights_%02d_channels_distance_%02d', ...
        channelsIncluded, radius);
    savefig(figureHandle, fullfile(weightOutputDir, [baseName '.fig']));
    exportgraphics(figureHandle, ...
        fullfile(weightOutputDir, [baseName '.png']), 'Resolution', 300);

    summaryTable = table( ...
        repmat(string(result.method), numPositions, 1), ...
        repmat(channelsIncluded, numPositions, 1), ...
        repmat(radius, numPositions, 1), relativePosition, meanWeight, ...
        sdWeight, semWeight, min(weightMatrix, [], 1)', ...
        max(weightMatrix, [], 1)', repmat(fitCount, numPositions, 1), ...
        'VariableNames', {'Method', 'ChannelsIncluded', ...
        'MaxDistanceChannels', 'RelativeChannelPosition', 'MeanWeight', ...
        'SDWeight', 'SEMWeight', 'MinWeight', 'MaxWeight', 'NumFits'});
    writetable(summaryTable, ...
        fullfile(weightOutputDir, [baseName '_summary.csv']));
    allSummaryTable = [allSummaryTable; summaryTable]; %#ok<AGROW>

    numFitRows = fitCount * numPositions;
    weightValues = reshape(weightMatrix', [], 1);
    fitTable = table( ...
        repmat(string(result.method), numFitRows, 1), ...
        repelem(repeatByFit, numPositions), ...
        repelem(foldByFit, numPositions), ...
        repmat(channelsIncluded, numFitRows, 1), ...
        repmat(radius, numFitRows, 1), ...
        repmat(relativePosition, fitCount, 1), weightValues, ...
        'VariableNames', {'Method', 'Repeat', 'Fold', ...
        'ChannelsIncluded', 'MaxDistanceChannels', ...
        'RelativeChannelPosition', 'Weight'});
    allFitTable = [allFitTable; fitTable]; %#ok<AGROW>
    figureHandles(windowIndex) = figureHandle;
end

writetable(allSummaryTable, ...
    fullfile(weightOutputDir, 'all_weight_distributions_summary.csv'));
writetable(allFitTable, ...
    fullfile(weightOutputDir, 'all_weight_distributions_individual_fits.csv'));
end

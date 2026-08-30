function outputFiles = SaveWeightedMetaTuningBiasComparison( ...
    result, outputFolder, options)
%SAVEWEIGHTEDMETATUNINGBIASCOMPARISON Export weighted-meta results.

arguments
    result (1, 1) struct
    outputFolder (1, 1) string
    options.FigureVisible (1, 1) logical = false
end

if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
visible = "off";
if options.FigureVisible
    visible = "on";
end

outputFiles = strings(0, 1);
outputFiles(end + 1, 1) = writeTable(result.GroupSummary, outputFolder, ...
    'WeightedMeta_GroupSummary.csv');
outputFiles(end + 1, 1) = writeTable(result.ConditionSummary, outputFolder, ...
    'WeightedMeta_ConditionSummary.csv');
outputFiles(end + 1, 1) = writeTable(result.FullWeightSummary, outputFolder, ...
    'WeightedMeta_FullFitWeights.csv');
outputFiles(end + 1, 1) = writeTable(result.FoldWeightTable, outputFolder, ...
    'WeightedMeta_CVFoldWeights.csv');
outputFiles(end + 1, 1) = writeTable(result.Cache.Audit, outputFolder, ...
    'WeightedMeta_SessionAudit.csv');
featureAudit = buildFeatureAudit(result);
outputFiles(end + 1, 1) = writeTable(featureAudit, outputFolder, ...
    'WeightedMeta_CenterReconstructionAudit.csv');
outputFiles(end + 1, 1) = writeTable( ...
    result.CenterReconstructionSummary, outputFolder, ...
    'WeightedMeta_CenterReconstructionSummary.csv');

variants = unique(result.GroupSummary.ModelVariant, 'stable');
analyses = unique(result.GroupSummary.Analysis, 'stable');
for variant = variants'
    for analysis = analyses'
        successful = result.GroupSummary.Status == "Success" & ...
            result.GroupSummary.ModelVariant == variant & ...
            result.GroupSummary.Analysis == analysis;
        if ~any(successful)
            continue
        end
        r2Figure = plotR2Figure(result.GroupSummary(successful, :), ...
            variant, analysis, result.RelativePositions, visible);
        stem = sprintf('WeightedMeta_R2_%s_%s', variant, analysis);
        outputFiles = [outputFiles; exportFigureSet( ...
            r2Figure, outputFolder, stem)]; %#ok<AGROW>
        close(r2Figure)

        matchingGroups = result.Groups(arrayfun(@(group) ...
            group.Status == "Success" && group.ModelVariant == variant && ...
            group.Analysis == analysis, result.Groups));
        weightFigure = plotWeightFigure(matchingGroups, variant, ...
            analysis, visible);
        stem = sprintf('WeightedMeta_WeightSilhouettes_%s_%s', ...
            variant, analysis);
        outputFiles = [outputFiles; exportFigureSet( ...
            weightFigure, outputFolder, stem)]; %#ok<AGROW>
        close(weightFigure)
    end
end

resultsFile = fullfile(outputFolder, ...
    'WeightedMetaTuningBiasComparisonResults.mat');
outputFiles(end + 1, 1) = string(resultsFile);
save(resultsFile, 'result', 'outputFiles', '-v7.3')
end


function file = writeTable(input, outputFolder, fileName)
file = string(fullfile(outputFolder, fileName));
writetable(input, file);
end


function audit = buildFeatureAudit(result)
center = result.CenterWeightIndex;
sessionStats = result.Cache.SessionStats;
sourceRow = [sessionStats.SourceRow]';
area = string({sessionStats.Area})';
unitType = string({sessionStats.UnitType})';
storedAI = reshape(vertcat(sessionStats.StoredStimAI), 4, [])';
reconstructedAI = result.Features.AI(:, :, center);
storedOD = [sessionStats.OriginalSignedOD]';
reconstructedOD = result.Features.SignedOD(:, center);
maxAbsAIError = max(abs(storedAI - reconstructedAI), [], 2, 'omitnan');
audit = table(sourceRow, area, unitType, maxAbsAIError, storedOD, ...
    reconstructedOD, reconstructedOD - storedOD, ...
    'VariableNames', {'SourceRow', 'Area', 'UnitType', ...
    'MaxAbsStoredVsReconstructedAIError', 'StoredSignedOD', ...
    'ReconstructedSignedOD', 'SignedODDifference'});
for cue = 1:4
    audit.(sprintf('StoredAI_Cue%d', cue)) = storedAI(:, cue);
    audit.(sprintf('ReconstructedAI_Cue%d', cue)) = ...
        reconstructedAI(:, cue);
end
end


function fig = plotR2Figure(summary, variant, analysis, ...
    relativePositions, visible)
fig = figure('Color', 'w', 'Visible', visible, ...
    'Position', [60 60 1500 720], ...
    'Name', sprintf('Weighted meta tuning R2 %s %s', variant, analysis));
layout = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
axOrdinary = nexttile(layout);
plotComparisonPanel(axOrdinary, summary.BaselineMacroOrdinaryR2, ...
    summary.ExpandedMacroOrdinaryR2, summary, ...
    'Macro ordinary in-sample R^2');
axCV = nexttile(layout);
plotComparisonPanel(axCV, summary.BaselineMeanMacroCVR2, ...
    summary.ExpandedMeanMacroCVR2, summary, ...
    'Mean macro held-out R^2');
if variant == "AIxOD"
    formula = 'Bias ~ MetaAI + MetaAI:|MetaOD|';
else
    formula = 'Bias ~ MetaAI';
end
if analysis == "AllCue"
    scope = 'all four cues, shared channel weights';
else
    scope = 'Stereo cue only';
end
title(layout, [sprintf("Weighted z-scored %d-channel meta tuning", ...
    numel(relativePositions)); ...
    string(formula) + " | " + string(scope)], ...
    'FontName', 'Arial', 'FontSize', 16, 'FontWeight', 'bold')
end


function plotComparisonPanel(ax, x, y, summary, panelTitle)
hold(ax, 'on')
valid = isfinite(x) & isfinite(y);
values = [x(valid); y(valid)];
lower = min([values; 0]);
upper = max([values; 0]);
span = max(upper - lower, 0.2);
limits = [lower - 0.08 * span, upper + 0.08 * span];
plot(ax, limits, limits, '--', 'Color', [0.45 0.45 0.45], ...
    'LineWidth', 1.2, 'HandleVisibility', 'off')
colors = [0.18 0.49 0.72; 0.85 0.33 0.10; 0.47 0.67 0.19; 0.49 0.18 0.56];
for row = 1:height(summary)
    marker = populationMarker(summary.Area(row), summary.UnitType(row));
    colorIndex = populationColorIndex(summary.Area(row), summary.UnitType(row));
    scatter(ax, x(row), y(row), 90, colors(colorIndex, :), marker, ...
        'filled', 'MarkerEdgeColor', [0.15 0.15 0.15], 'LineWidth', 0.8)
    text(ax, x(row), y(row), "  " + summary.Area(row) + " " + ...
        summary.UnitType(row), 'FontName', 'Arial', 'FontSize', 9, ...
        'VerticalAlignment', 'middle')
end
xlabel(ax, 'Stimulation-only baseline R^2', 'FontName', 'Arial')
ylabel(ax, 'Optimized meta-tuning R^2', 'FontName', 'Arial')
title(ax, panelTitle, 'FontName', 'Arial', 'FontWeight', 'bold')
subtitle(ax, 'Above diagonal favors learned neighboring-channel weights', ...
    'FontName', 'Arial')
xlim(ax, limits)
ylim(ax, limits)
axis(ax, 'square')
grid(ax, 'on')
box(ax, 'on')
set(ax, 'FontName', 'Arial', 'FontSize', 11, 'LineWidth', 1)
end


function fig = plotWeightFigure(groups, variant, analysis, visible)
groupCount = numel(groups);
if groupCount <= 2
    rows = 1;
    columns = groupCount;
    position = [80 80 750 * groupCount 700];
else
    rows = 2;
    columns = 2;
    position = [80 40 1450 940];
end
fig = figure('Color', 'w', 'Visible', visible, 'Position', position, ...
    'Name', sprintf('Weighted meta tuning weights %s %s', variant, analysis));
layout = tiledlayout(fig, rows, columns, 'TileSpacing', 'loose', ...
    'Padding', 'loose');
relativePositions = groups(1).RelativePositions;
colors = lines(numel(relativePositions));
for groupIndex = 1:groupCount
    group = groups(groupIndex);
    ax = nexttile(layout);
    plotWeightViolins(ax, group.CV.WeightSamples, ...
        group.FullExpandedWeights, relativePositions, colors)
    title(ax, group.Area + " " + group.UnitType, ...
        'FontName', 'Arial', 'FontWeight', 'bold')
    subtitle(ax, sprintf('n = %d; mean \\DeltaCV R^2 = %.3f', ...
        group.NSessions, group.MeanDeltaMacroCVR2), ...
        'FontName', 'Arial')
    ylim(ax, [-0.03 1.03])
    ylabel(ax, 'Channel weight', 'FontName', 'Arial')
    grid(ax, 'on')
    box(ax, 'on')
    set(ax, 'FontName', 'Arial', 'FontSize', 11, 'LineWidth', 1)
end
if variant == "AIxOD"
    variantLabel = 'AI + AI:|OD|';
else
    variantLabel = 'AI only';
end
title(layout, sprintf('Learned fold-wise meta-tuning weights | %s | %s', ...
    variantLabel, analysis), 'FontName', 'Arial', 'FontSize', 16, ...
    'FontWeight', 'bold')
xlabel(layout, ['Physical contact relative to stimulation channel ' ...
    '(violin = outer-training folds; diamond = full fit)'], ...
    'FontName', 'Arial')
end


function plotWeightViolins(ax, samples, fullWeights, ...
    relativePositions, colors)
hold(ax, 'on')
positionCount = numel(relativePositions);
for position = 1:positionCount
    values = samples(:, position);
    values = values(isfinite(values));
    values = max(0, min(1, values));
    if numel(unique(values)) >= 3
        [density, support] = ksdensity(values, ...
            'Support', [-1e-6 1 + 1e-6], ...
            'NumPoints', 120, 'BoundaryCorrection', 'reflection');
        density = 0.34 .* density ./ max(density);
        patch(ax, [position - density, fliplr(position + density)], ...
            [support, fliplr(support)], colors(position, :), ...
            'FaceAlpha', 0.35, 'EdgeColor', colors(position, :), ...
            'LineWidth', 0.9)
    end
    quantiles = prctile(values, [2.5 25 50 75 97.5]);
    plot(ax, [position position], quantiles([1 5]), '-', ...
        'Color', [0.2 0.2 0.2], 'LineWidth', 1)
    plot(ax, [position position], quantiles([2 4]), '-', ...
        'Color', [0.1 0.1 0.1], 'LineWidth', 4)
    plot(ax, position, quantiles(3), 'o', 'MarkerFaceColor', 'w', ...
        'MarkerEdgeColor', [0.1 0.1 0.1], 'MarkerSize', 5)
    plot(ax, position, fullWeights(position), 'd', ...
        'MarkerFaceColor', colors(position, :), ...
        'MarkerEdgeColor', [0.05 0.05 0.05], 'MarkerSize', 8)
end
xticks(ax, 1:positionCount)
xticklabels(ax, channelLabels(relativePositions))
xlim(ax, [0.45 positionCount + 0.55])
end


function labels = channelLabels(relativePositions)
labels = strings(size(relativePositions));
for index = 1:numel(relativePositions)
    position = relativePositions(index);
    if position < 0
        labels(index) = "CH" + position;
    elseif position > 0
        labels(index) = "CH+" + position;
    else
        labels(index) = "STIM";
    end
end
end


function marker = populationMarker(area, unitType)
if area == "MT" && unitType == "2D"
    marker = 'o';
elseif area == "MT"
    marker = '^';
elseif unitType == "2D"
    marker = 's';
else
    marker = 'd';
end
end


function index = populationColorIndex(area, unitType)
if area == "MT" && unitType == "2D"
    index = 1;
elseif area == "MT"
    index = 2;
elseif unitType == "2D"
    index = 3;
else
    index = 4;
end
end


function files = exportFigureSet(fig, outputFolder, stem)
pngFile = fullfile(outputFolder, [char(stem), '.png']);
pdfFile = fullfile(outputFolder, [char(stem), '.pdf']);
figFile = fullfile(outputFolder, [char(stem), '.fig']);
drawnow
pause(0.15)
exportgraphics(fig, pngFile, 'Resolution', 300)
exportgraphics(fig, pdfFile, 'ContentType', 'vector')
savefig(fig, figFile)
files = string({pngFile; pdfFile; figFile});
end

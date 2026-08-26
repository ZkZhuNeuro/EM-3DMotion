function result = AnalyzeBestQuickPopulationOutliers(options)
%ANALYZEBESTQUICKPOPULATIONOUTLIERS Find sessions flattening AI-bias effects.
%
% Influence is evaluated on the merged Dominant + NonDominant population
% relationship separately for selected-channel 2D and 3D units. A session
% is a flattening outlier when it is influential by grouped Cook distance
% or standardized residual and its removal recovers the population
% weighted-slope magnitude by at least 0.01 or 5% of the full slope.

arguments
    options.PopulationResultFile (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\BestQuickChannelPopulation\SSE\PopulationAnalysisResults.mat"
    options.PreparedInputFile (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\BestQuickChannelPopulation\SSE\unit_table_gof_best_quick_channel.mat"
    options.OutputFolder (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\BestQuickChannelPopulation\OutlierAnalysis_SelectedChannelCriteria"
    options.TopCountPerUnitType (1, 1) double ...
        {mustBeInteger, mustBePositive} = 5
    options.CookThresholdMultiplier (1, 1) double ...
        {mustBePositive} = 4
    options.StandardizedResidualThreshold (1, 1) double ...
        {mustBePositive} = 2.5
    options.MinimumAbsoluteSlopeRecovery (1, 1) double ...
        {mustBeNonnegative} = 0.01
    options.MinimumRelativeSlopeRecovery (1, 1) double ...
        {mustBeNonnegative} = 0.05
    options.FigureVisible (1, 1) logical = false
end

if ~isfile(options.PopulationResultFile) || ...
        ~isfile(options.PreparedInputFile)
    error('BestQuickOutliers:MissingInput', ...
        'Population result or prepared input file is missing.');
end
if ~isfolder(options.OutputFolder)
    mkdir(options.OutputFolder);
end

populationLoaded = load(options.PopulationResultFile, 'population_results');
if ~isfield(populationLoaded, 'population_results')
    error('BestQuickOutliers:MissingPopulationResults', ...
        'Population result MAT lacks population_results.');
end
population = populationLoaded.population_results;
if ~isfield(population, 'bias_table') || ~istable(population.bias_table)
    error('BestQuickOutliers:MissingBiasTable', ...
        'population_results lacks bias_table.');
end

projectFolder = string(fileparts(fileparts(mfilename('fullpath'))));
populationFolder = fullfile(projectFolder, 'PopulationAnalysis');
addpath(populationFolder);
[unitTable, ~, workbookAudit] = ...
    LoadLatestUnitTableGof(options.PreparedInputFile);
[deltaBias, biasNoStim, biasStim, validBias] = ...
    CalculateSigmoidFitBiases(unitTable, 4);

biasTable = population.bias_table;
validateUnitIndices(biasTable.UnitIndex, height(unitTable));
biasTable.Date = normalizeDateColumn(unitTable.Date(biasTable.UnitIndex));
biasTable.BestQuickChannel = ...
    unitTable.best_quick_channel(biasTable.UnitIndex);

unitTypes = ["2D", "3D"];
tables = cell(numel(unitTypes), 1);
modelSummary = cell(numel(unitTypes), 1);
for index = 1:numel(unitTypes)
    [tables{index}, modelSummary{index}] = analyzeUnitType( ...
        biasTable, unitTable, unitTypes(index), options);
end
influenceTable = vertcat(tables{:});
modelSummaryTable = vertcat(modelSummary{:});
influenceTable = sortrows(influenceTable, ...
    {'IsFlatteningOutlier', 'FlatteningScore'}, {'descend', 'descend'});
modelSummaryTable = addCleanRefitSummary( ...
    modelSummaryTable, biasTable, influenceTable);

plotCandidate = false(height(influenceTable), 1);
for index = 1:numel(unitTypes)
    rows = find(influenceTable.UnitType == unitTypes(index) & ...
        influenceTable.FlatteningScore > 0);
    rows = rows(1:min(options.TopCountPerUnitType, numel(rows)));
    plotCandidate(rows) = true;
end
plotCandidate = plotCandidate | influenceTable.IsFlatteningOutlier;
influenceTable.PlotCandidate = plotCandidate;

% Persist the numerical influence results before rendering diagnostics so
% they remain available even if an individual legacy plotting record is
% incomplete.
writetable(influenceTable, fullfile(options.OutputFolder, ...
    'SessionInfluence_All.csv'));
writetable(influenceTable(influenceTable.IsFlatteningOutlier, :), ...
    fullfile(options.OutputFolder, 'FlatteningOutlierSessions.csv'));
writetable(modelSummaryTable, fullfile(options.OutputFolder, ...
    'InfluenceModelSummary.csv'));

summaryFigure = makeInfluenceFigure( ...
    biasTable, influenceTable, options.FigureVisible);
summaryPNG = fullfile(options.OutputFolder, ...
    'PopulationInfluence_SelectedChannelCriteria.png');
summaryFIG = fullfile(options.OutputFolder, ...
    'PopulationInfluence_SelectedChannelCriteria.fig');
exportgraphics(summaryFigure, summaryPNG, 'Resolution', 220);
savefig(summaryFigure, summaryFIG);
close(summaryFigure);

candidateRows = find(influenceTable.PlotCandidate);
diagnosticRows = cell(numel(candidateRows), 1);
for index = 1:numel(candidateRows)
    influenceRow = influenceTable(candidateRows(index), :);
    unitRow = influenceRow.UnitIndex;
    figureHandle = makeSessionDiagnostic( ...
        unitTable, unitRow, influenceRow, deltaBias, biasNoStim, ...
        biasStim, validBias, options.FigureVisible);
    baseName = sprintf('%02d_%s_%s_%s_ch%02d', index, ...
        char(influenceRow.UnitType), char(influenceRow.Monkey), ...
        char(string(influenceRow.Date, 'yyyyMMdd')), ...
        influenceRow.BestQuickChannel);
    pngFile = fullfile(options.OutputFolder, baseName + ".png");
    figFile = fullfile(options.OutputFolder, baseName + ".fig");
    exportgraphics(figureHandle, pngFile, 'Resolution', 220);
    savefig(figureHandle, figFile);
    close(figureHandle);
    diagnosticRows{index} = table(index, influenceRow.UnitIndex, ...
        influenceRow.Monkey, influenceRow.Date, influenceRow.UnitType, ...
        influenceRow.BestQuickChannel, influenceRow.IsFlatteningOutlier, ...
        influenceRow.FlatteningScore, string(pngFile), string(figFile), ...
        'VariableNames', {'PlotRank', 'UnitIndex', 'Monkey', 'Date', ...
        'UnitType', 'BestQuickChannel', 'IsFlatteningOutlier', ...
        'FlatteningScore', 'PNGFile', 'FIGFile'});
end
if isempty(diagnosticRows)
    diagnosticManifest = table();
else
    diagnosticManifest = vertcat(diagnosticRows{:});
end

writetable(diagnosticManifest, fullfile(options.OutputFolder, ...
    'TuningBehaviorDiagnosticManifest.csv'));

result = struct();
result.PopulationResultFile = options.PopulationResultFile;
result.PreparedInputFile = options.PreparedInputFile;
result.OutputFolder = options.OutputFolder;
result.Options = options;
result.InfluenceTable = influenceTable;
result.FlatteningOutliers = ...
    influenceTable(influenceTable.IsFlatteningOutlier, :);
result.ModelSummary = modelSummaryTable;
result.DiagnosticManifest = diagnosticManifest;
result.WorkbookAudit = workbookAudit;
result.SummaryPNG = summaryPNG;
result.SummaryFIG = summaryFIG;
save(fullfile(options.OutputFolder, 'BestQuickOutlierAnalysis.mat'), ...
    'result', '-v7.3');

fprintf('Flagged %d flattening outlier session(s); plotted %d candidates.\n', ...
    height(result.FlatteningOutliers), height(diagnosticManifest));
end


function [influence, summary] = analyzeUnitType( ...
    biasTable, unitTable, unitType, options)
points = biasTable(string(biasTable.UnitType) == unitType & ...
    ismember(biasTable.Condition, [1 4]) & ...
    isfinite(biasTable.AI) & isfinite(biasTable.MergedEyeBias) & ...
    isfinite(biasTable.OD), :);
units = unique(points.UnitIndex);
if height(points) < 5 || numel(units) < 3
    error('BestQuickOutliers:InsufficientPoints', ...
        'Insufficient %s points for influence analysis.', unitType);
end

model = fitlm(points, 'MergedEyeBias ~ AI + AI:OD');
cook = model.Diagnostics.CooksDistance;
standardizedResidual = model.Residuals.Standardized;
[fullSlope, fullIntercept] = weightedLine( ...
    points.AI, points.MergedEyeBias, points.OD);
fullInteraction = coefficientValue(model, 'AI:OD', 'Estimate');
fullInteractionP = coefficientValue(model, 'AI:OD', 'pValue');
fullR2 = model.Rsquared.Ordinary;

rowCount = numel(units);
UnitIndex = units;
Monkey = strings(rowCount, 1);
Date = NaT(rowCount, 1);
UnitType = repmat(unitType, rowCount, 1);
BestQuickChannel = nan(rowCount, 1);
NPoints = zeros(rowCount, 1);
CookSum = nan(rowCount, 1);
MaxAbsStandardizedResidual = nan(rowCount, 1);
LeaveOneOutWeightedSlope = nan(rowCount, 1);
LeaveOneOutInteraction = nan(rowCount, 1);
LeaveOneOutInteractionP = nan(rowCount, 1);
LeaveOneOutR2 = nan(rowCount, 1);

for index = 1:rowCount
    unit = units(index);
    unitPoints = points.UnitIndex == unit;
    remaining = points(~unitPoints, :);
    Monkey(index) = getRowText(unitTable.Monkey, unit);
    Date(index) = normalizeDateColumn(unitTable.Date(unit));
    BestQuickChannel(index) = unitTable.best_quick_channel(unit);
    NPoints(index) = nnz(unitPoints);
    CookSum(index) = sum(cook(unitPoints), 'omitnan');
    MaxAbsStandardizedResidual(index) = ...
        max(abs(standardizedResidual(unitPoints)), [], 'omitnan');
    [LeaveOneOutWeightedSlope(index), ~] = weightedLine( ...
        remaining.AI, remaining.MergedEyeBias, remaining.OD);
    leaveOneOutModel = fitlm(remaining, 'MergedEyeBias ~ AI + AI:OD');
    LeaveOneOutInteraction(index) = coefficientValue( ...
        leaveOneOutModel, 'AI:OD', 'Estimate');
    LeaveOneOutInteractionP(index) = coefficientValue( ...
        leaveOneOutModel, 'AI:OD', 'pValue');
    LeaveOneOutR2(index) = leaveOneOutModel.Rsquared.Ordinary;
end

if abs(fullSlope) > 0.05
    FlatteningScore = sign(fullSlope) .* ...
        (LeaveOneOutWeightedSlope - fullSlope);
else
    FlatteningScore = abs(LeaveOneOutWeightedSlope) - abs(fullSlope);
end
InteractionMagnitudeIncrease = ...
    abs(LeaveOneOutInteraction) - abs(fullInteraction);
R2Increase = LeaveOneOutR2 - fullR2;
InteractionPDecrease = fullInteractionP - LeaveOneOutInteractionP;
CookThreshold = repmat(options.CookThresholdMultiplier ./ ...
    height(points), rowCount, 1);
IsInfluential = CookSum > CookThreshold | ...
    MaxAbsStandardizedResidual > options.StandardizedResidualThreshold;
RequiredSlopeRecovery = repmat(max( ...
    options.MinimumAbsoluteSlopeRecovery, ...
    options.MinimumRelativeSlopeRecovery .* abs(fullSlope)), rowCount, 1);
IsMeaningfulFlattening = FlatteningScore >= RequiredSlopeRecovery;
IsFlatteningOutlier = IsInfluential & IsMeaningfulFlattening;

influence = table(UnitIndex, Monkey, Date, UnitType, BestQuickChannel, ...
    NPoints, CookSum, CookThreshold, MaxAbsStandardizedResidual, ...
    repmat(fullSlope, rowCount, 1), LeaveOneOutWeightedSlope, ...
    FlatteningScore, RequiredSlopeRecovery, IsMeaningfulFlattening, ...
    repmat(fullInteraction, rowCount, 1), ...
    LeaveOneOutInteraction, InteractionMagnitudeIncrease, ...
    repmat(fullInteractionP, rowCount, 1), ...
    LeaveOneOutInteractionP, InteractionPDecrease, ...
    repmat(fullR2, rowCount, 1), LeaveOneOutR2, R2Increase, ...
    IsInfluential, IsFlatteningOutlier, ...
    'VariableNames', {'UnitIndex', 'Monkey', 'Date', 'UnitType', ...
    'BestQuickChannel', 'NPoints', 'CookSum', 'CookThreshold', ...
    'MaxAbsStandardizedResidual', 'FullWeightedSlope', ...
    'LeaveOneOutWeightedSlope', 'FlatteningScore', ...
    'RequiredSlopeRecovery', 'IsMeaningfulFlattening', ...
    'FullAIxOD', 'LeaveOneOutAIxOD', 'AIxODMagnitudeIncrease', ...
    'FullAIxODP', 'LeaveOneOutAIxODP', 'AIxODPDecrease', ...
    'FullR2', 'LeaveOneOutR2', 'R2Increase', ...
    'IsInfluential', 'IsFlatteningOutlier'});

summary = table(unitType, height(points), numel(units), fullSlope, ...
    fullIntercept, fullInteraction, fullInteractionP, fullR2, ...
    nnz(IsInfluential), nnz(IsFlatteningOutlier), ...
    'VariableNames', {'UnitType', 'NPoints', 'NUnits', ...
    'FullWeightedSlope', 'FullWeightedIntercept', 'FullAIxOD', ...
    'FullAIxODP', 'FullR2', 'NInfluential', 'NFlatteningOutliers'});
end


function figureHandle = makeInfluenceFigure(biasTable, influence, visible)
figureHandle = figure('Color', 'w', 'Visible', visible, ...
    'Name', 'Selected-channel population influence');
layout = tiledlayout(figureHandle, 1, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
unitTypes = ["2D", "3D"];
for typeIndex = 1:2
    axesHandle = nexttile(layout);
    hold(axesHandle, 'on');
    points = biasTable(string(biasTable.UnitType) == unitTypes(typeIndex) & ...
        ismember(biasTable.Condition, [1 4]) & ...
        isfinite(biasTable.AI) & isfinite(biasTable.MergedEyeBias) & ...
        isfinite(biasTable.OD), :);
    flaggedUnits = influence.UnitIndex(influence.UnitType == ...
        unitTypes(typeIndex) & influence.IsFlatteningOutlier);
    flagged = ismember(points.UnitIndex, flaggedUnits);
    scatter(axesHandle, points.AI(~flagged), points.MergedEyeBias(~flagged), ...
        28, [0.45 0.45 0.45], 'filled', 'MarkerFaceAlpha', 0.45);
    scatter(axesHandle, points.AI(flagged), points.MergedEyeBias(flagged), ...
        58, [0.85 0.10 0.10], 'filled', 'MarkerEdgeColor', 'k');
    xGrid = linspace(-1, 1, 101)';
    [fullSlope, fullIntercept] = weightedLine( ...
        points.AI, points.MergedEyeBias, points.OD);
    plot(axesHandle, xGrid, fullIntercept + fullSlope .* xGrid, ...
        'k-', 'LineWidth', 2);
    clean = ~flagged;
    [cleanSlope, cleanIntercept] = weightedLine( ...
        points.AI(clean), points.MergedEyeBias(clean), points.OD(clean));
    plot(axesHandle, xGrid, cleanIntercept + cleanSlope .* xGrid, ...
        'r--', 'LineWidth', 2);
    xline(axesHandle, 0, 'k:');
    yline(axesHandle, 0, 'k:');
    xlim(axesHandle, [-1 1]);
    xlabel(axesHandle, 'Selected-channel Quick AI');
    ylabel(axesHandle, 'Merged-eye Delta Bias');
    title(axesHandle, sprintf('%s | flagged %d | slope %.3f -> %.3f', ...
        unitTypes(typeIndex), numel(flaggedUnits), fullSlope, cleanSlope));
    legend(axesHandle, {'Other sessions', 'Flattening outliers', ...
        'Full fit', 'Fit without flagged'}, 'Location', 'best');
    box(axesHandle, 'on');
end
title(layout, 'Sessions flattening the selected-channel population effect');
end


function figureHandle = makeSessionDiagnostic(unitTable, row, influenceRow, ...
    deltaBias, biasNoStim, biasStim, validBias, visible)
colors = [0 0 0; 254 191 15; 110 205 221; 234 0 233] ./ 255;
cueNames = ["Combined", "MonoL", "MonoR", "Stereo"];
channel = unitTable.best_quick_channel(row);
[coherence, meanTuning, semTuning, tuningZ, tuningSource] = ...
    getSelectedChannelQuickTuning(unitTable, row, channel);

figureHandle = figure('Color', 'w', 'Visible', visible, ...
    'Name', sprintf('%s %s best channel %d', ...
    getRowText(unitTable.Monkey, row), ...
    string(normalizeDateColumn(unitTable.Date(row)), 'yyyyMMdd'), channel), ...
    'Position', [100 100 1300 760]);
layout = tiledlayout(figureHandle, 2, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');

axesHandle = nexttile(layout, 1);
hold(axesHandle, 'on');
for cue = 1:4
    errorbar(axesHandle, coherence, ...
        reshape(meanTuning(cue, :), 1, []), ...
        reshape(semTuning(cue, :), 1, []), '-o', ...
        'Color', colors(cue, :), 'LineWidth', 1.4, ...
        'MarkerFaceColor', colors(cue, :));
end
xline(axesHandle, 0, 'k:');
xlabel(axesHandle, '3D Quick coherence');
ylabel(axesHandle, 'Firing rate (Hz)');
title(axesHandle, sprintf('Best Quick channel %d tuning (%s)', ...
    channel, tuningSource));
legend(axesHandle, cueNames, 'Location', 'best');
box(axesHandle, 'on');

axesHandle = nexttile(layout, 2);
imagesc(axesHandle, coherence, 1:4, tuningZ);
colormap(axesHandle, parula);
colorbar(axesHandle);
xlabel(axesHandle, '3D Quick coherence');
yticks(axesHandle, 1:4);
yticklabels(axesHandle, cueNames);
title(axesHandle, 'Cue-wise Quick z tuning');

axesHandle = nexttile(layout, 3);
hold(axesHandle, 'on');
x = 1:4;
for cue = 1:4
    if validBias(row, cue)
        plot(axesHandle, [cue-0.12 cue+0.12], ...
            [biasNoStim(row, cue) biasStim(row, cue)], '-', ...
            'Color', colors(cue, :), 'LineWidth', 1.5);
        scatter(axesHandle, cue-0.12, biasNoStim(row, cue), 55, ...
            colors(cue, :), 'o', 'filled');
        scatter(axesHandle, cue+0.12, biasStim(row, cue), 55, ...
            colors(cue, :), 's', 'filled');
    end
end
yline(axesHandle, 0, 'k:');
xlim(axesHandle, [0.5 4.5]);
xticks(axesHandle, x);
xticklabels(axesHandle, cueNames);
ylabel(axesHandle, 'Behavioral PSE bias');
title(axesHandle, 'NoStim circles and Stim squares');
box(axesHandle, 'on');

axesHandle = nexttile(layout, 4);
bar(axesHandle, x, deltaBias(row, :), 'FaceColor', 'flat');
axesHandle.Children.CData = colors;
yline(axesHandle, 0, 'k:');
xlim(axesHandle, [0.5 4.5]);
xticks(axesHandle, x);
xticklabels(axesHandle, cueNames);
ylabel(axesHandle, 'Delta Bias (NoStim - Stim)');
title(axesHandle, sprintf( ...
    'Cook sum %.3g | std resid %.2f | flattening %.3g', ...
    influenceRow.CookSum, influenceRow.MaxAbsStandardizedResidual, ...
    influenceRow.FlatteningScore));
box(axesHandle, 'on');

pValues = unitTable.best_quick_p_AI{row};
aiValues = unitTable.best_quick_AI{row};
if ismember('best_quick_OD_magnitude', ...
        unitTable.Properties.VariableNames)
    odMagnitude = unitTable.best_quick_OD_magnitude(row);
else
    odMagnitude = abs(unitTable.best_quick_OD_max(row));
end
title(layout, sprintf([ ...
    '%s %s | %s | ch %d | pL %.3g pR %.3g | Z3D-Z2D %.3f | ' ...
    'AI [%s] | |OD| %.3f'], getRowText(unitTable.Monkey, row), ...
    string(normalizeDateColumn(unitTable.Date(row)), 'yyyy-MM-dd'), ...
    influenceRow.UnitType, channel, pValues(2), pValues(3), ...
    unitTable.best_quick_Z3D_v_Z2D(row), num2str(aiValues(:)', ' %.2f'), ...
    odMagnitude), 'Interpreter', 'none');
end


function [coherence, meanTuning, semTuning, tuningZ, sourceLabel] = ...
    getSelectedChannelQuickTuning(unitTable, row, channel)
sourceLabel = "selection cache";
sourceFile = "";
if ismember('best_quick_selection_cache_file', ...
        unitTable.Properties.VariableNames)
    sourceFile = string(unitTable.best_quick_selection_cache_file(row));
end
if strlength(sourceFile) == 0 || ~isfile(sourceFile)
    monkey = getRowText(unitTable.Monkey, row);
    sessionDate = normalizeDateColumn(unitTable.Date(row));
    sourceFile = fullfile("C:\" + monkey, "StimData", ...
        string(sessionDate, 'yyyyMMdd') + ".mat");
end

if strlength(sourceFile) > 0 && isfile(sourceFile)
    loaded = load(sourceFile, 'Neuro');
    if isfield(loaded, 'Neuro') && ...
            channel <= size(loaded.Neuro.Means, 3)
        meanTuning = double(loaded.Neuro.Means(:, :, channel));
        if isfield(loaded.Neuro, 'SEM') && ...
                size(loaded.Neuro.SEM, 1) == 4 && ...
                size(loaded.Neuro.SEM, 2) == size(meanTuning, 2) && ...
                channel <= size(loaded.Neuro.SEM, 3)
            semTuning = double(loaded.Neuro.SEM(:, :, channel));
        else
            semTuning = nan(size(meanTuning));
        end
        if isfield(loaded.Neuro, 'CoherenceArray') && ...
                numel(loaded.Neuro.CoherenceArray) == size(meanTuning, 2)
            coherence = double(loaded.Neuro.CoherenceArray(:)');
        else
            coherence = inferQuickCoherence(size(meanTuning, 2));
        end
        tuningZ = rowwiseZScore(meanTuning);
        return
    end
end

sourceLabel = "prepared table";
allMean = unitTable.tuning_mean{row};
meanTuning = double(allMean(:, :, channel));
coherence = inferQuickCoherence(size(meanTuning, 2));
allSEM = unitTable.tuning_SEM{row};
if size(allSEM, 2) == size(meanTuning, 2) && ...
        channel <= size(allSEM, 3)
    semTuning = double(allSEM(:, :, channel));
else
    semTuning = nan(size(meanTuning));
end
tuningZ = rowwiseZScore(meanTuning);
end


function valuesZ = rowwiseZScore(values)
valuesZ = nan(size(values));
for row = 1:size(values, 1)
    finite = isfinite(values(row, :));
    if sum(finite) < 2
        continue
    end
    rowMean = mean(values(row, finite));
    rowSD = std(values(row, finite));
    if rowSD > 0
        valuesZ(row, finite) = ...
            (values(row, finite) - rowMean) ./ rowSD;
    else
        valuesZ(row, finite) = 0;
    end
end
end


function summary = addCleanRefitSummary(summary, biasTable, influence)
rowCount = height(summary);
NExcludedOutliers = zeros(rowCount, 1);
CleanNPoints = zeros(rowCount, 1);
CleanNUnits = zeros(rowCount, 1);
CleanWeightedSlope = nan(rowCount, 1);
CleanAIxOD = nan(rowCount, 1);
CleanAIxODP = nan(rowCount, 1);
CleanR2 = nan(rowCount, 1);
for index = 1:rowCount
    unitType = summary.UnitType(index);
    excluded = influence.UnitIndex( ...
        influence.UnitType == unitType & ...
        influence.IsFlatteningOutlier);
    points = biasTable(string(biasTable.UnitType) == unitType & ...
        ismember(biasTable.Condition, [1 4]) & ...
        isfinite(biasTable.AI) & isfinite(biasTable.MergedEyeBias) & ...
        isfinite(biasTable.OD) & ...
        ~ismember(biasTable.UnitIndex, excluded), :);
    NExcludedOutliers(index) = numel(excluded);
    CleanNPoints(index) = height(points);
    CleanNUnits(index) = numel(unique(points.UnitIndex));
    [CleanWeightedSlope(index), ~] = weightedLine( ...
        points.AI, points.MergedEyeBias, points.OD);
    model = fitlm(points, 'MergedEyeBias ~ AI + AI:OD');
    CleanAIxOD(index) = coefficientValue(model, 'AI:OD', 'Estimate');
    CleanAIxODP(index) = coefficientValue(model, 'AI:OD', 'pValue');
    CleanR2(index) = model.Rsquared.Ordinary;
end
summary.NExcludedOutliers = NExcludedOutliers;
summary.CleanNPoints = CleanNPoints;
summary.CleanNUnits = CleanNUnits;
summary.CleanWeightedSlope = CleanWeightedSlope;
summary.CleanAIxOD = CleanAIxOD;
summary.CleanAIxODP = CleanAIxODP;
summary.CleanR2 = CleanR2;
end


function [slope, intercept] = weightedLine(x, y, weight)
valid = isfinite(x) & isfinite(y) & isfinite(weight) & weight > 0;
if nnz(valid) < 2
    slope = NaN;
    intercept = NaN;
    return
end
design = [ones(nnz(valid), 1), x(valid)];
rootWeight = sqrt(weight(valid));
coefficients = (design .* rootWeight) \ (y(valid) .* rootWeight);
intercept = coefficients(1);
slope = coefficients(2);
end


function value = coefficientValue(model, name, column)
row = strcmp(model.CoefficientNames, name);
if ~any(row)
    value = NaN;
else
    value = model.Coefficients{row, column};
end
end


function validateUnitIndices(indices, rowCount)
if any(~isfinite(indices) | indices ~= fix(indices) | ...
        indices < 1 | indices > rowCount)
    error('BestQuickOutliers:InvalidUnitIndices', ...
        'Population UnitIndex values do not map to the prepared table.');
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
        error('BestQuickOutliers:UnknownCoherenceGrid', ...
            'Expected 8, 12, or 13 Quick coherence values; found %d.', count);
end
coherence = numerator ./ 22;
end


function value = getRowText(column, row)
if iscell(column)
    value = string(column{row});
else
    value = string(column(row));
end
end


function dates = normalizeDateColumn(values)
if isdatetime(values)
    dates = dateshift(values(:), 'start', 'day');
elseif isnumeric(values)
    if all(isnan(values) | values > 1e7)
        dates = datetime(string(values(:)), 'InputFormat', 'yyyyMMdd');
    else
        dates = datetime(values(:), 'ConvertFrom', 'datenum');
    end
else
    dates = dateshift(datetime(string(values(:))), 'start', 'day');
end
end

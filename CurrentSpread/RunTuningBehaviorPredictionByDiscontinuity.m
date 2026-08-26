function analysis = RunTuningBehaviorPredictionByDiscontinuity(options)
%RUNTUNINGBEHAVIORPREDICTIONBYDISCONTINUITY Compare held-out prediction.
%
% Uses the low/high maximum-jump split produced by
% RunPopulationByAdjacentTuningDiscontinuity. The established 2D merged-eye
% AI + AI:OD model and 3D cue-specific AI models are evaluated with all
% observations from a session held out together. Repeated matched-size
% resampling compares the two groups fairly, and a monkey-stratified label
% permutation tests the difference in cross-validated R-squared.

arguments
    options.MedianSplitFile (1, 1) string = [ ...
        "C:\EM\StimTuningAnalysis\AdjacentFullTuningDiscontinuity\" + ...
        "PopulationMedianSplit\Population_MaxJumpMedianSplit.mat"]
    options.OutputFolder (1, 1) string = [ ...
        "C:\EM\StimTuningAnalysis\AdjacentFullTuningDiscontinuity\" + ...
        "BehaviorPredictionComparison"]
    options.NumCVRepeats (1, 1) double ...
        {mustBeInteger, mustBePositive} = 50
    options.NumFolds (1, 1) double ...
        {mustBeInteger, mustBeGreaterThan(options.NumFolds, 1)} = 5
    options.NumResamples (1, 1) double ...
        {mustBeInteger, mustBePositive} = 500
    options.NumPermutations (1, 1) double ...
        {mustBeInteger, mustBePositive} = 500
    options.MinimumSessions (1, 1) double ...
        {mustBeInteger, mustBeGreaterThanOrEqual( ...
        options.MinimumSessions, 5)} = 5
    options.RandomSeed (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 1
    options.FigureVisible (1, 1) logical = false
end

if ~isfile(options.MedianSplitFile)
    error('TuningBehaviorComparison:MissingMedianSplitFile', ...
        'Median-split MAT file does not exist: %s', ...
        options.MedianSplitFile);
end
ensureFolder(options.OutputFolder);
loaded = load(options.MedianSplitFile, ...
    'PopulationByTuningDiscontinuity');
if ~isfield(loaded, 'PopulationByTuningDiscontinuity') || ...
        ~isfield(loaded.PopulationByTuningDiscontinuity, ...
        'PopulationResults')
    error('TuningBehaviorComparison:InvalidMedianSplitFile', ...
        ['Median-split MAT file must contain ' ...
        'PopulationByTuningDiscontinuity.PopulationResults.']);
end
sourceAnalysis = loaded.PopulationByTuningDiscontinuity;

areas = ["MT", "FST"];
unitTypes = ["2D", "3D"];
summaryTable = table();
predictionTable = table();
comparisonResults = struct();
figureFiles = struct();
for areaIndex = 1:numel(areas)
    area = areas(areaIndex);
    areaResults = sourceAnalysis.PopulationResults.(char(area));
    lowBias = areaResults.BelowMedian.BiasTable;
    highBias = areaResults.AboveMedian.BiasTable;
    for typeIndex = 1:numel(unitTypes)
        unitType = unitTypes(typeIndex);
        analysisSeed = options.RandomSeed + ...
            100000 .* areaIndex + 10000 .* typeIndex;
        lowCV = CrossValidateTuningBehaviorModel(lowBias, unitType, ...
            NumRepeats=options.NumCVRepeats, ...
            NumFolds=options.NumFolds, RandomSeed=analysisSeed, ...
            MinimumSessions=options.MinimumSessions);
        highCV = CrossValidateTuningBehaviorModel(highBias, unitType, ...
            NumRepeats=options.NumCVRepeats, ...
            NumFolds=options.NumFolds, RandomSeed=analysisSeed + 1000, ...
            MinimumSessions=options.MinimumSessions);
        validComparison = lowCV.Status == "Success" && ...
            highCV.Status == "Success";

        if validComparison
            resampling = matchedSizeResampling(lowBias, highBias, ...
                unitType, options.NumResamples, options.NumFolds, ...
                options.MinimumSessions, analysisSeed + 2000);
            permutation = stratifiedPermutationTest( ...
                lowBias, highBias, unitType, options.NumPermutations, ...
                options.NumFolds, options.MinimumSessions, ...
                mean(resampling.DeltaR2, 'omitmissing'), ...
                analysisSeed + 3000);
            status = "Success";
        else
            resampling = emptyResampling();
            permutation = emptyPermutation();
            status = "InsufficientSessions";
        end

        thisSummary = buildSummary(area, unitType, status, ...
            lowCV, highCV, resampling, permutation);
        summaryTable = [summaryTable; thisSummary]; %#ok<AGROW>
        predictionTable = [predictionTable; ...
            predictionRows(area, unitType, "Below median", lowCV); ...
            predictionRows(area, unitType, "Above median", highCV)]; %#ok<AGROW>

        [figureHandle, thisFigureFiles] = saveComparisonFigure( ...
            area, unitType, lowCV, highCV, resampling, permutation, ...
            sourceAnalysis.MedianMaxAdjacentJumpSquared, ...
            options.OutputFolder, options.FigureVisible);
        closeValidFigure(figureHandle);
        field = unitTypeField(unitType);
        figureFiles.(char(area)).(char(field)) = thisFigureFiles;

        thisResult = struct();
        thisResult.Status = status;
        thisResult.LowCV = lowCV;
        thisResult.HighCV = highCV;
        thisResult.MatchedSizeResampling = resampling;
        thisResult.Permutation = permutation;
        comparisonResults.(char(area)).(char(field)) = thisResult;
    end
end

writetable(summaryTable, fullfile(options.OutputFolder, ...
    'TuningBehaviorPrediction_DiscontinuityGroupSummary.csv'));
writetable(predictionTable, fullfile(options.OutputFolder, ...
    'TuningBehaviorPrediction_HeldOutPredictions.csv'));

analysis = struct();
analysis.MedianSplitFile = options.MedianSplitFile;
analysis.OutputFolder = options.OutputFolder;
analysis.MedianMaxAdjacentJumpSquared = ...
    sourceAnalysis.MedianMaxAdjacentJumpSquared;
analysis.NumCVRepeats = options.NumCVRepeats;
analysis.NumFolds = options.NumFolds;
analysis.NumResamples = options.NumResamples;
analysis.NumPermutations = options.NumPermutations;
analysis.MinimumSessions = options.MinimumSessions;
analysis.RandomSeed = options.RandomSeed;
analysis.SummaryTable = summaryTable;
analysis.HeldOutPredictionTable = predictionTable;
analysis.ComparisonResults = comparisonResults;
analysis.FigureFiles = figureFiles;
analysis.ScoreDefinition = [ ...
    "Cross-validated R2 = 1 - held-out model SSE / held-out training-mean SSE"; ...
    "All observations from one session remain in the same fold"; ...
    "2D: MergedEyeBias ~ AI + AI:OD"; ...
    "3D: Bias ~ AI fitted separately for each of four cues"; ...
    "Positive DeltaR2 means below-median discontinuity predicts better"; ...
    "Matched-size resampling uses equal session counts without replacement"; ...
    "Permutation labels are shuffled within monkey"];
TuningBehaviorPredictionByDiscontinuity = analysis;
save(fullfile(options.OutputFolder, ...
    'TuningBehaviorPredictionByDiscontinuity.mat'), ...
    'TuningBehaviorPredictionByDiscontinuity', '-v7.3');

disp(summaryTable)
fprintf('Tuning-behavior prediction comparison saved to %s\n', ...
    options.OutputFolder);
end


function result = matchedSizeResampling(lowBias, highBias, unitType, ...
    repeatCount, foldCount, minimumSessions, seed)
lowSessions = unitTypeSessions(lowBias, unitType);
highSessions = unitTypeSessions(highBias, unitType);
matchedCount = min(numel(lowSessions), numel(highSessions));
result = emptyResampling();
result.MatchedSessionCount = matchedCount;
result.LowR2 = nan(repeatCount, 1);
result.HighR2 = nan(repeatCount, 1);
result.DeltaR2 = nan(repeatCount, 1);
stream = RandStream('mt19937ar', 'Seed', mod(seed, 2^32 - 1));
for repeat = 1:repeatCount
    lowSelected = randomSubset( ...
        lowSessions, matchedCount, stream);
    highSelected = randomSubset( ...
        highSessions, matchedCount, stream);
    lowTable = lowBias(ismember(lowBias.SourceTableRow, lowSelected), :);
    highTable = highBias(ismember(highBias.SourceTableRow, highSelected), :);
    cvSeed = randi(stream, 2^31 - 1);
    lowResult = CrossValidateTuningBehaviorModel(lowTable, unitType, ...
        NumRepeats=1, NumFolds=foldCount, RandomSeed=cvSeed, ...
        MinimumSessions=minimumSessions);
    highResult = CrossValidateTuningBehaviorModel(highTable, unitType, ...
        NumRepeats=1, NumFolds=foldCount, RandomSeed=cvSeed + 1, ...
        MinimumSessions=minimumSessions);
    result.LowR2(repeat) = lowResult.MeanR2;
    result.HighR2(repeat) = highResult.MeanR2;
    result.DeltaR2(repeat) = lowResult.MeanR2 - highResult.MeanR2;
end
finiteDelta = result.DeltaR2(isfinite(result.DeltaR2));
if ~isempty(finiteDelta)
    result.MeanLowR2 = mean(result.LowR2, 'omitmissing');
    result.MeanHighR2 = mean(result.HighR2, 'omitmissing');
    result.MeanDeltaR2 = mean(finiteDelta);
    result.DeltaCI95 = prctile(finiteDelta, [2.5 97.5]);
end
end


function result = stratifiedPermutationTest(lowBias, highBias, unitType, ...
    permutationCount, foldCount, minimumSessions, observedDelta, seed)
lowSessions = unitTypeSessions(lowBias, unitType);
highSessions = unitTypeSessions(highBias, unitType);
matchedCount = min(numel(lowSessions), numel(highSessions));
combined = [lowBias; highBias];
allSessions = [lowSessions; highSessions];
trueLow = ismember(allSessions, lowSessions);
sessionMonkey = strings(numel(allSessions), 1);
for index = 1:numel(allSessions)
    row = find(combined.SourceTableRow == allSessions(index), 1);
    sessionMonkey(index) = string(combined.Monkey(row));
end
result = emptyPermutation();
result.NullDeltaR2 = nan(permutationCount, 1);
stream = RandStream('mt19937ar', 'Seed', mod(seed, 2^32 - 1));
for permutation = 1:permutationCount
    permutedLow = false(size(trueLow));
    monkeyNames = unique(sessionMonkey, 'stable');
    for monkeyIndex = 1:numel(monkeyNames)
        member = find(sessionMonkey == monkeyNames(monkeyIndex));
        lowCount = nnz(trueLow(member));
        order = randperm(stream, numel(member));
        permutedLow(member(order(1:lowCount))) = true;
    end
    permLowSessions = allSessions(permutedLow);
    permHighSessions = allSessions(~permutedLow);
    selectedLow = randomSubset(permLowSessions, matchedCount, stream);
    selectedHigh = randomSubset(permHighSessions, matchedCount, stream);
    lowTable = combined(ismember(combined.SourceTableRow, selectedLow), :);
    highTable = combined(ismember(combined.SourceTableRow, selectedHigh), :);
    cvSeed = randi(stream, 2^31 - 1);
    lowResult = CrossValidateTuningBehaviorModel(lowTable, unitType, ...
        NumRepeats=1, NumFolds=foldCount, RandomSeed=cvSeed, ...
        MinimumSessions=minimumSessions);
    highResult = CrossValidateTuningBehaviorModel(highTable, unitType, ...
        NumRepeats=1, NumFolds=foldCount, RandomSeed=cvSeed + 1, ...
        MinimumSessions=minimumSessions);
    result.NullDeltaR2(permutation) = ...
        lowResult.MeanR2 - highResult.MeanR2;
end
finiteNull = result.NullDeltaR2(isfinite(result.NullDeltaR2));
result.ObservedDeltaR2 = observedDelta;
if ~isempty(finiteNull) && isfinite(observedDelta)
    result.TwoSidedP = (1 + nnz(abs(finiteNull) >= ...
        abs(observedDelta))) ./ (numel(finiteNull) + 1);
end
end


function sessions = unitTypeSessions(input, unitType)
selected = string(input.UnitType) == unitType & ...
    isfinite(input.AI) & isfinite(input.SourceTableRow);
if unitType == "2D"
    selected = selected & ismember(input.Condition, [1 4]) & ...
        isfinite(input.OD) & isfinite(input.MergedEyeBias);
else
    selected = selected & isfinite(input.Bias);
end
sessions = unique(input.SourceTableRow(selected), 'stable');
end


function selected = randomSubset(values, count, stream)
if count > numel(values)
    error('TuningBehaviorComparison:SubsetTooLarge', ...
        'Cannot select %d values from %d sessions.', count, numel(values));
end
order = randperm(stream, numel(values));
selected = values(order(1:count));
end


function output = buildSummary(area, unitType, status, lowCV, highCV, ...
    resampling, permutation)
model = lowCV.ModelName;
belowMedianSessions = lowCV.SessionCount;
aboveMedianSessions = highCV.SessionCount;
matchedSessions = resampling.MatchedSessionCount;
belowMedianCVR2 = lowCV.MeanR2;
aboveMedianCVR2 = highCV.MeanR2;
fullSampleDeltaR2 = belowMedianCVR2 - aboveMedianCVR2;
belowMedianCVRMSE = lowCV.MeanRMSE;
aboveMedianCVRMSE = highCV.MeanRMSE;
belowMedianPredictionR = lowCV.MeanPearsonR;
aboveMedianPredictionR = highCV.MeanPearsonR;
matchedMeanBelowR2 = resampling.MeanLowR2;
matchedMeanAboveR2 = resampling.MeanHighR2;
matchedMeanDeltaR2 = resampling.MeanDeltaR2;
deltaCI95Low = resampling.DeltaCI95(1);
deltaCI95High = resampling.DeltaCI95(2);
permutationP = permutation.TwoSidedP;
output = table(area, unitType, model, status, belowMedianSessions, ...
    aboveMedianSessions, matchedSessions, belowMedianCVR2, ...
    aboveMedianCVR2, fullSampleDeltaR2, belowMedianCVRMSE, ...
    aboveMedianCVRMSE, belowMedianPredictionR, ...
    aboveMedianPredictionR, matchedMeanBelowR2, matchedMeanAboveR2, ...
    matchedMeanDeltaR2, deltaCI95Low, deltaCI95High, permutationP, ...
    'VariableNames', {'Area', 'UnitType', 'Model', 'Status', ...
    'BelowMedianSessions', 'AboveMedianSessions', 'MatchedSessions', ...
    'BelowMedianCVR2', 'AboveMedianCVR2', 'FullSampleDeltaR2', ...
    'BelowMedianCVRMSE', 'AboveMedianCVRMSE', ...
    'BelowMedianPredictionR', 'AboveMedianPredictionR', ...
    'MatchedMeanBelowR2', 'MatchedMeanAboveR2', ...
    'MatchedMeanDeltaR2', 'DeltaCI95Low', 'DeltaCI95High', ...
    'PermutationP'});
end


function output = predictionRows(area, unitType, group, cv)
if isempty(cv.ObservationTable)
    output = table();
    return
end
input = cv.ObservationTable;
rowCount = height(input);
output = table(repmat(area, rowCount, 1), ...
    repmat(unitType, rowCount, 1), repmat(group, rowCount, 1), ...
    input.SourceTableRow, string(input.Monkey), input.Condition, ...
    input.AI, input.OD, cv.Observed, cv.MeanHeldOutPrediction, ...
    cv.MeanNullPrediction, ...
    'VariableNames', {'Area', 'UnitType', 'DiscontinuityGroup', ...
    'SourceTableRow', 'Monkey', 'Condition', 'AI', 'OD', ...
    'ObservedBehavior', 'MeanHeldOutPrediction', ...
    'MeanHeldOutNullPrediction'});
end


function [figureHandle, files] = saveComparisonFigure(area, unitType, ...
    lowCV, highCV, resampling, permutation, threshold, outputFolder, visible)
if visible
    visibility = 'on';
else
    visibility = 'off';
end
figureHandle = figure('Color', 'w', 'Visible', visibility, ...
    'Position', [100 100 1250 900], ...
    'Name', char("Behavior prediction " + area + " " + unitType));
if lowCV.Status ~= "Success" || highCV.Status ~= "Success"
    set(figureHandle, 'Position', [100 100 1050 360]);
    layout = tiledlayout(figureHandle, 1, 1, ...
        'TileSpacing', 'compact', 'Padding', 'compact');
    axesHandle = nexttile(layout);
    axis(axesHandle, 'off');
    text(axesHandle, 0.5, 0.5, ...
        sprintf(['Insufficient sessions for session-grouped CV\n' ...
        'Below median: N = %d | Above median: N = %d\n' ...
        'Minimum required: N = 5 per group'], ...
        lowCV.SessionCount, highCV.SessionCount), ...
        'HorizontalAlignment', 'center', 'FontSize', 14);
else
    layout = tiledlayout(figureHandle, 2, 2, ...
        'TileSpacing', 'compact', 'Padding', 'compact');
    scoreAxes = nexttile(layout);
    plotScoreDistributions(scoreAxes, resampling);
    deltaAxes = nexttile(layout);
    plotDeltaDistributions(deltaAxes, resampling, permutation);
    lowAxes = nexttile(layout);
    highAxes = nexttile(layout);
    limits = predictionLimits(lowCV, highCV);
    plotPredictionScatter(lowAxes, lowCV, "Below median", limits);
    plotPredictionScatter(highAxes, highCV, "Above median", limits);
end
title(layout, sprintf( ...
    '%s %s | behavior prediction from tuning | max-jump median %.4g', ...
    area, unitType, threshold), 'FontWeight', 'bold', 'FontSize', 14);
baseName = "TuningBehaviorPrediction_" + area + "_" + unitType;
files = struct();
files.PNG = fullfile(outputFolder, baseName + ".png");
files.PDF = fullfile(outputFolder, baseName + ".pdf");
files.FIG = fullfile(outputFolder, baseName + ".fig");
exportgraphics(figureHandle, files.PNG, 'Resolution', 300);
exportgraphics(figureHandle, files.PDF, 'ContentType', 'vector');
savefig(figureHandle, files.FIG);
end


function plotScoreDistributions(axesHandle, resampling)
values = [resampling.LowR2; resampling.HighR2];
groups = [repmat("Below median", numel(resampling.LowR2), 1); ...
    repmat("Above median", numel(resampling.HighR2), 1)];
valid = isfinite(values);
boxchart(axesHandle, categorical(groups(valid), ...
    ["Below median", "Above median"]), values(valid), ...
    'BoxFaceColor', [0.3 0.55 0.8]);
yline(axesHandle, 0, ':', 'No improvement');
ylabel(axesHandle, 'Matched-size CV R^2');
finiteValues = values(isfinite(values));
low = min(0, prctile(finiteValues, 2.5));
high = max(0, prctile(finiteValues, 97.5));
padding = 0.08 .* max(high - low, 0.25);
ylim(axesHandle, [low - padding, high + padding]);
title(axesHandle, sprintf( ...
    'Equal-N resampling (N = %d/group; central 95%% shown)', ...
    resampling.MatchedSessionCount));
grid(axesHandle, 'on');
end


function plotDeltaDistributions(axesHandle, resampling, permutation)
observed = resampling.DeltaR2(isfinite(resampling.DeltaR2));
nullValues = permutation.NullDeltaR2(isfinite(permutation.NullDeltaR2));
edges = robustCommonEdges([observed; nullValues]);
nullHistogram = histogram(axesHandle, nullValues, 'BinEdges', edges, ...
    'Normalization', 'probability', 'DisplayStyle', 'stairs', ...
    'EdgeColor', [0.35 0.35 0.35], 'LineWidth', 1.5);
hold(axesHandle, 'on');
observedHistogram = histogram(axesHandle, observed, 'BinEdges', edges, ...
    'Normalization', 'probability', 'FaceColor', [0.25 0.55 0.8], ...
    'FaceAlpha', 0.55, 'EdgeColor', 'none');
xline(axesHandle, 0, ':');
xline(axesHandle, resampling.MeanDeltaR2, '-', ...
    sprintf('Mean %.3g', resampling.MeanDeltaR2), 'LineWidth', 1.25);
xlabel(axesHandle, '\DeltaCV R^2 (below - above)');
ylabel(axesHandle, 'Probability');
title(axesHandle, sprintf('95%% interval [%.3g, %.3g], perm. p = %.3g', ...
    resampling.DeltaCI95(1), resampling.DeltaCI95(2), ...
    permutation.TwoSidedP));
legend(axesHandle, [nullHistogram, observedHistogram], ...
    {'Permuted labels', 'Observed groups'}, ...
    'Location', 'best');
grid(axesHandle, 'on');
end


function limits = predictionLimits(lowCV, highCV)
values = [lowCV.Observed; lowCV.MeanHeldOutPrediction; ...
    highCV.Observed; highCV.MeanHeldOutPrediction];
values = values(isfinite(values));
low = min([0; values]);
high = max([0; values]);
padding = 0.08 .* max(high - low, 1);
limits = [low - padding, high + padding];
end


function plotPredictionScatter(axesHandle, cv, group, limits)
colors = [254 191 15; 0 0 0; 234 0 233; 110 205 221] ./ 255;
hold(axesHandle, 'on');
plot(axesHandle, limits, limits, ':', 'Color', [0.3 0.3 0.3]);
input = cv.ObservationTable;
for condition = unique(input.Condition)'
    selected = input.Condition == condition & ...
        isfinite(cv.MeanHeldOutPrediction) & isfinite(cv.Observed);
    scatter(axesHandle, cv.MeanHeldOutPrediction(selected), ...
        cv.Observed(selected), 34, colors(condition, :), 'filled', ...
        'MarkerFaceAlpha', 0.65);
end
xlim(axesHandle, limits);
ylim(axesHandle, limits);
axis(axesHandle, 'square');
xlabel(axesHandle, 'Held-out predicted behavior');
ylabel(axesHandle, 'Observed behavior');
title(axesHandle, sprintf('%s: R^2 = %.3g, RMSE = %.3g, r = %.3g', ...
    group, cv.MeanR2, cv.MeanRMSE, cv.MeanPearsonR));
grid(axesHandle, 'on');
end


function edges = robustCommonEdges(values)
values = values(isfinite(values));
if isempty(values)
    edges = linspace(-1, 1, 21);
    return
end
low = prctile(values, 1);
high = prctile(values, 99);
low = min(low, 0);
high = max(high, 0);
if high <= low
    high = low + 1;
end
edges = linspace(low, high, 26);
end


function result = emptyResampling()
result = struct('MatchedSessionCount', NaN, 'LowR2', nan(0, 1), ...
    'HighR2', nan(0, 1), 'DeltaR2', nan(0, 1), ...
    'MeanLowR2', NaN, 'MeanHighR2', NaN, 'MeanDeltaR2', NaN, ...
    'DeltaCI95', [NaN NaN]);
end


function result = emptyPermutation()
result = struct('NullDeltaR2', nan(0, 1), ...
    'ObservedDeltaR2', NaN, 'TwoSidedP', NaN);
end


function field = unitTypeField(unitType)
if unitType == "2D"
    field = "TwoD";
else
    field = "ThreeD";
end
end


function closeValidFigure(figureHandle)
if isgraphics(figureHandle)
    close(figureHandle);
end
end


function ensureFolder(folder)
if ~isfolder(folder)
    mkdir(folder);
end
end

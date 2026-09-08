function result = BuildGaussianChannelBiasPredictionObjective(options)
%BUILDGAUSSIANCHANNELBIASPREDICTIONOBJECTIVE Optimize channel-first model.
%
% This is the non-meta alternative to Gaussian tuning-curve aggregation.
% Source MonoL/MonoR p_AI gates the neuron and stimulation contact; every
% neighboring contributor must pass its own raw MonoL/MonoR tuning tests.
% Default: predict every cue using dominant-eye AI*abs(OD), fit beta separately
% for each cue by ordinary least squares, and maximize summed ordinary R2.
% FitMethod="CV" retains the previous cue-specific AI + AI:OD CV model.

arguments
    options.CacheFile (1, 1) string = [ ...
        "C:\EM\CurrentSpread\02_gaussian\" + ...
        "InteractiveGaussianMetaPopulation\MT\" + ...
        "GaussianMetaPopulationSigmaCache.mat"]
    options.OutputFolder (1, 1) string = ""
    options.UnitType (1, 1) string ...
        {mustBeMember(options.UnitType, ["2D", "3D"])} = "2D"
    options.FigureVisible (1, 1) logical = false
    options.FitMethod (1, 1) string ...
        {mustBeMember(options.FitMethod, ["OrdinaryR2", "CV"])} = "OrdinaryR2"
    options.PredictorMode (1, 1) string ...
        {mustBeMember(options.PredictorMode, ...
        ["CombinedAI", "DominantAIxOD"])} = "DominantAIxOD"
    options.NumRepeats (1, 1) double ...
        {mustBeInteger, mustBePositive} = 5
    options.NumFolds (1, 1) double ...
        {mustBeInteger, mustBeGreaterThan(options.NumFolds, 1)} = 5
    options.RandomSeed (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 1
end

if ~isfile(options.CacheFile)
    error('GaussianChannelPrediction:MissingCache', ...
        'Population cache not found: %s', options.CacheFile);
end
loaded = load(options.CacheFile, 'cache');
if ~isfield(loaded, 'cache')
    error('GaussianChannelPrediction:InvalidCache', ...
        'Cache file does not contain a cache structure.');
end
cache = loaded.cache;
validateCache(cache);
isOrdinary = options.FitMethod == "OrdinaryR2";

if strlength(options.OutputFolder) == 0
    if isOrdinary
        folderName = 'ChannelFirstBiasPrediction_' + ...
            options.PredictorMode + '_OrdinaryR2_SourceStimBothEyes';
    else
        folderName = 'ChannelFirstBiasPrediction_DomNonDom_SourceStimBothEyes';
    end
    options.OutputFolder = fullfile(cache.OutputFolder, options.UnitType, folderName);
end
currentSpreadRoot = string(fileparts(fileparts(fileparts( ...
    fileparts(mfilename('fullpath'))))));
assertOutputOutsideRepository(options.OutputFolder, currentSpreadRoot);
ensureFolder(options.OutputFolder);

if isOrdinary
    selectionMode = options.PredictorMode;
else
    selectionMode = "CueAIOD";
end
selection = selectGaussianChannelPredictionCohort(cache, options.UnitType, selectionMode);
sessionMask = selection.SessionMask;
eligibleChannels = selection.ChannelEligible;
referenceOD = double(cache.StimReferenceOD(:));
if nnz(sessionMask) < 2
    error('GaussianChannelPrediction:TooFewEligibleSessions', ...
        'Fewer than two source-both-eye-significant %s neurons have valid inputs.', ...
        options.UnitType);
end

channelAI = double(cache.ChannelAI(sessionMask, :, :));
channelSignedOD = double(cache.ChannelSignedOD(sessionMask, :));
channelEligible = eligibleChannels(sessionMask, :);
relativePositions = double(cache.ChannelRelativePositions(sessionMask, :));
behavior = double(cache.BehaviorByPhysicalCue(sessionMask, :));
behaviorValid = selection.BehaviorValid(sessionMask, :);
behaviorSignedOD = referenceOD(sessionMask);

if isOrdinary
    fit = fitGaussianChannelCombinedAIOrdinaryModel( ...
        channelAI, channelSignedOD, channelEligible, relativePositions, ...
        behavior, behaviorValid, behaviorSignedOD, cache.SigmaValues, ...
        PredictorMode=options.PredictorMode);
else
    fit = fitGaussianChannelBiasModel( ...
        channelAI, channelSignedOD, channelEligible, relativePositions, ...
        behavior, behaviorValid, behaviorSignedOD, cache.SigmaValues, ...
        NumRepeats=options.NumRepeats, NumFolds=options.NumFolds, ...
        RandomSeed=options.RandomSeed);
end

sourceRows = double(cache.SourceRows(sessionMask));
fit.ObservationMap.SourceTableRow = ...
    sourceRows(fit.ObservationMap.SessionIndex);
selectedSourceP = selection.SourceTuningP(sessionMask, :);
fit.ObservationMap.SourceMonoLP = selectedSourceP(fit.ObservationMap.SessionIndex, 2);
fit.ObservationMap.SourceMonoRP = selectedSourceP(fit.ObservationMap.SessionIndex, 3);
selectedMonkey = string(cache.Monkey(sessionMask));
fit.ObservationMap.Monkey = ...
    selectedMonkey(fit.ObservationMap.SessionIndex);
selectedDate = cache.Date(sessionMask);
fit.ObservationMap.Date = selectedDate(fit.ObservationMap.SessionIndex);
fit.ObservationMap.ObservedBias = fit.Observed;
fit.ObservationMap.FullPrediction = fit.BestFullPrediction;
fit.ObservationMap.FullResidual = ...
    fit.Observed - fit.BestFullPrediction;
if ~isOrdinary
    fit.ObservationMap.HeldOutPrediction = fit.BestHeldOutPrediction;
    fit.ObservationMap.HeldOutResidual = ...
        fit.Observed - fit.BestHeldOutPrediction;
end

conditionNames = fit.ConditionNames(:);
termNames = repmat(fit.BetaTermNames(:), 4, 1);
conditionColumn = repelem(conditionNames, numel(fit.BetaTermNames));
betaTable = table(conditionColumn, termNames, ...
    reshape(fit.BestFullBeta', [], 1), ...
    'VariableNames', {'Condition', 'Term', 'Beta'});

sigmaValues = fit.SigmaValues;
meanEffectiveChannels = mean(double(fit.EffectiveChannels), ...
    1, 'omitnan')';
if isOrdinary
    sigmaTable = table(sigmaValues, fit.SumFourCueOrdinaryR2, ...
        fit.MeanFourCueOrdinaryR2, fit.FullMSE, meanEffectiveChannels, ...
        'VariableNames', {'Sigma', 'SumFourCueOrdinaryR2', ...
        'MeanFourCueOrdinaryR2', 'FullSampleMSE', 'MeanEffectiveChannels'});
else
    sigmaTable = table(sigmaValues, fit.MeanCVMSE, fit.SEMCVMSE, ...
        fit.MeanCVR2, fit.SEMCVR2, fit.FullMSE, fit.FullR2, ...
        meanEffectiveChannels, ...
        'VariableNames', {'Sigma', 'MeanCrossValidatedMSE', ...
        'SEMCrossValidatedMSE', 'MeanCrossValidatedR2', ...
        'SEMCrossValidatedR2', 'FullSampleMSE', 'FullSampleR2', ...
        'MeanEffectiveChannels'});
end
cueTokens = fit.ConditionNames;
for cue = 1:4
    token = cueTokens(cue);
    if isOrdinary
        sigmaTable.("OrdinaryR2_" + token) = fit.PerCueFullR2(cue, :)';
        sigmaTable.("MSE_" + token) = fit.PerCueFullMSE(cue, :)';
    else
        sigmaTable.("CVMSE_" + token) = fit.PerCueMeanCVMSE(cue, :)';
        sigmaTable.("CVR2_" + token) = fit.PerCueMeanCVR2(cue, :)';
    end
end

weightTable = buildWeightTable(cache, sessionMask, ...
    fit.BestChannelWeights, fit.BestFullBeta, channelEligible, ...
    string(fit.PredictorMode), selection);
validateChannelPredictionSum(fit, weightTable);
writetable(sigmaTable, fullfile(options.OutputFolder, ...
    'GaussianChannelBiasPredictionObjective.csv'));
writetable(betaTable, fullfile(options.OutputFolder, ...
    'GaussianChannelBiasPredictionBeta.csv'));
writetable(fit.ObservationMap, fullfile(options.OutputFolder, ...
    'GaussianChannelBiasPredictionPoints.csv'));
writetable(weightTable, fullfile(options.OutputFolder, ...
    'GaussianChannelBiasPredictionWeights.csv'));
writetable(selection.Audit, fullfile(options.OutputFolder, ...
    'GaussianChannelNeuronInclusionAudit.csv'));

result = fit;
result.SchemaVersion = 5;
result.CohortDefinition = selection.Definition;
result.SessionAudit = selection.Audit;
result.SourceTuningP = selectedSourceP;
result.Created = datetime('now', 'TimeZone', 'local');
result.FitMethod = options.FitMethod;
result.CacheFile = options.CacheFile;
result.OutputFolder = options.OutputFolder;
result.Area = string(cache.Area);
result.UnitType = options.UnitType;
result.ODDefinition = string(cache.ODDefinition);
result.TuningAlpha = cache.TuningAlpha;
result.SessionMask = sessionMask;
result.SourceRows = sourceRows;
result.SessionCount = nnz(sessionMask);
result.EligibleChannelCount = sum(channelEligible, 2);
result.ConditionColors = [254 191 15; 0 0 0; 234 0 233; 110 205 221] ./ 255;
result.SigmaTable = sigmaTable;
result.BetaTable = betaTable;
result.PointTable = fit.ObservationMap;
result.WeightTable = weightTable;
gaussian_channel_bias_prediction = result;
save(fullfile(options.OutputFolder, ...
    'GaussianChannelBiasPredictionOptimization.mat'), ...
    'gaussian_channel_bias_prediction', '-v7.3');

if isfield(cache, 'ConditionColors')
    conditionColors = double(cache.ConditionColors);
else
    conditionColors = [254 191 15; 0 0 0; 234 0 233; 110 205 221] ./ 255;
end
saveFigures(result, conditionColors, options.FigureVisible);
manifest = [ ...
    "Gaussian channel-first behavioral bias prediction"; ...
    "Area: " + result.Area; ...
    "Stimulation-channel unit type: " + result.UnitType; ...
    "Channel OD definition: " + result.ODDefinition; ...
    "Neuron gate: source unit_table_gof.p_AI(2) and p_AI(3) < " + result.TuningAlpha; ...
    "Stim contact uses source p_AI; neighbors use their own raw direction p-values"; ...
    result.ModelDescription; ...
    "Best sigma: " + result.BestSigma; ...
    "Sessions: " + result.SessionCount; ...
    "Source cache: " + options.CacheFile];
if isOrdinary
    manifest = [manifest; ...
        "Best summed ordinary R2: " + result.BestSumFourCueOrdinaryR2; ...
        "Per-cue ordinary R2: " + join(string(result.BestPerCueOrdinaryR2'), ', '); ...
        "Sigma at grid boundary: " + result.SigmaAtGridBoundary];
else
    manifest = [manifest; "Best CV MSE: " + result.BestCVMSE];
end
writelines(manifest, fullfile(options.OutputFolder, ...
    'GaussianChannelBiasPredictionManifest.txt'));

if isOrdinary
    fprintf(['%s ordinary optimum: sigma %.12g, summed R2 %.8g, ' ...
        '%s %s N=%d. Outputs: %s\n'], char(result.PredictorMode), ...
        result.BestSigma, ...
        result.BestSumFourCueOrdinaryR2, result.Area, result.UnitType, ...
        result.SessionCount, options.OutputFolder);
else
    fprintf('Channel-first CV optimum: sigma %.12g, CV MSE %.8g. Outputs: %s\n', ...
        result.BestSigma, result.BestCVMSE, options.OutputFolder);
end
end


function validateCache(cache)
required = ["SchemaVersion", "OutputFolder", "Area", "ODDefinition", ...
    "TuningAlpha", "SigmaValues", "SourceRows", "Monkey", "Date", ...
    "SessionStatus", "StimZ3DMinusZ2D", "StimReferenceOD", ...
    "BehaviorByPhysicalCue", ...
    "BehaviorValidByPhysicalCue", "ChannelNumbers", ...
    "ChannelRelativePositions", "ChannelAI", "ChannelSignedOD", ...
    "ChannelTuningP", "ChannelAvailable", "StimChannel"];
missing = required(~isfield(cache, required));
if ~isempty(missing) || double(cache.SchemaVersion) < 5
    error('GaussianChannelPrediction:CacheRequiresRebuild', ...
        ['The cache predates channel-first prediction inputs or is missing ' ...
        'fields: %s. Rebuild it with ' ...
        'BuildInteractiveGaussianMetaPopulationCache.'], join(missing, ', '));
end
end


function output = buildWeightTable(cache, sessionMask, weights, beta, eligible, predictorMode, selection)
sourceRows = double(cache.SourceRows(sessionMask));
channelNumbers = double(cache.ChannelNumbers(sessionMask, :));
positions = double(cache.ChannelRelativePositions(sessionMask, :));
signedOD = double(cache.ChannelSignedOD(sessionMask, :));
pValues = selection.EffectiveChannelTuningP(sessionMask, :, :);
rawP = selection.RawChannelTuningP(sessionMask, :, :);
sources = selection.ChannelTuningSource(sessionMask, :);
channelAI = double(cache.ChannelAI(sessionMask, :, :));
rows = find(eligible);
[sessionIndex, positionIndex] = ind2sub(size(eligible), rows);
linearIndex = sub2ind(size(eligible), sessionIndex, positionIndex);
leftP = nan(numel(rows), 1);
rightP = nan(numel(rows), 1);
rawLeftP = leftP;
rawRightP = rightP;
for index = 1:numel(rows)
    leftP(index) = pValues(sessionIndex(index), 2, positionIndex(index));
    rightP(index) = pValues(sessionIndex(index), 3, positionIndex(index));
    rawLeftP(index) = rawP(sessionIndex(index), 2, positionIndex(index));
    rawRightP(index) = rawP(sessionIndex(index), 3, positionIndex(index));
end
output = table(sessionIndex, sourceRows(sessionIndex), ...
    channelNumbers(linearIndex), positions(linearIndex), ...
    signedOD(linearIndex), abs(signedOD(linearIndex)), leftP, rightP, ...
    weights(linearIndex), ...
    'VariableNames', {'SessionIndex', 'SourceTableRow', 'Channel', ...
    'RelativePosition', 'SignedOD', 'OD', 'MonoLP', 'MonoRP', ...
    'BestGaussianWeight'});
output.TuningPSource = sources(linearIndex);
output.RecomputedMonoLP = rawLeftP;
output.RecomputedMonoRP = rawRightP;
assert(all(output.MonoLP < cache.TuningAlpha & output.MonoRP < cache.TuningAlpha), ...
    'GaussianChannelPrediction:IneligibleContribution', 'Every channel contribution must pass both eye tests.');
cueTokens = ["Dominant", "Combined", "Stereo", "NonDominant"];
localCueOrder = gaussianChannelConditionCueOrder(signedOD(linearIndex));
if predictorMode == "CombinedAI"
    localCueOrder(:) = 1; % Combined AI is used for every behavioral cue.
elseif predictorMode == "DominantAIxOD"
    localCueOrder = repmat(localCueOrder(:, 1), 1, 4);
end
for condition = 1:4
    channelPrediction = nan(numel(rows), 1);
    for index = 1:numel(rows)
        sourceCue = localCueOrder(index, condition);
        ai = channelAI(sessionIndex(index), sourceCue, positionIndex(index));
        if predictorMode == "CombinedAI"
            channelPrediction(index) = [1, ai] * beta(condition, :)';
        elseif predictorMode == "DominantAIxOD"
            channelPrediction(index) = ...
                [1, ai .* abs(signedOD(linearIndex(index)))] * ...
                beta(condition, :)';
        else
            channelPrediction(index) = ...
                [1, ai, ai .* abs(signedOD(linearIndex(index)))] * ...
                beta(condition, :)';
        end
    end
    output.("ChannelSourceCue_" + cueTokens(condition)) = ...
        localCueOrder(:, condition);
    output.("ChannelPrediction_" + cueTokens(condition)) = ...
        channelPrediction;
    output.("WeightedContribution_" + cueTokens(condition)) = ...
        channelPrediction .* output.BestGaussianWeight;
end
end


function validateChannelPredictionSum(fit, weightTable)
cueTokens = fit.ConditionNames;
reconstructed = nan(height(fit.ObservationMap), 1);
for row = 1:height(fit.ObservationMap)
    session = fit.ObservationMap.SessionIndex(row);
    cue = fit.ObservationMap.ConditionIndex(row);
    use = weightTable.SessionIndex == session;
    contribution = weightTable.( ...
        "WeightedContribution_" + cueTokens(cue));
    reconstructed(row) = sum(contribution(use));
end
difference = abs(reconstructed - fit.BestFullPrediction);
assert(all(difference < 1e-6 | ...
    (~isfinite(reconstructed) & ~isfinite(fit.BestFullPrediction))), ...
    'GaussianChannelPrediction:ChannelSumMismatch', ...
    ['The saved per-channel predictions do not sum to the fitted ' ...
    'session predictions.']);
end


function saveFigures(result, conditionColors, figureVisible)
isOrdinary = result.FitMethod == "OrdinaryR2";
if isOrdinary
    perCueMetric = result.PerCueFullR2;
    objectiveValues = result.SumFourCueOrdinaryR2;
    metricName = "ordinary R^2";
    objectiveName = "Sum of four ordinary R^2 values";
    yLabel = 'Ordinary R^2 / summed objective';
    xPredictionLabel = 'Fitted predicted \DeltaBias (ordinary fit)';
    predicted = result.PointTable.FullPrediction;
    predictionFile = 'GaussianChannelBiasOrdinaryPrediction';
    summary = sprintf('Best sigma %.6g; sum R^2 %.4f; mean R^2 %.4f', ...
        result.BestSigma, result.BestSumFourCueOrdinaryR2, ...
        result.BestMeanFourCueOrdinaryR2);
else
    perCueMetric = result.PerCueMeanCVMSE;
    objectiveValues = result.MeanCVMSE;
    metricName = "CV MSE";
    objectiveName = "Equal-cue mean CV MSE";
    yLabel = 'Held-out mean squared prediction error';
    xPredictionLabel = 'Mean held-out predicted \DeltaBias';
    predicted = result.PointTable.HeldOutPrediction;
    predictionFile = 'GaussianChannelBiasHeldOutPrediction';
    summary = sprintf('Best sigma %.6g; CV MSE %.4g; CV R^2 %.4f', ...
        result.BestSigma, result.BestCVMSE, result.BestCVR2);
end
previousVisibility = get(groot, 'defaultFigureVisible');
visibilityCleanup = onCleanup( ...
    @() set(groot, 'defaultFigureVisible', previousVisibility));
set(groot, 'defaultFigureVisible', ternary(figureVisible, 'on', 'off'));

objectiveFigure = figure('Color', 'w', ...
    'Name', 'Gaussian channel-first prediction objective', ...
    'Position', [120 120 980 650]);
hold on
cueColors = conditionColors;
for cue = 1:4
    plot(result.SigmaValues, perCueMetric(cue, :), ...
        '-', 'Color', cueColors(cue, :), 'LineWidth', 1.2, ...
        'DisplayName', result.ConditionNames(cue) + " " + metricName);
end
plot(result.SigmaValues, objectiveValues, 'k-', 'LineWidth', 3, ...
    'DisplayName', objectiveName);
xline(result.BestSigma, 'r--', 'LineWidth', 2, ...
    'DisplayName', sprintf('Best sigma = %.6g', result.BestSigma));
set(gca, 'XScale', 'log');
grid on; box on
xlabel('Gaussian \sigma (physical contact spacings)');
ylabel(yLabel);
title(sprintf('%s %s channel-first bias prediction (%s OD)', ...
    result.Area, result.UnitType, result.ODDefinition));
subtitle(summary);
legend('Location', 'best');
exportgraphics(objectiveFigure, fullfile(result.OutputFolder, ...
    'GaussianChannelBiasPredictionObjective.png'), 'Resolution', 300);
savefig(objectiveFigure, fullfile(result.OutputFolder, ...
    'GaussianChannelBiasPredictionObjective.fig'));
close(objectiveFigure);

predictionFigure = figure('Color', 'w', ...
    'Name', 'Gaussian channel-first predictions', ...
    'Position', [140 140 760 690]);
hold on
points = result.PointTable;
finite = isfinite(predicted) & ...
    isfinite(points.ObservedBias);
limit = max(abs([predicted(finite); ...
    points.ObservedBias(finite)]), [], 'omitnan');
if isempty(limit) || ~isfinite(limit) || limit <= 0
    limit = 1;
end
limit = 1.08 .* limit;
plot([-limit limit], [-limit limit], 'k--', 'LineWidth', 1.2, ...
    'DisplayName', 'Identity');
for cue = 1:4
    use = finite & points.ConditionIndex == cue;
    scatter(predicted(use), points.ObservedBias(use), ...
        42, cueColors(cue, :), 'filled', 'MarkerEdgeColor', [0.2 0.2 0.2], ...
        'DisplayName', result.ConditionNames(cue));
end
axis equal
xlim([-limit limit]); ylim([-limit limit]);
grid on; box on
xlabel(xPredictionLabel);
ylabel('Observed \DeltaBias');
title(sprintf('%s %s channel-first predictions at \\sigma = %.5g', ...
    result.Area, result.UnitType, result.BestSigma));
subtitle(summary);
legend('Location', 'best');
exportgraphics(predictionFigure, fullfile(result.OutputFolder, ...
    [predictionFile '.png']), 'Resolution', 300);
savefig(predictionFigure, fullfile(result.OutputFolder, ...
    [predictionFile '.fig']));
close(predictionFigure);
clear visibilityCleanup
end


function assertOutputOutsideRepository(outputFolder, repositoryRoot)
resolvedOutput = string(char(java.io.File(char(outputFolder)).getCanonicalPath()));
resolvedRepository = string(char( ...
    java.io.File(char(repositoryRoot)).getCanonicalPath()));
if startsWith(lower(resolvedOutput), lower(resolvedRepository + filesep)) || ...
        strcmpi(resolvedOutput, resolvedRepository)
    error('GaussianChannelPrediction:RepositoryLocalOutput', ...
        'OutputFolder must be outside the repository: %s', resolvedOutput);
end
end


function ensureFolder(folder)
if ~isfolder(folder)
    mkdir(folder);
end
end


function value = ternary(condition, trueValue, falseValue)
if condition
    value = trueValue;
else
    value = falseValue;
end
end

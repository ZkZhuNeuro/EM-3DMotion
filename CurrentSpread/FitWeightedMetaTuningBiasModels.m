function result = FitWeightedMetaTuningBiasModels(cache, options)
%FITWEIGHTEDMETATUNINGBIASMODELS Train/test weighted meta-tuning models.
%
% The expanded model learns one nonnegative, sum-to-one population weight
% vector over the cache's centered physical-contact window. Weights and
% behavioral coefficients are fitted only on each outer training fold. The
% center-only one-hot baseline otherwise uses identical features and folds.

arguments
    cache (1, 1) struct
    options.NumRepeats (1, 1) double ...
        {mustBeInteger, mustBePositive} = 20
    options.NumFolds (1, 1) double ...
        {mustBeInteger, mustBeGreaterThan(options.NumFolds, 1)} = 5
    options.RandomSeed (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 1
    options.WeightStep (1, 1) double ...
        {mustBeGreaterThan(options.WeightStep, 0), ...
        mustBeLessThanOrEqual(options.WeightStep, 0.5)} = 0.05
    options.ModelVariants (1, :) string = ["AIOnly", "AIxOD"]
    options.Analyses (1, :) string = ["AllCue", "StereoOnly"]
    options.MinimumGroupSize (1, 1) double ...
        {mustBeInteger, mustBePositive} = 8
end

validateCache(cache);
modelVariants = canonicalVariants(options.ModelVariants);
analyses = canonicalAnalyses(options.Analyses);
relativePositions = cache.RelativePositions(:)';
positionCount = numel(relativePositions);
centerPosition = find(relativePositions == 0, 1);
if isempty(centerPosition) || mod(positionCount, 2) ~= 1
    error('WeightedMetaTuning:InvalidRelativePositions', ...
        'Cache RelativePositions must contain one centered odd window.');
end
weightGrid = simplexWeightGrid(options.WeightStep, positionCount);
features = CalculateThreeChannelMetaFeatures( ...
    cache.SessionStats, weightGrid);
conditionAI = nan(size(features.AI));
centerWeights = zeros(1, positionCount);
centerWeights(centerPosition) = 1;
centerIndex = find(all(abs(weightGrid - centerWeights) < 1e-12, 2), 1);
for session = 1:numel(cache.SessionStats)
    sourceCue = cache.SessionStats(session).SourceCueByCondition;
    for condition = 1:4
        conditionAI(session, condition, :) = ...
            features.AI(session, sourceCue(condition), :);
    end
end
features.RawCueAI = features.AI;
features.ConditionAI = conditionAI;
if isempty(centerIndex)
    error('WeightedMetaTuning:MissingCenterWeight', ...
        'The weight grid does not contain the center-only baseline.');
end

sessionTable = cache.SessionTable;
behavior = vertcat(cache.SessionStats.Behavior);
areas = ["MT", "FST"];
unitTypes = ["2D", "3D"];
groupCapacity = numel(modelVariants) * numel(analyses) * ...
    numel(areas) * numel(unitTypes);
groups = repmat(emptyGroupResult(), groupCapacity, 1);
groupSummary = table();
conditionSummary = table();
fullWeightSummary = table();
foldWeightTable = table();
writeIndex = 0;

for variant = modelVariants
    for analysis = analyses
        if analysis == "AllCue"
            conditionIndices = 1:4;
        else
            conditionIndices = 3;
        end
        for area = areas
            for unitType = unitTypes
                writeIndex = writeIndex + 1;
                group = emptyGroupResult();
                group.ModelVariant = variant;
                group.Analysis = analysis;
                group.Area = area;
                group.UnitType = unitType;
                group.ConditionIndices = conditionIndices;
                group.ConditionNames = cache.ConditionNames(conditionIndices);
                group.WeightGrid = weightGrid;
                group.RelativePositions = relativePositions;

                populationMask = string(sessionTable.Area) == area & ...
                    string(sessionTable.UnitType) == unitType;
                group.NPopulationSessions = nnz(populationMask);
                finiteAI = squeeze(all(isfinite( ...
                    conditionAI(:, conditionIndices, :)), 3));
                if isvector(finiteAI)
                    finiteAI = finiteAI(:);
                end
                finiteOD = all(isfinite(features.OD), 2);
                validObservation = isfinite(behavior(:, conditionIndices)) & ...
                    finiteAI & finiteOD;
                eligibleSession = populationMask & any(validObservation, 2);
                sourceSessionRows = find(eligibleSession);
                group.SourceSessionRows = sourceSessionRows;
                group.NSessions = numel(sourceSessionRows);
                group.NExcludedFromAnalysisCohort = ...
                    group.NPopulationSessions - group.NSessions;
                group.NObservations = nnz(validObservation(eligibleSession, :));
                if group.NSessions < options.MinimumGroupSize
                    group.Status = sprintf( ...
                        'Too few complete sessions (%d; need at least %d)', ...
                        group.NSessions, options.MinimumGroupSize);
                    groups(writeIndex) = group;
                    groupSummary = appendTable(groupSummary, ...
                        groupSummaryRow(group));
                    continue
                end

                localAI = conditionAI(eligibleSession, conditionIndices, :);
                localOD = features.OD(eligibleSession, :);
                localBehavior = behavior(eligibleSession, conditionIndices);
                localValid = validObservation(eligibleSession, :);
                parameterCount = 2 + double(variant == "AIxOD");
                observationCounts = sum(localValid, 1);
                group.ConditionObservationCounts = observationCounts;
                if any(observationCounts < parameterCount + 2)
                    group.Status = "Too few observations in at least one cue";
                    groups(writeIndex) = group;
                    groupSummary = appendTable(groupSummary, ...
                        groupSummaryRow(group));
                    continue
                end

                [fullExpandedIndex, fullExpandedBetas, fullObjective] = ...
                    selectBestWeight(localAI, localOD, localBehavior, ...
                    localValid, true(group.NSessions, 1), variant, ...
                    weightGrid);
                [baselineBetas, baselineObjective] = fitAtWeight( ...
                    localAI, localOD, localBehavior, localValid, ...
                    true(group.NSessions, 1), variant, centerIndex);
                if ~isfinite(fullExpandedIndex) || ~isfinite(baselineObjective)
                    group.Status = "Full-data model fit failed";
                    groups(writeIndex) = group;
                    groupSummary = appendTable(groupSummary, ...
                        groupSummaryRow(group));
                    continue
                end

                fullBaseline = fullFitStatistics(localAI, localOD, ...
                    localBehavior, localValid, variant, centerIndex, ...
                    baselineBetas);
                fullExpanded = fullFitStatistics(localAI, localOD, ...
                    localBehavior, localValid, variant, fullExpandedIndex, ...
                    fullExpandedBetas);
                fullBaseline.Objective = baselineObjective;
                fullExpanded.Objective = fullObjective;

                stableIndex = stableGroupIndex(area, unitType, analysis);
                folds = repeatedBalancedFolds(group.NSessions, ...
                    options.NumFolds, options.NumRepeats, ...
                    options.RandomSeed + 1000 * stableIndex);
                cv = evaluateCrossValidation(localAI, localOD, ...
                    localBehavior, localValid, variant, weightGrid, ...
                    centerIndex, folds);
                paired = isfinite(cv.BaselineMacroR2) & ...
                    isfinite(cv.ExpandedMacroR2);
                if nnz(paired) ~= options.NumRepeats
                    group.Status = sprintf( ...
                        'Incomplete paired cross-validation (%d/%d repeats)', ...
                        nnz(paired), options.NumRepeats);
                    group.FullBaseline = fullBaseline;
                    group.FullExpanded = fullExpanded;
                    group.CV = cv;
                    groups(writeIndex) = group;
                    groupSummary = appendTable(groupSummary, ...
                        groupSummaryRow(group));
                    continue
                end

                deltaMacro = cv.ExpandedMacroR2 - cv.BaselineMacroR2;
                group.FullBaseline = fullBaseline;
                group.FullExpanded = fullExpanded;
                group.CV = cv;
                group.FullExpandedWeightIndex = fullExpandedIndex;
                group.FullExpandedWeights = weightGrid(fullExpandedIndex, :);
                group.MeanBaselineMacroCVR2 = mean(cv.BaselineMacroR2);
                group.MeanExpandedMacroCVR2 = mean(cv.ExpandedMacroR2);
                group.MeanDeltaMacroCVR2 = mean(deltaMacro);
                group.DeltaMacroPartitionRange = ...
                    prctile(deltaMacro, [2.5 97.5]);
                group.MeanBaselinePooledCVR2 = mean(cv.BaselinePooledR2);
                group.MeanExpandedPooledCVR2 = mean(cv.ExpandedPooledR2);
                group.Status = "Success";
                groups(writeIndex) = group;

                groupSummary = appendTable(groupSummary, ...
                    groupSummaryRow(group));
                conditionSummary = appendTable(conditionSummary, ...
                    conditionSummaryRows(group, cache.ConditionNames));
                fullWeightSummary = appendTable(fullWeightSummary, ...
                    fullWeightRow(group));
                foldWeightTable = appendTable(foldWeightTable, ...
                    foldWeightRows(group));
            end
        end
    end
end

groups = groups(1:writeIndex);
storedAI = reshape(vertcat(cache.SessionStats.StoredStimAI), 4, [])';
reconstructedAI = features.RawCueAI(:, :, centerIndex);
maxAIError = max(abs(storedAI - reconstructedAI), [], 2, 'omitnan');
storedOD = [cache.SessionStats.OriginalSignedOD]';
reconstructedOD = features.SignedOD(:, centerIndex);
absODError = abs(storedOD - reconstructedOD);
reconstructionSummary = table(numel(maxAIError), ...
    median(maxAIError, 'omitnan'), max(maxAIError, [], 'omitnan'), ...
    nnz(maxAIError > 0.01), nnz(maxAIError > 0.05), ...
    median(absODError, 'omitnan'), max(absODError, [], 'omitnan'), ...
    'VariableNames', {'NSessions', 'MedianMaxAbsAIError', ...
    'MaximumAbsAIError', 'NAIErrorAbove001', 'NAIErrorAbove005', ...
    'MedianAbsODError', 'MaximumAbsODError'});
result = struct();
result.Analysis = sprintf( ...
    'Behavior-optimized %d-channel z-scored meta tuning', positionCount);
result.PrimaryFormula = "Bias = beta0 + beta1*MetaAI";
result.SensitivityFormula = ...
    "Bias = beta0 + beta1*MetaAI + beta2*(MetaAI*abs(MetaOD))";
result.BaselineWeights = centerWeights;
result.RelativePositions = relativePositions;
result.WeightConstraint = "w >= 0; sum(w) = 1";
result.WeightInterpretation = [ ...
    "The free simplex may assign zero weight to STIM"; ...
    "Expanded model tests an optimized " + string(positionCount) + ...
    "-contact readout, not forced addition to STIM"];
result.AllCueWeighting = ...
    "One shared channel-weight vector per area/type; cue-specific regression coefficients";
result.FixedLabelPolicy = [ ...
    "Original stimulation-site 2D/3D classes are fixed"; ...
    "Original OD sign fixes Dominant/NonDominant response labels"; ...
    "Meta-OD magnitude enters AIxOD but its sign does not relabel outcomes"];
result.WeightStep = options.WeightStep;
result.WeightGrid = weightGrid;
result.CenterWeightIndex = centerIndex;
result.Features = features;
result.CenterReconstructionSummary = reconstructionSummary;
result.BaselineDefinition = [ ...
    "Center-only feature reconstructed from Quick cache with one-hot center weight"; ...
    "Uses the common requested-window complete-trial support for fair nesting"; ...
    "May differ from stored stimulation-channel AI/OD; see reconstruction audit"];
result.Cache = cache;
result.Groups = groups;
result.GroupSummary = groupSummary;
result.ConditionSummary = conditionSummary;
result.FullWeightSummary = fullWeightSummary;
result.FoldWeightTable = foldWeightTable;
result.NumRepeats = options.NumRepeats;
result.NumFolds = options.NumFolds;
result.RandomSeed = options.RandomSeed;
result.ResamplingInterpretation = ...
    "Repeated-fold percentiles describe partition sensitivity, not confidence intervals";
end


function cv = evaluateCrossValidation(ai, od, behavior, validObservation, ...
    variant, weightGrid, centerIndex, foldMatrix)
sessionCount = size(ai, 1);
conditionCount = size(ai, 2);
repeatCount = size(foldMatrix, 2);
foldCount = max(foldMatrix, [], 'all');
baselinePrediction = nan(sessionCount, conditionCount, repeatCount);
expandedPrediction = nan(sessionCount, conditionCount, repeatCount);
nullPrediction = nan(sessionCount, conditionCount, repeatCount);
weightSamples = nan(repeatCount * foldCount, size(weightGrid, 2));
selectedWeightIndex = nan(repeatCount, foldCount);
baselinePerCueR2 = nan(repeatCount, conditionCount);
expandedPerCueR2 = nan(repeatCount, conditionCount);
baselineMacroR2 = nan(repeatCount, 1);
expandedMacroR2 = nan(repeatCount, 1);
baselinePooledR2 = nan(repeatCount, 1);
expandedPooledR2 = nan(repeatCount, 1);
sampleIndex = 0;

for repeatIndex = 1:repeatCount
    folds = foldMatrix(:, repeatIndex);
    for fold = 1:foldCount
        train = folds ~= fold;
        test = folds == fold;
        [expandedIndex, expandedBetas] = selectBestWeight( ...
            ai, od, behavior, validObservation, train, variant, weightGrid);
        [baselineBetas, ~] = fitAtWeight(ai, od, behavior, ...
            validObservation, train, variant, centerIndex);
        if ~isfinite(expandedIndex)
            continue
        end
        sampleIndex = sampleIndex + 1;
        weightSamples(sampleIndex, :) = weightGrid(expandedIndex, :);
        selectedWeightIndex(repeatIndex, fold) = expandedIndex;
        for condition = 1:conditionCount
            validTrain = train & validObservation(:, condition);
            validTest = test & validObservation(:, condition);
            if ~any(validTest) || ~all(isfinite( ...
                    baselineBetas(condition, 1:parameterCount(variant)))) || ...
                    ~all(isfinite(expandedBetas( ...
                    condition, 1:parameterCount(variant))))
                continue
            end
            baselinePrediction(validTest, condition, repeatIndex) = ...
                predictAtWeight(ai, od, validTest, condition, ...
                centerIndex, baselineBetas(condition, :), variant);
            expandedPrediction(validTest, condition, repeatIndex) = ...
                predictAtWeight(ai, od, validTest, condition, ...
                expandedIndex, expandedBetas(condition, :), variant);
            nullPrediction(validTest, condition, repeatIndex) = ...
                mean(behavior(validTrain, condition), 'omitnan');
        end
    end

    for condition = 1:conditionCount
        valid = validObservation(:, condition);
        baselinePerCueR2(repeatIndex, condition) = heldOutR2( ...
            behavior(valid, condition), ...
            baselinePrediction(valid, condition, repeatIndex), ...
            nullPrediction(valid, condition, repeatIndex));
        expandedPerCueR2(repeatIndex, condition) = heldOutR2( ...
            behavior(valid, condition), ...
            expandedPrediction(valid, condition, repeatIndex), ...
            nullPrediction(valid, condition, repeatIndex));
    end
    sharedCue = isfinite(baselinePerCueR2(repeatIndex, :)) & ...
        isfinite(expandedPerCueR2(repeatIndex, :));
    if all(sharedCue)
        baselineMacroR2(repeatIndex) = ...
            mean(baselinePerCueR2(repeatIndex, sharedCue));
        expandedMacroR2(repeatIndex) = ...
            mean(expandedPerCueR2(repeatIndex, sharedCue));
    end
    baselinePooledR2(repeatIndex) = heldOutR2( ...
        behavior(:), ...
        reshape(baselinePrediction(:, :, repeatIndex), [], 1), ...
        reshape(nullPrediction(:, :, repeatIndex), [], 1), ...
        validObservation);
    expandedPooledR2(repeatIndex) = heldOutR2( ...
        behavior(:), ...
        reshape(expandedPrediction(:, :, repeatIndex), [], 1), ...
        reshape(nullPrediction(:, :, repeatIndex), [], 1), ...
        validObservation);
end

cv = struct();
cv.FoldMatrix = foldMatrix;
cv.BaselinePrediction = baselinePrediction;
cv.ExpandedPrediction = expandedPrediction;
cv.NullPrediction = nullPrediction;
cv.BaselinePerCueR2 = baselinePerCueR2;
cv.ExpandedPerCueR2 = expandedPerCueR2;
cv.BaselineMacroR2 = baselineMacroR2;
cv.ExpandedMacroR2 = expandedMacroR2;
cv.BaselinePooledR2 = baselinePooledR2;
cv.ExpandedPooledR2 = expandedPooledR2;
cv.WeightSamples = weightSamples(1:sampleIndex, :);
cv.SelectedWeightIndex = selectedWeightIndex;
end


function [bestIndex, bestBetas, bestObjective] = selectBestWeight( ...
    ai, od, behavior, validObservation, train, variant, weightGrid)
weightCount = size(weightGrid, 1);
objective = inf(weightCount, 1);
betas = cell(weightCount, 1);
for weightIndex = 1:weightCount
    [thisBetas, thisObjective] = fitAtWeight(ai, od, behavior, ...
        validObservation, train, variant, weightIndex);
    betas{weightIndex} = thisBetas;
    objective(weightIndex) = thisObjective;
end
finite = isfinite(objective);
if ~any(finite)
    bestIndex = nan;
    bestBetas = nan(size(behavior, 2), 3);
    bestObjective = nan;
    return
end
bestObjective = min(objective(finite));
tolerance = 1e-10 * max(1, abs(bestObjective));
ties = find(finite & objective <= bestObjective + tolerance);
centerPosition = (size(weightGrid, 2) + 1) ./ 2;
[~, relative] = max(weightGrid(ties, centerPosition));
bestIndex = ties(relative);
bestBetas = betas{bestIndex};
end


function [betas, objective] = fitAtWeight(ai, od, behavior, ...
    validObservation, train, variant, weightIndex)
conditionCount = size(ai, 2);
betas = nan(conditionCount, 3);
normalizedSSE = nan(conditionCount, 1);
for condition = 1:conditionCount
    valid = train & validObservation(:, condition) & ...
        isfinite(ai(:, condition, weightIndex)) & ...
        isfinite(od(:, weightIndex));
    design = designMatrix(ai(valid, condition, weightIndex), ...
        od(valid, weightIndex), variant);
    y = behavior(valid, condition);
    if size(design, 1) < size(design, 2) + 2 || ...
            rank(design) < size(design, 2)
        objective = inf;
        return
    end
    beta = design \ y;
    betas(condition, 1:numel(beta)) = beta;
    residual = y - design * beta;
    sst = sum((y - mean(y)) .^ 2);
    if ~isfinite(sst) || sst <= eps
        objective = inf;
        return
    end
    normalizedSSE(condition) = sum(residual .^ 2) ./ sst;
end
objective = mean(normalizedSSE);
end


function stats = fullFitStatistics(ai, od, behavior, validObservation, ...
    variant, weightIndex, betas)
conditionCount = size(ai, 2);
perCueR2 = nan(1, conditionCount);
prediction = nan(size(behavior));
for condition = 1:conditionCount
    valid = validObservation(:, condition);
    prediction(valid, condition) = predictAtWeight( ...
        ai, od, valid, condition, weightIndex, betas(condition, :), variant);
    perCueR2(condition) = ordinaryR2(behavior(valid, condition), ...
        prediction(valid, condition));
end
stats = struct();
stats.Betas = betas;
stats.PerCueR2 = perCueR2;
stats.PerCueRMSE = nan(1, conditionCount);
for condition = 1:conditionCount
    valid = validObservation(:, condition) & ...
        isfinite(prediction(:, condition));
    if any(valid)
        stats.PerCueRMSE(condition) = sqrt(mean( ...
            (behavior(valid, condition) - prediction(valid, condition)) .^ 2));
    end
end
stats.MacroR2 = mean(perCueR2, 'omitnan');
stats.PooledR2 = ordinaryR2(behavior(validObservation), ...
    prediction(validObservation));
stats.Prediction = prediction;
stats.Objective = nan;
end


function prediction = predictAtWeight(ai, od, rows, condition, ...
    weightIndex, beta, variant)
x = ai(rows, condition, weightIndex);
odValue = od(rows, weightIndex);
design = designMatrix(x, odValue, variant);
prediction = design * beta(1:size(design, 2))';
end


function design = designMatrix(ai, od, variant)
if variant == "AIxOD"
    design = [ones(numel(ai), 1), ai(:), ai(:) .* od(:)];
else
    design = [ones(numel(ai), 1), ai(:)];
end
end


function count = parameterCount(variant)
count = 2 + double(variant == "AIxOD");
end


function value = ordinaryR2(observed, predicted)
valid = isfinite(observed) & isfinite(predicted);
sst = sum((observed(valid) - mean(observed(valid))) .^ 2);
if nnz(valid) < 3 || sst <= eps
    value = nan;
else
    value = 1 - sum((observed(valid) - predicted(valid)) .^ 2) ./ sst;
end
end


function value = heldOutR2(observed, predicted, nullPredicted, mask)
if nargin < 4
    mask = true(size(observed));
end
observed = observed(:);
predicted = predicted(:);
nullPredicted = nullPredicted(:);
mask = mask(:);
valid = mask & isfinite(observed) & isfinite(predicted) & ...
    isfinite(nullPredicted);
nullSSE = sum((observed(valid) - nullPredicted(valid)) .^ 2);
if nnz(valid) < 3 || nullSSE <= eps
    value = nan;
else
    value = 1 - sum((observed(valid) - predicted(valid)) .^ 2) ./ nullSSE;
end
end


function weights = simplexWeightGrid(step, positionCount)
stepCount = round(1 ./ step);
if abs(stepCount .* step - 1) > 1e-10
    error('WeightedMetaTuning:WeightStep', ...
        'WeightStep must evenly divide one.');
end
integerWeights = integerCompositions(stepCount, positionCount);
weights = integerWeights ./ stepCount;
end


function output = integerCompositions(total, partCount)
if partCount == 1
    output = total;
    return
end
rowCount = nchoosek(total + partCount - 1, partCount - 1);
output = zeros(rowCount, partCount);
writeIndex = 0;
for first = 0:total
    remainder = integerCompositions(total - first, partCount - 1);
    count = size(remainder, 1);
    output(writeIndex + (1:count), :) = [ ...
        repmat(first, count, 1), remainder];
    writeIndex = writeIndex + count;
end
output = output(1:writeIndex, :);
end


function folds = repeatedBalancedFolds(rowCount, foldCount, ...
    repeatCount, seed)
foldCount = min(foldCount, rowCount);
folds = zeros(rowCount, repeatCount);
for repeatIndex = 1:repeatCount
    stream = RandStream('mt19937ar', 'Seed', seed + repeatIndex - 1);
    order = randperm(stream, rowCount);
    assignment = zeros(rowCount, 1);
    assignment(order) = mod(0:rowCount-1, foldCount) + 1;
    folds(:, repeatIndex) = assignment;
end
end


function index = stableGroupIndex(area, unitType, analysis)
areaIndex = find(["MT", "FST"] == area, 1);
typeIndex = find(["2D", "3D"] == unitType, 1);
analysisIndex = find(["AllCue", "StereoOnly"] == analysis, 1);
index = ((analysisIndex - 1) * 4) + ((areaIndex - 1) * 2) + typeIndex;
end


function group = emptyGroupResult()
emptyStats = struct('Betas', nan(0, 3), 'PerCueR2', nan(1, 0), ...
    'PerCueRMSE', nan(1, 0), ...
    'MacroR2', nan, 'PooledR2', nan, 'Prediction', nan(0, 0), ...
    'Objective', nan);
emptyCV = struct('FoldMatrix', zeros(0, 0), ...
    'BaselinePrediction', nan(0, 0, 0), ...
    'ExpandedPrediction', nan(0, 0, 0), ...
    'NullPrediction', nan(0, 0, 0), ...
    'BaselinePerCueR2', nan(0, 0), ...
    'ExpandedPerCueR2', nan(0, 0), ...
    'BaselineMacroR2', nan(0, 1), ...
    'ExpandedMacroR2', nan(0, 1), ...
    'BaselinePooledR2', nan(0, 1), ...
    'ExpandedPooledR2', nan(0, 1), ...
    'WeightSamples', nan(0, 0), ...
    'SelectedWeightIndex', nan(0, 0));
group = struct('ModelVariant', "", 'Analysis', "", 'Area', "", ...
    'UnitType', "", 'ConditionIndices', [], ...
    'ConditionNames', strings(1, 0), 'SourceSessionRows', [], ...
    'NPopulationSessions', 0, 'NSessions', 0, ...
    'NExcludedFromAnalysisCohort', 0, 'NObservations', 0, ...
    'ConditionObservationCounts', [], 'WeightGrid', nan(0, 0), ...
    'RelativePositions', [], ...
    'FullBaseline', emptyStats, 'FullExpanded', emptyStats, 'CV', emptyCV, ...
    'FullExpandedWeightIndex', nan, 'FullExpandedWeights', nan(1, 0), ...
    'MeanBaselineMacroCVR2', nan, 'MeanExpandedMacroCVR2', nan, ...
    'MeanDeltaMacroCVR2', nan, 'DeltaMacroPartitionRange', [nan nan], ...
    'MeanBaselinePooledCVR2', nan, 'MeanExpandedPooledCVR2', nan, ...
    'Status', "Not fit");
end


function row = groupSummaryRow(group)
row = table(group.ModelVariant, group.Analysis, group.Area, ...
    group.UnitType, group.NPopulationSessions, group.NSessions, ...
    group.NExcludedFromAnalysisCohort, group.NObservations, ...
    string(group.Status), group.FullBaseline.MacroR2, ...
    group.FullExpanded.MacroR2, ...
    group.FullExpanded.MacroR2 - group.FullBaseline.MacroR2, ...
    group.MeanBaselineMacroCVR2, group.MeanExpandedMacroCVR2, ...
    group.MeanDeltaMacroCVR2, group.DeltaMacroPartitionRange(1), ...
    group.DeltaMacroPartitionRange(2), ...
    group.MeanBaselinePooledCVR2, group.MeanExpandedPooledCVR2, ...
    'VariableNames', {'ModelVariant', 'Analysis', 'Area', 'UnitType', ...
    'NPopulationSessions', 'NSessions', 'NExcludedFromAnalysisCohort', ...
    'NObservations', 'Status', 'BaselineMacroOrdinaryR2', ...
    'ExpandedMacroOrdinaryR2', 'DeltaMacroOrdinaryR2', ...
    'BaselineMeanMacroCVR2', 'ExpandedMeanMacroCVR2', ...
    'MeanDeltaMacroCVR2', 'DeltaMacroPartitionP02_5', ...
    'DeltaMacroPartitionP97_5', 'BaselineMeanPooledCVR2', ...
    'ExpandedMeanPooledCVR2'});
end


function rows = conditionSummaryRows(group, allConditionNames)
conditionCount = numel(group.ConditionIndices);
variant = repmat(group.ModelVariant, conditionCount, 1);
analysis = repmat(group.Analysis, conditionCount, 1);
area = repmat(group.Area, conditionCount, 1);
unitType = repmat(group.UnitType, conditionCount, 1);
condition = allConditionNames(group.ConditionIndices)';
baselineOrdinary = group.FullBaseline.PerCueR2(:);
expandedOrdinary = group.FullExpanded.PerCueR2(:);
baselineCV = mean(group.CV.BaselinePerCueR2, 1, 'omitnan')';
expandedCV = mean(group.CV.ExpandedPerCueR2, 1, 'omitnan')';
deltaByRepeat = group.CV.ExpandedPerCueR2 - group.CV.BaselinePerCueR2;
deltaP02_5 = prctile(deltaByRepeat, 2.5, 1)';
deltaP97_5 = prctile(deltaByRepeat, 97.5, 1)';
n = group.ConditionObservationCounts(:);
baselineBeta = group.FullBaseline.Betas;
expandedBeta = group.FullExpanded.Betas;
baselineRMSE = group.FullBaseline.PerCueRMSE(:);
expandedRMSE = group.FullExpanded.PerCueRMSE(:);
rows = table(variant, analysis, area, unitType, condition, ...
    n, baselineOrdinary, expandedOrdinary, ...
    expandedOrdinary - baselineOrdinary, baselineCV, expandedCV, ...
    expandedCV - baselineCV, deltaP02_5, deltaP97_5, ...
    baselineRMSE, expandedRMSE, ...
    baselineBeta(:, 1), baselineBeta(:, 2), baselineBeta(:, 3), ...
    expandedBeta(:, 1), expandedBeta(:, 2), expandedBeta(:, 3), ...
    'VariableNames', {'ModelVariant', 'Analysis', 'Area', 'UnitType', ...
    'Condition', 'N', 'BaselineOrdinaryR2', 'ExpandedOrdinaryR2', ...
    'DeltaOrdinaryR2', 'BaselineMeanCVR2', 'ExpandedMeanCVR2', ...
    'MeanDeltaCVR2', 'DeltaCVPartitionP02_5', ...
    'DeltaCVPartitionP97_5', 'BaselineRMSE', 'ExpandedRMSE', ...
    'BaselineIntercept', 'BaselineBetaAI', 'BaselineBetaAIxOD', ...
    'ExpandedIntercept', 'ExpandedBetaAI', 'ExpandedBetaAIxOD'});
end


function row = fullWeightRow(group)
row = table(group.ModelVariant, group.Analysis, group.Area, ...
    group.UnitType, 'VariableNames', ...
    {'ModelVariant', 'Analysis', 'Area', 'UnitType'});
for positionIndex = 1:numel(group.RelativePositions)
    variable = weightVariableName(group.RelativePositions(positionIndex));
    row.(variable) = group.FullExpandedWeights(positionIndex);
end
end


function rows = foldWeightRows(group)
sampleCount = size(group.CV.WeightSamples, 1);
rows = table(repmat(group.ModelVariant, sampleCount, 1), ...
    repmat(group.Analysis, sampleCount, 1), ...
    repmat(group.Area, sampleCount, 1), ...
    repmat(group.UnitType, sampleCount, 1), (1:sampleCount)', ...
    'VariableNames', {'ModelVariant', 'Analysis', 'Area', 'UnitType', ...
    'FitIndex'});
for positionIndex = 1:numel(group.RelativePositions)
    variable = weightVariableName(group.RelativePositions(positionIndex));
    rows.(variable) = group.CV.WeightSamples(:, positionIndex);
end
end


function name = weightVariableName(position)
if position < 0
    name = sprintf('Weight_CHminus%d', abs(position));
elseif position > 0
    name = sprintf('Weight_CHplus%d', position);
else
    name = 'Weight_STIM';
end
end


function output = appendTable(output, rows)
if width(output) == 0
    output = rows;
else
    output = [output; rows];
end
end


function variants = canonicalVariants(input)
allowed = ["AIxOD", "AIOnly"];
variants = strings(size(input));
for index = 1:numel(input)
    match = find(strcmpi(input(index), allowed), 1);
    if isempty(match)
        error('WeightedMetaTuning:UnknownVariant', ...
            'Unknown model variant: %s.', input(index));
    end
    variants(index) = allowed(match);
end
variants = unique(variants, 'stable');
end


function analyses = canonicalAnalyses(input)
allowed = ["AllCue", "StereoOnly"];
analyses = strings(size(input));
for index = 1:numel(input)
    match = find(strcmpi(input(index), allowed), 1);
    if isempty(match)
        error('WeightedMetaTuning:UnknownAnalysis', ...
            'Unknown analysis: %s.', input(index));
    end
    analyses(index) = allowed(match);
end
analyses = unique(analyses, 'stable');
end


function validateCache(cache)
required = {'SessionStats', 'SessionTable', 'ConditionNames', ...
    'RelativePositions'};
missing = required(~isfield(cache, required));
if ~isempty(missing) || numel(cache.ConditionNames) ~= 4 || ...
        isempty(cache.RelativePositions) || ...
        numel(cache.SessionStats) ~= height(cache.SessionTable)
    error('WeightedMetaTuning:InvalidCache', ...
        'The weighted meta-tuning cache is incomplete.');
end
end

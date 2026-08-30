function result = FitAdjacentChannelBiasModels(observations, options)
%FITADJACENTCHANNELBIASMODELS Compare stimulation-only and neighbor models.
%
% Both nested models use the same complete-case sessions and the same repeated
% cross-validation folds within every area x unit-type x cue group:
%
%   Baseline: Bias ~ AI_STIM
%   Augmented: Bias ~ AI_CH-1 + AI_STIM + AI_CH+1
%
% NeighborRadius defaults to one but may be increased explicitly. The output
% retains fold-wise coefficients for silhouette/violin plots.

arguments
    observations table
    options.Areas (1, :) string = ["MT", "FST"]
    options.UnitTypes (1, :) string = ["2D", "3D"]
    options.Conditions (1, :) string = ...
        ["Dominant", "Combined", "Stereo", "NonDominant"]
    options.NeighborRadius (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 1
    options.NumRepeats (1, 1) double ...
        {mustBeInteger, mustBePositive} = 20
    options.NumFolds (1, 1) double ...
        {mustBeInteger, mustBeGreaterThan(options.NumFolds, 1)} = 5
    options.RandomSeed (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 1
    options.MinimumGroupSize (1, 1) double ...
        {mustBeInteger, mustBePositive} = 8
end

required = ["Area", "UnitType", "Condition", "Bias", "UnitTableRow"];
missing = setdiff(required, string(observations.Properties.VariableNames));
if ~isempty(missing)
    error('AdjacentChannelModel:MissingObservationVariables', ...
        'observations is missing variable(s): %s.', strjoin(missing, ', '));
end

relativePositions = -options.NeighborRadius:options.NeighborRadius;
predictorNames = strings(1, numel(relativePositions));
for index = 1:numel(relativePositions)
    predictorNames(index) = "AI_" + relativePositionTag( ...
        relativePositions(index));
end
missingPredictors = setdiff(predictorNames, ...
    string(observations.Properties.VariableNames));
if ~isempty(missingPredictors)
    error('AdjacentChannelModel:MissingPredictors', ...
        'observations is missing predictor(s): %s.', ...
        strjoin(missingPredictors, ', '));
end

areas = upper(strtrim(options.Areas));
unitTypes = upper(strtrim(options.UnitTypes));
conditions = canonicalConditionNames(options.Conditions);
baselinePredictorIndex = find(relativePositions == 0, 1);
baselinePredictor = predictorNames(baselinePredictorIndex);

groupCount = numel(areas) * numel(unitTypes) * numel(conditions);
groups = repmat(emptyGroupResult(), groupCount, 1);
groupSummary = table();
modelSummary = table();
coefficientSummary = table();

groupIndex = 0;
for area = areas
    for unitType = unitTypes
        for condition = conditions
            groupIndex = groupIndex + 1;
            group = emptyGroupResult();
            group.Area = area;
            group.UnitType = unitType;
            group.Condition = condition;
            group.RelativePositions = relativePositions;
            group.PredictorNames = predictorNames;
            group.BaselinePredictorName = baselinePredictor;

            selected = upper(string(observations.Area)) == area & ...
                upper(string(observations.UnitType)) == unitType & ...
                canonicalObservationConditions(observations.Condition) == ...
                condition;
            candidateRows = find(selected);
            group.CandidateObservationRows = candidateRows;

            if isempty(candidateRows)
                group.Status = "No observations";
                groups(groupIndex) = group;
                groupSummary = appendTable(groupSummary, ...
                    groupSummaryRow(group));
                continue
            end

            yCandidate = double(observations.Bias(candidateRows));
            xCandidate = double(observations{candidateRows, ...
                cellstr(predictorNames)});
            complete = isfinite(yCandidate) & all(isfinite(xCandidate), 2);
            matchedRows = candidateRows(complete);
            y = yCandidate(complete);
            x = xCandidate(complete, :);
            group.MatchedObservationRows = matchedRows;
            group.N = numel(y);

            minimumForRank = size(x, 2) + 3;
            requiredN = max(options.MinimumGroupSize, minimumForRank);
            if group.N < requiredN
                group.Status = sprintf( ...
                    'Too few complete cases (%d; need at least %d)', ...
                    group.N, requiredN);
                groups(groupIndex) = group;
                groupSummary = appendTable(groupSummary, ...
                    groupSummaryRow(group));
                continue
            end

            xBaseline = x(:, baselinePredictorIndex);
            baselineFormula = "Bias ~ " + baselinePredictor;
            augmentedFormula = "Bias ~ " + strjoin(predictorNames, " + ");
            baselineFit = fitLinearModel( ...
                xBaseline, y, baselinePredictor, baselineFormula);
            augmentedFit = fitLinearModel( ...
                x, y, predictorNames, augmentedFormula);
            group.BaselineFit = baselineFit;
            group.AugmentedFit = augmentedFit;

            if baselineFit.Status ~= "Success" || ...
                    augmentedFit.Status ~= "Success"
                group.Status = "Fit failed: baseline=" + ...
                    baselineFit.Status + "; augmented=" + ...
                    augmentedFit.Status;
                groups(groupIndex) = group;
                groupSummary = appendTable(groupSummary, ...
                    groupSummaryRow(group));
                continue
            end

            stableIndex = stableGroupIndex(area, unitType, condition);
            foldMatrix = repeatedBalancedFolds(group.N, options.NumFolds, ...
                options.NumRepeats, options.RandomSeed + 1000 * stableIndex);
            group.FoldMatrix = foldMatrix;
            augmentedParameterCount = size(x, 2) + 1;
            minimumTrainingCount = minimumTrainingRows(foldMatrix);
            if minimumTrainingCount <= augmentedParameterCount
                group.Status = sprintf( ...
                    'Too few training cases per fold (%d; need > %d)', ...
                    minimumTrainingCount, augmentedParameterCount);
                groups(groupIndex) = group;
                groupSummary = appendTable(groupSummary, ...
                    groupSummaryRow(group));
                continue
            end

            baselineCV = evaluateCrossValidation(xBaseline, y, foldMatrix);
            augmentedCV = evaluateCrossValidation(x, y, foldMatrix);
            pairedFinite = isfinite(baselineCV.R2ByRepeat) & ...
                isfinite(augmentedCV.R2ByRepeat);
            baselineCV = summarizeCVOnMask(baselineCV, pairedFinite);
            augmentedCV = summarizeCVOnMask(augmentedCV, pairedFinite);
            group.BaselineCV = baselineCV;
            group.AugmentedCV = augmentedCV;
            if nnz(pairedFinite) ~= options.NumRepeats
                group.Status = sprintf( ...
                    'Incomplete paired cross-validation (%d/%d repeats)', ...
                    nnz(pairedFinite), options.NumRepeats);
                groups(groupIndex) = group;
                groupSummary = appendTable(groupSummary, ...
                    groupSummaryRow(group));
                continue
            end

            pairedDeltaR2 = augmentedCV.R2ByRepeat - baselineCV.R2ByRepeat;
            validDelta = pairedDeltaR2(isfinite(pairedDeltaR2));
            if isempty(validDelta)
                meanDeltaCVR2 = nan;
                deltaCVR2PartitionRange = [nan nan];
            else
                meanDeltaCVR2 = mean(validDelta);
                deltaCVR2PartitionRange = prctile(validDelta, [2.5 97.5]);
            end

            group.PairedDeltaCVR2 = pairedDeltaR2;
            group.MeanDeltaCVR2 = meanDeltaCVR2;
            group.DeltaCVR2PartitionRange = deltaCVR2PartitionRange;
            group.ImprovesMeanCVR2 = isfinite(meanDeltaCVR2) && ...
                meanDeltaCVR2 > 0;
            group.PartitionRangeEntirelyPositive = ...
                isfinite(deltaCVR2PartitionRange(1)) && ...
                deltaCVR2PartitionRange(1) > 0;
            group.Status = "Success";
            groups(groupIndex) = group;

            groupSummary = appendTable(groupSummary, ...
                groupSummaryRow(group));
            modelSummary = appendTable(modelSummary, ...
                modelSummaryRows(group));
            coefficientSummary = appendTable(coefficientSummary, ...
                coefficientSummaryRows(group));
        end
    end
end

result = struct();
result.Analysis = "Adjacent-channel AI linear model comparison";
result.BaselineFormula = "Bias ~ AI_STIM";
result.AugmentedFormula = "Bias ~ " + ...
    strjoin(channelDisplayNames(relativePositions), " + ");
result.RelativePositions = relativePositions;
result.PredictorNames = predictorNames;
result.Areas = areas;
result.UnitTypes = unitTypes;
result.Conditions = conditions;
result.NumRepeats = options.NumRepeats;
result.NumFolds = options.NumFolds;
result.RandomSeed = options.RandomSeed;
result.MinimumGroupSize = options.MinimumGroupSize;
result.Groups = groups;
result.GroupSummary = groupSummary;
result.ModelSummary = modelSummary;
result.CoefficientSummary = coefficientSummary;
result.ObservationTable = observations;
end


function group = emptyGroupResult()
emptyFit = emptyFitResult();
emptyCV = emptyCVResult();
group = struct( ...
    'Area', "", ...
    'UnitType', "", ...
    'Condition', "", ...
    'N', 0, ...
    'RelativePositions', [], ...
    'PredictorNames', strings(1, 0), ...
    'BaselinePredictorName', "", ...
    'CandidateObservationRows', zeros(0, 1), ...
    'MatchedObservationRows', zeros(0, 1), ...
    'BaselineFit', emptyFit, ...
    'AugmentedFit', emptyFit, ...
    'BaselineCV', emptyCV, ...
    'AugmentedCV', emptyCV, ...
    'FoldMatrix', zeros(0, 0), ...
    'PairedDeltaCVR2', nan(0, 1), ...
    'MeanDeltaCVR2', nan, ...
    'DeltaCVR2PartitionRange', [nan nan], ...
    'ImprovesMeanCVR2', false, ...
    'PartitionRangeEntirelyPositive', false, ...
    'Status', "Not fit");
end


function fit = emptyFitResult()
fit = struct( ...
    'Status', "Not fit", ...
    'Formula', "", ...
    'N', 0, ...
    'PredictorNames', strings(1, 0), ...
    'CoefficientNames', strings(1, 0), ...
    'Estimate', nan(0, 1), ...
    'SE', nan(0, 1), ...
    'PValue', nan(0, 1), ...
    'OrdinaryR2', nan, ...
    'AdjustedR2', nan, ...
    'RMSE', nan);
end


function fit = fitLinearModel(x, y, predictorNames, formula)
fit = emptyFitResult();
fit.Formula = formula;
fit.N = numel(y);
fit.PredictorNames = predictorNames;

design = [ones(size(x, 1), 1), x];
if rank(design) < size(design, 2)
    fit.Status = "Rank deficient design";
    return
end

try
    input = array2table([y x], ...
        'VariableNames', cellstr(["Bias", predictorNames]));
    model = fitlm(input, char(formula));
    fit.CoefficientNames = string(model.CoefficientNames);
    fit.Estimate = model.Coefficients.Estimate;
    fit.SE = model.Coefficients.SE;
    fit.PValue = model.Coefficients.pValue;
    fit.OrdinaryR2 = model.Rsquared.Ordinary;
    fit.AdjustedR2 = model.Rsquared.Adjusted;
    fit.RMSE = model.RMSE;
    fit.Status = "Success";
catch modelError
    fit.Status = "Error: " + string(modelError.identifier) + ...
        " - " + string(modelError.message);
end
end


function foldMatrix = repeatedBalancedFolds( ...
    rowCount, foldCount, repeatCount, randomSeed)
foldCount = min(foldCount, rowCount);
foldMatrix = zeros(rowCount, repeatCount);
for repeatIndex = 1:repeatCount
    stream = RandStream('mt19937ar', ...
        'Seed', randomSeed + repeatIndex - 1);
    order = randperm(stream, rowCount);
    folds = zeros(rowCount, 1);
    folds(order) = mod(0:rowCount-1, foldCount) + 1;
    foldMatrix(:, repeatIndex) = folds;
end
end


function minimumCount = minimumTrainingRows(foldMatrix)
minimumCount = inf;
for repeatIndex = 1:size(foldMatrix, 2)
    folds = foldMatrix(:, repeatIndex);
    for foldLabel = unique(folds)'
        minimumCount = min(minimumCount, nnz(folds ~= foldLabel));
    end
end
end


function index = stableGroupIndex(area, unitType, condition)
canonicalAreas = ["MT", "FST"];
canonicalUnitTypes = ["2D", "3D"];
canonicalConditions = ["Dominant", "Combined", "Stereo", "NonDominant"];
areaIndex = find(canonicalAreas == area, 1);
unitTypeIndex = find(canonicalUnitTypes == unitType, 1);
conditionIndex = find(canonicalConditions == condition, 1);
index = ((areaIndex - 1) * numel(canonicalUnitTypes) + ...
    (unitTypeIndex - 1)) * numel(canonicalConditions) + conditionIndex;
end


function cv = emptyCVResult()
cv = struct( ...
    'FoldMatrix', zeros(0, 0), ...
    'PredictionByRepeat', nan(0, 0), ...
    'NullPredictionByRepeat', nan(0, 0), ...
    'BetaSamples', nan(0, 0), ...
    'R2ByRepeat', nan(0, 1), ...
    'MeanR2', nan, ...
    'SDR2', nan, ...
    'SEMR2', nan, ...
    'R2PartitionRange', [nan nan]);
end


function cv = evaluateCrossValidation(x, y, foldMatrix)
rowCount = numel(y);
repeatCount = size(foldMatrix, 2);
foldCount = max(foldMatrix, [], 'all');
parameterCount = size(x, 2) + 1;
prediction = nan(rowCount, repeatCount);
nullPrediction = nan(rowCount, repeatCount);
betaSamples = nan(repeatCount * foldCount, parameterCount);
r2ByRepeat = nan(repeatCount, 1);
writeIndex = 0;

for repeatIndex = 1:repeatCount
    folds = foldMatrix(:, repeatIndex);
    for foldIndex = 1:foldCount
        test = folds == foldIndex;
        train = ~test;
        trainDesign = [ones(nnz(train), 1), x(train, :)];
        if nnz(test) == 0 || nnz(train) <= parameterCount || ...
                rank(trainDesign) < parameterCount
            continue
        end
        beta = trainDesign \ y(train);
        prediction(test, repeatIndex) = ...
            [ones(nnz(test), 1), x(test, :)] * beta;
        nullPrediction(test, repeatIndex) = mean(y(train));
        writeIndex = writeIndex + 1;
        betaSamples(writeIndex, :) = beta(:)';
    end

    if all(isfinite(prediction(:, repeatIndex))) && ...
            all(isfinite(nullPrediction(:, repeatIndex)))
        r2ByRepeat(repeatIndex) = crossValidatedR2( ...
            y, prediction(:, repeatIndex), ...
            nullPrediction(:, repeatIndex));
    end
end
betaSamples = betaSamples(1:writeIndex, :);
validR2 = r2ByRepeat(isfinite(r2ByRepeat));
cv = emptyCVResult();
cv.FoldMatrix = foldMatrix;
cv.PredictionByRepeat = prediction;
cv.NullPredictionByRepeat = nullPrediction;
cv.BetaSamples = betaSamples;
cv.R2ByRepeat = r2ByRepeat;
if ~isempty(validR2)
    cv.MeanR2 = mean(validR2);
    cv.SDR2 = std(validR2);
    cv.SEMR2 = cv.SDR2 ./ sqrt(numel(validR2));
    cv.R2PartitionRange = prctile(validR2, [2.5 97.5]);
end
end


function cv = summarizeCVOnMask(cv, mask)
validR2 = cv.R2ByRepeat(mask & isfinite(cv.R2ByRepeat));
cv.MeanR2 = nan;
cv.SDR2 = nan;
cv.SEMR2 = nan;
cv.R2PartitionRange = [nan nan];
if isempty(validR2)
    return
end
cv.MeanR2 = mean(validR2);
cv.SDR2 = std(validR2);
cv.SEMR2 = cv.SDR2 ./ sqrt(numel(validR2));
cv.R2PartitionRange = prctile(validR2, [2.5 97.5]);
end


function value = crossValidatedR2(observed, predicted, nullPredicted)
valid = isfinite(observed) & isfinite(predicted) & ...
    isfinite(nullPredicted);
modelSSE = sum((observed(valid) - predicted(valid)) .^ 2);
nullSSE = sum((observed(valid) - nullPredicted(valid)) .^ 2);
if nnz(valid) < 3 || nullSSE <= eps
    value = nan;
else
    value = 1 - modelSSE ./ nullSSE;
end
end


function row = groupSummaryRow(group)
row = table(group.Area, group.UnitType, group.Condition, group.N, ...
    string(group.Status), group.BaselineFit.OrdinaryR2, ...
    group.AugmentedFit.OrdinaryR2, ...
    group.AugmentedFit.OrdinaryR2 - group.BaselineFit.OrdinaryR2, ...
    group.BaselineFit.AdjustedR2, group.AugmentedFit.AdjustedR2, ...
    group.AugmentedFit.AdjustedR2 - group.BaselineFit.AdjustedR2, ...
    group.BaselineCV.MeanR2, group.AugmentedCV.MeanR2, ...
    group.MeanDeltaCVR2, group.DeltaCVR2PartitionRange(1), ...
    group.DeltaCVR2PartitionRange(2), group.ImprovesMeanCVR2, ...
    group.PartitionRangeEntirelyPositive, ...
    'VariableNames', {'Area', 'UnitType', 'Condition', 'N', 'Status', ...
    'BaselineOrdinaryR2', 'AdjacentOrdinaryR2', 'DeltaOrdinaryR2', ...
    'BaselineAdjustedR2', 'AdjacentAdjustedR2', 'DeltaAdjustedR2', ...
    'BaselineMeanCVR2', 'AdjacentMeanCVR2', 'MeanDeltaCVR2', ...
    'DeltaCVR2PartitionP02_5', 'DeltaCVR2PartitionP97_5', ...
    'ImprovesMeanCVR2', 'PartitionRangeEntirelyPositive'});
end


function rows = modelSummaryRows(group)
rows = [modelSummaryRow(group, "Baseline", group.BaselineFit, ...
    group.BaselineCV); ...
    modelSummaryRow(group, "Adjacent", group.AugmentedFit, ...
    group.AugmentedCV)];
end


function row = modelSummaryRow(group, modelName, fit, cv)
row = table(group.Area, group.UnitType, group.Condition, modelName, ...
    string(fit.Formula), fit.N, fit.OrdinaryR2, fit.AdjustedR2, ...
    fit.RMSE, cv.MeanR2, cv.SDR2, cv.SEMR2, ...
    cv.R2PartitionRange(1), cv.R2PartitionRange(2), ...
    'VariableNames', {'Area', 'UnitType', 'Condition', 'Model', ...
    'Formula', 'N', 'OrdinaryR2', 'AdjustedR2', 'RMSE', ...
    'MeanCrossValidatedR2', 'SDCrossValidatedR2', ...
    'SEMCrossValidatedR2', 'CrossValidatedR2PartitionP02_5', ...
    'CrossValidatedR2PartitionP97_5'});
end


function rows = coefficientSummaryRows(group)
rows = [coefficientSummaryForModel(group, "Baseline", ...
    group.BaselineFit, group.BaselineCV); ...
    coefficientSummaryForModel(group, "Adjacent", ...
    group.AugmentedFit, group.AugmentedCV)];
end


function rows = coefficientSummaryForModel(group, modelName, fit, cv)
coefficientNames = string(fit.CoefficientNames(:));
rowCount = numel(coefficientNames);
area = repmat(group.Area, rowCount, 1);
unitType = repmat(group.UnitType, rowCount, 1);
condition = repmat(group.Condition, rowCount, 1);
model = repmat(modelName, rowCount, 1);
predictor = coefficientNames;
fullEstimate = fit.Estimate(:);
fullSE = fit.SE(:);
fullPValue = fit.PValue(:);
cvMean = nan(rowCount, 1);
cvSD = nan(rowCount, 1);
cvMedian = nan(rowCount, 1);
cvFoldP02_5 = nan(rowCount, 1);
cvFoldP97_5 = nan(rowCount, 1);

for coefficientIndex = 1:rowCount
    if coefficientIndex > size(cv.BetaSamples, 2)
        continue
    end
    values = cv.BetaSamples(:, coefficientIndex);
    values = values(isfinite(values));
    if isempty(values)
        continue
    end
    cvMean(coefficientIndex) = mean(values);
    cvSD(coefficientIndex) = std(values);
    cvMedian(coefficientIndex) = median(values);
    interval = prctile(values, [2.5 97.5]);
    cvFoldP02_5(coefficientIndex) = interval(1);
    cvFoldP97_5(coefficientIndex) = interval(2);
end

rows = table(area, unitType, condition, model, predictor, fullEstimate, ...
    fullSE, fullPValue, cvMean, cvSD, cvMedian, ...
    cvFoldP02_5, cvFoldP97_5, ...
    'VariableNames', {'Area', 'UnitType', 'Condition', 'Model', ...
    'Predictor', 'FullEstimate', 'FullSE', 'FullPValue', ...
    'CVFoldMean', 'CVFoldSD', 'CVFoldMedian', ...
    'CVFoldPercentile02_5', 'CVFoldPercentile97_5'});
end


function output = appendTable(output, rows)
if width(output) == 0
    output = rows;
else
    output = [output; rows];
end
end


function conditions = canonicalConditionNames(inputConditions)
canonical = ["Dominant", "Combined", "Stereo", "NonDominant"];
conditions = strings(size(inputConditions));
for index = 1:numel(inputConditions)
    normalized = lower(regexprep(strtrim(inputConditions(index)), ...
        '[^a-zA-Z]', ''));
    matchIndex = find(lower(canonical) == normalized, 1);
    if isempty(matchIndex)
        error('AdjacentChannelModel:UnknownCondition', ...
            'Unknown condition "%s".', inputConditions(index));
    end
    conditions(index) = canonical(matchIndex);
end
conditions = unique(conditions, 'stable');
end


function conditions = canonicalObservationConditions(inputConditions)
conditions = strings(size(inputConditions));
for index = 1:numel(inputConditions)
    conditions(index) = canonicalConditionNames( ...
        string(inputConditions(index)));
end
end


function names = channelDisplayNames(relativePositions)
names = strings(size(relativePositions));
for index = 1:numel(relativePositions)
    position = relativePositions(index);
    if position < 0
        names(index) = "AI_CH" + position;
    elseif position > 0
        names(index) = "AI_CH+" + position;
    else
        names(index) = "AI_STIM";
    end
end
end


function tag = relativePositionTag(relativePosition)
if relativePosition < 0
    tag = sprintf('m%02d', abs(relativePosition));
elseif relativePosition > 0
    tag = sprintf('p%02d', relativePosition);
else
    tag = 'zero';
end
end

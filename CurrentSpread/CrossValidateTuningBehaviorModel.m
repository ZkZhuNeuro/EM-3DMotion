function result = CrossValidateTuningBehaviorModel(biasTable, unitType, options)
%CROSSVALIDATETUNINGBEHAVIORMODEL Session-grouped held-out prediction.
%
% 2D populations use the established merged-eye model:
%
%   MergedEyeBias = beta0 + beta1*AI + beta2*(AI*OD)
%
% using dominant and sign-flipped non-dominant observations. 3D
% populations use four cue-specific models:
%
%   Bias_cue = beta0_cue + beta1_cue*AI_cue
%
% Every observation from one SourceTableRow is held out together. Reported
% R-squared compares model SSE with predictions from the matching training-
% fold mean (and the matching cue mean for 3D).

arguments
    biasTable table
    unitType (1, 1) string {mustBeMember(unitType, ["2D", "3D"])}
    options.NumRepeats (1, 1) double ...
        {mustBeInteger, mustBePositive} = 25
    options.NumFolds (1, 1) double ...
        {mustBeInteger, mustBeGreaterThan(options.NumFolds, 1)} = 5
    options.RandomSeed (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 1
    options.MinimumSessions (1, 1) double ...
        {mustBeInteger, mustBePositive} = 5
end

required = ["AI", "Bias", "OD", "Condition", "UnitType", ...
    "SourceTableRow", "Monkey"];
missing = setdiff(required, string(biasTable.Properties.VariableNames));
if ~isempty(missing)
    error('TuningBehaviorCV:MissingVariables', ...
        'Missing required variable(s): %s.', join(missing, ', '));
end
selected = string(biasTable.UnitType) == unitType;
input = biasTable(selected, :);
if unitType == "2D"
    if ~ismember('MergedEyeBias', input.Properties.VariableNames)
        error('TuningBehaviorCV:MissingMergedEyeBias', ...
            'The 2D model requires MergedEyeBias.');
    end
    input = input(ismember(input.Condition, [1 4]), :);
    observed = input.MergedEyeBias;
    modelName = "Merged-eye AI + AI:OD";
else
    observed = input.Bias;
    modelName = "Four cue-specific AI models";
end

valid = isfinite(input.AI) & isfinite(observed) & ...
    isfinite(input.SourceTableRow);
if unitType == "2D"
    valid = valid & isfinite(input.OD);
end
input = input(valid, :);
observed = observed(valid);
sessionIDs = unique(input.SourceTableRow, 'stable');
sessionCount = numel(sessionIDs);

result = struct();
result.UnitType = unitType;
result.ModelName = modelName;
result.SessionCount = sessionCount;
result.ObservationCount = height(input);
result.NumRepeats = options.NumRepeats;
result.NumFolds = min(options.NumFolds, sessionCount);
result.RandomSeed = options.RandomSeed;
result.Status = "Success";
result.R2ByRepeat = nan(options.NumRepeats, 1);
result.RMSEByRepeat = nan(options.NumRepeats, 1);
result.PearsonRByRepeat = nan(options.NumRepeats, 1);
result.PredictionByRepeat = nan(height(input), options.NumRepeats);
result.NullPredictionByRepeat = nan(height(input), options.NumRepeats);
result.Observed = observed;
result.ObservationTable = input;
result.FoldBySession = nan(sessionCount, options.NumRepeats);

if sessionCount < options.MinimumSessions || result.NumFolds < 2
    result.Status = "InsufficientSessions";
    result.MeanR2 = NaN;
    result.MeanRMSE = NaN;
    result.MeanPearsonR = NaN;
    result.MeanHeldOutPrediction = nan(height(input), 1);
    result.MeanNullPrediction = nan(height(input), 1);
    return
end

observationSessionIndex = sessionMembership( ...
    input.SourceTableRow, sessionIDs);
for repeat = 1:options.NumRepeats
    folds = balancedFolds(sessionCount, result.NumFolds, ...
        options.RandomSeed + repeat - 1);
    result.FoldBySession(:, repeat) = folds;
    [prediction, nullPrediction] = oneCrossValidation( ...
        input, observed, observationSessionIndex, folds, unitType);
    result.PredictionByRepeat(:, repeat) = prediction;
    result.NullPredictionByRepeat(:, repeat) = nullPrediction;
    [result.R2ByRepeat(repeat), result.RMSEByRepeat(repeat), ...
        result.PearsonRByRepeat(repeat)] = predictionMetrics( ...
        observed, prediction, nullPrediction);
end
result.MeanR2 = mean(result.R2ByRepeat, 'omitmissing');
result.MeanRMSE = mean(result.RMSEByRepeat, 'omitmissing');
result.MeanPearsonR = mean(result.PearsonRByRepeat, 'omitmissing');
result.MeanHeldOutPrediction = ...
    mean(result.PredictionByRepeat, 2, 'omitmissing');
result.MeanNullPrediction = ...
    mean(result.NullPredictionByRepeat, 2, 'omitmissing');
end


function [prediction, nullPrediction] = oneCrossValidation( ...
    input, observed, observationSessionIndex, folds, unitType)
prediction = nan(height(input), 1);
nullPrediction = nan(height(input), 1);
for fold = unique(folds)'
    test = folds(observationSessionIndex) == fold;
    train = ~test;
    if unitType == "2D"
        trainDesign = [ones(nnz(train), 1), input.AI(train), ...
            input.AI(train) .* input.OD(train)];
        testDesign = [ones(nnz(test), 1), input.AI(test), ...
            input.AI(test) .* input.OD(test)];
        beta = safeLeastSquares(trainDesign, observed(train));
        if all(isfinite(beta))
            prediction(test) = testDesign * beta;
        end
        nullPrediction(test) = mean(observed(train), 'omitmissing');
    else
        for condition = 1:4
            conditionTrain = train & input.Condition == condition;
            conditionTest = test & input.Condition == condition;
            if ~any(conditionTest)
                continue
            end
            trainDesign = [ones(nnz(conditionTrain), 1), ...
                input.AI(conditionTrain)];
            testDesign = [ones(nnz(conditionTest), 1), ...
                input.AI(conditionTest)];
            beta = safeLeastSquares( ...
                trainDesign, observed(conditionTrain));
            if all(isfinite(beta))
                prediction(conditionTest) = testDesign * beta;
            end
            nullPrediction(conditionTest) = ...
                mean(observed(conditionTrain), 'omitmissing');
        end
    end
end
end


function beta = safeLeastSquares(design, response)
valid = all(isfinite(design), 2) & isfinite(response);
design = design(valid, :);
response = response(valid);
if size(design, 1) <= size(design, 2) || ...
        rank(design) < size(design, 2)
    beta = nan(size(design, 2), 1);
else
    beta = design \ response;
end
end


function [r2, rmse, pearsonR] = predictionMetrics( ...
    observed, predicted, nullPredicted)
valid = isfinite(observed) & isfinite(predicted) & ...
    isfinite(nullPredicted);
if nnz(valid) < 3
    r2 = NaN;
    rmse = NaN;
    pearsonR = NaN;
    return
end
residual = observed(valid) - predicted(valid);
nullResidual = observed(valid) - nullPredicted(valid);
modelSSE = sum(residual .^ 2);
nullSSE = sum(nullResidual .^ 2);
if nullSSE <= eps
    r2 = NaN;
else
    r2 = 1 - modelSSE ./ nullSSE;
end
rmse = sqrt(mean(residual .^ 2));
if std(observed(valid)) <= eps || std(predicted(valid)) <= eps
    pearsonR = NaN;
else
    pearsonR = corr(observed(valid), predicted(valid));
end
end


function membership = sessionMembership(values, uniqueValues)
[found, membership] = ismember(values, uniqueValues);
if ~all(found)
    error('TuningBehaviorCV:SessionMapping', ...
        'At least one observation could not be mapped to a session.');
end
end


function folds = balancedFolds(rowCount, foldCount, seed)
stream = RandStream('mt19937ar', 'Seed', mod(seed, 2^32 - 1));
order = randperm(stream, rowCount);
folds = zeros(rowCount, 1);
folds(order) = mod(0:rowCount - 1, foldCount) + 1;
end

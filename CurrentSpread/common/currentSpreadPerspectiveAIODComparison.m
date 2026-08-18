function result = currentSpreadPerspectiveAIODComparison(paths, options)
%CURRENTSPREADPERSPECTIVEAIODCOMPARISON Compare original and Gaussian AI/OD.
%
% Dominant- and non-dominant-eye perspective conditions are assigned separately
% for each method from that method's signed OD. The non-dominant-eye Delta Bias
% is then negated using the population-analysis convention. Channel-AI models
% use the signed mean OD across available channels. FR models calculate signed
% OD from the Gaussian-weighted raw meta-tuning curves.
% Gaussian widths are optimized using combined-cue data only. Those widths are
% then held fixed for the perspective-cue plot and session-grouped repeated
% cross-validation of:
%   MergedEyeBias = beta0 + beta1 * AI + beta2 * (AI * abs(OD)).

arguments
    paths (1, 1) struct
    options.NumRepeats (1, 1) double {mustBeInteger, mustBePositive} = 5
    options.NumFolds (1, 1) double {mustBeInteger, ...
        mustBeGreaterThan(options.NumFolds, 1)} = 5
    options.RandomSeed (1, 1) double {mustBeInteger, mustBeNonnegative} = 1
    options.SigmaValues (1, :) double = logspace(-2, 2, 41)
end

sigmaValues = sort(unique(options.SigmaValues(:)));
if isempty(sigmaValues) || any(~isfinite(sigmaValues)) || any(sigmaValues <= 0)
    error('CurrentSpread:SigmaValues', ...
        'SigmaValues must contain finite positive values.');
end

combinedAIOptimization = currentSpreadCombinedCueGaussianSigmaR2( ...
    paths, "gaussian-ai", NumRepeats=options.NumRepeats, ...
    NumFolds=options.NumFolds, RandomSeed=options.RandomSeed, ...
    SigmaValues=sigmaValues');
combinedFROptimization = currentSpreadCombinedCueGaussianSigmaR2( ...
    paths, "gaussian-fr", NumRepeats=options.NumRepeats, ...
    NumFolds=options.NumFolds, RandomSeed=options.RandomSeed, ...
    SigmaValues=sigmaValues');
channelSigma = combinedAIOptimization.bestSigma;
frSigma = combinedFROptimization.bestSigma;

unitData = load(paths.unitTableGof, 'unit_table_gof');
unitTableAll = unitData.unit_table_gof;
[selection, rawBehaviorByCue] = selectPerspectiveSessions(unitTableAll);
unitTable = unitTableAll(selection, :);
rawBehaviorByCue = rawBehaviorByCue(selection, :);

neuroData = load(paths.neuroAll, 'NeuroAll');
neuroIndex = unitTable.OriginalRecIdx;
if any(~isfinite(neuroIndex)) || any(neuroIndex < 1) || ...
        any(neuroIndex > numel(neuroData.NeuroAll))
    error('CurrentSpread:NeuroIndex', ...
        'Selected unit_table_gof rows do not map to NeuroAll via OriginalRecIdx.');
end

channelMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10];
maxRadius = 7;
positionOffset = (-maxRadius:maxRadius)';
[alignedAI, alignedOD, alignedFRZ, alignedFRRaw] = alignPerspectiveData( ...
    unitTable, neuroData.NeuroAll(neuroIndex), channelMap, maxRadius);

numSessions = height(unitTable);
channelSignedOD = mean(alignedOD, 2, 'omitnan');
channelWeights = gaussianPositionWeights(positionOffset, channelSigma);
frWeights = gaussianPositionWeights(positionOffset, frSigma);
channelAIByCue = weightedMatrix(alignedAI, channelWeights);
[frAIByCue, frSignedOD] = weightedFiringRateAIOD( ...
    alignedFRZ, alignedFRRaw, frWeights);

originalAIByCue = NaN(numSessions, 2);
originalSignedOD = NaN(numSessions, 1);
for session = 1:numSessions
    stimulationChannel = unitTable.StimElec(session);
    aiValues = unitTable.AI{session};
    originalAIByCue(session, :) = aiValues([2, 3], stimulationChannel)';
    originalSignedOD(session) = unitTable.OD_max{session};
end

[originalAI, originalBehavior, originalDominantCue, originalNonDominantCue] = ...
    assignDominance(originalAIByCue, rawBehaviorByCue, originalSignedOD);
[channelAI, channelBehavior, channelDominantCue, channelNonDominantCue] = ...
    assignDominance(channelAIByCue, rawBehaviorByCue, channelSignedOD);
[frAI, frBehavior, frDominantCue, frNonDominantCue] = ...
    assignDominance(frAIByCue, rawBehaviorByCue, frSignedOD);
originalOD = abs(originalSignedOD);
channelAverageOD = abs(channelSignedOD);
frOD = abs(frSignedOD);

numRepeats = options.NumRepeats;
numFolds = min(options.NumFolds, numSessions);
originalR2ByRepeat = crossValidatedAIOD(originalAI, originalOD, ...
    originalBehavior, ...
    numRepeats, numFolds, options.RandomSeed);
channelR2ByRepeat = crossValidatedAIOD(channelAI, channelAverageOD, ...
    channelBehavior, ...
    numRepeats, numFolds, options.RandomSeed);
frR2ByRepeat = crossValidatedAIOD(frAI, frOD, frBehavior, ...
    numRepeats, numFolds, options.RandomSeed);

methods(1) = summarizeMethod("Original stimulation electrode", NaN, ...
    originalAI, originalOD, originalBehavior, ...
    mean(originalR2ByRepeat, 'omitnan'), ...
    "Absolute OD_max at the stimulation electrode; sign assigns eye", ...
    originalDominantCue, originalDominantCue, originalSignedOD);
methods(2) = summarizeMethod("Gaussian channel AI + mean channel OD", ...
    channelSigma, channelAI, channelAverageOD, channelBehavior, ...
    mean(channelR2ByRepeat, 'omitnan'), ...
    "Absolute signed mean OD_max_all across available aligned channels; sign assigns eye", ...
    channelDominantCue, originalDominantCue, channelSignedOD);
methods(3) = summarizeMethod("Gaussian firing-rate meta-tuning AI + OD", ...
    frSigma, frAI, frOD, frBehavior, mean(frR2ByRepeat, 'omitnan'), ...
    "Absolute normalized left-right maximum-response difference; sign assigns eye", ...
    frDominantCue, originalDominantCue, frSignedOD);

summaryTable = table( ...
    vertcat(methods.name), vertcat(methods.odDefinition), ...
    vertcat(methods.sigma), ...
    vertcat(methods.dominanceFlipCount), ...
    vertcat(methods.numPoints), vertcat(methods.numSessions), ...
    vertcat(methods.crossValidatedR2), vertcat(methods.fullModelR2), ...
    vertcat(methods.pAI), vertcat(methods.pAIxOD), ...
    'VariableNames', {'Method', 'ODDefinition', 'Sigma', ...
    'DominanceFlipCount', 'NPoints', 'NSessions', ...
    'MeanCrossValidatedR2', 'FullModelR2', 'P_AI', 'P_AIxOD'});

pointTable = table();
for methodIndex = 1:numel(methods)
    methodPoints = methods(methodIndex).pointTable;
    methodPoints.Method = repmat(methods(methodIndex).name, ...
        height(methodPoints), 1);
    methodPoints = movevars(methodPoints, 'Method', 'Before', 1);
    pointTable = [pointTable; methodPoints]; %#ok<AGROW>
end

result = struct();
result.modelEquation = ...
    "MergedEyeBias = beta0 + beta1 * AI + beta2 * (AI * abs(OD))";
result.optimizationTarget = ...
    "Sigma selected by combined-cue cross-validated R-squared only";
result.sourceTable = string(paths.unitTableGof);
result.behaviorField = ["Behav_bias_NminusS cues 2/3"; ...
    "method-specific non-dominant eye negated after signed-OD assignment"];
result.selectionRule = ["Jim"; "MT"; "ND = 2D"; ...
    "perspective-cue p_AI(2:3) < 0.05"; ...
    "valid perspective-cue behavioral fits"];
result.originalRowIndex = find(selection);
result.sessionCount = numSessions;
result.rawBehaviorByCue = rawBehaviorByCue;
result.dominantCue = originalDominantCue;
result.nonDominantCue = originalNonDominantCue;
result.originalDominantCue = originalDominantCue;
result.originalNonDominantCue = originalNonDominantCue;
result.channelDominantCue = channelDominantCue;
result.channelNonDominantCue = channelNonDominantCue;
result.frDominantCue = frDominantCue;
result.frNonDominantCue = frNonDominantCue;
result.originalBehavior = originalBehavior;
result.channelBehavior = channelBehavior;
result.frBehavior = frBehavior;
result.positionOffset = positionOffset;
result.sigmaValues = sigmaValues;
result.channelSigma = channelSigma;
result.frSigma = frSigma;
result.channelWeights = channelWeights;
result.frWeights = frWeights;
result.channelAverageOD = channelAverageOD;
result.frOD = frOD;
result.originalSignedOD = originalSignedOD;
result.channelSignedOD = channelSignedOD;
result.frSignedOD = frSignedOD;
result.originalR2ByRepeat = originalR2ByRepeat;
result.channelR2ByRepeat = channelR2ByRepeat;
result.frR2ByRepeat = frR2ByRepeat;
result.combinedAIOptimization = combinedAIOptimization;
result.combinedFROptimization = combinedFROptimization;
result.methods = methods;
result.summaryTable = summaryTable;
result.pointTable = pointTable;
result.numRepeats = numRepeats;
result.numFolds = numFolds;
result.randomSeed = options.RandomSeed;
end

function [selection, rawBehaviorByCue] = selectPerspectiveSessions(unitTable)
numRows = height(unitTable);
selection = false(numRows, 1);
rawBehaviorByCue = NaN(numRows, 2);

for row = 1:numRows
    isJimMT = strcmp(unitTable.ROI{row}, 'MT') && ...
        strcmp(unitTable.Monkey{row}, 'Jim');
    is2D = strcmp(unitTable.ND{row}, '2D');
    pAI = unitTable.p_AI{row};
    isPerspectiveTuned = numel(pAI) >= 3 && pAI(2) < 0.05 && pAI(3) < 0.05;
    if ~(isJimMT && is2D && isPerspectiveTuned)
        continue
    end

    bias = unitTable.Behav_bias_NminusS{row};
    goodFit = unitTable.Behav_goodfit_both{row};
    if numel(bias) < 3 || numel(goodFit) < 3
        continue
    end
    cue2Valid = logical(goodFit(2)) && isfinite(bias(2));
    cue3Valid = logical(goodFit(3)) && isfinite(bias(3));
    if ~(cue2Valid || cue3Valid)
        continue
    end

    if cue2Valid
        rawBehaviorByCue(row, 1) = bias(2);
    end
    if cue3Valid
        rawBehaviorByCue(row, 2) = bias(3);
    end
    selection(row) = true;
end
end

function [alignedAI, alignedOD, alignedFRZ, alignedFRRaw] = alignPerspectiveData( ...
        unitTable, neuroAll, channelMap, maxRadius)
numSessions = height(unitTable);
numPositions = 2 * maxRadius + 1;
alignedAI = NaN(numSessions, 2, numPositions);
alignedOD = NaN(numSessions, numPositions);
alignedFRZ = cell(numSessions, numPositions);
alignedFRRaw = cell(numSessions, numPositions);

for session = 1:numSessions
    stimulationIndex = find(channelMap == unitTable.StimElec(session), 1);
    deadChannels = unitTable.DeadChannel{session};
    aiValues = unitTable.AI{session};
    odValues = unitTable.OD_max_all{session};
    recording = neuroAll{session};
    coherenceIndex = [1:4, size(recording, 2)-3:size(recording, 2)];

    for relativePosition = -maxRadius:maxRadius
        probeIndex = stimulationIndex + relativePosition;
        outputIndex = relativePosition + maxRadius + 1;
        if probeIndex < 1 || probeIndex > numel(channelMap)
            continue
        end
        channel = channelMap(probeIndex);
        if ismember(channel, deadChannels)
            continue
        end

        alignedAI(session, :, outputIndex) = aiValues([2, 3], channel)';
        if numel(odValues) >= channel
            alignedOD(session, outputIndex) = odValues(channel);
        end

        channelDataAll = recording(:, :, :, channel);
        channelMean = mean(channelDataAll, 'all', 'omitnan');
        channelStd = std(channelDataAll, 0, 'all', 'omitnan');
        if isfinite(channelStd) && channelStd > 0
            channelData = channelDataAll([2, 3], coherenceIndex, :);
            alignedFRRaw{session, outputIndex} = channelData;
            alignedFRZ{session, outputIndex} = ...
                (channelData - channelMean) ./ channelStd;
        end
    end
end
end

function weighted = weightedMatrix(data, weights)
numSessions = size(data, 1);
if ismatrix(data)
    weighted = NaN(numSessions, 1);
    for session = 1:numSessions
        values = data(session, :)';
        available = isfinite(values);
        if any(available)
            weighted(session) = sum(values(available) .* weights(available)) ./ ...
                sum(weights(available));
        end
    end
else
    weighted = NaN(numSessions, size(data, 2));
    for session = 1:numSessions
        for eye = 1:size(data, 2)
            values = squeeze(data(session, eye, :));
            available = isfinite(values);
            if any(available)
                weighted(session, eye) = ...
                    sum(values(available) .* weights(available)) ./ ...
                    sum(weights(available));
            end
        end
    end
end
end

function [orderedAI, mergedBehavior, dominantCue, nonDominantCue] = ...
        assignDominance(aiByCue, rawBehaviorByCue, signedOD)
numSessions = size(aiByCue, 1);
orderedAI = NaN(numSessions, 2);
mergedBehavior = NaN(numSessions, 2);
dominantCue = NaN(numSessions, 1);
nonDominantCue = NaN(numSessions, 1);

for session = 1:numSessions
    if ~isfinite(signedOD(session))
        continue
    end
    if signedOD(session) > 0
        cueOrder = [1, 2];
    else
        cueOrder = [2, 1];
    end
    dominantCue(session) = cueOrder(1) + 1;
    nonDominantCue(session) = cueOrder(2) + 1;
    orderedAI(session, :) = aiByCue(session, cueOrder);
    mergedBehavior(session, 1) = rawBehaviorByCue(session, cueOrder(1));
    mergedBehavior(session, 2) = -rawBehaviorByCue(session, cueOrder(2));
end
end

function [ai, od] = weightedFiringRateAIOD(alignedFRZ, alignedFRRaw, weights)
numSessions = size(alignedFRZ, 1);
ai = NaN(numSessions, 2);
od = NaN(numSessions, 1);

for session = 1:numSessions
    weightedZ = [];
    weightedRaw = [];
    totalWeight = 0;
    for position = 1:size(alignedFRZ, 2)
        responseZ = alignedFRZ{session, position};
        responseRaw = alignedFRRaw{session, position};
        if isempty(responseZ) || isempty(responseRaw) || ...
                ~any(isfinite(responseZ), 'all') || ...
                weights(position) <= eps
            continue
        end
        if isempty(weightedZ)
            weightedZ = zeros(size(responseZ));
            weightedRaw = zeros(size(responseRaw));
        end
        responseZ(~isfinite(responseZ)) = 0;
        responseRaw(~isfinite(responseRaw)) = 0;
        weightedZ = weightedZ + weights(position) .* responseZ;
        weightedRaw = weightedRaw + weights(position) .* responseRaw;
        totalWeight = totalWeight + weights(position);
    end
    if totalWeight <= eps || isempty(weightedZ)
        continue
    end
    metaTuningZ = weightedZ ./ totalWeight;
    metaTuningRaw = weightedRaw ./ totalWeight;
    ai(session, :) = [asymmetryIndex(squeeze(metaTuningZ(1, :, :))), ...
        asymmetryIndex(squeeze(metaTuningZ(2, :, :)))];
    od(session) = metaTuningOD(metaTuningRaw);
end
end

function value = metaTuningOD(metaTuning)
leftCurve = squeeze(mean(metaTuning(1, :, :), 3, 'omitnan'));
rightCurve = squeeze(mean(metaTuning(2, :, :), 3, 'omitnan'));
leftMaximum = max(leftCurve, [], 'omitnan');
rightMaximum = max(rightCurve, [], 'omitnan');
denominator = leftMaximum + rightMaximum;
if ~isfinite(denominator) || abs(denominator) <= eps
    value = NaN;
else
    value = (leftMaximum - rightMaximum) ./ denominator;
end
end

function value = asymmetryIndex(response)
toward = flipud(response(5:8, :));
away = response(1:4, :);
towardMean = mean(toward, 2, 'omitnan');
awayMean = mean(away, 2, 'omitnan');
towardStd = std(toward, 0, 2, 'omitnan');
awayStd = std(away, 0, 2, 'omitnan');
denominator = abs(towardMean - awayMean) + ...
    mean([towardStd, awayStd], 2, 'omitnan');
perCoherence = (towardMean - awayMean) ./ denominator;
value = mean(perCoherence, 'omitnan');
end

function weights = gaussianPositionWeights(positionOffset, sigma)
weights = exp(-(positionOffset.^2) ./ (2 .* sigma.^2));
weights = weights ./ sum(weights);
end

function r2ByRepeat = crossValidatedAIOD(ai, od, behavior, ...
        numRepeats, numFolds, randomSeed)
numSessions = size(ai, 1);
r2ByRepeat = NaN(numRepeats, 1);
[aiVector, odVector, biasVector, sessionIndex] = observationVectors( ...
    ai, od, behavior);

for repeatIndex = 1:numRepeats
    folds = balancedFolds(numSessions, numFolds, randomSeed + repeatIndex - 1);
    prediction = NaN(size(biasVector));
    nullPrediction = NaN(size(biasVector));
    for fold = 1:numFolds
        test = folds(sessionIndex) == fold;
        train = ~test;
        beta = fitAIODModel(aiVector(train), odVector(train), biasVector(train));
        if all(isfinite(beta))
            prediction(test) = beta(1) + beta(2) .* aiVector(test) + ...
                beta(3) .* aiVector(test) .* odVector(test);
        end
        nullPrediction(test) = mean(biasVector(train), 'omitnan');
    end
    r2ByRepeat(repeatIndex) = crossValidatedR2( ...
        biasVector, prediction, nullPrediction);
end
end

function method = summarizeMethod(name, sigma, ai, od, behavior, cvR2, ...
        odDefinition, dominantCue, originalDominantCue, signedOD)
[aiVector, odVector, biasVector, sessionIndex, eyeCondition] = ...
    observationVectors(ai, od, behavior);
sourceCue = [dominantCue; 5 - dominantCue];
signedODVector = [signedOD; signedOD];
valid = isfinite(aiVector) & isfinite(odVector) & isfinite(biasVector);
aiVector = aiVector(valid);
odVector = odVector(valid);
biasVector = biasVector(valid);
sessionIndex = sessionIndex(valid);
eyeCondition = eyeCondition(valid);
sourceCue = sourceCue(valid);
signedODVector = signedODVector(valid);

modelTable = table(aiVector, odVector, biasVector, ...
    'VariableNames', {'AI', 'OD', 'MergedEyeBias'});
linearModel = fitlm(modelTable, 'MergedEyeBias ~ AI + AI:OD');
[weightedSlope, weightedIntercept] = weightedFitLine( ...
    aiVector, biasVector, odVector);

method = struct();
method.name = name;
method.odDefinition = odDefinition;
method.sigma = sigma;
validAssignment = isfinite(dominantCue) & isfinite(originalDominantCue);
method.dominanceFlipCount = sum( ...
    dominantCue(validAssignment) ~= originalDominantCue(validAssignment));
method.numPoints = numel(aiVector);
method.numSessions = numel(unique(sessionIndex));
method.crossValidatedR2 = cvR2;
method.fullModelR2 = linearModel.Rsquared.Ordinary;
method.pAI = coefficientPValue(linearModel, 'AI');
method.pAIxOD = coefficientPValue(linearModel, 'AI:OD');
method.weightedSlope = weightedSlope;
method.weightedIntercept = weightedIntercept;
method.linearModel = linearModel;
method.pointTable = table(sessionIndex, eyeCondition, sourceCue, aiVector, ...
    signedODVector, odVector, aiVector .* odVector, biasVector, ...
    'VariableNames', {'Session', 'EyeCondition', 'SourceCue', 'AI', ...
    'SignedOD', 'OD', 'AIxOD', 'MergedEyeDeltaBias'});
end

function [aiVector, odVector, biasVector, sessionIndex, eyeCondition] = ...
        observationVectors(ai, od, behavior)
numSessions = size(ai, 1);
aiVector = [ai(:, 1); ai(:, 2)];
odVector = [od(:); od(:)];
biasVector = [behavior(:, 1); behavior(:, 2)];
sessionIndex = [(1:numSessions)'; (1:numSessions)'];
eyeCondition = [repmat("Dominant", numSessions, 1); ...
    repmat("NonDominant", numSessions, 1)];
end

function beta = fitAIODModel(ai, od, bias)
valid = isfinite(ai) & isfinite(od) & isfinite(bias);
design = [ones(sum(valid), 1), ai(valid), ai(valid) .* od(valid)];
if size(design, 1) < 4 || rank(design) < 3
    beta = NaN(3, 1);
else
    beta = design \ bias(valid);
end
end

function folds = balancedFolds(numRows, numFolds, seed)
stream = RandStream('mt19937ar', 'Seed', seed);
order = randperm(stream, numRows);
folds = zeros(numRows, 1);
folds(order) = mod(0:numRows-1, numFolds) + 1;
end

function value = crossValidatedR2(observed, predicted, nullPredicted)
valid = isfinite(observed) & isfinite(predicted) & isfinite(nullPredicted);
modelSSE = sum((observed(valid) - predicted(valid)).^2);
nullSSE = sum((observed(valid) - nullPredicted(valid)).^2);
if sum(valid) < 4 || nullSSE <= eps
    value = NaN;
else
    value = 1 - modelSSE ./ nullSSE;
end
end

function [slope, intercept] = weightedFitLine(x, y, w)
valid = isfinite(x) & isfinite(y) & isfinite(w) & w > 0;
if exist('type2_reg_weighted_matrix', 'file') == 2
    [slope, intercept] = type2_reg_weighted_matrix( ...
        x(valid), y(valid), w(valid));
    return
end
design = [x(valid), ones(sum(valid), 1)];
coefficients = lscov(design, y(valid), w(valid));
slope = coefficients(1);
intercept = coefficients(2);
end

function pValue = coefficientPValue(linearModel, coefficientName)
rowNames = linearModel.Coefficients.Properties.RowNames;
row = find(strcmp(rowNames, coefficientName), 1);
if isempty(row)
    pValue = NaN;
else
    pValue = linearModel.Coefficients.pValue(row);
end
end

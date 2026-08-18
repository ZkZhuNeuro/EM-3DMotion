function result = currentSpreadPerspectiveAIODGaussianOptimization(paths, options)
%CURRENTSPREADPERSPECTIVEAIODGAUSSIANOPTIMIZATION Optimize sigma on AI x OD.
%
% This analysis uses Jim MT 2D perspective-cue sessions and the merged-eye
% population model:
%   MergedEyeDeltaBias = beta0 + beta1*AI + beta2*(AI*abs(OD)).
% In fitlm notation this is "MergedEyeDeltaBias ~ AI + AI:OD". Sigma is
% selected by repeated, session-grouped cross-validated R-squared. A nested
% cross-validation estimate is also reported to evaluate sigma selection on
% held-out sessions.
%
% Signed OD is retained until dominant/non-dominant eye assignment. For every
% candidate sigma, AI and raw cue-2/cue-3 behavioral biases are reordered from
% that method's OD sign, and only then is the non-dominant-eye bias negated.

arguments
    paths (1, 1) struct
    options.NumRepeats (1, 1) double {mustBeInteger, mustBePositive} = 5
    options.NumFolds (1, 1) double {mustBeInteger, ...
        mustBeGreaterThan(options.NumFolds, 1)} = 5
    options.RandomSeed (1, 1) double {mustBeInteger, mustBeNonnegative} = 1
    options.SigmaValues (1, :) double = logspace(-2, 2, 41)
end

sigmaValues = sort(unique(options.SigmaValues(:)));
if isempty(sigmaValues) || any(~isfinite(sigmaValues)) || ...
        any(sigmaValues <= 0)
    error('CurrentSpread:SigmaValues', ...
        'SigmaValues must contain finite positive values.');
end

unitData = load(paths.unitTableGof, 'unit_table_gof');
unitTableAll = unitData.unit_table_gof;
[selection, rawBehaviorByCue] = selectPerspectiveSessions(unitTableAll);
unitTable = unitTableAll(selection, :);
rawBehaviorByCue = rawBehaviorByCue(selection, :);
sourceRows = find(selection);

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
numSigmas = numel(sigmaValues);
weightsBySigma = NaN(numel(positionOffset), numSigmas);
for sigmaIndex = 1:numSigmas
    weightsBySigma(:, sigmaIndex) = gaussianPositionWeights( ...
        positionOffset, sigmaValues(sigmaIndex));
end
effectiveChannels = 1 ./ sum(weightsBySigma.^2, 1)';

originalAIByCue = NaN(numSessions, 2);
originalSignedOD = NaN(numSessions, 1);
for session = 1:numSessions
    stimulationChannel = unitTable.StimElec(session);
    aiValues = unitTable.AI{session};
    originalAIByCue(session, :) = aiValues([2, 3], stimulationChannel)';
    originalSignedOD(session) = unitTable.OD_max{session};
end
[originalAI, originalBehavior, originalDominantCue, ...
    originalNonDominantCue] = assignDominance( ...
    originalAIByCue, rawBehaviorByCue, originalSignedOD);
originalOD = abs(originalSignedOD);

numRepeats = options.NumRepeats;
numFolds = min(options.NumFolds, numSessions);
originalR2ByRepeat = repeatedCrossValidatedR2(originalAI, originalOD, ...
    originalBehavior, numRepeats, numFolds, options.RandomSeed);
originalMeanR2 = mean(originalR2ByRepeat, 'omitnan');
originalSemR2 = finiteSEM(originalR2ByRepeat, 1);
originalSummary = summarizeFeatureSet( ...
    "Original stimulation electrode", ...
    "Absolute OD_max at stimulation electrode; sign assigns eye", ...
    NaN, 1, originalAI, originalOD, originalBehavior, originalSignedOD, ...
    originalDominantCue, originalDominantCue, sourceRows, ...
    originalMeanR2, originalSemR2, originalMeanR2, originalSemR2);
originalSummary.sigmaAtGridBoundary = false;
originalSummary.sigmaInterpretation = "Stimulation-electrode baseline";

channelSignedOD = mean(alignedOD, 2, 'omitnan');
channelFeatures = initializeFeatureGrid(numSessions, numSigmas);
for sigmaIndex = 1:numSigmas
    aiByCue = weightedMatrix(alignedAI, weightsBySigma(:, sigmaIndex));
    [channelFeatures.ai(:, :, sigmaIndex), ...
        channelFeatures.behavior(:, :, sigmaIndex), ...
        channelFeatures.dominantCue(:, sigmaIndex), ...
        channelFeatures.nonDominantCue(:, sigmaIndex)] = assignDominance( ...
        aiByCue, rawBehaviorByCue, channelSignedOD);
    channelFeatures.signedOD(:, sigmaIndex) = channelSignedOD;
    channelFeatures.od(:, sigmaIndex) = abs(channelSignedOD);
end

frFeatures = initializeFeatureGrid(numSessions, numSigmas);
for sigmaIndex = 1:numSigmas
    [aiByCue, signedOD] = weightedFiringRateAIOD( ...
        alignedFRZ, alignedFRRaw, weightsBySigma(:, sigmaIndex));
    [frFeatures.ai(:, :, sigmaIndex), ...
        frFeatures.behavior(:, :, sigmaIndex), ...
        frFeatures.dominantCue(:, sigmaIndex), ...
        frFeatures.nonDominantCue(:, sigmaIndex)] = assignDominance( ...
        aiByCue, rawBehaviorByCue, signedOD);
    frFeatures.signedOD(:, sigmaIndex) = signedOD;
    frFeatures.od(:, sigmaIndex) = abs(signedOD);
end

channelResult = optimizeFeatureGrid(channelFeatures, sigmaValues, ...
    weightsBySigma, effectiveChannels, originalDominantCue, sourceRows, ...
    "Perspective-optimized Gaussian channel AI + mean channel OD", ...
    "Absolute signed mean OD_max_all across available channels; sign assigns eye", ...
    numRepeats, numFolds, options.RandomSeed);
frResult = optimizeFeatureGrid(frFeatures, sigmaValues, ...
    weightsBySigma, effectiveChannels, originalDominantCue, sourceRows, ...
    "Perspective-optimized Gaussian FR meta-tuning AI + OD", ...
    "Absolute normalized left-right maximum difference of raw meta-tuning curves; sign assigns eye", ...
    numRepeats, numFolds, options.RandomSeed);

methods = [originalSummary, channelResult.bestSummary, frResult.bestSummary];
summaryTable = table( ...
    vertcat(methods.name), vertcat(methods.odDefinition), ...
    vertcat(methods.sigma), vertcat(methods.effectiveChannels), ...
    vertcat(methods.sigmaAtGridBoundary), ...
    vertcat(methods.sigmaInterpretation), ...
    vertcat(methods.dominanceFlipCount), vertcat(methods.numPoints), ...
    vertcat(methods.numSessions), vertcat(methods.selectionCVR2), ...
    vertcat(methods.selectionCVSEM), ...
    vertcat(methods.nestedSelectionCVR2), ...
    vertcat(methods.nestedSelectionCVSEM), ...
    vertcat(methods.fullModelR2), vertcat(methods.pAI), ...
    vertcat(methods.pAIxOD), ...
    vertcat(methods.nestedSelectionCVR2) - originalMeanR2, ...
    'VariableNames', {'Method', 'ODDefinition', 'BestSigma', ...
    'EffectiveChannels', 'SigmaAtGridBoundary', 'SigmaInterpretation', ...
    'DominanceFlipCount', 'NPoints', 'NSessions', ...
    'SelectionCVR2', 'SelectionCVSEM', 'NestedSelectionCVR2', ...
    'NestedSelectionCVSEM', 'FullModelR2', 'P_AI', 'P_AIxOD', ...
    'NestedSelectionR2ChangeVsOriginal'});

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
    "MergedEyeDeltaBias = beta0 + beta1*AI + beta2*(AI*abs(OD))";
result.fitlmFormula = "MergedEyeDeltaBias ~ AI + AI:OD";
result.optimizationTarget = ...
    "Maximum repeated session-grouped perspective-cue cross-validated R-squared";
result.evaluationTarget = ...
    "Nested session-grouped cross-validated R-squared";
result.sourceTable = string(paths.unitTableGof);
result.behaviorField = ["Behav_bias_NminusS cues 2/3"; ...
    "method-specific non-dominant eye negated after signed-OD assignment"];
result.selectionRule = ["Jim"; "MT"; "ND = 2D"; ...
    "perspective-cue p_AI(2:3) < 0.05"; ...
    "at least one valid perspective-cue behavioral fit"];
result.originalRowIndex = sourceRows;
result.sessionCount = numSessions;
result.rawBehaviorByCue = rawBehaviorByCue;
result.positionOffset = positionOffset;
result.sigmaValues = sigmaValues;
result.weightsBySigma = weightsBySigma;
result.effectiveChannels = effectiveChannels;
result.originalSignedOD = originalSignedOD;
result.originalDominantCue = originalDominantCue;
result.originalNonDominantCue = originalNonDominantCue;
result.originalR2ByRepeat = originalR2ByRepeat;
result.channel = channelResult;
result.fr = frResult;
result.methods = methods;
result.summaryTable = summaryTable;
result.pointTable = pointTable;
result.numRepeats = numRepeats;
result.numFolds = numFolds;
result.randomSeed = options.RandomSeed;

validateResult(result);
end

function features = initializeFeatureGrid(numSessions, numSigmas)
features = struct();
features.ai = NaN(numSessions, 2, numSigmas);
features.od = NaN(numSessions, numSigmas);
features.behavior = NaN(numSessions, 2, numSigmas);
features.signedOD = NaN(numSessions, numSigmas);
features.dominantCue = NaN(numSessions, numSigmas);
features.nonDominantCue = NaN(numSessions, numSigmas);
end

function method = optimizeFeatureGrid(features, sigmaValues, weightsBySigma, ...
        effectiveChannels, originalDominantCue, sourceRows, name, ...
        odDefinition, numRepeats, numFolds, randomSeed)
numSigmas = numel(sigmaValues);
[r2ByRepeat, meanR2, semR2] = crossValidatedSigmaCurve( ...
    features, numRepeats, numFolds, randomSeed);
bestIndex = bestFiniteIndex(meanR2);
if ~isfinite(bestIndex)
    error('CurrentSpread:NoValidSigma', ...
        'No candidate sigma produced a finite cross-validated R-squared.');
end

[nestedR2ByRepeat, nestedSelectedSigma] = nestedCrossValidatedR2( ...
    features, sigmaValues, numRepeats, numFolds, randomSeed);

fullModelR2 = NaN(numSigmas, 1);
pAI = NaN(numSigmas, 1);
pAIxOD = NaN(numSigmas, 1);
numPoints = zeros(numSigmas, 1);
dominanceFlipCount = zeros(numSigmas, 1);
for sigmaIndex = 1:numSigmas
    stats = fullModelStatistics(features.ai(:, :, sigmaIndex), ...
        features.od(:, sigmaIndex), ...
        features.behavior(:, :, sigmaIndex));
    fullModelR2(sigmaIndex) = stats.r2;
    pAI(sigmaIndex) = stats.pAI;
    pAIxOD(sigmaIndex) = stats.pAIxOD;
    numPoints(sigmaIndex) = stats.numPoints;
    validAssignment = isfinite(features.dominantCue(:, sigmaIndex)) & ...
        isfinite(originalDominantCue);
    dominanceFlipCount(sigmaIndex) = sum( ...
        features.dominantCue(validAssignment, sigmaIndex) ~= ...
        originalDominantCue(validAssignment));
end
referenceValidCount = sum(isfinite(features.ai(:, :, 1)) & ...
    isfinite(features.behavior(:, :, 1)) & ...
    isfinite(features.od(:, 1)), 2);
for sigmaIndex = 2:numSigmas
    validCount = sum(isfinite(features.ai(:, :, sigmaIndex)) & ...
        isfinite(features.behavior(:, :, sigmaIndex)) & ...
        isfinite(features.od(:, sigmaIndex)), 2);
    if ~isequal(validCount, referenceValidCount)
        error('CurrentSpread:SigmaDependentMissingness', ...
            ['Valid perspective observations vary with sigma. Use a common ' ...
            'session/cue mask before comparing cross-validated R-squared.']);
    end
end

method = struct();
method.name = name;
method.odDefinition = odDefinition;
method.features = features;
method.sigmaValues = sigmaValues;
method.weightsBySigma = weightsBySigma;
method.effectiveChannels = effectiveChannels;
method.r2ByRepeat = r2ByRepeat;
method.meanR2 = meanR2;
method.semR2 = semR2;
method.bestIndex = bestIndex;
method.bestSigma = sigmaValues(bestIndex);
method.bestWeights = weightsBySigma(:, bestIndex);
method.bestEffectiveChannels = effectiveChannels(bestIndex);
method.bestSelectionCVR2 = meanR2(bestIndex);
method.bestSelectionCVSEM = semR2(bestIndex);
method.bestAtGridBoundary = bestIndex == 1 || bestIndex == numSigmas;
if bestIndex == numSigmas
    method.bestSigmaInterpretation = ...
        "Upper grid boundary; best tested profile is effectively uniform";
elseif bestIndex == 1
    method.bestSigmaInterpretation = ...
        "Lower grid boundary; optimum is not resolved within the tested grid";
else
    method.bestSigmaInterpretation = "Interior grid optimum";
end
method.nestedR2ByRepeat = nestedR2ByRepeat;
method.nestedSelectionCVR2 = mean(nestedR2ByRepeat, 'omitnan');
method.nestedSelectionCVSEM = finiteSEM(nestedR2ByRepeat, 1);
method.nestedSelectedSigma = nestedSelectedSigma;
method.table = table(sigmaValues, effectiveChannels, meanR2, semR2, ...
    fullModelR2, pAI, pAIxOD, dominanceFlipCount, numPoints, ...
    'VariableNames', {'Sigma', 'EffectiveChannels', 'SelectionCVR2', ...
    'SelectionCVSEM', 'FullModelR2', 'P_AI', 'P_AIxOD', ...
    'DominanceFlipCount', 'NPoints'});

method.bestSummary = summarizeFeatureSet(name, odDefinition, ...
    method.bestSigma, method.bestEffectiveChannels, ...
    features.ai(:, :, bestIndex), features.od(:, bestIndex), ...
    features.behavior(:, :, bestIndex), ...
    features.signedOD(:, bestIndex), ...
    features.dominantCue(:, bestIndex), originalDominantCue, sourceRows, ...
    method.bestSelectionCVR2, method.bestSelectionCVSEM, ...
    method.nestedSelectionCVR2, method.nestedSelectionCVSEM);
method.bestSummary.sigmaAtGridBoundary = method.bestAtGridBoundary;
method.bestSummary.sigmaInterpretation = method.bestSigmaInterpretation;
end

function [r2ByRepeat, meanR2, semR2] = crossValidatedSigmaCurve( ...
        features, numRepeats, numFolds, randomSeed)
numSessions = size(features.ai, 1);
numSigmas = size(features.ai, 3);
r2ByRepeat = NaN(numRepeats, numSigmas);
for repeatIndex = 1:numRepeats
    folds = balancedFolds(numSessions, numFolds, ...
        randomSeed + repeatIndex - 1);
    for sigmaIndex = 1:numSigmas
        r2ByRepeat(repeatIndex, sigmaIndex) = crossValidatedFeatureSet( ...
            features.ai(:, :, sigmaIndex), features.od(:, sigmaIndex), ...
            features.behavior(:, :, sigmaIndex), folds);
    end
end
meanR2 = mean(r2ByRepeat, 1, 'omitnan')';
semR2 = finiteSEM(r2ByRepeat, 1)';
end

function [nestedR2ByRepeat, selectedSigma] = nestedCrossValidatedR2( ...
        features, sigmaValues, numRepeats, numFolds, randomSeed)
numSessions = size(features.ai, 1);
numSigmas = numel(sigmaValues);
nestedR2ByRepeat = NaN(numRepeats, 1);
selectedSigma = NaN(numRepeats, numFolds);

for repeatIndex = 1:numRepeats
    outerFolds = balancedFolds(numSessions, numFolds, ...
        randomSeed + repeatIndex - 1);
    observed = NaN(2 * numSessions, 1);
    predicted = NaN(2 * numSessions, 1);
    nullPredicted = NaN(2 * numSessions, 1);

    for outerFold = 1:numFolds
        outerTrain = outerFolds ~= outerFold;
        outerTest = outerFolds == outerFold;
        trainSessions = find(outerTrain);
        innerNumFolds = min(numFolds, numel(trainSessions));
        innerFoldsLocal = balancedFolds(numel(trainSessions), ...
            innerNumFolds, randomSeed + 10000 + ...
            (repeatIndex - 1) * numFolds + outerFold);
        innerScores = NaN(numSigmas, 1);

        for sigmaIndex = 1:numSigmas
            innerFolds = zeros(numSessions, 1);
            innerFolds(trainSessions) = innerFoldsLocal;
            innerScores(sigmaIndex) = crossValidatedFeatureSet( ...
                features.ai(:, :, sigmaIndex), ...
                features.od(:, sigmaIndex), ...
                features.behavior(:, :, sigmaIndex), innerFolds, outerTrain);
        end
        bestIndex = bestFiniteIndex(innerScores);
        if ~isfinite(bestIndex)
            continue
        end
        selectedSigma(repeatIndex, outerFold) = sigmaValues(bestIndex);

        [trainAI, trainOD, trainBias] = observationVectorsForSessions( ...
            features.ai(:, :, bestIndex), features.od(:, bestIndex), ...
            features.behavior(:, :, bestIndex), outerTrain);
        [testAI, testOD, testBias, testSessionIndex] = ...
            observationVectorsForSessions( ...
            features.ai(:, :, bestIndex), features.od(:, bestIndex), ...
            features.behavior(:, :, bestIndex), outerTest);
        beta = fitAIODModel(trainAI, trainOD, trainBias);
        if all(isfinite(beta))
            foldPrediction = beta(1) + beta(2) .* testAI + ...
                beta(3) .* testAI .* testOD;
        else
            foldPrediction = NaN(size(testBias));
        end
        foldNull = repmat(mean(trainBias, 'omitnan'), size(testBias));
        observed(testSessionIndex) = testBias;
        predicted(testSessionIndex) = foldPrediction;
        nullPredicted(testSessionIndex) = foldNull;
    end
    nestedR2ByRepeat(repeatIndex) = crossValidatedR2( ...
        observed, predicted, nullPredicted);
end
end

function value = crossValidatedFeatureSet(ai, od, behavior, folds, inclusion)
numSessions = size(ai, 1);
if nargin < 5
    inclusion = true(numSessions, 1);
end
foldLabels = unique(folds(inclusion & folds > 0))';
[aiVector, odVector, biasVector, sessionIndex] = observationVectors( ...
    ai, od, behavior);
prediction = NaN(size(biasVector));
nullPrediction = NaN(size(biasVector));
includedObservation = inclusion(sessionIndex);

for fold = foldLabels
    test = includedObservation & folds(sessionIndex) == fold;
    train = includedObservation & folds(sessionIndex) > 0 & ~test;
    beta = fitAIODModel(aiVector(train), odVector(train), biasVector(train));
    if all(isfinite(beta))
        prediction(test) = beta(1) + beta(2) .* aiVector(test) + ...
            beta(3) .* aiVector(test) .* odVector(test);
    end
    nullPrediction(test) = mean(biasVector(train), 'omitnan');
end
value = crossValidatedR2(biasVector(includedObservation), ...
    prediction(includedObservation), nullPrediction(includedObservation));
end

function r2ByRepeat = repeatedCrossValidatedR2(ai, od, behavior, ...
        numRepeats, numFolds, randomSeed)
numSessions = size(ai, 1);
r2ByRepeat = NaN(numRepeats, 1);
for repeatIndex = 1:numRepeats
    folds = balancedFolds(numSessions, numFolds, ...
        randomSeed + repeatIndex - 1);
    r2ByRepeat(repeatIndex) = crossValidatedFeatureSet( ...
        ai, od, behavior, folds);
end
end

function [aiVector, odVector, biasVector, sessionIndex] = ...
        observationVectorsForSessions(ai, od, behavior, inclusion)
[allAI, allOD, allBias, allSession] = observationVectors(ai, od, behavior);
keep = inclusion(allSession);
aiVector = allAI(keep);
odVector = allOD(keep);
biasVector = allBias(keep);
sessionIndex = find(keep);
end

function summary = summarizeFeatureSet(name, odDefinition, sigma, ...
        effectiveChannels, ai, od, behavior, signedOD, dominantCue, ...
        originalDominantCue, sourceRows, selectionCVR2, selectionCVSEM, ...
        nestedSelectionCVR2, nestedSelectionCVSEM)
stats = fullModelStatistics(ai, od, behavior);
[aiVector, odVector, biasVector, sessionIndex, eyeCondition] = ...
    observationVectors(ai, od, behavior);
sourceCue = [dominantCue; 5 - dominantCue];
signedODVector = [signedOD; signedOD];
sourceRowVector = [sourceRows; sourceRows];
valid = isfinite(aiVector) & isfinite(odVector) & isfinite(biasVector);
aiVector = aiVector(valid);
odVector = odVector(valid);
biasVector = biasVector(valid);
sessionIndex = sessionIndex(valid);
eyeCondition = eyeCondition(valid);
sourceCue = sourceCue(valid);
signedODVector = signedODVector(valid);
sourceRowVector = sourceRowVector(valid);
[weightedSlope, weightedIntercept] = weightedFitLine( ...
    aiVector, biasVector, odVector);
validAssignment = isfinite(dominantCue) & isfinite(originalDominantCue);

summary = struct();
summary.name = name;
summary.odDefinition = odDefinition;
summary.sigma = sigma;
summary.effectiveChannels = effectiveChannels;
summary.dominanceFlipCount = sum( ...
    dominantCue(validAssignment) ~= originalDominantCue(validAssignment));
summary.numPoints = numel(aiVector);
summary.numSessions = numel(unique(sessionIndex));
summary.selectionCVR2 = selectionCVR2;
summary.selectionCVSEM = selectionCVSEM;
summary.nestedSelectionCVR2 = nestedSelectionCVR2;
summary.nestedSelectionCVSEM = nestedSelectionCVSEM;
summary.fullModelR2 = stats.r2;
summary.pAI = stats.pAI;
summary.pAIxOD = stats.pAIxOD;
summary.weightedSlope = weightedSlope;
summary.weightedIntercept = weightedIntercept;
summary.pointTable = table(sourceRowVector, sessionIndex, eyeCondition, ...
    sourceCue, aiVector, signedODVector, odVector, ...
    aiVector .* odVector, biasVector, ...
    'VariableNames', {'SourceRow', 'Session', 'EyeCondition', 'SourceCue', ...
    'AI', 'SignedOD', 'OD', 'AIxOD', 'MergedEyeDeltaBias'});
end

function stats = fullModelStatistics(ai, od, behavior)
[aiVector, odVector, biasVector] = observationVectors(ai, od, behavior);
valid = isfinite(aiVector) & isfinite(odVector) & isfinite(biasVector);
stats = struct('r2', NaN, 'pAI', NaN, 'pAIxOD', NaN, ...
    'numPoints', sum(valid));
if sum(valid) < 4
    return
end
modelTable = table(aiVector(valid), odVector(valid), biasVector(valid), ...
    'VariableNames', {'AI', 'OD', 'MergedEyeDeltaBias'});
linearModel = fitlm(modelTable, 'MergedEyeDeltaBias ~ AI + AI:OD');
stats.r2 = linearModel.Rsquared.Ordinary;
stats.pAI = coefficientPValue(linearModel, 'AI');
stats.pAIxOD = coefficientPValue(linearModel, 'AI:OD');
manualBeta = fitAIODModel(aiVector(valid), odVector(valid), biasVector(valid));
if all(isfinite(manualBeta)) && ...
        max(abs(linearModel.Coefficients.Estimate - manualBeta)) > 1e-8
    error('CurrentSpread:ModelMismatch', ...
        'Manual AI-by-OD design did not match the fitlm formula.');
end
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
    isPerspectiveTuned = numel(pAI) >= 3 && ...
        pAI(2) < 0.05 && pAI(3) < 0.05;
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

function [alignedAI, alignedOD, alignedFRZ, alignedFRRaw] = ...
        alignPerspectiveData(unitTable, neuroAll, channelMap, maxRadius)
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
weighted = NaN(numSessions, size(data, 2));
for session = 1:numSessions
    for cue = 1:size(data, 2)
        values = squeeze(data(session, cue, :));
        available = isfinite(values);
        if any(available)
            weighted(session, cue) = ...
                sum(values(available) .* weights(available)) ./ ...
                sum(weights(available));
        end
    end
end
end

function [ai, signedOD] = weightedFiringRateAIOD( ...
        alignedFRZ, alignedFRRaw, weights)
numSessions = size(alignedFRZ, 1);
ai = NaN(numSessions, 2);
signedOD = NaN(numSessions, 1);
for session = 1:numSessions
    zNumerator = [];
    zDenominator = [];
    rawNumerator = [];
    rawDenominator = [];
    for position = 1:size(alignedFRZ, 2)
        responseZ = alignedFRZ{session, position};
        responseRaw = alignedFRRaw{session, position};
        if isempty(responseZ) || isempty(responseRaw) || ...
                weights(position) <= eps
            continue
        end
        if isempty(zNumerator)
            zNumerator = zeros(size(responseZ));
            zDenominator = zeros(size(responseZ));
            rawNumerator = zeros(size(responseRaw));
            rawDenominator = zeros(size(responseRaw));
        end
        finiteZ = isfinite(responseZ);
        finiteRaw = isfinite(responseRaw);
        responseZ(~finiteZ) = 0;
        responseRaw(~finiteRaw) = 0;
        zNumerator = zNumerator + weights(position) .* responseZ;
        zDenominator = zDenominator + weights(position) .* finiteZ;
        rawNumerator = rawNumerator + weights(position) .* responseRaw;
        rawDenominator = rawDenominator + weights(position) .* finiteRaw;
    end
    if isempty(zNumerator)
        continue
    end
    metaTuningZ = zNumerator ./ zDenominator;
    metaTuningRaw = rawNumerator ./ rawDenominator;
    metaTuningZ(zDenominator <= eps) = NaN;
    metaTuningRaw(rawDenominator <= eps) = NaN;
    ai(session, :) = [asymmetryIndex(squeeze(metaTuningZ(1, :, :))), ...
        asymmetryIndex(squeeze(metaTuningZ(2, :, :)))];
    signedOD(session) = metaTuningOD(metaTuningRaw);
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

function value = finiteSEM(data, dimension)
finiteCount = sum(isfinite(data), dimension);
value = std(data, 0, dimension, 'omitnan') ./ sqrt(finiteCount);
value(finiteCount == 0) = NaN;
end

function index = bestFiniteIndex(values)
finiteValues = isfinite(values);
if ~any(finiteValues)
    index = NaN;
    return
end
finiteIndices = find(finiteValues);
[~, relativeIndex] = max(values(finiteValues));
index = finiteIndices(relativeIndex);
end

function [slope, intercept] = weightedFitLine(x, y, w)
valid = isfinite(x) & isfinite(y) & isfinite(w) & w > 0;
if sum(valid) < 2
    slope = NaN;
    intercept = NaN;
    return
end
design = [x(valid), ones(sum(valid), 1)];
coefficients = lscov(design, y(valid), w(valid));
slope = coefficients(1);
intercept = coefficients(2);
end

function value = coefficientPValue(linearModel, coefficientName)
rowNames = linearModel.Coefficients.Properties.RowNames;
row = find(strcmp(rowNames, coefficientName), 1);
if isempty(row)
    value = NaN;
else
    value = linearModel.Coefficients.pValue(row);
end
end

function validateResult(result)
assert(result.channel.bestIndex == bestFiniteIndex(result.channel.meanR2));
assert(result.fr.bestIndex == bestFiniteIndex(result.fr.meanR2));
assert(all(result.weightsBySigma >= 0, 'all'));
assert(max(abs(sum(result.weightsBySigma, 1) - 1)) < 1e-12);
assert(max(abs(result.weightsBySigma - flipud(result.weightsBySigma)), ...
    [], 'all') < 1e-12);

methods = {result.channel, result.fr};
for methodIndex = 1:numel(methods)
    method = methods{methodIndex};
    for sigmaIndex = 1:numel(result.sigmaValues)
        signedOD = method.features.signedOD(:, sigmaIndex);
        dominantCue = method.features.dominantCue(:, sigmaIndex);
        nonDominantCue = method.features.nonDominantCue(:, sigmaIndex);
        finiteOD = isfinite(signedOD);
        expectedDominant = 2 + (signedOD <= 0);
        assert(isequaln(dominantCue(finiteOD), expectedDominant(finiteOD)));
        assert(isequaln(nonDominantCue(finiteOD), ...
            5 - dominantCue(finiteOD)));
        assert(max(abs(method.features.od(finiteOD, sigmaIndex) - ...
            abs(signedOD(finiteOD))), [], 'omitnan') < 1e-12);
        for session = find(finiteOD)'
            if dominantCue(session) == 2
                expectedBehavior = [result.rawBehaviorByCue(session, 1), ...
                    -result.rawBehaviorByCue(session, 2)];
            else
                expectedBehavior = [result.rawBehaviorByCue(session, 2), ...
                    -result.rawBehaviorByCue(session, 1)];
            end
            assert(isequaln( ...
                method.features.behavior(session, :, sigmaIndex), ...
                expectedBehavior));
        end
    end
end
end

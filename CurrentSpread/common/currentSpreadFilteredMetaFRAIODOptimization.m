function result = currentSpreadFilteredMetaFRAIODOptimization(paths, options)
%CURRENTSPREADFILTEREDMETAFRAIODOPTIMIZATION Clean and optimize FR meta tuning.
%
% The neural cohort is rebuilt without stimulation-channel tuning or ND
% labels. Every Jim recording is considered. Each live channel is retained
% only when trial-level direction tuning is significant for both monocular
% perspective cues. A fixed, equal-channel meta-tuning curve then determines
% whether the recording is 2D (Z3D - Z2D < 0). Gaussian sigma is optimized
% only after this neural selection, using the fixed cohort and the model
%
%   MergedEyeDeltaBias ~ AI + AI:OD
%
% with session-grouped cross-validation.

arguments
    paths (1, 1) struct
    options.NumRepeats (1, 1) double {mustBeInteger, mustBePositive} = 5
    options.NumFolds (1, 1) double {mustBeInteger, ...
        mustBeGreaterThan(options.NumFolds, 1)} = 5
    options.RandomSeed (1, 1) double {mustBeInteger, mustBeNonnegative} = 1
    options.SigmaValues (1, :) double = logspace(-2, 2, 41)
    options.TuningAlpha (1, 1) double ...
        {mustBeGreaterThan(options.TuningAlpha, 0), ...
        mustBeLessThan(options.TuningAlpha, 1)} = 0.05
    options.ROI (1, 1) string ...
        {mustBeMember(options.ROI, ["All", "MT", "FST"])} = "All"
end

sigmaValues = sort(unique(options.SigmaValues(:)));
if isempty(sigmaValues) || any(~isfinite(sigmaValues)) || ...
        any(sigmaValues <= 0)
    error('CurrentSpread:SigmaValues', ...
        'SigmaValues must contain finite positive values.');
end

unitData = load(paths.unitTableGof, 'unit_table_gof');
unitTableAll = unitData.unit_table_gof;
jimMask = strcmp(unitTableAll.Monkey, 'Jim');
if options.ROI == "All"
    candidateMask = jimMask;
    candidateLabel = "All Jim";
else
    candidateMask = jimMask & strcmp(unitTableAll.ROI, options.ROI);
    candidateLabel = "Jim " + options.ROI;
end
unitTable = unitTableAll(candidateMask, :);
sourceRows = find(candidateMask);

neuroData = load(paths.neuroAll, 'NeuroAll');
neuroIndex = unitTable.OriginalRecIdx;
validMapping = isfinite(neuroIndex) & neuroIndex >= 1 & ...
    neuroIndex <= numel(neuroData.NeuroAll);

[rawBehaviorByCue, validBehaviorCount] = extractPerspectiveBehavior(unitTable);
channelMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10];
positionOffset = (-15:15)';
numSessionsAll = height(unitTable);
numPositions = numel(positionOffset);

sessionData = repmat(emptySessionData(), numSessionsAll, 1);
pLeft = NaN(numSessionsAll, 16);
pRight = NaN(numSessionsAll, 16);
tunedBoth = false(numSessionsAll, 16);
validChannel = false(numSessionsAll, 16);
deadChannelMask = false(numSessionsAll, 16);
relativePosition = NaN(numSessionsAll, 16);
validNeural = false(numSessionsAll, 1);

for session = 1:numSessionsAll
    if ~validMapping(session)
        continue
    end
    recording = neuroData.NeuroAll{neuroIndex(session)};
    if ~isnumeric(recording) || ndims(recording) ~= 4 || ...
            size(recording, 1) < 3
        continue
    end
    [coherence, nonzeroIndex] = coherenceForRecording(recording);
    numChannels = min(size(recording, 4), numel(channelMap));
    stimulationPosition = find(channelMap == unitTable.StimElec(session), 1);
    if isempty(stimulationPosition)
        continue
    end
    deadChannels = numericDeadChannels(unitTable.DeadChannel{session});
    deadChannels = deadChannels(deadChannels >= 1 & deadChannels <= numChannels);
    deadChannelMask(session, deadChannels) = true;

    zRecording = NaN(2, size(recording, 2), size(recording, 3), numChannels);
    for channel = 1:numChannels
        channelPosition = find(channelMap == channel, 1);
        relativePosition(session, channel) = ...
            channelPosition - stimulationPosition;
        if deadChannelMask(session, channel)
            continue
        end
        perspectiveData = recording([2, 3], :, :, channel);
        validChannel(session, channel) = any(isfinite(perspectiveData), 'all');
        if ~validChannel(session, channel)
            continue
        end
        pLeft(session, channel) = directionTuningPValue( ...
            squeeze(recording(2, :, :, channel)), coherence, nonzeroIndex);
        pRight(session, channel) = directionTuningPValue( ...
            squeeze(recording(3, :, :, channel)), coherence, nonzeroIndex);
        tunedBoth(session, channel) = ...
            pLeft(session, channel) < options.TuningAlpha && ...
            pRight(session, channel) < options.TuningAlpha;

        allChannelData = recording(:, :, :, channel);
        channelMean = mean(allChannelData, 'all', 'omitnan');
        channelStd = std(allChannelData, 0, 'all', 'omitnan');
        if isfinite(channelStd) && channelStd > 0
            zRecording(:, :, :, channel) = ...
                (perspectiveData - channelMean) ./ channelStd;
        else
            tunedBoth(session, channel) = false;
        end
    end

    rawPerspective = recording([2, 3], :, :, 1:numChannels);
    sessionData(session).raw = rawPerspective;
    sessionData(session).z = zRecording;
    sessionData(session).coherence = coherence;
    sessionData(session).nonzeroIndex = nonzeroIndex;
    sessionData(session).aiIndex = [1:4, size(recording, 2)-3:size(recording, 2)];
    sessionData(session).tunedMask = tunedBoth(session, 1:numChannels);
    sessionData(session).relativePosition = ...
        relativePosition(session, 1:numChannels);
    sessionData(session).numChannels = numChannels;
    validNeural(session) = true;
end

tunedChannelCount = sum(tunedBoth, 2);
uniformAIByCue = NaN(numSessionsAll, 2);
uniformSignedOD = NaN(numSessionsAll, 1);
selectionSignedOD = NaN(numSessionsAll, 1);
uniformMetaPLeft = NaN(numSessionsAll, 1);
uniformMetaPRight = NaN(numSessionsAll, 1);
metaZ2D = NaN(numSessionsAll, 1);
metaZ3D = NaN(numSessionsAll, 1);
metaZDifference = NaN(numSessionsAll, 1);
metaPairedCoherenceCount = zeros(numSessionsAll, 1);
uniformWeightsByPosition = zeros(numSessionsAll, numPositions);

for session = find(validNeural & tunedChannelCount > 0)'
    [metaZ, metaRaw, channelWeights] = buildMetaTuning( ...
        sessionData(session), Inf);
    uniformAIByCue(session, :) = metaAI(metaZ, sessionData(session).aiIndex);
    uniformSignedOD(session) = metaOD(metaRaw, sessionData(session).aiIndex);
    selectionSignedOD(session) = metaOD( ...
        metaRaw, sessionData(session).nonzeroIndex);
    uniformMetaPLeft(session) = directionTuningPValue( ...
        squeeze(metaRaw(1, :, :)), sessionData(session).coherence, ...
        sessionData(session).nonzeroIndex);
    uniformMetaPRight(session) = directionTuningPValue( ...
        squeeze(metaRaw(2, :, :)), sessionData(session).coherence, ...
        sessionData(session).nonzeroIndex);
    [metaZ2D(session), metaZ3D(session), metaZDifference(session), ...
        metaPairedCoherenceCount(session)] = meta2DStatistics( ...
        metaRaw, sessionData(session).nonzeroIndex, ...
        selectionSignedOD(session));
    uniformWeightsByPosition(session, :) = weightsAtPositions( ...
        channelWeights, sessionData(session).relativePosition, positionOffset);
end

hasTunedChannel = tunedChannelCount > 0;
metaTunedBoth = uniformMetaPLeft < options.TuningAlpha & ...
    uniformMetaPRight < options.TuningAlpha;
isMeta2D = metaTunedBoth & isfinite(metaZDifference) & metaZDifference < 0;
hasValidBehavior = validBehaviorCount > 0;
hasFiniteUniformFeatures = all(isfinite(uniformAIByCue), 2) & ...
    isfinite(uniformSignedOD);
included = validMapping & validNeural & hasTunedChannel & isMeta2D & ...
    hasValidBehavior & hasFiniteUniformFeatures;

if sum(included) < max(6, options.NumFolds)
    error('CurrentSpread:TooFewCleanSessions', ...
        ['Only %d sessions survived channel tuning, meta-2D, behavior, and ' ...
        'finite-feature selection.'], sum(included));
end

sessionAudit = buildSessionAudit(unitTable, sourceRows, neuroIndex, ...
    validMapping, validNeural, validBehaviorCount, validChannel, ...
    tunedChannelCount, uniformSignedOD, selectionSignedOD, ...
    uniformMetaPLeft, uniformMetaPRight, metaTunedBoth, metaZ2D, metaZ3D, ...
    metaZDifference, metaPairedCoherenceCount, hasFiniteUniformFeatures, ...
    isMeta2D, included);
channelAudit = buildChannelAudit(unitTable, sourceRows, neuroIndex, ...
    relativePosition, deadChannelMask, validChannel, pLeft, pRight, ...
    tunedBoth, options.TuningAlpha);
flowTable = buildFlowTable(validMapping, validNeural, hasTunedChannel, ...
    metaTunedBoth, isMeta2D, hasValidBehavior, hasFiniteUniformFeatures, ...
    included, candidateLabel);
roiFlowTable = buildROIFlowTable(string(unitTable.ROI), validMapping, ...
    validNeural, hasTunedChannel, metaTunedBoth, isMeta2D, ...
    hasValidBehavior, hasFiniteUniformFeatures, included);

cleanTable = unitTable(included, :);
cleanSessionData = sessionData(included);
cleanSourceRows = sourceRows(included);
cleanBehavior = rawBehaviorByCue(included, :);
cleanUniformAIByCue = uniformAIByCue(included, :);
cleanUniformSignedOD = uniformSignedOD(included);
cleanUniformWeights = uniformWeightsByPosition(included, :);
numSessions = height(cleanTable);
numSigmas = numel(sigmaValues);
numRepeats = options.NumRepeats;
numFolds = min(options.NumFolds, numSessions);

originalAIByCue = NaN(numSessions, 2);
originalSignedOD = NaN(numSessions, 1);
for session = 1:numSessions
    stimulationChannel = cleanTable.StimElec(session);
    aiValues = cleanTable.AI{session};
    if size(aiValues, 1) >= 3 && size(aiValues, 2) >= stimulationChannel
        originalAIByCue(session, :) = aiValues([2, 3], stimulationChannel)';
    end
    odValue = cleanTable.OD_max{session};
    if isnumeric(odValue) && ~isempty(odValue)
        originalSignedOD(session) = odValue(1);
    end
end
[originalAI, originalBehavior, originalDominantCue, ...
    originalNonDominantCue] = assignDominance( ...
    originalAIByCue, cleanBehavior, originalSignedOD);
[uniformAI, uniformBehavior, uniformDominantCue, ...
    uniformNonDominantCue] = assignDominance( ...
    cleanUniformAIByCue, cleanBehavior, cleanUniformSignedOD);

originalR2ByRepeat = repeatedCrossValidatedR2(originalAI, ...
    abs(originalSignedOD), originalBehavior, numRepeats, numFolds, ...
    options.RandomSeed);
uniformR2ByRepeat = repeatedCrossValidatedR2(uniformAI, ...
    abs(cleanUniformSignedOD), uniformBehavior, numRepeats, numFolds, ...
    options.RandomSeed);

originalSummary = summarizeFeatureSet( ...
    "Original stimulation electrode on cleaned cohort", ...
    "Stimulation-electrode OD_max; sign assigns eye", NaN, 1, ...
    originalAI, abs(originalSignedOD), originalBehavior, originalSignedOD, ...
    originalDominantCue, originalDominantCue, cleanSourceRows, cleanTable, ...
    mean(originalR2ByRepeat, 'omitnan'), finiteSEM(originalR2ByRepeat, 1), ...
    mean(originalR2ByRepeat, 'omitnan'), finiteSEM(originalR2ByRepeat, 1));
uniformEffectiveChannels = 1 ./ sum(cleanUniformWeights .^ 2, 2);
uniformSummary = summarizeFeatureSet( ...
    "Clean uniform FR meta tuning", ...
    "Raw uniform meta-curve OD; sign assigns eye", Inf, ...
    median(uniformEffectiveChannels, 'omitnan'), uniformAI, ...
    abs(cleanUniformSignedOD), uniformBehavior, cleanUniformSignedOD, ...
    uniformDominantCue, originalDominantCue, cleanSourceRows, cleanTable, ...
    mean(uniformR2ByRepeat, 'omitnan'), finiteSEM(uniformR2ByRepeat, 1), ...
    mean(uniformR2ByRepeat, 'omitnan'), finiteSEM(uniformR2ByRepeat, 1));

features = initializeFeatureGrid(numSessions, numSigmas);
effectiveChannelsBySession = NaN(numSessions, numSigmas);
realizedWeightsBySession = zeros(numSessions, numPositions, numSigmas);
for sigmaIndex = 1:numSigmas
    aiByCue = NaN(numSessions, 2);
    signedOD = NaN(numSessions, 1);
    for session = 1:numSessions
        [metaZ, metaRaw, channelWeights] = buildMetaTuning( ...
            cleanSessionData(session), sigmaValues(sigmaIndex));
        aiByCue(session, :) = metaAI( ...
            metaZ, cleanSessionData(session).aiIndex);
        signedOD(session) = metaOD( ...
            metaRaw, cleanSessionData(session).aiIndex);
        effectiveChannelsBySession(session, sigmaIndex) = ...
            1 ./ sum(channelWeights .^ 2);
        realizedWeightsBySession(session, :, sigmaIndex) = ...
            weightsAtPositions(channelWeights, ...
            cleanSessionData(session).relativePosition, positionOffset);
    end
    [features.ai(:, :, sigmaIndex), ...
        features.behavior(:, :, sigmaIndex), ...
        features.dominantCue(:, sigmaIndex), ...
        features.nonDominantCue(:, sigmaIndex)] = assignDominance( ...
        aiByCue, cleanBehavior, signedOD);
    features.signedOD(:, sigmaIndex) = signedOD;
    features.od(:, sigmaIndex) = abs(signedOD);
end

meanRealizedWeights = squeeze(mean(realizedWeightsBySession, 1, 'omitnan'));
if isvector(meanRealizedWeights)
    meanRealizedWeights = meanRealizedWeights(:);
end
optimized = optimizeFeatureGrid(features, sigmaValues, ...
    effectiveChannelsBySession, meanRealizedWeights, originalDominantCue, ...
    cleanSourceRows, cleanTable, ...
    "Clean optimized FR meta tuning", ...
    "Raw Gaussian meta-curve OD; sign assigns eye", ...
    numRepeats, numFolds, options.RandomSeed);

methods = [originalSummary, uniformSummary, optimized.bestSummary];
summaryTable = table(vertcat(methods.name), vertcat(methods.odDefinition), ...
    vertcat(methods.sigma), vertcat(methods.effectiveChannels), ...
    vertcat(methods.dominanceFlipCount), vertcat(methods.numPoints), ...
    vertcat(methods.numSessions), vertcat(methods.selectionCVR2), ...
    vertcat(methods.selectionCVSEM), ...
    vertcat(methods.nestedSelectionCVR2), ...
    vertcat(methods.nestedSelectionCVSEM), ...
    vertcat(methods.fullModelR2), vertcat(methods.pAI), ...
    vertcat(methods.pAIxOD), ...
    'VariableNames', {'Method', 'ODDefinition', 'Sigma', ...
    'MedianEffectiveChannels', 'DominanceFlipCount', 'NPoints', ...
    'NSessions', 'SelectionCVR2', 'SelectionCVSEM', ...
    'NestedSelectionCVR2', 'NestedSelectionCVSEM', 'FullModelR2', ...
    'P_AI', 'P_AIxOD'});

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
    "Maximum repeated session-grouped perspective-cue CV R-squared";
result.evaluationTarget = "Nested session-grouped CV R-squared";
result.sourceTable = string(paths.unitTableGof);
result.sourceNeuroAll = string(paths.neuroAll);
result.sourceDataNote = [ ...
    "Channel p-values are newly computed from NeuroAll_20250627"; ...
    "12-bin and 13-bin recordings are handled explicitly; zero coherence is excluded"; ...
    "Stored p_AI and ND are never used for selection"];
result.selectionRule = [ ...
    "Candidate pool: " + candidateLabel + " recordings before neural selection"; ...
    "Exclude dead or invalid channels"; ...
    sprintf("Per-channel cue 2 p < %.3g AND cue 3 p < %.3g", ...
    options.TuningAlpha, options.TuningAlpha); ...
    sprintf("Uniform meta cue 2 p < %.3g AND cue 3 p < %.3g", ...
    options.TuningAlpha, options.TuningAlpha); ...
    "Equal-weight cleaned raw meta curve has Z3D - Z2D < 0"; ...
    "At least one valid perspective behavioral fit"];
result.tuningTest = ...
    "Trial FR ~ abs(coherence) + direction; ANOVA direction-term p";
result.metaSelectionWeighting = ...
    "Equal weights across all retained channels; fixed before sigma optimization";
result.channelMultiplicityCorrection = "None (raw p, matching p_AI convention)";
result.tuningAlpha = options.TuningAlpha;
result.candidateLabel = candidateLabel;
result.candidateROI = options.ROI;
result.candidateCount = numSessionsAll;
result.sessionCount = numSessions;
result.originalRowIndex = cleanSourceRows;
result.rawBehaviorByCue = cleanBehavior;
result.positionOffset = positionOffset;
result.sigmaValues = sigmaValues;
result.originalR2ByRepeat = originalR2ByRepeat;
result.uniformR2ByRepeat = uniformR2ByRepeat;
result.originalDominantCue = originalDominantCue;
result.originalNonDominantCue = originalNonDominantCue;
result.uniformDominantCue = uniformDominantCue;
result.uniformNonDominantCue = uniformNonDominantCue;
result.sessionAudit = sessionAudit;
result.channelAudit = channelAudit;
result.flowTable = flowTable;
result.roiFlowTable = roiFlowTable;
result.original = originalSummary;
result.uniform = uniformSummary;
result.optimized = optimized;
result.methods = methods;
result.summaryTable = summaryTable;
result.pointTable = pointTable;
result.numRepeats = numRepeats;
result.numFolds = numFolds;
result.randomSeed = options.RandomSeed;

validateResult(result);
end

function output = emptySessionData()
output = struct('raw', [], 'z', [], 'coherence', [], ...
    'nonzeroIndex', [], 'aiIndex', [], 'tunedMask', [], ...
    'relativePosition', [], 'numChannels', 0);
end

function [behaviorByCue, validCount] = extractPerspectiveBehavior(unitTable)
numSessions = height(unitTable);
behaviorByCue = NaN(numSessions, 2);
for session = 1:numSessions
    bias = unitTable.Behav_bias_NminusS{session};
    goodFit = unitTable.Behav_goodfit_both{session};
    if numel(bias) < 3 || numel(goodFit) < 3
        continue
    end
    for cueIndex = 1:2
        sourceCue = cueIndex + 1;
        if logical(goodFit(sourceCue)) && isfinite(bias(sourceCue))
            behaviorByCue(session, cueIndex) = bias(sourceCue);
        end
    end
end
validCount = sum(isfinite(behaviorByCue), 2);
end

function [coherence, nonzeroIndex] = coherenceForRecording(recording)
switch size(recording, 2)
    case 12
        coherence = [-22 -14 -10 -8 -4 -2 2 4 8 10 14 22] ./ 22;
    case 13
        coherence = [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22] ./ 22;
    otherwise
        error('CurrentSpread:UnexpectedCoherenceCount', ...
            'Expected 12 or 13 coherence bins, found %d.', size(recording, 2));
end
nonzeroIndex = find(coherence ~= 0);
end

function channels = numericDeadChannels(value)
if isempty(value)
    channels = [];
elseif isnumeric(value)
    channels = value(:)';
elseif iscell(value)
    channels = cell2mat(value(:)');
else
    channels = [];
end
channels = unique(channels(isfinite(channels)));
end

function pValue = directionTuningPValue(response, coherence, nonzeroIndex)
pValue = NaN;
firingRate = [];
signedCoherence = [];
for coherenceIndex = nonzeroIndex(:)'
    values = response(coherenceIndex, :);
    values = values(isfinite(values));
    firingRate = [firingRate; values(:)]; %#ok<AGROW>
    signedCoherence = [signedCoherence; ...
        repmat(coherence(coherenceIndex), numel(values), 1)]; %#ok<AGROW>
end
if numel(firingRate) < 4 || std(firingRate) <= eps
    return
end
try
    tuningTable = table(firingRate, abs(signedCoherence), ...
        sign(signedCoherence), 'VariableNames', ...
        {'FR', 'Abs_Coherence', 'Direction'});
    linearModel = fitlm(tuningTable, ...
        'FR ~ Abs_Coherence + Direction');
    anovaResults = anova(linearModel);
    pValue = anovaResults.pValue(2);
catch
    pValue = NaN;
end
end

function [metaZ, metaRaw, channelWeights] = buildMetaTuning(data, sigma)
includedChannels = find(data.tunedMask);
if isempty(includedChannels)
    metaZ = [];
    metaRaw = [];
    channelWeights = [];
    return
end
if isinf(sigma)
    retainedWeights = ones(numel(includedChannels), 1);
else
    distance = data.relativePosition(includedChannels)';
    logWeight = -(distance .^ 2) ./ (2 .* sigma .^ 2);
    logWeight = logWeight - max(logWeight);
    retainedWeights = exp(logWeight(:));
end
retainedWeights = retainedWeights ./ sum(retainedWeights);
channelWeights = zeros(data.numChannels, 1);
channelWeights(includedChannels) = retainedWeights;
metaZ = finiteWeightedChannelMean( ...
    data.z(:, :, :, includedChannels), retainedWeights);
metaRaw = finiteWeightedChannelMean( ...
    data.raw(:, :, :, includedChannels), retainedWeights);
end

function output = finiteWeightedChannelMean(data, weights)
targetSize = size(data);
targetSize = targetSize(1:3);
numerator = zeros(targetSize);
denominator = zeros(targetSize);
for channelIndex = 1:numel(weights)
    values = data(:, :, :, channelIndex);
    finiteValues = isfinite(values);
    values(~finiteValues) = 0;
    numerator = numerator + weights(channelIndex) .* values;
    denominator = denominator + weights(channelIndex) .* finiteValues;
end
output = numerator ./ denominator;
output(denominator <= eps) = NaN;
end

function values = metaAI(metaTuningZ, aiIndex)
values = NaN(1, 2);
if isempty(metaTuningZ)
    return
end
for cue = 1:2
    response = squeeze(metaTuningZ(cue, aiIndex, :));
    values(cue) = asymmetryIndex(response);
end
end

function value = asymmetryIndex(response)
value = NaN;
if size(response, 1) ~= 8
    return
end
toward = flipud(response(5:8, :));
away = response(1:4, :);
towardMean = mean(toward, 2, 'omitnan');
awayMean = mean(away, 2, 'omitnan');
towardStd = std(toward, 0, 2, 'omitnan');
awayStd = std(away, 0, 2, 'omitnan');
denominator = abs(towardMean - awayMean) + ...
    mean([towardStd, awayStd], 2, 'omitnan');
perCoherence = (towardMean - awayMean) ./ denominator;
perCoherence(denominator <= eps) = NaN;
value = mean(perCoherence, 'omitnan');
end

function value = metaOD(metaTuningRaw, coherenceIndex)
value = NaN;
if isempty(metaTuningRaw)
    return
end
leftCurve = squeeze(mean(metaTuningRaw(1, coherenceIndex, :), 3, 'omitnan'));
rightCurve = squeeze(mean(metaTuningRaw(2, coherenceIndex, :), 3, 'omitnan'));
leftMaximum = max(leftCurve, [], 'omitnan');
rightMaximum = max(rightCurve, [], 'omitnan');
denominator = leftMaximum + rightMaximum;
if isfinite(denominator) && abs(denominator) > eps
    value = (leftMaximum - rightMaximum) ./ denominator;
end
end

function [z2D, z3D, zDifference, pairedCount] = ...
        meta2DStatistics(metaTuningRaw, nonzeroIndex, signedOD)
z2D = NaN;
z3D = NaN;
zDifference = NaN;
pairedCount = 0;
if isempty(metaTuningRaw) || ~isfinite(signedOD)
    return
end
leftCurve = squeeze(mean(metaTuningRaw(1, nonzeroIndex, :), 3, 'omitnan'));
rightCurve = squeeze(mean(metaTuningRaw(2, nonzeroIndex, :), 3, 'omitnan'));
leftCurve = leftCurve(:);
rightCurve = rightCurve(:);
valid = isfinite(leftCurve) & isfinite(rightCurve) & ...
    isfinite(flipud(leftCurve)) & isfinite(flipud(rightCurve));
valid = valid & flipud(valid);
leftCurve = leftCurve(valid);
rightCurve = rightCurve(valid);
pairedCount = numel(leftCurve);
if pairedCount <= 3 || std(leftCurve) <= eps || std(rightCurve) <= eps
    return
end
r2D = safeCorrelation(leftCurve, flipud(rightCurve));
r3D = safeCorrelation(leftCurve, rightCurve);
if signedOD > 0
    dominantCurve = leftCurve;
else
    dominantCurve = rightCurve;
end
rPrediction = safeCorrelation(dominantCurve, flipud(dominantCurve));
if any(~isfinite([r2D, r3D, rPrediction]))
    return
end
[z2D, z3D] = partialCorrelationZ(r2D, r3D, rPrediction, pairedCount);
zDifference = z3D - z2D;
end

function value = safeCorrelation(x, y)
valid = isfinite(x) & isfinite(y);
if sum(valid) < 2 || std(x(valid)) <= eps || std(y(valid)) <= eps
    value = NaN;
else
    value = corr(x(valid), y(valid));
end
end

function [z2D, z3D] = partialCorrelationZ(r2D, r3D, rPrediction, n)
denominator2D = sqrt((1 - r3D .^ 2) .* (1 - rPrediction .^ 2));
denominator3D = sqrt((1 - r2D .^ 2) .* (1 - rPrediction .^ 2));
if ~all(isfinite([denominator2D, denominator3D])) || ...
        denominator2D <= 1e-10 || denominator3D <= 1e-10 || n <= 3
    z2D = NaN;
    z3D = NaN;
    return
end
partial2D = (r2D - r3D .* rPrediction) ./ denominator2D;
partial3D = (r3D - r2D .* rPrediction) ./ denominator3D;
if ~all(isfinite([partial2D, partial3D])) || ...
        abs(partial2D) >= 1 || abs(partial3D) >= 1
    z2D = NaN;
    z3D = NaN;
    return
end
z2D = atanh(partial2D) .* sqrt(n - 3);
z3D = atanh(partial3D) .* sqrt(n - 3);
end

function output = weightsAtPositions(weights, relativePosition, positionOffset)
output = zeros(1, numel(positionOffset));
if isempty(weights)
    return
end
if numel(relativePosition) ~= numel(weights)
    error('CurrentSpread:WeightPositionMismatch', ...
        'Channel weights could not be mapped to relative positions.');
end
for index = 1:numel(weights)
    output(positionOffset == relativePosition(index)) = weights(index);
end
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

function method = optimizeFeatureGrid(features, sigmaValues, ...
        effectiveChannelsBySession, meanRealizedWeights, ...
        originalDominantCue, sourceRows, unitTable, name, odDefinition, ...
        numRepeats, numFolds, randomSeed)
[r2ByRepeat, meanR2, semR2] = crossValidatedSigmaCurve( ...
    features, numRepeats, numFolds, randomSeed);
bestIndex = bestFiniteIndex(meanR2);
if ~isfinite(bestIndex)
    error('CurrentSpread:NoValidSigma', ...
        'No candidate sigma produced a finite cross-validated R-squared.');
end
[nestedR2ByRepeat, nestedSelectedSigma] = nestedCrossValidatedR2( ...
    features, sigmaValues, numRepeats, numFolds, randomSeed);

numSigmas = numel(sigmaValues);
fullModelR2 = NaN(numSigmas, 1);
pAI = NaN(numSigmas, 1);
pAIxOD = NaN(numSigmas, 1);
numPoints = zeros(numSigmas, 1);
dominanceFlipCount = zeros(numSigmas, 1);
for sigmaIndex = 1:numSigmas
    stats = fullModelStatistics(features.ai(:, :, sigmaIndex), ...
        features.od(:, sigmaIndex), features.behavior(:, :, sigmaIndex));
    fullModelR2(sigmaIndex) = stats.r2;
    pAI(sigmaIndex) = stats.pAI;
    pAIxOD(sigmaIndex) = stats.pAIxOD;
    numPoints(sigmaIndex) = stats.numPoints;
    valid = isfinite(features.dominantCue(:, sigmaIndex)) & ...
        isfinite(originalDominantCue);
    dominanceFlipCount(sigmaIndex) = sum( ...
        features.dominantCue(valid, sigmaIndex) ~= originalDominantCue(valid));
end

medianEffective = median(effectiveChannelsBySession, 1, 'omitnan')';
meanEffective = mean(effectiveChannelsBySession, 1, 'omitnan')';
method = struct();
method.name = name;
method.odDefinition = odDefinition;
method.sigmaValues = sigmaValues;
method.r2ByRepeat = r2ByRepeat;
method.meanR2 = meanR2;
method.semR2 = semR2;
method.fullModelR2 = fullModelR2;
method.pAI = pAI;
method.pAIxOD = pAIxOD;
method.numPoints = numPoints;
method.dominanceFlipCount = dominanceFlipCount;
method.effectiveChannelsBySession = effectiveChannelsBySession;
method.medianEffectiveChannels = medianEffective;
method.meanEffectiveChannels = meanEffective;
method.meanRealizedWeights = meanRealizedWeights;
method.bestIndex = bestIndex;
method.bestSigma = sigmaValues(bestIndex);
method.bestWeights = meanRealizedWeights(:, bestIndex);
method.bestMedianEffectiveChannels = medianEffective(bestIndex);
method.bestSelectionCVR2 = meanR2(bestIndex);
method.bestSelectionCVSEM = semR2(bestIndex);
method.nestedR2ByRepeat = nestedR2ByRepeat;
method.nestedSelectedSigma = nestedSelectedSigma;
method.nestedMeanR2 = mean(nestedR2ByRepeat, 'omitnan');
method.nestedSemR2 = finiteSEM(nestedR2ByRepeat, 1);
method.features = features;
method.table = table(sigmaValues, medianEffective, meanEffective, ...
    meanR2, semR2, fullModelR2, pAI, pAIxOD, numPoints, ...
    dominanceFlipCount, 'VariableNames', {'Sigma', ...
    'MedianEffectiveChannels', 'MeanEffectiveChannels', ...
    'SelectionCVR2', 'SelectionCVSEM', 'FullModelR2', ...
    'P_AI', 'P_AIxOD', 'NPoints', 'DominanceFlipCount'});
method.bestSummary = summarizeFeatureSet(name, odDefinition, ...
    method.bestSigma, method.bestMedianEffectiveChannels, ...
    features.ai(:, :, bestIndex), features.od(:, bestIndex), ...
    features.behavior(:, :, bestIndex), ...
    features.signedOD(:, bestIndex), ...
    features.dominantCue(:, bestIndex), originalDominantCue, sourceRows, ...
    unitTable, method.bestSelectionCVR2, method.bestSelectionCVSEM, ...
    method.nestedMeanR2, method.nestedSemR2);
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
                features.ai(:, :, sigmaIndex), features.od(:, sigmaIndex), ...
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
        [testAI, testOD, testBias, testObservationIndex] = ...
            observationVectorsForSessions(features.ai(:, :, bestIndex), ...
            features.od(:, bestIndex), features.behavior(:, :, bestIndex), ...
            outerTest);
        beta = fitAIODModel(trainAI, trainOD, trainBias);
        if all(isfinite(beta))
            foldPrediction = beta(1) + beta(2) .* testAI + ...
                beta(3) .* testAI .* testOD;
        else
            foldPrediction = NaN(size(testBias));
        end
        observed(testObservationIndex) = testBias;
        predicted(testObservationIndex) = foldPrediction;
        nullPredicted(testObservationIndex) = ...
            repmat(mean(trainBias, 'omitnan'), size(testBias));
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
    r2ByRepeat(repeatIndex) = crossValidatedFeatureSet(ai, od, behavior, folds);
end
end

function [aiVector, odVector, biasVector, observationIndex] = ...
        observationVectorsForSessions(ai, od, behavior, inclusion)
[allAI, allOD, allBias, allSession] = observationVectors(ai, od, behavior);
keep = inclusion(allSession);
aiVector = allAI(keep);
odVector = allOD(keep);
biasVector = allBias(keep);
observationIndex = find(keep);
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
end

function summary = summarizeFeatureSet(name, odDefinition, sigma, ...
        effectiveChannels, ai, od, behavior, signedOD, dominantCue, ...
        originalDominantCue, sourceRows, unitTable, selectionCVR2, ...
        selectionCVSEM, nestedSelectionCVR2, nestedSelectionCVSEM)
stats = fullModelStatistics(ai, od, behavior);
[aiVector, odVector, biasVector, sessionIndex, eyeCondition] = ...
    observationVectors(ai, od, behavior);
sourceCue = [dominantCue; 5 - dominantCue];
signedODVector = [signedOD; signedOD];
sourceRowVector = [sourceRows; sourceRows];
roiVector = [string(unitTable.ROI); string(unitTable.ROI)];
originalRecVector = [unitTable.OriginalRecIdx; unitTable.OriginalRecIdx];
valid = isfinite(aiVector) & isfinite(odVector) & isfinite(biasVector);
aiVector = aiVector(valid);
odVector = odVector(valid);
biasVector = biasVector(valid);
sessionIndex = sessionIndex(valid);
eyeCondition = eyeCondition(valid);
sourceCue = sourceCue(valid);
signedODVector = signedODVector(valid);
sourceRowVector = sourceRowVector(valid);
roiVector = roiVector(valid);
originalRecVector = originalRecVector(valid);
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
summary.pointTable = table(sourceRowVector, originalRecVector, roiVector, ...
    sessionIndex, eyeCondition, sourceCue, aiVector, signedODVector, ...
    odVector, aiVector .* odVector, biasVector, ...
    'VariableNames', {'SourceRow', 'OriginalRecIdx', 'ROI', 'Session', ...
    'EyeCondition', 'SourceCue', 'AI', 'SignedOD', 'OD', 'AIxOD', ...
    'MergedEyeDeltaBias'});
end

function sessionAudit = buildSessionAudit(unitTable, sourceRows, neuroIndex, ...
        validMapping, validNeural, validBehaviorCount, validChannel, ...
        tunedChannelCount, signedOD, selectionOD, metaPLeft, metaPRight, ...
        metaTunedBoth, z2D, z3D, zDifference, pairedCount, ...
        finiteUniformFeatures, isMeta2D, included)
numSessions = height(unitTable);
metaClass = repmat("Unknown", numSessions, 1);
metaClass(metaTunedBoth & isfinite(zDifference) & zDifference < 0) = "2D";
metaClass(metaTunedBoth & isfinite(zDifference) & zDifference >= 0) = "3D";
sessionAudit = table(sourceRows, neuroIndex, string(unitTable.ROI), ...
    unitTable.StimElec, sum(validChannel, 2), tunedChannelCount, ...
    validMapping, validNeural, validBehaviorCount, signedOD, selectionOD, ...
    metaPLeft, metaPRight, metaTunedBoth, z2D, z3D, zDifference, ...
    pairedCount, metaClass, finiteUniformFeatures, isMeta2D, included, ...
    'VariableNames', {'SourceRow', 'OriginalRecIdx', 'ROI', 'StimElec', ...
    'ValidChannelCount', 'TunedBothChannelCount', 'ValidNeuroMapping', ...
    'ValidNeuralData', 'ValidPerspectiveCueCount', 'UniformMetaSignedOD', ...
    'SelectionMetaSignedOD', 'UniformMetaP_Left', 'UniformMetaP_Right', ...
    'UniformMetaTunedBoth', 'UniformMetaZ2D', 'UniformMetaZ3D', ...
    'UniformMetaZ3DMinusZ2D', 'PairedCoherenceCount', 'MetaClass', ...
    'FiniteUniformFeatures', 'IsMeta2D', 'Included'});
end

function channelAudit = buildChannelAudit(unitTable, sourceRows, neuroIndex, ...
        relativePosition, deadMask, validChannel, pLeft, pRight, tunedBoth, ...
        tuningAlpha)
numSessions = height(unitTable);
numChannels = size(pLeft, 2);
[sessionIndex, channel] = ndgrid(1:numSessions, 1:numChannels);
sessionVector = sessionIndex(:);
channelVector = channel(:);
linearIndex = sub2ind(size(pLeft), sessionVector, channelVector);
channelAudit = table(sourceRows(sessionVector), neuroIndex(sessionVector), ...
    string(unitTable.ROI(sessionVector)), sessionVector, channelVector, ...
    relativePosition(linearIndex), deadMask(linearIndex), ...
    validChannel(linearIndex), pLeft(linearIndex), pRight(linearIndex), ...
    tunedBoth(linearIndex), repmat(tuningAlpha, numel(linearIndex), 1), ...
    'VariableNames', {'SourceRow', 'OriginalRecIdx', 'ROI', 'JimSession', ...
    'Channel', 'RelativePosition', 'DeadChannel', 'ValidChannel', ...
    'P_Left', 'P_Right', 'TunedBoth', 'Alpha'});
end

function output = buildFlowTable(validMapping, validNeural, hasTuned, ...
        metaTunedBoth, isMeta2D, hasBehavior, finiteFeatures, included, ...
        candidateLabel)
stage = ["Candidate pool: " + candidateLabel; "Valid NeuroAll mapping"; ...
    "Valid multichannel neural data"; ">=1 channel tuned in both eyes"; ...
    "Uniform cleaned meta tuned in both eyes"; ...
    "Uniform cleaned meta tuning classified 2D"; ...
    ">=1 valid perspective behavior cue"; "Finite uniform AI and OD"; ...
    "Final fixed cohort"];
count = [numel(validMapping); sum(validMapping); ...
    sum(validMapping & validNeural); ...
    sum(validMapping & validNeural & hasTuned); ...
    sum(validMapping & validNeural & hasTuned & metaTunedBoth); ...
    sum(validMapping & validNeural & hasTuned & metaTunedBoth & isMeta2D); ...
    sum(validMapping & validNeural & hasTuned & isMeta2D & hasBehavior); ...
    sum(validMapping & validNeural & hasTuned & isMeta2D & hasBehavior & ...
    finiteFeatures); ...
    sum(included)];
output = table(stage, count, 'VariableNames', {'Stage', 'Count'});
end

function output = buildROIFlowTable(roi, validMapping, validNeural, ...
        hasTuned, metaTunedBoth, isMeta2D, hasBehavior, finiteFeatures, included)
group = ["All"; "MT"; "FST"];
total = zeros(3, 1);
mapped = zeros(3, 1);
neural = zeros(3, 1);
tuned = zeros(3, 1);
metaTuned = zeros(3, 1);
meta2D = zeros(3, 1);
behavior = zeros(3, 1);
finite = zeros(3, 1);
final = zeros(3, 1);
for groupIndex = 1:numel(group)
    if group(groupIndex) == "All"
        mask = true(size(roi));
    else
        mask = roi == group(groupIndex);
    end
    total(groupIndex) = sum(mask);
    mapped(groupIndex) = sum(mask & validMapping);
    neural(groupIndex) = sum(mask & validMapping & validNeural);
    tuned(groupIndex) = sum(mask & validMapping & validNeural & hasTuned);
    metaTuned(groupIndex) = sum(mask & validMapping & validNeural & ...
        hasTuned & metaTunedBoth);
    meta2D(groupIndex) = sum(mask & validMapping & validNeural & hasTuned & ...
        metaTunedBoth & isMeta2D);
    behavior(groupIndex) = sum(mask & validMapping & validNeural & hasTuned & ...
        isMeta2D & hasBehavior);
    finite(groupIndex) = sum(mask & validMapping & validNeural & hasTuned & ...
        isMeta2D & hasBehavior & finiteFeatures);
    final(groupIndex) = sum(mask & included);
end
output = table(group, total, mapped, neural, tuned, metaTuned, meta2D, ...
    behavior, finite, final, ...
    'VariableNames', {'ROI', 'CandidateTotal', 'ValidMapping', 'ValidNeural', ...
    'HasTunedBothChannel', 'MetaTunedBoth', 'Meta2D', 'ValidBehavior', ...
    'FiniteUniformFeatures', 'FinalIncluded'});
end

function folds = balancedFolds(numRows, numFolds, seed)
stream = RandStream('mt19937ar', 'Seed', seed);
order = randperm(stream, numRows);
folds = zeros(numRows, 1);
folds(order) = mod(0:numRows-1, numFolds) + 1;
end

function value = crossValidatedR2(observed, predicted, nullPredicted)
valid = isfinite(observed) & isfinite(predicted) & isfinite(nullPredicted);
modelSSE = sum((observed(valid) - predicted(valid)) .^ 2);
nullSSE = sum((observed(valid) - nullPredicted(valid)) .^ 2);
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
assert(result.candidateCount == height(result.sessionAudit));
assert(result.sessionCount == sum(result.sessionAudit.Included));
assert(result.optimized.bestIndex == ...
    bestFiniteIndex(result.optimized.meanR2));
assert(all(result.channelAudit.TunedBoth == ...
    (result.channelAudit.ValidChannel & ...
    result.channelAudit.P_Left < result.tuningAlpha & ...
    result.channelAudit.P_Right < result.tuningAlpha)));
assert(all(result.sessionAudit.IsMeta2D == ...
    (result.sessionAudit.UniformMetaTunedBoth & ...
    isfinite(result.sessionAudit.UniformMetaZ3DMinusZ2D) & ...
    result.sessionAudit.UniformMetaZ3DMinusZ2D < 0)));
for methodIndex = 1:numel(result.methods)
    points = result.methods(methodIndex).pointTable;
    assert(all(points.OD >= 0));
    assert(all(abs(points.SignedOD) - points.OD < 1e-12));
end
end

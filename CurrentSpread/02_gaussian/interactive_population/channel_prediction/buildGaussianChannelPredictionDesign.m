function [design, observed, observationMap, channelWeights] = ...
    buildGaussianChannelPredictionDesign( ...
    channelAI, channelSignedOD, channelEligible, relativePositions, ...
    behavior, behaviorValid, behaviorSignedOD, sigma, options)
%BUILDGAUSSIANCHANNELPREDICTIONDESIGN Build channel-first bias predictors.
%
% Each channel is assigned its own dominant/non-dominant eye from the sign
% of its signed OD. The channel-level design row is
%
%   [1, AI, AI*abs(OD)]
%
% in the corresponding Dominant, Combined, Stereo, or NonDominant beta
% block. Channel design rows are combined only after this local assignment,
% using Gaussian distance weights normalized over eligible channels.
%
% Input cue rows are [Combined, MonoL, MonoR, Stereo]. Output observations,
% beta blocks, and aggregation use [Dominant, Combined, Stereo, NonDominant].
% Each channel's own dominant prediction contributes to Dominant regardless
% of physical eye. behaviorSignedOD fixes the session's observed target
% assignment (stimulation-channel OD), independently of sigma and neighbors.
% PredictorMode="CombinedAI" uses [1, AI_combined] for every condition.
% PredictorMode="DominantAIxOD" uses the channel's locally dominant-eye AI:
% [1, AI_dominant*abs(local OD)].
% Both have a separate two-column beta block for each condition.

arguments
    channelAI {mustBeNumeric, mustBeReal}
    channelSignedOD {mustBeNumeric, mustBeReal}
    channelEligible {mustBeNumericOrLogical}
    relativePositions {mustBeNumeric, mustBeReal}
    behavior {mustBeNumeric, mustBeReal}
    behaviorValid {mustBeNumericOrLogical}
    behaviorSignedOD {mustBeNumeric, mustBeReal}
    sigma (1, 1) double {mustBeFinite, mustBePositive}
    options.PredictorMode (1, 1) string ...
        {mustBeMember(options.PredictorMode, ...
        ["CueAIOD", "CombinedAI", "DominantAIxOD"])} = ...
        "CueAIOD"
end

channelAI = double(channelAI);
channelSignedOD = double(channelSignedOD);
channelEligible = logical(channelEligible);
relativePositions = double(relativePositions);
behavior = double(behavior);
behaviorValid = logical(behaviorValid);
behaviorSignedOD = double(behaviorSignedOD(:));

numSessions = size(channelAI, 1);
numCues = size(channelAI, 2);
numPositions = size(channelAI, 3);
if numCues ~= 4 || ...
        ~isequal(size(channelSignedOD), [numSessions numPositions]) || ...
        ~isequal(size(channelEligible), [numSessions numPositions]) || ...
        ~isequal(size(behavior), [numSessions 4]) || ...
        ~isequal(size(behaviorValid), [numSessions 4]) || ...
        numel(behaviorSignedOD) ~= numSessions
    error('GaussianChannelPrediction:InputSize', ...
        ['Expected channelAI N-by-4-by-P, channel OD/eligibility N-by-P, ' ...
        'behavior/validity N-by-4, and behaviorSignedOD N-by-1.']);
end
if isvector(relativePositions) && numel(relativePositions) == numPositions
    relativePositions = repmat(reshape(relativePositions, 1, []), ...
        numSessions, 1);
elseif ~isequal(size(relativePositions), [numSessions numPositions])
    error('GaussianChannelPrediction:PositionSize', ...
        'relativePositions must be 1-by-P or N-by-P.');
end

dominantAI = nan(numSessions, numPositions);
if options.PredictorMode == "DominantAIxOD"
    leftAI = reshape(channelAI(:, 2, :), numSessions, numPositions);
    rightAI = reshape(channelAI(:, 3, :), numSessions, numPositions);
    dominantAI(channelSignedOD > 0) = leftAI(channelSignedOD > 0);
    dominantAI(channelSignedOD < 0) = rightAI(channelSignedOD < 0);
    predictorFinite = isfinite(dominantAI);
    numTerms = 2;
elseif options.PredictorMode == "CombinedAI"
    predictorFinite = reshape(isfinite(channelAI(:, 1, :)), ...
        numSessions, numPositions);
    numTerms = 2;
else
    predictorFinite = reshape(all(isfinite(channelAI), 2), ...
        numSessions, numPositions);
    numTerms = 3;
end
usable = channelEligible & predictorFinite & ...
    isfinite(channelSignedOD) & channelSignedOD ~= 0 & ...
    isfinite(relativePositions);
channelWeights = zeros(numSessions, numPositions);
for sessionIndex = 1:numSessions
    use = usable(sessionIndex, :);
    if ~any(use)
        continue
    end
    logWeight = -(relativePositions(sessionIndex, use) .^ 2) ./ ...
        (2 .* sigma .^ 2);
    % Subtracting the largest exponent keeps the nearest eligible channel
    % defined even when a very small sigma would otherwise underflow.
    logWeight = logWeight - max(logWeight);
    weight = exp(logWeight);
    weight = weight ./ sum(weight);
    channelWeights(sessionIndex, use) = weight;
end

maximumRows = numSessions .* 4;
design = zeros(maximumRows, 4 .* numTerms);
observed = nan(maximumRows, 1);
sessionColumn = zeros(maximumRows, 1);
conditionColumn = zeros(maximumRows, 1);
sourceCueColumn = zeros(maximumRows, 1);
behaviorCueOrder = gaussianChannelConditionCueOrder(behaviorSignedOD);
writeIndex = 0;
for sessionIndex = 1:numSessions
    use = channelWeights(sessionIndex, :) > 0;
    if ~any(use) || any(~isfinite(behaviorCueOrder(sessionIndex, :)))
        continue
    end
    channels = find(use);
    localCueOrder = gaussianChannelConditionCueOrder( ...
        channelSignedOD(sessionIndex, :));
    for condition = 1:4
        behaviorCue = behaviorCueOrder(sessionIndex, condition);
        if ~behaviorValid(sessionIndex, behaviorCue) || ...
                ~isfinite(behavior(sessionIndex, behaviorCue))
            continue
        end
        writeIndex = writeIndex + 1;
        for positionIndex = channels
            signedOD = channelSignedOD(sessionIndex, positionIndex);
            columns = (condition - 1) .* numTerms + (1:numTerms);
            if options.PredictorMode == "CombinedAI"
                ai = channelAI(sessionIndex, 1, positionIndex);
                channelDesign = [1, ai];
            elseif options.PredictorMode == "DominantAIxOD"
                channelDesign = [1, dominantAI(sessionIndex, positionIndex) .* ...
                    abs(signedOD)];
            else
                channelCue = localCueOrder(positionIndex, condition);
                ai = channelAI(sessionIndex, channelCue, positionIndex);
                channelDesign = [1, ai, ai .* abs(signedOD)];
            end
            design(writeIndex, columns) = ...
                design(writeIndex, columns) + ...
                channelWeights(sessionIndex, positionIndex) .* ...
                channelDesign;
        end
        observed(writeIndex) = behavior(sessionIndex, behaviorCue);
        sessionColumn(writeIndex) = sessionIndex;
        conditionColumn(writeIndex) = condition;
        sourceCueColumn(writeIndex) = behaviorCue;
    end
end

keep = 1:writeIndex;
design = design(keep, :);
observed = observed(keep);
sessionColumn = sessionColumn(keep);
conditionColumn = conditionColumn(keep);
sourceCueColumn = sourceCueColumn(keep);
conditionNames = ["Dominant", "Combined", "Stereo", "NonDominant"];
observationMap = table(sessionColumn, conditionColumn, ...
    reshape(conditionNames(conditionColumn), [], 1), sourceCueColumn, ...
    behaviorSignedOD(sessionColumn), ...
    'VariableNames', {'SessionIndex', 'ConditionIndex', 'Condition', ...
    'BehaviorSourceCueIndex', 'BehaviorReferenceSignedOD'});
end

function data = buildCombinedAIStimComparisonDesign(cache, options)
%BUILDCOMBINEDAISTIMCOMPARISONDESIGN Match Gaussian and literal stim predictor.
% Both models use the requested channel predictor with independent beta per behavior
% cue. The common cohort requires the stimulation contact itself to be live,
% finite, and significant in both eyes, matching the channel eligibility gate.
% The selected neuron's significance is source p_AI; neighboring contacts
% use their own raw direction tests, shared with the ordinary-fit selector.
% Stim-only uses a literal one-hot mask, never a small-sigma approximation.

arguments
    cache (1, 1) struct
    options.UnitType (1, 1) string {mustBeMember(options.UnitType, ["2D", "3D"])} = "2D"
    options.SigmaValues (:, 1) double {mustBeFinite, mustBePositive} = []
    options.PredictorMode (1, 1) string ...
        {mustBeMember(options.PredictorMode, ...
        ["CombinedAI", "DominantAIxOD"])} = "DominantAIxOD"
end
sigmaValues = options.SigmaValues;
if isempty(sigmaValues)
    sigmaValues = double(cache.SigmaValues(:));
end
sigmaValues = sort(unique(sigmaValues));
if isempty(sigmaValues)
    error('GaussianStimCV:EmptySigmaGrid', 'A nonempty sigma grid is required.');
end
selection = selectGaussianChannelPredictionCohort(cache, options.UnitType, options.PredictorMode);
mask = selection.SessionMask;
if ~any(mask)
    error('GaussianStimCV:NoMatchedSessions', 'No source-both-eye-significant neurons have eligible stimulation inputs.');
end
ai = double(cache.ChannelAI);
signedOD = double(cache.ChannelSignedOD);
positions = double(cache.ChannelRelativePositions);
eligible = selection.ChannelEligible;
stimMask = selection.StimChannelMask;
referenceOD = double(cache.StimReferenceOD(:));
behavior = double(cache.BehaviorByPhysicalCue);
validBehavior = selection.BehaviorValid;
channelPredictor = selection.ChannelPredictor;
audit = selection.Audit;
sourceRows = double(cache.SourceRows(mask));
ai = ai(mask, :, :);
signedOD = signedOD(mask, :);
positions = positions(mask, :);
eligible = eligible(mask, :);
stimMask = stimMask(mask, :);
referenceOD = referenceOD(mask);
behavior = behavior(mask, :);
validBehavior = validBehavior(mask, :);

% The scalar sigma here is an unused placeholder: exactly one eligible
% contact has weight one regardless of its value.
[stimDesign, y, map, stimWeights] = buildGaussianChannelPredictionDesign( ...
    ai, signedOD, stimMask, positions, behavior, validBehavior, referenceOD, 1, ...
    PredictorMode=options.PredictorMode);
assert(isequal(stimWeights, double(stimMask)), 'GaussianStimCV:StimWeightMismatch', ...
    'Stim-only weights must be exactly one at StimChannel and zero elsewhere.');
channelPredictor = channelPredictor(mask, :);
stimPredictor = zeros(nnz(mask), 1);
for session = 1:nnz(mask)
    stimPredictor(session) = ...
        channelPredictor(session, stimMask(session, :));
end
for condition = 1:4
    rows = map.ConditionIndex == condition;
    columns = (condition - 1) .* 2 + (1:2);
    expected = [ones(nnz(rows), 1), ...
        stimPredictor(map.SessionIndex(rows))];
    assert(isequal(stimDesign(rows, columns), expected), ...
        'GaussianStimCV:StimPredictorMismatch', ...
        'Baseline must use the requested predictor at the actual stimulation channel.');
end
gaussianDesign = zeros(numel(y), 8, numel(sigmaValues));
for sigmaIndex = 1:numel(sigmaValues)
    [gaussianDesign(:, :, sigmaIndex), newY, newMap] = ...
        buildGaussianChannelPredictionDesign(ai, signedOD, eligible, positions, ...
            behavior, validBehavior, referenceOD, sigmaValues(sigmaIndex), ...
            PredictorMode=options.PredictorMode);
    assert(isequaln(y, newY) && isequal(map, newMap), ...
        'GaussianStimCV:UnmatchedTargets', 'Both models must predict the same observations at every sigma.');
end
data = struct('StimDesign', stimDesign, 'GaussianDesign', gaussianDesign, ...
    'Observed', y, 'ObservationMap', map, 'SigmaValues', sigmaValues, ...
    'SourceRows', sourceRows, 'SessionMask', mask, 'SessionAudit', audit, ...
    'SessionCount', nnz(mask), 'StimChannelMask', stimMask, ...
    'GaussianChannelMask', eligible, 'StimPredictor', stimPredictor, ...
    'ChannelPredictor', channelPredictor, ...
    'SourceTuningP', selection.SourceTuningP(mask, :), ...
    'EffectiveChannelTuningP', selection.EffectiveChannelTuningP(mask, :, :), ...
    'RawChannelTuningP', selection.RawChannelTuningP(mask, :, :), ...
    'ChannelTuningSource', selection.ChannelTuningSource(mask, :), ...
    'CohortDefinition', selection.Definition, ...
    'PredictorMode', options.PredictorMode);
end

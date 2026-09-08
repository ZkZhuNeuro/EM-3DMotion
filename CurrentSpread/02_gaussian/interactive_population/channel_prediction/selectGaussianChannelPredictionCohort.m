function selection = selectGaussianChannelPredictionCohort(cache, unitType, predictorMode)
%SELECTGAUSSIANCHANNELPREDICTIONCOHORT One both-eye gate for all channel fits.
% Neuron/site inclusion uses source unit_table_gof.p_AI at StimElec. At that
% contact these are also the authoritative channel p-values; neighboring
% contacts use their own cached raw direction-tuning tests. Raw recomputed
% stimulation p-values are retained for audit, never substituted for p_AI.

arguments
    cache (1, 1) struct
    unitType (1, 1) string {mustBeMember(unitType, ["2D", "3D"])}
    predictorMode (1, 1) string ...
        {mustBeMember(predictorMode, ["CombinedAI", "DominantAIxOD", "CueAIOD"])}
end
n = size(cache.ChannelAI, 1);
p = size(cache.ChannelAI, 3);
sourceP = sourceTuningP(cache, n);
rawP = double(cache.ChannelTuningP);
if ~isequal(size(rawP), size(cache.ChannelAI)) || ~isequal(size(sourceP), [n 4])
    error('GaussianCohort:TuningSize', 'Expected N-by-4 source p-values and N-by-4-by-P channel tests.');
end
stimMatch = double(cache.ChannelNumbers) == double(cache.StimChannel(:));
uniqueStim = sum(stimMatch, 2) == 1;
effectiveP = rawP;
tuningSource = repmat("QuickRawDirection", n, p);
stimRawLeftP = nan(n, 1);
stimRawRightP = nan(n, 1);
for row = 1:n
    if ~uniqueStim(row)
        continue
    end
    column = find(stimMatch(row, :));
    stimRawLeftP(row) = rawP(row, 2, column);
    stimRawRightP(row) = rawP(row, 3, column);
    effectiveP(row, :, column) = sourceP(row, :);
    tuningSource(row, column) = "UnitTable_p_AI";
end
alpha = double(cache.TuningAlpha);
sourceBoth = validP(sourceP(:, 2), alpha) & validP(sourceP(:, 3), alpha);
channelLeftP = reshape(effectiveP(:, 2, :), n, p);
channelRightP = reshape(effectiveP(:, 3, :), n, p);
channelBoth = validP(channelLeftP, alpha) & validP(channelRightP, alpha);
rawStimBoth = validP(stimRawLeftP, alpha) & validP(stimRawRightP, alpha);
ai = double(cache.ChannelAI);
od = double(cache.ChannelSignedOD);
if predictorMode == "DominantAIxOD"
    leftAI = reshape(ai(:, 2, :), n, p);
    rightAI = reshape(ai(:, 3, :), n, p);
    predictor = nan(n, p);
    predictor(od > 0) = leftAI(od > 0);
    predictor(od < 0) = rightAI(od < 0);
    predictor = predictor .* abs(od);
    predictorFinite = isfinite(predictor);
else
    predictor = reshape(ai(:, 1, :), n, p);
    if predictorMode == "CueAIOD"
        predictorFinite = reshape(all(isfinite(ai), 2), n, p);
    else
        predictorFinite = isfinite(predictor);
    end
end
positions = double(cache.ChannelRelativePositions);
eligible = logical(cache.ChannelAvailable) & channelBoth & predictorFinite & ...
    isfinite(od) & od ~= 0 & isfinite(positions);
eligibleStim = stimMatch & eligible;
hasStim = uniqueStim & any(eligibleStim, 2);
referenceOD = double(cache.StimReferenceOD(:));
if unitType == "2D"
    classMask = cache.StimZ3DMinusZ2D(:) < 0;
else
    classMask = cache.StimZ3DMinusZ2D(:) > 0;
end
behavior = double(cache.BehaviorByPhysicalCue);
behaviorValid = logical(cache.BehaviorValidByPhysicalCue) & isfinite(behavior);
base = strcmp(string(cache.SessionStatus(:)), "Success") & classMask & ...
    isfinite(referenceOD) & referenceOD ~= 0 & any(behaviorValid, 2);
included = base & sourceBoth & hasStim;
assert(all(sourceBoth(included)), 'GaussianCohort:InvalidNeuron', ...
    'Every selected neuron must have source MonoL and MonoR p_AI below alpha.');
assert(all(channelBoth(eligible)), 'GaussianCohort:InvalidChannel', ...
    'Every contributing channel must pass both eye tests.');
if any(positions(eligibleStim & included) ~= 0)
    error('GaussianCohort:StimPosition', 'The mapped stimulation channel must be at relative position zero.');
end

audit = table(double(cache.SourceRows(:)), double(cache.StimChannel(:)), ...
    base, sourceP(:, 2), sourceP(:, 3), stimRawLeftP, stimRawRightP, ...
    sourceBoth, rawStimBoth, sourceBoth ~= rawStimBoth, any(eligible, 2), ...
    hasStim, sum(eligible, 2), included, 'VariableNames', ...
    {'SourceTableRow', 'StimChannel', 'BaseCandidate', 'SourceMonoLP', ...
    'SourceMonoRP', 'RecomputedStimMonoLP', 'RecomputedStimMonoRP', ...
    'SourceStimBothEyesSignificant', 'RecomputedStimBothEyesSignificant', ...
    'StimSignificanceDisagrees', 'HasEligibleGaussianChannel', ...
    'HasEligibleStimChannel', 'EligibleChannelCount', 'Included'});
audit.Reason = repmat("Not requested class or invalid processing/behavior/reference", n, 1);
audit.Reason(base & ~sourceBoth) = "Source stimulation-neuron MonoL or MonoR p_AI fails significance";
audit.Reason(base & sourceBoth & ~hasStim) = "Source-significant stim neuron lacks a unique live finite predictor";
audit.Reason(included) = "Source stim neuron and every contributing channel pass both-eye gate";
selection = struct('Definition', "SourceStimBothEyes_ChannelBothEyes_v1", ...
    'SessionMask', included, 'ChannelEligible', eligible, ...
    'StimChannelMask', eligibleStim, 'SourceTuningP', sourceP, ...
    'EffectiveChannelTuningP', effectiveP, 'RawChannelTuningP', rawP, ...
    'ChannelTuningSource', tuningSource, 'ChannelPredictor', predictor, ...
    'BehaviorValid', behaviorValid, 'Audit', audit);
end

function passed = validP(values, alpha)
passed = isfinite(values) & values >= 0 & values < alpha;
end

function values = sourceTuningP(cache, numSessions)
if isfield(cache, 'StimChannelSourceP')
    values = double(cache.StimChannelSourceP);
    return
end
if ~isfield(cache, 'StateFile') || ~isfile(cache.StateFile)
    error('GaussianCohort:MissingSourceP', ...
        'Cache needs StimChannelSourceP or the original StateFile; recomputed p-values cannot replace source p_AI.');
end
loaded = load(cache.StateFile, 'unit_table_gof');
t = loaded.unit_table_gof;
sourceRows = double(cache.SourceRows(:));
if numel(sourceRows) ~= numSessions || any(sourceRows < 1 | sourceRows > height(t) | sourceRows ~= fix(sourceRows))
    error('GaussianCohort:SourceRows', 'Cached source rows no longer align with the source table.');
end
values = nan(numSessions, 4);
for row = 1:numSessions
    sourceRow = sourceRows(row);
    stim = rowValue(t.StimElec, sourceRow);
    if isfinite(cache.StimChannel(row)) && ~isequal(double(stim), double(cache.StimChannel(row)))
        error('GaussianCohort:SourceIdentity', 'Stimulation channel differs at source row %d; rebuild the cache.', sourceRow);
    end
    if isfield(cache, 'Monkey') && ~strcmpi(string(rowValue(t.Monkey, sourceRow)), string(cache.Monkey(row)))
        error('GaussianCohort:SourceIdentity', 'Monkey differs at source row %d; rebuild the cache.', sourceRow);
    end
    if isfield(cache, 'Date') && isdatetime(t.Date) && ...
            dateshift(t.Date(sourceRow), 'start', 'day') ~= dateshift(cache.Date(row), 'start', 'day')
        error('GaussianCohort:SourceIdentity', 'Date differs at source row %d; rebuild the cache.', sourceRow);
    end
    pValues = double(rowValue(t.p_AI, sourceRow));
    count = min(4, numel(pValues));
    values(row, 1:count) = reshape(pValues(1:count), 1, count);
end
end

function value = rowValue(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
while iscell(value) && isscalar(value)
    value = value{1};
end
end

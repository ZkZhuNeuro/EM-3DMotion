function [unitTablePrepared, eligibleMask, audit] = ...
    BuildEqualFiveChannelMetaQuickAI(unitTable, options)
%BUILDEQUALFIVECHANNELMETAQUICKAI Build a trial-level five-contact Quick AI.
%
% For physical probe positions -2:-1:2 relative to the stimulation
% contact, every live channel is standardized once across all of its valid
% Quick-task trials (all cues and coherences). The five standardized firing
% rates are then averaged trial-by-trial with fixed weights of 1/5. Cue AIs
% are recalculated from this meta response over the four strongest matched
% nonzero coherence pairs, matching the original CurrentSpread analyses,
% using the legacy pairwise definition:
%
%   (toward-away) / (abs(toward-away) + (SDtoward+SDaway)/2)
%
% A row is eligible only when all five physical contacts exist, are live,
% have finite nonconstant Quick responses, and yield finite meta AI, meta
% maximum-response OD, and meta Z3D-Z2D values. AI is based on the z-scored
% meta curve. OD and 2D/3D statistics are based on an equal-weight raw-FR
% meta curve built from the same five contacts and trials. p_AI is untouched.

arguments
    unitTable table
    options.JimCacheFolder (1, 1) string = "C:\Jim\StimData"
    options.ClayCacheFolder (1, 1) string = "C:\Clay\StimData"
    options.ChannelMap (1, :) double ...
        {mustBeInteger, mustBePositive} = ...
        [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]
    options.CandidateMask (:, 1) logical = false(0, 1)
    options.WeightingMode (1, 1) string ...
        {mustBeMember(options.WeightingMode, ...
        ["EqualFive", "GaussianAll"])} = "EqualFive"
    options.GaussianSigma (1, 1) double = NaN
end

if options.WeightingMode == "GaussianAll" && ...
        (~isfinite(options.GaussianSigma) || options.GaussianSigma <= 0)
    error('FiveChannelMeta:InvalidGaussianSigma', ...
        'GaussianSigma must be finite and positive in GaussianAll mode.');
end

requireVariables(unitTable, ["Date", "Monkey", "ROI", "StimElec", ...
    "NChannels", "AI", "OD_max", "Z3D_v_Z2D"]);
rowCount = height(unitTable);
candidateMask = options.CandidateMask;
if isempty(candidateMask)
    candidateMask = true(rowCount, 1);
elseif numel(candidateMask) ~= rowCount
    error('FiveChannelMeta:CandidateMaskSize', ...
        'CandidateMask must contain one value per unit-table row.');
end

unitTablePrepared = unitTable;
sourceTableRow = (1:rowCount)';
unitTablePrepared.MetaSourceTableRow = sourceTableRow;
unitTablePrepared.MetaQuickAI = repmat({nan(4, 1)}, rowCount, 1);
unitTablePrepared.MetaQuickChannels = repmat({nan(1, 5)}, rowCount, 1);
unitTablePrepared.MetaQuickWeights = repmat({nan(1, 5)}, rowCount, 1);
unitTablePrepared.MetaQuickWeightingMode = ...
    repmat(options.WeightingMode, rowCount, 1);
unitTablePrepared.MetaQuickGaussianSigma = ...
    repmat(options.GaussianSigma, rowCount, 1);
unitTablePrepared.MetaQuickEligible = false(rowCount, 1);

recordingDate = normalizeDateColumn(unitTable.Date);
monkey = strings(rowCount, 1);
roi = strings(rowCount, 1);
stimChannel = nan(rowCount, 1);
stimProbePosition = nan(rowCount, 1);
minus2Channel = nan(rowCount, 1);
minus1Channel = nan(rowCount, 1);
plus1Channel = nan(rowCount, 1);
plus2Channel = nan(rowCount, 1);
channelSet = repmat({nan(1, 5)}, rowCount, 1);
relativePositionSet = repmat({nan(1, 5)}, rowCount, 1);
metaWeights = repmat({nan(1, 5)}, rowCount, 1);
channelCenter = repmat({nan(1, 5)}, rowCount, 1);
channelScale = repmat({nan(1, 5)}, rowCount, 1);
channelObservationCount = repmat({zeros(1, 5)}, rowCount, 1);
coherence = repmat({nan(1, 0)}, rowCount, 1);
metaMean = repmat({nan(4, 0)}, rowCount, 1);
metaSEM = repmat({nan(4, 0)}, rowCount, 1);
metaCount = repmat({zeros(4, 0)}, rowCount, 1);
metaRawMean = repmat({nan(4, 0)}, rowCount, 1);
metaRawSEM = repmat({nan(4, 0)}, rowCount, 1);
metaRawCount = repmat({zeros(4, 0)}, rowCount, 1);
stimMean = repmat({nan(4, 0)}, rowCount, 1);
stimSEM = repmat({nan(4, 0)}, rowCount, 1);
stimCount = repmat({zeros(4, 0)}, rowCount, 1);
metaPLeft = nan(rowCount, 1);
metaPRight = nan(rowCount, 1);
originalStimAI = repmat({nan(4, 1)}, rowCount, 1);
reconstructedStimAI = repmat({nan(4, 1)}, rowCount, 1);
metaAI = repmat({nan(4, 1)}, rowCount, 1);
maxAbsStimAIReconstructionError = nan(rowCount, 1);
originalODMax = nan(rowCount, 1);
metaODMax = nan(rowCount, 1);
originalZ3DMinusZ2D = nan(rowCount, 1);
metaZ2D = nan(rowCount, 1);
metaZ3D = nan(rowCount, 1);
metaZ3DMinusZ2D = nan(rowCount, 1);
metaPairedCoherenceCount = zeros(rowCount, 1);
dominantEyeChanged = false(rowCount, 1);
unitTypeChanged = false(rowCount, 1);
cacheFile = strings(rowCount, 1);
status = repmat("Pending", rowCount, 1);
message = strings(rowCount, 1);

for row = 1:rowCount
    monkey(row) = getRowText(unitTable.Monkey, row);
    roi(row) = getRowText(unitTable.ROI, row);
    if ~candidateMask(row)
        status(row) = "NotCandidate";
        continue
    end

    try
        stimChannel(row) = numericScalar(unitTable.StimElec, row);
        declaredChannelCount = numericScalar(unitTable.NChannels, row);
        aiValues = numericArray(unitTable.AI, row);
        validateChannelIndex(stimChannel(row), 'stimulation channel');
        if size(aiValues, 1) < 4 || ...
                stimChannel(row) > size(aiValues, 2)
            error('FiveChannelMeta:InvalidStoredAI', ...
                'Stored four-cue AI is unavailable at the stimulation channel.');
        end
        originalStimAI{row} = double(aiValues(1:4, stimChannel(row)));
        if ismember('OD_max', unitTable.Properties.VariableNames)
            originalODMax(row) = numericScalar(unitTable.OD_max, row);
        end
        if ismember('Z3D_v_Z2D', unitTable.Properties.VariableNames)
            originalZ3DMinusZ2D(row) = ...
                numericScalar(unitTable.Z3D_v_Z2D, row);
        end

        stimPosition = find(options.ChannelMap == stimChannel(row), 1);
        if isempty(stimPosition)
            error('FiveChannelMeta:UnmappedStimChannel', ...
                'Stimulation channel is absent from ChannelMap.');
        end
        stimProbePosition(row) = stimPosition;
        if options.WeightingMode == "EqualFive"
            requestedPositions = stimPosition + (-2:2);
            if requestedPositions(1) < 1 || ...
                    requestedPositions(end) > numel(options.ChannelMap)
                error('FiveChannelMeta:OutsideProbe', ...
                    ['The stimulation contact does not have two contacts ' ...
                    'on both sides.']);
            end
        else
            requestedPositions = 1:numel(options.ChannelMap);
        end
        channels = options.ChannelMap(requestedPositions);
        neighborPositions = stimPosition + [-2 -1 1 2];
        neighborChannels = nan(1, 4);
        insideProbe = neighborPositions >= 1 & ...
            neighborPositions <= numel(options.ChannelMap);
        neighborChannels(insideProbe) = ...
            options.ChannelMap(neighborPositions(insideProbe));
        minus2Channel(row) = neighborChannels(1);
        minus1Channel(row) = neighborChannels(2);
        plus1Channel(row) = neighborChannels(3);
        plus2Channel(row) = neighborChannels(4);

        cacheFolder = selectCacheFolder(monkey(row), ...
            options.JimCacheFolder, options.ClayCacheFolder);
        cacheFile(row) = fullfile(cacheFolder, ...
            string(recordingDate(row), 'yyyyMMdd') + ".mat");
        if ~isfile(cacheFile(row))
            error('FiveChannelMeta:MissingCache', ...
                'Quick cache does not exist: %s', cacheFile(row));
        end
        loaded = load(cacheFile(row), 'Neuro');
        if ~isfield(loaded, 'Neuro')
            error('FiveChannelMeta:MissingNeuro', ...
                'Quick cache does not contain Neuro.');
        end
        Neuro = loaded.Neuro;
        validateNeuro(Neuro);

        availableChannelCount = min([declaredChannelCount, ...
            size(aiValues, 2), size(Neuro.All, 4)]);
        deadChannels = getDeadChannels(unitTable, row);
        if options.WeightingMode == "EqualFive"
            if any(channels > availableChannelCount)
                error('FiveChannelMeta:UnavailableChannel', ...
                    ['Required channels %s exceed the available channel ' ...
                    'count of %d.'], mat2str(channels), availableChannelCount);
            end
            deadRequired = intersect(channels, deadChannels, 'stable');
            if ~isempty(deadRequired)
                error('FiveChannelMeta:DeadChannel', ...
                    'Required channel(s) marked dead: %s.', ...
                    mat2str(deadRequired));
            end
        else
            keep = channels <= availableChannelCount & ...
                ~ismember(channels, deadChannels);
            channels = channels(keep);
            requestedPositions = requestedPositions(keep);
            if isempty(channels) || ~ismember(stimChannel(row), channels)
                error('FiveChannelMeta:NoLiveGaussianChannels', ...
                    ['No valid Gaussian channel set containing the ' ...
                    'stimulation channel is available.']);
            end
        end

        relativePositions = requestedPositions - stimPosition;
        if options.WeightingMode == "EqualFive"
            weights = ones(1, numel(channels));
        else
            weights = exp(-(relativePositions .^ 2) ./ ...
                (2 .* options.GaussianSigma .^ 2));
        end
        weights = weights ./ sum(weights);
        channelSet{row} = channels;
        relativePositionSet{row} = relativePositions;
        metaWeights{row} = weights;

        thisCoherence = getNeuroCoherence(Neuro);
        coherence{row} = thisCoherence;
        [metaTrials, rawMetaTrials, centers, scales, observationCounts] = ...
            buildMetaTrials(Neuro, channels, weights);
        [thisMetaAI, thisMetaMean, thisMetaSEM, thisMetaCount] = ...
            calculateAIFromTrials(metaTrials, Neuro.Trials.NumTrials, ...
            thisCoherence);
        [~, thisRawMean, thisRawSEM, thisRawCount] = ...
            calculateAIFromTrials(rawMetaTrials, ...
            Neuro.Trials.NumTrials, thisCoherence);
        [thisStimAI, thisStimMean, thisStimSEM, thisStimCount] = ...
            calculateAIFromTrials( ...
            Neuro.All(:, :, :, stimChannel(row)), ...
            Neuro.Trials.NumTrials, thisCoherence);
        thisMetaPLeft = directionTuningPValue( ...
            rawMetaTrials, Neuro.Trials.NumTrials, 2, thisCoherence);
        thisMetaPRight = directionTuningPValue( ...
            rawMetaTrials, Neuro.Trials.NumTrials, 3, thisCoherence);
        if any(~isfinite(thisMetaAI))
            error('FiveChannelMeta:NonfiniteMetaAI', ...
                'At least one cue has no finite meta AI.');
        end
        thisMetaOD = calculateMetaMaxOD(thisRawMean, thisRawCount);
        [thisMetaZ2D, thisMetaZ3D, thisMetaZDifference, pairedCount] = ...
            calculateMeta2DStatistics(thisRawMean, thisRawCount, ...
            thisCoherence, thisMetaOD);
        if ~isfinite(thisMetaOD) || thisMetaOD == 0
            error('FiveChannelMeta:NonfiniteMetaOD', ...
                'The five-channel meta maximum-response OD is zero or nonfinite.');
        end
        if ~isfinite(thisMetaZDifference) || thisMetaZDifference == 0
            error('FiveChannelMeta:NonfiniteMetaClass', ...
                'The five-channel meta Z3D-Z2D value is zero or nonfinite.');
        end

        channelCenter{row} = centers;
        channelScale{row} = scales;
        channelObservationCount{row} = observationCounts;
        metaMean{row} = thisMetaMean;
        metaSEM{row} = thisMetaSEM;
        metaCount{row} = thisMetaCount;
        metaRawMean{row} = thisRawMean;
        metaRawSEM{row} = thisRawSEM;
        metaRawCount{row} = thisRawCount;
        stimMean{row} = thisStimMean;
        stimSEM{row} = thisStimSEM;
        stimCount{row} = thisStimCount;
        metaPLeft(row) = thisMetaPLeft;
        metaPRight(row) = thisMetaPRight;
        reconstructedStimAI{row} = thisStimAI;
        metaAI{row} = thisMetaAI;
        metaODMax(row) = thisMetaOD;
        metaZ2D(row) = thisMetaZ2D;
        metaZ3D(row) = thisMetaZ3D;
        metaZ3DMinusZ2D(row) = thisMetaZDifference;
        metaPairedCoherenceCount(row) = pairedCount;
        dominantEyeChanged(row) = isfinite(originalODMax(row)) && ...
            sign(originalODMax(row)) ~= sign(thisMetaOD);
        unitTypeChanged(row) = isfinite(originalZ3DMinusZ2D(row)) && ...
            sign(originalZ3DMinusZ2D(row)) ~= sign(thisMetaZDifference);
        difference = abs(thisStimAI - originalStimAI{row});
        maxAbsStimAIReconstructionError(row) = ...
            max(difference, [], 'omitnan');

        updatedAI = aiValues;
        updatedAI(1:4, stimChannel(row)) = thisMetaAI;
        unitTablePrepared.AI{row} = updatedAI;
        unitTablePrepared = setNumericRowValue( ...
            unitTablePrepared, 'OD_max', row, thisMetaOD);
        unitTablePrepared = setNumericRowValue( ...
            unitTablePrepared, 'Z3D_v_Z2D', row, thisMetaZDifference);
        unitTablePrepared.MetaQuickAI{row} = thisMetaAI;
        unitTablePrepared.MetaQuickChannels{row} = channels;
        unitTablePrepared.MetaQuickWeights{row} = weights;
        unitTablePrepared.MetaQuickEligible(row) = true;
        status(row) = "Success";
    catch ME
        status(row) = "Error";
        message(row) = string(ME.identifier) + ": " + string(ME.message);
    end
end

eligibleMask = candidateMask & status == "Success";
audit = table(sourceTableRow, monkey, recordingDate, roi, candidateMask, ...
    stimChannel, stimProbePosition, minus2Channel, minus1Channel, ...
    plus1Channel, plus2Channel, channelSet, relativePositionSet, ...
    metaWeights, channelCenter, channelScale, ...
    channelObservationCount, coherence, originalStimAI, ...
    reconstructedStimAI, maxAbsStimAIReconstructionError, metaAI, ...
    metaMean, metaSEM, metaCount, metaRawMean, metaRawSEM, metaRawCount, ...
    stimMean, stimSEM, stimCount, metaPLeft, metaPRight, ...
    originalODMax, metaODMax, originalZ3DMinusZ2D, metaZ2D, metaZ3D, ...
    metaZ3DMinusZ2D, metaPairedCoherenceCount, dominantEyeChanged, ...
    unitTypeChanged, cacheFile, status, message, eligibleMask, ...
    'VariableNames', {'SourceTableRow', 'Monkey', 'Date', 'ROI', ...
    'CandidateForPopulation', 'StimChannel', 'StimProbePosition', ...
    'Minus2Channel', 'Minus1Channel', 'Plus1Channel', 'Plus2Channel', ...
    'FiveChannels', 'RelativeChannelPositions', 'MetaWeights', ...
    'ChannelZCenter', 'ChannelZScale', ...
    'ChannelObservationCount', 'Coherence', 'StoredStimAI', ...
    'ReconstructedStimAI', 'MaxAbsStimAIReconstructionError', ...
    'MetaAI', 'MetaMean', 'MetaSEM', 'MetaCount', ...
    'MetaRawMean', 'MetaRawSEM', 'MetaRawCount', ...
    'StimMean', 'StimSEM', 'StimCount', 'MetaPLeft', 'MetaPRight', ...
    'OriginalODMax', 'MetaODMax', 'OriginalZ3DMinusZ2D', ...
    'MetaZ2D', 'MetaZ3D', 'MetaZ3DMinusZ2D', ...
    'MetaPairedCoherenceCount', 'DominantEyeChanged', ...
    'UnitTypeChanged', 'CacheFile', ...
    'Status', 'Message', 'Eligible'});
audit.MetaChannels = audit.FiveChannels;
if options.WeightingMode == "EqualFive"
    audit.Properties.Description = [ ...
        'Equal-weight five-contact Quick meta tuning. Each physical channel ' ...
        'is z-scored across all valid Quick trials before the five channels ' ...
        'are averaged trial-by-trial with weight 1/5. AI uses the z-scored ' ...
        'meta curve; maximum-response OD and Z3D-Z2D use the equal-weight raw ' ...
        'five-channel meta curve.'];
else
    audit.Properties.Description = sprintf([ ...
        'All-live-channel Quick meta tuning with one shared Gaussian sigma ' ...
        'of %.12g physical contact spacings. Each channel is z-scored ' ...
        'across all valid Quick trials before the fixed distance weights ' ...
        'are applied. AI uses the z-scored meta curve; maximum-response OD ' ...
        'and Z3D-Z2D use the matching raw-FR Gaussian meta curve.'], ...
        options.GaussianSigma);
end
end


function value = calculateMetaMaxOD(rawMean, rawCount)
value = NaN;
if size(rawMean, 1) < 3
    return
end
valid = rawCount(2, :) > 0 & rawCount(3, :) > 0 & ...
    isfinite(rawMean(2, :)) & isfinite(rawMean(3, :));
if ~any(valid)
    return
end
leftMaximum = max(rawMean(2, valid), [], 'omitnan');
rightMaximum = max(rawMean(3, valid), [], 'omitnan');
denominator = leftMaximum + rightMaximum;
if isfinite(denominator) && abs(denominator) > eps
    value = (leftMaximum - rightMaximum) ./ denominator;
end
end


function [z2D, z3D, difference, pairedCount] = ...
    calculateMeta2DStatistics(rawMean, rawCount, coherence, signedOD)
z2D = NaN;
z3D = NaN;
difference = NaN;
pairedCount = 0;
if size(rawMean, 1) < 3 || ~isfinite(signedOD)
    return
end
coherence = double(coherence(:)');
tolerance = max(1e-12, 32 * eps(max(1, max(abs(coherence)))));
columns = find(abs(coherence) > tolerance);
[~, order] = sort(coherence(columns));
columns = columns(order);
leftCurve = rawMean(2, columns)';
rightCurve = rawMean(3, columns)';
valid = rawCount(2, columns)' > 0 & rawCount(3, columns)' > 0 & ...
    isfinite(leftCurve) & isfinite(rightCurve) & ...
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
[z2D, z3D] = partialCorrelationZ( ...
    r2D, r3D, rPrediction, pairedCount);
difference = z3D - z2D;
end


function value = safeCorrelation(x, y)
valid = isfinite(x) & isfinite(y);
if nnz(valid) < 2 || std(x(valid)) <= eps || std(y(valid)) <= eps
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


function [metaTrials, rawMetaTrials, centers, scales, observationCounts] = ...
    buildMetaTrials(Neuro, channels, weights)
cueCount = min(4, size(Neuro.All, 1));
coherenceCount = size(Neuro.All, 2);
trialCapacity = size(Neuro.All, 3);
channelCount = numel(channels);
centers = nan(1, channelCount);
scales = nan(1, channelCount);
observationCounts = zeros(1, channelCount);

for index = 1:channelCount
    values = validChannelObservations(Neuro, channels(index), cueCount, ...
        coherenceCount, trialCapacity);
    centers(index) = mean(values, 'omitnan');
    scales(index) = std(values, 0, 'omitnan');
    observationCounts(index) = nnz(isfinite(values));
    if observationCounts(index) < 2 || ~isfinite(scales(index)) || ...
            scales(index) <= eps(max(1, abs(centers(index))))
        error('FiveChannelMeta:ZeroVariance', ...
            'Channel %d has fewer than two finite observations or zero variance.', ...
            channels(index));
    end
end

metaTrials = nan(cueCount, coherenceCount, trialCapacity);
rawMetaTrials = nan(cueCount, coherenceCount, trialCapacity);
for cue = 1:cueCount
    for coherenceIndex = 1:coherenceCount
        trialCount = boundedTrialCount(Neuro.Trials.NumTrials, cue, ...
            coherenceIndex, trialCapacity);
        if trialCount == 0
            continue
        end
        raw = reshape(double(Neuro.All(cue, coherenceIndex, ...
            1:trialCount, channels)), trialCount, channelCount);
        standardized = (raw - centers) ./ scales;
        complete = all(isfinite(standardized), 2);
        values = nan(trialCount, 1);
        values(complete) = standardized(complete, :) * weights(:);
        metaTrials(cue, coherenceIndex, 1:trialCount) = values;
        rawValues = nan(trialCount, 1);
        rawValues(complete) = raw(complete, :) * weights(:);
        rawMetaTrials(cue, coherenceIndex, 1:trialCount) = rawValues;
    end
end
end


function values = validChannelObservations( ...
    Neuro, channel, cueCount, coherenceCount, trialCapacity)
values = nan(0, 1);
for cue = 1:cueCount
    for coherenceIndex = 1:coherenceCount
        trialCount = boundedTrialCount(Neuro.Trials.NumTrials, cue, ...
            coherenceIndex, trialCapacity);
        if trialCount == 0
            continue
        end
        block = reshape(double(Neuro.All(cue, coherenceIndex, ...
            1:trialCount, channel)), [], 1);
        values = [values; block(isfinite(block))]; %#ok<AGROW>
    end
end
end


function [AI, meanTuning, semTuning, countTuning] = ...
    calculateAIFromTrials(trials, trialCounts, coherence)
trials = double(trials);
if ndims(trials) == 4
    trials = trials(:, :, :, 1);
end
cueCount = min(4, size(trials, 1));
coherenceCount = size(trials, 2);
trialCapacity = size(trials, 3);
if numel(coherence) ~= coherenceCount
    error('FiveChannelMeta:CoherenceSizeMismatch', ...
        'Coherence axis and trial array have different lengths.');
end
meanTuning = nan(4, coherenceCount);
semTuning = nan(4, coherenceCount);
countTuning = zeros(4, coherenceCount);
for cue = 1:cueCount
    for coherenceIndex = 1:coherenceCount
        trialCount = boundedTrialCount(trialCounts, cue, ...
            coherenceIndex, trialCapacity);
        values = reshape(trials(cue, coherenceIndex, 1:trialCount), [], 1);
        values = values(isfinite(values));
        countTuning(cue, coherenceIndex) = numel(values);
        if isempty(values)
            continue
        end
        meanTuning(cue, coherenceIndex) = mean(values);
        sampleSD = std(values, 0);
        semTuning(cue, coherenceIndex) = sampleSD ./ sqrt(numel(values));
    end
end

[positiveColumns, negativeColumns] = matchedCoherenceColumns(coherence);
AI = nan(4, 1);
for cue = 1:4
    towardMean = meanTuning(cue, positiveColumns);
    awayMean = meanTuning(cue, negativeColumns);
    towardSD = semTuning(cue, positiveColumns) .* ...
        sqrt(countTuning(cue, positiveColumns));
    awaySD = semTuning(cue, negativeColumns) .* ...
        sqrt(countTuning(cue, negativeColumns));
    numerator = towardMean - awayMean;
    denominator = abs(numerator) + (towardSD + awaySD) ./ 2;
    valid = isfinite(numerator) & isfinite(denominator) & denominator > 0;
    if any(valid)
        AI(cue) = mean(numerator(valid) ./ denominator(valid));
    end
end
end


function pValue = directionTuningPValue( ...
    trials, trialCounts, cue, coherence)
pValue = NaN;
if cue > size(trials, 1)
    return
end
trialCapacity = size(trials, 3);
firingRate = zeros(0, 1);
signedCoherence = zeros(0, 1);
tolerance = max(1e-12, 32 * eps(max(1, max(abs(coherence)))));
for coherenceIndex = find(abs(coherence) > tolerance)
    trialCount = boundedTrialCount( ...
        trialCounts, cue, coherenceIndex, trialCapacity);
    if trialCount == 0
        continue
    end
    values = reshape(double(trials(cue, coherenceIndex, ...
        1:trialCount)), [], 1);
    values = values(isfinite(values));
    firingRate = [firingRate; values]; %#ok<AGROW>
    signedCoherence = [signedCoherence; repmat( ...
        coherence(coherenceIndex), numel(values), 1)]; %#ok<AGROW>
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


function [positiveColumns, negativeColumns] = ...
    matchedCoherenceColumns(coherence)
coherence = double(coherence(:)');
tolerance = max(1e-12, 32 * eps(max(1, max(abs(coherence)))));
positiveColumns = find(coherence > tolerance);
availableNegative = find(coherence < -tolerance);
[magnitudes, order] = sort(coherence(positiveColumns));
positiveColumns = positiveColumns(order);
negativeColumns = nan(size(positiveColumns));
keep = false(size(positiveColumns));
for index = 1:numel(magnitudes)
    match = availableNegative(abs(abs(coherence(availableNegative)) - ...
        magnitudes(index)) <= tolerance);
    if isscalar(match)
        negativeColumns(index) = match;
        keep(index) = true;
    end
end
positiveColumns = positiveColumns(keep);
negativeColumns = negativeColumns(keep);
if isempty(positiveColumns)
    error('FiveChannelMeta:NoMatchedCoherencePairs', ...
        'No matched positive/negative nonzero coherence pairs were found.');
end
% The original CurrentSpread code keeps columns [1:4, end-3:end]. On a
% six-pair Quick grid this is exactly the four largest magnitudes; on the
% older four-pair grid it retains all available pairs.
if numel(positiveColumns) > 4
    retain = numel(positiveColumns)-3:numel(positiveColumns);
    positiveColumns = positiveColumns(retain);
    negativeColumns = negativeColumns(retain);
end
end


function count = boundedTrialCount(trialCounts, cue, coherenceIndex, capacity)
if cue > size(trialCounts, 1) || coherenceIndex > size(trialCounts, 2)
    count = 0;
    return
end
count = double(trialCounts(cue, coherenceIndex));
if ~isscalar(count) || ~isfinite(count) || count <= 0
    count = 0;
else
    count = min(capacity, floor(count));
end
end


function coherence = getNeuroCoherence(Neuro)
if isfield(Neuro, 'CoherenceArray') && ...
        numel(Neuro.CoherenceArray) == size(Neuro.All, 2)
    coherence = double(Neuro.CoherenceArray(:)');
    return
end
switch size(Neuro.All, 2)
    case 8
        numerator = [-22 -14 -10 -8 8 10 14 22];
    case 12
        numerator = [-22 -14 -10 -8 -4 -2 2 4 8 10 14 22];
    case 13
        numerator = [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22];
    otherwise
        error('FiveChannelMeta:UnknownCoherenceGrid', ...
            'Expected 8, 12, or 13 Quick coherence values; found %d.', ...
            size(Neuro.All, 2));
end
coherence = numerator ./ 22;
end


function validateNeuro(Neuro)
required = {'All', 'Trials'};
missing = required(~isfield(Neuro, required));
if ~isempty(missing) || ~isfield(Neuro.Trials, 'NumTrials') || ...
        ndims(Neuro.All) ~= 4 || size(Neuro.All, 1) < 4 || ...
        size(Neuro.Trials.NumTrials, 1) < 4
    error('FiveChannelMeta:InvalidNeuro', ...
        'Cached Neuro structure is incomplete.');
end
end


function channels = getDeadChannels(unitTable, row)
channels = [];
if ~ismember('DeadChannel', unitTable.Properties.VariableNames)
    return
end
value = getRowValue(unitTable.DeadChannel, row);
while iscell(value) && isscalar(value)
    value = value{1};
end
if isempty(value)
    return
elseif isnumeric(value)
    channels = double(value(:)');
elseif isstring(value) || ischar(value) || iscategorical(value)
    tokens = regexp(char(string(value)), '\d+', 'match');
    channels = str2double(tokens);
elseif iscell(value)
    numericValues = value(cellfun(@isnumeric, value));
    if ~isempty(numericValues)
        channels = double(cell2mat(numericValues(:)'));
    end
end
channels = unique(channels(isfinite(channels) & channels >= 1));
end


function folder = selectCacheFolder(monkey, jimFolder, clayFolder)
if strcmpi(monkey, "Jim")
    folder = jimFolder;
elseif strcmpi(monkey, "Clay")
    folder = clayFolder;
else
    error('FiveChannelMeta:UnknownMonkey', 'Unknown monkey: %s', monkey);
end
end


function dates = normalizeDateColumn(values)
if isdatetime(values)
    dates = dateshift(values(:), 'start', 'day');
elseif isnumeric(values)
    if all(isnan(values) | values > 1e7)
        dates = datetime(string(values(:)), 'InputFormat', 'yyyyMMdd');
    else
        dates = datetime(values(:), 'ConvertFrom', 'datenum');
    end
else
    dates = dateshift(datetime(string(values(:))), 'start', 'day');
end
end


function requireVariables(tableData, required)
missing = setdiff(required, string(tableData.Properties.VariableNames));
if ~isempty(missing)
    error('FiveChannelMeta:MissingVariables', ...
        'Missing required variable(s): %s', join(missing, ', '));
end
end


function validateChannelIndex(value, name)
if ~isscalar(value) || ~isfinite(value) || value < 1 || value ~= fix(value)
    error('FiveChannelMeta:InvalidChannel', ...
        '%s must be a finite positive integer.', name);
end
end


function tableData = setNumericRowValue(tableData, variableName, row, value)
if ~ismember(variableName, tableData.Properties.VariableNames)
    error('FiveChannelMeta:MissingOutputVariable', ...
        'Required output variable %s is missing.', variableName);
end
column = tableData.(variableName);
if iscell(column)
    tableData.(variableName){row} = value;
else
    tableData.(variableName)(row) = value;
end
end


function value = numericArray(column, row)
value = getRowValue(column, row);
while iscell(value) && isscalar(value)
    value = value{1};
end
if ~isnumeric(value)
    error('FiveChannelMeta:ExpectedNumericValue', ...
        'Expected numeric data at row %d.', row);
end
value = double(value);
end


function value = numericScalar(column, row)
value = numericArray(column, row);
if ~isscalar(value)
    error('FiveChannelMeta:ExpectedNumericScalar', ...
        'Expected a numeric scalar at row %d.', row);
end
end


function value = getRowText(column, row)
value = getRowValue(column, row);
while iscell(value) && isscalar(value)
    value = value{1};
end
value = string(value);
if ~isscalar(value)
    value = join(value, ",");
end
end


function value = getRowValue(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
end

function cache = BuildInteractiveGaussianMetaPopulationCache(options)
%BUILDINTERACTIVEGAUSSIANMETAPOPULATIONCACHE Precompute population by sigma.
%
% This is the batch half of the interactive Gaussian-meta population
% explorer. It evaluates a dense, logarithmically spaced sigma grid without
% rerunning the legacy population script or rereading every Quick cache at
% every sigma. Each Quick session is loaded once. Trial-level channel means
% and covariance matrices are then used to reproduce the Gaussian-weighted
% meta AI, raw-FR OD, and raw-FR Z3D-Z2D classification for every sigma.
% OD can be defined either by the left/right maximum-response difference or
% by the difference between the two eye-to-Combined correlations.
%
% Population selection and plotting match the current pipeline:
%   * the requested MT/FST area and monkey selection;
%   * stored monocular p_AI(2) and p_AI(3) < 0.05;
%   * optional adjacent-channel continuity exclusions;
%   * AI from the z-scored Gaussian meta tuning;
%   * signed OD and 2D/3D class from the matching raw Gaussian meta tuning;
%   * dominant/non-dominant cue ordering reassigned separately at each sigma;
%   * OD-weighted population lines constrained through the origin.
%
% The default output is area-specific under:
%   C:\EM\CurrentSpread\02_gaussian\InteractiveGaussianMetaPopulation
%
% Example:
%   BuildInteractiveGaussianMetaPopulationCache;

arguments
    options.StateFile (1, 1) string = ...
        "C:\EM\PopulationAnalysis\unit_table_gof.mat"
    options.OutputFolder (1, 1) string = ""
    options.CacheFileName (1, 1) string = ...
        "GaussianMetaPopulationSigmaCache.mat"
    options.SigmaValues (1, :) double = logspace(-2, 2, 1000)
    options.Monkey (1, 1) string ...
        {mustBeMember(options.Monkey, ["Both", "Jim", "Clay"])} = "Both"
    options.Area (1, 1) string ...
        {mustBeMember(options.Area, ["MT", "FST"])} = "MT"
    options.ODDefinition (1, 1) string ...
        {mustBeMember(options.ODDefinition, ...
        ["Max", "RMSE", "Correlation", "PartialCorrelation"])} = "Max"
    options.TuningAlpha (1, 1) double ...
        {mustBeGreaterThan(options.TuningAlpha, 0), ...
        mustBeLessThan(options.TuningAlpha, 1)} = 0.05
    options.ExcludedRowsFile (1, 1) string = ""
    options.JimCacheFolder (1, 1) string = "C:\Jim\StimData"
    options.ClayCacheFolder (1, 1) string = "C:\Clay\StimData"
    options.ChannelMap (1, :) double ...
        {mustBeInteger, mustBePositive} = ...
        [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]
    options.ValidateAgainstBuilder (1, 1) logical = false
    options.ValidationSigma (1, 1) double ...
        {mustBePositive} = 5.01187233627272
end

sigmaValues = sort(unique(double(options.SigmaValues(:)')));
if isempty(sigmaValues) || any(~isfinite(sigmaValues)) || ...
        any(sigmaValues <= 0)
    error('GaussianMetaInteractive:InvalidSigmaGrid', ...
        'SigmaValues must contain finite positive values.');
end

scriptFolder = string(fileparts(mfilename('fullpath')));
currentSpreadRoot = string(fileparts(fileparts(fileparts(scriptFolder))));
projectFolder = string(fileparts(currentSpreadRoot));
populationFolder = fullfile(projectFolder, 'PopulationAnalysis');
requiredPopulationFunctions = [ ...
    "LoadLatestUnitTableGof.m", "CalculateSigmoidFitBiases.m"];
for index = 1:numel(requiredPopulationFunctions)
    if ~isfile(fullfile(populationFolder, requiredPopulationFunctions(index)))
        error('GaussianMetaInteractive:MissingPopulationFunction', ...
            'Required population function is missing: %s', ...
            fullfile(populationFolder, requiredPopulationFunctions(index)));
    end
end
addpath(currentSpreadRoot, scriptFolder, populationFolder);
if strlength(options.OutputFolder) == 0
    outputRoot = ...
        "C:\EM\CurrentSpread\02_gaussian\InteractiveGaussianMetaPopulation";
    if options.ODDefinition ~= "Max"
        outputRoot = fullfile(outputRoot, 'CorrelationOD');
        if options.ODDefinition == "RMSE"
            outputRoot = replace(outputRoot, 'CorrelationOD', 'RMSEOD');
        elseif options.ODDefinition == "PartialCorrelation"
            outputRoot = replace(outputRoot, 'CorrelationOD', ...
                'PartialCorrelationOD');
        end
    end
    options.OutputFolder = fullfile(outputRoot, options.Area);
end
assertOutputOutsideRepository(options.OutputFolder, currentSpreadRoot);
ensureFolder(options.OutputFolder);

[unitTable, resolvedStateFile, workbookAudit] = ...
    LoadLatestUnitTableGof(options.StateFile); %#ok<ASGLU>
requireVariables(unitTable, ["Date", "Monkey", "ROI", "StimElec", ...
    "NChannels", "AI", "p_AI"]);

excludedRows = loadExcludedRows(options.ExcludedRowsFile, height(unitTable));
candidateMask = populationCandidateMask( ...
    unitTable, options.Area, options.Monkey, options.TuningAlpha);
candidateMask(excludedRows) = false;
sourceRows = find(candidateMask);
if isempty(sourceRows)
    error('GaussianMetaInteractive:NoCandidates', ...
        'No %s population candidates remained after selection.', options.Area);
end

[deltaBias, ~, ~, validBiasFit] = ...
    CalculateSigmoidFitBiases(unitTable, 4);
recordingDates = normalizeDateColumn(unitTable.Date);

numSessions = numel(sourceRows);
numSigmas = numel(sigmaValues);
metaAI = nan(numSessions, 4, numSigmas, 'single');
metaOD = nan(numSessions, numSigmas, 'single');
metaZDifference = nan(numSessions, numSigmas, 'single');
effectiveChannels = nan(numSessions, numSigmas, 'single');
sessionStatus = repmat("Pending", numSessions, 1);
sessionMessage = strings(numSessions, 1);
sessionCacheFile = strings(numSessions, 1);
sessionChannelCount = zeros(numSessions, 1);
sessionRelativePositions = repmat({zeros(1, 0)}, numSessions, 1);
sessionMonkey = strings(numSessions, 1);
sessionDate = NaT(numSessions, 1);
sessionStimChannel = nan(numSessions, 1);

fprintf(['Building Gaussian-meta %s population cache: %d sessions x ' ...
    '%d sigma values.\n'], options.Area, numSessions, numSigmas);
batchStart = tic;
for sessionIndex = 1:numSessions
    sourceRow = sourceRows(sessionIndex);
    sessionMonkey(sessionIndex) = getRowText(unitTable.Monkey, sourceRow);
    sessionDate(sessionIndex) = recordingDates(sourceRow);
    try
        summary = preprocessQuickSession(unitTable, sourceRow, ...
            recordingDates(sourceRow), options);
        [thisAI, thisOD, thisZDifference, thisEffectiveChannels] = ...
            evaluateSessionAcrossSigma( ...
            summary, sigmaValues, options.ODDefinition);
        metaAI(sessionIndex, :, :) = reshape(single(thisAI), ...
            [1, 4, numSigmas]);
        metaOD(sessionIndex, :) = single(thisOD);
        metaZDifference(sessionIndex, :) = single(thisZDifference);
        effectiveChannels(sessionIndex, :) = ...
            single(thisEffectiveChannels);
        sessionStatus(sessionIndex) = "Success";
        sessionCacheFile(sessionIndex) = summary.CacheFile;
        sessionChannelCount(sessionIndex) = numel(summary.Channels);
        sessionRelativePositions{sessionIndex} = ...
            summary.RelativePositions;
        sessionStimChannel(sessionIndex) = summary.StimChannel;
    catch ME
        sessionStatus(sessionIndex) = "Error";
        sessionMessage(sessionIndex) = ...
            string(ME.identifier) + ": " + string(ME.message);
    end

    if mod(sessionIndex, 10) == 0 || sessionIndex == numSessions
        fprintf('  Processed %d/%d sessions (%.1f s).\n', ...
            sessionIndex, numSessions, toc(batchStart));
    end
end

successfulSession = sessionStatus == "Success";
eligible = successfulSession & isfinite(metaOD) & metaOD ~= 0 & ...
    isfinite(metaZDifference) & metaZDifference ~= 0 & ...
    squeeze(all(isfinite(metaAI), 2));
is2D = eligible & metaZDifference < 0;
is3D = eligible & metaZDifference > 0;

[pointAI, pointBias, pointOD, pointValid2D, pointValid3D, sourceCue] = ...
    buildPopulationPoints(metaAI, metaOD, is2D, is3D, sourceRows, ...
    deltaBias, validBiasFit);
statistics2D = calculatePopulationStatistics( ...
    pointAI, pointBias, pointOD, pointValid2D, sourceRows, is2D, is3D);
statistics3D = calculatePopulationStatistics( ...
    pointAI, pointBias, pointOD, pointValid3D, sourceRows, is2D, is3D);

sessionAudit = table(sourceRows, sessionMonkey, sessionDate, ...
    sessionStimChannel, sessionChannelCount, sessionRelativePositions, ...
    sessionCacheFile, successfulSession, sessionStatus, sessionMessage, ...
    'VariableNames', {'SourceTableRow', 'Monkey', 'Date', 'StimChannel', ...
    'LiveGaussianChannelCount', 'RelativeChannelPositions', 'CacheFile', ...
    'SuccessfullyPreprocessed', 'Status', 'Message'});
writetable(sessionAudit, fullfile(options.OutputFolder, ...
    'GaussianMetaPopulationSessionAudit.csv'));

summaryTable2D = buildSigmaSummaryTable( ...
    sigmaValues, effectiveChannels, statistics2D);
summaryTable3D = buildSigmaSummaryTable( ...
    sigmaValues, effectiveChannels, statistics3D);
writetable(summaryTable2D, fullfile(options.OutputFolder, ...
    'GaussianMetaPopulationSigmaSummary.csv'));
writetable(summaryTable2D, fullfile(options.OutputFolder, ...
    'GaussianMetaPopulationSigmaSummary_2D.csv'));
writetable(summaryTable3D, fullfile(options.OutputFolder, ...
    'GaussianMetaPopulationSigmaSummary_3D.csv'));

validation = struct();
if options.ValidateAgainstBuilder && options.ODDefinition == "Max"
    validation = validateAgainstExistingBuilder(unitTable, candidateMask, ...
        sourceRows, sigmaValues, metaAI, metaOD, metaZDifference, options);
elseif options.ValidateAgainstBuilder
    validation.Skipped = true;
    validation.Reason = ...
        "The established meta builder exposes maximum-response OD only; " + ...
        "correlation OD is verified independently by unit tests.";
end

cache = struct();
cache.SchemaVersion = 3;
cache.Created = datetime('now', 'TimeZone', 'local');
odDescription = odDefinitionDescription(options.ODDefinition);
cache.Description = [ ...
    "Interactive " + options.Area + " Gaussian-meta population cache"; ...
    "AI from channel-standardized Gaussian meta tuning"; ...
    "OD from matching raw-FR Gaussian meta tuning: " + odDescription; ...
    "Z3D-Z2D class from matching raw-FR Gaussian meta tuning"; ...
    "Dominant-eye cue ordering recomputed independently at every sigma"; ...
    "Population lines are OD-weighted least-squares slopes through zero"];
cache.StateFile = string(resolvedStateFile);
cache.OutputFolder = options.OutputFolder;
cache.MonkeySelection = options.Monkey;
cache.Area = options.Area;
cache.ODDefinition = options.ODDefinition;
cache.ODFormula = odDefinitionFormula(options.ODDefinition);
cache.TuningAlpha = options.TuningAlpha;
cache.ExcludedRowsFile = options.ExcludedRowsFile;
cache.ExcludedSourceRows = excludedRows;
cache.ChannelMap = options.ChannelMap;
cache.JimCacheFolder = options.JimCacheFolder;
cache.ClayCacheFolder = options.ClayCacheFolder;
cache.SigmaValues = sigmaValues;
cache.SourceRows = sourceRows;
cache.Monkey = sessionMonkey;
cache.Date = sessionDate;
cache.StimChannel = sessionStimChannel;
cache.SessionStatus = sessionStatus;
cache.MetaAI = metaAI;
cache.MetaOD = metaOD;
cache.MetaZ3DMinusZ2D = metaZDifference;
cache.EffectiveChannels = effectiveChannels;
cache.Eligible = eligible;
cache.Is2D = is2D;
cache.Is3D = is3D;
cache.PointAI = pointAI;
cache.PointBias = pointBias;
cache.PointOD = pointOD;
cache.PointValid = pointValid2D;
cache.PointValid2D = pointValid2D;
cache.PointValid3D = pointValid3D;
cache.SourceCue = sourceCue;
cache.ConditionNames = ["Dominant", "Combined", "Stereo", "NonDominant"];
cache.ConditionColors = [254 191 15; 0 0 0; 234 0 233; 110 205 221] ./ 255;
cache.Statistics = statistics2D;
cache.Statistics2D = statistics2D;
cache.Statistics3D = statistics3D;
cache.SigmaSummary = summaryTable2D;
cache.SigmaSummary2D = summaryTable2D;
cache.SigmaSummary3D = summaryTable3D;
cache.SessionAudit = sessionAudit;
cache.Validation = validation;

cacheFile = fullfile(options.OutputFolder, options.CacheFileName);
save(cacheFile, 'cache', '-v7.3');

manifest = [ ...
    "Gaussian-meta interactive population cache"; ...
    "Created: " + string(cache.Created); ...
    "State file: " + string(resolvedStateFile); ...
    "Area: " + options.Area; ...
    "OD definition: " + options.ODDefinition; ...
    "OD formula: " + cache.ODFormula; ...
    "Monkey selection: " + options.Monkey; ...
    "Sigma count: " + numSigmas; ...
    "Sigma range: " + sigmaValues(1) + " to " + sigmaValues(end); ...
    "Candidate sessions: " + numSessions; ...
    "Successfully preprocessed: " + nnz(successfulSession); ...
    "Continuity exclusions: " + numel(excludedRows); ...
    "Excluded rows file: " + options.ExcludedRowsFile; ...
    "Cache file: " + cacheFile; ...
    "Viewer: ExploreInteractiveGaussianMetaPopulation.m"];
writelines(manifest, fullfile(options.OutputFolder, ...
    'GaussianMetaPopulationCacheManifest.txt'));

fprintf(['Saved %d-sigma Gaussian-meta population cache (%d/%d sessions ' ...
    'preprocessed) to:\n  %s\n'], numSigmas, nnz(successfulSession), ...
    numSessions, cacheFile);
end


function summary = preprocessQuickSession( ...
    unitTable, row, recordingDate, options)
stimChannel = numericScalar(unitTable.StimElec, row);
declaredChannelCount = numericScalar(unitTable.NChannels, row);
aiValues = numericArray(unitTable.AI, row);
if ~isscalar(stimChannel) || ~isfinite(stimChannel) || ...
        stimChannel < 1 || stimChannel ~= fix(stimChannel)
    error('GaussianMetaInteractive:InvalidStimChannel', ...
        'Invalid stimulation channel at source row %d.', row);
end
stimPosition = find(options.ChannelMap == stimChannel, 1);
if isempty(stimPosition)
    error('GaussianMetaInteractive:UnmappedStimChannel', ...
        'Stimulation channel %d is absent from ChannelMap.', stimChannel);
end

monkey = getRowText(unitTable.Monkey, row);
cacheFolder = selectCacheFolder( ...
    monkey, options.JimCacheFolder, options.ClayCacheFolder);
cacheFile = fullfile(cacheFolder, ...
    string(recordingDate, 'yyyyMMdd') + ".mat");
if ~isfile(cacheFile)
    error('GaussianMetaInteractive:MissingCache', ...
        'Quick cache does not exist: %s', cacheFile);
end
loaded = load(cacheFile, 'Neuro');
if ~isfield(loaded, 'Neuro')
    error('GaussianMetaInteractive:MissingNeuro', ...
        'Quick cache does not contain Neuro: %s', cacheFile);
end
Neuro = loaded.Neuro;
validateNeuro(Neuro);

availableChannelCount = min([declaredChannelCount, ...
    size(aiValues, 2), size(Neuro.All, 4)]);
probePositions = 1:numel(options.ChannelMap);
channels = options.ChannelMap;
deadChannels = getDeadChannels(unitTable, row);
keep = channels <= availableChannelCount & ...
    ~ismember(channels, deadChannels);
channels = channels(keep);
probePositions = probePositions(keep);
if isempty(channels) || ~ismember(stimChannel, channels)
    error('GaussianMetaInteractive:NoLiveChannels', ...
        'No valid all-channel set containing stimulation channel %d.', ...
        stimChannel);
end
relativePositions = probePositions - stimPosition;

cueCount = min(4, size(Neuro.All, 1));
coherenceCount = size(Neuro.All, 2);
trialCapacity = size(Neuro.All, 3);
channelCount = numel(channels);
centers = nan(1, channelCount);
scales = nan(1, channelCount);
for channelIndex = 1:channelCount
    values = validChannelObservations(Neuro, channels(channelIndex), ...
        cueCount, coherenceCount, trialCapacity);
    centers(channelIndex) = mean(values, 'omitnan');
    scales(channelIndex) = std(values, 0, 'omitnan');
    if nnz(isfinite(values)) < 2 || ~isfinite(scales(channelIndex)) || ...
            scales(channelIndex) <= ...
            eps(max(1, abs(centers(channelIndex))))
        error('GaussianMetaInteractive:ZeroVariance', ...
            'Channel %d has insufficient observations or zero variance.', ...
            channels(channelIndex));
    end
end

rawChannelMean = nan(4, coherenceCount, channelCount);
standardizedMean = nan(4, coherenceCount, channelCount);
standardizedCovariance = cell(4, coherenceCount);
observationCount = zeros(4, coherenceCount);
for cue = 1:cueCount
    for coherenceIndex = 1:coherenceCount
        trialCount = boundedTrialCount(Neuro.Trials.NumTrials, cue, ...
            coherenceIndex, trialCapacity);
        if trialCount == 0
            continue
        end
        raw = reshape(double(Neuro.All(cue, coherenceIndex, ...
            1:trialCount, channels)), trialCount, channelCount);
        complete = all(isfinite(raw), 2);
        raw = raw(complete, :);
        observationCount(cue, coherenceIndex) = size(raw, 1);
        if isempty(raw)
            continue
        end
        standardized = (raw - centers) ./ scales;
        rawChannelMean(cue, coherenceIndex, :) = mean(raw, 1);
        standardizedMean(cue, coherenceIndex, :) = ...
            mean(standardized, 1);
        if size(standardized, 1) > 1
            standardizedCovariance{cue, coherenceIndex} = ...
                cov(standardized, 0);
        else
            standardizedCovariance{cue, coherenceIndex} = ...
                zeros(channelCount);
        end
    end
end

summary = struct();
summary.CacheFile = cacheFile;
summary.StimChannel = stimChannel;
summary.Channels = channels;
summary.RelativePositions = relativePositions;
summary.Coherence = getNeuroCoherence(Neuro);
summary.RawChannelMean = rawChannelMean;
summary.StandardizedMean = standardizedMean;
summary.StandardizedCovariance = standardizedCovariance;
summary.ObservationCount = observationCount;
end


function [metaAI, metaOD, metaZDifference, effectiveChannels] = ...
    evaluateSessionAcrossSigma(summary, sigmaValues, odDefinition)
relativePositions = double(summary.RelativePositions(:));
weights = exp(-(relativePositions .^ 2) ./ ...
    (2 .* double(sigmaValues(:)').^2));
weights = weights ./ sum(weights, 1);
effectiveChannels = 1 ./ sum(weights .^ 2, 1);

coherenceCount = numel(summary.Coherence);
numSigmas = numel(sigmaValues);
standardizedMetaMean = nan(4, coherenceCount, numSigmas);
standardizedMetaSD = nan(4, coherenceCount, numSigmas);
rawMetaMean = nan(4, coherenceCount, numSigmas);
for cue = 1:4
    for coherenceIndex = 1:coherenceCount
        count = summary.ObservationCount(cue, coherenceIndex);
        if count == 0
            continue
        end
        rawMean = reshape(summary.RawChannelMean( ...
            cue, coherenceIndex, :), 1, []);
        zMean = reshape(summary.StandardizedMean( ...
            cue, coherenceIndex, :), 1, []);
        covariance = summary.StandardizedCovariance{cue, coherenceIndex};
        rawMetaMean(cue, coherenceIndex, :) = ...
            reshape(rawMean * weights, 1, 1, []);
        standardizedMetaMean(cue, coherenceIndex, :) = ...
            reshape(zMean * weights, 1, 1, []);
        variance = sum(weights .* (covariance * weights), 1);
        variance(variance < 0 & variance > -1e-12) = 0;
        standardizedMetaSD(cue, coherenceIndex, :) = ...
            reshape(sqrt(max(variance, 0)), 1, 1, []);
    end
end

[positiveColumns, negativeColumns] = ...
    matchedCoherenceColumns(summary.Coherence);
metaAI = nan(4, numSigmas);
for cue = 1:4
    towardMean = reshape(standardizedMetaMean( ...
        cue, positiveColumns, :), numel(positiveColumns), numSigmas);
    awayMean = reshape(standardizedMetaMean( ...
        cue, negativeColumns, :), numel(negativeColumns), numSigmas);
    towardSD = reshape(standardizedMetaSD( ...
        cue, positiveColumns, :), numel(positiveColumns), numSigmas);
    awaySD = reshape(standardizedMetaSD( ...
        cue, negativeColumns, :), numel(negativeColumns), numSigmas);
    numerator = towardMean - awayMean;
    denominator = abs(numerator) + (towardSD + awaySD) ./ 2;
    ratio = numerator ./ denominator;
    ratio(~isfinite(ratio) | denominator <= 0) = NaN;
    metaAI(cue, :) = mean(ratio, 1, 'omitnan');
    metaAI(cue, all(~isfinite(ratio), 1)) = NaN;
end

metaOD = calculateGaussianMetaOD( ...
    rawMetaMean, summary.ObservationCount, odDefinition);

metaZDifference = nan(1, numSigmas);
for sigmaIndex = 1:numSigmas
    rawMean = rawMetaMean(:, :, sigmaIndex);
    [~, ~, metaZDifference(sigmaIndex)] = ...
        calculateMeta2DStatistics(rawMean, summary.ObservationCount, ...
        summary.Coherence, metaOD(sigmaIndex));
end
end


function description = odDefinitionDescription(definition)
switch definition
    case "Max"
        description = "normalized MonoL/MonoR maximum-response difference";
    case "RMSE"
        description = "normalized Combined-to-MonoL/MonoR RMSE difference";
    case "Correlation"
        description = "Combined-to-MonoL r minus Combined-to-MonoR r";
    case "PartialCorrelation"
        description = "Fisher-z partial-correlation left-minus-right difference";
end
end


function formula = odDefinitionFormula(definition)
switch definition
    case "Max"
        formula = "(max(MonoL)-max(MonoR))/(max(MonoL)+max(MonoR))";
    case "RMSE"
        formula = "(RMSE(Combined,MonoR)-RMSE(Combined,MonoL))/(RMSE(Combined,MonoR)+RMSE(Combined,MonoL))";
    case "Correlation"
        formula = "PearsonR(Combined,MonoL)-PearsonR(Combined,MonoR)";
    case "PartialCorrelation"
        formula = "FisherZ(partialR(Combined,MonoL|MonoR))-FisherZ(partialR(Combined,MonoR|MonoL))";
end
end


function [pointAI, pointBias, pointOD, pointValid2D, pointValid3D, ...
    sourceCue] = buildPopulationPoints(metaAI, metaOD, is2D, is3D, ...
    sourceRows, ...
    deltaBias, validBiasFit)
[numSessions, ~, numSigmas] = size(metaAI);
pointAI = nan(numSessions, 4, numSigmas, 'single');
pointBias = nan(numSessions, 4, numSigmas, 'single');
pointOD = abs(metaOD);
pointValid2D = false(numSessions, 4, numSigmas);
pointValid3D = false(numSessions, 4, numSigmas);
sourceCue = zeros(numSessions, 4, numSigmas, 'uint8');
leftOrder = [2 1 4 3];
rightOrder = [3 1 4 2];
for sessionIndex = 1:numSessions
    sourceRow = sourceRows(sessionIndex);
    for sigmaIndex = 1:numSigmas
        if metaOD(sessionIndex, sigmaIndex) > 0
            order = leftOrder;
        elseif metaOD(sessionIndex, sigmaIndex) < 0
            order = rightOrder;
        else
            continue
        end
        for condition = 1:4
            cue = order(condition);
            ai = metaAI(sessionIndex, cue, sigmaIndex);
            bias = deltaBias(sourceRow, cue);
            pointAI(sessionIndex, condition, sigmaIndex) = ai;
            pointBias(sessionIndex, condition, sigmaIndex) = ...
                single(bias);
            sourceCue(sessionIndex, condition, sigmaIndex) = uint8(cue);
            validPoint = validBiasFit(sourceRow, cue) && isfinite(ai) && ...
                isfinite(bias) && isfinite(metaOD(sessionIndex, sigmaIndex));
            pointValid2D(sessionIndex, condition, sigmaIndex) = ...
                is2D(sessionIndex, sigmaIndex) && validPoint;
            pointValid3D(sessionIndex, condition, sigmaIndex) = ...
                is3D(sessionIndex, sigmaIndex) && validPoint;
        end
    end
end
end


function statistics = calculatePopulationStatistics( ...
    pointAI, pointBias, pointOD, pointValid, sourceRows, is2D, is3D)
numSigmas = size(pointAI, 3);
statistics = struct();
statistics.N2DSessions = sum(is2D, 1)';
statistics.N3DSessions = sum(is3D, 1)';
statistics.NPoints = zeros(4, numSigmas);
statistics.NUnits = zeros(4, numSigmas);
statistics.WeightedSlope = nan(4, numSigmas);
statistics.WeightedIntercept = zeros(4, numSigmas);
statistics.OrdinarySlope = nan(4, numSigmas);
statistics.OrdinaryIntercept = nan(4, numSigmas);
statistics.P_AI = nan(4, numSigmas);
statistics.R2_AI = nan(4, numSigmas);
statistics.P_AIxODWithinCondition = nan(4, numSigmas);
statistics.R2_AIxODWithinCondition = nan(4, numSigmas);
statistics.MergedNPoints = zeros(1, numSigmas);
statistics.MergedNUnits = zeros(1, numSigmas);
statistics.MergedWeightedSlope = nan(1, numSigmas);
statistics.MergedP_AI = nan(1, numSigmas);
statistics.MergedP_AIxOD = nan(1, numSigmas);
statistics.MergedR2 = nan(1, numSigmas);

for sigmaIndex = 1:numSigmas
    for condition = 1:4
        valid = pointValid(:, condition, sigmaIndex);
        x = double(pointAI(valid, condition, sigmaIndex));
        y = double(pointBias(valid, condition, sigmaIndex));
        w = double(pointOD(valid, sigmaIndex));
        statistics.NPoints(condition, sigmaIndex) = numel(x);
        statistics.NUnits(condition, sigmaIndex) = ...
            numel(unique(sourceRows(valid)));
        [statistics.WeightedSlope(condition, sigmaIndex), ...
            statistics.WeightedIntercept(condition, sigmaIndex)] = ...
            weightedOriginFit(x, y, w);
        simple = linearModelStatistics(x, y, zeros(size(x)), false);
        statistics.OrdinarySlope(condition, sigmaIndex) = simple.Beta(2);
        statistics.OrdinaryIntercept(condition, sigmaIndex) = simple.Beta(1);
        statistics.P_AI(condition, sigmaIndex) = simple.PValue(2);
        statistics.R2_AI(condition, sigmaIndex) = simple.R2;
        interaction = linearModelStatistics(x, y, w, true);
        statistics.P_AIxODWithinCondition(condition, sigmaIndex) = ...
            interaction.PValue(3);
        statistics.R2_AIxODWithinCondition(condition, sigmaIndex) = ...
            interaction.R2;
    end

    dominantValid = pointValid(:, 1, sigmaIndex);
    nonDominantValid = pointValid(:, 4, sigmaIndex);
    x = [double(pointAI(dominantValid, 1, sigmaIndex)); ...
        double(pointAI(nonDominantValid, 4, sigmaIndex))];
    y = [double(pointBias(dominantValid, 1, sigmaIndex)); ...
        -double(pointBias(nonDominantValid, 4, sigmaIndex))];
    w = [double(pointOD(dominantValid, sigmaIndex)); ...
        double(pointOD(nonDominantValid, sigmaIndex))];
    mergedRows = [sourceRows(dominantValid); sourceRows(nonDominantValid)];
    statistics.MergedNPoints(sigmaIndex) = numel(x);
    statistics.MergedNUnits(sigmaIndex) = numel(unique(mergedRows));
    statistics.MergedWeightedSlope(sigmaIndex) = ...
        weightedOriginFit(x, y, w);
    merged = linearModelStatistics(x, y, w, true);
    statistics.MergedP_AI(sigmaIndex) = merged.PValue(2);
    statistics.MergedP_AIxOD(sigmaIndex) = merged.PValue(3);
    statistics.MergedR2(sigmaIndex) = merged.R2;
end
end


function tableData = buildSigmaSummaryTable( ...
    sigmaValues, effectiveChannels, statistics)
tableData = table(sigmaValues(:), ...
    mean(double(effectiveChannels), 1, 'omitnan')', ...
    median(double(effectiveChannels), 1, 'omitnan')', ...
    statistics.N2DSessions, statistics.N3DSessions, ...
    statistics.MergedNPoints', statistics.MergedNUnits', ...
    statistics.MergedWeightedSlope', statistics.MergedP_AI', ...
    statistics.MergedP_AIxOD', statistics.MergedR2', ...
    'VariableNames', {'Sigma', 'MeanEffectiveChannels', ...
    'MedianEffectiveChannels', 'N2DSessions', 'N3DSessions', ...
    'MergedNPoints', 'MergedNUnits', 'MergedWeightedSlope', ...
    'MergedP_AI', 'MergedP_AIxOD', 'MergedR2'});
conditionTokens = ["Dominant", "Combined", "Stereo", "NonDominant"];
for condition = 1:4
    token = conditionTokens(condition);
    tableData.("N_" + token) = ...
        statistics.NPoints(condition, :)';
    tableData.("WeightedSlope_" + token) = ...
        statistics.WeightedSlope(condition, :)';
    tableData.("P_AI_" + token) = ...
        statistics.P_AI(condition, :)';
    tableData.("R2_AI_" + token) = ...
        statistics.R2_AI(condition, :)';
    tableData.("P_AIxOD_" + token) = ...
        statistics.P_AIxODWithinCondition(condition, :)';
end
end


function validation = validateAgainstExistingBuilder( ...
    unitTable, candidateMask, sourceRows, sigmaValues, metaAI, metaOD, ...
    metaZDifference, options)
[~, sigmaIndex] = min(abs(sigmaValues - options.ValidationSigma));
sigma = sigmaValues(sigmaIndex);
fprintf('Validating batch calculations against builder at sigma %.12g...\n', ...
    sigma);
[~, eligibleMask, audit] = BuildEqualFiveChannelMetaQuickAI(unitTable, ...
    JimCacheFolder=options.JimCacheFolder, ...
    ClayCacheFolder=options.ClayCacheFolder, ...
    CandidateMask=candidateMask, WeightingMode="GaussianAll", ...
    GaussianSigma=sigma);
builderAI = nan(numel(sourceRows), 4);
for index = 1:numel(sourceRows)
    value = audit.MetaAI{sourceRows(index)};
    if isnumeric(value) && numel(value) >= 4
        builderAI(index, :) = double(value(1:4));
    end
end
builderOD = audit.MetaODMax(sourceRows);
builderZ = audit.MetaZ3DMinusZ2D(sourceRows);
batchAI = double(metaAI(:, :, sigmaIndex));
batchOD = double(metaOD(:, sigmaIndex));
batchZ = double(metaZDifference(:, sigmaIndex));
validation = struct();
validation.Sigma = sigma;
validation.EligibleAgreement = isequal( ...
    eligibleMask(sourceRows), all(isfinite(batchAI), 2) & ...
    isfinite(batchOD) & batchOD ~= 0 & isfinite(batchZ) & batchZ ~= 0);
validation.MaxAbsAIDifference = max(abs(builderAI - batchAI), [], ...
    'all', 'omitnan');
validation.MaxAbsODDifference = max(abs(builderOD - batchOD), [], ...
    'all', 'omitnan');
validation.MaxAbsZDifference = max(abs(builderZ - batchZ), [], ...
    'all', 'omitnan');
fprintf(['Validation: eligible agreement %d; max |AI difference| %.3g; ' ...
    'max |OD difference| %.3g; max |Z difference| %.3g.\n'], ...
    validation.EligibleAgreement, validation.MaxAbsAIDifference, ...
    validation.MaxAbsODDifference, validation.MaxAbsZDifference);
end


function model = linearModelStatistics(x, y, od, includeInteraction)
x = double(x(:));
y = double(y(:));
od = double(od(:));
if includeInteraction
    valid = isfinite(x) & isfinite(y) & isfinite(od);
    design = [ones(nnz(valid), 1), x(valid), x(valid) .* od(valid)];
else
    valid = isfinite(x) & isfinite(y);
    design = [ones(nnz(valid), 1), x(valid)];
end
response = y(valid);
parameterCount = size(design, 2);
model = struct('Beta', nan(parameterCount, 1), ...
    'PValue', nan(parameterCount, 1), 'R2', NaN);
if numel(response) <= parameterCount || rank(design) < parameterCount
    return
end
beta = design \ response;
residual = response - design * beta;
sse = sum(residual .^ 2);
sst = sum((response - mean(response)) .^ 2);
degreesFreedom = numel(response) - parameterCount;
covariance = (sse ./ degreesFreedom) .* pinv(design' * design);
standardError = sqrt(max(diag(covariance), 0));
tStatistic = beta ./ standardError;
pValue = 2 .* tcdf(-abs(tStatistic), degreesFreedom);
model.Beta = beta;
model.PValue = pValue;
if sst > eps
    model.R2 = 1 - sse ./ sst;
end
end


function [slope, intercept] = weightedOriginFit(x, y, weights)
valid = isfinite(x) & isfinite(y) & isfinite(weights) & weights > 0;
x = x(valid);
y = y(valid);
weights = weights(valid);
slope = NaN;
intercept = 0;
weightedXX = sum(weights .* x .^ 2);
if numel(x) >= 2 && isfinite(weightedXX) && weightedXX > eps
    slope = sum(weights .* x .* y) ./ weightedXX;
end
end


function [z2D, z3D, difference] = calculateMeta2DStatistics( ...
    rawMean, rawCount, coherence, signedOD)
z2D = NaN;
z3D = NaN;
difference = NaN;
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
denominator2D = sqrt((1 - r3D ^ 2) * (1 - rPrediction ^ 2));
denominator3D = sqrt((1 - r2D ^ 2) * (1 - rPrediction ^ 2));
if ~all(isfinite([denominator2D, denominator3D])) || ...
        denominator2D <= 1e-10 || denominator3D <= 1e-10
    return
end
partial2D = (r2D - r3D * rPrediction) / denominator2D;
partial3D = (r3D - r2D * rPrediction) / denominator3D;
if ~all(isfinite([partial2D, partial3D])) || ...
        abs(partial2D) >= 1 || abs(partial3D) >= 1
    return
end
z2D = atanh(partial2D) * sqrt(pairedCount - 3);
z3D = atanh(partial3D) * sqrt(pairedCount - 3);
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
    error('GaussianMetaInteractive:NoMatchedCoherencePairs', ...
        'No matched positive/negative coherence pairs were found.');
end
if numel(positiveColumns) > 4
    retain = numel(positiveColumns)-3:numel(positiveColumns);
    positiveColumns = positiveColumns(retain);
    negativeColumns = negativeColumns(retain);
end
end


function values = validChannelObservations( ...
    Neuro, channel, cueCount, coherenceCount, trialCapacity)
values = zeros(0, 1);
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
        error('GaussianMetaInteractive:UnknownCoherenceGrid', ...
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
    error('GaussianMetaInteractive:InvalidNeuro', ...
        'Cached Neuro structure is incomplete.');
end
end


function mask = populationCandidateMask(unitTable, area, monkey, alpha)
rowCount = height(unitTable);
mask = false(rowCount, 1);
for row = 1:rowCount
    if ~strcmpi(getRowText(unitTable.ROI, row), area)
        continue
    end
    monkeyName = getRowText(unitTable.Monkey, row);
    if monkey ~= "Both" && ~strcmpi(monkeyName, monkey)
        continue
    end
    pValues = numericArray(unitTable.p_AI, row);
    mask(row) = numel(pValues) >= 3 && isfinite(pValues(2)) && ...
        isfinite(pValues(3)) && pValues(2) < alpha && pValues(3) < alpha;
end
end


function assertOutputOutsideRepository(outputFolder, repositoryRoot)
resolvedOutput = string(char(java.io.File(char(outputFolder)).getCanonicalPath()));
resolvedRepository = string(char(java.io.File(char(repositoryRoot)).getCanonicalPath()));
if startsWith(lower(resolvedOutput), lower(resolvedRepository + filesep)) || ...
        strcmpi(resolvedOutput, resolvedRepository)
    error('GaussianMetaInteractive:RepositoryLocalOutput', ...
        'OutputFolder must be outside the repository: %s', resolvedOutput);
end
end


function rows = loadExcludedRows(fileName, rowCount)
rows = zeros(0, 1);
if strlength(fileName) == 0
    return
end
if ~isfile(fileName)
    warning('GaussianMetaInteractive:MissingExclusionFile', ...
        'Exclusion file was not found; no continuity exclusions applied: %s', ...
        fileName);
    return
end
data = readtable(fileName);
if ~ismember('TableRow', data.Properties.VariableNames)
    error('GaussianMetaInteractive:InvalidExclusionFile', ...
        'ExcludedRowsFile must contain a TableRow variable.');
end
rows = unique(double(data.TableRow(:)));
rows = rows(isfinite(rows) & rows >= 1 & rows <= rowCount & ...
    rows == fix(rows));
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
    error('GaussianMetaInteractive:UnknownMonkey', ...
        'Unknown monkey: %s', monkey);
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
    error('GaussianMetaInteractive:MissingVariables', ...
        'Missing required variable(s): %s', join(missing, ', '));
end
end


function value = numericArray(column, row)
value = getRowValue(column, row);
while iscell(value) && isscalar(value)
    value = value{1};
end
if ~isnumeric(value)
    error('GaussianMetaInteractive:ExpectedNumericValue', ...
        'Expected numeric data at row %d.', row);
end
value = double(value);
end


function value = numericScalar(column, row)
value = numericArray(column, row);
if ~isscalar(value)
    error('GaussianMetaInteractive:ExpectedNumericScalar', ...
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


function ensureFolder(folder)
if ~isfolder(folder)
    mkdir(folder);
end
end

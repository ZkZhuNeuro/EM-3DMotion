function [Neuro, TrialSummary, ExtractionSummary, tuningFigure] = ...
    Extract3DMotionStimTuning(pathName, fileNames, options)
%EXTRACT3DMOTIONSTIMTUNING Extract multichannel 3-D tuning from a Stim TInfo pair.
%
% [Neuro, TrialSummary, ExtractionSummary] = Extract3DMotionStimTuning(...)
% uses the same motion-on (EID 118) through motion-off (EID 130) firing-rate
% window and event decoding as Offline_3DMotion_NoSaccade_v1_081421. In a
% 3DMotionStim file, EID 222 identifies electrical-stimulation trials.
%
% The top-level Neuro.Means, Neuro.SEM, Neuro.All, and Neuro.Trials fields
% contain only non-electrical-stimulation trials. This preserves the legacy
% Quick-file Neuro contract while avoiding stimulation artifacts. Identical
% structures for electrical-stimulation and pooled trials are available as
% Neuro.Stim and Neuro.Pooled. Neuro.NoStim is an explicit copy of the
% top-level result. The top-level fields keep the Quick extractor's 12
% nonzero coherence columns; Neuro.WithZero retains zero-inclusive versions.
%
% Inputs follow the existing offline-analysis convention:
%   pathName - folder containing the MAT files
%   fileNames - TInfo/SelIndex names in either order (cell or string array)
%
% Name-value options:
%   ApplyEyeCheck      - run the Quick pipeline's version/vergence check
%                        when its helper is available (default true)
%   MakePlot           - make a 16-channel NoStim tuning figure (false)
%   FigureVisible      - show that figure on screen (true)
%   StimulationCode    - electrical-stimulation event code (222)
%   CoherenceValues    - Quick-compatible signed bins (12 nonzero defaults)
%   PreserveZeroCoherence - retain zero in Neuro.WithZero (true)
%   EyeCheckChunkSize  - trials per version/vergence helper call (128)
%   SkipEyeCheckDates  - dates intentionally excluded by the legacy Quick
%                        pipeline (default 20-May-2022)
%   ProgressInterval   - print progress every N trials; 0 disables (100)

% The response arrays retain acquisition-channel order. Neuro.ChannelMap is
% provided only for physical probe ordering; it is not applied to the data.

% See also Offline_3DMotion_NoSaccade_v1_081421, plot3DMotionTuning_Stim.

arguments
    pathName
    fileNames
    options.ApplyEyeCheck (1, 1) logical = true
    options.MakePlot (1, 1) logical = false
    options.FigureVisible (1, 1) logical = true
    options.StimulationCode (1, 1) double {mustBeInteger} = 222
    options.CoherenceValues (1, :) double = ...
        [-22 -14 -10 -8 -4 -2 2 4 8 10 14 22] ./ 22
    options.PreserveZeroCoherence (1, 1) logical = true
    options.EyeCheckChunkSize (1, 1) double ...
        {mustBeInteger, mustBePositive} = 128
    options.SkipEyeCheckDates (1, :) datetime = datetime(2022, 5, 20)
    options.ProgressInterval (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 100
end

conditionNames = ["Combined", "MonoL", "MonoR", "Binocular"];
channelMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10];
% The task writes integer event codes whose nominal fractions are rounded by
% the legacy Quick extractor to two decimals (for example, 14/22 -> 0.64).
coherenceValues = round(options.CoherenceValues, 2);
if isempty(coherenceValues) || any(~isfinite(coherenceValues)) || ...
        numel(unique(coherenceValues)) ~= numel(coherenceValues)
    error('StimTuning:InvalidCoherenceValues', ...
        'CoherenceValues must contain unique, finite values.');
end
if any(coherenceValues == 0)
    error('StimTuning:ZeroInQuickCoherenceValues', ...
        ['CoherenceValues defines the Quick-compatible top-level output ' ...
        'and must omit zero. Use PreserveZeroCoherence=true to retain ' ...
        'zero in Neuro.WithZero.']);
end
if any(diff(coherenceValues) <= 0)
    error('StimTuning:UnsortedCoherenceValues', ...
        'CoherenceValues must be strictly increasing.');
end
analysisCoherenceValues = coherenceValues;
if options.PreserveZeroCoherence
    analysisCoherenceValues = sort([analysisCoherenceValues 0]);
end

[tInfoPath, selIndexPath] = resolveInputFiles(pathName, fileNames);
if ~contains(lower(string(tInfoPath)), "3dmotionstim")
    error('StimTuning:ExpectedStimFile', ...
        ['The TInfo filename does not contain 3DMotionStim. EID %d is ' ...
        'safe to interpret as electrical stimulation only for a Stim task.'], ...
        options.StimulationCode);
end

fprintf('Loading stimulation TrialInfo: %s\n', tInfoPath);
tInfoData = load(tInfoPath, 'TrialInfo', 'Config');
if ~isfield(tInfoData, 'TrialInfo')
    error('StimTuning:MissingTrialInfo', ...
        'The TInfo file does not contain TrialInfo: %s', tInfoPath);
end

selectionData = load(selIndexPath);
[selectionMask, selectionVariable] = getSelectionMask(selectionData);
inputTrialCount = numel(tInfoData.TrialInfo);
if numel(selectionMask) ~= inputTrialCount
    error('StimTuning:SelectionLengthMismatch', ...
        '%s has %d entries, but TrialInfo contains %d trials.', ...
        selectionVariable, numel(selectionMask), inputTrialCount);
end

config = getConfig(tInfoData, selectionData);
allTrialInfo = tInfoData.TrialInfo;
clear tInfoData selectionData
selectedSourceIndex = find(selectionMask(:));
trialInfo = allTrialInfo(selectionMask(:));
clear allTrialInfo
selectedTrialCount = numel(trialInfo);
if selectedTrialCount == 0
    error('StimTuning:NoSelectedTrials', ...
        'The selection file retains no trials: %s', selIndexPath);
end

[trialInfo, selectedSourceIndex, eyeCheck] = applyEyeCheckIfRequested( ...
    trialInfo, selectedSourceIndex, config, tInfoPath, ...
    options.ApplyEyeCheck, options.EyeCheckChunkSize, ...
    options.SkipEyeCheckDates);

analyzedTrialCount = numel(trialInfo);
if analyzedTrialCount == 0
    error('StimTuning:NoTrialsAfterEyeCheck', ...
        'No selected trials remained after the version/vergence check.');
end

[numChannels, numUnits] = findResponseDimensions(trialInfo);
trialFR = nan(analyzedTrialCount, numChannels, numUnits);
included = false(analyzedTrialCount, 1);
isElectricalStim = false(analyzedTrialCount, 1);
condition = nan(analyzedTrialCount, 1);
coherence = nan(analyzedTrialCount, 1);
coherenceIndex = nan(analyzedTrialCount, 1);
direction = nan(analyzedTrialCount, 1);
response = nan(analyzedTrialCount, 1);
block = nan(analyzedTrialCount, 1);
trialStart = nan(analyzedTrialCount, 1);
trialEnd = nan(analyzedTrialCount, 1);
motionOn = nan(analyzedTrialCount, 1);
motionOff = nan(analyzedTrialCount, 1);
responseDuration = nan(analyzedTrialCount, 1);
exclusionReason = strings(analyzedTrialCount, 1);

fprintf('Extracting 3-D tuning from %d selected trials...\n', analyzedTrialCount);
for trialIndex = 1:analyzedTrialCount
    [metadata, reason] = decodeMotionTrial( ...
        trialInfo(trialIndex), analysisCoherenceValues, ...
        options.StimulationCode);

    isElectricalStim(trialIndex) = metadata.IsElectricalStim;
    condition(trialIndex) = metadata.Condition;
    coherence(trialIndex) = metadata.Coherence;
    coherenceIndex(trialIndex) = metadata.CoherenceIndex;
    direction(trialIndex) = metadata.Direction;
    response(trialIndex) = metadata.Response;
    block(trialIndex) = metadata.Block;
    trialStart(trialIndex) = metadata.TrialStart;
    trialEnd(trialIndex) = metadata.TrialEnd;
    motionOn(trialIndex) = metadata.MotionOn;
    motionOff(trialIndex) = metadata.MotionOff;
    responseDuration(trialIndex) = metadata.Duration;

    if strlength(reason) > 0
        exclusionReason(trialIndex) = reason;
    else
        spikes = trialInfo(trialIndex).UnitT;
        if size(spikes, 1) ~= numChannels || size(spikes, 2) ~= numUnits
            exclusionReason(trialIndex) = "UnitT channel/unit dimensions changed";
        elseif ~isnumeric(spikes)
            exclusionReason(trialIndex) = "UnitT is not numeric";
        else
            spikeCount = sum(metadata.MotionOn <= spikes & ...
                spikes <= metadata.MotionOff, 3);
            trialFR(trialIndex, :, :) = reshape( ...
                spikeCount ./ metadata.Duration, [1 numChannels numUnits]);
            included(trialIndex) = true;
        end
    end

    if options.ProgressInterval > 0 && ...
            (mod(trialIndex, options.ProgressInterval) == 0 || ...
            trialIndex == analyzedTrialCount)
        fprintf('  Trial %d/%d\n', trialIndex, analyzedTrialCount);
    end
end
clear trialInfo

noStimMask = included & ~isElectricalStim;
stimMask = included & isElectricalStim;
pooledMask = included;

noStimWithZero = buildTuningGroup(trialFR, noStimMask, condition, ...
    coherenceIndex, direction, response, numel(conditionNames), ...
    numel(analysisCoherenceValues));
stimWithZero = buildTuningGroup(trialFR, stimMask, condition, ...
    coherenceIndex, direction, response, numel(conditionNames), ...
    numel(analysisCoherenceValues));
pooledWithZero = buildTuningGroup(trialFR, pooledMask, condition, ...
    coherenceIndex, direction, response, numel(conditionNames), ...
    numel(analysisCoherenceValues));

quickBinMask = ismember(analysisCoherenceValues, coherenceValues);
quickTrialMask = included & ismember(coherence, coherenceValues);
noStim = subsetTuningGroup(noStimWithZero, quickBinMask, ...
    quickTrialMask & ~isElectricalStim);
stim = subsetTuningGroup(stimWithZero, quickBinMask, ...
    quickTrialMask & isElectricalStim);
pooled = subsetTuningGroup(pooledWithZero, quickBinMask, quickTrialMask);

Neuro = noStim;
Neuro.NoStim = noStim;
Neuro.Stim = stim;
Neuro.Pooled = pooled;
Neuro.Coherence = coherenceValues;
Neuro.CoherenceArray = coherenceValues;
Neuro.CoherenceArrayWithZero = analysisCoherenceValues;
Neuro.ConditionNames = conditionNames;
Neuro.ConditionArray = 1:numel(conditionNames);
Neuro.ChannelMap = channelMap;
Neuro.StimulationCode = options.StimulationCode;
Neuro.DefaultSubset = "NoStim";
Neuro.TrialFiringRate = trialFR;
Neuro.WithZero = struct( ...
    'NoStim', noStimWithZero, ...
    'Stim', stimWithZero, ...
    'Pooled', pooledWithZero, ...
    'Coherence', analysisCoherenceValues);
Neuro.Source = struct( ...
    'TInfoFile', string(tInfoPath), ...
    'SelIndexFile', string(selIndexPath), ...
    'SelectionVariable', string(selectionVariable), ...
    'TopLevelTrialGroup', "NoStim", ...
    'ResponseWindow', "first EID 118 through last EID 130 before trial end");

TrialSummary = table( ...
    selectedSourceIndex(:), (1:analyzedTrialCount)', included, ...
    isElectricalStim, condition, coherence, coherenceIndex, direction, ...
    response, block, trialStart, trialEnd, motionOn, motionOff, ...
    responseDuration, exclusionReason, ...
    'VariableNames', { ...
    'TInfoTrialIndex', 'AnalyzedTrialIndex', 'Included', ...
    'ElectricalStim', 'Condition', 'Coherence', 'CoherenceIndex', ...
    'Direction', 'Response', 'Block', 'TrialStart', 'TrialEnd', ...
    'MotionOn', 'MotionOff', 'ResponseDuration', 'ExclusionReason'});

ExtractionSummary = buildExtractionSummary( ...
    tInfoPath, selIndexPath, selectionVariable, inputTrialCount, ...
    selectedTrialCount, analyzedTrialCount, included, noStimMask, stimMask, ...
    exclusionReason, numChannels, numUnits, coherenceValues, eyeCheck, ...
    noStim.Trials.NumTrials, stim.Trials.NumTrials, ...
    analysisCoherenceValues, noStimWithZero.Trials.NumTrials, ...
    stimWithZero.Trials.NumTrials);

fprintf(['Parsed %d tuning trials: %d NoStim and %d Stim; excluded %d. ' ...
    'Quick-compatible nonzero output: %d NoStim and %d Stim.\n'], ...
    nnz(included), nnz(noStimMask), nnz(stimMask), nnz(~included), ...
    nnz(quickTrialMask & ~isElectricalStim), ...
    nnz(quickTrialMask & isElectricalStim));

tuningFigure = gobjects(0);
if options.MakePlot
    tuningFigure = makeTuningFigure(noStimWithZero, ...
        analysisCoherenceValues, ...
        conditionNames, channelMap, options.FigureVisible);
end
end


function [tInfoPath, selIndexPath] = resolveInputFiles(pathName, fileNames)
while iscell(pathName) && isscalar(pathName)
    pathName = pathName{1};
end
if ~(ischar(pathName) || (isstring(pathName) && isscalar(pathName)))
    error('StimTuning:InvalidPathName', ...
        'pathName must be scalar text.');
end
pathName = char(string(pathName));

if ischar(fileNames)
    names = string({fileNames});
elseif isstring(fileNames)
    names = fileNames(:);
elseif iscell(fileNames)
    try
        names = string(fileNames(:));
    catch
        error('StimTuning:InvalidFileNames', ...
            'fileNames must contain text TInfo/SelIndex names.');
    end
else
    error('StimTuning:InvalidFileNames', ...
        'fileNames must be a cell or string array.');
end

if numel(names) ~= 2
    error('StimTuning:ExpectedFilePair', ...
        'Provide exactly one TInfo file and one SelIndex file.');
end
isSelection = contains(lower(names), "selindex");
if nnz(isSelection) ~= 1
    error('StimTuning:AmbiguousFilePair', ...
        'Exactly one filename must contain SelIndex.');
end

tInfoPath = resolveOneFile(pathName, names(~isSelection));
selIndexPath = resolveOneFile(pathName, names(isSelection));
end


function filePath = resolveOneFile(pathName, fileName)
fileName = char(fileName);
if isfile(fileName)
    filePath = fileName;
else
    filePath = fullfile(pathName, fileName);
end
if ~isfile(filePath)
    error('StimTuning:FileNotFound', 'File not found: %s', filePath);
end
end


function [selectionMask, variableName] = getSelectionMask(selectionData)
if isfield(selectionData, 'EditSel')
    selectionMask = logical(selectionData.EditSel);
    variableName = 'EditSel';
elseif isfield(selectionData, 'Selected')
    selectionMask = logical(selectionData.Selected);
    variableName = 'Selected';
else
    error('StimTuning:MissingSelection', ...
        'The SelIndex file contains neither EditSel nor Selected.');
end
selectionMask = selectionMask(:);
end


function config = getConfig(tInfoData, selectionData)
if isfield(selectionData, 'Config')
    config = selectionData.Config;
elseif isfield(tInfoData, 'Config')
    config = tInfoData.Config;
else
    config = struct();
end
end


function [trialInfo, sourceIndex, status] = applyEyeCheckIfRequested( ...
    trialInfo, sourceIndex, config, tInfoPath, applyEyeCheck, chunkSize, ...
    skipEyeCheckDates)
status = struct('Requested', applyEyeCheck, 'Applied', false, ...
    'IntentionallySkipped', false, ...
    'Status', "not requested", 'InputTrialCount', numel(trialInfo), ...
    'OutputTrialCount', numel(trialInfo), ...
    'RejectedTrialCount', 0, 'ZeroCoherenceBypassedCount', 0, ...
    'ChunkSize', chunkSize, 'Message', "");
if ~applyEyeCheck
    return
end

recordingDate = inferRecordingDate(tInfoPath);
if strlength(recordingDate) == 0
    status.Status = "recording date unavailable; continued without eye check";
    status.Message = "Could not infer a recording date from the input path";
    warning('StimTuning:EyeCheckDateMissing', '%s.', status.Message);
    return
end
recordingDay = dateshift(datetime(recordingDate, ...
    'InputFormat', 'ddMMMyyyy'), 'start', 'day');
skipDays = dateshift(skipEyeCheckDates, 'start', 'day');
if any(recordingDay == skipDays)
    status.IntentionallySkipped = true;
    status.Status = ...
        "skipped: known bad eye data (legacy Quick exception)";
    status.Message = "The Quick pipeline intentionally skips " + ...
        string(recordingDay, 'dd-MMM-yyyy');
    return
end

if exist('Offline_3DMotion_VersionVergenceCondCheck', 'file') ~= 2 && ...
        exist('Setup3DMotionAnalysisPaths', 'file') == 2
    Setup3DMotionAnalysisPaths();
end
if exist('Offline_3DMotion_VersionVergenceCondCheck', 'file') ~= 2
    status.Status = "helper unavailable; continued without eye check";
    status.Message = "Offline_3DMotion_VersionVergenceCondCheck was not found";
    warning('StimTuning:EyeCheckUnavailable', '%s.', status.Message);
    return
end
if ~isfield(config, 'ScrDistmm')
    status.Status = "Config.ScrDistmm unavailable; continued without eye check";
    status.Message = "Config.ScrDistmm is required by the eye-check helper";
    warning('StimTuning:EyeCheckConfigMissing', '%s.', status.Message);
    return
end

% The legacy helper rejects every zero-coherence trial before checking its
% eyes. Preserve those valid trials and apply the identical eye criteria to
% the nonzero trials that the Quick pipeline was designed to handle.
zeroCoherenceMask = hasZeroCoherenceCode(trialInfo);
status.ZeroCoherenceBypassedCount = nnz(zeroCoherenceMask);
checkPositions = find(~zeroCoherenceMask);
if isempty(checkPositions)
    status.Applied = true;
    status.Status = "no nonzero-coherence trials; zero coherence preserved";
    return
end
try
    keepMask = zeroCoherenceMask;
    for chunkStart = 1:chunkSize:numel(checkPositions)
        chunkStop = min(chunkStart + chunkSize - 1, numel(checkPositions));
        chunkPositions = checkPositions(chunkStart:chunkStop);
        checkInput = trialInfo(chunkPositions);
        keysBefore = trialKeys(checkInput);
        [checkedTrials, ~, ~, ~] = ...
            Offline_3DMotion_VersionVergenceCondCheck( ...
            30, config, [0 0 0], checkInput, char(recordingDate), 0);
        keysAfter = trialKeys(checkedTrials);
        [keptChunkPositions, mappingSucceeded] = mapKeptTrialPositions( ...
            keysBefore, keysAfter);
        if ~mappingSucceeded
            error('StimTuning:EyeCheckMappingFailed', ...
                ['Could not map eye-checked trials back to TInfo trial ' ...
                'indices in chunk %d:%d.'], chunkStart, chunkStop);
        end
        keepMask(chunkPositions(keptChunkPositions)) = true;
        clear checkInput checkedTrials
    end
    trialInfo = trialInfo(keepMask);
    sourceIndex = sourceIndex(keepMask);
    status.Applied = true;
    if any(zeroCoherenceMask)
        status.Status = "applied to nonzero coherence; zero coherence preserved";
    else
        status.Status = "applied";
    end
    status.OutputTrialCount = numel(trialInfo);
    status.RejectedTrialCount = status.InputTrialCount - ...
        status.OutputTrialCount;
catch ME
    status.Status = "failed; continued without eye check";
    status.Message = string(ME.message);
    warning('StimTuning:EyeCheckFailed', ...
        'Version/vergence check failed; retaining selected trials: %s', ...
        ME.message);
end
end


function mask = hasZeroCoherenceCode(trialInfo)
mask = false(numel(trialInfo), 1);
for index = 1:numel(trialInfo)
    if isfield(trialInfo, 'EID')
        mask(index) = any(trialInfo(index).EID == 10000);
    end
end
end


function recordingDate = inferRecordingDate(tInfoPath)
% The table's YYYYMMDD session folder is more reliable than historical
% filenames. A few Stim files carry copied or malformed embedded dates.
pathToken = regexp(fileparts(tInfoPath), ...
    '(?<!\d)\d{8}(?!\d)', 'match');
if ~isempty(pathToken)
    try
        value = datetime(pathToken{end}, 'InputFormat', 'yyyyMMdd');
        value.Format = 'ddMMMyyyy';
        recordingDate = string(value);
        return
    catch
    end
end

[~, fileName] = fileparts(tInfoPath);
token = regexp(fileName, '\d{1,2}[A-Za-z]{3}\d{4}', 'match', 'once');
if ~isempty(token)
    recordingDate = string(token);
    return
end
token = regexp(tInfoPath, '(?<!\d)\d{8}(?!\d)', 'match', 'once');
if isempty(token)
    recordingDate = "";
else
    try
        value = datetime(token, 'InputFormat', 'yyyyMMdd');
        value.Format = 'ddMMMyyyy';
        recordingDate = string(value);
    catch
        recordingDate = "";
    end
end
end


function keys = trialKeys(trialInfo)
keys = nan(numel(trialInfo), 1);
if ~isfield(trialInfo, 'StartTimeStamp')
    return
end
for index = 1:numel(trialInfo)
    value = trialInfo(index).StartTimeStamp;
    if isnumeric(value) && isscalar(value) && isfinite(value)
        keys(index) = value;
    end
end
end


function [positions, succeeded] = mapKeptTrialPositions(keysBefore, keysAfter)
if numel(keysAfter) == numel(keysBefore)
    positions = (1:numel(keysBefore))';
    succeeded = true;
    return
end
if all(isfinite(keysBefore)) && all(isfinite(keysAfter)) && ...
        numel(unique(keysBefore)) == numel(keysBefore)
    [found, location] = ismember(keysAfter, keysBefore);
    if all(found) && numel(unique(location)) == numel(location)
        positions = location;
        succeeded = true;
        return
    end
end
positions = zeros(0, 1);
succeeded = false;
end


function [numChannels, numUnits] = findResponseDimensions(trialInfo)
if ~isfield(trialInfo, 'UnitT')
    error('StimTuning:MissingUnitT', ...
        'Selected TrialInfo records do not contain UnitT.');
end
for index = 1:numel(trialInfo)
    spikes = trialInfo(index).UnitT;
    if isnumeric(spikes) && ~isempty(spikes)
        numChannels = size(spikes, 1);
        numUnits = size(spikes, 2);
        if numChannels < 1 || numUnits < 1
            break
        end
        return
    end
end
error('StimTuning:NoUnitData', ...
    'No selected trial contains a nonempty numeric UnitT array.');
end


function [metadata, reason] = decodeMotionTrial( ...
    trial, coherenceValues, stimulationCode)
metadata = struct( ...
    'IsElectricalStim', false, 'Condition', NaN, 'Coherence', NaN, ...
    'CoherenceIndex', NaN, 'Direction', NaN, 'Response', NaN, ...
    'Block', NaN, 'TrialStart', NaN, 'TrialEnd', NaN, ...
    'MotionOn', NaN, 'MotionOff', NaN, 'Duration', NaN);
reason = "";

requiredFields = {'EID', 'EventT', 'UnitT'};
for fieldIndex = 1:numel(requiredFields)
    if ~isfield(trial, requiredFields{fieldIndex})
        reason = "Missing field " + requiredFields{fieldIndex};
        return
    end
end

events = double(trial.EID(:)');
eventTimes = double(trial.EventT(:)');
if isempty(events) || numel(events) ~= numel(eventTimes)
    reason = "EID and EventT are empty or different lengths";
    return
end
metadata.IsElectricalStim = any(events == stimulationCode);

startTimes = eventTimes(events == 111);
endTimes = eventTimes(events == 112);
if isempty(startTimes) || isempty(endTimes)
    reason = "Missing trial start (111) or end (112)";
    return
end
trialStart = max(startTimes);
endTimes = endTimes(endTimes >= trialStart);
if isempty(endTimes)
    reason = "No trial end (112) follows the final trial start (111)";
    return
end
trialEnd = min(endTimes);
metadata.TrialStart = trialStart;
metadata.TrialEnd = trialEnd;
if ~isfinite(trialStart) || ~isfinite(trialEnd) || trialEnd <= trialStart
    reason = "Invalid trial start/end times";
    return
end

inTrial = eventTimes >= trialStart & eventTimes <= trialEnd;
trialEvents = events(inTrial);
trialEventTimes = eventTimes(inTrial);
metadata.IsElectricalStim = any(trialEvents == stimulationCode);

motionOnTimes = trialEventTimes(trialEvents == 118 & ...
    trialEventTimes < trialEnd);
if isempty(motionOnTimes)
    reason = "Missing motion on (118) or off (130)";
    return
end
metadata.MotionOn = motionOnTimes(1);
motionOffTimes = trialEventTimes(trialEvents == 130 & ...
    trialEventTimes > metadata.MotionOn & trialEventTimes < trialEnd);
if isempty(motionOffTimes)
    reason = "Missing motion off (130) after motion on (118)";
    return
end
metadata.MotionOff = motionOffTimes(end);
metadata.Duration = metadata.MotionOff - metadata.MotionOn;
if ~isfinite(metadata.Duration) || metadata.Duration <= 0
    reason = "Nonpositive motion response window";
    return
end

directionCandidates = unique( ...
    trialEvents(trialEvents >= 4000 & trialEvents < 5000) - 4001, ...
    'stable');
directionCandidates = directionCandidates(ismember(directionCandidates, [-1 1]));
if numel(directionCandidates) ~= 1
    reason = "Missing or ambiguous direction code";
    return
end
metadata.Direction = directionCandidates(1);

conditionCandidates = unique( ...
    trialEvents(trialEvents >= 8000 & trialEvents < 9000) - 8000, ...
    'stable');
conditionCandidates = conditionCandidates(ismember(conditionCandidates, 1:4));
if numel(conditionCandidates) ~= 1
    reason = "Missing or ambiguous condition code";
    return
end
metadata.Condition = conditionCandidates(1);

coherenceCodes = unique( ...
    trialEvents(trialEvents >= 10000 & trialEvents <= 20000), 'stable');
candidateCoherence = round( ...
    ((coherenceCodes - 10000) .* metadata.Direction) ./ 10000, 2);
[isSupported, candidateIndex] = ismember(candidateCoherence, coherenceValues);
candidateIndex = unique(candidateIndex(isSupported), 'stable');
if numel(candidateIndex) ~= 1
    reason = "Missing, unsupported, or ambiguous coherence code";
    return
end
metadata.CoherenceIndex = candidateIndex;
metadata.Coherence = coherenceValues(candidateIndex);

responseCandidates = unique( ...
    trialEvents(trialEvents >= 6000 & trialEvents < 7000) - 6000, ...
    'stable');
responseCandidates = responseCandidates(ismember(responseCandidates, [0 1]));
if ~isempty(responseCandidates)
    metadata.Response = responseCandidates(1);
end

blockCandidates = unique( ...
    trialEvents(trialEvents >= 2000 & trialEvents < 3000) - 2000, ...
    'stable');
if ~isempty(blockCandidates)
    metadata.Block = blockCandidates(1);
end
end


function tuning = buildTuningGroup(trialFR, groupMask, condition, ...
    coherenceIndex, direction, response, numConditions, numCoherences)
numChannels = size(trialFR, 2);
numUnits = size(trialFR, 3);
counts = zeros(numConditions, numCoherences);
toward = zeros(numConditions, numCoherences);
correct = zeros(numConditions, numCoherences);

groupIndices = find(groupMask);
for index = groupIndices(:)'
    row = condition(index);
    column = coherenceIndex(index);
    counts(row, column) = counts(row, column) + 1;
    if response(index) == 1
        correct(row, column) = correct(row, column) + 1;
    end
    choseToward = (response(index) == 1 && direction(index) == 1) || ...
        (response(index) == 0 && direction(index) == -1);
    if choseToward
        toward(row, column) = toward(row, column) + 1;
    end
end

maxReplicates = max(counts, [], 'all');
responses = nan(numConditions, numCoherences, maxReplicates, ...
    numChannels, numUnits);
nextReplicate = zeros(numConditions, numCoherences);
for index = groupIndices(:)'
    row = condition(index);
    column = coherenceIndex(index);
    nextReplicate(row, column) = nextReplicate(row, column) + 1;
    replicate = nextReplicate(row, column);
    responses(row, column, replicate, :, :) = trialFR(index, :, :);
end

if maxReplicates == 0
    means = nan(numConditions, numCoherences, numChannels, numUnits);
    sem = means;
else
    means = reshape(mean(responses, 3, 'omitnan'), ...
        [numConditions numCoherences numChannels numUnits]);
    responseStd = reshape(std(responses, 0, 3, 'omitnan'), ...
        [numConditions numCoherences numChannels numUnits]);
    sem = responseStd ./ reshape(sqrt(counts), ...
        [numConditions numCoherences 1 1]);
    emptyCells = reshape(counts == 0, ...
        [numConditions numCoherences 1 1]);
    sem(repmat(emptyCells, [1 1 numChannels numUnits])) = NaN;
end

tuning = struct();
tuning.Means = means;
tuning.SEM = sem;
tuning.All = responses;
tuning.Trials = struct('NumTrials', counts, 'Toward', toward, ...
    'Correct', correct);
tuning.TrialMask = groupMask;
end


function subset = subsetTuningGroup(tuning, coherenceMask, trialMask)
subset = struct();
subset.Means = tuning.Means(:, coherenceMask, :, :);
subset.SEM = tuning.SEM(:, coherenceMask, :, :);
subset.All = tuning.All(:, coherenceMask, :, :, :);
subset.Trials = struct( ...
    'NumTrials', tuning.Trials.NumTrials(:, coherenceMask), ...
    'Toward', tuning.Trials.Toward(:, coherenceMask), ...
    'Correct', tuning.Trials.Correct(:, coherenceMask));
subset.TrialMask = trialMask;
end


function summary = buildExtractionSummary( ...
    tInfoPath, selIndexPath, selectionVariable, inputTrialCount, ...
    selectedTrialCount, analyzedTrialCount, included, noStimMask, stimMask, ...
    exclusionReason, numChannels, numUnits, coherenceValues, eyeCheck, ...
    noStimCounts, stimCounts, coherenceValuesWithZero, ...
    noStimCountsWithZero, stimCountsWithZero)
summary = struct();
summary.TInfoFile = string(tInfoPath);
summary.SelIndexFile = string(selIndexPath);
summary.SelectionVariable = string(selectionVariable);
summary.InputTrialCount = inputTrialCount;
summary.SelectedTrialCount = selectedTrialCount;
summary.AnalyzedTrialCount = analyzedTrialCount;
summary.IncludedTrialCount = nnz(included);
summary.NoStimTrialCount = nnz(noStimMask);
summary.StimTrialCount = nnz(stimMask);
summary.QuickCompatibleNoStimTrialCount = sum(noStimCounts, 'all');
summary.QuickCompatibleStimTrialCount = sum(stimCounts, 'all');
summary.ExcludedTrialCount = nnz(~included);
summary.NumChannels = numChannels;
summary.NumUnits = numUnits;
summary.Coherence = coherenceValues;
summary.NoStimCounts = noStimCounts;
summary.StimCounts = stimCounts;
summary.CoherenceWithZero = coherenceValuesWithZero;
summary.NoStimCountsWithZero = noStimCountsWithZero;
summary.StimCountsWithZero = stimCountsWithZero;
summary.ZeroCoherenceTrialCount = ...
    summary.IncludedTrialCount - ...
    summary.QuickCompatibleNoStimTrialCount - ...
    summary.QuickCompatibleStimTrialCount;
summary.EyeCheck = eyeCheck;

excludedReasons = exclusionReason(~included);
if isempty(excludedReasons)
    summary.ExcludedByReason = table( ...
        strings(0, 1), zeros(0, 1), ...
        'VariableNames', {'Reason', 'Count'});
else
    [reasonNames, ~, group] = unique(excludedReasons);
    reasonCounts = accumarray(group, 1);
    summary.ExcludedByReason = table(reasonNames, reasonCounts, ...
        'VariableNames', {'Reason', 'Count'});
end
end


function tuningFigure = makeTuningFigure( ...
    tuning, coherenceValues, conditionNames, channelMap, figureVisible)
if figureVisible
    visible = 'on';
else
    visible = 'off';
end
colors = [0 0 0; 0 0 255; 5 150 5; 234 0 233] ./ 255;
tuningFigure = figure('Color', 'w', 'Visible', visible, ...
    'Name', '3DMotionStim NoStim tuning');
layout = tiledlayout(tuningFigure, 2, 8, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
numChannels = size(tuning.Means, 3);
numUnits = size(tuning.Means, 4);

for tileIndex = 1:numel(channelMap)
    axesHandle = nexttile(layout, tileIndex);
    channel = channelMap(tileIndex);
    if channel > numChannels || numUnits < 1
        axis(axesHandle, 'off');
        continue
    end
    hold(axesHandle, 'on');
    validCoherence = any(tuning.Trials.NumTrials > 0, 1);
    for conditionIndex = 1:numel(conditionNames)
        y = reshape(tuning.Means( ...
            conditionIndex, validCoherence, channel, 1), 1, []);
        errorValue = reshape(tuning.SEM( ...
            conditionIndex, validCoherence, channel, 1), 1, []);
        errorbar(axesHandle, coherenceValues(validCoherence), y, ...
            errorValue, '-o', 'Color', colors(conditionIndex, :), ...
            'MarkerFaceColor', colors(conditionIndex, :), ...
            'MarkerSize', 3, 'LineWidth', 1);
    end
    yline(axesHandle, 0, ':', 'Color', [0.75 0.75 0.75]);
    title(axesHandle, sprintf('Ch %d', channel));
    box(axesHandle, 'on');
    xlim(axesHandle, [min(coherenceValues) max(coherenceValues)]);
    if tileIndex > 8
        xlabel(axesHandle, 'Coherence');
    end
    if tileIndex == 1 || tileIndex == 9
        ylabel(axesHandle, 'Firing rate (spikes/s)');
    end
end
title(layout, sprintf(['3DMotionStim tuning from NoStim trials ' ...
    '(%d trials; unit 1)'], nnz(tuning.TrialMask)));

legendAxes = nexttile(layout, 1);
legendHandle = legend(legendAxes, cellstr(conditionNames), ...
    'Orientation', 'horizontal', 'FontSize', 7);
legendHandle.Layout.Tile = 'south';
end

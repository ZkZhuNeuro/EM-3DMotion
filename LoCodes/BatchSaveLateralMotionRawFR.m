function RawFRData = BatchSaveLateralMotionRawFR(files, varargin)
%BATCHSAVELATERALMOTIONRAWFR Export raw lateral-motion firing rates by trial.
%   RawFRData = BatchSaveLateralMotionRawFR(files) loads each 2D-motion
%   TInfo file listed in the `files` table, computes stimulus-window firing
%   rate from TrialInfo.UnitT, groups trials by the same event-code axes
%   used by the lateral-motion analysis (condition, direction, speed), and
%   saves one MAT file per recording.
%
%   Expected columns in `files` follow UpdatedBatchLateralMotionAnalysis:
%   Paths, Names, ROI, and Units.
%
%   Optional name/value pairs:
%       'saveOutputs' - logical, save MAT files to disk (default true)
%       'outputSubdir' - subfolder under C:\<Monkey>\In_Processing\<ROI>\
%                        used for export files (default '2D_RawFR')
%       'saveCombined' - logical, save one combined MAT file in the current
%                        folder (default false)
%       'combinedName' - filename for the combined MAT file
%                        (default 'LateralMotionRawFR_All.mat')

options = struct( ...
    'saveOutputs', true, ...
    'outputSubdir', '2D_RawFR', ...
    'saveCombined', false, ...
    'combinedName', 'LateralMotionRawFR_All.mat');

optionNames = fieldnames(options);
if mod(numel(varargin), 2) == 1
    error('Please provide propertyName/propertyValue pairs.');
end
for pair = reshape(varargin, 2, [])
    if any(strcmp(pair{1}, optionNames))
        options.(pair{1}) = pair{2};
    else
        error('%s is not a recognized parameter name.', pair{1});
    end
end

RawFRData = [];

for f = 1:size(files, 1)
    tinfoPath = fullfile(files.Paths{f}, files.Names{f, 1});
    selIndexPath = get_selindex_path(files, f);
    units = get_selected_units(files, f, tinfoPath);

    disp(['Exporting lateral raw FR: ', files.Names{f, 1}, ...
        '  (', num2str(f), '/', num2str(size(files, 1)), ')']);

    S = load(tinfoPath, 'TrialInfo');
    TrialInfo = S.TrialInfo;
    [TrialInfo, selIndexUsed] = apply_selection_if_present(TrialInfo, selIndexPath);

    exportData = extract_raw_fr_from_trialinfo(TrialInfo, units);
    exportData.recording_name = make_recording_name(files.Names{f, 1});
    exportData.source_tinfo = tinfoPath;
    exportData.source_selindex = selIndexUsed;
    exportData.roi = files.ROI{f};
    exportData.path = files.Paths{f};
    exportData.tinfo_name = files.Names{f, 1};
    exportData.units = units(:)';

    if isempty(RawFRData)
        RawFRData = exportData;
    else
        RawFRData(end + 1) = exportData; %#ok<AGROW>
    end

    if options.saveOutputs
        monkey = extractBetween(files.Paths(f), '\', '\');
        saveDir = fullfile(['C:\', monkey{1}, '\In_Processing\', files.ROI{f}], options.outputSubdir);
        if ~isfolder(saveDir)
            mkdir(saveDir);
        end
        savePath = fullfile(saveDir, [exportData.recording_name, '_RawFR.mat']);
        RawFRExport = exportData; %#ok<NASGU>
        save(savePath, 'RawFRExport', '-v7.3');
    end
end

if options.saveCombined
    save(options.combinedName, 'RawFRData', '-v7.3');
end
end

function exportData = extract_raw_fr_from_trialinfo(TrialInfo, units)
nTrials = numel(TrialInfo);
nUnits = numel(units);

trialFR = nan(nTrials, nUnits);
stimOn = nan(nTrials, 1);
stimOff = nan(nTrials, 1);
stimDur = nan(nTrials, 1);
conditionCode = nan(nTrials, 1);
directionCode = nan(nTrials, 1);
speedCode = nan(nTrials, 1);
taskCode = nan(nTrials, 1);
validTrial = false(nTrials, 1);

for t = 1:nTrials
    T = get_trial_times(TrialInfo(t));
    if ~isfinite(T.StimOn) || ~isfinite(T.StimOff) || T.StimOff <= T.StimOn
        continue
    end

    trialEvents = get_trial_events(TrialInfo(t), T.Start, T.End);

    conditionCode(t) = first_code_in_range(trialEvents, 8000, 9000);
    directionCode(t) = get_direction_code(trialEvents);
    speedCode(t) = get_speed_code(trialEvents);
    taskCode(t) = first_code_in_range(trialEvents, 2000, 3000);

    stimOn(t) = T.StimOn;
    stimOff(t) = T.StimOff;
    stimDur(t) = T.StimOff - T.StimOn;
    validTrial(t) = true;

    for u = 1:nUnits
        [spikeTimes, unitMapped] = get_unit_spike_times(TrialInfo(t), units(u));
        if unitMapped
            trialFR(t, u) = sum(spikeTimes >= T.StimOn & spikeTimes < T.StimOff) ./ stimDur(t);
        else
            trialFR(t, u) = nan;
        end
    end
end

conditionLevels = unique(fillmissing_codes(conditionCode(validTrial)));
directionLevels = unique(fillmissing_codes(directionCode(validTrial)));
speedLevels = unique(fillmissing_codes(speedCode(validTrial)));

[rawByCDS, meanByCDS, semByCDS, nByCDS] = group_trials_by_axes( ...
    trialFR, conditionCode, directionCode, speedCode, validTrial, ...
    conditionLevels, directionLevels, speedLevels);

[rawByDir, meanByDir, semByDir, nByDir] = group_trials_by_direction( ...
    trialFR, directionCode, validTrial, directionLevels);

exportData = struct();
exportData.trial_raw_fr = trialFR;
exportData.trial_condition_code = conditionCode;
exportData.trial_direction_code = directionCode;
exportData.trial_speed_code = speedCode;
exportData.trial_task_code = taskCode;
exportData.trial_stim_on = stimOn;
exportData.trial_stim_off = stimOff;
exportData.trial_stim_duration = stimDur;
exportData.valid_trial = validTrial;

exportData.condition_codes = conditionLevels;
exportData.direction_codes = directionLevels;
exportData.speed_codes = speedLevels;
exportData.direction_degrees_guess = guess_direction_degrees(directionLevels);

exportData.rawFR_by_condition_direction_speed = rawByCDS;
exportData.meanFR_by_condition_direction_speed = meanByCDS;
exportData.semFR_by_condition_direction_speed = semByCDS;
exportData.nTrials_by_condition_direction_speed = nByCDS;

exportData.rawFR_by_direction = rawByDir;
exportData.meanFR_by_direction = meanByDir;
exportData.semFR_by_direction = semByDir;
exportData.nTrials_by_direction = nByDir;
end

function [rawByCDS, meanByCDS, semByCDS, nByCDS] = group_trials_by_axes( ...
    trialFR, conditionCode, directionCode, speedCode, validTrial, ...
    conditionLevels, directionLevels, speedLevels)

nUnits = size(trialFR, 2);
rawByCDS = cell(numel(conditionLevels), numel(directionLevels), numel(speedLevels), nUnits);
meanByCDS = nan(numel(conditionLevels), numel(directionLevels), numel(speedLevels), nUnits);
semByCDS = nan(numel(conditionLevels), numel(directionLevels), numel(speedLevels), nUnits);
nByCDS = zeros(numel(conditionLevels), numel(directionLevels), numel(speedLevels), nUnits);

conditionCode = fillmissing_codes(conditionCode);
directionCode = fillmissing_codes(directionCode);
speedCode = fillmissing_codes(speedCode);

for c = 1:numel(conditionLevels)
    for d = 1:numel(directionLevels)
        for s = 1:numel(speedLevels)
            trialMask = validTrial ...
                & conditionCode == conditionLevels(c) ...
                & directionCode == directionLevels(d) ...
                & speedCode == speedLevels(s);
            for u = 1:nUnits
                vals = trialFR(trialMask, u);
                vals = vals(~isnan(vals));
                rawByCDS{c, d, s, u} = vals;
                nByCDS(c, d, s, u) = numel(vals);
                if ~isempty(vals)
                    meanByCDS(c, d, s, u) = mean(vals, 'omitnan');
                    semByCDS(c, d, s, u) = std(vals, 'omitnan') ./ sqrt(numel(vals));
                end
            end
        end
    end
end
end

function [rawByDir, meanByDir, semByDir, nByDir] = group_trials_by_direction( ...
    trialFR, directionCode, validTrial, directionLevels)

nUnits = size(trialFR, 2);
rawByDir = cell(numel(directionLevels), nUnits);
meanByDir = nan(numel(directionLevels), nUnits);
semByDir = nan(numel(directionLevels), nUnits);
nByDir = zeros(numel(directionLevels), nUnits);

directionCode = fillmissing_codes(directionCode);

for d = 1:numel(directionLevels)
    trialMask = validTrial & directionCode == directionLevels(d);
    for u = 1:nUnits
        vals = trialFR(trialMask, u);
        vals = vals(~isnan(vals));
        rawByDir{d, u} = vals;
        nByDir(d, u) = numel(vals);
        if ~isempty(vals)
            meanByDir(d, u) = mean(vals, 'omitnan');
            semByDir(d, u) = std(vals, 'omitnan') ./ sqrt(numel(vals));
        end
    end
end
end

function T = get_trial_times(trial)
T.Start = get_first_event_time(trial, 111, @min);
T.End = get_first_event_time(trial, 112, @min);
T.StimOn = get_first_event_time(trial, 118, @min);
T.StimOff = get_stim_off_time(trial, T.StimOn, T.End);
end

function eventTime = get_first_event_time(trial, eventID, reducer)
eventTimes = trial.EventT(trial.EID == eventID);
if isempty(eventTimes)
    eventTime = nan;
else
    eventTime = reducer(eventTimes);
end
end

function stimOff = get_stim_off_time(trial, stimOn, trialEnd)
% Newer files use 130. Older Jim lateral-motion files end the stimulus at
% 120, and broken-fixation trials can terminate at 119.
candidates = [];
for eventID = [130 120 119 112]
    eventTimes = trial.EventT(trial.EID == eventID);
    if ~isempty(eventTimes)
        eventTimes = eventTimes(eventTimes > stimOn);
        candidates = [candidates; eventTimes(:)]; %#ok<AGROW>
    end
end

if isempty(candidates)
    stimOff = trialEnd;
else
    stimOff = min(candidates);
end
end

function trialEvents = get_trial_events(trial, startTime, endTime)
if ~isfinite(startTime) || ~isfinite(endTime)
    trialEvents = trial.EID;
else
    trialEvents = trial.EID(trial.EventT >= startTime & trial.EventT < endTime);
end
end

function code = first_code_in_range(events, lowerBound, upperBound)
idx = events >= lowerBound & events < upperBound;
if any(idx)
    code = events(find(idx, 1, 'first'));
else
    code = nan;
end
end

function [spikeTimes, unitMapped] = get_unit_spike_times(trial, unitIndex)
unitMapped = true;
unitT = trial.UnitT;

if isfield(trial, 'UnitID')
    unitIDs = trial.UnitID(:)';
else
    unitIDs = [];
end

unitDim = infer_unit_dimension(unitT, unitIDs);
mappedIndex = map_unit_index(unitT, unitIDs, unitIndex, unitDim);
if isnan(mappedIndex)
    spikeTimes = [];
    unitMapped = false;
    return
end

subs = repmat({':'}, 1, ndims(unitT));
subs{unitDim} = mappedIndex;
spikeTimes = squeeze(unitT(subs{:}));
spikeTimes = spikeTimes(:);
spikeTimes = spikeTimes(isfinite(spikeTimes) & spikeTimes > 0);
end

function unitDim = infer_unit_dimension(unitT, unitIDs)
sz = size(unitT);

if ~isempty(unitIDs) && numel(unitIDs) > 1
    matchDims = find(sz == numel(unitIDs));
    if ~isempty(matchDims)
        unitDim = matchDims(1);
        return
    end
end

nonSingletonDims = find(sz > 1);
if isempty(nonSingletonDims)
    unitDim = 1;
else
    unitDim = nonSingletonDims(1);
end
end

function mappedIndex = map_unit_index(unitT, unitIDs, unitIndex, unitDim)
mappedIndex = nan;
axisLength = size(unitT, unitDim);

if ~isempty(unitIDs) && numel(unitIDs) > 1
    % Older Jim files often store unit IDs as [0 1 2 ...], while the table
    % labels the first sorted unit as 2. In that case, prefer unitIndex-1.
    if any(unitIDs == 0) && unitIndex > 1
        idx = find(unitIDs == (unitIndex - 1), 1, 'first');
        if ~isempty(idx)
            mappedIndex = idx;
            return
        end
    end

    idx = find(unitIDs == unitIndex, 1, 'first');
    if ~isempty(idx)
        mappedIndex = idx;
        return
    end

    idx = find(unitIDs == (unitIndex - 1), 1, 'first');
    if ~isempty(idx)
        mappedIndex = idx;
        return
    end
end

if unitIndex >= 1 && unitIndex <= axisLength
    mappedIndex = unitIndex;
elseif unitIndex > 1 && (unitIndex - 1) <= axisLength
    mappedIndex = unitIndex - 1;
end
end

function codes = fillmissing_codes(codes)
codes(isnan(codes)) = 0;
end

function degrees = guess_direction_degrees(directionCodes)
degrees = nan(size(directionCodes));
validMask = directionCodes >= 4001 & directionCodes < 5000;
degrees(validMask) = mod(directionCodes(validMask) - 4001, 360);
legacyMask = directionCodes >= 30000 & directionCodes < 40000;
degrees(legacyMask) = mod(directionCodes(legacyMask) - 30000, 360);
end

function directionCode = get_direction_code(events)
directionCode = first_code_in_range(events, 4000, 5000);
if isnan(directionCode)
    directionCode = first_code_in_range(events, 30000, 40000);
end
end

function speedCode = get_speed_code(events)
speedCode = first_code_in_range(events, 10000, 20001);
if isnan(speedCode)
    speedCode = first_code_in_range(events, 7000, 8000);
end
if isnan(speedCode)
    speedCode = first_code_in_range(events, 9000, 10000);
end
end

function units = get_selected_units(files, rowIdx, tinfoPath)
if ismember('Units', files.Properties.VariableNames) && ~isempty(files.Units{rowIdx})
    units = files.Units{rowIdx};
    return
end

S = load(tinfoPath, 'TrialInfo');
units = 1:size(S.TrialInfo(1).UnitT, 1);
end

function selIndexPath = get_selindex_path(files, rowIdx)
selIndexPath = '';
if size(files.Names, 2) >= 2 && ~isempty(files.Names{rowIdx, 2})
    selIndexPath = fullfile(files.Paths{rowIdx}, files.Names{rowIdx, 2});
elseif contains(files.Names{rowIdx, 1}, '_TInfo.mat')
    candidate = fullfile(files.Paths{rowIdx}, strrep(files.Names{rowIdx, 1}, '_TInfo.mat', '_SelIndex.mat'));
    if isfile(candidate)
        selIndexPath = candidate;
    end
end
end

function [TrialInfo, selIndexUsed] = apply_selection_if_present(TrialInfo, selIndexPath)
selIndexUsed = '';
if isempty(selIndexPath) || ~isfile(selIndexPath)
    return
end

S = load(selIndexPath);
if ~isfield(S, 'EditSel')
    return
end

selection = logical(S.EditSel);
if numel(selection) ~= numel(TrialInfo)
    warning('SelIndex length does not match TrialInfo length. Skipping selection.');
    return
end

TrialInfo = TrialInfo(selection);
selIndexUsed = selIndexPath;
end

function recordingName = make_recording_name(tinfoName)
recordingName = extractBefore(tinfoName, '_TInfo');
recordingName = replace(recordingName, '-', '_');
recordingName = char(recordingName);
end

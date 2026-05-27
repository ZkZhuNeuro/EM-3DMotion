function sessionRF = RFMappingFunction_MUAStim(session_table, i_session, channelNums, sessionProgressText)
%% Settings
if nargin < 3 || isempty(channelNums)
    channelNums = 1:16;
end
if nargin < 4 || isempty(sessionProgressText)
    sessionProgressText = sprintf('Session %d', i_session);
end

disp(['Analyzing receptive field session: ', sessionProgressText]);
PSTH_preWinT = 0.05;
PSTH_postWinT = 0.05;

pathname = session_table.Paths{i_session};
waveformFile = session_table.Names{i_session};
waveformPath = fullfile(pathname, waveformFile);
nevPath = session_table.NevPath{i_session};

loadedWaveform = load(string(waveformPath));
[SpikeTsByChannel, waveformFields] = extractMUAChannelSpikeTimes( ...
    loadedWaveform, channelNums, waveformFile);

hFile = [];
[ns_status, hFile] = ns_OpenFile(char(nevPath));
if ~isequal(ns_status, 'ns_OK')
    error('Unable to open NEV file for %s: %s', sessionProgressText, nevPath);
end

fileCloser = onCleanup(@() safeCloseNeuroshareFile(hFile)); %#ok<NASGU>
Event = decodeNevEvents(hFile, sessionProgressText);
sessionDecode = decodeSparseNoiseSession(Event, PSTH_preWinT, PSTH_postWinT, sessionProgressText);

nChannels = numel(channelNums);
sessionRF = struct();
sessionRF.ChannelNums = channelNums(:);
sessionRF.WaveformFields = waveformFields(:);
sessionRF.rawRFmap = cell(nChannels, 1);
sessionRF.uniXPos = cell(nChannels, 1);
sessionRF.uniYPos = cell(nChannels, 1);
sessionRF.meanXYpos = cell(nChannels, 1);
sessionRF.FRbyTrial = cell(nChannels, 1);
sessionRF.Baseline = cell(nChannels, 1);

for iChannel = 1:nChannels
    channelProgressText = sprintf('%s channel %02d (%d/%d)', ...
        sessionProgressText, channelNums(iChannel), iChannel, nChannels);
    channelRF = computeRFForOneChannel( ...
        SpikeTsByChannel{iChannel}, sessionDecode, channelProgressText);

    sessionRF.rawRFmap{iChannel} = channelRF.rawRFmap;
    sessionRF.uniXPos{iChannel} = channelRF.uniXPos;
    sessionRF.uniYPos{iChannel} = channelRF.uniYPos;
    sessionRF.meanXYpos{iChannel} = channelRF.meanXYpos;
    sessionRF.FRbyTrial{iChannel} = channelRF.FRbyTrial;
    sessionRF.Baseline{iChannel} = channelRF.Baseline;
end
end

function sessionDecode = decodeSparseNoiseSession(Event, PSTH_preWinT, PSTH_postWinT, sessionProgressText)
StimOnID = 118;
EventTs = Event.timestamps;
EIDs = Event.EventID;

allXPos = nan(1, numel(EIDs));
allYPos = nan(1, numel(EIDs));
allBarWidth = nan(1, numel(EIDs));
allBarHeight = nan(1, numel(EIDs));
allBarColor = nan(1, numel(EIDs));

allBarWidth(EIDs >= 7000 & EIDs < 8000) = EIDs(EIDs >= 7000 & EIDs < 8000) - 7000;
allBarHeight(EIDs >= 8000 & EIDs < 9000) = EIDs(EIDs >= 8000 & EIDs < 9000) - 8000;
allBarColor(EIDs >= 9000 & EIDs < 10000) = EIDs(EIDs >= 9000 & EIDs < 10000) - 9000;
allXPos(EIDs >= 10000 & EIDs < 15000) = EIDs(EIDs >= 10000 & EIDs < 15000) - 10000;
allYPos(EIDs >= 20000 & EIDs < 25000) = EIDs(EIDs >= 20000 & EIDs < 25000) - 20000;

FixOnIdx = find(EIDs == 114);
FixHoldIdx = find(EIDs == 117);
FixHoldIdx = FixHoldIdx(FixHoldIdx > 1);
goodFixHoldIdx = FixHoldIdx(EIDs(FixHoldIdx - 1) == 114);
goodFixOnIdx = goodFixHoldIdx - 1;

goodFixOnset = EventTs(goodFixOnIdx);
goodFixHold = EventTs(goodFixHoldIdx);
goodFixationDura = goodFixHold - goodFixOnset;

FixDuraThreshold = 0.3;
chcFixIdx = abs(goodFixationDura - FixDuraThreshold) >= 0.01;
disp(['Trial number of fixation sessions out of range: ' num2str(sum(chcFixIdx))]);
if sum(chcFixIdx) >= 10
    warning('Fixation-duration mismatch was unusually frequent in %s.', sessionProgressText);
end

StimOnIdx = find(EIDs == StimOnID);
StimOffIdx = [];
tempArr = [];

for iStim = 1:length(StimOnIdx) - 1
    p = find(EIDs(StimOnIdx(iStim):StimOnIdx(iStim + 1)) == 130, 1, 'first');
    if isempty(p)
        tempArr(end + 1) = iStim; %#ok<AGROW>
    else
        StimOffIdx(end + 1) = StimOnIdx(iStim) + p - 1; %#ok<AGROW>
    end
end

if ~isempty(StimOnIdx)
    p = find(EIDs(StimOnIdx(end):end) == 130, 1, 'first');
    if ~isempty(p)
        StimOffIdx(end + 1) = StimOnIdx(end) + p - 1; %#ok<AGROW>
    else
        tempArr(end + 1) = length(StimOnIdx); %#ok<AGROW>
    end
end

if ~isempty(tempArr)
    StimOnIdx(tempArr) = [];
end

if ~isempty(EIDs) && EIDs(end) == 130 && ~isempty(StimOffIdx)
    StimOffIdx = StimOffIdx(1:end - 1);
end

tempIdx = find(EIDs == 140, 1, 'first');
if isempty(tempIdx)
    error('No reward event was found while analyzing %s.', sessionProgressText);
end

if tempIdx >= 3 && EIDs(tempIdx - 2) == 130
    goodStimOffIdx = StimOffIdx(EIDs(StimOffIdx + 1) == 118 | EIDs(StimOffIdx + 2) == 140);
else
    goodStimOffIdx = StimOffIdx(EIDs(StimOffIdx + 1) == 118 | ...
        EIDs(StimOffIdx + 1) == 140 | EIDs(StimOffIdx + 1) == 131);
end

temp = bsxfun(@minus, goodStimOffIdx, StimOnIdx');
temp(temp < 0) = inf;
[~, TrialIdx] = min(temp, [], 2);
goodStimOnIdx = StimOnIdx(TrialIdx);
if numel(goodStimOffIdx) < numel(goodStimOnIdx)
    goodStimOnIdx(end) = [];
end

goodStimOnset = EventTs(goodStimOnIdx);
goodStimOffset = EventTs(goodStimOffIdx);
goodStimDura = goodStimOffset - goodStimOnset;

DuraThreshold = 0.15;
rmIdx = abs(goodStimDura - DuraThreshold) >= 0.02;
goodStimOnset(rmIdx) = [];
goodStimOffset(rmIdx) = [];
goodStimDura(rmIdx) = [];
goodStimOffIdx(rmIdx) = [];
goodStimOnIdx(rmIdx) = [];
disp(['Trial number removed for duration mismatch: ' num2str(sum(rmIdx))]);

if isempty(goodStimOnset)
    error('No valid sparse-noise stimulus trials remained for %s.', sessionProgressText);
end

keepStimTrial = false(1, numel(goodStimOnset));
keptTrialCount = 0;
StimParam = struct();

for iTrial = 1:numel(goodStimOnset)
    tmpXpos = unique(allXPos(goodStimOnIdx(iTrial):goodStimOffIdx(iTrial)));
    tmpYpos = unique(allYPos(goodStimOnIdx(iTrial):goodStimOffIdx(iTrial)));
    tmpStiWidth = unique(allBarWidth(goodStimOnIdx(iTrial):goodStimOffIdx(iTrial)));
    tmpStiHeight = unique(allBarHeight(goodStimOnIdx(iTrial):goodStimOffIdx(iTrial)));
    tmpStiColor = unique(allBarColor(goodStimOnIdx(iTrial):goodStimOffIdx(iTrial)));

    tmpXpos(isnan(tmpXpos)) = [];
    tmpYpos(isnan(tmpYpos)) = [];
    tmpStiWidth(isnan(tmpStiWidth)) = [];
    tmpStiHeight(isnan(tmpStiHeight)) = [];
    tmpStiColor(isnan(tmpStiColor)) = [];

    if numel(tmpXpos) ~= 1 || numel(tmpYpos) ~= 1 || numel(tmpStiWidth) ~= 1 || ...
            numel(tmpStiHeight) ~= 1 || numel(tmpStiColor) ~= 1
        warning('Skipping malformed stimulus trial in %s.', sessionProgressText);
        continue
    end

    keptTrialCount = keptTrialCount + 1;
    keepStimTrial(iTrial) = true;

    StimParam.OnsetIdx(keptTrialCount, :) = goodStimOnIdx(iTrial); %#ok<AGROW>
    StimParam.OffsetIdx(keptTrialCount, :) = goodStimOffIdx(iTrial); %#ok<AGROW>
    StimParam.Onset(keptTrialCount, :) = goodStimOnset(iTrial); %#ok<AGROW>
    StimParam.Offset(keptTrialCount, :) = goodStimOffset(iTrial); %#ok<AGROW>
    StimParam.Duration(keptTrialCount, :) = goodStimDura(iTrial); %#ok<AGROW>
    StimParam.StiXPos(keptTrialCount, :) = tmpXpos; %#ok<AGROW>
    StimParam.StiYPos(keptTrialCount, :) = tmpYpos; %#ok<AGROW>
    StimParam.StiWidth(keptTrialCount, :) = tmpStiWidth; %#ok<AGROW>
    StimParam.StiHeight(keptTrialCount, :) = tmpStiHeight; %#ok<AGROW>
    StimParam.StiColor(keptTrialCount, :) = tmpStiColor; %#ok<AGROW>
end

if any(~keepStimTrial)
    disp(['Skipped ' num2str(sum(~keepStimTrial)) ' malformed stimulus trial(s) in ' sessionProgressText]);
end

if keptTrialCount == 0
    error('All stimulus trials were malformed for %s.', sessionProgressText);
end

sessionDecode = struct();
sessionDecode.goodFixOnset = goodFixOnset;
sessionDecode.goodFixHold = goodFixHold;
sessionDecode.goodFixationDura = goodFixationDura;
sessionDecode.StimParam = StimParam;
sessionDecode.PSTH_preWinT = PSTH_preWinT;
sessionDecode.PSTH_postWinT = PSTH_postWinT;
end

function channelRF = computeRFForOneChannel(SpikeTs, sessionDecode, channelProgressText)
postFixT = 0.1;
goodFixOnset = sessionDecode.goodFixOnset;
goodFixHold = sessionDecode.goodFixHold;
goodFixationDura = sessionDecode.goodFixationDura;
StimParam = sessionDecode.StimParam;
PSTH_preWinT = sessionDecode.PSTH_preWinT;
PSTH_postWinT = sessionDecode.PSTH_postWinT;

Resp = struct();
for iTrial = 1:numel(goodFixOnset)
    baselineStart = goodFixOnset(iTrial) + postFixT;
    baselineStop = goodFixHold(iTrial);
    Resp.SpikeCount_Baseline(iTrial) = numel( ...
        SpikeTs(SpikeTs >= baselineStart & SpikeTs <= baselineStop)); %#ok<AGROW>
    Resp.SpikeRate_Baseline(iTrial) = Resp.SpikeCount_Baseline(iTrial) / ...
        (goodFixationDura(iTrial) - postFixT); %#ok<AGROW>
end

for iTrial = 1:numel(StimParam.Onset)
    Resp.SpikeT{iTrial} = SpikeTs( ...
        SpikeTs >= StimParam.Onset(iTrial) - PSTH_preWinT & ...
        SpikeTs <= StimParam.Offset(iTrial) + PSTH_postWinT); %#ok<AGROW>
    Resp.SpikeT_StiOnset{iTrial} = Resp.SpikeT{iTrial} - StimParam.Onset(iTrial); %#ok<AGROW>
    Resp.SpikeCount_StiDura(iTrial) = numel( ...
        SpikeTs(SpikeTs >= StimParam.Onset(iTrial) & SpikeTs <= StimParam.Offset(iTrial))); %#ok<AGROW>
    Resp.SpikeRate_StiDura(iTrial) = Resp.SpikeCount_StiDura(iTrial) / ...
        StimParam.Duration(iTrial); %#ok<AGROW>
end

disp(['Computing channel RF for ', channelProgressText]);
uniXPos = unique(StimParam.StiXPos);
uniYPos = unique(StimParam.StiYPos);
uniColor = unique(StimParam.StiColor);

if numel(uniColor) < 2
    warning('Only one stimulus color was found in %s; on/off maps will collapse to the same color.', ...
        channelProgressText);
end

SortResp = struct();
iOnTrial = 0;
iOffTrial = 0;
meanIdx = 1;

for iXpos = 1:numel(uniXPos)
    for iYpos = 1:numel(uniYPos)
        onColor = uniColor(1);
        offColor = uniColor(min(2, numel(uniColor)));
        tmpIdxOn = StimParam.StiXPos == uniXPos(iXpos) & ...
            StimParam.StiYPos == uniYPos(iYpos) & ...
            StimParam.StiColor == onColor;
        tmpIdxOff = StimParam.StiXPos == uniXPos(iXpos) & ...
            StimParam.StiYPos == uniYPos(iYpos) & ...
            StimParam.StiColor == offColor;
        tmpIdxMean = StimParam.StiXPos == uniXPos(iXpos) & ...
            StimParam.StiYPos == uniYPos(iYpos);

        SortResp.meanXYpos(meanIdx, :) = [uniXPos(iXpos), uniYPos(iYpos)]; %#ok<AGROW>
        SortResp.OnStiXPos(iOnTrial + 1:iOnTrial + sum(tmpIdxOn)) = repmat(uniXPos(iXpos), sum(tmpIdxOn), 1); %#ok<AGROW>
        SortResp.OnStiYPos(iOnTrial + 1:iOnTrial + sum(tmpIdxOn)) = repmat(uniYPos(iYpos), sum(tmpIdxOn), 1); %#ok<AGROW>
        SortResp.OnSpikeT_StiOnset(iOnTrial + 1:iOnTrial + sum(tmpIdxOn)) = Resp.SpikeT_StiOnset(tmpIdxOn); %#ok<AGROW>
        SortResp.SortIndex_On(iOnTrial + 1:iOnTrial + sum(tmpIdxOn)) = repmat(meanIdx, sum(tmpIdxOn), 1); %#ok<AGROW>
        SortResp.OnSpikeRate_StiDura(iOnTrial + 1:iOnTrial + sum(tmpIdxOn)) = Resp.SpikeRate_StiDura(tmpIdxOn); %#ok<AGROW>
        SortResp.meanOnSpikeRate_StiDura(meanIdx) = mean(Resp.SpikeRate_StiDura(tmpIdxOn)); %#ok<AGROW>

        SortResp.OffStiXPos(iOffTrial + 1:iOffTrial + sum(tmpIdxOff)) = repmat(uniXPos(iXpos), sum(tmpIdxOff), 1); %#ok<AGROW>
        SortResp.OffStiYPos(iOffTrial + 1:iOffTrial + sum(tmpIdxOff)) = repmat(uniYPos(iYpos), sum(tmpIdxOff), 1); %#ok<AGROW>
        SortResp.OffSpikeT_StiOnset(iOffTrial + 1:iOffTrial + sum(tmpIdxOff)) = Resp.SpikeT_StiOnset(tmpIdxOff); %#ok<AGROW>
        SortResp.SortIndex_Off(iOffTrial + 1:iOffTrial + sum(tmpIdxOff)) = repmat(meanIdx, sum(tmpIdxOff), 1); %#ok<AGROW>
        SortResp.OffSpikeRate_StiDura(iOffTrial + 1:iOffTrial + sum(tmpIdxOff)) = Resp.SpikeRate_StiDura(tmpIdxOff); %#ok<AGROW>
        SortResp.meanOffSpikeRate_StiDura(meanIdx) = mean(Resp.SpikeRate_StiDura(tmpIdxOff)); %#ok<AGROW>

        SortResp.meanAllSpikeRate_StiDura(meanIdx) = mean(Resp.SpikeRate_StiDura(tmpIdxMean)); %#ok<AGROW>
        SortResp.AllSpikeRate_StiDura{meanIdx} = Resp.SpikeRate_StiDura(tmpIdxMean); %#ok<AGROW>

        meanIdx = meanIdx + 1;
        iOnTrial = size(SortResp.OnStiXPos, 1);
        iOffTrial = size(SortResp.OffStiXPos, 1);
    end
end

channelRF = struct();
channelRF.rawRFmap = reshape( ...
    SortResp.meanAllSpikeRate_StiDura(:), numel(uniYPos), numel(uniXPos));
channelRF.uniXPos = uniXPos;
channelRF.uniYPos = uniYPos;
channelRF.meanXYpos = SortResp.meanXYpos;
channelRF.FRbyTrial = SortResp.AllSpikeRate_StiDura;
channelRF.Baseline = Resp.SpikeRate_Baseline;
end

function [SpikeTsByChannel, waveformFields] = extractMUAChannelSpikeTimes(S, channelNums, fileName)
SpikeTsByChannel = cell(numel(channelNums), 1);
waveformFields = cell(numel(channelNums), 1);

for iChannel = 1:numel(channelNums)
    [SpikeTsByChannel{iChannel}, waveformFields{iChannel}] = ...
        extractOneChannelSpikeTimes(S, channelNums(iChannel), fileName);
end
end

function [SpikeTs, fieldNameUsed] = extractOneChannelSpikeTimes(S, channelNum, fileName)
fieldCandidates = { ...
    sprintf('raw_%05d', channelNum), ...
    sprintf('Raw%d', channelNum), ...
    sprintf('raw%d', channelNum)};

matrix = [];
fieldNameUsed = sprintf('raw_%05d', channelNum);
for iField = 1:numel(fieldCandidates)
    if isfield(S, fieldCandidates{iField})
        matrix = S.(fieldCandidates{iField});
        fieldNameUsed = fieldCandidates{iField};
        break
    end
end

if isempty(matrix)
    orderedFields = sortWaveformFields(fieldnames(S));
    if channelNum <= numel(orderedFields)
        fieldNameUsed = orderedFields{channelNum};
        matrix = S.(fieldNameUsed);
    else
        warning('Waveform channel %02d was missing from %s. Returning an empty spike train.', ...
            channelNum, fileName);
        SpikeTs = [];
        return
    end
end

if isempty(matrix)
    SpikeTs = [];
    return
end

if ~isnumeric(matrix) || size(matrix, 2) < 3
    error('Waveform field for channel %02d in %s did not contain the expected timestamp matrix.', ...
        channelNum, fileName);
end

SpikeTs = matrix(:, 3);
SpikeTs = SpikeTs(isfinite(SpikeTs));
SpikeTs = sort(SpikeTs(:));
end

function orderedFields = sortWaveformFields(fieldNames)
pattern = '^raw_(\d+)$';
fieldNumbers = nan(numel(fieldNames), 1);

for iField = 1:numel(fieldNames)
    tok = regexp(lower(fieldNames{iField}), pattern, 'tokens', 'once');
    if ~isempty(tok)
        fieldNumbers(iField) = str2double(tok{1});
    end
end

keep = isfinite(fieldNumbers);
fieldNames = fieldNames(keep);
fieldNumbers = fieldNumbers(keep);
[~, order] = sort(fieldNumbers);
orderedFields = fieldNames(order);
end

function Event = decodeNevEvents(hFile, sessionProgressText)
Event.timestamps = [];
Event.EventID = [];

eventReasons = {hFile.Entity.Reason};
parallelMask = cellfun(@strcmpi, eventReasons, repmat({'Parallel Input'}, size(eventReasons)));
EventCh = find(parallelMask);

if isempty(EventCh)
    error('No Parallel Input event channel was found for %s.', sessionProgressText);
end

EventCh = EventCh(1);
[ns_RESULT, entityInfo] = ns_GetEntityInfo(hFile, EventCh);
if ~isequal(ns_RESULT, 'ns_OK')
    error('ns_GetEntityInfo failed for %s.', sessionProgressText);
end

for iEvent = 1:entityInfo.ItemCount
    [~, timeStamps, rawdata, ~] = ns_GetEventData(hFile, EventCh, iEvent);
    Event.EventID(end + 1) = rawdata; %#ok<AGROW>
    Event.timestamps(end + 1) = timeStamps; %#ok<AGROW>
end

disp(['Decoded ', num2str(entityInfo.ItemCount), ' event records for ', sessionProgressText]);
end

function safeCloseNeuroshareFile(hFile)
if isempty(hFile)
    return
end

if exist('ns_CloseFile', 'file') ~= 2
    return
end

try
    ns_CloseFile(hFile);
catch
end
end

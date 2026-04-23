function [rawRFmap, uniXPos, uniYPos, meanXYpos, RFmapTable_allSti, SpikeRate_Baseline] = RFMappingFunction_Lo(unit_table, i_tt, i_unit, unitProgressText, targetUnitID)
%% Settings
% ElectrodeNums = [1:16];
if nargin < 4 || isempty(unitProgressText)
    unitProgressText = sprintf('TT row %d, unit file %d', i_tt, i_unit);
end
disp(['Analyzing receptive field: ', unitProgressText]);
windowWidth = 1920; %(pixels)
windowHeight = 1080; %(pixels)
viewingDistance = 570; %(mm)
ScreenWidth = 635; %(mm)
ScreenHeight = 358; %(mm)
mm2deg = @(x) atand(x./viewingDistance);
pix2mm = @(x) x.*ScreenWidth./windowWidth;
mm2pix = @(x) x.*windowWidth./ScreenWidth;
pix2deg = @(x) mm2deg(pix2mm(x));
WindowCenter = [windowWidth/2, windowHeight/2];
StimOnID = 118; %Event ID: Stimulus onset
PSTH_preWinT = 0.05; PSTH_postWinT = 0.05; %seconds

%%
pathname = unit_table.Paths{i_tt};
file_names = unit_table.Names{i_tt}{i_unit};
nev_names = unit_table.NevNames(i_tt, :);
% nev_names = 'P:\Jim\NeuroData\20190918\Raw Ripple\SparseNoise0001.nev';
if length(nev_names) > 1
    error("More than one nev file!")
end
RawSpikes = load(string(fullfile(pathname,file_names)));
RawSpikes = RawSpikes.Raw1;

%%
unitIDs = unique(RawSpikes(:, 2));
unitIDs(unitIDs == 0) = [];

if nargin < 5 || isempty(targetUnitID)
    if numel(unitIDs) == 1
        targetUnitID = unitIDs(1);
    else
        error(['Multiple sorted units were found in %s. Pass targetUnitID ', ...
            'explicitly. Available units: %s'], file_names, mat2str(unitIDs'));
    end
end

if ~ismember(targetUnitID, unitIDs)
    error('Target internal unit %d was not found in %s. Available units: %s', ...
        targetUnitID, file_names, mat2str(unitIDs'));
end

SpikeTsForFile = RawSpikes(RawSpikes(:, 2) == targetUnitID, 3);

%%
[ns_status, hFile] = ns_OpenFile([pathname 'Raw Ripple\' nev_names{1}]);
% [ns_status, hFile] = ns_OpenFile(nev_names);

if isequal(ns_status,'ns_OK')
    SpikeChNum = 0; LFPNum = 0; RawNum = 0;
    SpikeCh = []; LFPCh = []; RawCh = []; AICh = []; EventCh=[];
    Event = [];
    Event.timestamps = []; Event.EventID = [];

    EventCh = find(cellfun(@strcmpi, {hFile.Entity.Reason},...
        repmat({'Parallel Input'}, size({hFile.Entity.Reason}))));  %% TCP packet from Matlab
    DICh = find(cellfun(@strcmpi, {hFile.Entity.Reason},...
        repmat({'SMA 1'}, size({hFile.Entity.Reason}))));   %% digital input 1

    % Extract channel info
    if ~isempty(EventCh)
        [ns_RESULT, entityInfo] = ns_GetEntityInfo(hFile, EventCh);
        if isequal(ns_RESULT,'ns_OK')

            numCount = entityInfo.ItemCount;
            NumT=1;
            for i = 1:numCount
                [~, timeStamps, rawdata, ~] = ns_GetEventData(hFile, EventCh, i);
                Event.EventID(end+1) = rawdata;
                Event.timestamps(end+1) = timeStamps;
            end
            disp(['Decoded ', num2str(numCount), ' event records for ', unitProgressText]);
        end
    end
end
EventTs = Event.timestamps;
EIDs = Event.EventID;

StimOnT = EventTs(EIDs == StimOnID); %Timestampe of stimulus onset
allXPos = nan(1, numel(EIDs));
allYPos  = nan(1, numel(EIDs));
allBarWidth = nan(1, numel(EIDs));
allBarHeight = nan(1, numel(EIDs));
allBarColor = nan(1, numel(EIDs));

%% Read stimulus parameter using event ID
%bar or spares noise,
%ID:203, bBarWidth(pixel):7000, BarHeight(pixel):8000, BarColor(0-255):9000
%xPos: 10000, yPos: 20000, Rect(3):1000, Rect(4):2000
alltimestamps = EventTs;
allBarWidth(EIDs >= 7000 & EIDs < 8000) = EIDs(EIDs >= 7000 & EIDs < 8000) - 7000; %stimulus width in pixels
allBarHeight(EIDs >= 8000 & EIDs < 9000) = EIDs(EIDs >= 8000 & EIDs < 9000) - 8000; %stimulus height in pixels
allBarColor(EIDs >= 9000 & EIDs < 10000) = EIDs(EIDs >= 9000 & EIDs < 10000) - 9000; %stimulus color in grayscale (0~255)
allXPos(EIDs >= 10000 & EIDs < 15000) = EIDs(EIDs >= 10000 & EIDs < 15000) - 10000; %stimulus position in pixels (horizental axis)
allYPos(EIDs >= 20000 & EIDs < 25000) = EIDs(EIDs >= 20000 & EIDs < 25000) - 20000; %stimulus position in pixels (vertical axis)

%% Find good fixation on and hold EIDs and time stamps.
% 117: hold fixation, 114: fixation acquired, 140: rewarded, 130: stimulus off, 118: stimulus on
FixOnIdx = find(EIDs == 114); %Event ID: Fixation onset
FixHoldIdx = find(EIDs == 117); %Event ID: maintain fixation successfully (should be also stimulus onset)
goodFixHoldIdx = FixHoldIdx(EIDs(FixHoldIdx-1) == 114);
goodFixOnIdx = goodFixHoldIdx-1;

goodFixOnset = EventTs(goodFixOnIdx); %Timestampe of fixation onset
goodFixHold = EventTs(goodFixHoldIdx); %Timestampe of fixation held
goodFixationDura = goodFixHold-goodFixOnset; %duration of fixation alone withoud stimulus presentation

% Fixation holding duration, which is defined in GUI and should be 0.3 s for our sparse noise protocol
% the if condition is check if there is any trail with missing/dropped frames
FixDuraThreshold = 0.3;
chcFixIdx = abs(goodFixationDura - FixDuraThreshold) >= 0.01;
disp([ 'Trial number of fixation session which are out of range: ' num2str(sum(chcFixIdx)) ]);
if chcFixIdx >= 10
    warning('Check the data and the protocol when the trails number is abnormally huge!!!!');
end
meanFixDura = round(mean(goodFixationDura(~chcFixIdx)),2);%calculate average duration for plotting

%% Find good trials.
StimOnIdx = find(EIDs == StimOnID);
RewardIdx = find(EIDs == 140);
tempArr = [];
StimOffIdx = [];

for i=1:length(StimOnIdx)-1
    p = find(EIDs(StimOnIdx(i):StimOnIdx(i+1))==130);
    if isempty(p)
        tempArr = [tempArr i];
    else
        StimOffIdx = [StimOffIdx StimOnIdx(i)+p(1)-1];
    end
end
p = find(EIDs(StimOnIdx(end):end)==130);
if ~isempty(p)
    StimOffIdx = [StimOffIdx StimOnIdx(end)+p(1)-1];
else
    tempArr = [tempArr length(StimOnIdx)];
end

if ~isempty(tempArr)
    StimOnIdx(tempArr) = [];
end

if EIDs(end) == 130
    StimOffIdx = StimOffIdx(1:end - 1);
end

%test event ID using the 1st reward event
tempIdx = find(EIDs == 140, 1, 'first');
if EIDs(tempIdx - 2) == 130 %this difference is because the exp. code changed/updated
    goodStimOffIdx = StimOffIdx(EIDs(StimOffIdx+1) == 118 | EIDs(StimOffIdx+2) == 140);
else
    goodStimOffIdx = StimOffIdx(EIDs(StimOffIdx+1) == 118 | EIDs(StimOffIdx+1) == 140 | EIDs(StimOffIdx+1) == 131);
end

temp = bsxfun(@(x,y) x-y, goodStimOffIdx, StimOnIdx');
temp(temp < 0) = inf;
[~, TrialIdx] = min(temp,[],2);
goodStimOnIdx = StimOnIdx(TrialIdx);
if numel(goodStimOffIdx) < numel(goodStimOnIdx)
    goodStimOnIdx(end) = [];
end
goodStimOnset = EventTs(goodStimOnIdx);
goodStimOffset = EventTs(goodStimOffIdx);

goodStimDura = goodStimOffset-goodStimOnset;

%stimulus duration, which is  is defined on GUI, and should be 0.15 s for our sparse noise protocol
%this if condition is to get rid of the trails whith missing/dropped frames
%Specifically, if the duration is more or less 0.02 s than 0.15 s, the trial is excluded
DuraThreshold = 0.15; %0.15 seconds is presented duration of each square stimulus
rmIdx = abs(goodStimDura - DuraThreshold) >= 0.02; % 0.02 criterion is 2~3 frames for 120 Hz or 1~2 frames for 60 Hz
goodStimOnset(rmIdx) = []; goodStimOffset(rmIdx) = []; goodStimDura(rmIdx) = [];
goodStimOffIdx(rmIdx) = []; goodStimOnIdx(rmIdx) = [];
disp([ 'Trial number of getting removed: ' num2str(sum(rmIdx)) ]);

% ideal mean duration should be 0.15s, but I calculate real average duration for plotting
meanDura = round(mean(goodStimDura),2);


%% Trial Decoding
% f = figure; hold on;
% sub_plt = @(m,n,p) subtightplot (m, n, p, [0.001 0.01], [0.25 0.25], [0.05 0.01]);
% % sub_plt = @(m,n,p) subplot (m, n, p);
% dcm_obj = datacursormode(f); % Have a built-in interaction after 2018.
% set(dcm_obj,'UpdateFcn',{@rappidofflineupdate,f})

for unitLoop = 1

    SpikeTs = SpikeTsForFile;
    disp(['Computing firing rates for ', unitProgressText])
    colorIndex = [0 0.5 0.5; 0 1 0; 0 0 0.7; 0 0.7 0; 0 1 1];
    % while 1
    %% Baseline Raster Plot
    postFixT = 0.1;
    iTrial = 1;
    while 1
        FixationParam.FixationOn(iTrial, :) = goodFixOnset(iTrial);
        FixationParam.FixationHold(iTrial, :) = goodFixHold(iTrial);
        FixationParam.BaselineTimeWindow(iTrial, :) = goodFixationDura(iTrial);

        %Response Array
        Resp.SpikeCount_Baseline(iTrial) = numel(SpikeTs(SpikeTs >= FixationParam.FixationOn(iTrial)+postFixT & SpikeTs <= FixationParam.FixationHold(iTrial)));
        Resp.SpikeRate_Baseline(iTrial) = Resp.SpikeCount_Baseline(iTrial)/(FixationParam.BaselineTimeWindow(iTrial)-postFixT);
        iTrial = iTrial+1;

        if iTrial > numel(goodFixOnset)
            break
        end
    end
    %%
    for iTrial = 1:numel(goodStimOnset)
        tmpXpos = unique(allXPos(goodStimOnIdx(iTrial):goodStimOffIdx(iTrial))); tmpXpos(isnan(tmpXpos)) = [];
        tmpYpos = unique(allYPos(goodStimOnIdx(iTrial):goodStimOffIdx(iTrial))); tmpYpos(isnan(tmpYpos)) = [];
        tmpStiWidth = unique(allBarWidth(goodStimOnIdx(iTrial):goodStimOffIdx(iTrial))); tmpStiWidth(isnan(tmpStiWidth)) = [];
        tmpStiHeight = unique(allBarHeight(goodStimOnIdx(iTrial):goodStimOffIdx(iTrial))); tmpStiHeight(isnan(tmpStiHeight)) = [];
        tmpStiColor = unique(allBarColor(goodStimOnIdx(iTrial):goodStimOffIdx(iTrial))); tmpStiColor(isnan(tmpStiColor)) = [];

        if numel(tmpXpos) ~= 1 || numel(tmpYpos) ~= 1 || numel(tmpStiWidth) ~= 1 || numel(tmpStiHeight) ~= 1 || numel(tmpStiColor) ~= 1
            warning([ 'Check onset index:' num2str(goodStimOnIdx(iTrial)) '; offset index: ' num2str(goodStimOffIdx(iTrial))]);
            warning('Check the experiment code, now we just delete this index!!');
            goodStimOnset(iTrial) = []; goodStimOffset(iTrial) = []; goodStimDura(iTrial) = [];
            goodStimOffIdx(iTrial) = []; goodStimOnIdx(iTrial) = [];
        else
            %Stimulus Parameters
            StimParam.OnsetIdx(iTrial, :) = goodStimOnIdx(iTrial);
            StimParam.OffsetIdx(iTrial, :) = goodStimOffIdx(iTrial);
            StimParam.Onset(iTrial, :) = goodStimOnset(iTrial);
            StimParam.Offset(iTrial, :) = goodStimOffset(iTrial);
            StimParam.Duration(iTrial, :) = goodStimDura(iTrial);
            StimParam.StiXPos(iTrial, :) = tmpXpos;
            StimParam.StiYPos(iTrial, :) = tmpYpos;
            StimParam.StiWidth(iTrial, :) = tmpStiWidth;
            StimParam.StiHeight(iTrial, :) = tmpStiHeight;
            StimParam.StiColor(iTrial, :) = tmpStiColor;

            %Response Array
            Resp.SpikeT{iTrial} = SpikeTs(SpikeTs >= StimParam.Onset(iTrial)-PSTH_preWinT & SpikeTs <= StimParam.Offset(iTrial)+PSTH_postWinT);
            Resp.SpikeT_StiOnset{iTrial} = SpikeTs(SpikeTs >= StimParam.Onset(iTrial)-PSTH_preWinT & SpikeTs <= StimParam.Offset(iTrial)+PSTH_postWinT)-StimParam.Onset(iTrial);
            Resp.SpikeCount_StiDura(iTrial) = numel(SpikeTs(SpikeTs >= StimParam.Onset(iTrial) & SpikeTs <= StimParam.Offset(iTrial)));
            Resp.SpikeRate_StiDura(iTrial) = Resp.SpikeCount_StiDura(iTrial)/StimParam.Duration(iTrial);
            %             plot(Resp.SpikeT_StiOnset{iTrial}, iTrial*ones(numel(Resp.SpikeT_StiOnset{iTrial}),1), '.', 'color', colorIndex(1,:)); hold on;
        end
    end

    %% Sorted by Stimulus Locations
    disp(['Sorting responses by stimulus location for ', unitProgressText]);
    uniXPos = unique(StimParam.StiXPos);
    uniYPos = unique(StimParam.StiYPos);
    uniColor = unique(StimParam.StiColor);

    colorIndex = [0.2 0.2 0.2; 0 0.5 0.5; 0 1 0; 0 0 0.7; 0 0.7 0; 0 1 1];
    iOnTrial = 0; iOffTrial = 0; meanIdx = 1;
    for iXpos = 1:numel(uniXPos)
        for iYpos = 1:numel(uniYPos)
            iColor = 1; % White
            tmpIdxOn = (StimParam.StiXPos == uniXPos(iXpos) & StimParam.StiYPos == uniYPos(iYpos) & StimParam.StiColor == uniColor(iColor));
            iColor = 2; % Black
            tmpIdxOff = (StimParam.StiXPos == uniXPos(iXpos) & StimParam.StiYPos == uniYPos(iYpos) & StimParam.StiColor == uniColor(iColor));
            tmpIdxMean = (StimParam.StiXPos == uniXPos(iXpos) & StimParam.StiYPos == uniYPos(iYpos));
            %Stimulu Locations
            SortResp.meanXYpos(meanIdx, :) = [uniXPos(iXpos), uniYPos(iYpos)];
            %On
            SortResp.OnStiXPos(iOnTrial+1:iOnTrial+sum(tmpIdxOn)) = repmat(uniXPos(iXpos), sum(tmpIdxOn), 1);
            SortResp.OnStiYPos(iOnTrial+1:iOnTrial+sum(tmpIdxOn)) = repmat(uniYPos(iYpos), sum(tmpIdxOn), 1);
            SortResp.OnSpikeT_StiOnset(iOnTrial+1:iOnTrial+sum(tmpIdxOn)) = Resp.SpikeT_StiOnset(tmpIdxOn);
            SortResp.SortIndex_On(iOnTrial+1:iOnTrial+sum(tmpIdxOn)) = repmat(meanIdx, sum(tmpIdxOn), 1);
            SortResp.OnSpikeRate_StiDura(iOnTrial+1:iOnTrial+sum(tmpIdxOn)) = Resp.SpikeRate_StiDura(tmpIdxOn);
            SortResp.meanOnSpikeRate_StiDura(meanIdx) = mean(Resp.SpikeRate_StiDura(tmpIdxOn));
            %Off
            SortResp.OffStiXPos(iOffTrial+1:iOffTrial+sum(tmpIdxOff)) = repmat(uniXPos(iXpos), sum(tmpIdxOff), 1);
            SortResp.OffStiYPos(iOffTrial+1:iOffTrial+sum(tmpIdxOff)) = repmat(uniYPos(iYpos), sum(tmpIdxOff), 1);
            SortResp.OffSpikeT_StiOnset(iOffTrial+1:iOffTrial+sum(tmpIdxOff)) = Resp.SpikeT_StiOnset(tmpIdxOff);
            SortResp.SortIndex_Off(iOffTrial+1:iOffTrial+sum(tmpIdxOff)) = repmat(meanIdx, sum(tmpIdxOff), 1);
            SortResp.OffSpikeRate_StiDura(iOffTrial+1:iOffTrial+sum(tmpIdxOff)) = Resp.SpikeRate_StiDura(tmpIdxOff);
            SortResp.meanOffSpikeRate_StiDura(meanIdx) = mean(Resp.SpikeRate_StiDura(tmpIdxOff));
            %Mean regardless of white or black stimulus
            SortResp.meanAllSpikeRate_StiDura(meanIdx) = mean(Resp.SpikeRate_StiDura(tmpIdxMean));
            SortResp.AllSpikeRate_StiDura{meanIdx} = Resp.SpikeRate_StiDura(tmpIdxMean);

            meanIdx = meanIdx+1;
            iOnTrial = size(SortResp.OnStiXPos,1);
            iOffTrial = size(SortResp.OffStiXPos,1);

            if iXpos == numel(uniXPos) && iYpos == numel(uniYPos)
                MaxYval = max([iOnTrial iOffTrial]);
            end
        end
    end

    %% RF map
    PlotingType = 'mean';
    % RFfig = zeros(numel(UnitIdx),4);
    RFmapTable_allSti = reshape(SortResp.meanAllSpikeRate_StiDura(:),  numel(uniYPos), numel(uniXPos));
    RFmapTable_OnSti = reshape(SortResp.meanOnSpikeRate_StiDura(:),  numel(uniYPos), numel(uniXPos));
    RFmapTable_OffSti = reshape(SortResp.meanOffSpikeRate_StiDura(:),  numel(uniYPos), numel(uniXPos));
    RFmapTable_combineOnOff = RFmapTable_OnSti + RFmapTable_OffSti;

    switch PlotingType
        case 'mean'
            %         RFmapTable_allSti_Thresh = reshape(SortResp.meanAllSpikeRate_Thres(:),  numel(uniYPos), numel(uniXPos));
            rawRFmap = RFmapTable_allSti;
        case 'merge'
            %         RFmapTable_allSti_Thresh = reshape(SortResp.mergeAllSpikeRate_Thres(:),  numel(uniYPos), numel(uniXPos));
            rawRFmap = RFmapTable_combineOnOff;
        otherwise
            error('There is not this option!!!')
    end

    RFmapTable_allSti = SortResp.AllSpikeRate_StiDura;
    meanXYpos = SortResp.meanXYpos;

    %%
    RFData.Date = unit_table.Date(i_tt);
    RFData.TT = i_tt;
    RFData.i_unit = targetUnitID;
    RFData.InternalUnitID = targetUnitID;
    RFData.rawRFmap = rawRFmap;
    RFData.uniXPos = uniXPos;
    RFData.uniYPos = uniYPos;
    RFData.meanXYpos = meanXYpos;
    RFData.FRbyTrial = RFmapTable_allSti;
    SpikeRate_Baseline = Resp.SpikeRate_Baseline;
    RFData.Baseline = SpikeRate_Baseline;

    PathStr = strsplit(unit_table.Paths{i_tt}, '\\');
    Monkey = PathStr{2};
    if ~(strcmp(Monkey, 'Jim') | strcmp(Monkey, 'Clay'))
        error('The monkey is not Jim or Clay')
    end

    fn = file_names;

    tok = regexp(fn, 'tt(\d+).*sorted-(\d+)', 'tokens', 'once');

    ttNum     = tok{1};   % 2
    sortedNum = tok{2};   % 2  （'02' -> 2）

    savePath = ['P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\LoRFs\RFData\', Monkey];
    saveFilename = ['RF_', datestr(unit_table.Date(i_tt), 'yyyymmdd'), ...
        'TT', ttNum, 'Sort', sortedNum, 'Unit', num2str(targetUnitID), '.mat'];
    save(fullfile(savePath, saveFilename), "RFData");
end
end

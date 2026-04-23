% [fName, PathName] = uigetfile({ '*.nev' ; '*.*' }, 'Select .nev File');
load('RFTinfo_0422.mat');

%%
OnlineSpk = 1;
ElectrodeNums = [1:16];

ChannelMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]; % Edge Design
% [ns_status, hFile] = ns_OpenFile([PathName fName]);
% 
% if isequal(ns_status,'ns_OK')
%     SpikeChNum = 0; LFPNum = 0; RawNum = 0;
%     SpikeCh = []; LFPCh = []; RawCh = []; AICh = []; EventCh=[]; 
%     Event = [];
%     Event.timestamps = []; Event.EventID = [];
%     
%     EventCh = find(cellfun(@strcmpi, {hFile.Entity.Reason},...
%         repmat({'Parallel Input'}, size({hFile.Entity.Reason}))));  %% TCP packet from Matlab
%     DICh = find(cellfun(@strcmpi, {hFile.Entity.Reason},...
%         repmat({'SMA 1'}, size({hFile.Entity.Reason}))));   %% digital input 1
%      
%     % Extract channel info
%     if ~isempty(EventCh)
%         [ns_RESULT, entityInfo] = ns_GetEntityInfo(hFile, EventCh);
%         if isequal(ns_RESULT,'ns_OK')
%             
%             numCount = entityInfo.ItemCount;
%             NumT=1;
%             for i = 1:numCount
%                 disp(['decoding Trial structure: ' num2str(i) '/' num2str(numCount) ' done']);
%                 [~, timeStamps, rawdata, ~] = ns_GetEventData(hFile, EventCh, i);
%                 Event.EventID(end+1) = rawdata;
%                 Event.timestamps(end+1) = timeStamps;
%             end
%         end
%     end
% end
% EventTs = Event.timestamps;
% EIDs = Event.EventID;
% 
%% Load your spike data here after converting to plexon and running your batch processing script (filters, detects spikes, sorts)
disp('Loading waveform file...');
[fName, PathName] = uigetfile({ '*.mat' ; '*.*' }, 'Select waveform file','Multiselect','on');

disp('Converting spike data to cell array...');
for e = ElectrodeNums
    RawSpikes = struct2cell(load([PathName fName]));
    Spike(e).SpikeT(:)= RawSpikes{e}(:,3);
end



%% Settings
disp('Analyzing Receptive Fields...');
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
f = figure; hold on;
sub_plt = @(m,n,p) subtightplot (m, n, p, [0.001 0.01], [0.25 0.25], [0.05 0.01]);
% sub_plt = @(m,n,p) subplot (m, n, p);
dcm_obj = datacursormode(f); % Have a built-in interaction after 2018. 
set(dcm_obj,'UpdateFcn',{@rappidofflineupdate,f}) 
% for u = ElectrodeNums
for u = 7

    SpikeTs = Spike(u).SpikeT;
    disp('Decoding stimulus information from each valid trial...')
    colorIndex = [0 0.5 0.5; 0 1 0; 0 0 0.7; 0 0.7 0; 0 1 1];
    % while 1
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
    disp('Sorting by stimulus location...');
    Label_FontSize = 16; Title_FontSize = 18; Tick_FontSize = 14;
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
            
            meanIdx = meanIdx+1;
            iOnTrial = size(SortResp.OnStiXPos,1);
            iOffTrial = size(SortResp.OffStiXPos,1);
            
            if iXpos == numel(uniXPos) && iYpos == numel(uniYPos)
                MaxYval = max([iOnTrial iOffTrial]);
            end
        end
    end

    %% RF map in degree
    PlotingType = 'merge';
    Label_FontSize = 8; Text_FontSize = 8; Title_FontSize = 10; Tick_FontSize = 6;
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
    
    xVal = reshape(SortResp.meanXYpos(:,1), numel(uniYPos), numel(uniXPos));
    yVal = reshape(SortResp.meanXYpos(:,2), numel(uniYPos), numel(uniXPos));
    xVal_deg = round(atand(pix2mm(xVal-WindowCenter(1))/viewingDistance),2); %round(pix2deg(xVal-WindowCenter(1)), 2);
    yVal_deg = round(atand(pix2mm(WindowCenter(2)-yVal)/viewingDistance),2); %round(pix2deg(WindowCenter(2)-yVal), 2);
    
    XTick4map = round(linspace(min(xVal(1,:)), max(xVal(1,:)), 10), 1);
    YTick4map = round(linspace(min(yVal(:,1)), max(yVal(:,1)), 10), 1);
    XTick4map_deg = round(pix2deg(XTick4map-WindowCenter(1)), 1);
    YTick4map_deg = round(pix2deg(WindowCenter(2)-YTick4map), 1);
    
    %% Fit a 2D Gauss
    try
        [cx,cy,sx,sy,PeakOD,DC] = Gaussian2D(rawRFmap,1*10^-3);
        %         [cx,cy,sx,sy,PeakOD,DC,theta] = Gaussian2D_wRot(rawRFmap,1*10^-10);
    catch
        warning('Unable to fit 2D Gaussian');
        cx = NaN;
        cy = NaN;
        sx = NaN;
        sy = NaN;
        PeakOD = NaN;
        DC = NaN;
        theta = NaN;
    end
%     [mass_x,mass_y] = centerofmass(rawRFmap);
    [sizey sizex] = size(rawRFmap);
    [x,y] = meshgrid(1:sizex,1:sizey);
    %     fit = (DC + PeakOD.*(exp(-((((cosd(theta).^2)./(2*sx.^2)) + ((sind(theta).^2)./(2*sy.^2))).*(x-cx).^2 + 2*(((-sind(2*theta))./(4*sx.^2)) +...
    %     ((sind(2*theta))./(4*sy.^2))).*(x-cx).*(y-cy) +...
    %     (((sind(theta).^2)./(2*sx.^2)) + ((cosd(theta).^2)./(2*sy.^2))).*(y-cy).^2))));
    
    fit = DC + abs(PeakOD)*(exp(-0.5*(x-cx).^2./(sx^2)-0.5*(y-cy).^2./(sy^2)));
    within = (x-cx).^2/(1.1.*sx)^2 + (y-cy).^2/(1.1.*sy)^2 <= 1; % Area within sds

    %% Final RF contour plot over the raw responses
%     if ch_ind == 1
%         t(tet_num) = subplot(2,2,ch_ind); hold on;
%         set(dcm_obj(tet_num),'UpdateFcn',{@rappidofflineupdate,finalrawRF(tet_num)})
%     else
%         subplot(2,2,ch_ind); hold on;
%     end
    p = find(ChannelMap == u); 
    sub_plt(2,8,p); hold on;
    
    imagesc(xVal(:), yVal(:), rawRFmap); colormap('parula');
%     center_pix = (StimParam.StiWidth(iTrial).*[mass_x mass_y]) + [(min(xVal(:)) + StimParam.StiWidth(1)/2),(min(yVal(:)) + StimParam.StiWidth(1)/2)];
%     plot(center_pix(1),  center_pix(2), '*r', 'MarkerSize', 10);
    axis on; 
%     colorbar; 
    caxis([min(rawRFmap(:)) max(rawRFmap(:))]); hold on;
    xlim([min(xVal(:)),max(xVal(:))]); ylim([min(yVal(:)),max(yVal(:))]);
    set(gca, 'XTick', XTick4map, 'YTick', YTick4map, 'FontSize', Tick_FontSize);
    set(gca, 'XTickLabel', num2cell(XTick4map_deg), 'box', 'on')
    set(gca, 'YTickLabel', num2cell(YTick4map_deg), 'TickDir', 'out', 'Layer', 'top')
    % contour(xVal,yVal,within,1,'r','LineWidth',5)
    if p>=9
        xlabel('Horizontal (\circ)', 'FontSize', Label_FontSize)
    end
    if p == 1 || p == 9
        ylabel('Vertical (\circ)', 'FontSize', Label_FontSize)
    end
    if ismember(p,[4,5,12,13])
       set(gca,'LineWidth',3); 
    end
    title(['Electrode: ' num2str(u)]);
    set(gca,'YDir','reverse');
    axis square;
%     dcm_obj(tet_num) = datacursormode(finalrawRF(tet_num));
    
    % text(TextPos4center(1), TextPos4center(2), sprintf('Center: %.1f\\circ, %.1f\\circ', RFData.RFcenter_deg),'Color','w', 'FontSize', Text_FontSize)
    % title(sprintf('Raw RF Map - Receptive Field Size: %.2f\\circ', RFData.RFsize))    

end






function [AnaData, Neuro] = Offline_RF_LinearArray_v1(varargin)
% RF estimates using the trial structure generated during the "SparseNoise" stimulus.
% This is part of the 3D motion stimulation project by
% LWT. Modified based on the Oflline_3DMotion_NoSaccade code and RappidOfflineRF code by LWT
% This function can be used in 2 ways:
% 1: without arguments, a dialog box will appear and you can select your
%       TInfo ans SInfo files created after using TrialViewer.
% 2: Arguments:
%       {PathName}, {TInfo_file_name, SInfor_file_name}
% Usually the UnitT field from TrialViewer ouput is [1xUnitxTimes]
% For MUA data it will be [ChannelsxUnitsxTimes] where Units == 1
% You will need to alter the code to work with channels with unequal unit
% sizes. Currently TrialViewer does not support this!
% Outputs:
% AnaData: Essentially an updated TInfo file with additional variables
% Neuro: Typically, a structure containing different matrices of response
% values. I imagine outputting a structure with:
% Neuro.Response: [X x Y x Channel] matrix of the responses at each location
% Neuro.XVals: the x values (probably in degrees)
% Neuro.YVals: the Y values (probabily in degrees)
% Neuro.2DGauss.S1: The first principle axis of a 2D gaussian fit (in degrees)
% Neuro.2DGauss.S2: The second principle axis of a 2D gaussian fit (in degrees)
% Neuro.2DGauss.Center: [x,y] location of the 2D gaussian mean

%% Load files
% Dialog box for no arguments
if length(varargin)<2
    warning('not enought input parameters, select files manually');
    [file_names, pathname] = uigetfile({'*_RF*.mat' }, 'Select RF TInfo and SInfo files',pwd, 'MultiSelect', 'on');
    if ischar(file_names)
        TrialInfo_file = load(fullfile(pathname,file_names));
        TrialInfo = TrialInfo_file.TrialInfo;
    elseif length(file_names) == 2
        TrialInfo_file = load(fullfile(pathname,file_names{~contains(file_names, 'SelIndex')}));
        TrialInfo = TrialInfo_file.TrialInfo;
        SelectionInfo_file = load(fullfile(pathname,file_names{contains(file_names, 'SelIndex')}));
        Config = SelectionInfo_file.Config;
        SelectionInfo = logical(SelectionInfo_file.EditSel);
        TrialInfo = TrialInfo(SelectionInfo); % Only look at selected trials
        plotFlag = 1;
    else
        error('Too many files selected, please select a TInfo file and optional SellIndex file');
    end
    % If input provided, extract the files from the directory provided
elseif length(varargin)==2 || length(varargin)>= 3
    pathname = varargin{1};
    file_names = varargin{2};
    TrialInfo_file = load(string(fullfile(pathname,file_names{~contains(file_names, 'SelIndex')})));
    TrialInfo = TrialInfo_file.TrialInfo;
    SelectionInfo_file = load(string(fullfile(pathname,file_names{contains(file_names, 'SelIndex')})));
    Config = SelectionInfo_file.Config;
    SelectionInfo = logical(SelectionInfo_file.EditSel);
    TrialInfo = TrialInfo(SelectionInfo); % Only look at selected trials
end
filename_base = extractBefore(file_names{1},'2DM');
DashIdx = strfind(filename_base, '_');
DateIdx = strfind(filename_base, '201');
if isempty(DateIdx)
    DateIdx = strfind(filename_base, '202');
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Digout control words from Matlab machine
% THESE ARE BASED ON OTHER STIMULI, NOT THE SPARSENOISE STIMULUS, MODIFY ACCORDINGLY
% 111: trial starts
% 113: fixation on
% 114: acquire fixation point
% 115: fail to acquire fixation point
% 116: break fixation point
% 117: hold fixation point
% 118: stimulus on
% 119: break fixation point while stimulus on
% 120: saccade targets on and fixation off
% 130: stimulus off and fixation still on
% 140: reward on
% 141: reward off
% 112: trial ends
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Figure Parameters
sub_plt = @(m,n,p) subtightplot (m, n, p, [0.07 0.01], [0.1 0.1], [0.05 0.01]); % 2D plots
colorsteps = [0 0 255;...
    5 150 5;...
    0 0 0]./255;
ChannelMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]; % Edge Design

%% Settings
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

%% Initial Eye Checking
% NOTE THE FUNCTION USED BELOW WAS MADE FOR THE 3D MOTION STIMULUS AND USES
% DIFFERENT EVENT CODES
% Ensure that the monkey did not break fixation while the stimulus was on.
% GUI does not always catch this.
disp('Checking fixation data...');
eye_plotFlag = 0;
IOD = 35;
%vergence defination
FixPoint = [0, 0, 0]; %[x, y, z] mm position of the fixation point
% This will remove the trials that violate the version/vergence windows
[TrialInfo, version_vergence, version_confirmed, vergence_confirmed] = Offline_3DMotion_VersionVergenceCheck(IOD, Config, FixPoint, TrialInfo, recordingDate, eye_plotFlag);

%% Data Analysis/Sorting
AnaData = TrialInfo; % Make a copy so you don't overwrite it
TrialNum = length(TrialInfo);
TotalUnit = size(AnaData(1).UnitT,2); % Maximum # units assuming nan's where unit does not exist on some channels
TotalChannels = size(AnaData(1).UnitT,1);

%%
disp('Analyzing Receptive Fields...');
disp(['decoding Trial structure: ' num2str(TrialNum) ' total trials']);
for NumT = 1:TrialNum
    Event = AnaData(NumT).EID;
    Spikes = AnaData(NumT).UnitT;
    
    %bar or spares noise,
    %ID:203, bBarWidth(pixel):7000, BarHeight(pixel):8000, BarColor(0-255):9000
    %xPos: 10000, yPos: 20000, Rect(3):1000, Rect(4):2000
    
    AnaData(NumT).BarWidth = Event(Event >= 7000 & Event < 8000) - 7000; %stimulus width in pixels
    AnaData(NumT).BarHeight = Event(Event >= 8000 & Event < 9000) - 7000; %stimulus height in pixels
    AnaData(NumT).XPos = Event(Event >= 10000 & Event < 15000) - 10000; %stimulus position in pixels (horizental axis)
    AnaData(NumT).YPos = Event(Event >= 20000 & Event < 25000) - 20000; %stimulus position in pixels (vertical axis)
    AnaData(NumT).BarColor = Event(Event >= 9000 & Event < 10000) - 9000; %stimulus color in grayscale (0~255)
    
    % 117: hold fixation, 114: fixation acquired, 140: rewarded, 130: stimulus off, 118: stimulus on
    % Get time points
    T.Start = max(AnaData(NumT).EventT(AnaData(NumT).EID == 111));
    T.End = min(AnaData(NumT).EventT(AnaData(NumT).EID == 112));
    T.FixOn = max(AnaData(NumT).EventT(AnaData(NumT).EID == 114));
    T.StimOn = AnaData(NumT).EventT(AnaData(NumT).EID == 118 & AnaData(NumT).EventT < T.End);
    T.StimOff = AnaData(NumT).EventT(AnaData(NumT).EID == 130); % Last stim frame
    T.StimOff = T.StimOff(T.StimOff < T.End);
    
    % Locate spikes occuring within the time window
    tempSCount = sum(T.StimOn<=Spikes & Spikes<=T.StimOff, 3);
    % Calculate duration
    tempTime = T.StimOff - T.StimOn;
    
    AnaData(NumT).RawFR = tempSCount./tempTime;
    AnaData(NumT).Spikes = tempSCount;
    AnaData(NumT).time = tempTime;
    
end

uniXPos = unique(StimParam.StiXPos);
uniYPos = unique(StimParam.StiYPos);
uniColor = unique(StimParam.StiColor);

f = figure; hold on;
for u = ElectrodeNums
        
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
            %            plot(Resp.SpikeT_StiOnset{iTrial,jUnit}, iTrial*ones(numel(Resp.SpikeT_StiOnset{iTrial,jUnit}),1), '.', 'color', colorIndex(1,:)); hold on;
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

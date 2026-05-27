function [AnaData, Neuro] = Offline_Rapid2D_v1_051822(varargin)
% 2D Motion tuning using the trial structure generated during "Rapid 2D/3D
% Motion tuning" stimulus. This is part of the 3D motion stimulation project by
% LWT. Modified based on the Oflline_3DMotion_NoSaccade code by LWT on
% 5/18/22.
% Usually UnitT is [1xUnitxTimes]
% For MUA it will be [ChannelsxUnitsxTimes] where Units == 1
% You will need to alter the code to work with channels with unequal unit
% sizes. Currently TrialViewer does not support this!

if length(varargin)<2
    warning('not enought input parameters, select files manually');
    [file_names, pathname] = uigetfile({'*_2D*.mat' }, 'Select Quick 2D Motion Files',pwd, 'MultiSelect', 'on');
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
    fig_handle = [];
elseif length(varargin)==2 || length(varargin)>= 3
    pathname = varargin{1};
    file_names = varargin{2};
    if length(varargin)>= 3
        plotFlag = varargin{3};
        if length(varargin) >= 4
            plotUnits = varargin{4};
            if length(varargin) ~= 5
                fig_handle = [];
            end
        end
        if length(varargin) == 5
            fit_psychometric = 0;
            fig_handle = varargin{5};
        end
    else
        plotFlag = 0;
    end
    TrialInfo_file = load(string(fullfile(pathname,file_names{~contains(file_names, 'SelIndex')})));
    TrialInfo = TrialInfo_file.TrialInfo;
    SelectionInfo_file = load(string(fullfile(pathname,file_names{contains(file_names, 'SelIndex')})));
    Config = SelectionInfo_file.Config;
    SelectionInfo = logical(SelectionInfo_file.EditSel);
    TrialInfo = TrialInfo(SelectionInfo); % Only look at selected trials
end
filename_base = extractBefore(file_names{1},'2DM');
DashIdx = strfind(filename_base, '_');
FNameIdx = strfind(filename_base, 'TT');
DateIdx = strfind(filename_base, '201');
if isempty(DateIdx)
    DateIdx = strfind(filename_base, '202');
end
recordingDate = filename_base(DashIdx(find(DashIdx < DateIdx,1,'last'))+1:DashIdx(find(DashIdx > DateIdx,1,'first'))-1);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Digout control words from Matlab machine
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
% 131: break fixation during overlapped period
% 121: acquire saccade target vb
% 122: fail to acquire saccade target
% 123: hold saccade target
% 124: break holding saccade
% 140: reward on
% 141: reward off
% 112: trial ends
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Figure Parameters
if exist('subtightplot', 'file') == 2
    sub_plt = @(m,n,p) subtightplot(m, n, p, [0.07 0.01], [0.1 0.1], [0.05 0.01]); % 2D plots
else
    sub_plt = @(m,n,p) subplot(m, n, p);
end
colorsteps = [0 0 255;...
    5 150 5;...
    0 0 0]./255;
ChannelMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]; % Edge Design
conditionNames = {'Left','Right','Both'};
lineWidth = 3;
axesWidth = 1.5;
markerSize = 36;
FontSize = 18;
baselineSubtract = 1;

xRange = -1:0.01:1;
edgeSize = 5;

% For subplots
subplotFontSize = 10;
subplotLineWidth = 2;
subplotMarkerSize = 26;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Initial Eye Checking
% Ensure that the monkey did not break fixation while the stimulus was on.
% GUI does not always catch this.
disp('Checking fixation data...');
eye_plotFlag = 0;
IOD = 30;
%vergence defination
FixPoint = [0, 0, 0]; %[x, y, z] mm position of the fixation point

if datenum(recordingDate) ~= datenum(2022,05,20) % Bad eye data on 5/20/2022
    [TrialInfo, version_vergence, version_confirmed, vergence_confirmed] = Offline_3DMotion_VersionVergenceCondCheck(IOD, Config, FixPoint, TrialInfo, recordingDate, eye_plotFlag);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Data Analysis/Sorting
AnaData = TrialInfo; % Make a copy so you don't overwrite it
TrialNum = length(TrialInfo);
TotalUnit = size(AnaData(1).UnitT,2); % Maximum # units assuming nan's where unit does not exist on some channels
TotalChannels = size(AnaData(1).UnitT,1);
if length(varargin) < 4
    plotUnits = 1:TotalUnit;
end

max_blocks =  ceil(size(AnaData,2)/24); % This is based on a maximum of 48 trials/block!!!! %AnaData(end).EID(AnaData(end).EID>=2000 &  AnaData(end).EID<3000) - 2000; %TrialNum/trials_per_block;
ConditionArray = [1 2 3];
speed_array = [4.166667, 4.166667*3];
direction_array = linspace(0,360-45,8);
TrialResp = struct;
TrialResp.NumTrials = zeros(length(direction_array),2,length(ConditionArray));
NeuroResp_All = nan(length(direction_array),2,length(ConditionArray),max_blocks,TotalChannels,TotalUnit);

disp(['decoding Trial structure: ' num2str(TrialNum) ' total trials']);
for NumT = 1:TrialNum
    if mod(NumT,50) == 0 || NumT == TrialNum
        disp(['Rapid 2D trial progress: ' num2str(NumT) '/' num2str(TrialNum)]);
    end
    Event = AnaData(NumT).EID;
    AnaData(NumT).CodedEvents = num2cell(Event);
    Spikes = AnaData(NumT).UnitT;
    % Get time points
    T.Start = max(AnaData(NumT).EventT(AnaData(NumT).EID == 111));
    T.End = min(AnaData(NumT).EventT(AnaData(NumT).EID == 112));
    T.FixOn = max(AnaData(NumT).EventT(AnaData(NumT).EID == 114));
    T.StimOn = AnaData(NumT).EventT(AnaData(NumT).EID == 118 & AnaData(NumT).EventT < T.End);
    
    T.StimOff = AnaData(NumT).EventT(AnaData(NumT).EID == 130); % Last stim frame
    T.StimOff = T.StimOff(T.StimOff < T.End);
        
    Event = Event(AnaData(NumT).EventT>= T.Start & AnaData(NumT).EventT<=T.End);
    
    % Get pertinent stimulus information
    % Direction
    Direction = Event(Event>=4000 & Event<5000); % find 'direction'
    Direction = Direction - 4001;
    AnaData(NumT).Direction = Direction;
    DirectionNum = find(direction_array == Direction);

    % find 'Speed Index'
    Speed = Event(Event>=10000 & Event<=20000); % find 'Speed index'
    Speed = Speed - 10000;
    AnaData(NumT).Speed = Speed;
    if isempty(Speed)
        error('Speed not found');
    end
    
    % Condition
    % 1-left eye, 2-right eye, 3-both eyes (5, 6, 7 technically)
    Condition = Event(Event>=8000 & Event<9000);
    AnaData(NumT).Condition = Condition - 8000;
    ConditionNum = AnaData(NumT).Condition; %find( AnaData(NumT).Condition == ConditionArray);
    ConditionNum = ConditionNum-4; % this is because it will be coded as 5,6,7 with the first 4 conditions being 3D motion
    AnaData(NumT).ConditionNum = ConditionNum;
    
    % Find spike events for the units
    tempSCount = sum(T.StimOn<=Spikes & Spikes<=T.StimOff, 3);
    tempTime = T.StimOff - T.StimOn;
    
    AnaData(NumT).RawFR = tempSCount./tempTime;
    AnaData(NumT).Spikes = tempSCount;
    AnaData(NumT).time = tempTime;
    TrialResp.NumTrials(DirectionNum,Speed,ConditionNum) = TrialResp.NumTrials(DirectionNum,Speed,ConditionNum)+1;
    NeuroResp_All(DirectionNum,Speed,ConditionNum,TrialResp.NumTrials(DirectionNum,Speed,ConditionNum),:,:) = AnaData(NumT).RawFR;
end
NeuroResp_Means = squeeze(nanmean(NeuroResp_All,4));
NeuroResp_SEM = squeeze(nanstd(NeuroResp_All,[],4))./sqrt(TrialResp.NumTrials); % ONLY COUNTING NON-STIMULATION TRIALS
Neuro = struct('Means',NeuroResp_Means,'SEM',NeuroResp_SEM, 'All', NeuroResp_All, 'Trials', TrialResp);

%% Plot tuning curves
if plotFlag
    for SpeedNum = 1:2
        figure; hold on;
        for ch = 1:length(ChannelMap)
            p = find(ChannelMap == ch);
            ax = sub_plt(2,8,p); hold on; %#ok<NASGU>
            % We want to plot mean rate for all direction values,
            % separately for each eye
            for e = 1:length(ConditionArray)
                disp_plot(e) = plot(direction_array',NeuroResp_Means(:,SpeedNum,e,ch),'o','MarkerFaceColor',colorsteps(e,:), 'MarkerEdgeColor', colorsteps(e,:)); %#ok<NASGU>
                hold on;
                disp_plot_err(e) = errorbar(direction_array',NeuroResp_Means(:,SpeedNum,e,ch),NeuroResp_SEM(:,SpeedNum,e,ch),'Color',colorsteps(e,:)); %#ok<NASGU>
            end
            title(['Speed: ', num2str(round(speed_array(SpeedNum))), ' Ch: ', num2str(ch)]);
            if p>=9
                xlabel('Direction');
            end
            xticks(round(direction_array));
            if p == 1 || p == 9
                ylabel('Firing Rate');
            end
        end
    end
end

end

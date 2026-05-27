function [AnaData, LFP_Data,BehaviorData] = Offline_3DMotion_Stimulation_v2_081421(varargin)
% Altered this function such that UniT accepts multiple channels and units
% on 8/14/21 by LWT
% Usually UnitT is [1xUnitxTimes]
% For MUA it will be [ChannelsxUnitsxTimes] where Units == 1
% You will need to alter the code to work with channels with unequal unit
% sizes. Currently TrialViewer does not support this!

fit_psychometric = 0;
if length(varargin)<2
    warning('not enought input parameters, select files manually');
    [file_names, pathname] = uigetfile({'*_3D*.mat' }, 'Select 3D Motion Stimulation Files',pwd, 'MultiSelect', 'on');
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
filename_base = extractBefore(file_names{1},'3DM');
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
stim_code = 222;
stop_codes = [116,119,131,122,124]; % The different ecodes that should stop the stimulation as soon as possible
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Figure Parameters
colorsteps = [0 0 0;...
    0 0 255;...
    5 150 5;...
    234 0 233;
    0 100 255;...
    0 255 100]./255;

conditionNames = {'Combined','L Mono','R Mono','Binocular','L Control', 'R Control', 'Weighted All', 'Weighted Control'};
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


saccade_time_off = 0.3; % How much to subtract from stim off signal for saccade only trials; this is used to calculate baseline activity.
if datenum(recordingDate) < datenum(2019,04,02)
    trials_per_block = 58;
else
    trials_per_block = 60;
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Initial Eye Checking
% Ensure that the monkey did not break fixation while the stimulus was on.
% GUI does not always catch this.
TrialNum = length(TrialInfo);
version = tand(1)*Config.ScrDistmm;
disp('Checking fixation data...');
eye_plotFlag = 0;
smoothBin = 25;
IOD = 30;
%vergence defination
FixPoint = [0, 0, 0]; %[x, y, z] mm position of the fixation point

if datenum(recordingDate) ~= datenum(2022,05,20) % Bad eye data on 5/20/2022
    try
        [TrialInfo, version_vergence, version_confirmed, vergence_confirmed] = Offline_3DMotion_VersionVergenceCondCheck(IOD, Config, FixPoint, TrialInfo, recordingDate, eye_plotFlag);
    catch ME
        disp(['Version/vergence check failed for ' recordingDate '; continuing without additional trial rejection. ' ME.message]);
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Initial check of trial structure to remove trials that don't have the necessary event codes
AnaData = TrialInfo; % Make a copy so you don't overwrite it
TrialNum = length(TrialInfo);
for NumT = 1:TrialNum
    Event = AnaData(NumT).EID;
    % Get time points
    T.Start = max(AnaData(NumT).EventT(AnaData(NumT).EID == 111));
    T.End = min(AnaData(NumT).EventT(AnaData(NumT).EID == 112));
    T.FixOn = max(AnaData(NumT).EventT(AnaData(NumT).EID == 114));
    T.StimOn = AnaData(NumT).EventT(AnaData(NumT).EID == 118 & AnaData(NumT).EventT < T.End);
    T.StimOff = AnaData(NumT).EventT(AnaData(NumT).EID == 130); % Last stim frame
    T.StimOff = T.StimOff(T.StimOff < T.End);
    T.SaccOn = AnaData(NumT).EventT(AnaData(NumT).EID == 120); % Saccade targets on
    T.SaccMade = max(AnaData(NumT).EventT(AnaData(NumT).EID == 123));
    Event = Event(AnaData(NumT).EventT>= T.Start & AnaData(NumT).EventT<=T.End);
    % Get pertinent stimulus information
    
    % Direction
    Direction = Event(Event>=4000 & Event<5000); % find 'direction', coded as 0 or 2 (subtract 1)
    
    % Coherence
    Coherence = Event(Event>=10000 & Event<=20000); % find 'Coherence'
    
    % Condition
    % 1-combined, 2-monoL, 3-monoR, 4-bino
    Condition = Event(Event>=8000 & Event<9000);
    
    
    if ~isempty(T.StimOn) && ~isempty(T.StimOff) && ~isempty(T.SaccMade) && ~isempty(Condition) && ~isempty(Coherence) && ~isempty(Direction)
        good(NumT) = true;
    else
        good(NumT) = false;
    end
end
AnaData = AnaData(good);
TrialNum = length(AnaData);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Data Analysis/Sorting

TotalUnit = size(AnaData(1).UnitT,2); % Maximum # units assuming nan's where unit does not exist on some channels
TotalChannels = size(AnaData(1).UnitT,1);
if length(varargin) < 4
    plotUnits = 1:TotalUnit;
end

max_blocks =  ceil(size(AnaData,2)/60); % This is based on a maximum of 60 trials/block!!!! %AnaData(end).EID(AnaData(end).EID>=2000 &  AnaData(end).EID<3000) - 2000; %TrialNum/trials_per_block;

CoherenceArray = [-22 -14 -10 -8 -4 -2 2 4 8 10 14 22]./22;
ConditionArray = [1 2 3 4];

BlockOffset = 0;
TrialResp = struct; % zeros(length(ConditionNum),length(CoherenceNum),2);
TrialResp.NumTrials = zeros(length(ConditionArray),length(CoherenceArray));
TrialResp.Toward = zeros(length(ConditionArray),length(CoherenceArray));
TrialResp.Correct = zeros(length(ConditionArray),length(CoherenceArray));
NonStimTrials = TrialResp;
StimTrials = TrialResp;
NeuroResp_All = nan(length(ConditionArray),length(CoherenceArray),max_blocks,TotalChannels,TotalUnit);

NeuroResp = cell(TotalUnit,length(ConditionArray),length(CoherenceArray),max_blocks);
NeuroResp_C = nan(TotalUnit,length(ConditionArray),length(CoherenceArray),max_blocks);
NeuroResp_W = nan(TotalUnit,length(ConditionArray),length(CoherenceArray),max_blocks);
NeuroTime_C = nan(length(ConditionArray),length(CoherenceArray),max_blocks);
NeuroTime_W = nan(length(ConditionArray),length(CoherenceArray),max_blocks);
NeuroResp_Chose_T = cell(length(ConditionArray),length(CoherenceArray));
NeuroResp_Chose_A = cell(length(ConditionArray),length(CoherenceArray));
LFP_Data.All = [];
LFP_Data.All_Post = [];
LFP_Data.Stim = [];
LFP_Data.NoStim = [];
BehaviorData = struct('Choice',[],'MonkeyChoice',[],'ConditionNum',[],'CoherenceNum',[],'Block',[], 'EM', []);

b = 1;
Block_Count(1) = 0;
skippedCoherenceTrials = [];
disp(['decoding Trial structure: ' num2str(TrialNum) ' total trials']);
for NumT = 1:TrialNum
    if mod(NumT,50) == 0 || NumT == TrialNum
        disp(['Stimulation trial progress: ' num2str(NumT) '/' num2str(TrialNum)]);
    end
    
    Event = AnaData(NumT).EID;
    AnaData(NumT).CodedEvents = num2cell(Event);
    Spikes = AnaData(NumT).UnitT;
    % Get time points
    T.Start = max(AnaData(NumT).EventT(AnaData(NumT).EID == 111));
    AnaData(NumT).CodedEvents(AnaData(NumT).EID == 111) = {"Start"};
    T.End = min(AnaData(NumT).EventT(AnaData(NumT).EID == 112));
    AnaData(NumT).CodedEvents(AnaData(NumT).EID == 112) = {"End"};
    T.FixOn = max(AnaData(NumT).EventT(AnaData(NumT).EID == 114));
    AnaData(NumT).CodedEvents(AnaData(NumT).EID == 114) = {"FixOn"};
    T.StimOn = AnaData(NumT).EventT(AnaData(NumT).EID == 118 & AnaData(NumT).EventT < T.End);
    AnaData(NumT).CodedEvents(AnaData(NumT).EID == 118 & AnaData(NumT).EventT < T.End) = {"StimOn"};
    if ~isempty(T.StimOn)
        T.StimOn = T.StimOn(1);
    end
    
    T.StimOff = AnaData(NumT).EventT(AnaData(NumT).EID == 130); % Last stim frame
    T.StimOff = T.StimOff(T.StimOff < T.End);
    if ~isempty(T.StimOff)
        T.StimOff = T.StimOff(end);
    end
    
    T.SaccOn = AnaData(NumT).EventT(AnaData(NumT).EID == 120); % Saccade targets on
    AnaData(NumT).CodedEvents(AnaData(NumT).EID == 120 & AnaData(NumT).EventT < T.End) = {"SaccOn"};
    if ~isempty(T.SaccOn)
        T.SaccOn = T.SaccOn(1);
    end
    
    T.SaccMade = max(AnaData(NumT).EventT(AnaData(NumT).EID == 123));
    AnaData(NumT).CodedEvents(max(AnaData(NumT).EID == 123)) = {"SaccMade"};
    Event = Event(AnaData(NumT).EventT>= T.Start & AnaData(NumT).EventT<=T.End);
    % Get pertinent stimulus information
    
    % Direction
    Direction = unique(Event(Event>=4000 & Event<5000) - 4001); % find 'direction', coded as 0 or 2 (subtract 1)
    if isempty(Direction)
        error('Direction not found');
    end
    AnaData(NumT).Direction = Direction(1);
    
    % Coherence
    Coherence = unique(Event(Event>=10000 & Event<=20000)); % find 'Coherence'
    Coh_Trial = round(((Coherence(:)' - 10000) .* AnaData(NumT).Direction) ./ (1*10^4), 2);
    validCoh = Coh_Trial(ismember(Coh_Trial, round(CoherenceArray,2)));
    if isempty(validCoh)
        AnaData(NumT).Coherence = [];
        AnaData(NumT).CoherenceNum = [];
        skippedCoherenceTrials(end+1) = NumT; %#ok<AGROW>
        continue
    else
        AnaData(NumT).Coherence = validCoh(1);
    end
    CoherenceNum = find(AnaData(NumT).Coherence == round(CoherenceArray,2), 1, 'first');
    AnaData(NumT).CoherenceNum = CoherenceNum;
    if isempty(CoherenceNum)
        error('Coherence not found');
    end
    
    % Condition
    % 1-combined, 2-monoL, 3-monoR, 4-bino
    Condition = Event(Event>=8000 & Event<9000);
    AnaData(NumT).Condition = Condition - 8000;
    ConditionNum = AnaData(NumT).Condition; %find( AnaData(NumT).Condition == ConditionArray);
    AnaData(NumT).ConditionNum = ConditionNum;
    
    % Block Number
    Block = Event(Event>=2000 &  Event<3000) - 2000;
    AnaData(NumT).Block = Block;
    if length(Block_Count) < Block
        Block_Count(Block) = 1;
    else
        Block_Count(Block) = Block_Count(Block) + 1;
    end
    if isempty(Block)
        error('Block not found');
    end
    if  NumT>1
        if (Block - AnaData(NumT-1).Block <0)
            if BlockOffset ~= 0
                error('I havent accounted for more than one block change...');
            else
                BlockOffset = AnaData(NumT-1).Block; % This only works for a single block change (1 restart)
            end
        end
    end
    Block = Block + BlockOffset;
    if Block > size(NeuroResp,4)
        %         Block = size(NeuroResp,4) + 1;
        %         old = NeuroResp;
        %         NeuroResp =  cell(TotalUnit,length(ConditionArray),length(CoherenceArray),size(NeuroResp,4) + 1);
        %         NeuroResp(:,:,:,1:Block-1) = old; % cell(TotalUnit,length(ConditionArray),length(CoherenceArray),max_blocks);
        %         NeuroResp_C(:,:,:,end+1) = nan; %nan(TotalUnit,length(ConditionArray),length(CoherenceArray),max_blocks);
        %         NeuroResp_W(:,:,:,end+1) = nan; % nan(TotalUnit,length(ConditionArray),length(CoherenceArray),max_blocks);
        %         NeuroTime_C(:,:,end+1) = nan; %nan(length(ConditionArray),length(CoherenceArray),max_blocks);
        %         NeuroTime_W(:,:,end+1) = nan; % = nan(length(ConditionArray),length(CoherenceArray),max_blocks);
    end
    %
    %
    %     if isempty(T.StimOff) % No 120 signal means no saccade target
    %         if(AnaData(NumT).Condition == 5 || AnaData(NumT).Condition == 6 || AnaData(NumT).Condition == 9 || AnaData(NumT).Condition == 10)
    %             % The closest stim off signal is the 130 command, indicating
    %             % the last frame of the stimulus.
    %             T.StimOff = AnaData(NumT).EventT(AnaData(NumT).EID == 130);
    %         else
    %             error('No stimulus off (saccade target on) EID, and the condition is not a control trial');
    %         end
    %     end
    
    % Response
    Response = Event(Event>=6000 & Event<7000);
    AnaData(NumT).Response = Response - 6000;
    
    % Initialize
    AnaData(NumT).Choice = 'N';
    
    % Eye Presentation
    Eye = Event(Event>=9000 & Event<10000);
    AnaData(NumT).Eye = Eye - 9000;
    
    % Find spike events for the units
    if ConditionNum > 6
        tempSCount = sum(T.StimOn<=Spikes & Spikes<=(T.StimOff-saccade_time_off), 3);
        tempTime = (T.StimOff-saccade_time_off) - T.StimOn;
    else
        tempSCount = sum(T.StimOn<=Spikes & Spikes<=T.StimOff, 3);
        tempTime = T.StimOff - T.StimOn;
    end
    % Do we need to loop through units or can we bin data simultaneously?
    for u = 1:size(Spikes,2)
        bin_temp = squeeze(Spikes(1,u,T.StimOn<=Spikes(1,u,:) & Spikes(1,u,:)<=T.SaccMade)); % stim on to sacc made
        if isempty(min(bin_temp))
            AnaData(NumT).binned_data{u,:} = NaN;
            %             disp(['Unable to bin data for unit: ' num2str(u), ' Trial: ', num2str(NumT)]);
        else
            binLimits = [T.StimOn, T.SaccMade];
            if numel(binLimits) ~= 2 || any(~isfinite(binLimits)) || binLimits(2) <= binLimits(1)
                AnaData(NumT).binned_data{u,:} = NaN;
            else
                AnaData(NumT).binned_data{u,:} = histcounts(bin_temp,'BinWidth', 0.01, 'BinLimits',binLimits)./0.01;
            end
        end
    end
    AnaData(NumT).RawFR = tempSCount./tempTime;
    AnaData(NumT).Spikes = tempSCount;
    AnaData(NumT).time = tempTime;
    
    AnaData(NumT).isstim_trial = any(Event==stim_code);
    
    % Also do the same thing for LFP data to calculate AUC and clustering
    % index
    % Unlike spike data, the LFP data contains actual values rather than
    % time stamps. Use the AIT values to determine the indices of the LFP
    % data that are within the range you want.
    SI = find(AnaData(NumT).AITs>=T.StimOn,1,'first')-1 ; % Start index. Subtract one or the first point is already the spike.
    EI = SI+1000-1; % Assumes 1000 Hz sampling to get equal sized matrix with 1 second stimulus; Alternatively, true value is: find(TrialInfo(NumT).AITs<=T.StimOff,1,'last'); % End index
    % EI = find(TrialInfo(NumT).AITs<=T.StimOff,1,'last'); % End index
       % LFP_Data.All(end+1,:,:) = AnaData(NumT).LFP(:,SI:EI); % select dataS
      LFP_Data.All(end+1,:,:) = AnaData(NumT).LFP(:,EI+1:EI+200); % select data 
    lfpTrialIdx = size(LFP_Data.All,1);
    
%     if NumT == 1
%         figure;
%     else
%         hold off;
%     end
%     if AnaData(NumT).isstim_trial
%         plot(AnaData(NumT).LFP(:,EI+1:EI+200)')
%         hold on;
% %         plot([SI,SI],[-1500,1500],'--b')
% %         plot([EI,EI],[-1500,1500],'--r')
% %         plot([EI+200,EI+200],[-1500,1500],'--k')
%     end
    
    TrialResp.NumTrials(ConditionNum,CoherenceNum) = TrialResp.NumTrials(ConditionNum,CoherenceNum)+1;
    if AnaData(NumT).Response == 1 % completed and correct
        TrialResp.Correct(ConditionNum,CoherenceNum) = TrialResp.Correct(ConditionNum,CoherenceNum)+1;
        if AnaData(NumT).Direction == 1
            if ~AnaData(NumT).isstim_trial
                NonStimTrials.Toward(ConditionNum,CoherenceNum) = NonStimTrials.Toward(ConditionNum,CoherenceNum) + 1;
            else
                StimTrials.Toward(ConditionNum,CoherenceNum) = StimTrials.Toward(ConditionNum,CoherenceNum) + 1;
            end
            TrialResp.Toward(ConditionNum,CoherenceNum) = TrialResp.Toward(ConditionNum,CoherenceNum) + 1;
            AnaData(NumT).Choice = 'T';
            AnaData(NumT).MonkeyChoice = 'T';
        else
            AnaData(NumT).Choice = 'A'; % Correct away trial
            AnaData(NumT).MonkeyChoice = 'A';
        end
    elseif AnaData(NumT).Response == 0 % completed and wrong
        if AnaData(NumT).Direction == -1 % Was away
            TrialResp.Toward(ConditionNum,CoherenceNum) = TrialResp.Toward(ConditionNum,CoherenceNum) + 1;
            if ~AnaData(NumT).isstim_trial
                NonStimTrials.Toward(ConditionNum,CoherenceNum) = NonStimTrials.Toward(ConditionNum,CoherenceNum) + 1;
            else
                StimTrials.Toward(ConditionNum,CoherenceNum) = StimTrials.Toward(ConditionNum,CoherenceNum) + 1;
            end
            AnaData(NumT).Choice = 'A';
            AnaData(NumT).MonkeyChoice = 'T';
        else
            AnaData(NumT).Choice = 'T'; % Incorrect toward trial
            AnaData(NumT).MonkeyChoice = 'A';
        end
    end
    
    % Only count spikes from non-stimulation trials!!!
    if ~AnaData(NumT).isstim_trial
        if ~isempty(T.StimOn) && ~isempty(T.StimOff) % This would be weird, but could be due to trials where latched eye mode caught an error but target circles remained on screen
            LFP_Data.NoStim(end+1,:,:) = LFP_Data.All(lfpTrialIdx,:,:);
            NonStimTrials.NumTrials(ConditionNum,CoherenceNum) = NonStimTrials.NumTrials(ConditionNum,CoherenceNum) + 1;
            % Just a large matrix of neural responses
            NeuroResp_All(ConditionNum,CoherenceNum,NonStimTrials.NumTrials(ConditionNum,CoherenceNum),:,:) = AnaData(NumT).RawFR;
        end
    else
        LFP_Data.Stim(end+1,:,:) = LFP_Data.All(lfpTrialIdx,:,:);
        StimTrials.NumTrials(ConditionNum,CoherenceNum) = StimTrials.NumTrials(ConditionNum,CoherenceNum) + 1;
    end
    
    if ~isempty(T.StimOn) && ~isempty(T.StimOff) % This would be weird, but could be due to trials where latched eye mode caught an error but target circles remained on screen
        % We can build a towards and away response matrix from this pretty
        % easily, the only issue is the 0% coherence. We must specifiy the
        % towards and away responses at 0 %
        BehaviorData.Choice(end+1) = AnaData(NumT).Choice;
        BehaviorData.MonkeyChoice(end+1) = AnaData(NumT).MonkeyChoice;
        BehaviorData.ConditionNum(end+1) = ConditionNum;
        BehaviorData.CoherenceNum(end+1) = CoherenceNum;
        BehaviorData.Block(end+1) = Block;
        if ~AnaData(NumT).isstim_trial
            BehaviorData.EM(end+1) = 0;
        else
            BehaviorData.EM(end+1) = 1;
        end
    end
end
if ~isempty(skippedCoherenceTrials)
    disp(['Skipped ' num2str(numel(skippedCoherenceTrials)) ' stimulation trials with unsupported coherence values (for example 0 coherence).']);
end
NeuroResp_Means = squeeze(nanmean(NeuroResp_All,3));
NeuroResp_SEM = squeeze(nanstd(NeuroResp_All,[],3))./sqrt(NonStimTrials.NumTrials); % ONLY COUNTING NON-STIMULATION TRIALS

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% AnaData_ByStim.mean_NeuroResp_Chose_T = cellfun(@(x) mean(x,2), NeuroResp_Chose_T,'UniformOutput',false);
% AnaData_ByStim.mean_NeuroResp_Chose_A = cellfun(@(x) mean(x,2), NeuroResp_Chose_A,'UniformOutput',false);
% std_NeuroResp_Chose_T = cellfun(@(x) std(x,0,2), NeuroResp_Chose_T,'UniformOutput',false);
% std_NeuroResp_Chose_A = cellfun(@(x) std(x,0,2), NeuroResp_Chose_A,'UniformOutput',false);
% trials_NeuroResp_Chose_T = cellfun(@(x) size(x,2), NeuroResp_Chose_T,'UniformOutput',false);
% trials_NeuroResp_Chose_A = cellfun(@(x) size(x,2), NeuroResp_Chose_A,'UniformOutput',false);
% sem_NeuroResp_Chose_T =  cellfun(@(x) std_NeuroResp_Chose_T{x}/trials_NeuroResp_Chose_T{x}, num2cell(1:numel(trials_NeuroResp_Chose_T)),'UniformOutput',false);
% sem_NeuroResp_Chose_A = cellfun(@(x) std_NeuroResp_Chose_A{x}/trials_NeuroResp_Chose_A{x}, num2cell(1:numel(trials_NeuroResp_Chose_A)),'UniformOutput',false);
% AnaData_ByStim.sem_NeuroResp_Chose_T = reshape(sem_NeuroResp_Chose_T,size(trials_NeuroResp_Chose_T));
% AnaData_ByStim.sem_NeuroResp_Chose_A = reshape(sem_NeuroResp_Chose_A,size(trials_NeuroResp_Chose_A));
% AnaData_ByStim.NeuroResp_C= NeuroResp_C;
% AnaData_ByStim.NeuroResp_W = NeuroResp_W;
% AnaData_ByStim.NeuroResp_Chose_T = NeuroResp_Chose_T;
% AnaData_ByStim.NeuroResp_Chose_A = NeuroResp_Chose_A;
% AnaData_ByStim.mean_FR = mean_FR;
% AnaData_ByStim.sem_FR = sem_FR;
% AnaData_ByStim.baseline = baseline_mean_FR;
% AnaData_ByStim.pFit = pFitVals;
% AnaData_ByStim.pFitOut = temp_pFit;
% AnaData_ByStim.NeuroResp = NeuroResp;
% AnaData_ByStim.Trial_Resp = TrialResp;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
plotSpikeMat_Means = NeuroResp_Means(1:4,:,:,:);

%% Generate Tuning Curves

if plotFlag
    for ch = 1:size(plotSpikeMat_Means,3)
        tempCh = squeeze(plotSpikeMat_Means(:,:,ch,:));
        % Get the total units for this channel
        totalU = sum(~isnan(tempCh(1,1,:)));
        figure; hold on;
        for u = 1:totalU
            temp = tempCh(:,:,u);
            subplot(1,u,TotalUnit)
            
            fr = plot(CoherenceArray,temp,'-o');
            hold on;
            %     axis square;
            box on;
            title(['Channel: ', num2str(ch), ' Unit: ', num2str(u)]);
            ylabel('Firing Rate');
            xlabel('Coherence');
            for cond = 1:min(4, numel(fr))
                fr(cond).Color = colorsteps(cond,:);
                fr(cond).MarkerFaceColor = colorsteps(cond,:);
                fr(cond).MarkerEdgeColor = colorsteps(cond,:);
            end
        end
    end
end


%% Behavior plots
%%%%%%%%%%%%%%%%%%%%%%%%%
% Parameters from behavioral data collection before recording:
requiredBehaviorFns = {'psignifit', 'getStandardParameters'};
for iFn = 1:numel(requiredBehaviorFns)
    if exist(requiredBehaviorFns{iFn}, 'file') ~= 2
        error('Missing required psychometric toolbox function: %s', requiredBehaviorFns{iFn});
    end
end

options.sigmoidName = 'norm'; % norm cdf fit
%options.estimateType = 'MAP';
options.fixedPars = NaN(5,1);
options.fixedPars(3:4) = 0.00001; % Fix the upper and lower asymptotes\
options.expType = 'equalAsymptote'; %'YesNo';%'equalAsymptote';

% Provide prior on width
lowerBound = 2;
priorWidth = @(x) (x>0&x<=lowerBound).*(1-cos(pi.*x./lowerBound)) + (x>lowerBound&x<=100).*2; % raised cosine
options.priors{2} = priorWidth;
options.borders = nan(5,2);
options.borders(3,:)=[0,.05]; % upper range of lapse rate
options.borders(4,:)=[0,.05]; % lower range of lapse rate
%%%%%%%%%%%%%%%%%%%%%%%%%
% 1) Non-stimulation trials
if plotFlag
    figure; subplot(1,2,1); hold on;
end
for cond = 1:4
    pfitMat(:,:,cond) = [CoherenceArray', NonStimTrials.Toward(cond,:)',NonStimTrials.NumTrials(cond,:)'];
    temp_pFit(cond) = psignifit(pfitMat(:,:,cond),options);
    pFitVals(:,cond) = getStandardParameters(temp_pFit(cond),'gauss');
    if plotFlag
        plotOptions.dataColor = colorsteps(cond,:);
        plotOptions.lineColor = colorsteps(cond,:);
        pfitPlot(cond) = plotPsych(temp_pFit(cond),plotOptions); %#ok<NASGU>
        if cond == 1
            hold on;
        end
    end
end
if plotFlag
    title('Non-Stimulation Trials');
    line(xRange, ones(length(xRange),1)*0.5,'LineStyle','--','Color',[0 0 0]);
    line(zeros(length(xRange),1),[0:0.5:100],'LineStyle','--','Color',[0 0 0]);
    xlabel('Coherence');
    ylabel('Proportion Chose Towards');
    xlim([-1,1]);
    axis square;
end
BehaviorData.NoStim.pFitVals = pFitVals;
BehaviorData.NoStim.pFitResult = temp_pFit;

% Stimulation Trials
if plotFlag
    subplot(1,2,2); hold on;
end
for cond = 1:4 %length(ConditionArray)-4
    pfitMat(:,:,cond) = [CoherenceArray', StimTrials.Toward(cond,:)',StimTrials.NumTrials(cond,:)'];
    
    temp_pFit(cond) = psignifit(pfitMat(:,:,cond), options); % No options here, options were for "regular" data that had a prior on the biases and lapses
    pFitVals(:,cond) = getStandardParameters(temp_pFit(cond),'gauss');
    if plotFlag
        plotOptions.dataColor = colorsteps(cond,:);
        plotOptions.lineColor = colorsteps(cond,:);
        pfitPlot(cond) = plotPsych(temp_pFit(cond),plotOptions); %#ok<NASGU>
    end
end
if plotFlag
    title('Stimulation Trials');
    line(xRange, ones(length(xRange),1)*0.5,'LineStyle','--','Color',[0 0 0]);
    line(zeros(length(xRange),1),[0:0.5:100],'LineStyle','--','Color',[0 0 0]);
    xlabel('Coherence');
    ylabel('Proportion Chose Towards');
    xlim([-1,1]);
    axis square;
end
BehaviorData.Stim.pFitVals = pFitVals;
BehaviorData.Stim.pFitResult = temp_pFit;
BehaviorData.StimTrials = StimTrials;
BehaviorData.NonStimTrials = NonStimTrials;

end

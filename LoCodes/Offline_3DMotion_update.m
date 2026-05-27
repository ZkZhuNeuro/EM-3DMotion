function [AnaData, AnaData_ByStim,BehaviorData] = Offline_3DMotion_update(varargin)
fit_psychometric = 0;
if length(varargin)<2
    warning('not enought input parameters, select files manually');
    [file_names, pathname] = uigetfile({'*_3D*.mat' }, 'Select Files',pwd, 'MultiSelect', 'on');
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
filename_base = extractBefore(file_names{1},'3D');
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
eyeLocation = [-IOD/2, IOD/2];
FPx = FixPoint(1) + ((eyeLocation - FixPoint(1))./Config.ScrDistmm + FixPoint(3))*FixPoint(3);
FPy = FixPoint(2) + (FixPoint(2)*(FixPoint(2)+Config.ScrDistmm)./Config.ScrDistmm)-FixPoint(2);

perfectEyeLx = atan2d(Config.ScrDistmm+FixPoint(3), FPx(1)+(IOD/2)) - 90; %degrees
perfectEyeRx = 90 - atan2d(Config.ScrDistmm+FixPoint(3),FPx(2)-(IOD/2)); %degrees
perfectDeltaX = perfectEyeLx + perfectEyeRx; %degrees

if eye_plotFlag
    figure;
end
for NumT = 1:TrialNum
    Event = TrialInfo(NumT).EID;
    % Get time points
    T.Start = TrialInfo(NumT).EventT(TrialInfo(NumT).EID == 111);
    T.End = min(TrialInfo(NumT).EventT(TrialInfo(NumT).EID == 112));
    T.FixOn = max(TrialInfo(NumT).EventT(TrialInfo(NumT).EID == 114));
    T.StimOn = TrialInfo(NumT).EventT(TrialInfo(NumT).EID == 118 & TrialInfo(NumT).EventT <= T.End);
    T.StimOff = TrialInfo(NumT).EventT(TrialInfo(NumT).EID == 130); % Technically 2 frames left
    T.StimOff = T.StimOff(T.StimOff < T.End);
    Condition = Event(Event>=8000 & Event<9000 & TrialInfo(NumT).EventT <= T.End);
    TrialInfo(NumT).Condition = Condition - 8000;
    if isempty(T.StimOff) % No 120 signal means no saccade target
        if isempty(Condition)
         warning(['Trial: ' num2str(NumT) ' is missing a condition EID, skipping trial']);
         version_confirmed(NumT) = 0;
         continue
        end
        if(TrialInfo(NumT).Condition == 5 || TrialInfo(NumT).Condition == 6 || TrialInfo(NumT).Condition == 9 || TrialInfo(NumT).Condition == 10)
            % The closest stim off signal is the 130 command, indicating
            % the last frame of the stimulus.
            T.StimOff = TrialInfo(NumT).EventT(TrialInfo(NumT).EID == 130);
        else
            warning(['Trial: ' num2str(NumT) ' has no stimulus off (saccade target on) EID, and the condition is not a control trial']);
        end
    end
    if isempty(T.FixOn) || isempty(T.StimOn) || isempty(T.StimOff)
         warning(['Trial: ' num2str(NumT) ' is missing a fix on, stim on, or stim off signal']);
         version_confirmed(NumT) = 0;
         continue
    end
    
    AIT_fix = find(TrialInfo(NumT).AITs >= T.FixOn & TrialInfo(NumT).AITs <= T.StimOn); % Analog index where time is only during fixation period
    AIT_stim = find(TrialInfo(NumT).AITs >= T.StimOn & TrialInfo(NumT).AITs <= T.StimOff); % Analog index where time is equal to stim on
    
    if datenum(recordingDate) >= datenum(2019,04,03) % Added offset from GUI to MATLAB and then to Rippleon this date
        L_offset.x = TrialInfo(NumT).EID(TrialInfo(NumT).EID >= 20750 & TrialInfo(NumT).EID<21250 & TrialInfo(NumT).EventT < T.End) - 21000; % CAN ONLY BE WITHIN 250 OF THE VALUE!!!!
        L_offset.y = TrialInfo(NumT).EID(TrialInfo(NumT).EID >= 21250 & TrialInfo(NumT).EID<21750 & TrialInfo(NumT).EventT < T.End) - 21500;
        R_offset.x = TrialInfo(NumT).EID(TrialInfo(NumT).EID >= 21750 & TrialInfo(NumT).EID<22250 & TrialInfo(NumT).EventT < T.End) - 22000;
        R_offset.y = TrialInfo(NumT).EID(TrialInfo(NumT).EID >= 22250 & TrialInfo(NumT).EID<22750 & TrialInfo(NumT).EventT < T.End) - 22500;
        
        % TrialViewer calculates an offset which is already applied to
        % data- must add it back if using GUI data.
        % Add the offset and from Trial Viewer, the offset from the GUI,
        % and smooth the data to remove small jitter.
        smoothed_AIT.LEyeX = smooth((TrialInfo(NumT).LEyeX+ L_offset.x + TrialInfo(NumT).OffsetLX), smoothBin);
        smoothed_AIT.LEyeY = smooth((TrialInfo(NumT).LEyeY+ L_offset.y + TrialInfo(NumT).OffsetLY), smoothBin);
        smoothed_AIT.REyeX = smooth((TrialInfo(NumT).REyeX+ R_offset.x + TrialInfo(NumT).OffsetRX), smoothBin);
        smoothed_AIT.REyeY = smooth((TrialInfo(NumT).REyeY+ R_offset.y + TrialInfo(NumT).OffsetRY), smoothBin);
        
        smoothed_AIT_stim.LEyeX = smoothed_AIT.LEyeX(AIT_stim);
        smoothed_AIT_stim.LEyeY = smoothed_AIT.LEyeY(AIT_stim);
        smoothed_AIT_stim.REyeX = smoothed_AIT.REyeX(AIT_stim);
        smoothed_AIT_stim.REyeY = smoothed_AIT.REyeY(AIT_stim);
        
%         L = sqrt((TrialInfo(NumT).LEyeX(AIT_stim) + L_offset.x + TrialInfo(NumT).OffsetLX).^2 + (TrialInfo(NumT).LEyeY(AIT_stim) + L_offset.y + TrialInfo(NumT).OffsetLY).^2); % TrialViewer calculates an offset which is already applied to data- must add it back if using GUI data
%         R = sqrt((TrialInfo(NumT).REyeX(AIT_stim) + R_offset.x + TrialInfo(NumT).OffsetRX).^2 + (TrialInfo(NumT).REyeY(AIT_stim) + R_offset.y + TrialInfo(NumT).OffsetRY).^2);
        
        L = sqrt((smoothed_AIT_stim.LEyeX).^2 + (smoothed_AIT_stim.LEyeY).^2);
        R = sqrt((smoothed_AIT_stim.REyeX).^2 + (smoothed_AIT_stim.REyeY).^2);
        
        % Check vergence as well (X only)
        actualEyeLx = atan2d(Config.ScrDistmm, smoothed_AIT_stim.LEyeX+(IOD/2)) - 90; %degrees
        actualEyeRx =  90 - atan2d(Config.ScrDistmm, smoothed_AIT_stim.REyeX-(IOD/2)); %degrees
        actualDeltax = actualEyeLx + actualEyeRx;  %diffence between left and right eyes in X-axis
        vergenceDiffX{NumT} = actualDeltax - perfectDeltaX;
        TrialInfo(NumT).vergence = vergenceDiffX{NumT};
        if any(abs(vergenceDiffX{NumT}) > 0.5)
            vergence_confirmed(NumT) = 0;
        else
            vergence_confirmed(NumT) = 1;
        end
        
    else
        %         Calculate an average fixation position during the initial fixation
        %         holding phase for each eye and axis:
        L_offset.x = mean(TrialInfo(NumT).LEyeX(AIT_fix)+ TrialInfo(NumT).OffsetLX);
        L_offset.y = mean(TrialInfo(NumT).LEyeY(AIT_fix)+ TrialInfo(NumT).OffsetLY);
        R_offset.x = mean(TrialInfo(NumT).REyeX(AIT_fix)+ TrialInfo(NumT).OffsetRX);
        R_offset.y = mean(TrialInfo(NumT).REyeX(AIT_fix)+ TrialInfo(NumT).OffsetRY);
        
        smoothed_AIT.LEyeX = smooth((TrialInfo(NumT).LEyeX - L_offset.x + TrialInfo(NumT).OffsetLX), smoothBin);
        smoothed_AIT.LEyeY = smooth((TrialInfo(NumT).LEyeY - L_offset.y + TrialInfo(NumT).OffsetLY), smoothBin);
        smoothed_AIT.REyeX = smooth((TrialInfo(NumT).REyeX - R_offset.x + TrialInfo(NumT).OffsetRX), smoothBin);
        smoothed_AIT.REyeY = smooth((TrialInfo(NumT).REyeY - R_offset.y + TrialInfo(NumT).OffsetRY), smoothBin);
        
        smoothed_AIT_stim.LEyeX = smoothed_AIT.LEyeX(AIT_stim);
        smoothed_AIT_stim.LEyeY = smoothed_AIT.LEyeY(AIT_stim);
        smoothed_AIT_stim.REyeX = smoothed_AIT.REyeX(AIT_stim);
        smoothed_AIT_stim.REyeY = smoothed_AIT.REyeY(AIT_stim);
        
        L = sqrt((smoothed_AIT_stim.LEyeX).^2 + (smoothed_AIT_stim.LEyeY).^2);
        R = sqrt((smoothed_AIT_stim.REyeX).^2 + (smoothed_AIT_stim.REyeY).^2);

        % Now take all eye position data from while the stimulus was on and
        % offset it by the average during fixation. Then calculate the total
        % distance from fixation at each point in time.
%         L = sqrt((TrialInfo(NumT).LEyeX(AIT_stim) - L_offset.x + TrialInfo(NumT).OffsetLX).^2 + (TrialInfo(NumT).LEyeY(AIT_stim) - L_offset.y + TrialInfo(NumT).OffsetLY).^2);
%         R = sqrt((TrialInfo(NumT).REyeX(AIT_stim) - R_offset.x + TrialInfo(NumT).OffsetRX).^2 + (TrialInfo(NumT).REyeY(AIT_stim) - R_offset.y + TrialInfo(NumT).OffsetRY).^2);
        
          % Check vergence as well (X only)
        actualEyeLx = atan2d(Config.ScrDistmm, (TrialInfo(NumT).LEyeX(AIT_stim) - L_offset.x + TrialInfo(NumT).OffsetLX)+(IOD/2)) - 90; %degrees
        actualEyeRx =  90 - atan2d(Config.ScrDistmm, (TrialInfo(NumT).REyeX(AIT_stim) - R_offset.x + TrialInfo(NumT).OffsetRX)-(IOD/2)); %degrees
        actualDeltax = actualEyeLx + actualEyeRx;  %diffence between left and right eyes in X-axis
        vergenceDiffX{NumT} = actualDeltax - perfectDeltaX;
        TrialInfo(NumT).vergence = vergenceDiffX{NumT};
        if any(abs(vergenceDiffX{NumT}) > 0.5)
            vergence_confirmed(NumT) = 0;
        else
            vergence_confirmed(NumT) = 1;
        end
        
    end
    
   
    
    % Check if the distance is greater than the version window!
    
    if eye_plotFlag
        violation_points{NumT} = find((L>version | R>version));
        num_violoation_points(NumT) = length(violation_points{NumT});
        subplot(1,3,1); hold off;
        %             plot(1:length(L),smoothed_AIT_stim.LEyeX,'r');% Stim only
        plot(1:length(smoothed_AIT.LEyeX),smoothed_AIT.LEyeX,'r'); % Whole trial
        hold on;
        %             plot(violation_points{NumT},smoothed_AIT_stim.LEyeX(violation_points{NumT}),'ro','MarkerFaceColor','r'); % Stim only
        v = 1:length(smoothed_AIT.LEyeX);
        plot(v(AIT_stim(violation_points{NumT})),smoothed_AIT.LEyeX(AIT_stim(violation_points{NumT})),'ro','MarkerFaceColor','r'); % Whole trial
        
        %             plot(1:length(R),smoothed_AIT_stim.REyeX,'b'); % Stim only
        %             plot(violation_points{NumT},smoothed_AIT_stim.REyeX(violation_points{NumT}),'bo','MarkerFaceColor','b'); % Stim only
        plot(1:length(smoothed_AIT.REyeX),smoothed_AIT.REyeX,'b'); % Whole trial
        plot(v(AIT_stim(violation_points{NumT})),smoothed_AIT.REyeX(AIT_stim(violation_points{NumT})),'bo','MarkerFaceColor','b'); % Whole trial
        plot([AIT_stim(1),AIT_stim(1)], [min(smoothed_AIT.LEyeX), max(smoothed_AIT.LEyeX)], '--k')
        plot([AIT_stim(end),AIT_stim(end)], [min(smoothed_AIT.LEyeX), max(smoothed_AIT.LEyeX)], '--k')
        title('X');
        %             [~,s] = min(abs(TrialInfo(NumT).AITs - T.StimOn));
        %             plot([s,s],[min(smoothed_AIT.LEyeX), max(smoothed_AIT.LEyeX)],'--k');
        %             [~,f] = min(abs(TrialInfo(NumT).AITs - T.FixOn));
        %             plot([f,f],[min(smoothed_AIT.LEyeX), max(smoothed_AIT.LEyeX)],'--k');
        
        subplot(1,3,2); hold off;
        %             plot(1:length(L),smoothed_AIT_stim.LEyeY,'r');% Stim Only
        plot(1:length(smoothed_AIT.LEyeY),smoothed_AIT.LEyeY,'r'); % Whole trial
        hold on;
        %             plot(violation_points{NumT},smoothed_AIT_stim.LEyeY(violation_points{NumT}),'ro','MarkerFaceColor','r'); % Stim Only
        plot(v(AIT_stim(violation_points{NumT})),smoothed_AIT.LEyeY(AIT_stim(violation_points{NumT})),'ro','MarkerFaceColor','r'); % Whole trial
        %             plot(1:length(R),smoothed_AIT_stim.REyeY,'b'); % Stim Only
        %             plot(violation_points{NumT},smoothed_AIT_stim.REyeY(violation_points{NumT}),'bo','MarkerFaceColor','b'); % Stim only
        plot(1:length(smoothed_AIT.REyeY),smoothed_AIT.REyeY,'b'); % Whole trial
        plot(v(AIT_stim(violation_points{NumT})),smoothed_AIT.REyeY(AIT_stim(violation_points{NumT})),'bo','MarkerFaceColor','b'); % Whole trial
        
        plot([AIT_stim(1),AIT_stim(1)], [min(smoothed_AIT.LEyeY), max(smoothed_AIT.LEyeY)], '--k')
        plot([AIT_stim(end),AIT_stim(end)], [min(smoothed_AIT.LEyeY), max(smoothed_AIT.LEyeY)], '--k')
        title('Y');
        %             plot([s,s],[min(smoothed_AIT.LEyeY), max(smoothed_AIT.LEyeY)],'--k');
        %             plot([f,f],[min(smoothed_AIT.LEyeY), max(smoothed_AIT.LEyeY)],'--k');
        
        subplot(1,3,3); hold off;
        plot(smoothed_AIT_stim.LEyeX,smoothed_AIT_stim.LEyeY,'r');
        hold on;
        circ_x = 0:0.2:2*pi;
        x_units = cos(circ_x)*version;
        y_units = sin(circ_x)*version;
        plot(smoothed_AIT_stim.REyeX,smoothed_AIT_stim.REyeY,'b');
        plot(smoothed_AIT_stim.LEyeX(violation_points{NumT}),smoothed_AIT_stim.LEyeY(violation_points{NumT}),'ro','MarkerFaceColor','r');
        plot(smoothed_AIT_stim.REyeX(violation_points{NumT}),smoothed_AIT_stim.REyeY(violation_points{NumT}),'bo','MarkerFaceColor','b');
        plot(x_units,y_units,'--k');
        axis square;
        
        % Plot whole trial
        %             subplot(1,2,2); hold off;
        %             plot(1:length(TrialInfo(NumT).LEyeY),(TrialInfo(NumT).LEyeY + L_offset.y + TrialInfo(NumT).OffsetLY),'r');
        %             hold on;
        %             plot(1:length(TrialInfo(NumT).REyeY),(TrialInfo(NumT).REyeY + R_offset.y + TrialInfo(NumT).OffsetRY),'b');
        %             [~,s] = min(abs(TrialInfo(NumT).AITs - T.StimOn));
        %             lims = axis;
        %             plot([s,s],[min((TrialInfo(NumT).REyeY + R_offset.y + TrialInfo(NumT).OffsetRY)),max((TrialInfo(NumT).REyeY + R_offset.y + TrialInfo(NumT).OffsetRY))],'--k');
    end
    if any(L>version) || any(R>version)
        version_confirmed(NumT) = 0;
        version_error{NumT} = [L-version, R-version];
        
        %         disp(['Trial: ' num2str(NumT) '/' num2str(TrialNum) ': Rejected due to version violation']);
    else
        
        version_confirmed(NumT) = 1;
        version_error{NumT} = [L-version R-version];
    end
    
end
version_vergence = logical(version_confirmed & vergence_confirmed);
disp(['Total rejected trials due to version/vergence violations: ' num2str(sum(version_vergence == 0))]);
% Remove the bad trials!
TotalUnit = size(TrialInfo(1).UnitT,2);
if ~strcmp(recordingDate,'25November2020')
    TrialInfo = TrialInfo(logical(version_vergence));
else
    warning('Recording date indicates eye data should not be sorted, including all trials...')
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Data Analysis/Sorting
AnaData = TrialInfo; % Make a copy so you don't overwrite it
TrialNum = length(TrialInfo);
if length(varargin) < 4
    plotUnits = 1:TotalUnit;
end
    
max_blocks =  ceil(size(AnaData,2)/60); % This is based on a maximum of 60 trials/block!!!! %AnaData(end).EID(AnaData(end).EID>=2000 &  AnaData(end).EID<3000) - 2000; %TrialNum/trials_per_block;
 
CoherenceArray = [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22]./22;
% We added dioptic lateral motion control trials on 4/3/19
if datenum(recordingDate) < datenum(2019,04,02)
    ConditionArray = [1 2 3 4 5 6 7 8];
else
    ConditionArray = [1 2 3 4 5 6 7 8 9 10];
end

BlockOffset = 0;
TrialResp = struct; % zeros(length(ConditionNum),length(CoherenceNum),2);
TrialResp.NumTrials = zeros(length(ConditionArray),length(CoherenceArray));
TrialResp.Toward = zeros(length(ConditionArray),length(CoherenceArray));
TrialResp.Correct = zeros(length(ConditionArray),length(CoherenceArray));
NeuroResp = cell(TotalUnit,length(ConditionArray),length(CoherenceArray),max_blocks);
NeuroResp_C = nan(TotalUnit,length(ConditionArray),length(CoherenceArray),max_blocks);
NeuroResp_W = nan(TotalUnit,length(ConditionArray),length(CoherenceArray),max_blocks);
NeuroTime_C = nan(length(ConditionArray),length(CoherenceArray),max_blocks);
NeuroTime_W = nan(length(ConditionArray),length(CoherenceArray),max_blocks);
NeuroResp_Chose_T = cell(length(ConditionArray),length(CoherenceArray));
NeuroResp_Chose_A = cell(length(ConditionArray),length(CoherenceArray));
b = 1;
Block_Count(1) = 0;
invalid = [];
disp(['decoding Trial structure: ' num2str(TrialNum) 'total trials']);
for NumT = 1:TrialNum
    
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
    T.StimOff = AnaData(NumT).EventT(AnaData(NumT).EID == 130); % Technically saccade target on
    AnaData(NumT).CodedEvents(AnaData(NumT).EID == 130 & AnaData(NumT).EventT < T.End) = {"SaccOn"};
    T.StimOff = T.StimOff(T.StimOff < T.End);
    T.SaccMade = max(AnaData(NumT).EventT(AnaData(NumT).EID == 123));
    AnaData(NumT).CodedEvents(max(AnaData(NumT).EID == 123)) = {"SaccMade"};
    Event = Event(AnaData(NumT).EventT>= T.Start & AnaData(NumT).EventT<=T.End); 
    % Get pertinent stimulus information
    
    % Direction
    Direction = Event(Event>=4000 & Event<5000); % find 'direction', coded as 0 or 2 (subtract 1)
    AnaData(NumT).Direction = Direction - 4001;
    
    % Coherence
    Coherence = Event(Event>=10000 & Event<=20000); % find 'Coherence'
    AnaData(NumT).Coherence = round((Coherence-10000)*AnaData(NumT).Direction/(1*10^4),2);
    CoherenceNum = find(AnaData(NumT).Coherence == round(CoherenceArray,2));
    AnaData(NumT).CoherenceNum = CoherenceNum;
    if isempty(CoherenceNum)
        error('Coherence not found');
    end
    
    % Condition
    % 1-combined, 2-monoL, 3-monoR, 4-bino, 5-controlL, 6-controlR, 7-up, 8-down
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
        Block = size(NeuroResp,4) + 1;
        old = NeuroResp;
        NeuroResp =  cell(TotalUnit,length(ConditionArray),length(CoherenceArray),size(NeuroResp,4) + 1);
        NeuroResp(:,:,:,1:Block-1) = old; % cell(TotalUnit,length(ConditionArray),length(CoherenceArray),max_blocks);
        NeuroResp_C(:,:,:,end+1) = nan; %nan(TotalUnit,length(ConditionArray),length(CoherenceArray),max_blocks);
        NeuroResp_W(:,:,:,end+1) = nan; % nan(TotalUnit,length(ConditionArray),length(CoherenceArray),max_blocks);
        NeuroTime_C(:,:,end+1) = nan; %nan(length(ConditionArray),length(CoherenceArray),max_blocks);
        NeuroTime_W(:,:,end+1) = nan; % = nan(length(ConditionArray),length(CoherenceArray),max_blocks);
    end

    
    if isempty(T.StimOff) % No 120 signal means no saccade target
        if(AnaData(NumT).Condition == 5 || AnaData(NumT).Condition == 6 || AnaData(NumT).Condition == 9 || AnaData(NumT).Condition == 10)
            % The closest stim off signal is the 130 command, indicating
            % the last frame of the stimulus.
            T.StimOff = AnaData(NumT).EventT(AnaData(NumT).EID == 130);
        else
            error('No stimulus off (saccade target on) EID, and the condition is not a control trial');
        end
    end
    
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
            try
                AnaData(NumT).binned_data{u,:} = histcounts(bin_temp,'BinWidth', 0.01, 'BinLimits',[T.StimOn, T.SaccMade])./0.01;
            catch
                dbstop
            end
        end
    end
    AnaData(NumT).RawFR = tempSCount./tempTime;
    AnaData(NumT).Spikes = tempSCount;
    AnaData(NumT).time = tempTime;
     
    % Reward and data storage
    % YOU NEED MEAN FIRING RATES ACROSS TRIALS -- WHAT IF THE TRIAL NUMBERS ARE
    % DIFFERENT FOR A GIVEN COHERENCE AND CONDITION THOUGH?
    if AnaData(NumT).Response == 1 % completed and correct
        % We need a data mat for each condition and
        % coherence.
        TrialResp.NumTrials(ConditionNum,CoherenceNum) = TrialResp.NumTrials(ConditionNum,CoherenceNum)+1;
        TrialResp.Correct(ConditionNum,CoherenceNum) = TrialResp.Correct(ConditionNum,CoherenceNum)+1;
        if AnaData(NumT).Direction == 1
            TrialResp.Toward(ConditionNum,CoherenceNum) = TrialResp.Toward(ConditionNum,CoherenceNum) + 1;
            NeuroResp_Chose_T{ConditionNum,CoherenceNum} = [NeuroResp_Chose_T{ConditionNum,CoherenceNum}, tempSCount'./tempTime]; % If correct and direction was 1, chose towards
            AnaData(NumT).Choice = 'T';
        else
            NeuroResp_Chose_A{ConditionNum,CoherenceNum} = [NeuroResp_Chose_A{ConditionNum,CoherenceNum}, tempSCount'./tempTime]; % If correct and direction was -1, chose away
            AnaData(NumT).Choice = 'A';
        end
%         if ~isnan(NeuroTime_C(ConditionNum,CoherenceNum,Block)) || Block_Count(b) >= trials_per_block
%            b = b+1;
% %            Block_Count(b) = 0;
%         end
%         Block_Count(b) =  Block_Count(b) + 1;
        if ~isnan(NeuroResp_C(1,ConditionNum,CoherenceNum,Block)) || ~isnan(NeuroResp_W(1,ConditionNum,CoherenceNum,Block))
            warning('You have multiple trials for the same condition/block')
        end
        NeuroResp_C(:,ConditionNum,CoherenceNum,Block) = tempSCount'./tempTime; %nansum([NeuroResp_C(:,ConditionNum,CoherenceNum,Block), tempSCount'],2);
        NeuroTime_C(ConditionNum,CoherenceNum,Block) = tempTime; %nansum([NeuroTime_C(ConditionNum,CoherenceNum,Block),tempTime]);
    elseif AnaData(NumT).Response == 0 % completed and wrong
        TrialResp.NumTrials(ConditionNum,CoherenceNum) = TrialResp.NumTrials(ConditionNum,CoherenceNum)+1;
        if AnaData(NumT).Direction == -1
            TrialResp.Toward(ConditionNum,CoherenceNum) = TrialResp.Toward(ConditionNum,CoherenceNum) + 1;
            NeuroResp_Chose_T{ConditionNum,CoherenceNum} = [NeuroResp_Chose_T{ConditionNum,CoherenceNum}, tempSCount'./tempTime]; % If wrong and direction was -1, chose towards
            AnaData(NumT).Choice = 'T';
        else
            NeuroResp_Chose_A{ConditionNum,CoherenceNum} = [NeuroResp_Chose_A{ConditionNum,CoherenceNum}, tempSCount'./tempTime]; % If wrong and direction was 1, chose away
            AnaData(NumT).Choice = 'A';
        end
%         if ~isnan(NeuroTime_W(ConditionNum,CoherenceNum,Block)) ||  Block_Count(b) >= trials_per_block
%             b = b+1;
% %             Block_Count(b) = 0;
%         end
%         Block_Count(b) =  Block_Count(b) + 1;
        if ~isnan(NeuroResp_C(1,ConditionNum,CoherenceNum,Block)) || ~isnan(NeuroResp_W(1,ConditionNum,CoherenceNum,Block))
            warning('You have multiple trials for the same condition/block')
        end
        NeuroResp_W(:,ConditionNum,CoherenceNum,Block) = tempSCount'./tempTime; %tempSCount'; %nansum([NeuroResp_W(:,ConditionNum,CoherenceNum,Block),tempSCount'],2);
        NeuroTime_W(ConditionNum,CoherenceNum,Block) = tempTime; %nansum([NeuroTime_W(ConditionNum,CoherenceNum,Block),tempTime]);
    elseif isempty(AnaData(NumT).Response) && (AnaData(NumT).Condition == 5 || AnaData(NumT).Condition == 6 || AnaData(NumT).Condition == 9 || AnaData(NumT).Condition == 10) % Control trials have no response, place them in the "correct" matrix
%         if ~isnan(NeuroTime_C(ConditionNum,CoherenceNum,Block)) ||  Block_Count(b) >= trials_per_block
%              b = b+1;
% %              Block_Count(b) = 0;
%         end
%         Block_Count(b) =  Block_Count(b) + 1;
        if ~isnan(NeuroResp_C(1,ConditionNum,CoherenceNum,Block)) || ~isnan(NeuroResp_W(1,ConditionNum,CoherenceNum,Block))
            warning('You have multiple trials for the same condition/block')
        end
        NeuroResp_C(:,ConditionNum,CoherenceNum,Block) = tempSCount'./tempTime; % nansum([NeuroResp_C(:,ConditionNum,CoherenceNum,Block),tempSCount'],2);
        NeuroTime_C(ConditionNum,CoherenceNum,Block) = tempTime; %nansum([NeuroTime_C(ConditionNum,CoherenceNum,Block),tempTime]);
    else
        warning('No Response EID, and the condition is not a control trial, removing trial');
        invalid = [NumT, invalid];
        continue
    end
    if isnan(NeuroResp_C(2,ConditionNum,CoherenceNum,Block)) && isnan(NeuroResp_W(2,ConditionNum,CoherenceNum,Block))
        error('No response recorded for this trial');
    end
    if isnan(NeuroTime_C(ConditionNum,CoherenceNum,Block)) && isnan(NeuroTime_W(ConditionNum,CoherenceNum,Block))
        error('No response recorded for this trial');
    end
    %     if ~isnan(NeuroResp(1,ConditionNum,CoherenceNum,Block))
    for n = 1:size(NeuroResp,1) 
        NeuroResp{n,ConditionNum,CoherenceNum,Block} =  [NeuroResp{n,ConditionNum,CoherenceNum,Block}, tempSCount(n)./tempTime];
    end
%     else
%         NeuroResp{:,ConditionNum,CoherenceNum,Block} =  tempSCount'./tempTime;
%     end
    % We can build a towards and away response matrix from this pretty
    % easily, the only issue is the 0% coherence. We must specifiy the
    % towards and away responses at 0 %
    BehaviorData(NumT).Choice = AnaData(NumT).Choice;
    BehaviorData(NumT).ConditionNum = ConditionNum;
    BehaviorData(NumT).CoherenceNum = CoherenceNum;
    BehaviorData(NumT).Block = Block;
end
AnaData(invalid) = [];

if any(any(TrialResp.NumTrials(1:4,:) < 14))
    warning('YOU HAVE LESS THAN 14 TRIALS FOR SOME CONDITIONS/COHERENCES, PLEASE CHECK THIS DATA!!!');
end
repeat_check = cellfun(@numel,NeuroResp);
if any(repeat_check(:)>1)
    warning('You have multiple trials for the same condition/block')
end
NeuroResp = cellfun(@nanmean, NeuroResp);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Generate psychometric curves
fit_psychometric = 1;
if fit_psychometric
%     options.useGPU = 0;
%     options.borders = nan(5,2);
%     options.borders(1,:) = [-1,1];
%     options.borders(2,:) = [0.1,5];
    
    %%%%%%%%%%%%%%%%%%%%%%%%%
    % Parameters from behavioral data collection before recording:
    options.sigmoidName = 'norm'; % norm cdf fit
    %options.estimateType = 'MAP';
    options.fixedPars = NaN(5,1);
    %options.fixedPars(3:4) = 0.00001; % Fix the upper and lower asymptotes\
    options.expType = 'equalAsymptote'; %'YesNo';%'equalAsymptote';
    
    % Provide prior on width
    lowerBound = 2;
    priorWidth = @(x) (x>0&x<=lowerBound).*(1-cos(pi.*x./lowerBound)) + (x>lowerBound&x<=100).*2; % raised cosine
    options.priors{2} = priorWidth;
    options.borders = nan(5,2);
    options.borders(3,:)=[0,.001]; % upper range of lapse rate
    options.borders(4,:)=[0,.001]; % lower range of lapse rate
    %%%%%%%%%%%%%%%%%%%%%%%%%
    
    % figure(1);
    for cond = 1:4
        pfitMat(:,:,cond) = [CoherenceArray', TrialResp.Toward(cond,:)',TrialResp.NumTrials(cond,:)'];
        %     pfitMat(find(pfitMat(:,3,cond) == 0),3,cond) = 1; % Need at least 1 lapse?
        try
            temp_pFit(cond) = psignifit(pfitMat(:,:,cond),options);
            pFitVals(:,cond) = getStandardParameters(temp_pFit(cond),'gauss');
            %         plotOptions.dataColor = colorsteps(cond,:);
            %         plotOptions.lineColor = colorsteps(cond,:);
            %         pfitPlot(cond) = plotPsych(temp_pFit(cond),plotOptions);
            %         if cond == 1
            %             hold on;
            %         end
        catch e
            fprintf(2,'The identifier was:\n%s', e.identifier);
            pFitVals(:,cond) = [NaN NaN NaN NaN];
        end
    end
else
    pFitVals = nan(5,4);
end
    
    
% line(xRange, ones(length(xRange),1)*0.5,'LineStyle','--','Color',[0.6 0.6 0.6]);
% line(zeros(length(xRange),1),[0:0.5:100],'LineStyle','--','Color',[0.6 0.6 0.6]);
% xlabel('Coherence');
% ylabel('Proportion Chose Towards');
% hold off;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Generate mean and SEM firing rate regardless of whether the response was
% correct or wrong
nan_c = isnan(NeuroResp_C);
nan_w = isnan(NeuroResp_W);
both_nans = find(isnan(NeuroResp_C) & isnan(NeuroResp_W));
tmp_c = NeuroResp_C;
tmp_c(nan_c) = 0;
tmp_w = NeuroResp_W;
tmp_w(nan_w) = 0;
FR_by_block = plus(tmp_c, tmp_w);
FR_by_block(both_nans) = NaN;

saccade_only_trials = [squeeze(FR_by_block(:,7,1,:)), squeeze(FR_by_block(:,8,end,:))];
baseline_mean_FR = nanmean(saccade_only_trials,2);
mean_FR = nanmean(FR_by_block,length(size(FR_by_block)));
sd_FR = nanstd(FR_by_block,0,length(size(FR_by_block)));
repetitions = sum(~isnan(FR_by_block),length(size(FR_by_block)));
sem_FR = sd_FR./sqrt(repetitions);

AnaData_ByStim.mean_NeuroResp_Chose_T = cellfun(@(x) mean(x,2), NeuroResp_Chose_T,'UniformOutput',false);
AnaData_ByStim.mean_NeuroResp_Chose_A = cellfun(@(x) mean(x,2), NeuroResp_Chose_A,'UniformOutput',false);
std_NeuroResp_Chose_T = cellfun(@(x) std(x,0,2), NeuroResp_Chose_T,'UniformOutput',false);
std_NeuroResp_Chose_A = cellfun(@(x) std(x,0,2), NeuroResp_Chose_A,'UniformOutput',false);
trials_NeuroResp_Chose_T = cellfun(@(x) size(x,2), NeuroResp_Chose_T,'UniformOutput',false);
trials_NeuroResp_Chose_A = cellfun(@(x) size(x,2), NeuroResp_Chose_A,'UniformOutput',false);
sem_NeuroResp_Chose_T =  cellfun(@(x) std_NeuroResp_Chose_T{x}/trials_NeuroResp_Chose_T{x}, num2cell(1:numel(trials_NeuroResp_Chose_T)),'UniformOutput',false);
sem_NeuroResp_Chose_A = cellfun(@(x) std_NeuroResp_Chose_A{x}/trials_NeuroResp_Chose_A{x}, num2cell(1:numel(trials_NeuroResp_Chose_A)),'UniformOutput',false);
AnaData_ByStim.sem_NeuroResp_Chose_T = reshape(sem_NeuroResp_Chose_T,size(trials_NeuroResp_Chose_T));
AnaData_ByStim.sem_NeuroResp_Chose_A = reshape(sem_NeuroResp_Chose_A,size(trials_NeuroResp_Chose_A));
AnaData_ByStim.NeuroResp_C= NeuroResp_C;
AnaData_ByStim.NeuroResp_W = NeuroResp_W;
AnaData_ByStim.NeuroResp_Chose_T = NeuroResp_Chose_T;
AnaData_ByStim.NeuroResp_Chose_A = NeuroResp_Chose_A;
AnaData_ByStim.mean_FR = mean_FR;
AnaData_ByStim.sem_FR = sem_FR;
AnaData_ByStim.baseline = baseline_mean_FR;
AnaData_ByStim.pFit = pFitVals;
AnaData_ByStim.pFitOut = temp_pFit;
AnaData_ByStim.NeuroResp = NeuroResp;
AnaData_ByStim.Trial_Resp = TrialResp;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Modeling
opts1=  optimset('display','off');
for u = 1:TotalUnit
    % Invariance calculations across cue conditions
    % 1) Singular Value Decomposition to look at "separability"
    % Calculate correlations of predicted vs observed as well
    % 2) Correlations across cue conditions?
    condition_matrix = squeeze(mean_FR(u,1:4,:))';
    [U,S,V] = svd(condition_matrix);
    svd_pred = S(1)*U(:,1)*V(:,1)';
    AnaData_ByStim.element_svd_corr(u) = corr(condition_matrix(:), svd_pred(:));
    AnaData_ByStim.condition_svd_corr(u,:) = diag(corr(condition_matrix, svd_pred)); % by condition
    AnaData_ByStim.mean_condition_svd_corr(u) = mean(AnaData_ByStim.condition_svd_corr(u,:));
    AnaData_ByStim.separability(u) = max(diag(S))/sum(diag(S));
    
    % just correlation of tuning curves
    UT = logical(triu(ones(size(corr(condition_matrix))),1)); % upper triangle
    condition_corr = corr(condition_matrix);
    AnaData_ByStim.mean_condition_corr(u) = mean(condition_corr(UT));
    
    % Linear models against coherence for each condition
    for cond = 1:4
        resp = squeeze(NeuroResp(u,cond,:,:));
        labels = repmat(CoherenceArray,size(NeuroResp,ndims(NeuroResp)),1)';
        lm_tb = array2table([resp(:), labels(:)],'VariableNames',{'FR','Coherence'});
        fit = fitlm(lm_tb,'FR~Coherence');
        AnaData_ByStim.lmfit_slope(u,cond) = fit.Coefficients.Estimate(2);
        AnaData_ByStim.lmfit_p(u,cond) = fit.Coefficients.pValue(2);
        AnaData_ByStim.lmfit_sig(u,cond) = AnaData_ByStim.lmfit_p(u,cond) < 0.05;
    end
    % linear model comparing responses in the two eyes
    resp = squeeze(NeuroResp(u,2:3,:,:));
    coh = repmat(CoherenceArray,size(resp,1),1,size(resp,3));
    eye = repmat([-0.5;0.5],1,size(resp,2),size(resp,3));
    lm_tb = array2table([resp(:), coh(:), eye(:)],'VariableNames',{'FR','Coherence','Eye'});
    fit = fitlm(lm_tb,'FR~Coherence*Eye');
    AnaData_ByStim.eye_lmfit_slope(u,:) = fit.Coefficients.Estimate(:);
    AnaData_ByStim.eye_lmfit_p(u,:) = fit.Coefficients.pValue(:);
    AnaData_ByStim.eye_lmfit_sig(u,:) = AnaData_ByStim.lmfit_p(u,:) < 0.05;
    
    sum_mono(u,:) = squeeze(mean_FR(u,2,:)) + squeeze(mean_FR(u,3,:));
    
    % Linear combination based on Ocular dominance
    OD = mean(squeeze(mean_FR(u,2,:))./squeeze(mean_FR(u,3,:)));
    if OD >1
        weighted_mono_OD(u,:) = (1-1/OD).*squeeze(mean_FR(u,2,:)) + (1/OD).*squeeze(mean_FR(u,3,:));
    else
        weighted_mono_OD(u,:) = OD.*squeeze(mean_FR(u,2,:)) + (1-OD).*squeeze(mean_FR(u,3,:));
    end
    
    % 
    
    % Weighted combination of monocular signals
    mono_fit = @(w) w(1).*squeeze(mean_FR(u,2,:)) + w(2).*squeeze(mean_FR(u,3,:)) - squeeze(mean_FR(u,1,:));
    w_mono(u,:) = lsqnonlin(mono_fit,[0.5,0.5],[0,0],[100,100],opts1);
    weighted_mono(u,:) = w_mono(u,1).*squeeze(mean_FR(u,2,:)) + w_mono(u,2).*squeeze(mean_FR(u,3,:));
    
    % Can we use the same weights on control trials to predict binocular
    % 100% coherence trials?
    weighted_control(u,:) = w_mono(u,1).*squeeze(mean_FR(u,5,[1,end])) + w_mono(u,2).*squeeze(mean_FR(u,6,[1,end]));
    
    % Weighted combination of all cues
    weighted_all_fit = @(w) ((w(1).*squeeze(mean_FR(u,2,:)) + w(2).*squeeze(mean_FR(u,3,:)) + w(3).*squeeze(mean_FR(u,4,:))) - squeeze(mean_FR(u,1,:)));
    w_all(u,:) = lsqnonlin(weighted_all_fit,[0.3,0.3,0.3],[0,0,0],[100,100,100],opts1);
    weighted_all(u,:) = (w_all(u,1).*squeeze(mean_FR(u,2,:)) + w_all(u,2).*squeeze(mean_FR(u,3,:)) + w_all(u,3).*squeeze(mean_FR(u,4,:)));
    
    % Divisive normalization of monocular signals
    div_mono(u,:) = (squeeze(mean_FR(u,2,:)).^2 + squeeze(mean_FR(u,3,:)).^2)./(squeeze(mean_FR(u,2,:)) + squeeze(mean_FR(u,3,:)));
    div_control(u,:) = (squeeze(mean_FR(u,5,[1,end])).^2 + squeeze(mean_FR(u,6,[1,end])).^2)./(squeeze(mean_FR(u,5,[1,end])) + squeeze(mean_FR(u,6,[1,end])));
    
    % Divisive normalization of monocular signals w/weights
    div_mono_weighted_fit = @(w) (w(1).*squeeze(mean_FR(u,2,:)).^2 + w(2).*squeeze(mean_FR(u,3,:)).^2)./(w(1).*squeeze(mean_FR(u,2,:)) + w(2).*squeeze(mean_FR(u,3,:))) - squeeze(mean_FR(u,1,:));
    try
        w_div_mono(u,:) = lsqnonlin(div_mono_weighted_fit,[0.5,0.5],[0,0],[100,100],opts1);
    catch
        warning('Unable to fit weighted div norm monocular model');
        w_div_mono(u,:) = [0.5,0.5];
    end
    div_mono_weighted(u,:) = (w_div_mono(u,1).*squeeze(mean_FR(u,2,:)).^2 + w_div_mono(u,2).*squeeze(mean_FR(u,3,:)).^2)./(w_div_mono(u,1).*squeeze(mean_FR(u,2,:)) + w_div_mono(u,2).*squeeze(mean_FR(u,3,:)));
    div_control_weighted(u,:) = (w_div_mono(u,1).*squeeze(mean_FR(u,5,[1,end])).^2 + w_div_mono(u,2).*squeeze(mean_FR(u,6,[1,end])).^2)./(w_div_mono(u,1).*squeeze(mean_FR(u,5,[1,end])) + w_div_mono(u,2).*squeeze(mean_FR(u,6,[1,end])));
    
    % Divisive normalization of monocular signals plus independent stereo w/weights
    div_mono_stereo_weighted_fit = @(w) ((w(1).*squeeze(mean_FR(u,2,:)).^2 + w(2).*squeeze(mean_FR(u,3,:)).^2)./(w(1).*squeeze(mean_FR(u,2,:)) + w(2).*squeeze(mean_FR(u,3,:))) + w(3).*squeeze(mean_FR(u,4,:))) - squeeze(mean_FR(u,1,:));
    try
        w_div_mono_stereo(u,:) = lsqnonlin(div_mono_stereo_weighted_fit,[0.5,0.5,0.5],[0,0,0],[100,100,100],opts1);
    catch
        warning('Unable to fit weighted div norm monocular plus stereo model');
        w_div_mono_stereo(u,:) = [0.5,0.5, 0.5];
    end
    div_mono_stereo_weighted(u,:) = (w_div_mono(u,1).*squeeze(mean_FR(u,2,:)).^2 + w_div_mono(u,2).*squeeze(mean_FR(u,3,:)).^2)./(w_div_mono(u,1).*squeeze(mean_FR(u,2,:)) + w_div_mono(u,2).*squeeze(mean_FR(u,3,:)));
    
    % Divisive normalization of monocular signals (no weights) + independent stereo
    two_pop(u,:) = ((squeeze(mean_FR(u,2,:)).^2 + squeeze(mean_FR(u,3,:)).^2)./(squeeze(mean_FR(u,2,:)) + squeeze(mean_FR(u,3,:)))) + squeeze(mean_FR(u,4,:));
    
    % Divisive normalization of the 3 signals (weighted average)
    one_pop(u,:) = (squeeze(mean_FR(u,2,:)).^2 + squeeze(mean_FR(u,3,:)).^2 + squeeze(mean_FR(u,4,:)).^2)./(squeeze(mean_FR(u,2,:)) + squeeze(mean_FR(u,3,:)) + squeeze(mean_FR(u,4,:)));
    
    
    model_errors(u).sum_mono = (sum_mono(u,:)' - squeeze(mean_FR(u,1,:)));
    model_errors(u).weighted_mono_OD = (weighted_mono_OD(u,:)' - squeeze(mean_FR(u,1,:)));
    model_errors(u).weighted_mono = (weighted_mono(u,:)' - squeeze(mean_FR(u,1,:)));
    model_errors(u).weighted_all = (weighted_all(u,:)' - squeeze(mean_FR(u,1,:)));    
    model_errors(u).div_mono_weighted = (div_mono_weighted(u,:)' - squeeze(mean_FR(u,1,:)));    
    model_errors(u).div_mono = (div_mono(u,:)' - squeeze(mean_FR(u,1,:)));
    model_errors(u).two_pop = (two_pop(u,:)' - squeeze(mean_FR(u,1,:)));
    model_errors(u).one_pop = (one_pop(u,:)' - squeeze(mean_FR(u,1,:)));
    model_errors(u).weighted_control = (weighted_control(u,:)' - squeeze(mean_FR(u,4,[1,end])));
    model_errors(u).weighted_control = [model_errors(u).weighted_control; nan(11,1)];
    model_errors(u).div_control = (div_control(u,:)' - squeeze(mean_FR(u,4,[1,end])));
    model_errors(u).div_control = [model_errors(u).div_control; nan(11,1)];
    model_errors(u).div_control_weighted = (div_control_weighted(u,:)' - squeeze(mean_FR(u,4,[1,end])));
    model_errors(u).div_control_weighted = [model_errors(u).div_control_weighted; nan(11,1)];
    model_weights(u,:).weighted_mono = w_mono(u,:);
    model_weights(u,:).weighted_all = w_all(u,:);
    model_weights(u,:).div_mono_weighted = w_div_mono(u,:);
    model_weights(u,:).div_mono_stereo_weighted = w_div_mono_stereo(u,:);
end
AnaData_ByStim.div_mono = div_mono;
AnaData_ByStim.div_mono_weighted = div_mono_weighted;
AnaData_ByStim.two_pop = two_pop;
AnaData_ByStim.one_pop = one_pop;
AnaData_ByStim.weighted_mono = weighted_mono;
AnaData_ByStim.weighted_all = weighted_all;
AnaData_ByStim.div_mono_stereo_weighted = div_mono_stereo_weighted;
AnaData_ByStim.ModelErrors = model_errors;
AnaData_ByStim.ModelWeights = model_weights;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Generate neurometric curves
if plotFlag
    for u = 1:length(plotUnits)
        unit_num = plotUnits(u);
        
        if any(ishandle(fig_handle)) && length(plotUnits)==1
            ax = fig_handle;
            hold(ax,'on');
        else
            fig_handle = figure; hold on;
            ax = gca;
        end
        
        %     line(xRange, ones(length(xRange),1)*0.5,'LineStyle','--','Color',[0.6 0.6 0.6]);
        
        plotConditionIdx = 1:4;
        plotConditionNames = {'Combined', 'L Mono', 'R Mono', 'Stereo'};
        p = gobjects(1, numel(plotConditionIdx));

        for plotIdx = 1:numel(plotConditionIdx)
            cond = plotConditionIdx(plotIdx);
            xVals = CoherenceArray';
            yVals = squeeze(mean_FR(unit_num,cond,:))';
            yErr = squeeze(sem_FR(unit_num,cond,:))';

            if baselineSubtract
                yVals = yVals - baseline_mean_FR(unit_num);
            end

            fill(ax, [xVals; flipud(xVals)], ...
                [yVals + yErr, fliplr(yVals - yErr)]', ...
                colorsteps(cond,:), ...
                'FaceAlpha', 0.2, ...
                'EdgeColor', 'none', ...
                'HandleVisibility', 'off');

            p(plotIdx) = plot(ax, xVals, yVals, '-', ...
                'Color', [colorsteps(cond,:), 0.8], ...
                'LineWidth', subplotLineWidth, ...
                'Marker', 'none');
        end

        if ~baselineSubtract
            plot(ax,[-1,1], [baseline_mean_FR(unit_num),baseline_mean_FR(unit_num)], '--k');
        end
        
        ylim('auto');
        xlim(ax, [-1, 1]);
        xticks(ax, [-1, -0.5, 0, 0.5, 1]);
        if any(contains(file_names, 'TT'))
            tetrode = extractBetween(file_names{1},'TT','_');
            title(ax,{[string(recordingDate) + ' : TT '+ string(tetrode)], [' Unit ', num2str(unit_num)]});
        else
            title(ax,[recordingDate, ' : ', 'Unit ', num2str(unit_num)]);
        end
        xlabel(ax,'Coherence');
        ylabel(ax,'Firing Rate');
        legend(ax, p, plotConditionNames, 'Location', 'eastoutside')
        axis square;
        box(ax, 'off');
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Calculate SDF for Choice Analysis
% [raw_SDF, mean_SDF, mean_SDF_time, zscore_SDF, zscore_SDF_time]
Zero_Coh_Ind = find([AnaData.Coherence]==0); % Get all trials where coherence was 0%
Saccade = find([AnaData.Condition]==7 | [AnaData.Condition]==8); % Get all saccade only trials. 7 is away. 8 is towards

[~, AnaData_ByStim.mean_SDF_Zero, ~, AnaData_ByStim.zscore_SDF_Zero, AnaData_ByStim.zscore_SDF_Zero_Time] = getSDF(AnaData(Zero_Coh_Ind),118,130,1:TotalUnit);
AnaData_ByStim.mean_zscore_SDF_Towards = mean(AnaData_ByStim.zscore_SDF_Zero([AnaData(Zero_Coh_Ind).Response] == 1,:,:),1);
AnaData_ByStim.mean_zscore_SDF_Away = mean(AnaData_ByStim.zscore_SDF_Zero([AnaData(Zero_Coh_Ind).Response] == 0,:,:),1);
AnaData_ByStim.mean_zscore_SDF_Time_Towards = mean(AnaData_ByStim.zscore_SDF_Zero_Time([AnaData(Zero_Coh_Ind).Response] == 1,:,:),1);
AnaData_ByStim.mean_zscore_SDF_Time_Away = mean(AnaData_ByStim.zscore_SDF_Zero_Time([AnaData(Zero_Coh_Ind).Response] == 0,:,:),1);
[~, AnaData_ByStim.mean_SDF_Towards, ~] = getSDF(AnaData([AnaData(Zero_Coh_Ind).Response] == 1),118,130,1:TotalUnit);
[~, AnaData_ByStim.mean_SDF_Away, ~] = getSDF(AnaData([AnaData(Zero_Coh_Ind).Response] == 0),118,130,1:TotalUnit);

[~, AnaData_ByStim.mean_SDF_Saccade, ~, AnaData_ByStim.zscore_SDF_Saccade, AnaData_ByStim.zscore_SDF_Saccade_Time] = getSDF(AnaData(Saccade),118,130,1:TotalUnit);
AnaData_ByStim.mean_zscore_SDF_Saccade_Towards = mean(AnaData_ByStim.zscore_SDF_Saccade([AnaData(Saccade).Condition] == 8,:,:),1);
AnaData_ByStim.mean_zscore_SDF_Saccade_Away = mean(AnaData_ByStim.zscore_SDF_Saccade([AnaData(Saccade).Condition] == 7,:,:),1);
AnaData_ByStim.mean_zscore_SDF_Time_Saccade_Towards = mean(AnaData_ByStim.zscore_SDF_Saccade_Time([AnaData(Saccade).Condition] == 8,:,:),1);
AnaData_ByStim.mean_zscore_SDF_Time_Saccade_Away = mean(AnaData_ByStim.zscore_SDF_Saccade_Time([AnaData(Saccade).Condition] == 7,:,:),1);

% Extract your SDFs broken up by saccade up and down trials as well, with
% no stimulus

% Optional plots
% If there is a phasic effect here, you should see changes in your CP analysis if
% you bin it over time
%figure; hold on; plot(squeeze(AnaData_ByStim.mean_zscore_SDF_Towards(1,1:length(plotUnits),:)),'-r'); plot(squeeze(AnaData_ByStim.mean_zscore_SDF_Away(1,1:length(plotUnits),:)),'-b')

%figure; hold on; plot(squeeze(AnaData_ByStim.mean_zscore_SDF_Time_Towards(1,1:length(plotUnits),:)),'-r'); plot(squeeze(AnaData_ByStim.mean_zscore_SDF_Time_Away(1,1:length(plotUnits),:)),'-b')

end

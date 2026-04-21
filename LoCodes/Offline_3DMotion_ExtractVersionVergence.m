function [TrialInfo] = Offline_3DMotion_ExtractVersionVergence(varargin)
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
date = datestr(datenum(recordingDate),'mm_dd_yy');
date = [date, '_00_00_00'];
savePath = 'P:\Jim\EyeData\JNeuroData\';

% Clay_09_10_20_09_39_34
SaveName = [savePath 'Jim_' date '_Eyes_Trials.mat'];
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
    T.StimOn = TrialInfo(NumT).EventT(TrialInfo(NumT).EID == 118 & TrialInfo(NumT).EventT < T.End);
    T.StimOff = TrialInfo(NumT).EventT(TrialInfo(NumT).EID == 130); % Technically 2 frames left
    T.StimOff = T.StimOff(T.StimOff < T.End);
    T.SaccMade = TrialInfo(NumT).EventT(TrialInfo(NumT).EID == 123);
    
    Event = Event(TrialInfo(NumT).EventT >= T.Start & TrialInfo(NumT).EventT < T.End);
    % Condition
    Condition = Event(Event>=8000 & Event<9000);
    TrialInfo(NumT).Condition = Condition - 8000;
    EyeInfo(NumT).Condition = TrialInfo(NumT).Condition;
    
    % Direction
    Direction = Event(Event>=4000 & Event<5000); % find 'direction', coded as 0 or 2 (subtract 1)
    TrialInfo(NumT).Direction = Direction - 4001;
    EyeInfo(NumT).Direction = TrialInfo(NumT).Direction;
    
    % Coherence
    Coherence = Event(Event>=10000 & Event<=20000); % find 'Coherence'
    if isempty(Coherence)
        vergence_confirmed(NumT) = 0;
        EyeInfo(NumT).version_confirmed = 0;
        EyeInfo(NumT).Valid = 0;
        continue
    end
    TrialInfo(NumT).Coherence = round((Coherence-10000)*TrialInfo(NumT).Direction/(1*10^4),2);
    EyeInfo(NumT).Coherence = TrialInfo(NumT).Coherence;
    
    % Check if trial has valid eye movement and stim data
    if isempty(T.FixOn) || isempty(T.StimOn) || isempty(T.StimOff) || isempty(T.SaccMade)
        vergence_confirmed(NumT) = 0;
        EyeInfo(NumT).version_confirmed = 0;
        EyeInfo(NumT).Valid = 0;
        continue
    end
    EyeInfo(NumT).Valid = 1;
    
    AIT_fix = find(TrialInfo(NumT).AITs >= T.FixOn & TrialInfo(NumT).AITs <= T.StimOn); % Analog index where time is only during fixation period
%     AIT_stim = AIT_fix;
        AIT_stim = find(TrialInfo(NumT).AITs >= T.FixOn & TrialInfo(NumT).AITs <= T.StimOff); % Analog index where time is equal to stim on
    
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
        
        if any(abs(vergenceDiffX{NumT}) > 0.5)
            vergence_confirmed(NumT) = 0;
        else
            vergence_confirmed(NumT) = 1;
        end
        
    end
    
    Response = Event(Event>=6000 & Event<7000);
    EyeInfo(NumT).Response = Response - 6000;
    
    if EyeInfo(NumT).Direction == 1
        EyeInfo(NumT).Towards = EyeInfo(NumT).Response; % correct is towards
    else
        EyeInfo(NumT).Towards = ~EyeInfo(NumT).Response; % incorrect is towards
    end
    EyeInfo(NumT).Vergence = vergenceDiffX{NumT};
    
    if any(L>version) || any(R>version)
        EyeInfo(NumT).version_confirmed = 0;
        version_error{NumT} = [L-version, R-version];
        
        %         disp(['Trial: ' num2str(NumT) '/' num2str(TrialNum) ': Rejected due to version violation']);
    else
        
        EyeInfo(NumT).version_confirmed = 1;
        version_error{NumT} = [L-version R-version];
    end
    
end
version_vergence = logical(extractfield(EyeInfo,'version_confirmed') & vergence_confirmed);
disp(['Total rejected trials due to version/vergence violations: ' num2str(sum(version_vergence == 0))]);
% Remove the bad trials!
if ~strcmp(recordingDate,'25November2020')
    EyeInfo = EyeInfo(logical(version_vergence));
else
    warning('Recording date indicates eye data should not be sorted, including all trials...')
end

TrialInfo = struct2table(EyeInfo);
% save(SaveName,'TrialInfo','savePath','NumT', '-v7.3');

end
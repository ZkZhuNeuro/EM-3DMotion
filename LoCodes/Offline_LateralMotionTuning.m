function LateralMotionData = Offline_LateralMotionTuning(varargin)
if length(varargin)<2
    warning('not enought input parameters, select files manually');
    [file_names, pathname] = uigetfile({'*_LateralMotion*.mat' }, 'Select Files',pwd, 'MultiSelect', 'on');
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
        plotFlag_von = 0;
    else
        error('Too many files selected, please select a TInfo file and optional SellIndex file');
    end
    fig_handle = [];
    fig_handle2 = [];
elseif length(varargin)==2 || length(varargin)== 3 || length(varargin) >= 4
    pathname = varargin{1};
    file_names = varargin{2};
    if length(varargin)>= 3
        plotFlag = varargin{3};
        if length(varargin) >= 4
            plotUnits = varargin{4};
        end
        if length(varargin) == 5 || length(varargin) == 6
            fig_handle = varargin{5};
            if length(varargin) == 6
                fig_handle2 = varargin{6};
            end
        else 
            fig_handle = [];
            fig_handle2 = [];
        end
    else
        fig_handle = [];
        fig_handle2 = [];
        plotFlag = 0;
    end
    plotFlag_von = 0;
    TrialInfo_file = load(string(fullfile(pathname,file_names{~contains(file_names, 'SelIndex')})));
    TrialInfo = TrialInfo_file.TrialInfo;
    SelectionInfo_file = load(string(fullfile(pathname,file_names{contains(file_names, 'SelIndex')})));
    Config = SelectionInfo_file.Config;
    SelectionInfo = logical(SelectionInfo_file.EditSel);
    TrialInfo = TrialInfo(SelectionInfo); % Only look at selected trials
end
filename_base = extractBefore(file_names{1},'Lateral');
DashIdx = strfind(filename_base, '_');
FNameIdx = strfind(filename_base, 'TT');
DateIdx = strfind(filename_base, '201');
if isempty(DateIdx)
    DateIdx = strfind(filename_base, '202');
end
recordingDate = filename_base(DashIdx(find(DashIdx < DateIdx,1,'last'))+1:DashIdx(find(DashIdx > DateIdx,1,'first'))-1);
%% Offline Lateral Motion Tuning Analysis
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

colorsteps = [0 0 1;...
    0 0.7 1;...
    1 0.15 0];
eyeLabels = [{'Left'},{'Right'},{'Both'}];
options = optimset('Display','off');
%% Initial Eye Checking
% Ensure that the monkey did not break fixation while the stimulus was on.
% GUI does not always catch this.
TrialNum = length(TrialInfo);
version = tand(1)*Config.ScrDistmm;
smoothBin = 25;
eye_plotFlag = 0;
disp('Checking fixation data...');
% if plotFlag
%     figure; hold on;
% end
for NumT = 1:TrialNum
    % measure initial fixation
    FixOn = TrialInfo(NumT).EventT(TrialInfo(NumT).EID == 114);
    StimOn = TrialInfo(NumT).EventT(TrialInfo(NumT).EID == 118);
    StimOff = TrialInfo(NumT).EventT(TrialInfo(NumT).EID == 120);
    T.End = min(TrialInfo(NumT).EventT(TrialInfo(NumT).EID == 112));
    
    if length(FixOn) ~= 1 || length(StimOn) ~=1 || length(StimOff) ~= 1
        warning(['Trial ' num2str(NumT) 'has multiple stimulus onset and offset values, skipping for now...']);
        version_confirmed(NumT) = 0;
        continue
    end
    
    AIT_fix = find(TrialInfo(NumT).AITs >= FixOn & TrialInfo(NumT).AITs <= StimOn); % Analog index where time is only during fixation period
    AIT_stim = find(TrialInfo(NumT).AITs >= StimOn & TrialInfo(NumT).AITs <= StimOff); % Analog index where time is equal to stim on
    
    if datenum(recordingDate) > datenum(2019,04,03) % Added offset from GUI to MATLAB and then to Rippleon this date
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
        
        L = sqrt((smoothed_AIT_stim.LEyeX).^2 + (smoothed_AIT_stim.LEyeY).^2);
        R = sqrt((smoothed_AIT_stim.REyeX).^2 + (smoothed_AIT_stim.REyeY).^2);
        
        % OLD METHOD BEFORE SENDING OFFSET FROM GUI
    else
        % Calculate an average fixation position during the initial fixation
        % holding phase for each eye and axis:
        L_offset.x = mean(TrialInfo(NumT).LEyeX(AIT_fix));
        L_offset.y = mean(TrialInfo(NumT).LEyeY(AIT_fix));
        R_offset.x = mean(TrialInfo(NumT).REyeX(AIT_fix));
        R_offset.y = mean(TrialInfo(NumT).REyeX(AIT_fix));
        
        % Now take all eye position data from while the stimulus was on and
        % offset it by the average during fixation. Then calculate the total
        % distance from fixation at each point in time.
        L = sqrt((TrialInfo(NumT).LEyeX(AIT_stim) - L_offset.x).^2 + (TrialInfo(NumT).LEyeY(AIT_stim) - L_offset.y).^2);
        R = sqrt((TrialInfo(NumT).REyeX(AIT_stim) - R_offset.x).^2 + (TrialInfo(NumT).REyeY(AIT_stim) - R_offset.y).^2);
    end
    
    % Check if the distance is greater than the version window!
    if any(L>version) || any(R>version)
        if eye_plotFlag
%             plot(L,R,'r');
            plot(smoothed_AIT_stim.LEyeX,smoothed_AIT_stim.LEyeY,'r');
            hold on;
            circ_x = 0:0.2:2*pi;
            x_units = cos(circ_x)*version;
            y_units = sin(circ_x)*version;
            plot(smoothed_AIT_stim.REyeX,smoothed_AIT_stim.REyeY,'b');
%             plot(smoothed_AIT_stim.LEyeX(violation_points{NumT}),smoothed_AIT_stim.LEyeY(violation_points{NumT}),'ro','MarkerFaceColor','r');
%             plot(smoothed_AIT_stim.REyeX(violation_points{NumT}),smoothed_AIT_stim.REyeY(violation_points{NumT}),'bo','MarkerFaceColor','b');
            plot(x_units,y_units,'--k');
            axis square;
        end
        version_confirmed(NumT) = 0;
        disp(['Trial: ' num2str(NumT) '/' num2str(TrialNum) ': Rejected due to version violation']);
    else
        if eye_plotFlag
            plot(L,R,'b');
        end
        version_confirmed(NumT) = 1;
    end
    
end
disp(['Total rejected trials due to version violations: ' num2str(sum(version_confirmed == 0))]);
% Remove the bad trials!
if ~strcmp(recordingDate,'25November2020')
    TrialInfo = TrialInfo(logical(version_confirmed));
else
    warning('Recording date indicates eye data should not be sorted, including all trials...')
end

%% Analyze
TrialNum = length(TrialInfo);
AnaData = TrialInfo; % Make a copy so you don't overwrite it
TotalUnit = size(AnaData(1).UnitT,2);
if length(varargin) < 4
    plotUnits = 1:TotalUnit;
end
disp(['decoding Trial structure: ' num2str(TrialNum) ' total trials']);
for NumT = 1:TrialNum
    
    Event = AnaData(NumT).EID;
    Spikes = AnaData(NumT).UnitT;
    % Get time points
    T.Start = AnaData(NumT).EventT(AnaData(NumT).EID == 111);
    T.End = AnaData(NumT).EventT(AnaData(NumT).EID == 112);
    T.FixOn = AnaData(NumT).EventT(AnaData(NumT).EID == 114);
    T.StimOn = AnaData(NumT).EventT(AnaData(NumT).EID == 118);
    T.StimOff = AnaData(NumT).EventT(AnaData(NumT).EID == 120);
    
    % Get pertinent stimulus information
    Direction = Event(Event>=30000 & Event<=31000);
    AnaData(NumT).Direction = Direction - 30000;
    AnaData(NumT).Direction = wrapTo360(-AnaData(NumT).Direction);
    
    Speed = Event(Event>=7000 & Event<8000);
    Speed = round((Speed-7000)/10,0);
    AnaData(NumT).Speed = Speed;
    
    Eye = Event(Event>=8000 & Event<9000);
    AnaData(NumT).Eye = Eye - 8000;
    
    % Find spike events for the units
    tempSCount = sum(T.StimOn<=Spikes & Spikes<=T.StimOff, 3);
    tempTime = T.StimOff - T.StimOn;

    AnaData(NumT).RawFR = tempSCount./tempTime;
end

AnaDataTbl = struct2table(AnaData);
Presented_Directions = sort(unique(AnaDataTbl.Direction));
Presented_Eye = sort(unique(AnaDataTbl.Eye));
Speeds = sort(unique(AnaDataTbl.Speed));
ByTrial2D = nan(length(Presented_Eye), length(Presented_Directions), length(Speeds), TotalUnit, ceil(TrialNum/(length(Presented_Eye)*length(Presented_Directions))));

for s = 1:length(Speeds)
    for e = 1:length(Presented_Eye)
        for d = 1:length(Presented_Directions)
            all_trials{e,d,s,:} = AnaDataTbl.RawFR(AnaDataTbl.Eye == Presented_Eye(e) & AnaDataTbl.Direction == Presented_Directions(d) & AnaDataTbl.Speed == Speeds(s),:);
            anova_labels{e,d,s} = d*ones(numel(AnaDataTbl.RawFR(AnaDataTbl.Eye == Presented_Eye(e) & AnaDataTbl.Direction == Presented_Directions(d) & AnaDataTbl.Speed == Speeds(s),1)),1);
            watson_labels{e,d,s} = Presented_Directions(d)*ones(numel(AnaDataTbl.RawFR(AnaDataTbl.Eye == Presented_Eye(e) & AnaDataTbl.Direction == Presented_Directions(d) & AnaDataTbl.Speed == Speeds(s),1)),1);
            meanFR(e,d,s,:) = mean(AnaDataTbl.RawFR(AnaDataTbl.Eye == Presented_Eye(e) & AnaDataTbl.Direction == Presented_Directions(d) & AnaDataTbl.Speed == Speeds(s),:));
            semFR(e,d,s,:) = std(AnaDataTbl.RawFR(AnaDataTbl.Eye == Presented_Eye(e) & AnaDataTbl.Direction == Presented_Directions(d) & AnaDataTbl.Speed == Speeds(s),:))./...
                sqrt(sum(AnaDataTbl.Eye == Presented_Eye(e) & AnaDataTbl.Direction == Presented_Directions(d) & AnaDataTbl.Speed == Speeds(s)));
            % Also create a matrix with trials
            temp = squeeze(AnaDataTbl.RawFR(AnaDataTbl.Eye == Presented_Eye(e) & AnaDataTbl.Direction == Presented_Directions(d) & AnaDataTbl.Speed == Speeds(s),:))';
            ByTrial2D(e,d,s,:,1:size(temp,2)) = temp;
        end
        
        for u = 1:TotalUnit
            % Get the mean direction vectors and magnitudes
            norm_vec_dir(e,s,u) = wrapTo360(angle(dot(squeeze(meanFR(e,:,s,u)),exp(1i*deg2rad(Presented_Directions))))*180/pi);
            norm_vec_mag(e,s,u) = norm(dot(squeeze(meanFR(e,:,s,u)),exp(1i*deg2rad(Presented_Directions))));
            
            
            %% Statistical comparisons for this speed, eye and unit
            
            % Rayleigh significance test for tuning
            ray_p(e,s,u) = circ_rtest(deg2rad(Presented_Directions),squeeze(meanFR(e,:,s,u)));
            
            % 1 way anova
            anova_data = [];
            labels = [];
            watson = [];
            for d = 1:length(Presented_Directions)
                anova_data = [anova_data; all_trials{e,d,s}(:,u)];
                labels = [labels; anova_labels{e,d,s}];
                watson = [watson; watson_labels{e,d,s}];
            end
            anova_one_way(e,s,u) = anova1(anova_data, labels,'off');
            % watson u
            watson_u(e,s,u) = calc_WatsonU2_stat(anova_data, watson);
            ray_p(e,s,u) = NaN;
            
            % Get DI values
            DI(e,s,u) = DiscriminationIndex(squeeze(ByTrial2D(e,:,s,u,:))',1);
            
            % Get DI values left right direction comparison
            DI_LR(e,s,u) = DiscriminationIndex(squeeze(ByTrial2D(e,[1,5],s,u,:))',1);
            % Get DI values up down comparison
            DI_UD(e,s,u) = DiscriminationIndex(squeeze(ByTrial2D(e,[3,7],s,u,:))',1);
            
            % Get DTI values (Rosenberg et al., 2008)
            [pref_FR, pref_idx] = max(meanFR(e,:,s,u));
            antipref_idx = find(Presented_Directions == (wrapTo360(Presented_Directions(pref_idx) + 181)-1));
            antipref_FR = meanFR(e,antipref_idx,s,u);
            DTI(e,s,u) = (pref_FR - antipref_FR)/(pref_FR + antipref_FR);

            % Get ATI values (Rosenberg et al., 2008)
            if wrapTo360(Presented_Directions(pref_idx) + 90) == 360
                pref_ortho = find(Presented_Directions == 0);
            else
                pref_ortho = find(Presented_Directions == wrapTo360(Presented_Directions(pref_idx) + 90));
            end
            pref_ortho_FR = meanFR(e,pref_ortho,s,u);
            if wrapTo360(Presented_Directions(antipref_idx) + 90) == 360
                antipref_ortho = find(Presented_Directions == 0);
            else
                antipref_ortho = find(Presented_Directions == wrapTo360(Presented_Directions(antipref_idx) + 90));
            end
            antipref_ortho_FR = meanFR(e,antipref_ortho,s,u);
            if pref_ortho == antipref_ortho
                error('orthogonal preferred and antipreferred directions are identical');
            end
            ATI(e,s,u) = ((pref_FR*antipref_FR) - (pref_ortho_FR*antipref_ortho_FR))/((pref_FR*antipref_FR) + (pref_ortho_FR*antipref_ortho_FR));
            
            
        end
    end
end

%% Weighted linear model
opts1=  optimset('display','off');
for u = 1:TotalUnit
    mono_fit = @(w) w(1).*squeeze(meanFR(1,:,s,u)) + w(2).*squeeze(meanFR(2,:,s,u)) - squeeze(meanFR(3,:,s,u));
    w_mono(u,:) = lsqnonlin(mono_fit,[0.5,0.5],[0,0],[100,100],opts1);
    weighted_mono(u,:) = w_mono(u,1).*squeeze(meanFR(1,:,s,u)) + w_mono(u,2).*squeeze(meanFR(2,:,s,u));
end

%% More advanced statistics by unit
for u = 1:TotalUnit
    
    % Many comparisons across speeds, eye of stimulation, and direction
    % Are mean direction preferences different:
    % for each eye?
    % for each speed/eye?
    % 2 way anova for: direction, speed
    % Do you want to do a large analysis or break it up?
    % FR ~ eye + speed + direction
    % The other question is how these variables interact:
    %
    % FR ~ eye + speed + direction + direction*eye + direction*speed + eye*speed + direction*eye*speed
    % Eye*speed interaction doesn't make much sense: does the effect of eye
    % depend on speed?
    % Lets just go with it for now.
    UnitTable = table(AnaDataTbl.RawFR(:,u), AnaDataTbl.Direction, AnaDataTbl.Speed, AnaDataTbl.Eye, 'VariableNames',{'FR', 'Direction','Speed','Eye'});
    
    % Which variables need centering?
    % Let's keep direction for now
    % Let's keep speed for now even though only testing 1 or 2 speeds
    % How to code for eye?
    UnitTable.LvR = zeros(size(UnitTable,1),1); % First contrast code compares left and right eyes Lambda = [L B R] = [-1 0 1];
    UnitTable.LvR(UnitTable.Eye == 1) = -1;
    UnitTable.LvR(UnitTable.Eye == 2) = 1;
    % The second contrast code compares mean of Left,Right to Binocular
    UnitTable.MeanLRvB = 3*(UnitTable.Eye == 3) - 1; % 3 to 2, 0 goes to -1
    
    if length(Speeds) > 1 % more than 1 speed test is more complex
        complex_lm_fit{u} = fitlm(UnitTable,'FR ~ Direction + Speed + LvR + MeanLRvB + Direction*Speed + Direction*LvR + Direction*MeanLRvB');
        % a simpler model that looks at whether there is significant direction
        % tuning and significant speed tuning, for each eye individually
        for e = 1:length(Presented_Eye)
            glmtble = UnitTable(UnitTable.Eye == e,:);
            anova_speed_x_dir{e,u} = anova(fitlm(glmtble,'FR ~ Direction + Speed + Direction*Speed')); % allows for interaction
            anova_speed_dir{e,u} = anova(fitlm(glmtble,'FR ~ Direction + Speed')); % just a two-way anova
        end
    else
        for e = 1:length(Presented_Eye)
            anova_speed_x_dir{e,u} = NaN; %anova(fitlm(glmtble,'FR ~ Direction + Speed + Direction*Speed')); % allows for interaction
            anova_speed_dir{e,u} = NaN; %anova(fitlm(glmtble,'FR ~ Direction + Speed')); % just a two-way anova
        end
        complex_lm_fit{u} = fitlm(UnitTable,'FR ~ Direction + LvR + MeanLRvB + Direction*LvR + Direction*MeanLRvB');
    end

end
    
%% Von Mises Tuning Curve Fitting & ODI Metrics
VonMises = @(p,x) p(1) + p(2).*exp(-p(3))*exp(p(3)*cosd(x-p(4)));
fitting_x = 0:0.1:360;
% if plotFlag 
%     figure;
% end
for u = 1:TotalUnit
    for s = 1:length(Speeds)
        monkey = extractBefore(filename_base,'_');
        % Get ocular dominance info
        % meanFR(e,d,s,u)
        switch monkey
            case 'Jim'
                % Right hemisphere recordings
                % contra/(contra + ipsi)
                ODI(u) = nanmean(meanFR(1,:,:,u),'all')./(nanmean(meanFR(1,:,:,u),'all') + nanmean(meanFR(2,:,:,u),'all'));
                
                % Positive means contra dominant
                Monocularity_2D_Max(s,u) = (max(meanFR(1,:,s,u)) - max(meanFR(2,:,s,u)))/(max(meanFR(1,:,s,u)) + max(meanFR(2,:,s,u)));
                if ODI(u) >= 0.5
                    % contra is dominant
                    ODI_Eye(u) = 'L';
                else
                    ODI_Eye(u) = 'R';
                end
            case 'Clay'
                % Left hemisphere recordings
                ODI(u) = nanmean(meanFR(2,:,:,u),'all')./(nanmean(meanFR(1,:,s,u),'all') + nanmean(meanFR(2,:,:,u),'all'));
                Monocularity_2D_Max(s,u) = (max(meanFR(2,:,s,u)) - max(meanFR(1,:,s,u)))/(max(meanFR(1,:,s,u)) + max(meanFR(2,:,s,u)));
                if ODI(u) >= 0.5
                    % contra is dominant
                    ODI_Eye(u) = 'R';
                else
                    ODI_Eye(u) = 'L';
                end
        end
        for e = 1:length(Presented_Eye)
            % Get firing rate for this unit and eye
            temp_raw = meanFR(e,:,s,u);
            % starting input: [DC = min firing rate, Gain = difference between
            % min and max, Kappa = 1, Mu = direction closest to max firing
            % rate]
            start_points = [min(temp_raw),max(temp_raw) - min(temp_raw), 1, Presented_Directions(find(temp_raw == max(temp_raw),1))];
            % Lower bounds: [DC = opposite of max firing rate, the rest are
            % zero];
            lower_bounds = [-1.1*max(temp_raw),0,0,0];
            % Upper bounds: [DC = max firing rate, Gain = Max firing rate,
            % Kappa = 50 (arbitrary), Mu = max direction (360 deg)]
            upper_bounds = [1.1*max(temp_raw),1.1*max(temp_raw),5,360];
            %         Fit the data using lsqcurvefit:
            try
                %[X,RESNORM,RESIDUAL,EXITFLAG,OUTPUT,LAMBDA,JACOBIAN]
                [phat(e,s,:,u),~,resid,~,~,~,jacob] = lsqcurvefit(VonMises, start_points, Presented_Directions', temp_raw, lower_bounds, upper_bounds,opts1);
                Von_CI(e,s,:,:,u) = nlparci(phat(e,s,:,u),resid,'jacobian',jacob);
                meanFits(e,s,:,u) = VonMises(phat(e,s,:,u), fitting_x);
                [r_corr(e,s,u), p_corr(e,s,u)] = corr(VonMises(phat(e,s,:,u), Presented_Directions), temp_raw');
            catch
                phat(e,s,:,u) = NaN;
                meanFits(e,s,:,u) = NaN;
                r_corr(e,s,u) = NaN;
                p_corr(e,s,u) = NaN;
            end
            
        end
        if plotFlag_von
            subplot(length(Speeds),TotalUnit, u+TotalUnit*(s-1));
            title(['Unit ' num2str(u) ' von Mises Fit'])
            set(gca, 'ColorOrder', colorsteps,'NextPlot', 'replacechildren');
            h = plot(repmat(fitting_x',1,length(Presented_Eye)),squeeze(meanFits(:,s,:,u))'); % Fitting curve
            set(gca, 'ColorOrder', colorsteps,'NextPlot', 'replacechildren');
            hold on;
            h2 = plot(repmat(Presented_Directions,1,length(Presented_Eye)),squeeze(meanFR(:,:,s,u))','o'); % Actual points
            set(gca, 'ColorOrder', colorsteps,'NextPlot', 'replacechildren');
            %     eh = errorbar(repmat(Presented_Directions,1,length(Presented_Eye)),squeeze(meanFits(:,:,u))',squeeze(semFR(:,:,u))');
            xlabel('Direction');
            ylabel('Firing Rate');
            xticks(Presented_Directions);
            legend(eyeLabels);
            hold off;
        end
        

    end
end

%% Data to export
% lateral_left = [left eye leftward, right eye leftward]
lateral_left.left = AnaDataTbl.RawFR(AnaDataTbl.Eye == Presented_Eye(1) & AnaDataTbl.Direction == 180,:);
lateral_left.right = AnaDataTbl.RawFR(AnaDataTbl.Eye == Presented_Eye(2) & AnaDataTbl.Direction == 180,:);
lateral_left.both = AnaDataTbl.RawFR(AnaDataTbl.Eye == Presented_Eye(3) & AnaDataTbl.Direction == 180,:);
lateral_right.left = AnaDataTbl.RawFR(AnaDataTbl.Eye == Presented_Eye(1) & AnaDataTbl.Direction == 0,:);
lateral_right.right = AnaDataTbl.RawFR(AnaDataTbl.Eye == Presented_Eye(2) & AnaDataTbl.Direction == 0,:);
lateral_right.both = AnaDataTbl.RawFR(AnaDataTbl.Eye == Presented_Eye(3) & AnaDataTbl.Direction == 0,:);


LateralMotionData = struct('AnaDataTbl',AnaDataTbl,'meanFR',meanFR,'semFR',semFR,'lateral_left',lateral_left,'lateral_right',lateral_right,'VonMisesParams',phat,'VonFits',meanFits,'ByTrial2D',ByTrial2D,...
    'DIs',DI,'DI_LR',DI_LR,'DI_UD',DI_UD,'corr_p', p_corr, 'corr_r', r_corr, 'Rayleigh', ray_p,'Mono_Weights',w_mono);
% LateralMotionData.norm_vec_ori = norm_vec_ori_length;
LateralMotionData.norm_vec_dir = norm_vec_dir;
LateralMotionData.norm_vec_mag = norm_vec_mag;
LateralMotionData.anova_one_way = anova_one_way;
LateralMotionData.watson_u = watson_u;
LateralMotionData.anova_speed_x_dir = anova_speed_x_dir;
LateralMotionData.anova_speed_dir = anova_speed_dir;
LateralMotionData.complex_lm_fit = complex_lm_fit;
LateralMotionData.Von_CI = Von_CI;
LateralMotionData.DTI = DTI;
LateralMotionData.ATI = ATI;
LateralMotionData.ODI_2D = ODI;
LateralMotionData.Monocularity_2D_Max = Monocularity_2D_Max;
LateralMotionData.ODI_Eye_2D = ODI_Eye;
                            
try
    save(fullfile(pathname, [filename_base 'LateralMotionData.mat']),'LateralMotionData');
catch ME
    disp(ME.message)
end

%% Generate lateral motion tuning curves for each eye and unit
if plotFlag
    for s = 1:length(Speeds)
        if s == 1
            if ishandle(fig_handle)
                ax = fig_handle;
                hold(ax,'on');
            else
                figure; hold on;
                ax = gca;
            end
        elseif s == 2
             if ishandle(fig_handle2)
                ax = fig_handle2;
                hold(ax,'on');
            else
                figure; hold on;
                ax = gca;
             end
        end
            
        if length(plotUnits)>1
            for i = 1:length(plotUnits)
                p = plotUnits(i);
                subplot(1,length(plotUnits),i); hold on;
                ax = gca;
                title(['Speed ',num2str(Speeds(s)),'Unit ' num2str(p) ' 2D Tuning Curve'])
                set(ax, 'ColorOrder', colorsteps,'NextPlot', 'replacechildren');
                h = plot(ax,repmat(Presented_Directions,1,length(Presented_Eye)),squeeze(meanFR(:,:,s,p))');
                set(ax, 'ColorOrder', colorsteps,'NextPlot', 'replacechildren');
                eh = errorbar(ax,repmat(Presented_Directions,1,length(Presented_Eye)),squeeze(meanFR(:,:,s,p))',squeeze(semFR(:,:,s,p))');
                xlabel('Direction');
                ylabel('Firing Rate');
                xticks(Presented_Directions);
                legend(ax,{['Left: ' num2str(round(ATI(1,s,p),2))], ['Right: ' num2str(round(ATI(2,s,p),2))], ['Both: ' num2str(round(ATI(3,s,p),2))]});
                hold off;
            end
        else
            p = plotUnits;
            title(ax,['Speed ',num2str(Speeds(s)),' Unit ' num2str(p) ' 2D'])
            xticks(ax,Presented_Directions);
            set(ax, 'ColorOrder', colorsteps,'NextPlot', 'replacechildren');
            h = plot(ax,repmat(Presented_Directions,1,length(Presented_Eye)),squeeze(meanFR(:,:,s,plotUnits))');
            set(ax, 'ColorOrder', colorsteps,'NextPlot', 'replacechildren');
            eh = errorbar(ax,repmat(Presented_Directions,1,length(Presented_Eye)),squeeze(meanFR(:,:,s,plotUnits))',squeeze(semFR(:,:,s,plotUnits))');
            hold(ax,'on');
            legend(ax,{['Left: ' num2str(round(ATI(1,s,p),2))], ['Right: ' num2str(round(ATI(2,s,p),2))], ['Both: ' num2str(round(ATI(3,s,p),2))]});
            xlabel(ax,'Direction');
            ylabel(ax,'Firing Rate');
        end
    end
end
end



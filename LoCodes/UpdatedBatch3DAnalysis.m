%% Updated Batch3DMotionAnalysis
function [MIDTable, AllData, MotionData_ByStim, model_weights] = UpdatedBatch3DAnalysis(MIDTable, file_table, LateralMotionTable, varargin)

% default input options (varargin)
options = struct('reanalyze', 0,       ...   
                 'trialBased', 0,        ...
                 'area', 'MT');

% read input parameters
optionNames = fieldnames(options);
if mod(length(varargin),2) == 1
	error('Please provide propertyName/propertyValue pairs')
end
for pair = reshape(varargin,2,[])    % pair is {propName; propValue}
	if any(strcmp(pair{1}, optionNames))
        options.(pair{1}) = pair{2};
    else
        error('%s is not a recognized parameter name', pair{1})
	end
end

%% Batch 3D Motion Analysis
% (1) Select files
% (2) Run 3DMotionTuning
% (3) Extract "good" units
% (4) Sort/arrange as necessary
% (5) Run the desired analyses

clear LateralMotionData % you can't have both in memory at the same time. At this point you just need the table

%% Figure Parameters
colorsteps = [0.49 0.18 0.56;...
    0 0 1;...
    0 0.7 1;...
    1 0.15 0;
    0 1 0;...
    0.8 1 0];

conditionNames = {'Combined','L Mono','R Mono','Binocular','L Control', 'R Control'};
plotFlag = 0;
fit_neurometric = 1;

%% (2) Run 3D Motion Tuning

for f = 1:size(file_table,1)
    m = extractBetween(file_table.Paths(f),'\','\');
    monkey = m{1};
    options.area = file_table.ROI{f};
    save_location = ['C:\', monkey, '\In_Processing\', options.area];
    save_location_trial = ['C:\', monkey, '\In_Processing\', options.area '\TrialBased'];
    
    if ~options.reanalyze
        % Grab the names of previously analyzed data without loading the data
        % into memory
        previousData = dir([save_location,'\',monkey,'*.mat']);
        if ~isempty(previousData)
            previousData = extractfield(previousData,'name'); % Requires Mapping Toolbox
            previousData = extractBefore(previousData,'.mat');
        else
            previousData = {};
        end
    end

    tic;
    disp(['Calculating 3D Motion Tuning Curves: ' file_table.Names{f}(8:16), ' ', num2str(file_table.Tetrode(f)), '; ' num2str(f) '/' num2str(size(file_table,1))])
    saveToStruct = extractBefore(file_table.Names{f,1},'_3D'); % Name for this recording
    saveToStruct = replace(saveToStruct, '-','_'); % Can't have dashes in fieldnames
    fieldOrder.(saveToStruct) = []; % If data was saved in an order different from the way it is extracted from the table, you need to reorder it - create an empty structure with the properly ordered field names.
    saveOrder{f} = save_location;
    % Check if you have already analyzed this file (and aren't reanalyzing)
    if ~isvarname('saveToStruct')
        error('No files identified');
    end
    if options.reanalyze || ~ismember(saveToStruct,previousData)
        if options.reanalyze
            disp('Reanalyzing data...');
        else
            disp('No previous data found, reanalyzing data. Check that your paths are correct!');
        end
        % Create temporary structure where each field is a file name - one
        % with raw trial-based data (if desired) and one with FRs separated by stimulus type
        if options.trialBased
            [MotionData.(saveToStruct), temp_ByStim.(saveToStruct)] =  Offline_3DMotion_update(file_table.Paths(f),file_table.Names(f,:), plotFlag, file_table.Units{f}); % Get 3D motion data for this cell
        else
            [~, temp_ByStim.(saveToStruct)] =  Offline_3DMotion_update(file_table.Paths(f),file_table.Names(f,:), plotFlag, file_table.Units{f});
        end
        % Are you adding data to existing file or appending it?
%         if reanalyze && f == 1
%             Initialization of the saved files you will append to
%             if trialBased
%                 save(fullfile(save_location_trial, 'MotionData.mat'),'-struct', 'MotionData', saveToStruct);
%             end
%             save(fullfile(save_location, 'MotionData_ByStim.mat'),'-struct', 'temp_ByStim', saveToStruct);
%         end
        disp('Saving data...');
        if options.trialBased
            disp('Saving trial-based data...');
%             save(fullfile(save_location_trial, [saveToStruct,'.mat']),'-struct', 'MotionData', saveToStruct, '-append'); % Add new recording field to saved data structure
            save(fullfile(save_location_trial, [saveToStruct,'.mat']),'-struct', 'MotionData');
        end
        try
            save(fullfile(save_location, [saveToStruct,'.mat']),'-struct', 'temp_ByStim');
            %             save(fullfile(save_location, 'MotionData_ByStim.mat'),'-struct', 'temp_ByStim', saveToStruct, '-append'); % Add new recording field to saved data structure
        catch e
            disp('Unable to save');
            disp('Saving separate file...');
            save(fullfile(save_location, ['MotionData_ByStim_', saveToStruct, '.mat']),'-struct', 'temp_ByStim', saveToStruct);
        end
        clear MotionData temp_ByStim; % clear the temporary data structures since it is huge and we may load many.
    else
        % This file has already been analyzed, no need to do it again
        disp('Data already exists, skipping...');
    end
    disp(num2str(toc));
end
disp('Loading all the condition separated data...');
data_to_load = (fieldnames(fieldOrder));
for d = 1:size(data_to_load,1)
    MotionData_ByStim.(data_to_load{d}) = load(fullfile(saveOrder{d},[data_to_load{d},'.mat']));
    % Below is clunky and due to the way you save your struct - fix the way
    % you save and you shouldn't have to do this
    MotionData_ByStim.(data_to_load{d}) = MotionData_ByStim.(data_to_load{d}).(data_to_load{d});
end
MotionData_ByStim = orderfields(MotionData_ByStim,fieldOrder); % Ensure that the loaded data and extracted table are in the same order.
% Concatenate all the individual strucutres into a struct array
temp = struct2cell(MotionData_ByStim);
MotionData_ByStim = horzcat(temp{:});
clear temp
%% After this point, analyses are done on a per-unit basis.
min_trials = 3;
num_bootstraps = 100;
CoherenceArray = [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22]./22;
MIDTable.Both_Lateral_Mu = nan(size(MIDTable,1),1);
MIDTable.Left_Lateral_Mu = nan(size(MIDTable,1),1);
MIDTable.Right_Lateral_Mu = nan(size(MIDTable,1),1);

MIDTable.Both_Lateral_Kappa = nan(size(MIDTable,1),1);
MIDTable.Left_Lateral_Kappa = nan(size(MIDTable,1),1);
MIDTable.Right_Lateral_Kappa = nan(size(MIDTable,1),1);

MIDTable.Left_Lateral_Weight = nan(size(MIDTable,1),1);
MIDTable.Right_Lateral_Weight = nan(size(MIDTable,1),1);
MIDTable.Both_Norm_Dir = nan(size(MIDTable,1),1);
MIDTable.Both_Norm_Mag = nan(size(MIDTable,1),1);

MIDTable.Left_Anova = nan(size(MIDTable,1),1);
MIDTable.Right_Anova = nan(size(MIDTable,1),1);
MIDTable.Both_Anova = nan(size(MIDTable,1),1);
MIDTable.Left_Watson = nan(size(MIDTable,1),1);
MIDTable.Right_Watson = nan(size(MIDTable,1),1);
MIDTable.Both_Watson = nan(size(MIDTable,1),1);
for ith_unit = 1:size(MIDTable,1)
    disp(['Analyzing unit: ' num2str(ith_unit) '/' num2str(size(MIDTable,1))])
    
    rec = extractBefore(MIDTable.Names{ith_unit,1},'_3D'); % Name for this recording
    rec = replace(rec, '-','_'); % Can't have dashes in fieldnames
    
    f = find(strcmp(rec,fieldnames(fieldOrder)));
    MIDTable.Folder_Index(ith_unit) = f;
    selected_unit = MIDTable.Unit(ith_unit);
    
    m = extractBetween(MIDTable.Paths(ith_unit),'\','\');
    monkey = m{1};
    
    %% Generate large data structure
    AllData(ith_unit).Combined = squeeze(MotionData_ByStim(f).NeuroResp(selected_unit,1,:,:));
    AllData(ith_unit).Means.Combined = nanmean(AllData(ith_unit).Combined,2);
    AllData(ith_unit).SEMs.Combined = std(AllData(ith_unit).Combined,[],2,'omitnan')./sqrt(sum(~isnan(AllData(ith_unit).Combined),2));
    AllData(ith_unit).MonoL = squeeze(MotionData_ByStim(f).NeuroResp(selected_unit,2,:,:));
    AllData(ith_unit).Means.MonoL = nanmean(AllData(ith_unit).MonoL,2);
    AllData(ith_unit).SEMs.MonoL = std(AllData(ith_unit).MonoL,[],2,'omitnan')./sqrt(sum(~isnan(AllData(ith_unit).MonoL),2));
    AllData(ith_unit).MonoR = squeeze(MotionData_ByStim(f).NeuroResp(selected_unit,3,:,:));
    AllData(ith_unit).Means.MonoR = nanmean(AllData(ith_unit).MonoR,2);
    AllData(ith_unit).SEMs.MonoR = std(AllData(ith_unit).MonoR,[],2,'omitnan')./sqrt(sum(~isnan(AllData(ith_unit).MonoR),2));
    AllData(ith_unit).Bino = squeeze(MotionData_ByStim(f).NeuroResp(selected_unit,4,:,:));
    AllData(ith_unit).Means.Bino = nanmean(AllData(ith_unit).Bino,2);
    AllData(ith_unit).SEMs.Bino = std(AllData(ith_unit).Bino,[],2,'omitnan')./sqrt(sum(~isnan(AllData(ith_unit).Bino),2));
    AllData(ith_unit).ControlL = squeeze(MotionData_ByStim(f).NeuroResp(selected_unit,5,:,:));
    AllData(ith_unit).Means.ControlL = nanmean(AllData(ith_unit).ControlL,2);
    AllData(ith_unit).SEMs.ControlL = std(AllData(ith_unit).ControlL,[],2,'omitnan')./sqrt(sum(~isnan(AllData(ith_unit).ControlL),2));
    AllData(ith_unit).ControlR = squeeze(MotionData_ByStim(f).NeuroResp(selected_unit,6,:,:));
    AllData(ith_unit).Means.ControlR = nanmean(AllData(ith_unit).ControlR,2);
    AllData(ith_unit).SEMs.ControlR = std(AllData(ith_unit).ControlR,[],2,'omitnan')./sqrt(sum(~isnan(AllData(ith_unit).ControlR),2));
    AllData(ith_unit).SaccUp = squeeze(MotionData_ByStim(f).NeuroResp(selected_unit,7,:,:));
    AllData(ith_unit).Means.SaccUp = nanmean(AllData(ith_unit).SaccUp,2);
    AllData(ith_unit).SEMs.SaccUp = std(AllData(ith_unit).SaccUp,[],2,'omitnan')./sqrt(sum(~isnan(AllData(ith_unit).SaccUp),2));
    AllData(ith_unit).SaccDown = squeeze(MotionData_ByStim(f).NeuroResp(selected_unit,8,:,:));
    AllData(ith_unit).Means.SaccDown = nanmean(AllData(ith_unit).SaccDown,2);
    AllData(ith_unit).SEMs.SaccDown = std(AllData(ith_unit).SaccUp,[],2,'omitnan')./sqrt(sum(~isnan(AllData(ith_unit).SaccDown),2));
    if size(MotionData_ByStim(f).NeuroResp,2)>8
        AllData(ith_unit).ControlBL = squeeze(MotionData_ByStim(f).NeuroResp(selected_unit,9,:,:));
        AllData(ith_unit).Means.ControlBL = nanmean(AllData(ith_unit).ControlBL,2);
        AllData(ith_unit).SEMs.ControlBL = std(AllData(ith_unit).ControlBL,[],2,'omitnan')./sqrt(sum(~isnan(AllData(ith_unit).ControlBL),2));
        AllData(ith_unit).ControlBR = squeeze(MotionData_ByStim(f).NeuroResp(selected_unit,10,:,:));
        AllData(ith_unit).Means.ControlBR = nanmean(AllData(ith_unit).ControlBR,2);
        AllData(ith_unit).SEMs.ControlBR = std(AllData(ith_unit).ControlBR,[],2,'omitnan')./sqrt(sum(~isnan(AllData(ith_unit).ControlBR),2));
    else
        AllData(ith_unit).ControlBL = nan(size(AllData(ith_unit).Combined));
        AllData(ith_unit).Means.ControlBL = nanmean(AllData(ith_unit).ControlBL,2);
        AllData(ith_unit).SEMs.ControlBL = nan(size(AllData(ith_unit).ControlBL));
        AllData(ith_unit).ControlBR = nan(size(AllData(ith_unit).Combined));
        AllData(ith_unit).Means.ControlBR = nanmean(AllData(ith_unit).ControlBR,2);
        AllData(ith_unit).SEMs.ControlBR = nan(size(AllData(ith_unit).ControlBL));
    end
    %% Discrimination Indices
    MIDTable.Combined_DI(ith_unit) = DiscriminationIndex(AllData(ith_unit).Combined');
    MIDTable.MonoL_DI(ith_unit) = DiscriminationIndex(AllData(ith_unit).MonoL');
    MIDTable.MonoR_DI(ith_unit) = DiscriminationIndex(AllData(ith_unit).MonoR');
    MIDTable.Bino_DI(ith_unit) = DiscriminationIndex(AllData(ith_unit).Bino');
    
    %     disp('Running Discrimination Index Analysis...');
    %     % Step through each coherence level
    %     for coh = 1:size(DI.Data(ith_unit).Combined,1)/2
    %         [DI.Combined(ith_unit,coh), DI.Combined_CI(ith_unit,coh,:)] = DiscriminationIndex([DI.Data(ith_unit).Combined(coh,:); DI.Data(ith_unit).Combined(end-(coh-1),:)]',num_bootstraps);
    %         [DI.MonoL(ith_unit,coh), DI.MonoL_CI(ith_unit,coh,:)] = DiscriminationIndex([DI.Data(ith_unit).MonoL(coh,:); DI.Data(ith_unit).MonoL(end-(coh-1),:)]',num_bootstraps);
    %         [DI.MonoR(ith_unit,coh), DI.MonoR_CI(ith_unit,coh,:)] = DiscriminationIndex([DI.Data(ith_unit).MonoR(coh,:); DI.Data(ith_unit).MonoR(end-(coh-1),:)]',num_bootstraps);
    %         [DI.Bino(ith_unit,coh), DI.Bino_CI(ith_unit,coh,:)] = DiscriminationIndex([DI.Data(ith_unit).Bino(coh,:); DI.Data(ith_unit).Bino(end-(coh-1),:)]',num_bootstraps);
    %         [DI.ControlL(ith_unit,coh), DI.ControlL_CI(ith_unit,coh,:)] = DiscriminationIndex([DI.Data(ith_unit).ControlL(coh,:); DI.Data(ith_unit).ControlL(end-(coh-1),:)]',num_bootstraps);
    %         [DI.ControlR(ith_unit,coh), DI.ControlR_CI(ith_unit,coh,:)] = DiscriminationIndex([DI.Data(ith_unit).ControlR(coh,:); DI.Data(ith_unit).ControlR(end-(coh-1),:)]',num_bootstraps);
    %     end
    
    
    
    %% Merge this table with the 2D tuning table if it exists in the current
    % workspace
    
    
    try
        MID_index = find(ismember([datenum(MIDTable.Date) MIDTable.Tetrode MIDTable.Unit],[datenum(LateralMotionTable.Date) LateralMotionTable.Tetrode LateralMotionTable.Unit],'rows'));
        Lateral_index = find(ismember([datenum(LateralMotionTable.Date) LateralMotionTable.Tetrode LateralMotionTable.Unit],[datenum(MIDTable.Date) MIDTable.Tetrode MIDTable.Unit],'rows'));
        
        MIDTable.Both_Lateral_Mu(MID_index) = LateralMotionTable.Both_Mu(Lateral_index);
        MIDTable.Left_Lateral_Mu(MID_index) = LateralMotionTable.Left_Mu(Lateral_index);
        MIDTable.Right_Lateral_Mu(MID_index) = LateralMotionTable.Right_Mu(Lateral_index);
        
        MIDTable.Both_Lateral_Kappa(MID_index) = LateralMotionTable.Both_Kappa(Lateral_index);
        MIDTable.Left_Lateral_Kappa(MID_index) = LateralMotionTable.Left_Kappa(Lateral_index);
        MIDTable.Right_Lateral_Kappa(MID_index) = LateralMotionTable.Right_Kappa(Lateral_index);
        
%         MIDTable.Left_Lateral_Weight(MID_index) = LateralMotionTable.Left_Weights(Lateral_index);
%         MIDTable.Right_Lateral_Weight(MID_index) = LateralMotionTable.Right_Weights(Lateral_index);
        MIDTable.Both_Norm_Dir(MID_index) = LateralMotionTable.Both_Dir_Vec(Lateral_index);
        MIDTable.Both_Norm_Mag(MID_index) = LateralMotionTable.Both_Dir_Mag(Lateral_index);
        
        MIDTable.Left_Anova(MID_index) = LateralMotionTable.Left_Anova(Lateral_index);
        MIDTable.Right_Anova(MID_index) = LateralMotionTable.Right_Anova(Lateral_index);
        MIDTable.Both_Anova(MID_index) = LateralMotionTable.Both_Anova(Lateral_index);
        MIDTable.Left_Watson(MID_index) = LateralMotionTable.Left_Watson(Lateral_index);
        MIDTable.Right_Watson(MID_index) = LateralMotionTable.Right_Watson(Lateral_index);
        MIDTable.Both_Watson(MID_index) = LateralMotionTable.Both_Watson(Lateral_index);
    catch
        warning('No lateral motion tuning table in the current workspace, run BatchLateralMotionAnalysis first');
    end
    
    %% Label the neuron
    tmp_lbl = string([monkey(1), '-', datestr(MIDTable.Date(ith_unit)), '-TT', num2str(MIDTable.Tetrode(ith_unit)), '-U', num2str(MIDTable.Unit(ith_unit))]);
    MIDTable.Label(ith_unit) = tmp_lbl;
    
    %% Assymetry Indices
    disp('Calculating Assymetry Indices...');
    MIDTable.Combined_AI(ith_unit) = AssymetryIndex(AllData(ith_unit).Combined(8:end,:),flipud(AllData(ith_unit).Combined(1:6,:))); % Positive means prefers towards
    MIDTable.MonoL_AI(ith_unit) = AssymetryIndex(AllData(ith_unit).MonoL(8:end,:),flipud(AllData(ith_unit).MonoL(1:6,:)));
    MIDTable.MonoR_AI(ith_unit) = AssymetryIndex(AllData(ith_unit).MonoR(8:end,:),flipud(AllData(ith_unit).MonoR(1:6,:)));
    MIDTable.Bino_AI(ith_unit) = AssymetryIndex(AllData(ith_unit).Bino(8:end,:),flipud(AllData(ith_unit).Bino(1:6,:)));
    
    % Linear models (FR~Coherence)
    MIDTable.Combined_lm_slope(ith_unit) = MotionData_ByStim(f).lmfit_slope(selected_unit,1);
    MIDTable.Combined_lm_p(ith_unit) = MotionData_ByStim(f).lmfit_p(selected_unit,1);
    MIDTable.Combined_lm_sig(ith_unit) = MotionData_ByStim(f).lmfit_sig(selected_unit,1);
    
    MIDTable.MonoL_lm_slope(ith_unit) = MotionData_ByStim(f).lmfit_slope(selected_unit,2);
    MIDTable.MonoL_lm_p(ith_unit) = MotionData_ByStim(f).lmfit_p(selected_unit,2);
    MIDTable.MonoL_lm_sig(ith_unit) = MotionData_ByStim(f).lmfit_sig(selected_unit,2);
    
    MIDTable.MonoR_lm_slope(ith_unit) = MotionData_ByStim(f).lmfit_slope(selected_unit,3);
    MIDTable.MonoR_lm_p(ith_unit) = MotionData_ByStim(f).lmfit_p(selected_unit,3);
    MIDTable.MonoR_lm_sig(ith_unit) = MotionData_ByStim(f).lmfit_sig(selected_unit,3);
    
    MIDTable.Bino_lm_slope(ith_unit) = MotionData_ByStim(f).lmfit_slope(selected_unit,4);
    MIDTable.Bino_lm_p(ith_unit) = MotionData_ByStim(f).lmfit_p(selected_unit,4);
    MIDTable.Bino_lm_sig(ith_unit) = MotionData_ByStim(f).lmfit_sig(selected_unit,4);
    
    MIDTable.eye_lmfit_slope(ith_unit,:) = MotionData_ByStim(f).eye_lmfit_slope(selected_unit,:); % FR = 1 + Coherence + Eye + Coh*Eye
    MIDTable.eye_lmfit_p(ith_unit,:) = MotionData_ByStim(f).eye_lmfit_slope(selected_unit,:);
    MIDTable.eye_lmfit_sig(ith_unit,:) = MotionData_ByStim(f).eye_lmfit_sig(selected_unit,:);
    
    % Complex linear models with explained variance
%     tmp = struct2table(AllMeans(ith_unit).Means);
%     MIDTable.Combined_Complex(ith_unit) = fitlm(tmp,'Combined ~ MonoL*MonoR')
    
    % Mean AI
    MIDTable.Mean_AI(ith_unit) = mean([MIDTable.Combined_AI(ith_unit),MIDTable.MonoL_AI(ith_unit), MIDTable.MonoR_AI(ith_unit), MIDTable.Bino_AI(ith_unit)]);
    
    %% Invariance metrics
    MIDTable.element_svd_corr(ith_unit) = MotionData_ByStim(f).element_svd_corr(selected_unit);
    MIDTable.condition_svd_corr(ith_unit,:) = MotionData_ByStim(f).condition_svd_corr(selected_unit,:);
    MIDTable.mean_condition_svd_corr(ith_unit) = MotionData_ByStim(f).mean_condition_svd_corr(selected_unit);
    MIDTable.separability(ith_unit) = MotionData_ByStim(f).separability(selected_unit);
    MIDTable.mean_condition_corr(ith_unit) = MotionData_ByStim(f).mean_condition_corr(selected_unit);
    
    % Correlations and congruency
    MIDTable.MonoL_Coh_Corr(ith_unit) = corr(CoherenceArray', AllData(ith_unit).Means.MonoL);
    MIDTable.MonoR_Coh_Corr(ith_unit) = corr(CoherenceArray', AllData(ith_unit).Means.MonoR);
    MIDTable.CongruencyIndex(ith_unit) = MIDTable.MonoL_Coh_Corr(ith_unit)*MIDTable.MonoR_Coh_Corr(ith_unit);
    MIDTable.AICongruencyIndex(ith_unit) = MIDTable.MonoL_AI(ith_unit)*MIDTable.MonoR_AI(ith_unit);
    
    MIDTable.MeanLRRatio(ith_unit) = mean(AllData(ith_unit).Means.MonoL./AllData(ith_unit).Means.MonoR);
    
    %% ROC Choice Related Activity
    % Grand Choice Prob
    disp('Running bootstrapped Grand Choice Probability...');
    [pref, GrandChoiceDat] = GrandChoiceProb_Prep(MotionData_ByStim(f), selected_unit); % Already segregates by unit
    
    % New Method:
    % Use 0% coherence for each stimulus condition and treat the cue
    % conditions as different "stimulus values" (normally we use
    % coherence). Therefore, we do a composite Z score for each cue
    % condition, pool conditions together, then bootstrap the Z scores.
    % Doing this only on 0% coherence, because it should be ambiguous to
    % the cue.
    % Preferences in the prep code above are based only on means. Create a
    % pref based on AI as well:
    if MIDTable.Combined_AI(ith_unit)>0
        ai_pref = 2;
    else
        ai_pref = 1;
    end
    dat = [{GrandChoiceDat.Combined{1:2,7}}', {GrandChoiceDat.MonoL{1:2,7}}', {GrandChoiceDat.MonoR{1:2,7}}', {GrandChoiceDat.Bino{1:2,7}}']; %
    [MIDTable.ROC(ith_unit), MIDTable.ROC_CI(ith_unit,:)] = GrandChoiceProb(dat, pref.Combined, min_trials,num_bootstraps);
    
%     
%     
    
    %% Dominance and MRR
    % Monocular Response Ratio
    disp('Running Monocular Response Ratio Analysis...');
    MIDTable.MRR(ith_unit) = MonocularResponseRatio(AllData(ith_unit).Means.MonoL, AllData(ith_unit).Means.MonoR);
    
    % Classic ODI metric from DeAngelis, etc.:
    % Random dot stimuli comparison = 0% coherence trials
    % Just a normalized comparison making:
    MIDTable.Monkey(ith_unit,:) = {monkey};
    switch monkey
        case 'Jim'
            % Right hemisphere recordings
            % contra/(contra + ipsi)
            MIDTable.ODI(ith_unit) = nanmean(AllData(ith_unit).MonoL(7,:))./(nanmean(AllData(ith_unit).MonoL(7,:)) + nanmean(AllData(ith_unit).MonoR(7,:)));
             MIDTable.Monocularity_3D_Max(ith_unit) = (max(AllData(ith_unit).Means.MonoL(:))-max(AllData(ith_unit).Means.MonoR(:)))/(max(AllData(ith_unit).Means.MonoL(:)) + max(AllData(ith_unit).Means.MonoR(:)));
            
             if MIDTable.ODI(ith_unit) >= 0.5
                % contra is dominant
                MIDTable.ODI_Eye(ith_unit) = 'L';
                MIDTable.Dom_Coh_Corr(ith_unit) = corr(CoherenceArray', AllData(ith_unit).Means.MonoL);
                MIDTable.NonDom_Coh_Corr(ith_unit) = corr(CoherenceArray', AllData(ith_unit).Means.MonoR);
                MIDTable.DomCongruencyIndex(ith_unit) = MIDTable.Dom_Coh_Corr(ith_unit)*MIDTable.NonDom_Coh_Corr(ith_unit);
            else
                MIDTable.ODI_Eye(ith_unit) = 'R';
                MIDTable.Dom_Coh_Corr(ith_unit) = corr(CoherenceArray', AllData(ith_unit).Means.MonoR);
                MIDTable.NonDom_Coh_Corr(ith_unit) = corr(CoherenceArray', AllData(ith_unit).Means.MonoL);
                MIDTable.DomCongruencyIndex(ith_unit) = MIDTable.Dom_Coh_Corr(ith_unit)*MIDTable.NonDom_Coh_Corr(ith_unit);
            end
        case 'Clay'
            % Left hemisphere recordings
            MIDTable.ODI(ith_unit) = nanmean(AllData(ith_unit).MonoR(7,:))./(nanmean(AllData(ith_unit).MonoL(7,:)) + nanmean(AllData(ith_unit).MonoR(7,:)));
            MIDTable.Monocularity_3D_Max(ith_unit) = (max(AllData(ith_unit).Means.MonoR(:))-max(AllData(ith_unit).Means.MonoL(:)))/(max(AllData(ith_unit).Means.MonoL(:)) + max(AllData(ith_unit).Means.MonoR(:)));            
            if MIDTable.ODI(ith_unit) >= 0.5
                % contra is dominant
                MIDTable.ODI_Eye(ith_unit) = 'R';
                MIDTable.Dom_Coh_Corr(ith_unit) = corr(CoherenceArray', AllData(ith_unit).Means.MonoR);
                MIDTable.NonDom_Coh_Corr(ith_unit) = corr(CoherenceArray', AllData(ith_unit).Means.MonoL);
                MIDTable.DomCongruencyIndex(ith_unit) = MIDTable.Dom_Coh_Corr(ith_unit)*MIDTable.NonDom_Coh_Corr(ith_unit);
            else
                MIDTable.ODI_Eye(ith_unit) = 'L';
                MIDTable.Dom_Coh_Corr(ith_unit) = corr(CoherenceArray', AllData(ith_unit).Means.MonoL);
                MIDTable.NonDom_Coh_Corr(ith_unit) = corr(CoherenceArray', AllData(ith_unit).Means.MonoR);
                MIDTable.DomCongruencyIndex(ith_unit) = MIDTable.Dom_Coh_Corr(ith_unit)*MIDTable.NonDom_Coh_Corr(ith_unit);
            end
    end
    
    % OD based on the maximum normalized difference of concurrent
    % stimulation
    MIDTable.OD_Concurrent(ith_unit) =  max(abs((AllData(ith_unit).Means.MonoR - AllData(ith_unit).Means.MonoL)./(AllData(ith_unit).Means.MonoR + AllData(ith_unit).Means.MonoL)));
    
    
    % Use an AI to determine OD
    MIDTable.OD_Persp_3D_AI(ith_unit) = AssymetryIndex(AllData(ith_unit).MonoR, AllData(ith_unit).MonoL); % Matched by 3D direction
    MIDTable.OD_Persp_2D_AI(ith_unit) = AssymetryIndex(AllData(ith_unit).MonoR, flipud(AllData(ith_unit).MonoL)); % Matched by 2D (retinal) direction
    
    if all([LateralMotionTable.ODI_2D(ith_unit)<0.5, strcmp(MIDTable.Monkey{ith_unit},'Jim')]) || all([LateralMotionTable.ODI_2D(ith_unit)>0.5, strcmp(MIDTable.Monkey{ith_unit},'Clay')])
        % Dominant is right eye
        [ MIDTable.dominant_mono_stereo_corr_coef(ith_unit),  MIDTable.dominant_mono_stereo_corr_p(ith_unit)] = corr(AllData(ith_unit).Means.MonoR,AllData(ith_unit).Means.Bino);
        [ MIDTable.nondominant_mono_stereo_corr_coef(ith_unit),  MIDTable.nondominant_mono_stereo_corr_p(ith_unit)] = corr(AllData(ith_unit).Means.MonoL,AllData(ith_unit).Means.Bino);
        [ MIDTable.dominant_mono_comb_corr_coef(ith_unit),  MIDTable.dominant_mono_comb_corr_p(ith_unit)] = corr(AllData(ith_unit).Means.MonoR,AllData(ith_unit).Means.Combined);
        [ MIDTable.nondominant_mono_comb_corr_coef(ith_unit),  MIDTable.nondominant_comb_stereo_corr_p(ith_unit)] = corr(AllData(ith_unit).Means.MonoL,AllData(ith_unit).Means.Combined);
        [ MIDTable.dominant_nondominant_corr_coef(ith_unit),  MIDTable.dominant_nondominant_corr_p(ith_unit)] = corr(AllData(ith_unit).Means.MonoR,AllData(ith_unit).Means.MonoL);

    else
        [ MIDTable.dominant_mono_stereo_corr_coef(ith_unit),  MIDTable.dominant_mono_stereo_corr_p(ith_unit)] = corr(AllData(ith_unit).Means.MonoL,AllData(ith_unit).Means.Bino);
        [ MIDTable.nondominant_mono_stereo_corr_coef(ith_unit),  MIDTable.nondominant_mono_stereo_corr_p(ith_unit)] = corr(AllData(ith_unit).Means.MonoR,AllData(ith_unit).Means.Bino);
        [ MIDTable.dominant_mono_comb_corr_coef(ith_unit),  MIDTable.dominant_mono_comb_corr_p(ith_unit)] = corr(AllData(ith_unit).Means.MonoL,AllData(ith_unit).Means.Combined);
        [ MIDTable.nondominant_mono_comb_corr_coef(ith_unit),  MIDTable.nondominant_mono_comb_corr_p(ith_unit)] = corr(AllData(ith_unit).Means.MonoR,AllData(ith_unit).Means.Combined);
        [ MIDTable.dominant_nondominant_corr_coef(ith_unit),  MIDTable.dominant_nondominant_corr_p(ith_unit)] = corr(AllData(ith_unit).Means.MonoL,AllData(ith_unit).Means.MonoR);

    end
    % Correlations between the two eyes responses:
    [ MIDTable.monocular_corr_coef(ith_unit),  MIDTable.monocular_corr_p(ith_unit)] = corr(AllData(ith_unit).Means.MonoL,AllData(ith_unit).Means.MonoR);
    [ MIDTable.inv_monocular_corr_coef(ith_unit),  MIDTable.inv_monocular_corr_p(ith_unit)] = corr(AllData(ith_unit).Means.MonoL,flipud(AllData(ith_unit).Means.MonoR));
    
    %% Calculate fano factors
    fano_factors.Combined(ith_unit,:) = var(AllData(ith_unit).Combined,[],2,'omitnan')./ AllData(ith_unit).Means.Combined;
    fano_factors.MonoL(ith_unit,:) = var(AllData(ith_unit).MonoL,[],2,'omitnan')./ AllData(ith_unit).Means.MonoL;
    fano_factors.MonoR(ith_unit,:) = var(AllData(ith_unit).MonoR,[],2,'omitnan')./ AllData(ith_unit).Means.MonoR;
    fano_factors.Bino(ith_unit,:) = var(AllData(ith_unit).Bino,[],2,'omitnan')./ AllData(ith_unit).Means.Bino;
    
    
    Z_Scored_SDF_Time_Saccade_Towards{ith_unit} = squeeze(MotionData_ByStim(f).mean_zscore_SDF_Time_Saccade_Towards(1,selected_unit,:));
    Z_Scored_SDF_Time_Saccade_Away{ith_unit} = squeeze(MotionData_ByStim(f).mean_zscore_SDF_Time_Saccade_Away(1,selected_unit,:));
    Z_Scored_SDF_Saccade_Towards{ith_unit} = squeeze(MotionData_ByStim(f).mean_zscore_SDF_Saccade_Towards(1,selected_unit,:));
    Z_Scored_SDF_Saccade_Away{ith_unit} = squeeze(MotionData_ByStim(f).mean_zscore_SDF_Saccade_Away(1,selected_unit,:));
    
    %% SDF & Neurometric responses - gather for future fitting if desired
    % depends on the cell preference
    if MIDTable.Combined_AI(ith_unit) > 0
        Z_Scored_SDF_Time_Pref{ith_unit} = squeeze(MotionData_ByStim(f).mean_zscore_SDF_Time_Towards(1,selected_unit,:));
        Z_Scored_SDF_Time_NonPref{ith_unit} = squeeze(MotionData_ByStim(f).mean_zscore_SDF_Time_Away(1,selected_unit,:));
        Z_Scored_SDF_Pref{ith_unit} = squeeze(MotionData_ByStim(f).mean_zscore_SDF_Towards(1,selected_unit,:));
        Z_Scored_SDF_NonPref{ith_unit} = squeeze(MotionData_ByStim(f).mean_zscore_SDF_Away(1,selected_unit,:));
        
        
    else
        Z_Scored_SDF_Time_Pref{ith_unit} = squeeze(MotionData_ByStim(f).mean_zscore_SDF_Time_Away(1,selected_unit,:));
        Z_Scored_SDF_Time_NonPref{ith_unit} = squeeze(MotionData_ByStim(f).mean_zscore_SDF_Time_Towards(1,selected_unit,:));
        Z_Scored_SDF_Pref{ith_unit} = squeeze(MotionData_ByStim(f).mean_zscore_SDF_Away(1,selected_unit,:));
        Z_Scored_SDF_NonPref{ith_unit} = squeeze(MotionData_ByStim(f).mean_zscore_SDF_Towards(1,selected_unit,:));
        
    end
    
    %% Anovas & other stats
    for coh = 1:size(AllData(ith_unit).Combined,1)/2
        % (1) One-way Anova with main effect of direction
        Anovas.one_way.Combined(ith_unit,coh) =  anova1([AllData(ith_unit).Combined(coh,:); AllData(ith_unit).Combined(end-(coh-1),:)]',[],'off');
        Anovas.one_way.MonoL(ith_unit,coh) =  anova1([AllData(ith_unit).MonoL(coh,:); AllData(ith_unit).MonoL(end-(coh-1),:)]',[],'off');
        Anovas.one_way.MonoR(ith_unit,coh) =  anova1([AllData(ith_unit).MonoR(coh,:); AllData(ith_unit).MonoR(end-(coh-1),:)]',[],'off');
        Anovas.one_way.Bino(ith_unit,coh) =  anova1([AllData(ith_unit).Bino(coh,:); AllData(ith_unit).Bino(end-(coh-1),:)]',[],'off');
        
        Ranksum.Combined(ith_unit,coh) =  ranksum(AllData(ith_unit).Combined(coh,:), AllData(ith_unit).Combined(end-(coh-1),:));
        Ranksum.MonoL(ith_unit,coh) =  ranksum(AllData(ith_unit).MonoL(coh,:), AllData(ith_unit).MonoL(end-(coh-1),:));
        Ranksum.MonoR(ith_unit,coh) =  ranksum(AllData(ith_unit).MonoR(coh,:), AllData(ith_unit).MonoR(end-(coh-1),:));
        Ranksum.Bino(ith_unit,coh) =  ranksum(AllData(ith_unit).Bino(coh,:), AllData(ith_unit).Bino(end-(coh-1),:));
        
    end
    
    coherence_labels = repmat(transpose(1:6),1, size(AllData(ith_unit).MonoL,2));
    for cond = 1:4
        switch cond
            case 1
                away_data = AllData(ith_unit).Combined(1:6,:);
                towards_data = flipud(AllData(ith_unit).Combined(8:end,:));
            case 2
                away_data = AllData(ith_unit).MonoL(1:6,:);
                towards_data = flipud(AllData(ith_unit).MonoL(8:end,:));
            case 3
                away_data = AllData(ith_unit).MonoR(1:6,:);
                towards_data = flipud(AllData(ith_unit).MonoR(8:end,:));
            case 4
                away_data = AllData(ith_unit).Bino(1:6,:);
                towards_data = flipud(AllData(ith_unit).Bino(8:end,:));
        end
        away_data = away_data(:);
        away_coh_labels = coherence_labels(:);
        away_coh_labels = away_coh_labels(~isnan(away_data));
        away_data = away_data(~isnan(away_data));
        away_labels = zeros(length(away_data),1);
        
        towards_data = towards_data(:);
        towards_coh_labels = coherence_labels(:);
        towards_coh_labels = towards_coh_labels(~isnan(towards_data));
        towards_data = towards_data(~isnan(towards_data));
        towards_labels = ones(length(towards_data),1);
        
        % now collapse for anova
        direction_anova_data = [away_data; towards_data];
        direction_anova_labels = {[away_labels; towards_labels], [away_coh_labels; towards_coh_labels]};
        direction_anova_p(cond,:) = anovan(direction_anova_data, direction_anova_labels, 'varnames', {'Direction','Coherence'},'display','off');
    end
    
    Anovas.two_way_p.Combined(ith_unit,:) = direction_anova_p(1,:);
    Anovas.two_way_p.MonoL(ith_unit,:) = direction_anova_p(2,:);
    Anovas.two_way_p.MonoR(ith_unit,:) = direction_anova_p(3,:);
    Anovas.two_way_p.Bino(ith_unit,:) = direction_anova_p(4,:);
    
    
    %% Modeling results
    if ith_unit == 1
        model_errors = struct2table(MotionData_ByStim(f).ModelErrors(selected_unit));
        model_weights = struct2table(MotionData_ByStim(f).ModelWeights(selected_unit));
    else
        temp = struct2table(MotionData_ByStim(f).ModelErrors(selected_unit));
        temp_weights = struct2table(MotionData_ByStim(f).ModelWeights(selected_unit));
        model_errors = [model_errors; temp];
        model_weights = [model_weights; temp_weights];
        if isempty(temp) || isempty(temp_weights)
            error(['No model weights for unit: ', num2str(ith_unit)]);
        end
    end
    
end
MIDTable = [MIDTable, model_weights];
MIDTable.ROC_sig = (MIDTable.ROC_CI(:,2)>0.5 & MIDTable.ROC_CI(:,1)>0.5) | (MIDTable.ROC_CI(:,2)<0.5 & MIDTable.ROC_CI(:,1)<0.5);
MIDTable.sig_Anova2_Combined = [Anovas.two_way_p.Combined(:,1) < 0.05]; %, Anovas.two_way_p.Combined(:,2) < 0.05];
MIDTable.sig_Anova2_MonoL = [Anovas.two_way_p.MonoL(:,1) < 0.05]; % Anovas.two_way_p.MonoL(:,2) < 0.05];
MIDTable.sig_Anova2_MonoR = [Anovas.two_way_p.MonoR(:,1) < 0.05]; % Anovas.two_way_p.MonoR(:,2) < 0.05];
MIDTable.sig_Anova2_Bino = [Anovas.two_way_p.Bino(:,1) < 0.05]; % Anovas.two_way_p.Bino(:,2) < 0.05];
MIDTable.sig_Anova2_Coherence_Combined = [Anovas.two_way_p.Combined(:,2) < 0.05];
MIDTable.sig_Anova2_Coherence_MonoL = [Anovas.two_way_p.MonoL(:,2) < 0.05];
MIDTable.sig_Anova2_Coherence_MonoR = [Anovas.two_way_p.MonoR(:,2) < 0.05];
MIDTable.sig_Anova2_Coherence_Bino = [Anovas.two_way_p.Bino(:,2) < 0.05];
MIDTable.sig_Anova_All = all([MIDTable.sig_Anova2_Combined, MIDTable.sig_Anova2_MonoL, MIDTable.sig_Anova2_MonoR, MIDTable.sig_Anova2_Bino],2);
MIDTable.sig_Anova_CLR = all([MIDTable.sig_Anova2_Combined, MIDTable.sig_Anova2_MonoL, MIDTable.sig_Anova2_MonoR],2);

% U shaped cells
MIDTable.U_shape = (MIDTable.monocular_corr_coef>0 & MIDTable.inv_monocular_corr_coef>0);

%% Extract means

for u= 1:size(MIDTable,1)
    AllData(u).model_weights = model_weights(u,:);
    Combined_Means(:,u) = AllData(u).Means.Combined;
    MonoL_Means(:,u) = AllData(u).Means.MonoL;
    MonoR_Means(:,u) = AllData(u).Means.MonoR;
    Bino_Means(:,u) = AllData(u).Means.Bino;
    Bino_100_means(:,u) = AllData(u).Means.Bino([1,end]);
    ControlL_Means(:,u) = AllData(u).Means.ControlL;
    ControlR_Means(:,u) = AllData(u).Means.ControlR;
    ControlBL_Means(:,u) = AllData(u).Means.ControlBL;
    ControlBR_Means(:,u) = AllData(u).Means.ControlBR;
end
BehavioralDataPlots


end
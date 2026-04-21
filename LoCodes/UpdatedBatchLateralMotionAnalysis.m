%% Batch Lateral Motion Analysis
function [LateralMotionTable, LateralMotionData] = UpdatedBatchLateralMotionAnalysis(LateralMotionTable, files, varargin)

% (1) Select files
% (2) Run LateralMotionTuning
% (3) Extract "good" units
% (4) Sort/arrange as necessary
% (5) Run the desired analyses

% default input options (varargin)
options = struct('reanalyze', 0,       ...   
                 'trialBased', 0,        ...
                 'area', 'FST',         ...
                 'plotFlag', 0);

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

%% (2) Run 2D Analysis

for f = 1:size(files,1)
    tic;
    m = extractBetween(files.Paths(f),'\','\');
    options.area = files.ROI{f}; 
    monkey = m{1};
    save_location = ['C:\', monkey, '\In_Processing\', options.area,'\2D'];
    
    if ~options.reanalyze
        % Grab the names of previously analyzed data without loading the data
        % into memory
        previousData = dir([save_location,'\','*.mat']);
        if ~isempty(previousData)
            previousData = extractfield(previousData,'name'); % Requires Mapping Toolbox
            previousData = extractBefore(previousData,'.mat');
        else
            previousData = {};
        end
    end
    
    Units{f} = files.Units{f,:};
    disp(['Calculating 2D Motion Tuning Curves: ' files.Names{f}(8:16), ' TT: ', num2str(files.Tetrode(f)), '; ' num2str(f) '/' num2str(size(files,1))])
    saveToStruct = extractBefore(files.Names{f,1},'_Lateral'); % Name for this recording
    saveToStruct = replace(saveToStruct, '-','_'); % Can't have dashes in fieldnames
    fieldOrder.(saveToStruct) = []; % If data was saved in an order different from the way it is extracted from the table, you need to reorder it - create an empty structure with the properly ordered field names.
    % Check if you have already analyzed this file (and aren't reanalyzing)
    if options.reanalyze || ~ismember(saveToStruct,previousData)
        % Create temporary structure where each field is a file name - one
        % with raw trial-based data (if desired) and one with FRs separated by stimulus type
        LMData.(saveToStruct) =  Offline_LateralMotionTuning(files.Paths(f),files.Names(f,:), options.plotFlag); 
        
        disp('Saving data...');
        try
            save(fullfile(save_location, [saveToStruct,'.mat']),'-struct', 'LMData');
%             save(fullfile(save_location, 'MotionData_ByStim.mat'),'-struct', 'temp_ByStim', saveToStruct, '-append'); % Add new recording field to saved data structure
        catch e
            disp('Unable to save');
            disp('Saving separate file...');
            save(fullfile(save_location, ['MotionData_ByStim_', saveToStruct, '.mat']),'-struct', 'temp_ByStim', saveToStruct);
        end
        clear LMData; % clear the temporary data structures since it is huge and we may load many.
    else
        % This file has already been analyzed, no need to do it again
        disp('Data already exists, skipping...');
    end
    disp(num2str(toc));
end

disp('Loading all the condition separated data...');
data_to_load = (fieldnames(fieldOrder));
tic
visual_latency = 0;
for d = 1:size(data_to_load,1)
    m = extractBetween(files.Paths(d),'\','\');
    options.area = files.ROI{d}; 
    monkey = m{1};
    save_location = ['C:\', monkey, '\In_Processing\', options.area,'\2D'];
    LateralMotionData.(data_to_load{d}) = load(fullfile(save_location,[data_to_load{d},'.mat']));
    % Below is clunky and due to the way you save your struct - fix the way
    % you save and you shouldn't have to do this
    LateralMotionData.(data_to_load{d}) = LateralMotionData.(data_to_load{d}).(data_to_load{d});

    LateralMotionData.(data_to_load{d}).AnaDataTbl = []; % Lots of memory here
end
fprintf('%6.2f sec', toc);
LateralMotionData = orderfields(LateralMotionData,fieldOrder); % Ensure that the loaded data and extracted table are in the same order.
% Concatenate all the individual strucutres into a struct array
temp = struct2cell(LateralMotionData);
LateralMotionData = horzcat(temp{:});
clear temp

%% (4) Sort/Arrange
% Most of the data structures inside LateralMotionData will be size:
% (conditions x speeds x units).
% For Jim, some data will be (3 x 1 x units) and others (3 x 2 x units)
% This makes using a table rather difficult.
% Assume that each input (unit) in the table will be (n=speeds) long
% Hard coded to be n = 2 right now, will need to be fixed if using more
% speeds.

Von_Params = [];
DI_values = [];
r_values = [];
clear temp;
LateralMotionTable.Both_Kappa = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Both_Mu = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Both_Ray_p = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Left_Ray_p = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Left_Kappa = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Left_Mu = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Right_Ray_p = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Right_Kappa = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Right_Mu = nan(size(LateralMotionTable,1),2);

LateralMotionTable.Axial_Both_Kappa = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Axial_Both_Mu = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Axial_Left_Kappa = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Axial_Left_Mu = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Axial_Right_Kappa = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Axial_Right_Mu = nan(size(LateralMotionTable,1),2);

LateralMotionTable.Comp_Axial_Both_Gain1 = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Axial_Both_Gain2 = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Axial_Left_Gain1 = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Axial_Left_Gain2 = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Axial_Right_Gain1 = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Axial_Right_Gain2 = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Axial_Both_Kappa1 = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Axial_Both_Kappa2 = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Axial_Both_Mu = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Axial_Left_Kappa1 = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Axial_Left_Kappa2 = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Axial_Left_Mu = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Axial_Right_Kappa1 = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Axial_Right_Kappa2 = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Axial_Right_Mu = nan(size(LateralMotionTable,1),2);

LateralMotionTable.Both_r = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Left_r = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Right_r = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Both_p = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Left_p = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Right_p = nan(size(LateralMotionTable,1),2);

LateralMotionTable.Axial_Both_r = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Axial_Left_r = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Axial_Right_r = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Axial_Both_p = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Axial_Left_p = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Axial_Right_p = nan(size(LateralMotionTable,1),2);

LateralMotionTable.Comp_Axial_Both_r = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Axial_Left_r = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Axial_Right_r = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Axial_Both_p = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Axial_Left_p = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Axial_Right_p = nan(size(LateralMotionTable,1),2);

LateralMotionTable.mono_weights = nan(size(LateralMotionTable,1),2);
LateralMotionTable.both_dir_vec = nan(size(LateralMotionTable,1),2);
LateralMotionTable.both_dir_mag = nan(size(LateralMotionTable,1),2);
LateralMotionTable.left_anova_one_way = nan(size(LateralMotionTable,1),2);
LateralMotionTable.right_anova_one_way = nan(size(LateralMotionTable,1),2);
LateralMotionTable.both_anova_one_way = nan(size(LateralMotionTable,1),2);
LateralMotionTable.DI_both = nan(size(LateralMotionTable,1),2);
LateralMotionTable.DI_left = nan(size(LateralMotionTable,1),2);
LateralMotionTable.DI_right = nan(size(LateralMotionTable,1),2);

LateralMotionTable.DI_LR_both = nan(size(LateralMotionTable,1),2);
LateralMotionTable.DI_LR_left = nan(size(LateralMotionTable,1),2);
LateralMotionTable.DI_LR_right = nan(size(LateralMotionTable,1),2);

LateralMotionTable.DI_UD_both = nan(size(LateralMotionTable,1),2);
LateralMotionTable.DI_UD_left = nan(size(LateralMotionTable,1),2);
LateralMotionTable.DI_UD_right = nan(size(LateralMotionTable,1),2);
LateralMotionTable.DTI_both = nan(size(LateralMotionTable,1),2);
LateralMotionTable.DTI_left = nan(size(LateralMotionTable,1),2);
LateralMotionTable.DTI_right = nan(size(LateralMotionTable,1),2);
LateralMotionTable.ATI_both = nan(size(LateralMotionTable,1),2);
LateralMotionTable.ATI_left = nan(size(LateralMotionTable,1),2);
LateralMotionTable.ATI_right = nan(size(LateralMotionTable,1),2);
LateralMotionTable.ODI_2D = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Monocularity_2D_Max = nan(size(LateralMotionTable,1),2);
LateralMotionTable.ODI_Eye_2D = nan(size(LateralMotionTable,1),1);
LateralMotionTable.corr_r_both = nan(size(LateralMotionTable,1),2);
LateralMotionTable.corr_p_both = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Both_r_corr_reg_ax = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Both_p_corr_reg_ax = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Left_r_corr_reg_ax = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Left_p_corr_reg_ax = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Right_r_corr_reg_ax = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Right_p_corr_reg_ax = nan(size(LateralMotionTable,1),2);

LateralMotionTable.Both_r_corr_reg_ax_comp = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Both_p_corr_reg_ax_comp = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Left_r_corr_reg_ax_comp = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Left_p_corr_reg_ax_comp = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Right_r_corr_reg_ax_comp = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Right_p_corr_reg_ax_comp = nan(size(LateralMotionTable,1),2);

LateralMotionTable.Both_R_PD = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Both_R_PA = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Both_Z_PD = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Both_Z_PA = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Both_R_PD = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Both_R_PA = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Both_Z_PD = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Both_Z_PA = nan(size(LateralMotionTable,1),2);

LateralMotionTable.Left_R_PD = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Left_R_PA = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Left_Z_PD = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Left_Z_PA = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Left_R_PD = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Left_R_PA = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Left_Z_PD = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Left_Z_PA = nan(size(LateralMotionTable,1),2);

LateralMotionTable.Right_R_PD = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Right_R_PA = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Right_Z_PD = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Right_Z_PA = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Right_R_PD = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Right_R_PA = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Right_Z_PD = nan(size(LateralMotionTable,1),2);
LateralMotionTable.Comp_Right_Z_PA = nan(size(LateralMotionTable,1),2);
LateralMotionTable.latency = nan(size(LateralMotionTable,1),1);
u = 1;
ind = 1;
for f = 1:size(files,1)
    if size(squeeze(LateralMotionData(f).VonMisesParams(3,:,3,Units{f}))',1) == 1
       i = 1; 
    else
        i = ':';
    end
    if visual_latency
        LateralMotionTable.latency(u:u+length(Units{f})-1) = DrawSpkRaster(files.Paths(f),files.Names(f,:), 1, Units{f}, struct());
    end
    for uni = 1:length(Units{f})
        % Calculate horizontal and vertical DI values
        
        
        disp(['Fitting Von Mises curves for unit: ', num2str(ind),'/', num2str(size(LateralMotionTable,1))]);
        [VM(ind), VM_axial(ind)] = VM_Axial_Fitting(LateralMotionData(f).meanFR,Units{f}(uni));
        %         saveas(gcf,['P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\AllProperties\2DFits\VMFit_', datestr(LateralMotionTable.Date(ind)),'_TT', num2str(LateralMotionTable.Tetrode(ind)), '_U', num2str(u),'.pdf']);
        %         close(gcf);
        
        
        
        % Extract fitting parameters and correlations
        LateralMotionTable.Both_r_corr_reg_ax(ind,i) = VM(ind).r_corr_reg_ax(3,i);
        LateralMotionTable.Both_p_corr_reg_ax(ind,i) = VM(ind).p_corr_reg_ax(3,i);
        LateralMotionTable.Left_r_corr_reg_ax(ind,i) = VM(ind).r_corr_reg_ax(1,i);
        LateralMotionTable.Left_p_corr_reg_ax(ind,i) = VM(ind).p_corr_reg_ax(1,i);
        LateralMotionTable.Right_r_corr_reg_ax(ind,i) = VM(ind).r_corr_reg_ax(2,i);
        LateralMotionTable.Right_p_corr_reg_ax(ind,i) = VM(ind).p_corr_reg_ax(2,i); 
        
        LateralMotionTable.Both_r_corr_reg_ax_comp(ind,i) = VM(ind).r_corr_reg_ax_comp(3,i);
        LateralMotionTable.Both_p_corr_reg_ax_comp(ind,i) = VM(ind).p_corr_reg_ax_comp(3,i);
        LateralMotionTable.Left_r_corr_reg_ax_comp(ind,i) = VM(ind).r_corr_reg_ax_comp(1,i);
        LateralMotionTable.Left_p_corr_reg_ax_comp(ind,i) = VM(ind).p_corr_reg_ax_comp(1,i);
        LateralMotionTable.Right_r_corr_reg_ax_comp(ind,i) = VM(ind).r_corr_reg_ax_comp(2,i);
        LateralMotionTable.Right_p_corr_reg_ax_comp(ind,i) = VM(ind).p_corr_reg_ax_comp(2,i); 
        
        LateralMotionTable.Both_Kappa(ind,i) = VM(ind).phat(3,i,3);
        LateralMotionTable.Both_Mu(ind,i) = VM(ind).phat(3,i,4);
        LateralMotionTable.Left_Kappa(ind,i) = VM(ind).phat(1,i,3);
        LateralMotionTable.Left_Mu(ind,i) = VM(ind).phat(1,i,4);
        LateralMotionTable.Right_Kappa(ind,i) = VM(ind).phat(2,i,3);
        LateralMotionTable.Right_Mu(ind,i) = VM(ind).phat(2,i,4);
        
        LateralMotionTable.Both_r(ind,i) = VM(ind).r_corr(3,i);
        LateralMotionTable.Left_r(ind,i) = VM(ind).r_corr(1,i);
        LateralMotionTable.Right_r(ind,i) = VM(ind).r_corr(2,i);
        LateralMotionTable.Both_p(ind,i) = VM(ind).p_corr(3,i);
        LateralMotionTable.Left_p(ind,i) = VM(ind).p_corr(1,i);
        LateralMotionTable.Right_p(ind,i) = VM(ind).p_corr(2,i);
        
        LateralMotionTable.Axial_Both_Kappa(ind,i) = VM_axial(ind).phat_ax(3,i,3);
        LateralMotionTable.Axial_Both_Mu(ind,i) = VM_axial(ind).phat_ax(3,i,4);
        LateralMotionTable.Axial_Left_Kappa(ind,i) = VM_axial(ind).phat_ax(1,i,3);
        LateralMotionTable.Axial_Left_Mu(ind,i) = VM_axial(ind).phat_ax(1,i,4);
        LateralMotionTable.Axial_Right_Kappa(ind,i) = VM_axial(ind).phat_ax(2,i,3);
        LateralMotionTable.Axial_Right_Mu(ind,i) = VM_axial(ind).phat_ax(2,i,4);
        
        LateralMotionTable.Axial_Both_r(ind,i) = VM_axial(ind).r_corr_ax(3,i);
        LateralMotionTable.Axial_Left_r(ind,i) = VM_axial(ind).r_corr_ax(1,i);
        LateralMotionTable.Axial_Right_r(ind,i) = VM_axial(ind).r_corr_ax(2,i);
        LateralMotionTable.Axial_Both_p(ind,i) = VM_axial(ind).p_corr_ax(3,i);
        LateralMotionTable.Axial_Left_p(ind,i) = VM_axial(ind).p_corr_ax(1,i);
        LateralMotionTable.Axial_Right_p(ind,i) = VM_axial(ind).p_corr_ax(2,i);
        
        % complex axial
        LateralMotionTable.Comp_Axial_Both_Kappa1(ind,i) = VM_axial(ind).phat_ax_comp(3,i,3);
        LateralMotionTable.Comp_Axial_Both_Kappa2(ind,i) = VM_axial(ind).phat_ax_comp(3,i,6);
        LateralMotionTable.Comp_Axial_Both_Gain1(ind,i) = VM_axial(ind).phat_ax_comp(3,i,2);
        LateralMotionTable.Comp_Axial_Both_Gain2(ind,i) = VM_axial(ind).phat_ax_comp(3,i,5);
        LateralMotionTable.Comp_Axial_Both_Mu(ind,i) = VM_axial(ind).phat_ax_comp(3,i,4);
        LateralMotionTable.Comp_Axial_Left_Kappa1(ind,i) = VM_axial(ind).phat_ax_comp(1,i,3);
        LateralMotionTable.Comp_Axial_Left_Kappa2(ind,i) = VM_axial(ind).phat_ax_comp(1,i,6);
        LateralMotionTable.Comp_Axial_Left_Gain1(ind,i) = VM_axial(ind).phat_ax_comp(1,i,2);
        LateralMotionTable.Comp_Axial_Left_Gain2(ind,i) = VM_axial(ind).phat_ax_comp(1,i,5);
        LateralMotionTable.Comp_Axial_Left_Mu(ind,i) = VM_axial(ind).phat_ax_comp(1,i,4);
        LateralMotionTable.Comp_Axial_Right_Kappa1(ind,i) = VM_axial(ind).phat_ax_comp(2,i,3);
        LateralMotionTable.Comp_Axial_Right_Kappa2(ind,i) = VM_axial(ind).phat_ax_comp(2,i,6);
        LateralMotionTable.Comp_Axial_Right_Gain1(ind,i) = VM_axial(ind).phat_ax_comp(2,i,2);
        LateralMotionTable.Comp_Axial_Right_Gain2(ind,i) = VM_axial(ind).phat_ax_comp(2,i,5);
        LateralMotionTable.Comp_Axial_Right_Mu(ind,i) = VM_axial(ind).phat_ax_comp(2,i,4);
        
        LateralMotionTable.Comp_Axial_Both_r(ind,i) = VM_axial(ind).r_corr_ax_comp(3,i);
        LateralMotionTable.Comp_Axial_Left_r(ind,i) = VM_axial(ind).r_corr_ax_comp(1,i);
        LateralMotionTable.Comp_Axial_Right_r(ind,i) = VM_axial(ind).r_corr_ax_comp(2,i);
        LateralMotionTable.Comp_Axial_Both_p(ind,i) = VM_axial(ind).p_corr_ax_comp(3,i);
        LateralMotionTable.Comp_Axial_Left_p(ind,i) = VM_axial(ind).p_corr_ax_comp(1,i);
        LateralMotionTable.Comp_Axial_Right_p(ind,i) = VM_axial(ind).p_corr_ax_comp(2,i);
        
        % partial correlations
        [LateralMotionTable.Both_R_PD(ind,i), LateralMotionTable.Both_R_PA(ind,i), LateralMotionTable.Both_Z_PD(ind,i), LateralMotionTable.Both_Z_PA(ind,i)] =...
            partial_corr_custom(LateralMotionTable.Both_r(ind,i), LateralMotionTable.Axial_Both_r(ind,i), LateralMotionTable.Both_r_corr_reg_ax(ind,i), 8);
        [LateralMotionTable.Left_R_PD(ind,i), LateralMotionTable.Left_R_PA(ind,i), LateralMotionTable.Left_Z_PD(ind,i), LateralMotionTable.Left_Z_PA(ind,i)] =...
            partial_corr_custom(LateralMotionTable.Left_r(ind,i), LateralMotionTable.Axial_Left_r(ind,i), LateralMotionTable.Left_r_corr_reg_ax(ind,i), 8);
        [LateralMotionTable.Right_R_PD(ind,i), LateralMotionTable.Right_R_PA(ind,i), LateralMotionTable.Right_Z_PD(ind,i), LateralMotionTable.Right_Z_PA(ind,i)] =...
            partial_corr_custom(LateralMotionTable.Right_r(ind,i), LateralMotionTable.Axial_Right_r(ind,i), LateralMotionTable.Right_r_corr_reg_ax(ind,i), 8);
        
        [LateralMotionTable.Comp_Both_R_PD(ind,i), LateralMotionTable.Comp_Both_R_PA(ind,i), LateralMotionTable.Comp_Both_Z_PD(ind,i), LateralMotionTable.Comp_Both_Z_PA(ind,i)] =...
            partial_corr_custom(LateralMotionTable.Both_r(ind,i), LateralMotionTable.Comp_Axial_Both_r(ind,i), LateralMotionTable.Both_r_corr_reg_ax_comp(ind,i), 8);
        [LateralMotionTable.Comp_Left_R_PD(ind,i), LateralMotionTable.Comp_Left_R_PA(ind,i), LateralMotionTable.Comp_Left_Z_PD(ind,i), LateralMotionTable.Comp_Left_Z_PA(ind,i)] =...
            partial_corr_custom(LateralMotionTable.Left_r(ind,i), LateralMotionTable.Comp_Axial_Left_r(ind,i), LateralMotionTable.Left_r_corr_reg_ax_comp(ind,i), 8);
        [LateralMotionTable.Comp_Right_R_PD(ind,i), LateralMotionTable.Comp_Right_R_PA(ind,i), LateralMotionTable.Comp_Right_Z_PD(ind,i), LateralMotionTable.Comp_Right_Z_PA(ind,i)] =...
            partial_corr_custom(LateralMotionTable.Right_r(ind,i), LateralMotionTable.Comp_Axial_Right_r(ind,i), LateralMotionTable.Right_r_corr_reg_ax_comp(ind,i), 8);
        
        % Another analysis we need to do that isn't in the main
        % OfflineLateralMotion script is determine the "preferred" speed
        % (not actually since we don't have a speed tuning curve)
        if i == 1 % if only 1 speed, then the preferred speed is the slow speed
            LateralMotionTable.PrefSpeed(ind,:) = [1 1 1];
        else
            %meanFR(e,d,s,u)
            % Using same calculation as ODI but for speeds, comparing the
            % faster speed relative to the sum of the 2 speeds
            SDI =...
                [nanmean(LateralMotionData(f).meanFR(1,:,2,Units{f}(uni)),'all')./(nanmean(LateralMotionData(f).meanFR(1,:,2,Units{f}(uni)),'all') + nanmean(LateralMotionData(f).meanFR(1,:,1,Units{f}(uni)),'all')),...
                nanmean(LateralMotionData(f).meanFR(2,:,2,Units{f}(uni)),'all')./(nanmean(LateralMotionData(f).meanFR(2,:,2,Units{f}(uni)),'all') + nanmean(LateralMotionData(f).meanFR(2,:,1,Units{f}(uni)),'all')),...
                nanmean(LateralMotionData(f).meanFR(3,:,2,Units{f}(uni)),'all')./(nanmean(LateralMotionData(f).meanFR(3,:,2,Units{f}(uni)),'all') + nanmean(LateralMotionData(f).meanFR(3,:,1,Units{f}(uni)),'all'))];
            LateralMotionTable.PrefSpeed(ind,:) = [SDI(1)>0.5, SDI(2)>0.5, SDI(3)>0.5] + 1; % Values greater than 0.5 indicate fast speed (==2) is dominant
        end
        
        ind = ind+1;
    end
    
%     LateralMotionTable.Both_Kappa(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).VonMisesParams(3,:,3,Units{f}))';
%     LateralMotionTable.Both_Mu(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).VonMisesParams(3,:,4,Units{f}))';
%     LateralMotionTable.Left_Kappa(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).VonMisesParams(1,:,3,Units{f}))';
%     LateralMotionTable.Left_Mu(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).VonMisesParams(1,:,4,Units{f}))';
%     LateralMotionTable.Right_Kappa(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).VonMisesParams(2,:,3,Units{f}))';
%     LateralMotionTable.Right_Mu(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).VonMisesParams(2,:,4,Units{f}))';
%     
%     
    LateralMotionTable.Left_Ray_p(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).Rayleigh(1,:,Units{f}))';
    LateralMotionTable.Right_Ray_p(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).Rayleigh(2,:,Units{f}))';
    LateralMotionTable.Both_Ray_p(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).Rayleigh(3,:,Units{f}))';
    LateralMotionTable.DI_both(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).DIs(3,:,Units{f}))';
    LateralMotionTable.DI_left(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).DIs(1,:,Units{f}))';
    LateralMotionTable.DI_right(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).DIs(2,:,Units{f}))';
    
    LateralMotionTable.DI_LR_both(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).DI_LR(3,:,Units{f}))';
    LateralMotionTable.DI_LR_left(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).DI_LR(1,:,Units{f}))';
    LateralMotionTable.DI_LR_right(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).DI_LR(2,:,Units{f}))';
    
    LateralMotionTable.DI_UD_both(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).DI_UD(3,:,Units{f}))';
    LateralMotionTable.DI_UD_left(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).DI_UD(1,:,Units{f}))';
    LateralMotionTable.DI_UD_right(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).DI_UD(2,:,Units{f}))';
    
    LateralMotionTable.corr_r_both(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).corr_r(3,:,Units{f}))';
    LateralMotionTable.corr_p_both(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).corr_p(3,:,Units{f}))';
    LateralMotionTable.both_dir_vec(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).norm_vec_dir(3,:,Units{f}))';
    LateralMotionTable.both_dir_mag(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).norm_vec_mag(3,:,Units{f}))';
    LateralMotionTable.left_anova_one_way(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).anova_one_way(1,:,Units{f}))';
    LateralMotionTable.right_anova_one_way(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).anova_one_way(2,:,Units{f}))';
    LateralMotionTable.both_anova_one_way(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).anova_one_way(3,:,Units{f}))';
    LateralMotionTable.DTI_both(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).DTI(3,:,Units{f}))';
    LateralMotionTable.DTI_left(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).DTI(1,:,Units{f}))';
    LateralMotionTable.DTI_right(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).DTI(2,:,Units{f}))';
    LateralMotionTable.ATI_both(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).ATI(3,:,Units{f}))';
    LateralMotionTable.ATI_left(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).ATI(1,:,Units{f}))';
    LateralMotionTable.ATI_right(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).ATI(2,:,Units{f}))';
    LateralMotionTable.ODI_2D(u:u+length(Units{f})-1) = squeeze(LateralMotionData(f).ODI_2D(Units{f}))';
    LateralMotionTable.Monocularity_2D_Max(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).Monocularity_2D_Max(:,Units{f}))';
    LateralMotionTable.ODI_Eye_2D(u:u+length(Units{f})-1,i) = squeeze(LateralMotionData(f).ODI_Eye_2D(:,Units{f}))';

    u = u + length(Units{f});
end
% Note that this finds significant tuning based on a one-way anova for BOTH
% speeds
LateralMotionTable.sig_anova_both = all(LateralMotionTable.both_anova_one_way < 0.05,2);
LateralMotionTable.sig_anova_either = any(LateralMotionTable.both_anova_one_way < 0.05,2);

%% (5) Run desired analyses


% f = Tuning_Comparisons2D(Von_Params,DI_values,LateralMotionTable);

%% (6) Additional plots
% figure;
% histogram(r_values);
% xlabel('von Mises Fit (r)');
% 
% figure; rose((squeeze(Von_Params(1,4,LateralMotionTable.Both_Watson<0.05))-squeeze(Von_Params(2,4,LateralMotionTable.Both_Watson<0.05)))*pi/180,[0:10:350]*pi/180)


%% Display info
% disp(['Both eye % with significant Rayleigh test: ', num2str(sum(LateralMotionTable.Both_Ray_p < 0.05)/size(LateralMotionTable,1)*100)]);
% disp(['Left eye % with significant Rayleigh test: ', num2str(sum(LateralMotionTable.Left_Ray_p < 0.05)/size(LateralMotionTable,1)*100)]);
% disp(['Right eye % with significant Rayleigh test: ', num2str(sum(LateralMotionTable.Right_Ray_p < 0.05)/size(LateralMotionTable,1)*100)]);
end
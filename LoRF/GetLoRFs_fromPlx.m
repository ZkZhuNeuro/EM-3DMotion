clear all
ElectrodeNums = [1:16];
ChannelMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]; % Edge Design Dorsal-->Ventral
% Define distance between channels
Distance = 0:50:50*(length(ChannelMap)-1); % 50 micrometers apart
monkeys = ["Jim"];
areas = ["FST"];
file_tag = {'SparseNoise'};

%% Get excel sheet with session information
xls_table = 'P:\Jim\NeuroData\RecordingRecord_MinusMissing.xlsx';
path_options = {'P:\Jim\NeuroData\'};
% exclusion_criteria = [{'InRF','N'}; {'ROI','MT/FST'}; {'ROI','MT?'}; {'WF',''};{'WF','N'}; {'RF','N'}; {'RF',''}];
exclusion_criteria = [{'ROI','MT/FST'}; {'ROI','N/A'}; {'ROI','MT?'}; {'ROI','Border'}; {'WF',''};{'WF','N'}; {'RF','N'}; {'RF',''}];
inclusion_criteria = [{'ROI','FST'}];

%% Read in the excel file
opts = detectImportOptions(xls_table, "Sheet","Sheet1");
opts.VariableNamesRange = "A1";   % header row
opts.DataRange          = "A2";   % data starts row 2
tb = readtable(xls_table, opts);
unit_table = table();

%% Use inclusion and exclusion criteria
if ~isempty(inclusion_criteria)
    for i = 1:size(inclusion_criteria,1)
        inclusion(:,i) = strcmp(tb.(inclusion_criteria{i,1}), inclusion_criteria{i,2}); % These are inclusion criteria that contain strings
    end
else
    inclusion = ones(size(tb,1),size(tb,2));
end

if ~isempty(exclusion_criteria)
    for e = 1:size(exclusion_criteria,1)
        exclusion(:,e) = strcmp(tb.(exclusion_criteria{e,1}), exclusion_criteria{e,2});
    end
else
    exclusion = zeros(size(tb,1),size(tb,2));
end
exclusion = any(exclusion,2);
inclusion = all(inclusion,2);
inclusion = logical(inclusion & ~exclusion);

%% Extract paths corresponding to each recording date that will be included
excel_table_inds = find(inclusion);
% Find the folders with the appropriate date
sorted_folders = dir(path_options{1});
if numel(path_options) > 1
    alt_sorts = dir(path_options{2});
    sorted_folders = [sorted_folders; alt_sorts];
end

names = {sorted_folders.name};

% keep only directories, exclude . and .., and require exactly 8 digits
isDir   = [sorted_folders.isdir];
isDot   = ismember(names, {'.','..'});
isDate8 = ~cellfun(@isempty, regexp(names, '^\d{8}$', 'once'));

keep = isDir & ~isDot & isDate8;

sorted_folders = sorted_folders(keep);
names = names(keep);

dn = datenum(names, 'yyyymmdd');           % now safe
[~, ia] = unique(dn, 'stable');            % stable keeps first occurrence (local before server if concatenated that way)
sorted_folders = sorted_folders(ia);

folder_dt = datetime(names,"InputFormat","yyyyMMdd");
excel_dt  = datetime(tb.Date(excel_table_inds));

[tf, inclusion_folder_indices] = ismember(excel_dt, folder_dt);

%% Step through each recording date and obtain the file names of interest
for recording_num = 1:length(inclusion_folder_indices)
% for recording_num = 73
    % Build structure of file paths and relevant waveform files
    recording_dir = dir(fullfile([sorted_folders(inclusion_folder_indices(recording_num)).folder, '/' sorted_folders(inclusion_folder_indices(recording_num)).name],'*.plx'));
    expression = file_tag;

    pattern = strjoin(expression, '|');   % 'MUA_SparseNoise|SparseNoise_MUA'

    names = {recording_dir.name};
    isMatch = ~cellfun(@isempty, regexp(names, pattern, 'once'));

    matches = recording_dir(isMatch);

    plx_file = reshape({matches.name}, [], 1);

    temp_table = table();
    temp_table.Paths = {fullfile(recording_dir(1).folder,'\')};
    temp_table.Names = {plx_file};
    unit_table = [unit_table; temp_table];

end


%%
%% Export Waveform Files from Offlinesorter (batch mode)
for ifolder = 1:size(unit_table, 1)
    for i_unit = 1:size(unit_table.Names{ifolder}, 1) % This should be based on TT not units. It works now but is redundant. 

        % [~,name,~] = fileparts(FName{ifile});
        PName = unit_table.Paths{ifolder};
        FName = unit_table.Names{ifolder}{i_unit};

        % PName = 'P:\Jim\NeuroData\20190918\';
        % FName = 'Jim_FST_18Sept2019_TT1_mrg_Sorted-02_SparseNoise.plx';

        % Create a batch file (.ofb file) in the path defined by PName.
        BatchF = [PName 'SparseNoiseWaveform.ofb'];
        if exist(BatchF,'file')==2
            delete(BatchF);
        end

        % Write the batch script in the new batch file.
        fID = fopen(BatchF,'w');
        fprintf(fID, '%s\n',['File ' [PName FName]]);
        fprintf(fID, '%s\n','ForEachFile ExportWaveformInfo');
        fprintf(fID, '%s\n','Process');
        fclose(fID);

        % Execute the batch file.
        system(['OfflineSorterx64V4.exe /b ' BatchF]);
    end
    
end
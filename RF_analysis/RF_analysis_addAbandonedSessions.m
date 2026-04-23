
clear all
ElectrodeNums = [1:16];
ChannelMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]; % Edge Design Dorsal-->Ventral
% Define distance between channels
Distance = 0:50:50*(length(ChannelMap)-1); % 50 micrometers apart
cell_column = ['MUAStim']; % Will find all cells with stimulus in RF
monkeys = ["Jim"];
areas = ["MT", "FST"];
file_tag = 'mua_sparsenoise.wfexp';
isSave = 1;

%% Get excel sheet with session information
xls_table = 'P:\Jim\NeuroData\RecordingRecord_Stimulation_20240515.xlsx';
path_options = {'P:\Jim\NeuroData\'};
exclusion_criteria = ['Depth'];
inclusion_criteria = [];

%% Read in the excel file
tb = readtable(xls_table);
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
        exclusion = isnan(tb.(exclusion_criteria));
    end
else
    exclusion = zeros(size(tb,1),size(tb,2));
end
exclusion = any(exclusion,2);
inclusion = all(inclusion,2);
inclusion = logical(inclusion & ~exclusion);
inclusion(1:23, 1) = 0;

%% Extract paths corresponding to each recording date that will be included
excel_table_inds = find(inclusion);
% Find the folders with the appropriate date
sorted_folders = dir(path_options{1});
if length(path_options) > 1
    alt_sorts = dir(path_options{2});
    sorted_folders = [sorted_folders; alt_sorts]; % Concatanate so that it checks local drive first, server second
end
[un, ia] = unique(datenum({sorted_folders.name},'yyyymmdd')); % finds first instance -- therefore, if on local drive, will use that file first
sorted_folders = sorted_folders(ia); % We have now thinned our folders to include only the fist instance of each possible recording date, checking the paths sequentially.
inclusion_folder_indices = datefind(tb.Date(excel_table_inds), datenum({sorted_folders.name},'yyyymmdd')); % Now only select folders based on your inclusion/exclusion criteria

if length(inclusion_folder_indices) ~= length(excel_table_inds)
    error('number of files does not match the number of indices selected');
end

%% Step through each recording date and obtain the file names of interest
for recording_num = 1:length(inclusion_folder_indices)
    % Build structure of file paths and relevant waveform files
    recording_dir = dir(fullfile([sorted_folders(inclusion_folder_indices(recording_num)).folder, '/' sorted_folders(inclusion_folder_indices(recording_num)).name],'*.wfexp.mat'));
    expression = {file_tag};
    waveform_filename = recording_dir(~cellfun(@isempty, regexp({recording_dir.name}, strjoin(expression,'.*')))).name;
    RawRipple_folder_idx = 0;
    recording_dir_nev = dir(fullfile([sorted_folders(inclusion_folder_indices(recording_num)).folder, '/' sorted_folders(inclusion_folder_indices(recording_num)).name], '*SparseNoise0001.nev'));
    if size(recording_dir_nev, 1) == 0
        RawRipple_folder_idx = 1;
        recording_dir_nev = dir(fullfile([sorted_folders(inclusion_folder_indices(recording_num)).folder, '/' sorted_folders(inclusion_folder_indices(recording_num)).name],'/Raw Ripple', '*.nev'));
    end
    expression_nev = {'SparseNoise'};
    nev_filename = recording_dir_nev(~cellfun(@isempty, regexp({recording_dir_nev.name}, strjoin(expression_nev,'.*')))).name;

    temp_table = table();
    temp_table.Date = tb.Date(excel_table_inds(recording_num));
    temp_table.ROI = tb.ROI(excel_table_inds(recording_num));
    temp_table.Hole = str2num(char(tb.Hole(excel_table_inds(recording_num))));
    temp_table.Depth = tb.Depth(excel_table_inds(recording_num));
    temp_table.Offset = str2num(char(tb.Offset(excel_table_inds(recording_num))));
    temp_table.Guide = tb.GuideTube(excel_table_inds(recording_num));
    temp_table.StimLoc = str2num(char(tb.StimulusLocation(excel_table_inds(recording_num))));
    temp_table.Paths = {fullfile(recording_dir(1).folder,'\')};
    temp_table.Names = {waveform_filename};
    temp_table.NevNames = {nev_filename};
    temp_table.Folder_Index = recording_num;
    temp_table.NChannels = tb.Channels(excel_table_inds(recording_num));
    temp_table.StimElec = tb.StimElec(excel_table_inds(recording_num));
    temp_table.RawRippleIdx = RawRipple_folder_idx;

    unit_table = [unit_table; temp_table];

end
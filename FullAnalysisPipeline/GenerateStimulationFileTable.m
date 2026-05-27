function [unit_table] = GenerateUnitFileTable(xls_table, path_options, cell_column, inclusion_criteria, exclusion_criteria, file_tag)
% Specifically for stimulation files where all channels are in a single
% file and the units effectively do not matter
%% Input Variables
% xls_table: path and file name of the excel table you'll use to compile
% the table

% path_options: a cell array of possible paths to look for appropriate
% sorted files from trial viewer. If there are multiple possible paths,
% list them in order from which to search first. NOTE: ONLY 2 PATHS
% SUPPORTED

% cell_column: the column name that has the cell/unit numbers to include, which is later filtered by your inclusion and exclusion criteria
% If left empty, will use all the units in the desired file (except
% unsorted).

% inclusion_criteria: a list of dictionary like inputs of column names and
% corresponding element contents that will indicate whether a unit should
% be included in the table.
% E.g.:
%   {'Location', 'V1'}
%   {'Analysis', 'Y'}
%   [{'Location', 'V1'}; {'Analysis', 'Y'}] -- must contain both
%   {'Cells', []}
% For cases like the last listed above, where the second element is empty
% '[]', we assume that the column referenced will include the indices of
% cells for which you would like to include.

% [OPTIONAL] exclusion_criteria: a list of dictionary like inputs of column names and
% corresponding element contents that will indicate whether a unit should
% be excluded from the table. If your inclusion criteria is sufficient then
% you can ignore this input variable.
% E.g.:
%   {'Location', 'Unknown'}
%   {'Analysis', 'N'}

% file_tage: this is the string "tag" that identifies the type of TInfo and
% SInfo files you are trying to identify. It should be unique or you may
% accidentally select more than 2 files. You may choose an alternate file
% type that is not a tinfo file by specifying a tag that includes the
% extension: e.g., 'SparseNoise_Raw.mat'

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
    exclusion(:,e) = strcmp(tb.(exclusion_criteria{e,1}), exclusion_criteria{e,2}); %Miral: I just fixed a spelling mistake; exclusiocn_criteria to exclusion_criteria
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
    disp(recording_num)
    % Build structure of file paths and relevant Tinfo files
    % What are you possibilities?
    % Tetrode, non-tetrode
    % final sort or max sort
    expression = {};
    recording_dir = dir(fullfile([sorted_folders(inclusion_folder_indices(recording_num)).folder, '/' sorted_folders(inclusion_folder_indices(recording_num)).name],'*.mat'));
%     recording_dir.name
%     disp(recording_dir)
    expression{end+1} = 'MUA';
    expression{end+1} = file_tag;
    
    clear tinfo_file sinfo_file
    if ~contains(file_tag,'.') % Check if you specified a special file name and extension, otherwise look for files with the expression and a tinfo and sinfo
        expression{end+1} = 'TInfo';
        tinfo_idx = ~cellfun(@isempty, regexp({recording_dir.name}, strjoin(expression,'.*')));
        expression{end} = 'SelIndex';
        sinfo_idx = ~cellfun(@isempty, regexp({recording_dir.name}, strjoin(expression,'.*')));

        if sum(tinfo_idx)<1 || sum(sinfo_idx)<1
            % try different order of expressions
            expression{end} = 'TInfo';
            expression = [{expression{2}}, {expression{1}}, {expression{3}}];
%             disp(expression)
%             disp(recording_num)
            tinfo_file = recording_dir(~cellfun(@isempty, regexp({recording_dir.name}, strjoin(expression,'.*')))).name;
            expression{end} = 'SelIndex';
            sinfo_file = recording_dir(~cellfun(@isempty, regexp({recording_dir.name}, strjoin(expression,'.*')))).name;
        else
            tinfo_file = recording_dir(tinfo_idx).name;
            sinfo_file = recording_dir(sinfo_idx).name;
        end
        if isempty(tinfo_file) || isempty(sinfo_file)
            error(['No file found for Recording number: ', num2str(recording_num), ' Folder Index: ', num2str(inclusion_folder_indices(recording_num))]);
        end
    else
       tinfo_file = recording_dir(~cellfun(@isempty, regexp({recording_dir.name}, strjoin(expression,'.*')))).name; % This code seems to only give the SelIndex file (John 06/2023)
       sinfo_file = [];
    end
        
    
    %% Now create a table
    
    temp_table = table();
    temp_table.Date = tb.Date(excel_table_inds(recording_num));
    temp_table.ROI = tb.ROI(excel_table_inds(recording_num));
    temp_table.Hole = str2num(char(tb.Hole(excel_table_inds(recording_num))));
    temp_table.Depth = tb.Depth(excel_table_inds(recording_num));
    temp_table.Offset = str2num(char(tb.Offset(excel_table_inds(recording_num))));
    temp_table.Guide = tb.GuideTube(excel_table_inds(recording_num));
    temp_table.StimLoc = str2num(char(tb.StimulusLocation(excel_table_inds(recording_num))));
    temp_table.Paths = {fullfile(recording_dir(1).folder,'\')};
    temp_table.Names = {tinfo_file, sinfo_file};
    temp_table.Folder_Index = recording_num;
    temp_table.NChannels = tb.Channels(excel_table_inds(recording_num));
    temp_table.StimElec = tb.StimElec(excel_table_inds(recording_num));
    
    unit_table = [unit_table; temp_table]; 
    
end
end

function [unit_table, file_table] = GenerateUnitFileTable(xls_table, path_options, cell_column, inclusion_criteria, exclusion_criteria, file_tag)

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
tb = load_recording_table(xls_table);

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
if length(path_options) > 1
    alt_sorts = dir(path_options{2});
    sorted_folders = [sorted_folders; alt_sorts]; % Concatanate so that it checks local drive first, server second
end

folder_names = {sorted_folders.name};
is_dir = [sorted_folders.isdir];
is_dot = ismember(folder_names, {'.','..'});
is_date_folder = ~cellfun(@isempty, regexp(folder_names, '^\d{8}$', 'once'));
sorted_folders = sorted_folders(is_dir & ~is_dot & is_date_folder);

[un, ia] = unique(datenum({sorted_folders.name},'yyyymmdd')); % finds first instance -- therefore, if on local drive, will use that file first
sorted_folders = sorted_folders(ia); % We have now thinned our folders to include only the fist instance of each possible recording date, checking the paths sequentially.

folder_dates = datetime({sorted_folders.name}, 'InputFormat', 'yyyyMMdd');
excel_dates = datetime(tb.Date(excel_table_inds));
[tf, inclusion_folder_indices] = ismember(excel_dates, folder_dates); % Now only select folders based on your inclusion/exclusion criteria

if length(inclusion_folder_indices) ~= length(excel_table_inds) || any(~tf)
    error('number of files does not match the number of indices selected');
end

%% Step through each recording date and obtain the file names of interest
unit_table = table();
file_table = table();
for recording_num = 1:length(inclusion_folder_indices)
    % Build structure of file paths and relevant Tinfo files
    % What are you possibilities?
    % Tetrode, non-tetrode
    % final sort or max sort
    expression = {};
    recording_dir = dir(fullfile([sorted_folders(inclusion_folder_indices(recording_num)).folder, '/' sorted_folders(inclusion_folder_indices(recording_num)).name],'*.mat'));
    if ~isnan(tb.Tetrode(excel_table_inds(recording_num)))
        expression{1} = ['TT',num2str(tb.Tetrode(excel_table_inds(recording_num)))];
    end
    if any(contains({recording_dir.name},'Final'))
        expression{end+1} = 'Final';
    else
        if ~isempty(expression) % contains TT number
            recording_dir = recording_dir(contains({recording_dir.name},expression{1}));
%             expression{end+1} = ['Sorted-0',num2str(max(str2double(string([expression{1},extractBefore(extractAfter({recording_dir.name},'Sorted-'),'_')]))))];
        end
        if isnan(max(str2double(string(extractBefore(extractAfter({recording_dir.name},'Sorted-'),'_')))))
            expression{end+1} = ['Sorted_0',num2str(max(str2double(string(extractBefore(extractAfter({recording_dir.name},'Sorted_'),'_')))))];
        else
            expression{end+1} = ['Sorted-0',num2str(max(str2double(string(extractBefore(extractAfter({recording_dir.name},'Sorted-'),'_')))))];
        end
%         end
    end
    
    expression{end+1} = file_tag;
    if ~contains(file_tag,'.') % Check if you specified a special file name and extension, otherwise look for files with the expression and a tinfo and sinfo
        expression{end+1} = 'TInfo';
        tinfo_file = recording_dir(~cellfun(@isempty, regexp({recording_dir.name}, strjoin(expression,'.*')))).name;
        expression{end} = 'SelIndex';
        sinfo_file = recording_dir(~cellfun(@isempty, regexp({recording_dir.name}, strjoin(expression,'.*')))).name;
        
        if isempty(tinfo_file) || isempty(sinfo_file)
            error(['No file found for Recording number: ', num2str(recording_num), ' Folder Index: ', num2str(inclusion_folder_indices(recording_num))]);
        end
    else
       tinfo_file = recording_dir(~cellfun(@isempty, regexp({recording_dir.name}, strjoin(expression,'.*')))).name;
       sinfo_file = [];
    end
        
    
    %% Now create a table, repeating information for each unit.
    if ~isempty(cell_column)
        n_units = length(str2num(char(tb.(cell_column)((excel_table_inds(recording_num))))));
    else
        a = regexp(tinfo_file, '_');
        [~,wfcount] = plx_info([recording_dir(1).folder, '\', tinfo_file(1:a(end)-1),'.plx'],0);
        n_units = sum(wfcount(:,2) ~= 0) - 1;
    end
    
    temp_table = table();
    temp_file_table = table();
    temp_table.Date = tb.Date(excel_table_inds(recording_num));
    temp_table.ROI = tb.ROI(excel_table_inds(recording_num));
    temp_table.Hole = str2num(char(tb.Hole(excel_table_inds(recording_num))));
    temp_table.Depth = tb.Depth(excel_table_inds(recording_num));
    temp_table.Offset = str2num(char(tb.Offset(excel_table_inds(recording_num))));
    temp_table.Guide = tb.GuideTube(excel_table_inds(recording_num));
    temp_table.StimLoc = str2num(char(tb.StimulusLocation(excel_table_inds(recording_num))));
    temp_table.Paths = {fullfile(recording_dir(1).folder,'\')};
    temp_table.Names = {tinfo_file, sinfo_file};
    temp_table.Tetrode = tb.Tetrode(excel_table_inds(recording_num));
    temp_table.Folder_Index = recording_num;
    
    temp_file_table = temp_table;
    if ~isempty(cell_column)
        temp_file_table.Units = {str2num(char(tb.(cell_column)((excel_table_inds(recording_num)))))};
    else
        temp_file_table.Units = {2:n_units+1};
    end
    
    temp_table = repmat(temp_table,n_units,1);
    if ~isempty(cell_column)
        temp_table.Unit = str2num(char(tb.(cell_column)((excel_table_inds(recording_num)))))';
        temp_table.RF = zeros(size(temp_table,1),1);
        temp_table.InRF = zeros(size(temp_table,1),1);
        temp_table.RF(ismember(temp_table.Unit, str2num(char(tb.RF((excel_table_inds(recording_num))))))) = 1;
        temp_table.InRF(ismember(temp_table.Unit, str2num(char(tb.InRF((excel_table_inds(recording_num))))))) = 1;
    else
        temp_table.Unit = [2:n_units+1]';
    end
    
    unit_table = [unit_table; temp_table]; 
    file_table = [file_table; temp_file_table];
    
end
end

function tb = load_recording_table(xls_table)
try
    opts = detectImportOptions(xls_table, "Sheet", "Sheet1");
catch
    opts = detectImportOptions(xls_table);
end

opts.VariableNamesRange = "A1";
opts.DataRange = "A2";
tb = readtable(xls_table, opts);

% Some sheets occasionally still come in as Var1, Var2, ... despite having
% a valid header row. In that case, promote the first row of the sheet to
% variable names manually.
if ~ismember("ROI", string(tb.Properties.VariableNames))
    raw = readcell(xls_table);
    header = raw(1, :);
    header = matlab.lang.makeValidName(string(header));
    if any(header == "ROI")
        data = raw(2:end, :);
        tb = cell2table(data, 'VariableNames', cellstr(header));
    end
end
end




%     
%     
%     files(i).paths = fullfile(sorted_folders(inclusion_folder_indices(i)).folder,sorted_folders(ind(i)).name,'\');
%     temp = struct2table(dir(files(i).paths));
%     if ~isnan(tb.Tetrode(excel_table_inds(i))) % Tetrode filenames contain TTN in the title
%         f = contains(temp.name(:),'Final') & contains(temp.name(:), ['TT', num2str(tb.Tetrode(excel_table_inds(i)))]) & contains(temp.name(:),'_3D');
%         if ~any(f)
%             f = contains(temp.name(:),'Sorted-') & contains(temp.name(:),'_3D') & contains(temp.name(:), ['TT', num2str(tb.Tetrode(excel_table_inds(i)))]);
%             % May have multiple renditions
%             latest_sorts = temp.name(f);
%             max_sort = max(str2double(string(extractBetween(latest_sorts,'Sorted-','_3D'))));
%             f = contains(temp.name(:),['Sorted-0' num2str(max_sort)]) & contains(temp.name(:),'_3D') & contains(temp.name(:), ['TT', num2str(tb.Tetrode(excel_table_inds(i)))]);
%             
%         end
%         if ~any(f)
%             error('No Sorted files identified')
%         end
%     else
%         f = contains(temp.name(:),'Final');
%         if ~any(f)
%             f = contains(temp.name(:),'Sorted-') & contains(temp.name(:),'_3D');
%             % May have multiple renditions
%             latest_sorts = temp.name(f);
%             max_sort = max(str2double(string(extractBetween(latest_sorts,'Sorted-','_3D'))));
%             f = contains(temp.name(:),['Sorted-0' num2str(max_sort)]) & contains(temp.name(:),'_3D');
%             
%         end
%         if ~any(f)
%             error('No Sorted files identified')
%         end
%     end
%     
%     latest_sorts = temp.name(f);
%     files(i).names(1) = string(latest_sorts(contains(latest_sorts, 'TInfo') & contains(latest_sorts, '3D')));
%     files(i).names(2) =  string(latest_sorts(contains(latest_sorts, 'SelIndex') & contains(latest_sorts, '3D')));
%     
%     Units{i} = tb.UnitIndex(excel_table_inds(i));
%     Units{i} = str2num(Units{i}{1}); % YOUR UNIT INDEX MUST HAVE A COMMA AND SPACE IF THERE ARE MULTIPLE GOOD UNITS FOR THIS RECORDING FILE
%     
%     temp_table = table();
%     temp_table.Date = repmat(tb.Date(excel_table_inds(i)),length(Units{i}),1);
%     temp_table.Tetrode = repmat(tb.Tetrode(excel_table_inds(i)),length(Units{i}),1);
%     temp_table.Hole = repmat(str2num(string(tb.Hole(excel_table_inds(i)))),length(Units{i}),1);
%     temp_table.Depth = repmat(tb.GuideTube(excel_table_inds(i)) + tb.Depth(excel_table_inds(i)),length(Units{i}),1);
%     temp_table.Units = Units{i}';
%     loc = tb.StimulusLocation(excel_table_inds(i));
%     temp_table.StimLoc = repmat(str2num(loc{1}),length(Units{i}),1);
%     temp_table.Folder_Index = repmat(i,length(Units{i}),1);
%     if i == 1
%         MIDTable = temp_table;
%     else
%         MIDTable = [MIDTable; temp_table];
%     end
% end
% 
% MIDTable.Tetrode(isnan(MIDTable.Tetrode)) = 0;


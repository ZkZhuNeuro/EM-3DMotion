clear all
ElectrodeNums = [1:16];
ChannelMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]; % Edge Design Dorsal-->Ventral
% Define distance between channels
Distance = 0:50:50*(length(ChannelMap)-1); % 50 micrometers apart
monkeys = ["Jim"];
areas = ["FST"];
file_tag = {'wfexp'};

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
tt_table = table();

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
    recording_dir = dir(fullfile([sorted_folders(inclusion_folder_indices(recording_num)).folder, '/' sorted_folders(inclusion_folder_indices(recording_num)).name],'*.mat'));
    expression = file_tag;

    names = {recording_dir.name};
    isMatch = ~cellfun(@isempty, regexp(names, expression, 'once'));

    matches = recording_dir(isMatch);

    wfexp_file = reshape({matches.name}, [], 1);

    files = wfexp_file;
    n = numel(files);

    tt      = cell(n,1);
    sorted  = cell(n,1);
    noiseNum = zeros(n,1);

    pat = 'tt(\d+)_mrg_(?:clust_)?sorted-(\d+)_sparsenoise(?:-(\d+))?';

    for i = 1:n
        tok = regexp(files{i}, pat, 'tokens', 'once');
        if isempty(tok)
            error('Filename did not match expected pattern: %s', files{i});
        end

        tt{i}     = tok{1};
        sorted{i} = tok{2};

        if numel(tok) >= 3 && ~isempty(tok{3})
            noiseNum(i) = str2double(tok{3});
        else
            noiseNum(i) = 0;
        end
    end

    groupID = strcat(tt, '_', sorted);

    [~,~,gidx] = unique(groupID, 'stable');
    keepIdx = accumarray(gidx, (1:n)', [], @(idx) idx(find(noiseNum(idx)==max(noiseNum(idx)), 1, 'last')));

    filteredFiles = files(keepIdx);

    % waveform_filename = recording_dir(~cellfun(@isempty, regexp({recording_dir.name}, strjoin(expression,'.*')))).name;
    RawRipple_folder_idx = 0;
    recording_dir_nev = dir(fullfile( ...
        [sorted_folders(inclusion_folder_indices(recording_num)).folder, '/' ...
        sorted_folders(inclusion_folder_indices(recording_num)).name], ...
        '*SparseNoise000*.nev'));
    % Extract run numbers
    nums = nan(numel(recording_dir_nev),1);

    for i = 1:numel(recording_dir_nev)
        tok = regexp(recording_dir_nev(i).name,'SparseNoise000(\d+)\.nev','tokens');
        nums(i) = str2double(tok{1}{1});
    end

    % Find highest index
    [~, idx] = max(nums);

    % Final file
    recording_dir_nev = recording_dir_nev(idx);

    if size(recording_dir_nev, 1) == 0
        RawRipple_folder_idx = 1;
        basePath = fullfile(sorted_folders(inclusion_folder_indices(recording_num)).folder, ...
            sorted_folders(inclusion_folder_indices(recording_num)).name);

        recording_dir_nev = [
            dir(fullfile(basePath, 'RawRipple', '*.nev'));
            dir(fullfile(basePath, 'Raw Ripple', '*.nev'))
            ];
        
    end
    expression_nev = {'SparseNoise'};
    match_idx = ~cellfun(@isempty, regexp({recording_dir_nev.name}, strjoin(expression_nev,'.*')));

    nev_matches = recording_dir_nev(match_idx);

    if isempty(nev_matches)
        nev_filename = [];
    elseif numel(nev_matches) == 1
        nev_filename = nev_matches(1).name;
    else
        nev_filename = nev_matches(end).name;   % take last one
    end

    temp_table = table();

    temp_table.Date = tb.Date(excel_table_inds(recording_num));
    temp_table.ROI = tb.ROI(excel_table_inds(recording_num));
    temp_table.Hole = str2num(char(tb.Hole(excel_table_inds(recording_num))));
    temp_table.Depth = tb.Depth(excel_table_inds(recording_num));
    temp_table.Offset = str2num(char(tb.Offset(excel_table_inds(recording_num))));
    temp_table.Guide = tb.GuideTube(excel_table_inds(recording_num));
    temp_table.StimLoc = str2num(char(tb.StimulusLocation(excel_table_inds(recording_num))));
    temp_table.Paths = {fullfile(recording_dir(1).folder,'\')};
    temp_table.Names = {filteredFiles};
    temp_table.NevNames = {nev_filename};
    temp_table.Folder_Index = recording_num;
    temp_table.RawRippleIdx = RawRipple_folder_idx;

    tt_table = [tt_table; temp_table];

end

%%
% for rec = 1
for i_tt = 1:size(tt_table, 1)
    for i_unit = 1:size(tt_table.Names{i_tt}, 1)
        RFMappingFunction_Lo(tt_table, i_tt, i_unit);
    end
end
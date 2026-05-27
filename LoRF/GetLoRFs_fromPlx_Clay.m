clear all
ElectrodeNums = 1:16; %#ok<NASGU>
ChannelMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]; %#ok<NASGU>
Distance = 0:50:50*(length(ChannelMap)-1); %#ok<NASGU>
monkeys = ["Clay"]; %#ok<NASGU>
areas = ["FST"]; %#ok<NASGU>

%% Get excel sheet with session information
xls_table = 'P:\Clay\NeuroData\RecordingRecord.xlsx';
path_options = {'P:\Clay\NeuroData\'};
exclusion_criteria = [{'ROI','MT/FST'}; {'ROI','N/A'}; {'ROI','MT?'}; {'ROI','Border'}; {'WF',''}; {'WF','N'}; {'RF','N'}; {'RF',''}];
inclusion_criteria = [{'ROI','FST'}];

%% Read in the excel file
opts = detectImportOptions(xls_table, "Sheet", "Sheet1");
opts.VariableNamesRange = "A1";
opts.DataRange = "A2";
tb = readtable(xls_table, opts);
unit_table = table();

%% Use inclusion and exclusion criteria
if ~isempty(inclusion_criteria)
    inclusion = false(size(tb, 1), size(inclusion_criteria, 1));
    for i = 1:size(inclusion_criteria, 1)
        inclusion(:, i) = strcmp(tb.(inclusion_criteria{i, 1}), inclusion_criteria{i, 2});
    end
else
    inclusion = true(size(tb, 1), 1);
end

if ~isempty(exclusion_criteria)
    exclusion = false(size(tb, 1), size(exclusion_criteria, 1));
    for e = 1:size(exclusion_criteria, 1)
        exclusion(:, e) = strcmp(tb.(exclusion_criteria{e, 1}), exclusion_criteria{e, 2});
    end
else
    exclusion = false(size(tb, 1), 1);
end

exclusion = any(exclusion, 2);
inclusion = all(inclusion, 2);
inclusion = logical(inclusion & ~exclusion);

%% Extract paths corresponding to each recording date that will be included
excel_table_inds = find(inclusion);
sorted_folders = dir(path_options{1});
if numel(path_options) > 1
    alt_sorts = dir(path_options{2});
    sorted_folders = [sorted_folders; alt_sorts];
end

names = {sorted_folders.name};
isDir = [sorted_folders.isdir];
isDot = ismember(names, {'.', '..'});
isDate8 = ~cellfun(@isempty, regexp(names, '^\d{8}$', 'once'));

keep = isDir & ~isDot & isDate8;
sorted_folders = sorted_folders(keep);
names = names(keep);

dn = datenum(names, 'yyyymmdd');
[~, ia] = unique(dn, 'stable');
sorted_folders = sorted_folders(ia);
names = names(ia);

folder_dt = datetime(names, "InputFormat", "yyyyMMdd");
excel_dt = datetime(tb.Date(excel_table_inds));
[~, inclusion_folder_indices] = ismember(excel_dt, folder_dt);

% Avoid exporting the same date folder multiple times when the recording
% sheet has repeated included rows for the same session date.
[~, unique_recording_rows] = unique(inclusion_folder_indices, 'stable');
inclusion_folder_indices = inclusion_folder_indices(unique_recording_rows);

%% Step through each recording date and obtain the sorted SparseNoise plx files
for recording_num = 1:length(inclusion_folder_indices)
    folderIdx = inclusion_folder_indices(recording_num);
    if folderIdx == 0
        continue
    end

    baseRecordingPath = fullfile(sorted_folders(folderIdx).folder, sorted_folders(folderIdx).name);
    recording_dir = dir(fullfile(baseRecordingPath, '*.plx'));
    fileNames = {recording_dir.name};
    lowerNames = lower(fileNames);

    isSparseNoise = contains(lowerNames, 'sparsenoise');
    isSorted = ~cellfun(@isempty, regexp(lowerNames, 'sorted[-_]', 'once'));
    isMua = contains(lowerNames, 'mua');
    isMatch = isSparseNoise & isSorted & ~isMua;

    matches = recording_dir(isMatch);
    plx_file = reshape({matches.name}, [], 1);

    if isempty(plx_file)
        warning('No sorted SparseNoise .plx files matched in %s', baseRecordingPath);
    end

    temp_table = table();
    temp_table.Paths = {fullfile(baseRecordingPath, '\')};
    temp_table.Names = {plx_file};
    unit_table = [unit_table; temp_table];
end

%% Export waveform files from OfflineSorter (batch mode)
for ifolder = 1:size(unit_table, 1)
    for i_unit = 1:size(unit_table.Names{ifolder}, 1)
        PName = unit_table.Paths{ifolder};
        FName = unit_table.Names{ifolder}{i_unit};

        BatchF = fullfile(PName, 'SparseNoiseWaveform_Clay.ofb');
        if exist(BatchF, 'file') == 2
            delete(BatchF);
        end

        fID = fopen(BatchF, 'w');
        fprintf(fID, '%s\n', ['File ' fullfile(PName, FName)]);
        fprintf(fID, '%s\n', 'ForEachFile ExportWaveformInfo');
        fprintf(fID, '%s\n', 'Process');
        fclose(fID);

        fprintf('Exporting waveform info %d/%d in folder %d/%d: %s\n', ...
            i_unit, size(unit_table.Names{ifolder}, 1), ifolder, size(unit_table, 1), FName);
        system(['OfflineSorterx64V4.exe /b "' BatchF '"']);
    end
end

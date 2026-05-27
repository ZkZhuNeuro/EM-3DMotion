clear all
ElectrodeNums = [1:16];
ChannelMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]; % Edge Design Dorsal-->Ventral
% Define distance between channels
Distance = 0:50:50*(length(ChannelMap)-1); % 50 micrometers apart
monkeys = ["Clay"];
areas = ["FST"];
outputTag = lower(char(monkeys(1)));
finalSaveName = sprintf('LoRF_unit_table_%s', outputTag);
checkpointSavePath = sprintf('C:\\LoData\\RF\\unit_table_temp2_%s.mat', outputTag);
paperTablePath = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\LoRF\LoRFTable.mat';
paperFilter = loadPaperNeuronFilter(paperTablePath, monkeys(1));

%% Get excel sheet with session information
xls_table = 'P:\Clay\NeuroData\RecordingRecord.xlsx';
path_options = {'P:\Clay\NeuroData\'};
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

% Some recording spreadsheets contain multiple included rows for the same
% date. Each date folder contains the same SparseNoise waveform files, so
% processing every repeated spreadsheet row duplicates RFs in unit_table.
[~, unique_recording_rows] = unique(inclusion_folder_indices, 'stable');
inclusion_folder_indices = inclusion_folder_indices(unique_recording_rows);
excel_table_inds = excel_table_inds(unique_recording_rows);

%% Step through each recording date and obtain the file names of interest
for recording_num = 1:length(inclusion_folder_indices)
    % for recording_num = 73
    % Build structure of file paths and relevant waveform files
    baseRecordingPath = fullfile( ...
        sorted_folders(inclusion_folder_indices(recording_num)).folder, ...
        sorted_folders(inclusion_folder_indices(recording_num)).name);
    recording_dir = dir(fullfile(baseRecordingPath, '*.wfexp.mat'));

    names = {recording_dir.name};
    lowerNames = lower(names);
    isMatch = contains(lowerNames, 'sparsenoise') & ...
        ~cellfun(@isempty, regexp(lowerNames, 'sorted[-_]', 'once')) & ...
        ~contains(lowerNames, 'mua');

    matches = recording_dir(isMatch);

    wfexp_file = reshape({matches.name}, [], 1);
    if isempty(wfexp_file)
        warning(['No sparse-noise sorted waveform export (*.wfexp.mat) files ', ...
            'matched in %s'], baseRecordingPath);
    end

    files = wfexp_file;
    if isempty(files)
        filteredFiles = files;
    else
        n = numel(files);
        tt      = cell(n,1);
        sorted  = cell(n,1);
        fileTime = nan(n,1);

        pat = '(?i)tt(\d+).*sorted[-_](\d+).*sparsenoise(?:[-_](\d+))?';

        for i = 1:n
            tok = regexp(files{i}, pat, 'tokens', 'once');
            if isempty(tok)
                error('Filename did not match expected pattern: %s', files{i});
            end

            tt{i}     = tok{1};
            sorted{i} = tok{2};
            fileTime(i) = matches(i).datenum;
        end

        groupID = strcat(tt, '_', sorted);

        [~,~,gidx] = unique(groupID, 'stable');
        keepIdx = accumarray(gidx, (1:n)', [], @(idx) idx(find(fileTime(idx) == max(fileTime(idx)), 1, 'last')));

        filteredFiles = files(keepIdx);
    end

    % waveform_filename = recording_dir(~cellfun(@isempty, regexp({recording_dir.name}, strjoin(expression,'.*')))).name;
    [nev_filename, RawRipple_folder_idx] = findSparseNoiseNev(baseRecordingPath);

    if isempty(filteredFiles)
        fprintf('Skipping session with no waveform exports: %s\n', baseRecordingPath);
        continue
    end

    temp_table = table();

    temp_table.Date = tb.Date(excel_table_inds(recording_num));
    temp_table.ROI = tb.ROI(excel_table_inds(recording_num));
    temp_table.Hole = str2num(char(tb.Hole(excel_table_inds(recording_num))));
    temp_table.Depth = tb.Depth(excel_table_inds(recording_num));
    temp_table.Offset = str2num(char(tb.Offset(excel_table_inds(recording_num))));
    temp_table.Guide = tb.GuideTube(excel_table_inds(recording_num));
    temp_table.StimLoc = str2num(char(tb.StimulusLocation(excel_table_inds(recording_num))));
    temp_table.Paths = {fullfile(baseRecordingPath,'\')};
    temp_table.Names = {filteredFiles};
    temp_table.NevNames = {nev_filename};
    temp_table.Folder_Index = recording_num;
    temp_table.RawRippleIdx = RawRipple_folder_idx;

    tt_table = [tt_table; temp_table];

end

%% Analyze each sorted unit and keep trial-by-trial RF responses.
unit_table = table();
for i_tt = 1:size(tt_table, 1)
    nFilesThisTT = size(tt_table.Names{i_tt}, 1);
    fprintf('Processing TT/session row %d/%d: %d waveform file(s)\n', ...
        i_tt, size(tt_table, 1), nFilesThisTT);

    for i_file = 1:nFilesThisTT
        fileName = tt_table.Names{i_tt}{i_file};
        unitIDsThisFile = getWaveformUnitIDs(tt_table.Paths{i_tt}, fileName);
        [ttNumForProgress, sortedNumForProgress] = ...
            parseSparseNoiseUnitName(fileName);

        fprintf('  TT%d sort-file-%02d: %d unit(s)\n', ...
            ttNumForProgress, sortedNumForProgress, numel(unitIDsThisFile));

        for i_unit = 1:numel(unitIDsThisFile)
            targetUnitID = unitIDsThisFile(i_unit);
            if ~shouldKeepPaperNeuron(paperFilter, tt_table.Date(i_tt), fileName, targetUnitID)
                fprintf('Skipping non-paper neuron: %s | internal-unit-%d\n', fileName, targetUnitID);
                continue
            end
            unitProgressText = sprintf( ...
                'TT/session row %d/%d, waveform file %d/%d, unit %d/%d, TT%d sort-file-%02d internal-unit-%d', ...
                i_tt, size(tt_table, 1), i_file, nFilesThisTT, ...
                i_unit, numel(unitIDsThisFile), ttNumForProgress, ...
                sortedNumForProgress, targetUnitID);
            fprintf('%s\n', unitProgressText);

            [rawRFmap, uniXPos, uniYPos, meanXYpos, RFmapTable_allSti, SpikeRate_Baseline] = ...
                RFMappingFunction_Lo_Clay(tt_table, i_tt, i_file, unitProgressText, targetUnitID);

            temp_table = tt_table(i_tt, :);
            temp_table.Names = tt_table.Names{i_tt}(i_file);
            temp_table.SessionIndex = i_tt;
            temp_table.FileIndex = i_file;
            temp_table.UnitIndex = i_unit;
            temp_table.InternalUnitID = targetUnitID;

            [ttNum, sortedNum] = parseSparseNoiseUnitName(temp_table.Names{1});
            temp_table.TTNum = ttNum;
            temp_table.SortedNum = sortedNum;

            temp_table.rawRFmap = {rawRFmap};
            temp_table.uniXPos = {uniXPos};
            temp_table.uniYPos = {uniYPos};
            temp_table.meanXYpos = {meanXYpos};
            temp_table.FRbyTrial = {RFmapTable_allSti};
            temp_table.Baseline = {SpikeRate_Baseline};

            unit_table = [unit_table; temp_table];
            RF_table = unit_table; %#ok<NASGU>
            save(checkpointSavePath, 'unit_table', 'RF_table', 'tt_table', '-v7.3');
        end
    end
end

%% Transform RF position coordinates from pixels into mm and deg.
windowWidth = 1920; %(pixels)
windowHeight = 1080; %(pixels)
viewingDistance = 570; %(mm)
ScreenWidth = 635; %(mm)
ScreenHeight = 358; %(mm)
mm2deg = @(x) atand(x./viewingDistance);
pix2mm = @(x) x.*ScreenWidth./windowWidth;
pix2deg = @(x) mm2deg(pix2mm(x));

for i_unit = 1:size(unit_table, 1)
    XPos_pix = unit_table.uniXPos{i_unit};
    YPos_pix = unit_table.uniYPos{i_unit};
    meanXYpos_pix = unit_table.meanXYpos{i_unit};

    unit_table.XPos_mm{i_unit} = pix2mm(XPos_pix);
    unit_table.YPos_mm{i_unit} = pix2mm(YPos_pix);
    unit_table.meanXYpos_mm{i_unit} = pix2mm(meanXYpos_pix);

    unit_table.XPos_deg{i_unit} = pix2deg(XPos_pix - windowWidth/2);
    unit_table.YPos_deg{i_unit} = pix2deg(-YPos_pix + windowHeight/2);
    unit_table.meanXYpos_deg{i_unit} = pix2deg([ ...
        meanXYpos_pix(:, 1) - windowWidth/2, ...
        -meanXYpos_pix(:, 2) + windowHeight/2]);
end

RF_table = unit_table;
save(finalSaveName, 'unit_table', 'RF_table', 'tt_table');
save(checkpointSavePath, 'unit_table', 'RF_table', 'tt_table', '-v7.3');

function [ttNum, sortedNum] = parseSparseNoiseUnitName(fileName)
tok = regexp(fileName, '(?i)tt(\d+).*sorted[-_](\d+)', 'tokens', 'once');
if isempty(tok)
    ttNum = NaN;
    sortedNum = NaN;
else
    ttNum = str2double(tok{1});
    sortedNum = str2double(tok{2});
end
end

function unitIDs = getWaveformUnitIDs(pathName, fileName)
S = load(string(fullfile(pathName, fileName)));
RawSpikes = extractWaveformSpikeMatrix(S, fileName);
unitIDs = unique(RawSpikes(:, 2));
unitIDs(unitIDs == 0) = [];
unitIDs = unitIDs(:)';
end

function RawSpikes = extractWaveformSpikeMatrix(S, fileName)
if isfield(S, 'Raw1') && isnumeric(S.Raw1) && ismatrix(S.Raw1) && size(S.Raw1, 2) >= 3
    RawSpikes = S.Raw1;
    return
end

candidates = {};
fieldNames = fieldnames(S);
for iField = 1:numel(fieldNames)
    candidates = [candidates, collectWaveformCandidates(S.(fieldNames{iField}))]; %#ok<AGROW>
end

if isempty(candidates)
    error('No numeric waveform matrix was found in %s. Top-level fields: %s', ...
        fileName, strjoin(fieldNames, ', '));
end

scores = cellfun(@scoreWaveformCandidate, candidates);
[~, bestIdx] = max(scores);
RawSpikes = candidates{bestIdx};
end

function candidates = collectWaveformCandidates(value)
candidates = {};

if isnumeric(value) && ismatrix(value) && size(value, 2) >= 3
    candidates = {value};
    return
end

if ~isstruct(value)
    return
end

subFields = fieldnames(value);
for iSub = 1:numel(subFields)
    candidates = [candidates, collectWaveformCandidates(value.(subFields{iSub}))]; %#ok<AGROW>
end
end

function score = scoreWaveformCandidate(candidate)
if isempty(candidate) || size(candidate, 2) < 3
    score = -inf;
    return
end

score = min(size(candidate, 1) / 1000, 5);
col2 = candidate(:, 2);
col3 = candidate(:, 3);

if all(isfinite(col2))
    score = score + 3;
    if all(abs(col2 - round(col2)) < 1e-6)
        score = score + 4;
    end
    if all(col2 >= 0)
        score = score + 1;
    end
    nonzeroUnits = unique(col2(col2 ~= 0));
    if numel(nonzeroUnits) <= 32
        score = score + 3;
    end
end

if all(isfinite(col3))
    score = score + 2;
    if nnz(diff(col3) >= 0) >= max(numel(col3) - 1, 0) * 0.95
        score = score + 6;
    end
end
end

function [nev_filename, rawRippleFolderIdx] = findSparseNoiseNev(baseRecordingPath)
nev_filename = [];
rawRippleFolderIdx = 0;

topNev = dir(fullfile(baseRecordingPath, '*.nev'));
rawRippleNev = dir(fullfile(baseRecordingPath, 'RawRipple', '*.nev'));
rawRippleSpacedNev = dir(fullfile(baseRecordingPath, 'Raw Ripple', '*.nev'));
rippleDataNev = dir(fullfile(baseRecordingPath, 'RippleData', '*.nev'));

allNev = [topNev; rawRippleNev; rawRippleSpacedNev; rippleDataNev];
if isempty(allNev)
    allNev = dir(fullfile(baseRecordingPath, '**', '*.nev'));
end
if isempty(allNev)
    return
end

allNames = {allNev.name};
lowerNames = lower(allNames);
isSparseNoise = contains(lowerNames, 'sparsenoise');
nevMatches = allNev(isSparseNoise);

if isempty(nevMatches)
    return
end

matchNames = {nevMatches.name};
runNums = nan(numel(matchNames), 1);
for iName = 1:numel(matchNames)
    tok = regexp(matchNames{iName}, '(?i)sparsenoise0*(\d+)\.nev$', 'tokens', 'once');
    if ~isempty(tok)
        runNums(iName) = str2double(tok{1});
    end
end

if any(isfinite(runNums))
    maxRun = max(runNums(isfinite(runNums)));
    keepIdx = find(runNums == maxRun, 1, 'last');
else
    keepIdx = numel(nevMatches);
end

chosenNev = nevMatches(keepIdx);
nev_filename = chosenNev.name;

chosenFolder = strrep(chosenNev.folder, '/', '\');
if contains(lower(chosenFolder), '\rawripple')
    rawRippleFolderIdx = 1;
elseif contains(lower(chosenFolder), '\raw ripple')
    rawRippleFolderIdx = 1;
elseif contains(lower(chosenFolder), '\rippledata')
    rawRippleFolderIdx = 2;
else
    rawRippleFolderIdx = 3;
end
end

function paperFilter = loadPaperNeuronFilter(matPath, monkeyName)
paperFilter = struct('enabled', false, 'unitKeys', {{}});

if exist(matPath, 'file') ~= 2
    warning('Paper filter table was not found: %s', matPath);
    return
end

S = load(matPath);
if ~isfield(S, 'AllRFTable')
    warning('AllRFTable was not found in %s.', matPath);
    return
end
T = S.AllRFTable;

requiredFields = {'Date', 'ROI', 'Names', 'Tetrode', 'Unit'};
for iField = 1:numel(requiredFields)
    if ~hasNamedField(T, requiredFields{iField})
        warning('AllRFTable is missing field %s.', requiredFields{iField});
        return
    end
end

names = normalizeTextField(getNamedField(T, 'Names'));
roi = normalizeTextField(getNamedField(T, 'ROI'));
paperMonkey = lower(strtrim(monkeyName));
unitKeys = {};

for iRow = 1:numel(names)
    rowName = names(iRow);
    if ~startsWith(lower(strtrim(rowName)), extractBefore(paperMonkey, 2))
        continue
    end
    if ~strcmpi(strtrim(roi(iRow)), 'FST')
        continue
    end

    dateKey = formatDateKey(getIndexedFieldValue(T, 'Date', iRow));
    ttNum = getNumericElement(getNamedField(T, 'Tetrode'), iRow);
    paperUnitNum = getNumericElement(getNamedField(T, 'Unit'), iRow);
    internalUnitID = paperUnitNum - 1;
    if ~isfinite(ttNum) || ~isfinite(paperUnitNum) || ~isfinite(internalUnitID) || internalUnitID < 1
        continue
    end

    unitKeys{end + 1} = canonicalNeuronKey(char(monkeyName), dateKey, ttNum, internalUnitID); %#ok<AGROW>
end

paperFilter.enabled = true;
paperFilter.unitKeys = unique(unitKeys);
end

function keep = shouldKeepPaperNeuron(paperFilter, unitDate, fileName, internalUnitID)
if ~paperFilter.enabled
    keep = true;
    return
end

ttNum = parseTTNumFromFileName(fileName);
if ~isfinite(ttNum) || ~isfinite(internalUnitID)
    keep = false;
    return
end

monkeyName = inferMonkeyFromFileName(fileName);
dateKey = formatDateKey(unitDate);
unitKey = canonicalNeuronKey(monkeyName, dateKey, ttNum, internalUnitID);
keep = ismember(unitKey, paperFilter.unitKeys);
end

function key = canonicalNeuronKey(monkeyName, dateKey, ttNum, unitID)
key = sprintf('%s|%s|tt%02d|unit%02d', lower(strtrim(monkeyName)), dateKey, ttNum, unitID);
end

function tf = hasNamedField(T, fieldName)
if istable(T)
    tf = ismember(fieldName, T.Properties.VariableNames);
else
    tf = isfield(T, fieldName);
end
end

function value = getNamedField(T, fieldName)
value = T.(fieldName);
end

function value = getIndexedFieldValue(T, fieldName, idx)
fieldValue = getNamedField(T, fieldName);
if iscell(fieldValue)
    value = fieldValue{idx};
else
    value = fieldValue(idx, :);
end
end

function values = normalizeTextField(fieldValue)
values = strings(numel(fieldValue), 1);
for i = 1:numel(fieldValue)
    if iscell(fieldValue)
        rawValue = fieldValue{i};
    else
        rawValue = fieldValue(i, :);
    end
    values(i) = string(normalizeTextValue(rawValue));
end
end

function out = normalizeTextValue(v)
if iscell(v)
    if isempty(v)
        out = '';
        return
    end
    if numel(v) == 1
        out = normalizeTextValue(v{1});
        return
    end
    out = '';
    return
end
if isstring(v)
    if isscalar(v)
        out = char(v);
    else
        out = '';
        return
    end
elseif ischar(v)
    out = v;
else
    try
        converted = string(v);
        if isscalar(converted)
            out = char(converted);
        else
            out = '';
            return
        end
    catch
        out = '';
    end
end
out = strtrim(out);
end

function value = getNumericElement(fieldValue, idx)
if iscell(fieldValue)
    rawValue = fieldValue{idx};
else
    rawValue = fieldValue(idx, :);
end
value = scalarNumeric(rawValue);
end

function ttNum = parseTTNumFromFileName(fileName)
tok = regexp(fileName, '(?i)tt(\d+)', 'tokens', 'once');
if isempty(tok)
    ttNum = NaN;
else
    ttNum = str2double(tok{1});
end
end

function monkeyName = inferMonkeyFromFileName(fileName)
tokens = regexp(fileName, '^(Jim|Clay)', 'tokens', 'once', 'ignorecase');
if isempty(tokens)
    monkeyName = 'unknown';
else
    monkeyName = tokens{1};
end
end

function dateKey = formatDateKey(dateValue)
dateKey = '';
try
    if iscell(dateValue)
        dateValue = dateValue{1};
    end
    if isdatetime(dateValue)
        if ~isnat(dateValue)
            dateKey = datestr(dateValue, 'yyyymmdd');
        end
        return
    end
    if isnumeric(dateValue) && isscalar(dateValue) && isfinite(dateValue)
        dateKey = datestr(datetime(dateValue, 'ConvertFrom', 'datenum'), 'yyyymmdd');
        return
    end
    textValue = normalizeTextValue(dateValue);
    if isempty(textValue)
        return
    end
    parsed = NaT;
    try
        parsed = datetime(textValue, 'InputFormat', 'yyyyMMdd');
    catch
    end
    if isnat(parsed)
        try
            parsed = datetime(textValue, 'InputFormat', 'M/d/yyyy');
        catch
        end
    end
    if isnat(parsed)
        try
            parsed = datetime(textValue);
        catch
        end
    end
    if ~isnat(parsed)
        dateKey = datestr(parsed, 'yyyymmdd');
    end
catch
end
end

function value = scalarNumeric(rawValue)
value = NaN;
if isnumeric(rawValue) && isscalar(rawValue) && isfinite(rawValue)
    value = double(rawValue);
elseif islogical(rawValue) && isscalar(rawValue)
    value = double(rawValue);
elseif isstring(rawValue) || ischar(rawValue)
    candidate = str2double(string(rawValue));
    if isfinite(candidate)
        value = candidate;
    end
end
end

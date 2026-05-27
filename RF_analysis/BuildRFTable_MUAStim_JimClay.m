clear

outputRoot = 'C:\EM\RF_data';
outputSaveName = fullfile(outputRoot, 'RF_table_MUAStim_JimClay.mat');
checkpointSavePath = fullfile(outputRoot, 'RF_table_MUAStim_JimClay_checkpoint.mat');
expectedChannelsPerFile = 16;

if ~exist(outputRoot, 'dir')
    mkdir(outputRoot);
end

configs = struct( ...
    'Monkey', {'Jim', 'Clay'}, ...
    'ExcelPath', { ...
        'P:\Jim\NeuroData\RecordingRecord_Stimulation_20240515.xlsx', ...
        'P:\Clay\NeuroData\RecordingRecord_Stimulation.xlsx'}, ...
    'RootPath', { ...
        'P:\Jim\NeuroData\', ...
        'P:\Clay\NeuroData\'});

session_table = table();
for iConfig = 1:numel(configs)
    session_table = [session_table; buildMUAStimSessionTable(configs(iConfig))]; %#ok<AGROW>
end

if isempty(session_table)
    error('No MUA stimulation sessions were found across the Jim and Clay workbooks.');
end

unit_table = table();
for i_session = 1:size(session_table, 1)
    fprintf('Processing session %d/%d: %s %s\n', ...
        i_session, size(session_table, 1), ...
        session_table.Monkey{i_session}, ...
        datestr(session_table.Date(i_session), 'yyyymmdd'));

    sessionProgressText = sprintf('%s %s', ...
        session_table.Monkey{i_session}, ...
        datestr(session_table.Date(i_session), 'yyyymmdd'));
    sessionRF = RFMappingFunction_MUAStim( ...
        session_table, i_session, 1:expectedChannelsPerFile, sessionProgressText);

    temp_table = session_table(i_session, :);
    temp_table.SessionIndex = i_session;
    temp_table.ChannelNums = {sessionRF.ChannelNums};
    temp_table.UnitIndex = {ones(numel(sessionRF.ChannelNums), 1)};
    temp_table.InternalUnitID = {ones(numel(sessionRF.ChannelNums), 1)};
    temp_table.WaveformFields = {sessionRF.WaveformFields};

    temp_table.rawRFmap = {sessionRF.rawRFmap};
    temp_table.uniXPos = {sessionRF.uniXPos};
    temp_table.uniYPos = {sessionRF.uniYPos};
    temp_table.meanXYpos = {sessionRF.meanXYpos};
    temp_table.FRbyTrial = {sessionRF.FRbyTrial};
    temp_table.Baseline = {sessionRF.Baseline};

    unit_table = [unit_table; temp_table]; %#ok<AGROW>
    RF_table = unit_table; %#ok<NASGU>
    save(checkpointSavePath, 'session_table', 'unit_table', 'RF_table', '-v7.3');
end

windowWidth = 1920; %(pixels)
windowHeight = 1080; %(pixels)
viewingDistance = 570; %(mm)
ScreenWidth = 635; %(mm)
mm2deg = @(x) atand(x./viewingDistance);
pix2mm = @(x) x.*ScreenWidth./windowWidth;
pix2deg = @(x) mm2deg(pix2mm(x));

for i_unit = 1:size(unit_table, 1)
    sessionXPos_pix = unit_table.uniXPos{i_unit};
    sessionYPos_pix = unit_table.uniYPos{i_unit};
    sessionMeanXYpos_pix = unit_table.meanXYpos{i_unit};
    nChannelsThisSession = numel(sessionXPos_pix);

    XPos_mm = cell(nChannelsThisSession, 1);
    YPos_mm = cell(nChannelsThisSession, 1);
    meanXYpos_mm = cell(nChannelsThisSession, 1);
    XPos_deg = cell(nChannelsThisSession, 1);
    YPos_deg = cell(nChannelsThisSession, 1);
    meanXYpos_deg = cell(nChannelsThisSession, 1);

    for i_channel = 1:nChannelsThisSession
        XPos_pix = sessionXPos_pix{i_channel};
        YPos_pix = sessionYPos_pix{i_channel};
        meanXYpos_pix = sessionMeanXYpos_pix{i_channel};

        XPos_mm{i_channel} = pix2mm(XPos_pix);
        YPos_mm{i_channel} = pix2mm(YPos_pix);
        meanXYpos_mm{i_channel} = pix2mm(meanXYpos_pix);

        XPos_deg{i_channel} = pix2deg(XPos_pix - windowWidth/2);
        YPos_deg{i_channel} = pix2deg(-YPos_pix + windowHeight/2);
        meanXYpos_deg{i_channel} = pix2deg([ ...
            meanXYpos_pix(:, 1) - windowWidth/2, ...
            -meanXYpos_pix(:, 2) + windowHeight/2]);
    end

    unit_table.XPos_mm{i_unit} = XPos_mm;
    unit_table.YPos_mm{i_unit} = YPos_mm;
    unit_table.meanXYpos_mm{i_unit} = meanXYpos_mm;
    unit_table.XPos_deg{i_unit} = XPos_deg;
    unit_table.YPos_deg{i_unit} = YPos_deg;
    unit_table.meanXYpos_deg{i_unit} = meanXYpos_deg;
end

RF_table = unit_table; %#ok<NASGU>
save(outputSaveName, 'session_table', 'unit_table', 'RF_table', '-v7.3');
save(checkpointSavePath, 'session_table', 'unit_table', 'RF_table', '-v7.3');

function session_table = buildMUAStimSessionTable(config)
tb = readtable(config.ExcelPath);

muaStimColumn = getTableColumn(tb, 'MUAStim');
recordingDates = normalizeDateColumn(getTableColumn(tb, 'Date'));
includedRows = strcmpi(normalizeTextColumn(muaStimColumn), 'Y') & ~isnat(recordingDates);

excel_table_inds = find(includedRows);
excel_dates = recordingDates(excel_table_inds);

[dateFolders, folderDates] = listDateFolders(config.RootPath);
[isMatched, inclusion_folder_indices] = ismember(excel_dates, folderDates);

excel_table_inds = excel_table_inds(isMatched);
inclusion_folder_indices = inclusion_folder_indices(isMatched);

if isempty(excel_table_inds)
    warning('No matching date folders were found for %s.', config.Monkey);
    session_table = table();
    return
end

% Multiple spreadsheet rows can point to the same recording-date folder.
[~, uniqueRecordingRows] = unique(inclusion_folder_indices, 'stable');
excel_table_inds = excel_table_inds(uniqueRecordingRows);
inclusion_folder_indices = inclusion_folder_indices(uniqueRecordingRows);

session_table = table();
for iRow = 1:numel(excel_table_inds)
    folderInfo = dateFolders(inclusion_folder_indices(iRow));
    baseRecordingPath = fullfile(folderInfo.folder, folderInfo.name);
    [waveformFile, waveformFolder] = findMUAStimWaveformExport(baseRecordingPath);
    [nevPath, rawRippleFolderIdx] = findSparseNoiseNevFullPath(baseRecordingPath);

    if isempty(waveformFile)
        warning('No MUA sparse-noise waveform export was found in %s.', baseRecordingPath);
        continue
    end

    if isempty(nevPath)
        warning('No sparse-noise NEV file was found in %s.', baseRecordingPath);
        continue
    end

    spreadsheetRow = excel_table_inds(iRow);
    [~, nevName, nevExt] = fileparts(nevPath);
    temp_table = table();
    temp_table.Monkey = {config.Monkey};
    temp_table.Date = recordingDates(spreadsheetRow);
    temp_table.ROI = {getTextValue(tb, spreadsheetRow, 'ROI')};
    temp_table.Hole = {getNumericValue(tb, spreadsheetRow, 'Hole')};
    temp_table.Depth = getScalarDouble(getNumericValue(tb, spreadsheetRow, 'Depth'));
    temp_table.Offset = {getNumericValue(tb, spreadsheetRow, 'Offset')};
    temp_table.Guide = {getTextValue(tb, spreadsheetRow, 'GuideTube')};
    temp_table.StimLoc = {getNumericValue(tb, spreadsheetRow, 'StimulusLocation')};
    temp_table.StimElec = {getNumericValue(tb, spreadsheetRow, 'StimElec')};
    temp_table.NChannels = getScalarDouble(getNumericValue(tb, spreadsheetRow, 'Channels'));
    temp_table.Paths = {[waveformFolder filesep]};
    temp_table.Names = {waveformFile};
    temp_table.NevPath = {nevPath};
    temp_table.NevNames = {[nevName nevExt]};
    temp_table.RootPath = {config.RootPath};
    temp_table.WorkbookPath = {config.ExcelPath};
    temp_table.WorkbookRow = spreadsheetRow;
    temp_table.Folder_Index = inclusion_folder_indices(iRow);
    temp_table.RawRippleIdx = rawRippleFolderIdx;

    session_table = [session_table; temp_table]; %#ok<AGROW>
end
end

function [dateFolders, folderDates] = listDateFolders(rootPath)
allFolders = dir(rootPath);
names = {allFolders.name};
isDir = [allFolders.isdir];
isDate8 = ~cellfun(@isempty, regexp(names, '^\d{8}$', 'once'));
keep = isDir & isDate8;

dateFolders = allFolders(keep);
folderDates = datetime({dateFolders.name}, 'InputFormat', 'yyyyMMdd')';

[~, uniqueIdx] = unique(datenum(folderDates), 'stable');
dateFolders = dateFolders(uniqueIdx);
folderDates = folderDates(uniqueIdx);
end

function [waveformFile, waveformFolder] = findMUAStimWaveformExport(baseRecordingPath)
waveformFile = [];
waveformFolder = [];

wfexpFiles = dir(fullfile(baseRecordingPath, '*.wfexp.mat'));
if isempty(wfexpFiles)
    wfexpFiles = dir(fullfile(baseRecordingPath, '**', '*.wfexp.mat'));
end
if isempty(wfexpFiles)
    return
end

names = {wfexpFiles.name};
lowerNames = lower(names);
isSparseNoise = contains(lowerNames, 'sparsenoise');

if ~any(isSparseNoise)
    return
end

scores = zeros(numel(wfexpFiles), 1);
scores = scores + 100 .* isSparseNoise(:);
scores = scores + 50 .* contains(lowerNames(:), 'mua');
scores = scores + 10 .* contains(lowerNames(:), 'mrg');

candidateIdx = find(isSparseNoise);
candidateScores = scores(candidateIdx);
candidateTimes = [wfexpFiles(candidateIdx).datenum]';

[~, order] = sortrows([-candidateScores, -candidateTimes]);
bestFile = wfexpFiles(candidateIdx(order(1)));

waveformFile = bestFile.name;
waveformFolder = bestFile.folder;
end

function [nevPath, rawRippleFolderIdx] = findSparseNoiseNevFullPath(baseRecordingPath)
nevPath = [];
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

runNums = nan(numel(nevMatches), 1);
for iName = 1:numel(nevMatches)
    tok = regexp(nevMatches(iName).name, '(?i)sparsenoise0*(\d+)\.nev$', 'tokens', 'once');
    if ~isempty(tok)
        runNums(iName) = str2double(tok{1});
    end
end

if any(isfinite(runNums))
    maxRun = max(runNums(isfinite(runNums)));
    keepIdx = find(runNums == maxRun, 1, 'last');
else
    [~, keepIdx] = max([nevMatches.datenum]);
end

chosenNev = nevMatches(keepIdx);
nevPath = fullfile(chosenNev.folder, chosenNev.name);

chosenFolder = lower(strrep(chosenNev.folder, '/', '\'));
if contains(chosenFolder, '\rawripple') || contains(chosenFolder, '\raw ripple')
    rawRippleFolderIdx = 1;
elseif contains(chosenFolder, '\rippledata')
    rawRippleFolderIdx = 2;
else
    rawRippleFolderIdx = 3;
end
end

function columnData = getTableColumn(tb, requestedName)
variableNames = tb.Properties.VariableNames;
normalizedVariables = normalizeVariableNames(variableNames);
normalizedRequest = normalizeVariableNames({requestedName});
matchIdx = find(strcmp(normalizedVariables, normalizedRequest{1}), 1, 'first');

if isempty(matchIdx)
    error('Column "%s" was not found in the recording table.', requestedName);
end

columnData = tb.(variableNames{matchIdx});
end

function values = normalizeVariableNames(names)
values = cell(size(names));
for iName = 1:numel(names)
    values{iName} = lower(regexprep(char(string(names{iName})), '[^a-zA-Z0-9]', ''));
end
end

function textValues = normalizeTextColumn(columnData)
textValues = strings(numel(columnData), 1);
for iRow = 1:numel(columnData)
    textValues(iRow) = string(normalizeTextValue(getColumnValueAtRow(columnData, iRow)));
end
end

function dateValues = normalizeDateColumn(columnData)
dateValues = NaT(numel(columnData), 1);
for iRow = 1:numel(columnData)
    dateValues(iRow) = parseDateValue(getColumnValueAtRow(columnData, iRow));
end
end

function textValue = getTextValue(tb, rowIdx, requestedName)
columnData = getTableColumn(tb, requestedName);
textValue = normalizeTextValue(getColumnValueAtRow(columnData, rowIdx));
end

function numericValue = getNumericValue(tb, rowIdx, requestedName)
columnData = getTableColumn(tb, requestedName);
numericValue = parseNumericValue(getColumnValueAtRow(columnData, rowIdx));
end

function value = getColumnValueAtRow(columnData, rowIdx)
if iscell(columnData)
    value = columnData{rowIdx};
else
    value = columnData(rowIdx, :);
end
end

function parsed = parseDateValue(rawValue)
parsed = NaT;

if isdatetime(rawValue)
    if isscalar(rawValue) && ~isnat(rawValue)
        parsed = rawValue;
    end
    return
end

if isnumeric(rawValue) && isscalar(rawValue) && isfinite(rawValue)
    try
        parsed = datetime(rawValue, 'ConvertFrom', 'excel');
    catch
        try
            parsed = datetime(rawValue, 'ConvertFrom', 'datenum');
        catch
        end
    end
    return
end

textValue = normalizeTextValue(rawValue);
if isempty(textValue)
    return
end

dateFormats = {'yyyyMMdd', 'M/d/yyyy', 'MM/dd/yyyy', 'M/d/yy', 'MM/dd/yy'};
for iFormat = 1:numel(dateFormats)
    try
        parsed = datetime(textValue, 'InputFormat', dateFormats{iFormat});
        if ~isnat(parsed)
            return
        end
    catch
    end
end

try
    parsed = datetime(textValue);
catch
    parsed = NaT;
end
end

function out = normalizeTextValue(rawValue)
out = '';

if iscell(rawValue)
    if isempty(rawValue)
        return
    end
    out = normalizeTextValue(rawValue{1});
    return
end

if isstring(rawValue)
    if isscalar(rawValue)
        out = char(rawValue);
    end
elseif ischar(rawValue)
    out = rawValue;
elseif isnumeric(rawValue) && isscalar(rawValue) && isfinite(rawValue)
    out = num2str(rawValue);
end

out = strtrim(out);
end

function value = parseNumericValue(rawValue)
if isempty(rawValue)
    value = [];
    return
end

if isnumeric(rawValue)
    value = double(rawValue);
    return
end

if islogical(rawValue)
    value = double(rawValue);
    return
end

textValue = normalizeTextValue(rawValue);
if isempty(textValue)
    value = [];
    return
end

value = str2num(textValue); %#ok<ST2NM>
if isempty(value)
    scalarValue = str2double(textValue);
    if isfinite(scalarValue)
        value = scalarValue;
    else
        value = [];
    end
end
end

function scalarValue = getScalarDouble(value)
if isnumeric(value) && isscalar(value) && ~isempty(value)
    scalarValue = double(value);
else
    scalarValue = NaN;
end
end

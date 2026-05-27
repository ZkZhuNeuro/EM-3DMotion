%% Build MIDTable for Jim and Clay stimulation sessions

if ~exist('sessionLimitPerMonkey', 'var')
    sessionLimitPerMonkey = inf;
end

areas = {'MT', 'FST'};
saveOutput = false;
outputSavePath = 'C:\EM\MIDTable_MUAStim_JimClay.mat';

configs = struct( ...
    'Monkey', {'Jim', 'Clay'}, ...
    'ExcelPath', { ...
        'P:\Jim\NeuroData\RecordingRecord_Stimulation_20250331.xlsx', ...
        'P:\Clay\NeuroData\RecordingRecord_Stimulation.xlsx'}, ...
    'PathOptions', { ...
        {'P:\Jim\NeuroData\', 'C:\Jim\In_Processing\'}, ...
        {'C:\Clay\In_Processing\', 'P:\Clay\NeuroData\'}});

MIDTable = table();
SkippedSessions = table();

for iConfig = 1:numel(configs)
    [tmpMIDTable, tmpSkipped] = buildMonkeyMIDTable(configs(iConfig), areas, sessionLimitPerMonkey);
    MIDTable = [MIDTable; tmpMIDTable]; %#ok<AGROW>
    SkippedSessions = [SkippedSessions; tmpSkipped]; %#ok<AGROW>
end

if isempty(MIDTable)
    warning('No MIDTable rows were built. Check workbook filters, date folders, and file tags.');
else
    safeDisplay(sprintf('Built MIDTable with %d session rows.', size(MIDTable, 1)));
end

if ~isempty(SkippedSessions)
    safeDisplay(sprintf('Skipped %d workbook rows that were missing folders or files.', size(SkippedSessions, 1)));
end

if saveOutput
    save(outputSavePath, 'MIDTable', 'SkippedSessions', 'configs', '-v7.3');
    safeDisplay(sprintf('Saved MIDTable to %s', outputSavePath));
end

function [midTable, skippedTable] = buildMonkeyMIDTable(config, areas, sessionLimitPerMonkey)
tb = readtable(config.ExcelPath, 'VariableNamingRule', 'preserve');

recordingDates = normalizeDateColumn(getTableColumn(tb, 'Date'));
muaStim = normalizeTextColumn(getTableColumn(tb, 'MUAStim'));
roiValues = normalizeTextColumn(getTableColumn(tb, 'ROI'));
validAreaMask = ismember(upper(roiValues), upper(string(areas)));

includeRows = strcmpi(muaStim, 'Y') & validAreaMask & ~isnat(recordingDates);
rowIdx = find(includeRows);
if isfinite(sessionLimitPerMonkey)
    rowIdx = rowIdx(1:min(numel(rowIdx), sessionLimitPerMonkey));
end

midTable = table();
skippedTable = table();

if isempty(rowIdx)
    warning('No rows passed the inclusion filters for %s.', config.Monkey);
    return
end

dateFolderMap = listDateFolders(config.PathOptions);

for iRow = 1:numel(rowIdx)
    spreadsheetRow = rowIdx(iRow);
    recordingDate = recordingDates(spreadsheetRow);
    roiValue = getTextValue(tb, spreadsheetRow, 'ROI');
    stimElecValue = getScalarDouble(getNumericValue(tb, spreadsheetRow, 'StimElec'));
    safeDisplay(sprintf('Processing %s session %d/%d: %s (workbook row %d)', ...
        config.Monkey, iRow, numel(rowIdx), datestr(recordingDate, 'yyyy-mm-dd'), spreadsheetRow));
    [recordingFolder, folderSource] = resolveRecordingFolder(recordingDate, dateFolderMap);

    if isempty(recordingFolder)
        skippedTable = appendSkippedRow(skippedTable, config, recordingDate, spreadsheetRow, ...
            roiValue, stimElecValue, '', 'MIDTableBuild', ...
            'No matching YYYYMMDD recording folder was found.');
        continue
    end

    separate2DValue = getOptionalTextValue(tb, spreadsheetRow, 'Separate2D');
    if parseSpreadsheetFlag(separate2DValue)
        twoDTag = 'LateralMotion';
    else
        twoDTag = '2DMotion';
    end

    [stimPair, quickPair, twoDPair, analysisFolder, reason] = resolveSessionFileSet(recordingFolder, twoDTag);
    if isempty(analysisFolder)
        skippedTable = appendSkippedRow(skippedTable, config, recordingDate, spreadsheetRow, ...
            roiValue, stimElecValue, recordingFolder, 'MIDTableBuild', reason);
        continue
    end

    tempTable = table();
    tempTable.Monkey = {config.Monkey};
    tempTable.Date = recordingDate;
    tempTable.ROI = {getTextValue(tb, spreadsheetRow, 'ROI')};
    tempTable.Hole = normalizeFixedWidthNumericRow(getNumericValue(tb, spreadsheetRow, 'Hole'), 2);
    tempTable.Depth = getScalarDouble(getNumericValue(tb, spreadsheetRow, 'Depth'));
    tempTable.Offset = normalizeFixedWidthNumericRow(getNumericValue(tb, spreadsheetRow, 'Offset'), 3);
    tempTable.Guide = getScalarDouble(getNumericValue(tb, spreadsheetRow, 'GuideTube'));
    tempTable.StimLoc = normalizeFixedWidthNumericRow(getNumericValue(tb, spreadsheetRow, 'StimulusLocation'), 2);
    tempTable.Paths = {appendFilesep(analysisFolder)};
    tempTable.Names = stimPair;
    tempTable.QuickNames = quickPair;
    tempTable.Names_2D = twoDPair;
    tempTable.NChannels = getScalarDouble(getNumericValue(tb, spreadsheetRow, 'Channels'));
    tempTable.StimElec = getScalarDouble(getNumericValue(tb, spreadsheetRow, 'StimElec'));
    tempTable.Analysis2DTag = {twoDTag};
    tempTable.Separate2D = {separate2DValue};
    tempTable.WorkbookPath = {config.ExcelPath};
    tempTable.WorkbookRow = spreadsheetRow;
    tempTable.FolderPath = {recordingFolder};
    tempTable.FolderSource = {folderSource};
    tempTable.Folder_Index = iRow;

    midTable = [midTable; tempTable]; %#ok<AGROW>
end
end

function dateFolderMap = listDateFolders(pathOptions)
dateFolderMap = table();

for iPath = 1:numel(pathOptions)
    rootPath = pathOptions{iPath};
    if ~isfolder(rootPath)
        continue
    end

    folderInfo = dir(rootPath);
    names = {folderInfo.name};
    isDir = [folderInfo.isdir];
    isDateFolder = ~cellfun(@isempty, regexp(names, '^\d{8}$', 'once'));
    keep = isDir & isDateFolder;

    folderInfo = folderInfo(keep);
    if isempty(folderInfo)
        continue
    end

    folderDates = datetime({folderInfo.name}, 'InputFormat', 'yyyyMMdd')';
    tempTable = table();
    tempTable.Date = folderDates;
    tempTable.FolderPath = string(fullfile({folderInfo.folder}', {folderInfo.name}'));
    tempTable.SourceRoot = repmat(string(rootPath), numel(folderDates), 1);
    tempTable.Priority = repmat(iPath, numel(folderDates), 1);

    dateFolderMap = [dateFolderMap; tempTable]; %#ok<AGROW>
end

if isempty(dateFolderMap)
    return
end

[~, order] = sortrows([datenum(dateFolderMap.Date), dateFolderMap.Priority], [1 2]);
dateFolderMap = dateFolderMap(order, :);

[~, uniqueIdx] = unique(datenum(dateFolderMap.Date), 'stable');
dateFolderMap = dateFolderMap(uniqueIdx, :);
end

function [recordingFolder, folderSource] = resolveRecordingFolder(recordingDate, dateFolderMap)
recordingFolder = '';
folderSource = '';

if isempty(dateFolderMap)
    return
end

matchIdx = find(dateFolderMap.Date == recordingDate, 1, 'first');
if isempty(matchIdx)
    return
end

recordingFolder = char(dateFolderMap.FolderPath(matchIdx));
folderSource = char(dateFolderMap.SourceRoot(matchIdx));
end

function [stimPair, quickPair, twoDPair, analysisFolder, reason] = resolveSessionFileSet(recordingFolder, twoDTag)
stimPair = cell(1, 2);
quickPair = cell(1, 2);
twoDPair = cell(1, 2);
analysisFolder = '';
reason = '';

matFiles = collectMatFiles(recordingFolder);
if isempty(matFiles)
    reason = sprintf('No MAT files were found under %s.', recordingFolder);
    return
end

folderNames = unique(string({matFiles.folder}));
bestScore = -Inf;

for iFolder = 1:numel(folderNames)
    thisFolder = char(folderNames(iFolder));
    folderMask = strcmp({matFiles.folder}, thisFolder);
    folderFiles = matFiles(folderMask);

    stimCandidate = selectBestFilePair(folderFiles, '3DMotionStim');
    quickCandidate = selectBestFilePair(folderFiles, '3DMotionQuick');
    twoDCandidate = selectBestFilePair(folderFiles, twoDTag);

    if isempty(stimCandidate) || isempty(quickCandidate) || isempty(twoDCandidate)
        continue
    end

    folderScore = scoreAnalysisFolder(thisFolder, recordingFolder, folderFiles);
    if folderScore > bestScore
        bestScore = folderScore;
        analysisFolder = thisFolder;
        stimPair = stimCandidate;
        quickPair = quickCandidate;
        twoDPair = twoDCandidate;
    end
end

if isempty(analysisFolder)
    reason = sprintf(['Could not find one folder under %s containing ', ...
        '3DMotionStim, 3DMotionQuick, and %s TInfo/SelIndex files.'], ...
        recordingFolder, twoDTag);
end
end

function matFiles = collectMatFiles(recordingFolder)
topLevelFiles = dir(fullfile(recordingFolder, '*.mat'));
recursiveFiles = dir(fullfile(recordingFolder, '**', '*.mat'));
matFiles = [topLevelFiles; recursiveFiles];

if isempty(matFiles)
    return
end

fullPaths = fullfile({matFiles.folder}', {matFiles.name}');
[~, uniqueIdx] = unique(fullPaths, 'stable');
matFiles = matFiles(uniqueIdx);
end

function pair = selectBestFilePair(folderFiles, fileTag)
pair = {};

names = {folderFiles.name};
lowerNames = lower(string(names));
tagMask = contains(lowerNames, lower(fileTag));

tinfoCandidates = folderFiles(tagMask & contains(lowerNames, 'tinfo'));
selIndexCandidates = folderFiles(tagMask & contains(lowerNames, 'selindex'));

if isempty(tinfoCandidates) || isempty(selIndexCandidates)
    return
end

bestTInfo = pickBestFile(tinfoCandidates, fileTag);
bestSelIndex = pickBestFile(selIndexCandidates, fileTag);
pair = {bestTInfo.name, bestSelIndex.name};
end

function bestFile = pickBestFile(fileInfo, fileTag)
scores = zeros(numel(fileInfo), 1);
lowerTag = lower(fileTag);

for iFile = 1:numel(fileInfo)
    lowerName = lower(fileInfo(iFile).name);
    scores(iFile) = scores(iFile) + 100 * contains(lowerName, lowerTag);
    scores(iFile) = scores(iFile) + 25 * contains(lowerName, 'mua');
    scores(iFile) = scores(iFile) + 10 * contains(lowerName, 'final');
    scores(iFile) = scores(iFile) + 5 * contains(lowerName, 'edit');
end

times = [fileInfo.datenum]';
[~, bestIdx] = sortrows([-scores, -times]);
bestFile = fileInfo(bestIdx(1));
end

function folderScore = scoreAnalysisFolder(candidateFolder, recordingFolder, folderFiles)
folderScore = 0;

if strcmpi(candidateFolder, recordingFolder)
    folderScore = folderScore + 1000;
end

relativeDepth = count(string(candidateFolder), filesep) - count(string(recordingFolder), filesep);
folderScore = folderScore - 10 * max(relativeDepth, 0);
folderScore = folderScore + max([folderFiles.datenum]);
end

function skippedTable = appendSkippedRow(skippedTable, config, recordingDate, workbookRow, roiValue, stimElecValue, folderPath, stageName, reason)
tempTable = table();
tempTable.SessionIndex = NaN;
tempTable.IssueType = {'Skipped'};
tempTable.Stage = {stageName};
tempTable.Monkey = {config.Monkey};
tempTable.Date = recordingDate;
tempTable.ROI = {roiValue};
tempTable.StimElec = stimElecValue;
tempTable.WorkbookPath = {config.ExcelPath};
tempTable.WorkbookRow = workbookRow;
tempTable.FolderPath = {folderPath};
tempTable.Reason = {reason};
skippedTable = [skippedTable; tempTable]; %#ok<AGROW>
end

function value = appendFilesep(folderPath)
value = folderPath;
if isempty(value)
    return
end

if value(end) ~= filesep
    value = [value filesep];
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

function textValue = getTextValue(tb, rowIdx, requestedName)
columnData = getTableColumn(tb, requestedName);
textValue = normalizeTextValue(getColumnValueAtRow(columnData, rowIdx));
end

function textValue = getOptionalTextValue(tb, rowIdx, requestedName)
variableNames = tb.Properties.VariableNames;
normalizedVariables = normalizeVariableNames(variableNames);
normalizedRequest = normalizeVariableNames({requestedName});
matchIdx = find(strcmp(normalizedVariables, normalizedRequest{1}), 1, 'first');

if isempty(matchIdx)
    textValue = '';
    return
end

columnData = tb.(variableNames{matchIdx});
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

function rowValue = normalizeFixedWidthNumericRow(value, width)
rowValue = nan(1, width);

if isempty(value)
    return
end

value = double(value(:)');
nCopy = min(numel(value), width);
rowValue(1:nCopy) = value(1:nCopy);
end

function flag = parseSpreadsheetFlag(rawValue)
textValue = upper(strtrim(normalizeTextValue(rawValue)));
flag = ismember(textValue, {'Y', 'YES', 'TRUE', 'T', '1'});
end

function safeDisplay(messageText)
try
    disp(messageText);
catch
end
end

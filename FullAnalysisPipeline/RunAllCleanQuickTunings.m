function [unit_table_3DQuick_cleaned, unit_table_2DQuick_cleaned] = ...
    RunAllCleanQuickTunings(tableFile, options)
%RUNALLCLEANQUICKTUNINGS Clean 3D Quick and 2D Quick tunings for all sessions.
%
% The source table and P: recordings are read only. Results are saved in
% separate 3DQuick and 2DQuick folders. Every successful session also gets a
% compact trial-FR/mask MAT and side-by-side original-versus-cleaned figures.

arguments
    tableFile (1, 1) string = ...
        "C:\EM\PopulationAnalysis\unit_table_gof.mat"
    options.OutputRoot (1, 1) string = ...
        "C:\EM\QuickTuningCleaningAnalysis"
    options.Rows (1, :) double {mustBeInteger, mustBePositive} = []
    options.OutlierThreshold (1, 1) double ...
        {mustBeFinite, mustBePositive} = 3.5
    options.MinimumTrials (1, 1) double ...
        {mustBeInteger, mustBePositive} = 5
    options.ExcludeOutliers (1, 1) logical = true
    options.MakeFigures (1, 1) logical = true
    options.FigureVisible (1, 1) logical = false
    options.SaveFIG (1, 1) logical = false
    options.Overwrite (1, 1) logical = false
    options.Resume (1, 1) logical = true
    options.CheckpointEvery (1, 1) double ...
        {mustBeInteger, mustBePositive} = 5
    options.FailFast (1, 1) logical = false
end

if ~isfile(tableFile)
    error('QuickTuningCleaning:MissingTableFile', ...
        'Source table file does not exist: %s', tableFile);
end
loaded = load(tableFile, 'unit_table_gof');
if ~isfield(loaded, 'unit_table_gof') || ...
        ~istable(loaded.unit_table_gof)
    error('QuickTuningCleaning:MissingUnitTable', ...
        '%s does not contain unit_table_gof.', tableFile);
end
sourceTable = loaded.unit_table_gof;
clear loaded
validateSourceTable(sourceTable);

settings = struct( ...
    'SchemaVersion', 1, ...
    'ExcludeOutliers', options.ExcludeOutliers, ...
    'Threshold', options.OutlierThreshold, ...
    'MinimumTrials', options.MinimumTrials, ...
    'SourceTableFile', tableFile);

threeDFolder = fullfile(options.OutputRoot, '3DQuick');
twoDFolder = fullfile(options.OutputRoot, '2DQuick');
threeDPaths = makeOutputPaths(threeDFolder, "3DQuick");
twoDPaths = makeOutputPaths(twoDFolder, "2DQuick");
ensureOutputFolders(threeDPaths);
ensureOutputFolders(twoDPaths);

unit_table_3DQuick_cleaned = loadOrInitializeTable( ...
    sourceTable, threeDPaths.TableMAT, ...
    'unit_table_3DQuick_cleaned', "3DQuick", settings, options);
unit_table_2DQuick_cleaned = loadOrInitializeTable( ...
    sourceTable, twoDPaths.TableMAT, ...
    'unit_table_2DQuick_cleaned', "2DQuick", settings, options);

rows = options.Rows;
if isempty(rows)
    rows = 1:height(sourceTable);
end
rows = unique(rows, 'stable');
if any(rows > height(sourceTable))
    error('QuickTuningCleaning:RowsOutOfRange', ...
        'Rows contains an index above table height %d.', height(sourceTable));
end

attemptCount = 0;
for rowPosition = 1:numel(rows)
    row = rows(rowPosition);
    monkey = rowText(sourceTable.Monkey, row);
    [dateLabel, dateFileText] = formatDate(sourceTable.Date(row));
    fprintf('\n[%d/%d] Row %d | %s | %s\n', ...
        rowPosition, numel(rows), row, monkey, dateLabel);

    try
        sources = DiscoverQuickTuningFiles( ...
            string(rowText(sourceTable.Paths, row)), ...
            rowValue(sourceTable.Names, row), sourceTable.Date(row));
    catch ME
        unit_table_3DQuick_cleaned = assignFailure( ...
            unit_table_3DQuick_cleaned, row, ME);
        unit_table_2DQuick_cleaned = assignFailure( ...
            unit_table_2DQuick_cleaned, row, ME);
        warning('QuickTuningCleaning:DiscoveryFailed', ...
            'Row %d source discovery failed: %s', row, ME.message);
        if options.FailFast
            rethrow(ME)
        end
        attemptCount = attemptCount + 1;
        if mod(attemptCount, options.CheckpointEvery) == 0
            saveAllOutputs(unit_table_3DQuick_cleaned, ...
                unit_table_2DQuick_cleaned, threeDPaths, twoDPaths, settings);
        end
        continue
    end

    sessionInfo = struct('Row', row, 'Monkey', string(monkey), ...
        'DateLabel', string(dateLabel), 'DateFileText', string(dateFileText), ...
        'StimChannel', double(sourceTable.StimElec(row)));

    [unit_table_3DQuick_cleaned, attempted3D] = processTask( ...
        unit_table_3DQuick_cleaned, sourceTable, row, "3DQuick", ...
        sources.ThreeD, threeDPaths, sessionInfo, options);
    [unit_table_2DQuick_cleaned, attempted2D] = processTask( ...
        unit_table_2DQuick_cleaned, sourceTable, row, "2DQuick", ...
        sources.TwoD, twoDPaths, sessionInfo, options);
    attemptCount = attemptCount + attempted3D + attempted2D;

    if mod(max(attemptCount, 1), options.CheckpointEvery) == 0
        saveAllOutputs(unit_table_3DQuick_cleaned, ...
            unit_table_2DQuick_cleaned, threeDPaths, twoDPaths, settings);
    end
end

saveAllOutputs(unit_table_3DQuick_cleaned, ...
    unit_table_2DQuick_cleaned, threeDPaths, twoDPaths, settings);
printSummary(unit_table_3DQuick_cleaned, "3DQuick", threeDPaths);
printSummary(unit_table_2DQuick_cleaned, "2DQuick", twoDPaths);
end


function [tableData, attempted] = processTask( ...
    tableData, sourceTable, row, taskName, source, paths, ...
    sessionInfo, options)
attempted = 0;
trialFile = makeTrialFile(paths.TrialFolder, sessionInfo, taskName);

canResume = options.Resume && ~options.Overwrite && ...
    startsWith(tableData.Status(row), "Success") && isfile(trialFile);
if canResume
    loaded = load(trialFile, 'QuickTrialFR');
    if isfield(loaded, 'QuickTrialFR')
        QuickResult = loaded.QuickTrialFR;
        if options.MakeFigures
            figureFiles = PlotQuickTuningCleaningComparison( ...
                QuickResult, sessionInfo, paths.FigureFolder, ...
                FigureVisible=options.FigureVisible, ...
                SaveFIG=options.SaveFIG, ...
                Overwrite=false);
            tableData.FigureFiles{row} = figureFiles;
        end
        fprintf('  %s: reused completed trial-FR result.\n', taskName);
        return
    end
end

attempted = 1;
startTime = tic;
tableData.Status(row) = "Processing";
tableData.Message(row) = "";
figuresBefore = findall(groot, 'Type', 'figure');
figureVisibility = get(groot, 'defaultFigureVisible');
visibilityCleanup = onCleanup(@() set( ...
    groot, 'defaultFigureVisible', figureVisibility));
set(groot, 'defaultFigureVisible', 'off');

try
    recordingFolder = string(fileparts(source.TInfoFile));
    [~, Neuro] = feval(char(source.Extractor), ...
        char(recordingFolder), source.FileNames, false);
    closeNewFigures(figuresBefore);

    QuickResult = BuildQuickTuningCleaningResult( ...
        Neuro, taskName, double(sourceTable.NChannels(row)), ...
        Enabled=options.ExcludeOutliers, ...
        Threshold=options.OutlierThreshold, ...
        MinimumTrials=options.MinimumTrials);
    QuickResult.UnitTableRow = row;
    QuickResult.Monkey = string(sessionInfo.Monkey);
    QuickResult.Date = sourceTable.Date(row);
    QuickResult.StimChannel = double(sourceTable.StimElec(row));
    QuickResult.Source = source;
    [alignedCleanedMean, alignedCleanedSEM, alignedCleanedCount, ...
        alignedAxis, tableDifference] = alignWithSourceTable( ...
        QuickResult, sourceTable, row, taskName);
    QuickResult.TableGrid = struct( ...
        'Axis', alignedAxis, ...
        'CleanedMean', alignedCleanedMean, ...
        'CleanedSEM', alignedCleanedSEM, ...
        'CleanedCount', alignedCleanedCount, ...
        'OriginalTableMaxAbsDifference', tableDifference);
    QuickResult.CreatedAtUTC = datetime('now', 'TimeZone', 'UTC');

    atomicSaveTrialResult(trialFile, QuickResult);
    tableData = assignSuccess(tableData, row, QuickResult, source, ...
        trialFile, alignedCleanedMean, alignedCleanedSEM, ...
        alignedCleanedCount, alignedAxis, tableDifference, toc(startTime));
    if options.MakeFigures
        figureFiles = PlotQuickTuningCleaningComparison( ...
            QuickResult, sessionInfo, paths.FigureFolder, ...
            FigureVisible=options.FigureVisible, ...
            SaveFIG=options.SaveFIG, ...
            Overwrite=options.Overwrite);
        tableData.FigureFiles{row} = figureFiles;
    end
    fprintf('  %s: %d observations across %d trials affected.\n', ...
        taskName, QuickResult.OutlierAudit.OutlierObservationCount, ...
        QuickResult.OutlierAudit.TrialWithAnyOutlierCount);
catch ME
    closeNewFigures(figuresBefore);
    tableData = assignFailure(tableData, row, ME);
    tableData.DurationSeconds(row) = toc(startTime);
    warning('QuickTuningCleaning:TaskFailed', ...
        'Row %d %s failed: %s', row, taskName, ME.message);
    if options.FailFast
        rethrow(ME)
    end
end
clear visibilityCleanup
end


function tableData = initializeResultTable(sourceTable, taskName, settings)
n = height(sourceTable);
tableData = table();
tableData.UnitTableRow = (1:n)';
tableData.Monkey = strings(n, 1);
tableData.Date = sourceTable.Date;
tableData.ROI = strings(n, 1);
tableData.StimChannel = double(sourceTable.StimElec);
tableData.NChannels = double(sourceTable.NChannels);
tableData.RecordingFolder = strings(n, 1);
for row = 1:n
    tableData.Monkey(row) = rowText(sourceTable.Monkey, row);
    tableData.ROI(row) = rowText(sourceTable.ROI, row);
    tableData.RecordingFolder(row) = rowText(sourceTable.Paths, row);
end
tableData.Task = repmat(taskName, n, 1);
tableData.Status = repmat("Pending", n, 1);
tableData.Message = strings(n, 1);
tableData.Variant = strings(n, 1);
tableData.Extractor = strings(n, 1);
tableData.TInfoFile = strings(n, 1);
tableData.SelIndexFile = strings(n, 1);
tableData.TrialFRFile = strings(n, 1);
tableData.AnalyzedTrials = nan(n, 1);
tableData.OutlierObservations = nan(n, 1);
tableData.OutlierTrials = nan(n, 1);
tableData.TestedCells = nan(n, 1);
tableData.InsufficientTrialCells = nan(n, 1);
tableData.ZeroMADCells = nan(n, 1);
tableData.OriginalTableMaxAbsDifference = nan(n, 1);
tableData.OutlierEnabled = repmat(settings.ExcludeOutliers, n, 1);
tableData.OutlierThreshold = repmat(settings.Threshold, n, 1);
tableData.OutlierMinimumTrials = repmat(settings.MinimumTrials, n, 1);
tableData.OriginalMean = repmat({[]}, n, 1);
tableData.OriginalSEM = repmat({[]}, n, 1);
tableData.OriginalCount = repmat({[]}, n, 1);
tableData.CleanedMean = repmat({[]}, n, 1);
tableData.CleanedSEM = repmat({[]}, n, 1);
tableData.CleanedCount = repmat({[]}, n, 1);
tableData.CleanedMeanTableGrid = repmat({[]}, n, 1);
tableData.CleanedSEMTableGrid = repmat({[]}, n, 1);
tableData.CleanedCountTableGrid = repmat({[]}, n, 1);
tableData.Axes = repmat({struct()}, n, 1);
tableData.TableGridAxis = repmat({[]}, n, 1);
tableData.OutlierAudit = repmat({struct()}, n, 1);
tableData.FigureFiles = repmat({strings(0, 1)}, n, 1);
tableData.ProcessedAtUTC = NaT(n, 1, 'TimeZone', 'UTC');
tableData.DurationSeconds = nan(n, 1);
end


function tableData = loadOrInitializeTable( ...
    sourceTable, tableFile, variableName, taskName, settings, options)
if options.Resume && ~options.Overwrite && isfile(tableFile)
    loaded = load(tableFile, variableName, 'PipelineMetadata');
    if ~isfield(loaded, variableName) || ...
            ~istable(loaded.(variableName))
        error('QuickTuningCleaning:InvalidResumeFile', ...
            '%s does not contain %s.', tableFile, variableName);
    end
    tableData = loaded.(variableName);
    if height(tableData) ~= height(sourceTable)
        error('QuickTuningCleaning:ResumeRowMismatch', ...
            '%s has %d rows; source table has %d.', ...
            tableFile, height(tableData), height(sourceTable));
    end
    if ~isfield(loaded, 'PipelineMetadata') || ...
            ~isequaln(loaded.PipelineMetadata.Settings, settings)
        error('QuickTuningCleaning:ResumeSettingsMismatch', ...
            ['Existing %s output used different settings. Choose a new ' ...
            'OutputRoot or set Overwrite=true.'], taskName);
    end
else
    tableData = initializeResultTable(sourceTable, taskName, settings);
end
end


function tableData = assignSuccess(tableData, row, result, source, ...
    trialFile, alignedMean, alignedSEM, alignedCount, alignedAxis, ...
    tableDifference, duration)
tableData.Status(row) = "Success";
tableData.Message(row) = "";
tableData.Variant(row) = source.Variant;
tableData.Extractor(row) = source.Extractor;
tableData.TInfoFile(row) = source.TInfoFile;
tableData.SelIndexFile(row) = source.SelIndexFile;
tableData.TrialFRFile(row) = trialFile;
tableData.AnalyzedTrials(row) = sum(result.CellTrialCounts, 'all');
tableData.OutlierObservations(row) = ...
    result.OutlierAudit.OutlierObservationCount;
tableData.OutlierTrials(row) = ...
    result.OutlierAudit.TrialWithAnyOutlierCount;
tableData.TestedCells(row) = result.OutlierAudit.TestedCellCount;
tableData.InsufficientTrialCells(row) = ...
    result.OutlierAudit.InsufficientTrialCellCount;
tableData.ZeroMADCells(row) = result.OutlierAudit.ZeroMADCellCount;
tableData.OriginalTableMaxAbsDifference(row) = tableDifference;
tableData.OriginalMean{row} = result.OriginalMean;
tableData.OriginalSEM{row} = result.OriginalSEM;
tableData.OriginalCount{row} = result.OriginalCount;
tableData.CleanedMean{row} = result.CleanedMean;
tableData.CleanedSEM{row} = result.CleanedSEM;
tableData.CleanedCount{row} = result.CleanedCount;
tableData.CleanedMeanTableGrid{row} = alignedMean;
tableData.CleanedSEMTableGrid{row} = alignedSEM;
tableData.CleanedCountTableGrid{row} = alignedCount;
tableData.Axes{row} = result.Axes;
tableData.TableGridAxis{row} = alignedAxis;
tableData.OutlierAudit{row} = result.OutlierAudit;
tableData.ProcessedAtUTC(row) = datetime('now', 'TimeZone', 'UTC');
tableData.DurationSeconds(row) = duration;
end


function tableData = assignFailure(tableData, row, exception)
tableData.Status(row) = "Failed";
tableData.Message(row) = string(exception.identifier) + ": " + ...
    string(exception.message);
tableData.ProcessedAtUTC(row) = datetime('now', 'TimeZone', 'UTC');
end


function [alignedMean, alignedSEM, alignedCount, alignedAxis, maxDifference] = ...
    alignWithSourceTable(result, sourceTable, row, taskName)
if taskName == "3DQuick"
    savedMean = double(rowValue(sourceTable.tuning_mean, row));
    alignedAxis = infer3DQuickCoherence(size(savedMean, 2));
    sourceAxis = result.Axes.Coherence;
    [isPresent, sourceColumn] = ismember( ...
        round(alignedAxis, 8), round(sourceAxis, 8));
    channelCount = result.NumChannels;
    alignedSize = [4 numel(alignedAxis) channelCount];
    alignedOriginal = nan(alignedSize);
    alignedMean = nan(alignedSize);
    alignedSEM = nan(alignedSize);
    alignedCount = zeros(alignedSize);
    alignedOriginal(:, isPresent, :) = ...
        result.OriginalMean(:, sourceColumn(isPresent), :);
    alignedMean(:, isPresent, :) = ...
        result.CleanedMean(:, sourceColumn(isPresent), :);
    alignedSEM(:, isPresent, :) = ...
        result.CleanedSEM(:, sourceColumn(isPresent), :);
    alignedCount(:, isPresent, :) = ...
        result.CleanedCount(:, sourceColumn(isPresent), :);
else
    savedMean = double(rowValue(sourceTable.tuning_2D, row));
    alignedAxis = result.Axes.DirectionDegrees;
    alignedOriginal = result.OriginalMean;
    alignedMean = result.CleanedMean;
    alignedSEM = result.CleanedSEM;
    alignedCount = result.CleanedCount;
end
maxDifference = finiteMaximumDifference(savedMean, alignedOriginal);
end


function coherence = infer3DQuickCoherence(coherenceCount)
switch coherenceCount
    case 8
        numerator = [-22 -14 -10 -8 8 10 14 22];
    case 12
        numerator = [-22 -14 -10 -8 -4 -2 2 4 8 10 14 22];
    case 13
        numerator = [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22];
    otherwise
        error('QuickTuningCleaning:Unknown3DGrid', ...
            'Expected 8, 12, or 13 saved 3D coherence columns; found %d.', ...
            coherenceCount);
end
coherence = numerator ./ 22;
end


function value = finiteMaximumDifference(a, b)
if ~isequal(size(a), size(b))
    value = Inf;
    return
end
valid = isfinite(a) & isfinite(b);
missingMismatch = xor(isfinite(a), isfinite(b));
if any(missingMismatch, 'all')
    value = Inf;
elseif any(valid, 'all')
    value = max(abs(a(valid) - b(valid)));
else
    value = NaN;
end
end


function paths = makeOutputPaths(folder, taskName)
paths = struct();
paths.Root = string(folder);
paths.TrialFolder = fullfile(folder, 'TrialFiringRates');
paths.FigureFolder = fullfile(folder, 'OriginalVsCleanedFigures');
paths.TableMAT = fullfile(folder, ...
    "unit_table_" + taskName + "_cleaned.mat");
paths.ManifestCSV = fullfile(folder, ...
    taskName + "_CleaningSessionManifest.csv");
end


function ensureOutputFolders(paths)
folders = [paths.Root paths.TrialFolder paths.FigureFolder];
for folder = folders
    if ~isfolder(folder)
        mkdir(folder);
    end
end
end


function trialFile = makeTrialFile(folder, sessionInfo, taskName)
trialFile = fullfile(folder, sprintf( ...
    'Row%03d_%s_%s_%s_TrialFR.mat', sessionInfo.Row, ...
    regexprep(char(sessionInfo.Monkey), '[^A-Za-z0-9_-]', '_'), ...
    char(sessionInfo.DateFileText), char(taskName)));
end


function atomicSaveTrialResult(destination, QuickTrialFR)
temporaryFile = string(tempname(fileparts(destination))) + ".mat";
cleanup = onCleanup(@() deleteIfPresent(temporaryFile));
save(temporaryFile, 'QuickTrialFR', '-v7.3');
[success, message] = movefile(temporaryFile, destination, 'f');
if ~success
    error('QuickTuningCleaning:TrialSaveFailed', ...
        'Could not finalize %s: %s', destination, message);
end
clear cleanup
end


function saveAllOutputs(threeDTable, twoDTable, ...
    threeDPaths, twoDPaths, settings)
saveOneOutput(threeDTable, threeDPaths, ...
    'unit_table_3DQuick_cleaned', settings);
saveOneOutput(twoDTable, twoDPaths, ...
    'unit_table_2DQuick_cleaned', settings);
end


function saveOneOutput(tableData, paths, variableName, settings)
PipelineMetadata = struct( ...
    'Settings', settings, ...
    'UpdatedAtUTC', datetime('now', 'TimeZone', 'UTC'), ...
    'OutputRoot', paths.Root);
payload = struct();
payload.(variableName) = tableData;
payload.PipelineMetadata = PipelineMetadata;
temporaryMAT = string(tempname(paths.Root)) + ".mat";
matCleanup = onCleanup(@() deleteIfPresent(temporaryMAT));
save(temporaryMAT, '-struct', 'payload', '-v7.3');
[success, message] = movefile(temporaryMAT, paths.TableMAT, 'f');
if ~success
    error('QuickTuningCleaning:TableSaveFailed', ...
        'Could not finalize %s: %s', paths.TableMAT, message);
end
clear matCleanup

manifest = makeManifest(tableData);
temporaryCSV = string(tempname(paths.Root)) + ".csv";
csvCleanup = onCleanup(@() deleteIfPresent(temporaryCSV));
writetable(manifest, temporaryCSV);
[success, message] = movefile(temporaryCSV, paths.ManifestCSV, 'f');
if ~success
    error('QuickTuningCleaning:ManifestSaveFailed', ...
        'Could not finalize %s: %s', paths.ManifestCSV, message);
end
clear csvCleanup
end


function manifest = makeManifest(tableData)
columns = ["UnitTableRow", "Monkey", "Date", "ROI", "StimChannel", ...
    "NChannels", "Task", "Status", "Message", "Variant", ...
    "Extractor", "TInfoFile", "SelIndexFile", "TrialFRFile", ...
    "AnalyzedTrials", "OutlierObservations", "OutlierTrials", ...
    "TestedCells", "InsufficientTrialCells", "ZeroMADCells", ...
    "OriginalTableMaxAbsDifference", "OutlierEnabled", ...
    "OutlierThreshold", "OutlierMinimumTrials", ...
    "ProcessedAtUTC", "DurationSeconds"];
manifest = tableData(:, columns);
figureFiles = strings(height(tableData), 1);
for row = 1:height(tableData)
    paths = string(tableData.FigureFiles{row});
    figureFiles(row) = join(paths(:)', " | ");
end
manifest.FigureFiles = figureFiles;
end


function printSummary(tableData, taskName, paths)
fprintf('\n%s cleaning summary:\n', taskName);
statuses = unique(tableData.Status, 'stable');
for status = statuses(:)'
    fprintf('  %-24s %d\n', status, nnz(tableData.Status == status));
end
fprintf('  Outlier observations: %.0f\n', ...
    sum(tableData.OutlierObservations, 'omitnan'));
fprintf('  Trials affected: %.0f\n', ...
    sum(tableData.OutlierTrials, 'omitnan'));
fprintf('  Table: %s\n', paths.TableMAT);
fprintf('  Manifest: %s\n', paths.ManifestCSV);
end


function validateSourceTable(tableData)
required = ["Date", "ROI", "Paths", "Names", "NChannels", ...
    "StimElec", "Monkey", "tuning_mean", "tuning_2D"];
missing = setdiff(required, string(tableData.Properties.VariableNames));
if ~isempty(missing)
    error('QuickTuningCleaning:MissingSourceColumns', ...
        'unit_table_gof is missing column(s): %s', join(missing, ', '));
end
end


function value = rowValue(variable, row)
if iscell(variable)
    value = variable{row};
else
    value = variable(row, :);
end
end


function value = rowText(variable, row)
value = string(rowValue(variable, row));
if numel(value) ~= 1
    value = join(value(:)', " ");
end
end


function [label, fileText] = formatDate(value)
if isdatetime(value)
    label = string(value, 'yyyy-MM-dd');
    fileText = string(value, 'yyyyMMdd');
else
    label = string(value);
    fileText = regexprep(label, '[^A-Za-z0-9_-]', '_');
end
end


function closeNewFigures(figuresBefore)
figuresAfter = findall(groot, 'Type', 'figure');
newFigures = setdiff(figuresAfter, figuresBefore);
if ~isempty(newFigures)
    close(newFigures);
end
end


function deleteIfPresent(path)
if isfile(path)
    delete(path);
end
end

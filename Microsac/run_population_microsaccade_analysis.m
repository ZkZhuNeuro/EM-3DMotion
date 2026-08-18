function BatchResults = run_population_microsaccade_analysis(unitTableFile, varargin)
%RUN_POPULATION_MICROSACCADE_ANALYSIS Run the detector across UnitTable sessions.
%
% BatchResults = run_population_microsaccade_analysis(unitTableFile) reads
% unit_table, resolves each recording folder's 3DMotionStim TInfo/SelIndex
% pair, and runs analyze_microsaccades once per session. Existing session
% results are loaded by default so an interrupted batch can be resumed.

parser = inputParser;
parser.FunctionName = mfilename;
addRequired(parser, 'unitTableFile', @(x) ischar(x) || isstring(x));
addParameter(parser, 'OutputRoot', ...
    fullfile('C:\EM\Microsac', 'population_results'), ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'AggregateSuffix', "", ...
    @(x) (ischar(x) || isstring(x)) && isscalar(string(x)));
addParameter(parser, 'SessionRows', [], ...
    @(x) isempty(x) || (isnumeric(x) && isvector(x) && all(isfinite(x))));
addParameter(parser, 'MaxSessions', Inf, ...
    @(x) isscalar(x) && ((isinf(x) && x > 0) || ...
    (isfinite(x) && x >= 1 && mod(x, 1) == 0)));
addParameter(parser, 'ComparisonPermutationCount', 1000, ...
    @(x) isscalar(x) && x >= 100 && mod(x, 1) == 0);
addParameter(parser, 'ComparisonSeed', 1729, ...
    @(x) isscalar(x) && isfinite(x) && mod(x, 1) == 0);
addParameter(parser, 'SmoothWindowMs', 5, @(x) isscalar(x) && x >= 0);
addParameter(parser, 'MinDurationMs', 12, @(x) isscalar(x) && x > 0);
addParameter(parser, 'RequireBinocular', true, @(x) islogical(x) && isscalar(x));
addParameter(parser, 'SaveEyeTraces', false, @(x) islogical(x) && isscalar(x));
addParameter(parser, 'MakeQCPlot', true, @(x) islogical(x) && isscalar(x));
addParameter(parser, 'MakeDirectionPlot', true, @(x) islogical(x) && isscalar(x));
addParameter(parser, 'MakeExampleTrajectoryPlot', true, ...
    @(x) islogical(x) && isscalar(x));
addParameter(parser, 'ExampleTrajectoryCount', 10, ...
    @(x) isscalar(x) && x >= 2 && mod(x, 1) == 0);
addParameter(parser, 'ExampleTrajectoryCountPerCondition', [], ...
    @(x) isempty(x) || (isscalar(x) && x >= 1 && mod(x, 1) == 0));
addParameter(parser, 'DirectionFigureRoot', "", ...
    @(x) ischar(x) || (isstring(x) && isscalar(x)));
addParameter(parser, 'ExampleFigureRoot', "", ...
    @(x) ischar(x) || (isstring(x) && isscalar(x)));
addParameter(parser, 'OverwriteExisting', false, @(x) islogical(x) && isscalar(x));
addParameter(parser, 'ContinueOnError', true, @(x) islogical(x) && isscalar(x));
addParameter(parser, 'DryRun', false, @(x) islogical(x) && isscalar(x));
parse(parser, unitTableFile, varargin{:});
options = parser.Results;
aggregateSuffix = char(string(options.AggregateSuffix));
assert(isempty(regexp(aggregateSuffix, '[^A-Za-z0-9_-]', 'once')), ...
    'AggregateSuffix may contain only letters, numbers, underscores, and hyphens.');

unitTableFile = char(unitTableFile);
outputRoot = char(options.OutputRoot);
assert(isfile(unitTableFile), 'UnitTable file not found: %s', unitTableFile);
if ~isfolder(outputRoot)
    mkdir(outputRoot);
end

loaded = load(unitTableFile, 'unit_table');
assert(isfield(loaded, 'unit_table') && istable(loaded.unit_table), ...
    'The MAT file does not contain a table named unit_table.');
unitTable = loaded.unit_table;
requiredVariables = {'Date', 'Monkey', 'ROI', 'Paths'};
assert(all(ismember(requiredVariables, unitTable.Properties.VariableNames)), ...
    'unit_table must contain Date, Monkey, ROI, and Paths variables.');

if isempty(options.SessionRows)
    sessionRows = 1:height(unitTable);
else
    sessionRows = unique(options.SessionRows(:)', 'stable');
    assert(all(sessionRows >= 1 & sessionRows <= height(unitTable) & ...
        mod(sessionRows, 1) == 0), ...
        'SessionRows must contain integer row numbers within unit_table.');
end

SessionTable = emptySessionTable();
CombinedSummaryTable = table;
CombinedDirectionStatsTable = table;
CombinedStimComparisonTable = table;
completedCount = 0;

fprintf('Loaded %d sessions from %s.\n', height(unitTable), unitTableFile);
for row = sessionRows
    if completedCount >= options.MaxSessions
        break
    end

    recordingDate = unitTable.Date(row);
    monkey = string(unitTable.Monkey(row));
    roi = string(unitTable.ROI(row));
    recordingFolder = char(string(unitTable.Paths(row)));
    [tInfoFile, selIndexFile, resolutionMessage] = ...
        resolveStimFilePair(recordingFolder);

    if isempty(tInfoFile)
        SessionTable = [SessionTable; makeSessionRow(row, recordingDate, monkey, ...
            roi, recordingFolder, "", "", "", "SkippedNoFiles", ...
            resolutionMessage, NaN, NaN, NaN, 0)]; %#ok<AGROW>
        fprintf('[%d/%d] Skipped row %d: %s\n', row, height(unitTable), ...
            row, resolutionMessage);
        BatchResults = writeBatchCheckpoint(outputRoot, unitTableFile, unitTable, options, ...
            SessionTable, CombinedSummaryTable, CombinedDirectionStatsTable, ...
            CombinedStimComparisonTable);
        continue
    end

    [~, inputStem] = fileparts(tInfoFile);
    inputStem = regexprep(inputStem, '_TInfo$', '', 'ignorecase');
    sessionFolderName = sprintf('%03d_%s', row, ...
        regexprep(inputStem, '[^A-Za-z0-9_-]', '_'));
    sessionOutputDir = fullfile(outputRoot, sessionFolderName);
    expectedMat = fullfile(sessionOutputDir, [inputStem '_microsaccades.mat']);
    directionFigureFile = "";
    if strlength(string(options.DirectionFigureRoot)) > 0
        directionFigureFile = fullfile(string(options.DirectionFigureRoot), ...
            sprintf('%03d_%s_direction_envelope.png', row, inputStem));
    end
    exampleFigureFile = "";
    if strlength(string(options.ExampleFigureRoot)) > 0
        exampleFigureFile = fullfile(string(options.ExampleFigureRoot), ...
            sprintf('%03d_%s_random_trajectories.png', row, inputStem));
    end
    completedCount = completedCount + 1;

    if options.DryRun
        SessionTable = [SessionTable; makeSessionRow(row, recordingDate, monkey, ...
            roi, recordingFolder, tInfoFile, selIndexFile, sessionOutputDir, ...
            "Ready", "Resolved without analysis because DryRun is true.", ...
            NaN, NaN, NaN, 0)]; %#ok<AGROW>
        fprintf('[%d/%d] Ready: %s\n', completedCount, ...
            min(numel(sessionRows), options.MaxSessions), tInfoFile);
        BatchResults = writeBatchCheckpoint(outputRoot, unitTableFile, unitTable, options, ...
            SessionTable, CombinedSummaryTable, CombinedDirectionStatsTable, ...
            CombinedStimComparisonTable);
        continue
    end

    startTime = tic;
    try
        if isfile(expectedMat) && ~options.OverwriteExisting
            saved = load(expectedMat, 'Results');
            assert(isfield(saved, 'Results'), ...
                'Existing MAT file does not contain Results: %s', expectedMat);
            Results = saved.Results;
            status = "LoadedExisting";
            message = "Loaded the existing result; analysis was not repeated.";
        else
            fprintf('\n[%d/%d] Analyzing UnitTable row %d: %s\n', ...
                completedCount, min(numel(sessionRows), options.MaxSessions), ...
                row, tInfoFile);
            Results = analyze_microsaccades(tInfoFile, selIndexFile, ...
                'OutputDir', sessionOutputDir, ...
                'SmoothWindowMs', options.SmoothWindowMs, ...
                'VelocityThresholdLambda', 6, ...
                'MinDurationMs', options.MinDurationMs, ...
                'MergeGapMs', 0, ...
                'MinAmplitudeDeg', 0, ...
                'MaxAmplitudeDeg', Inf, ...
                'MaxDurationMs', Inf, ...
                'MaxInterocularOnsetLagMs', Inf, ...
                'MaxDirectionDifferenceDeg', 180, ...
                'RequireBinocular', options.RequireBinocular, ...
                'ComparisonPermutationCount', options.ComparisonPermutationCount, ...
                'ComparisonSeed', options.ComparisonSeed + row, ...
                'SaveEyeTraces', options.SaveEyeTraces, ...
                'MakeQCPlot', options.MakeQCPlot, ...
                'MakeDirectionPlot', options.MakeDirectionPlot, ...
                'MakeExampleTrajectoryPlot', options.MakeExampleTrajectoryPlot, ...
                'ExampleTrajectoryCount', options.ExampleTrajectoryCount, ...
                'ExampleTrajectoryCountPerCondition', ...
                options.ExampleTrajectoryCountPerCondition, ...
                'ExampleTrajectorySeed', options.ComparisonSeed + 100000 + row, ...
                'DirectionFigureFile', directionFigureFile, ...
                'ExampleTrajectoryFigureFile', exampleFigureFile);
            status = "Completed";
            message = "";
        end

        runtimeSeconds = toc(startTime);
        trialCount = height(Results.TrialTable);
        validTrialCount = nnz(Results.TrialTable.HasAnalysisWindow);
        eventCount = height(Results.MicrosaccadeTable);
        SessionTable = [SessionTable; makeSessionRow(row, recordingDate, monkey, ...
            roi, recordingFolder, tInfoFile, selIndexFile, sessionOutputDir, ...
            status, message, trialCount, validTrialCount, eventCount, ...
            runtimeSeconds)]; %#ok<AGROW>
        CombinedSummaryTable = appendSessionMetadata(CombinedSummaryTable, ...
            Results.SummaryTable, row, recordingDate, monkey, roi, tInfoFile);
        CombinedDirectionStatsTable = appendSessionMetadata( ...
            CombinedDirectionStatsTable, Results.DirectionStatsTable, row, ...
            recordingDate, monkey, roi, tInfoFile);
        CombinedStimComparisonTable = appendSessionMetadata( ...
            CombinedStimComparisonTable, Results.StimComparisonTable, row, ...
            recordingDate, monkey, roi, tInfoFile);
        fprintf('Session row %d finished: %d trials, %d events, %.1f s.\n', ...
            row, trialCount, eventCount, runtimeSeconds);
    catch errorInfo
        runtimeSeconds = toc(startTime);
        SessionTable = [SessionTable; makeSessionRow(row, recordingDate, monkey, ...
            roi, recordingFolder, tInfoFile, selIndexFile, sessionOutputDir, ...
            "Failed", string(errorInfo.message), NaN, NaN, NaN, ...
            runtimeSeconds)]; %#ok<AGROW>
        fprintf(2, 'Session row %d failed: %s\n', row, errorInfo.message);
        BatchResults = writeBatchCheckpoint(outputRoot, unitTableFile, unitTable, options, ...
            SessionTable, CombinedSummaryTable, CombinedDirectionStatsTable, ...
            CombinedStimComparisonTable);
        if ~options.ContinueOnError
            rethrow(errorInfo)
        end
        continue
    end

    BatchResults = writeBatchCheckpoint(outputRoot, unitTableFile, unitTable, options, ...
        SessionTable, CombinedSummaryTable, CombinedDirectionStatsTable, ...
        CombinedStimComparisonTable);
end

if ~exist('BatchResults', 'var')
    BatchResults = writeBatchCheckpoint(outputRoot, unitTableFile, unitTable, options, ...
        SessionTable, CombinedSummaryTable, CombinedDirectionStatsTable, ...
        CombinedStimComparisonTable);
end
fprintf('\nPopulation microsaccade batch finished. Manifest: %s\n', ...
    BatchResults.OutputFiles.SessionManifestCSV);
end


function [tInfoFile, selIndexFile, message] = resolveStimFilePair(recordingFolder)
tInfoFile = '';
selIndexFile = '';
message = '';
if ~isfolder(recordingFolder)
    message = sprintf('Recording folder not found: %s', recordingFolder);
    return
end

topLevelFiles = dir(fullfile(recordingFolder, '*.mat'));
[tInfoFile, selIndexFile] = selectBestStimPair(topLevelFiles);
if ~isempty(tInfoFile)
    return
end

recursiveFiles = dir(fullfile(recordingFolder, '**', '*.mat'));
if isempty(recursiveFiles)
    message = sprintf('No MAT files found under %s.', recordingFolder);
    return
end
folderNames = unique(string({recursiveFiles.folder}), 'stable');
for iFolder = 1:numel(folderNames)
    folderMask = strcmp({recursiveFiles.folder}, char(folderNames(iFolder)));
    [candidateTInfo, candidateSelIndex, candidateScore] = ...
        selectBestStimPair(recursiveFiles(folderMask));
    if ~isempty(candidateTInfo)
        relativeDepth = count(folderNames(iFolder), filesep) - ...
            count(string(recordingFolder), filesep);
        folderScore = candidateScore - 1000 * max(relativeDepth, 0);
        if ~exist('bestFolderScore', 'var') || folderScore > bestFolderScore
            bestFolderScore = folderScore;
            tInfoFile = candidateTInfo;
            selIndexFile = candidateSelIndex;
        end
    end
end
if isempty(tInfoFile)
    message = sprintf(['No paired 3DMotionStim TInfo and SelIndex files ' ...
        'were found under %s.'], recordingFolder);
end
end


function [tInfoFile, selIndexFile, bestScore] = selectBestStimPair(files)
tInfoFile = '';
selIndexFile = '';
bestScore = -Inf;
if isempty(files)
    return
end

names = string({files.name});
lowerNames = lower(names);
tInfoMask = contains(lowerNames, '3dmotionstim') & ...
    contains(lowerNames, 'tinfo');
tInfoCandidates = find(tInfoMask);
for index = tInfoCandidates
    expectedSelIndex = regexprep(char(files(index).name), ...
        '_TInfo\.mat$', '_SelIndex.mat', 'ignorecase');
    selIndex = find(strcmpi({files.name}, expectedSelIndex), 1, 'first');
    if isempty(selIndex)
        continue
    end
    score = scoreInputFile(files(index));
    if score > bestScore
        bestScore = score;
        tInfoFile = fullfile(files(index).folder, files(index).name);
        selIndexFile = fullfile(files(selIndex).folder, files(selIndex).name);
    end
end
if isempty(tInfoFile)
    selIndexMask = contains(lowerNames, '3dmotionstim') & ...
        contains(lowerNames, 'selindex');
    selIndexCandidates = find(selIndexMask);
    if ~isempty(tInfoCandidates) && ~isempty(selIndexCandidates)
        tInfoScores = arrayfun(@(index) scoreInputFile(files(index)), ...
            tInfoCandidates);
        selIndexScores = arrayfun(@(index) scoreInputFile(files(index)), ...
            selIndexCandidates);
        [bestTInfoScore, bestTInfo] = max(tInfoScores);
        [bestSelIndexScore, bestSelIndex] = max(selIndexScores);
        tInfoIndex = tInfoCandidates(bestTInfo);
        selIndexIndex = selIndexCandidates(bestSelIndex);
        tInfoFile = fullfile(files(tInfoIndex).folder, files(tInfoIndex).name);
        selIndexFile = fullfile(files(selIndexIndex).folder, files(selIndexIndex).name);
        bestScore = bestTInfoScore + bestSelIndexScore;
    end
end
end


function score = scoreInputFile(fileInfo)
lowerName = lower(fileInfo.name);
score = fileInfo.datenum / 1e6;
score = score + 100 * contains(lowerName, 'mua');
score = score + 10 * contains(lowerName, 'final');
score = score + 5 * contains(lowerName, 'edit');
end


function output = appendSessionMetadata(output, input, row, recordingDate, ...
        monkey, roi, tInfoFile)
rowCount = height(input);
input = addvars(input, repmat(row, rowCount, 1), ...
    repmat(recordingDate, rowCount, 1), repmat(monkey, rowCount, 1), ...
    repmat(roi, rowCount, 1), repmat(string(tInfoFile), rowCount, 1), ...
    'Before', 1, 'NewVariableNames', {'UnitTableRow', 'Date', 'Monkey', ...
    'ROI', 'TrialInfoFile'});
if isempty(output)
    output = input;
else
    output = [output; input];
end
end


function row = makeSessionRow(unitTableRow, recordingDate, monkey, roi, ...
        recordingFolder, tInfoFile, selIndexFile, outputDir, status, message, ...
        trialCount, validTrialCount, eventCount, runtimeSeconds)
row = table(unitTableRow, recordingDate, monkey, roi, string(recordingFolder), ...
    string(tInfoFile), string(selIndexFile), string(outputDir), string(status), ...
    string(message), trialCount, validTrialCount, eventCount, runtimeSeconds, ...
    'VariableNames', {'UnitTableRow', 'Date', 'Monkey', 'ROI', ...
    'RecordingFolder', 'TrialInfoFile', 'SelIndexFile', 'OutputDir', ...
    'Status', 'Message', 'TrialCount', 'ValidTrialCount', 'EventCount', ...
    'RuntimeSeconds'});
end


function output = emptySessionTable()
output = table('Size', [0, 14], 'VariableTypes', ...
    {'double', 'datetime', 'string', 'string', 'string', 'string', 'string', ...
    'string', 'string', 'string', 'double', 'double', 'double', 'double'}, ...
    'VariableNames', {'UnitTableRow', 'Date', 'Monkey', 'ROI', ...
    'RecordingFolder', 'TrialInfoFile', 'SelIndexFile', 'OutputDir', ...
    'Status', 'Message', 'TrialCount', 'ValidTrialCount', 'EventCount', ...
    'RuntimeSeconds'});
end


function BatchResults = writeBatchCheckpoint(outputRoot, unitTableFile, sourceUnitTable, options, ...
        SessionTable, CombinedSummaryTable, CombinedDirectionStatsTable, ...
        CombinedStimComparisonTable)
suffix = char(string(options.AggregateSuffix));
outputFiles = struct( ...
    'Mat', fullfile(outputRoot, ['population_microsaccade_results' suffix '.mat']), ...
    'SessionManifestCSV', fullfile(outputRoot, ...
    ['population_microsaccade_session_manifest' suffix '.csv']), ...
    'SummaryCSV', fullfile(outputRoot, ...
    ['population_microsaccade_summary' suffix '.csv']), ...
    'DirectionStatsCSV', fullfile(outputRoot, ...
    ['population_microsaccade_direction_stats' suffix '.csv']), ...
    'StimComparisonCSV', fullfile(outputRoot, ...
    ['population_microsaccade_stim_nonstim_tests' suffix '.csv']), ...
    'UnitTableMat', fullfile(outputRoot, ...
    ['unit_table_microsaccades' suffix '.mat']));

BatchResults = struct;
BatchResults.UnitTableFile = unitTableFile;
BatchResults.Parameters = options;
BatchResults.SessionTable = SessionTable;
BatchResults.CombinedSummaryTable = CombinedSummaryTable;
BatchResults.CombinedDirectionStatsTable = CombinedDirectionStatsTable;
BatchResults.CombinedStimComparisonTable = CombinedStimComparisonTable;
BatchResults.OutputFiles = outputFiles;

writetable(SessionTable, outputFiles.SessionManifestCSV);
if ~isempty(CombinedSummaryTable)
    writetable(CombinedSummaryTable, outputFiles.SummaryCSV);
end
if ~isempty(CombinedDirectionStatsTable)
    writetable(CombinedDirectionStatsTable, outputFiles.DirectionStatsCSV);
end
if ~isempty(CombinedStimComparisonTable)
    writetable(CombinedStimComparisonTable, outputFiles.StimComparisonCSV);
end
unit_table = makeMicrosaccadeUnitTable(sourceUnitTable, SessionTable, ...
    CombinedSummaryTable, CombinedDirectionStatsTable, CombinedStimComparisonTable);
save(outputFiles.UnitTableMat, 'unit_table', '-v7.3');
save(outputFiles.Mat, 'BatchResults', '-v7.3');
end


function unitTable = makeMicrosaccadeUnitTable(sourceUnitTable, sessions, summaries, ...
        directionStats, comparisons)
unitTable = sourceUnitTable;
nRows = height(unitTable);
unitTable.MS_Status = strings(nRows, 1);
unitTable.MS_Message = strings(nRows, 1);
unitTable.MS_TrialInfoFile = strings(nRows, 1);
unitTable.MS_SelIndexFile = strings(nRows, 1);
unitTable.MS_OutputDir = strings(nRows, 1);
unitTable.MS_ResultMat = strings(nRows, 1);
unitTable.MS_EventDataMat = strings(nRows, 1);
unitTable.MS_TrialCount = nan(nRows, 1);
unitTable.MS_ValidTrialCount = nan(nRows, 1);
unitTable.MS_EventCount = nan(nRows, 1);
unitTable.MS_RuntimeSeconds = nan(nRows, 1);
unitTable.MS_NonStimEventCount = nan(nRows, 1);
unitTable.MS_StimEventCount = nan(nRows, 1);
unitTable.MS_NonStimMeanRateHz = nan(nRows, 1);
unitTable.MS_StimMeanRateHz = nan(nRows, 1);
unitTable.MS_NonStimRayleighP = nan(nRows, 1);
unitTable.MS_StimRayleighP = nan(nRows, 1);
unitTable.MS_RatePermutationP = nan(nRows, 1);
unitTable.MS_AnyPermutationP = nan(nRows, 1);
unitTable.MS_AmplitudePermutationP = nan(nRows, 1);
unitTable.MS_PeakVelocityPermutationP = nan(nRows, 1);
unitTable.MS_DurationPermutationP = nan(nRows, 1);
unitTable.MS_DirectionPermutationP = nan(nRows, 1);

for i = 1:height(sessions)
    row = sessions.UnitTableRow(i);
    unitTable.MS_Status(row) = sessions.Status(i);
    unitTable.MS_Message(row) = sessions.Message(i);
    unitTable.MS_TrialInfoFile(row) = sessions.TrialInfoFile(i);
    unitTable.MS_SelIndexFile(row) = sessions.SelIndexFile(i);
    unitTable.MS_OutputDir(row) = sessions.OutputDir(i);
    unitTable.MS_TrialCount(row) = sessions.TrialCount(i);
    unitTable.MS_ValidTrialCount(row) = sessions.ValidTrialCount(i);
    unitTable.MS_EventCount(row) = sessions.EventCount(i);
    unitTable.MS_RuntimeSeconds(row) = sessions.RuntimeSeconds(i);
    if strlength(sessions.TrialInfoFile(i)) > 0 && strlength(sessions.OutputDir(i)) > 0
        [~, stem] = fileparts(sessions.TrialInfoFile(i));
        stem = regexprep(stem, '_TInfo$', '', 'ignorecase');
        base = fullfile(sessions.OutputDir(i), stem + "_microsaccades");
        unitTable.MS_ResultMat(row) = base + ".mat";
        unitTable.MS_EventDataMat(row) = base + "_event_data.mat";
    end
end

for i = 1:height(summaries)
    row = summaries.UnitTableRow(i);
    if summaries.TrialType(i) == "NonStim"
        unitTable.MS_NonStimEventCount(row) = summaries.MicrosaccadeCount(i);
        unitTable.MS_NonStimMeanRateHz(row) = summaries.MeanRateHz(i);
    else
        unitTable.MS_StimEventCount(row) = summaries.MicrosaccadeCount(i);
        unitTable.MS_StimMeanRateHz(row) = summaries.MeanRateHz(i);
    end
end

for i = 1:height(directionStats)
    row = directionStats.UnitTableRow(i);
    if directionStats.TrialType(i) == "NonStim"
        unitTable.MS_NonStimRayleighP(row) = directionStats.RayleighP(i);
    else
        unitTable.MS_StimRayleighP(row) = directionStats.RayleighP(i);
    end
end

metricVariables = ["MS_RatePermutationP", "MS_AnyPermutationP", ...
    "MS_AmplitudePermutationP", "MS_PeakVelocityPermutationP", ...
    "MS_DurationPermutationP", "MS_DirectionPermutationP"];
metricNames = ["MicrosaccadeRate", "AnyMicrosaccade", "MeanAmplitude", ...
    "MeanPeakVelocity", "MeanDuration", "DirectionFirstMoment"];
if ~isempty(comparisons)
    for iMetric = 1:numel(metricNames)
        mask = comparisons.Metric == metricNames(iMetric);
        metricRows = comparisons.UnitTableRow(mask);
        metricP = comparisons.PermutationP(mask);
        unitTable.(metricVariables(iMetric))(metricRows) = metricP;
    end
end
end

function [unit_table_stim, SessionManifest, PipelineMetadata] = ...
    BuildUnitTableStimTunings(unitTableGofFile, outputFolder, options)
%BUILDUNITTABLESTIMTUNINGS Extract Stim-file 3-D tuning for a unit table.
%
% [unit_table_stim, SessionManifest] = BuildUnitTableStimTunings(...)
% copies unit_table_gof and appends zero-inclusive 3-D motion tuning from
% each session's MUA 3DMotionStim recording in three forms:
%   1. non-electrical-stimulation trials only;
%   2. electrical-stimulation trials only; and
%   3. both trial types pooled before calculating the mean and SEM.
%
% Six cell columns store the mean and SEM arrays for unit 1 (MUA) in
% cue x coherence x acquisition-channel order. Trial-level firing rates are
% deliberately excluded from the table. One compact MAT file per session
% stores its analyzed-trial x channel x unit firing-rate array and aligned
% TrialSummary under outputFolder/TrialFiringRates.
%
% The output MAT is checkpointed atomically and can be resumed. The source
% unit_table_gof file is read only and is never overwritten.
%
% Name-value options:
%   Rows                 - table rows to process; [] means all rows
%   ApplyEyeCheck        - request the Quick pipeline eye check (true)
%   RequireEyeCheck      - fail a row if requested eye check is not applied
%                          (false; otherwise status records a warning)
%   EyeCheckChunkSize    - trials per eye-check call (128)
%   TrialProgressInterval - extractor progress interval; 0 disables (0)
%   Resume               - reuse a compatible partial/final output (true)
%   OverwriteOutput      - ignore an existing output and start anew (false)
%   CheckpointEvery      - save the table after this many attempted rows (1)
%   RecursiveSearch      - search below each Paths folder (false). The
%                          table's exact session folder is authoritative.
%   MaxDirectTrialInfoBytes - v7.3 TrialInfo arrays at or above this
%                          uncompressed size are streamed through a slim
%                          temporary MAT file before extraction (512 MiB)
%   DryRun               - resolve files without extracting data (false)
%   FailFast             - rethrow the first row extraction error (false)

% Output files:
%   unit_table_stim.mat
%   StimTuningSessionManifest.csv
%   TrialFiringRates/<row>_<monkey>_<date>_StimTrialFR.mat

% See also Extract3DMotionStimTuning.

arguments
    unitTableGofFile (1, 1) string
    outputFolder (1, 1) string
    options.Rows (1, :) double {mustBeInteger, mustBePositive} = []
    options.ApplyEyeCheck (1, 1) logical = true
    options.RequireEyeCheck (1, 1) logical = false
    options.EyeCheckChunkSize (1, 1) double ...
        {mustBeInteger, mustBePositive} = 128
    options.TrialProgressInterval (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 0
    options.Resume (1, 1) logical = true
    options.OverwriteOutput (1, 1) logical = false
    options.CheckpointEvery (1, 1) double ...
        {mustBeInteger, mustBePositive} = 1
    options.RecursiveSearch (1, 1) logical = false
    options.MaxDirectTrialInfoBytes (1, 1) double ...
        {mustBeFinite, mustBePositive} = 512 * 1024^2
    options.DryRun (1, 1) logical = false
    options.FailFast (1, 1) logical = false
end

schemaVersion = "unit_table_stim_v1";
extractorInfo = dir(which('Extract3DMotionStimTuning'));
if isempty(extractorInfo)
    error('UnitTableStim:MissingExtractor', ...
        'Extract3DMotionStimTuning.m is not on the MATLAB path.');
end
if ~isfile(unitTableGofFile)
    error('UnitTableStim:MissingInputTable', ...
        'unit_table_gof MAT file not found: %s', unitTableGofFile);
end
if strlength(outputFolder) == 0
    error('UnitTableStim:MissingOutputFolder', ...
        'Provide a nonempty output folder.');
end

if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
trialFolder = fullfile(outputFolder, 'TrialFiringRates');
if ~isfolder(trialFolder)
    mkdir(trialFolder);
end
stateFile = fullfile(outputFolder, 'unit_table_stim.mat');
manifestFile = fullfile(outputFolder, ...
    'StimTuningSessionManifest.csv');

inputSignature = makeFileSignature(unitTableGofFile);
extractorSignature = makeFileSignature( ...
    string(which('Extract3DMotionStimTuning')));
analysisSignature = makeAnalysisSignature( ...
    schemaVersion, extractorSignature, options);
PipelineMetadata = struct( ...
    'SchemaVersion', schemaVersion, ...
    'InputTableFile', unitTableGofFile, ...
    'InputTableSignature', inputSignature, ...
    'ExtractorFile', string(which('Extract3DMotionStimTuning')), ...
    'ExtractorSignature', extractorSignature, ...
    'AnalysisSignature', analysisSignature, ...
    'OutputFolder', outputFolder, ...
    'CreatedAtUTC', datetime('now', 'TimeZone', 'UTC'), ...
    'ApplyEyeCheck', options.ApplyEyeCheck, ...
    'RequireEyeCheck', options.RequireEyeCheck, ...
    'DryRun', options.DryRun);

resumeLoaded = false;
if options.Resume && ~options.OverwriteOutput && isfile(stateFile)
    prior = load(stateFile, 'unit_table_stim', 'SessionManifest', ...
        'PipelineMetadata');
    if ~isfield(prior, 'unit_table_stim') || ...
            ~isfield(prior, 'PipelineMetadata')
        error('UnitTableStim:InvalidResumeFile', ...
            'Existing state file is missing required variables: %s', ...
            stateFile);
    end
    validateResumeMetadata(prior.PipelineMetadata, ...
        schemaVersion, inputSignature, analysisSignature);
    unit_table_stim = prior.unit_table_stim;
    PipelineMetadata = prior.PipelineMetadata;
    PipelineMetadata.LastResumedAtUTC = utcNow();
    resumeLoaded = true;
    fprintf('Resuming compatible output: %s\n', stateFile);
else
    inputData = load(unitTableGofFile, 'unit_table_gof');
    if ~isfield(inputData, 'unit_table_gof') || ...
            ~istable(inputData.unit_table_gof)
        error('UnitTableStim:MissingUnitTableVariable', ...
            '%s does not contain table unit_table_gof.', ...
            unitTableGofFile);
    end
    unit_table_stim = initializeStimColumns( ...
        inputData.unit_table_gof, schemaVersion);
    clear inputData
end

requiredBaseVariables = ["Date", "Paths", "Monkey", "StimElec"];
missingVariables = setdiff(requiredBaseVariables, ...
    string(unit_table_stim.Properties.VariableNames));
if ~isempty(missingVariables)
    error('UnitTableStim:MissingBaseColumns', ...
        'The input table is missing required column(s): %s', ...
        join(missingVariables, ', '));
end

rowCount = height(unit_table_stim);
rows = options.Rows;
if isempty(rows)
    rows = 1:rowCount;
end
rows = unique(rows, 'stable');
if any(rows > rowCount)
    error('UnitTableStim:RowsOutOfRange', ...
        'Rows contains an index greater than table height %d.', rowCount);
end

fprintf(['Building stimulation tuning for %d of %d unit-table rows ' ...
    '(resume=%d, dryRun=%d).\n'], numel(rows), rowCount, ...
    resumeLoaded, options.DryRun);

attemptCount = 0;
for row = rows
    attemptCount = attemptCount + 1;
    rowStart = tic;
    monkey = getRowText(unit_table_stim.Monkey, row);
    recordingDate = unit_table_stim.Date(row);
    recordingFolder = getRowText(unit_table_stim.Paths, row);
    fprintf('\n[%d/%d] Row %d: %s %s\n', attemptCount, numel(rows), ...
        row, monkey, char(string(recordingDate, 'yyyy-MM-dd')));

    discovery = resolveStimPair(recordingFolder, ...
        options.RecursiveSearch);
    unit_table_stim.stim_tuning_pair_candidate_count(row) = ...
        discovery.CandidateCount;
    unit_table_stim.stim_tuning_message(row) = discovery.Message;

    if discovery.Status == "MissingStimPair"
        unit_table_stim.stim_tuning_status(row) = discovery.Status;
        unit_table_stim.stim_tuning_processed_at(row) = utcNow();
        unit_table_stim.stim_tuning_duration_seconds(row) = toc(rowStart);
        fprintf('  Missing Stim pair: %s\n', discovery.Message);
        [~, PipelineMetadata] = checkpointIfNeeded( ...
            unit_table_stim, PipelineMetadata, stateFile, manifestFile, ...
            attemptCount, options.CheckpointEvery, false);
        continue
    elseif discovery.Status == "AmbiguousStimPair"
        unit_table_stim.stim_tuning_status(row) = discovery.Status;
        unit_table_stim.stim_tuning_processed_at(row) = utcNow();
        unit_table_stim.stim_tuning_duration_seconds(row) = toc(rowStart);
        fprintf('  Ambiguous Stim pair: %s\n', discovery.Message);
        [~, PipelineMetadata] = checkpointIfNeeded( ...
            unit_table_stim, PipelineMetadata, stateFile, manifestFile, ...
            attemptCount, options.CheckpointEvery, false);
        continue
    end

    sourceKey = makeSourceKey(discovery.TInfoFile, ...
        discovery.SelIndexFile);
    sourceSignature = makeSourceSignature( ...
        discovery.TInfoFile, discovery.SelIndexFile);
    reusableCompletedRow = isReusableRow( ...
        unit_table_stim, row, sourceSignature);
    unit_table_stim.stim_tuning_source_key(row) = sourceKey;
    unit_table_stim.stim_tuning_source_signature(row) = sourceSignature;
    unit_table_stim.stim_tuning_tinfo_file(row) = discovery.TInfoFile;
    unit_table_stim.stim_tuning_selindex_file(row) = ...
        discovery.SelIndexFile;

    if options.DryRun
        unit_table_stim.stim_tuning_status(row) = "Ready";
        unit_table_stim.stim_tuning_message(row) = discovery.Message;
        unit_table_stim.stim_tuning_processed_at(row) = utcNow();
        unit_table_stim.stim_tuning_duration_seconds(row) = toc(rowStart);
        fprintf('  Ready: %s\n', discovery.TInfoFile);
        [~, PipelineMetadata] = checkpointIfNeeded( ...
            unit_table_stim, PipelineMetadata, stateFile, manifestFile, ...
            attemptCount, options.CheckpointEvery, false);
        continue
    end

    if reusableCompletedRow
        fprintf('  Reused completed row and trial FR file.\n');
        continue
    end

    trialFile = makeTrialFRPath( ...
        trialFolder, row, monkey, recordingDate);
    [unit_table_stim, recovered] = recoverFromTrialFR( ...
        unit_table_stim, row, trialFile, sourceSignature, ...
        options.ApplyEyeCheck, options.RequireEyeCheck);
    if recovered
        unit_table_stim.stim_tuning_duration_seconds(row) = toc(rowStart);
        fprintf('  Recovered table tuning from existing trial FR file.\n');
        [~, PipelineMetadata] = checkpointIfNeeded( ...
            unit_table_stim, PipelineMetadata, stateFile, manifestFile, ...
            attemptCount, options.CheckpointEvery, false);
        continue
    end

    duplicateRow = findReusableSourceRow( ...
        unit_table_stim, row, sourceKey, sourceSignature);
    if ~isempty(duplicateRow)
        unit_table_stim = copyStimResults( ...
            unit_table_stim, duplicateRow, row);
        unit_table_stim.stim_tuning_message(row) = ...
            "Reused identical Stim source from table row " + ...
            string(duplicateRow);
        unit_table_stim.stim_tuning_processed_at(row) = utcNow();
        unit_table_stim.stim_tuning_duration_seconds(row) = toc(rowStart);
        fprintf('  Reused identical source from row %d.\n', duplicateRow);
        [~, PipelineMetadata] = checkpointIfNeeded( ...
            unit_table_stim, PipelineMetadata, stateFile, manifestFile, ...
            attemptCount, options.CheckpointEvery, false);
        continue
    end

    unit_table_stim.stim_tuning_status(row) = "Running";
    unit_table_stim.stim_tuning_error_identifier(row) = "";
    unit_table_stim = clearRowResults(unit_table_stim, row);
    try
        [Neuro, TrialSummary, ExtractionSummary] = ...
            extractStimWithMemorySafeInput(discovery, options);

        [Neuro, ExtractionSummary] = retainExpectedChannels( ...
            Neuro, ExtractionSummary, unit_table_stim, row);
        validateExtractedTuning(Neuro, unit_table_stim, row);
        validateTrialFiringRate(Neuro, TrialSummary);
        eyeWarning = evaluateEyeCheck( ...
            ExtractionSummary, options.ApplyEyeCheck, ...
            options.RequireEyeCheck);

        unit_table_stim = assignTuningResults( ...
            unit_table_stim, row, Neuro, ExtractionSummary);
        StimTrialFR = makeTrialFRStruct( ...
            row, unit_table_stim, discovery, sourceKey, ...
            sourceSignature, Neuro, TrialSummary, ExtractionSummary, ...
            schemaVersion);
        atomicSaveTrialFR(trialFile, StimTrialFR);
        unit_table_stim.stim_tuning_trial_FR_file(row) = trialFile;
        if strlength(eyeWarning) > 0
            unit_table_stim.stim_tuning_status(row) = ...
                "SuccessWithEyeCheckWarning";
            unit_table_stim.stim_tuning_message(row) = eyeWarning;
        else
            unit_table_stim.stim_tuning_status(row) = "Success";
            unit_table_stim.stim_tuning_message(row) = discovery.Message;
        end
        unit_table_stim.stim_tuning_processed_at(row) = utcNow();
        unit_table_stim.stim_tuning_duration_seconds(row) = toc(rowStart);
        fprintf(['  %s: %d NoStim, %d Stim trials; ' ...
            'trial FR -> %s\n'], ...
            unit_table_stim.stim_tuning_status(row), ...
            ExtractionSummary.NoStimTrialCount, ...
            ExtractionSummary.StimTrialCount, trialFile);
        clear Neuro TrialSummary ExtractionSummary StimTrialFR
    catch ME
        clear Neuro TrialSummary ExtractionSummary StimTrialFR
        unit_table_stim = clearRowResults(unit_table_stim, row);
        unit_table_stim.stim_tuning_status(row) = "ExtractionFailed";
        unit_table_stim.stim_tuning_message(row) = string(ME.message);
        unit_table_stim.stim_tuning_error_identifier(row) = ...
            string(ME.identifier);
        unit_table_stim.stim_tuning_processed_at(row) = utcNow();
        unit_table_stim.stim_tuning_duration_seconds(row) = toc(rowStart);
        unit_table_stim.stim_tuning_extraction_summary{row} = ...
            makeErrorSummary(ME);
        warning('UnitTableStim:RowFailed', ...
            'Row %d failed: %s', row, ME.message);
        if options.FailFast
            saveState(unit_table_stim, PipelineMetadata, ...
                stateFile, manifestFile);
            rethrow(ME)
        end
    end

    [~, PipelineMetadata] = checkpointIfNeeded( ...
        unit_table_stim, PipelineMetadata, stateFile, manifestFile, ...
        attemptCount, options.CheckpointEvery, false);
end

[SessionManifest, PipelineMetadata] = saveState( ...
    unit_table_stim, PipelineMetadata, stateFile, manifestFile);
printCompletionSummary(unit_table_stim, rows, stateFile);
end


function [Neuro, TrialSummary, ExtractionSummary] = ...
    extractStimWithMemorySafeInput(discovery, options)
% Keep the core extractor unchanged while avoiding large struct loads. A
% v7.3 TrialInfo is compressed on disk but load() reconstructs every field
% at once. Staging only fields used by the tuning and optional eye check
% bounds peak memory without changing trial order or selection indices.
[inputFolder, inputFiles, staging] = prepareStimExtractorInput( ...
    discovery, options.ApplyEyeCheck, options.MaxDirectTrialInfoBytes);
stagingCleanup = onCleanup(@() cleanupStimStaging(staging));

[Neuro, TrialSummary, ExtractionSummary] = ...
    Extract3DMotionStimTuning( ...
    inputFolder, inputFiles, ...
    ApplyEyeCheck=options.ApplyEyeCheck, ...
    MakePlot=false, FigureVisible=false, ...
    EyeCheckChunkSize=options.EyeCheckChunkSize, ...
    ProgressInterval=options.TrialProgressInterval);

if staging.Used
    Neuro.Source.TInfoFile = staging.OriginalTInfoFile;
    Neuro.Source.SelIndexFile = staging.OriginalSelIndexFile;
    ExtractionSummary.TInfoFile = staging.OriginalTInfoFile;
    ExtractionSummary.SelIndexFile = staging.OriginalSelIndexFile;
    audit = struct( ...
        'Used', true, ...
        'OriginalTrialInfoBytes', staging.OriginalTrialInfoBytes, ...
        'ChunkSize', staging.ChunkSize, ...
        'RetainedFields', staging.RetainedFields);
    Neuro.Source.MemorySafeSlimInput = audit;
    ExtractionSummary.MemorySafeSlimInput = audit;
end
clear stagingCleanup
end


function [inputFolder, inputFiles, staging] = ...
    prepareStimExtractorInput(discovery, applyEyeCheck, byteLimit)
inputFolder = string(fileparts(discovery.TInfoFile));
inputFiles = {char(extractFileName(discovery.TInfoFile)), ...
    char(extractFileName(discovery.SelIndexFile))};
staging = struct( ...
    'Used', false, ...
    'CleanupRoot', "", ...
    'OriginalTInfoFile', discovery.TInfoFile, ...
    'OriginalSelIndexFile', discovery.SelIndexFile, ...
    'OriginalTrialInfoBytes', NaN, ...
    'ChunkSize', 64, ...
    'RetainedFields', strings(1, 0));

[isV73, trialInfoBytes] = inspectTrialInfoStorage(discovery.TInfoFile);
staging.OriginalTrialInfoBytes = trialInfoBytes;
if ~isV73 || ~isfinite(trialInfoBytes) || trialInfoBytes < byteLimit
    return
end

fprintf(['  Oversized v7.3 TrialInfo: %.1f MiB uncompressed. ' ...
    'Creating a memory-safe slim input in %d-trial chunks.\n'], ...
    trialInfoBytes / 1024^2, staging.ChunkSize);

cleanupRoot = string(tempname);
[~, sessionFolderName] = fileparts(fileparts(discovery.TInfoFile));
if strlength(sessionFolderName) == 0
    sessionFolderName = "StimSession";
end
temporaryFolder = fullfile(cleanupRoot, sessionFolderName);
try
    mkdir(temporaryFolder);
    [TrialInfo, retainedFields] = streamSlimTrialInfo( ...
        discovery.TInfoFile, applyEyeCheck, staging.ChunkSize);

    sourceVariables = whos('-file', char(discovery.TInfoFile));
    sourceVariableNames = string({sourceVariables.name});
    metadataNames = ["Config", "FName", "PathName"];
    metadataNames = metadataNames(ismember( ...
        metadataNames, sourceVariableNames));
    payload = struct();
    if ~isempty(metadataNames)
        metadataNameCells = cellstr(metadataNames);
        payload = load(char(discovery.TInfoFile), ...
            metadataNameCells{:});
    end
    payload.TrialInfo = TrialInfo;

    temporaryTInfoFile = fullfile(temporaryFolder, ...
        extractFileName(discovery.TInfoFile));
    save(char(temporaryTInfoFile), '-struct', 'payload', '-v7.3');
    temporarySelIndexFile = fullfile(temporaryFolder, ...
        extractFileName(discovery.SelIndexFile));
    [copied, copyMessage] = copyfile( ...
        discovery.SelIndexFile, temporarySelIndexFile);
    if ~copied
        error('UnitTableStim:StagingSelectionCopyFailed', ...
            'Could not stage %s: %s', ...
            discovery.SelIndexFile, copyMessage);
    end

    staging.Used = true;
    staging.CleanupRoot = cleanupRoot;
    staging.RetainedFields = string(retainedFields(:)');
    inputFolder = string(temporaryFolder);
    inputFiles = {char(extractFileName(temporaryTInfoFile)), ...
        char(extractFileName(temporarySelIndexFile))};
catch ME
    cleanupTemporaryRoot(cleanupRoot);
    rethrow(ME)
end
end


function [isV73, trialInfoBytes] = inspectTrialInfoStorage(tInfoFile)
isV73 = isV73MatFile(tInfoFile);
trialInfoBytes = NaN;
if ~isV73
    return
end

try
    source = matfile(char(tInfoFile));
    variables = whos(source);
catch ME
    error('UnitTableStim:TrialInfoMetadataFailed', ...
        'Could not inspect v7.3 source %s: %s', tInfoFile, ME.message);
end
trialVariable = variables(strcmp({variables.name}, 'TrialInfo'));
if isempty(trialVariable)
    return
end
trialInfoBytes = double(trialVariable(1).bytes);
end


function tf = isV73MatFile(filePath)
[fileID, message] = fopen(char(filePath), 'r');
if fileID < 0
    error('UnitTableStim:TInfoHeaderReadFailed', ...
        'Could not open %s: %s', filePath, message);
end
fileCleanup = onCleanup(@() fclose(fileID));
header = fread(fileID, 128, '*char')';
tf = contains(string(header), "MATLAB 7.3 MAT-file");
clear fileCleanup
end


function [TrialInfo, retainedFields] = streamSlimTrialInfo( ...
    tInfoFile, applyEyeCheck, chunkSize)
source = matfile(char(tInfoFile));
trialInfoSize = size(source, 'TrialInfo');
if numel(trialInfoSize) ~= 2 || ...
        ~(trialInfoSize(1) == 1 || trialInfoSize(2) == 1)
    error('UnitTableStim:UnsupportedTrialInfoShape', ...
        'TrialInfo must be a vector; %s contains size %s.', ...
        tInfoFile, mat2str(trialInfoSize));
end
trialCount = prod(trialInfoSize);
if trialCount == 0
    error('UnitTableStim:EmptyTrialInfo', ...
        'TrialInfo is empty: %s', tInfoFile);
end

coreFields = {'EID', 'EventT', 'UnitT'};
desiredFields = coreFields;
if applyEyeCheck
    desiredFields = [desiredFields, ...
        {'AITs', 'LEyeX', 'LEyeY', 'REyeX', 'REyeY', ...
        'OffsetLX', 'OffsetLY', 'OffsetRX', 'OffsetRY', ...
        'StartTimeStamp'}];
end

TrialInfo = struct([]);
retainedFields = cell(0, 1);
template = struct();
for chunkStart = 1:chunkSize:trialCount
    chunkStop = min(chunkStart + chunkSize - 1, trialCount);
    if trialInfoSize(1) == 1
        chunk = source.TrialInfo(1, chunkStart:chunkStop);
    else
        chunk = source.TrialInfo(chunkStart:chunkStop, 1);
    end

    if chunkStart == 1
        availableFields = fieldnames(chunk);
        missingCoreFields = setdiff(coreFields, availableFields, 'stable');
        if ~isempty(missingCoreFields)
            error('UnitTableStim:MissingSlimInputField', ...
                'TrialInfo is missing required field(s): %s', ...
                strjoin(missingCoreFields, ', '));
        end
        retainedFields = desiredFields(ismember( ...
            desiredFields, availableFields));
        emptyValues = repmat({[]}, numel(retainedFields), 1);
        template = cell2struct(emptyValues, retainedFields(:), 1);
        TrialInfo = repmat(template, trialInfoSize);
    end

    droppedFields = setdiff(fieldnames(chunk), ...
        retainedFields, 'stable');
    if ~isempty(droppedFields)
        chunk = rmfield(chunk, droppedFields);
    end
    chunk = orderfields(chunk, template);
    if trialInfoSize(1) == 1
        TrialInfo(1, chunkStart:chunkStop) = chunk;
    else
        TrialInfo(chunkStart:chunkStop, 1) = chunk;
    end
    clear chunk

    if chunkStop == trialCount || mod(ceil(chunkStop / chunkSize), 5) == 0
        fprintf('    Streamed TrialInfo %d/%d\n', chunkStop, trialCount);
    end
end
end


function cleanupStimStaging(staging)
if isstruct(staging) && isfield(staging, 'Used') && staging.Used
    cleanupTemporaryRoot(staging.CleanupRoot);
end
end


function cleanupTemporaryRoot(cleanupRoot)
cleanupRoot = string(cleanupRoot);
if strlength(cleanupRoot) == 0 || ~isfolder(cleanupRoot)
    return
end
normalizedRoot = lower(replace(cleanupRoot, '/', '\'));
normalizedTemp = lower(replace(string(tempdir), '/', '\'));
normalizedTemp = stripTrailingSeparator(normalizedTemp);
if normalizedRoot == normalizedTemp || ...
        ~startsWith(normalizedRoot, normalizedTemp + "\")
    warning('UnitTableStim:UnsafeStagingCleanupSkipped', ...
        'Refused to remove unexpected staging path: %s', cleanupRoot);
    return
end
try
    rmdir(char(cleanupRoot), 's');
catch ME
    warning('UnitTableStim:StagingCleanupFailed', ...
        'Could not remove temporary staging folder %s: %s', ...
        cleanupRoot, ME.message);
end
end


function tableOut = initializeStimColumns(tableIn, schemaVersion)
tableOut = tableIn;
n = height(tableOut);
emptyCells = repmat({[]}, n, 1);
tableOut.stim_tuning_mean_noStim = emptyCells;
tableOut.stim_tuning_SEM_noStim = emptyCells;
tableOut.stim_tuning_mean_stim = emptyCells;
tableOut.stim_tuning_SEM_stim = emptyCells;
tableOut.stim_tuning_mean_merged = emptyCells;
tableOut.stim_tuning_SEM_merged = emptyCells;
tableOut.stim_tuning_n_noStim = emptyCells;
tableOut.stim_tuning_n_stim = emptyCells;
tableOut.stim_tuning_n_merged = emptyCells;
tableOut.stim_tuning_coherence = emptyCells;
tableOut.stim_tuning_condition_names = emptyCells;
tableOut.stim_tuning_channel_map = emptyCells;
tableOut.stim_tuning_num_units = nan(n, 1);
tableOut.stim_tuning_table_unit_index = ones(n, 1);
tableOut.stim_tuning_status = repmat("Pending", n, 1);
tableOut.stim_tuning_message = strings(n, 1);
tableOut.stim_tuning_source_key = strings(n, 1);
tableOut.stim_tuning_tinfo_file = strings(n, 1);
tableOut.stim_tuning_selindex_file = strings(n, 1);
tableOut.stim_tuning_source_signature = strings(n, 1);
tableOut.stim_tuning_trial_FR_file = strings(n, 1);
tableOut.stim_tuning_processed_at = NaT(n, 1, 'TimeZone', 'UTC');
tableOut.stim_tuning_schema_version = repmat(schemaVersion, n, 1);
tableOut.stim_tuning_extraction_summary = emptyCells;
tableOut.stim_tuning_pair_candidate_count = zeros(n, 1);
tableOut.stim_tuning_input_trial_count = nan(n, 1);
tableOut.stim_tuning_selected_trial_count = nan(n, 1);
tableOut.stim_tuning_analyzed_trial_count = nan(n, 1);
tableOut.stim_tuning_included_trial_count = nan(n, 1);
tableOut.stim_tuning_noStim_trial_count = nan(n, 1);
tableOut.stim_tuning_stim_trial_count = nan(n, 1);
tableOut.stim_tuning_excluded_trial_count = nan(n, 1);
tableOut.stim_tuning_eye_check_status = strings(n, 1);
tableOut.stim_tuning_duration_seconds = nan(n, 1);
tableOut.stim_tuning_error_identifier = strings(n, 1);
end


function validateResumeMetadata( ...
    metadata, schemaVersion, inputSignature, analysisSignature)
required = {'SchemaVersion', 'InputTableSignature', 'AnalysisSignature'};
if ~all(isfield(metadata, required))
    error('UnitTableStim:InvalidResumeMetadata', ...
        'Existing output has incomplete pipeline metadata.');
end
if string(metadata.SchemaVersion) ~= schemaVersion
    error('UnitTableStim:ResumeSchemaMismatch', ...
        ['Existing output uses schema %s, but this pipeline uses %s. ' ...
        'Use OverwriteOutput=true or a new output folder.'], ...
        string(metadata.SchemaVersion), schemaVersion);
end
if string(metadata.InputTableSignature) ~= inputSignature
    error('UnitTableStim:ResumeInputMismatch', ...
        ['unit_table_gof has changed since the existing output was ' ...
        'created. Use OverwriteOutput=true or a new output folder.']);
end
if string(metadata.AnalysisSignature) ~= analysisSignature
    error('UnitTableStim:ResumeAnalysisMismatch', ...
        ['The extractor or analysis options differ from the existing ' ...
        'output. Use OverwriteOutput=true or a new output folder.']);
end
end


function signature = makeAnalysisSignature( ...
    schemaVersion, extractorSignature, options)
signature = schemaVersion + "|" + extractorSignature + ...
    "|ApplyEyeCheck=" + string(options.ApplyEyeCheck) + ...
    "|RequireEyeCheck=" + string(options.RequireEyeCheck) + ...
    "|EyeCheckChunkSize=" + string(options.EyeCheckChunkSize) + ...
    "|RecursiveSearch=" + string(options.RecursiveSearch) + ...
    "|DryRun=" + string(options.DryRun) + ...
    "|TableUnitIndex=1|CoherenceGrid=13WithZero";
end


function discovery = resolveStimPair(recordingFolder, recursiveSearch)
discovery = struct('Status', "MissingStimPair", 'Message', "", ...
    'CandidateCount', 0, 'TInfoFile', "", 'SelIndexFile', "");
if strlength(recordingFolder) == 0 || ~isfolder(recordingFolder)
    discovery.Message = "Recording folder does not exist: " + ...
        recordingFolder;
    return
end

topFiles = dir(fullfile(recordingFolder, '*.mat'));
if recursiveSearch
    allFiles = [topFiles; dir(fullfile(recordingFolder, '**', '*.mat'))];
else
    allFiles = topFiles;
end
if isempty(allFiles)
    discovery.Message = "No MAT files under " + recordingFolder;
    return
end
fullPaths = string(fullfile({allFiles.folder}', {allFiles.name}'));
[~, uniqueIndex] = unique(lower(fullPaths), 'stable');
allFiles = allFiles(uniqueIndex);
names = lower(string({allFiles.name}'));
tagMask = contains(names, '3dmotionstim') & contains(names, 'mua');
tInfoIndex = find(tagMask & contains(names, 'tinfo'));
selIndex = find(tagMask & contains(names, 'selindex'));
if isempty(tInfoIndex) || isempty(selIndex)
    discovery.Message = sprintf(['No matched MUA 3DMotionStim TInfo/' ...
        'SelIndex pair under %s (TInfo=%d, SelIndex=%d).'], ...
        recordingFolder, numel(tInfoIndex), numel(selIndex));
    return
end

candidates = struct('TInfoFile', {}, 'SelIndexFile', {}, ...
    'Score', {}, 'Modified', {});
for t = tInfoIndex(:)'
    tFolder = string(allFiles(t).folder);
    tStem = pairStem(allFiles(t).name);
    for s = selIndex(:)'
        if ~strcmpi(allFiles(t).folder, allFiles(s).folder)
            continue
        end
        sStem = pairStem(allFiles(s).name);
        if tStem ~= sStem
            continue
        end
        candidate.TInfoFile = string(fullfile( ...
            allFiles(t).folder, allFiles(t).name));
        candidate.SelIndexFile = string(fullfile( ...
            allFiles(s).folder, allFiles(s).name));
        candidate.Score = scoreStimPair(candidate.TInfoFile, ...
            tFolder, string(recordingFolder), true);
        candidate.Modified = max(allFiles(t).datenum, ...
            allFiles(s).datenum);
        candidates(end + 1) = candidate; %#ok<AGROW>
    end
end

discovery.CandidateCount = numel(candidates);
if isempty(candidates)
    discovery.Message = "Stim TInfo and SelIndex files could not be paired";
    return
end

score = [candidates.Score]';
modified = [candidates.Modified]';
paths = lower(string({candidates.TInfoFile}'));
candidateTable = table((1:numel(candidates))', score, modified, paths, ...
    'VariableNames', {'Index', 'Score', 'Modified', 'Path'});
candidateTable = sortrows(candidateTable, ...
    {'Score', 'Modified', 'Path'}, ["descend", "descend", "ascend"]);
best = candidateTable.Index(1);
if height(candidateTable) > 1 && ...
        candidateTable.Score(1) == candidateTable.Score(2) && ...
        candidateTable.Modified(1) == candidateTable.Modified(2)
    discovery.Status = "AmbiguousStimPair";
    discovery.Message = sprintf(['The top two of %d candidate pairs have ' ...
        'identical score and modification time under %s.'], ...
        numel(candidates), recordingFolder);
    return
end

discovery.Status = "Found";
discovery.TInfoFile = candidates(best).TInfoFile;
discovery.SelIndexFile = candidates(best).SelIndexFile;
if isscalar(candidates)
    discovery.Message = "Unique matched Stim pair";
else
    discovery.Message = sprintf(['Selected the highest-ranked matched ' ...
        'Stim pair from %d candidates.'], numel(candidates));
end
end


function stem = pairStem(fileName)
stem = lower(string(fileName));
stem = regexprep(stem, '[_-]?(tinfo|selindex)\.mat$', '');
end


function score = scoreStimPair(tInfoFile, candidateFolder, rootFolder, exact)
name = lower(extractFileName(tInfoFile));
score = 1000 * exact;
if samePath(candidateFolder, rootFolder)
    score = score + 500;
end
score = score + 100 * contains(name, 'mua');
score = score + 40 * (contains(name, 'mrg') || contains(name, 'merge'));
score = score + 20 * contains(name, 'final');
score = score + 10 * contains(name, 'edit');
depth = count(normalizePath(candidateFolder), filesep) - ...
    count(normalizePath(rootFolder), filesep);
score = score - 5 * max(depth, 0);
end


function tf = samePath(pathA, pathB)
tf = strcmpi(stripTrailingSeparator(normalizePath(pathA)), ...
    stripTrailingSeparator(normalizePath(pathB)));
end


function value = normalizePath(value)
value = replace(string(value), '/', filesep);
value = replace(value, '\', filesep);
end


function value = stripTrailingSeparator(value)
while strlength(value) > 1 && endsWith(value, filesep)
    value = extractBefore(value, strlength(value));
end
end


function value = extractFileName(filePath)
[~, name, extension] = fileparts(filePath);
value = string(name) + string(extension);
end


function sourceKey = makeSourceKey(tInfoFile, selIndexFile)
sourceKey = lower(stripTrailingSeparator(normalizePath(tInfoFile))) + ...
    "||" + lower(stripTrailingSeparator(normalizePath(selIndexFile)));
end


function signature = makeSourceSignature(tInfoFile, selIndexFile)
signature = makeFileSignature(tInfoFile) + "||" + ...
    makeFileSignature(selIndexFile);
end


function signature = makeFileSignature(filePath)
information = dir(filePath);
if isempty(information)
    error('UnitTableStim:MissingSignatureFile', ...
        'Cannot fingerprint missing file: %s', filePath);
end
absolutePath = string(fullfile(information(1).folder, information(1).name));
signature = lower(normalizePath(absolutePath)) + "|" + ...
    string(information(1).bytes) + "|" + ...
    string(compose('%.12f', information(1).datenum));
end


function tf = isReusableRow(tableData, row, sourceSignature)
success = startsWith(tableData.stim_tuning_status(row), "Success");
sameSource = tableData.stim_tuning_source_signature(row) == sourceSignature;
trialFile = tableData.stim_tuning_trial_FR_file(row);
trialFileExists = isfile(trialFile);
curveColumns = resultCellColumns();
curvesPresent = true;
for column = curveColumns
    curvesPresent = curvesPresent && ...
        ~isempty(tableData.(column){row});
end
trialFileValid = false;
if success && sameSource && trialFileExists && curvesPresent
    try
        loaded = load(trialFile, 'StimTrialFR');
        trialFileValid = isfield(loaded, 'StimTrialFR') && ...
            isfield(loaded.StimTrialFR, 'SourceSignature') && ...
            string(loaded.StimTrialFR.SourceSignature) == sourceSignature && ...
            isfield(loaded.StimTrialFR, 'FiringRateHz') && ...
            isfield(loaded.StimTrialFR, 'TrialSummary') && ...
            size(loaded.StimTrialFR.FiringRateHz, 1) == ...
            height(loaded.StimTrialFR.TrialSummary);
    catch
        trialFileValid = false;
    end
end
tf = success && sameSource && trialFileExists && curvesPresent && ...
    trialFileValid;
end


function row = findReusableSourceRow(tableData, currentRow, ...
    sourceKey, sourceSignature)
row = [];
if currentRow <= 1
    return
end
candidates = find(startsWith( ...
    tableData.stim_tuning_status(1:currentRow - 1), "Success") & ...
    tableData.stim_tuning_source_key(1:currentRow - 1) == sourceKey & ...
    tableData.stim_tuning_source_signature(1:currentRow - 1) == ...
    sourceSignature);
for candidate = candidates(:)'
    if isReusableRow(tableData, candidate, sourceSignature)
        row = candidate;
        return
    end
end
end


function tableData = copyStimResults(tableData, sourceRow, targetRow)
cellColumns = [resultCellColumns(), ...
    "stim_tuning_extraction_summary"];
for column = cellColumns
    tableData.(column){targetRow} = tableData.(column){sourceRow};
end
valueColumns = ["stim_tuning_num_units", "stim_tuning_status", ...
    "stim_tuning_source_key", "stim_tuning_tinfo_file", ...
    "stim_tuning_selindex_file", "stim_tuning_source_signature", ...
    "stim_tuning_trial_FR_file", "stim_tuning_schema_version", ...
    "stim_tuning_input_trial_count", ...
    "stim_tuning_selected_trial_count", ...
    "stim_tuning_analyzed_trial_count", ...
    "stim_tuning_included_trial_count", ...
    "stim_tuning_noStim_trial_count", ...
    "stim_tuning_stim_trial_count", ...
    "stim_tuning_excluded_trial_count", ...
    "stim_tuning_eye_check_status"];
for column = valueColumns
    tableData.(column)(targetRow) = tableData.(column)(sourceRow);
end
end


function columns = resultCellColumns()
columns = ["stim_tuning_mean_noStim", "stim_tuning_SEM_noStim", ...
    "stim_tuning_mean_stim", "stim_tuning_SEM_stim", ...
    "stim_tuning_mean_merged", "stim_tuning_SEM_merged", ...
    "stim_tuning_n_noStim", "stim_tuning_n_stim", ...
    "stim_tuning_n_merged", "stim_tuning_coherence", ...
    "stim_tuning_condition_names", "stim_tuning_channel_map"];
end


function tableData = clearRowResults(tableData, row)
for column = resultCellColumns()
    tableData.(column){row} = [];
end
tableData.stim_tuning_extraction_summary{row} = [];
numericColumns = ["stim_tuning_num_units", ...
    "stim_tuning_input_trial_count", ...
    "stim_tuning_selected_trial_count", ...
    "stim_tuning_analyzed_trial_count", ...
    "stim_tuning_included_trial_count", ...
    "stim_tuning_noStim_trial_count", ...
    "stim_tuning_stim_trial_count", ...
    "stim_tuning_excluded_trial_count"];
for column = numericColumns
    tableData.(column)(row) = NaN;
end
tableData.stim_tuning_trial_FR_file(row) = "";
tableData.stim_tuning_eye_check_status(row) = "";
end


function [tableData, recovered] = recoverFromTrialFR( ...
    tableData, row, trialFile, sourceSignature, ...
    applyEyeCheck, requireEyeCheck)
recovered = false;
if ~isfile(trialFile)
    return
end
try
    loaded = load(trialFile, 'StimTrialFR');
    if ~isfield(loaded, 'StimTrialFR')
        return
    end
    trial = loaded.StimTrialFR;
    required = {'SourceSignature', 'FiringRateHz', 'TrialSummary', ...
        'Coherence', 'ConditionNames', 'ChannelMap', 'ExtractionSummary'};
    if ~all(isfield(trial, required)) || ...
            string(trial.SourceSignature) ~= sourceSignature || ...
            size(trial.FiringRateHz, 1) ~= height(trial.TrialSummary)
        return
    end
    expectedChannels = double(tableData.NChannels(row));
    if size(trial.FiringRateHz, 2) ~= expectedChannels
        return
    end

    [noStim, stim, merged] = summarizeTrialFiringRates( ...
        trial.FiringRateHz, trial.TrialSummary, trial.Coherence);
    tableData = clearRowResults(tableData, row);
    tableData.stim_tuning_mean_noStim{row} = noStim.Mean;
    tableData.stim_tuning_SEM_noStim{row} = noStim.SEM;
    tableData.stim_tuning_mean_stim{row} = stim.Mean;
    tableData.stim_tuning_SEM_stim{row} = stim.SEM;
    tableData.stim_tuning_mean_merged{row} = merged.Mean;
    tableData.stim_tuning_SEM_merged{row} = merged.SEM;
    tableData.stim_tuning_n_noStim{row} = noStim.Count;
    tableData.stim_tuning_n_stim{row} = stim.Count;
    tableData.stim_tuning_n_merged{row} = merged.Count;
    tableData.stim_tuning_coherence{row} = double(trial.Coherence(:)');
    tableData.stim_tuning_condition_names{row} = ...
        string(trial.ConditionNames(:)');
    tableData.stim_tuning_channel_map{row} = ...
        double(trial.ChannelMap(:)');
    tableData.stim_tuning_num_units(row) = size(trial.FiringRateHz, 3);
    tableData.stim_tuning_extraction_summary{row} = ...
        trial.ExtractionSummary;
    tableData = assignExtractionCounts( ...
        tableData, row, trial.ExtractionSummary);
    eyeWarning = evaluateEyeCheck( ...
        trial.ExtractionSummary, applyEyeCheck, requireEyeCheck);
    if strlength(eyeWarning) > 0
        tableData.stim_tuning_status(row) = ...
            "SuccessWithEyeCheckWarning";
        tableData.stim_tuning_message(row) = ...
            "Recovered from trial FR; " + eyeWarning;
    else
        tableData.stim_tuning_status(row) = "Success";
        tableData.stim_tuning_message(row) = ...
            "Recovered tuning from an existing atomic trial-FR file";
    end
    tableData.stim_tuning_trial_FR_file(row) = trialFile;
    tableData.stim_tuning_processed_at(row) = utcNow();
    recovered = true;
catch
    recovered = false;
end
end


function [noStim, stim, merged] = summarizeTrialFiringRates( ...
    firingRate, trialSummary, coherence)
noStim = summarizeTrialGroup(firingRate, trialSummary, coherence, false);
stim = summarizeTrialGroup(firingRate, trialSummary, coherence, true);
merged = summarizeTrialGroup(firingRate, trialSummary, coherence, []);
if ~isequal(merged.Count, noStim.Count + stim.Count)
    error('UnitTableStim:RecoveredCountMismatch', ...
        'Recovered merged counts do not equal group counts.');
end
end


function result = summarizeTrialGroup( ...
    firingRate, trialSummary, coherence, electricalStimValue)
cueCount = 4;
coherenceCount = numel(coherence);
channelCount = size(firingRate, 2);
meanFR = nan(cueCount, coherenceCount, channelCount);
semFR = nan(cueCount, coherenceCount, channelCount);
count = zeros(cueCount, coherenceCount);
for cue = 1:cueCount
    for coherenceIndex = 1:coherenceCount
        mask = trialSummary.Included & trialSummary.Condition == cue & ...
            round(trialSummary.Coherence, 2) == ...
            round(coherence(coherenceIndex), 2);
        if ~isempty(electricalStimValue)
            mask = mask & ...
                trialSummary.ElectricalStim == electricalStimValue;
        end
        count(cue, coherenceIndex) = nnz(mask);
        if count(cue, coherenceIndex) == 0
            continue
        end
        values = reshape(firingRate(mask, :, 1), [], channelCount);
        meanFR(cue, coherenceIndex, :) = mean(values, 1, 'omitnan');
        semFR(cue, coherenceIndex, :) = ...
            std(values, 0, 1, 'omitnan') ./ sqrt(count(cue, coherenceIndex));
    end
end
result = struct('Mean', meanFR, 'SEM', semFR, 'Count', count);
end


function [Neuro, summary] = retainExpectedChannels( ...
    Neuro, summary, tableData, row)
% UnitT rows are in acquisition-channel order. Some historical Stim files
% include trailing stimulation-monitor channels after the probe channels.
% NChannels in the authoritative unit table explicitly defines how many
% leading acquisition channels belong to the MUA probe.
originalCount = size(Neuro.TrialFiringRate, 2);
expectedCount = NaN;
if ismember('NChannels', tableData.Properties.VariableNames)
    expectedCount = double(tableData.NChannels(row));
end

if ~isfinite(expectedCount)
    retainedIndices = 1:originalCount;
    rule = "No explicit table NChannels; retained all acquisition rows";
elseif expectedCount < 1 || expectedCount ~= fix(expectedCount)
    error('UnitTableStim:InvalidExpectedChannelCount', ...
        'Table NChannels must be a positive integer; row %d contains %g.', ...
        row, expectedCount);
elseif originalCount < expectedCount
    error('UnitTableStim:TooFewChannels', ...
        'Table expects %d channels, but Stim data has only %d.', ...
        expectedCount, originalCount);
else
    retainedIndices = 1:expectedCount;
    rule = "Retained leading acquisition rows 1:NChannels";
end

if numel(retainedIndices) < originalCount
    Neuro.TrialFiringRate = ...
        Neuro.TrialFiringRate(:, retainedIndices, :);
    Neuro = subsetTopLevelTuning(Neuro, retainedIndices);
    groupNames = {'NoStim', 'Stim', 'Pooled'};
    for groupIndex = 1:numel(groupNames)
        name = groupNames{groupIndex};
        Neuro.(name) = subsetTuningChannels( ...
            Neuro.(name), retainedIndices);
        Neuro.WithZero.(name) = subsetTuningChannels( ...
            Neuro.WithZero.(name), retainedIndices);
    end
    if isfield(Neuro, 'ChannelMap')
        channelMap = double(Neuro.ChannelMap(:)');
        Neuro.ChannelMap = channelMap(ismember(channelMap, retainedIndices));
    end
end

retainedCount = numel(retainedIndices);
droppedIndices = setdiff(1:originalCount, retainedIndices, 'stable');
selection = struct( ...
    'Rule', rule, ...
    'ExpectedChannelCount', expectedCount, ...
    'OriginalChannelCount', originalCount, ...
    'RetainedChannelCount', retainedCount, ...
    'RetainedAcquisitionIndices', retainedIndices, ...
    'DroppedTrailingAcquisitionIndices', droppedIndices, ...
    'Applied', retainedCount < originalCount);
summary.OriginalNumChannels = originalCount;
summary.NumChannels = retainedCount;
summary.ChannelSelection = selection;
Neuro.Source.ChannelSelection = selection;
end


function Neuro = subsetTopLevelTuning(Neuro, retainedIndices)
if isfield(Neuro, 'Means')
    Neuro.Means = Neuro.Means(:, :, retainedIndices, :);
end
if isfield(Neuro, 'SEM')
    Neuro.SEM = Neuro.SEM(:, :, retainedIndices, :);
end
if isfield(Neuro, 'All')
    Neuro.All = Neuro.All(:, :, :, retainedIndices, :);
end
end


function tuning = subsetTuningChannels(tuning, retainedIndices)
tuning.Means = tuning.Means(:, :, retainedIndices, :);
tuning.SEM = tuning.SEM(:, :, retainedIndices, :);
if isfield(tuning, 'All')
    tuning.All = tuning.All(:, :, :, retainedIndices, :);
end
end


function validateExtractedTuning(Neuro, tableData, row)
requiredGroups = {'NoStim', 'Stim', 'Pooled'};
if ~isfield(Neuro, 'WithZero')
    error('UnitTableStim:MissingWithZero', ...
        'Extractor result is missing Neuro.WithZero.');
end
for group = requiredGroups
    if ~isfield(Neuro.WithZero, group{1}) || ...
            ~isfield(Neuro.WithZero.(group{1}), 'Means') || ...
            ~isfield(Neuro.WithZero.(group{1}), 'SEM')
        error('UnitTableStim:MissingTuningGroup', ...
            'Extractor result is missing WithZero.%s Means/SEM.', group{1});
    end
end
expectedCoherence = round( ...
    [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22] ./ 22, 2);
actualCoherence = round(double(Neuro.WithZero.Coherence(:)'), 2);
if ~isequal(actualCoherence, expectedCoherence)
    error('UnitTableStim:UnexpectedCoherenceGrid', ...
        'Expected the canonical 13-bin zero-inclusive coherence grid.');
end
if size(Neuro.WithZero.NoStim.Means, 1) ~= 4 || ...
        size(Neuro.WithZero.NoStim.Means, 2) ~= 13
    error('UnitTableStim:UnexpectedTuningSize', ...
        'Stim tuning must begin with dimensions 4 cues x 13 coherences.');
end
if ismember('NChannels', tableData.Properties.VariableNames)
    expectedChannels = double(tableData.NChannels(row));
    actualChannels = size(Neuro.WithZero.NoStim.Means, 3);
    if isfinite(expectedChannels) && expectedChannels ~= actualChannels
        error('UnitTableStim:ChannelCountMismatch', ...
            'Table expects %d channels, but Stim data has %d.', ...
            expectedChannels, actualChannels);
    end
end
pooledCounts = Neuro.WithZero.Pooled.Trials.NumTrials;
separateCounts = Neuro.WithZero.NoStim.Trials.NumTrials + ...
    Neuro.WithZero.Stim.Trials.NumTrials;
if ~isequal(pooledCounts, separateCounts)
    error('UnitTableStim:PooledCountMismatch', ...
        'Merged counts do not equal NoStim plus Stim counts.');
end

noStimMean = Neuro.WithZero.NoStim.Means;
stimMean = Neuro.WithZero.Stim.Means;
pooledMean = Neuro.WithZero.Pooled.Means;
noStimContribution = noStimMean;
stimContribution = stimMean;
noStimContribution(~isfinite(noStimContribution)) = 0;
stimContribution(~isfinite(stimContribution)) = 0;
noStimN = reshape(Neuro.WithZero.NoStim.Trials.NumTrials, ...
    [4 13 1 1]);
stimN = reshape(Neuro.WithZero.Stim.Trials.NumTrials, [4 13 1 1]);
pooledN = reshape(pooledCounts, [4 13 1 1]);
weightedMean = (noStimContribution .* noStimN + ...
    stimContribution .* stimN) ./ pooledN;
valid = repmat(pooledN > 0, ...
    [1 1 size(pooledMean, 3) size(pooledMean, 4)]);
if any(abs(weightedMean(valid) - pooledMean(valid)) > 1e-10)
    error('UnitTableStim:PooledMeanMismatch', ...
        ['Merged means do not equal the trial-count-weighted NoStim and ' ...
        'Stim means.']);
end
end


function validateTrialFiringRate(Neuro, TrialSummary)
trialFR = Neuro.TrialFiringRate;
if size(trialFR, 1) ~= height(TrialSummary)
    error('UnitTableStim:TrialFRRowMismatch', ...
        'Trial firing-rate rows do not match TrialSummary height.');
end
if size(trialFR, 2) ~= size(Neuro.WithZero.NoStim.Means, 3)
    error('UnitTableStim:TrialFRChannelMismatch', ...
        'Trial firing-rate channels do not match tuning channels.');
end
if size(trialFR, 3) ~= size(Neuro.WithZero.NoStim.Means, 4)
    error('UnitTableStim:TrialFRUnitMismatch', ...
        'Trial firing-rate units do not match tuning units.');
end
end


function warningMessage = evaluateEyeCheck( ...
    summary, requested, required)
warningMessage = "";
if ~requested
    return
end
if isfield(summary, 'EyeCheck') && ...
        isfield(summary.EyeCheck, 'IntentionallySkipped') && ...
        summary.EyeCheck.IntentionallySkipped
    return
end
if ~isfield(summary, 'EyeCheck') || ~summary.EyeCheck.Applied
    if isfield(summary, 'EyeCheck')
        status = string(summary.EyeCheck.Status);
        detail = string(summary.EyeCheck.Message);
    else
        status = "Eye-check status is absent";
        detail = "";
    end
    warningMessage = "Eye check warning: " + status;
    if strlength(detail) > 0
        warningMessage = warningMessage + " (" + detail + ")";
    end
    if required
        error('UnitTableStim:EyeCheckRequired', '%s', warningMessage);
    end
end
end


function tableData = assignTuningResults( ...
    tableData, row, Neuro, summary)
noStim = Neuro.WithZero.NoStim;
stim = Neuro.WithZero.Stim;
merged = Neuro.WithZero.Pooled;
tableData.stim_tuning_mean_noStim{row} = unitOne(noStim.Means);
tableData.stim_tuning_SEM_noStim{row} = unitOne(noStim.SEM);
tableData.stim_tuning_mean_stim{row} = unitOne(stim.Means);
tableData.stim_tuning_SEM_stim{row} = unitOne(stim.SEM);
tableData.stim_tuning_mean_merged{row} = unitOne(merged.Means);
tableData.stim_tuning_SEM_merged{row} = unitOne(merged.SEM);
tableData.stim_tuning_n_noStim{row} = noStim.Trials.NumTrials;
tableData.stim_tuning_n_stim{row} = stim.Trials.NumTrials;
tableData.stim_tuning_n_merged{row} = merged.Trials.NumTrials;
tableData.stim_tuning_coherence{row} = ...
    double(Neuro.WithZero.Coherence(:)');
tableData.stim_tuning_condition_names{row} = ...
    string(Neuro.ConditionNames(:)');
tableData.stim_tuning_channel_map{row} = double(Neuro.ChannelMap(:)');
tableData.stim_tuning_num_units(row) = ...
    size(Neuro.TrialFiringRate, 3);
tableData.stim_tuning_extraction_summary{row} = summary;
tableData = assignExtractionCounts(tableData, row, summary);
end


function tableData = assignExtractionCounts(tableData, row, summary)
tableData.stim_tuning_input_trial_count(row) = summary.InputTrialCount;
tableData.stim_tuning_selected_trial_count(row) = ...
    summary.SelectedTrialCount;
tableData.stim_tuning_analyzed_trial_count(row) = ...
    summary.AnalyzedTrialCount;
tableData.stim_tuning_included_trial_count(row) = ...
    summary.IncludedTrialCount;
tableData.stim_tuning_noStim_trial_count(row) = ...
    summary.NoStimTrialCount;
tableData.stim_tuning_stim_trial_count(row) = summary.StimTrialCount;
tableData.stim_tuning_excluded_trial_count(row) = ...
    summary.ExcludedTrialCount;
if isfield(summary, 'EyeCheck')
    tableData.stim_tuning_eye_check_status(row) = ...
        string(summary.EyeCheck.Status);
end
end


function values = unitOne(values)
if size(values, 4) < 1
    error('UnitTableStim:NoMUAUnit', ...
        'The Stim tuning array has no unit dimension.');
end
values = reshape(values(:, :, :, 1), ...
    [size(values, 1), size(values, 2), size(values, 3)]);
end


function trialPath = makeTrialFRPath(folder, row, monkey, dateValue)
safeMonkey = regexprep(char(monkey), '[^A-Za-z0-9_-]', '_');
dateText = char(string(dateValue, 'yyyyMMdd'));
trialPath = fullfile(folder, sprintf( ...
    'Row%03d_%s_%s_StimTrialFR.mat', row, safeMonkey, dateText));
end


function StimTrialFR = makeTrialFRStruct( ...
    row, tableData, discovery, sourceKey, sourceSignature, ...
    Neuro, TrialSummary, summary, schemaVersion)
StimTrialFR = struct();
StimTrialFR.SchemaVersion = schemaVersion;
StimTrialFR.UnitTableRow = row;
StimTrialFR.Monkey = string(getRowText(tableData.Monkey, row));
StimTrialFR.Date = tableData.Date(row);
StimTrialFR.StimElec = double(tableData.StimElec(row));
StimTrialFR.SourceKey = sourceKey;
StimTrialFR.SourceSignature = sourceSignature;
StimTrialFR.Source = struct( ...
    'TInfoFile', discovery.TInfoFile, ...
    'SelIndexFile', discovery.SelIndexFile, ...
    'ResponseWindow', string(Neuro.Source.ResponseWindow));
StimTrialFR.FiringRateHz = Neuro.TrialFiringRate;
StimTrialFR.TrialSummary = TrialSummary;
StimTrialFR.ChannelMap = double(Neuro.ChannelMap(:)');
StimTrialFR.ConditionNames = string(Neuro.ConditionNames(:)');
StimTrialFR.Coherence = double(Neuro.WithZero.Coherence(:)');
StimTrialFR.ExtractionSummary = summary;
StimTrialFR.CreatedAtUTC = utcNow();
end


function atomicSaveTrialFR(destination, StimTrialFR)
temporary = string(tempname(fileparts(destination))) + ".mat";
cleanup = onCleanup(@() deleteIfPresent(temporary));
save(temporary, 'StimTrialFR', '-v7.3');
[succeeded, message] = movefile(temporary, destination, 'f');
if ~succeeded
    error('UnitTableStim:TrialFRMoveFailed', ...
        'Could not finalize %s: %s', destination, message);
end
clear cleanup
end


function summary = makeErrorSummary(ME)
summary = struct('ErrorIdentifier', string(ME.identifier), ...
    'ErrorMessage', string(ME.message), ...
    'ErrorStack', {ME.stack}, 'RecordedAtUTC', utcNow());
end


function [manifest, metadata] = checkpointIfNeeded( ...
    tableData, metadata, stateFile, manifestFile, attemptCount, ...
    checkpointEvery, force)
if force || mod(attemptCount, checkpointEvery) == 0
    [manifest, metadata] = saveState( ...
        tableData, metadata, stateFile, manifestFile);
else
    manifest = buildManifest(tableData);
end
end


function [SessionManifest, PipelineMetadata] = saveState( ...
    unit_table_stim, PipelineMetadata, stateFile, manifestFile)
PipelineMetadata.LastSavedAtUTC = utcNow();
SessionManifest = buildManifest(unit_table_stim);
temporaryState = string(tempname(fileparts(stateFile))) + ".mat";
temporaryManifest = string(tempname(fileparts(manifestFile))) + ".csv";
stateCleanup = onCleanup(@() deleteIfPresent(temporaryState));
manifestCleanup = onCleanup(@() deleteIfPresent(temporaryManifest));
save(temporaryState, 'unit_table_stim', 'SessionManifest', ...
    'PipelineMetadata', '-v7.3');
writetable(SessionManifest, temporaryManifest);
[stateOK, stateMessage] = movefile(temporaryState, stateFile, 'f');
if ~stateOK
    error('UnitTableStim:StateMoveFailed', ...
        'Could not finalize %s: %s', stateFile, stateMessage);
end
[manifestOK, manifestMessage] = movefile( ...
    temporaryManifest, manifestFile, 'f');
if ~manifestOK
    error('UnitTableStim:ManifestMoveFailed', ...
        'Could not finalize %s: %s', manifestFile, manifestMessage);
end
clear stateCleanup manifestCleanup
end


function manifest = buildManifest(tableData)
row = (1:height(tableData))';
monkey = string(tableData.Monkey);
date = tableData.Date;
stimElec = double(tableData.StimElec);
recordingFolder = string(tableData.Paths);
status = tableData.stim_tuning_status;
message = tableData.stim_tuning_message;
tInfoFile = tableData.stim_tuning_tinfo_file;
selIndexFile = tableData.stim_tuning_selindex_file;
candidateCount = tableData.stim_tuning_pair_candidate_count;
trialFRFile = tableData.stim_tuning_trial_FR_file;
inputTrials = tableData.stim_tuning_input_trial_count;
selectedTrials = tableData.stim_tuning_selected_trial_count;
analyzedTrials = tableData.stim_tuning_analyzed_trial_count;
includedTrials = tableData.stim_tuning_included_trial_count;
noStimTrials = tableData.stim_tuning_noStim_trial_count;
stimTrials = tableData.stim_tuning_stim_trial_count;
excludedTrials = tableData.stim_tuning_excluded_trial_count;
eyeCheckStatus = tableData.stim_tuning_eye_check_status;
numUnits = tableData.stim_tuning_num_units;
processedAtUTC = tableData.stim_tuning_processed_at;
durationSeconds = tableData.stim_tuning_duration_seconds;
errorIdentifier = tableData.stim_tuning_error_identifier;
manifest = table(row, monkey, date, stimElec, recordingFolder, status, ...
    message, tInfoFile, selIndexFile, candidateCount, trialFRFile, ...
    inputTrials, selectedTrials, analyzedTrials, includedTrials, ...
    noStimTrials, stimTrials, excludedTrials, eyeCheckStatus, numUnits, ...
    processedAtUTC, durationSeconds, errorIdentifier, ...
    'VariableNames', {'UnitTableRow', 'Monkey', 'Date', 'StimElec', ...
    'RecordingFolder', 'Status', 'Message', 'TInfoFile', ...
    'SelIndexFile', 'CandidateCount', 'TrialFRFile', 'InputTrials', ...
    'SelectedTrials', 'AnalyzedTrials', 'IncludedTrials', ...
    'NoStimTrials', 'StimTrials', 'ExcludedTrials', ...
    'EyeCheckStatus', 'NumUnits', 'ProcessedAtUTC', ...
    'DurationSeconds', 'ErrorIdentifier'});
end


function printCompletionSummary(tableData, rows, stateFile)
statuses = tableData.stim_tuning_status(rows);
categories = unique(statuses, 'stable');
fprintf('\nStimulation tuning batch summary:\n');
for category = categories(:)'
    fprintf('  %-28s %d\n', category, nnz(statuses == category));
end
fprintf('Saved unit_table_stim: %s\n', stateFile);
end


function value = getRowText(column, row)
if iscell(column)
    value = string(column{row});
else
    value = string(column(row, :));
end
value = strtrim(value(1));
end


function value = utcNow()
value = datetime('now', 'TimeZone', 'UTC');
end


function deleteIfPresent(filePath)
if isfile(filePath)
    delete(filePath);
end
end

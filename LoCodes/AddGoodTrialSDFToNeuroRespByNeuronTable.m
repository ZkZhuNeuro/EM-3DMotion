function NeuroRespByNeuronTable = AddGoodTrialSDFToNeuroRespByNeuronTable(inputTablePath, tempDataPath, outputPath, sourceRows, metadataVar)
%ADDGOODTRIALSDFTONEURORESPBYNEURONTABLE Attach all-good-trial SDF by neuron.
%   NeuroRespByNeuronTable = AddGoodTrialSDFToNeuroRespByNeuronTable()
%   loads C:\LoData\MotionData_ByStim_NeuroResp_ByNeuron.mat, reruns
%   Offline_3DMotion_update for each 3D source recording listed in
%   C:\LoData\TempData.mat/files_3D, extracts raw SDF for all trials that pass
%   the existing analysis filters, and saves a new table to
%   C:\LoData\MotionData_ByStim_NeuroResp_ByNeuron_WithGoodTrialSDF.mat.
%
%   GoodTrialSDF is nGoodTrials x time for the neuron in that table row.
%   GoodTrialInfo is a per-row table with trial labels in matching order.
%
%   AddGoodTrialSDFToNeuroRespByNeuronTable(..., sourceRows) processes only
%   selected source recording rows. This is useful for testing or resuming.

if nargin < 1 || isempty(inputTablePath)
    inputTablePath = 'C:\LoData\MotionData_ByStim_NeuroResp_ByNeuron.mat';
end

if nargin < 2 || isempty(tempDataPath)
    tempDataPath = 'C:\LoData\TempData.mat';
end

if nargin < 3 || isempty(outputPath)
    outputPath = 'C:\LoData\MotionData_ByStim_NeuroResp_ByNeuron_WithGoodTrialSDF.mat';
end

if nargin < 4
    sourceRows = [];
end

if nargin < 5 || isempty(metadataVar)
    metadataVar = 'files_3D';
end

add_dependency_paths();

if isfile(outputPath)
    S = load(outputPath, 'NeuroRespByNeuronTable');
    disp(['Resuming from existing output: ', outputPath])
else
    S = load(inputTablePath, 'NeuroRespByNeuronTable');
end

if ~isfield(S, 'NeuroRespByNeuronTable')
    error('Variable "NeuroRespByNeuronTable" was not found.');
end

NeuroRespByNeuronTable = S.NeuroRespByNeuronTable;
requiredVars = {'SourceRow', 'OriginalNeuronIndex'};
missing = setdiff(requiredVars, NeuroRespByNeuronTable.Properties.VariableNames);
if ~isempty(missing)
    error('Input table is missing required columns: %s. Use the full, not thin, NeuroRespByNeuronTable.', strjoin(missing, ', '));
end

if ~ismember('GoodTrialSDF', NeuroRespByNeuronTable.Properties.VariableNames)
    NeuroRespByNeuronTable.GoodTrialSDF = cell(height(NeuroRespByNeuronTable), 1);
end
if ~ismember('GoodTrialInfo', NeuroRespByNeuronTable.Properties.VariableNames)
    NeuroRespByNeuronTable.GoodTrialInfo = cell(height(NeuroRespByNeuronTable), 1);
end
if ~ismember('GoodTrialSDFSize', NeuroRespByNeuronTable.Properties.VariableNames)
    NeuroRespByNeuronTable.GoodTrialSDFSize = strings(height(NeuroRespByNeuronTable), 1);
end
if ~ismember('GoodTrialSDFSource', NeuroRespByNeuronTable.Properties.VariableNames)
    NeuroRespByNeuronTable.GoodTrialSDFSource = strings(height(NeuroRespByNeuronTable), 1);
end

Temp = load(tempDataPath, metadataVar);
if ~isfield(Temp, metadataVar)
    error('Variable "%s" was not found in %s.', metadataVar, tempDataPath);
end
files = Temp.(metadataVar);

allSourceRows = unique(NeuroRespByNeuronTable.SourceRow);
if isempty(sourceRows)
    sourceRows = allSourceRows(:)';
else
    sourceRows = intersect(sourceRows(:)', allSourceRows(:)', 'stable');
end

startEID = 118;
endEID = 130;

for s = 1:numel(sourceRows)
    sourceRow = sourceRows(s);
    tableRows = find(NeuroRespByNeuronTable.SourceRow == sourceRow);
    sessionName = get_session_name(files, sourceRow);
    sessionsLeft = numel(sourceRows) - s;

    if all(cellfun(@(x) ~isempty(x), NeuroRespByNeuronTable.GoodTrialSDF(tableRows)))
        disp(['Skipping session ', num2str(s), '/', num2str(numel(sourceRows)), ...
            ' | source row ', num2str(sourceRow), ...
            ' | ', sessionName, ...
            ' | sessions left: ', num2str(sessionsLeft), ...
            ' | already filled.'])
        continue
    end

    disp(['Processing session ', num2str(s), '/', num2str(numel(sourceRows)), ...
        ' | source row ', num2str(sourceRow), ...
        ' | ', sessionName, ...
        ' | sessions left after this: ', num2str(sessionsLeft), ...
        ' | neuron rows: ', num2str(numel(tableRows))])
    [AnaData, ~] = Offline_3DMotion_update(files.Paths(sourceRow), files.Names(sourceRow, :), 0, files.Units{sourceRow});
    trialInfo = make_good_trial_info(AnaData);

    for r = transpose(tableRows)
        unitIndex = NeuroRespByNeuronTable.OriginalNeuronIndex(r);
        sdf = extract_unit_sdf(AnaData, unitIndex, startEID, endEID);

        NeuroRespByNeuronTable.GoodTrialSDF{r} = sdf;
        NeuroRespByNeuronTable.GoodTrialInfo{r} = trialInfo;
        NeuroRespByNeuronTable.GoodTrialSDFSize(r) = string(mat2str(size(sdf)));
        NeuroRespByNeuronTable.GoodTrialSDFSource(r) = "Offline_3DMotion_update:good_trials:event118to130";
    end

    save(outputPath, 'NeuroRespByNeuronTable', '-v7.3');
    filledRows = nnz(~cellfun(@isempty, NeuroRespByNeuronTable.GoodTrialSDF));
    disp(['Finished session ', num2str(s), '/', num2str(numel(sourceRows)), ...
        ' | ', sessionName, ...
        ' | total neuron rows filled: ', num2str(filledRows), '/', num2str(height(NeuroRespByNeuronTable))])
end

save(outputPath, 'NeuroRespByNeuronTable', '-v7.3');
disp(['Saved table with good-trial SDF to ', outputPath])
end

function add_dependency_paths()
localRoot = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\LoCodes';
offlineRoot = 'P:\Codes\Matlab\offlineAnalysis';

if isfolder(localRoot)
    addpath(localRoot, '-begin');
end
if isfolder(offlineRoot)
    addpath(genpath(offlineRoot));
end
end

function sessionName = get_session_name(files, sourceRow)
sessionName = "";
if ismember('Names', files.Properties.VariableNames)
    names = files.Names(sourceRow, :);
    if iscell(names)
        sessionName = string(names{1});
    else
        sessionName = string(names(1));
    end
end
if strlength(sessionName) == 0
    sessionName = "source row " + string(sourceRow);
end
end

function sdf = extract_unit_sdf(AnaData, unitIndex, startEID, endEID)
nTrials = numel(AnaData);
startIdx = nan(nTrials, 1);
endIdx = nan(nTrials, 1);
vectorLengths = nan(nTrials, 1);

for trialNum = 1:nTrials
    trialEnd = min(AnaData(trialNum).EventT(AnaData(trialNum).EID == 112));
    tStart = AnaData(trialNum).EventT(AnaData(trialNum).EID == startEID & AnaData(trialNum).EventT < trialEnd);
    tEnd = AnaData(trialNum).EventT(AnaData(trialNum).EID == endEID);
    tEnd = tEnd(tEnd < trialEnd);

    if isempty(tStart) || isempty(tEnd)
        continue
    end

    tStart = tStart(1);
    tEnd = tEnd(1);
    startIdx(trialNum) = round((tStart - AnaData(trialNum).StartTimeStamp) * 1000);
    endIdx(trialNum) = round((tEnd - AnaData(trialNum).StartTimeStamp) * 1000);
    vectorLengths(trialNum) = endIdx(trialNum) - startIdx(trialNum) + 1;
end

maxLen = max(vectorLengths, [], 'omitnan');
if isempty(maxLen) || isnan(maxLen)
    sdf = nan(nTrials, 0);
    return
end

sdf = nan(nTrials, maxLen);
for trialNum = 1:nTrials
    if isnan(vectorLengths(trialNum))
        continue
    end
    sdf(trialNum, 1:vectorLengths(trialNum)) = ...
        AnaData(trialNum).UnitSDF(1, unitIndex, startIdx(trialNum):endIdx(trialNum));
end
end

function T = make_good_trial_info(AnaData)
nTrials = numel(AnaData);
TrialIndex = transpose(1:nTrials);
Condition = nan(nTrials, 1);
ConditionNum = nan(nTrials, 1);
Coherence = nan(nTrials, 1);
CoherenceNum = nan(nTrials, 1);
Direction = nan(nTrials, 1);
Response = nan(nTrials, 1);
Choice = strings(nTrials, 1);
Block = nan(nTrials, 1);
RawFR = cell(nTrials, 1);

for trialNum = 1:nTrials
    Condition(trialNum) = get_numeric_field(AnaData, trialNum, 'Condition');
    ConditionNum(trialNum) = get_numeric_field(AnaData, trialNum, 'ConditionNum');
    Coherence(trialNum) = get_numeric_field(AnaData, trialNum, 'Coherence');
    CoherenceNum(trialNum) = get_numeric_field(AnaData, trialNum, 'CoherenceNum');
    Direction(trialNum) = get_numeric_field(AnaData, trialNum, 'Direction');
    Response(trialNum) = get_numeric_field(AnaData, trialNum, 'Response');
    Block(trialNum) = get_numeric_field(AnaData, trialNum, 'Block');

    if isfield(AnaData, 'Choice') && ~isempty(AnaData(trialNum).Choice)
        Choice(trialNum) = string(AnaData(trialNum).Choice);
    end
    if isfield(AnaData, 'RawFR')
        RawFR{trialNum} = AnaData(trialNum).RawFR;
    end
end

T = table(TrialIndex, Condition, ConditionNum, Coherence, CoherenceNum, ...
    Direction, Response, Choice, Block, RawFR);
end

function value = get_numeric_field(S, idx, fieldName)
value = nan;
if isfield(S, fieldName) && ~isempty(S(idx).(fieldName))
    tmp = S(idx).(fieldName);
    if isnumeric(tmp) || islogical(tmp)
        value = double(tmp(1));
    end
end
end

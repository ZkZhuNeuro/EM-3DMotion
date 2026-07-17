function NeuroRespByNeuronTable = KeepGoodTrialSDFLength1000(inputPath, outputPath, targetLen)
%KEEPGOODTRIALSDFLENGTH1000 Keep neurons with >=1000 SDF bins and trim to 1000.
%   NeuroRespByNeuronTable = KeepGoodTrialSDFLength1000()
%   loads the GoodTrialSDF table, removes neuron rows whose GoodTrialSDF has
%   fewer than targetLen time bins, trims longer SDF matrices to targetLen
%   columns, updates GoodTrialSDFSize, and saves a new MAT file.

if nargin < 1 || isempty(inputPath)
    inputPath = 'C:\LoData\MotionData_ByStim_NeuroResp_ByNeuron_WithGoodTrialSDF.mat';
end

if nargin < 2 || isempty(outputPath)
    outputPath = 'C:\LoData\MotionData_ByStim_NeuroResp_ByNeuron_WithGoodTrialSDF_1000ms.mat';
end

if nargin < 3 || isempty(targetLen)
    targetLen = 1000;
end

if ~isfile(inputPath)
    error('Input file not found: %s', inputPath);
end

fprintf('Loading %s\n', inputPath);
S = load(inputPath, 'NeuroRespByNeuronTable');
if ~isfield(S, 'NeuroRespByNeuronTable')
    error('Variable "NeuroRespByNeuronTable" was not found in %s.', inputPath);
end

T = S.NeuroRespByNeuronTable;
if ~ismember('GoodTrialSDF', T.Properties.VariableNames)
    error('Table does not contain GoodTrialSDF.');
end

nRowsBefore = height(T);
sdfSizes = cell(nRowsBefore, 2);
for r = 1:nRowsBefore
    if isempty(T.GoodTrialSDF{r})
        sdfSizes{r, 1} = 0;
        sdfSizes{r, 2} = 0;
    else
        sz = size(T.GoodTrialSDF{r});
        sdfSizes{r, 1} = sz(1);
        sdfSizes{r, 2} = sz(2);
    end
end

nTrials = cell2mat(sdfSizes(:, 1));
nTime = cell2mat(sdfSizes(:, 2));
keepRow = nTime >= targetLen;
trimRow = nTime > targetLen;
dropRow = ~keepRow;

fprintf('Rows before: %d\n', nRowsBefore);
fprintf('Rows dropped because SDF length < %d: %d\n', targetLen, nnz(dropRow));
fprintf('Rows trimmed because SDF length > %d: %d\n', targetLen, nnz(trimRow));
fprintf('Rows already exactly %d: %d\n', targetLen, nnz(nTime == targetLen));

originalSize = strings(nRowsBefore, 1);
for r = 1:nRowsBefore
    originalSize(r) = string(mat2str([nTrials(r), nTime(r)]));
end

T.GoodTrialSDFOriginalSize = originalSize;
T = T(keepRow, :);

for r = 1:height(T)
    T.GoodTrialSDF{r} = T.GoodTrialSDF{r}(:, 1:targetLen);
end

if ismember('GoodTrialSDFSize', T.Properties.VariableNames)
    T.GoodTrialSDFSize = strings(height(T), 1);
    for r = 1:height(T)
        T.GoodTrialSDFSize(r) = string(mat2str(size(T.GoodTrialSDF{r})));
    end
end

if ismember('GoodTrialSDFSource', T.Properties.VariableNames)
    T.GoodTrialSDFSource = string(T.GoodTrialSDFSource) + ";time_trimmed_to_" + string(targetLen);
end

NeuroRespByNeuronTable = T;
outputDir = fileparts(outputPath);
if ~isempty(outputDir) && ~isfolder(outputDir)
    mkdir(outputDir);
end

fprintf('Saving %d rows to %s\n', height(NeuroRespByNeuronTable), outputPath);
save(outputPath, 'NeuroRespByNeuronTable', '-v7.3');

summaryPath = replace(outputPath, '.mat', '_summary.txt');
fid = fopen(summaryPath, 'w');
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, 'Input: %s\n', inputPath);
fprintf(fid, 'Output: %s\n', outputPath);
fprintf(fid, 'Target SDF time length: %d\n', targetLen);
fprintf(fid, 'Rows before: %d\n', nRowsBefore);
fprintf(fid, 'Rows after: %d\n', height(NeuroRespByNeuronTable));
fprintf(fid, 'Rows dropped because SDF length < %d: %d\n', targetLen, nnz(dropRow));
fprintf(fid, 'Rows trimmed because SDF length > %d: %d\n', targetLen, nnz(trimRow));
fprintf(fid, 'Rows already exactly %d: %d\n', targetLen, nnz(nTime == targetLen));
fprintf(fid, 'Original SDF time lengths among non-empty rows:\n');
uLen = unique(nTime(nTime > 0));
for ii = 1:numel(uLen)
    fprintf(fid, '  %d: %d rows\n', uLen(ii), nnz(nTime == uLen(ii)));
end

fprintf('Summary saved to %s\n', summaryPath);
end

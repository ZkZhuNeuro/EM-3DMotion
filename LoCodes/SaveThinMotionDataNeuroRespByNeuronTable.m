function NeuroRespByNeuronTable = SaveThinMotionDataNeuroRespByNeuronTable(inputPath, outputPath)
%SAVETHINMOTIONDATANEURORESPBYNEURONTABLE Remove bookkeeping columns.
%   Loads NeuroRespByNeuronTable from the neuron-level MotionData file,
%   removes bookkeeping columns, and saves a thinner table.

if nargin < 1 || isempty(inputPath)
    inputPath = 'C:\LoData\MotionData_ByStim_NeuroResp_ByNeuron.mat';
end

if nargin < 2 || isempty(outputPath)
    outputPath = 'C:\LoData\MotionData_ByStim_NeuroResp_ByNeuron_Thin.mat';
end

if ~isfile(inputPath)
    error('Input file not found: %s', inputPath);
end

S = load(inputPath, 'NeuroRespByNeuronTable');
if ~isfield(S, 'NeuroRespByNeuronTable')
    error('Variable "NeuroRespByNeuronTable" was not found in %s.', inputPath);
end

NeuroRespByNeuronTable = S.NeuroRespByNeuronTable;

columnsToRemove = { ...
    'SourceRow', ...
    'Name', ...
    'StimLoc', ...
    'OriginalNeuronIndex', ...
    'OriginalRepeatCount', ...
    'KeptRepeatCount', ...
    'MetadataUnits', ...
    'NeuroRespSize'};

presentColumns = intersect(columnsToRemove, NeuroRespByNeuronTable.Properties.VariableNames, 'stable');
NeuroRespByNeuronTable(:, presentColumns) = [];

outputDir = fileparts(outputPath);
if ~isempty(outputDir) && ~isfolder(outputDir)
    mkdir(outputDir);
end

save(outputPath, 'NeuroRespByNeuronTable', '-v7.3');
disp(['Saved thin table with ', num2str(height(NeuroRespByNeuronTable)), ...
    ' rows and ', num2str(width(NeuroRespByNeuronTable)), ...
    ' columns to ', outputPath])
end

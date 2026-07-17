function NeuroRespByNeuronTable = SaveMotionDataNeuroRespByNeuronTable(inputPath, tempDataPath, outputPath, neuroRespPath)
%SAVEMOTIONDATANEURORESPBYNEURONTABLE Split MotionData_ByStim NeuroResp by neuron.
%   NeuroRespByNeuronTable = SaveMotionDataNeuroRespByNeuronTable()
%   reads C:\LoData\MotionData_ByStim.mat and C:\LoData\TempData.mat,
%   splits each tetrode-level NeuroResp array into one row per neuron,
%   skips the first MUA/noise entry, keeps conditions 1:4 and all 13
%   coherence levels, removes trailing all-NaN repeats, and saves the
%   result to C:\LoData\MotionData_ByStim_NeuroResp_ByNeuron.mat.

if nargin < 1 || isempty(inputPath)
    inputPath = 'C:\LoData\MotionData_ByStim.mat';
end

if nargin < 2 || isempty(tempDataPath)
    tempDataPath = 'C:\LoData\TempData.mat';
end

if nargin < 3 || isempty(outputPath)
    outputPath = 'C:\LoData\MotionData_ByStim_NeuroResp_ByNeuron.mat';
end

if nargin < 4
    neuroRespPath = 'C:\LoData\NeuroResp.mat';
end

metadataVar = 'files';

if ~isfile(inputPath)
    error('Input file not found: %s', inputPath);
end

if ~isfile(tempDataPath)
    error('TempData file not found: %s', tempDataPath);
end

disp(['Input MotionData file: ', inputPath])
disp(['Input metadata file: ', tempDataPath])
if ~isempty(neuroRespPath) && isfile(neuroRespPath)
    disp(['Input NeuroResp-only file: ', neuroRespPath])
end
disp(['Output file: ', outputPath])

metadata = load_metadata_table(tempDataPath, metadataVar);
NeuroRespSource = load_neuroresp_source(inputPath, neuroRespPath);
nTetrodes = numel(NeuroRespSource);

if height(metadata) ~= nTetrodes
    error('%s has %d rows, but %s has %d elements.', ...
        metadataVar, height(metadata), 'NeuroResp source', nTetrodes);
end

SourceRow = zeros(0, 1);
Name = strings(0, 1);
ROI = strings(0, 1);
StimLoc = zeros(0, 2);
Monkey = strings(0, 1);
TT = zeros(0, 1);
Unit = zeros(0, 1);
OriginalNeuronIndex = zeros(0, 1);
OriginalRepeatCount = zeros(0, 1);
KeptRepeatCount = zeros(0, 1);
MetadataUnits = cell(0, 1);
UnitSource = strings(0, 1);
NeuroResp = cell(0, 1);
NeuroRespSize = strings(0, 1);

rowOut = 0;
for tetrodeRow = 1:nTetrodes
    resp = NeuroRespSource{tetrodeRow};
    validate_neuroresp(resp, tetrodeRow);

    nNeurons = size(resp, 1);
    neuronIndices = 2:nNeurons;
    units = metadata.Units{tetrodeRow};
    units = units(:);
    [rowUnits, unitSource] = resolve_unit_numbers(units, neuronIndices, tetrodeRow);

    for neuronNum = 1:numel(neuronIndices)
        neuronIndex = neuronIndices(neuronNum);
        unitResp = reshape(resp(neuronIndex, 1:4, :, :), [4, 13, size(resp, 4)]);
        unitResp = keep_nonempty_repeats(unitResp);

        rowOut = rowOut + 1;
        SourceRow(rowOut, 1) = tetrodeRow; %#ok<AGROW>
        Name(rowOut, 1) = string(metadata.Names{tetrodeRow, 1}); %#ok<AGROW>
        ROI(rowOut, 1) = string(metadata.ROI{tetrodeRow}); %#ok<AGROW>
        StimLoc(rowOut, :) = normalize_stimloc(metadata.StimLoc(tetrodeRow, :)); %#ok<AGROW>
        Monkey(rowOut, 1) = monkey_from_name(Name(rowOut)); %#ok<AGROW>
        TT(rowOut, 1) = metadata.Tetrode(tetrodeRow); %#ok<AGROW>
        Unit(rowOut, 1) = rowUnits(neuronNum); %#ok<AGROW>
        OriginalNeuronIndex(rowOut, 1) = neuronIndex; %#ok<AGROW>
        OriginalRepeatCount(rowOut, 1) = size(resp, 4); %#ok<AGROW>
        KeptRepeatCount(rowOut, 1) = size(unitResp, 3); %#ok<AGROW>
        MetadataUnits{rowOut, 1} = units'; %#ok<AGROW>
        UnitSource(rowOut, 1) = unitSource; %#ok<AGROW>
        NeuroResp{rowOut, 1} = unitResp; %#ok<AGROW>
        NeuroRespSize(rowOut, 1) = string(mat2str(size(unitResp))); %#ok<AGROW>
    end

    if mod(tetrodeRow, 25) == 0 || tetrodeRow == nTetrodes
        disp(['Processed tetrode row ', num2str(tetrodeRow), '/', num2str(nTetrodes), ...
            '; output neurons so far: ', num2str(rowOut)])
    end
end

NeuroRespByNeuronTable = table( ...
    SourceRow, Name, ROI, StimLoc, Monkey, TT, Unit, OriginalNeuronIndex, ...
    OriginalRepeatCount, KeptRepeatCount, MetadataUnits, UnitSource, NeuroResp, NeuroRespSize);

validate_output_table(NeuroRespByNeuronTable);

outputDir = fileparts(outputPath);
if ~isempty(outputDir) && ~isfolder(outputDir)
    mkdir(outputDir);
end

save(outputPath, 'NeuroRespByNeuronTable', '-v7.3');
disp(['Saved ', num2str(height(NeuroRespByNeuronTable)), ...
    ' neuron rows to ', outputPath])
end

function NeuroRespSource = load_neuroresp_source(inputPath, neuroRespPath)
if ~isempty(neuroRespPath) && isfile(neuroRespPath)
    S = load(neuroRespPath, 'NeuroResp');
    if isfield(S, 'NeuroResp') && iscell(S.NeuroResp)
        NeuroRespSource = S.NeuroResp;
        return
    end
end

inputVar = 'MotionData_ByStim';
info = whos('-file', inputPath, inputVar);
if isempty(info)
    error('Variable "%s" was not found in %s.', inputVar, inputPath);
end

mf = matfile(inputPath);
nTetrodes = prod(info.size);
NeuroRespSource = cell(1, nTetrodes);
for i = 1:nTetrodes
    record = mf.(inputVar)(1, i);
    if ~isfield(record, 'NeuroResp')
        error('MotionData_ByStim element %d does not contain NeuroResp.', i);
    end
    NeuroRespSource{i} = record.NeuroResp;
end
end

function metadata = load_metadata_table(tempDataPath, metadataVar)
S = load(tempDataPath, metadataVar);
if ~isfield(S, metadataVar)
    error('Variable "%s" was not found in %s.', metadataVar, tempDataPath);
end
metadata = S.(metadataVar);
requiredVars = {'Names', 'ROI', 'StimLoc', 'Tetrode', 'Units'};
missing = setdiff(requiredVars, metadata.Properties.VariableNames);
if ~isempty(missing)
    error('%s is missing required columns: %s', metadataVar, strjoin(missing, ', '));
end
end

function [rowUnits, unitSource] = resolve_unit_numbers(units, neuronIndices, tetrodeRow)
if numel(units) == numel(neuronIndices)
    rowUnits = units;
    unitSource = "files.Units";
else
    rowUnits = neuronIndices(:);
    unitSource = "NeuroRespIndex";
    warning(['Unit count mismatch at MotionData_ByStim row %d: ', ...
        'files.Units has %d units, but NeuroResp has %d non-MUA neurons. ', ...
        'Using NeuroResp neuron indices as Unit values for this row.'], ...
        tetrodeRow, numel(units), numel(neuronIndices));
end
end

function validate_neuroresp(resp, tetrodeRow)
if ~isnumeric(resp) || ndims(resp) ~= 4
    error('Row %d NeuroResp must be a 4-D numeric matrix.', tetrodeRow);
end
if size(resp, 1) < 2
    error('Row %d NeuroResp has no neuron rows after the MUA/noise row.', tetrodeRow);
end
if size(resp, 2) < 4
    error('Row %d NeuroResp has only %d conditions; expected at least 4.', tetrodeRow, size(resp, 2));
end
if size(resp, 3) ~= 13
    error('Row %d NeuroResp has %d coherence levels; expected 13.', tetrodeRow, size(resp, 3));
end
end

function unitResp = keep_nonempty_repeats(unitResp)
emptyRepeats = squeeze(all(all(isnan(unitResp), 1), 2));
if isrow(emptyRepeats)
    emptyRepeats = emptyRepeats';
end
unitResp = unitResp(:, :, ~emptyRepeats);
end

function stimLoc = normalize_stimloc(value)
if iscell(value)
    value = value{1};
end
stimLoc = nan(1, 2);
value = double(value);
stimLoc(1:min(2, numel(value))) = value(1:min(2, numel(value)));
end

function monkey = monkey_from_name(name)
name = string(name);
if contains(name, "Jim", 'IgnoreCase', true)
    monkey = "Jim";
elseif contains(name, "Clay", 'IgnoreCase', true)
    monkey = "Clay";
else
    monkey = missing;
end
end

function validate_output_table(T)
for i = 1:height(T)
    resp = T.NeuroResp{i};
    if ~isequal(size(resp, 1), 4) || ~isequal(size(resp, 2), 13)
        error('Output row %d NeuroResp is %s, expected 4x13xD.', i, mat2str(size(resp)));
    end
    if size(resp, 3) > 0 && any(squeeze(all(all(isnan(resp), 1), 2)))
        error('Output row %d still contains an all-NaN repeat.', i);
    end
end
end

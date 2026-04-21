function NeuroRespTable = SaveMotionDataNeuroRespTable(inputSource, outputPath, varName)
%SAVEMOTIONDATANEURORESPTABLE Save MotionData_ByStim.NeuroResp as a table.
%   NeuroRespTable = SaveMotionDataNeuroRespTable(MotionData_ByStim)
%   extracts the NeuroResp field from a loaded MotionData_ByStim struct
%   array, stores it as a table with one row per struct element, and saves
%   it to C:\LoData\MotionData_ByStim_NeuroRespTable.mat.
%
%   NeuroRespTable = SaveMotionDataNeuroRespTable(inputMatPath)
%   loads MotionData_ByStim from the MAT file at inputMatPath and does the
%   same. The function first tries element-wise access via MATFILE and
%   falls back to LOAD if needed.
%
%   NeuroRespTable = SaveMotionDataNeuroRespTable(inputSource, outputPath)
%   saves the table to a custom output path.
%
%   NeuroRespTable = SaveMotionDataNeuroRespTable(inputSource, outputPath, varName)
%   uses a custom variable name instead of MotionData_ByStim.

if nargin < 3 || isempty(varName)
    varName = 'MotionData_ByStim';
end

if nargin < 2 || isempty(outputPath)
    outputPath = 'C:\LoData\MotionData_ByStim_NeuroRespTable.mat';
end

if ischar(inputSource) || isstring(inputSource)
    inputPath = char(inputSource);
    if ~isfile(inputPath)
        error('Input file not found: %s', inputPath);
    end
    data = load_neuroresp_only(inputPath, varName);
else
    data = inputSource;
end

if ~isstruct(data)
    error('%s must be a struct array.', varName);
end

nRows = numel(data);
rowIndex = transpose(1:nRows);
NeuroResp = cell(nRows, 1);
NeuroRespSize = strings(nRows, 1);

for i = 1:nRows
    if ~isfield(data(i), 'NeuroResp')
        error('Element %d does not contain a NeuroResp field.', i);
    end
    NeuroResp{i} = data(i).NeuroResp;
    NeuroRespSize(i) = string(mat2str(size(data(i).NeuroResp)));
end

NeuroRespTable = table(rowIndex, NeuroResp, NeuroRespSize, ...
    'VariableNames', {'Row', 'NeuroResp', 'NeuroRespSize'});

outputDir = fileparts(outputPath);
if ~isempty(outputDir) && ~isfolder(outputDir)
    mkdir(outputDir);
end

save(outputPath, 'NeuroRespTable', '-v7.3');
disp(['Saved NeuroResp table to ', outputPath]);
end

function data = load_neuroresp_only(inputPath, varName)
data = try_load_with_matfile(inputPath, varName);
if isempty(data)
    S = load(inputPath, varName);
    if ~isfield(S, varName)
        error('Variable "%s" was not found in %s.', varName, inputPath);
    end
    data = S.(varName);
end
end

function data = try_load_with_matfile(inputPath, varName)
data = [];

try
    info = whos('-file', inputPath, varName);
    if isempty(info)
        return
    end

    mf = matfile(inputPath);
    nRows = prod(info.size);
    data(1, nRows) = struct('NeuroResp', []); %#ok<AGROW>

    for i = 1:nRows
        tmp = mf.(varName)(1, i);
        if ~isfield(tmp, 'NeuroResp')
            data = [];
            return
        end
        data(i).NeuroResp = tmp.NeuroResp; %#ok<AGROW>
    end
catch
    data = [];
end
end

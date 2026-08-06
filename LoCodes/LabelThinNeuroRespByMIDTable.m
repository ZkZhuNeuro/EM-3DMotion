function NeuroRespByNeuronTable = LabelThinNeuroRespByMIDTable(fullTablePath, thinTablePath, tempDataPath, outputPath)
%LABELTHINNEURORESPBYMIDTABLE Label rows using the paper's 2D/3D criteria.
%   NeuroRespByNeuronTable = LabelThinNeuroRespByMIDTable()
%   loads the full and thin MotionData_ByStim_NeuroResp_ByNeuron tables,
%   loads only MIDTable from C:\LoData\TempData.mat, matches neurons by
%   Date, ROI, Tetrode/TT, and Unit, then adds NeuroType to the thin table.
%   Paper-included neurons (significant direction tuning for Combined,
%   MonoL, and MonoR) are labeled from Z_quad as "2D", "3D", or
%   "unclassified". Neurons classified as 2D that have significant MonoL
%   and MonoR tuning but not Combined tuning are labeled "2Donly". All
%   remaining rows, including rows not matched to MIDTable, are labeled
%   "unincluded". The table also includes Monocularity_3D_Max and an
%   anatomical dominant-eye label, OD_3D_Max_Eye. Because the source OD
%   sign is contralateral-positive, positive values mean left-eye dominance
%   for Jim and right-eye dominance for Clay.

if nargin < 1 || isempty(fullTablePath)
    fullTablePath = 'C:\LoData\MotionData_ByStim_NeuroResp_ByNeuron.mat';
end

if nargin < 2 || isempty(thinTablePath)
    thinTablePath = 'C:\LoData\MotionData_ByStim_NeuroResp_ByNeuron_Thin.mat';
end

if nargin < 3 || isempty(tempDataPath)
    tempDataPath = 'C:\LoData\TempData.mat';
end

if nargin < 4 || isempty(outputPath)
    outputPath = thinTablePath;
end

fullData = load(fullTablePath, 'NeuroRespByNeuronTable');
thinData = load(thinTablePath, 'NeuroRespByNeuronTable');
tempData = load(tempDataPath, 'MIDTable');

FullTable = fullData.NeuroRespByNeuronTable;
NeuroRespByNeuronTable = thinData.NeuroRespByNeuronTable;
MIDTable = tempData.MIDTable;

if height(FullTable) ~= height(NeuroRespByNeuronTable)
    error('Full table and thin table row counts differ: %d vs %d.', ...
        height(FullTable), height(NeuroRespByNeuronTable));
end

requiredFullVars = {'Name', 'ROI', 'TT', 'Unit'};
missingFullVars = setdiff(requiredFullVars, FullTable.Properties.VariableNames);
if ~isempty(missingFullVars)
    error('Full table is missing required columns: %s', strjoin(missingFullVars, ', '));
end

requiredMIDVars = {'Date', 'ROI', 'Tetrode', 'Unit', ...
    'sig_Anova2_Combined', 'sig_Anova2_MonoL', 'sig_Anova2_MonoR', ...
    'Z_quad', 'Monkey', 'Monocularity_3D_Max'};
missingMIDVars = setdiff(requiredMIDVars, MIDTable.Properties.VariableNames);
if ~isempty(missingMIDVars)
    error('MIDTable is missing required columns: %s', strjoin(missingMIDVars, ', '));
end

scoreVar = find_2d3d_score_variable(MIDTable);

fullDate = parse_dates_from_names(FullTable.Name);
midDate = date_to_day_number(MIDTable.Date);

midKeys = make_keys(midDate, MIDTable.ROI, MIDTable.Tetrode, MIDTable.Unit);
fullKeys = make_keys(fullDate, FullTable.ROI, FullTable.TT, FullTable.Unit);

[identified, midRow] = ismember(fullKeys, midKeys);

neuroType = strings(height(NeuroRespByNeuronTable), 1);
neuroType(:) = "unincluded";
score = nan(height(NeuroRespByNeuronTable), 1);
monocularity3DMax = nan(height(NeuroRespByNeuronTable), 1);
odEye = strings(height(NeuroRespByNeuronTable), 1);
odEye(:) = "unknown";

matchedRows = find(identified);
matchedMIDRows = midRow(matchedRows);
score(matchedRows) = MIDTable.(scoreVar)(matchedMIDRows);
monocularity3DMax(matchedRows) = MIDTable.Monocularity_3D_Max(matchedMIDRows);

combinedTuned = MIDTable.sig_Anova2_Combined(matchedMIDRows);
leftTuned = MIDTable.sig_Anova2_MonoL(matchedMIDRows);
rightTuned = MIDTable.sig_Anova2_MonoR(matchedMIDRows);
zQuad = MIDTable.Z_quad(matchedMIDRows);

paperIncluded = combinedTuned & leftTuned & rightTuned;
neuroType(matchedRows(paperIncluded & zQuad == 4)) = "2D";
neuroType(matchedRows(paperIncluded & zQuad == 2)) = "3D";
neuroType(matchedRows(paperIncluded & zQuad == 1)) = "unclassified";

twoDOnly = ~combinedTuned & leftTuned & rightTuned & zQuad == 4;
neuroType(matchedRows(twoDOnly)) = "2Donly";

matchedMonkey = string(MIDTable.Monkey(matchedMIDRows));
matchedOD = monocularity3DMax(matchedRows);
validOD = isfinite(matchedOD);
odEye(matchedRows(validOD & matchedOD == 0)) = "equal";
odEye(matchedRows(validOD & matchedMonkey == "Jim" & matchedOD > 0)) = "Left";
odEye(matchedRows(validOD & matchedMonkey == "Jim" & matchedOD < 0)) = "Right";
odEye(matchedRows(validOD & matchedMonkey == "Clay" & matchedOD > 0)) = "Right";
odEye(matchedRows(validOD & matchedMonkey == "Clay" & matchedOD < 0)) = "Left";

if ismember('Identified3D2D', NeuroRespByNeuronTable.Properties.VariableNames)
    NeuroRespByNeuronTable.Identified3D2D = [];
end
if ismember('Z3D_v_Z2D', NeuroRespByNeuronTable.Properties.VariableNames)
    NeuroRespByNeuronTable.Z3D_v_Z2D = [];
end
if ismember('Z2D_vs_Z3D', NeuroRespByNeuronTable.Properties.VariableNames)
    NeuroRespByNeuronTable.Z2D_vs_Z3D = [];
end

if ismember('NeuronType', NeuroRespByNeuronTable.Properties.VariableNames)
    NeuroRespByNeuronTable.NeuronType = [];
end
NeuroRespByNeuronTable.NeuroType = neuroType;
NeuroRespByNeuronTable.Z3D_v_Z2D = score;
NeuroRespByNeuronTable.Monocularity_3D_Max = monocularity3DMax;
NeuroRespByNeuronTable.OD_3D_Max_Eye = odEye;

save(outputPath, 'NeuroRespByNeuronTable', '-v7.3');

disp(['Saved labeled thin table to ', outputPath])
disp(['Rows in thin table: ', num2str(height(NeuroRespByNeuronTable))])
disp(['Matched to MIDTable: ', num2str(nnz(identified))])
disp(['NeuroType 2D: ', num2str(sum(NeuroRespByNeuronTable.NeuroType == "2D"))])
disp(['NeuroType 3D: ', num2str(sum(NeuroRespByNeuronTable.NeuroType == "3D"))])
disp(['NeuroType unclassified: ', num2str(sum(NeuroRespByNeuronTable.NeuroType == "unclassified"))])
disp(['NeuroType 2Donly: ', num2str(sum(NeuroRespByNeuronTable.NeuroType == "2Donly"))])
disp(['NeuroType unincluded: ', num2str(sum(NeuroRespByNeuronTable.NeuroType == "unincluded"))])
disp(['OD_3D_Max_Eye Left: ', num2str(sum(NeuroRespByNeuronTable.OD_3D_Max_Eye == "Left"))])
disp(['OD_3D_Max_Eye Right: ', num2str(sum(NeuroRespByNeuronTable.OD_3D_Max_Eye == "Right"))])
disp(['OD_3D_Max_Eye equal: ', num2str(sum(NeuroRespByNeuronTable.OD_3D_Max_Eye == "equal"))])
disp(['OD_3D_Max_Eye unknown: ', num2str(sum(NeuroRespByNeuronTable.OD_3D_Max_Eye == "unknown"))])
if nnz(identified) ~= height(MIDTable)
    warning('Matched row count (%d) does not equal MIDTable height (%d). Check duplicate or missing keys.', ...
        nnz(identified), height(MIDTable));
end

write_label_report(outputPath, NeuroRespByNeuronTable, FullTable, MIDTable, identified, midRow, scoreVar);
end

function dayNums = parse_dates_from_names(names)
dayNums = nan(numel(names), 1);
for i = 1:numel(names)
    name = char(string(names(i)));
    tok = regexp(name, '_(\d{1,2}[A-Za-z]+(?:19|20)\d{2})_', 'tokens', 'once');
    if isempty(tok)
        error('Could not parse date from recording name: %s', name);
    end
    dayNums(i) = floor(datenum(tok{1}));
end
end

function dayNums = date_to_day_number(dateValues)
if isdatetime(dateValues)
    dayNums = floor(datenum(dateValues));
elseif isnumeric(dateValues)
    dayNums = floor(dateValues);
else
    dayNums = floor(datenum(dateValues));
end
dayNums = dayNums(:);
end

function keys = make_keys(dayNums, roiValues, ttValues, unitValues)
n = numel(dayNums);
keys = strings(n, 1);
for i = 1:n
    roi = upper(strtrim(char(string(roiValues(i)))));
    tt = normalize_tetrode(ttValues(i));
    unit = double(unitValues(i));
    keys(i) = string(sprintf('%d|%s|%s|%g', dayNums(i), roi, tt, unit));
end
end

function tt = normalize_tetrode(value)
if isnan(value)
    tt = 'NaN';
else
    tt = sprintf('%g', double(value));
end
end

function scoreVar = find_2d3d_score_variable(MIDTable)
if ismember('Z3D_v_Z2D', MIDTable.Properties.VariableNames)
    scoreVar = 'Z3D_v_Z2D';
else
    error('MIDTable does not contain required column Z3D_v_Z2D.');
end
end

function write_label_report(outputPath, Tthin, Tfull, MIDTable, identified, midRow, scoreVar)
[outDir, outName] = fileparts(outputPath);
reportPath = fullfile(outDir, [outName, '_MIDTableLabelReport.txt']);
fid = fopen(reportPath, 'w');
cleanupObj = onCleanup(@() fclose(fid));

fprintf(fid, 'Output: %s\n', outputPath);
fprintf(fid, 'Thin rows: %d\n', height(Tthin));
fprintf(fid, 'MIDTable rows: %d\n', height(MIDTable));
fprintf(fid, 'Score variable used: %s\n', scoreVar);
fprintf(fid, 'Matched to MIDTable: %d\n', nnz(identified));
fprintf(fid, 'NeuroType 2D: %d\n', sum(Tthin.NeuroType == "2D"));
fprintf(fid, 'NeuroType 3D: %d\n', sum(Tthin.NeuroType == "3D"));
fprintf(fid, 'NeuroType unclassified: %d\n', sum(Tthin.NeuroType == "unclassified"));
fprintf(fid, 'NeuroType 2Donly: %d\n', sum(Tthin.NeuroType == "2Donly"));
fprintf(fid, 'NeuroType unincluded: %d\n', sum(Tthin.NeuroType == "unincluded"));
fprintf(fid, 'OD_3D_Max_Eye Left: %d\n', sum(Tthin.OD_3D_Max_Eye == "Left"));
fprintf(fid, 'OD_3D_Max_Eye Right: %d\n', sum(Tthin.OD_3D_Max_Eye == "Right"));
fprintf(fid, 'OD_3D_Max_Eye equal: %d\n', sum(Tthin.OD_3D_Max_Eye == "equal"));
fprintf(fid, 'OD_3D_Max_Eye unknown: %d\n', sum(Tthin.OD_3D_Max_Eye == "unknown"));
fprintf(fid, 'Variables: %s\n\n', strjoin(Tthin.Properties.VariableNames, ', '));

unmatched = find(~identified);
fprintf(fid, 'First unmatched rows:\n');
for i = 1:min(10, numel(unmatched))
    r = unmatched(i);
    fprintf(fid, 'row %d | Name=%s | ROI=%s | TT=%g | Unit=%g\n', ...
        r, char(string(Tfull.Name(r))), char(string(Tfull.ROI(r))), ...
        Tfull.TT(r), Tfull.Unit(r));
end

matched = find(identified);
fprintf(fid, '\nFirst matched rows:\n');
for i = 1:min(10, numel(matched))
    r = matched(i);
    fprintf(fid, ['row %d -> MIDTable row %d | ROI=%s | TT=%g | Unit=%g | ', ...
        'score=%g | NeuroType=%s | Monocularity_3D_Max=%g | OD_3D_Max_Eye=%s\n'], ...
        r, midRow(r), char(string(Tfull.ROI(r))), Tfull.TT(r), Tfull.Unit(r), ...
        Tthin.Z3D_v_Z2D(r), char(Tthin.NeuroType(r)), ...
        Tthin.Monocularity_3D_Max(r), char(Tthin.OD_3D_Max_Eye(r)));
end
end

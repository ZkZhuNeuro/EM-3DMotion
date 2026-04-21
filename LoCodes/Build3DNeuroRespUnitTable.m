%% Build 3D NeuroResp Unit Table
% Rebuild the same 3D unit selection used in FullAnalysisPipeline.m, then
% attach one NeuroResp array per included neuron so the final row count
% matches MIDTable.

cell_column = ['InRF']; %#ok<NBRAK>
exclusion_criteria = [{'InRF','N'}; {'ROI','MT/FST'}; {'Hemisphere','Right'}; ...
    {'ROI','MT?'}; {'WF',''}; {'WF','N'}; {'RF','N'}; {'RF',''}];
monkeys = ["Jim", "Clay"];
areas = ["MT", "FST"];

input_path = 'C:\LoData\NeuroResp.mat';
output_path = 'C:\LoData\NeuroRespUnitTable.mat';

disp('Building 3D NeuroResp unit table...')
disp(['Input: ', input_path])

if ~isfile(input_path)
    error('Input file not found: %s', input_path);
end

S = load(input_path, 'NeuroResp');
if ~isfield(S, 'NeuroResp')
    error('Variable "NeuroResp" was not found in %s.', input_path);
end
NeuroResp = S.NeuroResp;

%% Rebuild the same selection as FullAnalysisPipeline
file_table_MT_3D = table();
file_table_FST_3D = table();
MT_MIDTable = table();
FST_MIDTable = table();

for m = 1:size(monkeys, 2)
    disp(['Preparing 3D file tables for monkey ', char(monkeys(m)), ...
        ' (', num2str(m), '/', num2str(size(monkeys, 2)), ')'])

    if strcmp(monkeys(m), 'Jim')
        xls_table = 'P:\Jim\NeuroData\RecordingRecord_MinusMissing.xlsx';
        path_options = {'C:\Jim\In_Processing\', 'P:\Jim\NeuroData\'};
        exclusion_criteria = [{'InRF','N'}; {'ROI','MT/FST'}; {'ROI','MT?'}; ...
            {'WF',''}; {'WF','N'}; {'RF','N'}; {'RF',''}];

    elseif strcmp(monkeys(m), 'Clay')
        xls_table = 'P:\Clay\NeuroData\RecordingRecord.xlsx';
        path_options = {'C:\Clay\In_Processing\', 'P:\Clay\NeuroData\'};
        exclusion_criteria = [{'InRF','N'}; {'ROI','MT/FST'}; {'Hemisphere','Right'}; ...
            {'ROI','MT?'}; {'WF',''}; {'WF','N'}; {'RF','N'}; {'RF',''}];
    end

    if any(strcmp(areas, 'MT'))
        disp('  Loading MT 3D entries...')
        inclusion_criteria = [{'ROI','MT'}];
        [tmp_MT_MIDTable, tmp_file_table_MT_3D] = GenerateUnitFileTable( ...
            xls_table, path_options, cell_column, inclusion_criteria, ...
            exclusion_criteria, '3D');

        MT_MIDTable = [MT_MIDTable; tmp_MT_MIDTable]; %#ok<AGROW>
        file_table_MT_3D = [file_table_MT_3D; tmp_file_table_MT_3D]; %#ok<AGROW>
    end

    if any(strcmp(areas, 'FST'))
        disp('  Loading FST 3D entries...')
        inclusion_criteria = [{'ROI','FST'}];
        [tmp_FST_MIDTable, tmp_file_table_FST_3D] = GenerateUnitFileTable( ...
            xls_table, path_options, cell_column, inclusion_criteria, ...
            exclusion_criteria, '3D');

        FST_MIDTable = [FST_MIDTable; tmp_FST_MIDTable]; %#ok<AGROW>
        file_table_FST_3D = [file_table_FST_3D; tmp_file_table_FST_3D]; %#ok<AGROW>
    end
end

files_3D = [file_table_MT_3D; file_table_FST_3D];
MIDTable = [MT_MIDTable; FST_MIDTable];

disp(['Total 3D recordings selected: ', num2str(size(files_3D, 1))])
disp(['Total MIDTable rows selected: ', num2str(size(MIDTable, 1))])
disp(['NeuroResp session count: ', num2str(numel(NeuroResp))])

if numel(NeuroResp) ~= size(files_3D, 1)
    error('NeuroResp session count (%d) does not match files_3D count (%d).', ...
        numel(NeuroResp), size(files_3D, 1));
end

%% Build one row per included neuron
NeuroRespUnitTable = MIDTable;
nRows = height(NeuroRespUnitTable);
NeuroRespUnitTable.ExportRecordingName = strings(nRows, 1);
NeuroRespUnitTable.NeuroResp = cell(nRows, 1);
NeuroRespUnitTable.NeuroRespSize = strings(nRows, 1);

rowIdx = 1;
for f = 1:size(files_3D, 1)
    units = files_3D.Units{f};
    sessionResp = NeuroResp{f};

    disp(['Assigning recording ', num2str(f), '/', num2str(size(files_3D, 1)), ...
        ': ', files_3D.Names{f, 1}, '  (', num2str(numel(units)), ' units)'])

    if ndims(sessionResp) < 4
        error('Session %d NeuroResp does not have the expected unit x cue x coh x repeats layout.', f);
    end

    for u = 1:numel(units)
        assert_3d_row_alignment(NeuroRespUnitTable, files_3D, rowIdx, f, units(u));

        if units(u) > size(sessionResp, 1)
            error('Unit %d is out of bounds for session %d NeuroResp first dimension of size %d.', ...
                units(u), f, size(sessionResp, 1));
        end

        unitResp = squeeze(sessionResp(units(u), :, :, :));
        NeuroRespUnitTable.ExportRecordingName(rowIdx) = string(make_3d_recording_name(files_3D.Names{f, 1}));
        NeuroRespUnitTable.NeuroResp{rowIdx} = unitResp;
        NeuroRespUnitTable.NeuroRespSize(rowIdx) = string(mat2str(size(unitResp)));

        if mod(rowIdx, 50) == 0 || rowIdx == nRows
            disp(['  Filled rows ', num2str(rowIdx), '/', num2str(nRows)])
        end

        rowIdx = rowIdx + 1;
    end
end

if rowIdx ~= nRows + 1
    error('Row alignment failed while building NeuroRespUnitTable.');
end

%% Verify alignment with MIDTable
disp('Verifying Date / ROI / Unit alignment against MIDTable...')
[VerificationTable, verificationOK] = verify_neuroresp_unit_table(NeuroRespUnitTable, MIDTable);

if verificationOK
    disp('Verification passed: all rows match on Date, ROI, and Unit.')
else
    warning('Verification failed: mismatches were found. See VerificationTable for details.');
    mismatchRows = VerificationTable.RowIndex(~VerificationTable.AllMatch);
    disp(['First mismatched rows: ', num2str(transpose(mismatchRows(1:min(10, numel(mismatchRows)))))])
end

save(output_path, 'NeuroRespUnitTable', 'MIDTable', 'files_3D', 'VerificationTable', '-v7.3');
disp(['Saved NeuroResp unit table to ', output_path])

function assert_3d_row_alignment(NeuroRespUnitTable, files_3D, rowIdx, fileIdx, unitId)
if rowIdx > height(NeuroRespUnitTable)
    error('NeuroRespUnitTable has fewer rows than expected from files_3D.Units.');
end

if ~strcmp(NeuroRespUnitTable.Names{rowIdx, 1}, files_3D.Names{fileIdx, 1})
    error('Name mismatch at row %d while aligning NeuroResp output.', rowIdx);
end

if NeuroRespUnitTable.Unit(rowIdx) ~= unitId
    error('Unit mismatch at row %d while aligning NeuroResp output.', rowIdx);
end
end

function recordingName = make_3d_recording_name(tinfoName)
recordingName = extractBefore(tinfoName, '_TInfo');
recordingName = replace(recordingName, '-', '_');
recordingName = char(recordingName);
end

function [VerificationTable, verificationOK] = verify_neuroresp_unit_table(NeuroRespUnitTable, MIDTable)
if height(NeuroRespUnitTable) ~= height(MIDTable)
    error('Row count mismatch: NeuroRespUnitTable has %d rows, MIDTable has %d rows.', ...
        height(NeuroRespUnitTable), height(MIDTable));
end

nRows = height(MIDTable);
rowIndex = transpose(1:nRows);

dateMatch = false(nRows, 1);
roiMatch = false(nRows, 1);
unitMatch = false(nRows, 1);

for i = 1:nRows
    dateMatch(i) = isequal(datetime(NeuroRespUnitTable.Date(i)), datetime(MIDTable.Date(i)));
    roiMatch(i) = strcmp(string(NeuroRespUnitTable.ROI{i}), string(MIDTable.ROI{i}));
    unitMatch(i) = NeuroRespUnitTable.Unit(i) == MIDTable.Unit(i);
end

VerificationTable = table( ...
    rowIndex, ...
    dateMatch, ...
    roiMatch, ...
    unitMatch, ...
    dateMatch & roiMatch & unitMatch, ...
    'VariableNames', {'RowIndex', 'DateMatch', 'ROIMatch', 'UnitMatch', 'AllMatch'});

verificationOK = all(VerificationTable.AllMatch);
end

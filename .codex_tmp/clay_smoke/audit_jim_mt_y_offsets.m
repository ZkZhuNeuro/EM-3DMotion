addpath(fileparts(mfilename('fullpath')));
workbookPath = 'P:\Jim\NeuroData\RecordingRecord_Stimulation_final.xlsx';
tb = readtable(workbookPath, 'VariableNamingRule', 'preserve');
[includedRows, inclusionAudit] = getWorkbookRowsFromUnitTableGof(tb, 'Jim'); %#ok<NASGU>
roiValues = upper(strip(string(tb.ROI)));

fid = fopen(fullfile(fileparts(mfilename('fullpath')), ...
    'jim_y_offset_audit.txt'), 'w');
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, 'WORKBOOK=%s\n', workbookPath);
fprintf(fid, 'INCLUDED_JIM=%d\n', numel(includedRows));

nonzeroCount = 0;
for i = 1:numel(includedRows)
    row = includedRows(i);
    hole = parseVectorAuditLocal(valueAtAuditLocal(tb.Hole, row));
    offset = parseVectorAuditLocal(valueAtAuditLocal(tb.Offset, row));
    assert(numel(hole) == 2 && numel(offset) == 3, ...
        'Invalid Hole or Offset in workbook row %d.', row + 1);
    if abs(offset(2)) > 1e-12
        nonzeroCount = nonzeroCount + 1;
        baseAPVoxel = 68 - ((29 - hole(2)) * 0.8) * 2;
        adjustedAPVoxel = baseAPVoxel + 2 * offset(2);
        fprintf(fid, ['ROW=%d|DATE=%s|ROI=%s|HOLE_Y=%g|OFFSET_Y_MM=%g|' ...
            'BASE_AP_VOXEL=%g|ADJUSTED_AP_VOXEL=%g|MRI_SLICE_INDEX=%d\n'], ...
            row + 1, dateTextAuditLocal(valueAtAuditLocal(tb.Date, row)), roiValues(row), ...
            hole(2), offset(2), baseAPVoxel, adjustedAPVoxel, ...
            round(adjustedAPVoxel) + 1);
    end
end
fprintf(fid, 'NONZERO_Y_OFFSET_JIM=%d\n', nonzeroCount);

function value = valueAtAuditLocal(column, row)
if iscell(column), value = column{row}; else, value = column(row, :); end
end

function vector = parseVectorAuditLocal(value)
if isnumeric(value)
    vector = double(value(:).');
else
    textValue = char(string(value));
    numbers = regexp(textValue, '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', 'match');
    vector = str2double(numbers);
end
end

function textValue = dateTextAuditLocal(value)
if isdatetime(value)
    textValue = char(string(value, 'yyyy-MM-dd'));
elseif isnumeric(value)
    textValue = char(string(datetime(value, 'ConvertFrom', 'excel'), 'yyyy-MM-dd'));
else
    textValue = char(string(value));
end
end

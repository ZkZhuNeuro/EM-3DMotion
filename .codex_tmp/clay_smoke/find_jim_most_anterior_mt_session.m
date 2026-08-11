addpath('C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\MRI\RecordingLocationPlots\common');

workbookPath = 'P:\Jim\NeuroData\RecordingRecord_Stimulation_final.xlsx';
tb = readtable(workbookPath, 'VariableNamingRule', 'preserve');
[includedRows, inclusionAudit] = getWorkbookRowsFromUnitTableGof(tb, 'Jim'); %#ok<NASGU>

roiValues = upper(strip(string(getColumnLocal(tb, 'ROI'))));
dateValues = getColumnLocal(tb, 'Date');
holeValues = getColumnLocal(tb, 'Hole');
offsetValues = getColumnLocal(tb, 'Offset');
mtRows = includedRows(roiValues(includedRows) == "MT");
apVoxels = nan(size(mtRows));
holeYs = nan(size(mtRows));
adjustedGridYs = nan(size(mtRows));
for i = 1:numel(mtRows)
    hole = parseVectorLocal(valueAtLocal(holeValues, mtRows(i)));
    offset = parseVectorLocal(valueAtLocal(offsetValues, mtRows(i)));
    apVoxels(i) = 68 - ((29 - hole(2)) * 0.8) * 2 + 2 * offset(2);
    holeYs(i) = hole(2);
    adjustedGridYs(i) = hole(2) + offset(2) / 0.8;
end

largestGridY = max(holeYs);
largestAdjustedGridY = max(adjustedGridYs);
maximumIndices = find(abs(adjustedGridYs - largestAdjustedGridY) < 1e-12);
outPath = fullfile(fileparts(mfilename('fullpath')), 'jim_most_anterior_mt.txt');
fid = fopen(outPath, 'w');
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, 'INCLUDED_MT=%d\n', numel(mtRows));
fprintf(fid, 'LARGEST_RAW_GRID_Y=%g\n', largestGridY);
fprintf(fid, 'LARGEST_ADJUSTED_GRID_Y=%g\n', largestAdjustedGridY);
fprintf(fid, 'TIE_COUNT=%d\n', numel(maximumIndices));
for j = maximumIndices(:).'
    row = mtRows(j);
    hole = parseVectorLocal(valueAtLocal(holeValues, row));
    offset = parseVectorLocal(valueAtLocal(offsetValues, row));
    fprintf(fid, ['WORKBOOK_ROW=%d|DATE=%s|ROI=MT|HOLE=[%g,%g]|' ...
        'OFFSET=[%g,%g,%g]|ADJUSTED_GRID_Y=%g|AP_VOXEL=%g|MRI_SLICE_INDEX=%d\n'], ...
        row + 1, dateTextLocal(valueAtLocal(dateValues, row)), ...
        hole(1), hole(2), offset(1), offset(2), offset(3), ...
        adjustedGridYs(j), apVoxels(j), round(apVoxels(j)) + 1);
end

function column = getColumnLocal(tb, name)
names = tb.Properties.VariableNames;
idx = find(strcmpi(names, name), 1, 'first');
assert(~isempty(idx), 'Missing workbook column %s.', name);
column = tb.(names{idx});
end

function value = valueAtLocal(column, row)
if iscell(column), value = column{row}; else, value = column(row, :); end
end

function vector = parseVectorLocal(value)
if isnumeric(value)
    vector = double(value(:).');
else
    vector = str2double(regexp(char(string(value)), ...
        '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', 'match'));
end
end

function textValue = dateTextLocal(value)
if isdatetime(value)
    dateValue = value;
elseif isnumeric(value)
    dateValue = datetime(value, 'ConvertFrom', 'excel');
else
    dateValue = datetime(string(value));
end
textValue = char(string(dateValue, 'yyyy-MM-dd'));
end

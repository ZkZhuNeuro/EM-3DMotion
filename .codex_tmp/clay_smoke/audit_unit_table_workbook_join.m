addpath(fileparts(mfilename('fullpath')));
outPath = fullfile(fileparts(mfilename('fullpath')), 'unit_table_workbook_join_audit.txt');
fid = fopen(outPath, 'w');
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

sources = {
    'Clay', 'P:\Clay\NeuroData\RecordingRecord_Stimulation.xlsx';
    'Jim',  'P:\Jim\NeuroData\RecordingRecord_Stimulation_final.xlsx'
};
for s = 1:size(sources, 1)
    monkey = sources{s, 1};
    workbook = sources{s, 2};
    tb = readtable(workbook, 'VariableNamingRule', 'preserve');
    [rows, audit] = getWorkbookRowsFromUnitTableGof(tb, monkey);
    fprintf(fid, '%s_WORKBOOK=%s\n', upper(monkey), workbook);
    fprintf(fid, '%s_COUNT=%d\n', upper(monkey), audit.SessionCount);
    fprintf(fid, '%s_MT=%d\n', upper(monkey), audit.MTCount);
    fprintf(fid, '%s_FST=%d\n', upper(monkey), audit.FSTCount);
    fprintf(fid, '%s_ROWS=%s\n', upper(monkey), mat2str((rows + 1).'));

    dates = normalizeDatesAuditLocal(tb.Date);
    roi = upper(strip(string(tb.ROI)));
    mua = upper(strip(string(tb.MUAStim)));
    oldRows = find(mua == "Y" & ismember(roi, ["MT", "FST"]) & ~isnat(dates));
    extraRows = setdiff(oldRows, rows);
    for i = 1:numel(extraRows)
        r = extraRows(i);
        fprintf(fid, '%s_REMOVED_WORKBOOK_ROW=%d|DATE=%s|ROI=%s\n', ...
            upper(monkey), r + 1, string(dates(r), 'yyyy-MM-dd'), roi(r));
    end
end

function dates = normalizeDatesAuditLocal(values)
if isdatetime(values)
    dates = dateshift(values, 'start', 'day');
elseif isnumeric(values)
    dates = datetime(values, 'ConvertFrom', 'excel');
    dates = dateshift(dates, 'start', 'day');
else
    dates = datetime(strip(string(values)));
    dates = dateshift(dates, 'start', 'day');
end
end

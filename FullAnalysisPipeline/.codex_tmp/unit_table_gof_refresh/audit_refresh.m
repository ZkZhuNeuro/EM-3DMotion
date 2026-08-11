sourceXlsx = 'P:\Clay\NeuroData\RecordingRecord_Stimulation.xlsx';
gofPath = 'C:\EM\BehaviorFitting\unit_table_gof.mat';
assessPath = 'C:\EM\BehaviorFitting\unit_table_GLMAssess.mat';
updatingPath = 'C:\EM\PopulationAnalysis\UnitTable_updating.mat';

fprintf('Source workbook: %s\n', sourceXlsx);
source = readtable(sourceXlsx, 'VariableNamingRule', 'preserve');
fprintf('Source rows=%d cols=%d\n', height(source), width(source));
fprintf('Source variables: %s\n', strjoin(source.Properties.VariableNames, ', '));

g = load(gofPath, 'unit_table_gof');
gof = g.unit_table_gof;
fprintf('GOF rows=%d cols=%d\n', height(gof), width(gof));
fprintf('GOF variables (first 20): %s\n', strjoin(gof.Properties.VariableNames(1:min(20,width(gof))), ', '));

if isfile(assessPath)
    a = load(assessPath, 'unit_table');
    fprintf('GLMAssess rows=%d cols=%d\n', height(a.unit_table), width(a.unit_table));
end
if isfile(updatingPath)
    u = load(updatingPath, 'unit_table');
    fprintf('UnitTable_updating rows=%d cols=%d\n', height(u.unit_table), width(u.unit_table));
end

sourceDate = source.('Date');
if ~isdatetime(sourceDate)
    sourceDate = datetime(sourceDate, 'ConvertFrom', 'excel');
end
sourceROI = strip(string(source.('ROI')));

gofDate = gof.Date;
if ~isdatetime(gofDate)
    gofDate = datetime(gofDate, 'ConvertFrom', 'datenum');
end
gofMonkey = strip(string(gof.Monkey));
gofROI = strip(string(gof.ROI));

isClay = strcmpi(gofMonkey, 'Clay');
fprintf('GOF Clay rows=%d; ROI counts:\n', nnz(isClay));
disp(groupsummary(table(gofROI(isClay), 'VariableNames', {'ROI'}), 'ROI'));

[matched, sourceIdx] = ismember(dateshift(gofDate(isClay), 'start', 'day'), dateshift(sourceDate, 'start', 'day'));
clayIdx = find(isClay);
clayIdx = clayIdx(matched);
sourceIdx = sourceIdx(matched);
mismatch = ~strcmpi(gofROI(clayIdx), sourceROI(sourceIdx));
fprintf('Matched Clay dates=%d; ROI mismatches=%d\n', nnz(matched), nnz(mismatch));
if any(mismatch)
    comparison = table(clayIdx(mismatch), gofDate(clayIdx(mismatch)), gofROI(clayIdx(mismatch)), ...
        sourceIdx(mismatch), sourceROI(sourceIdx(mismatch)), ...
        'VariableNames', {'GOFRow','Date','OldGOF_ROI','ExcelRow','NewExcel_ROI'});
    disp(comparison);
end

fstToMt = mismatch & strcmpi(gofROI(clayIdx), 'FST') & strcmpi(sourceROI(sourceIdx), 'MT');
fprintf('Exact FST -> MT mismatches=%d\n', nnz(fstToMt));
if any(fstToMt)
    changed = table(clayIdx(fstToMt), gofDate(clayIdx(fstToMt)), sourceIdx(fstToMt), ...
        'VariableNames', {'GOFRow','Date','ExcelRow'});
    disp(changed);
end

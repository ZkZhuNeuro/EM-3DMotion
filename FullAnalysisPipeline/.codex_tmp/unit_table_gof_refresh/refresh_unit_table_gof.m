sourceXlsx = 'P:\Clay\NeuroData\RecordingRecord_Stimulation.xlsx';
canonicalPath = 'C:\EM\BehaviorFitting\unit_table_gof.mat';
outputDir = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\FullAnalysisPipeline\outputs\unit_table_gof_refresh_20260806';
outputPath = fullfile(outputDir, 'unit_table_gof.mat');
backupPath = fullfile(outputDir, 'unit_table_gof_before_roi_refresh.mat');
auditPath = fullfile(outputDir, 'roi_refresh_audit.csv');

assert(isfile(sourceXlsx), 'Source workbook not found: %s', sourceXlsx);
assert(isfile(canonicalPath), 'Existing GOF table not found: %s', canonicalPath);
if ~isfolder(outputDir)
    mkdir(outputDir);
end

loaded = load(canonicalPath, 'unit_table_gof');
assert(isfield(loaded, 'unit_table_gof') && istable(loaded.unit_table_gof), ...
    'Canonical MAT file does not contain table variable unit_table_gof.');
original = loaded.unit_table_gof;
unit_table_gof = original;

source = readtable(sourceXlsx, 'VariableNamingRule', 'preserve');
assert(all(ismember({'Date','ROI'}, source.Properties.VariableNames)), ...
    'Source workbook must contain Date and ROI columns.');
assert(all(ismember({'Date','ROI','Monkey'}, unit_table_gof.Properties.VariableNames)), ...
    'unit_table_gof must contain Date, ROI, and Monkey variables.');

sourceDate = source.('Date');
if ~isdatetime(sourceDate)
    sourceDate = datetime(sourceDate, 'ConvertFrom', 'excel');
end
sourceDate = dateshift(sourceDate, 'start', 'day');
sourceROI = strip(string(source.('ROI')));
assert(numel(unique(sourceDate)) == height(source), ...
    'Source workbook contains duplicate dates; refusing ambiguous ROI refresh.');

gofDate = unit_table_gof.Date;
if ~isdatetime(gofDate)
    gofDate = datetime(gofDate, 'ConvertFrom', 'datenum');
end
gofDate = dateshift(gofDate, 'start', 'day');
gofMonkey = strip(string(unit_table_gof.Monkey));
gofROI = strip(string(unit_table_gof.ROI));

clayRows = find(strcmpi(gofMonkey, 'Clay'));
[matched, sourceRows] = ismember(gofDate(clayRows), sourceDate);
assert(all(matched), 'One or more Clay GOF dates were not found in the source workbook.');

changedMask = ~strcmpi(gofROI(clayRows), sourceROI(sourceRows));
changedGOFRows = clayRows(changedMask);
changedSourceRows = sourceRows(changedMask);
oldROI = gofROI(changedGOFRows);
newROI = sourceROI(changedSourceRows);

assert(numel(changedGOFRows) == 3, ...
    'Expected exactly 3 ROI changes, found %d.', numel(changedGOFRows));
assert(all(strcmpi(oldROI, 'FST') & strcmpi(newROI, 'MT')), ...
    'Detected ROI changes other than FST -> MT; refusing update.');

for i = 1:numel(changedGOFRows)
    row = changedGOFRows(i);
    if iscell(unit_table_gof.ROI)
        unit_table_gof.ROI{row} = char(newROI(i));
    elseif isstring(unit_table_gof.ROI)
        unit_table_gof.ROI(row) = newROI(i);
    elseif iscategorical(unit_table_gof.ROI)
        unit_table_gof.ROI(row) = categorical(newROI(i));
    else
        error('Unsupported ROI variable type: %s', class(unit_table_gof.ROI));
    end
end

assert(isequaln(original(:, setdiff(original.Properties.VariableNames, {'ROI'}, 'stable')), ...
    unit_table_gof(:, setdiff(unit_table_gof.Properties.VariableNames, {'ROI'}, 'stable'))), ...
    'A non-ROI field changed unexpectedly.');

copyfile(canonicalPath, backupPath, 'f');
save(outputPath, 'unit_table_gof');

reloaded = load(outputPath, 'unit_table_gof');
assert(istable(reloaded.unit_table_gof), 'Saved output did not reload as a table.');
assert(height(reloaded.unit_table_gof) == height(original) && ...
    width(reloaded.unit_table_gof) == width(original), ...
    'Saved output dimensions changed unexpectedly.');
assert(all(strcmpi(strip(string(reloaded.unit_table_gof.ROI(changedGOFRows))), 'MT')), ...
    'Saved output failed ROI validation.');

audit = table(changedGOFRows, gofDate(changedGOFRows), changedSourceRows + 1, oldROI, newROI, ...
    'VariableNames', {'GOFRow','Date','ExcelRow','OldROI','NewROI'});
writetable(audit, auditPath);

copyfile(outputPath, canonicalPath, 'f');
canonical = load(canonicalPath, 'unit_table_gof');
assert(isequaln(canonical.unit_table_gof, reloaded.unit_table_gof), ...
    'Canonical copy does not match validated output.');

fprintf('Updated %d ROI labels in unit_table_gof.\n', height(audit));
disp(audit);
fprintf('Rows=%d, columns=%d\n', height(unit_table_gof), width(unit_table_gof));
fprintf('Validated output: %s\n', outputPath);
fprintf('Updated canonical: %s\n', canonicalPath);
fprintf('Backup: %s\n', backupPath);

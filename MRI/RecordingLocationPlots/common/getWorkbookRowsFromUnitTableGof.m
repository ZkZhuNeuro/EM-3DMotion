function [rowIndices, audit] = getWorkbookRowsFromUnitTableGof(tb, monkeyName)
% Match workbook rows to the sessions included by unit_table_gof.
% Exact Date-ROI matches are preferred. If a workbook ROI label was edited
% after unit_table_gof was built, an otherwise unique date match is used.
% Downstream plotting must use audit.WorkbookROI for MT/FST labels;
% audit.AnalysisROI is retained only to audit unit_table_gof disagreements.

gofPath = 'C:\EM\BehaviorFitting\unit_table_gof.mat';
loaded = load(gofPath, 'unit_table_gof');
assert(isfield(loaded, 'unit_table_gof') && istable(loaded.unit_table_gof), ...
    'The canonical MAT file must contain table variable unit_table_gof.');
gof = loaded.unit_table_gof;
assert(all(ismember({'Monkey','Date','ROI'}, gof.Properties.VariableNames)), ...
    'unit_table_gof must contain Monkey, Date, and ROI.');

workbookDates = normalizeDatesLocal(getTableColumnLocal(tb, 'Date'));
workbookROI = upper(strip(normalizeTextLocal(getTableColumnLocal(tb, 'ROI'))));
gofDates = normalizeDatesLocal(gof.Date);
gofMonkey = upper(strip(normalizeTextLocal(gof.Monkey)));
gofROI = upper(strip(normalizeTextLocal(gof.ROI)));

monkeyName = upper(strip(string(monkeyName)));
gofMask = gofMonkey == monkeyName & ismember(gofROI, ["MT", "FST"]) & ...
    ~isnat(gofDates);
gofDates = gofDates(gofMask);
gofROI = gofROI(gofMask);

gofKeys = string(gofDates, 'yyyy-MM-dd') + "|" + gofROI;
workbookKeys = string(workbookDates, 'yyyy-MM-dd') + "|" + workbookROI;
assert(numel(unique(gofKeys)) == numel(gofKeys), ...
    'unit_table_gof has duplicate %s Date-ROI session keys.', monkeyName);

rowIndices = nan(numel(gofKeys), 1);
usedDateOnlyFallback = false(numel(gofKeys), 1);
for i = 1:numel(gofKeys)
    matches = find(workbookKeys == gofKeys(i));
    if isempty(matches)
        matches = find(workbookDates == gofDates(i) & ...
            ismember(workbookROI, ["MT", "FST"]));
        usedDateOnlyFallback(i) = numel(matches) == 1;
    end
    assert(numel(matches) == 1, ...
        ['Expected one exact Date-ROI match or one unique date fallback ' ...
        'for %s %s, but found %d.'], ...
        monkeyName, gofKeys(i), numel(matches));
    rowIndices(i) = matches;
end
assert(numel(unique(rowIndices)) == numel(rowIndices), ...
    '%s analysis sessions mapped to duplicate workbook rows.', monkeyName);
[rowIndices, sortOrder] = sort(rowIndices);
analysisROI = gofROI(sortOrder);
analysisDates = gofDates(sortOrder);
usedDateOnlyFallback = usedDateOnlyFallback(sortOrder);

audit = struct();
audit.Monkey = monkeyName;
audit.SessionCount = numel(rowIndices);
audit.MTCount = nnz(analysisROI == "MT");
audit.FSTCount = nnz(analysisROI == "FST");
audit.Keys = gofKeys(sortOrder);
audit.AnalysisROI = analysisROI;
audit.AnalysisDates = analysisDates;
audit.WorkbookROI = workbookROI(rowIndices);
audit.UsedDateOnlyFallback = usedDateOnlyFallback;
audit.WorkbookMTCount = nnz(audit.WorkbookROI == "MT");
audit.WorkbookFSTCount = nnz(audit.WorkbookROI == "FST");
audit.LabelMismatch = audit.AnalysisROI ~= audit.WorkbookROI;
end

function column = getTableColumnLocal(tb, requested_name)
names = tb.Properties.VariableNames;
idx = find(strcmpi(names, requested_name), 1, 'first');
assert(~isempty(idx), 'Workbook is missing required column %s.', requested_name);
column = tb.(names{idx});
end

function textValues = normalizeTextLocal(values)
if iscell(values)
    textValues = strings(size(values));
    for i = 1:numel(values)
        value = values{i};
        if ismissing(value)
            textValues(i) = missing;
        elseif ischar(value) || isstring(value)
            textValues(i) = string(value);
        else
            textValues(i) = string(value);
        end
    end
else
    textValues = string(values);
end
textValues = strip(textValues);
end

function dates = normalizeDatesLocal(values)
if isdatetime(values)
    dates = dateshift(values, 'start', 'day');
elseif isnumeric(values)
    dates = datetime(values, 'ConvertFrom', 'excel');
    dates = dateshift(dates, 'start', 'day');
else
    textValues = strip(string(values));
    dates = NaT(size(textValues));
    formats = {'MM/dd/yyyy','M/d/yyyy','yyyy-MM-dd','dd-MMM-yyyy'};
    for i = 1:numel(textValues)
        if strlength(textValues(i)) == 0 || ismissing(textValues(i)), continue; end
        for j = 1:numel(formats)
            try
                dates(i) = datetime(textValues(i), 'InputFormat', formats{j});
                break
            catch
            end
        end
    end
end
end

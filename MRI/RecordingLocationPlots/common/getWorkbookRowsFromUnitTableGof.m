function [rowIndices, audit] = getWorkbookRowsFromUnitTableGof(tb, monkeyName)
% Match workbook rows exactly to the session keys in unit_table_gof.

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
for i = 1:numel(gofKeys)
    matches = find(workbookKeys == gofKeys(i));
    assert(numel(matches) == 1, ...
        'Expected one workbook match for %s %s, but found %d.', ...
        monkeyName, gofKeys(i), numel(matches));
    rowIndices(i) = matches;
end
rowIndices = sort(rowIndices);

audit = struct();
audit.Monkey = monkeyName;
audit.SessionCount = numel(rowIndices);
audit.MTCount = nnz(workbookROI(rowIndices) == "MT");
audit.FSTCount = nnz(workbookROI(rowIndices) == "FST");
audit.Keys = gofKeys;
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

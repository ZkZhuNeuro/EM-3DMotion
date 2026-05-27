clear; clc;

lorfTablePath = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\LoRF\LoRFTable.mat';
unitTablePath = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\LoRF\LoRF_unit_table_clay.mat';

S = load(lorfTablePath);
if ~isfield(S, 'AllRFTable')
    error('AllRFTable not found in %s', lorfTablePath);
end
P = S.AllRFTable;

U = load(unitTablePath);
if isfield(U, 'RF_table')
    RF = U.RF_table;
elseif isfield(U, 'unit_table')
    RF = U.unit_table;
else
    error('No RF_table or unit_table found in %s', unitTablePath);
end

paperRows = false(numel(P.ROI), 1);
for i = 1:numel(paperRows)
    roiVal = normalizeText(P.ROI{i});
    nameVal = normalizeText(P.Names{i});
    paperRows(i) = strcmpi(roiVal, 'FST') && startsWith(lower(nameVal), 'c');
end

paperDate = arrayfun(@(x) formatDateKey(x), P.Date(paperRows));
paperTT = double(P.Tetrode(paperRows));
paperUnit = double(P.Unit(paperRows));

paperKeys_exact = composeKeys(paperDate, paperTT, paperUnit);
paperKeys_minus1 = composeKeys(paperDate, paperTT, paperUnit - 1);
paperKeys_plus1 = composeKeys(paperDate, paperTT, paperUnit + 1);

rfDate = strings(height(RF), 1);
for i = 1:height(RF)
    rfDate(i) = formatDateKey(tableCell(RF.Date, i));
end
rfTT = getNumericColumn(RF, {'TTNum', 'Tetrode'});
rfSorted = getNumericColumn(RF, {'SortedNum', 'Unit'});
rfInternal = getNumericColumn(RF, {'InternalUnitID', 'i_unit', 'UnitIndex', 'UnitID'});

rfKeys_internal = composeKeys(rfDate, rfTT, rfInternal);
rfKeys_internalPlus1 = composeKeys(rfDate, rfTT, rfInternal + 1);
rfKeys_sorted = composeKeys(rfDate, rfTT, rfSorted);

match_internal_exact = ismember(rfKeys_internal, paperKeys_exact);
match_internal_plus1 = ismember(rfKeys_internalPlus1, paperKeys_exact);
match_sorted_exact = ismember(rfKeys_sorted, paperKeys_exact);
match_internal_to_minus1 = ismember(rfKeys_internal, paperKeys_minus1);

fprintf('Clay FST rows in paper table: %d\n', numel(paperKeys_exact));
fprintf('Clay unit-table rows: %d\n\n', height(RF));

fprintf('Match rule A: paper Unit == InternalUnitID        -> %d\n', sum(match_internal_exact));
fprintf('Match rule B: paper Unit == InternalUnitID + 1    -> %d\n', sum(match_internal_plus1));
fprintf('Match rule C: paper Unit == SortedNum             -> %d\n', sum(match_sorted_exact));
fprintf('Match rule D: paper Unit - 1 == InternalUnitID    -> %d\n', sum(match_internal_to_minus1));

fprintf('\nOverlaps:\n');
fprintf('A & B -> %d\n', sum(match_internal_exact & match_internal_plus1));
fprintf('A & C -> %d\n', sum(match_internal_exact & match_sorted_exact));
fprintf('B & C -> %d\n', sum(match_internal_plus1 & match_sorted_exact));

missingPaperA = setdiff(unique(paperKeys_exact), unique(rfKeys_internal(match_internal_exact)));
missingPaperB = setdiff(unique(paperKeys_exact), unique(rfKeys_internalPlus1(match_internal_plus1)));
missingPaperC = setdiff(unique(paperKeys_exact), unique(rfKeys_sorted(match_sorted_exact)));

fprintf('\nUnique paper keys not matched:\n');
fprintf('A: %d\n', numel(missingPaperA));
fprintf('B: %d\n', numel(missingPaperB));
fprintf('C: %d\n', numel(missingPaperC));

disp('First 20 missing keys for A:');
disp(missingPaperA(1:min(20, numel(missingPaperA))));

disp('First 20 missing keys for B:');
disp(missingPaperB(1:min(20, numel(missingPaperB))));

disp('First 20 missing keys for C:');
disp(missingPaperC(1:min(20, numel(missingPaperC))));

function keys = composeKeys(dateKey, ttNum, unitNum)
keys = strings(numel(dateKey), 1);
for i = 1:numel(dateKey)
    if strlength(dateKey(i)) == 0 || ~isfinite(ttNum(i)) || ~isfinite(unitNum(i))
        keys(i) = "";
    else
        keys(i) = sprintf('clay|%s|tt%02d|unit%02d', dateKey(i), ttNum(i), unitNum(i));
    end
end
keys = keys(strlength(keys) > 0);
end

function out = normalizeText(v)
if isstring(v)
    out = char(v);
elseif ischar(v)
    out = v;
else
    try
        out = char(string(v));
    catch
        out = '';
    end
end
out = strtrim(out);
end

function key = formatDateKey(dateValue)
key = "";
try
    if isdatetime(dateValue)
        if ~isnat(dateValue)
            key = string(datestr(dateValue, 'yyyymmdd'));
            return
        end
    end
    if isnumeric(dateValue) && isscalar(dateValue) && isfinite(dateValue)
        key = string(datestr(datetime(dateValue, 'ConvertFrom', 'datenum'), 'yyyymmdd'));
        return
    end
    if iscell(dateValue)
        key = formatDateKey(dateValue{1});
        return
    end
    textValue = normalizeText(dateValue);
    if ~isempty(textValue)
        parsed = datetime(textValue, 'InputFormat', 'yyyyMMdd');
        if ~isnat(parsed)
            key = string(datestr(parsed, 'yyyymmdd'));
            return
        end
    end
catch
end
end

function value = tableCell(col, idx)
if iscell(col)
    value = col{idx};
else
    value = col(idx, :);
end
end

function col = getNumericColumn(T, candidateVars)
col = nan(height(T), 1);
for iVar = 1:numel(candidateVars)
    varName = candidateVars{iVar};
    if ismember(varName, T.Properties.VariableNames)
        for i = 1:height(T)
            rawValue = tableCell(T.(varName), i);
            col(i) = scalarNumeric(rawValue);
        end
        return
    end
end
end

function value = scalarNumeric(rawValue)
value = NaN;
if isnumeric(rawValue) && isscalar(rawValue) && isfinite(rawValue)
    value = double(rawValue);
elseif islogical(rawValue) && isscalar(rawValue)
    value = double(rawValue);
elseif isstring(rawValue) || ischar(rawValue)
    candidate = str2double(string(rawValue));
    if isfinite(candidate)
        value = candidate;
    end
end
end

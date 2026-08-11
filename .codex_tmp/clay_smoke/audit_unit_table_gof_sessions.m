gofPath = 'C:\EM\BehaviorFitting\unit_table_gof.mat';
outDir = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\.codex_tmp\clay_smoke';
loaded = load(gofPath, 'unit_table_gof');
T = loaded.unit_table_gof;

fid = fopen(fullfile(outDir, 'unit_table_gof_session_audit.txt'), 'w');
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, 'ROWS=%d\nCOLS=%d\n', height(T), width(T));
fprintf(fid, 'VARIABLES=%s\n', strjoin(T.Properties.VariableNames, '|'));

required = {'Monkey','Date','ROI'};
assert(all(ismember(required, T.Properties.VariableNames)), ...
    'unit_table_gof is missing Monkey, Date, or ROI.');
monkey = upper(strip(string(T.Monkey)));
roi = upper(strip(string(T.ROI)));
dateValues = normalizeDatesLocal(T.Date);

for monkeyName = ["CLAY", "JIM"]
    for roiName = ["MT", "FST"]
        mask = monkey == monkeyName & roi == roiName & ~isnat(dateValues);
        fprintf(fid, '%s_%s_ROWS=%d\n', monkeyName, roiName, nnz(mask));
        fprintf(fid, '%s_%s_UNIQUE_DATES=%d\n', monkeyName, roiName, ...
            numel(unique(dateValues(mask))));
    end
end

keys = monkey + "|" + string(dateValues, 'yyyy-MM-dd') + "|" + roi;
[uniqueKeys, ~, keyGroup] = unique(keys, 'stable');
keyCounts = accumarray(keyGroup, 1);
fprintf(fid, 'UNIQUE_SESSION_KEYS=%d\n', numel(uniqueKeys));
fprintf(fid, 'DUPLICATE_SESSION_KEYS=%d\n', nnz(keyCounts > 1));
for i = find(keyCounts > 1).'
    fprintf(fid, 'DUPLICATE=%s|COUNT=%d\n', uniqueKeys(i), keyCounts(i));
end

keepVars = intersect({'Monkey','Date','ROI','ND','OriginalRecIdx'}, ...
    T.Properties.VariableNames, 'stable');
sessionTable = T(:, keepVars);
sessionTable.Date = dateValues;
writetable(sessionTable, fullfile(outDir, 'unit_table_gof_sessions.csv'));

function dates = normalizeDatesLocal(values)
if isdatetime(values)
    dates = dateshift(values, 'start', 'day');
elseif isnumeric(values)
    dates = datetime(values, 'ConvertFrom', 'excel');
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

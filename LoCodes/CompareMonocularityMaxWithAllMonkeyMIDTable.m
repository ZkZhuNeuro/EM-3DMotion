%% Compare Monocularity_max With AllMonkeyMIDTable
% Loads the computed NeuroRespUnitTable and AllMonkeyMIDTable, aligns rows,
% and compares Monocularity_max against Monocularity_3D_Max.

computed_path = 'C:\LoData\NeuroRespUnitTable_Monocularity.mat';
midtable_path = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\OD_2D3DCompare\AllMonkeyMIDTable.mat';

disp('Loading computed NeuroRespUnitTable...')
S1 = load(computed_path, 'NeuroRespUnitTable');
if ~isfield(S1, 'NeuroRespUnitTable')
    error('Variable "NeuroRespUnitTable" not found in %s.', computed_path);
end
NeuroRespUnitTable = S1.NeuroRespUnitTable;

disp('Loading AllMonkeyMIDTable...')
S2 = load(midtable_path, 'AllMonkeyMIDTable');
if ~isfield(S2, 'AllMonkeyMIDTable')
    error('Variable "AllMonkeyMIDTable" not found in %s.', midtable_path);
end
AllMonkeyMIDTable = S2.AllMonkeyMIDTable;

if height(NeuroRespUnitTable) ~= height(AllMonkeyMIDTable)
    error('Row count mismatch: NeuroRespUnitTable has %d rows, AllMonkeyMIDTable has %d rows.', ...
        height(NeuroRespUnitTable), height(AllMonkeyMIDTable));
end

disp('Checking Date / ROI / Unit row alignment first...')
dateMatch = false(height(NeuroRespUnitTable), 1);
roiMatch = false(height(NeuroRespUnitTable), 1);
unitMatch = false(height(NeuroRespUnitTable), 1);

for i = 1:height(NeuroRespUnitTable)
    dateMatch(i) = isequal(datetime(NeuroRespUnitTable.Date(i)), datetime(AllMonkeyMIDTable.Date(i)));
    roiMatch(i) = strcmp(string(NeuroRespUnitTable.ROI{i}), string(AllMonkeyMIDTable.ROI{i}));
    unitMatch(i) = NeuroRespUnitTable.Unit(i) == AllMonkeyMIDTable.Unit(i);
end

if ~all(dateMatch & roiMatch & unitMatch)
    badRows = find(~(dateMatch & roiMatch & unitMatch));
    error('Row alignment mismatch before comparison. First bad rows: %s', ...
        num2str(transpose(badRows(1:min(10, numel(badRows))))));
end

disp('Comparing Monocularity_max to AllMonkeyMIDTable.Monocularity_3D_Max...')
computedVals = NeuroRespUnitTable.Monocularity_max;
referenceVals = AllMonkeyMIDTable.Monocularity_3D_Max;
deltaVals = computedVals - referenceVals;

finiteMask = isfinite(computedVals) & isfinite(referenceVals);
exactMatch = false(size(computedVals));
exactMatch(finiteMask) = computedVals(finiteMask) == referenceVals(finiteMask);
tolerance = 1e-10;
closeMatch = false(size(computedVals));
closeMatch(finiteMask) = abs(deltaVals(finiteMask)) < tolerance;

ComparisonTable = table( ...
    transpose((1:height(NeuroRespUnitTable))), ...
    computedVals, ...
    referenceVals, ...
    deltaVals, ...
    exactMatch, ...
    closeMatch, ...
    'VariableNames', {'RowIndex', 'ComputedMonocularityMax', 'ReferenceMonocularity3DMax', ...
    'Delta', 'ExactMatch', 'CloseMatch'});

disp(['Finite comparisons: ', num2str(sum(finiteMask)), '/', num2str(numel(finiteMask))])
disp(['Exact matches: ', num2str(sum(exactMatch)), '/', num2str(sum(finiteMask))])
disp(['Matches within tolerance ', num2str(tolerance), ': ', num2str(sum(closeMatch)), '/', num2str(sum(finiteMask))])

if any(finiteMask)
    disp(['Max abs difference: ', num2str(max(abs(deltaVals(finiteMask))))])
    disp(['Mean abs difference: ', num2str(mean(abs(deltaVals(finiteMask))))])
end

badRows = ComparisonTable.RowIndex(~ComparisonTable.CloseMatch & finiteMask);
if ~isempty(badRows)
    disp('First rows that do not match within tolerance:')
    disp(badRows(1:min(10, numel(badRows)))')
end

save('C:\LoData\MonocularityMaxComparison.mat', 'ComparisonTable', '-v7.3');
disp('Saved comparison table to C:\LoData\MonocularityMaxComparison.mat')

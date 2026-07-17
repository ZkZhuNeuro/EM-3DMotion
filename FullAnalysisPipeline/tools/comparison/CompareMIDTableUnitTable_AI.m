% Compare MIDTable_20260513 against UnitTable_updating row by row.
%
% Checks:
%   1. Date, Monkey, and ROI agree for every row.
%   2. StimElec agrees, because it selects the unit_table.AI column.
%   3. MIDTable AI values match unit_table.AI{row}(:, StimElec).

clear;
clc;

populationDir = 'C:\EM\PopulationAnalysis';
outputRoot = 'C:\EM\FullAnalysisPipeline_Outputs_20260604';
comparisonDir = fullfile(outputRoot, 'MIDTable_20260513_UnitTableComparison');
if ~exist(comparisonDir, 'dir')
    mkdir(comparisonDir);
end
midPath = fullfile(populationDir, 'MIDTable_20260602.mat');
unitPath = fullfile(populationDir, 'UnitTable_updating.mat');

midData = load(midPath, 'MIDTable');
unitData = load(unitPath, 'unit_table');

MIDTable = midData.MIDTable;
unit_table = unitData.unit_table;

conditions = {'Combined', 'MonoL', 'MonoR', 'Stereo'};
midAIVars = {'Combined_AI', 'MonoL_AI', 'MonoR_AI', 'Stereo_AI'};
tol = 1e-10;

nMID = height(MIDTable);
nUnit = height(unit_table);
nRows = min(nMID, nUnit);

midAI = nan(nRows, numel(conditions));
unitAI = nan(nRows, numel(conditions));

for iCond = 1:numel(conditions)
    midAI(:, iCond) = MIDTable.(midAIVars{iCond})(1:nRows);
end

unitAISizeOK = false(nRows, 1);
stimElecOK = false(nRows, 1);

for iRow = 1:nRows
    thisAI = unit_table.AI{iRow};
    thisStimElec = unit_table.StimElec(iRow);

    unitAISizeOK(iRow) = isnumeric(thisAI) && ismatrix(thisAI) && size(thisAI, 1) >= numel(conditions);
    stimElecOK(iRow) = unitAISizeOK(iRow) && thisStimElec >= 1 && thisStimElec <= size(thisAI, 2);

    if stimElecOK(iRow)
        unitAI(iRow, :) = thisAI(1:numel(conditions), thisStimElec).';
    end
end

dateMatch = MIDTable.Date(1:nRows) == unit_table.Date(1:nRows);
monkeyMatch = strcmp(string(MIDTable.Monkey(1:nRows)), string(unit_table.Monkey(1:nRows)));
roiMatch = strcmp(string(MIDTable.ROI(1:nRows)), string(unit_table.ROI(1:nRows)));
stimElecMatch = MIDTable.StimElec(1:nRows) == unit_table.StimElec(1:nRows);

keyMatch = dateMatch & monkeyMatch & roiMatch;
rowIdentityMatch = keyMatch & stimElecMatch;

aiDiff = midAI - unitAI;
aiMatch = abs(aiDiff) <= tol | (isnan(midAI) & isnan(unitAI));
aiRowMatch = all(aiMatch, 2);

rowID = repelem((1:nRows).', numel(conditions));
condName = repmat(string(conditions(:)), nRows, 1);
midAICol = reshape(midAI.', [], 1);
unitAICol = reshape(unitAI.', [], 1);
diffCol = reshape(aiDiff.', [], 1);
aiMatchCol = reshape(aiMatch.', [], 1);

comparison = table( ...
    rowID, ...
    MIDTable.Date(rowID), ...
    string(MIDTable.Monkey(rowID)), ...
    string(unit_table.Monkey(rowID)), ...
    string(MIDTable.ROI(rowID)), ...
    string(unit_table.ROI(rowID)), ...
    MIDTable.StimElec(rowID), ...
    unit_table.StimElec(rowID), ...
    condName, ...
    midAICol, ...
    unitAICol, ...
    diffCol, ...
    aiMatchCol, ...
    'VariableNames', { ...
        'RowIndex', 'Date', 'MID_Monkey', 'Unit_Monkey', 'MID_ROI', 'Unit_ROI', ...
        'MID_StimElec', 'Unit_StimElec', 'Condition', 'MID_AI', 'Unit_AI', ...
        'MIDMinusUnit', 'AIMatch'});

rowSummary = table( ...
    (1:nRows).', ...
    MIDTable.Date(1:nRows), ...
    string(MIDTable.Monkey(1:nRows)), ...
    string(unit_table.Monkey(1:nRows)), ...
    string(MIDTable.ROI(1:nRows)), ...
    string(unit_table.ROI(1:nRows)), ...
    MIDTable.StimElec(1:nRows), ...
    unit_table.StimElec(1:nRows), ...
    dateMatch, ...
    monkeyMatch, ...
    roiMatch, ...
    stimElecMatch, ...
    rowIdentityMatch, ...
    aiRowMatch, ...
    max(abs(aiDiff), [], 2, 'omitnan'), ...
    'VariableNames', { ...
        'RowIndex', 'Date', 'MID_Monkey', 'Unit_Monkey', 'MID_ROI', 'Unit_ROI', ...
        'MID_StimElec', 'Unit_StimElec', 'DateMatch', 'MonkeyMatch', ...
        'ROIMatch', 'StimElecMatch', 'RowIdentityMatch', 'AIRowMatch', ...
        'MaxAbsAIDiff'});

outDetail = fullfile(comparisonDir, 'MIDTable_20260513_vs_UnitTable_updating_AIComparison.csv');
outRows = fullfile(comparisonDir, 'MIDTable_20260513_vs_UnitTable_updating_RowSummary.csv');
outSummary = fullfile(comparisonDir, 'MIDTable_20260513_vs_UnitTable_updating_Summary.txt');
writetable(comparison, outDetail);
writetable(rowSummary, outRows);

fid = fopen(outSummary, 'w');
cleanupObj = onCleanup(@() fclose(fid));

fprintf(fid, 'MID rows: %d\n', nMID);
fprintf(fid, 'Unit rows: %d\n', nUnit);
fprintf(fid, 'Compared rows: %d\n', nRows);
fprintf(fid, 'Date mismatches: %d\n', sum(~dateMatch));
fprintf(fid, 'Monkey mismatches: %d\n', sum(~monkeyMatch));
fprintf(fid, 'ROI mismatches: %d\n', sum(~roiMatch));
fprintf(fid, 'Date/Monkey/ROI row mismatches: %d\n', sum(~keyMatch));
fprintf(fid, 'StimElec mismatches: %d\n', sum(~stimElecMatch));
fprintf(fid, 'Rows with invalid unit_table.AI shape: %d\n', sum(~unitAISizeOK));
fprintf(fid, 'Rows with invalid StimElec index: %d\n', sum(~stimElecOK));
fprintf(fid, 'AI mismatching rows at tolerance %.1e: %d\n', tol, sum(~aiRowMatch));
fprintf(fid, 'AI mismatching values at tolerance %.1e: %d of %d\n', tol, sum(~aiMatch, 'all'), numel(aiMatch));
fprintf(fid, 'Max absolute AI difference: %.15g\n', max(abs(aiDiff), [], 'all', 'omitnan'));

for iCond = 1:numel(conditions)
    fprintf(fid, '%s AI mismatches: %d\n', conditions{iCond}, sum(~aiMatch(:, iCond)));
end

zeroMIDNonzeroUnit = all(midAI == 0, 2) & any(abs(unitAI) > tol, 2);
fprintf(fid, 'Rows with all MID AI values zero but selected Unit AI nonzero: %d\n', sum(zeroMIDNonzeroUnit));

issueRows = find(~rowIdentityMatch | ~aiRowMatch);
fprintf(fid, 'Rows with any identity or AI issue:\n');
fprintf(fid, '%d ', issueRows);
fprintf(fid, '\n');

fprintf(fid, 'Wrote detail CSV: %s\n', outDetail);
fprintf(fid, 'Wrote row summary CSV: %s\n', outRows);
fprintf(fid, 'Wrote summary TXT: %s\n', outSummary);

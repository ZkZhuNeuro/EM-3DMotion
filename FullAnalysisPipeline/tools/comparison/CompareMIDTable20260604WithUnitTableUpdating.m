%% Compare MIDTable_20260604 unit_table against UnitTable_updating

outputRoot = 'C:\EM\FullAnalysisPipeline_Outputs_20260604';
outputDir = fullfile(outputRoot, 'MIDTable_20260604_UnitTableComparison');
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

newPath = resolveMatPath('C:\EM\PopulationAnalysis\MIDTable_20260604');
refPath = resolveMatPath('C:\EM\PopulationAnalysis\UnitTable_updating');

newData = load(newPath);
refData = load(refPath);

newTable = getUnitTable(newData, newPath);
refTable = getUnitTable(refData, refPath);

conditionNames = {'Combined','MonoL','MonoR','Stereo'};
tuningCoherence = [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22]./22;

knownMissingMask = strcmp(asText(refTable.Monkey), 'Jim') & dateshift(refTable.Date, 'start', 'day') == datetime(2024, 5, 24);
knownMissingRows = find(knownMissingMask);
refComparable = refTable(~knownMissingMask, :);

nRows = min(height(newTable), height(refComparable));
rowReport = table();
aiStimDiffMatrix = nan(nRows, 4);
tuningStimLongReport = table();
tuningStimEdge8LongReport = table();

for iRow = 1:nRows
    refSourceRow = iRow + nnz(knownMissingRows <= iRow);
    newAI = getNumericCellValue(newTable.AI, iRow);
    refAI = getNumericCellValue(refComparable.AI, iRow);
    newStimElec = newTable.StimElec(iRow);
    refStimElec = refComparable.StimElec(iRow);
    stimElec = refStimElec;

    [fullAiEqual, fullAiMaxAbsDiff, fullAiNonNanDiffCount, fullAiSizeMismatch] = compareNumericArrays(newAI, refAI);
    newStimAI = getStimAI(newAI, stimElec);
    refStimAI = getStimAI(refAI, stimElec);
    [stimAiEqual, stimAiMaxAbsDiff, stimAiNonNanDiffCount, stimAiSizeMismatch] = compareNumericArrays(newStimAI, refStimAI);
    if numel(newStimAI) == 4 && numel(refStimAI) == 4
        aiStimDiffMatrix(iRow, :) = newStimAI(:).' - refStimAI(:).';
    end

    newTuningMean = getNumericCellValue(newTable.tuning_mean, iRow);
    refTuningMean = getNumericCellValue(refComparable.tuning_mean, iRow);
    [tuningMeanFullEqual, tuningMeanFullMaxAbsDiff, tuningMeanFullNonNanDiffCount, tuningMeanFullSizeMismatch] = compareNumericArrays(newTuningMean, refTuningMean);
    newTuningMeanNoZero = removeCoherenceSlots(newTuningMean, tuningCoherence == 0);
    refTuningMeanNoZero = removeCoherenceSlots(refTuningMean, tuningCoherence == 0);
    [tuningMeanFullNoZeroEqual, tuningMeanFullNoZeroMaxAbsDiff, tuningMeanFullNoZeroNonNanDiffCount, tuningMeanFullNoZeroSizeMismatch] = compareNumericArrays(newTuningMeanNoZero, refTuningMeanNoZero);
    [newTuningMeanEdge8, edgeCoherence] = selectEdgeCoherenceSlots(newTuningMean);
    [refTuningMeanEdge8, ~] = selectEdgeCoherenceSlots(refTuningMean);
    [tuningMeanFullEdge8Equal, tuningMeanFullEdge8MaxAbsDiff, tuningMeanFullEdge8NonNanDiffCount, tuningMeanFullEdge8SizeMismatch] = compareNumericArrays(newTuningMeanEdge8, refTuningMeanEdge8);
    newStimTuningMean = getStimTuning(newTuningMean, stimElec);
    refStimTuningMean = getStimTuning(refTuningMean, stimElec);
    [tuningMeanStimEqual, tuningMeanStimMaxAbsDiff, tuningMeanStimNonNanDiffCount, tuningMeanStimSizeMismatch] = compareNumericArrays(newStimTuningMean, refStimTuningMean);
    newStimTuningMeanNoZero = removeCoherenceSlots(newStimTuningMean, tuningCoherence == 0);
    refStimTuningMeanNoZero = removeCoherenceSlots(refStimTuningMean, tuningCoherence == 0);
    [tuningMeanStimNoZeroEqual, tuningMeanStimNoZeroMaxAbsDiff, tuningMeanStimNoZeroNonNanDiffCount, tuningMeanStimNoZeroSizeMismatch] = compareNumericArrays(newStimTuningMeanNoZero, refStimTuningMeanNoZero);
    [newStimTuningMeanEdge8, edgeCoherence] = selectEdgeCoherenceSlots(newStimTuningMean);
    [refStimTuningMeanEdge8, ~] = selectEdgeCoherenceSlots(refStimTuningMean);
    [tuningMeanStimEdge8Equal, tuningMeanStimEdge8MaxAbsDiff, tuningMeanStimEdge8NonNanDiffCount, tuningMeanStimEdge8SizeMismatch] = compareNumericArrays(newStimTuningMeanEdge8, refStimTuningMeanEdge8);
    tuningStimCondMaxDiff = computeConditionMaxAbsDiff(newStimTuningMean, refStimTuningMean);

    temp = table();
    temp.RowIndex = iRow;
    temp.NewSourceRow = iRow;
    temp.RefSourceRow = refSourceRow;
    temp.DateMatch = dateshift(newTable.Date(iRow), 'start', 'day') == dateshift(refComparable.Date(iRow), 'start', 'day');
    temp.MonkeyMatch = strcmp(asText(newTable.Monkey(iRow)), asText(refComparable.Monkey(iRow)));
    temp.ROIMatch = strcmp(asText(newTable.ROI(iRow)), asText(refComparable.ROI(iRow)));
    temp.StimElecMatch = newStimElec == refStimElec;
    temp.NewDate = newTable.Date(iRow);
    temp.RefDate = refComparable.Date(iRow);
    temp.NewMonkey = {asText(newTable.Monkey(iRow))};
    temp.RefMonkey = {asText(refComparable.Monkey(iRow))};
    temp.NewROI = {asText(newTable.ROI(iRow))};
    temp.RefROI = {asText(refComparable.ROI(iRow))};
    temp.NewStimElec = newStimElec;
    temp.RefStimElec = refStimElec;
    temp.FullAIEqual = fullAiEqual;
    temp.FullAIMaxAbsDiff = fullAiMaxAbsDiff;
    temp.FullAINonNanDiffCount = fullAiNonNanDiffCount;
    temp.FullAISizeMismatch = fullAiSizeMismatch;
    temp.StimAIEqual = stimAiEqual;
    temp.StimAIMaxAbsDiff = stimAiMaxAbsDiff;
    temp.StimAINonNanDiffCount = stimAiNonNanDiffCount;
    temp.StimAISizeMismatch = stimAiSizeMismatch;
    temp.NewStimAI = {mat2str(newStimAI, 8)};
    temp.RefStimAI = {mat2str(refStimAI, 8)};
    temp.TuningMeanFullEqual = tuningMeanFullEqual;
    temp.TuningMeanFullMaxAbsDiff = tuningMeanFullMaxAbsDiff;
    temp.TuningMeanFullNonNanDiffCount = tuningMeanFullNonNanDiffCount;
    temp.TuningMeanFullSizeMismatch = tuningMeanFullSizeMismatch;
    temp.TuningMeanFullNoZeroEqual = tuningMeanFullNoZeroEqual;
    temp.TuningMeanFullNoZeroMaxAbsDiff = tuningMeanFullNoZeroMaxAbsDiff;
    temp.TuningMeanFullNoZeroNonNanDiffCount = tuningMeanFullNoZeroNonNanDiffCount;
    temp.TuningMeanFullNoZeroSizeMismatch = tuningMeanFullNoZeroSizeMismatch;
    temp.TuningMeanFullEdge8Equal = tuningMeanFullEdge8Equal;
    temp.TuningMeanFullEdge8MaxAbsDiff = tuningMeanFullEdge8MaxAbsDiff;
    temp.TuningMeanFullEdge8NonNanDiffCount = tuningMeanFullEdge8NonNanDiffCount;
    temp.TuningMeanFullEdge8SizeMismatch = tuningMeanFullEdge8SizeMismatch;
    temp.TuningMeanStimEqual = tuningMeanStimEqual;
    temp.TuningMeanStimMaxAbsDiff = tuningMeanStimMaxAbsDiff;
    temp.TuningMeanStimNonNanDiffCount = tuningMeanStimNonNanDiffCount;
    temp.TuningMeanStimSizeMismatch = tuningMeanStimSizeMismatch;
    temp.TuningMeanStimNoZeroEqual = tuningMeanStimNoZeroEqual;
    temp.TuningMeanStimNoZeroMaxAbsDiff = tuningMeanStimNoZeroMaxAbsDiff;
    temp.TuningMeanStimNoZeroNonNanDiffCount = tuningMeanStimNoZeroNonNanDiffCount;
    temp.TuningMeanStimNoZeroSizeMismatch = tuningMeanStimNoZeroSizeMismatch;
    temp.TuningMeanStimEdge8Equal = tuningMeanStimEdge8Equal;
    temp.TuningMeanStimEdge8MaxAbsDiff = tuningMeanStimEdge8MaxAbsDiff;
    temp.TuningMeanStimEdge8NonNanDiffCount = tuningMeanStimEdge8NonNanDiffCount;
    temp.TuningMeanStimEdge8SizeMismatch = tuningMeanStimEdge8SizeMismatch;
    temp.TuningStimMaxDiff_Combined = tuningStimCondMaxDiff(1);
    temp.TuningStimMaxDiff_MonoL = tuningStimCondMaxDiff(2);
    temp.TuningStimMaxDiff_MonoR = tuningStimCondMaxDiff(3);
    temp.TuningStimMaxDiff_Stereo = tuningStimCondMaxDiff(4);
    rowReport = [rowReport; temp]; %#ok<AGROW>
    tuningStimLongReport = [tuningStimLongReport; buildTuningStimLongRows(iRow, refSourceRow, newTable, refComparable, stimElec, ...
        newStimTuningMean, refStimTuningMean, conditionNames, tuningCoherence)]; %#ok<AGROW>
    tuningStimEdge8LongReport = [tuningStimEdge8LongReport; buildTuningStimLongRows(iRow, refSourceRow, newTable, refComparable, stimElec, ...
        newStimTuningMeanEdge8, refStimTuningMeanEdge8, conditionNames, edgeCoherence)]; %#ok<AGROW>
end

extraNewRows = height(newTable) - nRows;
extraRefRows = height(refComparable) - nRows;
alignmentMismatch = ~rowReport.DateMatch | ~rowReport.MonkeyMatch | ~rowReport.ROIMatch | ~rowReport.StimElecMatch;
stimAiMismatch = ~rowReport.StimAIEqual;
fullAiMismatch = ~rowReport.FullAIEqual;
tuningMeanStimMismatch = ~rowReport.TuningMeanStimEqual;
tuningMeanFullMismatch = ~rowReport.TuningMeanFullEqual;
tuningMeanStimNoZeroMismatch = ~rowReport.TuningMeanStimNoZeroEqual;
tuningMeanFullNoZeroMismatch = ~rowReport.TuningMeanFullNoZeroEqual;
tuningMeanStimEdge8Mismatch = ~rowReport.TuningMeanStimEdge8Equal;
tuningMeanFullEdge8Mismatch = ~rowReport.TuningMeanFullEdge8Equal;

rowReportPath = fullfile(outputDir, 'MIDTable_20260604_vs_UnitTable_updating_row_report.csv');
aiStimDiffPath = fullfile(outputDir, 'MIDTable_20260604_vs_UnitTable_updating_AI_stim_diff_253x4.csv');
aiStimDiffMetaPath = fullfile(outputDir, 'MIDTable_20260604_vs_UnitTable_updating_AI_stim_diff_with_metadata.csv');
tuningMeanRowReportPath = fullfile(outputDir, 'MIDTable_20260604_vs_UnitTable_updating_tuning_mean_row_report.csv');
tuningMeanStimLongPath = fullfile(outputDir, 'MIDTable_20260604_vs_UnitTable_updating_tuning_mean_stim_long.csv');
tuningMeanStimEdge8LongPath = fullfile(outputDir, 'MIDTable_20260604_vs_UnitTable_updating_tuning_mean_stim_edge8_long.csv');
summaryPath = fullfile(outputDir, 'MIDTable_20260604_vs_UnitTable_updating_summary.txt');
[rowReportPath, rowReportFallbackMessage] = writeTableWithFallback(rowReport, rowReportPath);
[aiStimDiffPath, aiStimDiffFallbackMessage] = writeTableWithFallback(array2table(aiStimDiffMatrix, 'VariableNames', conditionNames), aiStimDiffPath);
aiStimDiffMetaTable = rowReport(:, {'RowIndex','NewSourceRow','RefSourceRow','NewMonkey','NewDate','NewROI','NewStimElec'});
aiStimDiffMetaTable.AI_Diff_Combined = aiStimDiffMatrix(:, 1);
aiStimDiffMetaTable.AI_Diff_MonoL = aiStimDiffMatrix(:, 2);
aiStimDiffMetaTable.AI_Diff_MonoR = aiStimDiffMatrix(:, 3);
aiStimDiffMetaTable.AI_Diff_Stereo = aiStimDiffMatrix(:, 4);
[aiStimDiffMetaPath, aiStimDiffMetaFallbackMessage] = writeTableWithFallback(aiStimDiffMetaTable, aiStimDiffMetaPath);
tuningMeanRowReport = rowReport(:, {'RowIndex','NewSourceRow','RefSourceRow','NewMonkey','NewDate','NewROI','NewStimElec', ...
    'TuningMeanFullEqual','TuningMeanFullMaxAbsDiff','TuningMeanFullNonNanDiffCount','TuningMeanFullSizeMismatch', ...
    'TuningMeanFullNoZeroEqual','TuningMeanFullNoZeroMaxAbsDiff','TuningMeanFullNoZeroNonNanDiffCount','TuningMeanFullNoZeroSizeMismatch', ...
    'TuningMeanFullEdge8Equal','TuningMeanFullEdge8MaxAbsDiff','TuningMeanFullEdge8NonNanDiffCount','TuningMeanFullEdge8SizeMismatch', ...
    'TuningMeanStimEqual','TuningMeanStimMaxAbsDiff','TuningMeanStimNonNanDiffCount','TuningMeanStimSizeMismatch', ...
    'TuningMeanStimNoZeroEqual','TuningMeanStimNoZeroMaxAbsDiff','TuningMeanStimNoZeroNonNanDiffCount','TuningMeanStimNoZeroSizeMismatch', ...
    'TuningMeanStimEdge8Equal','TuningMeanStimEdge8MaxAbsDiff','TuningMeanStimEdge8NonNanDiffCount','TuningMeanStimEdge8SizeMismatch', ...
    'TuningStimMaxDiff_Combined','TuningStimMaxDiff_MonoL','TuningStimMaxDiff_MonoR','TuningStimMaxDiff_Stereo'});
[tuningMeanRowReportPath, tuningMeanRowFallbackMessage] = writeTableWithFallback(tuningMeanRowReport, tuningMeanRowReportPath);
[tuningMeanStimLongPath, tuningMeanStimLongFallbackMessage] = writeTableWithFallback(tuningStimLongReport, tuningMeanStimLongPath);
[tuningMeanStimEdge8LongPath, tuningMeanStimEdge8LongFallbackMessage] = writeTableWithFallback(tuningStimEdge8LongReport, tuningMeanStimEdge8LongPath);

[fid, summaryPath, summaryFallbackMessage] = fopenWithFallback(summaryPath);
cleanup = onCleanup(@() fclose(fid));
if ~isempty(rowReportFallbackMessage)
    fprintf(fid, '%s\n', rowReportFallbackMessage);
end
if ~isempty(aiStimDiffFallbackMessage)
    fprintf(fid, '%s\n', aiStimDiffFallbackMessage);
end
if ~isempty(aiStimDiffMetaFallbackMessage)
    fprintf(fid, '%s\n', aiStimDiffMetaFallbackMessage);
end
if ~isempty(tuningMeanRowFallbackMessage)
    fprintf(fid, '%s\n', tuningMeanRowFallbackMessage);
end
if ~isempty(tuningMeanStimLongFallbackMessage)
    fprintf(fid, '%s\n', tuningMeanStimLongFallbackMessage);
end
if ~isempty(tuningMeanStimEdge8LongFallbackMessage)
    fprintf(fid, '%s\n', tuningMeanStimEdge8LongFallbackMessage);
end
if ~isempty(summaryFallbackMessage)
    fprintf(fid, '%s\n', summaryFallbackMessage);
end
fprintf(fid, 'newPath=%s\n', newPath);
fprintf(fid, 'refPath=%s\n', refPath);
fprintf(fid, 'differenceSign=newMinusReference\n');
fprintf(fid, 'aiStimDiff253x4Path=%s\n', aiStimDiffPath);
fprintf(fid, 'aiStimDiffWithMetadataPath=%s\n', aiStimDiffMetaPath);
fprintf(fid, 'tuningMeanRowReportPath=%s\n', tuningMeanRowReportPath);
fprintf(fid, 'tuningMeanStimLongPath=%s\n', tuningMeanStimLongPath);
fprintf(fid, 'tuningMeanStimEdge8LongPath=%s\n', tuningMeanStimEdge8LongPath);
fprintf(fid, 'newHeight=%d\n', height(newTable));
fprintf(fid, 'refHeight=%d\n', height(refTable));
fprintf(fid, 'knownMissingReferenceRows=%s\n', mat2str(knownMissingRows.'));
for iMissing = knownMissingRows.'
    fprintf(fid, 'knownMissing row=%d Monkey=%s Date=%s ROI=%s StimElec=%g\n', ...
        iMissing, asText(refTable.Monkey(iMissing)), datestr(refTable.Date(iMissing), 'yyyy-mm-dd'), ...
        asText(refTable.ROI(iMissing)), refTable.StimElec(iMissing));
end
fprintf(fid, 'refComparableHeight=%d\n', height(refComparable));
fprintf(fid, 'comparedRows=%d\n', nRows);
fprintf(fid, 'extraNewRows=%d\n', extraNewRows);
fprintf(fid, 'extraReferenceRowsAfterDroppingKnownMissing=%d\n', extraRefRows);
fprintf(fid, 'alignmentMismatchCount=%d\n', nnz(alignmentMismatch));
fprintf(fid, 'dateMismatchCount=%d\n', nnz(~rowReport.DateMatch));
fprintf(fid, 'monkeyMismatchCount=%d\n', nnz(~rowReport.MonkeyMatch));
fprintf(fid, 'roiMismatchCount=%d\n', nnz(~rowReport.ROIMatch));
fprintf(fid, 'stimElecMismatchCount=%d\n', nnz(~rowReport.StimElecMatch));
fprintf(fid, 'stimAIMismatchCount=%d\n', nnz(stimAiMismatch));
fprintf(fid, 'fullAIMismatchCount=%d\n', nnz(fullAiMismatch));
fprintf(fid, 'maxStimAIDiff=%g\n', max(rowReport.StimAIMaxAbsDiff, [], 'omitnan'));
fprintf(fid, 'maxFullAIDiff=%g\n', max(rowReport.FullAIMaxAbsDiff, [], 'omitnan'));
fprintf(fid, 'tuningMeanStimMismatchCount=%d\n', nnz(tuningMeanStimMismatch));
fprintf(fid, 'tuningMeanFullMismatchCount=%d\n', nnz(tuningMeanFullMismatch));
fprintf(fid, 'maxTuningMeanStimDiff=%g\n', max(rowReport.TuningMeanStimMaxAbsDiff, [], 'omitnan'));
fprintf(fid, 'maxTuningMeanFullDiff=%g\n', max(rowReport.TuningMeanFullMaxAbsDiff, [], 'omitnan'));
fprintf(fid, 'tuningMeanStimNoZeroMismatchCount=%d\n', nnz(tuningMeanStimNoZeroMismatch));
fprintf(fid, 'tuningMeanFullNoZeroMismatchCount=%d\n', nnz(tuningMeanFullNoZeroMismatch));
fprintf(fid, 'maxTuningMeanStimNoZeroDiff=%g\n', max(rowReport.TuningMeanStimNoZeroMaxAbsDiff, [], 'omitnan'));
fprintf(fid, 'maxTuningMeanFullNoZeroDiff=%g\n', max(rowReport.TuningMeanFullNoZeroMaxAbsDiff, [], 'omitnan'));
fprintf(fid, 'tuningMeanStimEdge8MismatchCount=%d\n', nnz(tuningMeanStimEdge8Mismatch));
fprintf(fid, 'tuningMeanFullEdge8MismatchCount=%d\n', nnz(tuningMeanFullEdge8Mismatch));
fprintf(fid, 'maxTuningMeanStimEdge8Diff=%g\n', max(rowReport.TuningMeanStimEdge8MaxAbsDiff, [], 'omitnan'));
fprintf(fid, 'maxTuningMeanFullEdge8Diff=%g\n', max(rowReport.TuningMeanFullEdge8MaxAbsDiff, [], 'omitnan'));

writeRows(fid, 'alignmentMismatchRows', rowReport.RowIndex(alignmentMismatch));
writeRows(fid, 'stimAIMismatchRows', rowReport.RowIndex(stimAiMismatch));
writeRows(fid, 'fullAIMismatchRows', rowReport.RowIndex(fullAiMismatch));
writeRows(fid, 'tuningMeanStimMismatchRows', rowReport.RowIndex(tuningMeanStimMismatch));
writeRows(fid, 'tuningMeanFullMismatchRows', rowReport.RowIndex(tuningMeanFullMismatch));
writeRows(fid, 'tuningMeanStimNoZeroMismatchRows', rowReport.RowIndex(tuningMeanStimNoZeroMismatch));
writeRows(fid, 'tuningMeanFullNoZeroMismatchRows', rowReport.RowIndex(tuningMeanFullNoZeroMismatch));
writeRows(fid, 'tuningMeanStimEdge8MismatchRows', rowReport.RowIndex(tuningMeanStimEdge8Mismatch));
writeRows(fid, 'tuningMeanFullEdge8MismatchRows', rowReport.RowIndex(tuningMeanFullEdge8Mismatch));

fprintf('Wrote %s\n', summaryPath);
fprintf('Wrote %s\n', rowReportPath);

function matPath = resolveMatPath(pathText)
if exist(pathText, 'file')
    matPath = pathText;
elseif exist([pathText '.mat'], 'file')
    matPath = [pathText '.mat'];
else
    error('Could not find MAT file: %s', pathText);
end
end

function unitTable = getUnitTable(dataStruct, sourcePath)
if isfield(dataStruct, 'unit_table')
    unitTable = dataStruct.unit_table;
    return
end

fieldNames = fieldnames(dataStruct);
for iField = 1:numel(fieldNames)
    value = dataStruct.(fieldNames{iField});
    if istable(value)
        unitTable = value;
        return
    end
end
error('Could not find unit_table or another table variable in %s', sourcePath);
end

function textValue = asText(value)
if iscell(value)
    value = value{1};
end
if isstring(value)
    textValue = char(value);
elseif ischar(value)
    textValue = value;
elseif iscategorical(value)
    textValue = char(value);
else
    textValue = char(string(value));
end
end

function value = getNumericCellValue(columnValue, rowIndex)
value = columnValue{rowIndex};
if isempty(value)
    value = nan;
end
end

function stimAI = getStimAI(aiValue, stimElec)
if isnumeric(aiValue) && ismatrix(aiValue) && stimElec >= 1 && stimElec <= size(aiValue, 2)
    stimAI = aiValue(:, stimElec);
else
    stimAI = nan(4, 1);
end
end

function stimTuning = getStimTuning(tuningMean, stimElec)
if isnumeric(tuningMean) && ndims(tuningMean) == 3 && size(tuningMean, 1) == 4 && stimElec >= 1 && stimElec <= size(tuningMean, 3)
    stimTuning = squeeze(tuningMean(:, :, stimElec));
else
    stimTuning = nan(4, 13);
end
if isvector(stimTuning)
    stimTuning = reshape(stimTuning, 4, []);
end
end

function conditionMaxDiff = computeConditionMaxAbsDiff(newStimTuning, refStimTuning)
conditionMaxDiff = nan(1, 4);
if ~isequal(size(newStimTuning), size(refStimTuning)) || size(newStimTuning, 1) ~= 4
    return
end
for cond = 1:4
    diffValue = abs(newStimTuning(cond, :) - refStimTuning(cond, :));
    conditionMaxDiff(cond) = max(diffValue(:), [], 'omitnan');
end
end

function valuesNoSlots = removeCoherenceSlots(values, removeMask)
valuesNoSlots = values;
if ~isnumeric(values)
    return
end

keepMask = ~removeMask;
if ismatrix(values) && size(values, 2) == numel(removeMask)
    valuesNoSlots = values(:, keepMask);
elseif ndims(values) == 3 && size(values, 2) == numel(removeMask)
    valuesNoSlots = values(:, keepMask, :);
end
end

function [edgeValues, edgeCoherence] = selectEdgeCoherenceSlots(values)
edgeValues = values;
edgeCoherence = [];
if ~isnumeric(values)
    return
end

if ismatrix(values)
    nCoherence = size(values, 2);
elseif ndims(values) == 3
    nCoherence = size(values, 2);
else
    return
end

if nCoherence == 13
    coherenceValues = [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22]./22;
elseif nCoherence == 12
    coherenceValues = [-22 -14 -10 -8 -4 -2 2 4 8 10 14 22]./22;
else
    coherenceValues = 1:nCoherence;
end

edgeIdx = unique([1:min(4, nCoherence), max(1, nCoherence - 3):nCoherence], 'stable');
edgeCoherence = coherenceValues(edgeIdx);
if ismatrix(values)
    edgeValues = values(:, edgeIdx);
else
    edgeValues = values(:, edgeIdx, :);
end
end

function longRows = buildTuningStimLongRows(rowIndex, refSourceRow, newTable, refComparable, stimElec, newStimTuning, refStimTuning, conditionNames, tuningCoherence)
if ~isequal(size(newStimTuning), size(refStimTuning))
    newStimTuning = nan(4, numel(tuningCoherence));
    refStimTuning = nan(4, numel(tuningCoherence));
end

nConditions = size(newStimTuning, 1);
nCoherence = size(newStimTuning, 2);
[conditionIndex, coherenceIndex] = ndgrid(1:nConditions, 1:nCoherence);
nRows = numel(conditionIndex);

longRows = table();
longRows.RowIndex = repmat(rowIndex, nRows, 1);
longRows.NewSourceRow = repmat(rowIndex, nRows, 1);
longRows.RefSourceRow = repmat(refSourceRow, nRows, 1);
longRows.NewDate = repmat(newTable.Date(rowIndex), nRows, 1);
longRows.RefDate = repmat(refComparable.Date(rowIndex), nRows, 1);
longRows.NewMonkey = repmat({asText(newTable.Monkey(rowIndex))}, nRows, 1);
longRows.RefMonkey = repmat({asText(refComparable.Monkey(rowIndex))}, nRows, 1);
longRows.NewROI = repmat({asText(newTable.ROI(rowIndex))}, nRows, 1);
longRows.RefROI = repmat({asText(refComparable.ROI(rowIndex))}, nRows, 1);
longRows.StimElec = repmat(stimElec, nRows, 1);
longRows.ConditionIndex = conditionIndex(:);
longRows.Condition = conditionNames(conditionIndex(:)).';
longRows.Condition = longRows.Condition(:);
longRows.CoherenceIndex = coherenceIndex(:);
longRows.Coherence = tuningCoherence(coherenceIndex(:)).';
longRows.NewTuningMean = newStimTuning(:);
longRows.RefTuningMean = refStimTuning(:);
longRows.Diff_NewMinusRef = longRows.NewTuningMean - longRows.RefTuningMean;
end

function [arraysEqual, maxAbsDiff, nonNanDiffCount, sizeMismatch] = compareNumericArrays(a, b)
sizeMismatch = ~isequal(size(a), size(b));
if sizeMismatch
    arraysEqual = false;
    maxAbsDiff = nan;
    nonNanDiffCount = nan;
    return
end

nanMask = isnan(a) & isnan(b);
diffValue = abs(a - b);
diffValue(nanMask) = 0;
nonNanDiffCount = nnz(diffValue > 1e-10 | xor(isnan(a), isnan(b)));
if isempty(diffValue)
    maxAbsDiff = 0;
else
    maxAbsDiff = max(diffValue(:), [], 'omitnan');
end
arraysEqual = nonNanDiffCount == 0;
end

function writeRows(fid, label, rows)
fprintf(fid, '%s=', label);
if isempty(rows)
    fprintf(fid, '[]\n');
else
    fprintf(fid, '%s\n', mat2str(rows.'));
end
end

function [writtenPath, fallbackMessage] = writeTableWithFallback(tableValue, requestedPath)
fallbackMessage = '';
writtenPath = requestedPath;
try
    writetable(tableValue, writtenPath);
catch ME
    writtenPath = makeTimestampedPath(requestedPath);
    fallbackMessage = sprintf('Requested row report path was locked; wrote fallback path instead. requestedPath=%s fallbackPath=%s originalError=%s', ...
        requestedPath, writtenPath, ME.message);
    writetable(tableValue, writtenPath);
end
end

function [fid, writtenPath, fallbackMessage] = fopenWithFallback(requestedPath)
fallbackMessage = '';
writtenPath = requestedPath;
[fid, message] = fopen(writtenPath, 'w');
if fid >= 0
    return
end

writtenPath = makeTimestampedPath(requestedPath);
fallbackMessage = sprintf('Requested summary path was locked; wrote fallback path instead. requestedPath=%s fallbackPath=%s originalError=%s', ...
    requestedPath, writtenPath, message);
[fid, message] = fopen(writtenPath, 'w');
if fid < 0
    error('Unable to open summary file for writing: %s. Last error: %s', writtenPath, message);
end
end

function fallbackPath = makeTimestampedPath(requestedPath)
[folderPath, fileName, fileExt] = fileparts(requestedPath);
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
fallbackPath = fullfile(folderPath, sprintf('%s_%s%s', fileName, timestamp, fileExt));
suffix = 1;
while exist(fallbackPath, 'file')
    fallbackPath = fullfile(folderPath, sprintf('%s_%s_%02d%s', fileName, timestamp, suffix, fileExt));
    suffix = suffix + 1;
end
end

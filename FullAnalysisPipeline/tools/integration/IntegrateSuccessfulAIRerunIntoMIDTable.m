%% Integrate successful all-zero AI reruns into MIDTable_20260513

clearvars
repoRoot = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\FullAnalysisPipeline';
cd(repoRoot);

populationDir = 'C:\EM\PopulationAnalysis';
outputRoot = 'C:\EM\FullAnalysisPipeline_Outputs_20260604';
rerunDir = fullfile(outputRoot, 'MIDTable_20260513_AllZeroAIRerun');
sourcePath = fullfile(populationDir, 'MIDTable_20260513.mat');
outputPath = fullfile(populationDir, 'MIDTable_20260602.mat');
rerunMatPath = fullfile(rerunDir, ...
    'AllZeroAIRerunSummary_afterQuickSelectionFix.mat');
integrationCsvPath = fullfile(rerunDir, ...
    'MIDTable_20260602_AIIntegrationSummary.csv');
skippedCsvPath = fullfile(rerunDir, ...
    'BuildMIDTable_SkippedSessions_afterQuickSelectionFix.csv');

sourceData = load(sourcePath, 'MIDTable');
MIDTable = sourceData.MIDTable;
rerunData = load(rerunMatPath, 'summary');
summary = rerunData.summary;

successMask = strcmp(summary.Status, 'Success');
successRows = find(successMask);

Old_Combined_AI = nan(numel(successRows), 1);
Old_MonoL_AI = nan(numel(successRows), 1);
Old_MonoR_AI = nan(numel(successRows), 1);
Old_Stereo_AI = nan(numel(successRows), 1);

for iRow = 1:numel(successRows)
    summaryRow = successRows(iRow);
    sourceRow = summary.SourceRowIndex(summaryRow);

    Old_Combined_AI(iRow) = MIDTable.Combined_AI(sourceRow);
    Old_MonoL_AI(iRow) = MIDTable.MonoL_AI(sourceRow);
    Old_MonoR_AI(iRow) = MIDTable.MonoR_AI(sourceRow);
    Old_Stereo_AI(iRow) = MIDTable.Stereo_AI(sourceRow);

    MIDTable.Combined_AI(sourceRow) = summary.New_Combined_AI(summaryRow);
    MIDTable.MonoL_AI(sourceRow) = summary.New_MonoL_AI(summaryRow);
    MIDTable.MonoR_AI(sourceRow) = summary.New_MonoR_AI(summaryRow);
    MIDTable.Stereo_AI(sourceRow) = summary.New_Stereo_AI(summaryRow);
end

integrationSummary = summary(successMask, {'SourceRowIndex', 'Monkey', 'Date', 'ROI', ...
    'StimElec', 'WorkbookRow', 'New_Combined_AI', 'New_MonoL_AI', 'New_MonoR_AI', 'New_Stereo_AI'});
integrationSummary.Old_Combined_AI = Old_Combined_AI;
integrationSummary.Old_MonoL_AI = Old_MonoL_AI;
integrationSummary.Old_MonoR_AI = Old_MonoR_AI;
integrationSummary.Old_Stereo_AI = Old_Stereo_AI;
integrationSummary = movevars(integrationSummary, ...
    {'Old_Combined_AI', 'Old_MonoL_AI', 'Old_MonoR_AI', 'Old_Stereo_AI'}, ...
    'Before', 'New_Combined_AI');

save(outputPath, 'MIDTable', '-v7.3');
savedMIDTable = MIDTable;
writetable(integrationSummary, integrationCsvPath);

sessionLimitPerMonkey = inf; %#ok<NASGU>
run(fullfile(repoRoot, 'BuildMIDTable_MUAStim_JimClay.m'));
writetable(SkippedSessions, skippedCsvPath);

fprintf('Saved %s\n', outputPath);
fprintf('Updated successful source rows: %d\n', height(integrationSummary));
fprintf('Remaining all-zero AI rows in saved MIDTable: %d\n', nnz(savedMIDTable.Combined_AI == 0 & ...
    savedMIDTable.MonoL_AI == 0 & savedMIDTable.MonoR_AI == 0 & savedMIDTable.Stereo_AI == 0));
fprintf('Wrote integration summary: %s\n', integrationCsvPath);
fprintf('Wrote skipped-session summary: %s\n', skippedCsvPath);
fprintf('Skipped workbook rows from corrected build: %d\n', height(SkippedSessions));

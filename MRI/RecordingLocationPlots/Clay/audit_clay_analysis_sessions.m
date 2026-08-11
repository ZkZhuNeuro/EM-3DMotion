pipeline_dir = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\FullAnalysisPipeline';
addpath(pipeline_dir);
cd(pipeline_dir);

build_log = evalc("run('BuildMIDTable_MUAStim_JimClay.m')"); %#ok<NASGU>
clay_mask = strcmp(MIDTable.Monkey, 'Clay');
clay_table = MIDTable(clay_mask, :);

audit = repmat(struct('workbookRow', [], 'date', '', 'roi', '', 'hole', [], ...
    'guideTubeMm', [], 'depthMm', [], 'stimElec', []), height(clay_table), 1);
for i = 1:height(clay_table)
    audit(i).workbookRow = clay_table.WorkbookRow(i) + 1;
    audit(i).date = datestr(clay_table.Date(i), 'yyyy-mm-dd');
    audit(i).roi = clay_table.ROI{i};
    audit(i).hole = clay_table.Hole(i, :);
    audit(i).guideTubeMm = clay_table.Guide(i);
    audit(i).depthMm = clay_table.Depth(i);
    audit(i).stimElec = clay_table.StimElec(i);
end

if isempty(SkippedSessions) || ~ismember('Monkey', SkippedSessions.Properties.VariableNames)
    clay_skipped = table();
else
    clay_skipped = SkippedSessions(strcmp(SkippedSessions.Monkey, 'Clay'), :);
end
fprintf('CLAY_ANALYSIS_SESSION_COUNT=%d\n', height(clay_table));
fprintf('CLAY_SKIPPED_AFTER_CRITERIA_COUNT=%d\n', height(clay_skipped));
fprintf('CLAY_ANALYSIS_SESSIONS_JSON=%s\n', jsonencode(audit));
if ~isempty(clay_skipped)
    skipped_audit = table2struct(clay_skipped(:, {'Date', 'WorkbookRow', 'ROI', 'Reason'}));
    fprintf('CLAY_SKIPPED_JSON=%s\n', jsonencode(skipped_audit));
end

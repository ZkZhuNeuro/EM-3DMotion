pipeline_dir = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\FullAnalysisPipeline';
addpath(pipeline_dir);
cd(pipeline_dir);

build_log = evalc("run('BuildMIDTable_MUAStim_JimClay.m')"); %#ok<NASGU>
jim_mask = strcmp(MIDTable.Monkey, 'Jim');
jim_table = MIDTable(jim_mask, :);

audit = repmat(struct('workbookRow', [], 'date', '', 'roi', '', 'hole', [], ...
    'guideTubeMm', [], 'depthMm', [], 'offset', [], 'stimElec', []), height(jim_table), 1);
for i = 1:height(jim_table)
    audit(i).workbookRow = jim_table.WorkbookRow(i) + 1;
    audit(i).date = datestr(jim_table.Date(i), 'yyyy-mm-dd');
    audit(i).roi = jim_table.ROI{i};
    audit(i).hole = jim_table.Hole(i, :);
    audit(i).guideTubeMm = jim_table.Guide(i);
    audit(i).depthMm = jim_table.Depth(i);
    audit(i).offset = jim_table.Offset(i, :);
    audit(i).stimElec = jim_table.StimElec(i);
end

if isempty(SkippedSessions) || ~ismember('Monkey', SkippedSessions.Properties.VariableNames)
    jim_skipped = table();
else
    jim_skipped = SkippedSessions(strcmp(SkippedSessions.Monkey, 'Jim'), :);
end
fprintf('JIM_ANALYSIS_SESSION_COUNT=%d\n', height(jim_table));
fprintf('JIM_SKIPPED_AFTER_CRITERIA_COUNT=%d\n', height(jim_skipped));
fprintf('JIM_ANALYSIS_SESSIONS_JSON=%s\n', jsonencode(audit));
if ~isempty(jim_skipped)
    skipped_audit = table2struct(jim_skipped(:, {'Date', 'WorkbookRow', 'ROI', 'Reason'}));
    fprintf('JIM_SKIPPED_JSON=%s\n', jsonencode(skipped_audit));
end

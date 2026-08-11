scriptDir = fileparts(mfilename('fullpath'));
outputDir = 'C:\EM\RecordingLocationPlots\Clay';
if ~exist(outputDir, 'dir'), mkdir(outputDir); end
diaryPath = fullfile(outputDir, 'clay_unit_table_gof_generation.log');
diary(diaryPath);
fprintf('Clay unit_table_gof regeneration started: %s\n', string(datetime('now')));
try
    run(fullfile(scriptDir, 'generate_clay_analysis_plots.m'));
    clearvars -except scriptDir diaryPath;
    run(fullfile(scriptDir, 'generate_clay_projected_by_y.m'));
    clearvars -except scriptDir diaryPath;
    run(fullfile(scriptDir, 'generate_clay_projected_sagittal.m'));
    fprintf('Clay unit_table_gof regeneration completed: %s\n', string(datetime('now')));
catch ME
    fprintf(2, '%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
    diary off;
    rethrow(ME);
end
diary off;

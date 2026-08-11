scriptDir = fileparts(mfilename('fullpath'));
outputDir = 'C:\EM\RecordingLocationPlots\Jim';
if ~exist(outputDir, 'dir'), mkdir(outputDir); end
diaryPath = fullfile(outputDir, 'jim_unit_table_gof_generation.log');
diary(diaryPath);
fprintf('Jim unit_table_gof regeneration started: %s\n', string(datetime('now')));
try
    generateSessionPlots = true;
    generateCoronalPlots = true;
    generateSagittalPlots = true;
    jimSessionWorkbookRows = [];
    run(fullfile(scriptDir, 'generate_jim_recording_location_plots.m'));
    fprintf('Jim unit_table_gof regeneration completed: %s\n', string(datetime('now')));
catch ME
    fprintf(2, '%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
    diary off;
    rethrow(ME);
end
diary off;

xls_tables = {
    'P:\Clay\NeuroData\RecordingRecord.xlsx'
    'P:\Clay\NeuroData\RecordingRecord_Stimulation.xlsx'
    };
outputDir = fullfile(pwd, 'ClayHoleTrajectoryFigures_AllTables_PositiveX_10to35');
guideDepth = 10;
maxDepth = 35;

summary = PlotClayHoleTrajectoriesMRI(outputDir, guideDepth, maxDepth, xls_tables);
disp(summary);

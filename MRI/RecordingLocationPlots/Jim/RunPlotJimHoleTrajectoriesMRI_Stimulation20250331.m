xls_table = 'P:\Jim\NeuroData\RecordingRecord_Stimulation_20250331.xlsx';
scriptDir = fileparts(mfilename('fullpath'));
outputDir = fullfile(fileparts(fileparts(scriptDir)), ...
    'JimHoleTrajectoryFigures_Stimulation20250331_PositiveX_10to35');
guideDepth = 10;
maxDepth = 35;

summary = PlotJimHoleTrajectoriesMRI(outputDir, guideDepth, maxDepth, xls_table);
disp(summary);

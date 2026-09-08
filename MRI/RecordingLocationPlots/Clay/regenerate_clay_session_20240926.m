workbookRowsToPlot = 21;
claySessionOutputDir = ...
    'C:\EM\RecordingLocationPlots\Clay\SingleSessions';
claySessionDotSize = 32;
claySessionDotColors = [0.00, 0.45, 0.95; 0.00, 0.70, 0.20];
run(fullfile(fileparts(mfilename('fullpath')), ...
    'generate_clay_analysis_plots.m'));

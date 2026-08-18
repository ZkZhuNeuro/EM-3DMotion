%% Clean all-Jim FR meta tuning, select meta-2D, and optimize AI-by-OD weights

clear; close all
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'common'));
[paths, outputDir] = currentSpreadInit(mfilename('fullpath'));

filteredMetaOptimization = ...
    currentSpreadFilteredMetaFRAIODOptimization(paths);
figureHandles = currentSpreadSaveFilteredMetaFRAIODOptimization( ...
    filteredMetaOptimization, outputDir);

disp(filteredMetaOptimization.flowTable)
disp(filteredMetaOptimization.roiFlowTable)
disp(filteredMetaOptimization.summaryTable)
close(figureHandles)
currentSpreadSaveResults(outputDir);

%% Clean Jim MT FR meta tuning, select meta-2D, and optimize AI-by-OD weights

clear; close all
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'common'));
[paths, outputDir] = currentSpreadInit(mfilename('fullpath'));

filteredMetaOptimization = ...
    currentSpreadFilteredMetaFRAIODOptimization(paths, ROI="MT");
figureHandles = currentSpreadSaveFilteredMetaFRAIODOptimization( ...
    filteredMetaOptimization, outputDir);
sessionPlotIndex = currentSpreadSaveIncludedSessionChannelTuning( ...
    filteredMetaOptimization, paths, outputDir);

disp(filteredMetaOptimization.flowTable)
disp(filteredMetaOptimization.roiFlowTable)
disp(filteredMetaOptimization.summaryTable)
disp(sessionPlotIndex(:, 1:7))
close(figureHandles)
currentSpreadSaveResults(outputDir);

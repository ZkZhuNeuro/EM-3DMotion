%% Optimize Gaussian spread on perspective Delta Bias ~ AI + AI:OD

clear; close all
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'common'));
[paths, outputDir] = currentSpreadInit(mfilename('fullpath'));

perspectiveOptimization = ...
    currentSpreadPerspectiveAIODGaussianOptimization(paths);
figureHandles = currentSpreadSavePerspectiveAIODGaussianOptimization( ...
    perspectiveOptimization, outputDir);

disp(perspectiveOptimization.summaryTable)
close(figureHandles)
currentSpreadSaveResults(outputDir);

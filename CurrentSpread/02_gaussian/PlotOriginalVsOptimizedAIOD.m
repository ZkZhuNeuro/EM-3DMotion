%% Original and Gaussian-optimized AI-versus-bias plots with OD modulation

clear; close all
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'common'));
[paths, outputDir] = currentSpreadInit(mfilename('fullpath'));

aiODComparison = currentSpreadPerspectiveAIODComparison(paths);
figureHandle = currentSpreadSavePerspectiveAIODComparison( ...
    aiODComparison, outputDir);
close(figureHandle)
currentSpreadSaveResults(outputDir);

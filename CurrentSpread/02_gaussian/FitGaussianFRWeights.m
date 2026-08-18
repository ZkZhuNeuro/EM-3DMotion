%% Gaussian relative-position weights applied before combined-cue AI calculation

clear; close all
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'common'));
[paths, outputDir] = currentSpreadInit(mfilename('fullpath'));

combinedCueR2 = currentSpreadCombinedCueGaussianSigmaR2( ...
    paths, "gaussian-fr");
figureHandles = currentSpreadSaveCombinedCueGaussianSigmaR2( ...
    combinedCueR2, outputDir);
close(figureHandles)
currentSpreadSaveResults(outputDir);

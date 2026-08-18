%% Gaussian relative-position weights applied to combined-cue channel AI

clear; close all
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'common'));
[paths, outputDir] = currentSpreadInit(mfilename('fullpath'));

combinedCueR2 = currentSpreadCombinedCueGaussianSigmaR2( ...
    paths, "gaussian-ai");
figureHandles = currentSpreadSaveCombinedCueGaussianSigmaR2( ...
    combinedCueR2, outputDir);
close(figureHandles)
currentSpreadSaveResults(outputDir);

%% Free relative-position weights applied before combined-cue AI calculation

clear; close all
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'common'));
[paths, outputDir] = currentSpreadInit(mfilename('fullpath'));

combinedCueR2 = currentSpreadCombinedCueDistanceR2(paths, "free-fr");
r2Figure = currentSpreadSaveCombinedCueDistanceR2(combinedCueR2, outputDir);
weightFigures = currentSpreadSaveWeightDistributions(combinedCueR2, outputDir);
close([r2Figure; weightFigures])

%% Population-style bias prediction using individual relative channels

clear; close all
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'common'));
[paths, outputDir] = currentSpreadInit(mfilename('fullpath'));

relativeChannelPrediction = currentSpreadRelativeChannelBiasPrediction( ...
    paths, RelativePositions=[0 3 4]);
figureHandles = currentSpreadSaveRelativeChannelBiasPrediction( ...
    relativeChannelPrediction, outputDir);
close(figureHandles)

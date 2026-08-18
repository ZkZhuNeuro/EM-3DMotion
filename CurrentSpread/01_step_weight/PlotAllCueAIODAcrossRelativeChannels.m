%% All-cue population plots at relative channels 0 through +4

clear; close all
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'common'));
[paths, outputDir] = currentSpreadInit(mfilename('fullpath'));

allCueAIOD = currentSpreadAllCueRelativeChannelAIOD( ...
    paths, RelativePositions=0:4);
figureHandle = currentSpreadSaveAllCueRelativeChannelAIOD( ...
    allCueAIOD, outputDir);
close(figureHandle)

%% Unified Max-OD Gaussian channel-prediction and legacy meta app

clear; close all
scriptFolder = fileparts(mfilename('fullpath'));
interactiveRoot = fullfile(scriptFolder, 'interactive_population');
addpath(interactiveRoot, fullfile(interactiveRoot, 'common'));
gaussianMetaPopulationApp = ExploreGaussianMetaPopulationApp( ...
    ODDefinition="Max");

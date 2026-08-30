%% Unified correlation-OD Gaussian-meta population app

clear; close all
scriptFolder = fileparts(mfilename('fullpath'));
interactiveRoot = fullfile(scriptFolder, 'interactive_population');
addpath(interactiveRoot, fullfile(interactiveRoot, 'common'));
gaussianMetaPopulationCorrelationODApp = ...
    ExploreGaussianMetaPopulationApp(ODDefinition="Correlation");

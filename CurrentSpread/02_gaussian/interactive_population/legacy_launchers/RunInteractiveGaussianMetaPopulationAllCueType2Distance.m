%% Launch MT 2D Gaussian-meta explorer optimized by Type II line distance

clear; close all
scriptFolder = fileparts(mfilename('fullpath'));
interactiveFolder = fileparts(scriptFolder);
addpath(fullfile(interactiveFolder, 'common'), ...
    fullfile(interactiveFolder, 'type2_distance'));

cacheFile = ...
    "C:\EM\CurrentSpread\02_gaussian\" + ...
    "InteractiveGaussianMetaPopulation\MT\" + ...
    "GaussianMetaPopulationSigmaCache.mat";
if ~isfile(cacheFile)
    fprintf('Interactive cache is missing; building the 1000-sigma cache.\n');
    BuildInteractiveGaussianMetaPopulationCache(Area="MT");
end

interactiveGaussianMetaPopulationAllCueType2Distance = ...
    ExploreInteractiveGaussianMetaPopulationAllCueType2Distance( ...
    CacheFile=cacheFile, UnitType="2D");

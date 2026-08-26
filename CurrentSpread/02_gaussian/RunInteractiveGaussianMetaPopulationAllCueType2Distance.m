%% Launch MT 2D Gaussian-meta explorer optimized by Type II line distance

clear; close all
scriptFolder = fileparts(mfilename('fullpath'));
addpath(scriptFolder);

cacheFile = ...
    "C:\EM\CurrentSpread\02_gaussian\" + ...
    "InteractiveGaussianMetaPopulation\" + ...
    "GaussianMetaPopulationSigmaCache.mat";
if ~isfile(cacheFile)
    fprintf('Interactive cache is missing; building the 1000-sigma cache.\n');
    BuildInteractiveGaussianMetaPopulationCache;
end

interactiveGaussianMetaPopulationAllCueType2Distance = ...
    ExploreInteractiveGaussianMetaPopulationAllCueType2Distance( ...
    CacheFile=cacheFile);

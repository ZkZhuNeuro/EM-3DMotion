%% Launch MT 2D Gaussian-meta population explorer optimized across all cues

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

interactiveGaussianMetaPopulationAllCueR2 = ...
    ExploreInteractiveGaussianMetaPopulationAllCueR2( ...
    CacheFile=cacheFile);

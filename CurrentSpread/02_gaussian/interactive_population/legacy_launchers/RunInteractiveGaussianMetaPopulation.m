%% Launch the cached MT 2D Gaussian-meta population explorer

clear; close all
scriptFolder = fileparts(mfilename('fullpath'));
interactiveFolder = fileparts(scriptFolder);
addpath(fullfile(interactiveFolder, 'common'));

cacheFile = ...
    "C:\EM\CurrentSpread\02_gaussian\" + ...
    "InteractiveGaussianMetaPopulation\MT\" + ...
    "GaussianMetaPopulationSigmaCache.mat";

if ~isfile(cacheFile)
    fprintf('Interactive cache is missing; building the 1000-sigma cache.\n');
    BuildInteractiveGaussianMetaPopulationCache(Area="MT");
end

interactiveGaussianMetaPopulation = ...
    ExploreInteractiveGaussianMetaPopulation(CacheFile=cacheFile);

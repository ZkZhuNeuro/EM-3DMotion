%% Launch simple non-CV all-cue ordinary-R2 Gaussian-meta explorer

clear;
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

interactiveGaussianMetaPopulationAllCueOrdinaryR2 = ...
    ExploreInteractiveGaussianMetaPopulationAllCueOrdinaryR2( ...
    CacheFile=cacheFile);

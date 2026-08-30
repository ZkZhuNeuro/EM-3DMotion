%% Launch MT 2D Gaussian-meta population explorer optimized across all cues

clear; close all
scriptFolder = fileparts(mfilename('fullpath'));
interactiveFolder = fileparts(scriptFolder);
addpath(fullfile(interactiveFolder, 'common'), ...
    fullfile(interactiveFolder, 'cv_ai_od'));

cacheFile = ...
    "C:\EM\CurrentSpread\02_gaussian\" + ...
    "InteractiveGaussianMetaPopulation\MT\" + ...
    "GaussianMetaPopulationSigmaCache.mat";
if ~isfile(cacheFile)
    fprintf('Interactive cache is missing; building the 1000-sigma cache.\n');
    BuildInteractiveGaussianMetaPopulationCache(Area="MT");
end

interactiveGaussianMetaPopulationAllCueR2 = ...
    ExploreInteractiveGaussianMetaPopulationAllCueR2( ...
    CacheFile=cacheFile, UnitType="2D");

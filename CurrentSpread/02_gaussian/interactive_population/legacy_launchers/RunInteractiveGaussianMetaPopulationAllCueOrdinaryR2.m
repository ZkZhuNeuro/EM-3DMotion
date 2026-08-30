%% Launch simple non-CV all-cue ordinary-R2 Gaussian-meta explorer

clear;
scriptFolder = fileparts(mfilename('fullpath'));
interactiveFolder = fileparts(scriptFolder);
addpath(fullfile(interactiveFolder, 'common'), ...
    fullfile(interactiveFolder, 'ordinary_ai_od'));

cacheFile = ...
    "C:\EM\CurrentSpread\02_gaussian\" + ...
    "InteractiveGaussianMetaPopulation\MT\" + ...
    "GaussianMetaPopulationSigmaCache.mat";
if ~isfile(cacheFile)
    fprintf('Interactive cache is missing; building the 1000-sigma cache.\n');
    BuildInteractiveGaussianMetaPopulationCache(Area="MT");
end

interactiveGaussianMetaPopulationAllCueOrdinaryR2 = ...
    ExploreInteractiveGaussianMetaPopulationAllCueOrdinaryR2( ...
    CacheFile=cacheFile, UnitType="2D");

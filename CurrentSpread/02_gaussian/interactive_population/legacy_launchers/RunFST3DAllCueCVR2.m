%% FST meta-3D: repeated-CV DeltaBias ~ AI + AI:OD

clear; close all
interactiveRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(interactiveRoot, fullfile(interactiveRoot, 'common'), ...
    fullfile(interactiveRoot, 'cv_ai_od'));
cacheFile = "C:\EM\CurrentSpread\02_gaussian\" + ...
    "InteractiveGaussianMetaPopulation\FST\" + ...
    "GaussianMetaPopulationSigmaCache.mat";
if ~isfile(cacheFile)
    BuildInteractiveGaussianMetaPopulationSuite(Area="FST");
end
fst3DAllCueCVR2 = ExploreInteractiveGaussianMetaPopulationAllCueR2( ...
    CacheFile=cacheFile, UnitType="3D");

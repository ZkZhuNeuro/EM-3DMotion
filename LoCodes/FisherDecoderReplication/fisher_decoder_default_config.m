function cfg = fisher_decoder_default_config()
%FISHER_DECODER_DEFAULT_CONFIG Configuration matching the published code.

cfg.metadataFile = '';
cfg.dataFiles = struct();
cfg.monkeys = {'Jim','Clay'};
cfg.areas = {'MT','FST'};

cfg.nBootstraps = 1000;
cfg.nPseudoTrials = 20;
cfg.nFolds = 2;
cfg.randomSeed = 1;

% The source firing rates use 50-ms bins stepped every 10 ms, from -200 to
% 1000 ms. The last possible 50-ms window starts at 950 ms.
cfg.binStartTimesMs = -200:10:950;
cfg.responseWindowMs = [0 950];

cfg.combinedCondition = 1;
cfg.testConditions = 1:4;
cfg.conditionNames = {'Combined','Dominant eye perspective', ...
    'Non-dominant eye perspective','Stereoscopic'};
cfg.zeroCoherenceIndex = 7;
cfg.awayCoherenceIndices = 1:6;
cfg.towardCoherenceIndices = 8:13;

cfg.significanceVariable = 'sig_Anova_CLR';
cfg.classificationVariable = 'Z_quad';
cfg.motionClasses = struct( ...
    'name',{'2D','3D','2D-only'}, ...
    'field',{'D2','D3','D2Only'}, ...
    'value',{4,2,5});
cfg.dominanceVariable = 'Monocularity_Aligned';

% Leave empty to read Coherence or CoherenceArray from a data MAT file.
% If neither is present, plots use coherence-level numbers 1:6.
cfg.signedCoherence = [];
cfg.outputDirectory = fullfile(pwd,'FisherDecoderResults');
cfg.saveFigures = true;
cfg.verbose = true;
end

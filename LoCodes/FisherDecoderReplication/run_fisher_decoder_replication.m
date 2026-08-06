%% Replicate Thompson et al. (2023) Figure 5 Fisher decoding
% Edit the paths below, then run this script. The first analysis pools Jim
% and Clay, matching the paper. The second analysis repeats the exact same
% procedure separately for each monkey.

clear;
clc;

scriptDirectory = fileparts(mfilename('fullpath'));
addpath(scriptDirectory);

cfg = fisher_decoder_default_config();

% Build decoder inputs from the row-aligned C:\LoData response and metadata
% tables. Existing prepared files are reused on later runs.
sourceFile = 'C:\LoData\NeuroRespUnitTable.mat';
prepared = prepare_lodata_fisher_inputs(sourceFile, ...
    fullfile(scriptDirectory,'FisherDecoderInputs'),false);
cfg.metadataFile = prepared.metadataFile;
cfg.dataFiles = prepared.dataFiles;

% NeuroResp is already the mean firing rate over the stimulus duration, so
% it has one response-time entry rather than the original 116 sliding bins.
cfg.binStartTimesMs = 0;
cfg.responseWindowMs = [0 0];

% For a quick pipeline test, temporarily use a small number such as 10.
% Use 1000 for the paper replication.
cfg.nBootstraps = 1000;
cfg.randomSeed = 20230802;
cfg.outputDirectory = fullfile(scriptDirectory, 'FisherDecoderResults');

results = replicate_fisher_decoder(cfg);

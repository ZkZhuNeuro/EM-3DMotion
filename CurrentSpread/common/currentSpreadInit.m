function [paths, outputDir] = currentSpreadInit(scriptFile)
%CURRENTSPREADINIT Resolve shared inputs and create this script's output folder.

arguments
    scriptFile (1, :) char
end

projectRoot = fileparts(fileparts(scriptFile));
[analysisDir, scriptName] = fileparts(scriptFile);
[~, analysisGroup] = fileparts(analysisDir);

paths = struct();
paths.projectRoot = projectRoot;
paths.outputRoot = 'C:\EM\CurrentSpread';
paths.sourceRoot = ['P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\' ...
    'Stimulation\John_analysis_try\Clustering'];
paths.analysisPipelineRoot = ['P:\Codes\Matlab\offlineAnalysis\' ...
    '3DMotionAnalysis\Stimulation\John_analysis_try\AnalysisPipeline'];

paths.unitTableUpdating = fullfile(paths.analysisPipelineRoot, ...
    'UnitTable_updating.mat');
paths.unitTableGof = 'C:\EM\PopulationAnalysis\unit_table_gof.mat';
paths.neuroAll = fullfile(paths.sourceRoot, 'NeuroAll_20250627.mat');
paths.neuroMean = fullfile(paths.sourceRoot, 'NeuroMean_all.mat');
paths.unitTableDiscontinue = fullfile(paths.sourceRoot, ...
    'unit_table_discontinue.mat');

outputDir = fullfile(paths.outputRoot, analysisGroup, scriptName);
if ~isfolder(outputDir)
    mkdir(outputDir);
end

fprintf('Current-spread results: %s\n', outputDir);
end

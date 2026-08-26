function analysis = RunPopulationAnalysis_BestQuickChannels(options)
%RUNPOPULATIONANALYSIS_BESTQUICKCHANNELS Run correlation-channel population.
%
% This driver selects the best Quick-task channel using pooled Pearson
% correlation against the Stim-task NoStim reference. It then runs the
% existing OD-weighted population analysis using that channel's trial-level
% Quick AI and an OD recalculated from that channel's Quick tuning_mean.
% OD sign is used only to identify the dominant eye; all models, weights,
% summaries, and plots use the absolute OD magnitude.
%
% The neural cohort p_AI gate and Z3D_v_Z2D classification are also
% recomputed at the selected Quick channel from cached trial-level data.

arguments
    options.StateFile (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\unit_table_stim.mat"
    options.OutputFolder (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\BestCorrelationChannelPopulation"
    options.Area (1, 1) string {mustBeMember(options.Area, ["MT", "FST"])} = ...
        "MT"
    options.Monkey (1, 1) string ...
        {mustBeMember(options.Monkey, ["Both", "Jim", "Clay"])} = "Both"
    options.ODMethod (1, 1) string ...
        {mustBeMember(options.ODMethod, ["Max", "LSQ"])} = "Max"
    options.MaxAbsRelativePosition (1, 1) double ...
        {mustBeNonnegative, mustBeInteger} = 4
    options.MakeRankingPlots (1, 1) logical = true
    options.FigureVisible (1, 1) logical = false
    options.JimCacheFolder (1, 1) string = "C:\Jim\StimData"
    options.ClayCacheFolder (1, 1) string = "C:\Clay\StimData"
end

if ~isfile(options.StateFile)
    error('BestQuickPopulation:MissingStateFile', ...
        'Input MAT file does not exist: %s', options.StateFile);
end

scriptFolder = string(fileparts(mfilename('fullpath')));
projectFolder = string(fileparts(scriptFolder));
populationFolder = fullfile(projectFolder, 'PopulationAnalysis');
populationScript = fullfile( ...
    populationFolder, 'RunPopulationAnalysis_ODweighted.m');
if ~isfile(populationScript)
    error('BestQuickPopulation:MissingPopulationScript', ...
        'Population analysis script does not exist: %s', populationScript);
end
addpath(scriptFolder, populationFolder);

if ~isfolder(options.OutputFolder)
    mkdir(options.OutputFolder);
end
[correlationSummary, correlationChannels, correlationMetadata, ...
    correlationFigures] = CorrelateQuickStimNoStimTunings( ...
    options.StateFile, ...
    OutputFolder=fullfile(options.OutputFolder, 'ChannelSelection'), ...
    SaveOutputs=true, MakePlot=options.MakeRankingPlots, ...
    FigureVisible=options.FigureVisible, ...
    MaxAbsRelativePosition=options.MaxAbsRelativePosition);
closeFigures(correlationFigures);

input = load(options.StateFile, 'unit_table_stim');
if ~isfield(input, 'unit_table_stim') || ~istable(input.unit_table_stim)
    error('BestQuickPopulation:MissingStimTable', ...
        '%s does not contain table unit_table_stim.', options.StateFile);
end

[correlationPopulationInput, correlationAudit] = ...
    PrepareBestQuickChannelPopulationTable( ...
    input.unit_table_stim, correlationSummary, "Correlation", ...
    "BestPearsonR", options.ODMethod);
% The configured OD definition on the selected channel assigns the eye for
% both Max and LSQ runs, so Z3D_v_Z2D and the population condition order
% use the same dominance definition as the modeled OD.
dominantEyeMethod = "SelectedOD";
[correlationPopulationInput, correlationCriteriaAudit] = ...
    PrepareBestQuickChannelSelectionCriteria(correlationPopulationInput, ...
    JimCacheFolder=options.JimCacheFolder, ...
    ClayCacheFolder=options.ClayCacheFolder, ...
    DominantEyeMethod=dominantEyeMethod);
correlationValid = correlationAudit.Status == "Success" & ...
    correlationCriteriaAudit.Status == "Success";
correlationPopulationInput = correlationPopulationInput( ...
    correlationValid, :);
if isempty(correlationPopulationInput)
    error('BestQuickPopulation:NoValidSelections', ...
        ['Correlation produced no rows with finite selected Quick AI and ' ...
        'OD values. Inspect the selection audits.']);
end

correlationInputFile = savePreparedInput( ...
    options.OutputFolder, correlationPopulationInput, correlationAudit, ...
    correlationCriteriaAudit, correlationSummary, correlationChannels, ...
    correlationMetadata, options.StateFile);

correlationPopulation = runAndSavePopulation( ...
    populationScript, correlationInputFile, options.OutputFolder, ...
    "Correlation", correlationAudit, correlationCriteriaAudit, options);

analysis = struct();
analysis.StateFile = options.StateFile;
analysis.OutputFolder = options.OutputFolder;
analysis.Area = options.Area;
analysis.Monkey = options.Monkey;
analysis.ODMethod = options.ODMethod;
analysis.MaxAbsRelativePosition = options.MaxAbsRelativePosition;
analysis.MaxDistanceMicrometers = ...
    50 .* options.MaxAbsRelativePosition;
analysis.Correlation = correlationPopulation;
analysis.CorrelationSelectionSummary = correlationSummary;
analysis.CorrelationSelectionCriteriaAudit = correlationCriteriaAudit;

fprintf(['Completed correlation-channel population analysis for %s/%s. ' ...
    'Outputs: %s\n'], options.Area, options.Monkey, ...
    options.OutputFolder);
end


function inputFile = savePreparedInput(folder, preparedTable, audit, ...
    criteriaAudit, selectionSummary, channelScores, selectionMetadata, ...
    sourceFile)
if ~isfolder(folder)
    mkdir(folder);
end
unit_table_gof = preparedTable;
BestQuickChannelAudit = audit;
BestQuickChannelSelectionCriteriaAudit = criteriaAudit;
BestQuickChannelSessionSummary = selectionSummary;
BestQuickChannelScores = channelScores;
BestQuickChannelSelectionMetadata = selectionMetadata;
BestQuickChannelSourceFile = sourceFile;
inputFile = fullfile(folder, 'unit_table_gof_best_quick_channel.mat');
save(inputFile, 'unit_table_gof', 'BestQuickChannelAudit', ...
    'BestQuickChannelSelectionCriteriaAudit', ...
    'BestQuickChannelSessionSummary', 'BestQuickChannelScores', ...
    'BestQuickChannelSelectionMetadata', 'BestQuickChannelSourceFile', ...
    '-v7.3');
writetable(audit, fullfile(folder, 'BestQuickChannelPopulationAudit.csv'));
writetable(criteriaAudit, fullfile(folder, ...
    'BestQuickChannelSelectionCriteriaAudit.csv'));
end


function populationResults = runAndSavePopulation(populationScript, ...
    inputFile, outputFolder, methodName, audit, criteriaAudit, options)
if options.FigureVisible
    visibility = 'on';
else
    visibility = 'off';
end
previousVisibility = get(groot, 'defaultFigureVisible');
visibilityCleanup = onCleanup( ...
    @() set(groot, 'defaultFigureVisible', previousVisibility));
set(groot, 'defaultFigureVisible', visibility);

populationResults = executePopulationScript( ...
    populationScript, inputFile, options.Area, options.Monkey);
if any(populationResults.bias_table.OD < 0, 'all')
    error('BestQuickPopulation:SignedODEnteredModel', ...
        'Population bias_table.OD must contain absolute OD magnitudes only.');
end
populationResults.best_quick_selection_method = methodName;
populationResults.od_method = options.ODMethod;
populationResults.max_abs_relative_position = ...
    options.MaxAbsRelativePosition;
populationResults.max_distance_micrometers = ...
    50 .* options.MaxAbsRelativePosition;
populationResults.od_model_convention = ...
    ['OD sign is used only to assign dominant/non-dominant eye; ' ...
    'models, weights, opacity, summaries, and plots use abs(OD).'];
populationResults.best_quick_selection_audit = audit;
populationResults.best_quick_selection_criteria_audit = criteriaAudit;
populationResults.best_quick_population_input_file = inputFile;
populationResults.ai_od_source = ...
    char(methodName + "-selected 3DMotionQuick channel: raw-trial AI; " + ...
    options.ODMethod + " OD magnitude in models with sign used only " + ...
    "for dominant-eye assignment");
populationResults.selection_source = [ ...
    'Behavior retains the stimulation-session definition. AI, MonoL/MonoR ' ...
    'p_AI tuning gates, and Z3D_v_Z2D use cached trial-level data from ' ...
    'the ' char(methodName) '-selected 3DMotionQuick channel within ' ...
    sprintf('%d probe positions (%d um); OD uses the ', ...
    options.MaxAbsRelativePosition, 50 .* options.MaxAbsRelativePosition) ...
    char(options.ODMethod) ' method on that channel tuning_mean. OD sign ' ...
    'assigns the dominant eye and absolute OD enters models/plots.'];

figureFiles = struct();
[figureFiles.TwoDPNG, figureFiles.TwoDFIG] = savePopulationFigure( ...
    populationResults.fig_2d, outputFolder, ...
    methodName + "_BestQuick_" + options.Area + "_" + ...
    options.Monkey + "_Population_2D");
[figureFiles.ThreeDPNG, figureFiles.ThreeDFIG] = savePopulationFigure( ...
    populationResults.fig_3d, outputFolder, ...
    methodName + "_BestQuick_" + options.Area + "_" + ...
    options.Monkey + "_Population_3D");
populationResults.figure_files = figureFiles;

closeValidFigure(populationResults.fig_2d);
closeValidFigure(populationResults.fig_3d);
populationResults.fig_2d = gobjects(0);
populationResults.fig_3d = gobjects(0);

population_results = populationResults;
save(fullfile(outputFolder, 'PopulationAnalysisResults.mat'), ...
    'population_results', '-v7.3');
writetable(populationResults.summary_table, ...
    fullfile(outputFolder, 'PopulationSummary.csv'));
writetable(populationResults.aixod_summary_table, ...
    fullfile(outputFolder, 'PopulationAIxODSummary.csv'));
writetable(populationResults.bias_table, ...
    fullfile(outputFolder, 'PopulationBiasTable.csv'));
clear visibilityCleanup
end


function populationResults = executePopulationScript( ...
    populationScript, inputFile, areaName, monkeyName)
% Run in this isolated function workspace because the legacy script uses
% clearvars and assignin('base', ...).
area = char(areaName); %#ok<NASGU>
monkey = char(monkeyName); %#ok<NASGU>
data_file = char(inputFile); %#ok<NASGU>
stim_data_file = ''; %#ok<NASGU>
close_existing_figures = true; %#ok<NASGU>
tuning_source = 'Quick'; %#ok<NASGU>
population_analysis_use_supplied_settings = true; %#ok<NASGU>
run(populationScript)
populationResults = results;
end


function [pngFile, figFile] = savePopulationFigure( ...
    figureHandle, outputFolder, baseName)
pngFile = fullfile(outputFolder, baseName + ".png");
figFile = fullfile(outputFolder, baseName + ".fig");
exportgraphics(figureHandle, pngFile, 'Resolution', 220);
savefig(figureHandle, figFile);
end


function closeFigures(figures)
if ~isstruct(figures)
    return
end
names = fieldnames(figures);
for index = 1:numel(names)
    handles = figures.(names{index});
    for handleIndex = 1:numel(handles)
        closeValidFigure(handles(handleIndex));
    end
end
end


function closeValidFigure(figureHandle)
if ~isempty(figureHandle) && all(isgraphics(figureHandle, 'figure'))
    close(figureHandle);
end
end

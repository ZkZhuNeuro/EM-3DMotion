function Comparison = RunExample_CompareStimTuningToQuick_20240416(options)
%RUNEXAMPLE_COMPARESTIMTUNINGTOQUICK_20240416 Run the Jim 2024-04-16 match.
%
% Comparison = RunExample_CompareStimTuningToQuick_20240416()
% loads the non-electrical-stimulation tuning extracted from the same-day
% 3DMotionStim recording, finds the Jim 2024-04-16 row in unit_table_gof,
% and ranks all Quick channels by fixed-grid z-scored tuning SSE.
%
% If the compact Stim tuning MAT does not yet exist, this runner creates it
% from P:\Jim\NeuroData\20240416 using the extraction example first.

arguments
    options.UnitTableGofFile (1, 1) string = ...
        "C:\EM\PopulationAnalysis\unit_table_gof.mat"
    options.FigureVisible (1, 1) logical = false
    options.SaveOutputs (1, 1) logical = true
    options.OutputDirectory (1, 1) string = ""
end

outputRoot = 'C:\EM\FullAnalysisPipeline\outputs';
stimOutputDirectory = fullfile(outputRoot, ...
    'StimTuning_20240416');
stimTuningFile = fullfile(stimOutputDirectory, ...
    'Jim_20240416_3DMotionStim_MUA_Tuning.mat');
if ~isfile(stimTuningFile)
    fprintf('Stim tuning MAT is missing; extracting it first.\n');
    RunExample_Extract3DMotionStimTuning_20240416( ...
        FigureVisible=false, OutputDirectory=stimOutputDirectory);
end

outputDirectory = options.OutputDirectory;
if strlength(outputDirectory) == 0
    outputDirectory = fullfile(outputRoot, ...
        'StimVsQuick_20240416');
end

[Comparison, figures] = CompareStimTuningToQuickChannels( ...
    stimTuningFile, options.UnitTableGofFile, ...
    Monkey="Jim", RecordingDate=datetime(2024, 4, 16), ...
    OutputDirectory=outputDirectory, ...
    MakePlots=true, FigureVisible=options.FigureVisible, ...
    SaveOutputs=options.SaveOutputs);

fprintf('\nJim 2024-04-16 Stim-versus-Quick ranking (lowest SSE first):\n');
disp(Comparison.ChannelSummary(:, { ...
    'Rank', 'Channel', 'ProbePosition', 'RelativePositionToStim', ...
    'DistanceToStimMicrometers', 'SSE', 'RMSE', 'PearsonR', ...
    'IsStimChannel'}));

% Keep handles available to an interactive caller without storing them in
% the MAT analysis result.
Comparison.Figures = figures;
end

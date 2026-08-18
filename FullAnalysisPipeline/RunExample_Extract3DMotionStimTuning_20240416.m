function ExampleResult = ...
    RunExample_Extract3DMotionStimTuning_20240416(options)
%RUNEXAMPLE_EXTRACT3DMOTIONSTIMTUNING_20240416 Run the Jim 2024-04-16 example.
%
% ExampleResult = RunExample_Extract3DMotionStimTuning_20240416()
% reads the stimulation TInfo/SelIndex pair from P:, extracts artifact-free
% tuning from the interleaved non-electrical-stimulation trials, and writes
% a compact MAT result, trial audit CSV, count CSV, and tuning figure under
% C:\EM\FullAnalysisPipeline\outputs.
%
% The source recording is read only; this function never writes to P:.

arguments
    options.ApplyEyeCheck (1, 1) logical = true
    options.MakePlot (1, 1) logical = true
    options.FigureVisible (1, 1) logical = true
    options.SaveOutput (1, 1) logical = true
    options.OutputDirectory (1, 1) string = ""
end

recordingFolder = 'P:\Jim\NeuroData\20240416';
stimFiles = { ...
    'Jim_FST_16Apr2024_3DMotionStim_MUA_TInfo.mat', ...
    'Jim_FST_16Apr2024_3DMotionStim_MUA_SelIndex.mat'};

[Neuro, TrialSummary, ExtractionSummary, tuningFigure] = ...
    Extract3DMotionStimTuning( ...
    recordingFolder, stimFiles, ...
    ApplyEyeCheck=options.ApplyEyeCheck, ...
    MakePlot=options.MakePlot, ...
    FigureVisible=options.FigureVisible);

% The same-day Quick file contains these eight signed coherence bins. This
% mask makes a later Quick-versus-Stim-period comparison explicit.
quickCoherence = round([-22 -14 -10 -8 8 10 14 22] ./ 22, 2);
allCoherence = Neuro.WithZero.Coherence;
commonQuickMask = ismember(allCoherence, quickCoherence);

conditionIndex = repelem((1:numel(Neuro.ConditionNames))', ...
    numel(allCoherence));
conditionName = repelem(Neuro.ConditionNames(:), ...
    numel(allCoherence));
coherence = repmat(allCoherence(:), ...
    numel(Neuro.ConditionNames), 1);
isCommonWithQuick = repmat(commonQuickMask(:), ...
    numel(Neuro.ConditionNames), 1);
noStimTrialCount = reshape( ...
    Neuro.WithZero.NoStim.Trials.NumTrials', [], 1);
stimTrialCount = reshape( ...
    Neuro.WithZero.Stim.Trials.NumTrials', [], 1);
CountTable = table(conditionIndex, conditionName, coherence, ...
    isCommonWithQuick, noStimTrialCount, stimTrialCount, ...
    'VariableNames', {'Condition', 'ConditionName', 'Coherence', ...
    'PresentInQuick', 'NoStimTrials', 'StimTrials'});

ExampleResult = struct();
ExampleResult.Neuro = Neuro;
ExampleResult.TrialSummary = TrialSummary;
ExampleResult.ExtractionSummary = ExtractionSummary;
ExampleResult.CountTable = CountTable;
ExampleResult.QuickCoherence = quickCoherence;
ExampleResult.CommonQuickMask = commonQuickMask;
ExampleResult.Figure = tuningFigure;

if options.SaveOutput
    outputDirectory = options.OutputDirectory;
    if strlength(outputDirectory) == 0
        outputDirectory = fullfile('C:\EM\FullAnalysisPipeline\outputs', ...
            'StimTuning_20240416');
    end
    if ~isfolder(outputDirectory)
        mkdir(outputDirectory);
    end

    matPath = fullfile(outputDirectory, ...
        'Jim_20240416_3DMotionStim_MUA_Tuning.mat');
    trialCsvPath = fullfile(outputDirectory, ...
        'Jim_20240416_3DMotionStim_TrialAudit.csv');
    countCsvPath = fullfile(outputDirectory, ...
        'Jim_20240416_3DMotionStim_ConditionCoherenceCounts.csv');
    save(matPath, 'Neuro', 'TrialSummary', 'ExtractionSummary', ...
        'CountTable', 'quickCoherence', 'commonQuickMask', '-v7.3');
    writetable(TrialSummary, trialCsvPath);
    writetable(CountTable, countCsvPath);

    figurePath = "";
    if ~isempty(tuningFigure) && isgraphics(tuningFigure)
        figurePath = fullfile(outputDirectory, ...
            'Jim_20240416_3DMotionStim_NoStimTuning.png');
        exportgraphics(tuningFigure, figurePath, 'Resolution', 200);
        savefig(tuningFigure, fullfile(outputDirectory, ...
            'Jim_20240416_3DMotionStim_NoStimTuning.fig'));
    end

    ExampleResult.OutputDirectory = string(outputDirectory);
    ExampleResult.MatPath = string(matPath);
    ExampleResult.TrialCsvPath = string(trialCsvPath);
    ExampleResult.CountCsvPath = string(countCsvPath);
    ExampleResult.FigurePath = string(figurePath);
    fprintf('Saved example stimulation tuning to %s\n', outputDirectory);
end
end

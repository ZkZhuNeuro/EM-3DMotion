function Results = analyze_microsaccades(tInfoFile, selIndexFile, varargin)
%ANALYZE_MICROSACCADES Detect microsaccades in selected trials.
%
% Results = analyze_microsaccades(tInfoFile, selIndexFile) loads the eye
% traces from a TrialInfo file, keeps trials selected in the matching
% SelIndex file, and compares electrical-stimulation (EID 222) with
% non-stimulation trials. Detection is restricted to the visual stimulus
% interval (EID 118 to EID 130).
%
% Name-value options:
%   OutputDir                    Folder for MAT, CSV, and PNG outputs
%   SmoothWindowMs              Moving-mean window; 0 disables it (default 5 ms)
%   VelocityThresholdLambda     Robust velocity multiplier (default 6)
%   MinDurationMs               Minimum event duration (default 12 ms)
%   MergeGapMs                  Candidate merge gap (default 0 ms)
%   MinAmplitudeDeg             Optional lower amplitude gate (default 0)
%   MaxAmplitudeDeg             Optional upper amplitude gate (default Inf)
%   MaxDurationMs               Optional maximum duration (default Inf)
%   MaxInterocularOnsetLagMs    Optional onset-lag gate (default Inf)
%   MaxDirectionDifferenceDeg   Optional direction gate (default 180)
%   RequireBinocular            Require left/right temporal overlap (default true)
%   DirectionBinCount           Angular bins in the envelope plot
%   DirectionEnvelopePercentile Radial percentile for the envelope
%   ExampleTrajectoryCount      Legacy total event count (default 10)
%   ExampleTrajectoryCountPerCondition Random events per condition
%   ExampleTrajectorySeed       Reproducible trajectory sampling seed
%   DirectionFigureFile         Optional dedicated envelope-figure path
%   ExampleTrajectoryFigureFile Optional dedicated trajectory-figure path
%   ComparisonPermutationCount  Stim/NonStim permutations (default 1000)
%   ComparisonSeed              Reproducible permutation seed
%   SaveEyeTraces               Save smoothed positions and velocities
%   MakeQCPlot                  Export a summary QC plot
%   MakeDirectionPlot           Export direction/vector summary plot
%   MakeExampleTrajectoryPlot   Export centered example trajectories


parser = inputParser;
parser.FunctionName = mfilename;
addRequired(parser, 'tInfoFile', @(x) ischar(x) || isstring(x));
addRequired(parser, 'selIndexFile', @(x) ischar(x) || isstring(x));
addParameter(parser, 'OutputDir', fullfile('C:\EM\Microsac', 'results'), ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'SmoothWindowMs', 5, @(x) isscalar(x) && x >= 0);
addParameter(parser, 'VelocityThresholdLambda', 6, @(x) isscalar(x) && x > 0);
addParameter(parser, 'MinDurationMs', 12, @(x) isscalar(x) && x > 0);
addParameter(parser, 'MergeGapMs', 0, @(x) isscalar(x) && x >= 0);
addParameter(parser, 'MinAmplitudeDeg', 0, @(x) isscalar(x) && x >= 0);
addParameter(parser, 'MaxAmplitudeDeg', Inf, @(x) isscalar(x) && x > 0);
addParameter(parser, 'MaxDurationMs', Inf, @(x) isscalar(x) && x > 0);
addParameter(parser, 'MaxInterocularOnsetLagMs', Inf, @(x) isscalar(x) && x >= 0);
addParameter(parser, 'MaxDirectionDifferenceDeg', 180, @(x) isscalar(x) && x >= 0 && x <= 180);
addParameter(parser, 'RequireBinocular', true, @(x) islogical(x) && isscalar(x));
addParameter(parser, 'DirectionBinCount', 24, @(x) isscalar(x) && x >= 8 && mod(x, 1) == 0);
addParameter(parser, 'DirectionEnvelopePercentile', 95, ...
    @(x) isscalar(x) && x > 0 && x <= 100);
addParameter(parser, 'ExampleTrajectoryCount', 10, ...
    @(x) isscalar(x) && x >= 2 && mod(x, 1) == 0);
addParameter(parser, 'ExampleTrajectoryCountPerCondition', [], ...
    @(x) isempty(x) || (isscalar(x) && x >= 1 && mod(x, 1) == 0));
addParameter(parser, 'ExampleTrajectorySeed', 2718, ...
    @(x) isscalar(x) && isfinite(x) && mod(x, 1) == 0);
addParameter(parser, 'DirectionFigureFile', "", ...
    @(x) ischar(x) || (isstring(x) && isscalar(x)));
addParameter(parser, 'ExampleTrajectoryFigureFile', "", ...
    @(x) ischar(x) || (isstring(x) && isscalar(x)));
addParameter(parser, 'ComparisonPermutationCount', 1000, ...
    @(x) isscalar(x) && x >= 100 && mod(x, 1) == 0);
addParameter(parser, 'ComparisonSeed', 1729, ...
    @(x) isscalar(x) && isfinite(x) && mod(x, 1) == 0);
addParameter(parser, 'StimCode', 222, @(x) isscalar(x));
addParameter(parser, 'VisualStimOnCode', 118, @(x) isscalar(x));
addParameter(parser, 'VisualStimOffCode', 130, @(x) isscalar(x));
addParameter(parser, 'SaveEyeTraces', true, @(x) islogical(x) && isscalar(x));
addParameter(parser, 'MakeQCPlot', true, @(x) islogical(x) && isscalar(x));
addParameter(parser, 'MakeDirectionPlot', true, @(x) islogical(x) && isscalar(x));
addParameter(parser, 'MakeExampleTrajectoryPlot', true, ...
    @(x) islogical(x) && isscalar(x));
parse(parser, tInfoFile, selIndexFile, varargin{:});
options = parser.Results;

tInfoFile = char(tInfoFile);
selIndexFile = char(selIndexFile);
outputDir = char(options.OutputDir);
assert(isfile(tInfoFile), 'TrialInfo file not found: %s', tInfoFile);
assert(isfile(selIndexFile), 'SelIndex file not found: %s', selIndexFile);
if ~isfolder(outputDir)
    mkdir(outputDir);
end

fprintf('Loading TrialInfo from %s\n', tInfoFile);
data = load(tInfoFile, 'TrialInfo', 'Config');
selectionData = load(selIndexFile, 'EditSel', 'Selected');
TrialInfo = data.TrialInfo;
Config = data.Config;
clear data

[selection, selectionSource] = getSelection(selectionData);
assert(numel(selection) == numel(TrialInfo), ...
    'Selection length (%d) does not match TrialInfo length (%d).', ...
    numel(selection), numel(TrialInfo));
goodTrialIndex = find(selection(:));
nGood = numel(goodTrialIndex);
fprintf('Preparing %d selected trials using %s.\n', nGood, selectionSource);

traceTemplate = struct( ...
    'TrialIndex', [], 'IsStim', false, 'Valid', false, ...
    'TimeRelVisualStimS', [], ...
    'LeftXDeg', [], 'LeftYDeg', [], 'RightXDeg', [], 'RightYDeg', [], ...
    'LeftVXDegS', [], 'LeftVYDegS', [], 'RightVXDegS', [], 'RightVYDegS', []);
EyeTraces = repmat(traceTemplate, nGood, 1);

isStim = false(nGood, 1);
visualStimOnS = nan(nGood, 1);
visualStimOffS = nan(nGood, 1);
electricalStimOnRelVisualS = nan(nGood, 1);
analysisDurationS = nan(nGood, 1);
sampleRateHz = nan(nGood, 1);
condition = nan(nGood, 1);
signedCoherence = nan(nGood, 1);
direction = nan(nGood, 1);
response = nan(nGood, 1);
hasAnalysisWindow = false(nGood, 1);

for g = 1:nGood
    trialIndex = goodTrialIndex(g);
    trial = TrialInfo(trialIndex);
    EyeTraces(g).TrialIndex = trialIndex;

    eventID = trial.EID(:);
    eventTime = trial.EventT(:);
    isStim(g) = any(eventID == options.StimCode);
    EyeTraces(g).IsStim = isStim(g);

    trialEnd = eventTime(eventID == 112);
    if isempty(trialEnd)
        continue
    end
    trialEnd = min(trialEnd);
    onTimes = eventTime(eventID == options.VisualStimOnCode & eventTime < trialEnd);
    offTimes = eventTime(eventID == options.VisualStimOffCode & eventTime < trialEnd);
    if isempty(onTimes) || isempty(offTimes)
        continue
    end

    visualStimOnS(g) = onTimes(1);
    visualStimOffS(g) = offTimes(end);
    if visualStimOffS(g) <= visualStimOnS(g)
        continue
    end

    electricalTimes = eventTime(eventID == options.StimCode & eventTime < trialEnd);
    if ~isempty(electricalTimes)
        electricalStimOnRelVisualS(g) = electricalTimes(1) - visualStimOnS(g);
    end

    [condition(g), signedCoherence(g), direction(g), response(g)] = decodeTrial(eventID);

    time = trial.AITs(:);
    sampleMask = time >= visualStimOnS(g) & time <= visualStimOffS(g);
    sampleIndex = find(sampleMask);
    if numel(sampleIndex) < 20
        continue
    end
    if any(sampleIndex > numel(trial.LEyeX)) || any(sampleIndex > numel(trial.LEyeY)) || ...
            any(sampleIndex > numel(trial.REyeX)) || any(sampleIndex > numel(trial.REyeY))
        continue
    end

    time = time(sampleIndex);
    dt = median(diff(time), 'omitmissing');
    if ~isfinite(dt) || dt <= 0
        if isfield(Config, 'AISampleRate') && Config.AISampleRate > 0
            dt = 1 / Config.AISampleRate;
        else
            continue
        end
    end
    fs = 1 / dt;
    smoothSamples = makeOddSampleCount(options.SmoothWindowMs, fs);

    leftX = atan2d(double(trial.LEyeX(sampleIndex(:))), Config.ScrDistmm);
    leftY = atan2d(double(trial.LEyeY(sampleIndex(:))), Config.ScrDistmm);
    rightX = atan2d(double(trial.REyeX(sampleIndex(:))), Config.ScrDistmm);
    rightY = atan2d(double(trial.REyeY(sampleIndex(:))), Config.ScrDistmm);

    leftX = smoothFiniteSegments(leftX, smoothSamples);
    leftY = smoothFiniteSegments(leftY, smoothSamples);
    rightX = smoothFiniteSegments(rightX, smoothSamples);
    rightY = smoothFiniteSegments(rightY, smoothSamples);
    [leftVX, leftVY] = fivePointVelocity(leftX, leftY, dt);
    [rightVX, rightVY] = fivePointVelocity(rightX, rightY, dt);

    EyeTraces(g).Valid = true;
    EyeTraces(g).TimeRelVisualStimS = time - visualStimOnS(g);
    EyeTraces(g).LeftXDeg = leftX;
    EyeTraces(g).LeftYDeg = leftY;
    EyeTraces(g).RightXDeg = rightX;
    EyeTraces(g).RightYDeg = rightY;
    EyeTraces(g).LeftVXDegS = leftVX;
    EyeTraces(g).LeftVYDegS = leftVY;
    EyeTraces(g).RightVXDegS = rightVX;
    EyeTraces(g).RightVYDegS = rightVY;

    hasAnalysisWindow(g) = true;
    sampleRateHz(g) = fs;
    analysisDurationS(g) = time(end) - time(1) + dt;
end

validTrace = [EyeTraces.Valid]';
assert(any(validTrace), 'No selected trial contained a usable visual-stimulus eye-data window.');
if any(~validTrace)
    warning('%d selected trial(s) lacked a usable visual-stimulus eye-data window.', nnz(~validTrace));
end

leftCandidateCount = zeros(nGood, 1);
rightCandidateCount = zeros(nGood, 1);
microsaccadeCount = zeros(nGood, 1);
microsaccadeRateHz = nan(nGood, 1);
meanMicrosaccadeAmplitudeDeg = nan(nGood, 1);
meanMicrosaccadePeakVelocityDegS = nan(nGood, 1);
meanMicrosaccadeDurationMs = nan(nGood, 1);
trialDirectionX = nan(nGood, 1);
trialDirectionY = nan(nGood, 1);
trialMeanDirectionDeg = nan(nGood, 1);
trialDirectionResultantLength = nan(nGood, 1);
leftThresholdXDegS = nan(nGood, 1);
leftThresholdYDegS = nan(nGood, 1);
rightThresholdXDegS = nan(nGood, 1);
rightThresholdYDegS = nan(nGood, 1);
eventRows = emptyOutputEvents();
trajectoryRows = emptyEventTrajectoryRows();

for g = 1:nGood
    if ~EyeTraces(g).Valid
        continue
    end
    fs = sampleRateHz(g);
    trialThresholds = estimateVelocityThresholds(EyeTraces(g), ...
        options.VelocityThresholdLambda);
    leftThresholdXDegS(g) = trialThresholds.LeftX;
    leftThresholdYDegS(g) = trialThresholds.LeftY;
    rightThresholdXDegS(g) = trialThresholds.RightX;
    rightThresholdYDegS(g) = trialThresholds.RightY;
    leftEvents = detectEyeEvents(EyeTraces(g).LeftXDeg, EyeTraces(g).LeftYDeg, ...
        EyeTraces(g).LeftVXDegS, EyeTraces(g).LeftVYDegS, ...
        trialThresholds.LeftX, trialThresholds.LeftY, fs, options);
    rightEvents = detectEyeEvents(EyeTraces(g).RightXDeg, EyeTraces(g).RightYDeg, ...
        EyeTraces(g).RightVXDegS, EyeTraces(g).RightVYDegS, ...
        trialThresholds.RightX, trialThresholds.RightY, fs, options);
    if options.RequireBinocular
        detectedEvents = pairBinocularEvents(leftEvents, rightEvents, fs, ...
            options.MaxInterocularOnsetLagMs, options.MaxDirectionDifferenceDeg);
    else
        detectedEvents = mergeOverlappingEyeEvents(leftEvents, rightEvents, fs);
    end
    detectedEvents = measureDetectedEvents(detectedEvents, EyeTraces(g), fs);

    leftCandidateCount(g) = numel(leftEvents);
    rightCandidateCount(g) = numel(rightEvents);
    microsaccadeCount(g) = numel(detectedEvents);
    microsaccadeRateHz(g) = microsaccadeCount(g) / analysisDurationS(g);
    if ~isempty(detectedEvents)
        meanMicrosaccadeAmplitudeDeg(g) = mean(arrayfun( ...
            @eventMeanAmplitude, detectedEvents));
        meanMicrosaccadePeakVelocityDegS(g) = mean(arrayfun( ...
            @eventPeakVelocity, detectedEvents));
        meanMicrosaccadeDurationMs(g) = mean([detectedEvents.DurationMs]);
        eventDirections = arrayfun(@eventDirection, detectedEvents);
        trialDirectionX(g) = mean(cosd(eventDirections));
        trialDirectionY(g) = mean(sind(eventDirections));
        trialMeanDirectionDeg(g) = mod(atan2d(trialDirectionY(g), trialDirectionX(g)), 360);
        trialDirectionResultantLength(g) = hypot(trialDirectionX(g), trialDirectionY(g));
    end

    for e = 1:numel(detectedEvents)
        b = detectedEvents(e);
        time = EyeTraces(g).TimeRelVisualStimS;
        row = makeOutputEvent();
        row.TrialIndex = goodTrialIndex(g);
        row.TrialType = trialTypeLabel(isStim(g));
        row.IsStim = isStim(g);
        row.Condition = condition(g);
        row.SignedCoherence = signedCoherence(g);
        row.ElectricalStimOnRelVisualS = electricalStimOnRelVisualS(g);
        row.EventNumberInTrial = e;
        row.DetectionSource = b.DetectionSource;
        row.OnsetRelVisualStimS = time(b.On);
        row.OffsetRelVisualStimS = time(b.Off);
        row.OnsetRelElectricalStimS = row.OnsetRelVisualStimS - electricalStimOnRelVisualS(g);
        row.DurationMs = b.DurationMs;
        row.LeftAmplitudeDeg = b.Left.AmplitudeDeg;
        row.RightAmplitudeDeg = b.Right.AmplitudeDeg;
        row.MeanAmplitudeDeg = eventMeanAmplitude(b);
        row.LeftPeakVelocityDegS = b.Left.PeakVelocityDegS;
        row.RightPeakVelocityDegS = b.Right.PeakVelocityDegS;
        row.PeakVelocityDegS = eventPeakVelocity(b);
        row.MeanDXDeg = mean([b.Left.DXDeg, b.Right.DXDeg], 'omitmissing');
        row.MeanDYDeg = mean([b.Left.DYDeg, b.Right.DYDeg], 'omitmissing');
        row.DirectionDeg = eventDirection(b);
        row.InterocularOnsetLagMs = b.InterocularOnsetLagMs;
        row.InterocularDirectionDiffDeg = b.InterocularDirectionDiffDeg;
        eventRows(end + 1, 1) = row; %#ok<AGROW>
        trajectoryRows(end + 1, 1) = makeEventTrajectoryRow( ...
            numel(eventRows), b, EyeTraces(g), row); %#ok<AGROW>
    end
end

TrialType = arrayfun(@trialTypeLabel, isStim, 'UniformOutput', true);
TrialTable = table(goodTrialIndex, true(nGood, 1), TrialType, isStim, hasAnalysisWindow, ...
    visualStimOnS, visualStimOffS, electricalStimOnRelVisualS, analysisDurationS, ...
    sampleRateHz, condition, signedCoherence, direction, response, ...
    leftCandidateCount, rightCandidateCount, microsaccadeCount, microsaccadeRateHz, ...
    meanMicrosaccadeAmplitudeDeg, meanMicrosaccadePeakVelocityDegS, ...
    meanMicrosaccadeDurationMs, trialDirectionX, trialDirectionY, ...
    trialMeanDirectionDeg, trialDirectionResultantLength, ...
    leftThresholdXDegS, leftThresholdYDegS, rightThresholdXDegS, rightThresholdYDegS, ...
    'VariableNames', {'TrialIndex', 'GoodSelection', 'TrialType', 'IsStim', ...
    'HasAnalysisWindow', 'VisualStimOnS', 'VisualStimOffS', ...
    'ElectricalStimOnRelVisualS', 'AnalysisDurationS', 'SampleRateHz', ...
    'Condition', 'SignedCoherence', 'Direction', 'Response', ...
    'LeftCandidateCount', 'RightCandidateCount', 'MicrosaccadeCount', ...
    'MicrosaccadeRateHz', 'MeanMicrosaccadeAmplitudeDeg', ...
    'MeanMicrosaccadePeakVelocityDegS', 'MeanMicrosaccadeDurationMs', ...
    'TrialDirectionX', 'TrialDirectionY', 'TrialMeanDirectionDeg', ...
    'TrialDirectionResultantLength', 'LeftThresholdXDegS', ...
    'LeftThresholdYDegS', 'RightThresholdXDegS', 'RightThresholdYDegS'});

if isempty(eventRows)
    MicrosaccadeTable = emptyMicrosaccadeTable();
else
    MicrosaccadeTable = struct2table(eventRows, 'AsArray', true);
end
if isempty(trajectoryRows)
    EventTrajectoryTable = emptyEventTrajectoryTable();
else
    EventTrajectoryTable = struct2table(trajectoryRows, 'AsArray', true);
end
EventTrialTable = makeEventTrialTable(TrialTable, MicrosaccadeTable, TrialInfo);
SummaryTable = makeSummaryTable(TrialTable, MicrosaccadeTable);
DirectionStatsTable = makeDirectionStatsTable(MicrosaccadeTable);
StimComparisonTable = makeStimComparisonTable(TrialTable, options);

[~, inputStem] = fileparts(tInfoFile);
inputStem = regexprep(inputStem, '_TInfo$', '');
outputStem = fullfile(outputDir, [inputStem '_microsaccades']);
outputFiles = struct( ...
    'Mat', [outputStem '.mat'], ...
    'TrialsCSV', [outputStem '_trials.csv'], ...
    'EventsCSV', [outputStem '_events.csv'], ...
    'SummaryCSV', [outputStem '_summary.csv'], ...
    'DirectionStatsCSV', [outputStem '_direction_stats.csv'], ...
    'StimComparisonCSV', [outputStem '_stim_nonstim_tests.csv'], ...
    'EventDataMat', [outputStem '_event_data.mat'], ...
    'QCFigure', [outputStem '_qc.png'], ...
    'DirectionFigure', [outputStem '_direction_envelope.png'], ...
    'ExampleTrajectoryFigure', [outputStem '_example_trajectories.png']);
if strlength(string(options.DirectionFigureFile)) > 0
    outputFiles.DirectionFigure = char(options.DirectionFigureFile);
end
if strlength(string(options.ExampleTrajectoryFigureFile)) > 0
    outputFiles.ExampleTrajectoryFigure = char(options.ExampleTrajectoryFigureFile);
end
figureFiles = {outputFiles.DirectionFigure, outputFiles.ExampleTrajectoryFigure};
for iFile = 1:numel(figureFiles)
    figureFolder = fileparts(figureFiles{iFile});
    if ~isempty(figureFolder) && ~isfolder(figureFolder)
        mkdir(figureFolder);
    end
end

parameters = options;
parameters.SelectionSource = selectionSource;
parameters.EyePositionInputUnit = 'screen millimeters';
parameters.EyePositionOutputUnit = 'visual degrees';
parameters.AnalysisWindow = sprintf('EID %g to EID %g', ...
    options.VisualStimOnCode, options.VisualStimOffCode);
if options.RequireBinocular
    parameters.BinocularRule = 'one-to-one temporal overlap';
else
    parameters.BinocularRule = ['not required; temporally connected left- and ' ...
        'right-eye candidates are merged over their union interval, and ' ...
        'unmatched monocular candidates are retained'];
end
if options.SmoothWindowMs > 0
    smoothingDescription = sprintf('%.3g ms position smoothing', ...
        options.SmoothWindowMs);
else
    smoothingDescription = 'no additional position smoothing';
end
parameters.Detector = sprintf(['Engbert and Kliegl (2003) defaults with %s ' ...
    'and %.3g ms minimum duration'], smoothingDescription, options.MinDurationMs);

thresholds = table(TrialType, leftThresholdXDegS, leftThresholdYDegS, ...
    rightThresholdXDegS, rightThresholdYDegS, ...
    'VariableNames', {'TrialType', 'LeftX', 'LeftY', 'RightX', 'RightY'});

Results = struct;
Results.InputFiles = struct('TrialInfo', tInfoFile, 'SelIndex', selIndexFile);
Results.Parameters = parameters;
Results.VelocityThresholdsDegS = thresholds;
Results.TrialTable = TrialTable;
Results.MicrosaccadeTable = MicrosaccadeTable;
Results.SummaryTable = SummaryTable;
Results.DirectionStatsTable = DirectionStatsTable;
Results.StimComparisonTable = StimComparisonTable;
Results.OutputFiles = outputFiles;
if options.SaveEyeTraces
    Results.EyeTraces = EyeTraces;
end

writetable(TrialTable, outputFiles.TrialsCSV);
writetable(MicrosaccadeTable, outputFiles.EventsCSV);
writetable(SummaryTable, outputFiles.SummaryCSV);
writetable(DirectionStatsTable, outputFiles.DirectionStatsCSV);
writetable(StimComparisonTable, outputFiles.StimComparisonCSV);
if options.MakeQCPlot
    makeQCPlot(EyeTraces, TrialTable, MicrosaccadeTable, outputFiles.QCFigure, options);
else
    Results.OutputFiles.QCFigure = '';
end
if options.MakeDirectionPlot
    makeDirectionEnvelopePlot(MicrosaccadeTable, DirectionStatsTable, ...
        outputFiles.DirectionFigure, options);
else
    Results.OutputFiles.DirectionFigure = '';
end
if options.MakeExampleTrajectoryPlot
    exampleCountPerCondition = options.ExampleTrajectoryCountPerCondition;
    if isempty(exampleCountPerCondition)
        exampleCountPerCondition = floor(options.ExampleTrajectoryCount / 2);
    end
    makeExampleTrajectoryPlot(EyeTraces, MicrosaccadeTable, ...
        outputFiles.ExampleTrajectoryFigure, exampleCountPerCondition, options);
else
    Results.OutputFiles.ExampleTrajectoryFigure = '';
end
save(outputFiles.EventDataMat, 'MicrosaccadeTable', 'EventTrajectoryTable', ...
    'EventTrialTable', '-v7.3');
save(outputFiles.Mat, 'Results', '-v7.3');

fprintf('\nMicrosaccade analysis complete.\n');
disp(SummaryTable);
disp(DirectionStatsTable(:, {'TrialType', 'EventCount', 'MeanDirectionDeg', ...
    'MeanResultantLength', 'RayleighP', 'TrialMeanRayleighP'}));
disp(StimComparisonTable(:, {'Metric', 'NonStimEstimate', 'StimEstimate', ...
    'StimMinusNonStim', 'PermutationP'}));
fprintf('Results saved to %s\n', outputDir);
end


function [selection, source] = getSelection(selectionData)
if isfield(selectionData, 'EditSel')
    selection = logical(selectionData.EditSel(:));
    source = 'EditSel';
elseif isfield(selectionData, 'Selected')
    selection = logical(selectionData.Selected(:));
    source = 'Selected';
else
    error('SelIndex file must contain EditSel or Selected.');
end
end


function [condition, coherence, direction, response] = decodeTrial(eventID)
conditionCode = eventID(eventID >= 8000 & eventID < 9000);
directionCode = eventID(eventID >= 4000 & eventID < 5000);
coherenceCode = eventID(eventID >= 10000 & eventID <= 20000);
responseCode = eventID(eventID >= 6000 & eventID < 7000);

condition = firstOrNaN(conditionCode) - 8000;
direction = firstOrNaN(directionCode) - 4001;
rawCoherence = firstOrNaN(coherenceCode);
if isfinite(rawCoherence) && isfinite(direction)
    coherence = round(((rawCoherence - 10000) * direction) / 10000, 4);
else
    coherence = NaN;
end
response = firstOrNaN(responseCode) - 6000;
end


function value = firstOrNaN(values)
if isempty(values)
    value = NaN;
else
    value = values(1);
end
end


function count = makeOddSampleCount(windowMs, fs)
count = max(1, round(windowMs * fs / 1000));
if mod(count, 2) == 0
    count = count + 1;
end
end


function smoothed = smoothFiniteSegments(values, windowSamples)
values = values(:);
smoothed = nan(size(values));
runs = logicalRuns(isfinite(values));
for i = 1:size(runs, 1)
    idx = runs(i, 1):runs(i, 2);
    smoothed(idx) = movmean(values(idx), windowSamples, 'Endpoints', 'shrink');
end
end


function [vx, vy] = fivePointVelocity(x, y, dt)
n = numel(x);
vx = nan(n, 1);
vy = nan(n, 1);
if n < 5
    return
end
vx(3:n-2) = (x(5:n) + x(4:n-1) - x(2:n-3) - x(1:n-4)) / (6 * dt);
vy(3:n-2) = (y(5:n) + y(4:n-1) - y(2:n-3) - y(1:n-4)) / (6 * dt);
end


function thresholds = estimateVelocityThresholds(traces, lambda)
leftVX = vertcat(traces.LeftVXDegS);
leftVY = vertcat(traces.LeftVYDegS);
rightVX = vertcat(traces.RightVXDegS);
rightVY = vertcat(traces.RightVYDegS);
thresholds = struct;
thresholds.Lambda = lambda;
thresholds.LeftSigmaX = robustVelocitySD(leftVX);
thresholds.LeftSigmaY = robustVelocitySD(leftVY);
thresholds.RightSigmaX = robustVelocitySD(rightVX);
thresholds.RightSigmaY = robustVelocitySD(rightVY);
thresholds.LeftX = lambda * thresholds.LeftSigmaX;
thresholds.LeftY = lambda * thresholds.LeftSigmaY;
thresholds.RightX = lambda * thresholds.RightSigmaX;
thresholds.RightY = lambda * thresholds.RightSigmaY;
end


function sigma = robustVelocitySD(values)
values = values(isfinite(values));
if isempty(values)
    sigma = NaN;
    return
end
center = median(values);
sigmaSquared = median(values .^ 2) - center .^ 2;
sigma = sqrt(max(0, sigmaSquared));
if ~isfinite(sigma) || sigma <= eps
    sigma = 1.4826 * median(abs(values - center));
end
if ~isfinite(sigma) || sigma <= eps
    sigma = std(values);
end
if ~isfinite(sigma) || sigma <= eps
    sigma = NaN;
end
end


function events = detectEyeEvents(x, y, vx, vy, radiusX, radiusY, fs, options)
events = emptyEyeEvents();
validRadiusX = isfinite(radiusX) && radiusX > 0;
validRadiusY = isfinite(radiusY) && radiusY > 0;
if ~validRadiusX && ~validRadiusY
    return
end

ellipseValue = zeros(size(vx));
finiteVelocity = true(size(vx));
if validRadiusX
    ellipseValue = ellipseValue + (vx ./ radiusX) .^ 2;
    finiteVelocity = finiteVelocity & isfinite(vx);
end
if validRadiusY
    ellipseValue = ellipseValue + (vy ./ radiusY) .^ 2;
    finiteVelocity = finiteVelocity & isfinite(vy);
end
candidate = finiteVelocity & ellipseValue > 1;
runs = logicalRuns(candidate);
runs = mergeRuns(runs, round(options.MergeGapMs * fs / 1000));
minSamples = max(1, ceil(options.MinDurationMs * fs / 1000));

for i = 1:size(runs, 1)
    on = runs(i, 1);
    off = runs(i, 2);
    if off - on + 1 < minSamples
        continue
    end
    metricOn = max(1, on - 1);
    metricOff = min(numel(x), off + 1);
    if any(~isfinite([x(metricOn), y(metricOn), x(metricOff), y(metricOff)]))
        continue
    end
    dx = x(metricOff) - x(metricOn);
    dy = y(metricOff) - y(metricOn);
    amplitude = hypot(dx, dy);
    durationMs = (off - on + 1) * 1000 / fs;
    if durationMs > options.MaxDurationMs || amplitude > options.MaxAmplitudeDeg || ...
            amplitude < options.MinAmplitudeDeg
        continue
    end
    speed = hypot(vx(on:off), vy(on:off));
    peakVelocity = max(speed, [], 'omitmissing');
    if ~isfinite(peakVelocity)
        continue
    end

    event = makeEyeEvent();
    event.On = on;
    event.Off = off;
    event.DurationMs = durationMs;
    event.DXDeg = dx;
    event.DYDeg = dy;
    event.AmplitudeDeg = amplitude;
    event.PeakVelocityDegS = peakVelocity;
    event.DirectionDeg = mod(atan2d(dy, dx), 360);
    events(end + 1, 1) = event; %#ok<AGROW>
end
end


function events = pairBinocularEvents(leftEvents, rightEvents, fs, ...
        maxInterocularOnsetLagMs, maxDirectionDifference)
events = emptyBinocularEvents();
if isempty(leftEvents) || isempty(rightEvents)
    return
end

candidates = zeros(0, 5);
for i = 1:numel(leftEvents)
    for j = 1:numel(rightEvents)
        overlap = min(leftEvents(i).Off, rightEvents(j).Off) - ...
            max(leftEvents(i).On, rightEvents(j).On) + 1;
        if overlap <= 0
            continue
        end
        directionDifference = angularDifference(leftEvents(i).DirectionDeg, ...
            rightEvents(j).DirectionDeg);
        if directionDifference > maxDirectionDifference
            continue
        end
        onsetLag = abs(rightEvents(j).On - leftEvents(i).On);
        if onsetLag * 1000 / fs > maxInterocularOnsetLagMs
            continue
        end
        candidates(end + 1, :) = [i, j, overlap, onsetLag, directionDifference]; %#ok<AGROW>
    end
end
if isempty(candidates)
    return
end

[~, order] = sortrows([-candidates(:, 3), candidates(:, 4)], [1 2]);
leftUsed = false(numel(leftEvents), 1);
rightUsed = false(numel(rightEvents), 1);
for c = order(:)'
    leftIndex = candidates(c, 1);
    rightIndex = candidates(c, 2);
    if leftUsed(leftIndex) || rightUsed(rightIndex)
        continue
    end
    leftUsed(leftIndex) = true;
    rightUsed(rightIndex) = true;
    left = leftEvents(leftIndex);
    right = rightEvents(rightIndex);

    event = makeBinocularEvent();
    event.DetectionSource = "Binocular";
    event.On = min(left.On, right.On);
    event.Off = max(left.Off, right.Off);
    event.DurationMs = (event.Off - event.On + 1) * 1000 / fs;
    event.Left = left;
    event.Right = right;
    event.LeftCandidateCount = 1;
    event.RightCandidateCount = 1;
    event.InterocularOnsetLagMs = (right.On - left.On) * 1000 / fs;
    event.InterocularDirectionDiffDeg = candidates(c, 5);
    events(end + 1, 1) = event; %#ok<AGROW>
end

if ~isempty(events)
    [~, order] = sort([events.On]);
    events = events(order);
end
end


function events = mergeOverlappingEyeEvents(leftEvents, rightEvents, fs)
events = emptyBinocularEvents();
eventCount = numel(leftEvents) + numel(rightEvents);
if eventCount == 0
    return
end

onsets = nan(eventCount, 1);
offsets = nan(eventCount, 1);
eyeCode = nan(eventCount, 1);
index = 0;
for i = 1:numel(leftEvents)
    index = index + 1;
    onsets(index) = leftEvents(i).On;
    offsets(index) = leftEvents(i).Off;
    eyeCode(index) = 1;
end
for i = 1:numel(rightEvents)
    index = index + 1;
    onsets(index) = rightEvents(i).On;
    offsets(index) = rightEvents(i).Off;
    eyeCode(index) = 2;
end
[~, order] = sortrows([onsets, offsets], [1 2]);
onsets = onsets(order);
offsets = offsets(order);
eyeCode = eyeCode(order);

clusterOn = onsets(1);
clusterOff = offsets(1);
clusterLeftOnsets = onsets(1) .* (eyeCode(1) == 1);
clusterRightOnsets = onsets(1) .* (eyeCode(1) == 2);
clusterLeftOnsets = clusterLeftOnsets(clusterLeftOnsets > 0);
clusterRightOnsets = clusterRightOnsets(clusterRightOnsets > 0);
for i = 2:eventCount
    if onsets(i) <= clusterOff
        clusterOff = max(clusterOff, offsets(i));
        if eyeCode(i) == 1
            clusterLeftOnsets(end + 1) = onsets(i); %#ok<AGROW>
        else
            clusterRightOnsets(end + 1) = onsets(i); %#ok<AGROW>
        end
    else
        events(end + 1, 1) = makeMergedIntervalEvent(clusterOn, clusterOff, ...
            clusterLeftOnsets, clusterRightOnsets, fs); %#ok<AGROW>
        clusterOn = onsets(i);
        clusterOff = offsets(i);
        clusterLeftOnsets = onsets(i) .* (eyeCode(i) == 1);
        clusterRightOnsets = onsets(i) .* (eyeCode(i) == 2);
        clusterLeftOnsets = clusterLeftOnsets(clusterLeftOnsets > 0);
        clusterRightOnsets = clusterRightOnsets(clusterRightOnsets > 0);
    end
end
events(end + 1, 1) = makeMergedIntervalEvent(clusterOn, clusterOff, ...
    clusterLeftOnsets, clusterRightOnsets, fs);
end


function event = makeMergedIntervalEvent(on, off, leftOnsets, rightOnsets, fs)
event = makeBinocularEvent();
event.On = on;
event.Off = off;
event.DurationMs = (off - on + 1) * 1000 / fs;
event.LeftCandidateCount = numel(leftOnsets);
event.RightCandidateCount = numel(rightOnsets);
if ~isempty(leftOnsets) && ~isempty(rightOnsets)
    event.DetectionSource = "Merged";
    event.InterocularOnsetLagMs = (min(rightOnsets) - min(leftOnsets)) * 1000 / fs;
elseif ~isempty(leftOnsets)
    event.DetectionSource = "Left";
    event.InterocularOnsetLagMs = NaN;
else
    event.DetectionSource = "Right";
    event.InterocularOnsetLagMs = NaN;
end
event.InterocularDirectionDiffDeg = NaN;
end


function events = measureDetectedEvents(events, traces, fs)
missingEye = makeMissingEyeEvent();
for i = 1:numel(events)
    if events(i).LeftCandidateCount > 0
        events(i).Left = measureEyeOverPeriod(traces.LeftXDeg, traces.LeftYDeg, ...
            traces.LeftVXDegS, traces.LeftVYDegS, events(i).On, events(i).Off, fs);
    else
        events(i).Left = missingEye;
    end
    if events(i).RightCandidateCount > 0
        events(i).Right = measureEyeOverPeriod(traces.RightXDeg, traces.RightYDeg, ...
            traces.RightVXDegS, traces.RightVYDegS, events(i).On, events(i).Off, fs);
    else
        events(i).Right = missingEye;
    end
    if events(i).LeftCandidateCount > 0 && events(i).RightCandidateCount > 0
        events(i).InterocularDirectionDiffDeg = angularDifference( ...
            events(i).Left.DirectionDeg, events(i).Right.DirectionDeg);
    else
        events(i).InterocularDirectionDiffDeg = NaN;
    end
end
end


function event = measureEyeOverPeriod(x, y, vx, vy, on, off, fs)
event = makeEyeEvent();
event.On = on;
event.Off = off;
event.DurationMs = (off - on + 1) * 1000 / fs;
event.DXDeg = x(off) - x(on);
event.DYDeg = y(off) - y(on);
event.AmplitudeDeg = hypot(event.DXDeg, event.DYDeg);
event.PeakVelocityDegS = max(hypot(vx(on:off), vy(on:off)), [], 'omitmissing');
event.DirectionDeg = mod(atan2d(event.DYDeg, event.DXDeg), 360);
end


function event = makeMissingEyeEvent()
event = makeEyeEvent();
fields = fieldnames(event);
for iField = 1:numel(fields)
    event.(fields{iField}) = NaN;
end
end


function value = eventMeanAmplitude(event)
value = mean([event.Left.AmplitudeDeg, event.Right.AmplitudeDeg], 'omitmissing');
end


function value = eventPeakVelocity(event)
value = max([event.Left.PeakVelocityDegS, event.Right.PeakVelocityDegS], ...
    [], 'omitmissing');
end


function value = eventDirection(event)
dx = mean([event.Left.DXDeg, event.Right.DXDeg], 'omitmissing');
dy = mean([event.Left.DYDeg, event.Right.DYDeg], 'omitmissing');
value = mod(atan2d(dy, dx), 360);
end


function difference = angularDifference(a, b)
difference = abs(mod(a - b + 180, 360) - 180);
end


function runs = logicalRuns(mask)
mask = logical(mask(:));
edges = diff([false; mask; false]);
runs = [find(edges == 1), find(edges == -1) - 1];
end


function merged = mergeRuns(runs, maxGapSamples)
if isempty(runs)
    merged = runs;
    return
end
merged = runs(1, :);
for i = 2:size(runs, 1)
    gap = runs(i, 1) - merged(end, 2) - 1;
    if gap <= maxGapSamples
        merged(end, 2) = runs(i, 2);
    else
        merged(end + 1, :) = runs(i, :); %#ok<AGROW>
    end
end
end


function label = trialTypeLabel(isStim)
if isStim
    label = "Stim";
else
    label = "NonStim";
end
end


function summary = makeSummaryTable(trials, events)
groups = ["NonStim"; "Stim"];
n = numel(groups);
trialCount = zeros(n, 1);
trialsWithMicrosaccade = zeros(n, 1);
trialsWithMicrosaccadePct = zeros(n, 1);
microsaccadeCount = zeros(n, 1);
meanCountPerTrial = nan(n, 1);
medianCountPerTrial = nan(n, 1);
meanRateHz = nan(n, 1);
medianRateHz = nan(n, 1);
meanAmplitudeDeg = nan(n, 1);
meanPeakVelocityDegS = nan(n, 1);

for i = 1:n
    trialMask = trials.TrialType == groups(i) & trials.HasAnalysisWindow;
    eventMask = events.TrialType == groups(i);
    trialCount(i) = nnz(trialMask);
    trialCounts = trials.MicrosaccadeCount(trialMask);
    trialRates = trials.MicrosaccadeRateHz(trialMask);
    trialsWithMicrosaccade(i) = nnz(trialCounts > 0);
    trialsWithMicrosaccadePct(i) = 100 * trialsWithMicrosaccade(i) / trialCount(i);
    microsaccadeCount(i) = sum(trialCounts);
    meanCountPerTrial(i) = mean(trialCounts, 'omitmissing');
    medianCountPerTrial(i) = median(trialCounts, 'omitmissing');
    meanRateHz(i) = mean(trialRates, 'omitmissing');
    medianRateHz(i) = median(trialRates, 'omitmissing');
    meanAmplitudeDeg(i) = mean(events.MeanAmplitudeDeg(eventMask), 'omitmissing');
    meanPeakVelocityDegS(i) = mean(events.PeakVelocityDegS(eventMask), 'omitmissing');
end

summary = table(groups, trialCount, trialsWithMicrosaccade, trialsWithMicrosaccadePct, ...
    microsaccadeCount, meanCountPerTrial, medianCountPerTrial, meanRateHz, ...
    medianRateHz, meanAmplitudeDeg, meanPeakVelocityDegS, ...
    'VariableNames', {'TrialType', 'TrialCount', 'TrialsWithMicrosaccade', ...
    'TrialsWithMicrosaccadePct', 'MicrosaccadeCount', 'MeanCountPerTrial', ...
    'MedianCountPerTrial', 'MeanRateHz', 'MedianRateHz', 'MeanAmplitudeDeg', ...
    'MeanPeakVelocityDegS'});
end


function comparison = makeStimComparisonTable(trials, options)
metric = ["MicrosaccadeRate"; "AnyMicrosaccade"; "MeanAmplitude"; ...
    "MeanPeakVelocity"; "MeanDuration"; "DirectionFirstMoment"];
unit = ["Hz"; "proportion"; "deg"; "deg/s"; "ms"; "unit-vector distance"];
nMetrics = numel(metric);
nonStimNTrials = zeros(nMetrics, 1);
stimNTrials = zeros(nMetrics, 1);
nonStimEstimate = nan(nMetrics, 1);
stimEstimate = nan(nMetrics, 1);
stimMinusNonStim = nan(nMetrics, 1);
testStatistic = nan(nMetrics, 1);
permutationP = nan(nMetrics, 1);
nonStimDirectionDeg = nan(nMetrics, 1);
stimDirectionDeg = nan(nMetrics, 1);

strata = [trials.Condition, trials.SignedCoherence];
scalarValues = {trials.MicrosaccadeRateHz, double(trials.MicrosaccadeCount > 0), ...
    trials.MeanMicrosaccadeAmplitudeDeg, trials.MeanMicrosaccadePeakVelocityDegS, ...
    trials.MeanMicrosaccadeDurationMs};
for m = 1:numel(scalarValues)
    [nonStimEstimate(m), stimEstimate(m), stimMinusNonStim(m), ...
        testStatistic(m), permutationP(m), nonStimNTrials(m), stimNTrials(m)] = ...
        stratifiedScalarPermutation(scalarValues{m}, trials.IsStim, strata, ...
        options.ComparisonPermutationCount, options.ComparisonSeed + m);
end

m = nMetrics;
[nonStimEstimate(m), stimEstimate(m), stimMinusNonStim(m), ...
    testStatistic(m), permutationP(m), nonStimNTrials(m), stimNTrials(m), ...
    nonStimDirectionDeg(m), stimDirectionDeg(m)] = ...
    stratifiedDirectionPermutation(trials.TrialDirectionX, trials.TrialDirectionY, ...
    trials.IsStim, strata, options.ComparisonPermutationCount, ...
    options.ComparisonSeed + m);

permutationCount = repmat(options.ComparisonPermutationCount, nMetrics, 1);
stratification = repmat("Condition + SignedCoherence", nMetrics, 1);
comparison = table(metric, unit, nonStimNTrials, stimNTrials, nonStimEstimate, ...
    stimEstimate, stimMinusNonStim, testStatistic, permutationP, ...
    nonStimDirectionDeg, stimDirectionDeg, permutationCount, stratification, ...
    'VariableNames', {'Metric', 'Unit', 'NonStimNTrials', 'StimNTrials', ...
    'NonStimEstimate', 'StimEstimate', 'StimMinusNonStim', 'TestStatistic', ...
    'PermutationP', 'NonStimDirectionDeg', 'StimDirectionDeg', ...
    'PermutationCount', 'Stratification'});
end


function [nonStimMean, stimMean, difference, statistic, pValue, ...
        nonStimN, stimN] = stratifiedScalarPermutation(values, isStim, strata, ...
        permutationCount, seed)
valid = isfinite(values) & all(isfinite(strata), 2);
values = values(valid);
isStim = logical(isStim(valid));
strata = strata(valid, :);
nonStimN = nnz(~isStim);
stimN = nnz(isStim);
if nonStimN == 0 || stimN == 0
    [nonStimMean, stimMean, difference, statistic, pValue] = deal(NaN);
    return
end
nonStimMean = mean(values(~isStim));
stimMean = mean(values(isStim));
difference = stimMean - nonStimMean;
statistic = abs(difference);

previousRng = rng;
cleanup = onCleanup(@() rng(previousRng));
rng(seed, 'twister');
[~, ~, stratumID] = unique(strata, 'rows');
nullStatistic = nan(permutationCount, 1);
for b = 1:permutationCount
    permutedStim = permuteWithinStrata(isStim, stratumID);
    nullDifference = mean(values(permutedStim)) - mean(values(~permutedStim));
    nullStatistic(b) = abs(nullDifference);
end
pValue = (1 + nnz(nullStatistic >= statistic)) / (permutationCount + 1);
end


function [nonStimLength, stimLength, lengthDifference, statistic, pValue, ...
        nonStimN, stimN, nonStimDirection, stimDirection] = ...
        stratifiedDirectionPermutation(x, y, isStim, strata, permutationCount, seed)
valid = isfinite(x) & isfinite(y) & all(isfinite(strata), 2);
x = x(valid);
y = y(valid);
isStim = logical(isStim(valid));
strata = strata(valid, :);
nonStimN = nnz(~isStim);
stimN = nnz(isStim);
if nonStimN == 0 || stimN == 0
    [nonStimLength, stimLength, lengthDifference, statistic, pValue, ...
        nonStimDirection, stimDirection] = deal(NaN);
    return
end
[nonStimVector, nonStimLength, nonStimDirection] = meanDirectionVector(x(~isStim), y(~isStim));
[stimVector, stimLength, stimDirection] = meanDirectionVector(x(isStim), y(isStim));
lengthDifference = stimLength - nonStimLength;
statistic = hypot(stimVector(1) - nonStimVector(1), ...
    stimVector(2) - nonStimVector(2));

previousRng = rng;
cleanup = onCleanup(@() rng(previousRng));
rng(seed, 'twister');
[~, ~, stratumID] = unique(strata, 'rows');
nullStatistic = nan(permutationCount, 1);
for b = 1:permutationCount
    permutedStim = permuteWithinStrata(isStim, stratumID);
    nonStimVectorPermuted = [mean(x(~permutedStim)), mean(y(~permutedStim))];
    stimVectorPermuted = [mean(x(permutedStim)), mean(y(permutedStim))];
    nullStatistic(b) = hypot(stimVectorPermuted(1) - nonStimVectorPermuted(1), ...
        stimVectorPermuted(2) - nonStimVectorPermuted(2));
end
pValue = (1 + nnz(nullStatistic >= statistic)) / (permutationCount + 1);
end


function permuted = permuteWithinStrata(labels, stratumID)
permuted = labels;
for s = 1:max(stratumID)
    index = find(stratumID == s);
    permuted(index) = labels(index(randperm(numel(index))));
end
end


function [vector, lengthValue, directionDeg] = meanDirectionVector(x, y)
vector = [mean(x), mean(y)];
lengthValue = hypot(vector(1), vector(2));
directionDeg = mod(atan2d(vector(2), vector(1)), 360);
end


function stats = makeDirectionStatsTable(events)
groups = ["NonStim"; "Stim"];
nGroups = numel(groups);
eventCount = zeros(nGroups, 1);
meanDirectionDeg = nan(nGroups, 1);
meanResultantLength = nan(nGroups, 1);
rayleighZ = nan(nGroups, 1);
rayleighP = nan(nGroups, 1);
rejectUniform05 = false(nGroups, 1);
unitVectorSumX = nan(nGroups, 1);
unitVectorSumY = nan(nGroups, 1);
displacementVectorSumXDeg = nan(nGroups, 1);
displacementVectorSumYDeg = nan(nGroups, 1);
displacementVectorSumMagnitudeDeg = nan(nGroups, 1);
displacementVectorSumDirectionDeg = nan(nGroups, 1);
meanDisplacementXDeg = nan(nGroups, 1);
meanDisplacementYDeg = nan(nGroups, 1);
meanDisplacementMagnitudeDeg = nan(nGroups, 1);
trialsWithEvents = zeros(nGroups, 1);
trialMeanDirectionDeg = nan(nGroups, 1);
trialMeanResultantLength = nan(nGroups, 1);
trialMeanRayleighZ = nan(nGroups, 1);
trialMeanRayleighP = nan(nGroups, 1);
trialMeanRejectUniform05 = false(nGroups, 1);

for g = 1:nGroups
    groupEvents = events(events.TrialType == groups(g), :);
    directionValues = groupEvents.DirectionDeg;
    eventCount(g) = numel(directionValues);
    [rayleighP(g), rayleighZ(g), meanResultantLength(g), ...
        meanDirectionDeg(g), unitVectorSumX(g), unitVectorSumY(g)] = ...
        rayleighTestDegrees(directionValues);
    rejectUniform05(g) = rayleighP(g) < 0.05;

    sumX = sum(groupEvents.MeanDXDeg, 'omitmissing');
    sumY = sum(groupEvents.MeanDYDeg, 'omitmissing');
    displacementVectorSumXDeg(g) = sumX;
    displacementVectorSumYDeg(g) = sumY;
    displacementVectorSumMagnitudeDeg(g) = hypot(sumX, sumY);
    displacementVectorSumDirectionDeg(g) = mod(atan2d(sumY, sumX), 360);
    meanDisplacementXDeg(g) = sumX / eventCount(g);
    meanDisplacementYDeg(g) = sumY / eventCount(g);
    meanDisplacementMagnitudeDeg(g) = hypot(meanDisplacementXDeg(g), ...
        meanDisplacementYDeg(g));

    trialIDs = unique(groupEvents.TrialIndex);
    trialsWithEvents(g) = numel(trialIDs);
    trialDirections = nan(numel(trialIDs), 1);
    for t = 1:numel(trialIDs)
        trialAngles = deg2rad(groupEvents.DirectionDeg( ...
            groupEvents.TrialIndex == trialIDs(t)));
        trialDirections(t) = mod(atan2d(sum(sin(trialAngles)), ...
            sum(cos(trialAngles))), 360);
    end
    [trialMeanRayleighP(g), trialMeanRayleighZ(g), ...
        trialMeanResultantLength(g), trialMeanDirectionDeg(g)] = ...
        rayleighTestDegrees(trialDirections);
    trialMeanRejectUniform05(g) = trialMeanRayleighP(g) < 0.05;
end

stats = table(groups, eventCount, meanDirectionDeg, meanResultantLength, ...
    rayleighZ, rayleighP, rejectUniform05, unitVectorSumX, unitVectorSumY, ...
    displacementVectorSumXDeg, displacementVectorSumYDeg, ...
    displacementVectorSumMagnitudeDeg, displacementVectorSumDirectionDeg, ...
    meanDisplacementXDeg, meanDisplacementYDeg, meanDisplacementMagnitudeDeg, ...
    trialsWithEvents, trialMeanDirectionDeg, trialMeanResultantLength, ...
    trialMeanRayleighZ, trialMeanRayleighP, trialMeanRejectUniform05, ...
    'VariableNames', {'TrialType', 'EventCount', 'MeanDirectionDeg', ...
    'MeanResultantLength', 'RayleighZ', 'RayleighP', 'RejectUniform05', ...
    'UnitVectorSumX', 'UnitVectorSumY', 'DisplacementVectorSumXDeg', ...
    'DisplacementVectorSumYDeg', 'DisplacementVectorSumMagnitudeDeg', ...
    'DisplacementVectorSumDirectionDeg', 'MeanDisplacementXDeg', ...
    'MeanDisplacementYDeg', 'MeanDisplacementMagnitudeDeg', ...
    'TrialsWithEvents', 'TrialMeanDirectionDeg', 'TrialMeanResultantLength', ...
    'TrialMeanRayleighZ', 'TrialMeanRayleighP', 'TrialMeanRejectUniform05'});
end


function [pValue, z, meanResultantLength, meanDirectionDeg, sumCos, sumSin] = ...
        rayleighTestDegrees(directionDeg)
directionDeg = directionDeg(isfinite(directionDeg));
n = numel(directionDeg);
if n == 0
    [pValue, z, meanResultantLength, meanDirectionDeg, sumCos, sumSin] = ...
        deal(NaN);
    return
end

theta = deg2rad(directionDeg(:));
sumCos = sum(cos(theta));
sumSin = sum(sin(theta));
resultantLength = hypot(sumCos, sumSin);
meanResultantLength = resultantLength / n;
meanDirectionDeg = mod(atan2d(sumSin, sumCos), 360);
z = resultantLength ^ 2 / n;

% Stable finite-sample approximation used by common circular-statistics tools.
logP = sqrt(1 + 4 * n + 4 * (n ^ 2 - resultantLength ^ 2)) - (1 + 2 * n);
pValue = min(1, max(0, exp(logP)));
end


function makeDirectionEnvelopePlot(events, stats, outputFile, options)
figureHandle = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1300 620]);
layout = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, sprintf(['Microsaccade displacement vectors and %.0f%% ' ...
    'directional amplitude envelopes'], options.DirectionEnvelopePercentile));
groups = ["NonStim", "Stim"];
colors = [0.15 0.45 0.75; 0.85 0.25 0.20];

allAmplitude = hypot(events.MeanDXDeg, events.MeanDYDeg);
axisLimit = max(0.1, empiricalQuantile(allAmplitude, 0.995) * 1.1);
for g = 1:numel(groups)
    ax = nexttile;
    groupEvents = events(events.TrialType == groups(g), :);
    x = groupEvents.MeanDXDeg;
    y = groupEvents.MeanDYDeg;
    direction = mod(groupEvents.DirectionDeg, 360);
    amplitude = hypot(x, y);
    [envelopeX, envelopeY] = directionalAmplitudeEnvelope(direction, amplitude, ...
        options.DirectionBinCount, options.DirectionEnvelopePercentile / 100);

    hold(ax, 'on');
    endpointColor = 0.70 * [1 1 1] + 0.30 * colors(g, :);
    scatter(ax, x, y, 10, endpointColor, 'filled', ...
        'MarkerFaceAlpha', 0.30, 'MarkerEdgeAlpha', 0.15);
    fill(ax, envelopeX, envelopeY, colors(g, :), 'FaceAlpha', 0.18, ...
        'EdgeColor', colors(g, :), 'LineWidth', 2);

    statsRow = stats(stats.TrialType == groups(g), :);
    quiver(ax, 0, 0, statsRow.MeanDisplacementXDeg, ...
        statsRow.MeanDisplacementYDeg, 0, 'Color', [0.05 0.05 0.05], ...
        'LineWidth', 2.5, 'MaxHeadSize', 0.8);
    plot(ax, 0, 0, 'k+', 'MarkerSize', 9, 'LineWidth', 1.5);
    xline(ax, 0, ':', 'Color', [0.65 0.65 0.65], 'HandleVisibility', 'off');
    yline(ax, 0, ':', 'Color', [0.65 0.65 0.65], 'HandleVisibility', 'off');

    axis(ax, 'equal');
    xlim(ax, [-axisLimit axisLimit]);
    ylim(ax, [-axisLimit axisLimit]);
    if options.RequireBinocular
        xlabel(ax, 'Mean binocular horizontal displacement (deg)');
        ylabel(ax, 'Mean binocular vertical displacement (deg)');
    else
        xlabel(ax, 'Event horizontal displacement (deg)');
        ylabel(ax, 'Event vertical displacement (deg)');
    end
    title(ax, sprintf('%s: n = %d, mean direction = %.1f deg', ...
        groups(g), height(groupEvents), statsRow.MeanDirectionDeg));
    subtitle(ax, sprintf('Rayleigh p = %s, mean resultant length = %.3f', ...
        formatPValue(statsRow.RayleighP), statsRow.MeanResultantLength));
    legend(ax, {'Event endpoints', sprintf('%.0f%% amplitude envelope', ...
        options.DirectionEnvelopePercentile), 'Vector sum / N'}, ...
        'Location', 'best');
    text(ax, 0.03, 0.03, sprintf('Raw displacement sum = (%.2f, %.2f) deg', ...
        statsRow.DisplacementVectorSumXDeg, statsRow.DisplacementVectorSumYDeg), ...
        'Units', 'normalized', 'VerticalAlignment', 'bottom');
    box(ax, 'off');
end

exportgraphics(figureHandle, outputFile, 'Resolution', 180);
close(figureHandle);
end


function [xEnvelope, yEnvelope] = directionalAmplitudeEnvelope(directionDeg, amplitude, ...
        binCount, quantileProbability)
binWidth = 360 / binCount;
centers = (0:binCount-1)' * binWidth + binWidth / 2;
radius = nan(binCount, 1);
for b = 1:binCount
    lowerEdge = (b - 1) * binWidth;
    upperEdge = b * binWidth;
    inBin = directionDeg >= lowerEdge & directionDeg < upperEdge;
    radius(b) = empiricalQuantile(amplitude(inBin), quantileProbability);
end
radius = fillCircularMissing(radius);
xEnvelope = [radius .* cosd(centers); radius(1) * cosd(centers(1))];
yEnvelope = [radius .* sind(centers); radius(1) * sind(centers(1))];
end


function values = fillCircularMissing(values)
missing = ~isfinite(values);
if ~any(missing)
    return
end
known = find(~missing);
if isempty(known)
    values(:) = 0;
elseif isscalar(known)
    values(:) = values(known);
else
    n = numel(values);
    query = find(missing);
    extendedIndex = [known - n; known; known + n];
    extendedValues = [values(known); values(known); values(known)];
    values(query) = interp1(extendedIndex, extendedValues, query, 'linear');
end
end


function value = empiricalQuantile(values, probability)
values = sort(values(isfinite(values)));
if isempty(values)
    value = NaN;
    return
end
if isscalar(values)
    value = values;
    return
end
position = 1 + (numel(values) - 1) * probability;
lower = floor(position);
upper = ceil(position);
fraction = position - lower;
value = values(lower) + fraction * (values(upper) - values(lower));
end


function label = formatPValue(pValue)
if ~isfinite(pValue)
    label = 'NaN';
elseif pValue < 0.001
    label = sprintf('%.2e', pValue);
else
    label = sprintf('%.3f', pValue);
end
end


function makeExampleTrajectoryPlot(traces, events, outputFile, ...
        exampleCountPerCondition, options)
if isempty(events)
    warning('No microsaccades were available for the example trajectory plot.');
    figureHandle = figure('Visible', 'off', 'Color', 'white', ...
        'Position', [100 100 1300 650]);
    layout = tiledlayout(figureHandle, 1, 2, 'TileSpacing', 'compact', ...
        'Padding', 'compact');
    title(layout, 'Random microsaccade trajectories with all-event envelopes');
    groups = ["NonStim", "Stim"];
    for g = 1:numel(groups)
        ax = nexttile(layout);
        hold(ax, 'on');
        xline(ax, 0, ':', 'Color', [0.70 0.70 0.70]);
        yline(ax, 0, ':', 'Color', [0.70 0.70 0.70]);
        text(ax, 0, 0, 'No microsaccades detected', ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'Color', [0.35 0.35 0.35]);
        xlim(ax, [-0.05 0.05]);
        ylim(ax, [-0.05 0.05]);
        axis(ax, 'equal');
        grid(ax, 'on');
        box(ax, 'off');
        xlabel(ax, 'Horizontal displacement from event onset (deg)');
        ylabel(ax, 'Vertical displacement from event onset (deg)');
        title(ax, sprintf('%s: 0 events', groups(g)));
        ax.Toolbar.Visible = 'off';
    end
    exportgraphics(figureHandle, outputFile, 'Resolution', 180);
    close(figureHandle);
    return
end

figureHandle = figure('Visible', 'off', 'Color', 'white', ...
    'Position', [100 100 1300 650]);
layout = tiledlayout(figureHandle, 1, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
title(layout, sprintf(['Random microsaccade trajectories with all-event ' ...
    '%.0f%% envelopes'], options.DirectionEnvelopePercentile));
groups = ["NonStim", "Stim"];
baseColors = [0.10 0.38 0.72; 0.82 0.20 0.15];
previousRng = rng;
cleanup = onCleanup(@() rng(previousRng));

for g = 1:numel(groups)
    rng(options.ExampleTrajectorySeed + g, 'twister');
    selectedRows = selectRandomEventRows(events, groups(g), ...
        exampleCountPerCondition);
    groupEvents = events(events.TrialType == groups(g), :);
    direction = mod(groupEvents.DirectionDeg, 360);
    amplitude = hypot(groupEvents.MeanDXDeg, groupEvents.MeanDYDeg);
    [envelopeX, envelopeY] = directionalAmplitudeEnvelope(direction, amplitude, ...
        options.DirectionBinCount, options.DirectionEnvelopePercentile / 100);
    colors = makeGroupColors(baseColors(g, :), numel(selectedRows));

    ax = nexttile(layout);
    hold(ax, 'on');
    fill(ax, envelopeX, envelopeY, baseColors(g, :), 'FaceAlpha', 0.12, ...
        'EdgeColor', baseColors(g, :), 'LineWidth', 2, ...
        'DisplayName', sprintf('All-event %.0f%% envelope', ...
        options.DirectionEnvelopePercentile));
    xline(ax, 0, ':', 'Color', [0.70 0.70 0.70], ...
        'HandleVisibility', 'off');
    yline(ax, 0, ':', 'Color', [0.70 0.70 0.70], ...
        'HandleVisibility', 'off');

    allX = envelopeX(:);
    allY = envelopeY(:);
    validCount = 0;
    for i = 1:numel(selectedRows)
        event = events(selectedRows(i), :);
        [x, y, valid] = centeredEventTrajectory(traces, event);
        if ~valid
            continue
        end
        validCount = validCount + 1;
        visibility = 'off';
        if validCount == 1
            visibility = 'on';
        end
        plot(ax, x, y, '-', 'Color', colors(i, :), 'LineWidth', 1.5, ...
            'HandleVisibility', visibility, 'DisplayName', 'Random examples');
        scatter(ax, x(1), y(1), 24, 'o', 'MarkerEdgeColor', colors(i, :), ...
            'MarkerFaceColor', 'white', 'LineWidth', 1, ...
            'HandleVisibility', 'off');
        scatter(ax, x(end), y(end), 28, 'o', ...
            'MarkerEdgeColor', colors(i, :), 'MarkerFaceColor', colors(i, :), ...
            'HandleVisibility', 'off');
        allX = [allX; x(:)]; %#ok<AGROW>
        allY = [allY; y(:)]; %#ok<AGROW>
    end

    grid(ax, 'on');
    box(ax, 'off');
    xlabel(ax, 'Horizontal displacement from event onset (deg)');
    ylabel(ax, 'Vertical displacement from event onset (deg)');
    title(ax, sprintf('%s: %d random traces of %d events', ...
        groups(g), validCount, height(groupEvents)));
    if validCount > 0
        span = max([max(allX) - min(allX), max(allY) - min(allY), 0.05]);
        centerX = (min(allX) + max(allX)) / 2;
        centerY = (min(allY) + max(allY)) / 2;
        limit = 0.58 * span;
        xlim(ax, centerX + [-limit, limit]);
        ylim(ax, centerY + [-limit, limit]);
    end
    axis(ax, 'equal');
    ax.Toolbar.Visible = 'off';
    legend(ax, 'Location', 'best');
end

exportgraphics(figureHandle, outputFile, 'Resolution', 180);
close(figureHandle);
end


function rows = selectRandomEventRows(events, trialType, requestedCount)
rows = find(events.TrialType == trialType);
if isempty(rows) || requestedCount == 0
    return
end
if numel(rows) > requestedCount
    rows = rows(randperm(numel(rows), requestedCount));
end
end


function [x, y, valid] = centeredEventTrajectory(traces, event)
x = [];
y = [];
valid = false;
traceIndex = find([traces.TrialIndex]' == event.TrialIndex, 1, 'first');
if isempty(traceIndex)
    return
end
trace = traces(traceIndex);
sampleMask = trace.TimeRelVisualStimS >= event.OnsetRelVisualStimS & ...
    trace.TimeRelVisualStimS <= event.OffsetRelVisualStimS;
if nnz(sampleMask) < 2
    return
end
switch event.DetectionSource
    case {"Merged", "Binocular"}
        x = mean([trace.LeftXDeg(sampleMask), trace.RightXDeg(sampleMask)], ...
            2, 'omitmissing');
        y = mean([trace.LeftYDeg(sampleMask), trace.RightYDeg(sampleMask)], ...
            2, 'omitmissing');
    case "Left"
        x = trace.LeftXDeg(sampleMask);
        y = trace.LeftYDeg(sampleMask);
    case "Right"
        x = trace.RightXDeg(sampleMask);
        y = trace.RightYDeg(sampleMask);
    otherwise
        return
end
valid = numel(x) >= 2 && all(isfinite([x(1), y(1)]));
if valid
    x = x - x(1);
    y = y - y(1);
end
end


function colors = makeGroupColors(baseColor, count)
if count == 0
    colors = zeros(0, 3);
    return
end
whiteMix = linspace(0.45, 0, count)';
colors = baseColor .* (1 - whiteMix) + whiteMix;
end


function makeQCPlot(traces, trials, events, outputFile, options)
figureHandle = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1300 850]);
layout = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
if options.RequireBinocular
    title(layout, 'Binocular microsaccade detection QC');
    eventCountLabel = 'Binocular microsaccades per trial';
else
    title(layout, 'Either-eye microsaccade detection QC');
    eventCountLabel = 'Merged/unmatched events per trial';
end

plotExampleTrial(nexttile, "NonStim", traces, trials, events);
plotExampleTrial(nexttile, "Stim", traces, trials, events);

ax = nexttile;
hold(ax, 'on');
histogram(ax, trials.MicrosaccadeCount(trials.TrialType == "NonStim"), ...
    'BinMethod', 'integers', 'DisplayStyle', 'stairs', 'LineWidth', 2, ...
    'EdgeColor', [0.15 0.45 0.75]);
histogram(ax, trials.MicrosaccadeCount(trials.TrialType == "Stim"), ...
    'BinMethod', 'integers', 'DisplayStyle', 'stairs', 'LineWidth', 2, ...
    'EdgeColor', [0.85 0.25 0.20]);
xlabel(ax, eventCountLabel);
ylabel(ax, 'Trial count');
legend(ax, {'NonStim', 'Stim'}, 'Location', 'best');
title(ax, 'Per-trial event counts');
box(ax, 'off');

ax = nexttile;
groupNames = ["NonStim", "Stim"];
meanRates = [mean(trials.MicrosaccadeRateHz(trials.TrialType == groupNames(1)), 'omitmissing'), ...
    mean(trials.MicrosaccadeRateHz(trials.TrialType == groupNames(2)), 'omitmissing')];
bars = bar(ax, meanRates, 0.65, 'FaceColor', 'flat');
bars.CData = [0.15 0.45 0.75; 0.85 0.25 0.20];
set(ax, 'XTick', 1:2, 'XTickLabel', cellstr(groupNames));
ylabel(ax, 'Mean microsaccade rate (Hz)');
title(ax, 'Group comparison');
box(ax, 'off');

exportgraphics(figureHandle, outputFile, 'Resolution', 180);
close(figureHandle);
end


function plotExampleTrial(ax, groupName, traces, trials, events)
groupMask = trials.TrialType == groupName & trials.HasAnalysisWindow;
eventTrialMask = groupMask & trials.MicrosaccadeCount > 0;
candidate = find(eventTrialMask, 1, 'first');
if isempty(candidate)
    candidate = find(groupMask, 1, 'first');
end
if isempty(candidate)
    title(ax, sprintf('%s: no usable trial', groupName));
    return
end

trace = traces(candidate);
time = trace.TimeRelVisualStimS;
horizontal = mean([trace.LeftXDeg, trace.RightXDeg], 2, 'omitmissing');
vertical = mean([trace.LeftYDeg, trace.RightYDeg], 2, 'omitmissing');
plot(ax, time, horizontal, 'Color', [0.10 0.35 0.65], 'LineWidth', 1.2);
hold(ax, 'on');
plot(ax, time, vertical, 'Color', [0.75 0.25 0.15], 'LineWidth', 1.2);
trialEvents = events(events.TrialIndex == trials.TrialIndex(candidate), :);
for i = 1:height(trialEvents)
    xline(ax, trialEvents.OnsetRelVisualStimS(i), ':', 'Color', [0.1 0.1 0.1], ...
        'LineWidth', 1, 'HandleVisibility', 'off');
end
xlabel(ax, 'Time from visual stimulus onset (s)');
ylabel(ax, 'Mean binocular position (deg)');
legend(ax, {'Horizontal', 'Vertical'}, 'Location', 'best');
title(ax, sprintf('%s example, trial %d', groupName, trials.TrialIndex(candidate)));
box(ax, 'off');
end


function row = makeEventTrajectoryRow(eventRow, event, trace, outputEvent)
row = makeEventTrajectoryRowTemplate();
sampleIndex = (event.On:event.Off)';
time = trace.TimeRelVisualStimS(sampleIndex);
leftX = trace.LeftXDeg(sampleIndex);
leftY = trace.LeftYDeg(sampleIndex);
rightX = trace.RightXDeg(sampleIndex);
rightY = trace.RightYDeg(sampleIndex);
leftVX = trace.LeftVXDegS(sampleIndex);
leftVY = trace.LeftVYDegS(sampleIndex);
rightVX = trace.RightVXDegS(sampleIndex);
rightVY = trace.RightVYDegS(sampleIndex);

switch event.DetectionSource
    case {"Merged", "Binocular"}
        eventX = mean([leftX, rightX], 2, 'omitmissing');
        eventY = mean([leftY, rightY], 2, 'omitmissing');
        eventVX = mean([leftVX, rightVX], 2, 'omitmissing');
        eventVY = mean([leftVY, rightVY], 2, 'omitmissing');
    case "Left"
        eventX = leftX;
        eventY = leftY;
        eventVX = leftVX;
        eventVY = leftVY;
    case "Right"
        eventX = rightX;
        eventY = rightY;
        eventVX = rightVX;
        eventVY = rightVY;
end

row.EventRow = eventRow;
row.TrialIndex = outputEvent.TrialIndex;
row.EventNumberInTrial = outputEvent.EventNumberInTrial;
row.TrialType = outputEvent.TrialType;
row.DetectionSource = outputEvent.DetectionSource;
row.Condition = outputEvent.Condition;
row.SignedCoherence = outputEvent.SignedCoherence;
row.OnsetRelVisualStimS = outputEvent.OnsetRelVisualStimS;
row.OffsetRelVisualStimS = outputEvent.OffsetRelVisualStimS;
row.OnsetRelElectricalStimS = outputEvent.OnsetRelElectricalStimS;
row.SampleIndexInAnalysisTrace = {sampleIndex};
row.TimeRelVisualStimS = {time};
row.TimeRelEventOnsetMs = {(time - time(1)) * 1000};
row.LeftXDeg = {leftX};
row.LeftYDeg = {leftY};
row.RightXDeg = {rightX};
row.RightYDeg = {rightY};
row.LeftVXDegS = {leftVX};
row.LeftVYDegS = {leftVY};
row.RightVXDegS = {rightVX};
row.RightVYDegS = {rightVY};
row.EventXDeg = {eventX};
row.EventYDeg = {eventY};
row.EventVXDegS = {eventVX};
row.EventVYDegS = {eventVY};
row.CenteredEventXDeg = {eventX - eventX(1)};
row.CenteredEventYDeg = {eventY - eventY(1)};
end


function output = makeEventTrialTable(trials, events, TrialInfo)
if isempty(events)
    output = trials([], :);
else
    eventTrialIndex = unique(events.TrialIndex, 'stable');
    [found, trialRows] = ismember(eventTrialIndex, trials.TrialIndex);
    assert(all(found), 'An event TrialIndex was missing from TrialTable.');
    output = trials(trialRows, :);
end

originalEID = cell(height(output), 1);
originalEventT = cell(height(output), 1);
for i = 1:height(output)
    trialIndex = output.TrialIndex(i);
    originalEID{i} = TrialInfo(trialIndex).EID(:);
    originalEventT{i} = TrialInfo(trialIndex).EventT(:);
end
output = addvars(output, originalEID, originalEventT, 'After', 'TrialIndex', ...
    'NewVariableNames', {'OriginalEID', 'OriginalEventT'});
end


function rows = emptyEventTrajectoryRows()
rows = repmat(makeEventTrajectoryRowTemplate(), 0, 1);
end


function output = emptyEventTrajectoryTable()
output = struct2table(makeEventTrajectoryRowTemplate(), 'AsArray', true);
output(1, :) = [];
end


function row = makeEventTrajectoryRowTemplate()
row = struct( ...
    'EventRow', NaN, 'TrialIndex', NaN, 'EventNumberInTrial', NaN, ...
    'TrialType', "", 'DetectionSource', "", 'Condition', NaN, ...
    'SignedCoherence', NaN, 'OnsetRelVisualStimS', NaN, ...
    'OffsetRelVisualStimS', NaN, 'OnsetRelElectricalStimS', NaN, ...
    'SampleIndexInAnalysisTrace', {{}}, 'TimeRelVisualStimS', {{}}, ...
    'TimeRelEventOnsetMs', {{}}, 'LeftXDeg', {{}}, 'LeftYDeg', {{}}, ...
    'RightXDeg', {{}}, 'RightYDeg', {{}}, 'LeftVXDegS', {{}}, ...
    'LeftVYDegS', {{}}, 'RightVXDegS', {{}}, 'RightVYDegS', {{}}, ...
    'EventXDeg', {{}}, 'EventYDeg', {{}}, 'EventVXDegS', {{}}, ...
    'EventVYDegS', {{}}, 'CenteredEventXDeg', {{}}, ...
    'CenteredEventYDeg', {{}});
end


function events = emptyEyeEvents()
events = repmat(makeEyeEvent(), 0, 1);
end


function event = makeEyeEvent()
event = struct('On', [], 'Off', [], 'DurationMs', [], 'DXDeg', [], ...
    'DYDeg', [], 'AmplitudeDeg', [], 'PeakVelocityDegS', [], 'DirectionDeg', []);
end


function events = emptyBinocularEvents()
events = repmat(makeBinocularEvent(), 0, 1);
end


function event = makeBinocularEvent()
event = struct('On', [], 'Off', [], 'DurationMs', [], ...
    'Left', makeEyeEvent(), 'Right', makeEyeEvent(), ...
    'DetectionSource', "", 'LeftCandidateCount', 0, ...
    'RightCandidateCount', 0, 'InterocularOnsetLagMs', [], ...
    'InterocularDirectionDiffDeg', []);
end


function events = emptyOutputEvents()
events = repmat(makeOutputEvent(), 0, 1);
end


function event = makeOutputEvent()
event = struct( ...
    'TrialIndex', NaN, 'TrialType', "", 'IsStim', false, ...
    'Condition', NaN, 'SignedCoherence', NaN, ...
    'ElectricalStimOnRelVisualS', NaN, 'EventNumberInTrial', NaN, ...
    'DetectionSource', "", 'OnsetRelVisualStimS', NaN, ...
    'OffsetRelVisualStimS', NaN, 'OnsetRelElectricalStimS', NaN, ...
    'DurationMs', NaN, 'LeftAmplitudeDeg', NaN, ...
    'RightAmplitudeDeg', NaN, 'MeanAmplitudeDeg', NaN, ...
    'LeftPeakVelocityDegS', NaN, 'RightPeakVelocityDegS', NaN, ...
    'PeakVelocityDegS', NaN, 'MeanDXDeg', NaN, 'MeanDYDeg', NaN, ...
    'DirectionDeg', NaN, 'InterocularOnsetLagMs', NaN, ...
    'InterocularDirectionDiffDeg', NaN);
end


function output = emptyMicrosaccadeTable()
output = struct2table(makeOutputEvent(), 'AsArray', true);
output(1, :) = [];
end

function analysis = RunQuickTuningWindowDiameterStim2D(options)
%RUNQUICKTUNINGWINDOWDIAMETERSTIM2D Nine-contact diameter for MT/FST 2D.
%
% The cohort is defined at the stimulation channel using source-table
% MonoL/MonoR p_AI < 0.05 and Z3D-Z2D < 0. A complete live physical window
% across the requested relative-position window is required. Dead
% non-stimulation contacts are skipped. MT and FST diameter distributions
% are overlaid with shared bins.

arguments
    options.StateFile (1, 1) string = ...
        "C:\EM\PopulationAnalysis\unit_table_gof.mat"
    options.OutputFolder (1, 1) string = [ ...
        "C:\EM\StimTuningAnalysis\" + ...
        "QuickTuningWindowDiameter_Stim2D_Minus4Plus4"]
    options.RelativePositions (1, :) double ...
        {mustBeInteger} = -4:4
    options.Areas (1, :) string = ["MT", "FST"]
    options.Monkey (1, 1) string ...
        {mustBeMember(options.Monkey, ["Both", "Jim", "Clay"])} = "Both"
    options.NumSplits (1, 1) double ...
        {mustBeInteger, mustBePositive} = 200
    options.MinTrialsPerCondition (1, 1) double ...
        {mustBeInteger, mustBeGreaterThanOrEqual( ...
        options.MinTrialsPerCondition, 2)} = 2
    options.RandomSeed (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 1
    options.FigureVisible (1, 1) logical = false
    options.JimCacheFolder (1, 1) string = "C:\Jim\StimData"
    options.ClayCacheFolder (1, 1) string = "C:\Clay\StimData"
    options.ChannelMap (1, :) double ...
        {mustBeInteger, mustBePositive} = ...
        [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]
end

if ~isfile(options.StateFile)
    error('QuickTuningDiameterRunner:MissingStateFile', ...
        'Input MAT file does not exist: %s', options.StateFile);
end
areas = unique(upper(options.Areas), 'stable');
if isempty(areas) || any(~ismember(areas, ["MT", "FST"]))
    error('QuickTuningDiameterRunner:InvalidAreas', ...
        'Areas must contain MT, FST, or both.');
end
ensureFolder(options.OutputFolder);
scriptFolder = string(fileparts(mfilename('fullpath')));
projectFolder = string(fileparts(scriptFolder));
addpath(scriptFolder, fullfile(projectFolder, 'PopulationAnalysis'));

[unitTable, resolvedStateFile, workbookAudit] = ...
    LoadLatestUnitTableGof(options.StateFile);
candidateMask = stimChannel2DCandidateMask( ...
    unitTable, areas, options.Monkey);
audit = ComputeQuickTuningWindowDiameter(unitTable, ...
    JimCacheFolder=options.JimCacheFolder, ...
    ClayCacheFolder=options.ClayCacheFolder, ...
    ChannelMap=options.ChannelMap, ...
    RelativePositions=options.RelativePositions, ...
    CandidateMask=candidateMask, NumSplits=options.NumSplits, ...
    MinTrialsPerCondition=options.MinTrialsPerCondition, ...
    RandomSeed=options.RandomSeed, AllowDeadChannels=true);
successful = audit.Status == "Success" & ...
    isfinite(audit.WindowDiameterSquared);
if ~any(successful)
    error('QuickTuningDiameterRunner:NoSuccessfulSessions', ...
        'No candidate session had a complete analyzable nine-contact window.');
end

scalarAudit = scalarAuditTable(audit);
pairTable = buildPairTable(audit, successful);
summaryTable = summarizeDiameter(audit, candidateMask, successful);
spanTable = summarizeDiameterSpans( ...
    audit, successful, options.RelativePositions);
writetable(scalarAudit, fullfile(options.OutputFolder, ...
    'QuickTuningWindowDiameter_SessionAudit.csv'));
writetable(pairTable, fullfile(options.OutputFolder, ...
    'QuickTuningWindowDiameter_AllPairDistances.csv'));
writetable(summaryTable, fullfile(options.OutputFolder, ...
    'QuickTuningWindowDiameter_DistributionSummary.csv'));
writetable(spanTable, fullfile(options.OutputFolder, ...
    'QuickTuningWindowDiameter_MaxPairSpanSummary.csv'));

figureHandle = plotOverlaidHistograms( ...
    audit(successful, :), options.RelativePositions, ...
    options.FigureVisible);
baseName = fullfile(options.OutputFolder, ...
    'QuickTuningWindowDiameter_MT_FST_OverlayHistogram');
exportgraphics(figureHandle, baseName + ".png", 'Resolution', 300);
exportgraphics(figureHandle, baseName + ".pdf", ...
    'ContentType', 'vector');
savefig(figureHandle, baseName + ".fig");
if ~options.FigureVisible
    close(figureHandle);
end

analysis = struct();
analysis.StateFile = resolvedStateFile;
analysis.OutputFolder = options.OutputFolder;
analysis.Areas = areas;
analysis.Monkey = options.Monkey;
analysis.RelativePositions = options.RelativePositions;
analysis.NumSplits = options.NumSplits;
analysis.MinTrialsPerCondition = options.MinTrialsPerCondition;
analysis.RandomSeed = options.RandomSeed;
analysis.CandidateMask = candidateMask;
analysis.SuccessfulMask = successful;
analysis.Audit = audit;
analysis.PairTable = pairTable;
analysis.DistributionSummary = summaryTable;
analysis.MaxPairSpanSummary = spanTable;
analysis.WorkbookAudit = workbookAudit;
analysis.CohortDefinition = [ ...
    "MT or FST as requested"; ...
    "Stimulation-channel source p_AI MonoL and MonoR < 0.05"; ...
    "Stimulation-channel source Z3D-Z2D < 0"; ...
    compose("Complete physical positions %d through %+d", ...
    options.RelativePositions(1), options.RelativePositions(end)); ...
    "Dead non-stimulation contacts omitted; at least two live contacts required"];
analysis.DiameterDefinition = [ ...
    compose("All %d unique live-contact pair distances", ...
    nchoosek(numel(options.RelativePositions), 2)); ...
    "Full four-cue by coherence Quick-task tuning vectors"; ...
    "Each channel standardized across common-valid trials"; ...
    "Cross-validated squared Euclidean distance"; ...
    "Window diameter is the maximum split-averaged pair distance"];
QuickTuningWindowDiameterStim2D = analysis;
save(fullfile(options.OutputFolder, ...
    sprintf('QuickTuningWindowDiameter_Stim2D_Minus%dPlus%d.mat', ...
    abs(options.RelativePositions(1)), options.RelativePositions(end))), ...
    'QuickTuningWindowDiameterStim2D', '-v7.3');

disp(summaryTable)
disp(spanTable)
fprintf('%d-contact tuning-window diameter saved to %s\n', ...
    numel(options.RelativePositions), options.OutputFolder);
end


function figureHandle = plotOverlaidHistograms( ...
    audit, relativePositions, visible)
if visible
    visibility = 'on';
else
    visibility = 'off';
end
mt = strcmpi(audit.ROI, "MT");
fst = strcmpi(audit.ROI, "FST");
allValues = audit.WindowDiameterSquared(mt | fst);
edges = commonHistogramEdges(allValues);
figureHandle = figure('Color', 'w', 'Visible', visibility, ...
    'Position', [100 100 900 600], ...
    'Name', 'MT FST nine-contact tuning-window diameter');
axesHandle = axes(figureHandle);
hold(axesHandle, 'on');
mtHistogram = histogram(axesHandle, audit.WindowDiameterSquared(mt), ...
    'BinEdges', edges, 'Normalization', 'probability', ...
    'FaceColor', [0.15 0.45 0.75], 'FaceAlpha', 0.48, ...
    'EdgeColor', [0.15 0.45 0.75], 'LineWidth', 1.1);
fstHistogram = histogram(axesHandle, audit.WindowDiameterSquared(fst), ...
    'BinEdges', edges, 'Normalization', 'probability', ...
    'FaceColor', [0.9 0.4 0.15], 'FaceAlpha', 0.42, ...
    'EdgeColor', [0.9 0.4 0.15], 'LineWidth', 1.1);
mtMedian = median(audit.WindowDiameterSquared(mt), 'omitmissing');
fstMedian = median(audit.WindowDiameterSquared(fst), 'omitmissing');
xline(axesHandle, mtMedian, '-', sprintf('MT median %.3g', mtMedian), ...
    'Color', [0.15 0.45 0.75], 'LineWidth', 1.4, ...
    'LabelVerticalAlignment', 'top');
xline(axesHandle, fstMedian, '-', sprintf('FST median %.3g', fstMedian), ...
    'Color', [0.9 0.4 0.15], 'LineWidth', 1.4, ...
    'LabelVerticalAlignment', 'bottom');
xlabel(axesHandle, ...
    sprintf('%d-contact window diameter: CV squared tuning distance (z^2/condition)', ...
    numel(relativePositions)));
ylabel(axesHandle, 'Proportion of sessions');
title(axesHandle, sprintf([ ...
    'Stimulation-channel-defined 2D sessions, live contacts within %d to %+d\n' ...
    'MT N = %d; FST N = %d'], relativePositions(1), ...
    relativePositions(end), nnz(mt), nnz(fst)));
legend(axesHandle, [mtHistogram, fstHistogram], {'MT', 'FST'}, ...
    'Location', 'best');
grid(axesHandle, 'on');
axesHandle.Box = 'off';
axesHandle.TickDir = 'out';
end


function edges = commonHistogramEdges(values)
values = values(isfinite(values));
low = min([0; values]);
high = max([0; values]);
if high <= low
    high = low + 0.1;
end
edges = linspace(low, high, 21);
end


function output = scalarAuditTable(audit)
output = audit(:, {'TableRow', 'Monkey', 'Date', 'ROI', ...
    'CandidateForAnalysis', 'StimChannel', 'StimProbePosition', ...
    'LiveContactCount', 'DeadContactCount', 'EvaluatedPairCount', ...
    'ConditionCount', 'MinimumTrialCount', 'NumSplits', ...
    'WindowDiameterSquared', 'WindowDiameter', ...
    'DiameterLeftRelativePosition', 'DiameterRightRelativePosition', ...
    'DiameterLeftChannel', 'DiameterRightChannel', ...
    'DiameterPhysicalSpan', 'DiameterPairSplitSelectionFraction', ...
    'MeanPairDistanceSquared', 'EndpointDistanceSquared', ...
    'MaxStimDistanceSquared', 'MaxStimDistanceRelativePosition', ...
    'CacheFile', 'Status', 'Message'});
end


function output = buildPairTable(audit, successful)
output = table();
rows = find(successful);
for rowIndex = 1:numel(rows)
    row = rows(rowIndex);
    positions = audit.PairRelativePositions{row};
    distances = audit.PairDistanceSquared{row};
    channels = audit.WindowChannels{row};
    windowPositions = audit.WindowRelativePositions{row};
    pairCount = size(positions, 1);
    leftChannel = nan(pairCount, 1);
    rightChannel = nan(pairCount, 1);
    for pair = 1:pairCount
        leftChannel(pair) = channels(windowPositions == positions(pair, 1));
        rightChannel(pair) = channels(windowPositions == positions(pair, 2));
    end
    tableRow = repmat(audit.TableRow(row), pairCount, 1);
    monkey = repmat(audit.Monkey(row), pairCount, 1);
    date = repmat(audit.Date(row), pairCount, 1);
    roi = repmat(audit.ROI(row), pairCount, 1);
    leftRelativePosition = positions(:, 1);
    rightRelativePosition = positions(:, 2);
    physicalSpan = rightRelativePosition - leftRelativePosition;
    pairDistanceSquared = distances(:);
    isDiameterPair = leftRelativePosition == ...
        audit.DiameterLeftRelativePosition(row) & ...
        rightRelativePosition == audit.DiameterRightRelativePosition(row);
    thisTable = table(tableRow, monkey, date, roi, ...
        leftRelativePosition, rightRelativePosition, leftChannel, ...
        rightChannel, physicalSpan, pairDistanceSquared, isDiameterPair, ...
        'VariableNames', {'TableRow', 'Monkey', 'Date', 'ROI', ...
        'LeftRelativePosition', 'RightRelativePosition', 'LeftChannel', ...
        'RightChannel', 'PhysicalSpan', 'PairDistanceSquared', ...
        'IsDiameterPair'});
    output = [output; thisTable]; %#ok<AGROW>
end
end


function output = summarizeDiameter(audit, candidateMask, successful)
groups = ["All"; "MT"; "FST"; "Jim"; "Clay"];
output = table();
for index = 1:numel(groups)
    group = groups(index);
    switch group
        case "All"
            groupMask = true(height(audit), 1);
        case {"MT", "FST"}
            groupMask = strcmpi(audit.ROI, group);
        otherwise
            groupMask = strcmpi(audit.Monkey, group);
    end
    candidate = candidateMask & groupMask;
    included = successful & groupMask;
    values = audit.WindowDiameterSquared(included);
    row = table(group, nnz(candidate), nnz(included), ...
        nnz(candidate & audit.Status == "Error"), ...
        mean(values, 'omitmissing'), median(values, 'omitmissing'), ...
        prctile(values, 25), prctile(values, 75), ...
        min(values, [], 'omitmissing'), max(values, [], 'omitmissing'), ...
        'VariableNames', {'Group', 'CandidateSessions', ...
        'AnalyzableWindowSessions', 'ErrorSessions', 'MeanDiameterSquared', ...
        'MedianDiameterSquared', 'Quartile25', 'Quartile75', ...
        'MinimumDiameterSquared', 'MaximumDiameterSquared'});
    output = [output; row]; %#ok<AGROW>
end
end


function output = summarizeDiameterSpans( ...
    audit, successful, relativePositions)
areas = ["MT", "FST"];
output = table();
for areaIndex = 1:numel(areas)
    area = areas(areaIndex);
    areaRows = successful & strcmpi(audit.ROI, area);
    for span = 1:(relativePositions(end) - relativePositions(1))
        count = nnz(areaRows & audit.DiameterPhysicalSpan == span);
        fraction = count ./ max(nnz(areaRows), 1);
        output = [output; table(area, span, count, fraction, ...
            'VariableNames', {'Area', 'PhysicalSpanContacts', ...
            'SessionCount', 'SessionFraction'})]; %#ok<AGROW>
    end
end
end


function mask = stimChannel2DCandidateMask(unitTable, areas, monkey)
required = ["ROI", "Monkey", "p_AI", "Z3D_v_Z2D"];
missing = setdiff(required, string(unitTable.Properties.VariableNames));
if ~isempty(missing)
    error('QuickTuningDiameterRunner:MissingSelectionVariables', ...
        'Missing population-selection variable(s): %s.', join(missing, ', '));
end
mask = false(height(unitTable), 1);
for row = 1:height(unitTable)
    roi = getRowText(unitTable.ROI, row);
    monkeyName = getRowText(unitTable.Monkey, row);
    if ~ismember(upper(roi), areas) || ...
            (monkey ~= "Both" && ~strcmpi(monkeyName, monkey))
        continue
    end
    pValues = numericArray(unitTable.p_AI, row);
    zDifference = numericArray(unitTable.Z3D_v_Z2D, row);
    mask(row) = numel(pValues) >= 3 && ...
        all(isfinite(pValues(2:3))) && all(pValues(2:3) < 0.05) && ...
        isscalar(zDifference) && isfinite(zDifference) && zDifference < 0;
end
end


function value = numericArray(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
while iscell(value) && isscalar(value)
    value = value{1};
end
value = double(value);
end


function value = getRowText(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
while iscell(value) && isscalar(value)
    value = value{1};
end
value = string(value);
end


function ensureFolder(folder)
if ~isfolder(folder)
    mkdir(folder);
end
end

function FigureManifest = PlotCombinedFSTPerUnitMotionTuning( ...
        outputDirectory, inputMatPath, options)
%PLOTCOMBINEDFSTPERUNITMOTIONTUNING Plot 3D and 2D lateral tuning per unit.
%   Each output figure has left-eye and right-eye panels. Each panel shows
%   mean +/- SEM for two-point 3D perspective and slow 2D tuning. Slow 2D
%   significance is a one-way ANOVA across the leftward and rightward
%   raw-trial groups. Fast 2D and saved 3D statistics remain in the output
%   manifest but are not displayed in the figures.
%
%   The 3D coherence-to-motion mapping is:
%       Left eye:  coherence -1 -> leftward,  +1 -> rightward
%       Right eye: coherence +1 -> leftward,  -1 -> rightward

arguments
    outputDirectory (1, 1) string = "C:\EM\FST_LeftRightMotionTuning_PerUnit"
    inputMatPath (1, 1) string = fullfile( ...
        fileparts(mfilename('fullpath')), 'outputs_combined', ...
        'CombinedLoEMFST3DPatternTuningIndices.mat')
    options.SmokeTest (1, 1) logical = false
    options.UnitIDs string = strings(0, 1)
    options.LoNeuroRespPath (1, 1) string = "C:\LoData\NeuroRespUnitTable.mat"
    options.LoLateral2DPath (1, 1) string = "C:\LoData\LateralMotionRawFRTable.mat"
    options.LoMIDPath (1, 1) string = "C:\LoData\MIDTable.mat"
    options.EMUnitTablePath (1, 1) string = ...
        "C:\EM\PopulationAnalysis\unit_table_gof.mat"
end

assert(isfile(inputMatPath), 'Input MAT file not found: %s', inputMatPath);
loaded = load(inputMatPath, 'CombinedPatternTuningBySpeedTable');
assert(isfield(loaded, 'CombinedPatternTuningBySpeedTable'), ...
    'Input MAT file does not contain CombinedPatternTuningBySpeedTable.');
T = loaded.CombinedPatternTuningBySpeedTable;
validate_input_table(T);
sources = load_source_tables(options);

if ~isfolder(outputDirectory)
    mkdir(outputDirectory);
end

unitIDs = unique(string(T.SourceID), 'stable');
if ~isempty(options.UnitIDs)
    requestedIDs = reshape(string(options.UnitIDs), [], 1);
    missingIDs = setdiff(requestedIDs, unitIDs);
    assert(isempty(missingIDs), 'Unknown SourceID(s): %s', ...
        strjoin(missingIDs, ', '));
    unitIDs = requestedIDs;
end

if options.SmokeTest
    hasBothSpeeds = false(size(unitIDs));
    for unitIndex = 1:numel(unitIDs)
        unitRows = T(string(T.SourceID) == unitIDs(unitIndex), :);
        hasBothSpeeds(unitIndex) = all(ismember([1, 2], unitRows.SpeedRank_2D));
    end
    firstComplete = find(hasBothSpeeds, 1);
    assert(~isempty(firstComplete), ...
        'No unit has both slow and fast 2D tuning for the smoke test.');
    unitIDs = unitIDs(firstComplete);
end

nFigures = numel(unitIDs);
SourceID = strings(nFigures, 1);
SourceDataset = strings(nFigures, 1);
Monkey = strings(nFigures, 1);
SourceRow = nan(nFigures, 1);
HasSlow2D = false(nFigures, 1);
HasFast2D = false(nFigures, 1);
P_3D_Left = nan(nFigures, 1);
P_3D_Right = nan(nFigures, 1);
Sig_3D_Left = false(nFigures, 1);
Sig_3D_Right = false(nFigures, 1);
P_2DSlow_Left = nan(nFigures, 1);
P_2DSlow_Right = nan(nFigures, 1);
P_2DFast_Left = nan(nFigures, 1);
P_2DFast_Right = nan(nFigures, 1);
FigurePath = strings(nFigures, 1);

for unitIndex = 1:nFigures
    sourceID = unitIDs(unitIndex);
    unitRows = T(string(T.SourceID) == sourceID, :);
    unitRows = sortrows(unitRows, 'SpeedRank_2D');
    assert(~isempty(unitRows), 'No rows found for %s.', sourceID);

    slowRow = find(unitRows.SpeedRank_2D == 1, 1);
    fastRow = find(unitRows.SpeedRank_2D == 2, 1);
    HasSlow2D(unitIndex) = ~isempty(slowRow);
    HasFast2D(unitIndex) = ~isempty(fastRow);

    stats = unit_tuning_statistics(unitRows, slowRow, fastRow, sources);
    allMeans = [stats.Left.Mean3D, stats.Right.Mean3D, ...
        stats.Left.MeanSlow, stats.Right.MeanSlow];
    allSEM = [stats.Left.SEM3D, stats.Right.SEM3D, ...
        stats.Left.SEMSlow, stats.Right.SEMSlow];
    sharedYLimits = firing_rate_limits(allMeans, allSEM);

    fig = figure('Visible', 'off', 'Color', 'w', ...
        'Position', [100, 100, 1320, 590]);
    figureCleanup = onCleanup(@() close(fig));
    layout = tiledlayout(fig, 1, 2, ...
        'TileSpacing', 'compact', 'Padding', 'compact');

    leftAxes = nexttile(layout);
    plot_eye_panel(leftAxes, stats.Left, ...
        [0.0000, 0.4470, 0.7410], 'Left eye', sharedYLimits);
    ylabel(leftAxes, 'Mean firing rate (spikes/s)');

    rightAxes = nexttile(layout);
    plot_eye_panel(rightAxes, stats.Right, ...
        [0.2000, 0.6000, 0.3000], 'Right eye', sharedYLimits);

    title(layout, unit_title(unitRows), 'Interpreter', 'none');
    safeID = regexprep(char(sourceID), '[^A-Za-z0-9_-]', '_');
    outputPath = fullfile(outputDirectory, safeID + "_motion_tuning.png");
    exportgraphics(fig, outputPath, 'Resolution', 180);

    SourceID(unitIndex) = sourceID;
    SourceDataset(unitIndex) = string(unitRows.SourceDataset(1));
    Monkey(unitIndex) = string(unitRows.Monkey(1));
    SourceRow(unitIndex) = double(unitRows.SourceRow(1));
    P_3D_Left(unitIndex) = stats.Left.P3D;
    P_3D_Right(unitIndex) = stats.Right.P3D;
    Sig_3D_Left(unitIndex) = stats.Left.Sig3D;
    Sig_3D_Right(unitIndex) = stats.Right.Sig3D;
    P_2DSlow_Left(unitIndex) = stats.Left.PSlow;
    P_2DSlow_Right(unitIndex) = stats.Right.PSlow;
    P_2DFast_Left(unitIndex) = stats.Left.PFast;
    P_2DFast_Right(unitIndex) = stats.Right.PFast;
    FigurePath(unitIndex) = outputPath;
    clear figureCleanup
end

FigureManifest = table(SourceID, SourceDataset, Monkey, SourceRow, ...
    HasSlow2D, HasFast2D, P_3D_Left, P_3D_Right, ...
    Sig_3D_Left, Sig_3D_Right, P_2DSlow_Left, P_2DSlow_Right, ...
    P_2DFast_Left, P_2DFast_Right, FigurePath);
manifestPath = fullfile(outputDirectory, 'PerUnitMotionTuningManifest.csv');
writetable(FigureManifest, manifestPath);

fprintf('Saved %d per-unit figure(s) to %s\n', nFigures, outputDirectory);
if options.SmokeTest
    fprintf('Smoke-test unit: %s\n', FigureManifest.SourceID(1));
end
end

function sources = load_source_tables(options)
paths = [options.LoNeuroRespPath, options.LoLateral2DPath, ...
    options.LoMIDPath, options.EMUnitTablePath];
for path = paths
    assert(isfile(path), 'Raw-data input not found: %s', path);
end
lo3D = load(options.LoNeuroRespPath, 'NeuroRespUnitTable');
lo2D = load(options.LoLateral2DPath, 'LateralMotionRawFRTable');
loMID = load(options.LoMIDPath, 'MIDTable');
em = load(options.EMUnitTablePath, 'unit_table_gof');
sources.Lo3D = lo3D.NeuroRespUnitTable;
sources.Lo2D = lo2D.LateralMotionRawFRTable;
sources.LoMID = loMID.MIDTable;
sources.EM = em.unit_table_gof;
end

function validate_input_table(T)
required = {'SourceDataset', 'SourceID', 'SourceRow', 'Date', 'Monkey', ...
    'SpeedRank_2D', 'T_L', 'T_R', 'A_L', 'A_R', ...
    'R_L', 'R_R', 'L_L', 'L_R'};
missing = setdiff(required, T.Properties.VariableNames);
assert(isempty(missing), 'Combined table is missing: %s', ...
    strjoin(missing, ', '));
end

function stats = unit_tuning_statistics(T, slowRow, fastRow, sources)
sourceDataset = string(T.SourceDataset(1));
sourceRow = double(T.SourceRow(1));
assert(sourceRow >= 1 && sourceRow == round(sourceRow), ...
    'Invalid source row for %s.', T.SourceID(1));

stats.Left.Mean3D = [T.A_L(1), T.T_L(1)];
stats.Right.Mean3D = [T.T_R(1), T.A_R(1)];
stats.Left.MeanSlow = extract_2d_tuning(T, slowRow, 'left');
stats.Right.MeanSlow = extract_2d_tuning(T, slowRow, 'right');
stats.Left.MeanFast = extract_2d_tuning(T, fastRow, 'left');
stats.Right.MeanFast = extract_2d_tuning(T, fastRow, 'right');

if sourceDataset == "Lo"
    response = sources.Lo3D.NeuroResp{sourceRow};
    left3D = {finite_values(response(2, 1, :)), ...
        finite_values(response(2, end, :))};
    right3D = {finite_values(response(3, end, :)), ...
        finite_values(response(3, 1, :))};
    stats.Left.SEM3D = sem_pair(left3D);
    stats.Right.SEM3D = sem_pair(right3D);
    stats.Left.P3D = nan;
    stats.Right.P3D = nan;
    stats.Left.Sig3D = logical(sources.LoMID.sig_Anova2_MonoL(sourceRow));
    stats.Right.Sig3D = logical(sources.LoMID.sig_Anova2_MonoR(sourceRow));
    stats.Left.HasExactP3D = false;
    stats.Right.HasExactP3D = false;

    leftSlow = lo_2d_pair(sources.Lo2D, sourceRow, 8001, 1);
    rightSlow = lo_2d_pair(sources.Lo2D, sourceRow, 8002, 1);
    leftFast = lo_2d_pair(sources.Lo2D, sourceRow, 8001, 2);
    rightFast = lo_2d_pair(sources.Lo2D, sourceRow, 8002, 2);
elseif sourceDataset == "EM"
    channel = double(sources.EM.StimElec(sourceRow));
    tuningSEM = sources.EM.tuning_SEM{sourceRow};
    stats.Left.SEM3D = [tuningSEM(2, 1, channel), ...
        tuningSEM(2, end, channel)];
    stats.Right.SEM3D = [tuningSEM(3, end, channel), ...
        tuningSEM(3, 1, channel)];
    pAI = double(sources.EM.p_AI{sourceRow});
    stats.Left.P3D = pAI(2);
    stats.Right.P3D = pAI(3);
    stats.Left.Sig3D = isfinite(stats.Left.P3D) && stats.Left.P3D < 0.05;
    stats.Right.Sig3D = isfinite(stats.Right.P3D) && stats.Right.P3D < 0.05;
    stats.Left.HasExactP3D = true;
    stats.Right.HasExactP3D = true;

    raw2D = sources.EM.Raw2D_StimCh{sourceRow};
    leftSlow = em_2d_pair(raw2D, 1, 1);
    rightSlow = em_2d_pair(raw2D, 2, 1);
    leftFast = em_2d_pair(raw2D, 1, 2);
    rightFast = em_2d_pair(raw2D, 2, 2);
else
    error('Unknown SourceDataset: %s', sourceDataset);
end

stats.Left.SEMSlow = sem_pair(leftSlow);
stats.Right.SEMSlow = sem_pair(rightSlow);
stats.Left.SEMFast = sem_pair(leftFast);
stats.Right.SEMFast = sem_pair(rightFast);
stats.Left.PSlow = pair_anova(leftSlow);
stats.Right.PSlow = pair_anova(rightSlow);
stats.Left.PFast = pair_anova(leftFast);
stats.Right.PFast = pair_anova(rightFast);
end

function tuning = extract_2d_tuning(T, rowIndex, eye)
if isempty(rowIndex)
    tuning = [nan, nan];
elseif strcmp(eye, 'left')
    tuning = [T.L_L(rowIndex), T.R_L(rowIndex)];
else
    tuning = [T.L_R(rowIndex), T.R_R(rowIndex)];
end
end

function samples = lo_2d_pair(T, sourceRow, conditionCode, speedRank)
samples = {zeros(0, 1), zeros(0, 1)};
raw2D = T.RawFR_ByConditionDirectionSpeed{sourceRow};
if speedRank > size(raw2D, 3)
    return
end
conditionCodes = numeric_vector(T.ConditionCodesUsed{sourceRow});
directions = mod(numeric_vector(T.DirectionDegreesGuess{sourceRow}), 360);
conditionIndex = find(conditionCodes == conditionCode, 1);
leftIndex = find(abs(directions - 180) < 1e-9, 1);
rightIndex = find(abs(directions - 0) < 1e-9, 1);
if isempty(conditionIndex) || isempty(leftIndex) || isempty(rightIndex)
    return
end
samples{1} = finite_values(raw2D{conditionIndex, leftIndex, speedRank});
samples{2} = finite_values(raw2D{conditionIndex, rightIndex, speedRank});
end

function samples = em_2d_pair(raw2D, eyeIndex, speedRank)
samples = {zeros(0, 1), zeros(0, 1)};
if speedRank > size(raw2D, 2) || eyeIndex > size(raw2D, 3)
    return
end
samples{1} = finite_values(raw2D(5, speedRank, eyeIndex, :));
samples{2} = finite_values(raw2D(1, speedRank, eyeIndex, :));
end

function values = numeric_vector(values)
if iscell(values)
    values = cell2mat(values);
end
values = double(values(:));
end

function values = finite_values(values)
values = double(values(:));
values = values(isfinite(values));
end

function sem = sem_pair(samples)
sem = [sample_sem(samples{1}), sample_sem(samples{2})];
end

function sem = sample_sem(values)
values = finite_values(values);
if numel(values) < 2
    sem = nan;
else
    sem = std(values, 0) / sqrt(numel(values));
end
end

function p = pair_anova(samples)
left = finite_values(samples{1});
right = finite_values(samples{2});
if numel(left) < 2 || numel(right) < 2
    p = nan;
    return
end
responses = [left; right];
groups = [ones(numel(left), 1); 2 .* ones(numel(right), 1)];
p = anova1(responses, groups, 'off');
end

function handles = plot_eye_panel(ax, stats, eyeColor, panelTitle, yLimits)
x = [1, 2];
fadedColor = blend_with_white(eyeColor, 0.58);
hold(ax, 'on');
handles = gobjects(2, 1);
handles(1) = errorbar(ax, x, stats.Mean3D, stats.SEM3D, '-o', ...
    'Color', eyeColor, 'MarkerFaceColor', eyeColor, ...
    'MarkerEdgeColor', eyeColor, 'LineWidth', 2.2, ...
    'MarkerSize', 7, 'CapSize', 9);
handles(2) = errorbar(ax, x, stats.MeanSlow, stats.SEMSlow, '--o', ...
    'Color', fadedColor, 'MarkerFaceColor', fadedColor, ...
    'MarkerEdgeColor', fadedColor, 'LineWidth', 1.8, ...
    'MarkerSize', 6, 'CapSize', 9);
hold(ax, 'off');

ax.XTick = x;
ax.XTickLabel = {'Leftward', 'Rightward'};
ax.XLim = [0.75, 2.25];
ax.YLim = yLimits;
ax.FontSize = 11;
box(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'Motion direction');
title(ax, panelTitle);
legend(ax, handles, {'3D perspective', ...
    two_d_label('2D slow', stats.PSlow)}, ...
    'Location', 'northeast', 'Box', 'off', 'FontSize', 9);
end

function label = two_d_label(seriesName, p)
label = sprintf('%s (L/R ANOVA %s)', seriesName, p_value_label(p));
end

function label = p_value_label(p)
if ~isfinite(p)
    label = 'p=NA';
elseif p < 0.001
    label = sprintf('p=%.1e ***', p);
elseif p < 0.01
    label = sprintf('p=%.3f **', p);
elseif p < 0.05
    label = sprintf('p=%.3f *', p);
else
    label = sprintf('p=%.3f n.s.', p);
end
end

function color = blend_with_white(baseColor, opacity)
color = opacity .* baseColor + (1 - opacity) .* [1, 1, 1];
end

function limits = firing_rate_limits(means, sem)
validSEM = sem;
validSEM(~isfinite(validSEM)) = 0;
bounds = [means - validSEM, means + validSEM];
bounds = bounds(isfinite(bounds));
if isempty(bounds)
    limits = [0, 1];
    return
end

minimum = min(bounds);
maximum = max(bounds);
if minimum >= 0
    lowerLimit = 0;
    upperLimit = maximum * 1.14;
    if upperLimit <= 0
        upperLimit = 1;
    end
else
    span = maximum - minimum;
    if span <= 0
        span = max(1, abs(maximum));
    end
    lowerLimit = minimum - 0.08 * span;
    upperLimit = maximum + 0.14 * span;
end
limits = [lowerLimit, upperLimit];
end

function label = unit_title(T)
sourceID = string(T.SourceID(1));
dataset = string(T.SourceDataset(1));
monkey = string(T.Monkey(1));
dateText = string(T.Date(1));
label = sprintf('%s | %s, %s | %s | source row %d', ...
    sourceID, dataset, monkey, dateText, T.SourceRow(1));
end

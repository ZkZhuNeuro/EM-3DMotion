function [PatternTuningTable, PatternTuningBySpeedTable, PatternTuningSummary, ...
        ZeroTestResults] = ...
    RunFSTPatternTuningAnalysis(outputDirectory, inputPaths)
%RUNFSTPATTERNTUNINGANALYSIS Load source tables, compute indices, and save outputs.

arguments
    outputDirectory (1, 1) string = ""
    inputPaths.NeuroResp (1, 1) string = "C:\LoData\NeuroRespUnitTable.mat"
    inputPaths.Lateral2D (1, 1) string = "C:\LoData\LateralMotionRawFRTable.mat"
    inputPaths.MID (1, 1) string = "C:\LoData\MIDTable.mat"
end

if strlength(outputDirectory) == 0
    outputDirectory = fullfile(fileparts(mfilename('fullpath')), 'outputs');
end

assert(isfile(inputPaths.NeuroResp), 'Input not found: %s', inputPaths.NeuroResp);
assert(isfile(inputPaths.Lateral2D), 'Input not found: %s', inputPaths.Lateral2D);
assert(isfile(inputPaths.MID), 'Input not found: %s', inputPaths.MID);

fprintf('Loading 3D responses from %s\n', inputPaths.NeuroResp);
data3D = load(inputPaths.NeuroResp, 'NeuroRespUnitTable');
fprintf('Loading 2D lateral responses from %s\n', inputPaths.Lateral2D);
data2D = load(inputPaths.Lateral2D, 'LateralMotionRawFRTable');
fprintf('Loading classification metadata from %s\n', inputPaths.MID);
metadata = load(inputPaths.MID, 'MIDTable');

[PatternTuningTable, PatternTuningBySpeedTable, PatternTuningSummary] = ...
    ComputeFSTPatternTuningIndices(data3D.NeuroRespUnitTable, ...
    data2D.LateralMotionRawFRTable, metadata.MIDTable);
slowSpeedCode = 7041;
fastSpeedCode = 7125;
FastPatternTuningTable = PatternTuningBySpeedTable( ...
    PatternTuningBySpeedTable.SpeedCode_2D == fastSpeedCode, :);
if isempty(FastPatternTuningTable)
    error('RunFSTPatternTuningAnalysis:MissingFastSpeed', ...
        'No selected unit has the fast 2D speed code %g.', fastSpeedCode);
end
if height(FastPatternTuningTable) ~= numel(unique(FastPatternTuningTable.SourceRow))
    error('RunFSTPatternTuningAnalysis:DuplicateFastSpeed', ...
        'Expected at most one fast-speed row per selected unit.');
end
if ~all(ismember(FastPatternTuningTable.SourceRow, PatternTuningTable.SourceRow))
    error('RunFSTPatternTuningAnalysis:UnexpectedFastUnit', ...
        'The fast-speed table contains a unit outside the primary population.');
end
ZeroTestResults = [ ...
    build_zero_test_results(PatternTuningTable, "Slow (~4.2 deg/s)", slowSpeedCode); ...
    build_zero_test_results(FastPatternTuningTable, "Fast (~12.6 deg/s)", fastSpeedCode)];
allSpeedFamilySize = height(ZeroTestResults);
ZeroTestResults.FamilySize_AllSpeeds = ...
    repmat(allSpeedFamilySize, allSpeedFamilySize, 1);
ZeroTestResults.PValue_BonferroniAllSpeeds = ...
    min(ZeroTestResults.PValue .* allSpeedFamilySize, 1);
ZeroTestResults.Significant_BonferroniAllSpeeds = ...
    ZeroTestResults.PValue_BonferroniAllSpeeds < 0.05;

if ~isfolder(outputDirectory)
    mkdir(outputDirectory);
end

AnalysisConfig = struct();
AnalysisConfig.Generated = datetime('now');
AnalysisConfig.Selection = ...
    'ROI==FST & sig_Anova_CLR & Z_quad==2 (complete Lo 1.28 classification)';
AnalysisConfig.LoClassification = ...
    ['Z_quad==2: winning 3D model clears the component-Z gate and ' ...
    'Z3D_v_Z2D exceeds 1.28'];
AnalysisConfig.CueOrder = ...
    '1=Combined, 2=left-eye perspective, 3=right-eye perspective, 4=Stereo';
AnalysisConfig.Coherence = [-22, -14, -10, -8, -4, -2, 0, 2, 4, 8, 10, 14, 22] ./ 22;
AnalysisConfig.Primary2DSpeedCode = slowSpeedCode;
AnalysisConfig.Primary2DSpeed = 'slow (~4.2 deg/s), matched to the 100%-coherence 3D retinal speed';
AnalysisConfig.Fast2DSpeedCode = fastSpeedCode;
AnalysisConfig.Fast2DSpeed = 'fast (~12.6 deg/s)';
AnalysisConfig.DirectionConvention = '0 deg=rightward, 180 deg=leftward';
AnalysisConfig.ResponseWindow = 'full stimulus interval; no baseline subtraction';
AnalysisConfig.PreferenceDefinition = ...
    'MIDTable.Combined_AI > 0: Toward; < 0: Away; == 0: Neutral';
AnalysisConfig.ZeroTest = ...
    'Two-sided one-sample Wilcoxon signed-rank test against zero';
AnalysisConfig.ZeroTestMultiplicity = ...
    ['Raw p-values plus Bonferroni adjustment within each four-test speed family ' ...
    'and across the complete eight-test slow-plus-fast family'];
AnalysisConfig.InputPaths = inputPaths;

matPath = fullfile(outputDirectory, 'FST3DPatternTuningIndices.mat');
primaryCsvPath = fullfile(outputDirectory, 'FST3DPatternTuningIndices.csv');
bySpeedCsvPath = fullfile(outputDirectory, 'FST3DPatternTuningIndices_BySpeed.csv');
fastCsvPath = fullfile(outputDirectory, 'FST3DPatternTuningIndices_Fast.csv');
summaryCsvPath = fullfile(outputDirectory, 'FST3DPatternTuningSummary.csv');
zeroTestsCsvPath = fullfile(outputDirectory, 'FST3DPatternTuningZeroTests.csv');
figurePath = fullfile(outputDirectory, 'FST3DPatternTuningIndices.png');

save(matPath, 'PatternTuningTable', 'FastPatternTuningTable', ...
    'PatternTuningBySpeedTable', ...
    'PatternTuningSummary', 'ZeroTestResults', 'AnalysisConfig', '-v7.3');
writetable(PatternTuningTable, primaryCsvPath);
writetable(PatternTuningBySpeedTable, bySpeedCsvPath);
writetable(FastPatternTuningTable, fastCsvPath);
writetable(PatternTuningSummary, summaryCsvPath);
writetable(ZeroTestResults, zeroTestsCsvPath);
make_summary_figure(PatternTuningTable, FastPatternTuningTable, ...
    ZeroTestResults, figurePath);

fprintf('\nLo-classified 3D FST units (Z_quad == 2): %d\n', ...
    height(PatternTuningTable));
fprintf('Complete primary rows: %d\n', nnz(PatternTuningTable.Complete_AllEightMetrics));
fprintf('Combined-cue preference: %d toward, %d away, %d neutral/undefined\n', ...
    nnz(PatternTuningTable.CombinedCuePreference == "Toward"), ...
    nnz(PatternTuningTable.CombinedCuePreference == "Away"), ...
    nnz(~ismember(PatternTuningTable.CombinedCuePreference, ["Toward", "Away"])));
fprintf('Primary TDI mean/median: %.4f / %.4f\n', ...
    mean(PatternTuningTable.TDI, 'omitnan'), median(PatternTuningTable.TDI, 'omitnan'));
fprintf('Primary ADI mean/median: %.4f / %.4f\n', ...
    mean(PatternTuningTable.ADI, 'omitnan'), median(PatternTuningTable.ADI, 'omitnan'));
fprintf('Fast-speed rows: %d (complete: %d)\n', height(FastPatternTuningTable), ...
    nnz(FastPatternTuningTable.Complete_AllEightMetrics));
fprintf('Fast TDI mean/median: %.4f / %.4f\n', ...
    mean(FastPatternTuningTable.TDI, 'omitnan'), ...
    median(FastPatternTuningTable.TDI, 'omitnan'));
fprintf('Fast ADI mean/median: %.4f / %.4f\n', ...
    mean(FastPatternTuningTable.ADI, 'omitnan'), ...
    median(FastPatternTuningTable.ADI, 'omitnan'));
disp('Two-sided Wilcoxon signed-rank tests against zero:');
disp(ZeroTestResults(:, {'SpeedLabel_2D', 'Index', 'Preference', 'N', 'Median', ...
    'PValue', 'PValue_Bonferroni', 'PValue_BonferroniAllSpeeds', ...
    'Significant_BonferroniAllSpeeds'}));
fprintf('Saved outputs to %s\n', outputDirectory);
end

function make_summary_figure(slowT, fastT, zeroTests, outputPath)
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 1260, 830]);
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, sprintf(['Lo-classified 3D FST units (Z_{quad}=2): ' ...
    'slow 2D speed above (n=%d), fast 2D speed below (n=%d)'], ...
    height(slowT), height(fastT)));

tdiEdges = shared_histogram_edges([ ...
    slowT.TDI(slowT.Valid_TDI); fastT.TDI(fastT.Valid_TDI)], 0.1);
adiEdges = shared_histogram_edges([ ...
    slowT.ADI(slowT.Valid_ADI); fastT.ADI(fastT.Valid_ADI)], 0.1);

slowAxes = plot_speed_row(layout, slowT, zeroTests, 7041, ...
    'Slow (~4.2 deg/s)', tdiEdges, adiEdges);
fastAxes = plot_speed_row(layout, fastT, zeroTests, 7125, ...
    'Fast (~12.6 deg/s)', tdiEdges, adiEdges);

set_common_probability_limits(slowAxes(1), fastAxes(1));
set_common_probability_limits(slowAxes(2), fastAxes(2));

exportgraphics(fig, outputPath, 'Resolution', 180);
end

function axesHandles = plot_speed_row(layout, T, zeroTests, speedCode, speedLabel, tdiEdges, adiEdges)
axesHandles = gobjects(1, 3);
axesHandles(1) = nexttile(layout);
plot_preference_histogram(T.TDI, T.Valid_TDI, T.CombinedCuePreference, tdiEdges);
xline(0, 'k--', 'LineWidth', 1.2, 'HandleVisibility', 'off');
xlim([tdiEdges(1), tdiEdges(end)]);
xlabel('TDI');
ylabel('Proportion within preference group');
title({sprintf('%s TDI: mean %.3f, median %.3f', speedLabel, ...
    mean(T.TDI, 'omitnan'), median(T.TDI, 'omitnan')), ...
    zero_test_subtitle(zeroTests, "TDI", speedCode)});
box off;

axesHandles(2) = nexttile(layout);
plot_preference_histogram(T.ADI, T.Valid_ADI, T.CombinedCuePreference, adiEdges);
xline(0, 'k--', 'LineWidth', 1.2, 'HandleVisibility', 'off');
xlim([adiEdges(1), adiEdges(end)]);
xlabel('ADI');
ylabel('Proportion within preference group');
title({sprintf('%s ADI: mean %.3f, median %.3f', speedLabel, ...
    mean(T.ADI, 'omitnan'), median(T.ADI, 'omitnan')), ...
    zero_test_subtitle(zeroTests, "ADI", speedCode)});
box off;

axesHandles(3) = nexttile(layout);
valid = T.Valid_TDI & T.Valid_ADI;
hold on;
away = valid & T.CombinedCuePreference == "Away";
toward = valid & T.CombinedCuePreference == "Toward";
other = valid & ~(away | toward);
scatter(T.TDI(away), T.ADI(away), 42, 'filled', ...
    'MarkerFaceColor', preference_colors("Away"), 'MarkerFaceAlpha', 0.62, ...
    'DisplayName', sprintf('Away (n=%d)', nnz(away)));
scatter(T.TDI(toward), T.ADI(toward), 42, 'filled', ...
    'MarkerFaceColor', preference_colors("Toward"), 'MarkerFaceAlpha', 0.62, ...
    'DisplayName', sprintf('Toward (n=%d)', nnz(toward)));
if any(other)
    scatter(T.TDI(other), T.ADI(other), 42, 'filled', ...
        'MarkerFaceColor', preference_colors("Other"), 'MarkerFaceAlpha', 0.62, ...
        'DisplayName', sprintf('Neutral/undefined (n=%d)', nnz(other)));
end
xline(0, 'k--', 'HandleVisibility', 'off');
yline(0, 'k--', 'HandleVisibility', 'off');
xlabel('TDI');
ylabel('ADI');
title(sprintf('%s per-unit indices', speedLabel));
legend('Location', 'best');
xlim([tdiEdges(1), tdiEdges(end)]);
ylim([adiEdges(1), adiEdges(end)]);
axis square;
box off;
hold off;
end

function set_common_probability_limits(firstAxes, secondAxes)
upperLimit = max([firstAxes.YLim(2), secondAxes.YLim(2)]);
firstAxes.YLim = [0, upperLimit];
secondAxes.YLim = [0, upperLimit];
end

function results = build_zero_test_results(T, speedLabel, speedCode)
indexNames = ["TDI"; "TDI"; "ADI"; "ADI"];
preferences = ["Toward"; "Away"; "Toward"; "Away"];
nTests = numel(indexNames);
N = zeros(nTests, 1);
Mean = nan(nTests, 1);
Median = nan(nTests, 1);
SignedRank = nan(nTests, 1);
ZValue = nan(nTests, 1);
PValue = nan(nTests, 1);

for testIndex = 1:nTests
    values = T.(indexNames(testIndex));
    mask = T.CombinedCuePreference == preferences(testIndex) & isfinite(values);
    values = values(mask);
    N(testIndex) = numel(values);
    if isempty(values)
        continue
    end
    Mean(testIndex) = mean(values);
    Median(testIndex) = median(values);
    [PValue(testIndex), ~, stats] = signrank(values, 0, 'tail', 'both');
    if isfield(stats, 'signedrank')
        SignedRank(testIndex) = stats.signedrank;
    end
    if isfield(stats, 'zval')
        ZValue(testIndex) = stats.zval;
    end
end

PValue_Bonferroni = min(PValue .* nTests, 1);
Significant_Uncorrected = PValue < 0.05;
Significant_Bonferroni = PValue_Bonferroni < 0.05;
Index = indexNames;
Preference = preferences;
SpeedLabel_2D = repmat(string(speedLabel), nTests, 1);
SpeedCode_2D = repmat(speedCode, nTests, 1);
Test = repmat("Two-sided Wilcoxon signed-rank vs 0", nTests, 1);
NullValue = zeros(nTests, 1);
FamilySize = repmat(nTests, nTests, 1);
results = table(SpeedLabel_2D, SpeedCode_2D, Index, Preference, Test, ...
    NullValue, N, Mean, Median, ...
    SignedRank, ZValue, PValue, Significant_Uncorrected, FamilySize, ...
    PValue_Bonferroni, Significant_Bonferroni);
end

function label = zero_test_subtitle(results, indexName, speedCode)
rows = results.Index == indexName & results.SpeedCode_2D == speedCode;
towardP = results.PValue(rows & results.Preference == "Toward");
awayP = results.PValue(rows & results.Preference == "Away");
label = sprintf('Signed-rank vs 0: toward p=%s; away p=%s', ...
    format_p_value(towardP), format_p_value(awayP));
end

function label = format_p_value(pValue)
if isempty(pValue) || ~isfinite(pValue)
    label = 'NaN';
elseif pValue < 0.001
    label = sprintf('%.2e', pValue);
else
    label = sprintf('%.3f', pValue);
end
end

function edges = shared_histogram_edges(values, binWidth)
values = values(isfinite(values));
if isempty(values)
    edges = [-binWidth, 0, binWidth];
    return
end

lowerEdge = floor(min([values; 0]) / binWidth) * binWidth;
upperEdge = ceil(max([values; 0]) / binWidth) * binWidth;
if upperEdge <= lowerEdge
    upperEdge = lowerEdge + binWidth;
end
edges = lowerEdge:binWidth:upperEdge;
if numel(edges) < 2
    edges = [lowerEdge, lowerEdge + binWidth];
end
end

function plot_preference_histogram(values, valid, preference, edges)
values = values(valid);
preference = preference(valid);
if isempty(values)
    return
end
toward = preference == "Toward";
away = preference == "Away";
other = ~(toward | away);

hold on;
plots = gobjects(1, 3);
labels = cell(1, 3);
plotCount = 0;
if any(toward)
    plotCount = plotCount + 1;
    plots(plotCount) = histogram(values(toward), edges, ...
        'Normalization', 'probability', ...
        'FaceColor', preference_colors("Toward"), ...
        'EdgeColor', preference_colors("Toward"), ...
        'FaceAlpha', 0.42, 'EdgeAlpha', 0.78, 'LineWidth', 0.8);
    labels{plotCount} = sprintf('Toward (n=%d)', nnz(toward));
end
if any(away)
    plotCount = plotCount + 1;
    plots(plotCount) = histogram(values(away), edges, ...
        'Normalization', 'probability', ...
        'FaceColor', preference_colors("Away"), ...
        'EdgeColor', preference_colors("Away"), ...
        'FaceAlpha', 0.42, 'EdgeAlpha', 0.78, 'LineWidth', 0.8);
    labels{plotCount} = sprintf('Away (n=%d)', nnz(away));
end
if any(other)
    plotCount = plotCount + 1;
    plots(plotCount) = histogram(values(other), edges, ...
        'Normalization', 'probability', ...
        'FaceColor', preference_colors("Other"), ...
        'EdgeColor', preference_colors("Other"), ...
        'FaceAlpha', 0.42, 'EdgeAlpha', 0.78, 'LineWidth', 0.8);
    labels{plotCount} = sprintf('Neutral/undefined (n=%d)', nnz(other));
end
legend(plots(1:plotCount), labels(1:plotCount), 'Location', 'best');
hold off;
end

function color = preference_colors(preference)
if preference == "Toward"
    color = [0.84, 0.28, 0.20];
elseif preference == "Away"
    color = [0.18, 0.47, 0.72];
else
    color = [0.45, 0.45, 0.45];
end
end

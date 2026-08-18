function [CombinedPatternTuningTable, CombinedPatternTuningBySpeedTable, ...
        CombinedPatternTuningSummary, ZeroTestResults, ...
        CombinedBinocularOpticFlowTable, ...
        CombinedBinocularOpticFlowSummary, BODIZeroTestResults] = ...
    RunCombinedLoEMFSTPatternTuningAnalysis(outputDirectory, inputPaths, options)
%RUNCOMBINEDLOEMFSTPATTERNTUNINGANALYSIS Merge Lo and EM analyses.

arguments
    outputDirectory (1, 1) string = ""
    inputPaths.LoNeuroResp (1, 1) string = "C:\LoData\NeuroRespUnitTable.mat"
    inputPaths.LoLateral2D (1, 1) string = "C:\LoData\LateralMotionRawFRTable.mat"
    inputPaths.LoMID (1, 1) string = "C:\LoData\MIDTable.mat"
    inputPaths.EMUnitTableGof (1, 1) string = "C:\EM\PopulationAnalysis\unit_table_gof.mat"
    options.SelectionMode (1, 1) string {mustBeMember(options.SelectionMode, ...
        ["relaxed", "both-1.28"])} = "relaxed"
end

if strlength(outputDirectory) == 0
    if options.SelectionMode == "both-1.28"
        outputDirectory = ...
            "C:\EM\PatternTuning\Archive\Previous_TDI_ADI_Results\Combined_128";
    else
        outputDirectory = ...
            "C:\EM\PatternTuning\Archive\Previous_TDI_ADI_Results\Combined";
    end
end

inputNames = fieldnames(inputPaths);
for inputIndex = 1:numel(inputNames)
    inputPath = inputPaths.(inputNames{inputIndex});
    assert(isfile(inputPath), 'Input not found: %s', inputPath);
end

lo3D = load(inputPaths.LoNeuroResp, 'NeuroRespUnitTable');
lo2D = load(inputPaths.LoLateral2D, 'LateralMotionRawFRTable');
loMetadata = load(inputPaths.LoMID, 'MIDTable');
emData = load(inputPaths.EMUnitTableGof, 'unit_table_gof');

if options.SelectionMode == "both-1.28"
    [~, loBySpeed, ~, loBODI] = ComputeFSTPatternTuningIndices( ...
        lo3D.NeuroRespUnitTable, lo2D.LateralMotionRawFRTable, ...
        loMetadata.MIDTable, SelectionMode="lo-1.28");
    [~, emBySpeed, ~, emBODI] = ComputeEMFSTPatternTuningIndices( ...
        emData.unit_table_gof, Z3DMinus2DThreshold=1.28);
    loSelection = "ROI==FST & sig_Anova_CLR & Z_quad==2";
    emSelection = "ROI==FST & ND==3D & Z3D_v_Z2D>1.28";
    outputPrefix = "CombinedLoEMFST3DPatternTuning128";
    bodiPrefix = "CombinedLoEMFST3DBinocularOpticFlowDiscrimination128";
    analysisLabel = "Combined Lo and EM 1.28-criterion FST units";
    description = "Merged Lo and EM FST indices using Lo Z_quad==2 and " + ...
        "EM ND==3D with Z3D_v_Z2D>1.28.";
else
    [~, loBySpeed, ~, loBODI] = ComputeFSTPatternTuningIndices( ...
        lo3D.NeuroRespUnitTable, lo2D.LateralMotionRawFRTable, ...
        loMetadata.MIDTable, SelectionMode="positive-score");
    [~, emBySpeed, ~, emBODI] = ...
        ComputeEMFSTPatternTuningIndices(emData.unit_table_gof);
    loSelection = "ROI==FST & sig_Anova_CLR & Z3D_v_Z2D>0";
    emSelection = "ROI==FST & ND==3D";
    outputPrefix = "CombinedLoEMFST3DPatternTuning";
    bodiPrefix = "CombinedLoEMFST3DBinocularOpticFlowDiscrimination";
    analysisLabel = "Combined Lo (Z3D-Z2D>0) and EM 3D FST units";
    description = "Merged Lo and EM FST indices using positive-score Lo and " + ...
        "ND==3D EM selections.";
end

[CombinedPatternTuningBySpeedTable, CombinedPatternTuningSummary] = ...
    MergeFSTPatternTuningDatasets(loBySpeed, emBySpeed, ...
    LoSelectionCriterion=loSelection, ...
    EMSelectionCriterion=emSelection, Description=description);
[CombinedBinocularOpticFlowTable, CombinedBinocularOpticFlowSummary] = ...
    MergeFSTBODIDatasets(loBODI, emBODI, ...
    LoSelectionCriterion=loSelection, ...
    EMSelectionCriterion=emSelection, ...
    Description="Merged one-row-per-neuron Lo and EM 3D-only BODI results");
CombinedPatternTuningTable = CombinedPatternTuningBySpeedTable( ...
    CombinedPatternTuningBySpeedTable.SpeedRank_2D == 1, :);
FastCombinedPatternTuningTable = CombinedPatternTuningBySpeedTable( ...
    CombinedPatternTuningBySpeedTable.SpeedRank_2D == 2, :);

ZeroTestResults = [ ...
    build_zero_test_results(CombinedPatternTuningTable, 1, "Slow (~4.2 deg/s)"); ...
    build_zero_test_results(FastCombinedPatternTuningTable, 2, ...
    "Fast (~12.5-12.6 deg/s)")];
allSpeedFamilySize = height(ZeroTestResults);
ZeroTestResults.FamilySize_AllSpeeds = ...
    repmat(allSpeedFamilySize, allSpeedFamilySize, 1);
ZeroTestResults.PValue_BonferroniAllSpeeds = ...
    min(ZeroTestResults.PValue .* allSpeedFamilySize, 1);
ZeroTestResults.Significant_BonferroniAllSpeeds = ...
    ZeroTestResults.PValue_BonferroniAllSpeeds < 0.05;
BODIZeroTestResults = ...
    BuildFSTBODIZeroTestResults(CombinedBinocularOpticFlowTable);

if ~isfolder(outputDirectory)
    mkdir(outputDirectory);
end

AnalysisConfig = struct();
AnalysisConfig.Generated = datetime('now');
AnalysisConfig.InputPaths = inputPaths;
AnalysisConfig.SelectionMode = options.SelectionMode;
AnalysisConfig.LoSelection = loSelection;
AnalysisConfig.EMSelection = emSelection;
if options.SelectionMode == "both-1.28"
    AnalysisConfig.Z3DMinus2DThreshold = 1.28;
end
AnalysisConfig.PreferenceDefinition = ...
    'Combined-cue AI > 0: Toward; < 0: Away; == 0: Neutral';
AnalysisConfig.BODI = ...
    ['(Combined_FR-Stereo_FR)/(Combined_FR+Stereo_FR), using coherence ' ...
    '+1 for toward-preferring units and -1 for away-preferring units; ' ...
    'one 3D-only value per neuron from cues 1 and 4'];
AnalysisConfig.HistogramEncoding = ...
    'Datasets pooled; color distinguishes Toward/Away preference only';
AnalysisConfig.ScatterEncoding = ...
    ['Color=Toward/Away; marker shape=monkey (Jim circle, Clay diamond); ' ...
    'Lo=filled and EM=open'];
AnalysisConfig.ZeroTest = ...
    ['TDI/ADI: two-sided one-sample Wilcoxon signed-rank test against ' ...
    'zero on pooled data'];
AnalysisConfig.BODIZeroTest = ...
    ['BODI: two-sided Wilcoxon rank-sum test against an equal-sized ' ...
    'zero reference sample on pooled data'];
AnalysisConfig.ZeroTestMultiplicity = ...
    ['TDI/ADI: Bonferroni within each four-test speed family and across ' ...
    'eight slow-plus-fast tests. BODI: separate two-test preference family.'];

matPath = fullfile(outputDirectory, outputPrefix + "Indices.mat");
slowCsvPath = fullfile(outputDirectory, outputPrefix + "Indices_Slow.csv");
fastCsvPath = fullfile(outputDirectory, outputPrefix + "Indices_Fast.csv");
bySpeedCsvPath = fullfile(outputDirectory, outputPrefix + "Indices_BySpeed.csv");
summaryCsvPath = fullfile(outputDirectory, outputPrefix + "Summary.csv");
zeroTestsCsvPath = fullfile(outputDirectory, outputPrefix + "ZeroTests.csv");
figurePath = fullfile(outputDirectory, outputPrefix + "Indices.png");
bodiCsvPath = fullfile(outputDirectory, bodiPrefix + ".csv");
bodiSummaryCsvPath = fullfile(outputDirectory, bodiPrefix + "Summary.csv");
bodiZeroTestsCsvPath = fullfile(outputDirectory, bodiPrefix + "ZeroTests.csv");
bodiFigurePath = fullfile(outputDirectory, bodiPrefix + ".png");

save(matPath, 'CombinedPatternTuningTable', ...
    'FastCombinedPatternTuningTable', 'CombinedPatternTuningBySpeedTable', ...
    'CombinedPatternTuningSummary', 'ZeroTestResults', ...
    'CombinedBinocularOpticFlowTable', ...
    'CombinedBinocularOpticFlowSummary', 'BODIZeroTestResults', ...
    'AnalysisConfig', '-v7.3');
writetable(CombinedPatternTuningTable, slowCsvPath);
writetable(FastCombinedPatternTuningTable, fastCsvPath);
writetable(CombinedPatternTuningBySpeedTable, bySpeedCsvPath);
writetable(CombinedPatternTuningSummary, summaryCsvPath);
writetable(ZeroTestResults, zeroTestsCsvPath);
writetable(CombinedBinocularOpticFlowTable, bodiCsvPath);
writetable(CombinedBinocularOpticFlowSummary, bodiSummaryCsvPath);
writetable(BODIZeroTestResults, bodiZeroTestsCsvPath);
make_summary_figure(CombinedPatternTuningTable, ...
    FastCombinedPatternTuningTable, ZeroTestResults, figurePath, analysisLabel);
MakeFSTBODIFigure(CombinedBinocularOpticFlowTable, BODIZeroTestResults, ...
    bodiFigurePath, ...
    analysisLabel + " - binocular optic-flow discrimination");

fprintf('\nCombined slow rows: %d (Lo %d, EM %d)\n', ...
    height(CombinedPatternTuningTable), ...
    nnz(CombinedPatternTuningTable.SourceDataset == "Lo"), ...
    nnz(CombinedPatternTuningTable.SourceDataset == "EM"));
fprintf('Combined fast rows: %d (Lo %d, EM %d)\n', ...
    height(FastCombinedPatternTuningTable), ...
    nnz(FastCombinedPatternTuningTable.SourceDataset == "Lo"), ...
    nnz(FastCombinedPatternTuningTable.SourceDataset == "EM"));
fprintf('Slow preference: %d toward, %d away, %d neutral/undefined\n', ...
    nnz(CombinedPatternTuningTable.CombinedCuePreference == "Toward"), ...
    nnz(CombinedPatternTuningTable.CombinedCuePreference == "Away"), ...
    nnz(~ismember(CombinedPatternTuningTable.CombinedCuePreference, ...
    ["Toward", "Away"])));
fprintf('Combined BODI mean/median: %.4f / %.4f\n', ...
    mean(CombinedBinocularOpticFlowTable.BODI, 'omitnan'), ...
    median(CombinedBinocularOpticFlowTable.BODI, 'omitnan'));
disp(ZeroTestResults(:, {'SpeedLabel_2D', 'Index', 'Preference', 'N', ...
    'Median', 'PValue', 'PValue_Bonferroni', ...
    'PValue_BonferroniAllSpeeds', 'Significant_BonferroniAllSpeeds'}));
fprintf('Saved combined outputs to %s\n', outputDirectory);
end

function results = build_zero_test_results(T, speedRank, speedLabel)
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
SpeedRank_2D = repmat(speedRank, nTests, 1);
SpeedLabel_2D = repmat(string(speedLabel), nTests, 1);
Index = indexNames;
Preference = preferences;
Test = repmat("Two-sided Wilcoxon signed-rank vs 0", nTests, 1);
NullValue = zeros(nTests, 1);
FamilySize = repmat(nTests, nTests, 1);
results = table(SpeedRank_2D, SpeedLabel_2D, Index, Preference, Test, ...
    NullValue, N, Mean, Median, SignedRank, ZValue, PValue, ...
    Significant_Uncorrected, FamilySize, PValue_Bonferroni, ...
    Significant_Bonferroni);
end

function make_summary_figure(slowT, fastT, zeroTests, outputPath, analysisLabel)
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 1320, 850]);
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, sprintf([char(analysisLabel) ': ' ...
    'slow above (n=%d), fast below (n=%d)'], ...
    height(slowT), height(fastT)), 'Interpreter', 'none');

tdiEdges = shared_histogram_edges([ ...
    slowT.TDI(slowT.Valid_TDI); fastT.TDI(fastT.Valid_TDI)], 0.1);
adiEdges = shared_histogram_edges([ ...
    slowT.ADI(slowT.Valid_ADI); fastT.ADI(fastT.Valid_ADI)], 0.1);
slowAxes = plot_speed_row(layout, slowT, zeroTests, 1, ...
    'Slow (~4.2 deg/s)', tdiEdges, adiEdges);
fastAxes = plot_speed_row(layout, fastT, zeroTests, 2, ...
    'Fast (~12.5-12.6 deg/s)', tdiEdges, adiEdges);
set_common_probability_limits(slowAxes(1), fastAxes(1));
set_common_probability_limits(slowAxes(2), fastAxes(2));

exportgraphics(fig, outputPath, 'Resolution', 180);
end

function axesHandles = plot_speed_row(layout, T, zeroTests, speedRank, ...
        speedLabel, tdiEdges, adiEdges)
axesHandles = gobjects(1, 3);
axesHandles(1) = nexttile(layout);
plot_pooled_preference_histogram( ...
    T.TDI, T.Valid_TDI, T.CombinedCuePreference, tdiEdges);
xline(0, 'k--', 'LineWidth', 1.2, 'HandleVisibility', 'off');
xlim([tdiEdges(1), tdiEdges(end)]);
xlabel('TDI');
ylabel('Proportion within preference group');
title({sprintf('%s TDI: mean %.3f, median %.3f', speedLabel, ...
    mean(T.TDI, 'omitnan'), median(T.TDI, 'omitnan')), ...
    zero_test_subtitle(zeroTests, "TDI", speedRank)});
box off;

axesHandles(2) = nexttile(layout);
plot_pooled_preference_histogram( ...
    T.ADI, T.Valid_ADI, T.CombinedCuePreference, adiEdges);
xline(0, 'k--', 'LineWidth', 1.2, 'HandleVisibility', 'off');
xlim([adiEdges(1), adiEdges(end)]);
xlabel('ADI');
ylabel('Proportion within preference group');
title({sprintf('%s ADI: mean %.3f, median %.3f', speedLabel, ...
    mean(T.ADI, 'omitnan'), median(T.ADI, 'omitnan')), ...
    zero_test_subtitle(zeroTests, "ADI", speedRank)});
box off;

axesHandles(3) = nexttile(layout);
plot_dataset_monkey_scatter(T);
xline(0, 'k--', 'HandleVisibility', 'off');
yline(0, 'k--', 'HandleVisibility', 'off');
xlabel('TDI');
ylabel('ADI');
title(sprintf('%s per-unit indices', speedLabel));
xlim([tdiEdges(1), tdiEdges(end)]);
ylim([adiEdges(1), adiEdges(end)]);
axis square;
box off;
end

function plot_dataset_monkey_scatter(T)
valid = T.Valid_TDI & T.Valid_ADI;
datasets = ["Lo", "EM"];
monkeys = ["Jim", "Clay"];
preferences = ["Away", "Toward"];
hold on;

for dataset = datasets
    for monkey = monkeys
        for preference = preferences
            mask = valid & T.SourceDataset == dataset ...
                & T.Monkey == monkey ...
                & T.CombinedCuePreference == preference;
            if ~any(mask)
                continue
            end
            color = preference_colors(preference);
            marker = monkey_marker(monkey);
            if dataset == "Lo"
                scatter(T.TDI(mask), T.ADI(mask), 48, 'filled', ...
                    'Marker', marker, ...
                    'MarkerFaceColor', color, 'MarkerEdgeColor', color, ...
                    'MarkerFaceAlpha', 0.62, 'MarkerEdgeAlpha', 0.85, ...
                    'HandleVisibility', 'off');
            else
                scatter(T.TDI(mask), T.ADI(mask), 54, 'Marker', marker, ...
                    'MarkerFaceColor', 'none', 'MarkerEdgeColor', color, ...
                    'MarkerEdgeAlpha', 0.9, 'LineWidth', 1.35, ...
                    'HandleVisibility', 'off');
            end
        end
    end
end

legendHandles = gobjects(6, 1);
legendLabels = {'Toward', 'Away', 'Lo Jim', 'Lo Clay', 'EM Jim', 'EM Clay'};
legendHandles(1) = plot(nan, nan, 'o', 'LineStyle', 'none', ...
    'MarkerFaceColor', preference_colors("Toward"), ...
    'MarkerEdgeColor', preference_colors("Toward"));
legendHandles(2) = plot(nan, nan, 'o', 'LineStyle', 'none', ...
    'MarkerFaceColor', preference_colors("Away"), ...
    'MarkerEdgeColor', preference_colors("Away"));
legendHandles(3) = plot(nan, nan, 'o', 'LineStyle', 'none', ...
    'MarkerFaceColor', [0.35, 0.35, 0.35], 'MarkerEdgeColor', [0.35, 0.35, 0.35]);
legendHandles(4) = plot(nan, nan, 'd', 'LineStyle', 'none', ...
    'MarkerFaceColor', [0.35, 0.35, 0.35], 'MarkerEdgeColor', [0.35, 0.35, 0.35]);
legendHandles(5) = plot(nan, nan, 'o', 'LineStyle', 'none', ...
    'MarkerFaceColor', 'none', 'MarkerEdgeColor', [0.35, 0.35, 0.35], ...
    'LineWidth', 1.35);
legendHandles(6) = plot(nan, nan, 'd', 'LineStyle', 'none', ...
    'MarkerFaceColor', 'none', 'MarkerEdgeColor', [0.35, 0.35, 0.35], ...
    'LineWidth', 1.35);
legend(legendHandles, legendLabels, 'Location', 'best', 'NumColumns', 2);
hold off;
end

function marker = monkey_marker(monkey)
if monkey == "Jim"
    marker = 'o';
elseif monkey == "Clay"
    marker = 'd';
else
    marker = '^';
end
end

function set_common_probability_limits(firstAxes, secondAxes)
upperLimit = max([firstAxes.YLim(2), secondAxes.YLim(2)]);
firstAxes.YLim = [0, upperLimit];
secondAxes.YLim = [0, upperLimit];
end

function label = zero_test_subtitle(results, indexName, speedRank)
rows = results.Index == indexName & results.SpeedRank_2D == speedRank;
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

function plot_pooled_preference_histogram(values, valid, preference, edges)
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
    labels{plotCount} = sprintf('Toward, pooled (n=%d)', nnz(toward));
end
if any(away)
    plotCount = plotCount + 1;
    plots(plotCount) = histogram(values(away), edges, ...
        'Normalization', 'probability', ...
        'FaceColor', preference_colors("Away"), ...
        'EdgeColor', preference_colors("Away"), ...
        'FaceAlpha', 0.42, 'EdgeAlpha', 0.78, 'LineWidth', 0.8);
    labels{plotCount} = sprintf('Away, pooled (n=%d)', nnz(away));
end
if any(other)
    plotCount = plotCount + 1;
    plots(plotCount) = histogram(values(other), edges, ...
        'Normalization', 'probability', ...
        'FaceColor', preference_colors("Other"), ...
        'EdgeColor', preference_colors("Other"), ...
        'FaceAlpha', 0.42, 'EdgeAlpha', 0.78, 'LineWidth', 0.8);
    labels{plotCount} = sprintf('Neutral/undefined, pooled (n=%d)', nnz(other));
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

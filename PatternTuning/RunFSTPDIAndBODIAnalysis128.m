function [LoResultTable, EMResultTable, CombinedResultTable] = ...
    RunFSTPDIAndBODIAnalysis128(outputRoot, inputPaths)
%RUNFSTPDIANDBODIANALYSIS128 Run final strict-criterion PDI/BODI analysis.

arguments
    outputRoot (1, 1) string = "C:\EM\PatternTuning\Final_128"
    inputPaths.LoNeuroResp (1, 1) string = "C:\LoData\NeuroRespUnitTable.mat"
    inputPaths.LoLateral2D (1, 1) string = "C:\LoData\LateralMotionRawFRTable.mat"
    inputPaths.LoMID (1, 1) string = "C:\LoData\MIDTable.mat"
    inputPaths.EMUnitTableGof (1, 1) string = ...
        "C:\EM\PopulationAnalysis\unit_table_gof.mat"
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

[loPattern, ~, ~, loBODI] = ComputeFSTPatternTuningIndices( ...
    lo3D.NeuroRespUnitTable, lo2D.LateralMotionRawFRTable, ...
    loMetadata.MIDTable, SelectionMode="lo-1.28");
[emPattern, ~, ~, emBODI] = ComputeEMFSTPatternTuningIndices( ...
    emData.unit_table_gof, Z3DMinus2DThreshold=1.28);

LoResultTable = BuildFSTPDIAndBODITable(loPattern, loBODI, ...
    SourceDataset="Lo", ...
    SelectionCriterion="ROI==FST & sig_Anova_CLR & Z_quad==2");
EMResultTable = BuildFSTPDIAndBODITable(emPattern, emBODI, ...
    SourceDataset="EM", ...
    SelectionCriterion="ROI==FST & ND==3D & Z3D_v_Z2D>1.28");
CombinedResultTable = sortrows([LoResultTable; EMResultTable], ...
    {'SourceDataset', 'Monkey', 'Date', 'SourceRow'});
CombinedResultTable.Properties.Description = ...
    ['Combined Lo and EM 1.28-criterion FST results: one slow-speed PDI ' ...
    'and one 3D-only BODI per neuron.'];
if numel(unique(CombinedResultTable.SourceID)) ~= height(CombinedResultTable)
    error('RunFSTPDIAndBODIAnalysis128:DuplicateSourceID', ...
        'Combined table contains duplicate neuron identifiers.');
end

pdiEdges = shared_edges(CombinedResultTable.PDI(CombinedResultTable.Valid_PDI), 0.1);
bodiEdges = shared_edges(CombinedResultTable.BODI(CombinedResultTable.Valid_BODI), 0.1);
AnalysisConfig = struct();
AnalysisConfig.Generated = datetime('now');
AnalysisConfig.LoSelection = 'ROI==FST & sig_Anova_CLR & Z_quad==2';
AnalysisConfig.EMSelection = 'ROI==FST & ND==3D & Z3D_v_Z2D>1.28';
AnalysisConfig.PDI = ...
    'Matched-slow-speed TDI for Toward preference; ADI for Away preference';
AnalysisConfig.BODI = ...
    ['(Combined_FR-Stereo_FR)/(Combined_FR+Stereo_FR), using coherence ' ...
    '+1 for Toward preference and -1 for Away preference'];
AnalysisConfig.Histograms = ...
    'All preference groups pooled; shared bins across Lo, EM, and combined figures';
AnalysisConfig.ZeroTest = ...
    ['Two-sided Wilcoxon rank-sum versus equal-sized zero reference; ' ...
    'Bonferroni family contains PDI and BODI'];
AnalysisConfig.InputPaths = inputPaths;

write_result_set(LoResultTable, fullfile(outputRoot, 'Lo'), ...
    "LoFSTPDIAndBODI128", "Lo FST - 1.28 criterion", ...
    pdiEdges, bodiEdges, AnalysisConfig);
write_result_set(EMResultTable, fullfile(outputRoot, 'EM'), ...
    "EMFSTPDIAndBODI128", "EM FST - 1.28 criterion", ...
    pdiEdges, bodiEdges, AnalysisConfig);
write_result_set(CombinedResultTable, fullfile(outputRoot, 'Combined'), ...
    "CombinedLoEMFSTPDIAndBODI128", ...
    "Combined Lo and EM FST - 1.28 criteria", ...
    pdiEdges, bodiEdges, AnalysisConfig);

fprintf('\nFinal 1.28-criterion PDI/BODI analysis\n');
print_result('Lo', LoResultTable);
print_result('EM', EMResultTable);
print_result('Combined', CombinedResultTable);
fprintf('Saved final results to %s\n', outputRoot);
end

function write_result_set(ResultTable, outputDirectory, prefix, ...
        figureTitle, pdiEdges, bodiEdges, AnalysisConfig)
if ~isfolder(outputDirectory)
    mkdir(outputDirectory);
end
SummaryTable = SummarizeFSTPDIAndBODI(ResultTable);
ZeroTestResults = BuildFSTPDIAndBODIZeroTests(ResultTable);
writetable(ResultTable, fullfile(outputDirectory, prefix + ".csv"));
writetable(SummaryTable, fullfile(outputDirectory, prefix + "Summary.csv"));
writetable(ZeroTestResults, fullfile(outputDirectory, prefix + "ZeroTests.csv"));
save(fullfile(outputDirectory, prefix + ".mat"), ...
    'ResultTable', 'SummaryTable', 'ZeroTestResults', 'AnalysisConfig', '-v7.3');
MakeFSTPDIAndBODIFigure(ResultTable, ZeroTestResults, ...
    fullfile(outputDirectory, prefix + ".png"), figureTitle, ...
    PDIEdges=pdiEdges, BODIEdges=bodiEdges);
end

function edges = shared_edges(values, binWidth)
values = values(isfinite(values));
lowerEdge = floor(min([values; 0]) / binWidth) * binWidth;
upperEdge = ceil(max([values; 0]) / binWidth) * binWidth;
if upperEdge <= lowerEdge
    upperEdge = lowerEdge + binWidth;
end
edges = lowerEdge:binWidth:upperEdge;
end

function print_result(label, T)
fprintf('%s: n=%d, PDI mean/median %.4f / %.4f, BODI %.4f / %.4f\n', ...
    label, height(T), mean(T.PDI, 'omitnan'), median(T.PDI, 'omitnan'), ...
    mean(T.BODI, 'omitnan'), median(T.BODI, 'omitnan'));
end

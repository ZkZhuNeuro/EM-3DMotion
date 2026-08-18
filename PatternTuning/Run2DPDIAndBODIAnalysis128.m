function [MT2DResults, FST2DResults] = ...
    Run2DPDIAndBODIAnalysis128(outputRoot, inputPaths)
%RUN2DPDIANDBODIANALYSIS128 Run strict MT2D and FST2D PDI/BODI analyses.
%   Produces Lo, EM, and combined result sets for each 2D population using
%   the same neuron-level table, summary, zero-test, MAT, and PNG format as
%   RunFSTPDIAndBODIAnalysis128.

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

populationNames = ["MT2D", "FST2D"];
targetROIs = ["MT", "FST"];
allResults = struct();

fprintf('\nStrict 1.28-criterion 2D PDI/BODI analyses\n');
for populationIndex = 1:numel(populationNames)
    populationName = populationNames(populationIndex);
    targetROI = targetROIs(populationIndex);

    [loPattern, ~, ~, loBODI] = ComputeFSTPatternTuningIndices( ...
        lo3D.NeuroRespUnitTable, lo2D.LateralMotionRawFRTable, ...
        loMetadata.MIDTable, SelectionMode="lo-2d-1.28", ...
        TargetROI=targetROI);
    [emPattern, ~, ~, emBODI] = ComputeEMFSTPatternTuningIndices( ...
        emData.unit_table_gof, TargetROI=targetROI, NeuroType="2D", ...
        Z3DMinus2DMaximum=-1.28);

    loSelection = "ROI==" + targetROI + ...
        " & sig_Anova_CLR & Z_quad==4";
    emSelection = "ROI==" + targetROI + ...
        " & ND==2D & Z3D_v_Z2D<-1.28";
    loResult = BuildFSTPDIAndBODITable(loPattern, loBODI, ...
        SourceDataset="Lo", SelectionCriterion=loSelection);
    emResult = BuildFSTPDIAndBODITable(emPattern, emBODI, ...
        SourceDataset="EM", SelectionCriterion=emSelection);
    combinedResult = sortrows([loResult; emResult], ...
        {'SourceDataset', 'Monkey', 'Date', 'SourceRow'});
    combinedResult.Properties.Description = sprintf( ...
        ['Combined Lo and EM strict-criterion %s results: one slow-speed ' ...
        'PDI and one 3D-stimulus BODI per neuron.'], populationName);
    if numel(unique(combinedResult.SourceID)) ~= height(combinedResult)
        error('Run2DPDIAndBODIAnalysis128:DuplicateSourceID', ...
            '%s combined table contains duplicate neuron identifiers.', ...
            populationName);
    end

    pdiEdges = shared_edges(combinedResult.PDI(combinedResult.Valid_PDI), 0.1);
    bodiEdges = shared_edges(combinedResult.BODI(combinedResult.Valid_BODI), 0.1);
    AnalysisConfig = struct();
    AnalysisConfig.Generated = datetime('now');
    AnalysisConfig.Population = populationName;
    AnalysisConfig.LoSelection = loSelection;
    AnalysisConfig.EMSelection = emSelection;
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

    populationRoot = fullfile(outputRoot, populationName);
    write_result_set(loResult, fullfile(populationRoot, 'Lo'), ...
        "Lo" + populationName + "PDIAndBODI128", ...
        "Lo " + populationName + " - 1.28 criterion", ...
        pdiEdges, bodiEdges, AnalysisConfig);
    write_result_set(emResult, fullfile(populationRoot, 'EM'), ...
        "EM" + populationName + "PDIAndBODI128", ...
        "EM " + populationName + " - 1.28 criterion", ...
        pdiEdges, bodiEdges, AnalysisConfig);
    write_result_set(combinedResult, fullfile(populationRoot, 'Combined'), ...
        "CombinedLoEM" + populationName + "PDIAndBODI128", ...
        "Combined Lo and EM " + populationName + " - 1.28 criteria", ...
        pdiEdges, bodiEdges, AnalysisConfig);

    populationResults = struct();
    populationResults.Lo = loResult;
    populationResults.EM = emResult;
    populationResults.Combined = combinedResult;
    allResults.(populationName) = populationResults;

    print_result(populationName + " Lo", loResult);
    print_result(populationName + " EM", emResult);
    print_result(populationName + " Combined", combinedResult);
end

MT2DResults = allResults.MT2D;
FST2DResults = allResults.FST2D;
fprintf('Saved strict 2D results under %s\n', outputRoot);
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
end

function print_result(label, T)
fprintf('%s: n=%d, PDI mean/median %.4f / %.4f, BODI %.4f / %.4f\n', ...
    label, height(T), mean(T.PDI, 'omitnan'), median(T.PDI, 'omitnan'), ...
    mean(T.BODI, 'omitnan'), median(T.BODI, 'omitnan'));
end

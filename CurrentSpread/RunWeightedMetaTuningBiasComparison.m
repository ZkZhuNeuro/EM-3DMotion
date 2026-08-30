function result = RunWeightedMetaTuningBiasComparison(options)
%RUNWEIGHTEDMETATUNINGBIASCOMPARISON Test neighboring tuning-curve weights.
%
% Primary expanded feature is a learned nonnegative simplex-weighted sum of
% z-scored tuning curves across a centered physical-contact window.
% Cue-specific AI is calculated from zMeta. Meta OD is calculated from the
% same weights on raw-FR tuning. Nonnegative weights sum to one and are fitted
% only inside each outer training fold. The matched baseline is center-only.

arguments
    options.DataFile (1, 1) string = ...
        "C:\EM\StimChannelAnalysis\unit_table_gof.mat"
    options.OutputFolder (1, 1) string = ""
    options.Areas (1, :) string = ["MT", "FST"]
    options.UnitTypes (1, :) string = ["2D", "3D"]
    options.JimCacheFolder (1, 1) string = "C:\Jim\StimData"
    options.ClayCacheFolder (1, 1) string = "C:\Clay\StimData"
    options.NeighborRadius (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 1
    options.NumRepeats (1, 1) double ...
        {mustBeInteger, mustBePositive} = 20
    options.NumFolds (1, 1) double ...
        {mustBeInteger, mustBeGreaterThan(options.NumFolds, 1)} = 5
    options.RandomSeed (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 1
    options.WeightStep (1, 1) double = NaN
    options.ModelVariants (1, :) string = ["AIOnly", "AIxOD"]
    options.Analyses (1, :) string = ["AllCue", "StereoOnly"]
    options.MinimumGroupSize (1, 1) double ...
        {mustBeInteger, mustBePositive} = 8
    options.FigureVisible (1, 1) logical = false
    options.WriteOutputs (1, 1) logical = true
    options.UnitTable table = table()
end

if strlength(strtrim(options.OutputFolder)) == 0
    options.OutputFolder = fullfile("C:\EM\CurrentSpread", ...
        "WeightedMetaTuningBiasComparison_Radius" + ...
        string(options.NeighborRadius));
end
if isnan(options.WeightStep)
    if options.NeighborRadius <= 1
        options.WeightStep = 0.05;
    elseif options.NeighborRadius == 2
        options.WeightStep = 0.10;
    else
        options.WeightStep = 0.20;
    end
else
    mustBeGreaterThan(options.WeightStep, 0)
    mustBeLessThanOrEqual(options.WeightStep, 0.5)
end

projectFolder = fileparts(mfilename('fullpath'));
repositoryRoot = fileparts(projectFolder);
populationFolder = fullfile(repositoryRoot, 'PopulationAnalysis');
pathWasPresent = pathContains(populationFolder);
if ~pathWasPresent
    addpath(populationFolder)
    pathCleanup = onCleanup(@() rmpath(populationFolder));
end

if isempty(options.UnitTable)
    [unitTable, resolvedDataFile, workbookAudit] = ...
        LoadLatestUnitTableGof(char(options.DataFile));
else
    unitTable = options.UnitTable;
    resolvedDataFile = "<supplied UnitTable>";
    workbookAudit = struct();
end
[deltaBias, ~, ~, validBiasFit] = ...
    CalculateSigmoidFitBiases(unitTable, 4);

fprintf('Building %d-channel trial-level tuning cache...\n', ...
    2 * options.NeighborRadius + 1)
cache = BuildThreeChannelMetaTuningCache(unitTable, deltaBias, ...
    validBiasFit, Areas=options.Areas, UnitTypes=options.UnitTypes, ...
    JimCacheFolder=options.JimCacheFolder, ...
    ClayCacheFolder=options.ClayCacheFolder, ...
    NeighborRadius=options.NeighborRadius);
if cache.SessionCount < options.MinimumGroupSize
    error('WeightedMetaTuning:TooFewCachedSessions', ...
        'Only %d sessions had complete requested-window tuning.', ...
        cache.SessionCount);
end

fprintf('Fitting training-fold-only channel weights...\n')
result = FitWeightedMetaTuningBiasModels(cache, ...
    NumRepeats=options.NumRepeats, NumFolds=options.NumFolds, ...
    RandomSeed=options.RandomSeed, WeightStep=options.WeightStep, ...
    ModelVariants=options.ModelVariants, Analyses=options.Analyses, ...
    MinimumGroupSize=options.MinimumGroupSize);
result.SourceTable = string(resolvedDataFile);
result.NeighborRadius = options.NeighborRadius;
result.WorkbookAudit = workbookAudit;
result.GeneratedAt = datetime('now', 'TimeZone', 'local');
result.OutputFolder = options.OutputFolder;
result.OutputFiles = strings(0, 1);
if result.CenterReconstructionSummary.NAIErrorAbove005 > 0
    warning('WeightedMetaTuning:CenterReconstructionDifference', ...
        ['%d sessions differ from stored stimulation-channel AI by more ' ...
        'than 0.05. The matched baseline uses reconstructed common-support ' ...
        'features; inspect the reconstruction audit.'], ...
        result.CenterReconstructionSummary.NAIErrorAbove005);
end

if options.WriteOutputs
    validateOutputFolder(options.OutputFolder, repositoryRoot)
    result.OutputFiles = SaveWeightedMetaTuningBiasComparison( ...
        result, options.OutputFolder, FigureVisible=options.FigureVisible);
    resultsFile = fullfile(options.OutputFolder, ...
        'WeightedMetaTuningBiasComparisonResults.mat');
    save(resultsFile, 'result', '-append')
end

success = result.GroupSummary.Status == "Success";
fprintf(['Weighted meta-tuning comparison complete: %d/%d groups fit; ' ...
    '%d show higher mean macro held-out R-squared.\n'], ...
    nnz(success), height(result.GroupSummary), ...
    nnz(result.GroupSummary.MeanDeltaMacroCVR2(success) > 0))
end


function present = pathContains(folder)
entries = string(strsplit(path, pathsep));
present = any(strcmpi(entries, string(folder)));
end


function validateOutputFolder(outputFolder, repositoryRoot)
outputPath = canonicalPath(outputFolder);
repositoryPath = canonicalPath(repositoryRoot);
if strcmpi(outputPath, repositoryPath) || startsWith( ...
        lower(outputPath), lower(repositoryPath + filesep))
    error('WeightedMetaTuning:OutputInsideRepository', ...
        'OutputFolder must resolve outside the repository.');
end
end


function output = canonicalPath(input)
output = string(char(java.io.File(char(input)).getCanonicalPath()));
end

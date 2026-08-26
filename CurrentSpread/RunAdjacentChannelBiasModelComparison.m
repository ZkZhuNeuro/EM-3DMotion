function result = RunAdjacentChannelBiasModelComparison(options)
%RUNADJACENTCHANNELBIASMODELCOMPARISON Implement Lo's channel-model request.
%
% The default run uses the current stimulation-channel population table and
% compares, within every MT/FST x 2D/3D x cue group:
%
%   Bias ~ AI_STIM
%   Bias ~ AI_CH-1 + AI_STIM + AI_CH+1
%
% The models use identical complete-case sessions and repeated folds. Outputs
% include ordinary/adjusted R-squared, held-out R-squared, coefficient
% silhouettes, a session-level channel audit, PNG, editable vector PDF, FIG,
% CSV, and MAT files. By default, artifacts are written outside the repository
% to C:\EM\CurrentSpread\AdjacentChannelBiasModelComparison.

arguments
    options.DataFile (1, 1) string = ...
        "C:\EM\StimChannelAnalysis\unit_table_gof.mat"
    options.OutputFolder (1, 1) string = ...
        "C:\EM\CurrentSpread\AdjacentChannelBiasModelComparison"
    options.Areas (1, :) string = ["MT", "FST"]
    options.UnitTypes (1, :) string = ["2D", "3D"]
    options.Conditions (1, :) string = ...
        ["Dominant", "Combined", "Stereo", "NonDominant"]
    options.NeighborRadius (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 1
    options.NumRepeats (1, 1) double ...
        {mustBeInteger, mustBePositive} = 20
    options.NumFolds (1, 1) double ...
        {mustBeInteger, mustBeGreaterThan(options.NumFolds, 1)} = 5
    options.RandomSeed (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 1
    options.MinimumGroupSize (1, 1) double ...
        {mustBeInteger, mustBePositive} = 8
    options.ChannelMap (1, :) double ...
        {mustBeInteger, mustBePositive} = ...
        [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]
    options.FigureVisible (1, 1) logical = false
    options.WriteOutputs (1, 1) logical = true
    options.UnitTable table = table()
end

projectFolder = fileparts(mfilename('fullpath'));
repositoryRoot = fileparts(projectFolder);
populationFolder = fullfile(repositoryRoot, 'PopulationAnalysis');
if ~isfolder(populationFolder)
    error('AdjacentChannelModel:MissingPopulationAnalysis', ...
        'PopulationAnalysis folder not found: %s', populationFolder);
end

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

[deltaBias, biasNonStim, biasStim, validBiasFit] = ...
    CalculateSigmoidFitBiases(unitTable, 4);

observations = BuildAdjacentChannelBiasObservations( ...
    unitTable, deltaBias, validBiasFit, ...
    Areas=options.Areas, UnitTypes=options.UnitTypes, ...
    Conditions=options.Conditions, NeighborRadius=options.NeighborRadius, ...
    ChannelMap=options.ChannelMap);

result = FitAdjacentChannelBiasModels(observations, ...
    Areas=options.Areas, UnitTypes=options.UnitTypes, ...
    Conditions=options.Conditions, NeighborRadius=options.NeighborRadius, ...
    NumRepeats=options.NumRepeats, NumFolds=options.NumFolds, ...
    RandomSeed=options.RandomSeed, ...
    MinimumGroupSize=options.MinimumGroupSize);

result.SourceTable = string(resolvedDataFile);
result.SourceTableRowCount = height(unitTable);
result.WorkbookAudit = workbookAudit;
result.ChannelMap = options.ChannelMap;
result.NeighborRadius = options.NeighborRadius;
result.BiasDefinition = "NoStim sigmoid-fit PSE minus Stim sigmoid-fit PSE";
result.SelectionRule = [ ...
    "Current recording-workbook sessions"; ...
    "MonoL and MonoR p_AI < 0.05 at the stimulation channel"; ...
    "2D/3D from sign(Z3D_v_Z2D)"; ...
    "Finite cue-specific sigmoid-fit delta bias"; ...
    "Matched complete cases at every included physical channel"];
result.ResamplingInterpretation = [ ...
    "Repeated-CV percentile ranges describe partition sensitivity, not inferential confidence intervals"; ...
    "Coefficient silhouettes summarize overlapping CV training folds and are descriptive stability plots"];
result.BiasNonStim = biasNonStim;
result.BiasStim = biasStim;
result.ValidBiasFit = validBiasFit;
result.GeneratedAt = datetime('now', 'TimeZone', 'local');
result.OutputFolder = options.OutputFolder;
result.OutputFiles = strings(0, 1);

if options.WriteOutputs
    validateOutputFolder(options.OutputFolder, repositoryRoot)
    fprintf('Adjacent-channel results: %s\n', options.OutputFolder)
    result.OutputFiles = SaveAdjacentChannelBiasModelComparison( ...
        result, options.OutputFolder, FigureVisible=options.FigureVisible);
    resultsFile = fullfile(options.OutputFolder, ...
        'AdjacentChannelBiasModelComparisonResults.mat');
    save(resultsFile, 'result', '-append')
end

successful = result.GroupSummary.Status == "Success";
fprintf(['Adjacent-channel model comparison complete: %d/%d groups fit; ' ...
    '%d show higher mean held-out R-squared.\n'], ...
    nnz(successful), height(result.GroupSummary), ...
    nnz(result.GroupSummary.ImprovesMeanCVR2(successful)))
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
    error('AdjacentChannelModel:OutputInsideRepository', ...
        ['OutputFolder resolves inside the repository. Choose an external ' ...
        'folder such as C:\\EM\\CurrentSpread\\AdjacentChannelBiasModelComparison.']);
end
end


function output = canonicalPath(input)
output = string(char(java.io.File(char(input)).getCanonicalPath()));
end

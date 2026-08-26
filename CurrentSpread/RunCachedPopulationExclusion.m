function analysis = RunCachedPopulationExclusion( ...
        analysisName, excludedOriginalRows, options)
%RUNCACHEDPOPULATIONEXCLUSION Quickly refit plots after row exclusions.
%
% The expensive/source-dependent step is cached as a compact normalized
% original-Max-OD population table. Each call only removes SourceTableRow
% values, fits the population models, and exports figures/tables.

arguments
    analysisName (1, 1) string
    excludedOriginalRows (:, 1) double = zeros(0, 1)
    options.StateFile (1, 1) string = ...
        "C:\EM\PopulationAnalysis\unit_table_gof.mat"
    options.CacheFile (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\PopulationQuickAccess\" + ...
        "OriginalMaxOD_PreparedPopulation.mat"
    options.OutputFolder (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\PopulationQuickAccess\Results"
    options.Areas (1, :) string = ["MT", "FST"]
    options.Monkey (1, 1) string ...
        {mustBeMember(options.Monkey, ["Both", "Jim", "Clay"])} = "Both"
    options.FigureVisible (1, 1) logical = false
    options.ForceRebuildCache (1, 1) logical = false
end

if strlength(strip(analysisName)) == 0
    error('CachedPopulation:EmptyName', ...
        'analysisName must be nonempty.');
end
areas = unique(upper(options.Areas), 'stable');
if isempty(areas) || any(~ismember(areas, ["MT", "FST"]))
    error('CachedPopulation:InvalidAreas', ...
        'Areas must contain MT, FST, or both.');
end

scriptFolder = string(fileparts(mfilename('fullpath')));
projectFolder = string(fileparts(scriptFolder));
populationFolder = fullfile(projectFolder, 'PopulationAnalysis');
addpath(scriptFolder, populationFolder);

[preparedPopulationTable, cacheMetadata] = loadOrBuildCache( ...
    options.StateFile, options.CacheFile, options.ForceRebuildCache);
excludedOriginalRows = unique(excludedOriginalRows(isfinite( ...
    excludedOriginalRows) & excludedOriginalRows >= 1 & ...
    excludedOriginalRows == fix(excludedOriginalRows)));
matchedExcludedRows = intersect( ...
    preparedPopulationTable.SourceTableRow, excludedOriginalRows);
included = ~ismember( ...
    preparedPopulationTable.SourceTableRow, matchedExcludedRows);
filteredTable = preparedPopulationTable(included, :);

ensureFolder(options.OutputFolder);
exclusionAudit = preparedPopulationTable(:, intersect( ...
    {'SourceTableRow', 'Date', 'Monkey', 'ROI'}, ...
    preparedPopulationTable.Properties.VariableNames, 'stable'));
exclusionAudit.Excluded = ismember( ...
    exclusionAudit.SourceTableRow, matchedExcludedRows);
writetable(exclusionAudit, fullfile(options.OutputFolder, ...
    'PopulationExclusionAudit.csv'));

areaResults = struct();
perCueSummary = table();
mergedEye2DSummary = table();
modelSummary = table();
for areaIndex = 1:numel(areas)
    area = areas(areaIndex);
    result = RunUnifiedPopulationFromPreparedTable( ...
        filteredTable, area, options.Monkey, analysisName, ...
        FigureVisible=options.FigureVisible);
    modelBiasTable = result.BiasTable;
    modelBiasTable.UnitIndex = modelBiasTable.SourceTableRow;
    [thisPerCue, thisMerged, thisModel] = ...
        BuildPopulationModelSummaryByUnitType( ...
        modelBiasTable, area, options.Monkey);
    perCueSummary = [perCueSummary; thisPerCue]; %#ok<AGROW>
    mergedEye2DSummary = [mergedEye2DSummary; thisMerged]; %#ok<AGROW>
    modelSummary = [modelSummary; thisModel]; %#ok<AGROW>

    areaFolder = fullfile(options.OutputFolder, area);
    ensureFolder(areaFolder);
    result.FigureFiles = struct( ...
        'TwoD', saveFigureSet(result.Figure2D, areaFolder, ...
        analysisName + "_" + area + "_" + options.Monkey + "_2D"), ...
        'ThreeD', saveFigureSet(result.Figure3D, areaFolder, ...
        analysisName + "_" + area + "_" + options.Monkey + "_3D"));
    close([result.Figure2D, result.Figure3D]);
    result.Figure2D = gobjects(0);
    result.Figure3D = gobjects(0);
    areaResults.(char(area)) = result;
end

writetable(perCueSummary, fullfile(options.OutputFolder, ...
    'PopulationPerCueModelSummary.csv'));
writetable(mergedEye2DSummary, fullfile(options.OutputFolder, ...
    'PopulationMergedEye2DModelSummary.csv'));
writetable(modelSummary, fullfile(options.OutputFolder, ...
    'PopulationModelSummary.csv'));

runSummary = table(analysisName, height(preparedPopulationTable), ...
    numel(excludedOriginalRows), numel(matchedExcludedRows), ...
    height(filteredTable), string(options.CacheFile), ...
    'VariableNames', {'Analysis', 'PreparedSourceRows', ...
    'RequestedExcludedRows', 'MatchedExcludedRows', ...
    'RemainingSourceRows', 'PopulationCacheFile'});
writetable(runSummary, fullfile(options.OutputFolder, 'RunSummary.csv'));

analysis = struct();
analysis.AnalysisName = analysisName;
analysis.OutputFolder = options.OutputFolder;
analysis.CacheFile = options.CacheFile;
analysis.CacheMetadata = cacheMetadata;
analysis.ExcludedOriginalRows = matchedExcludedRows;
analysis.RunSummary = runSummary;
analysis.AreaResults = areaResults;
analysis.PerCueModelSummary = perCueSummary;
analysis.MergedEye2DModelSummary = mergedEye2DSummary;
analysis.ModelSummary = modelSummary;
population_analysis = analysis;
save(fullfile(options.OutputFolder, 'PopulationAnalysisResults.mat'), ...
    'population_analysis', '-v7.3');

fprintf(['Cached population analysis %s complete: excluded %d source ' ...
    'rows; outputs: %s\n'], analysisName, numel(matchedExcludedRows), ...
    options.OutputFolder);
end


function [prepared, metadata] = loadOrBuildCache( ...
        stateFile, cacheFile, forceRebuild)
if isfile(cacheFile) && ~forceRebuild
    loaded = load(cacheFile, 'preparedPopulationTable', 'cacheMetadata');
    if isfield(loaded, 'preparedPopulationTable') && ...
            isfield(loaded, 'cacheMetadata')
        prepared = loaded.preparedPopulationTable;
        metadata = loaded.cacheMetadata;
        return
    end
end

[unitTable, resolvedStateFile, workbookAudit] = ...
    LoadLatestUnitTableGof(stateFile);
prepared = PrepareOriginalMaxODPopulationTable(unitTable);
metadata = struct();
metadata.SourceStateFile = resolvedStateFile;
metadata.Created = datetime('now');
metadata.WorkbookAudit = workbookAudit;
metadata.Definition = [ ...
    "Original stimulation-channel 3DMotionQuick AI"; ...
    "Original signed maximum-response OD_max"; ...
    "Compact normalized input for repeated exclusion-mask analyses"];
cacheFolder = string(fileparts(cacheFile));
ensureFolder(cacheFolder);
preparedPopulationTable = prepared;
cacheMetadata = metadata;
save(cacheFile, 'preparedPopulationTable', 'cacheMetadata', '-v7.3');
end


function files = saveFigureSet(figureHandle, outputFolder, baseName)
baseName = regexprep(char(baseName), '[^A-Za-z0-9_.-]+', '_');
files = struct();
files.PNG = fullfile(outputFolder, [baseName '.png']);
files.FIG = fullfile(outputFolder, [baseName '.fig']);
exportgraphics(figureHandle, files.PNG, 'Resolution', 300);
savefig(figureHandle, files.FIG);
end


function ensureFolder(folder)
if ~isfolder(folder)
    mkdir(folder);
end
end

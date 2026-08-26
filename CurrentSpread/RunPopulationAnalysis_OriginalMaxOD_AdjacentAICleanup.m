function analysis = ...
    RunPopulationAnalysis_OriginalMaxOD_AdjacentAICleanup(options)
%RUNPOPULATIONANALYSIS_ORIGINALMAXOD_ADJACENTAICLEANUP Audit and filter sites.
%
% This runner preserves the original population definition: 3DMotionQuick
% AI is read at the stimulation acquisition channel. By default,
% maximum-response OD (OD_max) assigns the dominant eye and supplies the
% absolute model weight; ODMethod="LSQ" recalculates the corresponding LSQ
% OD at that same fixed stimulation channel.
% It first runs the original cohort and marks every population point from a
% site with a significant adjacent-channel combined-AI sign flip. It then
% removes those sites and reruns the complete population analysis.

arguments
    options.StateFile (1, 1) string = ...
        "C:\EM\PopulationAnalysis\unit_table_gof.mat"
    options.OutputFolder (1, 1) string = ...
        ["C:\EM\StimTuningAnalysis\" + ...
        "OriginalMaxOD_AdjacentCombinedAIConsistency_UnitTypeModels"]
    options.Areas (1, :) string = ["MT", "FST"]
    options.Monkey (1, 1) string ...
        {mustBeMember(options.Monkey, ["Both", "Jim", "Clay"])} = "Both"
    options.TuningAlpha (1, 1) double ...
        {mustBeGreaterThan(options.TuningAlpha, 0), ...
        mustBeLessThan(options.TuningAlpha, 1)} = 0.05
    options.NeighborRadius (1, 1) double ...
        {mustBeInteger, mustBeMember(options.NeighborRadius, [1, 2])} = 1
    options.ODMethod (1, 1) string ...
        {mustBeMember(options.ODMethod, ["Max", "LSQ"])} = "Max"
    options.FigureVisible (1, 1) logical = false
    options.JimCacheFolder (1, 1) string = "C:\Jim\StimData"
    options.ClayCacheFolder (1, 1) string = "C:\Clay\StimData"
end

areas = unique(upper(options.Areas), 'stable');
if isempty(areas) || any(~ismember(areas, ["MT", "FST"]))
    error('AdjacentAIFlipPopulation:InvalidAreas', ...
        'Areas must contain MT, FST, or both.');
end
if ~isfile(options.StateFile)
    error('AdjacentAIFlipPopulation:MissingStateFile', ...
        'Input MAT file does not exist: %s', options.StateFile);
end

scriptFolder = string(fileparts(mfilename('fullpath')));
projectFolder = string(fileparts(scriptFolder));
populationFolder = fullfile(projectFolder, 'PopulationAnalysis');
populationScript = fullfile(populationFolder, ...
    'RunPopulationAnalysis_ODweighted.m');
if ~isfile(populationScript)
    error('AdjacentAIFlipPopulation:MissingPopulationScript', ...
        'Population analysis script does not exist: %s', populationScript);
end
addpath(scriptFolder, populationFolder);
if ~isfolder(options.OutputFolder)
    mkdir(options.OutputFolder);
end

[unitTable, resolvedStateFile, workbookAudit] = ...
    LoadLatestUnitTableGof(options.StateFile);
candidateMask = populationCandidateMask( ...
    unitTable, areas, options.Monkey);
adjacentAudit = AuditAdjacentQuickChannelAIFlips(unitTable, ...
    JimCacheFolder=options.JimCacheFolder, ...
    ClayCacheFolder=options.ClayCacheFolder, ...
    TuningAlpha=options.TuningAlpha, ...
    NeighborRadius=options.NeighborRadius, ...
    CandidateMask=candidateMask);
writetable(adjacentAudit, fullfile(options.OutputFolder, ...
    'AdjacentChannelCombinedAIFlipAudit.csv'));

[unitTable, odAudit, criteriaAudit] = prepareFixedStimChannelOD( ...
    unitTable, options.ODMethod, options.JimCacheFolder, ...
    options.ClayCacheFolder);
if options.ODMethod == "LSQ"
    writetable(odAudit, fullfile(options.OutputFolder, ...
        'OriginalStimChannel_LSQ_OD_Audit.csv'));
    writetable(criteriaAudit, fullfile(options.OutputFolder, ...
        'OriginalStimChannel_LSQ_SelectionCriteriaAudit.csv'));
end

if options.ODMethod == "LSQ"
    originalInputName = 'unit_table_gof_original_lsq_od.mat';
    filteredInputName = ...
        'unit_table_gof_adjacent_ai_flip_excluded_lsq_od.mat';
    resultBaseName = "OriginalLSQOD";
    analysisFileName = 'OriginalLSQOD_AdjacentAICleanupResults.mat';
else
    originalInputName = 'unit_table_gof_original_max_od.mat';
    filteredInputName = 'unit_table_gof_adjacent_ai_flip_excluded.mat';
    resultBaseName = "OriginalMaxOD";
    analysisFileName = 'OriginalMaxOD_AdjacentAICleanupResults.mat';
end

originalInputFile = fullfile(options.OutputFolder, ...
    originalInputName);
savePopulationInput(originalInputFile, unitTable, adjacentAudit, ...
    workbookAudit, resolvedStateFile, false, options.ODMethod, ...
    odAudit, criteriaAudit);

excludedRows = adjacentAudit.TableRow(adjacentAudit.ExcludeForAIFlip);
filteredTable = unitTable(~adjacentAudit.ExcludeForAIFlip, :);
filteredInputFile = fullfile(options.OutputFolder, ...
    filteredInputName);
savePopulationInput(filteredInputFile, filteredTable, adjacentAudit, ...
    workbookAudit, resolvedStateFile, true, options.ODMethod, ...
    odAudit, criteriaAudit);

previousVisibility = get(groot, 'defaultFigureVisible');
visibilityCleanup = onCleanup( ...
    @() set(groot, 'defaultFigureVisible', previousVisibility));
if options.FigureVisible
    set(groot, 'defaultFigureVisible', 'on');
else
    set(groot, 'defaultFigureVisible', 'off');
end

areaResults = struct();
allSummary = table();
allAIxODSummary = table();
allModelSummary = table();
areaFlow = table();
for areaIndex = 1:numel(areas)
    areaName = areas(areaIndex);
    areaFolder = fullfile(options.OutputFolder, areaName);
    originalFolder = fullfile(areaFolder, 'Original_Annotated');
    filteredFolder = fullfile(areaFolder, 'AIFlipExcluded');
    ensureFolder(originalFolder);
    ensureFolder(filteredFolder);

    original = executePopulationScript(populationScript, ...
        originalInputFile, areaName, options.Monkey);
    original = applyReadableMarkerEdgeTransparency(original);
    original = applyModelSpecification(original);
    original.adjacent_ai_flip_rule = exclusionRule( ...
        options.TuningAlpha, options.NeighborRadius);
    original.adjacent_neighbor_radius = options.NeighborRadius;
    original.adjacent_ai_flip_excluded = false;
    original.adjacent_ai_flip_table_rows = excludedRows;
    original.od_method = options.ODMethod;
    original = annotateAndSaveResult(original, originalFolder, ...
        resultBaseName + "_Annotated", excludedRows, true);

    filtered = executePopulationScript(populationScript, ...
        filteredInputFile, areaName, options.Monkey);
    filtered = applyReadableMarkerEdgeTransparency(filtered);
    filtered = applyModelSpecification(filtered);
    filtered.adjacent_ai_flip_rule = exclusionRule( ...
        options.TuningAlpha, options.NeighborRadius);
    filtered.adjacent_neighbor_radius = options.NeighborRadius;
    filtered.adjacent_ai_flip_excluded = true;
    filtered.adjacent_ai_flip_original_table_rows = excludedRows;
    filtered.od_method = options.ODMethod;
    filtered = annotateAndSaveResult(filtered, filteredFolder, ...
        resultBaseName + "_AIFlipExcluded", zeros(0, 1), false);

    fieldName = char(areaName);
    areaResults.(fieldName) = struct( ...
        'OriginalAnnotated', original, 'AIFlipExcluded', filtered);
    allSummary = [allSummary; tagCohort(original.summary_table, ...
        "Original (AI-flip sites marked)"); ...
        tagCohort(filtered.summary_table, ...
        "Adjacent AI-flip sites excluded")]; %#ok<AGROW>
    allAIxODSummary = [allAIxODSummary; ...
        tagCohort(original.aixod_summary_table, ...
        "Original (AI-flip sites marked)"); ...
        tagCohort(filtered.aixod_summary_table, ...
        "Adjacent AI-flip sites excluded")]; %#ok<AGROW>
    allModelSummary = [allModelSummary; ...
        tagCohort(original.model_summary_table, ...
        "Original (AI-flip sites marked)"); ...
        tagCohort(filtered.model_summary_table, ...
        "Adjacent AI-flip sites excluded")]; %#ok<AGROW>
    areaFlow = [areaFlow; buildAreaFlow(areaName, original, filtered, ...
        adjacentAudit, excludedRows)]; %#ok<AGROW>
end
clear visibilityCleanup

writetable(allSummary, fullfile(options.OutputFolder, ...
    'PopulationSummary_OriginalVsAIFlipExcluded.csv'));
writetable(allAIxODSummary, fullfile(options.OutputFolder, ...
    'PopulationAIxODSummary_OriginalVsAIFlipExcluded.csv'));
writetable(allModelSummary, fullfile(options.OutputFolder, ...
    'PopulationModelSummary_OriginalVsAIFlipExcluded.csv'));
writetable(areaFlow, fullfile(options.OutputFolder, ...
    'PopulationCohortFlow.csv'));

analysis = struct();
analysis.StateFile = resolvedStateFile;
analysis.OutputFolder = options.OutputFolder;
analysis.Areas = areas;
analysis.Monkey = options.Monkey;
analysis.ODMethod = options.ODMethod;
analysis.TuningSource = "3DMotionQuick stimulation channel";
analysis.TuningAlpha = options.TuningAlpha;
analysis.NeighborRadius = options.NeighborRadius;
analysis.ExclusionRule = exclusionRule( ...
    options.TuningAlpha, options.NeighborRadius);
analysis.AdjacentChannelAudit = adjacentAudit;
analysis.ExcludedOriginalTableRows = excludedRows;
analysis.OriginalInputFile = originalInputFile;
analysis.FilteredInputFile = filteredInputFile;
analysis.ODAudit = odAudit;
analysis.SelectionCriteriaAudit = criteriaAudit;
analysis.WorkbookAudit = workbookAudit;
analysis.AreaResults = areaResults;
analysis.PopulationSummaryComparison = allSummary;
analysis.PopulationAIxODSummaryComparison = allAIxODSummary;
analysis.PopulationModelSummaryComparison = allModelSummary;
analysis.PopulationCohortFlow = areaFlow;
population_analysis = analysis;
save(fullfile(options.OutputFolder, analysisFileName), ...
    'population_analysis', '-v7.3');

fprintf(['Completed original %s-OD adjacent-channel AI cleanup. ' ...
    'Flagged %d candidate site(s). Outputs: %s\n'], ...
    options.ODMethod, numel(excludedRows), options.OutputFolder);
end


function mask = populationCandidateMask(unitTable, areas, monkey)
required = ["ROI", "Monkey", "p_AI", "Z3D_v_Z2D"];
missing = setdiff(required, string(unitTable.Properties.VariableNames));
if ~isempty(missing)
    error('AdjacentAIFlipPopulation:MissingSelectionVariables', ...
        'Missing population-selection variable(s): %s', join(missing, ', '));
end
rowCount = height(unitTable);
mask = false(rowCount, 1);
for row = 1:rowCount
    roi = getRowText(unitTable.ROI, row);
    monkeyName = getRowText(unitTable.Monkey, row);
    if ~ismember(upper(roi), areas) || ...
            (monkey ~= "Both" && ~strcmpi(monkeyName, monkey))
        continue
    end
    pValues = getNumericRowValue(unitTable.p_AI, row);
    zValue = getNumericRowValue(unitTable.Z3D_v_Z2D, row);
    mask(row) = numel(pValues) >= 3 && pValues(2) < 0.05 && ...
        pValues(3) < 0.05 && isscalar(zValue) && ...
        isfinite(zValue) && zValue ~= 0;
end
end


function savePopulationInput(fileName, unitTable, adjacentAudit, ...
    workbookAudit, sourceFile, isFiltered, odMethod, odAudit, criteriaAudit)
unit_table_gof = unitTable;
AdjacentChannelCombinedAIFlipAudit = adjacentAudit;
AdjacentChannelAIFlipSourceFile = sourceFile;
AdjacentChannelAIFlipFilteredInput = isFiltered;
OriginalStimChannelODMethod = odMethod;
OriginalStimChannelODAudit = odAudit;
OriginalStimChannelSelectionCriteriaAudit = criteriaAudit;
save(fileName, 'unit_table_gof', 'AdjacentChannelCombinedAIFlipAudit', ...
    'workbookAudit', 'AdjacentChannelAIFlipSourceFile', ...
    'AdjacentChannelAIFlipFilteredInput', 'OriginalStimChannelODMethod', ...
    'OriginalStimChannelODAudit', ...
    'OriginalStimChannelSelectionCriteriaAudit', '-v7.3');
end


function [preparedTable, odAudit, criteriaAudit] = ...
    prepareFixedStimChannelOD(unitTable, odMethod, jimCache, clayCache)
preparedTable = unitTable;
odAudit = table();
criteriaAudit = table();
if odMethod == "Max"
    return
end

rowCount = height(unitTable);
unitTableRow = (1:rowCount)';
bestChannel = nan(rowCount, 1);
for row = 1:rowCount
    value = getNumericRowValue(unitTable.StimElec, row);
    if ~isscalar(value)
        error('AdjacentAIFlipPopulation:InvalidStimChannel', ...
            'StimElec is not scalar at source row %d.', row);
    end
    bestChannel(row) = value;
end
fixedStimChannelMetric = zeros(rowCount, 1);
status = repmat("Success", rowCount, 1);
fixedSelection = table(unitTableRow, bestChannel, ...
    fixedStimChannelMetric, status, 'VariableNames', ...
    {'UnitTableRow', 'BestChannel', 'FixedStimChannelMetric', 'Status'});

[preparedTable, odAudit] = PrepareBestQuickChannelPopulationTable( ...
    unitTable, fixedSelection, "FixedStimElec", ...
    "FixedStimChannelMetric", "LSQ");
[preparedTable, criteriaAudit] = ...
    PrepareBestQuickChannelSelectionCriteria(preparedTable, ...
    JimCacheFolder=jimCache, ClayCacheFolder=clayCache, ...
    DominantEyeMethod="SelectedOD");
end


function result = executePopulationScript( ...
    populationScript, inputFile, areaName, monkeyName)
% Isolate the legacy script because it uses clearvars and assignin.
area = char(areaName); %#ok<NASGU>
monkey = char(monkeyName); %#ok<NASGU>
data_file = char(inputFile); %#ok<NASGU>
stim_data_file = ''; %#ok<NASGU>
close_existing_figures = true; %#ok<NASGU>
tuning_source = 'Quick'; %#ok<NASGU>
population_analysis_use_supplied_settings = true; %#ok<NASGU>
run(populationScript)
result = results;
end


function result = annotateAndSaveResult( ...
    result, outputFolder, baseName, flaggedRows, addAnnotation)
if addAnnotation
    annotateFigure(result.fig_2d, result.bias_table, '2D', flaggedRows, ...
        result.adjacent_neighbor_radius);
    annotateFigure(result.fig_3d, result.bias_table, '3D', flaggedRows, ...
        result.adjacent_neighbor_radius);
end
figureFiles = struct();
figureFiles.TwoD = saveFigureSet(result.fig_2d, outputFolder, ...
    baseName + "_" + result.area + "_" + result.monkey + "_2D");
figureFiles.ThreeD = saveFigureSet(result.fig_3d, outputFolder, ...
    baseName + "_" + result.area + "_" + result.monkey + "_3D");
result.figure_files = figureFiles;
writetable(result.summary_table, fullfile(outputFolder, ...
    'PopulationSummary.csv'));
writetable(result.aixod_summary_table, fullfile(outputFolder, ...
    'PopulationAIxODSummary.csv'));
writetable(result.model_summary_table, fullfile(outputFolder, ...
    'PopulationModelSummary.csv'));
writetable(result.bias_table, fullfile(outputFolder, ...
    'PopulationBiasTable.csv'));
closeValidFigure(result.fig_2d);
closeValidFigure(result.fig_3d);
result.fig_2d = gobjects(0);
result.fig_3d = gobjects(0);
population_results = result;
save(fullfile(outputFolder, 'PopulationAnalysisResults.mat'), ...
    'population_results', '-v7.3');
end


function result = applyModelSpecification(result)
% Preserve the legacy broad tables for provenance, but make the requested
% unit-type-specific fits the authoritative exported summaries.
result.legacy_summary_table = result.summary_table;
result.legacy_aixod_summary_table = result.aixod_summary_table;
[perCue, mergedEye2D, modelSummary] = ...
    BuildPopulationModelSummaryByUnitType(result.bias_table, ...
    string(result.area), string(result.monkey));
result.per_cue_summary_table = perCue;
result.merged_eye_2d_summary_table = mergedEye2D;
result.model_summary_table = modelSummary;
result.summary_table = perCue;
result.aixod_summary_table = mergedEye2D;
result.model_specification = [ ...
    "2D: DeltaBias ~ AI separately for each cue"; ...
    "2D: MergedEyeDeltaBias ~ AI + AI:OD for dominant + non-dominant eyes"; ...
    "3D: DeltaBias ~ AI separately for each cue; no merged-eye model"];
end


function result = applyReadableMarkerEdgeTransparency(result)
% Keep OD-driven face opacity while preventing low-OD outlines from fading.
edgeAlpha = 0.55;
figureFields = {'fig_2d', 'fig_3d'};
for fieldIndex = 1:numel(figureFields)
    fieldName = figureFields{fieldIndex};
    if ~isfield(result, fieldName) || ...
            ~isgraphics(result.(fieldName), 'figure')
        continue
    end
    markers = findobj(result.(fieldName), 'Type', 'Scatter');
    for markerIndex = 1:numel(markers)
        faceAlpha = markers(markerIndex).MarkerFaceAlpha;
        if (ischar(faceAlpha) || isstring(faceAlpha)) && ...
                strcmp(faceAlpha, 'flat')
            markers(markerIndex).MarkerEdgeAlpha = edgeAlpha;
        end
    end
end
result.marker_face_alpha_source = "OD AlphaData";
result.marker_edge_alpha = edgeAlpha;
end


function annotateFigure( ...
    figureHandle, biasTable, unitType, flaggedRows, neighborRadius)
if isempty(flaggedRows) || isempty(biasTable) || ...
        ~isgraphics(figureHandle, 'figure')
    return
end
marked = ismember(biasTable.UnitIndex, flaggedRows) & ...
    strcmp(string(biasTable.UnitType), unitType);
if ~any(marked)
    return
end
axesHandle = findobj(figureHandle, 'Type', 'axes');
if isempty(axesHandle)
    return
end
axesHandle = axesHandle(1);
hold(axesHandle, 'on')
marker = scatter(axesHandle, biasTable.AI(marked), ...
    biasTable.Bias(marked), 105, 'o', ...
    'MarkerEdgeColor', [0.85 0.05 0.05], ...
    'MarkerFaceColor', 'none', 'LineWidth', 2.2);
marker.HandleVisibility = 'off';
siteCount = numel(unique(biasTable.UnitIndex(marked)));
label = sprintf([ ...
    'Red rings: significant combined-AI sign flip within +/- %d contacts ' ...
    '(%d site%s)'], neighborRadius, siteCount, pluralSuffix(siteCount));
text(axesHandle, -0.97, 2.08, label, ...
    'Color', [0.75 0 0], 'FontSize', 10, 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
    'Interpreter', 'none', 'Clipping', 'on');
end


function suffix = pluralSuffix(count)
if count == 1
    suffix = '';
else
    suffix = 's';
end
end


function files = saveFigureSet(figureHandle, folder, baseName)
files = struct();
files.PNG = fullfile(folder, baseName + ".png");
files.PDF = fullfile(folder, baseName + ".pdf");
files.FIG = fullfile(folder, baseName + ".fig");
exportgraphics(figureHandle, files.PNG, 'Resolution', 300);
exportgraphics(figureHandle, files.PDF, 'ContentType', 'vector');
savefig(figureHandle, files.FIG);
end


function output = tagCohort(input, cohort)
output = input;
output.Cohort = repmat(cohort, height(output), 1);
output = movevars(output, 'Cohort', 'Before', 1);
end


function output = buildAreaFlow( ...
    area, original, filtered, audit, excludedRows)
areaAuditRows = audit.CandidateForPopulation & audit.ROI == area;
successfulAuditRows = areaAuditRows & audit.Status == "Success";
flaggedAreaRows = areaAuditRows & audit.ExcludeForAIFlip;
originalUnits = unique(original.bias_table.UnitIndex);
flaggedOriginalUnits = intersect(originalUnits, excludedRows);
Area = area;
CandidateSites = sum(areaAuditRows);
SuccessfullyAuditedSites = sum(successfulAuditRows);
AuditErrorSites = sum(areaAuditRows & audit.Status == "Error");
FlaggedSites = sum(flaggedAreaRows);
FlaggedSitesInOriginalPopulation = numel(flaggedOriginalUnits);
OriginalPopulationSites = numel(originalUnits);
FilteredPopulationSites = numel(unique(filtered.bias_table.UnitIndex));
RemovedPopulationSites = OriginalPopulationSites - FilteredPopulationSites;
output = table(Area, CandidateSites, SuccessfullyAuditedSites, ...
    AuditErrorSites, FlaggedSites, FlaggedSitesInOriginalPopulation, ...
    OriginalPopulationSites, FilteredPopulationSites, ...
    RemovedPopulationSites);
end


function text = exclusionRule(alpha, neighborRadius)
text = sprintf(['Exclude a stimulation site when any of the %d physical ' ...
    'neighbors on each side is live, has raw combined-cue direction-tuning ' ...
    'p < %.6g, ' ...
    'and has combined-cue AI with the opposite nonzero sign from the ' ...
    'stimulation channel.'], neighborRadius, alpha);
end


function ensureFolder(folder)
if ~isfolder(folder)
    mkdir(folder);
end
end


function closeValidFigure(figureHandle)
if ~isempty(figureHandle) && all(isgraphics(figureHandle, 'figure'))
    close(figureHandle);
end
end


function value = getNumericRowValue(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
while iscell(value) && isscalar(value)
    value = value{1};
end
if ~isnumeric(value)
    value = NaN;
else
    value = double(value);
end
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
if ~isscalar(value)
    value = join(value, ",");
end
end

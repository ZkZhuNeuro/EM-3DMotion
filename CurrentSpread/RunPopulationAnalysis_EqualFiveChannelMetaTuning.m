function analysis = RunPopulationAnalysis_EqualFiveChannelMetaTuning(options)
%RUNPOPULATIONANALYSIS_EQUALFIVECHANNELMETATUNING Run the bold meta readout.
%
% Five physical contacts (-2, -1, stimulation, +1, +2) are independently
% z-scored across all valid Quick-task trials, then averaged trial-by-trial
% with exactly equal weights. AI is calculated from the four strongest
% matched coherence pairs. Maximum-response OD, dominant-eye assignment,
% and Z3D-Z2D classification are recalculated from the equal-weight raw-FR
% five-channel meta curve. Only the original p_AI selection remains fixed.
%
% The runner also analyzes (1) the stored stimulation-channel AI and (2) a
% stimulation-channel AI reconstructed from the same raw trials and four
% coherence pairs, on the exact same five-channel-eligible cohort. The
% latter is the strict control for the effect of merging channels.

arguments
    options.StateFile (1, 1) string = ...
        "C:\EM\PopulationAnalysis\unit_table_gof.mat"
    options.OutputFolder (1, 1) string = ...
        ["C:\EM\StimTuningAnalysis\" + ...
        "EqualFiveChannelZScoredMetaTuning_MetaOD_MetaClass"]
    options.Areas (1, :) string = ["MT", "FST"]
    options.Monkey (1, 1) string ...
        {mustBeMember(options.Monkey, ["Both", "Jim", "Clay"])} = "Both"
    options.FigureVisible (1, 1) logical = false
    options.JimCacheFolder (1, 1) string = "C:\Jim\StimData"
    options.ClayCacheFolder (1, 1) string = "C:\Clay\StimData"
    options.WeightingMode (1, 1) string ...
        {mustBeMember(options.WeightingMode, ...
        ["EqualFive", "GaussianAll"])} = "EqualFive"
    options.GaussianSigma (1, 1) double = NaN
    options.ExcludedOriginalRows (:, 1) double ...
        {mustBeInteger, mustBePositive} = zeros(0, 1)
end

if options.WeightingMode == "GaussianAll"
    if ~isfinite(options.GaussianSigma) || options.GaussianSigma <= 0
        error('FiveChannelMetaPopulation:InvalidGaussianSigma', ...
            'GaussianSigma must be finite and positive in GaussianAll mode.');
    end
    metaReadout = "All-channel Gaussian z-scored meta";
    metaBaseName = "GaussianAllChannelZScoredMeta";
    metaFolderName = "GaussianAllChannelMeta";
else
    metaReadout = "Equal five-channel z-scored meta";
    metaBaseName = "EqualFiveChannelZScoredMeta";
    metaFolderName = "EqualFiveChannelMeta";
end

areas = unique(upper(options.Areas), 'stable');
if isempty(areas) || any(~ismember(areas, ["MT", "FST"]))
    error('FiveChannelMetaPopulation:InvalidAreas', ...
        'Areas must contain MT, FST, or both.');
end
if ~isfile(options.StateFile)
    error('FiveChannelMetaPopulation:MissingStateFile', ...
        'Input MAT file does not exist: %s', options.StateFile);
end

scriptFolder = string(fileparts(mfilename('fullpath')));
projectFolder = string(fileparts(scriptFolder));
populationFolder = fullfile(projectFolder, 'PopulationAnalysis');
populationScript = fullfile(populationFolder, ...
    'RunPopulationAnalysis_ODweighted.m');
if ~isfile(populationScript)
    error('FiveChannelMetaPopulation:MissingPopulationScript', ...
        'Population analysis script does not exist: %s', populationScript);
end
addpath(scriptFolder, populationFolder);
ensureFolder(options.OutputFolder);

[unitTable, resolvedStateFile, workbookAudit] = ...
    LoadLatestUnitTableGof(options.StateFile);
candidateMask = populationCandidateMask(unitTable, areas, options.Monkey);
excludedOriginalRows = unique(options.ExcludedOriginalRows(:));
excludedOriginalRows = excludedOriginalRows( ...
    excludedOriginalRows <= height(unitTable));
candidateMask(excludedOriginalRows) = false;
[metaTable, eligibleMask, metaAudit] = ...
    BuildEqualFiveChannelMetaQuickAI(unitTable, ...
    JimCacheFolder=options.JimCacheFolder, ...
    ClayCacheFolder=options.ClayCacheFolder, ...
    CandidateMask=candidateMask, ...
    WeightingMode=options.WeightingMode, ...
    GaussianSigma=options.GaussianSigma);

auditCSV = scalarAuditTable(metaAudit);
writetable(auditCSV, fullfile(options.OutputFolder, ...
    'EqualFiveChannelMetaTuningAudit.csv'));
EqualFiveChannelMetaTuningAudit = metaAudit;
save(fullfile(options.OutputFolder, ...
    'EqualFiveChannelMetaTuningAudit.mat'), ...
    'EqualFiveChannelMetaTuningAudit', '-v7.3');

sourceRows = find(eligibleMask);
metaMatchedTable = metaTable(eligibleMask, :);
originalMatchedTable = restoreStoredAI( ...
    metaMatchedTable, unitTable, sourceRows);
reconstructedMatchedTable = buildReconstructedStimTable( ...
    originalMatchedTable, metaAudit, sourceRows);
if isempty(originalMatchedTable)
    error('FiveChannelMetaPopulation:NoEligibleSites', ...
        'No population candidate has five valid physical contacts.');
end

originalInputFile = fullfile(options.OutputFolder, ...
    'unit_table_gof_matched_original_stim_channel.mat');
reconstructedInputFile = fullfile(options.OutputFolder, ...
    'unit_table_gof_matched_reconstructed_stim_channel.mat');
metaInputFile = fullfile(options.OutputFolder, ...
    'unit_table_gof_equal_five_channel_meta.mat');
savePopulationInput(originalInputFile, originalMatchedTable, metaAudit, ...
    workbookAudit, resolvedStateFile, "Matched original stimulation channel");
savePopulationInput(reconstructedInputFile, reconstructedMatchedTable, ...
    metaAudit, workbookAudit, resolvedStateFile, ...
    "Matched raw stimulation channel using the meta AI definition");
savePopulationInput(metaInputFile, metaMatchedTable, metaAudit, ...
    workbookAudit, resolvedStateFile, ...
    metaReadout);

previousVisibility = get(groot, 'defaultFigureVisible');
visibilityCleanup = onCleanup( ...
    @() set(groot, 'defaultFigureVisible', previousVisibility));
if options.FigureVisible
    set(groot, 'defaultFigureVisible', 'on');
else
    set(groot, 'defaultFigureVisible', 'off');
end

areaResults = struct();
modelComparison = table();
perCueComparison = table();
mergedEye2DComparison = table();
populationFlow = table();
for areaIndex = 1:numel(areas)
    areaName = areas(areaIndex);
    areaFolder = fullfile(options.OutputFolder, areaName);
    originalFolder = fullfile(areaFolder, 'MatchedOriginalStimChannel');
    reconstructedFolder = fullfile(areaFolder, ...
        'MatchedRawStimChannelSameAIDefinition');
    metaFolder = fullfile(areaFolder, metaFolderName);
    ensureFolder(originalFolder);
    ensureFolder(reconstructedFolder);
    ensureFolder(metaFolder);

    original = executePopulationScript(populationScript, ...
        originalInputFile, areaName, options.Monkey);
    original = addOriginalSourceRows(original, originalMatchedTable);
    original = applyModelSpecification(original);
    original.method = ...
        "Stored stimulation-channel Quick AI with dominant eye and " + ...
        "2D/3D assignment from the five-channel meta curve";
    original = labelAndSaveResult(original, originalFolder, ...
        "MatchedOriginalStimChannel");

    reconstructed = executePopulationScript(populationScript, ...
        reconstructedInputFile, areaName, options.Monkey);
    reconstructed = addOriginalSourceRows( ...
        reconstructed, reconstructedMatchedTable);
    reconstructed = applyModelSpecification(reconstructed);
    reconstructed.method = ...
        "Stimulation channel reconstructed from raw Quick trials; " + ...
        "AI uses the four strongest matched coherence pairs; assignments " + ...
        "use the five-channel meta curve";
    reconstructed = labelAndSaveResult(reconstructed, ...
        reconstructedFolder, "MatchedRawStimSameAIDefinition");

    meta = executePopulationScript(populationScript, ...
        metaInputFile, areaName, options.Monkey);
    meta = addOriginalSourceRows(meta, metaMatchedTable);
    meta = applyModelSpecification(meta);
    if options.WeightingMode == "GaussianAll"
        meta.method = ...
            "All available live channels z-scored separately across all " + ...
            "valid Quick trials, then combined using one shared Gaussian " + ...
            "sigma=" + string(options.GaussianSigma) + ...
            "; AI uses the four strongest matched coherence pairs; " + ...
            "dominant eye and 2D/3D assignment use the matching raw-FR " + ...
            "Gaussian meta curve";
    else
        meta.method = ...
            "Five physical channels z-scored separately across all valid " + ...
            "Quick trials, then averaged trial-by-trial with weights 1/5; " + ...
            "AI uses the four strongest matched coherence pairs; dominant " + ...
            "eye and 2D/3D assignment use the five-channel meta curve";
    end
    meta = labelAndSaveResult(meta, metaFolder, ...
        metaBaseName);

    fieldName = char(areaName);
    areaResults.(fieldName) = struct( ...
        'MatchedOriginalStimChannel', original, ...
        'MatchedRawStimChannelSameAIDefinition', reconstructed, ...
        'Meta', meta);
    if options.WeightingMode == "EqualFive"
        areaResults.(fieldName).EqualFiveChannelMeta = meta;
    else
        areaResults.(fieldName).GaussianAllChannelMeta = meta;
    end
    modelComparison = [modelComparison; ...
        tagReadout(original.model_summary_table, ...
        "Matched original stimulation channel"); ...
        tagReadout(reconstructed.model_summary_table, ...
        "Matched raw stimulation channel (same AI definition)"); ...
        tagReadout(meta.model_summary_table, metaReadout)]; %#ok<AGROW>
    perCueComparison = [perCueComparison; ...
        tagReadout(original.per_cue_summary_table, ...
        "Matched original stimulation channel"); ...
        tagReadout(reconstructed.per_cue_summary_table, ...
        "Matched raw stimulation channel (same AI definition)"); ...
        tagReadout(meta.per_cue_summary_table, metaReadout)]; %#ok<AGROW>
    mergedEye2DComparison = [mergedEye2DComparison; ...
        tagReadout(original.merged_eye_2d_summary_table, ...
        "Matched original stimulation channel"); ...
        tagReadout(reconstructed.merged_eye_2d_summary_table, ...
        "Matched raw stimulation channel (same AI definition)"); ...
        tagReadout(meta.merged_eye_2d_summary_table, metaReadout)]; %#ok<AGROW>
    populationFlow = [populationFlow; buildAreaFlow( ...
        areaName, options.Monkey, candidateMask, eligibleMask, ...
        unitTable, original, reconstructed, meta)]; %#ok<AGROW>
end
clear visibilityCleanup

writetable(modelComparison, fullfile(options.OutputFolder, ...
    'PopulationModelSummary_MatchedOriginalVsFiveChannelMeta.csv'));
writetable(perCueComparison, fullfile(options.OutputFolder, ...
    'PopulationPerCueSummary_MatchedOriginalVsFiveChannelMeta.csv'));
writetable(mergedEye2DComparison, fullfile(options.OutputFolder, ...
    'PopulationMergedEye2DSummary_MatchedOriginalVsFiveChannelMeta.csv'));
writetable(populationFlow, fullfile(options.OutputFolder, ...
    'PopulationCohortFlow.csv'));

analysis = struct();
analysis.StateFile = resolvedStateFile;
analysis.OutputFolder = options.OutputFolder;
analysis.Areas = areas;
analysis.Monkey = options.Monkey;
analysis.WeightingMode = options.WeightingMode;
analysis.GaussianSigma = options.GaussianSigma;
analysis.ExcludedOriginalRows = excludedOriginalRows;
if options.WeightingMode == "GaussianAll"
    analysis.ODMethod = ...
        "Maximum-response OD from the raw-FR all-live-channel Gaussian meta curve";
    analysis.UnitTypeMethod = ...
        "Z3D-Z2D from the raw-FR all-live-channel Gaussian MonoL/MonoR meta curves using meta OD-defined dominant eye";
    analysis.CohortDefinition = ...
        "Original p_AI criterion, optional continuity row exclusion, and finite nonzero Gaussian-meta OD/Z3D-Z2D";
    analysis.MetaTuningDefinition = ...
        "Per-channel z-score across all valid Quick trials; all available live channels combined with a session-invariant Gaussian distance profile; AI over four strongest matched coherence pairs";
else
    analysis.ODMethod = ...
        "Maximum-response OD from the equal-weight raw-FR five-channel meta tuning curve";
    analysis.UnitTypeMethod = ...
        "Z3D-Z2D from the equal-weight raw-FR five-channel MonoL/MonoR meta tuning curves using the meta OD-defined dominant eye";
    analysis.CohortDefinition = ...
        "Original p_AI criterion plus five required live physical contacts at relative positions -2:-1:2 and finite nonzero meta OD/Z3D-Z2D";
    analysis.MetaTuningDefinition = ...
        "Per-channel z-score across all valid Quick trials; complete-case trial-level mean across five channels with fixed weight 1/5; AI over four strongest matched coherence pairs";
end
analysis.ModelSpecification = [ ...
    "2D: DeltaBias ~ AI for each cue"; ...
    "2D: MergedEyeDeltaBias ~ AI + AI:OD for merged eyes"; ...
    "3D: DeltaBias ~ AI for each cue only"];
analysis.CandidateMask = candidateMask;
analysis.EligibleMask = eligibleMask;
analysis.SourceRows = sourceRows;
analysis.MetaAudit = metaAudit;
analysis.WorkbookAudit = workbookAudit;
analysis.OriginalInputFile = originalInputFile;
analysis.ReconstructedStimInputFile = reconstructedInputFile;
analysis.MetaInputFile = metaInputFile;
analysis.AreaResults = areaResults;
analysis.ModelSummaryComparison = modelComparison;
analysis.PerCueSummaryComparison = perCueComparison;
analysis.MergedEye2DSummaryComparison = mergedEye2DComparison;
analysis.PopulationCohortFlow = populationFlow;
population_analysis = analysis;
save(fullfile(options.OutputFolder, ...
    'EqualFiveChannelMetaPopulationResults.mat'), ...
    'population_analysis', '-v7.3');

fprintf(['Completed equal-weight five-channel z-scored meta-tuning ' ...
    'population analysis. Eligible candidates: %d/%d. Outputs: %s\n'], ...
    nnz(eligibleMask), nnz(candidateMask), options.OutputFolder);
end


function output = restoreStoredAI(metaAssignedTable, sourceTable, sourceRows)
output = metaAssignedTable;
for row = 1:height(output)
    output.AI{row} = sourceTable.AI{sourceRows(row)};
end
end


function output = buildReconstructedStimTable(input, audit, sourceRows)
output = input;
for row = 1:height(output)
    sourceRow = sourceRows(row);
    stimChannel = output.StimElec(row);
    reconstructedAI = audit.ReconstructedStimAI{sourceRow};
    aiValues = output.AI{row};
    if numel(reconstructedAI) < 4 || size(aiValues, 1) < 4 || ...
            stimChannel < 1 || stimChannel > size(aiValues, 2)
        error('FiveChannelMetaPopulation:InvalidReconstructedStimAI', ...
            'Cannot install reconstructed stimulation AI for source row %d.', ...
            sourceRow);
    end
    aiValues(1:4, stimChannel) = reconstructedAI(1:4);
    output.AI{row} = aiValues;
end
end


function mask = populationCandidateMask(unitTable, areas, monkey)
required = ["ROI", "Monkey", "p_AI"];
missing = setdiff(required, string(unitTable.Properties.VariableNames));
if ~isempty(missing)
    error('FiveChannelMetaPopulation:MissingSelectionVariables', ...
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
    mask(row) = numel(pValues) >= 3 && isfinite(pValues(2)) && ...
        isfinite(pValues(3)) && pValues(2) < 0.05 && ...
        pValues(3) < 0.05;
end
end


function savePopulationInput(fileName, inputTable, metaAudit, ...
    workbookAudit, sourceFile, readout)
unit_table_gof = inputTable;
EqualFiveChannelMetaTuningAudit = metaAudit;
EqualFiveChannelMetaSourceFile = sourceFile;
EqualFiveChannelMetaReadout = readout;
save(fileName, 'unit_table_gof', 'EqualFiveChannelMetaTuningAudit', ...
    'workbookAudit', 'EqualFiveChannelMetaSourceFile', ...
    'EqualFiveChannelMetaReadout', '-v7.3');
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


function result = addOriginalSourceRows(result, matchedTable)
if isempty(result.bias_table)
    result.bias_table.OriginalSourceTableRow = zeros(0, 1);
    return
end
indices = result.bias_table.UnitIndex;
valid = indices >= 1 & indices <= height(matchedTable) & ...
    indices == fix(indices);
source = nan(height(result.bias_table), 1);
source(valid) = matchedTable.MetaSourceTableRow(indices(valid));
result.bias_table.OriginalSourceTableRow = source;
end


function result = applyModelSpecification(result)
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


function result = labelAndSaveResult(result, outputFolder, baseName)
labelFigure(result.fig_2d, baseName + " | " + result.area + " " + ...
    result.monkey + " 2D neurons");
labelFigure(result.fig_3d, baseName + " | " + result.area + " " + ...
    result.monkey + " 3D neurons");
figureFiles = struct();
figureFiles.TwoD = saveFigureSet(result.fig_2d, outputFolder, ...
    baseName + "_" + result.area + "_" + result.monkey + "_2D");
figureFiles.ThreeD = saveFigureSet(result.fig_3d, outputFolder, ...
    baseName + "_" + result.area + "_" + result.monkey + "_3D");
result.figure_files = figureFiles;
writetable(result.per_cue_summary_table, fullfile(outputFolder, ...
    'PopulationPerCueSummary.csv'));
writetable(result.merged_eye_2d_summary_table, fullfile(outputFolder, ...
    'PopulationMergedEye2DSummary.csv'));
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


function labelFigure(figureHandle, label)
if isempty(figureHandle) || ~isgraphics(figureHandle, 'figure')
    return
end
figureHandle.Name = char(label);
axesHandles = findobj(figureHandle, 'Type', 'axes');
if ~isempty(axesHandles)
    title(axesHandles(1), label, 'Interpreter', 'none', 'FontSize', 14);
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


function output = tagReadout(input, readout)
output = input;
output.Readout = repmat(readout, height(output), 1);
output = movevars(output, 'Readout', 'Before', 1);
end


function output = buildAreaFlow(area, monkey, candidateMask, ...
    eligibleMask, unitTable, original, reconstructed, meta)
areaRows = strcmpi(string(unitTable.ROI), area);
if monkey ~= "Both"
    areaRows = areaRows & strcmpi(string(unitTable.Monkey), monkey);
end
Area = area;
MonkeySelection = monkey;
CandidateSites = nnz(areaRows & candidateMask);
FiveChannelEligibleSites = nnz(areaRows & eligibleMask);
FiveChannelIneligibleSites = CandidateSites - FiveChannelEligibleSites;
MatchedOriginalPopulationSites = ...
    numel(unique(original.bias_table.OriginalSourceTableRow));
MatchedRawStimPopulationSites = ...
    numel(unique(reconstructed.bias_table.OriginalSourceTableRow));
MetaPopulationSites = ...
    numel(unique(meta.bias_table.OriginalSourceTableRow));
MatchedOriginal2DSites = uniqueUnitCount(original.bias_table, "2D");
MatchedOriginal3DSites = uniqueUnitCount(original.bias_table, "3D");
Meta2DSites = uniqueUnitCount(meta.bias_table, "2D");
Meta3DSites = uniqueUnitCount(meta.bias_table, "3D");
output = table(Area, MonkeySelection, CandidateSites, ...
    FiveChannelEligibleSites, FiveChannelIneligibleSites, ...
    MatchedOriginalPopulationSites, MatchedRawStimPopulationSites, ...
    MetaPopulationSites, ...
    MatchedOriginal2DSites, MatchedOriginal3DSites, ...
    Meta2DSites, Meta3DSites);
end


function count = uniqueUnitCount(biasTable, unitType)
selected = strcmp(string(biasTable.UnitType), unitType);
count = numel(unique(biasTable.OriginalSourceTableRow(selected)));
end


function output = scalarAuditTable(audit)
output = audit(:, {'SourceTableRow', 'Monkey', 'Date', 'ROI', ...
    'CandidateForPopulation', 'StimChannel', 'StimProbePosition', ...
    'Minus2Channel', 'Minus1Channel', 'Plus1Channel', 'Plus2Channel', ...
    'MaxAbsStimAIReconstructionError', 'CacheFile', 'Status', ...
    'Message', 'Eligible'});
output.StoredCombinedAI = cueCellValue(audit.StoredStimAI, 1);
output.StoredMonoLAI = cueCellValue(audit.StoredStimAI, 2);
output.StoredMonoRAI = cueCellValue(audit.StoredStimAI, 3);
output.StoredStereoAI = cueCellValue(audit.StoredStimAI, 4);
output.ReconstructedCombinedAI = ...
    cueCellValue(audit.ReconstructedStimAI, 1);
output.ReconstructedMonoLAI = ...
    cueCellValue(audit.ReconstructedStimAI, 2);
output.ReconstructedMonoRAI = ...
    cueCellValue(audit.ReconstructedStimAI, 3);
output.ReconstructedStereoAI = ...
    cueCellValue(audit.ReconstructedStimAI, 4);
output.MetaCombinedAI = cueCellValue(audit.MetaAI, 1);
output.MetaMonoLAI = cueCellValue(audit.MetaAI, 2);
output.MetaMonoRAI = cueCellValue(audit.MetaAI, 3);
output.MetaStereoAI = cueCellValue(audit.MetaAI, 4);
output.OriginalODMax = audit.OriginalODMax;
output.MetaODMax = audit.MetaODMax;
output.DominantEyeChanged = audit.DominantEyeChanged;
output.OriginalZ3DMinusZ2D = audit.OriginalZ3DMinusZ2D;
output.MetaZ2D = audit.MetaZ2D;
output.MetaZ3D = audit.MetaZ3D;
output.MetaZ3DMinusZ2D = audit.MetaZ3DMinusZ2D;
output.MetaPairedCoherenceCount = audit.MetaPairedCoherenceCount;
output.UnitTypeChanged = audit.UnitTypeChanged;
for index = 1:5
    output.(sprintf('Channel%dZCenter', index)) = ...
        indexedCellValue(audit.ChannelZCenter, index);
    output.(sprintf('Channel%dZScale', index)) = ...
        indexedCellValue(audit.ChannelZScale, index);
    output.(sprintf('Channel%dObservationCount', index)) = ...
        indexedCellValue(audit.ChannelObservationCount, index);
end
end


function values = cueCellValue(column, cue)
values = indexedCellValue(column, cue);
end


function values = indexedCellValue(column, index)
values = nan(numel(column), 1);
for row = 1:numel(column)
    value = column{row};
    if isnumeric(value) && numel(value) >= index
        values(row) = double(value(index));
    end
end
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

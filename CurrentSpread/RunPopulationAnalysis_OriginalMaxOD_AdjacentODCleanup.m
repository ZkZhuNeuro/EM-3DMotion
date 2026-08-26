function analysis = ...
    RunPopulationAnalysis_OriginalMaxOD_AdjacentODCleanup(options)
%RUNPOPULATIONANALYSIS_ORIGINALMAXOD_ADJACENTODCLEANUP
% Apply a 3- or 5-contact OD-sign continuity mask to the cached original
% Max-OD population and immediately regenerate MT/FST results.

arguments
    options.NeighborRadius (1, 1) double ...
        {mustBeInteger, mustBeMember(options.NeighborRadius, [1, 2])} = 1
    options.ODAuditFile (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\AdjacentODContinuity\" + ...
        "AdjacentODContinuityComparison.mat"
    options.OutputFolder (1, 1) string = ""
    options.StateFile (1, 1) string = ...
        "C:\EM\PopulationAnalysis\unit_table_gof.mat"
    options.CacheFile (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\PopulationQuickAccess\" + ...
        "OriginalMaxOD_PreparedPopulation.mat"
    options.FigureVisible (1, 1) logical = false
    options.ForceRebuildCache (1, 1) logical = false
end

if ~isfile(options.ODAuditFile)
    RunAdjacentODContinuityComparison(StateFile=options.StateFile);
end
loaded = load(options.ODAuditFile, 'OD_continuity_analysis');
if ~isfield(loaded, 'OD_continuity_analysis')
    error('AdjacentODPopulation:MissingAudit', ...
        'OD audit MAT file does not contain OD_continuity_analysis.');
end
odAnalysis = loaded.OD_continuity_analysis;
if options.NeighborRadius == 1
    audit = odAnalysis.Audit3Channels;
    channelCount = 3;
else
    audit = odAnalysis.Audit5Channels;
    channelCount = 5;
end

exclude = audit.Status == "Success" & audit.ExcludeForODFlip & ...
    audit.PopulationCandidate;
excludedRows = audit.TableRow(exclude);
if strlength(options.OutputFolder) == 0
    outputFolder = "C:\EM\StimTuningAnalysis\AdjacentODContinuity\" + ...
        "Population_" + channelCount + "Channels_OriginalMaxOD";
else
    outputFolder = options.OutputFolder;
end
analysisName = "Original Max OD: " + channelCount + ...
    "-channel OD-continuous";
population = RunCachedPopulationExclusion( ...
    analysisName, excludedRows, StateFile=options.StateFile, ...
    CacheFile=options.CacheFile, OutputFolder=outputFolder, ...
    FigureVisible=options.FigureVisible, ...
    ForceRebuildCache=options.ForceRebuildCache);

writetable(audit, fullfile(outputFolder, ...
    sprintf('AdjacentODContinuity_%dChannels_Audit.csv', channelCount)));
writetable(audit(exclude, :), fullfile(outputFolder, ...
    sprintf('AdjacentODContinuity_%dChannels_ExcludedSessions.csv', ...
    channelCount)));

analysis = population;
analysis.NeighborRadius = options.NeighborRadius;
analysis.ChannelCount = channelCount;
analysis.ODContinuityRule = odAnalysis.Rule;
analysis.ODAudit = audit;
analysis.ExcludedPopulationRows = excludedRows;
population_analysis = analysis;
save(fullfile(outputFolder, ...
    sprintf('OriginalMaxOD_ODContinuity_%dChannels_Results.mat', ...
    channelCount)), 'population_analysis', '-v7.3');
end

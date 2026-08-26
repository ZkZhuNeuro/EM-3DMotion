function results = ...
    RunPopulationAnalysis_CorrelationWithin200um_ODComparison(options)
%RUNPOPULATIONANALYSIS_CORRELATIONWITHIN200UM_ODCOMPARISON Compare Max/LSQ OD.
%
% Runs correlation-only selected-channel population analyses for MT and
% FST with a four-contact (200 um) channel-selection window. Both
% maximum-response and LSQ OD definitions are evaluated. OD sign assigns
% the eye; only absolute OD enters population models and plots.

arguments
    options.StateFile (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\unit_table_stim.mat"
    options.OutputRoot (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\BestCorrelationChannelPopulation_Within200um_ODComparison"
    options.Monkey (1, 1) string ...
        {mustBeMember(options.Monkey, ["Both", "Jim", "Clay"])} = "Both"
    options.MakeRankingPlots (1, 1) logical = false
    options.FigureVisible (1, 1) logical = false
    options.JimCacheFolder (1, 1) string = "C:\Jim\StimData"
    options.ClayCacheFolder (1, 1) string = "C:\Clay\StimData"
end

maxAbsRelativePosition = 4;
contactSpacingMicrometers = 50;
areas = ["MT", "FST"];
odMethods = ["Max", "LSQ"];

if ~isfolder(options.OutputRoot)
    mkdir(options.OutputRoot);
end
source = load(options.StateFile, 'unit_table_stim');
if ~isfield(source, 'unit_table_stim') || ...
        ~istable(source.unit_table_stim)
    error('BestQuickPopulation:MissingStimTable', ...
        '%s does not contain unit_table_stim.', options.StateFile);
end
sourceTable = source.unit_table_stim;

results = struct();
populationSummaryParts = cell(numel(odMethods) .* numel(areas), 1);
interactionSummaryParts = cell(size(populationSummaryParts));
runSummaryParts = cell(size(populationSummaryParts));
writeIndex = 0;

for methodIndex = 1:numel(odMethods)
    odMethod = odMethods(methodIndex);
    for areaIndex = 1:numel(areas)
        area = areas(areaIndex);
        writeIndex = writeIndex + 1;
        outputFolder = fullfile(options.OutputRoot, odMethod, area);
        analysis = RunPopulationAnalysis_BestQuickChannels( ...
            StateFile=options.StateFile, OutputFolder=outputFolder, ...
            Area=area, Monkey=options.Monkey, ODMethod=odMethod, ...
            MaxAbsRelativePosition=maxAbsRelativePosition, ...
            MakeRankingPlots=options.MakeRankingPlots, ...
            FigureVisible=options.FigureVisible, ...
            JimCacheFolder=options.JimCacheFolder, ...
            ClayCacheFolder=options.ClayCacheFolder);
        results.(odMethod).(area) = analysis;

        populationSummaryParts{writeIndex} = addRunColumns( ...
            analysis.Correlation.summary_table, odMethod, area);
        interactionSummaryParts{writeIndex} = addRunColumns( ...
            analysis.Correlation.aixod_summary_table, odMethod, area);
        runSummaryParts{writeIndex} = buildRunSummary( ...
            sourceTable, analysis, odMethod, area, ...
            maxAbsRelativePosition, contactSpacingMicrometers);
    end
end

results.PopulationSummary = vertcat(populationSummaryParts{:});
results.AIxODSummary = vertcat(interactionSummaryParts{:});
results.RunSummary = vertcat(runSummaryParts{:});
results.MaxAbsRelativePosition = maxAbsRelativePosition;
results.ContactSpacingMicrometers = contactSpacingMicrometers;
results.MaxDistanceMicrometers = ...
    maxAbsRelativePosition .* contactSpacingMicrometers;
results.ODModelConvention = ...
    "Sign assigns eye; models and plots use absolute OD magnitude";

writetable(results.PopulationSummary, fullfile(options.OutputRoot, ...
    'PopulationSummary_Max_vs_LSQ_MT_FST.csv'));
writetable(results.AIxODSummary, fullfile(options.OutputRoot, ...
    'AIxODSummary_Max_vs_LSQ_MT_FST.csv'));
writetable(results.RunSummary, fullfile(options.OutputRoot, ...
    'RunSummary_Max_vs_LSQ_MT_FST.csv'));
comparison_results = results;
save(fullfile(options.OutputRoot, 'Max_vs_LSQ_MT_FST_Results.mat'), ...
    'comparison_results', '-v7.3');
end


function output = addRunColumns(input, odMethod, requestedArea)
output = input;
output.ODMethod = repmat(odMethod, height(output), 1);
output.RequestedArea = repmat(requestedArea, height(output), 1);
output = movevars(output, {'ODMethod', 'RequestedArea'}, 'Before', 1);
end


function summary = buildRunSummary(sourceTable, analysis, odMethod, ...
    area, maxAbsRelativePosition, contactSpacingMicrometers)
selection = analysis.CorrelationSelectionSummary;
selectionRows = selection.UnitTableRow;
selectionArea = string(sourceTable.ROI(selectionRows));
areaSelection = selectionArea == area & selection.Status == "Success";

criteria = analysis.CorrelationSelectionCriteriaAudit;
criteriaRows = criteria.ArtifactTableRow;
criteriaArea = string(sourceTable.ROI(criteriaRows));
validNeural = criteriaArea == area & criteria.Status == "Success" & ...
    criteria.BestChannelTuningGatePass;
zValue = criteria.BestZ3DMinusZ2D;

interaction = analysis.Correlation.aixod_summary_table;
unitType = string(interaction.UnitType);
model2DUnits = valueForUnitType(interaction.NUnits, unitType, "2D");
model3DUnits = valueForUnitType(interaction.NUnits, unitType, "3D");

ODMethod = odMethod;
Area = area;
MaxAbsRelativePosition = maxAbsRelativePosition;
MaxDistanceMicrometers = ...
    maxAbsRelativePosition .* contactSpacingMicrometers;
AreaSessionCount = nnz(selectionArea == area);
SuccessfulSelectionCount = nnz(areaSelection);
SelectionChangedByThresholdCount = nnz(areaSelection & ...
    selection.SelectionChangedByDistanceThreshold);
BoundaryWinnerCount = nnz(areaSelection & ...
    selection.BestAtDistanceBoundary);
MedianAbsoluteBestDistanceMicrometers = median(abs( ...
    selection.BestDistanceToStimMicrometers(areaSelection)), 'omitnan');
MedianCorrelationPenalty = median( ...
    selection.UnconstrainedBestPearsonR(areaSelection) - ...
    selection.BestPearsonR(areaSelection), 'omitnan');
Neural2DCount = nnz(validNeural & zValue < 0);
Neural3DCount = nnz(validNeural & zValue > 0);
Model2DUnits = model2DUnits;
Model3DUnits = model3DUnits;

summary = table(ODMethod, Area, MaxAbsRelativePosition, ...
    MaxDistanceMicrometers, AreaSessionCount, ...
    SuccessfulSelectionCount, SelectionChangedByThresholdCount, ...
    BoundaryWinnerCount, MedianAbsoluteBestDistanceMicrometers, ...
    MedianCorrelationPenalty, Neural2DCount, Neural3DCount, ...
    Model2DUnits, Model3DUnits);
end


function value = valueForUnitType(values, unitTypes, requestedType)
row = find(unitTypes == requestedType, 1);
if isempty(row)
    value = 0;
else
    value = values(row);
end
end

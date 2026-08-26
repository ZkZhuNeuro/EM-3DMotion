function analysis = RunAdjacentODContinuityComparison(options)
%RUNADJACENTODCONTINUITYCOMPARISON Compare 3- and 5-contact OD cleanup.

arguments
    options.StateFile (1, 1) string = ...
        "C:\EM\PopulationAnalysis\unit_table_gof.mat"
    options.OutputFolder (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\AdjacentODContinuity"
    options.Areas (1, :) string = ["MT", "FST"]
    options.Monkey (1, 1) string ...
        {mustBeMember(options.Monkey, ["Both", "Jim", "Clay"])} = "Both"
end

scriptFolder = string(fileparts(mfilename('fullpath')));
projectFolder = string(fileparts(scriptFolder));
addpath(scriptFolder, fullfile(projectFolder, 'PopulationAnalysis'));
[unitTable, resolvedStateFile, workbookAudit] = ...
    LoadLatestUnitTableGof(options.StateFile);
populationCandidate = populationCandidateMask( ...
    unitTable, options.Areas, options.Monkey);

audit3 = AuditAdjacentQuickChannelODFlips(unitTable, NeighborRadius=1);
audit5 = AuditAdjacentQuickChannelODFlips(unitTable, NeighborRadius=2);
audit3.PopulationCandidate = populationCandidate;
audit5.PopulationCandidate = populationCandidate;

exclude3 = audit3.Status == "Success" & audit3.ExcludeForODFlip;
exclude5 = audit5.Status == "Success" & audit5.ExcludeForODFlip;
populationExclude3 = exclude3 & populationCandidate;
populationExclude5 = exclude5 & populationCandidate;

comparison = [summarizeCriterion( ...
    "3 channels (stim + 1 each side)", audit3, populationCandidate); ...
    summarizeCriterion( ...
    "5 channels (stim + 2 each side)", audit5, populationCandidate)];
comparison.IncrementalExcludedVs3Channels = [0; ...
    nnz(populationExclude5 & ~populationExclude3)];

breakdown = buildBreakdown(audit3, audit5, populationCandidate);

if ~isfolder(options.OutputFolder)
    mkdir(options.OutputFolder);
end
writetable(comparison, fullfile(options.OutputFolder, ...
    'AdjacentODContinuity_CountComparison.csv'));
writetable(breakdown, fullfile(options.OutputFolder, ...
    'AdjacentODContinuity_CountsByAreaMonkey.csv'));
writetable(audit3, fullfile(options.OutputFolder, ...
    'AdjacentODContinuity_3Channels_Audit.csv'));
writetable(audit5, fullfile(options.OutputFolder, ...
    'AdjacentODContinuity_5Channels_Audit.csv'));
writetable(audit3(populationExclude3, :), ...
    fullfile(options.OutputFolder, ...
    'AdjacentODContinuity_3Channels_ExcludedPopulationSessions.csv'));
writetable(audit5(populationExclude5, :), ...
    fullfile(options.OutputFolder, ...
    'AdjacentODContinuity_5Channels_ExcludedPopulationSessions.csv'));

analysis = struct();
analysis.StateFile = resolvedStateFile;
analysis.OutputFolder = options.OutputFolder;
analysis.Rule = [ ...
    "Exclude when any evaluated live physical neighbor has nonzero " + ...
    "OD_max_all opposite in sign to the stimulation contact"; ...
    "Dead, unavailable, outside-probe, zero-OD, and nonfinite-OD contacts do not trigger exclusion"];
analysis.PopulationCandidateMask = populationCandidate;
analysis.Audit3Channels = audit3;
analysis.Audit5Channels = audit5;
analysis.Comparison = comparison;
analysis.Breakdown = breakdown;
analysis.WorkbookAudit = workbookAudit;
OD_continuity_analysis = analysis;
save(fullfile(options.OutputFolder, ...
    'AdjacentODContinuityComparison.mat'), ...
    'OD_continuity_analysis', '-v7.3');

disp(comparison)
fprintf('OD continuity comparison saved to %s\n', options.OutputFolder);
end


function output = summarizeCriterion(name, audit, populationCandidate)
success = audit.Status == "Success";
excluded = success & audit.ExcludeForODFlip;
populationSuccess = success & populationCandidate;
populationExcluded = excluded & populationCandidate;
output = table(name, audit.NeighborRadius(1), ...
    2 * audit.NeighborRadius(1), nnz(success), ...
    nnz(success & audit.AllRequestedNeighborsEvaluated), nnz(excluded), ...
    nnz(populationCandidate), nnz(populationSuccess), ...
    nnz(populationSuccess & audit.AllRequestedNeighborsEvaluated), ...
    nnz(populationExcluded), nnz(populationCandidate & ~excluded), ...
    'VariableNames', {'Neighborhood', 'NeighborRadius', ...
    'RequestedAdjacentContacts', 'SuccessfulAuditSessions', ...
    'CompleteNeighborhoodSessions', 'ExcludedAllSessions', ...
    'PopulationCandidateSessions', 'SuccessfulPopulationAuditSessions', ...
    'CompletePopulationNeighborhoodSessions', ...
    'ExcludedPopulationSessions', 'RemainingPopulationSessions'});
end


function output = buildBreakdown(audit3, audit5, populationCandidate)
groups = ["All"; "MT"; "FST"; "Jim"; "Clay"];
output = table();
for groupIndex = 1:numel(groups)
    group = groups(groupIndex);
    switch group
        case "All"
            groupMask = true(height(audit3), 1);
        case {"MT", "FST"}
            groupMask = strcmpi(audit3.ROI, group);
        otherwise
            groupMask = strcmpi(audit3.Monkey, group);
    end
    candidate = populationCandidate & groupMask;
    for radius = 1:2
        if radius == 1
            audit = audit3;
            neighborhood = "3 channels";
        else
            audit = audit5;
            neighborhood = "5 channels";
        end
        success = audit.Status == "Success";
        excluded = candidate & success & audit.ExcludeForODFlip;
        row = table(group, neighborhood, nnz(candidate), nnz(excluded), ...
            nnz(candidate & ~excluded), ...
            'VariableNames', {'Group', 'Neighborhood', ...
            'PopulationCandidateSessions', 'ExcludedPopulationSessions', ...
            'RemainingPopulationSessions'});
        output = [output; row]; %#ok<AGROW>
    end
end
end


function mask = populationCandidateMask(unitTable, areas, monkey)
areas = upper(string(areas));
required = ["ROI", "Monkey", "p_AI", "Z3D_v_Z2D"];
missing = setdiff(required, string(unitTable.Properties.VariableNames));
if ~isempty(missing)
    error('AdjacentODContinuity:MissingSelectionVariables', ...
        'Missing population-selection variable(s): %s.', join(missing, ', '));
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
    pValues = numericArray(unitTable.p_AI, row);
    zValue = numericArray(unitTable.Z3D_v_Z2D, row);
    mask(row) = numel(pValues) >= 3 && all(isfinite(pValues(2:3))) && ...
        all(pValues(2:3) < 0.05) && isscalar(zValue) && ...
        isfinite(zValue) && zValue ~= 0;
end
end


function value = numericArray(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
while iscell(value) && isscalar(value)
    value = value{1};
end
value = double(value);
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
end

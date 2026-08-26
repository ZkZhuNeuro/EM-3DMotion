function analysis = ...
    RunPopulationAnalysis_OriginalMaxOD_ODPlusAdjacentAICleanup(options)
%RUNPOPULATIONANALYSIS_ORIGINALMAXOD_ODPLUSADJACENTAICLEANUP
% Combine local OD continuity and adjacent combined-cue AI continuity.
%
% A population candidate is removed when either:
%   1. it is a 2D site and OD_max reverses sign at an evaluated live
%      contact within the requested OD radius; or
%   2. a significant (raw p < alpha) combined-cue tuning curve within the
%      requested AI radius has nonzero AI opposite to the stimulation AI.
% Neighboring OD reversals are retained and audited for 3D sites.
%
% The resulting row union is passed to RunCachedPopulationExclusion, so
% the original Max-OD population data do not need to be rebuilt.

arguments
    options.ODNeighborRadius (1, 1) double ...
        {mustBeInteger, mustBeMember(options.ODNeighborRadius, [1, 2])} = 1
    options.AINeighborRadius (1, 1) double ...
        {mustBeInteger, mustBeMember(options.AINeighborRadius, [1, 2])} = 2
    options.TuningAlpha (1, 1) double ...
        {mustBeGreaterThan(options.TuningAlpha, 0), ...
        mustBeLessThan(options.TuningAlpha, 1)} = 0.05
    options.ODAuditFile (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\AdjacentODContinuity\" + ...
        "AdjacentODContinuityComparison.mat"
    options.AIAuditFile (1, 1) string = ...
        "C:\EM\StimTuningAnalysis\" + ...
        "OriginalMaxOD_Adjacent2EachSide_CombinedAIConsistency_" + ...
        "UnitTypeModels\OriginalMaxOD_AdjacentAICleanupResults.mat"
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
loadedOD = load(options.ODAuditFile, 'OD_continuity_analysis');
if ~isfield(loadedOD, 'OD_continuity_analysis')
    error('ODPlusAdjacentAI:MissingODAudit', ...
        'OD audit MAT file does not contain OD_continuity_analysis.');
end
odAnalysis = loadedOD.OD_continuity_analysis;
if options.ODNeighborRadius == 1
    odAudit = odAnalysis.Audit3Channels;
    odChannelCount = 3;
else
    odAudit = odAnalysis.Audit5Channels;
    odChannelCount = 5;
end

if ~isfile(options.AIAuditFile)
    error('ODPlusAdjacentAI:MissingAIAudit', ...
        'Adjacent combined-cue AI audit does not exist: %s', ...
        options.AIAuditFile);
end
loadedAI = load(options.AIAuditFile, 'population_analysis');
if ~isfield(loadedAI, 'population_analysis') || ...
        ~isfield(loadedAI.population_analysis, 'AdjacentChannelAudit')
    error('ODPlusAdjacentAI:InvalidAIAudit', ...
        ['AI audit MAT file must contain population_analysis.' ...
        'AdjacentChannelAudit.']);
end
aiAnalysis = loadedAI.population_analysis;
aiAudit = aiAnalysis.AdjacentChannelAudit;
if aiAnalysis.NeighborRadius ~= options.AINeighborRadius || ...
        abs(aiAnalysis.TuningAlpha - options.TuningAlpha) > 1e-12
    error('ODPlusAdjacentAI:AIAuditSettingsMismatch', ...
        ['Saved AI audit used radius %g and alpha %.6g; requested radius ' ...
        '%g and alpha %.6g.'], aiAnalysis.NeighborRadius, ...
        aiAnalysis.TuningAlpha, options.AINeighborRadius, ...
        options.TuningAlpha);
end

validateAlignedAudits(odAudit, aiAudit);
odCandidate = logical(odAudit.PopulationCandidate);
aiCandidate = logical(aiAudit.CandidateForPopulation);
if ~isequal(odCandidate, aiCandidate)
    error('ODPlusAdjacentAI:CandidateMismatch', ...
        'OD and AI audits do not identify the same population candidates.');
end

unitType = loadUnitType(options.CacheFile, options.StateFile, ...
    odAudit.TableRow);
odFlipObserved = odCandidate & odAudit.Status == "Success" & ...
    odAudit.ExcludeForODFlip;
odFail = odFlipObserved & unitType == "2D";
odFlipIgnoredFor3D = odFlipObserved & unitType == "3D";
aiFail = aiCandidate & aiAudit.Status == "Success" & ...
    aiAudit.ExcludeForAIFlip;
bothFail = odFail & aiFail;
eitherFail = odFail | aiFail;
excludedRows = odAudit.TableRow(eitherFail);

if strlength(options.OutputFolder) == 0
    outputFolder = "C:\EM\StimTuningAnalysis\AdjacentODContinuity\" + ...
        "Population_" + odChannelCount + ...
        "Channels_2DOnlyODPlusAdjacent4AI_OriginalMaxOD";
else
    outputFolder = options.OutputFolder;
end
analysisName = "Original Max OD: 2D-only " + odChannelCount + ...
    "-channel OD + adjacent-4 AI continuous";
population = RunCachedPopulationExclusion( ...
    analysisName, excludedRows, StateFile=options.StateFile, ...
    CacheFile=options.CacheFile, OutputFolder=outputFolder, ...
    FigureVisible=options.FigureVisible, ...
    ForceRebuildCache=options.ForceRebuildCache);

criterionAudit = table(odAudit.TableRow, odAudit.Date, ...
    string(odAudit.Monkey), string(odAudit.ROI), unitType, odCandidate, ...
    odFlipObserved, odFail, odFlipIgnoredFor3D, aiFail, bothFail, ...
    eitherFail, ...
    'VariableNames', {'TableRow', 'Date', 'Monkey', 'ROI', ...
    'UnitType', 'PopulationCandidate', 'ODFlipObserved', ...
    'ODContinuityFail', 'ODFlipIgnoredFor3D', ...
    'AdjacentCombinedAIFail', 'FailedBoth', 'ExcludedByUnion'});
counts = table(nnz(odCandidate), nnz(odFlipObserved), nnz(odFail), ...
    nnz(odFlipIgnoredFor3D), nnz(aiFail), ...
    nnz(bothFail), nnz(odFail & ~aiFail), nnz(aiFail & ~odFail), ...
    nnz(eitherFail), nnz(odCandidate & ~eitherFail), ...
    'VariableNames', {'PopulationCandidates', 'ODFlipsObserved', ...
    'ODContinuityExcluded2D', 'ODFlipsIgnored3D', ...
    'AdjacentCombinedAIExcluded', 'ExcludedByBoth', ...
    'ODOnlyExcluded', 'AIOnlyExcluded', 'UnionExcluded', ...
    'RemainingPopulationCandidates'});
writetable(criterionAudit, fullfile(outputFolder, ...
    'CombinedExclusionAudit.csv'));
writetable(criterionAudit(eitherFail, :), fullfile(outputFolder, ...
    'CombinedExcludedPopulationSessions.csv'));
writetable(counts, fullfile(outputFolder, ...
    'CombinedExclusionCounts.csv'));
writetable(odAudit, fullfile(outputFolder, ...
    sprintf('AdjacentODContinuity_%dChannels_Audit.csv', odChannelCount)));
writetable(aiAudit, fullfile(outputFolder, ...
    'Adjacent4ChannelCombinedAIAudit.csv'));

analysis = population;
analysis.ODNeighborRadius = options.ODNeighborRadius;
analysis.ODChannelCount = odChannelCount;
analysis.AINeighborRadius = options.AINeighborRadius;
analysis.TuningAlpha = options.TuningAlpha;
analysis.ODContinuityAppliesTo = "2D sites only";
analysis.ODContinuityRule = odAnalysis.Rule;
analysis.AdjacentCombinedAIRule = aiAnalysis.ExclusionRule;
analysis.ODAudit = odAudit;
analysis.AdjacentCombinedAIAudit = aiAudit;
analysis.CombinedExclusionAudit = criterionAudit;
analysis.CombinedExclusionCounts = counts;
analysis.ExcludedPopulationRows = excludedRows;
population_analysis = analysis;
save(fullfile(outputFolder, ...
    'OriginalMaxOD_ODPlusAdjacentAI_Results.mat'), ...
    'population_analysis', '-v7.3');
end


function unitType = loadUnitType(cacheFile, stateFile, sourceRows)
if isfile(cacheFile)
    loaded = load(cacheFile, 'preparedPopulationTable');
else
    loaded = struct();
end
if isfield(loaded, 'preparedPopulationTable')
    sourceTable = loaded.preparedPopulationTable;
else
    [sourceTable, ~, ~] = LoadLatestUnitTableGof(stateFile);
    sourceTable.SourceTableRow = (1:height(sourceTable))';
end
required = ["SourceTableRow", "Z3D_v_Z2D"];
missing = setdiff(required, string(sourceTable.Properties.VariableNames));
if ~isempty(missing)
    error('ODPlusAdjacentAI:MissingUnitTypeVariables', ...
        'Unit-type source is missing: %s.', join(missing, ', '));
end
[found, location] = ismember(double(sourceRows), ...
    double(sourceTable.SourceTableRow));
if ~all(found)
    error('ODPlusAdjacentAI:MissingUnitTypeRows', ...
        'Unit type is unavailable for one or more audit rows.');
end
unitType = repmat("Unknown", numel(sourceRows), 1);
for index = 1:numel(sourceRows)
    zValue = numericScalar(sourceTable.Z3D_v_Z2D, location(index));
    if isfinite(zValue) && zValue < 0
        unitType(index) = "2D";
    elseif isfinite(zValue) && zValue > 0
        unitType(index) = "3D";
    end
end
end


function value = numericScalar(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
while iscell(value) && isscalar(value)
    value = value{1};
end
if ~isnumeric(value) || ~isscalar(value)
    error('ODPlusAdjacentAI:ExpectedNumericScalar', ...
        'Expected a numeric scalar at row %d.', row);
end
value = double(value);
end


function validateAlignedAudits(odAudit, aiAudit)
if height(odAudit) ~= height(aiAudit) || ...
        ~isequal(double(odAudit.TableRow), double(aiAudit.TableRow))
    error('ODPlusAdjacentAI:RowMismatch', ...
        'OD and AI audits do not have the same source-table rows.');
end
odDate = string(odAudit.Date, 'yyyyMMdd');
aiDate = string(aiAudit.Date, 'yyyyMMdd');
if ~isequal(odDate, aiDate) || ...
        ~isequal(string(odAudit.Monkey), string(aiAudit.Monkey))
    error('ODPlusAdjacentAI:IdentityMismatch', ...
        'OD and AI audits are not aligned by date and monkey.');
end
end

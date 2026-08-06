function Analysis = analyze_ms_behavior_bias(varargin)
%ANALYZE_MS_BEHAVIOR_BIAS Relate vertical microsaccades to behavior bias.
%
% Sessions are matched across source tables by recording date, monkey, and
% ROI. For each cue, the primary model is:
%
%   Bias ~ MS_y * condition
%
% MS_y is the session-condition mean vertical microsaccade displacement in
% degrees. Positive values indicate upward displacement. The exact OLS
% model and a repeated-session mixed model are both saved.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'BehaviorTableFile', ...
    'C:\EM\BehaviorFitting\unit_table_gof.mat', ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'MicrosaccadeStatsFile', ...
    ['C:\EM\Microsac\population_merged_6ms_no_smoothing\' ...
    'population_microsaccade_direction_stats_complete.csv'], ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'OutputDir', ...
    'C:\EM\Microsac\ms_behavior_bias', ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'UseGoodFitsOnly', true, ...
    @(x) islogical(x) && isscalar(x));
addParameter(parser, 'MakePlots', true, ...
    @(x) islogical(x) && isscalar(x));
addParameter(parser, 'FilterROI', "", ...
    @(x) (ischar(x) || isstring(x)) && isscalar(string(x)));
addParameter(parser, 'FilterMonkey', "", ...
    @(x) (ischar(x) || isstring(x)) && isscalar(string(x)));
parse(parser, varargin{:});
options = parser.Results;

behaviorTableFile = char(options.BehaviorTableFile);
microsaccadeStatsFile = char(options.MicrosaccadeStatsFile);
outputDir = char(options.OutputDir);
assert(isfile(behaviorTableFile), ...
    'Behavior table file not found: %s', behaviorTableFile);
assert(isfile(microsaccadeStatsFile), ...
    'Microsaccade statistics file not found: %s', microsaccadeStatsFile);
if ~isfolder(outputDir)
    mkdir(outputDir);
end

loaded = load(behaviorTableFile, 'unit_table_gof');
assert(isfield(loaded, 'unit_table_gof') && istable(loaded.unit_table_gof), ...
    'Behavior MAT file must contain the table unit_table_gof.');
unit_table_gof = loaded.unit_table_gof;
requiredBehaviorVariables = {'Date', 'Monkey', 'ROI', ...
    'Behav_bias_N', 'Behav_bias_S', 'Behav_goodfit_N', 'Behav_goodfit_S'};
assert(all(ismember(requiredBehaviorVariables, ...
    unit_table_gof.Properties.VariableNames)), ...
    'unit_table_gof is missing one or more required variables.');

filterROI = strip(string(options.FilterROI));
filterMonkey = strip(string(options.FilterMonkey));
analysisLabel = "All sessions";
if strlength(filterROI) > 0
    unit_table_gof = unit_table_gof(strcmpi( ...
        strip(string(unit_table_gof.ROI)), filterROI), :);
    analysisLabel = "ROI = " + filterROI;
end
if strlength(filterMonkey) > 0
    unit_table_gof = unit_table_gof(strcmpi( ...
        strip(string(unit_table_gof.Monkey)), filterMonkey), :);
    if strlength(filterROI) > 0
        analysisLabel = "Monkey = " + filterMonkey + ", ROI = " + filterROI;
    else
        analysisLabel = "Monkey = " + filterMonkey;
    end
end
assert(height(unit_table_gof) > 0, ...
    'No behavior sessions remained after applying subgroup filters.');

msStats = readtable(microsaccadeStatsFile, ...
    'TextType', 'string', 'VariableNamingRule', 'preserve');
requiredMSVariables = {'Date', 'Monkey', 'ROI', 'TrialType', ...
    'EventCount', 'MeanDisplacementYDeg', 'UnitVectorSumY', ...
    'TrialsWithEvents', 'RayleighP', 'MeanResultantLength'};
assert(all(ismember(requiredMSVariables, msStats.Properties.VariableNames)), ...
    'Microsaccade direction-statistics CSV is missing required variables.');

behaviorKeys = makeSessionKeys(unit_table_gof.Date, ...
    unit_table_gof.Monkey, unit_table_gof.ROI);
msKeys = makeSessionKeys(msStats.Date, msStats.Monkey, msStats.ROI);
assert(numel(unique(behaviorKeys)) == height(unit_table_gof), ...
    'Date + Monkey + ROI does not uniquely identify behavior-table rows.');
msCondition = string(msStats.TrialType);
msCondition = replace(lower(strip(msCondition)), "nonstim", "NonStim");
msCondition = replace(msCondition, "stim", "Stim");
msPairKeys = msKeys + "|" + msCondition;
assert(numel(unique(msPairKeys)) == height(msStats), ...
    ['Date + Monkey + ROI + condition does not uniquely identify ' ...
    'microsaccade-statistics rows.']);

nSessions = height(unit_table_gof);
MS_y_NonStim = nan(nSessions, 1);
MS_y_Stim = nan(nSessions, 1);
MS_y_unit_NonStim = nan(nSessions, 1);
MS_y_unit_Stim = nan(nSessions, 1);
MS_EventCount_NonStim = nan(nSessions, 1);
MS_EventCount_Stim = nan(nSessions, 1);
MS_TrialsWithEvents_NonStim = nan(nSessions, 1);
MS_TrialsWithEvents_Stim = nan(nSessions, 1);
MS_RayleighP_NonStim = nan(nSessions, 1);
MS_RayleighP_Stim = nan(nSessions, 1);
MS_MeanResultantLength_NonStim = nan(nSessions, 1);
MS_MeanResultantLength_Stim = nan(nSessions, 1);
MS_UnitTableRow = nan(nSessions, 1);
MS_Matched = false(nSessions, 1);

for iSession = 1:nSessions
    nonStimRow = find(msKeys == behaviorKeys(iSession) & ...
        msCondition == "NonStim");
    stimRow = find(msKeys == behaviorKeys(iSession) & ...
        msCondition == "Stim");
    if isempty(nonStimRow) || isempty(stimRow)
        continue
    end
    assert(isscalar(nonStimRow) && isscalar(stimRow), ...
        'Microsaccade join returned duplicate condition rows for %s.', ...
        behaviorKeys(iSession));

    MS_y_NonStim(iSession) = msStats.MeanDisplacementYDeg(nonStimRow);
    MS_y_Stim(iSession) = msStats.MeanDisplacementYDeg(stimRow);
    MS_EventCount_NonStim(iSession) = msStats.EventCount(nonStimRow);
    MS_EventCount_Stim(iSession) = msStats.EventCount(stimRow);
    MS_y_unit_NonStim(iSession) = safeUnitY(msStats.UnitVectorSumY(nonStimRow), ...
        MS_EventCount_NonStim(iSession));
    MS_y_unit_Stim(iSession) = safeUnitY(msStats.UnitVectorSumY(stimRow), ...
        MS_EventCount_Stim(iSession));
    MS_TrialsWithEvents_NonStim(iSession) = ...
        msStats.TrialsWithEvents(nonStimRow);
    MS_TrialsWithEvents_Stim(iSession) = msStats.TrialsWithEvents(stimRow);
    MS_RayleighP_NonStim(iSession) = msStats.RayleighP(nonStimRow);
    MS_RayleighP_Stim(iSession) = msStats.RayleighP(stimRow);
    MS_MeanResultantLength_NonStim(iSession) = ...
        msStats.MeanResultantLength(nonStimRow);
    MS_MeanResultantLength_Stim(iSession) = ...
        msStats.MeanResultantLength(stimRow);
    if ismember('UnitTableRow', msStats.Properties.VariableNames)
        MS_UnitTableRow(iSession) = msStats.UnitTableRow(nonStimRow);
    end
    MS_Matched(iSession) = true;
end

unit_table_ms_behavior = addvars(unit_table_gof, behaviorKeys, ...
    MS_UnitTableRow, MS_Matched, MS_y_NonStim, MS_y_Stim, ...
    MS_y_unit_NonStim, MS_y_unit_Stim, MS_EventCount_NonStim, ...
    MS_EventCount_Stim, MS_TrialsWithEvents_NonStim, ...
    MS_TrialsWithEvents_Stim, MS_RayleighP_NonStim, MS_RayleighP_Stim, ...
    MS_MeanResultantLength_NonStim, MS_MeanResultantLength_Stim, ...
    'After', 'ROI', 'NewVariableNames', {'MS_SessionKey', ...
    'MS_UnitTableRow', 'MS_Matched', 'MS_y_NonStim', 'MS_y_Stim', ...
    'MS_y_unit_NonStim', 'MS_y_unit_Stim', 'MS_EventCount_NonStim', ...
    'MS_EventCount_Stim', 'MS_TrialsWithEvents_NonStim', ...
    'MS_TrialsWithEvents_Stim', 'MS_RayleighP_NonStim', ...
    'MS_RayleighP_Stim', 'MS_MeanResultantLength_NonStim', ...
    'MS_MeanResultantLength_Stim'});

cueNames = ["Combined", "MonoL", "MonoR", "Stereo"];
LongTable = makeLongTable(unit_table_gof, behaviorKeys, cueNames, ...
    MS_y_NonStim, MS_y_Stim, MS_y_unit_NonStim, MS_y_unit_Stim, ...
    MS_EventCount_NonStim, MS_EventCount_Stim, ...
    MS_TrialsWithEvents_NonStim, MS_TrialsWithEvents_Stim, ...
    MS_RayleighP_NonStim, MS_RayleighP_Stim);
LongTable.UsableForModel = isfinite(LongTable.Bias) & ...
    isfinite(LongTable.MS_y);
if options.UseGoodFitsOnly
    LongTable.UsableForModel = LongTable.UsableForModel & LongTable.GoodFit;
end

LinearModels = cell(4, 1);
MixedModels = cell(4, 1);
modelRows = repmat(makeModelRow(), 4, 1);
coefficientTables = cell(8, 1);
for iCue = 1:4
    cueData = LongTable(LongTable.CueIndex == iCue & ...
        LongTable.UsableForModel, :);
    cueData.condition = reordercats(cueData.condition, {'NonStim', 'Stim'});
    assert(any(cueData.condition == 'NonStim') && ...
        any(cueData.condition == 'Stim'), ...
        'Cue %d lacks usable data from one condition.', iCue);

    LinearModels{iCue} = fitlm(cueData, 'Bias ~ MS_y * condition');
    cueData.SessionKey = categorical(cueData.SessionKey);
    try
        MixedModels{iCue} = fitlme(cueData, ...
            'Bias ~ MS_y * condition + (1|SessionKey)');
    catch errorInfo
        warning('Mixed model failed for cue %d (%s): %s', ...
            iCue, cueNames(iCue), errorInfo.message);
        MixedModels{iCue} = [];
    end

    modelRows(iCue) = summarizeCueModel(iCue, cueNames(iCue), ...
        cueData, LinearModels{iCue}, MixedModels{iCue});
    coefficientTables{2 * iCue - 1} = makeCoefficientTable( ...
        LinearModels{iCue}, iCue, cueNames(iCue), "OLS");
    if ~isempty(MixedModels{iCue})
        coefficientTables{2 * iCue} = makeCoefficientTable( ...
            MixedModels{iCue}, iCue, cueNames(iCue), "LME");
    end
end

ModelSummaryTable = struct2table(modelRows, 'AsArray', true);
ModelSummaryTable.NonStimSlopeQ_FDR = ...
    benjaminiHochberg(ModelSummaryTable.NonStimSlopeP);
ModelSummaryTable.StimSlopeQ_FDR = ...
    benjaminiHochberg(ModelSummaryTable.StimSlopeP);
ModelSummaryTable.InteractionQ_FDR = ...
    benjaminiHochberg(ModelSummaryTable.InteractionP);
ModelSummaryTable.LME_NonStimSlopeQ_FDR = ...
    benjaminiHochberg(ModelSummaryTable.LME_NonStimSlopeP);
ModelSummaryTable.LME_StimSlopeQ_FDR = ...
    benjaminiHochberg(ModelSummaryTable.LME_StimSlopeP);
ModelSummaryTable.LME_InteractionQ_FDR = ...
    benjaminiHochberg(ModelSummaryTable.LME_InteractionP);
CoefficientTable = vertcat(coefficientTables{~cellfun(@isempty, coefficientTables)});

behaviorSessionSet = unique(behaviorKeys);
msSessionSet = unique(msKeys);
JoinAuditTable = table(height(unit_table_gof), numel(behaviorSessionSet), ...
    numel(msSessionSet), nnz(MS_Matched), nnz(~MS_Matched), ...
    nnz(MS_Matched & isfinite(MS_y_NonStim) & isfinite(MS_y_Stim)), ...
    'VariableNames', {'BehaviorRows', 'UniqueBehaviorSessions', ...
    'UniqueMSSessions', 'MatchedBehaviorSessions', ...
    'UnmatchedBehaviorSessions', 'MatchedWithFiniteMS_yBothConditions'});
UnmatchedBehaviorTable = unit_table_ms_behavior(~MS_Matched, ...
    {'Date', 'Monkey', 'ROI', 'MS_SessionKey'});

outputFiles = struct;
outputFiles.LongTableCSV = fullfile(outputDir, ...
    'ms_behavior_bias_long_table.csv');
outputFiles.ModelSummaryCSV = fullfile(outputDir, ...
    'ms_behavior_bias_model_summary.csv');
outputFiles.CoefficientsCSV = fullfile(outputDir, ...
    'ms_behavior_bias_coefficients.csv');
outputFiles.JoinAuditCSV = fullfile(outputDir, ...
    'ms_behavior_bias_join_audit.csv');
outputFiles.UnmatchedSessionsCSV = fullfile(outputDir, ...
    'ms_behavior_bias_unmatched_sessions.csv');
outputFiles.UnitTableMat = fullfile(outputDir, ...
    'unit_table_ms_behavior.mat');
outputFiles.ResultsMat = fullfile(outputDir, ...
    'ms_behavior_bias_results.mat');
outputFiles.OverviewFigurePNG = fullfile(outputDir, ...
    'ms_behavior_bias_by_cue.png');
outputFiles.OverviewFigureFIG = fullfile(outputDir, ...
    'ms_behavior_bias_by_cue.fig');

writetable(LongTable, outputFiles.LongTableCSV);
writetable(ModelSummaryTable, outputFiles.ModelSummaryCSV);
writetable(CoefficientTable, outputFiles.CoefficientsCSV);
writetable(JoinAuditTable, outputFiles.JoinAuditCSV);
writetable(UnmatchedBehaviorTable, outputFiles.UnmatchedSessionsCSV);
unit_table = unit_table_ms_behavior;
save(outputFiles.UnitTableMat, 'unit_table', 'unit_table_ms_behavior', ...
    'JoinAuditTable', '-v7.3');

if options.MakePlots
    makeOverviewPlot(LongTable, LinearModels, ModelSummaryTable, ...
        cueNames, analysisLabel, outputFiles);
end

Analysis = struct;
Analysis.Description = ["Sessions joined by Date + Monkey + ROI. ", ...
    "MS_y is mean event vertical displacement in degrees; positive is upward."];
Analysis.FilterROI = filterROI;
Analysis.FilterMonkey = filterMonkey;
Analysis.AnalysisLabel = analysisLabel;
Analysis.Formula = "Bias ~ MS_y * condition";
Analysis.MixedFormula = "Bias ~ MS_y * condition + (1|SessionKey)";
Analysis.CueNames = cueNames;
Analysis.Options = options;
Analysis.JoinAuditTable = JoinAuditTable;
Analysis.UnmatchedBehaviorTable = UnmatchedBehaviorTable;
Analysis.LongTable = LongTable;
Analysis.ModelSummaryTable = ModelSummaryTable;
Analysis.CoefficientTable = CoefficientTable;
Analysis.LinearModels = LinearModels;
Analysis.MixedModels = MixedModels;
Analysis.OutputFiles = outputFiles;
save(outputFiles.ResultsMat, 'Analysis', '-v7.3');

fprintf('\nMicrosaccade-behavior analysis complete.\n');
fprintf('Matched behavior sessions: %d/%d.\n', ...
    nnz(MS_Matched), nSessions);
disp(ModelSummaryTable(:, {'CueName', 'NRows', 'NonStimSlope', ...
    'StimSlope', 'InteractionP', 'InteractionQ_FDR', ...
    'LME_InteractionP'}));
fprintf('Results saved to %s\n', outputDir);
end


function LongTable = makeLongTable(unitTable, sessionKeys, cueNames, ...
        msYN, msYS, msYUnitN, msYUnitS, eventCountN, eventCountS, ...
        trialsWithEventsN, trialsWithEventsS, rayleighPN, rayleighPS)
nSessions = height(unitTable);
nRows = nSessions * 8;
BehaviorRow = zeros(nRows, 1);
SessionKey = strings(nRows, 1);
Date = NaT(nRows, 1);
Monkey = strings(nRows, 1);
ROI = strings(nRows, 1);
CueIndex = zeros(nRows, 1);
CueName = strings(nRows, 1);
conditionText = strings(nRows, 1);
IsStim = false(nRows, 1);
Bias = nan(nRows, 1);
GoodFit = false(nRows, 1);
MS_y = nan(nRows, 1);
MS_y_unit = nan(nRows, 1);
MS_EventCount = nan(nRows, 1);
MS_TrialsWithEvents = nan(nRows, 1);
MS_RayleighP = nan(nRows, 1);

row = 0;
for iSession = 1:nSessions
    biasN = extractFourValues(unitTable.Behav_bias_N, iSession, false);
    biasS = extractFourValues(unitTable.Behav_bias_S, iSession, false);
    goodN = logical(extractFourValues(unitTable.Behav_goodfit_N, iSession, true));
    goodS = logical(extractFourValues(unitTable.Behav_goodfit_S, iSession, true));
    for iCue = 1:4
        for iCondition = 1:2
            row = row + 1;
            BehaviorRow(row) = iSession;
            SessionKey(row) = sessionKeys(iSession);
            Date(row) = unitTable.Date(iSession);
            Monkey(row) = string(unitTable.Monkey(iSession));
            ROI(row) = string(unitTable.ROI(iSession));
            CueIndex(row) = iCue;
            CueName(row) = cueNames(iCue);
            IsStim(row) = iCondition == 2;
            if IsStim(row)
                conditionText(row) = "Stim";
                Bias(row) = biasS(iCue);
                GoodFit(row) = goodS(iCue);
                MS_y(row) = msYS(iSession);
                MS_y_unit(row) = msYUnitS(iSession);
                MS_EventCount(row) = eventCountS(iSession);
                MS_TrialsWithEvents(row) = trialsWithEventsS(iSession);
                MS_RayleighP(row) = rayleighPS(iSession);
            else
                conditionText(row) = "NonStim";
                Bias(row) = biasN(iCue);
                GoodFit(row) = goodN(iCue);
                MS_y(row) = msYN(iSession);
                MS_y_unit(row) = msYUnitN(iSession);
                MS_EventCount(row) = eventCountN(iSession);
                MS_TrialsWithEvents(row) = trialsWithEventsN(iSession);
                MS_RayleighP(row) = rayleighPN(iSession);
            end
        end
    end
end
condition = categorical(conditionText, ["NonStim", "Stim"]);
LongTable = table(BehaviorRow, SessionKey, Date, Monkey, ROI, CueIndex, ...
    CueName, condition, IsStim, Bias, GoodFit, MS_y, MS_y_unit, ...
    MS_EventCount, MS_TrialsWithEvents, MS_RayleighP);
end


function values = extractFourValues(variable, row, asLogical)
if iscell(variable)
    values = variable{row};
else
    values = variable(row, :);
end
values = values(:)';
assert(numel(values) == 4, ...
    'Expected four cue values in behavior row %d.', row);
if asLogical
    values = logical(values);
else
    values = double(values);
end
end


function keys = makeSessionKeys(dateValues, monkeyValues, roiValues)
dateText = normalizeDateText(dateValues);
monkeyText = lower(strip(string(monkeyValues)));
roiText = lower(strip(string(roiValues)));
assert(all(strlength(monkeyText) > 0) && all(strlength(roiText) > 0), ...
    'Monkey and ROI must be nonempty for session matching.');
keys = dateText + "|" + monkeyText + "|" + roiText;
end


function dateText = normalizeDateText(values)
if isdatetime(values)
    dates = dateshift(values, 'start', 'day');
else
    textValues = strip(string(values));
    dates = NaT(size(textValues));
    inputFormats = {'dd-MMM-yyyy', 'yyyy-MM-dd', 'MM/dd/yyyy', ...
        'dd-MMM-uuuu', 'yyyyMMdd'};
    for iFormat = 1:numel(inputFormats)
        missing = isnat(dates) & strlength(textValues) > 0;
        if ~any(missing)
            break
        end
        try
            parsed = datetime(textValues(missing), ...
                'InputFormat', inputFormats{iFormat}, 'Locale', 'en_US');
            dates(missing) = parsed;
        catch
        end
    end
end
assert(all(~isnat(dates)), 'At least one session date could not be parsed.');
dates.Format = 'yyyyMMdd';
dateText = string(dates);
end


function value = safeUnitY(vectorSumY, eventCount)
if isfinite(vectorSumY) && isfinite(eventCount) && eventCount > 0
    value = vectorSumY / eventCount;
else
    value = NaN;
end
end


function row = makeModelRow()
row = struct('CueIndex', NaN, 'CueName', "", 'NRows', NaN, ...
    'NSessions', NaN, 'NNonStim', NaN, 'NStim', NaN, ...
    'NonStimSlope', NaN, 'NonStimSlopeSE', NaN, ...
    'NonStimSlopeP', NaN, 'NonStimSlopeQ_FDR', NaN, ...
    'StimSlope', NaN, 'StimSlopeSE', NaN, 'StimSlopeP', NaN, ...
    'StimSlopeQ_FDR', NaN, 'SlopeDifference', NaN, ...
    'SlopeDifferenceSE', NaN, 'InteractionP', NaN, ...
    'InteractionQ_FDR', NaN, 'NonStimPearsonR', NaN, ...
    'NonStimPearsonP', NaN, 'StimPearsonR', NaN, ...
    'StimPearsonP', NaN, 'LME_NonStimSlope', NaN, ...
    'LME_NonStimSlopeP', NaN, 'LME_NonStimSlopeQ_FDR', NaN, ...
    'LME_StimSlope', NaN, 'LME_StimSlopeP', NaN, ...
    'LME_StimSlopeQ_FDR', NaN, 'LME_SlopeDifference', NaN, ...
    'LME_InteractionP', NaN, 'LME_InteractionQ_FDR', NaN);
end


function row = summarizeCueModel(cueIndex, cueName, data, lm, lme)
row = makeModelRow();
row.CueIndex = cueIndex;
row.CueName = cueName;
row.NRows = height(data);
row.NSessions = numel(unique(data.SessionKey));
row.NNonStim = nnz(data.condition == 'NonStim');
row.NStim = nnz(data.condition == 'Stim');
stats = extractSlopeStatistics(lm);
row.NonStimSlope = stats.NonStimSlope;
row.NonStimSlopeSE = stats.NonStimSlopeSE;
row.NonStimSlopeP = stats.NonStimSlopeP;
row.StimSlope = stats.StimSlope;
row.StimSlopeSE = stats.StimSlopeSE;
row.StimSlopeP = stats.StimSlopeP;
row.SlopeDifference = stats.SlopeDifference;
row.SlopeDifferenceSE = stats.SlopeDifferenceSE;
row.InteractionP = stats.InteractionP;
[row.NonStimPearsonR, row.NonStimPearsonP] = conditionCorrelation( ...
    data(data.condition == 'NonStim', :));
[row.StimPearsonR, row.StimPearsonP] = conditionCorrelation( ...
    data(data.condition == 'Stim', :));
if ~isempty(lme)
    mixedStats = extractSlopeStatistics(lme);
    row.LME_NonStimSlope = mixedStats.NonStimSlope;
    row.LME_NonStimSlopeP = mixedStats.NonStimSlopeP;
    row.LME_StimSlope = mixedStats.StimSlope;
    row.LME_StimSlopeP = mixedStats.StimSlopeP;
    row.LME_SlopeDifference = mixedStats.SlopeDifference;
    row.LME_InteractionP = mixedStats.InteractionP;
end
end


function stats = extractSlopeStatistics(model)
coefficientTable = model.Coefficients;
names = string(model.CoefficientNames(:));
msIndex = find(names == "MS_y", 1);
interactionIndex = find(contains(names, "MS_y") & ...
    contains(lower(names), "condition"), 1);
assert(~isempty(msIndex) && ~isempty(interactionIndex), ...
    'Could not locate MS_y and interaction coefficients.');

estimates = coefficientTable.Estimate;
covariance = model.CoefficientCovariance;
nonStimContrast = zeros(1, numel(estimates));
nonStimContrast(msIndex) = 1;
stimContrast = nonStimContrast;
stimContrast(interactionIndex) = 1;
interactionContrast = zeros(1, numel(estimates));
interactionContrast(interactionIndex) = 1;

stats = struct;
stats.NonStimSlope = nonStimContrast * estimates;
stats.NonStimSlopeSE = sqrt(nonStimContrast * covariance * nonStimContrast');
stats.NonStimSlopeP = coefficientTable.pValue(msIndex);
stats.StimSlope = stimContrast * estimates;
stats.StimSlopeSE = sqrt(stimContrast * covariance * stimContrast');
stats.StimSlopeP = coefTest(model, stimContrast, 0);
stats.SlopeDifference = interactionContrast * estimates;
stats.SlopeDifferenceSE = sqrt(interactionContrast * covariance * ...
    interactionContrast');
stats.InteractionP = coefficientTable.pValue(interactionIndex);
end


function [r, p] = conditionCorrelation(data)
r = NaN;
p = NaN;
if height(data) < 3 || numel(unique(data.MS_y)) < 2 || ...
        numel(unique(data.Bias)) < 2
    return
end
[r, p] = corr(data.MS_y, data.Bias, 'Rows', 'complete', ...
    'Type', 'Pearson');
end


function output = makeCoefficientTable(model, cueIndex, cueName, modelType)
coefficients = model.Coefficients;
n = numel(model.CoefficientNames);
output = table(repmat(cueIndex, n, 1), repmat(cueName, n, 1), ...
    repmat(modelType, n, 1), string(model.CoefficientNames(:)), ...
    coefficients.Estimate, coefficients.SE, coefficients.tStat, ...
    coefficients.pValue, 'VariableNames', {'CueIndex', 'CueName', ...
    'ModelType', 'Term', 'Estimate', 'SE', 'tStat', 'pValue'});
end


function q = benjaminiHochberg(p)
q = nan(size(p));
valid = find(isfinite(p));
if isempty(valid)
    return
end
[sortedP, order] = sort(p(valid));
m = numel(sortedP);
sortedQ = sortedP .* m ./ (1:m)';
sortedQ = flipud(cummin(flipud(sortedQ)));
sortedQ = min(sortedQ, 1);
q(valid(order)) = sortedQ;
end


function makeOverviewPlot(longTable, models, summaryTable, cueNames, ...
        analysisLabel, outputFiles)
figureHandle = figure('Color', 'w', 'Position', [100, 100, 1180, 850]);
layout = tiledlayout(figureHandle, 2, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
colors = [0.18, 0.20, 0.23; 0.78, 0.18, 0.16];
for iCue = 1:4
    axisHandle = nexttile(layout);
    hold(axisHandle, 'on');
    cueData = longTable(longTable.CueIndex == iCue & ...
        longTable.UsableForModel, :);
    conditionNames = ["NonStim", "Stim"];
    for iCondition = 1:2
        mask = string(cueData.condition) == conditionNames(iCondition);
        scatter(axisHandle, cueData.MS_y(mask), cueData.Bias(mask), 26, ...
            'MarkerFaceColor', colors(iCondition, :), ...
            'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.55, ...
            'DisplayName', conditionNames(iCondition));
    end
    xMinimum = min([cueData.MS_y; 0]);
    xMaximum = max([cueData.MS_y; 0]);
    xPadding = max(0.05 * (xMaximum - xMinimum), 1e-4);
    xLimits = [xMinimum - xPadding, xMaximum + xPadding];
    xRange = linspace(xLimits(1), xLimits(2), 150)';
    for iCondition = 1:2
        mask = string(cueData.condition) == conditionNames(iCondition);
        if nnz(mask) >= 2
            predictionTable = table(xRange, categorical( ...
                repmat(conditionNames(iCondition), numel(xRange), 1), ...
                ["NonStim", "Stim"]), ...
                'VariableNames', {'MS_y', 'condition'});
            fittedBias = predict(models{iCue}, predictionTable);
            plot(axisHandle, xRange, fittedBias, 'Color', ...
                colors(iCondition, :), 'LineWidth', 2, ...
                'HandleVisibility', 'off');
        end
    end
    xlim(axisHandle, xLimits);
    xline(axisHandle, 0, ':', 'Color', [0.55, 0.55, 0.55], ...
        'HandleVisibility', 'off');
    yline(axisHandle, 0, ':', 'Color', [0.55, 0.55, 0.55], ...
        'HandleVisibility', 'off');
    grid(axisHandle, 'on');
    box(axisHandle, 'off');
    axisHandle.Toolbar.Visible = 'off';
    title(axisHandle, sprintf('%s: interaction p = %.3g', ...
        cueNames(iCue), summaryTable.InteractionP(iCue)));
    xlabel(axisHandle, 'MS_y: mean vertical displacement (deg)');
    ylabel(axisHandle, 'Behavioral bias');
    if iCue == 1
        legend(axisHandle, 'Location', 'best');
    end
end
title(layout, "Behavioral bias versus microsaccade vertical displacement (" + ...
    analysisLabel + ")");
exportgraphics(figureHandle, outputFiles.OverviewFigurePNG, ...
    'Resolution', 220);
savefig(figureHandle, outputFiles.OverviewFigureFIG);
close(figureHandle);
end

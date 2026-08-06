function Analysis = analyze_stim_from_vertical_ms(varargin)
%ANALYZE_STIM_FROM_VERTICAL_MS Predict Stim versus NonStim from vertical MS.
%
% The model is deliberately simple:
%
%   Pooled:            IsStim ~ MeanMSY_Z
%   Session-adjusted:  IsStim ~ SessionID + MeanMSY_Z
%
% MeanMSY_Z is trial-average vertical microsaccade displacement,
% re-standardized within recording session. The pooled model is evaluated
% with leave-one-session-out cross-validation. Session-specific AUC values
% are treated as independent observations for a test against chance (0.5).

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'TrialCSV', ...
    ['C:\EM\Microsac\population_merged_12ms_no_smoothing\' ...
    'population_analysis\trialwise_ms_choice\' ...
    'trialwise_ms_choice_trials.csv'], ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'OutputDir', ...
    ['C:\EM\Microsac\population_merged_12ms_no_smoothing\' ...
    'population_analysis\stim_from_vertical_ms'], ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'MakePlot', true, ...
    @(x) islogical(x) && isscalar(x));
parse(parser, varargin{:});
options = parser.Results;

trialFile = char(options.TrialCSV);
outputDir = char(options.OutputDir);
assert(isfile(trialFile), 'Trial CSV not found: %s', trialFile);
if ~isfolder(outputDir)
    mkdir(outputDir);
end

trials = readtable(trialFile, 'TextType', 'string', ...
    'VariableNamingRule', 'preserve');
required = {'UnitTableRow', 'Monkey', 'ROI', 'IsStim', ...
    'MeanMSYDeg', 'UsableForModel'};
assert(all(ismember(required, trials.Properties.VariableNames)), ...
    'The trial table is missing required variables.');

valid = logical(trials.UsableForModel) & ...
    isfinite(trials.MeanMSYDeg) & ...
    isfinite(trials.UnitTableRow);
trials = trials(valid, :);
trials = standardizeWithinSession(trials);
trials = trials(isfinite(trials.MeanMSY_Z), :);

groupMonkey = ["Jim"; "Jim"; "Clay"; "Clay"];
groupROI = ["MT"; "FST"; "MT"; "FST"];
nGroups = numel(groupMonkey);
summaryRows = repmat(makeSummaryRow(), nGroups, 1);
sessionTables = cell(nGroups, 1);
pooledModels = cell(nGroups, 1);
sessionAdjustedModels = cell(nGroups, 1);
cvProbability = cell(nGroups, 1);

for iGroup = 1:nGroups
    mask = strcmpi(trials.Monkey, groupMonkey(iGroup)) & ...
        strcmpi(trials.ROI, groupROI(iGroup));
    data = trials(mask, :);
    assert(~isempty(data), 'No trials found for %s-%s.', ...
        groupMonkey(iGroup), groupROI(iGroup));
    data.SessionID = categorical(string(data.UnitTableRow));
    data.IsStim = logical(data.IsStim);

    summary = makeSummaryRow();
    summary.GroupIndex = iGroup;
    summary.Group = groupMonkey(iGroup) + "-" + groupROI(iGroup);
    summary.Monkey = groupMonkey(iGroup);
    summary.ROI = groupROI(iGroup);
    summary.NSessions = numel(unique(data.UnitTableRow));
    summary.NTrials = height(data);
    summary.NNonStimTrials = nnz(~data.IsStim);
    summary.NStimTrials = nnz(data.IsStim);
    summary.StimFraction = mean(data.IsStim);
    summary.NonStimMeanMSYDeg = mean(data.MeanMSYDeg(~data.IsStim));
    summary.StimMeanMSYDeg = mean(data.MeanMSYDeg(data.IsStim));
    summary.StimMinusNonStimMSYDeg = ...
        summary.StimMeanMSYDeg - summary.NonStimMeanMSYDeg;
    summary.NonStimMeanMSY_Z = mean(data.MeanMSY_Z(~data.IsStim));
    summary.StimMeanMSY_Z = mean(data.MeanMSY_Z(data.IsStim));
    summary.StimMinusNonStimMSY_Z = ...
        summary.StimMeanMSY_Z - summary.NonStimMeanMSY_Z;
    summary.BaselineAccuracy = max(summary.StimFraction, ...
        1 - summary.StimFraction);
    summary.PooledFormula = "IsStim ~ MeanMSY_Z";
    summary.SessionAdjustedFormula = ...
        "IsStim ~ SessionID + MeanMSY_Z";

    pooledModels{iGroup} = fitglm(data, ...
        char(summary.PooledFormula), 'Distribution', 'binomial');
    sessionAdjustedModels{iGroup} = fitglm(data, ...
        char(summary.SessionAdjustedFormula), ...
        'Distribution', 'binomial');

    pooledCoefficient = pooledModels{iGroup}.Coefficients('MeanMSY_Z', :);
    adjustedCoefficient = ...
        sessionAdjustedModels{iGroup}.Coefficients('MeanMSY_Z', :);
    summary.PooledSlope = pooledCoefficient.Estimate;
    summary.PooledSlopeSE = pooledCoefficient.SE;
    summary.PooledSlopeP = pooledCoefficient.pValue;
    summary.PooledOddsRatio = exp(summary.PooledSlope);
    summary.SessionAdjustedSlope = adjustedCoefficient.Estimate;
    summary.SessionAdjustedSlopeSE = adjustedCoefficient.SE;
    summary.SessionAdjustedSlopeP = adjustedCoefficient.pValue;
    summary.SessionAdjustedOddsRatio = exp(summary.SessionAdjustedSlope);

    apparentProbability = predict(pooledModels{iGroup}, data);
    summary.ApparentAUC = calculateAUC(data.IsStim, apparentProbability);

    [cvProbability{iGroup}, sessionTable] = ...
        leaveOneSessionOut(data, summary);
    summary.CVAUC = calculateAUC(data.IsStim, cvProbability{iGroup});
    predictedStim = cvProbability{iGroup} >= 0.5;
    summary.CVAccuracy = mean(predictedStim == data.IsStim);
    sensitivity = mean(predictedStim(data.IsStim));
    specificity = mean(~predictedStim(~data.IsStim));
    summary.CVBalancedAccuracy = mean([sensitivity, specificity]);

    validSessionAUC = isfinite(sessionTable.AUC);
    sessionAUC = sessionTable.AUC(validSessionAUC);
    summary.NSessionsWithAUC = numel(sessionAUC);
    summary.MeanSessionAUC = mean(sessionAUC);
    summary.MeanSessionAUCSE = std(sessionAUC) / sqrt(numel(sessionAUC));
    if summary.MeanSessionAUCSE > 0 && numel(sessionAUC) > 1
        critical = tinv(0.975, numel(sessionAUC) - 1);
        summary.MeanSessionAUCLower95 = ...
            summary.MeanSessionAUC - critical * summary.MeanSessionAUCSE;
        summary.MeanSessionAUCUpper95 = ...
            summary.MeanSessionAUC + critical * summary.MeanSessionAUCSE;
        tStatistic = (summary.MeanSessionAUC - 0.5) / ...
            summary.MeanSessionAUCSE;
        summary.MeanSessionAUCP = ...
            2 * tcdf(-abs(tStatistic), numel(sessionAUC) - 1);
    end

    sessionTables{iGroup} = sessionTable;
    summaryRows(iGroup) = summary;
end

SummaryTable = struct2table(summaryRows, 'AsArray', true);
SummaryTable.PooledSlopeP_Holm = holmBonferroni( ...
    SummaryTable.PooledSlopeP);
SummaryTable.SessionAdjustedSlopeP_Holm = holmBonferroni( ...
    SummaryTable.SessionAdjustedSlopeP);
SummaryTable.MeanSessionAUCP_Holm = holmBonferroni( ...
    SummaryTable.MeanSessionAUCP);
SessionAUCTable = vertcat(sessionTables{:});

outputFiles = struct;
outputFiles.Mat = fullfile(outputDir, ...
    'stim_from_vertical_ms_results.mat');
outputFiles.SummaryCSV = fullfile(outputDir, ...
    'stim_from_vertical_ms_summary.csv');
outputFiles.SessionAUCCSV = fullfile(outputDir, ...
    'stim_from_vertical_ms_session_auc.csv');
outputFiles.Figure = fullfile(outputDir, ...
    'stim_from_vertical_ms_summary.png');
writetable(SummaryTable, outputFiles.SummaryCSV);
writetable(SessionAUCTable, outputFiles.SessionAUCCSV);

if options.MakePlot
    makeSummaryFigure(SummaryTable, outputFiles.Figure);
else
    outputFiles.Figure = "";
end

Analysis = struct;
Analysis.Definition = ...
    "Can Stim versus NonStim be predicted from trial-average vertical MS?";
Analysis.Predictor = ...
    "MeanMSY_Z: trial-average vertical MS displacement, standardized within session";
Analysis.PrimaryModel = "IsStim ~ SessionID + MeanMSY_Z";
Analysis.PredictionModel = "IsStim ~ MeanMSY_Z";
Analysis.Validation = "Leave-one-session-out cross-validation";
Analysis.SummaryTable = SummaryTable;
Analysis.SessionAUCTable = SessionAUCTable;
Analysis.PooledModels = pooledModels;
Analysis.SessionAdjustedModels = sessionAdjustedModels;
Analysis.CVProbability = cvProbability;
Analysis.OutputFiles = outputFiles;
save(outputFiles.Mat, 'Analysis', '-v7.3');

end


function trials = standardizeWithinSession(trials)
[group, ~] = findgroups(trials.UnitTableRow);
meanY = splitapply(@(x) mean(x, 'omitmissing'), ...
    trials.MeanMSYDeg, group);
scaleY = splitapply(@(x) std(x, 'omitmissing'), ...
    trials.MeanMSYDeg, group);
trials.MeanMSY_Z = ...
    (trials.MeanMSYDeg - meanY(group)) ./ scaleY(group);
end


function [probability, sessionTable] = leaveOneSessionOut(data, summary)
sessionRows = unique(data.UnitTableRow, 'stable');
nSessions = numel(sessionRows);
probability = nan(height(data), 1);
rows = repmat(makeSessionRow(), nSessions, 1);
for iSession = 1:nSessions
    test = data.UnitTableRow == sessionRows(iSession);
    train = ~test;
    coefficients = glmfit(data.MeanMSY_Z(train), ...
        double(data.IsStim(train)), 'binomial', 'link', 'logit');
    probability(test) = glmval(coefficients, ...
        data.MeanMSY_Z(test), 'logit');

    row = makeSessionRow();
    row.GroupIndex = summary.GroupIndex;
    row.Group = summary.Group;
    row.Monkey = summary.Monkey;
    row.ROI = summary.ROI;
    row.UnitTableRow = sessionRows(iSession);
    row.NTrials = nnz(test);
    row.NNonStimTrials = nnz(test & ~data.IsStim);
    row.NStimTrials = nnz(test & data.IsStim);
    if row.NNonStimTrials > 0 && row.NStimTrials > 0
        row.AUC = calculateAUC(data.IsStim(test), probability(test));
    end
    predicted = probability(test) >= 0.5;
    row.Accuracy = mean(predicted == data.IsStim(test));
    rows(iSession) = row;
end
sessionTable = struct2table(rows, 'AsArray', true);
end


function auc = calculateAUC(labels, scores)
if numel(unique(labels)) < 2
    auc = NaN;
    return
end
[~, ~, ~, auc] = perfcurve(labels, scores, true);
end


function row = makeSummaryRow()
row = struct( ...
    'GroupIndex', NaN, 'Group', "", 'Monkey', "", 'ROI', "", ...
    'NSessions', NaN, 'NTrials', NaN, 'NNonStimTrials', NaN, ...
    'NStimTrials', NaN, 'StimFraction', NaN, ...
    'NonStimMeanMSYDeg', NaN, 'StimMeanMSYDeg', NaN, ...
    'StimMinusNonStimMSYDeg', NaN, ...
    'NonStimMeanMSY_Z', NaN, 'StimMeanMSY_Z', NaN, ...
    'StimMinusNonStimMSY_Z', NaN, ...
    'BaselineAccuracy', NaN, 'PooledFormula', "", ...
    'SessionAdjustedFormula', "", ...
    'PooledSlope', NaN, 'PooledSlopeSE', NaN, ...
    'PooledSlopeP', NaN, 'PooledOddsRatio', NaN, ...
    'SessionAdjustedSlope', NaN, 'SessionAdjustedSlopeSE', NaN, ...
    'SessionAdjustedSlopeP', NaN, ...
    'SessionAdjustedOddsRatio', NaN, ...
    'ApparentAUC', NaN, 'CVAUC', NaN, ...
    'CVAccuracy', NaN, 'CVBalancedAccuracy', NaN, ...
    'NSessionsWithAUC', NaN, 'MeanSessionAUC', NaN, ...
    'MeanSessionAUCSE', NaN, 'MeanSessionAUCLower95', NaN, ...
    'MeanSessionAUCUpper95', NaN, 'MeanSessionAUCP', NaN);
end


function row = makeSessionRow()
row = struct( ...
    'GroupIndex', NaN, 'Group', "", 'Monkey', "", 'ROI', "", ...
    'UnitTableRow', NaN, 'NTrials', NaN, ...
    'NNonStimTrials', NaN, 'NStimTrials', NaN, ...
    'AUC', NaN, 'Accuracy', NaN);
end


function adjustedP = holmBonferroni(p)
p = p(:);
adjustedP = nan(size(p));
valid = isfinite(p);
values = p(valid);
if isempty(values)
    return
end
[sorted, order] = sort(values);
m = numel(sorted);
adjusted = sorted .* (m:-1:1)';
adjusted = cummax(adjusted);
adjusted = min(adjusted, 1);
restored = nan(m, 1);
restored(order) = adjusted;
adjustedP(valid) = restored;
end


function makeSummaryFigure(summary, outputFile)
labels = categorical(summary.Group, summary.Group, 'Ordinal', true);
fig = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [100, 100, 1200, 500]);
layout = tiledlayout(fig, 1, 2, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, 'Can vertical MS discriminate Stim from NonStim?');

ax = nexttile(layout);
hold(ax, 'on');
errorbar(ax, 1:height(summary), summary.MeanSessionAUC, ...
    summary.MeanSessionAUC - summary.MeanSessionAUCLower95, ...
    summary.MeanSessionAUCUpper95 - summary.MeanSessionAUC, ...
    'o', 'LineWidth', 1.7, 'MarkerFaceColor', [0.20 0.48 0.75], ...
    'Color', [0.20 0.48 0.75]);
yline(ax, 0.5, ':k', 'Chance');
xticks(ax, 1:height(summary));
xticklabels(ax, string(labels));
ylabel(ax, 'Mean held-out session AUC');
title(ax, 'Leave-one-session-out discrimination');
grid(ax, 'on');
box(ax, 'off');

ax = nexttile(layout);
hold(ax, 'on');
errorbar(ax, 1:height(summary), summary.SessionAdjustedSlope, ...
    1.96 .* summary.SessionAdjustedSlopeSE, ...
    'o', 'LineWidth', 1.7, 'MarkerFaceColor', [0.55 0.25 0.65], ...
    'Color', [0.55 0.25 0.65]);
yline(ax, 0, ':k');
xticks(ax, 1:height(summary));
xticklabels(ax, string(labels));
ylabel(ax, 'Log-odds slope per within-session SD');
title(ax, 'Session-adjusted logistic coefficient');
grid(ax, 'on');
box(ax, 'off');

exportgraphics(fig, outputFile, 'Resolution', 220);
close(fig);
end

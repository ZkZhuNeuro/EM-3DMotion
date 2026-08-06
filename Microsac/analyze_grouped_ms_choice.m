function GroupedAnalysis = analyze_grouped_ms_choice(varargin)
%ANALYZE_GROUPED_MS_CHOICE Pool trial-level MS choice data by monkey and ROI.
%
% Four groups are fit: Jim-MT, Jim-FST, Clay-MT, and Clay-FST. MS X/Y are
% re-standardized within recording session before sessions are pooled. Both
% models include session-specific NonStim/Stim intercepts:
%
%   Simple:
%     Choice ~ SessionID * StimCondition + MeanMSY_Z * StimCondition
%
%   Adjusted:
%     Choice ~ SessionID * StimCondition + ...
%       SignedCoherence * VisualCondition + MeanMSY_Z * StimCondition
%
% A vector sensitivity model adds MeanMSX_Z and its Stim interaction. Holm-
% Bonferroni adjustment is applied across the four monkey/ROI groups within
% each model/test family.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'TrialwiseResultsFile', ...
    ['C:\EM\Microsac\population_merged_12ms_no_smoothing\' ...
    'population_analysis\trialwise_ms_choice\' ...
    'trialwise_ms_choice_results.mat'], ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'OutputDir', ...
    ['C:\EM\Microsac\population_merged_12ms_no_smoothing\' ...
    'population_analysis\grouped_monkey_roi_ms_choice'], ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'LikelihoodPenalty', "jeffreys-prior", ...
    @(x) any(strcmpi(string(x), ["none", "jeffreys-prior"])));
addParameter(parser, 'MaxIterations', 1000, ...
    @(x) isscalar(x) && isfinite(x) && x >= 100 && mod(x, 1) == 0);
addParameter(parser, 'MakePlots', true, ...
    @(x) islogical(x) && isscalar(x));
parse(parser, varargin{:});
options = parser.Results;

resultsFile = char(options.TrialwiseResultsFile);
outputDir = char(options.OutputDir);
assert(isfile(resultsFile), 'Trialwise result MAT not found: %s', resultsFile);
if ~isfolder(outputDir)
    mkdir(outputDir);
end
saved = load(resultsFile, 'Analysis');
assert(isfield(saved, 'Analysis') && isfield(saved.Analysis, 'TrialTable'), ...
    'Input MAT must contain Analysis.TrialTable.');
trials = saved.Analysis.TrialTable;
required = {'UnitTableRow', 'Monkey', 'ROI', 'Choice', 'IsStim', ...
    'StimCondition', 'VisualCondition', 'SignedCoherence', ...
    'MeanMSXDeg', 'MeanMSYDeg', 'UsableForModel'};
assert(all(ismember(required, trials.Properties.VariableNames)), ...
    'The trialwise table is missing required variables.');

valid = trials.UsableForModel & ismember(trials.Choice, [0, 1]) & ...
    isfinite(trials.SignedCoherence) & isfinite(trials.MeanMSXDeg) & ...
    isfinite(trials.MeanMSYDeg);
trials = trials(valid, :);
trials = standardizeMSWithinSession(trials);
trials = trials(isfinite(trials.MeanMSX_Z) & ...
    isfinite(trials.MeanMSY_Z), :);

groupMonkey = ["Jim"; "Jim"; "Clay"; "Clay"];
groupROI = ["MT"; "FST"; "MT"; "FST"];
nGroups = numel(groupMonkey);
summaryRows = repmat(makeGroupSummaryRow(), nGroups, 1);
coefficientTables = cell(nGroups, 1);
SimpleModels = cell(nGroups, 1);
AdjustedModels = cell(nGroups, 1);
VectorModels = cell(nGroups, 1);

fprintf('Fitting grouped MS/choice models for %d monkey/ROI groups.\n', nGroups);
for iGroup = 1:nGroups
    mask = strcmpi(trials.Monkey, groupMonkey(iGroup)) & ...
        strcmpi(trials.ROI, groupROI(iGroup));
    data = trials(mask, :);
    assert(height(data) > 0, 'No trials found for %s-%s.', ...
        groupMonkey(iGroup), groupROI(iGroup));

    summary = makeGroupSummaryRow();
    summary.GroupIndex = iGroup;
    summary.Group = groupMonkey(iGroup) + "-" + groupROI(iGroup);
    summary.Monkey = groupMonkey(iGroup);
    summary.ROI = groupROI(iGroup);
    summary.NSessions = numel(unique(data.UnitTableRow));
    summary.NTrials = height(data);
    summary.NNonStimTrials = nnz(~data.IsStim);
    summary.NStimTrials = nnz(data.IsStim);
    summary.NChoice0 = nnz(data.Choice == 0);
    summary.NChoice1 = nnz(data.Choice == 1);

    data.SessionID = categorical(string(data.UnitTableRow));
    data.StimCondition = categorical(data.StimCondition, ...
        ["NonStim", "Stim"]);
    data.VisualCondition = categorical(data.VisualCondition);
    fitOptions = statset('glmfit');
    fitOptions.MaxIter = options.MaxIterations;
    simpleFormula = ['Choice ~ SessionID * StimCondition + ' ...
        'MeanMSY_Z * StimCondition'];
    adjustedFormula = ['Choice ~ SessionID * StimCondition + ' ...
        'SignedCoherence * VisualCondition + ' ...
        'MeanMSY_Z * StimCondition'];
    vectorFormula = ['Choice ~ SessionID * StimCondition + ' ...
        'SignedCoherence * VisualCondition + ' ...
        'MeanMSX_Z * StimCondition + MeanMSY_Z * StimCondition'];
    summary.SimpleFormula = string(simpleFormula);
    summary.AdjustedFormula = string(adjustedFormula);
    summary.VectorFormula = string(vectorFormula);
    summary.LikelihoodPenalty = string(options.LikelihoodPenalty);

    lastwarn('');
    SimpleModels{iGroup} = fitglm(data, simpleFormula, ...
        'Distribution', 'binomial', ...
        'LikelihoodPenalty', char(options.LikelihoodPenalty), ...
        'Options', fitOptions);
    AdjustedModels{iGroup} = fitglm(data, adjustedFormula, ...
        'Distribution', 'binomial', ...
        'LikelihoodPenalty', char(options.LikelihoodPenalty), ...
        'Options', fitOptions);
    VectorModels{iGroup} = fitglm(data, vectorFormula, ...
        'Distribution', 'binomial', ...
        'LikelihoodPenalty', char(options.LikelihoodPenalty), ...
        'Options', fitOptions);

    summary = addVerticalStatistics(summary, SimpleModels{iGroup}, "Simple");
    summary = addVerticalStatistics(summary, AdjustedModels{iGroup}, "Adjusted");
    summary = addVectorStatistics(summary, VectorModels{iGroup});
    [warningMessage, ~] = lastwarn;
    summary.ModelWarning = string(warningMessage);
    summary.Status = "Complete";
    summaryRows(iGroup) = summary;
    coefficientTables{iGroup} = makeCoefficientTable(summary, ...
        SimpleModels{iGroup}, AdjustedModels{iGroup}, VectorModels{iGroup});
    fprintf('  %s: %d sessions, %d trials.\n', ...
        summary.Group, summary.NSessions, summary.NTrials);
end

GroupSummaryTable = struct2table(summaryRows, 'AsArray', true);
GroupSummaryTable.SimpleInteractionP_Holm = holmBonferroni( ...
    GroupSummaryTable.SimpleInteractionP);
GroupSummaryTable.SimpleAnyEffectP_Holm = holmBonferroni( ...
    GroupSummaryTable.SimpleAnyEffectJointP);
GroupSummaryTable.SimpleAverageSlopeP_Holm = holmBonferroni( ...
    GroupSummaryTable.SimpleAverageSlopeP);
GroupSummaryTable.AdjustedInteractionP_Holm = holmBonferroni( ...
    GroupSummaryTable.AdjustedInteractionP);
GroupSummaryTable.AdjustedAnyEffectP_Holm = holmBonferroni( ...
    GroupSummaryTable.AdjustedAnyEffectJointP);
GroupSummaryTable.AdjustedAverageSlopeP_Holm = holmBonferroni( ...
    GroupSummaryTable.AdjustedAverageSlopeP);
GroupSummaryTable.VectorInteractionP_Holm = holmBonferroni( ...
    GroupSummaryTable.VectorInteractionJointP);
GroupSummaryTable.VectorAnyEffectP_Holm = holmBonferroni( ...
    GroupSummaryTable.VectorAnyEffectJointP);
CoefficientTable = vertcat(coefficientTables{:});

outputFiles = struct( ...
    'Mat', fullfile(outputDir, 'grouped_ms_choice_results.mat'), ...
    'GroupSummaryCSV', fullfile(outputDir, ...
    'grouped_ms_choice_summary.csv'), ...
    'CoefficientCSV', fullfile(outputDir, ...
    'grouped_ms_choice_coefficients.csv'), ...
    'SummaryFigure', fullfile(outputDir, ...
    'grouped_ms_choice_summary.png'));
writetable(GroupSummaryTable, outputFiles.GroupSummaryCSV);
writetable(CoefficientTable, outputFiles.CoefficientCSV);
if options.MakePlots
    makeGroupedSummaryPlot(GroupSummaryTable, outputFiles.SummaryFigure);
else
    outputFiles.SummaryFigure = '';
end

Models = struct;
Models.Simple = SimpleModels;
Models.Adjusted = AdjustedModels;
Models.Vector = VectorModels;
GroupedAnalysis = struct;
GroupedAnalysis.Parameters = options;
GroupedAnalysis.InputFile = resultsFile;
GroupedAnalysis.GroupSummaryTable = GroupSummaryTable;
GroupedAnalysis.CoefficientTable = CoefficientTable;
GroupedAnalysis.Models = Models;
GroupedAnalysis.OutputFiles = outputFiles;
save(outputFiles.Mat, 'GroupedAnalysis', '-v7.3');

fprintf('\nGrouped MS/choice analysis complete.\n');
disp(GroupSummaryTable(:, {'Group', 'NSessions', 'NTrials', ...
    'SimpleInteraction', 'SimpleInteractionP', ...
    'SimpleInteractionP_Holm', 'AdjustedInteraction', ...
    'AdjustedInteractionP', 'AdjustedInteractionP_Holm'}));
fprintf('Results saved to %s\n', outputDir);
end


function trials = standardizeMSWithinSession(trials)
[group, ~] = findgroups(trials.UnitTableRow);
meanX = splitapply(@(x) mean(x, 'omitmissing'), trials.MeanMSXDeg, group);
meanY = splitapply(@(x) mean(x, 'omitmissing'), trials.MeanMSYDeg, group);
scaleX = splitapply(@(x) std(x, 'omitmissing'), trials.MeanMSXDeg, group);
scaleY = splitapply(@(x) std(x, 'omitmissing'), trials.MeanMSYDeg, group);
trials.MeanMSX_Z = (trials.MeanMSXDeg - meanX(group)) ./ scaleX(group);
trials.MeanMSY_Z = (trials.MeanMSYDeg - meanY(group)) ./ scaleY(group);
end


function summary = addVerticalStatistics(summary, model, prefix)
[nonStimSlope, nonStimSE, nonStimP, nonStimWeights] = ...
    componentSlope(model, 'MeanMSY_Z', false);
[stimSlope, stimSE, stimP, stimWeights] = ...
    componentSlope(model, 'MeanMSY_Z', true);
interactionWeights = stimWeights - nonStimWeights;
[interaction, interactionSE, interactionP] = ...
    linearContrast(model, interactionWeights);
averageWeights = 0.5 * (nonStimWeights + stimWeights);
[averageSlope, averageSlopeSE, averageSlopeP] = ...
    linearContrast(model, averageWeights);
summary.(prefix + "NonStimSlope") = nonStimSlope;
summary.(prefix + "NonStimSlopeSE") = nonStimSE;
summary.(prefix + "NonStimSlopeP") = nonStimP;
summary.(prefix + "NonStimOddsRatio") = exp(nonStimSlope);
summary.(prefix + "StimSlope") = stimSlope;
summary.(prefix + "StimSlopeSE") = stimSE;
summary.(prefix + "StimSlopeP") = stimP;
summary.(prefix + "StimOddsRatio") = exp(stimSlope);
summary.(prefix + "Interaction") = interaction;
summary.(prefix + "InteractionSE") = interactionSE;
summary.(prefix + "InteractionP") = interactionP;
summary.(prefix + "AverageSlope") = averageSlope;
summary.(prefix + "AverageSlopeSE") = averageSlopeSE;
summary.(prefix + "AverageSlopeP") = averageSlopeP;
summary.(prefix + "AnyEffectJointP") = jointContrast(model, ...
    [nonStimWeights; interactionWeights]);
end


function summary = addVectorStatistics(summary, model)
[~, ~, ~, xNonStim] = componentSlope(model, 'MeanMSX_Z', false);
[~, ~, ~, xStim] = componentSlope(model, 'MeanMSX_Z', true);
[~, ~, ~, yNonStim] = componentSlope(model, 'MeanMSY_Z', false);
[~, ~, ~, yStim] = componentSlope(model, 'MeanMSY_Z', true);
summary.VectorNonStimJointP = jointContrast(model, [xNonStim; yNonStim]);
summary.VectorStimJointP = jointContrast(model, [xStim; yStim]);
summary.VectorInteractionJointP = jointContrast(model, ...
    [xStim - xNonStim; yStim - yNonStim]);
summary.VectorAnyEffectJointP = jointContrast(model, ...
    [xNonStim; xStim - xNonStim; yNonStim; yStim - yNonStim]);
end


function [estimate, standardError, pValue, weights] = ...
        componentSlope(model, componentName, isStim)
names = string(model.CoefficientNames(:));
weights = zeros(1, numel(names));
mainIndex = find(names == componentName, 1);
assert(~isempty(mainIndex), 'Coefficient %s was not found.', componentName);
weights(mainIndex) = 1;
if isStim
    interactionIndex = find(contains(names, componentName) & ...
        contains(names, 'StimCondition_Stim') & contains(names, ':'), 1);
    assert(~isempty(interactionIndex), ...
        'Stim interaction for %s was not found.', componentName);
    weights(interactionIndex) = 1;
end
[estimate, standardError, pValue] = linearContrast(model, weights);
end


function [estimate, standardError, pValue] = linearContrast(model, weights)
weights = weights(:);
beta = model.Coefficients.Estimate;
covariance = model.CoefficientCovariance;
estimate = weights' * beta;
standardError = sqrt(max(0, weights' * covariance * weights));
if standardError > 0 && isfinite(standardError)
    pValue = 2 * normcdf(-abs(estimate / standardError));
else
    pValue = NaN;
end
end


function pValue = jointContrast(model, weights)
try
    pValue = coefTest(model, weights);
catch
    pValue = NaN;
end
end


function output = makeCoefficientTable(summary, simple, adjusted, vector)
models = {simple, adjusted, vector};
modelNames = ["Simple"; "Adjusted"; "Vector"];
parts = cell(3, 1);
for iModel = 1:3
    coefficients = models{iModel}.Coefficients;
    n = height(coefficients);
    parts{iModel} = table(repmat(summary.GroupIndex, n, 1), ...
        repmat(summary.Group, n, 1), repmat(summary.Monkey, n, 1), ...
        repmat(summary.ROI, n, 1), repmat(modelNames(iModel), n, 1), ...
        string(coefficients.Properties.RowNames), coefficients.Estimate, ...
        coefficients.SE, coefficients.tStat, coefficients.pValue, ...
        'VariableNames', {'GroupIndex', 'Group', 'Monkey', 'ROI', ...
        'Model', 'Coefficient', 'Estimate', 'SE', 'Z', 'PValue'});
end
output = vertcat(parts{:});
end


function row = makeGroupSummaryRow()
row = struct( ...
    'GroupIndex', NaN, 'Group', "", 'Monkey', "", 'ROI', "", ...
    'Status', "", 'ModelWarning', "", 'NSessions', NaN, ...
    'NTrials', NaN, 'NNonStimTrials', NaN, 'NStimTrials', NaN, ...
    'NChoice0', NaN, 'NChoice1', NaN, 'SimpleFormula', "", ...
    'AdjustedFormula', "", 'VectorFormula', "", ...
    'LikelihoodPenalty', "", ...
    'SimpleNonStimSlope', NaN, 'SimpleNonStimSlopeSE', NaN, ...
    'SimpleNonStimSlopeP', NaN, 'SimpleNonStimOddsRatio', NaN, ...
    'SimpleStimSlope', NaN, 'SimpleStimSlopeSE', NaN, ...
    'SimpleStimSlopeP', NaN, 'SimpleStimOddsRatio', NaN, ...
    'SimpleInteraction', NaN, 'SimpleInteractionSE', NaN, ...
    'SimpleInteractionP', NaN, 'SimpleAnyEffectJointP', NaN, ...
    'SimpleAverageSlope', NaN, 'SimpleAverageSlopeSE', NaN, ...
    'SimpleAverageSlopeP', NaN, ...
    'AdjustedNonStimSlope', NaN, 'AdjustedNonStimSlopeSE', NaN, ...
    'AdjustedNonStimSlopeP', NaN, 'AdjustedNonStimOddsRatio', NaN, ...
    'AdjustedStimSlope', NaN, 'AdjustedStimSlopeSE', NaN, ...
    'AdjustedStimSlopeP', NaN, 'AdjustedStimOddsRatio', NaN, ...
    'AdjustedInteraction', NaN, 'AdjustedInteractionSE', NaN, ...
    'AdjustedInteractionP', NaN, 'AdjustedAnyEffectJointP', NaN, ...
    'AdjustedAverageSlope', NaN, 'AdjustedAverageSlopeSE', NaN, ...
    'AdjustedAverageSlopeP', NaN, ...
    'VectorNonStimJointP', NaN, 'VectorStimJointP', NaN, ...
    'VectorInteractionJointP', NaN, 'VectorAnyEffectJointP', NaN);
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


function makeGroupedSummaryPlot(summary, outputFile)
labels = categorical(summary.Group, summary.Group, 'Ordinal', true);
colors = [0.20 0.45 0.75; 0.25 0.65 0.45];
fig = figure('Color', 'w', 'Visible', 'off', ...
    'Position', [100 100 1250 850]);
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');

ax = nexttile(layout);
hold(ax, 'on');
errorbar(ax, (1:4) - 0.10, summary.SimpleNonStimSlope, ...
    summary.SimpleNonStimSlopeSE, 'o', 'Color', colors(1, :), ...
    'MarkerFaceColor', colors(1, :), 'DisplayName', 'NonStim');
errorbar(ax, (1:4) + 0.10, summary.SimpleStimSlope, ...
    summary.SimpleStimSlopeSE, 'o', 'Color', colors(2, :), ...
    'MarkerFaceColor', colors(2, :), 'DisplayName', 'Stim');
yline(ax, 0, ':', 'HandleVisibility', 'off');
set(ax, 'XTick', 1:4, 'XTickLabel', labels);
xlim(ax, [0.5, 4.5]);
ylabel(ax, 'MS_y slope (log odds / SD)');
title(ax, 'Session-stratified simple model');
legend(ax, 'Location', 'best');
grid(ax, 'on');

ax = nexttile(layout);
hold(ax, 'on');
errorbar(ax, (1:4) - 0.10, summary.AdjustedNonStimSlope, ...
    summary.AdjustedNonStimSlopeSE, 'o', 'Color', colors(1, :), ...
    'MarkerFaceColor', colors(1, :), 'DisplayName', 'NonStim');
errorbar(ax, (1:4) + 0.10, summary.AdjustedStimSlope, ...
    summary.AdjustedStimSlopeSE, 'o', 'Color', colors(2, :), ...
    'MarkerFaceColor', colors(2, :), 'DisplayName', 'Stim');
yline(ax, 0, ':', 'HandleVisibility', 'off');
set(ax, 'XTick', 1:4, 'XTickLabel', labels);
xlim(ax, [0.5, 4.5]);
ylabel(ax, 'MS_y slope (log odds / SD)');
title(ax, 'Session-stratified adjusted model');
legend(ax, 'Location', 'best');
grid(ax, 'on');

ax = nexttile(layout);
hold(ax, 'on');
errorbar(ax, (1:4) - 0.10, summary.SimpleInteraction, ...
    summary.SimpleInteractionSE, 'o', 'Color', colors(1, :), ...
    'MarkerFaceColor', colors(1, :), 'DisplayName', 'Simple');
errorbar(ax, (1:4) + 0.10, summary.AdjustedInteraction, ...
    summary.AdjustedInteractionSE, 'o', 'Color', colors(2, :), ...
    'MarkerFaceColor', colors(2, :), 'DisplayName', 'Adjusted');
yline(ax, 0, ':', 'HandleVisibility', 'off');
set(ax, 'XTick', 1:4, 'XTickLabel', labels);
xlim(ax, [0.5, 4.5]);
ylabel(ax, 'MS_y x Stim coefficient');
title(ax, 'Stim modulation of the MS effect');
legend(ax, 'Location', 'best');
grid(ax, 'on');

ax = nexttile(layout);
bar(ax, 1:4, -log10(max([summary.SimpleInteractionP, ...
    summary.AdjustedInteractionP], realmin)));
hold(ax, 'on');
yline(ax, -log10(0.05), '--r', 'HandleVisibility', 'off');
set(ax, 'XTick', 1:4, 'XTickLabel', labels);
xlim(ax, [0.5, 4.5]);
ylabel(ax, '-log_{10}(raw interaction p)');
title(ax, sprintf('Raw evidence (Holm significant: %d simple, %d adjusted)', ...
    nnz(summary.SimpleInteractionP_Holm < 0.05), ...
    nnz(summary.AdjustedInteractionP_Holm < 0.05)));
legend(ax, {'Simple', 'Adjusted'}, 'Location', 'best');
grid(ax, 'on');

title(layout, 'Trial-level MS prediction of choice pooled by monkey and area');
exportgraphics(fig, outputFile, 'Resolution', 180);
close(fig);
end

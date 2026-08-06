function PooledLogisticAnalysis = analyze_pooled_logistic_ms_choice(varargin)
%ANALYZE_POOLED_LOGISTIC_MS_CHOICE Fit the exact pooled MS_y-by-Stim model.
%
% For Jim-MT, Jim-FST, Clay-MT, and Clay-FST, this function fits:
%
%   logit(P(Choice = 1)) = b0 + bMS*MeanMSY_Z + bStim*Stim ...
%       + bMSxStim*MeanMSY_Z*Stim
%
% MeanMSY_Z is the trial-average vertical microsaccade displacement,
% standardized within recording session before trials are pooled. This
% deliberately unstratified model treats trial rows as independent. A
% comparison with the existing session-stratified simple model is exported
% when GroupedResultsFile is available.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'TrialwiseResultsFile', ...
    ['C:\EM\Microsac\population_merged_12ms_no_smoothing\' ...
    'population_analysis\trialwise_ms_choice\' ...
    'trialwise_ms_choice_results.mat'], ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'GroupedResultsFile', ...
    ['C:\EM\Microsac\population_merged_12ms_no_smoothing\' ...
    'population_analysis\grouped_monkey_roi_ms_choice\' ...
    'grouped_ms_choice_results.mat'], ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'OutputDir', ...
    ['C:\EM\Microsac\population_merged_12ms_no_smoothing\' ...
    'population_analysis\grouped_monkey_roi_ms_choice\' ...
    'pooled_logistic'], ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'LikelihoodPenalty', "jeffreys-prior", ...
    @(x) any(strcmpi(string(x), ["none", "jeffreys-prior"])));
addParameter(parser, 'MaxIterations', 1000, ...
    @(x) isscalar(x) && isfinite(x) && x >= 100 && mod(x, 1) == 0);
addParameter(parser, 'BinCount', 12, ...
    @(x) isscalar(x) && isfinite(x) && x >= 6 && mod(x, 1) == 0);
addParameter(parser, 'MakePlots', true, ...
    @(x) islogical(x) && isscalar(x));
parse(parser, varargin{:});
options = parser.Results;

trialwiseFile = char(options.TrialwiseResultsFile);
groupedFile = char(options.GroupedResultsFile);
outputDir = char(options.OutputDir);
assert(isfile(trialwiseFile), ...
    'Trialwise result MAT not found: %s', trialwiseFile);
if ~isfolder(outputDir)
    mkdir(outputDir);
end

saved = load(trialwiseFile, 'Analysis');
assert(isfield(saved, 'Analysis') && isfield(saved.Analysis, 'TrialTable'), ...
    'Input MAT must contain Analysis.TrialTable.');
trials = saved.Analysis.TrialTable;
required = {'UnitTableRow', 'Monkey', 'ROI', 'Choice', 'IsStim', ...
    'StimCondition', 'SignedCoherence', 'MeanMSXDeg', 'MeanMSYDeg', ...
    'UsableForModel'};
assert(all(ismember(required, trials.Properties.VariableNames)), ...
    'The trialwise table is missing required variables.');

% Match the trial sample used by analyze_grouped_ms_choice exactly so that
% pooled-versus-session-stratified comparisons isolate the model structure.
valid = trials.UsableForModel & ismember(trials.Choice, [0, 1]) & ...
    isfinite(trials.SignedCoherence) & isfinite(trials.MeanMSXDeg) & ...
    isfinite(trials.MeanMSYDeg);
trials = standardizeMSWithinSession(trials(valid, :));
trials = trials(isfinite(trials.MeanMSX_Z) & ...
    isfinite(trials.MeanMSY_Z), :);

groupMonkey = ["Jim"; "Jim"; "Clay"; "Clay"];
groupROI = ["MT"; "FST"; "MT"; "FST"];
nGroups = numel(groupMonkey);
summaryRows = repmat(makeSummaryRow(), nGroups, 1);
coefficientTables = cell(nGroups, 1);
models = cell(nGroups, 1);
groupData = cell(nGroups, 1);
formula = 'Choice ~ MeanMSY_Z * StimCondition';

fprintf(['Fitting exact pooled logistic MS_y-by-Stim models for %d ' ...
    'monkey/ROI groups.\n'], nGroups);
for iGroup = 1:nGroups
    mask = strcmpi(trials.Monkey, groupMonkey(iGroup)) & ...
        strcmpi(trials.ROI, groupROI(iGroup));
    data = trials(mask, :);
    assert(height(data) > 0, 'No trials found for %s-%s.', ...
        groupMonkey(iGroup), groupROI(iGroup));
    data.StimCondition = categorical(data.StimCondition, ...
        ["NonStim", "Stim"]);

    summary = makeSummaryRow();
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
    summary.Formula = string(formula);
    summary.PredictorScale = "within-session SD";
    summary.LikelihoodPenalty = string(options.LikelihoodPenalty);
    summary.IndependenceAssumption = ...
        "trial rows treated as independent; no SessionID term";

    fitOptions = statset('glmfit');
    fitOptions.MaxIter = options.MaxIterations;
    lastwarn('');
    models{iGroup} = fitglm(data, formula, ...
        'Distribution', 'binomial', ...
        'LikelihoodPenalty', char(options.LikelihoodPenalty), ...
        'Options', fitOptions);
    [warningMessage, ~] = lastwarn;
    summary.ModelWarning = string(warningMessage);
    summary = addModelStatistics(summary, models{iGroup});
    summary.Status = "Complete";

    summaryRows(iGroup) = summary;
    coefficientTables{iGroup} = makeCoefficientTable( ...
        summary, models{iGroup});
    groupData{iGroup} = data;
    fprintf('  %s: %d sessions, %d trials.\n', ...
        summary.Group, summary.NSessions, summary.NTrials);
end

SummaryTable = struct2table(summaryRows, 'AsArray', true);
SummaryTable.AverageSlopeP_Holm = holmBonferroni( ...
    SummaryTable.AverageSlopeP);
SummaryTable.InteractionP_Holm = holmBonferroni( ...
    SummaryTable.InteractionP);
SummaryTable.AnyMSEffectJointP_Holm = holmBonferroni( ...
    SummaryTable.AnyMSEffectJointP);
CoefficientTable = vertcat(coefficientTables{:});

outputFiles = struct( ...
    'Mat', fullfile(outputDir, 'pooled_logistic_ms_choice_results.mat'), ...
    'SummaryCSV', fullfile(outputDir, ...
    'pooled_logistic_ms_choice_summary.csv'), ...
    'CoefficientCSV', fullfile(outputDir, ...
    'pooled_logistic_ms_choice_coefficients.csv'), ...
    'ProbabilityFigure', fullfile(outputDir, ...
    'pooled_logistic_ms_y_choice_probability.png'), ...
    'EffectFigure', fullfile(outputDir, ...
    'pooled_logistic_ms_y_effects_95ci.png'), ...
    'ComparisonCSV', '', 'ComparisonFigure', '');
writetable(SummaryTable, outputFiles.SummaryCSV);
writetable(CoefficientTable, outputFiles.CoefficientCSV);

ComparisonTable = table;
if isfile(groupedFile)
    groupedSaved = load(groupedFile, 'GroupedAnalysis');
    assert(isfield(groupedSaved, 'GroupedAnalysis'), ...
        'Grouped result MAT must contain GroupedAnalysis.');
    stratifiedSummary = groupedSaved.GroupedAnalysis.GroupSummaryTable;
    ComparisonTable = makeComparisonTable(SummaryTable, stratifiedSummary);
    outputFiles.ComparisonCSV = fullfile(outputDir, ...
        'pooled_vs_session_stratified_summary.csv');
    outputFiles.ComparisonFigure = fullfile(outputDir, ...
        'pooled_vs_session_stratified_ms_y_effects_95ci.png');
    writetable(ComparisonTable, outputFiles.ComparisonCSV);
end

if options.MakePlots
    makeProbabilityFigure(groupData, models, SummaryTable, ...
        options.BinCount, outputFiles.ProbabilityFigure);
    makeEffectFigure(SummaryTable, outputFiles.EffectFigure);
    if ~isempty(ComparisonTable)
        makeComparisonFigure(ComparisonTable, ...
            outputFiles.ComparisonFigure);
    end
else
    outputFiles.ProbabilityFigure = '';
    outputFiles.EffectFigure = '';
    outputFiles.ComparisonFigure = '';
end

PooledLogisticAnalysis = struct;
PooledLogisticAnalysis.Parameters = options;
PooledLogisticAnalysis.InputFile = trialwiseFile;
PooledLogisticAnalysis.ResponseDefinition = ...
    "Choice = decoded binary behavioral choice direction (0/1)";
PooledLogisticAnalysis.PredictorDefinition = ...
    "MeanMSY_Z = trial-average vertical MS displacement in within-session SD";
PooledLogisticAnalysis.ModelFormula = string(formula);
PooledLogisticAnalysis.SummaryTable = SummaryTable;
PooledLogisticAnalysis.CoefficientTable = CoefficientTable;
PooledLogisticAnalysis.ComparisonTable = ComparisonTable;
PooledLogisticAnalysis.Models = models;
PooledLogisticAnalysis.OutputFiles = outputFiles;
save(outputFiles.Mat, 'PooledLogisticAnalysis', '-v7.3');

fprintf('\nExact pooled logistic analysis complete.\n');
disp(SummaryTable(:, {'Group', 'NSessions', 'NTrials', ...
    'AverageSlope', 'AverageSlopeP', 'AverageSlopeP_Holm', ...
    'Interaction', 'InteractionP', 'InteractionP_Holm'}));
fprintf('Results saved to %s\n', outputDir);
end


function trials = standardizeMSWithinSession(trials)
[group, ~] = findgroups(trials.UnitTableRow);
meanX = splitapply(@(x) mean(x, 'omitmissing'), ...
    trials.MeanMSXDeg, group);
meanY = splitapply(@(x) mean(x, 'omitmissing'), ...
    trials.MeanMSYDeg, group);
scaleX = splitapply(@(x) std(x, 'omitmissing'), ...
    trials.MeanMSXDeg, group);
scaleY = splitapply(@(x) std(x, 'omitmissing'), ...
    trials.MeanMSYDeg, group);
trials.MeanMSX_Z = ...
    (trials.MeanMSXDeg - meanX(group)) ./ scaleX(group);
trials.MeanMSY_Z = ...
    (trials.MeanMSYDeg - meanY(group)) ./ scaleY(group);
end


function summary = addModelStatistics(summary, model)
[nonStimSlope, nonStimSE, nonStimP, nonStimWeights] = ...
    componentSlope(model, false);
[stimSlope, stimSE, stimP, stimWeights] = ...
    componentSlope(model, true);
interactionWeights = stimWeights - nonStimWeights;
[interaction, interactionSE, interactionP] = ...
    linearContrast(model, interactionWeights);
averageWeights = 0.5 .* (nonStimWeights + stimWeights);
[averageSlope, averageSlopeSE, averageSlopeP] = ...
    linearContrast(model, averageWeights);

summary.NonStimSlope = nonStimSlope;
summary.NonStimSlopeSE = nonStimSE;
summary.NonStimSlopeP = nonStimP;
summary.NonStimOddsRatio = exp(nonStimSlope);
summary.NonStimOddsRatioLower95 = exp(nonStimSlope - 1.96 .* nonStimSE);
summary.NonStimOddsRatioUpper95 = exp(nonStimSlope + 1.96 .* nonStimSE);
summary.StimSlope = stimSlope;
summary.StimSlopeSE = stimSE;
summary.StimSlopeP = stimP;
summary.StimOddsRatio = exp(stimSlope);
summary.StimOddsRatioLower95 = exp(stimSlope - 1.96 .* stimSE);
summary.StimOddsRatioUpper95 = exp(stimSlope + 1.96 .* stimSE);
summary.AverageSlope = averageSlope;
summary.AverageSlopeSE = averageSlopeSE;
summary.AverageSlopeP = averageSlopeP;
summary.AverageOddsRatio = exp(averageSlope);
summary.AverageOddsRatioLower95 = ...
    exp(averageSlope - 1.96 .* averageSlopeSE);
summary.AverageOddsRatioUpper95 = ...
    exp(averageSlope + 1.96 .* averageSlopeSE);
summary.Interaction = interaction;
summary.InteractionSE = interactionSE;
summary.InteractionP = interactionP;
summary.InteractionOddsRatio = exp(interaction);
summary.InteractionOddsRatioLower95 = ...
    exp(interaction - 1.96 .* interactionSE);
summary.InteractionOddsRatioUpper95 = ...
    exp(interaction + 1.96 .* interactionSE);
summary.AnyMSEffectJointP = jointContrast(model, ...
    [nonStimWeights; interactionWeights]);
end


function [estimate, standardError, pValue, weights] = ...
        componentSlope(model, isStim)
names = string(model.CoefficientNames(:));
weights = zeros(1, numel(names));
mainIndex = find(names == "MeanMSY_Z", 1);
assert(~isempty(mainIndex), 'Coefficient MeanMSY_Z was not found.');
weights(mainIndex) = 1;
if isStim
    interactionIndex = find(contains(names, 'MeanMSY_Z') & ...
        contains(names, 'StimCondition_Stim') & contains(names, ':'), 1);
    assert(~isempty(interactionIndex), ...
        'MeanMSY_Z-by-Stim interaction coefficient was not found.');
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
    pValue = 2 .* normcdf(-abs(estimate ./ standardError));
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


function output = makeCoefficientTable(summary, model)
coefficients = model.Coefficients;
n = height(coefficients);
estimate = coefficients.Estimate;
standardError = coefficients.SE;
output = table(repmat(summary.GroupIndex, n, 1), ...
    repmat(summary.Group, n, 1), repmat(summary.Monkey, n, 1), ...
    repmat(summary.ROI, n, 1), ...
    string(coefficients.Properties.RowNames), estimate, standardError, ...
    coefficients.tStat, coefficients.pValue, exp(estimate), ...
    exp(estimate - 1.96 .* standardError), ...
    exp(estimate + 1.96 .* standardError), ...
    'VariableNames', {'GroupIndex', 'Group', 'Monkey', 'ROI', ...
    'Coefficient', 'Estimate', 'SE', 'Z', 'PValue', 'OddsRatio', ...
    'OddsRatioLower95', 'OddsRatioUpper95'});
end


function row = makeSummaryRow()
row = struct( ...
    'GroupIndex', NaN, 'Group', "", 'Monkey', "", 'ROI', "", ...
    'Status', "", 'ModelWarning', "", 'NSessions', NaN, ...
    'NTrials', NaN, 'NNonStimTrials', NaN, 'NStimTrials', NaN, ...
    'NChoice0', NaN, 'NChoice1', NaN, 'Formula', "", ...
    'PredictorScale', "", 'LikelihoodPenalty', "", ...
    'IndependenceAssumption', "", ...
    'NonStimSlope', NaN, 'NonStimSlopeSE', NaN, ...
    'NonStimSlopeP', NaN, 'NonStimOddsRatio', NaN, ...
    'NonStimOddsRatioLower95', NaN, 'NonStimOddsRatioUpper95', NaN, ...
    'StimSlope', NaN, 'StimSlopeSE', NaN, 'StimSlopeP', NaN, ...
    'StimOddsRatio', NaN, 'StimOddsRatioLower95', NaN, ...
    'StimOddsRatioUpper95', NaN, ...
    'AverageSlope', NaN, 'AverageSlopeSE', NaN, ...
    'AverageSlopeP', NaN, 'AverageOddsRatio', NaN, ...
    'AverageOddsRatioLower95', NaN, 'AverageOddsRatioUpper95', NaN, ...
    'Interaction', NaN, 'InteractionSE', NaN, 'InteractionP', NaN, ...
    'InteractionOddsRatio', NaN, ...
    'InteractionOddsRatioLower95', NaN, ...
    'InteractionOddsRatioUpper95', NaN, ...
    'AnyMSEffectJointP', NaN);
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


function comparison = makeComparisonTable(pooled, stratified)
[found, location] = ismember(pooled.Group, stratified.Group);
assert(all(found), ...
    'The grouped result does not contain every pooled monkey/ROI group.');
stratified = stratified(location, :);
comparison = table(pooled.Group, pooled.Monkey, pooled.ROI, ...
    pooled.NSessions, pooled.NTrials, ...
    pooled.AverageSlope, pooled.AverageSlopeSE, ...
    pooled.AverageSlopeP, pooled.AverageSlopeP_Holm, ...
    stratified.SimpleAverageSlope, ...
    stratified.SimpleAverageSlopeSE, ...
    stratified.SimpleAverageSlopeP, ...
    stratified.SimpleAverageSlopeP_Holm, ...
    pooled.Interaction, pooled.InteractionSE, ...
    pooled.InteractionP, pooled.InteractionP_Holm, ...
    stratified.SimpleInteraction, ...
    stratified.SimpleInteractionSE, ...
    stratified.SimpleInteractionP, ...
    stratified.SimpleInteractionP_Holm, ...
    'VariableNames', {'Group', 'Monkey', 'ROI', 'NSessions', 'NTrials', ...
    'PooledAverageSlope', 'PooledAverageSlopeSE', ...
    'PooledAverageSlopeP', 'PooledAverageSlopeP_Holm', ...
    'StratifiedAverageSlope', 'StratifiedAverageSlopeSE', ...
    'StratifiedAverageSlopeP', 'StratifiedAverageSlopeP_Holm', ...
    'PooledInteraction', 'PooledInteractionSE', ...
    'PooledInteractionP', 'PooledInteractionP_Holm', ...
    'StratifiedInteraction', 'StratifiedInteractionSE', ...
    'StratifiedInteractionP', 'StratifiedInteractionP_Holm'});
end


function makeProbabilityFigure(groupData, models, summary, ...
        binCount, outputFile)
nonStimColor = [0.18 0.45 0.78];
stimColor = [0.90 0.35 0.12];
fig = figure('Color', 'w', 'Visible', 'off', ...
    'Position', [100 100 1350 900]);
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
for iGroup = 1:height(summary)
    ax = nexttile(layout);
    plotProbabilityPanel(ax, groupData{iGroup}, models{iGroup}, ...
        summary(iGroup, :), binCount, nonStimColor, stimColor);
end
title(layout, ['Exact pooled logistic model: observed and fitted ' ...
    'choice probability']);
exportgraphics(fig, outputFile, 'Resolution', 200);
close(fig);
end


function plotProbabilityPanel(ax, data, model, summaryRow, ...
        binCount, nonStimColor, stimColor)
hold(ax, 'on');
x = data.MeanMSY_Z;
edges = unique(quantile(x, linspace(0, 1, binCount + 1)));
edges(1) = -Inf;
edges(end) = Inf;
bin = discretize(x, edges);
conditions = {~data.IsStim, data.IsStim};
colors = [nonStimColor; stimColor];
conditionNames = ["NonStim", "Stim"];

for iCondition = 1:2
    xMean = nan(numel(edges) - 1, 1);
    probability = nan(numel(edges) - 1, 1);
    lower = nan(numel(edges) - 1, 1);
    upper = nan(numel(edges) - 1, 1);
    for iBin = 1:(numel(edges) - 1)
        mask = conditions{iCondition} & bin == iBin;
        if nnz(mask) == 0
            continue
        end
        xMean(iBin) = mean(x(mask));
        successes = sum(data.Choice(mask));
        [probability(iBin), lower(iBin), upper(iBin)] = ...
            wilsonInterval(successes, nnz(mask));
    end
    errorbar(ax, xMean, probability, probability - lower, ...
        upper - probability, 'o', 'LineStyle', 'none', ...
        'Color', colors(iCondition, :), ...
        'MarkerFaceColor', colors(iCondition, :), 'MarkerSize', 5, ...
        'CapSize', 3, 'HandleVisibility', 'off');
end

xLimits = quantile(x, [0.005, 0.995]);
xGrid = linspace(xLimits(1), xLimits(2), 250)';
for iCondition = 1:2
    predictor = table(xGrid, categorical( ...
        repmat(conditionNames(iCondition), numel(xGrid), 1), ...
        ["NonStim", "Stim"]), ...
        'VariableNames', {'MeanMSY_Z', 'StimCondition'});
    probabilityGrid = predict(model, predictor);
    plot(ax, xGrid, probabilityGrid, '-', ...
        'Color', colors(iCondition, :), 'LineWidth', 2.2, ...
        'DisplayName', conditionNames(iCondition) + " fitted");
end

xline(ax, 0, ':', 'Color', [0.35 0.35 0.35], ...
    'HandleVisibility', 'off');
xlim(ax, xLimits);
ylim(ax, [0, 1]);
xlabel(ax, 'MeanMSY_Z (within-session SD)');
ylabel(ax, 'P(Choice = 1)');
title(ax, {sprintf('%s (%d sessions; %s trials)', ...
    summaryRow.Group, summaryRow.NSessions, ...
    formatThousands(summaryRow.NTrials)), ...
    sprintf(['average slope p = %.3g (Holm %.3g); ' ...
    'MS_y x Stim p = %.3g (Holm %.3g)'], ...
    summaryRow.AverageSlopeP, summaryRow.AverageSlopeP_Holm, ...
    summaryRow.InteractionP, summaryRow.InteractionP_Holm)});
legend(ax, 'Location', 'best');
grid(ax, 'on');
box(ax, 'on');
end


function text = formatThousands(value)
text = regexprep(sprintf('%.0f', value), ...
    '(?<=\d)(?=(\d{3})+$)', ',');
end


function [proportion, lower, upper] = wilsonInterval(successes, n)
z = 1.95996398454005;
proportion = successes ./ n;
denominator = 1 + z^2 ./ n;
center = (proportion + z^2 ./ (2 .* n)) ./ denominator;
halfWidth = z .* sqrt(proportion .* (1 - proportion) ./ n + ...
    z^2 ./ (4 .* n^2)) ./ denominator;
lower = max(0, center - halfWidth);
upper = min(1, center + halfWidth);
end


function makeEffectFigure(summary, outputFile)
labels = categorical(summary.Group, summary.Group, 'Ordinal', true);
nonStimColor = [0.18 0.45 0.78];
stimColor = [0.90 0.35 0.12];
averageColor = [0.22 0.55 0.34];
interactionColor = [0.55 0.20 0.65];
fig = figure('Color', 'w', 'Visible', 'off', ...
    'Position', [100 100 1250 850]);
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');

ax = nexttile(layout);
plotOneEstimate(ax, summary.AverageSlope, ...
    summary.AverageSlopeSE, averageColor, labels);
ylabel(ax, 'Average MS_y slope (log odds / SD)');
title(ax, sprintf('Does MS_y predict choice? (Holm p < .05: %d/4)', ...
    nnz(summary.AverageSlopeP_Holm < 0.05)));

ax = nexttile(layout);
plotOneEstimate(ax, summary.Interaction, ...
    summary.InteractionSE, interactionColor, labels);
ylabel(ax, 'MS_y x Stim coefficient');
title(ax, sprintf(['Is the MS_y effect modulated by Stim? ' ...
    '(Holm p < .05: %d/4)'], nnz(summary.InteractionP_Holm < 0.05)));

ax = nexttile(layout);
hold(ax, 'on');
plotTwoEstimates(ax, summary.NonStimSlope, summary.NonStimSlopeSE, ...
    summary.StimSlope, summary.StimSlopeSE, nonStimColor, stimColor, labels);
ylabel(ax, 'MS_y slope (log odds / SD)');
title(ax, 'Condition-specific slopes (95% CI)');
legend(ax, {'NonStim', 'Stim'}, 'Location', 'best');

ax = nexttile(layout);
hold(ax, 'on');
plotOddsRatios(ax, summary, nonStimColor, stimColor, labels);
ylabel(ax, 'Odds ratio per 1 within-session SD');
title(ax, 'Condition-specific odds ratios (95% CI)');
legend(ax, {'NonStim', 'Stim'}, 'Location', 'best');

title(layout, ['Exact pooled logistic MS_y-by-Stim model: ' ...
    'estimates and 95% confidence intervals']);
exportgraphics(fig, outputFile, 'Resolution', 200);
close(fig);
end


function makeComparisonFigure(comparison, outputFile)
labels = categorical(comparison.Group, comparison.Group, 'Ordinal', true);
pooledColor = [0.80 0.32 0.12];
stratifiedColor = [0.18 0.45 0.78];
fig = figure('Color', 'w', 'Visible', 'off', ...
    'Position', [100 100 1250 560]);
layout = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');

ax = nexttile(layout);
hold(ax, 'on');
plotTwoEstimates(ax, comparison.PooledAverageSlope, ...
    comparison.PooledAverageSlopeSE, ...
    comparison.StratifiedAverageSlope, ...
    comparison.StratifiedAverageSlopeSE, pooledColor, ...
    stratifiedColor, labels);
ylabel(ax, 'Average MS_y slope (log odds / SD)');
title(ax, 'Does MS_y predict choice? (95% CI)');
legend(ax, {'Exact pooled', 'Session-stratified'}, 'Location', 'best');

ax = nexttile(layout);
hold(ax, 'on');
plotTwoEstimates(ax, comparison.PooledInteraction, ...
    comparison.PooledInteractionSE, ...
    comparison.StratifiedInteraction, ...
    comparison.StratifiedInteractionSE, pooledColor, ...
    stratifiedColor, labels);
ylabel(ax, 'MS_y x Stim coefficient');
title(ax, 'Is the MS_y effect modulated by Stim? (95% CI)');
legend(ax, {'Exact pooled', 'Session-stratified'}, 'Location', 'best');

title(layout, ['Model comparison: exact pooled logistic versus ' ...
    'session-specific intercepts']);
exportgraphics(fig, outputFile, 'Resolution', 200);
close(fig);
end


function plotOneEstimate(ax, estimate, standardError, color, labels)
hold(ax, 'on');
errorbar(ax, 1:4, estimate, 1.96 .* standardError, 'o', ...
    'Color', color, 'MarkerFaceColor', color, 'LineWidth', 1.2);
yline(ax, 0, ':', 'HandleVisibility', 'off');
set(ax, 'XTick', 1:4, 'XTickLabel', labels);
xlim(ax, [0.5, 4.5]);
grid(ax, 'on');
box(ax, 'on');
end


function plotTwoEstimates(ax, estimate1, se1, estimate2, se2, ...
        color1, color2, labels)
errorbar(ax, (1:4) - 0.10, estimate1, 1.96 .* se1, 'o', ...
    'Color', color1, 'MarkerFaceColor', color1, 'LineWidth', 1.2);
errorbar(ax, (1:4) + 0.10, estimate2, 1.96 .* se2, 'o', ...
    'Color', color2, 'MarkerFaceColor', color2, 'LineWidth', 1.2);
yline(ax, 0, ':', 'HandleVisibility', 'off');
set(ax, 'XTick', 1:4, 'XTickLabel', labels);
xlim(ax, [0.5, 4.5]);
grid(ax, 'on');
box(ax, 'on');
end


function plotOddsRatios(ax, summary, nonStimColor, stimColor, labels)
nonStim = summary.NonStimOddsRatio;
stim = summary.StimOddsRatio;
errorbar(ax, (1:4) - 0.10, nonStim, ...
    nonStim - summary.NonStimOddsRatioLower95, ...
    summary.NonStimOddsRatioUpper95 - nonStim, 'o', ...
    'Color', nonStimColor, 'MarkerFaceColor', nonStimColor, ...
    'LineWidth', 1.2);
errorbar(ax, (1:4) + 0.10, stim, ...
    stim - summary.StimOddsRatioLower95, ...
    summary.StimOddsRatioUpper95 - stim, 'o', ...
    'Color', stimColor, 'MarkerFaceColor', stimColor, ...
    'LineWidth', 1.2);
yline(ax, 1, ':', 'HandleVisibility', 'off');
set(ax, 'XTick', 1:4, 'XTickLabel', labels);
xlim(ax, [0.5, 4.5]);
grid(ax, 'on');
box(ax, 'on');
end

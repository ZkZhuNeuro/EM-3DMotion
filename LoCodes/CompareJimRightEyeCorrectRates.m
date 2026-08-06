%% Compare Jim right-eye perspective-cue correct rates
% This script compares Jim's right-eye perspective cue (MonoR, condition 3)
% against the other cue conditions using correct rates from psychometric
% count data: [coherence, chose_toward_count, total_trials].
%
% Correct rate is computed only from nonzero-coherence trials:
%   coh > 0: correct = chose_toward_count
%   coh < 0: correct = total_trials - chose_toward_count

clear
clc

%% User options
scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);

behaviorFile = fullfile(repoRoot, 'BehaviorFitting', 'BehaviorData_Jim.mat');
outputDir = fullfile(repoRoot, 'BehaviorFitting', 'JimRightEyeCorrectRate');

monkeyName = "Jim";
conditionNames = ["Combined", "MonoL", "MonoR", "Bino"];
rightEyeConditionName = "MonoR";

% The old paper behavior comparison should usually use non-stimulation data.
% Change to ["nonStim", "Stim"] if you also want the stimulation block.
blocksToAnalyze = "nonStim";

zeroCoherenceTolerance = 1e-10;
makeFigures = true;
runMixedEffectsModels = true;

%% Load and summarize behavior
if ~isfile(behaviorFile)
    error('Behavior file not found: %s', behaviorFile);
end

if ~isfolder(outputDir)
    mkdir(outputDir);
end

behaviorData = load(behaviorFile);
availableBlocks = get_available_blocks(behaviorData);
blocksToAnalyze = string(blocksToAnalyze);
missingBlocks = setdiff(blocksToAnalyze, availableBlocks);
if ~isempty(missingBlocks)
    error('Requested block(s) not found in %s: %s', behaviorFile, strjoin(missingBlocks, ', '));
end

sessionConditionTable = table();
conditionCoherenceTable = table();

for blockIdx = 1:numel(blocksToAnalyze)
    blockName = blocksToAnalyze(blockIdx);
    blockCells = get_block_cells(behaviorData, blockName);
    [blockSessionTable, blockCoherenceTable] = build_correct_rate_tables( ...
        blockCells, blockName, monkeyName, conditionNames, zeroCoherenceTolerance, behaviorFile);

    sessionConditionTable = [sessionConditionTable; blockSessionTable]; %#ok<AGROW>
    conditionCoherenceTable = [conditionCoherenceTable; blockCoherenceTable]; %#ok<AGROW>
end

if isempty(sessionConditionTable)
    error('No usable behavior rows were found in %s.', behaviorFile);
end

[pairedDifferenceTable, pairedStatsTable] = compute_paired_condition_stats( ...
    sessionConditionTable, rightEyeConditionName, conditionNames);

mixedModelSummaryTable = table();
mixedModels = struct();
if runMixedEffectsModels
    [mixedModelSummaryTable, mixedModels] = fit_pairwise_mixed_models( ...
        conditionCoherenceTable, rightEyeConditionName, conditionNames);
end

%% Save outputs
sessionConditionPath = fullfile(outputDir, 'Jim_correct_rate_by_session_condition.csv');
conditionCoherencePath = fullfile(outputDir, 'Jim_correct_rate_by_session_condition_coherence.csv');
pairedDifferencePath = fullfile(outputDir, 'Jim_MonoR_minus_other_conditions_by_session.csv');
pairedStatsPath = fullfile(outputDir, 'Jim_MonoR_paired_stats.csv');
mixedModelSummaryPath = fullfile(outputDir, 'Jim_MonoR_pairwise_mixed_model_summary.csv');
resultMatPath = fullfile(outputDir, 'JimRightEyeCorrectRateResults.mat');
summaryPath = fullfile(outputDir, 'JimRightEyeCorrectRateSummary.txt');

writetable(sessionConditionTable, sessionConditionPath);
writetable(conditionCoherenceTable, conditionCoherencePath);
writetable(pairedDifferenceTable, pairedDifferencePath);
writetable(pairedStatsTable, pairedStatsPath);
if ~isempty(mixedModelSummaryTable)
    writetable(mixedModelSummaryTable, mixedModelSummaryPath);
end

save(resultMatPath, 'sessionConditionTable', 'conditionCoherenceTable', ...
    'pairedDifferenceTable', 'pairedStatsTable', 'mixedModelSummaryTable', ...
    'mixedModels', 'behaviorFile', 'conditionNames', 'rightEyeConditionName', ...
    'blocksToAnalyze', '-v7.3');

write_summary_file(summaryPath, behaviorFile, outputDir, conditionNames, ...
    rightEyeConditionName, blocksToAnalyze, sessionConditionTable, ...
    pairedStatsTable, mixedModelSummaryTable);

if makeFigures
    make_correct_rate_figures(sessionConditionTable, conditionCoherenceTable, ...
        pairedDifferenceTable, conditionNames, rightEyeConditionName, outputDir);
end

disp(' ')
disp('Jim right-eye correct-rate comparison complete.')
disp(['Output directory: ', outputDir])
disp(' ')
disp('Paired stats:')
disp(pairedStatsTable)
if ~isempty(mixedModelSummaryTable)
    disp(' ')
    disp('Mixed model summary:')
    disp(mixedModelSummaryTable)
end

assignin('base', 'jim_right_eye_session_condition_table', sessionConditionTable);
assignin('base', 'jim_right_eye_condition_coherence_table', conditionCoherenceTable);
assignin('base', 'jim_right_eye_paired_difference_table', pairedDifferenceTable);
assignin('base', 'jim_right_eye_paired_stats_table', pairedStatsTable);
assignin('base', 'jim_right_eye_mixed_model_summary_table', mixedModelSummaryTable);
assignin('base', 'jim_right_eye_mixed_models', mixedModels);

%% Local functions
function availableBlocks = get_available_blocks(S)
availableBlocks = strings(0, 1);
if isfield(S, 'BehaviorData_nonStim_pFit_all')
    availableBlocks(end + 1, 1) = "nonStim";
end
if isfield(S, 'BehaviorData_Stim_pFit_all')
    availableBlocks(end + 1, 1) = "Stim";
end
end

function blockCells = get_block_cells(S, blockName)
switch string(blockName)
    case "nonStim"
        blockCells = S.BehaviorData_nonStim_pFit_all;
    case "Stim"
        blockCells = S.BehaviorData_Stim_pFit_all;
    otherwise
        error('Unknown block name: %s', blockName);
end
end

function [sessionTable, coherenceTable] = build_correct_rate_tables( ...
    behaviorCells, blockName, monkeyName, conditionNames, zeroTol, sourceFile)

sessionTable = table();
coherenceTable = table();
nConditions = numel(conditionNames);

for sessionIdx = 1:numel(behaviorCells)
    cueStruct = behaviorCells{sessionIdx};
    if isempty(cueStruct)
        continue
    end

    sessionID = sprintf('%s_%03d', monkeyName, sessionIdx);
    nCues = min(numel(cueStruct), nConditions);

    for conditionIdx = 1:nCues
        if ~isfield(cueStruct(conditionIdx), 'data') || isempty(cueStruct(conditionIdx).data)
            continue
        end

        data = cueStruct(conditionIdx).data;
        if size(data, 2) < 3
            warning('Skipping %s condition %d session %d: data has fewer than 3 columns.', ...
                blockName, conditionIdx, sessionIdx);
            continue
        end

        [coh, towardCount, totalTrials, correctCount, validRows] = ...
            compute_correct_counts_from_toward_data(data, zeroTol);

        if ~any(validRows)
            continue
        end

        totalCorrect = sum(correctCount(validRows), 'omitnan');
        totalN = sum(totalTrials(validRows), 'omitnan');
        if totalN <= 0
            continue
        end

        sessionRow = table( ...
            string(sourceFile), string(monkeyName), string(sessionID), sessionIdx, ...
            string(blockName), conditionIdx, string(conditionNames(conditionIdx)), ...
            totalCorrect, totalN, totalCorrect ./ totalN, nnz(validRows), ...
            'VariableNames', {'SourceFile', 'Monkey', 'SessionID', 'SessionIndex', ...
            'Block', 'ConditionIndex', 'ConditionName', 'CorrectCount', ...
            'TotalTrials', 'CorrectRate', 'NCoherenceLevels'});
        sessionTable = [sessionTable; sessionRow]; %#ok<AGROW>

        conditionRows = find(validRows);
        for rowIdx = conditionRows(:)'
            cohRow = table( ...
                string(sourceFile), string(monkeyName), string(sessionID), sessionIdx, ...
                string(blockName), conditionIdx, string(conditionNames(conditionIdx)), ...
                coh(rowIdx), abs(coh(rowIdx)), towardCount(rowIdx), ...
                correctCount(rowIdx), totalTrials(rowIdx), ...
                correctCount(rowIdx) ./ totalTrials(rowIdx), ...
                'VariableNames', {'SourceFile', 'Monkey', 'SessionID', 'SessionIndex', ...
                'Block', 'ConditionIndex', 'ConditionName', 'SignedCoherence', ...
                'AbsCoherence', 'TowardCount', 'CorrectCount', 'TotalTrials', ...
                'CorrectRate'});
            coherenceTable = [coherenceTable; cohRow]; %#ok<AGROW>
        end
    end
end
end

function [coh, towardCount, totalTrials, correctCount, validRows] = ...
    compute_correct_counts_from_toward_data(data, zeroTol)

coh = data(:, 1);
towardCount = data(:, 2);
totalTrials = data(:, 3);

correctCount = nan(size(coh));
towardStim = coh > zeroTol;
awayStim = coh < -zeroTol;
correctCount(towardStim) = towardCount(towardStim);
correctCount(awayStim) = totalTrials(awayStim) - towardCount(awayStim);

validRows = isfinite(coh) & isfinite(towardCount) & isfinite(totalTrials) & ...
    isfinite(correctCount) & totalTrials > 0 & abs(coh) > zeroTol;
end

function [pairedDiffTable, statsTable] = compute_paired_condition_stats( ...
    sessionConditionTable, rightConditionName, conditionNames)

pairedDiffTable = table();
statsTable = table();
blocks = unique(sessionConditionTable.Block, 'stable');
comparators = conditionNames(conditionNames ~= rightConditionName);

for blockIdx = 1:numel(blocks)
    blockName = blocks(blockIdx);
    blockRows = sessionConditionTable(sessionConditionTable.Block == blockName, :);
    sessionIDs = unique(blockRows.SessionID, 'stable');

    for compIdx = 1:numel(comparators)
        comparatorName = comparators(compIdx);

        SessionID = strings(0, 1);
        SessionIndex = zeros(0, 1);
        Block = strings(0, 1);
        ComparatorCondition = strings(0, 1);
        RightEyeRate = zeros(0, 1);
        ComparatorRate = zeros(0, 1);
        Difference = zeros(0, 1);

        for sessionIdx = 1:numel(sessionIDs)
            thisSession = sessionIDs(sessionIdx);
            rightRow = blockRows(blockRows.SessionID == thisSession & ...
                blockRows.ConditionName == rightConditionName, :);
            compRow = blockRows(blockRows.SessionID == thisSession & ...
                blockRows.ConditionName == comparatorName, :);

            if height(rightRow) ~= 1 || height(compRow) ~= 1
                continue
            end

            SessionID(end + 1, 1) = thisSession; %#ok<AGROW>
            SessionIndex(end + 1, 1) = rightRow.SessionIndex; %#ok<AGROW>
            Block(end + 1, 1) = blockName; %#ok<AGROW>
            ComparatorCondition(end + 1, 1) = comparatorName; %#ok<AGROW>
            RightEyeRate(end + 1, 1) = rightRow.CorrectRate; %#ok<AGROW>
            ComparatorRate(end + 1, 1) = compRow.CorrectRate; %#ok<AGROW>
            Difference(end + 1, 1) = rightRow.CorrectRate - compRow.CorrectRate; %#ok<AGROW>
        end

        if ~isempty(SessionID)
            diffRows = table(SessionID, SessionIndex, Block, ComparatorCondition, ...
                RightEyeRate, ComparatorRate, Difference);
            pairedDiffTable = [pairedDiffTable; diffRows]; %#ok<AGROW>
        end

        statsRow = summarize_paired_difference(blockRows, rightConditionName, comparatorName, ...
            blockName, Difference);
        statsTable = [statsTable; statsRow]; %#ok<AGROW>
    end
end
end

function statsRow = summarize_paired_difference(blockRows, rightConditionName, ...
    comparatorName, blockName, differences)

rightRows = blockRows(blockRows.ConditionName == rightConditionName, :);
compRows = blockRows(blockRows.ConditionName == comparatorName, :);

pooledRightCorrect = sum(rightRows.CorrectCount, 'omitnan');
pooledRightTrials = sum(rightRows.TotalTrials, 'omitnan');
pooledCompCorrect = sum(compRows.CorrectCount, 'omitnan');
pooledCompTrials = sum(compRows.TotalTrials, 'omitnan');

pooledRightRate = pooledRightCorrect ./ pooledRightTrials;
pooledCompRate = pooledCompCorrect ./ pooledCompTrials;

differences = differences(isfinite(differences));
nPairs = numel(differences);
meanDiff = mean(differences, 'omitnan');
medianDiff = median(differences, 'omitnan');
semDiff = std(differences, 'omitnan') ./ sqrt(max(nPairs, 1));
effectDz = meanDiff ./ std(differences, 'omitnan');

tP = nan;
tStat = nan;
tDf = nan;
ciLow = nan;
ciHigh = nan;
if nPairs >= 2 && exist('ttest', 'file') == 2
    try
        [~, tP, ci, tStats] = ttest(differences);
        tStat = tStats.tstat;
        tDf = tStats.df;
        ciLow = ci(1);
        ciHigh = ci(2);
    catch
    end
end

signrankP = nan;
if nPairs >= 2 && exist('signrank', 'file') == 2
    try
        signrankP = signrank(differences);
    catch
    end
end

statsRow = table( ...
    string(blockName), string(rightConditionName + " - " + comparatorName), ...
    string(rightConditionName), string(comparatorName), nPairs, ...
    pooledRightCorrect, pooledRightTrials, pooledRightRate, ...
    pooledCompCorrect, pooledCompTrials, pooledCompRate, ...
    meanDiff, medianDiff, semDiff, ciLow, ciHigh, effectDz, ...
    tP, tStat, tDf, signrankP, ...
    'VariableNames', {'Block', 'Comparison', 'RightEyeCondition', 'ComparatorCondition', ...
    'NPairs', 'PooledRightCorrect', 'PooledRightTrials', 'PooledRightRate', ...
    'PooledComparatorCorrect', 'PooledComparatorTrials', 'PooledComparatorRate', ...
    'MeanPairedDifference', 'MedianPairedDifference', 'SEMPairedDifference', ...
    'PairedDifferenceCILow', 'PairedDifferenceCIHigh', 'EffectSizeDz', ...
    'PairedTTestP', 'PairedTStat', 'PairedTDf', 'SignrankP'});
end

function [summaryTable, models] = fit_pairwise_mixed_models( ...
    conditionCoherenceTable, rightConditionName, conditionNames)

summaryTable = table();
models = struct();

if exist('fitglme', 'file') ~= 2
    warning('fitglme is unavailable. Skipping mixed-effects models.');
    return
end

blocks = unique(conditionCoherenceTable.Block, 'stable');
comparators = conditionNames(conditionNames ~= rightConditionName);

for blockIdx = 1:numel(blocks)
    blockName = blocks(blockIdx);
    for compIdx = 1:numel(comparators)
        comparatorName = comparators(compIdx);
        keepRows = conditionCoherenceTable.Block == blockName & ...
            (conditionCoherenceTable.ConditionName == rightConditionName | ...
            conditionCoherenceTable.ConditionName == comparatorName) & ...
            conditionCoherenceTable.TotalTrials > 0;
        pairTable = conditionCoherenceTable(keepRows, :);
        if height(pairTable) < 8
            continue
        end

        pairTable.SessionID = categorical(pairTable.SessionID);
        pairTable.IsRightEye = categorical(pairTable.ConditionName == rightConditionName, ...
            [false true], ["Comparator", "RightEye"]);
        pairTable.AbsCoherenceCentered = pairTable.AbsCoherence - ...
            mean(pairTable.AbsCoherence, 'omitnan');

        modelName = matlab.lang.makeValidName(sprintf('%s_%s_vs_%s', ...
            blockName, rightConditionName, comparatorName));
        trialTable = expand_binomial_count_rows(pairTable);
        if height(trialTable) < 8
            continue
        end

        try
            model = fitglme(trialTable, ...
                'CorrectTrial ~ IsRightEye * AbsCoherenceCentered + (1|SessionID)', ...
                'Distribution', 'Binomial');
            models.(modelName) = model;
            row = summarize_mixed_model(model, blockName, rightConditionName, comparatorName, ...
                height(pairTable), height(trialTable));
            summaryTable = [summaryTable; row]; %#ok<AGROW>
        catch ME
            warning('Mixed model failed for %s: %s', modelName, ME.message);
        end
    end
end
end

function trialTable = expand_binomial_count_rows(pairTable)
nExpanded = sum(round(pairTable.TotalTrials));

CorrectTrial = false(nExpanded, 1);
SessionID = strings(nExpanded, 1);
ConditionName = strings(nExpanded, 1);
IsRightEye = strings(nExpanded, 1);
SignedCoherence = nan(nExpanded, 1);
AbsCoherence = nan(nExpanded, 1);
AbsCoherenceCentered = nan(nExpanded, 1);

writeIdx = 0;
for rowIdx = 1:height(pairTable)
    nTotal = round(pairTable.TotalTrials(rowIdx));
    nCorrect = round(pairTable.CorrectCount(rowIdx));
    nCorrect = max(0, min(nCorrect, nTotal));
    if nTotal <= 0
        continue
    end

    rowRange = writeIdx + (1:nTotal);
    CorrectTrial(rowRange) = [true(nCorrect, 1); false(nTotal - nCorrect, 1)];
    SessionID(rowRange) = string(pairTable.SessionID(rowIdx));
    ConditionName(rowRange) = pairTable.ConditionName(rowIdx);
    IsRightEye(rowRange) = string(pairTable.IsRightEye(rowIdx));
    SignedCoherence(rowRange) = pairTable.SignedCoherence(rowIdx);
    AbsCoherence(rowRange) = pairTable.AbsCoherence(rowIdx);
    AbsCoherenceCentered(rowRange) = pairTable.AbsCoherenceCentered(rowIdx);
    writeIdx = writeIdx + nTotal;
end

keepRows = 1:writeIdx;
trialTable = table( ...
    double(CorrectTrial(keepRows)), ...
    categorical(SessionID(keepRows)), ...
    ConditionName(keepRows), ...
    categorical(IsRightEye(keepRows), ["Comparator", "RightEye"]), ...
    SignedCoherence(keepRows), ...
    AbsCoherence(keepRows), ...
    AbsCoherenceCentered(keepRows), ...
    'VariableNames', {'CorrectTrial', 'SessionID', 'ConditionName', ...
    'IsRightEye', 'SignedCoherence', 'AbsCoherence', 'AbsCoherenceCentered'});
end

function row = summarize_mixed_model(model, blockName, rightConditionName, comparatorName, nRows, nTrials)
coefTable = model.Coefficients;
rowNames = string(coefTable.Name);

rightCoefIdx = find(contains(rowNames, "IsRightEye_RightEye"), 1);
interactionIdx = find(contains(rowNames, "IsRightEye_RightEye:AbsCoherenceCentered") | ...
    contains(rowNames, "AbsCoherenceCentered:IsRightEye_RightEye"), 1);

[rightEstimate, rightSE, rightP] = get_coef_values(coefTable, rightCoefIdx);
[interactionEstimate, interactionSE, interactionP] = get_coef_values(coefTable, interactionIdx);
ordinaryR2 = nan;
try
    ordinaryR2 = model.Rsquared.Ordinary;
catch
end

row = table(string(blockName), string(rightConditionName + " vs " + comparatorName), ...
    string(rightConditionName), string(comparatorName), nRows, ...
    nTrials, rightEstimate, rightSE, rightP, interactionEstimate, interactionSE, interactionP, ...
    ordinaryR2, ...
    'VariableNames', {'Block', 'Comparison', 'RightEyeCondition', 'ComparatorCondition', ...
    'NRows', 'NExpandedTrials', 'RightEyeLogOddsEstimate', 'RightEyeLogOddsSE', 'RightEyeLogOddsP', ...
    'RightEyeByAbsCoherenceEstimate', 'RightEyeByAbsCoherenceSE', ...
    'RightEyeByAbsCoherenceP', 'OrdinaryR2'});
end

function [estimate, se, pValue] = get_coef_values(coefTable, idx)
estimate = nan;
se = nan;
pValue = nan;
if isempty(idx) || isnan(idx)
    return
end
estimate = coefTable.Estimate(idx);
se = coefTable.SE(idx);
pValue = coefTable.pValue(idx);
end

function make_correct_rate_figures(sessionConditionTable, conditionCoherenceTable, ...
    pairedDifferenceTable, conditionNames, rightConditionName, outputDir)

blocks = unique(sessionConditionTable.Block, 'stable');
conditionColors = get_condition_colors(conditionNames);

for blockIdx = 1:numel(blocks)
    blockName = blocks(blockIdx);
    blockSessionTable = sessionConditionTable(sessionConditionTable.Block == blockName, :);
    blockDiffTable = pairedDifferenceTable(pairedDifferenceTable.Block == blockName, :);

    fig = figure('Color', 'w', 'Name', sprintf('Jim_%s_MonoR_correct_rate', blockName));
    tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile
    plot_session_condition_rates(blockSessionTable, conditionNames, conditionColors);
    title(sprintf('%s correct rate by cue', blockName), 'Interpreter', 'none');

    nexttile
    plot_paired_differences(blockDiffTable, conditionNames, conditionColors);
    title(sprintf('%s MonoR paired differences', blockName), 'Interpreter', 'none');

    saveas(fig, fullfile(outputDir, sprintf('Jim_%s_MonoR_correct_rate_summary.fig', blockName)));
    exportgraphics(fig, fullfile(outputDir, sprintf('Jim_%s_MonoR_correct_rate_summary.png', blockName)), ...
        'Resolution', 300);

    fig2 = figure('Color', 'w', 'Name', sprintf('Jim_%s_correct_rate_by_coherence', blockName));
    blockCoherenceTable = conditionCoherenceTable(conditionCoherenceTable.Block == blockName, :);
    plot_correct_rate_by_abs_coherence(blockCoherenceTable, conditionNames, conditionColors);
    title(sprintf('%s correct rate by absolute coherence', blockName), 'Interpreter', 'none');

    saveas(fig2, fullfile(outputDir, sprintf('Jim_%s_correct_rate_by_abs_coherence.fig', blockName)));
    exportgraphics(fig2, fullfile(outputDir, sprintf('Jim_%s_correct_rate_by_abs_coherence.png', blockName)), ...
        'Resolution', 300);
end
end

function plot_session_condition_rates(T, conditionNames, conditionColors)
hold on
sessionIDs = unique(T.SessionID, 'stable');
xVals = 1:numel(conditionNames);
rateMatrix = nan(numel(sessionIDs), numel(conditionNames));

for sessionIdx = 1:numel(sessionIDs)
    thisSession = sessionIDs(sessionIdx);
    for condIdx = 1:numel(conditionNames)
        row = T(T.SessionID == thisSession & T.ConditionName == conditionNames(condIdx), :);
        if height(row) == 1
            rateMatrix(sessionIdx, condIdx) = row.CorrectRate;
        end
    end
    plot(xVals, rateMatrix(sessionIdx, :), '-', 'Color', [0.78 0.78 0.78], 'LineWidth', 0.5);
end

for condIdx = 1:numel(conditionNames)
    scatter(repelem(condIdx, size(rateMatrix, 1)), rateMatrix(:, condIdx), ...
        16, conditionColors(condIdx, :), 'filled', ...
        'MarkerFaceAlpha', 0.35, 'MarkerEdgeAlpha', 0.35);
end

meanRates = mean(rateMatrix, 1, 'omitnan');
semRates = std(rateMatrix, 0, 1, 'omitnan') ./ sqrt(sum(isfinite(rateMatrix), 1));
for condIdx = 1:numel(conditionNames)
    errorbar(xVals(condIdx), meanRates(condIdx), semRates(condIdx), 'o', ...
        'Color', conditionColors(condIdx, :), 'MarkerFaceColor', 'w', ...
        'MarkerEdgeColor', conditionColors(condIdx, :), 'LineWidth', 2, ...
        'MarkerSize', 7);
end

xticks(xVals)
xticklabels(conditionNames)
xlabel('Cue condition')
ylabel('Correct rate')
ylim([0.45 1])
box on
axis square
end

function plot_paired_differences(T, conditionNames, conditionColors)
hold on
if isempty(T)
    text(0.5, 0.5, 'No paired differences', 'HorizontalAlignment', 'center');
    axis off
    return
end

try
    comparators = unique(T.ComparatorCondition, 'stable');
    for idx = 1:numel(comparators)
        rows = T.ComparatorCondition == comparators(idx);
        colorIdx = find(conditionNames == comparators(idx), 1);
        if isempty(colorIdx)
            thisColor = [0.2 0.2 0.2];
        else
            thisColor = conditionColors(colorIdx, :);
        end
        boxchart(categorical(T.ComparatorCondition(rows)), T.Difference(rows), ...
            'BoxFaceColor', thisColor, 'MarkerColor', thisColor);
    end
catch
    boxplot(T.Difference, categorical(T.ComparatorCondition));
end
yline(0, 'k--');
ylabel('MonoR correct rate - comparator')
xlabel('Comparator condition')
box on
axis square
end

function plot_correct_rate_by_abs_coherence(T, conditionNames, conditionColors)
hold on
absLevels = unique(T.AbsCoherence);
absLevels = absLevels(isfinite(absLevels));
absLevels = sort(absLevels(:));

for condIdx = 1:numel(conditionNames)
    [meanRates, semRates] = compute_session_rates_by_abs_coherence( ...
        T, conditionNames(condIdx), absLevels);
    errorbar(absLevels, meanRates, semRates, '-o', ...
        'Color', conditionColors(condIdx, :), ...
        'MarkerFaceColor', conditionColors(condIdx, :), 'LineWidth', 2, ...
        'CapSize', 7, ...
        'DisplayName', conditionNames(condIdx));
end

xlabel('|Coherence|')
ylabel('Correct rate')
ylim([0.45 1])
legend('Location', 'southeast')
box on
axis square
end

function [meanRates, semRates] = compute_session_rates_by_abs_coherence( ...
    T, conditionName, absLevels)

meanRates = nan(size(absLevels));
semRates = nan(size(absLevels));
for levelIdx = 1:numel(absLevels)
    rows = T(T.ConditionName == conditionName & ...
        abs(T.AbsCoherence - absLevels(levelIdx)) < 1e-10, :);

    sessionIDs = unique(rows.SessionID, 'stable');
    sessionRates = nan(numel(sessionIDs), 1);
    for sessionIdx = 1:numel(sessionIDs)
        sessionRows = rows(rows.SessionID == sessionIDs(sessionIdx), :);
        totalCorrect = sum(sessionRows.CorrectCount, 'omitnan');
        totalTrials = sum(sessionRows.TotalTrials, 'omitnan');
        if totalTrials > 0
            sessionRates(sessionIdx) = totalCorrect ./ totalTrials;
        end
    end

    validRates = sessionRates(isfinite(sessionRates));
    if ~isempty(validRates)
        meanRates(levelIdx) = mean(validRates);
        semRates(levelIdx) = std(validRates) ./ sqrt(numel(validRates));
    end
end
end

function conditionColors = get_condition_colors(conditionNames)
conditionColors = nan(numel(conditionNames), 3);
for condIdx = 1:numel(conditionNames)
    switch string(conditionNames(condIdx))
        case {"Combined", "Comb"}
            conditionColors(condIdx, :) = [0 0 0] ./ 255;
        case {"MonoL", "L Mono", "Left"}
            conditionColors(condIdx, :) = [0 0 255] ./ 255;
        case {"MonoR", "R Mono", "Right"}
            conditionColors(condIdx, :) = [5 150 5] ./ 255;
        case {"Bino", "Stereo", "Binocular"}
            conditionColors(condIdx, :) = [234 0 233] ./ 255;
        otherwise
            conditionColors(condIdx, :) = [0.2 0.2 0.2];
    end
end
end

function write_summary_file(summaryPath, behaviorFile, outputDir, conditionNames, ...
    rightEyeConditionName, blocksToAnalyze, sessionConditionTable, ...
    pairedStatsTable, mixedModelSummaryTable)

fid = fopen(summaryPath, 'w');
if fid < 0
    warning('Could not write summary file: %s', summaryPath);
    return
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, 'Jim right-eye correct-rate comparison\n');
fprintf(fid, 'Generated: %s\n', datestr(now));
fprintf(fid, 'Behavior file: %s\n', behaviorFile);
fprintf(fid, 'Output directory: %s\n', outputDir);
fprintf(fid, 'Analyzed blocks: %s\n', strjoin(blocksToAnalyze, ', '));
fprintf(fid, 'Condition order: %s\n', strjoin(conditionNames, ', '));
fprintf(fid, 'Right-eye condition: %s\n', rightEyeConditionName);
fprintf(fid, 'Zero-coherence trials excluded from correct-rate calculations.\n\n');

blocks = unique(sessionConditionTable.Block, 'stable');
for blockIdx = 1:numel(blocks)
    blockName = blocks(blockIdx);
    rows = sessionConditionTable(sessionConditionTable.Block == blockName, :);
    fprintf(fid, 'Block: %s\n', blockName);
    fprintf(fid, '  Sessions with at least one valid condition: %d\n', numel(unique(rows.SessionID)));
    for condIdx = 1:numel(conditionNames)
        condRows = rows(rows.ConditionName == conditionNames(condIdx), :);
        fprintf(fid, '  %s: N sessions=%d, pooled correct rate=%.4f (%g/%g)\n', ...
            conditionNames(condIdx), height(condRows), ...
            sum(condRows.CorrectCount, 'omitnan') ./ sum(condRows.TotalTrials, 'omitnan'), ...
            sum(condRows.CorrectCount, 'omitnan'), sum(condRows.TotalTrials, 'omitnan'));
    end
    fprintf(fid, '\n');
end

fprintf(fid, 'Paired stats:\n');
for rowIdx = 1:height(pairedStatsTable)
    row = pairedStatsTable(rowIdx, :);
    fprintf(fid, '  %s %s: N=%d, mean diff=%.5f, t-test p=%.5g, signrank p=%.5g\n', ...
        row.Block, row.Comparison, row.NPairs, row.MeanPairedDifference, ...
        row.PairedTTestP, row.SignrankP);
end

if ~isempty(mixedModelSummaryTable)
    fprintf(fid, '\nMixed model summary:\n');
    for rowIdx = 1:height(mixedModelSummaryTable)
        row = mixedModelSummaryTable(rowIdx, :);
        fprintf(fid, '  %s %s: right-eye log-odds estimate=%.5f, p=%.5g; interaction p=%.5g\n', ...
            row.Block, row.Comparison, row.RightEyeLogOddsEstimate, ...
            row.RightEyeLogOddsP, row.RightEyeByAbsCoherenceP);
    end
end

end

function analysis = RunGaussianChannelCVComparison(options)
%RUNGAUSSIANCHANNELCVCOMPARISON Compare Combined AI with previous cue AI+AI:OD.
% Uses identical sessions, eligible channels, behavioral observations, sigma
% grids, and session folds. Reports the earlier 5x5 CV selection curves plus
% nested 5x5 outer/5-fold inner estimates. Statistical comparisons use paired
% outer-test errors with the Nadeau-Bengio variance correction for overlapping
% training sets. The aggregate test is primary; cue tests are Holm adjusted.

arguments
    options.CacheFile (1, 1) string = ...
        "C:\EM\CurrentSpread\02_gaussian\InteractiveGaussianMetaPopulation\MT\GaussianMetaPopulationSigmaCache.mat"
    options.OutputFolder (1, 1) string = ""
    options.UnitType (1, 1) string {mustBeMember(options.UnitType, ["2D", "3D"])} = "2D"
    options.SigmaValues (1, :) double = []
    options.NumRepeats (1, 1) double {mustBeInteger, mustBePositive} = 5
    options.NumFolds (1, 1) double {mustBeInteger, mustBeGreaterThan(options.NumFolds, 1)} = 5
    options.NumInnerFolds (1, 1) double {mustBeInteger, mustBeGreaterThan(options.NumInnerFolds, 1)} = 5
    options.RandomSeed (1, 1) double {mustBeInteger, mustBeNonnegative} = 1
end
loaded = load(options.CacheFile, 'cache');
cache = loaded.cache;
if strlength(options.OutputFolder) == 0
    options.OutputFolder = fullfile(cache.OutputFolder, options.UnitType, ...
        'ChannelFirstCombinedAI_CVComparison');
end
repositoryRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
outputFolder = string(char(java.io.File(char(options.OutputFolder)).getCanonicalPath()));
resolvedRoot = string(char(java.io.File(repositoryRoot).getCanonicalPath()));
if strcmpi(outputFolder, resolvedRoot) || startsWith(lower(outputFolder), lower(resolvedRoot + filesep))
    error('GaussianChannelCV:RepositoryOutput', 'Outputs must be outside the repository: %s', outputFolder);
end
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
sigmaValues = options.SigmaValues;
if isempty(sigmaValues)
    sigmaValues = double(cache.SigmaValues(:)');
end
sigmaValues = sort(unique(sigmaValues(:)));
if isempty(sigmaValues) || any(~isfinite(sigmaValues)) || any(sigmaValues <= 0)
    error('GaussianChannelCV:SigmaValues', 'Expected positive finite sigma values.');
end

% Use the intersection of channel eligibility to isolate the model change.
% Neither model can gain observations or channels the other cannot use.
n = size(cache.ChannelAI, 1);
p = size(cache.ChannelAI, 3);
commonChannels = logical(cache.ChannelEligibleForPrediction) & ...
    reshape(all(isfinite(cache.ChannelAI), 2), n, p) & ...
    isfinite(cache.ChannelSignedOD) & cache.ChannelSignedOD ~= 0 & ...
    isfinite(cache.ChannelRelativePositions);
referenceOD = double(cache.StimReferenceOD(:));
if options.UnitType == "2D"
    classMask = cache.StimZ3DMinusZ2D < 0;
else
    classMask = cache.StimZ3DMinusZ2D > 0;
end
mask = strcmp(string(cache.SessionStatus(:)), "Success") & classMask(:) & ...
    any(commonChannels, 2) & isfinite(referenceOD) & referenceOD ~= 0 & ...
    any(cache.BehaviorValidByPhysicalCue & isfinite(cache.BehaviorByPhysicalCue), 2);
if nnz(mask) < 10
    error('GaussianChannelCV:TooFewSessions', 'Fewer than ten matched sessions are available.');
end
ai = double(cache.ChannelAI(mask, :, :));
od = double(cache.ChannelSignedOD(mask, :));
eligible = commonChannels(mask, :);
positions = double(cache.ChannelRelativePositions(mask, :));
behavior = double(cache.BehaviorByPhysicalCue(mask, :));
validBehavior = logical(cache.BehaviorValidByPhysicalCue(mask, :));
referenceOD = referenceOD(mask);
sourceRows = double(cache.SourceRows(mask));

fprintf('Matched CV comparison: %s %s, %d sessions, %d channels, %d sigma values.\n', ...
    cache.Area, options.UnitType, nnz(mask), nnz(eligible), numel(sigmaValues));
[oldFirst, y, map, weights] = buildGaussianChannelPredictionDesign( ...
    ai, od, eligible, positions, behavior, validBehavior, referenceOD, sigmaValues(1));
oldDesign = zeros(numel(y), 12, numel(sigmaValues));
newDesign = zeros(numel(y), 8, numel(sigmaValues));
oldDesign(:, :, 1) = oldFirst;
for sigmaIndex = 1:numel(sigmaValues)
    if sigmaIndex > 1
        [oldDesign(:, :, sigmaIndex), oldY, oldMap, weights] = ...
            buildGaussianChannelPredictionDesign(ai, od, eligible, positions, ...
            behavior, validBehavior, referenceOD, sigmaValues(sigmaIndex));
        assert(isequaln(y, oldY) && isequal(map, oldMap), 'GaussianChannelCV:OldObservationChange', ...
            'The old-model observation set changed across sigma.');
    end
    [newDesign(:, :, sigmaIndex), newY, newMap, newWeights] = ...
        buildGaussianChannelPredictionDesign(ai, od, eligible, positions, ...
        behavior, validBehavior, referenceOD, sigmaValues(sigmaIndex), PredictorMode="CombinedAI");
    assert(isequaln(y, newY) && isequal(map, newMap) && isequal(weights, newWeights), ...
        'GaussianChannelCV:UnmatchedInputs', 'Models must use identical targets and Gaussian weights.');
end

args = {'NumRepeats', options.NumRepeats, 'NumFolds', options.NumFolds, ...
    'NumInnerFolds', options.NumInnerFolds, 'RandomSeed', options.RandomSeed};
fprintf('Evaluating previous cue-specific AI + AI:OD model...\n');
old = crossValidateGaussianChannelDesign(oldDesign, y, map, sigmaValues, args{:});
fprintf('Evaluating new Combined-AI model...\n');
new = crossValidateGaussianChannelDesign(newDesign, y, map, sigmaValues, args{:});
assert(isequal(old.FoldAssignments, new.FoldAssignments) && ...
    isequal(old.Nested.InnerFoldAssignments, new.Nested.InnerFoldAssignments), ...
    'GaussianChannelCV:UnmatchedFolds', 'Models must share outer and inner session folds.');
assert(isequaln(old.NullPredictionByRepeat, new.NullPredictionByRepeat), ...
    'GaussianChannelCV:UnmatchedNull', 'Models must share the cue-specific training-mean baseline.');

significance = compareGaussianChannelCVErrors(old.Nested.FoldMSE, ...
    new.Nested.FoldMSE, old.Nested.FoldTestTrainRatio);
conditionNames = ["Dominant"; "Combined"; "Stereo"; "NonDominant"];
performance = table(conditionNames, old.Nested.PerCueMeanMSE, new.Nested.PerCueMeanMSE, ...
    old.Nested.PerCueMeanR2, new.Nested.PerCueMeanR2, ...
    new.Nested.PerCueMeanR2 - old.Nested.PerCueMeanR2, ...
    significance.PImprovementOneSided(2:5), significance.PImprovementHolmWithinCues(2:5), ...
    'VariableNames', {'Condition', 'OldNestedMSE', 'NewNestedMSE', ...
    'OldNestedCVR2', 'NewNestedCVR2', 'DeltaNestedCVR2', ...
    'PImprovement', 'PImprovementHolm'});
summary = table(["Previous cue AI + AI:OD"; "Combined AI"], ...
    [12; 8], [old.BestSigma; new.BestSigma], [old.BestCVMSE; new.BestCVMSE], ...
    [old.BestCVR2; new.BestCVR2], [old.Nested.MeanMSE; new.Nested.MeanMSE], ...
    [old.Nested.MeanPooledR2; new.Nested.MeanPooledR2], ...
    'VariableNames', {'Model', 'BetaCount', 'SelectionCVBestSigma', ...
    'SelectionCV_MSE', 'SelectionCV_PooledR2', 'NestedCV_MSE', 'NestedCV_PooledR2'});
curve = table(sigmaValues, old.MeanCVMSE, new.MeanCVMSE, old.MeanCVR2, new.MeanCVR2, ...
    'VariableNames', {'Sigma', 'OldSelectionCVMSE', 'NewSelectionCVMSE', ...
    'OldSelectionCVR2', 'NewSelectionCVR2'});
for condition = 1:4
    curve.("OldCVMSE_" + conditionNames(condition)) = old.PerCueMeanCVMSE(condition, :)';
    curve.("NewCVMSE_" + conditionNames(condition)) = new.PerCueMeanCVMSE(condition, :)';
    curve.("OldCVR2_" + conditionNames(condition)) = old.PerCueMeanCVR2(condition, :)';
    curve.("NewCVR2_" + conditionNames(condition)) = new.PerCueMeanCVR2(condition, :)';
end
pointTable = map;
pointTable.SourceTableRow = sourceRows(map.SessionIndex);
monkey = string(cache.Monkey(mask));
pointTable.Monkey = monkey(map.SessionIndex);
pointTable.Observed = y;
pointTable.OldNestedPrediction = old.Nested.MeanPrediction;
pointTable.NewNestedPrediction = new.Nested.MeanPrediction;
pointTable.OldMeanSquaredError = mean((y - old.Nested.PredictionByRepeat).^2, 2);
pointTable.NewMeanSquaredError = mean((y - new.Nested.PredictionByRepeat).^2, 2);
foldTable = table();
for repeat = 1:options.NumRepeats
    for fold = 1:old.NumFolds
        entry = table(repeat, fold, old.Nested.SelectedSigma(repeat, fold), ...
            new.Nested.SelectedSigma(repeat, fold), old.Nested.FoldMSE(repeat, fold, 1), ...
            new.Nested.FoldMSE(repeat, fold, 1), old.Nested.FoldTestTrainRatio(repeat, fold, 1), ...
            'VariableNames', {'Repeat', 'Fold', 'OldSigma', 'NewSigma', ...
            'OldMSE', 'NewMSE', 'TestTrainRatio'});
        foldTable = [foldTable; entry]; %#ok<AGROW>
    end
end
analysis = struct('SchemaVersion', 1, 'Created', datetime('now'), ...
    'CacheFile', options.CacheFile, 'OutputFolder', outputFolder, ...
    'Area', cache.Area, 'UnitType', options.UnitType, 'ODDefinition', cache.ODDefinition, ...
    'SourceRows', sourceRows, 'CommonChannelMask', eligible, ...
    'SessionCount', nnz(mask), 'Old', old, 'New', new, ...
    'Summary', summary, 'PerCuePerformance', performance, ...
    'Significance', significance, 'SigmaCurve', curve, ...
    'Points', pointTable, 'OuterFoldAudit', foldTable);
analysis.Method = [ ...
    "Same session/channel/cue/sigma inputs and identical session-grouped folds"; ...
    "Repeated CV: 5 folds x 5 repeats by default; equal-cue MSE selects sigma"; ...
    "Nested CV: outer test excluded from both beta fitting and inner sigma selection"; ...
    "Primary significance: corrected paired t-test of old-minus-new outer-fold equal-cue MSE"; ...
    "Correction: SE = sqrt((1/(repeats*folds) + mean(nTest/nTrain))*var(error differences))"; ...
    "One-sided improvement test; two-sided p and 95% CI also reported; per-cue tests Holm adjusted"; ...
    "Approximate uncertainty for repeated CV with overlapping training sets"; ...
    "https://scikit-learn.org/stable/auto_examples/model_selection/plot_grid_search_stats.html"];
writetable(summary, fullfile(outputFolder, 'ModelSummary.csv'));
writetable(performance, fullfile(outputFolder, 'PerCuePerformance.csv'));
writetable(significance, fullfile(outputFolder, 'CorrectedPairedComparison.csv'));
writetable(curve, fullfile(outputFolder, 'SelectionCVCurves.csv'));
writetable(pointTable, fullfile(outputFolder, 'NestedHeldOutPredictions.csv'));
writetable(foldTable, fullfile(outputFolder, 'NestedFoldAudit.csv'));
save(fullfile(outputFolder, 'GaussianChannelCVComparison.mat'), 'analysis', '-v7.3');
saveComparisonFigure(analysis);
manifest = ["Combined-AI versus previous cue-AI+AI:OD CV comparison"; ...
    "Area / class: " + cache.Area + " " + options.UnitType; ...
    "Sessions: " + nnz(mask); "Sigma values: " + numel(sigmaValues); ...
    "Repeats: " + options.NumRepeats; "Outer folds: " + options.NumFolds; ...
    "Inner folds: " + options.NumInnerFolds; "Random seed: " + options.RandomSeed; ...
    analysis.Method; ...
    "Primary corrected improvement p = " + significance.PImprovementOneSided(1); ...
    "Primary MSE difference (old-new) = " + significance.MSEImprovement(1); ...
    "Primary difference 95% CI = [" + significance.ImprovementCILow(1) + ", " + ...
        significance.ImprovementCIHigh(1) + "]"];
writelines(manifest, fullfile(outputFolder, 'ComparisonManifest.txt'));
disp(summary); disp(performance); disp(significance);
fprintf('CV comparison saved to: %s\n', outputFolder);
end

function saveComparisonFigure(analysis)
f = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1380 820]);
cleanup = onCleanup(@() close(f));
layout = tiledlayout(f, 2, 2, 'TileSpacing', 'compact');
oldColor = [0.5 0.5 0.5]; newColor = [0.1 0.35 0.75];
ax = nexttile(layout);
semilogx(ax, analysis.Old.SigmaValues, analysis.Old.MeanCVMSE, ...
    'Color', oldColor, 'LineWidth', 2); hold(ax, 'on');
semilogx(ax, analysis.New.SigmaValues, analysis.New.MeanCVMSE, ...
    'Color', newColor, 'LineWidth', 2);
xlabel(ax, 'Gaussian sigma'); ylabel(ax, 'Equal-cue held-out MSE');
title(ax, 'Previous repeated-CV selection method');
legend(ax, {'Previous cue AI + AI:OD', 'Combined AI'}, 'Location', 'northwest'); grid(ax, 'on');
ax = nexttile(layout);
b = bar(ax, [analysis.Old.Nested.PerCueMeanR2 analysis.New.Nested.PerCueMeanR2]);
b(1).FaceColor = oldColor; b(2).FaceColor = newColor;
ax.XTickLabel = cellstr(analysis.PerCuePerformance.Condition);
ylabel(ax, 'Nested held-out R^2'); title(ax, 'Sigma and beta selected inside training data');
legend(ax, {'Previous cue AI + AI:OD', 'Combined AI'}, 'Location', 'northwest'); grid(ax, 'on');
ax = nexttile(layout);
test = analysis.Significance;
errorbar(ax, 1:5, test.MSEImprovement, test.MSEImprovement-test.ImprovementCILow, ...
    test.ImprovementCIHigh-test.MSEImprovement, 'o', 'Color', newColor, ...
    'LineWidth', 1.5, 'MarkerFaceColor', newColor);
yline(ax, 0, 'k--'); ax.XTick = 1:5; xlim(ax, [0.5 5.5]);
ax.XTickLabel = {'All cues', 'Dom', 'Combined', 'Stereo', 'NonDom'};
ylabel(ax, 'Old MSE - new MSE (positive = improvement)');
title(ax, sprintf('Corrected 95%% CI | primary one-sided p = %.4g', test.PImprovementOneSided(1)));
grid(ax, 'on');
ax = nexttile(layout);
plot(ax, analysis.OuterFoldAudit.OldSigma, 'o-', 'Color', oldColor); hold(ax, 'on');
plot(ax, analysis.OuterFoldAudit.NewSigma, 'o-', 'Color', newColor);
ax.YScale = 'log'; xlabel(ax, 'Outer evaluation fold'); ylabel(ax, 'Inner-CV selected sigma');
title(ax, 'Sigma stability across held-out folds'); grid(ax, 'on');
title(layout, sprintf('%s %s | matched CV comparison | N = %d sessions', ...
    analysis.Area, analysis.UnitType, analysis.SessionCount));
exportgraphics(f, fullfile(analysis.OutputFolder, 'GaussianChannelCVComparison.png'), 'Resolution', 200);
savefig(f, fullfile(analysis.OutputFolder, 'GaussianChannelCVComparison.fig'));
end

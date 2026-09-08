function comparison = compareGaussianChannelCVErrors(oldFoldMSE, newFoldMSE, testTrainRatio)
%COMPAREGAUSSIANCHANNELCVERRORS Corrected repeated-CV paired t comparison.
% Positive old-minus-new MSE means the new model improved. Uses the
% Nadeau-Bengio correction SE=sqrt((1/n+mean(nTest/nTrain))*var(d)).
% Input dimensions: repeat x fold x [equal-cue aggregate, Dom, Comb, Stereo, NonDom].
% The aggregate is the primary test. Four cue-wise p-values receive Holm
% adjustment. These are approximate repeated-CV tests, not independent-fold tests.

arguments
    oldFoldMSE double
    newFoldMSE double
    testTrainRatio double
end
if ~isequal(size(oldFoldMSE), size(newFoldMSE), size(testTrainRatio)) || ...
        size(oldFoldMSE, 3) ~= 5 || any(~isfinite(oldFoldMSE), 'all') || ...
        any(~isfinite(newFoldMSE), 'all') || any(~isfinite(testTrainRatio), 'all') || ...
        any(testTrainRatio <= 0, 'all')
    error('GaussianChannelCV:ComparisonSize', 'Expected matched finite repeat-by-fold-by-5 errors and positive test/train ratios.');
end
conditions = ["Equal-cue aggregate"; "Dominant"; "Combined"; "Stereo"; "NonDominant"];
n = size(oldFoldMSE, 1) * size(oldFoldMSE, 2);
if n < 2
    error('GaussianChannelCV:ComparisonCount', 'At least two paired fold differences are required.');
end
oldMSE = reshape(mean(oldFoldMSE, [1 2]), 5, 1);
newMSE = reshape(mean(newFoldMSE, [1 2]), 5, 1);
delta = oldMSE - newMSE;
se = nan(5, 1); t = se; p = se; pTwoSided = se;
ciLow = se; ciHigh = se;
for group = 1:5
    differences = reshape(oldFoldMSE(:, :, group) - newFoldMSE(:, :, group), [], 1);
    ratio = mean(testTrainRatio(:, :, group), 'all');
    se(group) = sqrt((1 ./ n + ratio) .* var(differences, 0));
    if se(group) == 0
        if delta(group) == 0
            t(group) = 0; p(group) = 1; pTwoSided(group) = 1;
        else
            t(group) = sign(delta(group)) .* Inf;
            p(group) = double(delta(group) < 0);
            pTwoSided(group) = 0;
        end
    else
        t(group) = delta(group) ./ se(group);
        p(group) = tcdf(t(group), n - 1, 'upper');
        pTwoSided(group) = min(1, 2 .* tcdf(abs(t(group)), n - 1, 'upper'));
    end
    margin = tinv(0.975, n - 1) .* se(group);
    ciLow(group) = delta(group) - margin;
    ciHigh(group) = delta(group) + margin;
end
adjusted = p;
[sortedP, order] = sort(p(2:5));
holm = min(1, cummax(sortedP .* (4:-1:1)'));
adjusted(1 + order) = holm;
significant = delta > 0 & adjusted < 0.05;
comparison = table(conditions, oldMSE, newMSE, delta, ...
    100 .* delta ./ oldMSE, se, ciLow, ciHigh, t, repmat(n - 1, 5, 1), ...
    p, pTwoSided, adjusted, significant, 'VariableNames', ...
    {'Condition', 'OldMeanFoldMSE', 'NewMeanFoldMSE', 'MSEImprovement', ...
    'PercentErrorReduction', 'CorrectedSE', 'ImprovementCILow', ...
    'ImprovementCIHigh', 'T', 'DF', 'PImprovementOneSided', 'PTwoSided', ...
    'PImprovementHolmWithinCues', 'SignificantImprovement'});
end

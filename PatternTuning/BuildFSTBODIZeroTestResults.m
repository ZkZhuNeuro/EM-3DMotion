function results = BuildFSTBODIZeroTestResults(T)
%BUILDFSTBODIZEROTESTRESULTS Rank-sum test BODI distributions against zero.

arguments
    T table
end

preferences = ["Toward"; "Away"];
nTests = numel(preferences);
N = zeros(nTests, 1);
Mean = nan(nTests, 1);
Median = nan(nTests, 1);
RankSum = nan(nTests, 1);
ZValue = nan(nTests, 1);
PValue = nan(nTests, 1);

for testIndex = 1:nTests
    mask = T.CombinedCuePreference == preferences(testIndex) & T.Valid_BODI;
    values = T.BODI(mask);
    values = values(isfinite(values));
    N(testIndex) = numel(values);
    if isempty(values)
        continue
    end
    Mean(testIndex) = mean(values);
    Median(testIndex) = median(values);
    zeroReference = zeros(size(values));
    [PValue(testIndex), ~, stats] = ranksum( ...
        values, zeroReference, 'tail', 'both');
    if isfield(stats, 'ranksum')
        RankSum(testIndex) = stats.ranksum;
    end
    if isfield(stats, 'zval')
        ZValue(testIndex) = stats.zval;
    end
end

Index = repmat("BODI", nTests, 1);
Preference = preferences;
Test = repmat("Two-sided Wilcoxon rank-sum vs zero reference", nTests, 1);
NullValue = zeros(nTests, 1);
FamilySize = repmat(nTests, nTests, 1);
PValue_Bonferroni = min(PValue .* nTests, 1);
Significant_Uncorrected = PValue < 0.05;
Significant_Bonferroni = PValue_Bonferroni < 0.05;
results = table(Index, Preference, Test, NullValue, N, Mean, Median, ...
    RankSum, ZValue, PValue, Significant_Uncorrected, FamilySize, ...
    PValue_Bonferroni, Significant_Bonferroni);
end

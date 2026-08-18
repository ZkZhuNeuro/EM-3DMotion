function TestBuildFSTBODIZeroTestResults
%TESTBUILDFSTBODIZEROTESTRESULTS Verify BODI uses ranksum versus zeros.

T = table();
T.CombinedCuePreference = ["Toward"; "Toward"; "Toward"; ...
    "Away"; "Away"; "Away"];
T.BODI = [0.1; 0.2; 0.3; -0.2; 0; 0.1];
T.Valid_BODI = true(height(T), 1);

results = BuildFSTBODIZeroTestResults(T);
assert(height(results) == 2);
assert(ismember('RankSum', results.Properties.VariableNames));
assert(~ismember('SignedRank', results.Properties.VariableNames));
assert(all(contains(results.Test, "rank-sum")));

for rowIndex = 1:height(results)
    values = T.BODI(T.CombinedCuePreference == results.Preference(rowIndex));
    expectedP = ranksum(values, zeros(size(values)), 'tail', 'both');
    assert(abs(results.PValue(rowIndex) - expectedP) < 1e-12);
end

fprintf('TestBuildFSTBODIZeroTestResults passed.\n');
end

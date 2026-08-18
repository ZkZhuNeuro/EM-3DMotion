%TESTBUILDFSTDATASETCOMPARISONSTATISTICS Synthetic comparison smoke test.

lo = synthetic_table("Lo", [0.1; 0.2; 0.3; 0.4], ...
    [0.05; 0.10; 0.15; 0.20]);
em = synthetic_table("EM", [0.2; 0.3; 0.4; 0.5], ...
    [0.10; 0.15; 0.20; 0.25]);
loZero = synthetic_zero_tests();
emZero = synthetic_zero_tests();
stats = BuildFSTDatasetComparisonStatistics(lo, em, loZero, emZero, ...
    BootstrapIterations=200, BootstrapSeed=17);

assert(isequal(stats.Metric, ["PDI"; "BODI"]));
assert(all(stats.Lo_N_Selected == 4 & stats.EM_N_Selected == 4));
assert(all(stats.Lo_N_Valid == 4 & stats.EM_N_Valid == 4));
assert(abs(stats.MeanDifference_EM_Minus_Lo(1) - 0.1) < 1e-12);
assert(stats.HedgesG_EM_Minus_Lo(1) > 0);
assert(stats.CliffsDelta_EM_Minus_Lo(1) > 0);
assert(all(stats.BootstrapIterations == 200));
fprintf('TestBuildFSTDatasetComparisonStatistics passed.\n');

function T = synthetic_table(dataset, pdi, bodi)
n = numel(pdi);
SourceDataset = repmat(dataset, n, 1);
CombinedCuePreference = ["Toward"; "Away"; "Toward"; "Away"];
TDI = pdi;
ADI = pdi;
Valid_TDI = true(n, 1);
Valid_ADI = true(n, 1);
PDI_Component = ["TDI"; "ADI"; "TDI"; "ADI"];
PDI_Numerator = pdi;
PDI_Denominator = ones(n, 1);
PDI = pdi;
Valid_PDI = true(n, 1);
Stereo_FR = ones(n, 1);
Combined_FR = (1 + bodi) ./ (1 - bodi);
BODI = bodi;
Valid_BODI = true(n, 1);
T = table(SourceDataset, CombinedCuePreference, TDI, ADI, ...
    Valid_TDI, Valid_ADI, PDI_Component, PDI_Numerator, PDI_Denominator, ...
    PDI, Valid_PDI, Combined_FR, Stereo_FR, BODI, Valid_BODI);
end

function T = synthetic_zero_tests()
Metric = ["PDI"; "BODI"];
PValue_Bonferroni = [0.02; 0.04];
T = table(Metric, PValue_Bonferroni);
end

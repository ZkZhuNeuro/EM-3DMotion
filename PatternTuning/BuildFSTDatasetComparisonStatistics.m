function StatisticsTable = BuildFSTDatasetComparisonStatistics( ...
        LoResultTable, EMResultTable, LoZeroTests, EMZeroTests, options)
%BUILDFSTDATASETCOMPARISONSTATISTICS Compare Lo and EM PDI/BODI results.
%   Effect-size signs are EM minus Lo. Hedges' g is a bias-corrected
%   pooled-SD standardized mean difference. Cliff's delta is
%   P(EM > Lo) - P(EM < Lo) with a deterministic percentile-bootstrap CI.

arguments
    LoResultTable table
    EMResultTable table
    LoZeroTests table
    EMZeroTests table
    options.BootstrapIterations (1, 1) double ...
        {mustBeInteger, mustBePositive} = 10000
    options.BootstrapSeed (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 1280812
end

validate_result_table(LoResultTable, "Lo");
validate_result_table(EMResultTable, "EM");

Metric = ["PDI"; "BODI"];
Definition = [ ...
    "TDI for Toward; ADI for Away; matched slow 2D speed (~4.2 deg/s)"; ...
    "(Combined_FR-Stereo_FR)/(Combined_FR+Stereo_FR) at the preferred coherence endpoint"];
EffectDirection = repmat("EM minus Lo (positive = larger in EM)", 2, 1);
BetweenDatasetTest = repmat("Two-sided Wilcoxon rank-sum (EM vs Lo)", 2, 1);

Lo_N_Selected = repmat(height(LoResultTable), 2, 1);
EM_N_Selected = repmat(height(EMResultTable), 2, 1);
Lo_N_Toward = repmat(nnz(LoResultTable.CombinedCuePreference == "Toward"), 2, 1);
Lo_N_Away = repmat(nnz(LoResultTable.CombinedCuePreference == "Away"), 2, 1);
EM_N_Toward = repmat(nnz(EMResultTable.CombinedCuePreference == "Toward"), 2, 1);
EM_N_Away = repmat(nnz(EMResultTable.CombinedCuePreference == "Away"), 2, 1);

nMetrics = numel(Metric);
Lo_N_Valid = zeros(nMetrics, 1);
EM_N_Valid = zeros(nMetrics, 1);
Lo_Mean = nan(nMetrics, 1);
Lo_SD = nan(nMetrics, 1);
Lo_SEM = nan(nMetrics, 1);
Lo_Mean_CI95_Lower = nan(nMetrics, 1);
Lo_Mean_CI95_Upper = nan(nMetrics, 1);
Lo_Median = nan(nMetrics, 1);
Lo_Q1 = nan(nMetrics, 1);
Lo_Q3 = nan(nMetrics, 1);
EM_Mean = nan(nMetrics, 1);
EM_SD = nan(nMetrics, 1);
EM_SEM = nan(nMetrics, 1);
EM_Mean_CI95_Lower = nan(nMetrics, 1);
EM_Mean_CI95_Upper = nan(nMetrics, 1);
EM_Median = nan(nMetrics, 1);
EM_Q1 = nan(nMetrics, 1);
EM_Q3 = nan(nMetrics, 1);
MeanDifference_EM_Minus_Lo = nan(nMetrics, 1);
MedianDifference_EM_Minus_Lo = nan(nMetrics, 1);
HedgesG_EM_Minus_Lo = nan(nMetrics, 1);
HedgesG_CI95_Lower = nan(nMetrics, 1);
HedgesG_CI95_Upper = nan(nMetrics, 1);
CliffsDelta_EM_Minus_Lo = nan(nMetrics, 1);
CliffsDelta_CI95_Lower = nan(nMetrics, 1);
CliffsDelta_CI95_Upper = nan(nMetrics, 1);
RankSum_EM = nan(nMetrics, 1);
ZValue = nan(nMetrics, 1);
PValue = nan(nMetrics, 1);
Lo_Zero_PValue_Bonferroni = nan(nMetrics, 1);
EM_Zero_PValue_Bonferroni = nan(nMetrics, 1);

for metricIndex = 1:nMetrics
    metricName = Metric(metricIndex);
    lo = metric_values(LoResultTable, metricName);
    em = metric_values(EMResultTable, metricName);
    Lo_N_Valid(metricIndex) = numel(lo);
    EM_N_Valid(metricIndex) = numel(em);

    [Lo_Mean(metricIndex), Lo_SD(metricIndex), Lo_SEM(metricIndex), ...
        Lo_Mean_CI95_Lower(metricIndex), Lo_Mean_CI95_Upper(metricIndex), ...
        Lo_Median(metricIndex), Lo_Q1(metricIndex), Lo_Q3(metricIndex)] = ...
        describe_values(lo);
    [EM_Mean(metricIndex), EM_SD(metricIndex), EM_SEM(metricIndex), ...
        EM_Mean_CI95_Lower(metricIndex), EM_Mean_CI95_Upper(metricIndex), ...
        EM_Median(metricIndex), EM_Q1(metricIndex), EM_Q3(metricIndex)] = ...
        describe_values(em);

    MeanDifference_EM_Minus_Lo(metricIndex) = ...
        EM_Mean(metricIndex) - Lo_Mean(metricIndex);
    MedianDifference_EM_Minus_Lo(metricIndex) = ...
        EM_Median(metricIndex) - Lo_Median(metricIndex);
    [HedgesG_EM_Minus_Lo(metricIndex), HedgesG_CI95_Lower(metricIndex), ...
        HedgesG_CI95_Upper(metricIndex)] = hedges_g(em, lo);
    CliffsDelta_EM_Minus_Lo(metricIndex) = cliffs_delta(em, lo);
    [CliffsDelta_CI95_Lower(metricIndex), ...
        CliffsDelta_CI95_Upper(metricIndex)] = bootstrap_cliffs_delta_ci( ...
        em, lo, options.BootstrapIterations, ...
        options.BootstrapSeed + metricIndex - 1);

    [PValue(metricIndex), ~, testStats] = ranksum(em, lo, 'tail', 'both');
    if isfield(testStats, 'ranksum')
        RankSum_EM(metricIndex) = testStats.ranksum;
    end
    if isfield(testStats, 'zval')
        ZValue(metricIndex) = testStats.zval;
    end
    Lo_Zero_PValue_Bonferroni(metricIndex) = ...
        zero_test_p_value(LoZeroTests, metricName);
    EM_Zero_PValue_Bonferroni(metricIndex) = ...
        zero_test_p_value(EMZeroTests, metricName);
end

FamilySize = repmat(nMetrics, nMetrics, 1);
PValue_Bonferroni = min(PValue .* FamilySize, 1);
Significant_Bonferroni = PValue_Bonferroni < 0.05;
BootstrapIterations = repmat(options.BootstrapIterations, nMetrics, 1);
BootstrapSeed = options.BootstrapSeed + (0:nMetrics-1)';

StatisticsTable = table(Metric, Definition, EffectDirection, ...
    Lo_N_Selected, Lo_N_Valid, Lo_N_Toward, Lo_N_Away, ...
    EM_N_Selected, EM_N_Valid, EM_N_Toward, EM_N_Away, ...
    Lo_Mean, Lo_SD, Lo_SEM, Lo_Mean_CI95_Lower, Lo_Mean_CI95_Upper, ...
    Lo_Median, Lo_Q1, Lo_Q3, ...
    EM_Mean, EM_SD, EM_SEM, EM_Mean_CI95_Lower, EM_Mean_CI95_Upper, ...
    EM_Median, EM_Q1, EM_Q3, ...
    MeanDifference_EM_Minus_Lo, MedianDifference_EM_Minus_Lo, ...
    HedgesG_EM_Minus_Lo, HedgesG_CI95_Lower, HedgesG_CI95_Upper, ...
    CliffsDelta_EM_Minus_Lo, CliffsDelta_CI95_Lower, ...
    CliffsDelta_CI95_Upper, BetweenDatasetTest, RankSum_EM, ZValue, ...
    PValue, FamilySize, PValue_Bonferroni, Significant_Bonferroni, ...
    Lo_Zero_PValue_Bonferroni, EM_Zero_PValue_Bonferroni, ...
    BootstrapIterations, BootstrapSeed);
StatisticsTable.Properties.Description = [ ...
    'Paper companion statistics for strict 1.28 FST 3D samples. ' ...
    'Effect-size signs are EM minus Lo. Hedges g uses a normal-approximation ' ...
    '95% CI; Cliff delta uses a deterministic percentile-bootstrap 95% CI.'];
end

function values = metric_values(T, metricName)
validName = "Valid_" + metricName;
values = double(T.(metricName)(T.(validName) & isfinite(T.(metricName))));
values = values(:);
end

function [valueMean, valueSD, valueSEM, ciLow, ciHigh, ...
        valueMedian, q1, q3] = describe_values(values)
n = numel(values);
valueMean = mean(values);
valueSD = std(values);
valueSEM = valueSD / sqrt(n);
criticalT = tinv(0.975, n - 1);
ciLow = valueMean - criticalT * valueSEM;
ciHigh = valueMean + criticalT * valueSEM;
valueMedian = median(values);
quartiles = prctile(values, [25, 75]);
q1 = quartiles(1);
q3 = quartiles(2);
end

function [g, ciLow, ciHigh] = hedges_g(groupEM, groupLo)
nEM = numel(groupEM);
nLo = numel(groupLo);
degreesFreedom = nEM + nLo - 2;
pooledVariance = ((nEM - 1) * var(groupEM) + ...
    (nLo - 1) * var(groupLo)) / degreesFreedom;
if pooledVariance <= 0 || ~isfinite(pooledVariance)
    g = nan;
    ciLow = nan;
    ciHigh = nan;
    return
end
cohenD = (mean(groupEM) - mean(groupLo)) / sqrt(pooledVariance);
smallSampleCorrection = 1 - 3 / (4 * (nEM + nLo) - 9);
g = smallSampleCorrection * cohenD;
standardError = sqrt((nEM + nLo) / (nEM * nLo) + ...
    g ^ 2 / (2 * degreesFreedom));
ciLow = g - 1.96 * standardError;
ciHigh = g + 1.96 * standardError;
end

function delta = cliffs_delta(groupEM, groupLo)
pairwiseSigns = sign(groupEM(:) - groupLo(:)');
delta = mean(pairwiseSigns, 'all');
end

function [ciLow, ciHigh] = bootstrap_cliffs_delta_ci( ...
        groupEM, groupLo, bootstrapIterations, seed)
previousRng = rng;
cleanup = onCleanup(@() rng(previousRng));
rng(seed, 'twister');
nEM = numel(groupEM);
nLo = numel(groupLo);
bootstrapDelta = nan(bootstrapIterations, 1);
for bootstrapIndex = 1:bootstrapIterations
    sampledEM = groupEM(randi(nEM, nEM, 1));
    sampledLo = groupLo(randi(nLo, nLo, 1));
    bootstrapDelta(bootstrapIndex) = cliffs_delta(sampledEM, sampledLo);
end
ci = prctile(bootstrapDelta, [2.5, 97.5]);
ciLow = ci(1);
ciHigh = ci(2);
clear cleanup
end

function pValue = zero_test_p_value(ZeroTests, metricName)
row = string(ZeroTests.Metric) == metricName;
if nnz(row) ~= 1
    error('BuildFSTDatasetComparisonStatistics:ZeroTestLookup', ...
        'Expected exactly one %s zero-test row.', metricName);
end
pValue = ZeroTests.PValue_Bonferroni(row);
end

function validate_result_table(T, expectedDataset)
required = {'SourceDataset', 'CombinedCuePreference', 'PDI_Component', ...
    'PDI_Numerator', 'PDI_Denominator', 'PDI', 'Valid_PDI', ...
    'Combined_FR', 'Stereo_FR', 'BODI', 'Valid_BODI'};
missing = setdiff(required, T.Properties.VariableNames);
if ~isempty(missing)
    error('BuildFSTDatasetComparisonStatistics:MissingVariables', ...
        'Missing variables: %s', strjoin(missing, ', '));
end
if ~all(string(T.SourceDataset) == expectedDataset)
    error('BuildFSTDatasetComparisonStatistics:DatasetMismatch', ...
        'Expected every row to be labeled %s.', expectedDataset);
end

preference = string(T.CombinedCuePreference);
toward = preference == "Toward";
away = preference == "Away";
expectedComponent = repmat("Undefined", height(T), 1);
expectedComponent(toward) = "TDI";
expectedComponent(away) = "ADI";
expectedValidPDI = (toward | away) & isfinite(T.PDI_Numerator) ...
    & isfinite(T.PDI_Denominator) & T.PDI_Denominator ~= 0;
expectedPDI = nan(height(T), 1);
expectedPDI(expectedValidPDI) = T.PDI_Numerator(expectedValidPDI) ...
    ./ T.PDI_Denominator(expectedValidPDI);
if ~isequal(string(T.PDI_Component), expectedComponent) || ...
        ~isequal(logical(T.Valid_PDI), expectedValidPDI) || ...
        any(abs(T.PDI(expectedValidPDI) - expectedPDI(expectedValidPDI)) > 1e-12)
    error('BuildFSTDatasetComparisonStatistics:PDIDefinitionChanged', ...
        'PDI no longer matches TDI for Toward and ADI for Away neurons.');
end

bodiDenominator = T.Combined_FR + T.Stereo_FR;
expectedValidBODI = isfinite(T.Combined_FR) & isfinite(T.Stereo_FR) ...
    & isfinite(bodiDenominator) & bodiDenominator ~= 0;
expectedBODI = nan(height(T), 1);
expectedBODI(expectedValidBODI) = ...
    (T.Combined_FR(expectedValidBODI) - T.Stereo_FR(expectedValidBODI)) ...
    ./ bodiDenominator(expectedValidBODI);
if ~isequal(logical(T.Valid_BODI), expectedValidBODI) || ...
        any(abs(T.BODI(expectedValidBODI) - expectedBODI(expectedValidBODI)) > 1e-12)
    error('BuildFSTDatasetComparisonStatistics:BODIDefinitionChanged', ...
        'BODI no longer matches (Combined_FR-Stereo_FR)/(Combined_FR+Stereo_FR).');
end
end

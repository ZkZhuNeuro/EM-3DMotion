function VerificationTable = VerifyFSTPDIAndBODIAug12Summary( ...
        LoResultTable, EMResultTable, CombinedResultTable, ...
        LoZeroTests, EMZeroTests, CombinedZeroTests)
%VERIFYFSTPDIANDBODIAUG12SUMMARY Check results against the Aug 12 summary.

arguments
    LoResultTable table
    EMResultTable table
    CombinedResultTable table
    LoZeroTests table
    EMZeroTests table
    CombinedZeroTests table
end

Dataset = ["Lo"; "EM"; "Combined"];
expected = [ ...
    58, 0.154, 0.185, 8.76e-08, 0.140, 0.127, 1.54e-11; ...
    24, 0.202, 0.209, 2.60e-07, 0.178, 0.191, 4.07e-06; ...
    82, 0.168, 0.197, 1.34e-13, 0.151, 0.148, 1.27e-16];
resultTables = {LoResultTable; EMResultTable; CombinedResultTable};
zeroTables = {LoZeroTests; EMZeroTests; CombinedZeroTests};
measureNames = ["N_Selected", "PDI_Mean", "PDI_Median", ...
    "PDI_PValue_Bonferroni", "BODI_Mean", "BODI_Median", ...
    "BODI_PValue_Bonferroni"];

nRows = numel(Dataset) * numel(measureNames);
ReferenceDate = repmat(datetime(2026, 8, 12), nRows, 1);
DatasetOut = strings(nRows, 1);
Measure = strings(nRows, 1);
Expected = nan(nRows, 1);
Actual = nan(nRows, 1);
Difference = nan(nRows, 1);
RelativeError = nan(nRows, 1);
ToleranceRule = strings(nRows, 1);
Pass = false(nRows, 1);

outRow = 0;
for datasetIndex = 1:numel(Dataset)
    T = resultTables{datasetIndex};
    zeroTests = zeroTables{datasetIndex};
    pdi = T.PDI(T.Valid_PDI & isfinite(T.PDI));
    bodi = T.BODI(T.Valid_BODI & isfinite(T.BODI));
    actual = [height(T), mean(pdi), median(pdi), ...
        zero_p(zeroTests, "PDI"), mean(bodi), median(bodi), ...
        zero_p(zeroTests, "BODI")];
    for measureIndex = 1:numel(measureNames)
        outRow = outRow + 1;
        DatasetOut(outRow) = Dataset(datasetIndex);
        Measure(outRow) = measureNames(measureIndex);
        Expected(outRow) = expected(datasetIndex, measureIndex);
        Actual(outRow) = actual(measureIndex);
        Difference(outRow) = Actual(outRow) - Expected(outRow);
        RelativeError(outRow) = abs(Difference(outRow)) ...
            / max(abs(Expected(outRow)), eps);
        if measureIndex == 1
            ToleranceRule(outRow) = "exact";
            Pass(outRow) = Difference(outRow) == 0;
        elseif ismember(measureIndex, [2, 3, 5, 6])
            ToleranceRule(outRow) = "absolute error <= 0.0005";
            Pass(outRow) = abs(Difference(outRow)) <= 5e-4 + 10 * eps;
        else
            ToleranceRule(outRow) = "relative error <= 1%";
            Pass(outRow) = RelativeError(outRow) <= 0.01;
        end
    end
end

Dataset = DatasetOut;
VerificationTable = table(ReferenceDate, Dataset, Measure, Expected, Actual, ...
    Difference, RelativeError, ToleranceRule, Pass);
VerificationTable.Properties.Description = ...
    ['Comparison with the rounded FST3D population table documented on ' ...
    'August 12, 2026 in PatternTuning/README.md and Final_128 outputs.'];
if ~all(Pass)
    failed = VerificationTable(~Pass, {'Dataset', 'Measure', ...
        'Expected', 'Actual', 'ToleranceRule'});
    disp(failed);
    error('VerifyFSTPDIAndBODIAug12Summary:ReferenceMismatch', ...
        '%d Aug 12 reference checks failed.', height(failed));
end
end

function pValue = zero_p(T, metricName)
row = string(T.Metric) == metricName;
if nnz(row) ~= 1
    error('VerifyFSTPDIAndBODIAug12Summary:ZeroTestLookup', ...
        'Expected exactly one %s zero-test row.', metricName);
end
pValue = T.PValue_Bonferroni(row);
end

function TestBuildFSTPDIAndBODITable
%TESTBUILDFSTPDIANDBODITABLE Verify preference selection and pooled tests.

pattern = table();
pattern.SourceRow = [10; 20; 30];
pattern.Date = datetime([2026; 2026; 2026], [1; 1; 1], [1; 2; 3]);
pattern.Monkey = ["Jim"; "Jim"; "Clay"];
pattern.ROI = repmat("FST", 3, 1);
pattern.NeuroType = repmat("3D", 3, 1);
pattern.Z3D_v_Z2D = [2; 3; 4];
pattern.Combined_AI = [0.5; -0.4; 0];
pattern.CombinedCuePreference = ["Toward"; "Away"; "Neutral"];
pattern.IsMatchedSlowSpeed = true(3, 1);
pattern.TDI_Numerator = [2; 3; 4];
pattern.TDI_Denominator = [10; 10; 10];
pattern.TDI = [0.2; 0.3; 0.4];
pattern.ADI_Numerator = [-1; -5; -2];
pattern.ADI_Denominator = [10; 10; 10];
pattern.ADI = [-0.1; -0.5; -0.2];
pattern.Valid_TDI = true(3, 1);
pattern.Valid_ADI = true(3, 1);

bodi = table();
bodi.SourceRow = [30; 10; 20];
bodi.CombinedCuePreference = ["Neutral"; "Toward"; "Away"];
bodi.PreferredCoherence = [nan; 1; -1];
bodi.Combined_FR = [nan; 30; 20];
bodi.Stereo_FR = [nan; 10; 30];
bodi.N_Combined_FR = [0; 2; 2];
bodi.N_Stereo_FR = [0; 2; 2];
bodi.BODI_Numerator = [nan; 20; -10];
bodi.BODI_Denominator = [nan; 40; 50];
bodi.BODI = [nan; 0.5; -0.2];
bodi.Valid_BODI = [false; true; true];

result = BuildFSTPDIAndBODITable(pattern, bodi, ...
    SourceDataset="Test", SelectionCriterion="synthetic");
assert(isequal(result.PDI_Component, ["TDI"; "ADI"; "Undefined"]));
assert(abs(result.PDI(1) - 0.2) < 1e-12);
assert(abs(result.PDI(2) + 0.5) < 1e-12);
assert(isnan(result.PDI(3)) && ~result.Valid_PDI(3));
assert(abs(result.BODI(1) - 0.5) < 1e-12);
assert(abs(result.BODI(2) + 0.2) < 1e-12);
assert(~ismember('TDI', result.Properties.VariableNames));
assert(~ismember('ADI', result.Properties.VariableNames));

tests = BuildFSTPDIAndBODIZeroTests(result);
assert(isequal(tests.Metric, ["PDI"; "BODI"]));
assert(all(tests.N == 2));
summary = SummarizeFSTPDIAndBODI(result);
assert(summary.N_Selected(summary.GroupType == "All") == 3);
fprintf('TestBuildFSTPDIAndBODITable passed.\n');
end

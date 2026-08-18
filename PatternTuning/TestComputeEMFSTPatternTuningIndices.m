function TestComputeEMFSTPatternTuningIndices
%TESTCOMPUTEEMFSTPATTERNTUNINGINDICES Synthetic EM mapping and formula test.

tuning3D = nan(4, 8, 2);
tuning3D(2, end, 2) = 10;
tuning3D(3, end, 2) = 20;
tuning3D(2, 1, 2) = 30;
tuning3D(3, 1, 2) = 40;
tuning3D(1, end, 2) = 50;
tuning3D(4, end, 2) = 30;
tuning3D(1, 1, 2) = 20;
tuning3D(4, 1, 2) = 60;

raw2D = nan(8, 2, 3, 3);
raw2D(1, 1, 1, :) = [1, 3, nan];
raw2D(1, 1, 2, :) = [4, 4, nan];
raw2D(5, 1, 1, :) = [6, nan, nan];
raw2D(5, 1, 2, :) = [8, nan, nan];
raw2D(1, 2, 1, :) = [12, nan, nan];
raw2D(1, 2, 2, :) = [14, nan, nan];
raw2D(5, 2, 1, :) = [16, nan, nan];
raw2D(5, 2, 2, :) = [18, nan, nan];

Date = [datetime(2024, 1, 1); datetime(2024, 1, 2)];
Monkey = {"Synthetic"; "Synthetic"};
ROI = {"FST"; "FST"};
StimElec = [2; 2];
ND = {"3D"; "2D"};
p_AI = {[0.01; 0.01; 0.01; 0.01]; [0.01; 0.01; 0.01; 0.01]};
aiMatrix = nan(4, 2);
aiMatrix(1, 2) = 0.25;
AI = {aiMatrix; aiMatrix};
Z3D_v_Z2D = {1.5; -1.5};
tuning_mean = {tuning3D; tuning3D};
Raw2D_StimCh = {raw2D; raw2D};
OriginalRecIdx = [101; 102];
unit_table_gof = table(Date, Monkey, ROI, StimElec, ND, p_AI, AI, ...
    Z3D_v_Z2D, tuning_mean, Raw2D_StimCh, OriginalRecIdx);

[slow, bySpeed, summary, bodi, bodiSummary] = ...
    ComputeEMFSTPatternTuningIndices(unit_table_gof);

assert(height(slow) == 1 && height(bySpeed) == 2);
assert(slow.SourceRow == 1 && slow.OriginalRecIdx == 101);
assert(slow.SpeedRank_2D == 1 && slow.IsMatchedSlowSpeed);
assert(slow.Combined_AI == 0.25 && slow.CombinedCuePreference == "Toward");
assert(slow.T_L == 10 && slow.T_R == 20 && slow.A_L == 30 && slow.A_R == 40);
assert(slow.R_L == 2 && slow.R_R == 4 && slow.L_L == 6 && slow.L_R == 8);
assert(abs(slow.TDI - 0.5) < 1e-12);
assert(abs(slow.ADI - 0.75) < 1e-12);
assert(height(bodi) == 1 && bodi.PreferredCoherence == 1);
assert(bodi.Combined_FR == 50 && bodi.Stereo_FR == 30);
assert(abs(bodi.BODI - 0.25) < 1e-12 && bodi.Valid_BODI);
assert(~ismember('BODI', bySpeed.Properties.VariableNames));
assert(isnan(slow.N_T_L) && slow.N_R_L == 2 && slow.N_R_R == 2);

fast = bySpeed(bySpeed.SpeedRank_2D == 2, :);
assert(fast.SpeedLabel_2D == "fast (~12.5 deg/s)");
assert(~fast.IsMatchedSlowSpeed);
assert(fast.R_L == 12 && fast.R_R == 14 && fast.L_L == 16 && fast.L_R == 18);
assert(abs(fast.TDI) < 1e-12);
assert(abs(fast.ADI - 0.4) < 1e-12);
assert(all(fast.Valid_TDI & fast.Valid_ADI));
assert(all(summary.N_Selected(summary.Group == "All") == 1));
assert(abs(bodiSummary.BODI_Mean(bodiSummary.Group == "All") - 0.25) < 1e-12);

awayUnitTable = unit_table_gof;
awayAI = aiMatrix;
awayAI(1, 2) = -0.25;
awayUnitTable.AI{1} = awayAI;
[~, ~, ~, away] = ComputeEMFSTPatternTuningIndices(awayUnitTable);
assert(away.PreferredCoherence == -1);
assert(away.Combined_FR == 20 && away.Stereo_FR == 60);
assert(abs(away.BODI + 0.5) < 1e-12);

thresholded = ComputeEMFSTPatternTuningIndices( ...
    unit_table_gof, Z3DMinus2DThreshold=1.28);
assert(height(thresholded) == 1 && thresholded.Z3D_v_Z2D == 1.5);
thresholdRejected = false;
try
    ComputeEMFSTPatternTuningIndices( ...
        unit_table_gof, Z3DMinus2DThreshold=2);
catch ME
    thresholdRejected = strcmp(ME.identifier, ...
        'ComputeEMFSTPatternTuningIndices:NoSelectedUnits');
end
assert(thresholdRejected);

[twoDPattern, ~, ~, twoDBODI] = ComputeEMFSTPatternTuningIndices( ...
    unit_table_gof, TargetROI="FST", NeuroType="2D", ...
    Z3DMinus2DMaximum=-1.28);
assert(height(twoDPattern) == 1 && twoDPattern.SourceRow == 2);
assert(twoDPattern.NeuroType == "2D" && twoDPattern.Z3D_v_Z2D == -1.5);
assert(abs(twoDPattern.TDI - 0.5) < 1e-12);
assert(abs(twoDBODI.BODI - 0.25) < 1e-12);

mtUnitTable = unit_table_gof;
mtUnitTable.ROI(:) = {"MT"};
[mtPattern, ~, ~, mtBODI] = ComputeEMFSTPatternTuningIndices( ...
    mtUnitTable, TargetROI="MT", NeuroType="2D", ...
    Z3DMinus2DMaximum=-1.28);
assert(mtPattern.ROI == "MT" && mtPattern.NeuroType == "2D");
assert(abs(mtBODI.BODI - 0.25) < 1e-12);

fprintf('TestComputeEMFSTPatternTuningIndices passed.\n');
end

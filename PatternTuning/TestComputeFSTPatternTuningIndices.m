function TestComputeFSTPatternTuningIndices
%TESTCOMPUTEFSTPATTERNTUNINGINDICES Synthetic mapping and formula test.

response = nan(4, 13, 3);
response(2, 13, :) = [9, 11, nan];   % T_L = 10
response(3, 13, :) = [19, 21, nan];  % T_R = 20
response(2, 1, :) = [29, 31, nan];   % A_L = 30
response(3, 1, :) = [39, 41, nan];   % A_R = 40
response(1, 13, :) = [49, 51, nan];  % preferred Combined_FR = 50
response(4, 13, :) = [29, 31, nan];  % preferred Stereo_FR = 30
response(1, 1, :) = [19, 21, nan];   % away Combined_FR = 20
response(4, 1, :) = [59, 61, nan];   % away Stereo_FR = 60

raw2D = cell(3, 8, 2);
raw2D{1, 1, 1} = [1; 3; nan];  % R_L = 2: rightward, left eye
raw2D{2, 1, 1} = [4; 4];       % R_R = 4: rightward, right eye
raw2D{1, 5, 1} = 6;            % L_L = 6: leftward, left eye
raw2D{2, 5, 1} = 8;            % L_R = 8: leftward, right eye
raw2D{1, 1, 2} = 12;
raw2D{2, 1, 2} = 14;
raw2D{1, 5, 2} = 16;
raw2D{2, 5, 2} = 18;

Date = datetime(2020, 1, 1);
ROI = "FST";
Tetrode = 2;
Unit = 3;
NeuroResp = {response};
NeuroRespUnitTable = table(Date, ROI, Tetrode, Unit, NeuroResp);

RawFR_ByConditionDirectionSpeed = {raw2D};
ConditionCodesUsed = {[8001, 8002, 8003]};
DirectionDegreesGuess = {[0, 45, 90, 135, 180, 225, 270, 315]};
SpeedCodesUsed = {[7041, 7125]};
LateralMotionRawFRTable = table(Date, ROI, Tetrode, Unit, ...
    RawFR_ByConditionDirectionSpeed, ConditionCodesUsed, ...
    DirectionDegreesGuess, SpeedCodesUsed);

Monkey = "Synthetic";
sig_Anova_CLR = true;
Z_quad = 2;
Z3D_v_Z2D = 1.5;
Combined_AI = 0.25;
MIDTable = table(Date, ROI, Tetrode, Unit, Monkey, sig_Anova_CLR, ...
    Z_quad, Z3D_v_Z2D, Combined_AI);

[primary, bySpeed, summary, bodi, bodiSummary] = ComputeFSTPatternTuningIndices( ...
    NeuroRespUnitTable, LateralMotionRawFRTable, MIDTable);

assert(height(primary) == 1 && height(bySpeed) == 2);
assert(primary.SpeedCode_2D == 7041);
assert(primary.Z3D_v_Z2D == 1.5);
assert(primary.Combined_AI == 0.25 && primary.CombinedCuePreference == "Toward");
assert(primary.T_L == 10 && primary.T_R == 20);
assert(primary.A_L == 30 && primary.A_R == 40);
assert(primary.R_L == 2 && primary.R_R == 4);
assert(primary.L_L == 6 && primary.L_R == 8);
assert(abs(primary.TDI - 0.5) < 1e-12);
assert(abs(primary.ADI - 0.75) < 1e-12);
assert(height(bodi) == 1 && bodi.PreferredCoherence == 1);
assert(bodi.Combined_FR == 50 && bodi.Stereo_FR == 30);
assert(abs(bodi.BODI - 0.25) < 1e-12);
assert(primary.N_T_L == 2 && primary.N_R_L == 2);
assert(bodi.N_Combined_FR == 2 && bodi.N_Stereo_FR == 2);
assert(all(primary.Valid_TDI & primary.Valid_ADI) && bodi.Valid_BODI);
assert(~ismember('BODI', bySpeed.Properties.VariableNames));
fast = bySpeed(bySpeed.SpeedCode_2D == 7125, :);
assert(height(fast) == 1 && fast.SpeedLabel_2D == "fast (~12.6 deg/s)");
assert(fast.R_L == 12 && fast.R_R == 14 && fast.L_L == 16 && fast.L_R == 18);
assert(abs(fast.TDI) < 1e-12);
assert(abs(fast.ADI - 0.4) < 1e-12);
assert(all(fast.Valid_TDI & fast.Valid_ADI));
assert(~fast.IsMatchedSlowSpeed);
assert(all([fast.N_R_L, fast.N_R_R, fast.N_L_L, fast.N_L_R] == 1));
assert(summary.N_Selected(summary.Group == "All") == 1);
assert(abs(bodiSummary.BODI_Mean(bodiSummary.Group == "All") - 0.25) < 1e-12);

awayMID = MIDTable;
awayMID.Combined_AI = -0.25;
[~, ~, ~, away] = ComputeFSTPatternTuningIndices( ...
    NeuroRespUnitTable, LateralMotionRawFRTable, awayMID);
assert(away.PreferredCoherence == -1);
assert(away.Combined_FR == 20 && away.Stereo_FR == 60);
assert(abs(away.BODI + 0.5) < 1e-12);

relaxedMID = MIDTable;
relaxedMID.Z_quad = 1;
relaxedMID.Z3D_v_Z2D = 0.25;
canonicalRejected = false;
try
    ComputeFSTPatternTuningIndices( ...
        NeuroRespUnitTable, LateralMotionRawFRTable, relaxedMID);
catch ME
    canonicalRejected = strcmp(ME.identifier, ...
        'ComputeFSTPatternTuningIndices:NoSelectedUnits');
end
assert(canonicalRejected);
relaxed = ComputeFSTPatternTuningIndices( ...
    NeuroRespUnitTable, LateralMotionRawFRTable, relaxedMID, ...
    SelectionMode="positive-score");
assert(height(relaxed) == 1 && relaxed.Z3D_v_Z2D == 0.25);

zeroScoreMID = relaxedMID;
zeroScoreMID.Z3D_v_Z2D = 0;
zeroRejected = false;
try
    ComputeFSTPatternTuningIndices( ...
        NeuroRespUnitTable, LateralMotionRawFRTable, zeroScoreMID, ...
        SelectionMode="positive-score");
catch ME
    zeroRejected = strcmp(ME.identifier, ...
        'ComputeFSTPatternTuningIndices:NoSelectedUnits');
end
assert(zeroRejected);

twoDMID = MIDTable;
twoDMID.Z_quad = 4;
twoDMID.Z3D_v_Z2D = -1.5;
[twoDPattern, ~, ~, twoDBODI] = ComputeFSTPatternTuningIndices( ...
    NeuroRespUnitTable, LateralMotionRawFRTable, twoDMID, ...
    SelectionMode="lo-2d-1.28", TargetROI="FST");
assert(height(twoDPattern) == 1 && twoDPattern.NeuroType == "2D");
assert(twoDPattern.ROI == "FST" && twoDBODI.NeuroType == "2D");
assert(abs(twoDPattern.TDI - 0.5) < 1e-12);
assert(abs(twoDBODI.BODI - 0.25) < 1e-12);

mtNeuroResp = NeuroRespUnitTable;
mtLateral = LateralMotionRawFRTable;
mtMID = twoDMID;
mtNeuroResp.ROI = "MT";
mtLateral.ROI = "MT";
mtMID.ROI = "MT";
[mtPattern, ~, ~, mtBODI] = ComputeFSTPatternTuningIndices( ...
    mtNeuroResp, mtLateral, mtMID, SelectionMode="lo-2d-1.28", ...
    TargetROI="MT");
assert(mtPattern.ROI == "MT" && mtPattern.NeuroType == "2D");
assert(abs(mtPattern.TDI - 0.5) < 1e-12);
assert(abs(mtBODI.BODI - 0.25) < 1e-12);

fastOnlyLateral = LateralMotionRawFRTable;
fastOnlyLateral.RawFR_ByConditionDirectionSpeed = {raw2D(:, :, 2)};
fastOnlyLateral.SpeedCodesUsed = {7125};
warning('off', 'ComputeFSTPatternTuningIndices:MissingMatchedSpeed');
warningCleanup = onCleanup(@() warning( ...
    'on', 'ComputeFSTPatternTuningIndices:MissingMatchedSpeed'));
[missingSlow, ~, ~, availableBODI] = ComputeFSTPatternTuningIndices( ...
    NeuroRespUnitTable, fastOnlyLateral, twoDMID, ...
    SelectionMode="lo-2d-1.28");
assert(height(missingSlow) == 1 && missingSlow.IsMatchedSlowSpeed);
assert(isnan(missingSlow.TDI) && isnan(missingSlow.ADI));
assert(~missingSlow.Valid_TDI && ~missingSlow.Valid_ADI);
assert(all([missingSlow.N_R_L, missingSlow.N_R_R, ...
    missingSlow.N_L_L, missingSlow.N_L_R] == 0));
assert(availableBODI.Valid_BODI && abs(availableBODI.BODI - 0.25) < 1e-12);
clear warningCleanup

fprintf('TestComputeFSTPatternTuningIndices passed.\n');
end

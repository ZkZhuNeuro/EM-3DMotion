function [PatternTuningTable, PatternTuningBySpeedTable, PatternTuningSummary, ...
        BinocularOpticFlowTable, BinocularOpticFlowSummary] = ...
    ComputeFSTPatternTuningIndices(NeuroRespUnitTable, LateralMotionRawFRTable, MIDTable, options)
%COMPUTEFSTPATTERNTUNINGINDICES Compute perspective-versus-lateral indices.
%   The primary output has one row for each selected Lo neuron and uses the
%   matched slow 2D speed (event code 7041, approximately 4.2 deg/s).
%   PatternTuningBySpeedTable retains one row per unit and available 2D
%   speed. TargetROI and SelectionMode select strict MT/FST 2D or 3D
%   populations while preserving the same response mapping and formulas.
%
%   Response labels follow motion_direction_eye:
%       T_L: toward, left-eye perspective cue
%       T_R: toward, right-eye perspective cue
%       A_L: away, left-eye perspective cue
%       A_R: away, right-eye perspective cue
%       R_L: rightward 2D motion, left eye
%       R_R: rightward 2D motion, right eye
%       L_L: leftward 2D motion, left eye
%       L_R: leftward 2D motion, right eye
%
%   TDI = (T_L + T_R - R_L - L_R) / ...
%         (T_L + T_R + R_L + L_R)
%   ADI = (A_L + A_R - L_L - R_R) / ...
%         (A_L + A_R + L_L + R_R)
%   BODI = (Combined_FR - Stereo_FR) / ...
%          (Combined_FR + Stereo_FR)
%   Combined_FR and Stereo_FR are evaluated at coherence +1 for
%   toward-preferring units and -1 for away-preferring units.

arguments
    NeuroRespUnitTable table
    LateralMotionRawFRTable table
    MIDTable table
    options.Matched2DSpeedCode (1, 1) double = 7041
    options.SelectionMode (1, 1) string = "lo-1.28"
    options.TargetROI (1, 1) string = "FST"
end

constants = analysis_constants(options.Matched2DSpeedCode);
validate_input_tables(NeuroRespUnitTable, LateralMotionRawFRTable, MIDTable);
verify_row_alignment(NeuroRespUnitTable, LateralMotionRawFRTable, MIDTable);

roi = upper(strtrim(string(MIDTable.ROI)));
targetROI = upper(strtrim(options.TargetROI));
if ~ismember(targetROI, ["MT", "FST"])
    error('ComputeFSTPatternTuningIndices:InvalidTargetROI', ...
        'TargetROI must be "MT" or "FST".');
end
if options.SelectionMode == "lo-1.28"
    isSelected = roi == targetROI ...
        & logical(MIDTable.sig_Anova_CLR) ...
        & MIDTable.Z_quad == 2;
    selectedNeuroType = "3D";
elseif options.SelectionMode == "lo-2d-1.28"
    isSelected = roi == targetROI ...
        & logical(MIDTable.sig_Anova_CLR) ...
        & MIDTable.Z_quad == 4;
    selectedNeuroType = "2D";
elseif options.SelectionMode == "positive-score"
    isSelected = roi == targetROI ...
        & logical(MIDTable.sig_Anova_CLR) ...
        & MIDTable.Z3D_v_Z2D > 0;
    selectedNeuroType = "3D";
else
    error('ComputeFSTPatternTuningIndices:UnknownSelectionMode', ...
        ['SelectionMode must be "lo-1.28", "lo-2d-1.28", or ' ...
        '"positive-score".']);
end
sourceRows = find(isSelected);

if isempty(sourceRows)
    error('ComputeFSTPatternTuningIndices:NoSelectedUnits', ...
        'No %s %s units satisfy SelectionMode %s.', ...
        targetROI, selectedNeuroType, options.SelectionMode);
end

nUnits = numel(sourceRows);
T_L = nan(nUnits, 1);
T_R = nan(nUnits, 1);
A_L = nan(nUnits, 1);
A_R = nan(nUnits, 1);
N_T_L = zeros(nUnits, 1);
N_T_R = zeros(nUnits, 1);
N_A_L = zeros(nUnits, 1);
N_A_R = zeros(nUnits, 1);
preferredCoherence = nan(nUnits, 1);
combinedFR = nan(nUnits, 1);
stereoFR = nan(nUnits, 1);
N_Combined_FR = zeros(nUnits, 1);
N_Stereo_FR = zeros(nUnits, 1);
speedCounts = zeros(nUnits, 1);

for unitIndex = 1:nUnits
    sourceRow = sourceRows(unitIndex);
    response = NeuroRespUnitTable.NeuroResp{sourceRow};
    validate_3d_response(response, sourceRow, constants);

    [T_L(unitIndex), N_T_L(unitIndex)] = finite_mean( ...
        response(constants.LeftPerspectiveCue, constants.TowardCoherenceIndex, :));
    [T_R(unitIndex), N_T_R(unitIndex)] = finite_mean( ...
        response(constants.RightPerspectiveCue, constants.TowardCoherenceIndex, :));
    [A_L(unitIndex), N_A_L(unitIndex)] = finite_mean( ...
        response(constants.LeftPerspectiveCue, constants.AwayCoherenceIndex, :));
    [A_R(unitIndex), N_A_R(unitIndex)] = finite_mean( ...
        response(constants.RightPerspectiveCue, constants.AwayCoherenceIndex, :));

    combinedAI = MIDTable.Combined_AI(sourceRow);
    if isfinite(combinedAI) && combinedAI > 0
        preferredCoherence(unitIndex) = 1;
        preferredCoherenceIndex = constants.TowardCoherenceIndex;
    elseif isfinite(combinedAI) && combinedAI < 0
        preferredCoherence(unitIndex) = -1;
        preferredCoherenceIndex = constants.AwayCoherenceIndex;
    else
        preferredCoherenceIndex = [];
    end
    if ~isempty(preferredCoherenceIndex)
        [combinedFR(unitIndex), N_Combined_FR(unitIndex)] = finite_mean( ...
            response(constants.CombinedCue, preferredCoherenceIndex, :));
        [stereoFR(unitIndex), N_Stereo_FR(unitIndex)] = finite_mean( ...
            response(constants.StereoCue, preferredCoherenceIndex, :));
    end

    speedCodes = normalize_numeric_vector( ...
        LateralMotionRawFRTable.SpeedCodesUsed{sourceRow});
    if isempty(speedCodes)
        error('ComputeFSTPatternTuningIndices:MissingSpeedCodes', ...
            'Lateral row %d has no speed codes.', sourceRow);
    end
    speedCounts(unitIndex) = numel(speedCodes);
end

bodiNumerator = combinedFR - stereoFR;
bodiDenominator = combinedFR + stereoFR;
completeBODIComponents = all(isfinite([combinedFR, stereoFR]), 2);
validBODI = completeBODIComponents & isfinite(bodiDenominator) ...
    & bodiDenominator ~= 0;
BODI = nan(nUnits, 1);
BODI(validBODI) = bodiNumerator(validBODI) ./ bodiDenominator(validBODI);

BinocularOpticFlowTable = table();
BinocularOpticFlowTable.SourceRow = sourceRows;
BinocularOpticFlowTable.Date = MIDTable.Date(sourceRows);
BinocularOpticFlowTable.Monkey = string(MIDTable.Monkey(sourceRows));
BinocularOpticFlowTable.ROI = string(MIDTable.ROI(sourceRows));
BinocularOpticFlowTable.Tetrode = MIDTable.Tetrode(sourceRows);
BinocularOpticFlowTable.Unit = MIDTable.Unit(sourceRows);
BinocularOpticFlowTable.NeuroType = repmat(selectedNeuroType, nUnits, 1);
BinocularOpticFlowTable.Z3D_v_Z2D = MIDTable.Z3D_v_Z2D(sourceRows);
BinocularOpticFlowTable.Combined_AI = MIDTable.Combined_AI(sourceRows);
BinocularOpticFlowTable.CombinedCuePreference = ...
    preference_labels(BinocularOpticFlowTable.Combined_AI);
BinocularOpticFlowTable.PreferredCoherence = preferredCoherence;
BinocularOpticFlowTable.Combined_FR = combinedFR;
BinocularOpticFlowTable.Stereo_FR = stereoFR;
BinocularOpticFlowTable.N_Combined_FR = N_Combined_FR;
BinocularOpticFlowTable.N_Stereo_FR = N_Stereo_FR;
BinocularOpticFlowTable.BODI_Numerator = bodiNumerator;
BinocularOpticFlowTable.BODI_Denominator = bodiDenominator;
BinocularOpticFlowTable.BODI = BODI;
BinocularOpticFlowTable.Valid_BODI = validBODI;

nLongRows = sum(speedCounts);
unitIndexLong = zeros(nLongRows, 1);
sourceRowLong = zeros(nLongRows, 1);
speedRankLong = zeros(nLongRows, 1);
speedCodeLong = nan(nLongRows, 1);
R_L = nan(nLongRows, 1);
R_R = nan(nLongRows, 1);
L_L = nan(nLongRows, 1);
L_R = nan(nLongRows, 1);
N_R_L = zeros(nLongRows, 1);
N_R_R = zeros(nLongRows, 1);
N_L_L = zeros(nLongRows, 1);
N_L_R = zeros(nLongRows, 1);

longRow = 0;
for unitIndex = 1:nUnits
    sourceRow = sourceRows(unitIndex);
    raw2D = LateralMotionRawFRTable.RawFR_ByConditionDirectionSpeed{sourceRow};
    conditionCodes = LateralMotionRawFRTable.ConditionCodesUsed{sourceRow};
    directionDegrees = LateralMotionRawFRTable.DirectionDegreesGuess{sourceRow};
    speedCodes = normalize_numeric_vector( ...
        LateralMotionRawFRTable.SpeedCodesUsed{sourceRow});

    validate_2d_response(raw2D, conditionCodes, directionDegrees, speedCodes, sourceRow);

    for speedRank = 1:numel(speedCodes)
        longRow = longRow + 1;
        unitIndexLong(longRow) = unitIndex;
        sourceRowLong(longRow) = sourceRow;
        speedRankLong(longRow) = speedRank;
        speedCodeLong(longRow) = speedCodes(speedRank);

        % The first letter is motion direction; the suffix is eye.
        [R_L(longRow), N_R_L(longRow)] = extract_2d_mean(raw2D, ...
            conditionCodes, directionDegrees, constants.LeftEyeCondition, ...
            constants.RightwardDegrees, speedRank);
        [R_R(longRow), N_R_R(longRow)] = extract_2d_mean(raw2D, ...
            conditionCodes, directionDegrees, constants.RightEyeCondition, ...
            constants.RightwardDegrees, speedRank);
        [L_L(longRow), N_L_L(longRow)] = extract_2d_mean(raw2D, ...
            conditionCodes, directionDegrees, constants.LeftEyeCondition, ...
            constants.LeftwardDegrees, speedRank);
        [L_R(longRow), N_L_R(longRow)] = extract_2d_mean(raw2D, ...
            conditionCodes, directionDegrees, constants.RightEyeCondition, ...
            constants.LeftwardDegrees, speedRank);
    end
end

T_L_long = T_L(unitIndexLong);
T_R_long = T_R(unitIndexLong);
A_L_long = A_L(unitIndexLong);
A_R_long = A_R(unitIndexLong);

tdiNumerator = T_L_long + T_R_long - R_L - L_R;
tdiDenominator = T_L_long + T_R_long + R_L + L_R;
adiNumerator = A_L_long + A_R_long - L_L - R_R;
adiDenominator = A_L_long + A_R_long + L_L + R_R;

TDI = nan(nLongRows, 1);
ADI = nan(nLongRows, 1);
completeTDIComponents = all(isfinite([T_L_long, T_R_long, R_L, L_R]), 2);
completeADIComponents = all(isfinite([A_L_long, A_R_long, L_L, R_R]), 2);
validTDI = completeTDIComponents & isfinite(tdiDenominator) & tdiDenominator ~= 0;
validADI = completeADIComponents & isfinite(adiDenominator) & adiDenominator ~= 0;
TDI(validTDI) = tdiNumerator(validTDI) ./ tdiDenominator(validTDI);
ADI(validADI) = adiNumerator(validADI) ./ adiDenominator(validADI);

PatternTuningBySpeedTable = table();
PatternTuningBySpeedTable.SourceRow = sourceRowLong;
PatternTuningBySpeedTable.Date = MIDTable.Date(sourceRowLong);
PatternTuningBySpeedTable.Monkey = string(MIDTable.Monkey(sourceRowLong));
PatternTuningBySpeedTable.ROI = string(MIDTable.ROI(sourceRowLong));
PatternTuningBySpeedTable.Tetrode = MIDTable.Tetrode(sourceRowLong);
PatternTuningBySpeedTable.Unit = MIDTable.Unit(sourceRowLong);
PatternTuningBySpeedTable.NeuroType = repmat(selectedNeuroType, nLongRows, 1);
PatternTuningBySpeedTable.Z3D_v_Z2D = MIDTable.Z3D_v_Z2D(sourceRowLong);
PatternTuningBySpeedTable.Combined_AI = MIDTable.Combined_AI(sourceRowLong);
PatternTuningBySpeedTable.CombinedCuePreference = ...
    preference_labels(PatternTuningBySpeedTable.Combined_AI);
PatternTuningBySpeedTable.SpeedRank_2D = speedRankLong;
PatternTuningBySpeedTable.SpeedCode_2D = speedCodeLong;
PatternTuningBySpeedTable.SpeedLabel_2D = speed_labels(speedCodeLong);
PatternTuningBySpeedTable.IsMatchedSlowSpeed = ...
    speedCodeLong == constants.Matched2DSpeedCode;
PatternTuningBySpeedTable.T_L = T_L_long;
PatternTuningBySpeedTable.T_R = T_R_long;
PatternTuningBySpeedTable.A_L = A_L_long;
PatternTuningBySpeedTable.A_R = A_R_long;
PatternTuningBySpeedTable.R_L = R_L;
PatternTuningBySpeedTable.R_R = R_R;
PatternTuningBySpeedTable.L_L = L_L;
PatternTuningBySpeedTable.L_R = L_R;
PatternTuningBySpeedTable.N_T_L = N_T_L(unitIndexLong);
PatternTuningBySpeedTable.N_T_R = N_T_R(unitIndexLong);
PatternTuningBySpeedTable.N_A_L = N_A_L(unitIndexLong);
PatternTuningBySpeedTable.N_A_R = N_A_R(unitIndexLong);
PatternTuningBySpeedTable.N_R_L = N_R_L;
PatternTuningBySpeedTable.N_R_R = N_R_R;
PatternTuningBySpeedTable.N_L_L = N_L_L;
PatternTuningBySpeedTable.N_L_R = N_L_R;
PatternTuningBySpeedTable.TDI_Numerator = tdiNumerator;
PatternTuningBySpeedTable.TDI_Denominator = tdiDenominator;
PatternTuningBySpeedTable.TDI = TDI;
PatternTuningBySpeedTable.ADI_Numerator = adiNumerator;
PatternTuningBySpeedTable.ADI_Denominator = adiDenominator;
PatternTuningBySpeedTable.ADI = ADI;
PatternTuningBySpeedTable.Valid_TDI = validTDI;
PatternTuningBySpeedTable.Valid_ADI = validADI;
PatternTuningBySpeedTable.Complete_AllEightMetrics = ...
    completeTDIComponents & completeADIComponents;

primaryMask = PatternTuningBySpeedTable.IsMatchedSlowSpeed;
primaryRows = PatternTuningBySpeedTable(primaryMask, :);
[foundPrimary, primaryLocation] = ismember(sourceRows, primaryRows.SourceRow);
if any(~foundPrimary)
    missingRows = sourceRows(~foundPrimary);
    warning('ComputeFSTPatternTuningIndices:MissingMatchedSpeed', ...
        ['Matched 2D speed code %g is missing for source row(s): %s. ' ...
        'Their matched-speed lateral responses and PDI components are NaN.'], ...
        constants.Matched2DSpeedCode, mat2str(missingRows(:)'));
    missingPrimaryRows = PatternTuningBySpeedTable([], :);
    for missingIndex = 1:numel(missingRows)
        sourceRow = missingRows(missingIndex);
        templateIndex = find( ...
            PatternTuningBySpeedTable.SourceRow == sourceRow, 1, 'first');
        placeholder = PatternTuningBySpeedTable(templateIndex, :);
        placeholder.SpeedRank_2D = nan;
        placeholder.SpeedCode_2D = constants.Matched2DSpeedCode;
        placeholder.SpeedLabel_2D = speed_labels(constants.Matched2DSpeedCode);
        placeholder.IsMatchedSlowSpeed = true;
        placeholder.R_L = nan;
        placeholder.R_R = nan;
        placeholder.L_L = nan;
        placeholder.L_R = nan;
        placeholder.N_R_L = 0;
        placeholder.N_R_R = 0;
        placeholder.N_L_L = 0;
        placeholder.N_L_R = 0;
        placeholder.TDI_Numerator = nan;
        placeholder.TDI_Denominator = nan;
        placeholder.TDI = nan;
        placeholder.ADI_Numerator = nan;
        placeholder.ADI_Denominator = nan;
        placeholder.ADI = nan;
        placeholder.Valid_TDI = false;
        placeholder.Valid_ADI = false;
        placeholder.Complete_AllEightMetrics = false;
        missingPrimaryRows = [missingPrimaryRows; placeholder]; %#ok<AGROW>
    end
    primaryRows = [primaryRows; missingPrimaryRows];
    [foundPrimary, primaryLocation] = ismember( ...
        sourceRows, primaryRows.SourceRow);
end
if ~all(foundPrimary) || height(primaryRows) ~= nUnits ...
        || numel(unique(primaryRows.SourceRow)) ~= nUnits
    error('ComputeFSTPatternTuningIndices:DuplicateMatchedSpeed', ...
        'Expected exactly one matched-speed row per selected unit.');
end
PatternTuningTable = primaryRows(primaryLocation, :);

if options.SelectionMode == "positive-score"
    selectionDescription = sprintf( ...
        'Lo %s units with significant tuning and Z3D_v_Z2D > 0', targetROI);
elseif options.SelectionMode == "lo-2d-1.28"
    selectionDescription = sprintf( ...
        'Lo-criterion %s 2D units (sig_Anova_CLR and Z_quad == 4)', targetROI);
else
    selectionDescription = sprintf( ...
        'Lo-criterion %s 3D units (sig_Anova_CLR and Z_quad == 2)', targetROI);
end
PatternTuningTable.Properties.Description = sprintf( ...
    '%s; primary perspective-versus-lateral pattern-tuning indices.', ...
    selectionDescription);
PatternTuningBySpeedTable.Properties.Description = sprintf( ...
    '%s; perspective-versus-lateral indices at each available 2D speed.', ...
    selectionDescription);
BinocularOpticFlowTable.Properties.Description = sprintf( ...
    ['%s; one 3D-stimulus BODI row per neuron using combined cue 1 and ' ...
    'stereoscopic cue 4.'], selectionDescription);

check_index_bounds(PatternTuningBySpeedTable.TDI, 'TDI');
check_index_bounds(PatternTuningBySpeedTable.ADI, 'ADI');
check_index_bounds(BinocularOpticFlowTable.BODI, 'BODI');
PatternTuningSummary = build_summary(PatternTuningTable);
BinocularOpticFlowSummary = build_bodi_summary(BinocularOpticFlowTable);
end

function constants = analysis_constants(matched2DSpeedCode)
constants.Coherence = [-22, -14, -10, -8, -4, -2, 0, 2, 4, 8, 10, 14, 22] ./ 22;
constants.TowardCoherenceIndex = find(constants.Coherence == 1, 1, 'first');
constants.AwayCoherenceIndex = find(constants.Coherence == -1, 1, 'first');
constants.CombinedCue = 1;
constants.LeftPerspectiveCue = 2;
constants.RightPerspectiveCue = 3;
constants.StereoCue = 4;
constants.LeftEyeCondition = 8001;
constants.RightEyeCondition = 8002;
constants.RightwardDegrees = 0;
constants.LeftwardDegrees = 180;
constants.Matched2DSpeedCode = matched2DSpeedCode;
end

function validate_input_tables(T3D, T2D, TMID)
check_required_variables(T3D, ...
    {'Date', 'ROI', 'Tetrode', 'Unit', 'NeuroResp'}, 'NeuroRespUnitTable');
check_required_variables(T2D, ...
    {'Date', 'ROI', 'Tetrode', 'Unit', 'RawFR_ByConditionDirectionSpeed', ...
    'ConditionCodesUsed', 'DirectionDegreesGuess', 'SpeedCodesUsed'}, ...
    'LateralMotionRawFRTable');
check_required_variables(TMID, ...
    {'Date', 'ROI', 'Tetrode', 'Unit', 'Monkey', 'sig_Anova_CLR', ...
    'Z_quad', 'Z3D_v_Z2D', 'Combined_AI'}, ...
    'MIDTable');

if height(T3D) ~= height(T2D) || height(T3D) ~= height(TMID)
    error('ComputeFSTPatternTuningIndices:RowCountMismatch', ...
        ['NeuroRespUnitTable, LateralMotionRawFRTable, and MIDTable must ' ...
        'have equal row counts.']);
end
end

function check_required_variables(T, required, tableName)
missing = required(~ismember(required, T.Properties.VariableNames));
if ~isempty(missing)
    error('ComputeFSTPatternTuningIndices:MissingVariables', ...
        '%s is missing variable(s): %s', tableName, strjoin(missing, ', '));
end
end

function verify_row_alignment(T3D, T2D, TMID)
date3D = normalize_dates(T3D.Date);
date2D = normalize_dates(T2D.Date);
dateMID = normalize_dates(TMID.Date);
dateMatch = isequaln(date3D, date2D) && isequaln(date3D, dateMID);
roi3D = upper(strtrim(string(T3D.ROI)));
roi2D = upper(strtrim(string(T2D.ROI)));
roiMID = upper(strtrim(string(TMID.ROI)));
roiMatch = isequaln(roi3D, roi2D) && isequaln(roi3D, roiMID);
tetrodeMatch = isequaln(double(T3D.Tetrode), double(T2D.Tetrode)) ...
    && isequaln(double(T3D.Tetrode), double(TMID.Tetrode));
unitMatch = isequaln(double(T3D.Unit), double(T2D.Unit)) ...
    && isequaln(double(T3D.Unit), double(TMID.Unit));

if ~(dateMatch && roiMatch && tetrodeMatch && unitMatch)
    error('ComputeFSTPatternTuningIndices:AlignmentFailure', ...
        ['Input rows do not align on the Date + ROI + Tetrode + Unit key. ' ...
        'Rebuild or explicitly key-match the source tables before analysis.']);
end
end

function values = normalize_dates(values)
if isdatetime(values)
    values = dateshift(values(:), 'start', 'day');
elseif isnumeric(values)
    values = floor(double(values(:)));
else
    values = dateshift(datetime(values(:)), 'start', 'day');
end
end

function validate_3d_response(response, sourceRow, constants)
if ~isnumeric(response) ...
        || size(response, 1) < constants.StereoCue ...
        || size(response, 2) < max(constants.TowardCoherenceIndex, constants.AwayCoherenceIndex)
    error('ComputeFSTPatternTuningIndices:Invalid3DResponse', ...
        '3D response at source row %d has invalid size %s.', ...
        sourceRow, mat2str(size(response)));
end
end

function validate_2d_response(raw2D, conditionCodes, directionDegrees, speedCodes, sourceRow)
if ~iscell(raw2D)
    error('ComputeFSTPatternTuningIndices:Invalid2DResponse', ...
        '2D response at source row %d must be a cell array.', sourceRow);
end
conditionCodes = normalize_numeric_vector(conditionCodes);
directionDegrees = normalize_numeric_vector(directionDegrees);
if size(raw2D, 1) ~= numel(conditionCodes) ...
        || size(raw2D, 2) ~= numel(directionDegrees) ...
        || size(raw2D, 3) ~= numel(speedCodes)
    error('ComputeFSTPatternTuningIndices:Invalid2DAxes', ...
        ['2D response axes at source row %d do not match the condition, ' ...
        'direction, and speed metadata.'], sourceRow);
end
end

function [meanFR, n] = extract_2d_mean(raw2D, conditionCodes, directionDegrees, ...
        targetCondition, targetDirection, speedRank)
conditionCodes = normalize_numeric_vector(conditionCodes);
directionDegrees = mod(normalize_numeric_vector(directionDegrees), 360);
conditionIndex = find(conditionCodes == targetCondition, 1, 'first');
directionIndex = find(abs(directionDegrees - mod(targetDirection, 360)) < 1e-9, 1, 'first');

if isempty(conditionIndex) || isempty(directionIndex) || speedRank > size(raw2D, 3)
    meanFR = nan;
    n = 0;
    return
end
[meanFR, n] = finite_mean(raw2D{conditionIndex, directionIndex, speedRank});
end

function [value, n] = finite_mean(values)
values = double(values(:));
values = values(isfinite(values));
n = numel(values);
if n == 0
    value = nan;
else
    value = mean(values);
end
end

function values = normalize_numeric_vector(values)
values = double(values(:));
end

function labels = speed_labels(speedCodes)
labels = strings(size(speedCodes));
for i = 1:numel(speedCodes)
    if speedCodes(i) == 7041
        labels(i) = "slow (~4.2 deg/s)";
    elseif speedCodes(i) == 7125
        labels(i) = "fast (~12.6 deg/s)";
    else
        labels(i) = "event " + string(speedCodes(i));
    end
end
end

function labels = preference_labels(combinedAI)
labels = repmat("Undefined", size(combinedAI));
labels(isfinite(combinedAI) & combinedAI > 0) = "Toward";
labels(isfinite(combinedAI) & combinedAI < 0) = "Away";
labels(isfinite(combinedAI) & combinedAI == 0) = "Neutral";
end

function check_index_bounds(values, label)
finiteValues = values(isfinite(values));
if any(finiteValues < -1 - 1e-10 | finiteValues > 1 + 1e-10)
    warning('ComputeFSTPatternTuningIndices:IndexOutOfBounds', ...
        '%s contains values outside [-1, 1]; check for negative firing rates.', label);
end
end

function summary = build_summary(T)
monkeys = unique(string(T.Monkey), 'stable');
groupNames = ["All"; monkeys(:)];
nGroups = numel(groupNames);
N_Selected = zeros(nGroups, 1);
N_Complete = zeros(nGroups, 1);
N_TowardPreferred = zeros(nGroups, 1);
N_AwayPreferred = zeros(nGroups, 1);
N_NeutralOrUndefined = zeros(nGroups, 1);
N_Valid_TDI = zeros(nGroups, 1);
TDI_Mean = nan(nGroups, 1);
TDI_Median = nan(nGroups, 1);
TDI_SD = nan(nGroups, 1);
N_TDI_Positive = zeros(nGroups, 1);
N_Valid_ADI = zeros(nGroups, 1);
ADI_Mean = nan(nGroups, 1);
ADI_Median = nan(nGroups, 1);
ADI_SD = nan(nGroups, 1);
N_ADI_Positive = zeros(nGroups, 1);

for groupIndex = 1:nGroups
    if groupNames(groupIndex) == "All"
        mask = true(height(T), 1);
    else
        mask = string(T.Monkey) == groupNames(groupIndex);
    end
    tdi = T.TDI(mask & T.Valid_TDI);
    adi = T.ADI(mask & T.Valid_ADI);
    N_Selected(groupIndex) = nnz(mask);
    N_Complete(groupIndex) = nnz(mask & T.Complete_AllEightMetrics);
    N_TowardPreferred(groupIndex) = nnz(mask & T.CombinedCuePreference == "Toward");
    N_AwayPreferred(groupIndex) = nnz(mask & T.CombinedCuePreference == "Away");
    N_NeutralOrUndefined(groupIndex) = nnz(mask ...
        & ~(T.CombinedCuePreference == "Toward" | T.CombinedCuePreference == "Away"));
    N_Valid_TDI(groupIndex) = numel(tdi);
    N_Valid_ADI(groupIndex) = numel(adi);
    if ~isempty(tdi)
        TDI_Mean(groupIndex) = mean(tdi);
        TDI_Median(groupIndex) = median(tdi);
        TDI_SD(groupIndex) = std(tdi);
        N_TDI_Positive(groupIndex) = nnz(tdi > 0);
    end
    if ~isempty(adi)
        ADI_Mean(groupIndex) = mean(adi);
        ADI_Median(groupIndex) = median(adi);
        ADI_SD(groupIndex) = std(adi);
        N_ADI_Positive(groupIndex) = nnz(adi > 0);
    end
end

Group = groupNames;
summary = table(Group, N_Selected, N_Complete, N_TowardPreferred, ...
    N_AwayPreferred, N_NeutralOrUndefined, N_Valid_TDI, ...
    TDI_Mean, TDI_Median, TDI_SD, N_TDI_Positive, N_Valid_ADI, ...
    ADI_Mean, ADI_Median, ADI_SD, N_ADI_Positive);
end

function summary = build_bodi_summary(T)
monkeys = unique(string(T.Monkey), 'stable');
groupNames = ["All"; monkeys(:)];
nGroups = numel(groupNames);
Group = groupNames;
N_Selected = zeros(nGroups, 1);
N_TowardPreferred = zeros(nGroups, 1);
N_AwayPreferred = zeros(nGroups, 1);
N_NeutralOrUndefined = zeros(nGroups, 1);
N_Valid_BODI = zeros(nGroups, 1);
BODI_Mean = nan(nGroups, 1);
BODI_Median = nan(nGroups, 1);
BODI_SD = nan(nGroups, 1);
N_BODI_Positive = zeros(nGroups, 1);

for groupIndex = 1:nGroups
    if groupNames(groupIndex) == "All"
        mask = true(height(T), 1);
    else
        mask = string(T.Monkey) == groupNames(groupIndex);
    end
    values = T.BODI(mask & T.Valid_BODI);
    N_Selected(groupIndex) = nnz(mask);
    N_TowardPreferred(groupIndex) = nnz(mask & T.CombinedCuePreference == "Toward");
    N_AwayPreferred(groupIndex) = nnz(mask & T.CombinedCuePreference == "Away");
    N_NeutralOrUndefined(groupIndex) = nnz(mask ...
        & ~ismember(T.CombinedCuePreference, ["Toward", "Away"]));
    N_Valid_BODI(groupIndex) = numel(values);
    if ~isempty(values)
        BODI_Mean(groupIndex) = mean(values);
        BODI_Median(groupIndex) = median(values);
        BODI_SD(groupIndex) = std(values);
        N_BODI_Positive(groupIndex) = nnz(values > 0);
    end
end

summary = table(Group, N_Selected, N_TowardPreferred, N_AwayPreferred, ...
    N_NeutralOrUndefined, N_Valid_BODI, BODI_Mean, BODI_Median, ...
    BODI_SD, N_BODI_Positive);
end

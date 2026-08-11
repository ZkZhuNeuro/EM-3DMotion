function [PatternTuningTable, PatternTuningBySpeedTable, PatternTuningSummary] = ...
    ComputeEMFSTPatternTuningIndices(unit_table_gof)
%COMPUTEEMFSTPATTERNTUNINGINDICES Compute EM perspective-versus-lateral indices.
%   Selects EM recording rows classified as FST and ND == "3D". The
%   stimulation channel is treated as the analyzed unit for each row.
%
%   unit_table_gof.tuning_mean is cue x coherence x channel. The first and
%   last coherence columns are away (-1) and toward (+1), respectively.
%   unit_table_gof.Raw2D_StimCh is direction x speed x eye x repeat for the
%   stimulation channel. Direction indices 1 and 5 are 0 and 180 degrees;
%   eye indices 1 and 2 are left and right.
%
%   TDI = (T_L + T_R - R_L - L_R) / ...
%         (T_L + T_R + R_L + L_R)
%   ADI = (A_L + A_R - L_L - R_R) / ...
%         (A_L + A_R + L_L + R_R)

arguments
    unit_table_gof table
end

validate_input_table(unit_table_gof);
constants = analysis_constants();

roi = upper(strtrim(string(unit_table_gof.ROI)));
neuroType = upper(strtrim(string(unit_table_gof.ND)));
sourceRows = find(roi == "FST" & neuroType == "3D");
if isempty(sourceRows)
    error('ComputeEMFSTPatternTuningIndices:NoSelectedUnits', ...
        'No EM rows satisfy ROI == FST and ND == 3D.');
end

nUnits = numel(sourceRows);
nSpeeds = numel(constants.SpeedDegreesPerSecond);
nLongRows = nUnits * nSpeeds;

unitIndexLong = repelem((1:nUnits)', nSpeeds, 1);
sourceRowLong = sourceRows(unitIndexLong);
speedRankLong = repmat((1:nSpeeds)', nUnits, 1);

T_L_unit = nan(nUnits, 1);
T_R_unit = nan(nUnits, 1);
A_L_unit = nan(nUnits, 1);
A_R_unit = nan(nUnits, 1);
combinedAI_unit = nan(nUnits, 1);
z3DMinus2D_unit = nan(nUnits, 1);
pMonoL_unit = nan(nUnits, 1);
pMonoR_unit = nan(nUnits, 1);

R_L = nan(nLongRows, 1);
R_R = nan(nLongRows, 1);
L_L = nan(nLongRows, 1);
L_R = nan(nLongRows, 1);
N_R_L = zeros(nLongRows, 1);
N_R_R = zeros(nLongRows, 1);
N_L_L = zeros(nLongRows, 1);
N_L_R = zeros(nLongRows, 1);

for unitIndex = 1:nUnits
    sourceRow = sourceRows(unitIndex);
    channel = unit_table_gof.StimElec(sourceRow);
    tuning3D = unit_table_gof.tuning_mean{sourceRow};
    raw2D = unit_table_gof.Raw2D_StimCh{sourceRow};
    validate_selected_row(tuning3D, raw2D, channel, sourceRow, constants);

    A_L_unit(unitIndex) = tuning3D(constants.LeftPerspectiveCue, 1, channel);
    A_R_unit(unitIndex) = tuning3D(constants.RightPerspectiveCue, 1, channel);
    T_L_unit(unitIndex) = tuning3D(constants.LeftPerspectiveCue, end, channel);
    T_R_unit(unitIndex) = tuning3D(constants.RightPerspectiveCue, end, channel);

    ai = unit_table_gof.AI{sourceRow};
    combinedAI_unit(unitIndex) = ai(constants.CombinedCue, channel);
    z3DMinus2D_unit(unitIndex) = scalar_cell_value( ...
        unit_table_gof.Z3D_v_Z2D{sourceRow}, 'Z3D_v_Z2D', sourceRow);
    pValues = unit_table_gof.p_AI{sourceRow};
    pMonoL_unit(unitIndex) = pValues(constants.LeftPerspectiveCue);
    pMonoR_unit(unitIndex) = pValues(constants.RightPerspectiveCue);

    for speedRank = 1:nSpeeds
        longRow = (unitIndex - 1) * nSpeeds + speedRank;
        [R_L(longRow), N_R_L(longRow)] = finite_mean( ...
            raw2D(constants.RightwardDirectionIndex, speedRank, ...
            constants.LeftEyeCondition, :));
        [R_R(longRow), N_R_R(longRow)] = finite_mean( ...
            raw2D(constants.RightwardDirectionIndex, speedRank, ...
            constants.RightEyeCondition, :));
        [L_L(longRow), N_L_L(longRow)] = finite_mean( ...
            raw2D(constants.LeftwardDirectionIndex, speedRank, ...
            constants.LeftEyeCondition, :));
        [L_R(longRow), N_L_R(longRow)] = finite_mean( ...
            raw2D(constants.LeftwardDirectionIndex, speedRank, ...
            constants.RightEyeCondition, :));
    end
end

T_L = T_L_unit(unitIndexLong);
T_R = T_R_unit(unitIndexLong);
A_L = A_L_unit(unitIndexLong);
A_R = A_R_unit(unitIndexLong);

tdiNumerator = T_L + T_R - R_L - L_R;
tdiDenominator = T_L + T_R + R_L + L_R;
adiNumerator = A_L + A_R - L_L - R_R;
adiDenominator = A_L + A_R + L_L + R_R;

completeTDIComponents = all(isfinite([T_L, T_R, R_L, L_R]), 2);
completeADIComponents = all(isfinite([A_L, A_R, L_L, R_R]), 2);
validTDI = completeTDIComponents & isfinite(tdiDenominator) & tdiDenominator ~= 0;
validADI = completeADIComponents & isfinite(adiDenominator) & adiDenominator ~= 0;
TDI = nan(nLongRows, 1);
ADI = nan(nLongRows, 1);
TDI(validTDI) = tdiNumerator(validTDI) ./ tdiDenominator(validTDI);
ADI(validADI) = adiNumerator(validADI) ./ adiDenominator(validADI);

PatternTuningBySpeedTable = table();
PatternTuningBySpeedTable.SourceRow = sourceRowLong;
PatternTuningBySpeedTable.OriginalRecIdx = optional_numeric_column( ...
    unit_table_gof, 'OriginalRecIdx', sourceRowLong);
PatternTuningBySpeedTable.Date = unit_table_gof.Date(sourceRowLong);
PatternTuningBySpeedTable.Monkey = string(unit_table_gof.Monkey(sourceRowLong));
PatternTuningBySpeedTable.ROI = string(unit_table_gof.ROI(sourceRowLong));
PatternTuningBySpeedTable.StimElec = unit_table_gof.StimElec(sourceRowLong);
PatternTuningBySpeedTable.NeuroType = repmat("3D", nLongRows, 1);
PatternTuningBySpeedTable.Z3D_v_Z2D = z3DMinus2D_unit(unitIndexLong);
PatternTuningBySpeedTable.P_MonoL = pMonoL_unit(unitIndexLong);
PatternTuningBySpeedTable.P_MonoR = pMonoR_unit(unitIndexLong);
PatternTuningBySpeedTable.Combined_AI = combinedAI_unit(unitIndexLong);
PatternTuningBySpeedTable.CombinedCuePreference = ...
    preference_labels(PatternTuningBySpeedTable.Combined_AI);
PatternTuningBySpeedTable.SpeedRank_2D = speedRankLong;
PatternTuningBySpeedTable.SpeedDegPerSec_2D = ...
    reshape(constants.SpeedDegreesPerSecond(speedRankLong), [], 1);
PatternTuningBySpeedTable.SpeedLabel_2D = speed_labels(speedRankLong);
PatternTuningBySpeedTable.IsMatchedSlowSpeed = speedRankLong == 1;
PatternTuningBySpeedTable.T_L = T_L;
PatternTuningBySpeedTable.T_R = T_R;
PatternTuningBySpeedTable.A_L = A_L;
PatternTuningBySpeedTable.A_R = A_R;
PatternTuningBySpeedTable.R_L = R_L;
PatternTuningBySpeedTable.R_R = R_R;
PatternTuningBySpeedTable.L_L = L_L;
PatternTuningBySpeedTable.L_R = L_R;
PatternTuningBySpeedTable.N_T_L = nan(nLongRows, 1);
PatternTuningBySpeedTable.N_T_R = nan(nLongRows, 1);
PatternTuningBySpeedTable.N_A_L = nan(nLongRows, 1);
PatternTuningBySpeedTable.N_A_R = nan(nLongRows, 1);
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

PatternTuningTable = PatternTuningBySpeedTable( ...
    PatternTuningBySpeedTable.IsMatchedSlowSpeed, :);
if height(PatternTuningTable) ~= nUnits
    error('ComputeEMFSTPatternTuningIndices:PrimaryRowCount', ...
        'Expected exactly one slow-speed row per selected EM unit.');
end

PatternTuningTable.Properties.Description = ...
    'EM unit_table_gof FST/3D rows; primary matched slow-speed indices.';
PatternTuningBySpeedTable.Properties.Description = ...
    'EM unit_table_gof FST/3D rows; indices at both stored 2D speeds.';
PatternTuningSummary = build_summary(PatternTuningBySpeedTable);

check_index_bounds(PatternTuningBySpeedTable.TDI, 'TDI');
check_index_bounds(PatternTuningBySpeedTable.ADI, 'ADI');
end

function constants = analysis_constants
constants.CombinedCue = 1;
constants.LeftPerspectiveCue = 2;
constants.RightPerspectiveCue = 3;
constants.RightwardDirectionIndex = 1;
constants.LeftwardDirectionIndex = 5;
constants.LeftEyeCondition = 1;
constants.RightEyeCondition = 2;
constants.SpeedDegreesPerSecond = [4.166667, 4.166667 * 3];
end

function validate_input_table(T)
required = {'Date', 'Monkey', 'ROI', 'StimElec', 'ND', 'p_AI', 'AI', ...
    'Z3D_v_Z2D', 'tuning_mean', 'Raw2D_StimCh'};
missing = setdiff(required, T.Properties.VariableNames);
if ~isempty(missing)
    error('ComputeEMFSTPatternTuningIndices:MissingVariables', ...
        'unit_table_gof is missing: %s', strjoin(missing, ', '));
end
end

function validate_selected_row(tuning3D, raw2D, channel, sourceRow, constants)
if ~isfinite(channel) || channel < 1 || channel ~= round(channel)
    error('ComputeEMFSTPatternTuningIndices:InvalidChannel', ...
        'Source row %d has invalid StimElec.', sourceRow);
end
if ~isnumeric(tuning3D) || size(tuning3D, 1) < constants.RightPerspectiveCue ...
        || size(tuning3D, 2) < 2 || size(tuning3D, 3) < channel
    error('ComputeEMFSTPatternTuningIndices:Invalid3DTuning', ...
        'Source row %d has invalid tuning_mean size %s.', ...
        sourceRow, mat2str(size(tuning3D)));
end
if ~isnumeric(raw2D) || size(raw2D, 1) < constants.LeftwardDirectionIndex ...
        || size(raw2D, 2) < 2 || size(raw2D, 3) < constants.RightEyeCondition
    error('ComputeEMFSTPatternTuningIndices:Invalid2DTuning', ...
        'Source row %d has invalid Raw2D_StimCh size %s.', ...
        sourceRow, mat2str(size(raw2D)));
end
end

function value = scalar_cell_value(value, variableName, sourceRow)
if ~isnumeric(value) || ~isscalar(value)
    error('ComputeEMFSTPatternTuningIndices:InvalidScalar', ...
        'Source row %d has invalid %s.', sourceRow, variableName);
end
value = double(value);
end

function values = optional_numeric_column(T, variableName, rows)
if ismember(variableName, T.Properties.VariableNames) && isnumeric(T.(variableName))
    values = double(T.(variableName)(rows));
else
    values = nan(numel(rows), 1);
end
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

function labels = speed_labels(speedRanks)
labels = strings(size(speedRanks));
labels(speedRanks == 1) = "slow (~4.2 deg/s)";
labels(speedRanks == 2) = "fast (~12.5 deg/s)";
labels(labels == "") = "unknown speed";
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
    warning('ComputeEMFSTPatternTuningIndices:IndexOutOfBounds', ...
        '%s contains values outside [-1, 1]; check for negative firing rates.', label);
end
end

function summary = build_summary(T)
speedRanks = unique(T.SpeedRank_2D, 'stable');
monkeys = unique(string(T.Monkey), 'stable');
groups = ["All"; monkeys(:)];
nRows = numel(speedRanks) * numel(groups);

SpeedRank_2D = zeros(nRows, 1);
SpeedLabel_2D = strings(nRows, 1);
Group = strings(nRows, 1);
N_Selected = zeros(nRows, 1);
N_Complete = zeros(nRows, 1);
N_TowardPreferred = zeros(nRows, 1);
N_AwayPreferred = zeros(nRows, 1);
N_NeutralOrUndefined = zeros(nRows, 1);
N_Valid_TDI = zeros(nRows, 1);
TDI_Mean = nan(nRows, 1);
TDI_Median = nan(nRows, 1);
TDI_SD = nan(nRows, 1);
N_Valid_ADI = zeros(nRows, 1);
ADI_Mean = nan(nRows, 1);
ADI_Median = nan(nRows, 1);
ADI_SD = nan(nRows, 1);

outRow = 0;
for speedRank = speedRanks(:)'
    for group = groups(:)'
        outRow = outRow + 1;
        mask = T.SpeedRank_2D == speedRank;
        if group ~= "All"
            mask = mask & string(T.Monkey) == group;
        end
        tdi = T.TDI(mask & T.Valid_TDI);
        adi = T.ADI(mask & T.Valid_ADI);
        SpeedRank_2D(outRow) = speedRank;
        SpeedLabel_2D(outRow) = T.SpeedLabel_2D(find(T.SpeedRank_2D == speedRank, 1));
        Group(outRow) = group;
        N_Selected(outRow) = nnz(mask);
        N_Complete(outRow) = nnz(mask & T.Complete_AllEightMetrics);
        N_TowardPreferred(outRow) = nnz(mask & T.CombinedCuePreference == "Toward");
        N_AwayPreferred(outRow) = nnz(mask & T.CombinedCuePreference == "Away");
        N_NeutralOrUndefined(outRow) = nnz(mask ...
            & ~ismember(T.CombinedCuePreference, ["Toward", "Away"]));
        N_Valid_TDI(outRow) = numel(tdi);
        N_Valid_ADI(outRow) = numel(adi);
        if ~isempty(tdi)
            TDI_Mean(outRow) = mean(tdi);
            TDI_Median(outRow) = median(tdi);
            TDI_SD(outRow) = std(tdi);
        end
        if ~isempty(adi)
            ADI_Mean(outRow) = mean(adi);
            ADI_Median(outRow) = median(adi);
            ADI_SD(outRow) = std(adi);
        end
    end
end

summary = table(SpeedRank_2D, SpeedLabel_2D, Group, N_Selected, ...
    N_Complete, N_TowardPreferred, N_AwayPreferred, ...
    N_NeutralOrUndefined, N_Valid_TDI, TDI_Mean, TDI_Median, TDI_SD, ...
    N_Valid_ADI, ADI_Mean, ADI_Median, ADI_SD);
end

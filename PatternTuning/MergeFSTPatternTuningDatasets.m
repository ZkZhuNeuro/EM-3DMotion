function [CombinedPatternTuningBySpeedTable, CombinedPatternTuningSummary] = ...
    MergeFSTPatternTuningDatasets(loBySpeed, emBySpeed, options)
%MERGEFSTPATTERNTUNINGDATASETS Standardize and merge Lo and EM index tables.

arguments
    loBySpeed table
    emBySpeed table
    options.LoSelectionCriterion (1, 1) string = ...
        "ROI==FST & sig_Anova_CLR & Z3D_v_Z2D>0"
    options.EMSelectionCriterion (1, 1) string = "ROI==FST & ND==3D"
    options.Description (1, 1) string = ...
        "Merged Lo and EM FST pattern-tuning indices"
end

required = {'SourceRow', 'Date', 'Monkey', 'ROI', 'NeuroType', ...
    'Z3D_v_Z2D', 'Combined_AI', 'CombinedCuePreference', ...
    'SpeedRank_2D', 'IsMatchedSlowSpeed', 'T_L', 'T_R', 'A_L', 'A_R', ...
    'R_L', 'R_R', 'L_L', 'L_R', 'N_T_L', 'N_T_R', 'N_A_L', 'N_A_R', ...
    'N_R_L', 'N_R_R', 'N_L_L', 'N_L_R', 'TDI_Numerator', ...
    'TDI_Denominator', 'TDI', 'ADI_Numerator', 'ADI_Denominator', 'ADI', ...
    'Valid_TDI', 'Valid_ADI', 'Complete_AllEightMetrics'};
validate_variables(loBySpeed, required, 'Lo');
validate_variables(emBySpeed, required, 'EM');

lo = standardize_source_table( ...
    loBySpeed, "Lo", options.LoSelectionCriterion);
em = standardize_source_table( ...
    emBySpeed, "EM", options.EMSelectionCriterion);
CombinedPatternTuningBySpeedTable = [lo; em];
CombinedPatternTuningBySpeedTable = sortrows( ...
    CombinedPatternTuningBySpeedTable, ...
    {'SpeedRank_2D', 'SourceDataset', 'Monkey', 'Date', 'SourceRow'});
CombinedPatternTuningBySpeedTable.Properties.Description = ...
    char(options.Description);

CombinedPatternTuningSummary = build_summary(CombinedPatternTuningBySpeedTable);
end

function validate_variables(T, required, sourceName)
missing = setdiff(required, T.Properties.VariableNames);
if ~isempty(missing)
    error('MergeFSTPatternTuningDatasets:MissingVariables', ...
        '%s table is missing: %s', sourceName, strjoin(missing, ', '));
end
end

function out = standardize_source_table(T, sourceDataset, selectionCriterion)
nRows = height(T);
out = table();
out.SourceDataset = repmat(sourceDataset, nRows, 1);
out.SourceRow = double(T.SourceRow);
out.SourceID = sourceDataset + "_" + string(T.SourceRow);
out.Date = T.Date;
out.Monkey = string(T.Monkey);
out.DatasetMonkey = sourceDataset + " " + out.Monkey;
out.ROI = string(T.ROI);
out.Tetrode = optional_numeric(T, 'Tetrode', nRows);
out.Unit = optional_numeric(T, 'Unit', nRows);
out.StimElec = optional_numeric(T, 'StimElec', nRows);
out.OriginalRecIdx = optional_numeric(T, 'OriginalRecIdx', nRows);
out.NeuroType = string(T.NeuroType);
out.SelectionCriterion = repmat(selectionCriterion, nRows, 1);
out.Z3D_v_Z2D = double(T.Z3D_v_Z2D);
out.Combined_AI = double(T.Combined_AI);
out.CombinedCuePreference = string(T.CombinedCuePreference);
out.SpeedRank_2D = double(T.SpeedRank_2D);
out.SpeedCode_2D = optional_numeric(T, 'SpeedCode_2D', nRows);
out.SpeedDegPerSec_2D = speed_values(T, sourceDataset);
out.SpeedLabel_2D = combined_speed_labels(out.SpeedRank_2D);
out.IsMatchedSlowSpeed = logical(T.IsMatchedSlowSpeed);

metricNames = {'T_L', 'T_R', 'A_L', 'A_R', 'R_L', 'R_R', 'L_L', 'L_R', ...
    'N_T_L', 'N_T_R', 'N_A_L', 'N_A_R', 'N_R_L', 'N_R_R', 'N_L_L', 'N_L_R', ...
    'TDI_Numerator', 'TDI_Denominator', 'TDI', ...
    'ADI_Numerator', 'ADI_Denominator', 'ADI'};
for metricIndex = 1:numel(metricNames)
    metricName = metricNames{metricIndex};
    out.(metricName) = double(T.(metricName));
end
out.Valid_TDI = logical(T.Valid_TDI);
out.Valid_ADI = logical(T.Valid_ADI);
out.Complete_AllEightMetrics = logical(T.Complete_AllEightMetrics);
end

function values = optional_numeric(T, variableName, nRows)
if ismember(variableName, T.Properties.VariableNames)
    values = double(T.(variableName));
else
    values = nan(nRows, 1);
end
values = reshape(values, [], 1);
end

function values = speed_values(T, sourceDataset)
if ismember('SpeedDegPerSec_2D', T.Properties.VariableNames)
    values = double(T.SpeedDegPerSec_2D);
elseif sourceDataset == "Lo"
    values = nan(height(T), 1);
    values(T.SpeedRank_2D == 1) = 4.2;
    values(T.SpeedRank_2D == 2) = 12.6;
else
    values = nan(height(T), 1);
end
values = reshape(values, [], 1);
end

function labels = combined_speed_labels(speedRanks)
labels = repmat("Unknown speed", size(speedRanks));
labels(speedRanks == 1) = "Slow (~4.2 deg/s)";
labels(speedRanks == 2) = "Fast (~12.5-12.6 deg/s)";
end

function summary = build_summary(T)
speedRanks = unique(T.SpeedRank_2D, 'stable');
datasets = unique(T.SourceDataset, 'stable');
monkeys = unique(T.Monkey, 'stable');
groupTypes = ["All"; repmat("Dataset", numel(datasets), 1); ...
    repmat("Monkey", numel(monkeys), 1)];
groupNames = ["All"; datasets; monkeys];
nRows = numel(speedRanks) * numel(groupNames);

SpeedRank_2D = zeros(nRows, 1);
SpeedLabel_2D = strings(nRows, 1);
GroupType = strings(nRows, 1);
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
    for groupIndex = 1:numel(groupNames)
        outRow = outRow + 1;
        mask = T.SpeedRank_2D == speedRank;
        if groupTypes(groupIndex) == "Dataset"
            mask = mask & T.SourceDataset == groupNames(groupIndex);
        elseif groupTypes(groupIndex) == "Monkey"
            mask = mask & T.Monkey == groupNames(groupIndex);
        end
        tdi = T.TDI(mask & T.Valid_TDI);
        adi = T.ADI(mask & T.Valid_ADI);
        SpeedRank_2D(outRow) = speedRank;
        SpeedLabel_2D(outRow) = combined_speed_labels(speedRank);
        GroupType(outRow) = groupTypes(groupIndex);
        Group(outRow) = groupNames(groupIndex);
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

summary = table(SpeedRank_2D, SpeedLabel_2D, GroupType, Group, ...
    N_Selected, N_Complete, N_TowardPreferred, N_AwayPreferred, ...
    N_NeutralOrUndefined, N_Valid_TDI, TDI_Mean, TDI_Median, TDI_SD, ...
    N_Valid_ADI, ADI_Mean, ADI_Median, ADI_SD);
end

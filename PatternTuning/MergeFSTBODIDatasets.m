function [CombinedBinocularOpticFlowTable, CombinedBinocularOpticFlowSummary] = ...
    MergeFSTBODIDatasets(loBODI, emBODI, options)
%MERGEFSTBODIDATASETS Merge one-row-per-neuron Lo and EM BODI tables.

arguments
    loBODI table
    emBODI table
    options.LoSelectionCriterion (1, 1) string = ...
        "ROI==FST & sig_Anova_CLR & Z3D_v_Z2D>0"
    options.EMSelectionCriterion (1, 1) string = "ROI==FST & ND==3D"
    options.Description (1, 1) string = ...
        "Merged one-row-per-neuron Lo and EM BODI results"
end

required = {'SourceRow', 'Date', 'Monkey', 'ROI', 'NeuroType', ...
    'Z3D_v_Z2D', 'Combined_AI', 'CombinedCuePreference', ...
    'PreferredCoherence', 'Combined_FR', 'Stereo_FR', ...
    'N_Combined_FR', 'N_Stereo_FR', 'BODI_Numerator', ...
    'BODI_Denominator', 'BODI', 'Valid_BODI'};
validate_variables(loBODI, required, 'Lo');
validate_variables(emBODI, required, 'EM');

lo = standardize_table(loBODI, "Lo", options.LoSelectionCriterion);
em = standardize_table(emBODI, "EM", options.EMSelectionCriterion);
CombinedBinocularOpticFlowTable = [lo; em];
CombinedBinocularOpticFlowTable = sortrows( ...
    CombinedBinocularOpticFlowTable, ...
    {'SourceDataset', 'Monkey', 'Date', 'SourceRow'});
CombinedBinocularOpticFlowTable.Properties.Description = char(options.Description);
CombinedBinocularOpticFlowSummary = build_summary(CombinedBinocularOpticFlowTable);
end

function validate_variables(T, required, sourceName)
missing = setdiff(required, T.Properties.VariableNames);
if ~isempty(missing)
    error('MergeFSTBODIDatasets:MissingVariables', ...
        '%s BODI table is missing: %s', sourceName, strjoin(missing, ', '));
end
end

function out = standardize_table(T, sourceDataset, selectionCriterion)
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
out.PreferredCoherence = double(T.PreferredCoherence);
out.Combined_FR = double(T.Combined_FR);
out.Stereo_FR = double(T.Stereo_FR);
out.N_Combined_FR = double(T.N_Combined_FR);
out.N_Stereo_FR = double(T.N_Stereo_FR);
out.BODI_Numerator = double(T.BODI_Numerator);
out.BODI_Denominator = double(T.BODI_Denominator);
out.BODI = double(T.BODI);
out.Valid_BODI = logical(T.Valid_BODI);
end

function values = optional_numeric(T, variableName, nRows)
if ismember(variableName, T.Properties.VariableNames)
    values = double(T.(variableName));
else
    values = nan(nRows, 1);
end
values = reshape(values, [], 1);
end

function summary = build_summary(T)
datasets = unique(T.SourceDataset, 'stable');
monkeys = unique(T.Monkey, 'stable');
GroupType = ["All"; repmat("Dataset", numel(datasets), 1); ...
    repmat("Monkey", numel(monkeys), 1)];
Group = ["All"; datasets; monkeys];
nRows = numel(Group);
N_Selected = zeros(nRows, 1);
N_TowardPreferred = zeros(nRows, 1);
N_AwayPreferred = zeros(nRows, 1);
N_NeutralOrUndefined = zeros(nRows, 1);
N_Valid_BODI = zeros(nRows, 1);
BODI_Mean = nan(nRows, 1);
BODI_Median = nan(nRows, 1);
BODI_SD = nan(nRows, 1);

for rowIndex = 1:nRows
    mask = true(height(T), 1);
    if GroupType(rowIndex) == "Dataset"
        mask = T.SourceDataset == Group(rowIndex);
    elseif GroupType(rowIndex) == "Monkey"
        mask = T.Monkey == Group(rowIndex);
    end
    values = T.BODI(mask & T.Valid_BODI);
    N_Selected(rowIndex) = nnz(mask);
    N_TowardPreferred(rowIndex) = nnz(mask & T.CombinedCuePreference == "Toward");
    N_AwayPreferred(rowIndex) = nnz(mask & T.CombinedCuePreference == "Away");
    N_NeutralOrUndefined(rowIndex) = nnz(mask ...
        & ~ismember(T.CombinedCuePreference, ["Toward", "Away"]));
    N_Valid_BODI(rowIndex) = numel(values);
    if ~isempty(values)
        BODI_Mean(rowIndex) = mean(values);
        BODI_Median(rowIndex) = median(values);
        BODI_SD(rowIndex) = std(values);
    end
end

summary = table(GroupType, Group, N_Selected, N_TowardPreferred, ...
    N_AwayPreferred, N_NeutralOrUndefined, N_Valid_BODI, BODI_Mean, ...
    BODI_Median, BODI_SD);
end

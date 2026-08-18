function SummaryTable = SummarizeFSTPDIAndBODI(T)
%SUMMARIZEFSTPDIANDBODI Summarize pooled PDI and BODI results.

arguments
    T table
end

datasets = unique(T.SourceDataset, 'stable');
monkeys = unique(T.Monkey, 'stable');
GroupType = ["All"; repmat("Dataset", numel(datasets), 1); ...
    repmat("Monkey", numel(monkeys), 1)];
Group = ["All"; datasets; monkeys];
nGroups = numel(Group);
N_Selected = zeros(nGroups, 1);
N_TowardPreferred = zeros(nGroups, 1);
N_AwayPreferred = zeros(nGroups, 1);
N_Valid_PDI = zeros(nGroups, 1);
PDI_Mean = nan(nGroups, 1);
PDI_Median = nan(nGroups, 1);
PDI_SD = nan(nGroups, 1);
N_Valid_BODI = zeros(nGroups, 1);
BODI_Mean = nan(nGroups, 1);
BODI_Median = nan(nGroups, 1);
BODI_SD = nan(nGroups, 1);

for groupIndex = 1:nGroups
    mask = true(height(T), 1);
    if GroupType(groupIndex) == "Dataset"
        mask = T.SourceDataset == Group(groupIndex);
    elseif GroupType(groupIndex) == "Monkey"
        mask = T.Monkey == Group(groupIndex);
    end
    pdi = T.PDI(mask & T.Valid_PDI);
    bodi = T.BODI(mask & T.Valid_BODI);
    N_Selected(groupIndex) = nnz(mask);
    N_TowardPreferred(groupIndex) = ...
        nnz(mask & T.CombinedCuePreference == "Toward");
    N_AwayPreferred(groupIndex) = ...
        nnz(mask & T.CombinedCuePreference == "Away");
    N_Valid_PDI(groupIndex) = numel(pdi);
    N_Valid_BODI(groupIndex) = numel(bodi);
    if ~isempty(pdi)
        PDI_Mean(groupIndex) = mean(pdi);
        PDI_Median(groupIndex) = median(pdi);
        PDI_SD(groupIndex) = std(pdi);
    end
    if ~isempty(bodi)
        BODI_Mean(groupIndex) = mean(bodi);
        BODI_Median(groupIndex) = median(bodi);
        BODI_SD(groupIndex) = std(bodi);
    end
end

SummaryTable = table(GroupType, Group, N_Selected, N_TowardPreferred, ...
    N_AwayPreferred, N_Valid_PDI, PDI_Mean, PDI_Median, PDI_SD, ...
    N_Valid_BODI, BODI_Mean, BODI_Median, BODI_SD);
end

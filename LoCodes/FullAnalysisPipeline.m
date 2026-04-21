%% Main Analyses
conditionNames = {'Combined','L Mono','R Mono','Binocular','L Control', 'R Control'};
cell_column = ['InRF']; % Will find all cells with stimulus in RF
exclusion_criteria = [{'InRF','N'}; {'ROI','MT/FST'}; {'Hemisphere','Right'}; {'ROI','MT?'}; {'WF',''};{'WF','N'}; {'RF','N'}; {'RF',''}];
monkeys = ["Jim", "Clay"];
areas = ["MT", "FST"];
reanalyze = 0;
trialBased = 1;

%% Initialize variables
file_table_MT_3D = table();
file_table_FST_3D = table();
file_table_MT_2D = table();
file_table_FST_2D = table();
MT_RFTable = table();
FST_RFTable = table();
MT_MIDTable = table();
FST_MIDTable = table();
MT_LateralMotionTable = table();
FST_LateralMotionTable = table();

for m = 1:size(monkeys,2)
    if strcmp(monkeys(m),'Jim')
        xls_table = 'P:\Jim\NeuroData\RecordingRecord_MinusMissing.xlsx';
        path_options = {'C:\Jim\In_Processing\','P:\Jim\NeuroData\'};
        exclusion_criteria = [{'InRF','N'}; {'ROI','MT/FST'}; {'ROI','MT?'}; {'WF',''};{'WF','N'}; {'RF','N'}; {'RF',''}];

    elseif strcmp(monkeys(m),'Clay')
        xls_table = 'P:\Clay\NeuroData\RecordingRecord.xlsx';
        path_options = {'C:\Clay\In_Processing\','P:\Clay\NeuroData\'};
        exclusion_criteria = [{'InRF','N'}; {'ROI','MT/FST'}; {'Hemisphere','Right'}; {'ROI','MT?'}; {'WF',''};{'WF','N'}; {'RF','N'}; {'RF',''}];

    end
    % MT tables
    if any(strcmp(areas,'MT'))
        inclusion_criteria = [{'ROI','MT'}];
        [tmp_RFTable, ~] = GenerateUnitFileTable(xls_table, path_options,...
            cell_column,inclusion_criteria,exclusion_criteria,'SparseNoise_Raw.mat');
        
        [tmp_MT_MIDTable,tmp_file_table_MT_3D] = GenerateUnitFileTable(xls_table, path_options,...
            cell_column,inclusion_criteria,exclusion_criteria,'3D');
        
        [tmp_MT_LateralMotionTable, tmp_file_table_MT_2D] = GenerateUnitFileTable(xls_table, path_options,...
            cell_column,inclusion_criteria,exclusion_criteria,'LateralMotion');
        
        MT_RFTable = [MT_RFTable; tmp_RFTable];
        MT_MIDTable = [MT_MIDTable; tmp_MT_MIDTable];
        MT_LateralMotionTable = [MT_LateralMotionTable; tmp_MT_LateralMotionTable];
        file_table_MT_3D = [file_table_MT_3D; tmp_file_table_MT_3D];
        file_table_MT_2D = [file_table_MT_2D; tmp_file_table_MT_2D];
    end
    % FST tables
    if any(strcmp(areas,'FST'))
        inclusion_criteria = [{'ROI','FST'}];
        [tmp_RFTable, ~] = GenerateUnitFileTable(xls_table, path_options,...
            cell_column,inclusion_criteria,exclusion_criteria,'SparseNoise_Raw.mat');
        
        [tmp_FST_MIDTable,tmp_file_table_FST_3D] = GenerateUnitFileTable(xls_table, path_options,...
            cell_column,inclusion_criteria,exclusion_criteria,'3D');
        
        [tmp_FST_LateralMotionTable, tmp_file_table_FST_2D] = GenerateUnitFileTable(xls_table, path_options,...
            cell_column,inclusion_criteria,exclusion_criteria,'LateralMotion');
        
        FST_RFTable = [FST_RFTable; tmp_RFTable];
        FST_MIDTable = [FST_MIDTable; tmp_FST_MIDTable];
        FST_LateralMotionTable = [FST_LateralMotionTable; tmp_FST_LateralMotionTable];
        file_table_FST_3D = [file_table_FST_3D; tmp_file_table_FST_3D];
        file_table_FST_2D = [file_table_FST_2D; tmp_file_table_FST_2D];
    end
end

files = [file_table_MT_2D; file_table_FST_2D];
files_3D = [file_table_MT_3D; file_table_FST_3D];
RFTable = [MT_RFTable; FST_RFTable];
MIDTable = [MT_MIDTable; FST_MIDTable];
LateralMotionTable = [MT_LateralMotionTable; FST_LateralMotionTable];

clear file_table_MT_2D file_table_FST_2D file_table_MT_3D file_table_FST_3D MT_RFTable FST_RFTable MT_MIDTable FST_MIDTable MT_LateralMotionTable FST_LateralMotionTable

MasterPlotOptions
%% Run Receptive Field Analysis
BatchRFAnalysis_Room2
%% Run 2D analyses
[LateralMotionTable,~] = UpdatedBatchLateralMotionAnalysis(LateralMotionTable, files,  'reanalyze', 0, 'area', 'MT', 'trialBased', trialBased);
%% Run 3D Analyses
[MIDTable, AllData, MotionData_ByStim, model_weights] = UpdatedBatch3DAnalysis(MIDTable, files_3D, LateralMotionTable, 'reanalyze', 0, 'area', 'MT', 'trialBased', trialBased);
MIDTable.Eccentricity = RFData.Eccentricity_Deg;
%% Run post analyses
MonocularityBootstrapTest;
MonocularityPlots;
MTFST_2DComparisons_PrefSpeed;
MonocularityLinearModels;
% MonoInvMonoPlots;
% Cue_Condition_Summary;
BehavioralDataPlots;
Neurometric_Fitting;
ChoiceActivityAnalysis;
PartialCorrelationPlots_2D3DPredictions;
% MonocularityBootstrapTest;F
% AI_Condition_Comparisons_Transposed;

%% Copy data over
AllMonkeyMIDTable = MIDTable;
AllMonkeyRFTable = RFTable;
AllMonkeyRFData = RFData;

AllNeurons = MIDTable;
AllMeans = AllData;
weights = model_weights;
AllRFTable = RFTable;
AllRFData = RFData;

%% Run post analyses
% close all;
% MultiLDA_Area
FLDModels_Area_Quadrant
% ChoiceActivityAnalysis
% LogisticRegressionAnalysis_ByMonkeyByArea
%% Plots
% ChoiceActivityPlots
% 
% 
% for n_area = 1:size(areas,2)
%     a = areas(n_area);
%     areaTable = AllMonkeyMIDTable(strcmp(a,AllMonkeyMIDTable.ROI),:);
% %     areaRFTable = AllRFTable(strcmp(a,AllMonkeyMIDTable.ROI),:);
% %     areaRFData = AllRFData(strcmp(a,AllMonkeyMIDTable.ROI),:);
% %     RFTable = areaRFTable;
% %     RFData = areaRFData;
%     MIDTable = areaTable;
%     ChoiceActivityPlots
% %     Cue_Condition_Summary
% %     RFSummaryPlots_v2
%     
%     
% %     for n_monk = 1:size(monkeys,2)
% %         m = monkeys{n_monk};
% %         MIDTable = areaTable(strcmp(m,areaTable.Monkey),:);
% %         RFTable = areaRFTable(strcmp(m,areaTable.Monkey),:);
% %         RFData = areaRFData(strcmp(m,areaTable.Monkey),:);
% %         if ~isempty(MIDTable)
% %             
% %             MonoInvMonoPlots
% %             ODI_Histograms
% %             MonocularityPlots
% %         end
% %     end
% end
% MIDTable = AllMonkeyMIDTable;



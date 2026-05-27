function [MIDTable, files_3D] = BuildExamplePlotMIDTable()
%BUILDEXAMPLEPLOTMIDTABLE Rebuild the 3D MIDTable selection for plotting.
% Matches the same recording selection logic used in FullAnalysisPipeline.

cell_column = ['InRF']; %#ok<NBRAK>
exclusion_criteria = [{'InRF','N'}; {'ROI','MT/FST'}; {'Hemisphere','Right'}; ...
    {'ROI','MT?'}; {'WF',''}; {'WF','N'}; {'RF','N'}; {'RF',''}];
monkeys = ["Jim", "Clay"];
areas = ["MT", "FST"];

file_table_MT_3D = table();
file_table_FST_3D = table();
MT_MIDTable = table();
FST_MIDTable = table();

for m = 1:size(monkeys, 2)
    if strcmp(monkeys(m), 'Jim')
        xls_table = 'P:\Jim\NeuroData\RecordingRecord_MinusMissing.xlsx';
        path_options = {'C:\Jim\In_Processing\', 'P:\Jim\NeuroData\'};
        exclusion_criteria = [{'InRF','N'}; {'ROI','MT/FST'}; {'ROI','MT?'}; ...
            {'WF',''}; {'WF','N'}; {'RF','N'}; {'RF',''}];

    elseif strcmp(monkeys(m), 'Clay')
        xls_table = 'P:\Clay\NeuroData\RecordingRecord.xlsx';
        path_options = {'C:\Clay\In_Processing\', 'P:\Clay\NeuroData\'};
        exclusion_criteria = [{'InRF','N'}; {'ROI','MT/FST'}; {'Hemisphere','Right'}; ...
            {'ROI','MT?'}; {'WF',''}; {'WF','N'}; {'RF','N'}; {'RF',''}];
    end

    if any(strcmp(areas, 'MT'))
        inclusion_criteria = [{'ROI','MT'}];
        [tmp_MT_MIDTable, tmp_file_table_MT_3D] = GenerateUnitFileTable( ...
            xls_table, path_options, cell_column, inclusion_criteria, ...
            exclusion_criteria, '3D');
        MT_MIDTable = [MT_MIDTable; tmp_MT_MIDTable]; %#ok<AGROW>
        file_table_MT_3D = [file_table_MT_3D; tmp_file_table_MT_3D]; %#ok<AGROW>
    end

    if any(strcmp(areas, 'FST'))
        inclusion_criteria = [{'ROI','FST'}];
        [tmp_FST_MIDTable, tmp_file_table_FST_3D] = GenerateUnitFileTable( ...
            xls_table, path_options, cell_column, inclusion_criteria, ...
            exclusion_criteria, '3D');
        FST_MIDTable = [FST_MIDTable; tmp_FST_MIDTable]; %#ok<AGROW>
        file_table_FST_3D = [file_table_FST_3D; tmp_file_table_FST_3D]; %#ok<AGROW>
    end
end

MIDTable = [MT_MIDTable; FST_MIDTable];
files_3D = [file_table_MT_3D; file_table_FST_3D];
end

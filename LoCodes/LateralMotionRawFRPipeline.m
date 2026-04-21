%% Lateral Motion Raw FR Pipeline
% Mirrors the file selection / inclusion logic in FullAnalysisPipeline.m,
% then exports per-unit raw firing-rate data for lateral motion and saves a
% single table to C:\LoData.

cell_column = ['InRF']; %#ok<NBRAK>
exclusion_criteria = [{'InRF','N'}; {'ROI','MT/FST'}; {'Hemisphere','Right'}; ...
    {'ROI','MT?'}; {'WF',''}; {'WF','N'}; {'RF','N'}; {'RF',''}];
monkeys = ["Jim", "Clay"];
areas = ["MT", "FST"];

%% Initialize variables
file_table_MT_2D = table();
file_table_FST_2D = table();
MT_LateralMotionTable = table();
FST_LateralMotionTable = table();

disp('Starting lateral raw FR pipeline...')
disp(['Monkeys: ', strjoin(cellstr(monkeys), ', ')])
disp(['Areas: ', strjoin(cellstr(areas), ', ')])

for m = 1:size(monkeys, 2)
    disp(['Preparing file tables for monkey ', char(monkeys(m)), ...
        ' (', num2str(m), '/', num2str(size(monkeys, 2)), ')'])
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

    % MT tables
    if any(strcmp(areas, 'MT'))
        disp('  Loading MT lateral-motion entries...')
        inclusion_criteria = [{'ROI','MT'}];
        [tmp_MT_LateralMotionTable, tmp_file_table_MT_2D] = GenerateUnitFileTable( ...
            xls_table, path_options, cell_column, inclusion_criteria, ...
            exclusion_criteria, 'LateralMotion');

        MT_LateralMotionTable = [MT_LateralMotionTable; tmp_MT_LateralMotionTable]; %#ok<AGROW>
        file_table_MT_2D = [file_table_MT_2D; tmp_file_table_MT_2D]; %#ok<AGROW>
    end

    % FST tables
    if any(strcmp(areas, 'FST'))
        disp('  Loading FST lateral-motion entries...')
        inclusion_criteria = [{'ROI','FST'}];
        [tmp_FST_LateralMotionTable, tmp_file_table_FST_2D] = GenerateUnitFileTable( ...
            xls_table, path_options, cell_column, inclusion_criteria, ...
            exclusion_criteria, 'LateralMotion');

        FST_LateralMotionTable = [FST_LateralMotionTable; tmp_FST_LateralMotionTable]; %#ok<AGROW>
        file_table_FST_2D = [file_table_FST_2D; tmp_file_table_FST_2D]; %#ok<AGROW>
    end
end

files = [file_table_MT_2D; file_table_FST_2D];
LateralMotionRawFRTable = [MT_LateralMotionTable; FST_LateralMotionTable];

disp(['Total recordings selected: ', num2str(size(files, 1))])
disp(['Total unit rows selected: ', num2str(size(LateralMotionRawFRTable, 1))])

%% Export raw FR from TInfo files
disp('Exporting raw FR from TInfo files...')
RawFRData = BatchSaveLateralMotionRawFR(files, ...
    'saveOutputs', false, ...
    'saveCombined', false);

%% Build one per-unit table aligned with the original lateral-motion table
disp('Building final per-unit raw FR table...')
LateralMotionRawFRTable = append_raw_fr_columns(LateralMotionRawFRTable, files, RawFRData);

%% Save outputs
output_dir = 'C:\LoData';
if ~isfolder(output_dir)
    mkdir(output_dir);
end

save(fullfile(output_dir, 'LateralMotionRawFRTable.mat'), ...
    'LateralMotionRawFRTable', 'files', 'RawFRData', '-v7.3');

disp(['Saved lateral raw FR table to ', fullfile(output_dir, 'LateralMotionRawFRTable.mat')]);
disp('Lateral raw FR pipeline complete.')

function LateralMotionRawFRTable = append_raw_fr_columns(LateralMotionRawFRTable, files, RawFRData)
nRows = size(LateralMotionRawFRTable, 1);

LateralMotionRawFRTable.ExportRecordingName = strings(nRows, 1);
LateralMotionRawFRTable.TrialRawFR = cell(nRows, 1);
LateralMotionRawFRTable.TrialConditionCode = cell(nRows, 1);
LateralMotionRawFRTable.TrialDirectionCode = cell(nRows, 1);
LateralMotionRawFRTable.TrialSpeedCode = cell(nRows, 1);
LateralMotionRawFRTable.TrialTaskCode = cell(nRows, 1);
LateralMotionRawFRTable.ValidTrial = cell(nRows, 1);
LateralMotionRawFRTable.ConditionCodesUsed = cell(nRows, 1);
LateralMotionRawFRTable.DirectionCodesUsed = cell(nRows, 1);
LateralMotionRawFRTable.SpeedCodesUsed = cell(nRows, 1);
LateralMotionRawFRTable.DirectionDegreesGuess = cell(nRows, 1);
LateralMotionRawFRTable.RawFR_ByConditionDirectionSpeed = cell(nRows, 1);
LateralMotionRawFRTable.MeanFR_ByConditionDirectionSpeed = cell(nRows, 1);
LateralMotionRawFRTable.SEMFR_ByConditionDirectionSpeed = cell(nRows, 1);
LateralMotionRawFRTable.NTrials_ByConditionDirectionSpeed = cell(nRows, 1);
LateralMotionRawFRTable.RawFR_ByDirection = cell(nRows, 1);
LateralMotionRawFRTable.MeanFR_ByDirection = cell(nRows, 1);
LateralMotionRawFRTable.SEMFR_ByDirection = cell(nRows, 1);
LateralMotionRawFRTable.NTrials_ByDirection = cell(nRows, 1);

rowIdx = 1;
totalRows = size(LateralMotionRawFRTable, 1);
for f = 1:size(files, 1)
    units = files.Units{f};
    exportData = RawFRData(f);

    disp(['Appending file ', num2str(f), '/', num2str(size(files, 1)), ...
        ': ', files.Names{f, 1}, '  (', num2str(numel(units)), ' units)'])

    for u = 1:numel(units)
        assert_row_alignment(LateralMotionRawFRTable, files, rowIdx, f, units(u));

        LateralMotionRawFRTable.ExportRecordingName(rowIdx) = string(exportData.recording_name);
        LateralMotionRawFRTable.TrialRawFR{rowIdx} = exportData.trial_raw_fr(:, u);
        LateralMotionRawFRTable.TrialConditionCode{rowIdx} = exportData.trial_condition_code;
        LateralMotionRawFRTable.TrialDirectionCode{rowIdx} = exportData.trial_direction_code;
        LateralMotionRawFRTable.TrialSpeedCode{rowIdx} = exportData.trial_speed_code;
        LateralMotionRawFRTable.TrialTaskCode{rowIdx} = exportData.trial_task_code;
        LateralMotionRawFRTable.ValidTrial{rowIdx} = exportData.valid_trial;

        LateralMotionRawFRTable.ConditionCodesUsed{rowIdx} = exportData.condition_codes;
        LateralMotionRawFRTable.DirectionCodesUsed{rowIdx} = exportData.direction_codes;
        LateralMotionRawFRTable.SpeedCodesUsed{rowIdx} = exportData.speed_codes;
        LateralMotionRawFRTable.DirectionDegreesGuess{rowIdx} = exportData.direction_degrees_guess;

        LateralMotionRawFRTable.RawFR_ByConditionDirectionSpeed{rowIdx} = ...
            squeeze(exportData.rawFR_by_condition_direction_speed(:, :, :, u));
        LateralMotionRawFRTable.MeanFR_ByConditionDirectionSpeed{rowIdx} = ...
            squeeze(exportData.meanFR_by_condition_direction_speed(:, :, :, u));
        LateralMotionRawFRTable.SEMFR_ByConditionDirectionSpeed{rowIdx} = ...
            squeeze(exportData.semFR_by_condition_direction_speed(:, :, :, u));
        LateralMotionRawFRTable.NTrials_ByConditionDirectionSpeed{rowIdx} = ...
            squeeze(exportData.nTrials_by_condition_direction_speed(:, :, :, u));

        LateralMotionRawFRTable.RawFR_ByDirection{rowIdx} = exportData.rawFR_by_direction(:, u);
        LateralMotionRawFRTable.MeanFR_ByDirection{rowIdx} = exportData.meanFR_by_direction(:, u);
        LateralMotionRawFRTable.SEMFR_ByDirection{rowIdx} = exportData.semFR_by_direction(:, u);
        LateralMotionRawFRTable.NTrials_ByDirection{rowIdx} = exportData.nTrials_by_direction(:, u);

        if mod(rowIdx, 50) == 0 || rowIdx == totalRows
            disp(['  Filled rows ', num2str(rowIdx), '/', num2str(totalRows)])
        end

        rowIdx = rowIdx + 1;
    end
end

if rowIdx ~= nRows + 1
    error('Row alignment failed while building LateralMotionRawFRTable.');
end
end

function assert_row_alignment(LateralMotionRawFRTable, files, rowIdx, fileIdx, unitId)
if rowIdx > size(LateralMotionRawFRTable, 1)
    error('LateralMotionRawFRTable has fewer rows than expected from files.Units.');
end

if ~strcmp(LateralMotionRawFRTable.Names{rowIdx, 1}, files.Names{fileIdx, 1})
    error('Name mismatch at row %d while aligning raw FR output.', rowIdx);
end

if LateralMotionRawFRTable.Unit(rowIdx) ~= unitId
    error('Unit mismatch at row %d while aligning raw FR output.', rowIdx);
end
end

function tests = TestLoadUnitTableStimForPopulation
%TESTLOADUNITTABLESTIMFORPOPULATION Direct-input and completeness tests.
tests = functiontests(localfunctions);
end


function testLoadsAuthoritativeTableDirectly(testCase)
unit_table_stim = makeStimTable();
unit_table_stim.Behav_bias_N = {1:4; 5:8};
unit_table_stim.p_AI = {[0.1; 0.01; 0.02]; [0.2; 0.03; 0.04]};
unit_table_stim.Z3D_v_Z2D = {-1.5; 2.5};
PipelineMetadata = struct('SchemaVersion', "synthetic-v1");
[stim_file, cleanup] = writeArtifact( ...
    unit_table_stim, PipelineMetadata, true); %#ok<ASGLU>

[loaded_table, resolved_file, loaded_metadata, audit] = ...
    LoadUnitTableStimForPopulation(stim_file);

expected_table = unit_table_stim;
expected_table.stim_tuning_artifact_table_row = [1; 2];
verifyEqual(testCase, loaded_table, expected_table);
verifyEqual(testCase, resolved_file, stim_file);
verifyEqual(testCase, loaded_metadata, PipelineMetadata);
verifyEqual(testCase, audit.ArtifactTableRow, [1; 2]);
verifyEqual(testCase, audit.Included, [true; true]);
verifyEqual(testCase, loaded_table.stim_tuning_artifact_table_row, [1; 2]);
end


function testExcludesIncompleteCheckpointRows(testCase)
unit_table_stim = makeStimTable();
unit_table_stim.stim_tuning_status(2) = "Pending";
[stim_file, cleanup] = writeArtifact( ...
    unit_table_stim, struct(), false); %#ok<ASGLU>

[loaded_table, ~, ~, audit] = ...
    LoadUnitTableStimForPopulation(stim_file);

verifyEqual(testCase, height(loaded_table), 1);
verifyEqual(testCase, loaded_table.Monkey, "Jim");
verifyEqual(testCase, loaded_table.stim_tuning_artifact_table_row, 1);
verifyEqual(testCase, audit.Included, [true; false]);
end


function testRejectsArtifactWithNoCompletedRows(testCase)
unit_table_stim = makeStimTable();
unit_table_stim.stim_tuning_status(:) = "Pending";
[stim_file, cleanup] = writeArtifact( ...
    unit_table_stim, struct(), false); %#ok<ASGLU>

verifyError(testCase, @() LoadUnitTableStimForPopulation(stim_file), ...
    'PopulationAnalysis:NoCompletedStimTuningRows');
end


function testRejectsMissingStatus(testCase)
unit_table_stim = removevars(makeStimTable(), 'stim_tuning_status');
[stim_file, cleanup] = writeArtifact( ...
    unit_table_stim, struct(), false); %#ok<ASGLU>

verifyError(testCase, @() LoadUnitTableStimForPopulation(stim_file), ...
    'PopulationAnalysis:MissingStimTuningStatus');
end


function testRejectsMissingTableVariable(testCase)
temporary_folder = tempname;
mkdir(temporary_folder);
cleanup = onCleanup( ...
    @() removeTemporaryFolder(temporary_folder));
stim_file = fullfile(temporary_folder, 'unit_table_stim.mat');
not_the_table = 1;
save(stim_file, 'not_the_table');

verifyError(testCase, @() LoadUnitTableStimForPopulation(stim_file), ...
    'PopulationAnalysis:MissingStimTable');
end


function unit_table_stim = makeStimTable()
Date = [datetime(2024, 1, 2); datetime(2024, 1, 3)];
Monkey = ["Jim"; "Clay"];
stim_tuning_status = ["Success"; "SuccessWithEyeCheckWarning"];
unit_table_stim = table(Date, Monkey, stim_tuning_status);
end


function [stim_file, cleanup] = writeArtifact( ...
    unit_table_stim, PipelineMetadata, include_metadata)
temporary_folder = tempname;
mkdir(temporary_folder);
cleanup = onCleanup(@() removeTemporaryFolder(temporary_folder));
stim_file = fullfile(temporary_folder, 'unit_table_stim.mat');
if include_metadata
    save(stim_file, 'unit_table_stim', 'PipelineMetadata');
else
    save(stim_file, 'unit_table_stim');
end
end


function removeTemporaryFolder(folder)
if isfolder(folder)
    rmdir(folder, 's');
end
end

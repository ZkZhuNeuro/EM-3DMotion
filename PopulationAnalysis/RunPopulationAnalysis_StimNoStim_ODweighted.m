clear

%% Population analysis using the stimulation task's NoStim neural tuning
% Edit area/monkey below, then run this script. Behavioral bias, the p_AI
% significance gate, and the 2D/3D label are read directly from the
% unit_table_stim artifact. AI and OD are recalculated from the stimulation
% electrode's non-electrical-stimulation trials in the 3DMotionStim task.

area = 'FST'; %#ok<NASGU> % 'MT' or 'FST'
monkey = 'Both'; %#ok<NASGU> % 'Both', 'Jim', or 'Clay'
stim_data_file = 'C:\EM\StimTuningAnalysis\unit_table_stim.mat'; %#ok<NASGU>
close_existing_figures = true; %#ok<NASGU>
tuning_source = 'StimNoStim'; %#ok<NASGU>
population_analysis_use_supplied_settings = true; %#ok<NASGU>

script_folder = fileparts(mfilename('fullpath'));
try
    run(fullfile(script_folder, 'RunPopulationAnalysis_ODweighted.m'))
catch ME
    clear area monkey stim_data_file close_existing_figures ...
        tuning_source population_analysis_use_supplied_settings script_folder
    rethrow(ME)
end

% Keep the result variables while preventing these wrapper settings from
% changing a later direct run of RunPopulationAnalysis_ODweighted.
clear area monkey stim_data_file close_existing_figures ...
    tuning_source population_analysis_use_supplied_settings script_folder

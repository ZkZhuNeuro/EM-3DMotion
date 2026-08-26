function output_files = GeneratePosterPopulationPDFs_StimChannel()
%GENERATEPOSTERPOPULATIONPDFS_STIMCHANNEL Export the latest population plots.
%
% The newest unit_table_gof_matched_original_stim_channel.mat artifact is
% selected recursively from C:\EM\StimTuningAnalysis. The population
% analysis is rerun with its weighted regression constrained to the origin,
% then the figures are relabeled and exported as vector PDFs under
% C:\EM\PopulationAnalysis\output\pdf.

analysis_root = 'C:\EM\StimTuningAnalysis';
table_name = 'unit_table_gof_matched_original_stim_channel.mat';
table_files = dir(fullfile(analysis_root, '**', table_name));
if isempty(table_files)
    error('PosterPopulation:MissingStimChannelTable', ...
        'No %s artifact was found under %s.', table_name, analysis_root);
end

[~, newest_index] = max([table_files.datenum]);
newest_table = fullfile(table_files(newest_index).folder, ...
    table_files(newest_index).name);
validate_stimulation_channel_artifact(newest_table);

source_folder = table_files(newest_index).folder;
script_folder = fileparts(mfilename('fullpath'));
population_script = fullfile(script_folder, ...
    'RunPopulationAnalysis_ODweighted.m');
output_folder = fullfile('C:\EM', 'PopulationAnalysis', 'output', 'pdf');
if ~isfolder(output_folder)
    mkdir(output_folder);
end

areas = {'MT', 'FST'};
unit_types = {'2D', '3D'};
output_files = strings(numel(areas) * numel(unit_types), 1);
output_index = 0;

for area_index = 1:numel(areas)
    area = areas{area_index};
    results = run_population_analysis( ...
        population_script, newest_table, area);
    figures = [results.fig_2d, results.fig_3d];
    for type_index = 1:numel(unit_types)
        unit_type = unit_types{type_index};
        fig = figures(type_index);
        cleanup = onCleanup(@() close_figure(fig));
        assert_lines_pass_origin(fig);
        polish_figure(fig, area, unit_type);

        output_index = output_index + 1;
        output_files(output_index) = fullfile(output_folder, sprintf( ...
            'Population_StimChannel_%s_Both_%s_Poster.pdf', ...
            area, unit_type));
        exportgraphics(fig, output_files(output_index), ...
            'ContentType', 'vector', 'BackgroundColor', 'white');
        clear cleanup
        close_figure(fig);
    end
end

fprintf('Newest stimulation-channel table: %s\n', newest_table);
fprintf('Population source folder: %s\n', source_folder);
fprintf('Table modified: %s\n', ...
    string(datetime(table_files(newest_index).datenum, ...
    'ConvertFrom', 'datenum', 'Format', 'yyyy-MM-dd HH:mm:ss')));
fprintf('Created %d poster PDFs in %s\n', numel(output_files), output_folder);
disp(output_files)
end


function results = run_population_analysis( ...
    population_script, data_file, selected_area)
area = selected_area; %#ok<NASGU>
monkey = 'Both'; %#ok<NASGU>
tuning_source = 'Quick'; %#ok<NASGU>
close_existing_figures = false; %#ok<NASGU>
population_analysis_use_supplied_settings = true; %#ok<NASGU>
run(population_script)
end


function validate_stimulation_channel_artifact(table_file)
variables = string({whos('-file', table_file).name});
if ~ismember("unit_table_gof", variables)
    error('PosterPopulation:MissingUnitTable', ...
        'The newest artifact does not contain unit_table_gof: %s', table_file);
end
if ismember("EqualFiveChannelMetaReadout", variables)
    metadata = load(table_file, 'EqualFiveChannelMetaReadout');
    readout = string(metadata.EqualFiveChannelMetaReadout);
    if ~contains(lower(readout), "original stimulation channel")
        error('PosterPopulation:WrongReadout', ...
            'The newest artifact is not the original stimulation-channel readout.');
    end
end
end


function assert_lines_pass_origin(fig)
axes_handles = findall(fig, 'Type', 'axes');
if isempty(axes_handles)
    error('PosterPopulation:MissingAxes', ...
        'No plotting axes were found in the generated figure.');
end
line_handles = findall(axes_handles(1), 'Type', 'line');
fit_line_count = 0;
for line_index = 1:numel(line_handles)
    line_handle = line_handles(line_index);
    if ~strcmp(line_handle.LineStyle, '-') || line_handle.LineWidth < 2
        continue
    end
    fit_line_count = fit_line_count + 1;
    x_data = double(line_handle.XData(:));
    y_data = double(line_handle.YData(:));
    [distance_to_zero, zero_index] = min(abs(x_data));
    if distance_to_zero > 1e-12 || abs(y_data(zero_index)) > 1e-10
        error('PosterPopulation:FitMissesOrigin', ...
            'A displayed weighted fit does not pass through the origin.');
    end
end
if fit_line_count ~= 4
    error('PosterPopulation:UnexpectedFitLineCount', ...
        'Expected four regression lines; found %d.', fit_line_count);
end
end


function polish_figure(fig, area, unit_type)
set(fig, 'Color', 'w', 'Units', 'inches', ...
    'Position', [0.5, 0.5, 8.5, 6.4], ...
    'PaperPositionMode', 'auto');

axes_handles = findall(fig, 'Type', 'axes');
if isempty(axes_handles)
    error('PosterPopulation:MissingAxes', ...
        'No plotting axes were found in the saved figure.');
end
ax = axes_handles(1);
set(ax, 'FontName', 'Arial', 'FontSize', 17, 'LineWidth', 1.25);
title(ax, sprintf('%s %s neurons', area, unit_type), ...
    'FontName', 'Arial', 'FontSize', 21, 'FontWeight', 'bold');
xlabel(ax, 'Asymmetry index (stimulation-channel tuning)', ...
    'FontName', 'Arial', 'FontSize', 19);
ylabel(ax, '\Delta bias', 'Interpreter', 'tex', ...
    'FontName', 'Arial', 'FontSize', 19);

legend_handles = findall(fig, 'Type', 'legend');
for legend_index = 1:numel(legend_handles)
    labels = string(legend_handles(legend_index).String);
    labels(labels == "NonDominant") = "Non-dominant";
    set(legend_handles(legend_index), ...
        'String', cellstr(labels), ...
        'FontName', 'Arial', 'FontSize', 16, ...
        'Box', 'off');
end
end


function close_figure(fig)
if isgraphics(fig)
    close(fig)
end
end

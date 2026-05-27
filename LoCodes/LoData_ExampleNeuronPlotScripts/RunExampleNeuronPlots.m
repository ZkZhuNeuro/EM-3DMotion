%% Run Example Neuron Plots
% Self-contained version of ExampleNeuronPlots.m for LoData exports.
% This script rebuilds (or loads) MIDTable, runs Offline_3DMotion_update
% for each requested neuron, and saves the figures to C:\LoData.

cfg = ExampleNeuronPlotConfig();
script_dir = fileparts(mfilename('fullpath'));

addpath(script_dir, '-begin');
addpath(cfg.code_root, '-begin');
add_dependency_paths(cfg);
rehash;
clear Offline_3DMotion_update GenerateUnitFileTable getSDF
addpath(script_dir, '-begin');
addpath(cfg.code_root, '-begin');

offlinePath = which('Offline_3DMotion_update');
getSdfPath = which('getSDF');

disp(['Using Offline_3DMotion_update from ', offlinePath])
disp(['Using getSDF from ', getSdfPath])

expectedOfflinePath = fullfile(cfg.code_root, 'Offline_3DMotion_update.m');
assert(strcmpi(offlinePath, expectedOfflinePath), ...
    ['MATLAB resolved Offline_3DMotion_update to an unexpected location: ', ...
    offlinePath, ' Expected: ', expectedOfflinePath]);

assert(exist('Offline_3DMotion_update', 'file') == 2, ...
    'Offline_3DMotion_update.m was not found on the MATLAB path.');
assert(exist('GenerateUnitFileTable', 'file') == 2, ...
    'GenerateUnitFileTable.m was not found on the MATLAB path.');

apply_plot_defaults();

if ~exist(cfg.output_dir, 'dir')
    mkdir(cfg.output_dir);
end

MIDTable = load_or_build_midtable(cfg);
nExamples = numel(cfg.examples);

disp(['Saving example neuron plots to ', cfg.output_dir])

for i = 1:nExamples
    spec = cfg.examples(i);
    disp(['Plotting example ', num2str(i), '/', num2str(nExamples), ...
        ': ', spec.DisplayName])

    matchIdx = find(strcmp(MIDTable.Names(:, 1), spec.RecordingName) & ...
        MIDTable.Unit == spec.Unit);

    if isempty(matchIdx)
        warning('No MIDTable row matched %s (unit %d).', ...
            spec.RecordingName, spec.Unit);
        continue
    end

    if numel(matchIdx) > 1
        warning('Multiple MIDTable rows matched %s (unit %d). Using the first row.', ...
            spec.RecordingName, spec.Unit);
        matchIdx = matchIdx(1);
    end

    Offline_3DMotion_update(MIDTable.Paths(matchIdx), MIDTable.Names(matchIdx, :), 1, spec.Unit);

    fig = gcf;
    baseName = make_export_name(MIDTable, matchIdx, spec);
    pdfPath = fullfile(cfg.output_dir, [baseName, '.pdf']);
    saveas(fig, pdfPath);

    if cfg.also_save_fig
        figPath = fullfile(cfg.output_dir, [baseName, '.fig']);
        savefig(fig, figPath);
    end

    if cfg.close_figures_after_save
        close(fig);
    end
end

disp('Finished exporting example neuron plots.')

function MIDTable = load_or_build_midtable(cfg)
MIDTable = [];

if cfg.use_saved_midtable && isfile(cfg.midtable_path)
    S = load(cfg.midtable_path);

    if isfield(S, 'MIDTable')
        MIDTable = S.MIDTable;
    elseif isfield(S, 'AllMonkeyMIDTable')
        MIDTable = S.AllMonkeyMIDTable;
    else
        error('No MIDTable or AllMonkeyMIDTable variable found in %s.', ...
            cfg.midtable_path);
    end

    disp(['Loaded MIDTable from ', cfg.midtable_path])
else
    [MIDTable, ~] = BuildExamplePlotMIDTable(); %#ok<ASGLU>
    disp(['Rebuilt MIDTable with ', num2str(height(MIDTable)), ' rows.'])
end
end

function baseName = make_export_name(MIDTable, matchIdx, spec)
baseName = '';

if ismember('Label', MIDTable.Properties.VariableNames)
    labelVal = MIDTable.Label(matchIdx);
    if ~isempty(labelVal) && strlength(string(labelVal)) > 0
        baseName = char(string(labelVal));
    end
end

if isempty(baseName)
    dateStr = datestr(MIDTable.Date(matchIdx), 'yyyy-mm-dd');
    roiStr = char(string(MIDTable.ROI(matchIdx)));
    tetrodeStr = num2str(MIDTable.Tetrode(matchIdx));
    unitStr = num2str(MIDTable.Unit(matchIdx));
    baseName = [roiStr, '_', dateStr, '_TT', tetrodeStr, '_U', unitStr];
end

if isfield(spec, 'DisplayName') && strlength(string(spec.DisplayName)) > 0
    baseName = [char(string(spec.DisplayName)), '_', baseName];
end

baseName = regexprep(baseName, '[^\w\-]', '_');
end

function apply_plot_defaults()
set(groot, {'DefaultAxesXColor','DefaultAxesYColor','DefaultAxesZColor', ...
    'DefaultTextFontName'}, {'k','k','k', 'Arial'})
set(groot, {'DefaultAxesLineWidth', 'DefaultLineLineWidth'}, {2, 2})
set(groot, 'FixedWidthFontName', 'Arial')
end

function add_dependency_paths(cfg)
if ~isfield(cfg, 'dependency_paths') || isempty(cfg.dependency_paths)
    return
end

for i = 1:numel(cfg.dependency_paths)
    depPath = cfg.dependency_paths{i};
    if isfolder(depPath)
        addpath(genpath(depPath));
    else
        warning('Dependency path not found and was skipped: %s', depPath);
    end
end
end

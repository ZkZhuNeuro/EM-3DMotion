generateSessionPlots = false;
generateCoronalPlots = false;
generateSagittalPlots = true;
jimSessionWorkbookRows = [];
run(fullfile(fileparts(mfilename('fullpath')), ...
    'generate_jim_recording_location_plots.m'));

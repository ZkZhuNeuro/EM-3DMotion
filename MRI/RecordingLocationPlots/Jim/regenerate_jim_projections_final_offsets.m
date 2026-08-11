generateSessionPlots = false;
generateCoronalPlots = true;
generateSagittalPlots = true;
jimSessionWorkbookRows = [];
run(fullfile(fileparts(mfilename('fullpath')), ...
    'generate_jim_recording_location_plots.m'));

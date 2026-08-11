scriptDir = fileparts(mfilename('fullpath'));
run(fullfile(scriptDir, 'generate_clay_projected_by_y.m'));
clearvars -except scriptDir;
run(fullfile(scriptDir, 'generate_clay_projected_sagittal.m'));

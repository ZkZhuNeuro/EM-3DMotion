% Recompute the Jim MT/FST label-optimized oblique sections and audits.
this_dir = fileparts(mfilename('fullpath'));
addpath(this_dir);
output_dir = 'C:\EM\RecordingLocationPlots\Jim\OptimizedOblique';
results = optimize_jim_mtfst_oblique_section(output_dir); %#ok<NASGU>

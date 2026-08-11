addpath(fileparts(mfilename('fullpath')));
workbookPath = 'P:\Jim\NeuroData\RecordingRecord_Stimulation_final.xlsx';
tb = readtable(workbookPath, 'VariableNamingRule', 'preserve');
[includedRows, inclusionAudit] = getWorkbookRowsFromUnitTableGof(tb, 'Jim'); %#ok<NASGU>
roiValues = upper(strip(string(tb.ROI)));
mtRows = includedRows(roiValues(includedRows) == "MT");
assert(numel(mtRows) == 54, 'Expected 54 included Jim MT sessions, found %d.', numel(mtRows));

generateSessionPlots = true;
generateCoronalPlots = true;
generateSagittalPlots = true;
jimSessionWorkbookRows = mtRows + 1;
jimCoronalAreas = "MT";
run('C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\.codex_tmp\clay_smoke\generate_jim_recording_location_plots.m');

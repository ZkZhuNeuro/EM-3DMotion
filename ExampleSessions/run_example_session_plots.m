%% Export P-drive example-session tuning and behavior plots
% These defaults mirror FullStimulationAnalysisPipeline_042022.m on P:.

thisDirectory = fileparts(mfilename('fullpath'));
pDriveWorkbook = ...
    'P:\Jim\NeuroData\RecordingRecord_Stimulation_20240515.xlsx';
pDriveSessionCache = 'P:\Jim\StimData';
monkey = "Jim";

% The P-drive pipeline uses `for rec = 2`. Change this vector to plot other
% MUA-stimulation sessions from the same P-drive workbook.
exampleSessionIndices = 2;

if ~isfile(pDriveWorkbook)
    error('P-drive recording workbook not found: %s', pDriveWorkbook);
end
if ~isfolder(pDriveSessionCache)
    error('P-drive session-cache folder not found: %s', pDriveSessionCache);
end

recordingTable = readtable(pDriveWorkbook, ...
    'VariableNamingRule', 'preserve');
recordingDates = normalizeRecordingDates(recordingTable.Date);
muaStim = strip(string(recordingTable.MUAStim));
roi = strip(string(recordingTable.ROI));
includedRows = find(strcmpi(muaStim, 'Y') & ismember(upper(roi), ["MT", "FST"]));

if any(exampleSessionIndices > numel(includedRows))
    error('Example session indices must be between 1 and %d.', numel(includedRows));
end

outputDirectory = 'C:\EM\ExampleSessionPlots';
manifest = table();
for exampleIndex = exampleSessionIndices
    workbookRow = includedRows(exampleIndex);
    sessionDate = recordingDates(workbookRow);
    cacheFile = fullfile(pDriveSessionCache, ...
        char(string(sessionDate, 'yyyyMMdd') + ".mat"));
    if ~isfile(cacheFile)
        error(['The P-drive cache is missing for workbook row %d: %s. ', ...
            'Run the P-drive stimulation pipeline for this session first.'], ...
            workbookRow + 1, cacheFile);
    end

    sessionManifest = PlotExampleSessions(cacheFile, ...
        OutputDirectory=outputDirectory, ...
        Formats=["png", "pdf"], ...
        Visible="off", ...
        StimElectrode=recordingTable.StimElec(workbookRow), ...
        Monkey=monkey, ...
        ROI=roi(workbookRow), ...
        SessionDate=sessionDate);
    sessionManifest.WorkbookRow(:) = workbookRow + 1;
    manifest = [manifest; sessionManifest]; %#ok<AGROW>
end

writetable(manifest, ...
    fullfile(outputDirectory, 'ExampleSessionPlots_manifest.csv'));
disp(manifest)

function dates = normalizeRecordingDates(values)
if isdatetime(values)
    dates = values;
elseif isnumeric(values)
    dates = datetime(values, 'ConvertFrom', 'excel');
elseif iscell(values)
    dates = datetime(string(values));
else
    dates = datetime(values);
end
dates = dates(:);
end

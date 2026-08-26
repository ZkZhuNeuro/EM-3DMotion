function tests = TestNoExperimentSpecificAPCutoff
%TESTNOEXPERIMENTSPECIFICAPCUTOFF Guard against restoring the AP<=26 filter.
tests = functiontests(localfunctions);
end


function testNoAnalysisUsesJimAP26Cutoff(testCase)
projectFolder = fileparts(fileparts(mfilename('fullpath')));
folders = ["CurrentSpread", "PopulationAnalysis", "FullAnalysisPipeline"];
violations = strings(0, 1);
thisFile = string(mfilename('fullpath'));

for folderIndex = 1:numel(folders)
    files = dir(fullfile(projectFolder, folders(folderIndex), '**', '*.m'));
    for fileIndex = 1:numel(files)
        file = string(fullfile(files(fileIndex).folder, files(fileIndex).name));
        if file == thisFile
            continue
        end
        contents = fileread(file);
        hasAP26Comparison = ~isempty(regexp(contents, ...
            '(?i)(?:\bAP\b|MIDTable\.AP)[^\r\n]{0,80}(?:<=|<|>=|>)\s*26', ...
            'once'));
        hasReverseAP26Comparison = ~isempty(regexp(contents, ...
            '(?i)26\s*(?:<=|<|>=|>)[^\r\n]{0,80}(?:\bAP\b|MIDTable\.AP)', ...
            'once'));
        if hasAP26Comparison || hasReverseAP26Comparison
            violations(end + 1, 1) = file; %#ok<AGROW>
        end
    end
end

verifyEmpty(testCase, violations, sprintf( ...
    'Experiment-specific AP=26 cutoff remains in:\n%s', ...
    strjoin(violations, newline)));
end

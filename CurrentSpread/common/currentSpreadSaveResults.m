function currentSpreadSaveResults(outputDir)
%CURRENTSPREADSAVERESULTS Save open figures and non-input workspace results.

arguments
    outputDir (1, :) char
end

if ~isfolder(outputDir)
    mkdir(outputDir);
end

figures = findall(groot, 'Type', 'figure');
figures = flipud(figures(:));
figureFiles = strings(numel(figures), 2);

for idx = 1:numel(figures)
    fig = figures(idx);
    figName = string(get(fig, 'Name'));
    if strlength(strtrim(figName)) == 0
        figName = sprintf('figure_%02d', idx);
    end
    safeName = regexprep(char(figName), '[^A-Za-z0-9_-]+', '_');
    safeName = regexprep(safeName, '^_+|_+$', '');
    if isempty(safeName)
        safeName = sprintf('figure_%02d', idx);
    end
    safeName = sprintf('%02d_%s', idx, safeName);

    figPath = fullfile(outputDir, [safeName '.fig']);
    pngPath = fullfile(outputDir, [safeName '.png']);
    savefig(fig, figPath);
    try
        exportgraphics(fig, pngPath, 'Resolution', 300);
    catch
        print(fig, pngPath, '-dpng', '-r300');
    end
    figureFiles(idx, :) = [string(figPath), string(pngPath)];
end

workspaceInfo = evalin('caller', 'whos');
excluded = {'unit_table', 'Neuro', 'NeuroMean', 'paths', 'outputDir', ...
    'projectRoot', 'scriptFile'};
maxVariableBytes = 50 * 1024 * 1024;
keep = workspaceInfo(~ismember({workspaceInfo.name}, excluded) & ...
    [workspaceInfo.bytes] <= maxVariableBytes);

resultsFile = fullfile(outputDir, 'workspace_results.mat');
if isempty(keep)
    save(resultsFile, 'figureFiles');
else
    quotedNames = strcat("'", string({keep.name}), "'");
    saveCommand = sprintf("save('%s', %s);", ...
        strrep(resultsFile, "'", "''"), strjoin(quotedNames, ', '));
    evalin('caller', saveCommand);
end

runInfo = struct();
runInfo.completedAt = datetime('now', 'TimeZone', 'local');
runInfo.script = string(evalin('caller', 'mfilename(''fullpath'')'));
runInfo.outputDir = string(outputDir);
runInfo.figureFiles = figureFiles;
runInfo.savedVariables = string({keep.name});
save(fullfile(outputDir, 'run_info.mat'), 'runInfo');

fprintf('Saved %d figure(s) and workspace results to %s\n', ...
    numel(figures), outputDir);
end

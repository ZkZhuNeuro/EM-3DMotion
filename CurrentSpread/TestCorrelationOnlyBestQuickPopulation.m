function tests = TestCorrelationOnlyBestQuickPopulation
%TESTCORRELATIONONLYBESTQUICKPOPULATION Guard the active correlation workflow.
tests = functiontests(localfunctions);
end


function testActivePopulationRunnersDoNotInvokeSSE(testCase)
folder = fileparts(mfilename('fullpath'));
files = [ ...
    "RunPopulationAnalysis_BestQuickChannels.m", ...
    "RunPopulationAnalysis_BestQuickChannels_LSQOD.m", ...
    "AnalyzeBestQuickPopulationOutliers_LSQOD.m"];
for index = 1:numel(files)
    source = string(fileread(fullfile(folder, files(index))));
    verifyFalse(testCase, contains(source, ...
        "RankQuickChannelsByStimNoStimSSE"), files(index));
    verifyFalse(testCase, contains(source, "analysis.SSE"), files(index));
    verifyFalse(testCase, contains(source, 'fullfile(root, "SSE"'), ...
        files(index));
end
end

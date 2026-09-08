function tests = TestGaussianCorrelationODPredictorScatters
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
folder = fullfile(fileparts(mfilename('fullpath')), '02_gaussian', ...
    'interactive_population', 'channel_prediction');
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
end

function testExportsFourMatchedPanels(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
result = SaveGaussianCorrelationODPredictorScatters(problem(), OutputFolder=fixture.Folder);
verifyEqual(testCase, height(result.Summary), 4);
verifyEqual(testCase, height(result.Pairs), 40);
verifyEqual(testCase, result.Summary.NumOuterRepeats, repmat(10, 4, 1));
verifyEqual(testCase, result.Summary.PredictorMode, ...
    ["CombinedAI"; "DominantAIxOD"; "CombinedAI"; "DominantAIxOD"]);
verifyTrue(testCase, isfile(result.FigureFile));
f = openfig(fullfile(fixture.Folder, ...
    'CorrelationOD_OverallR2_BothPredictors_MT2D_FST3D.fig'), 'invisible');
cleanup = onCleanup(@() close(f));
points = findall(f, 'Type', 'scatter');
verifyEqual(testCase, numel(points), 4);
for k = 1:4
    verifyEqual(testCase, numel(points(k).XData), 10);
    verifySize(testCase, points(k).CData, [1 3]); % No performance gradient.
end
end

function testRejectsMaxODAndMixedCohorts(testCase)
data = problem();
data{1, 1}.ODDefinition = "Max";
verifyError(testCase, @() SaveGaussianCorrelationODPredictorScatters(data), ...
    'GaussianCorrelationScatter:InvalidAnalysis');
data = problem();
data{2, 2}.SourceRows(1) = 50;
verifyError(testCase, @() SaveGaussianCorrelationODPredictorScatters(data), ...
    'GaussianCorrelationScatter:UnmatchedModels');
end

function testRejectsUnmatchedFoldsAndRepositoryOutput(testCase)
data = problem();
data{1, 2}.Gaussian.Nested.InnerFoldAssignments(1) = 7;
verifyError(testCase, @() SaveGaussianCorrelationODPredictorScatters(data), ...
    'GaussianCorrelationScatter:UnmatchedModels');
data = problem();
repo = fileparts(mfilename('fullpath'));
verifyError(testCase, @() SaveGaussianCorrelationODPredictorScatters(data, OutputFolder=repo), ...
    'GaussianCorrelationScatter:RepositoryOutput');
end

function data = problem()
areas = ["MT", "FST"];
types = ["2D", "3D"];
modes = ["CombinedAI", "DominantAIxOD"];
data = cell(2, 2);
for a = 1:2
    for m = 1:2
        original = (1:10)' ./ 100 + 0.1*a;
        improved = original + 0.01*m + 0.003*sin((1:10)');
        repeats = table(repmat("Equal-cue aggregate", 10, 1), (1:10)', original, improved, ...
            'VariableNames', {'Condition', 'Repeat', 'StimOnlyCVR2', 'GaussianCVR2'});
        data{a, m} = struct('Area', areas(a), 'UnitType', types(a), ...
            'PredictorMode', modes(m), 'ODDefinition', "Correlation", ...
            'CohortDefinition', "SourceStimBothEyes_ChannelBothEyes_v1", ...
            'SessionCount', 12, 'SourceRows', (1:12)', ...
            'GaussianChannelMask', true(12, 3), ...
            'Robustness', struct('RepeatMetrics', repeats), ...
            'Significance', table(0.2, 'VariableNames', {'PImprovementOneSided'}), ...
            'Points', table((1:12)', ones(12, 1), ...
            'VariableNames', {'Observed', 'BehaviorSourceCueIndex'}), ...
            'Gaussian', struct('FoldAssignments', ones(12, 10), ...
            'SigmaValues', [0.01; 1; 100], ...
            'Nested', struct('InnerFoldAssignments', ones(12, 3, 10))));
    end
end
end

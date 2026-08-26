function tests = TestAdjacentChannelBiasModelComparison
%TESTADJACENTCHANNELBIASMODELCOMPARISON Synthetic regression tests.
tests = functiontests(localfunctions);
end


function testPhysicalNeighborsAndAddedPredictivePower(testCase)
unitTable = makeSyntheticUnitTable(48, false);
result = RunAdjacentChannelBiasModelComparison( ...
    UnitTable=unitTable, WriteOutputs=false, ...
    Areas="MT", UnitTypes="2D", Conditions="Dominant", ...
    NeighborRadius=1, NumRepeats=8, NumFolds=4, ...
    RandomSeed=17, MinimumGroupSize=12);

verifyEqual(testCase, height(result.GroupSummary), 1)
verifyEqual(testCase, result.GroupSummary.Status, "Success")
verifyGreaterThan(testCase, result.GroupSummary.AdjacentOrdinaryR2, ...
    result.GroupSummary.BaselineOrdinaryR2)
verifyGreaterThan(testCase, result.GroupSummary.MeanDeltaCVR2, 0.20)
verifyTrue(testCase, result.GroupSummary.ImprovesMeanCVR2)

observations = result.ObservationTable;
verifyEqual(testCase, unique(observations.Channel_m01), 3)
verifyEqual(testCase, unique(observations.Channel_zero), 1)
verifyEqual(testCase, unique(observations.Channel_p01), 15)

coefficients = result.CoefficientSummary( ...
    result.CoefficientSummary.Model == "Adjacent", :);
minusEstimate = coefficients.FullEstimate( ...
    coefficients.Predictor == "AI_m01");
stimEstimate = coefficients.FullEstimate( ...
    coefficients.Predictor == "AI_zero");
plusEstimate = coefficients.FullEstimate( ...
    coefficients.Predictor == "AI_p01");
verifyGreaterThan(testCase, minusEstimate, 0)
verifyGreaterThan(testCase, stimEstimate, 0)
verifyLessThan(testCase, plusEstimate, 0)
end


function testDeadNeighborIsAuditedAndExcluded(testCase)
unitTable = makeSyntheticUnitTable(12, true);
result = RunAdjacentChannelBiasModelComparison( ...
    UnitTable=unitTable, WriteOutputs=false, ...
    Areas="MT", UnitTypes="2D", Conditions="Dominant", ...
    NeighborRadius=1, NumRepeats=2, NumFolds=3, ...
    MinimumGroupSize=6);

observations = result.ObservationTable;
verifyTrue(testCase, all(isnan(observations.AI_m01)))
verifyEqual(testCase, unique(observations.Status_m01), "dead channel")
verifyEqual(testCase, result.GroupSummary.Status, ...
    "Too few complete cases (0; need at least 6)")
end


function testZeroODMatchesPopulationRightEyeOrdering(testCase)
unitTable = makeSyntheticUnitTable(1, false);
unitTable.OD_max{1} = 0;
unitTable.AI{1}(3, [3 1 15]) = [0.2 0.3 0.4];
deltaBias = [0 0 0.7 0];
validBiasFit = true(1, 4);
observations = BuildAdjacentChannelBiasObservations( ...
    unitTable, deltaBias, validBiasFit, Areas="MT", ...
    UnitTypes="2D", Conditions="Dominant", NeighborRadius=1);

verifyEqual(testCase, height(observations), 1)
verifyEqual(testCase, observations.SourceCueIndex, 3)
verifyEqual(testCase, observations.Bias, 0.7, 'AbsTol', 1e-12)
verifyEqual(testCase, observations.AI_zero, 0.3, 'AbsTol', 1e-12)
end


function testOutputInsideRepositoryIsRejected(testCase)
unitTable = makeSyntheticUnitTable(12, false);
insideRepository = fullfile(fileparts(mfilename('fullpath')), ...
    'should_not_be_created');
verifyError(testCase, @() RunAdjacentChannelBiasModelComparison( ...
    UnitTable=unitTable, WriteOutputs=true, ...
    OutputFolder=insideRepository, Areas="MT", UnitTypes="2D", ...
    Conditions="Dominant", NumRepeats=2, NumFolds=3, ...
    MinimumGroupSize=6), ...
    'AdjacentChannelModel:OutputInsideRepository')
verifyFalse(testCase, isfolder(insideRepository))
end


function testOutputWriterCreatesColumnManifest(testCase)
unitTable = makeSyntheticUnitTable(20, false);
outputFolder = string(tempname);
mkdir(outputFolder)
cleanup = onCleanup(@() rmdir(outputFolder, 's'));

result = RunAdjacentChannelBiasModelComparison( ...
    UnitTable=unitTable, WriteOutputs=true, OutputFolder=outputFolder, ...
    Areas="MT", UnitTypes="2D", Conditions="Dominant", ...
    NeighborRadius=1, NumRepeats=3, NumFolds=4, ...
    RandomSeed=8, MinimumGroupSize=8);

verifySize(testCase, result.OutputFiles, [11 1])
verifyTrue(testCase, all(isfile(result.OutputFiles)))
saved = load(fullfile(outputFolder, ...
    'AdjacentChannelBiasModelComparisonResults.mat'), 'result');
verifyEqual(testCase, saved.result.OutputFiles, result.OutputFiles)
end


function unitTable = makeSyntheticUnitTable(rowCount, deadMinusNeighbor)
stream = RandStream('mt19937ar', 'Seed', 91);
channelMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10];
stimChannel = 1;
stimPosition = find(channelMap == stimChannel, 1);
minusChannel = channelMap(stimPosition - 1);
plusChannel = channelMap(stimPosition + 1);

Date = datetime(2024, 1, 1) + days((0:rowCount-1)');
ROI = repmat({'MT'}, rowCount, 1);
Monkey = repmat({'Jim'}, rowCount, 1);
NChannels = repmat(16, rowCount, 1);
StimElec = stimChannel .* ones(rowCount, 1);
DeadChannel = repmat({zeros(1, 0)}, rowCount, 1);
if deadMinusNeighbor
    DeadChannel(:) = {minusChannel};
end
p_AI = repmat({[0.2 0.01 0.01 0.2]}, rowCount, 1);
OD_max = repmat({0.6}, rowCount, 1);
Z3D_v_Z2D = repmat({-1.2}, rowCount, 1);
OriginalRecIdx = (1:rowCount)';

AI = cell(rowCount, 1);
Behav_b0 = repmat({zeros(1, 4)}, rowCount, 1);
Behav_b1 = repmat({ones(1, 4)}, rowCount, 1);
Behav_b2 = repmat({zeros(1, 4)}, rowCount, 1);
Behav_b3 = repmat({zeros(1, 4)}, rowCount, 1);
Behav_delta_bias_sigmoid = cell(rowCount, 1);

xMinus = -1 + 2 .* rand(stream, rowCount, 1);
xStim = -1 + 2 .* rand(stream, rowCount, 1);
xPlus = -1 + 2 .* rand(stream, rowCount, 1);
noise = 0.02 .* randn(stream, rowCount, 1);
y = 0.15 + 0.55 .* xMinus + 0.80 .* xStim - ...
    0.45 .* xPlus + noise;

for row = 1:rowCount
    values = zeros(4, 16);
    values(2, minusChannel) = xMinus(row);
    values(2, stimChannel) = xStim(row);
    values(2, plusChannel) = xPlus(row);
    AI{row} = values;
    Behav_delta_bias_sigmoid{row} = [0 y(row) 0 0];
end

unitTable = table(Date, ROI, Monkey, NChannels, StimElec, DeadChannel, ...
    p_AI, AI, OD_max, Z3D_v_Z2D, OriginalRecIdx, ...
    Behav_b0, Behav_b1, Behav_b2, Behav_b3, ...
    Behav_delta_bias_sigmoid);
end

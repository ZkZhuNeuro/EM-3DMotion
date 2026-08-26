function tests = TestCrossValidateTuningBehaviorModel
tests = functiontests(localfunctions);
end


function testTwoDModelPredictsHeldOutSessions(testCase)
biasTable = makeTwoDBiasTable(24);
result = CrossValidateTuningBehaviorModel( ...
    biasTable, "2D", NumRepeats=5, NumFolds=4, RandomSeed=3);

verifyEqual(testCase, result.Status, "Success");
verifyEqual(testCase, result.SessionCount, 24);
verifyEqual(testCase, result.ObservationCount, 48);
verifyGreaterThan(testCase, result.MeanR2, 0.95);
verifyLessThan(testCase, result.MeanRMSE, 0.05);
verifySize(testCase, result.MeanHeldOutPrediction, [48 1]);
end


function testThreeDCueModelsKeepSessionsGrouped(testCase)
biasTable = makeThreeDBiasTable(20);
result = CrossValidateTuningBehaviorModel( ...
    biasTable, "3D", NumRepeats=4, NumFolds=5, RandomSeed=7);

verifyEqual(testCase, result.Status, "Success");
verifyEqual(testCase, result.SessionCount, 20);
verifyEqual(testCase, result.ObservationCount, 80);
verifyGreaterThan(testCase, result.MeanR2, 0.95);
for repeat = 1:result.NumRepeats
    verifyEqual(testCase, numel(unique(result.FoldBySession(:, repeat))), 5);
end
end


function testTooFewSessionsReturnsInsufficient(testCase)
biasTable = makeThreeDBiasTable(3);
result = CrossValidateTuningBehaviorModel(biasTable, "3D");

verifyEqual(testCase, result.Status, "InsufficientSessions");
verifyTrue(testCase, isnan(result.MeanR2));
end


function output = makeTwoDBiasTable(sessionCount)
source = (1:sessionCount)';
aiDominant = linspace(-0.9, 0.9, sessionCount)';
aiNonDominant = flipud(aiDominant) .* 0.8;
od = 0.2 + 0.7 .* mod(source, 5) ./ 4;
mergedDominant = 0.1 + 0.7 .* aiDominant + ...
    0.9 .* aiDominant .* od;
mergedNonDominant = 0.1 + 0.7 .* aiNonDominant + ...
    0.9 .* aiNonDominant .* od;
AI = [aiDominant; aiNonDominant];
OD = [od; od];
Condition = [ones(sessionCount, 1); 4 .* ones(sessionCount, 1)];
SourceTableRow = [source; source];
MergedEyeBias = [mergedDominant; mergedNonDominant];
Bias = MergedEyeBias;
Bias(Condition == 4) = -Bias(Condition == 4);
UnitType = categorical(repmat("2D", 2 .* sessionCount, 1));
Monkey = repmat("Jim", 2 .* sessionCount, 1);
output = table(AI, Bias, OD, Condition, UnitType, SourceTableRow, ...
    Monkey, MergedEyeBias);
end


function output = makeThreeDBiasTable(sessionCount)
SourceTableRow = repelem((1:sessionCount)', 4);
Condition = repmat((1:4)', sessionCount, 1);
AI = linspace(-0.95, 0.95, sessionCount .* 4)';
cueIntercept = [-0.2 0.1 0.3 -0.1];
cueSlope = [0.4 0.7 -0.5 0.9];
Bias = nan(size(AI));
for cue = 1:4
    selected = Condition == cue;
    Bias(selected) = cueIntercept(cue) + cueSlope(cue) .* AI(selected);
end
OD = 0.6 .* ones(size(AI));
UnitType = categorical(repmat("3D", numel(AI), 1));
Monkey = repmat("Clay", numel(AI), 1);
MergedEyeBias = Bias;
output = table(AI, Bias, OD, Condition, UnitType, SourceTableRow, ...
    Monkey, MergedEyeBias);
end

function tests = TestBuildPopulationModelSummaryByUnitType
tests = functiontests(localfunctions);
end


function testModelScopeMatchesUnitTypeSpecification(testCase)
biasTable = makeBiasTable();
[perCue, merged2D, allModels] = ...
    BuildPopulationModelSummaryByUnitType(biasTable, "FST", "Both");

verifyEqual(testCase, height(perCue), 8);
verifyEqual(testCase, sum(perCue.UnitType == "2D"), 4);
verifyEqual(testCase, sum(perCue.UnitType == "3D"), 4);
verifyTrue(testCase, all(perCue.Formula == "DeltaBias ~ AI"));
verifyTrue(testCase, all(isnan(perCue.P_AIxOD)));
verifyEqual(testCase, height(merged2D), 1);
verifyEqual(testCase, merged2D.UnitType, "2D");
verifyEqual(testCase, merged2D.Formula, ...
    "MergedEyeDeltaBias ~ AI + AI:OD");
verifyEqual(testCase, height(allModels), 9);
verifyFalse(testCase, any(allModels.UnitType == "3D" & ...
    contains(allModels.ModelScope, "Merged")));
end


function biasTable = makeBiasTable()
AI = [];
OD = [];
Bias = [];
MergedEyeBias = [];
Condition = [];
UnitType = strings(0, 1);
UnitIndex = [];
writeIndex = 0;
for type = ["2D", "3D"]
    for condition = 1:4
        for point = 1:4
            writeIndex = writeIndex + 1;
            AI(writeIndex, 1) = -0.75 + 0.5 .* (point - 1); %#ok<AGROW>
            OD(writeIndex, 1) = 0.03 .* point + 0.01 .* condition; %#ok<AGROW>
            Bias(writeIndex, 1) = ... %#ok<AGROW>
                0.2 .* condition + 0.6 .* AI(writeIndex);
            MergedEyeBias(writeIndex, 1) = Bias(writeIndex); %#ok<AGROW>
            if condition == 4
                MergedEyeBias(writeIndex, 1) = -Bias(writeIndex);
            end
            Condition(writeIndex, 1) = condition; %#ok<AGROW>
            UnitType(writeIndex, 1) = type;
            UnitIndex(writeIndex, 1) = writeIndex; %#ok<AGROW>
        end
    end
end
biasTable = table(AI, OD, Bias, MergedEyeBias, Condition, ...
    UnitType, UnitIndex);
end

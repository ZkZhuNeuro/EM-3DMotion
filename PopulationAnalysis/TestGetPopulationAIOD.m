function tests = TestGetPopulationAIOD
%TESTGETPOPULATIONAIOD Source-selection regression tests.
tests = functiontests(localfunctions);
end


function testSelectsOppositeQuickAndStimValues(testCase)
StimElec = 2;
AI = {[1, 11; 2, 12; 3, 13; 4, 14]};
OD_max = {-0.75};
stim_noStim_AI = {[-1; -2; -3; -4]};
stim_noStim_OD_max = 0.6;
unitTable = table(StimElec, AI, OD_max, ...
    stim_noStim_AI, stim_noStim_OD_max);

[quickAI, quickOD] = GetPopulationAIOD(unitTable, 1, 'Quick');
[stimAI, stimOD] = GetPopulationAIOD(unitTable, 1, 'StimNoStim');

verifyEqual(testCase, quickAI, [11; 12; 13; 14]);
verifyEqual(testCase, quickOD, -0.75);
verifyEqual(testCase, stimAI, [-1; -2; -3; -4]);
verifyEqual(testCase, stimOD, 0.6);
verifyNotEqual(testCase, quickAI, stimAI);
verifyNotEqual(testCase, quickOD, stimOD);
end


function testUsesRequestedTableRow(testCase)
StimElec = [1; 2];
AI = {[1; 2; 3; 4]; [10, 20; 30, 40; 50, 60; 70, 80]};
OD_max = {0.1; -0.2};
stim_noStim_AI = {[-1; -2; -3; -4]; [-10; -20; -30; -40]};
stim_noStim_OD_max = [0.3; -0.4];
unitTable = table(StimElec, AI, OD_max, ...
    stim_noStim_AI, stim_noStim_OD_max);

[quickAI, quickOD] = GetPopulationAIOD(unitTable, 2, 'Quick');
[stimAI, stimOD] = GetPopulationAIOD(unitTable, 2, 'StimNoStim');

verifyEqual(testCase, quickAI, [20; 40; 60; 80]);
verifyEqual(testCase, quickOD, -0.2);
verifyEqual(testCase, stimAI, [-10; -20; -30; -40]);
verifyEqual(testCase, stimOD, -0.4);
end

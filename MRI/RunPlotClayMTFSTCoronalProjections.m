xlsTables = {
    'P:\Clay\NeuroData\RecordingRecord.xlsx'
    'P:\Clay\NeuroData\RecordingRecord_Stimulation.xlsx'
    };
outputDir = 'C:\EM\MRI\ClayMTFSTCoronalProjections';
guideDepth = 10;
maxDepth = 35;

summary = PlotClayMTFSTCoronalProjections(outputDir, guideDepth, maxDepth, xlsTables);
disp(summary);

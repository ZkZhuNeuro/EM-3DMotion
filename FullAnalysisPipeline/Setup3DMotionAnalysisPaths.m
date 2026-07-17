function Setup3DMotionAnalysisPaths()
% Add external dependencies used by the stimulation MID analysis.

offlineRootDir = 'P:\Codes\Matlab\offlineAnalysis';
rootDir = fullfile(offlineRootDir, '3DMotionAnalysis');
psignifitDir = fullfile(rootDir, 'psignifit-master', 'psignifit-master');
subtightplotDir = 'P:\Codes\Matlab\online_Analysis\Stimulation\subtightplot';

if isfolder(offlineRootDir)
    addpath(offlineRootDir);
end

if isfolder(rootDir)
    addpath(rootDir);
end

if isfolder(psignifitDir)
    addpath(psignifitDir);
end

if isfolder(subtightplotDir)
    addpath(subtightplotDir);
end
end

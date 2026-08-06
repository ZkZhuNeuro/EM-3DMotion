%% Microsaccade-behavior models separated by ROI and monkey
rootDir = 'C:\EM\Microsac';

subgroups = {
    "ROI",    "MT",   fullfile(rootDir, 'ms_behavior_bias_by_roi', 'MT');
    "ROI",    "FST",  fullfile(rootDir, 'ms_behavior_bias_by_roi', 'FST');
    "Monkey", "Jim",  fullfile(rootDir, 'ms_behavior_bias_by_monkey', 'Jim');
    "Monkey", "Clay", fullfile(rootDir, 'ms_behavior_bias_by_monkey', 'Clay')};

SubgroupAnalyses = cell(size(subgroups, 1), 1);
for iGroup = 1:size(subgroups, 1)
    groupType = subgroups{iGroup, 1};
    groupValue = subgroups{iGroup, 2};
    outputDir = subgroups{iGroup, 3};
    fprintf('\n=== Running %s = %s ===\n', groupType, groupValue);
    if groupType == "ROI"
        SubgroupAnalyses{iGroup} = analyze_ms_behavior_bias( ...
            'FilterROI', groupValue, 'OutputDir', outputDir);
    else
        SubgroupAnalyses{iGroup} = analyze_ms_behavior_bias( ...
            'FilterMonkey', groupValue, 'OutputDir', outputDir);
    end
end

save(fullfile(rootDir, 'ms_behavior_bias_subgroup_results.mat'), ...
    'SubgroupAnalyses', 'subgroups', '-v7.3');

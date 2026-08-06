%% Microsaccade-behavior models for each monkey-by-ROI subgroup
rootDir = 'C:\EM\Microsac\ms_behavior_bias_by_monkey_roi';

subgroups = {
    "Jim",  "MT";
    "Jim",  "FST";
    "Clay", "MT";
    "Clay", "FST"};

MonkeyROIAnalyses = cell(size(subgroups, 1), 1);
for iGroup = 1:size(subgroups, 1)
    monkey = subgroups{iGroup, 1};
    roi = subgroups{iGroup, 2};
    outputDir = fullfile(rootDir, monkey + "_" + roi);
    fprintf('\n=== Running Monkey = %s, ROI = %s ===\n', monkey, roi);
    MonkeyROIAnalyses{iGroup} = analyze_ms_behavior_bias( ...
        'FilterMonkey', monkey, 'FilterROI', roi, ...
        'OutputDir', outputDir);
end

CombinedModelSummaryTable = table;
CombinedCoefficientTable = table;
for iGroup = 1:size(subgroups, 1)
    monkey = subgroups{iGroup, 1};
    roi = subgroups{iGroup, 2};
    groupName = monkey + "_" + roi;
    summary = MonkeyROIAnalyses{iGroup}.ModelSummaryTable;
    summary = addvars(summary, repmat(groupName, height(summary), 1), ...
        repmat(monkey, height(summary), 1), repmat(roi, height(summary), 1), ...
        'Before', 1, 'NewVariableNames', {'Subpopulation', 'Monkey', 'ROI'});
    coefficients = MonkeyROIAnalyses{iGroup}.CoefficientTable;
    coefficients = addvars(coefficients, ...
        repmat(groupName, height(coefficients), 1), ...
        repmat(monkey, height(coefficients), 1), ...
        repmat(roi, height(coefficients), 1), ...
        'Before', 1, 'NewVariableNames', {'Subpopulation', 'Monkey', 'ROI'});
    CombinedModelSummaryTable = [CombinedModelSummaryTable; summary]; %#ok<AGROW>
    CombinedCoefficientTable = [CombinedCoefficientTable; coefficients]; %#ok<AGROW>
end
writetable(CombinedModelSummaryTable, fullfile(rootDir, ...
    'ms_behavior_bias_monkey_roi_model_summary.csv'));
writetable(CombinedCoefficientTable, fullfile(rootDir, ...
    'ms_behavior_bias_monkey_roi_coefficients.csv'));
save(fullfile(rootDir, 'ms_behavior_bias_monkey_roi_results.mat'), ...
    'MonkeyROIAnalyses', 'subgroups', 'CombinedModelSummaryTable', ...
    'CombinedCoefficientTable', '-v7.3');

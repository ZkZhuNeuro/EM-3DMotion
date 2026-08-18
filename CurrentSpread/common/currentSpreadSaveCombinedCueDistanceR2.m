function figureHandle = currentSpreadSaveCombinedCueDistanceR2(result, outputDir)
%CURRENTSPREADSAVECOMBINEDCUEDISTANCER2 Save the standardized CV-R2 result.

arguments
    result (1, 1) struct
    outputDir (1, :) char
end

if ~isfolder(outputDir)
    mkdir(outputDir);
end

figureHandle = figure('Color', 'w', ...
    'Name', 'combined_cue_channels_vs_cv_r2');
hold on
x = result.channelsIncluded;
y = result.meanR2;
sem = result.semR2;
fill([x; flipud(x)], [y-sem; flipud(y+sem)], [0.25 0.55 0.85], ...
    'FaceAlpha', 0.20, 'EdgeColor', 'none');
plot(x, y, 'o-', 'Color', [0.05 0.35 0.70], ...
    'MarkerFaceColor', [0.05 0.35 0.70], ...
    'LineWidth', 2, 'MarkerSize', 6);
yline(0, '--', 'Color', [0.35 0.35 0.35]);
grid on
box off
xticks(x)
xlabel('Centered channels included')
ylabel('Cross-validated R^2')
title(result.methodLabel, 'Interpreter', 'none')
subtitle(sprintf(['Jim MT 2D, Behav_bias_NminusS (N = %d); ' ...
    '%d x %d-fold CV'], result.sessionCount, result.numRepeats, result.numFolds), ...
    'Interpreter', 'none')

baseName = 'combined_cue_channels_vs_cv_r2';
savefig(figureHandle, fullfile(outputDir, [baseName '.fig']));
exportgraphics(figureHandle, fullfile(outputDir, [baseName '.png']), ...
    'Resolution', 300);
writetable(result.table, fullfile(outputDir, [baseName '.csv']));
save(fullfile(outputDir, [baseName '.mat']), 'result');
end

function figureHandles = currentSpreadSaveCombinedCueGaussianSigmaR2(result, outputDir)
%CURRENTSPREADSAVECOMBINEDCUEGAUSSIANSIGMAR2 Save CV-R2 and weight plots.

arguments
    result (1, 1) struct
    outputDir (1, :) char
end

if ~isfolder(outputDir)
    mkdir(outputDir);
end

blue = [0.05 0.35 0.70];
lightBlue = [0.25 0.55 0.85];

r2Figure = figure('Color', 'w', 'Name', 'combined_cue_sigma_vs_cv_r2');
hold on
x = result.sigmaValues;
y = result.meanR2;
sem = result.semR2;
fill([x; flipud(x)], [y-sem; flipud(y+sem)], lightBlue, ...
    'FaceAlpha', 0.20, 'EdgeColor', 'none');
plot(x, y, 'o-', 'Color', blue, 'MarkerFaceColor', blue, ...
    'LineWidth', 2, 'MarkerSize', 5);
if isfinite(result.bestIndex)
    plot(result.bestSigma, result.bestMeanR2, 'o', ...
        'MarkerSize', 10, 'MarkerFaceColor', [1 1 1], ...
        'MarkerEdgeColor', blue, 'LineWidth', 2);
end
yline(0, '--', 'Color', [0.35 0.35 0.35]);
set(gca, 'XScale', 'log')
grid on
box off
xlabel('Gaussian \sigma (channel positions)')
ylabel('Cross-validated R^2')
title(result.methodLabel, 'Interpreter', 'none')
subtitle(sprintf(['Jim MT 2D, Behav_bias_NminusS (N = %d); ' ...
    '%d x %d-fold CV; best sigma = %.3g'], result.sessionCount, ...
    result.numRepeats, result.numFolds, result.bestSigma), ...
    'Interpreter', 'none')

r2BaseName = 'combined_cue_sigma_vs_cv_r2';
savefig(r2Figure, fullfile(outputDir, [r2BaseName '.fig']));
exportgraphics(r2Figure, fullfile(outputDir, [r2BaseName '.png']), ...
    'Resolution', 300);
writetable(result.table, fullfile(outputDir, [r2BaseName '.csv']));
save(fullfile(outputDir, [r2BaseName '.mat']), 'result');

weightFigure = figure('Color', 'w', 'Name', 'combined_cue_best_sigma_weights');
plot(result.positionOffset, result.bestWeights, 'o-', 'Color', blue, ...
    'MarkerFaceColor', blue, 'LineWidth', 2, 'MarkerSize', 6);
grid on
box off
xticks(result.positionOffset)
xlabel('Channel position relative to stimulation electrode')
ylabel('Normalized Gaussian weight')
title(sprintf('Best Gaussian profile: sigma = %.3g', result.bestSigma))
methodLabelText = strjoin(string(result.methodLabel), "");
subtitle(sprintf('%s; mean CV R^2 = %.3f', ...
    char(methodLabelText), result.bestMeanR2), 'Interpreter', 'none')

weightBaseName = 'combined_cue_best_sigma_weights';
savefig(weightFigure, fullfile(outputDir, [weightBaseName '.fig']));
exportgraphics(weightFigure, fullfile(outputDir, [weightBaseName '.png']), ...
    'Resolution', 300);
writetable(result.bestWeightTable, ...
    fullfile(outputDir, [weightBaseName '.csv']));

figureHandles = [r2Figure; weightFigure];
end

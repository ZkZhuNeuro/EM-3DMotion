load("P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\LoRFs\LoRFTable.mat")
load("P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\LoRFs\LoRFData.mat")

%%
figure(); 
subplot(1, 2, 1)
AP = [];
Ecc = [];
for i_neuron = 1:size(AllRFTable, 1)
    if strcmp(AllRFTable.ROI{i_neuron}, 'FST') && startsWith(AllRFTable.Names{i_neuron}, 'J')
        AP  = [AP;  AllRFTable.Hole(i_neuron, 2)];
        Ecc = [Ecc; sqrt(AllRFData.Center(i_neuron, :) * AllRFData.Center(i_neuron, :)')];
    end
end

AP_unique = unique(AP);

hold on;

violin_width = 0.35;
point_jitter = 0.08;

Ecc_mean = nan(size(AP_unique));
Ecc_std  = nan(size(AP_unique));

for i = 1:length(AP_unique)
    idx = AP == AP_unique(i);
    y = Ecc(idx);
    x0 = i;

    % mean and std
    Ecc_mean(i) = mean(y, 'omitnan');
    Ecc_std(i)  = std(y, 'omitnan');

    % violin from kernel density
    if numel(y) > 1 && std(y) > 0
        [f, yi] = ksdensity(y);
        f = f / max(f) * violin_width;
        patch([x0 + f, fliplr(x0 - f)], ...
              [yi,     fliplr(yi)], ...
              [0.7 0.7 0.7], ...
              'EdgeColor', 'none', ...
              'FaceAlpha', 0.5);
    end

    % raw points
    x_scatter = x0 + (rand(size(y)) - 0.5) * 2 * point_jitter;
    scatter(x_scatter, y, 20, 'k', 'filled', ...
        'MarkerFaceAlpha', 0.35, 'MarkerEdgeAlpha', 0.35);
end

% mean ± std
errorbar(1:length(AP_unique), Ecc_mean, Ecc_std, 'r.', ...
    'LineWidth', 1.5, 'MarkerSize', 22, 'CapSize', 8);

set(gca, 'XTick', 1:length(AP_unique), 'XTickLabel', string(AP_unique));
xlabel('AP');
ylabel('Eccentricity');
title('Eccentricity as a function of AP in Jim');
box off;
hold off;

%%
AP = [];
Ecc = [];
for i_neuron = 1:size(AllRFTable, 1)
    if strcmp(AllRFTable.ROI{i_neuron}, 'FST') && startsWith(AllRFTable.Names{i_neuron}, 'C')
        AP  = [AP;  AllRFTable.Hole(i_neuron, 2)];
        Ecc = [Ecc; sqrt(AllRFData.Center(i_neuron, :) * AllRFData.Center(i_neuron, :)')];
    end
end

AP_unique = unique(AP);

subplot(1, 2, 2)
hold on;

violin_width = 0.35;
point_jitter = 0.08;

Ecc_mean = nan(size(AP_unique));
Ecc_std  = nan(size(AP_unique));

for i = 1:length(AP_unique)
    idx = AP == AP_unique(i);
    y = Ecc(idx);
    x0 = i;

    % mean and std
    Ecc_mean(i) = mean(y, 'omitnan');
    Ecc_std(i)  = std(y, 'omitnan');

    % violin from kernel density
    if numel(y) > 1 && std(y) > 0
        [f, yi] = ksdensity(y);
        f = f / max(f) * violin_width;
        patch([x0 + f, fliplr(x0 - f)], ...
              [yi,     fliplr(yi)], ...
              [0.7 0.7 0.7], ...
              'EdgeColor', 'none', ...
              'FaceAlpha', 0.5);
    end

    % raw points
    x_scatter = x0 + (rand(size(y)) - 0.5) * 2 * point_jitter;
    scatter(x_scatter, y, 20, 'k', 'filled', ...
        'MarkerFaceAlpha', 0.35, 'MarkerEdgeAlpha', 0.35);
end

% mean ± std
errorbar(1:length(AP_unique), Ecc_mean, Ecc_std, 'r.', ...
    'LineWidth', 1.5, 'MarkerSize', 22, 'CapSize', 8);

set(gca, 'XTick', 1:length(AP_unique), 'XTickLabel', string(AP_unique));
xlabel('AP');
ylabel('Eccentricity');
title('Eccentricity as a function of AP in Clay');
box off;
hold off;
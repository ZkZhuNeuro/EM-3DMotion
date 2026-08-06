function fig = plot_fisher_2donly_results(analysisResults,cfg,analysisName)
%PLOT_FISHER_2DONLY_RESULTS Focused MT/FST plot for the 2D-only population.

if isempty(cfg.signedCoherence)
    magnitudes = 1:6;
    xLabelText = 'Absolute coherence level';
else
    magnitudes = sort(unique(abs(cfg.signedCoherence)));
    magnitudes = magnitudes(magnitudes>0);
    xLabelText = 'Motion coherence';
end

colorsteps = [254 191 15; 0 0 0; 234 0 233; 110 205 221]./255;
colors = colorsteps([2 1 4 3],:); % Combined, dominant, non-dominant, stereo
fig = figure('Color','w','Name',['2D-only Fisher decoder - ' analysisName], ...
    'Position',[100 100 1300 540]);
tiledlayout(1,numel(cfg.areas),'TileSpacing','compact','Padding','compact');

for areaIndex = 1:numel(cfg.areas)
    area = cfg.areas{areaIndex};
    decoder = analysisResults.(area).D2Only;
    nexttile;
    hold on;
    for condition = 1:numel(cfg.testConditions)
        y = decoder.meanByMagnitude(condition,:);
        ci = squeeze(decoder.ci95ByMagnitude(condition,:,:));
        errorbar(magnitudes,y,y-ci(:,1)',ci(:,2)'-y,'-o', ...
            'Color',colors(condition,:),'LineWidth',1.4, ...
            'MarkerFaceColor',colors(condition,:));
    end
    yline(0.5,'--k');
    ylim([0 1]);
    yticks(0:0.25:1);
    axis square;
    grid on;
    xlabel(xLabelText);
    ylabel('Proportion correct');
    title(sprintf('%s 2D-only (N = %d)',area,decoder.nNeurons));
    if areaIndex == 1
        legend(cfg.conditionNames,'Location','best','Box','off');
    end
end
sgtitle(sprintf('%s: neurons without combined-cue tuning',analysisName));
end


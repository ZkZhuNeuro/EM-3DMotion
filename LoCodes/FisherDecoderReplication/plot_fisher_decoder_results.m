function fig = plot_fisher_decoder_results(analysisResults,cfg,analysisName)
%PLOT_FISHER_DECODER_RESULTS Recreate the four Figure 5-style panels.

if isempty(cfg.signedCoherence)
    magnitudes = 1:6;
    xLabelText = 'Absolute coherence level';
else
    magnitudes = unique(abs(cfg.signedCoherence));
    magnitudes = sort(magnitudes(magnitudes>0));
    xLabelText = 'Motion coherence';
end

% Requested colorsteps are ordered Dominant, Combined, Stereoscopic,
% Non-dominant. Map them to cfg.testConditions, whose order is Combined,
% Dominant, Non-dominant, Stereoscopic.
colorsteps = [254 191 15; 0 0 0; 234 0 233; 110 205 221]./255;
colors = colorsteps([2 1 4 3],:);
fig = figure('Color','w','Name',['Fisher decoder - ' analysisName], ...
    'Position',[50 50 620*numel(cfg.motionClasses) 450*numel(cfg.areas)]);
tiledlayout(numel(cfg.areas),numel(cfg.motionClasses), ...
    'TileSpacing','compact','Padding','compact');

for areaIndex = 1:numel(cfg.areas)
        area = cfg.areas{areaIndex};
    for classIndex = 1:numel(cfg.motionClasses)
        className = cfg.motionClasses(classIndex).name;
        classField = cfg.motionClasses(classIndex).field;
        decoder = analysisResults.(area).(classField);
        legacyDescendingOrder = ~isfield(decoder,'magnitudeOrder') || ...
            ~strcmp(decoder.magnitudeOrder,'ascending');
        nexttile;
        hold on;
        for condition = 1:numel(cfg.testConditions)
            y = decoder.meanByMagnitude(condition,:);
            ci = squeeze(decoder.ci95ByMagnitude(condition,:,:));
            if legacyDescendingOrder
                y = fliplr(y);
                ci = flipud(ci);
            end
            errorbar(magnitudes,y,y-ci(:,1)',ci(:,2)'-y,'-o', ...
                'Color',colors(condition,:),'LineWidth',1.2, ...
                'MarkerFaceColor',colors(condition,:));
        end
        yline(0.5,'--k');
        ylim([0 1]);
        yticks(0:0.25:1);
        axis square;
        grid on;
        xlabel(xLabelText);
        ylabel('Proportion correct');
        title(sprintf('%s %s-selective (N = %d)',area,className,decoder.nNeurons));
        if areaIndex==1 && classIndex==1
            legend(cfg.conditionNames,'Location','best','Box','off');
        end
    end
end
sgtitle(sprintf('%s: combined-cue-trained Fisher decoder',analysisName));
end

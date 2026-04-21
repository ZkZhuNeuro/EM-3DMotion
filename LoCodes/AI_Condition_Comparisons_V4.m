%% AI Condition Comparisons
% with Type II regression fits for each quadrant
set(0, 'DefaultFigureRenderer', 'painters');

% Reassignment
for u = 1:size(MIDTable,1)
    if MIDTable.Monocularity_Distance(u) > 0 % right eye dominant
       MIDTable.Dominant_AI_Persp_Weighted(u) = MIDTable.MonoR_AI(u);
       MIDTable.Non_Dominant_AI_Persp_Weighted(u) = MIDTable.MonoL_AI(u);
    else
       MIDTable.Dominant_AI_Persp_Weighted(u) = MIDTable.MonoL_AI(u);
       MIDTable.Non_Dominant_AI_Persp_Weighted(u) = MIDTable.MonoR_AI(u);
    end
end

%% Set up the plots
figure; hold on;
% 2D Row
subplot(2,4,1); hold on; title('Dominant MT');
xlim([-1,1]); ylim([-1,1]);
axis square; box on;
plot([-1,1],[0,0],'--k'); plot([0,0],[-1,1],'--k');
xlabel('Dominant AI'); ylabel('Binocular AI');

subplot(2,4,2); hold on; title('Dominant FST');
xlim([-1,1]);ylim([-1,1]);
axis square; box on;
plot([-1,1],[0,0],'--k'); plot([0,0],[-1,1],'--k');
xlabel('Dominant AI'); ylabel('Binocular AI');

subplot(2,4,3); hold on; title('Non-Dominant MT');
xlim([-1,1]); ylim([-1,1]);
axis square; box on;
plot([-1,1],[0,0],'--k'); plot([0,0],[-1,1],'--k');
xlabel('Non-Dominant AI'); ylabel('Binocular AI');

subplot(2,4,4); hold on; title('Non-Dominant FST');
xlim([-1,1]);ylim([-1,1]);
axis square; box on;
plot([-1,1],[0,0],'--k'); plot([0,0],[-1,1],'--k');
xlabel('Non-Dominant AI'); ylabel('Binocular AI');

% 3D Row
subplot(2,4,5); hold on; title('Dominant MT');
xlim([-1,1]); ylim([-1,1]);
axis square; box on;
plot([-1,1],[0,0],'--k'); plot([0,0],[-1,1],'--k');
xlabel('Dominant AI'); ylabel('Binocular AI');

subplot(2,4,6); hold on; title('Dominant FST');
xlim([-1,1]);ylim([-1,1]);
axis square; box on;
plot([-1,1],[0,0],'--k'); plot([0,0],[-1,1],'--k');
xlabel('Dominant AI'); ylabel('Binocular AI');

subplot(2,4,7); hold on; title('Non-Dominant MT');
xlim([-1,1]); ylim([-1,1]);
axis square; box on;
plot([-1,1],[0,0],'--k'); plot([0,0],[-1,1],'--k');
xlabel('Non-Dominant AI'); ylabel('Binocular AI');

subplot(2,4,8); hold on; title('Non-Dominant FST');
xlim([-1,1]);ylim([-1,1]);
axis square; box on;
plot([-1,1],[0,0],'--k'); plot([0,0],[-1,1],'--k');
xlabel('Non-Dominant AI'); ylabel('Binocular AI');

%% Loop plotting
for ith_unit = 1:size(MIDTable,1)
    % Identify the quadrant
    if MIDTable.Z_quad(ith_unit) == 4 % 2D
        q_ind = 0;
    elseif MIDTable.Z_quad(ith_unit) == 2 % 3D
        q_ind = 4;
    else
        continue
    end
    
    % Check if it meets your critera for combined-cue
    criteria = MIDTable.sig_Anova_CLR; % Combined cue
    if criteria(ith_unit)
        if strcmp(MIDTable.ROI(ith_unit),'MT') % First and 3
            subplot(2,4,q_ind+1); hold on;
            s = scatter(MIDTable.Dominant_AI_Persp_Weighted(ith_unit), MIDTable.Combined_AI(ith_unit),...
                50, plotOptions.Conditions.Combined, 'filled','MarkerEdgeColor',plotOptions.Conditions.Combined);
            s.MarkerFaceAlpha = abs(MIDTable.Monocularity_Distance(ith_unit))/max(abs(MIDTable.Monocularity_Distance(criteria & strcmp(MIDTable.ROI,'MT'))));
            s.MarkerEdgeAlpha = 1;
            
            subplot(2,4,q_ind+3); hold on;
            s = scatter(MIDTable.Non_Dominant_AI_Persp_Weighted(ith_unit), MIDTable.Combined_AI(ith_unit),...
                50, plotOptions.Conditions.Combined, 'filled','MarkerEdgeColor',plotOptions.Conditions.Combined);
            s.MarkerFaceAlpha = abs(MIDTable.Monocularity_Distance(ith_unit))/max(abs(MIDTable.Monocularity_Distance(criteria & strcmp(MIDTable.ROI,'MT'))));
            s.MarkerEdgeAlpha = 1;
        else
            subplot(2,4,q_ind+2); hold on;
            s = scatter(MIDTable.Dominant_AI_Persp_Weighted(ith_unit), MIDTable.Combined_AI(ith_unit),...
                50, plotOptions.Conditions.Combined, 'filled','MarkerEdgeColor',plotOptions.Conditions.Combined);
            s.MarkerFaceAlpha = abs(MIDTable.Monocularity_Distance(ith_unit))/max(abs(MIDTable.Monocularity_Distance(criteria & strcmp(MIDTable.ROI,'FST'))));
            s.MarkerEdgeAlpha = 1;
            
            subplot(2,4,q_ind+4); hold on;
            s = scatter(MIDTable.Non_Dominant_AI_Persp_Weighted(ith_unit), MIDTable.Combined_AI(ith_unit),...
                50, plotOptions.Conditions.Combined, 'filled','MarkerEdgeColor',plotOptions.Conditions.Combined);
            s.MarkerFaceAlpha = abs(MIDTable.Monocularity_Distance(ith_unit))/max(abs(MIDTable.Monocularity_Distance(criteria & strcmp(MIDTable.ROI,'FST'))));
            s.MarkerEdgeAlpha = 1;
        end
    end
    
%     criteria = MIDTable.sig_Anova_All; % Additional criteria for stereo cue
%     if criteria(ith_unit)
%         if strcmp(MIDTable.ROI(ith_unit),'MT') % First and 3
%             subplot(2,4,q_ind+1); hold on;
%             s = scatter(MIDTable.Dominant_AI_Persp_Weighted(ith_unit), MIDTable.Bino_AI(ith_unit),...
%                 50, plotOptions.Conditions.Bino, 'filled','MarkerEdgeColor',plotOptions.Conditions.Bino);
%             s.MarkerFaceAlpha = abs(MIDTable.Monocularity_Distance(ith_unit))/max(abs(MIDTable.Monocularity_Distance(criteria & strcmp(MIDTable.ROI,'MT'))));
%             s.MarkerEdgeAlpha = 1;
%             
%             subplot(2,4,q_ind+3); hold on;
%             s = scatter(MIDTable.Non_Dominant_AI_Persp_Weighted(ith_unit), MIDTable.Bino_AI(ith_unit),...
%                 50, plotOptions.Conditions.Bino, 'filled','MarkerEdgeColor',plotOptions.Conditions.Bino);
%             s.MarkerFaceAlpha = abs(MIDTable.Monocularity_Distance(ith_unit))/max(abs(MIDTable.Monocularity_Distance(criteria & strcmp(MIDTable.ROI,'MT'))));
%             s.MarkerEdgeAlpha = 1;
%         else
%             subplot(2,4,q_ind+2); hold on;
%             s = scatter(MIDTable.Dominant_AI_Persp_Weighted(ith_unit), MIDTable.Bino_AI(ith_unit),...
%                 50, plotOptions.Conditions.Bino, 'filled','MarkerEdgeColor',plotOptions.Conditions.Bino);
%             s.MarkerFaceAlpha = abs(MIDTable.Monocularity_Distance(ith_unit))/max(abs(MIDTable.Monocularity_Distance(criteria & strcmp(MIDTable.ROI,'FST'))));
%             s.MarkerEdgeAlpha = 1;
%             
%             subplot(2,4,q_ind+4); hold on;
%             s = scatter(MIDTable.Non_Dominant_AI_Persp_Weighted(ith_unit), MIDTable.Bino_AI(ith_unit),...
%                 50, plotOptions.Conditions.Bino, 'filled','MarkerEdgeColor',plotOptions.Conditions.Bino);
%             s.MarkerFaceAlpha = abs(MIDTable.Monocularity_Distance(ith_unit))/max(abs(MIDTable.Monocularity_Distance(criteria & strcmp(MIDTable.ROI,'FST'))));
%             s.MarkerEdgeAlpha = 1;
%         end
%     end
end

%% MT Type II Regression fits
x = -1:0.1:1;
% 2D Combined only
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4; % & MIDTable.Monocularity_Distance_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Dominant_AI_Persp_Weighted(criteria),...
    MIDTable.Combined_AI(criteria));
regress_line = x.*B(2) + B(1);
subplot(2,4,1); hold on;
plot(x,regress_line,'-','Color',plotOptions.Conditions.Combined)
[MT_TypeII.CvD.TwoD.slope, MT_TypeII.CvD.TwoD.intercept, MT_TypeII.CvD.TwoD.slopeInt, MT_TypeII.CvD.TwoD.r, MT_TypeII.CvD.TwoD.p] = deal(B(2),B(1),slopeInt, r, p);

% 2D Stereo only
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4; % & MIDTable.Monocularity_Distance_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Dominant_AI_Persp_Weighted(criteria),...
    MIDTable.Bino_AI(criteria));
regress_line = x.*B(2) + B(1);
subplot(2,4,1); hold on;
plot(x,regress_line,'-','Color',plotOptions.Conditions.Bino)
[MT_TypeII.SvD.TwoD.slope, MT_TypeII.SvD.TwoD.intercept, MT_TypeII.SvD.TwoD.slopeInt, MT_TypeII.SvD.TwoD.r, MT_TypeII.SvD.TwoD.p] = deal(B(2),B(1),slopeInt, r, p);

% 2D Combined only
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4; % & MIDTable.Monocularity_Distance_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Non_Dominant_AI_Persp_Weighted(criteria),...
    MIDTable.Combined_AI(criteria));
regress_line = x.*B(2) + B(1);
subplot(2,4,3); hold on;
plot(x,regress_line,'-','Color',plotOptions.Conditions.Combined)
[MT_TypeII.CvND.TwoD.slope, MT_TypeII.CvND.TwoD.intercept, MT_TypeII.CvND.TwoD.slopeInt, MT_TypeII.CvND.TwoD.r, MT_TypeII.CvND.TwoD.p] = deal(B(2),B(1),slopeInt, r, p);

% 2D Stereo only
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4; % & MIDTable.Monocularity_Distance_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Non_Dominant_AI_Persp_Weighted(criteria),...
    MIDTable.Bino_AI(criteria));
regress_line = x.*B(2) + B(1);
subplot(2,4,3); hold on;
plot(x,regress_line,'-','Color',plotOptions.Conditions.Bino)
[MT_TypeII.SvND.TwoD.slope, MT_TypeII.SvND.TwoD.intercept, MT_TypeII.SvND.TwoD.slopeInt, MT_TypeII.SvND.TwoD.r, MT_TypeII.SvND.TwoD.p] = deal(B(2),B(1),slopeInt, r, p);


% 3D Combined only
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 2; % & MIDTable.Monocularity_Distance_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Dominant_AI_Persp_Weighted(criteria),...
    MIDTable.Combined_AI(criteria));
regress_line = x.*B(2) + B(1);
subplot(2,4,5); hold on;
plot(x,regress_line,'-','Color',plotOptions.Conditions.Combined)
[MT_TypeII.CvD.ThreeD.slope, MT_TypeII.CvD.ThreeD.intercept, MT_TypeII.CvD.ThreeD.slopeInt, MT_TypeII.CvD.ThreeD.r, MT_TypeII.CvD.ThreeD.p] = deal(B(2),B(1),slopeInt, r, p);

% 3D Stereo only
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 2; % & MIDTable.Monocularity_Distance_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Dominant_AI_Persp_Weighted(criteria),...
    MIDTable.Bino_AI(criteria));
regress_line = x.*B(2) + B(1);
subplot(2,4,5); hold on;
plot(x,regress_line,'-','Color',plotOptions.Conditions.Bino)
[MT_TypeII.SvD.ThreeD.slope, MT_TypeII.SvD.ThreeD.intercept, MT_TypeII.SvD.ThreeD.slopeInt, MT_TypeII.SvD.ThreeD.r, MT_TypeII.SvD.ThreeD.p] = deal(B(2),B(1),slopeInt, r, p);

% 3D Combined only
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 2; % & MIDTable.Monocularity_Distance_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Non_Dominant_AI_Persp_Weighted(criteria),...
    MIDTable.Combined_AI(criteria));
regress_line = x.*B(2) + B(1);
subplot(2,4,7); hold on;
plot(x,regress_line,'-','Color',plotOptions.Conditions.Combined)
[MT_TypeII.CvND.ThreeD.slope, MT_TypeII.CvND.ThreeD.intercept, MT_TypeII.CvND.ThreeD.slopeInt, MT_TypeII.CvND.ThreeD.r, MT_TypeII.CvND.ThreeD.p] = deal(B(2),B(1),slopeInt, r, p);

% 3D Stereo only
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 2; % & MIDTable.Monocularity_Distance_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Non_Dominant_AI_Persp_Weighted(criteria),...
    MIDTable.Bino_AI(criteria));
regress_line = x.*B(2) + B(1);
subplot(2,4,7); hold on;
plot(x,regress_line,'-','Color',plotOptions.Conditions.Bino)
[MT_TypeII.SvND.ThreeD.slope, MT_TypeII.SvND.ThreeD.intercept, MT_TypeII.SvND.ThreeD.slopeInt, MT_TypeII.SvND.ThreeD.r, MT_TypeII.SvND.ThreeD.p] = deal(B(2),B(1),slopeInt, r, p);

%% FST Type II Regression fits
% 2D Combined only
subplot(2,4,2); hold on;
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 4; % & MIDTable.Monocularity_Distance_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Dominant_AI_Persp_Weighted(criteria),...
    MIDTable.Combined_AI(criteria));
regress_line = x.*B(2) + B(1);
plot(x,regress_line,'-','Color',plotOptions.Conditions.Combined)
[FST_TypeII.CvD.TwoD.slope, FST_TypeII.CvD.TwoD.intercept, FST_TypeII.CvD.TwoD.slopeInt, FST_TypeII.CvD.TwoD.r, FST_TypeII.CvD.TwoD.p] = deal(B(2),B(1),slopeInt, r, p);

% 2D Stereo only
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 4; % & MIDTable.Monocularity_Distance_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Dominant_AI_Persp_Weighted(criteria),...
    MIDTable.Bino_AI(criteria));
regress_line = x.*B(2) + B(1);
plot(x,regress_line,'-','Color',plotOptions.Conditions.Bino)
[FST_TypeII.SvD.TwoD.slope, FST_TypeII.SvD.TwoD.intercept, FST_TypeII.SvD.TwoD.slopeInt, FST_TypeII.SvD.TwoD.r, FST_TypeII.SvD.TwoD.p] = deal(B(2),B(1),slopeInt, r, p);

% 2D Combined only
subplot(2,4,4); hold on;
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 4; % & MIDTable.Monocularity_Distance_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Non_Dominant_AI_Persp_Weighted(criteria),...
    MIDTable.Combined_AI(criteria));
regress_line = x.*B(2) + B(1);
plot(x,regress_line,'-','Color',plotOptions.Conditions.Combined)
[FST_TypeII.CvND.TwoD.slope, FST_TypeII.CvND.TwoD.intercept, FST_TypeII.CvND.TwoD.slopeInt, FST_TypeII.CvND.TwoD.r, FST_TypeII.CvND.TwoD.p] = deal(B(2),B(1),slopeInt, r, p);

% 2D Stereo only
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 4; % & MIDTable.Monocularity_Distance_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Non_Dominant_AI_Persp_Weighted(criteria),...
    MIDTable.Bino_AI(criteria));
regress_line = x.*B(2) + B(1);
plot(x,regress_line,'-','Color',plotOptions.Conditions.Bino)
[FST_TypeII.SvND.TwoD.slope, FST_TypeII.SvND.TwoD.intercept, FST_TypeII.SvND.TwoD.slopeInt, FST_TypeII.SvND.TwoD.r, FST_TypeII.SvND.TwoD.p] = deal(B(2),B(1),slopeInt, r, p);


% 3D Combined only
subplot(2,4,6); hold on;
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 2; % & MIDTable.Monocularity_Distance_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Dominant_AI_Persp_Weighted(criteria),...
    MIDTable.Combined_AI(criteria));
regress_line = x.*B(2) + B(1);
plot(x,regress_line,'-','Color',plotOptions.Conditions.Combined)
[FST_TypeII.CvD.ThreeD.slope, FST_TypeII.CvD.ThreeD.intercept, FST_TypeII.CvD.ThreeD.slopeInt, FST_TypeII.CvD.ThreeD.r, FST_TypeII.CvD.ThreeD.p] = deal(B(2),B(1),slopeInt, r, p);

% 3D Stereo only
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 2; % & MIDTable.Monocularity_Distance_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Dominant_AI_Persp_Weighted(criteria),...
    MIDTable.Bino_AI(criteria));
regress_line = x.*B(2) + B(1);
plot(x,regress_line,'-','Color',plotOptions.Conditions.Bino)
[FST_TypeII.SvD.ThreeD.slope, FST_TypeII.SvD.ThreeD.intercept, FST_TypeII.SvD.ThreeD.slopeInt, FST_TypeII.SvD.ThreeD.r, FST_TypeII.SvD.ThreeD.p] = deal(B(2),B(1),slopeInt, r, p);

% 3D Combined only
subplot(2,4,8); hold on;
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 2; % & MIDTable.Monocularity_Distance_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Non_Dominant_AI_Persp_Weighted(criteria),...
    MIDTable.Combined_AI(criteria));
regress_line = x.*B(2) + B(1);
plot(x,regress_line,'-','Color',plotOptions.Conditions.Combined)
[FST_TypeII.CvND.ThreeD.slope, FST_TypeII.CvND.ThreeD.intercept, FST_TypeII.CvND.ThreeD.slopeInt, FST_TypeII.CvND.ThreeD.r, FST_TypeII.CvND.ThreeD.p] = deal(B(2),B(1),slopeInt, r, p);

% 3D Stereo only
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 2; % & MIDTable.Monocularity_Distance_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Non_Dominant_AI_Persp_Weighted(criteria),...
    MIDTable.Bino_AI(criteria));
regress_line = x.*B(2) + B(1);
plot(x,regress_line,'-','Color',plotOptions.Conditions.Bino)
[FST_TypeII.SvND.ThreeD.slope, FST_TypeII.SvND.ThreeD.intercept, FST_TypeII.SvND.ThreeD.slopeInt, FST_TypeII.SvND.ThreeD.r, FST_TypeII.SvND.ThreeD.p] = deal(B(2),B(1),slopeInt, r, p);

%% Do neurons that don't match our predictions have systematic differences in OD?
MIDTable.Abs_Monocularity_Distance = abs(MIDTable.Monocularity_Distance);

criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4; % Select all 2D MT neurons
aligned_ind = sign(MIDTable.Dominant_AI_Persp_Weighted(criteria)) == sign(MIDTable.Combined_AI(criteria));
unaligned_ind = sign(MIDTable.Dominant_AI_Persp_Weighted(criteria)) ~= sign(MIDTable.Combined_AI(criteria));
aligned = abs(MIDTable.Monocularity_Distance(sign(MIDTable.Dominant_AI_Persp_Weighted(criteria)) == sign(MIDTable.Combined_AI(criteria))));
unaligned = abs(MIDTable.Monocularity_Distance(sign(MIDTable.Dominant_AI_Persp_Weighted(criteria)) ~= sign(MIDTable.Combined_AI(criteria))));
ranksum(aligned,unaligned)
length(unaligned)

criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4; % Select all 2D MT neurons
aligned = abs(MIDTable.Monocularity_Distance(sign(MIDTable.Dominant_AI_Persp_Weighted(criteria)) == sign(MIDTable.Bino_AI(criteria))));
unaligned = abs(MIDTable.Monocularity_Distance(sign(MIDTable.Dominant_AI_Persp_Weighted(criteria)) ~= sign(MIDTable.Bino_AI(criteria))));
ranksum(aligned,unaligned)
length(unaligned)

criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 4; % Select all 2D FST neurons
aligned = abs(MIDTable.Monocularity_Distance(sign(MIDTable.Dominant_AI_Persp_Weighted(criteria)) == sign(MIDTable.Combined_AI(criteria))));
unaligned = abs(MIDTable.Monocularity_Distance(sign(MIDTable.Dominant_AI_Persp_Weighted(criteria)) ~= sign(MIDTable.Combined_AI(criteria))));
ranksum(aligned,unaligned)
length(unaligned)

criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 4; % Select all 2D FST neurons
aligned = abs(MIDTable.Monocularity_Distance(sign(MIDTable.Dominant_AI_Persp_Weighted(criteria)) == sign(MIDTable.Bino_AI(criteria))));
unaligned = abs(MIDTable.Monocularity_Distance(sign(MIDTable.Dominant_AI_Persp_Weighted(criteria)) ~= sign(MIDTable.Bino_AI(criteria))));
ranksum(aligned,unaligned)
length(unaligned)

% Alternative linear model
% Does OD differ significantly for neurons with aligned vs. unaligned
% tuning?

% Dominant MT
% Combined
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4; % Select all 2D MT neurons
lm = fitlm(MIDTable(criteria,:),'Combined_AI ~ Abs_Monocularity*Dominant_AI_Persp_Weighted')
anova(lm)
% Stereo
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4; % Select all 2D MT neurons
lm = fitlm(MIDTable(criteria,:),'Bino_AI ~ Abs_Monocularity_Distance*Dominant_AI_Persp_Weighted')
anova(lm)
% NonDominant MT
% Combined
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4; % Select all 2D MT neurons
lm = fitlm(MIDTable(criteria,:),'Combined_AI ~ Abs_Monocularity*Non_Dominant_AI_Persp_Weighted')
anova(lm)
% Stereo
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4; % Select all 2D MT neurons
lm = fitlm(MIDTable(criteria,:),'Bino_AI ~ Abs_Monocularity_Distance*Non_Dominant_AI_Persp_Weighted')
anova(lm)

% Run a version predicting both using the stricter criteria (NOTE
% NON-INDEPENDENT SAMPLES -- HOW TO HANDLE THIS?
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4; % Select all 2D MT neurons
temp_table = array2table([MIDTable.Combined_AI(criteria), MIDTable.Abs_Monocularity(criteria), MIDTable.Dominant_AI_Persp_Weighted(criteria),MIDTable.Non_Dominant_AI_Persp_Weighted(criteria);...
    MIDTable.Bino_AI(criteria), MIDTable.Abs_Monocularity_Distance(criteria), MIDTable.Dominant_AI_Persp_Weighted(criteria),MIDTable.Non_Dominant_AI_Persp_Weighted(criteria)],...
    'VariableNames',{'Binocular_AI', 'Abs_OD', 'Dominant_AI', 'Non_Dominant_AI'});    
lm = fitlm(temp_table,'Binocular_AI ~ Abs_OD*Dominant_AI')
anova(lm)
lm = fitlm(temp_table,'Binocular_AI ~ Abs_OD*Non_Dominant_AI')
anova(lm)

% Dominant FST
% Combined
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 4; % Select all 2D MT neurons
lm = fitlm(MIDTable(criteria,:),'Combined_AI ~ Abs_Monocularity*Dominant_AI_Persp_Weighted')
anova(lm)
% Stereo
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 4; % Select all 2D MT neurons
lm = fitlm(MIDTable(criteria,:),'Bino_AI ~ Abs_Monocularity_Distance*Dominant_AI_Persp_Weighted')
anova(lm)
figure; plotInteraction(lm,'Abs_Monocularity_Distance','Dominant_AI_Persp_Weighted','predictions')
% NonDominant FST
% Combined
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 4; % Select all 2D MT neurons
lm = fitlm(MIDTable(criteria,:),'Combined_AI ~ Abs_Monocularity*Non_Dominant_AI_Persp_Weighted')
anova(lm)
% Stereo
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 4; % Select all 2D MT neurons
lm = fitlm(MIDTable(criteria,:),'Bino_AI ~ Abs_Monocularity_Distance*Non_Dominant_AI_Persp_Weighted')
anova(lm)
figure; plotInteraction(lm,'Abs_Monocularity_Distance','Dominant_AI_Persp_Weighted','predictions')

% Run a version predicting both using the stricter criteria (NOTE
% NON-INDEPENDENT SAMPLES -- HOW TO HANDLE THIS?
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 4; % Select all 2D MT neurons
temp_table = array2table([MIDTable.Combined_AI(criteria), MIDTable.Abs_Monocularity(criteria), MIDTable.Dominant_AI_Persp_Weighted(criteria),MIDTable.Non_Dominant_AI_Persp_Weighted(criteria);...
    MIDTable.Bino_AI(criteria), MIDTable.Abs_Monocularity_Distance(criteria), MIDTable.Dominant_AI_Persp_Weighted(criteria),MIDTable.Non_Dominant_AI_Persp_Weighted(criteria)],...
    'VariableNames',{'Binocular_AI', 'Abs_OD', 'Dominant_AI', 'Non_Dominant_AI'});    
lm = fitlm(temp_table,'Binocular_AI ~ Abs_OD*Dominant_AI')
anova(lm)
lm = fitlm(temp_table,'Binocular_AI ~ Abs_OD*Non_Dominant_AI')
anova(lm)


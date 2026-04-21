%% AI Condition Comparisons
% with Type II regression fits for each quadrant

%% 2D Dominant Combined & Dominant Stereo
figure; hold on;
% MT
subplot(2,4,1); hold on;
title('Dominant MT');
% 2D Neurons - Combined Cue
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4; % & MIDTable.Monocularity_Aligned_sig;
scatter(MIDTable.Dominant_AI_Persp_3D(criteria), MIDTable.Combined_AI(criteria),...
    50, plotOptions.Conditions.Combined, 'filled')

% 2D Neurons - Stereo Cue
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4; % & MIDTable.Monocularity_Aligned_sig;
scatter(MIDTable.Dominant_AI_Control(criteria), MIDTable.Bino_AI(criteria),...
    50, plotOptions.Conditions.Bino, 'filled')
xlim([-1,1]);
ylim([-1,1]);
axis square;
box on;
plot([-1,1],[0,0],'--k');
plot([0,0],[-1,1],'--k');
xlabel('Dominant AI');
ylabel('Binocular AI');

x = -1:0.1:1;
% 2D Combined only
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4; % & MIDTable.Monocularity_Aligned_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Dominant_AI_Persp_3D(criteria),...
    MIDTable.Combined_AI(criteria));
regress_line = x.*B(2) + B(1);
plot(x,regress_line,'-','Color',plotOptions.Conditions.Combined)
[MT_TypeII.CvD.TwoD.slope, MT_TypeII.CvD.TwoD.intercept, MT_TypeII.CvD.TwoD.slopeInt, MT_TypeII.CvD.TwoD.r, MT_TypeII.CvD.TwoD.p] = deal(B(2),B(1),slopeInt, r, p);

% 2D Stereo only
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4; % & MIDTable.Monocularity_Aligned_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Dominant_AI_Control(criteria),...
    MIDTable.Bino_AI(criteria));
regress_line = x.*B(2) + B(1);
plot(x,regress_line,'-','Color',plotOptions.Conditions.Bino)
[MT_TypeII.SvD.TwoD.slope, MT_TypeII.SvD.TwoD.intercept, MT_TypeII.SvD.TwoD.slopeInt, MT_TypeII.SvD.TwoD.r, MT_TypeII.SvD.TwoD.p] = deal(B(2),B(1),slopeInt, r, p);


% FST
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 4; % & MIDTable.Monocularity_Aligned_sig;
subplot(2,4,2); hold on;
title('Dominant FST');
% 2D Neurons - Combined Cue
scatter(MIDTable.Dominant_AI_Persp_3D(criteria), MIDTable.Combined_AI(criteria),...
    50, plotOptions.Conditions.Combined, 'filled')

% 2D Neurons - Stereo Cue
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 4; % & MIDTable.Monocularity_Aligned_sig;
scatter(MIDTable.Dominant_AI_Control(criteria), MIDTable.Bino_AI(criteria),...
    50, plotOptions.Conditions.Bino, 'filled')
xlim([-1,1]);
ylim([-1,1]);
axis square;
box on;
plot([-1,1],[0,0],'--k');
plot([0,0],[-1,1],'--k');
xlabel('Dominant AI');
ylabel('Binocular AI');

% 2D Combined only
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 4; % & MIDTable.Monocularity_Aligned_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Dominant_AI_Persp_3D(criteria),...
    MIDTable.Combined_AI(criteria));
regress_line = x.*B(2) + B(1);
plot(x,regress_line,'-','Color',plotOptions.Conditions.Combined)
[FST_TypeII.CvD.TwoD.slope, FST_TypeII.CvD.TwoD.intercept, FST_TypeII.CvD.TwoD.slopeInt, FST_TypeII.CvD.TwoD.r, FST_TypeII.CvD.TwoD.p] = deal(B(2),B(1),slopeInt, r, p);

% 2D Stereo only
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 4; % & MIDTable.Monocularity_Aligned_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Dominant_AI_Control(criteria),...
    MIDTable.Bino_AI(criteria));
regress_line = x.*B(2) + B(1);
plot(x,regress_line,'-','Color',plotOptions.Conditions.Bino)
[FST_TypeII.SvD.TwoD.slope, FST_TypeII.SvD.TwoD.intercept, FST_TypeII.SvD.TwoD.slopeInt, FST_TypeII.SvD.TwoD.r, FST_TypeII.SvD.TwoD.p] = deal(B(2),B(1),slopeInt, r, p);

%% 2D Non-Dominant Combined & Non-Dominant Stereo
% MT
subplot(2,4,3); hold on;
title('Non-Dominant MT');
% 2D Neurons - Combined Cue
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4; % & MIDTable.Monocularity_Aligned_sig;
scatter(MIDTable.Non_Dominant_AI_Persp_3D(criteria), MIDTable.Combined_AI(criteria),...
    50, plotOptions.Conditions.Combined, 'filled')

% 2D Neurons - Stereo Cue
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4; % & MIDTable.Monocularity_Aligned_sig;
scatter(MIDTable.Non_Dominant_AI_Control(criteria), MIDTable.Bino_AI(criteria),...
    50, plotOptions.Conditions.Bino, 'filled')
xlim([-1,1]);
ylim([-1,1]);
axis square;
box on;
plot([-1,1],[0,0],'--k');
plot([0,0],[-1,1],'--k');
xlabel('Non-Dominant AI');
ylabel('Binocular AI');

x = -1:0.1:1;
% 2D Combined only
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4; % & MIDTable.Monocularity_Aligned_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Non_Dominant_AI_Persp_3D(criteria),...
    MIDTable.Combined_AI(criteria));
regress_line = x.*B(2) + B(1);
plot(x,regress_line,'-','Color',plotOptions.Conditions.Combined)
[MT_TypeII.CvND.TwoD.slope, MT_TypeII.CvND.TwoD.intercept, MT_TypeII.CvND.TwoD.slopeInt, MT_TypeII.CvND.TwoD.r, MT_TypeII.CvND.TwoD.p] = deal(B(2),B(1),slopeInt, r, p);

% 2D Stereo only
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4; % & MIDTable.Monocularity_Aligned_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Non_Dominant_AI_Control(criteria),...
    MIDTable.Bino_AI(criteria));
regress_line = x.*B(2) + B(1);
plot(x,regress_line,'-','Color',plotOptions.Conditions.Bino)
[MT_TypeII.SvND.TwoD.slope, MT_TypeII.SvND.TwoD.intercept, MT_TypeII.SvND.TwoD.slopeInt, MT_TypeII.SvND.TwoD.r, MT_TypeII.SvND.TwoD.p] = deal(B(2),B(1),slopeInt, r, p);


% FST
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 4; % & MIDTable.Monocularity_Aligned_sig;
subplot(2,4,4); hold on;
title('Non-Dominant FST');
% 2D Neurons - Combined Cue
scatter(MIDTable.Non_Dominant_AI_Persp_3D(criteria), MIDTable.Combined_AI(criteria),...
    50, plotOptions.Conditions.Combined, 'filled')

% 2D Neurons - Stereo Cue
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 4; % & MIDTable.Monocularity_Aligned_sig;
scatter(MIDTable.Non_Dominant_AI_Control(criteria), MIDTable.Bino_AI(criteria),...
    50, plotOptions.Conditions.Bino, 'filled')
xlim([-1,1]);
ylim([-1,1]);
axis square;
box on;
plot([-1,1],[0,0],'--k');
plot([0,0],[-1,1],'--k');
xlabel('Non-Dominant AI');
ylabel('Binocular AI');

% 2D Combined only
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 4; % & MIDTable.Monocularity_Aligned_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Non_Dominant_AI_Persp_3D(criteria),...
    MIDTable.Combined_AI(criteria));
regress_line = x.*B(2) + B(1);
plot(x,regress_line,'-','Color',plotOptions.Conditions.Combined)
[FST_TypeII.CvND.TwoD.slope, FST_TypeII.CvND.TwoD.intercept, FST_TypeII.CvND.TwoD.slopeInt, FST_TypeII.CvND.TwoD.r, FST_TypeII.CvND.TwoD.p] = deal(B(2),B(1),slopeInt, r, p);

% 2D Stereo only
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 4; % & MIDTable.Monocularity_Aligned_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Non_Dominant_AI_Control(criteria),...
    MIDTable.Bino_AI(criteria));
regress_line = x.*B(2) + B(1);
plot(x,regress_line,'-','Color',plotOptions.Conditions.Bino)
[FST_TypeII.SvND.TwoD.slope, FST_TypeII.SvND.TwoD.intercept, FST_TypeII.SvND.TwoD.slopeInt, FST_TypeII.SvND.TwoD.r, FST_TypeII.SvND.TwoD.p] = deal(B(2),B(1),slopeInt, r, p);




%% 3D Dominant Combined & Dominant Stereo
% MT
subplot(2,4,5); hold on;
title('Dominant MT');
% 3D Neurons - Combined Cue
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 2; % & MIDTable.Monocularity_Aligned_sig;
scatter(MIDTable.Dominant_AI_Persp_3D(criteria), MIDTable.Combined_AI(criteria),...
    50, plotOptions.Conditions.Combined, 'filled')

% 3D Neurons - Stereo Cue
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 2; % & MIDTable.Monocularity_Aligned_sig;
scatter(MIDTable.Dominant_AI_Control(criteria), MIDTable.Bino_AI(criteria),...
    50, plotOptions.Conditions.Bino, 'filled')
xlim([-1,1]);
ylim([-1,1]);
axis square;
box on;
plot([-1,1],[0,0],'--k');
plot([0,0],[-1,1],'--k');
xlabel('Dominant AI');
ylabel('Binocular AI');

x = -1:0.1:1;
% 3D Combined only
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 2; % & MIDTable.Monocularity_Aligned_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Dominant_AI_Persp_3D(criteria),...
    MIDTable.Combined_AI(criteria));
regress_line = x.*B(2) + B(1);
plot(x,regress_line,'-','Color',plotOptions.Conditions.Combined)
[MT_TypeII.CvD.ThreeD.slope, MT_TypeII.CvD.ThreeD.intercept, MT_TypeII.CvD.ThreeD.slopeInt, MT_TypeII.CvD.ThreeD.r, MT_TypeII.CvD.ThreeD.p] = deal(B(2),B(1),slopeInt, r, p);

% 3D Stereo only
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 2; % & MIDTable.Monocularity_Aligned_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Dominant_AI_Control(criteria),...
    MIDTable.Bino_AI(criteria));
regress_line = x.*B(2) + B(1);
plot(x,regress_line,'-','Color',plotOptions.Conditions.Bino)
[MT_TypeII.SvD.ThreeD.slope, MT_TypeII.SvD.ThreeD.intercept, MT_TypeII.SvD.ThreeD.slopeInt, MT_TypeII.SvD.ThreeD.r, MT_TypeII.SvD.ThreeD.p] = deal(B(2),B(1),slopeInt, r, p);


% FST
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 2; % & MIDTable.Monocularity_Aligned_sig;
subplot(2,4,6); hold on;
title('Dominant FST');
% 3D Neurons - Combined Cue
scatter(MIDTable.Dominant_AI_Persp_3D(criteria), MIDTable.Combined_AI(criteria),...
    50, plotOptions.Conditions.Combined, 'filled')

% 3D Neurons - Stereo Cue
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 2; % & MIDTable.Monocularity_Aligned_sig;
scatter(MIDTable.Dominant_AI_Control(criteria), MIDTable.Bino_AI(criteria),...
    50, plotOptions.Conditions.Bino, 'filled')
xlim([-1,1]);
ylim([-1,1]);
axis square;
box on;
plot([-1,1],[0,0],'--k');
plot([0,0],[-1,1],'--k');
xlabel('Dominant AI');
ylabel('Binocular AI');

% 3D Combined only
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 2; % & MIDTable.Monocularity_Aligned_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Dominant_AI_Persp_3D(criteria),...
    MIDTable.Combined_AI(criteria));
regress_line = x.*B(2) + B(1);
plot(x,regress_line,'-','Color',plotOptions.Conditions.Combined)
[FST_TypeII.CvD.ThreeD.slope, FST_TypeII.CvD.ThreeD.intercept, FST_TypeII.CvD.ThreeD.slopeInt, FST_TypeII.CvD.ThreeD.r, FST_TypeII.CvD.ThreeD.p] = deal(B(2),B(1),slopeInt, r, p);

% 3D Stereo only
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 2; % & MIDTable.Monocularity_Aligned_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Dominant_AI_Control(criteria),...
    MIDTable.Bino_AI(criteria));
regress_line = x.*B(2) + B(1);
plot(x,regress_line,'-','Color',plotOptions.Conditions.Bino)
[FST_TypeII.SvD.ThreeD.slope, FST_TypeII.SvD.ThreeD.intercept, FST_TypeII.SvD.ThreeD.slopeInt, FST_TypeII.SvD.ThreeD.r, FST_TypeII.SvD.ThreeD.p] = deal(B(2),B(1),slopeInt, r, p);

%% 3D Non-Dominant Combined & Non-Dominant Stereo
% MT
subplot(2,4,7); hold on;
title('Non-Dominant MT');
% 3D Neurons - Combined Cue
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 2; % & MIDTable.Monocularity_Aligned_sig;
scatter(MIDTable.Non_Dominant_AI_Persp_3D(criteria), MIDTable.Combined_AI(criteria),...
    50, plotOptions.Conditions.Combined, 'filled')

% 3D Neurons - Stereo Cue
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 2; % & MIDTable.Monocularity_Aligned_sig;
scatter(MIDTable.Non_Dominant_AI_Control(criteria), MIDTable.Bino_AI(criteria),...
    50, plotOptions.Conditions.Bino, 'filled')
xlim([-1,1]);
ylim([-1,1]);
axis square;
box on;
plot([-1,1],[0,0],'--k');
plot([0,0],[-1,1],'--k');
xlabel('Non-Dominant AI');
ylabel('Binocular AI');

x = -1:0.1:1;
% 3D Combined only
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 2; % & MIDTable.Monocularity_Aligned_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Non_Dominant_AI_Persp_3D(criteria),...
    MIDTable.Combined_AI(criteria));
regress_line = x.*B(2) + B(1);
plot(x,regress_line,'-','Color',plotOptions.Conditions.Combined)
[MT_TypeII.CvND.ThreeD.slope, MT_TypeII.CvND.ThreeD.intercept, MT_TypeII.CvND.ThreeD.slopeInt, MT_TypeII.CvND.ThreeD.r, MT_TypeII.CvND.ThreeD.p] = deal(B(2),B(1),slopeInt, r, p);

% 3D Stereo only
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 2; % & MIDTable.Monocularity_Aligned_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Non_Dominant_AI_Control(criteria),...
    MIDTable.Bino_AI(criteria));
regress_line = x.*B(2) + B(1);
plot(x,regress_line,'-','Color',plotOptions.Conditions.Bino)
[MT_TypeII.SvND.ThreeD.slope, MT_TypeII.SvND.ThreeD.intercept, MT_TypeII.SvND.ThreeD.slopeInt, MT_TypeII.SvND.ThreeD.r, MT_TypeII.SvND.ThreeD.p] = deal(B(2),B(1),slopeInt, r, p);


% FST
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 2; % & MIDTable.Monocularity_Aligned_sig;
subplot(2,4,8); hold on;
title('Non-Dominant FST');
% 3D Neurons - Combined Cue
scatter(MIDTable.Non_Dominant_AI_Persp_3D(criteria), MIDTable.Combined_AI(criteria),...
    50, plotOptions.Conditions.Combined, 'filled')

% 3D Neurons - Stereo Cue
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 2; % & MIDTable.Monocularity_Aligned_sig;
scatter(MIDTable.Non_Dominant_AI_Control(criteria), MIDTable.Bino_AI(criteria),...
    50, plotOptions.Conditions.Bino, 'filled')
xlim([-1,1]);
ylim([-1,1]);
axis square;
box on;
plot([-1,1],[0,0],'--k');
plot([0,0],[-1,1],'--k');
xlabel('Non-Dominant AI');
ylabel('Binocular AI');

% 3D Combined only
criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 2; % & MIDTable.Monocularity_Aligned_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Non_Dominant_AI_Persp_3D(criteria),...
    MIDTable.Combined_AI(criteria));
regress_line = x.*B(2) + B(1);
plot(x,regress_line,'-','Color',plotOptions.Conditions.Combined)
[FST_TypeII.CvND.ThreeD.slope, FST_TypeII.CvND.ThreeD.intercept, FST_TypeII.CvND.ThreeD.slopeInt, FST_TypeII.CvND.ThreeD.r, FST_TypeII.CvND.ThreeD.p] = deal(B(2),B(1),slopeInt, r, p);

% 3D Stereo only
criteria = MIDTable.sig_Anova_All & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 2; % & MIDTable.Monocularity_Aligned_sig;
[B(2),B(1),slopeInt, ~, r, p] = regress_perp(MIDTable.Non_Dominant_AI_Control(criteria),...
    MIDTable.Bino_AI(criteria));
regress_line = x.*B(2) + B(1);
plot(x,regress_line,'-','Color',plotOptions.Conditions.Bino)
[FST_TypeII.SvND.ThreeD.slope, FST_TypeII.SvND.ThreeD.intercept, FST_TypeII.SvND.ThreeD.slopeInt, FST_TypeII.SvND.ThreeD.r, FST_TypeII.SvND.ThreeD.p] = deal(B(2),B(1),slopeInt, r, p);


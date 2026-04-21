%% Statistics for MT/FST 3D Motion Paper
% Sessions
fprintf(2,'Sessions in each area & monkey\n')
disp(['MT: ', num2str(numel(unique(MIDTable.Date(strcmp(MIDTable.ROI,'MT')))))])
disp(['MT Jim : ', num2str(numel(unique(MIDTable.Date(strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Jim')))))])
disp(['MT Clay : ', num2str(numel(unique(MIDTable.Date(strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Clay')))))])

disp(['FST: ', num2str(numel(unique(MIDTable.Date(strcmp(MIDTable.ROI,'FST')))))])
disp(['FST Jim : ', num2str(numel(unique(MIDTable.Date(strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Jim')))))])
disp(['FST Clay : ', num2str(numel(unique(MIDTable.Date(strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Clay')))))])

%% Basic Properties
% RFs
RFData.Monkey = MIDTable.Monkey;
RFData.AreaCode = MIDTable.Area_Code;
fprintf(2,'RF Interaction Model w/Random Monkey Int')
lm = fitlme(RFData,'SqrtRFArea ~ Eccentricity_Deg*AreaCode + (1|Monkey)')
anova(lm)

% Visual latency
% fprintf(2,'Visual Latency')
% disp(['MT: Median = ', num2str(nanmedian(MIDTable.Latency(strcmp(MIDTable.ROI,'MT'))))])
% disp(['MT Jim: Median = ', num2str(nanmedian(MIDTable.Latency(strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Jim'))))])
% disp(['MT Clay: Median = ', num2str(nanmedian(MIDTable.Latency(strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Clay'))))])
% disp(['FST: Median = ', num2str(nanmedian(MIDTable.Latency(strcmp(MIDTable.ROI,'FST'))))])
% disp(['FST Jim: Median = ', num2str(nanmedian(MIDTable.Latency(strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Jim'))))])
% disp(['FST Clay: Median = ', num2str(nanmedian(MIDTable.Latency(strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Clay'))))])
% 
% fprintf(2,'Rank Sum Visual Latency')
% visual_p = ranksum(MIDTable.Latency(strcmp(MIDTable.ROI,'MT') & ~isnan(MIDTable.Latency)),...
%     MIDTable.Latency(strcmp(MIDTable.ROI,'FST') & ~isnan(MIDTable.Latency)))

% Euclidian RF distance
fprintf(2,'Rank Sum RF Distance')
RFDist_p = ranksum(Clusters.Euclidian_Distance(strcmp(Clusters.ROI,'MT')),...
    Clusters.Euclidian_Distance(strcmp(Clusters.ROI,'FST')));
Clusters.Log_ED = log(Clusters.Euclidian_Distance);
Clusters.ED2 = Clusters.Euclidian_Distance.^2;
lm = fitlm(Clusters,'Euclidian_Distance ~ ROI*MeanSqrtArea')
glm = fitglm(Clusters,'Euclidian_Distance ~ ROI*MeanSqrtArea','Distribution','poisson')

ranksum(Clusters.R3D(strcmp(Clusters.ROI,'MT')),Clusters.R3D(strcmp(Clusters.ROI,'FST')))


%% Combined cue selectivity
criteria = MIDTable.sig_Anova2_Combined;
fprintf(2,'Proportion of combined-cue selective neurons:\n')
disp(['MT: ', num2str(sum(strcmp(MIDTable.ROI,'MT') & criteria)/sum(strcmp(MIDTable.ROI,'MT'))*100)])
disp(['MT Jim : ', num2str(sum(strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Jim') & criteria)/sum(strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Jim'))*100)])
disp(['MT Clay : ', num2str(sum(strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Clay') & criteria)/sum(strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Clay'))*100)])

disp(['FST: ', num2str(sum(strcmp(MIDTable.ROI,'FST') & criteria)/sum(strcmp(MIDTable.ROI,'FST'))*100)])
disp(['FST Jim : ', num2str(sum(strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Jim') & criteria)/sum(strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Jim'))*100)])
disp(['FST Clay : ', num2str(sum(strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Clay') & criteria)/sum(strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Clay'))*100)])

fprintf(2,'T-test for toward tendency:')
disp('MT')
[~,p] = ttest(MIDTable.Combined_AI(strcmp(MIDTable.ROI,'MT')))
disp(['Jim:'])
[~,p] = ttest(MIDTable.Combined_AI(strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Jim')))
disp(['Clay:'])
[~,p] = ttest(MIDTable.Combined_AI(strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Jim')))

disp('FST')
[~,p] = ttest(MIDTable.Combined_AI(strcmp(MIDTable.ROI,'FST')))
disp(['Jim:'])
[~,p] = ttest(MIDTable.Combined_AI(strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Jim')))
disp(['Clay:'])
[~,p] = ttest(MIDTable.Combined_AI(strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Clay')))

%% OD
criteria = MIDTable.sig_Anova_CLR;
p = ranksum(MIDTable.Abs_Monocularity(strcmp(MIDTable.ROI,'MT') & criteria),MIDTable.Abs_Monocularity(strcmp(MIDTable.ROI,'MT') & ~criteria)) 
p = ranksum(MIDTable.Abs_Monocularity(strcmp(MIDTable.ROI,'FST') & criteria),MIDTable.Abs_Monocularity(strcmp(MIDTable.ROI,'FST') & ~criteria)) 

p = ranksum(MIDTable.Abs_Monocularity(strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4 & criteria),MIDTable.Abs_Monocularity(strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4 & ~criteria)) 
p = ranksum(MIDTable.Abs_Monocularity(strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 4 & criteria),MIDTable.Abs_Monocularity(strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 4 & ~criteria))

p = ranksum(MIDTable.Abs_Monocularity(strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 2 & criteria),MIDTable.Abs_Monocularity(strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 2 & ~criteria)) 
p = ranksum(MIDTable.Abs_Monocularity(strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 2 & criteria),MIDTable.Abs_Monocularity(strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 2 & ~criteria))

%% CLR selectivity
criteria = MIDTable.sig_Anova_CLR;
fprintf(2,'Proportion of combined-cue, left eye, and right eye selective neurons:\n')
disp(['MT: ', num2str(sum(strcmp(MIDTable.ROI,'MT') & criteria)/sum(strcmp(MIDTable.ROI,'MT'))*100)])
disp(['MT Jim : ', num2str(sum(strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Jim') & criteria)/sum(strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Jim'))*100)])
disp(['MT Clay : ', num2str(sum(strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Clay') & criteria)/sum(strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Clay'))*100)])

disp(['FST: ', num2str(sum(strcmp(MIDTable.ROI,'FST') & criteria)/sum(strcmp(MIDTable.ROI,'FST'))*100)])
disp(['FST Jim : ', num2str(sum(strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Jim') & criteria)/sum(strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Jim'))*100)])
disp(['FST Clay : ', num2str(sum(strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Clay') & criteria)/sum(strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Clay'))*100)])

%% Z_quad plot
criteria = MIDTable.sig_Anova_CLR;
% Proportion in each Z_quad
fprintf(2,'MT Proportions in Z_quads:\n')
disp(['Unclassified: N = ', num2str(sum(MIDTable.Z_quad == 1 & strcmp(MIDTable.ROI,'MT') & criteria)),', ', num2str(sum(MIDTable.Z_quad == 1 & strcmp(MIDTable.ROI,'MT') & criteria)/sum(strcmp(MIDTable.ROI,'MT') & criteria)*100)])
disp(['Unclassified Jim: N = ', num2str(sum(MIDTable.Z_quad == 1 & strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Jim') & criteria)),', ' num2str(sum(MIDTable.Z_quad == 1 & strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Jim') & criteria)/sum(strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Jim') & criteria)*100)])
disp(['Unclassified Clay: N = ', num2str(sum(MIDTable.Z_quad == 1 & strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Clay') & criteria)),', ' num2str(sum(MIDTable.Z_quad == 1 & strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Clay') & criteria)/sum(strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Clay') & criteria)*100)])
disp(['2D: N = ', num2str(sum(MIDTable.Z_quad == 4 & strcmp(MIDTable.ROI,'MT') & criteria)),', ' num2str(sum(MIDTable.Z_quad == 4 & strcmp(MIDTable.ROI,'MT') & criteria)/sum(strcmp(MIDTable.ROI,'MT') & criteria)*100)])
disp(['2D Jim: N = ', num2str(sum(MIDTable.Z_quad == 4 & strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Jim') & criteria)),', ' num2str(sum(MIDTable.Z_quad == 4 & strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Jim') & criteria)/sum(strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Jim') & criteria)*100)])
disp(['2D Clay: N = ', num2str(sum(MIDTable.Z_quad == 4 & strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Clay') & criteria)),', ' num2str(sum(MIDTable.Z_quad == 4 & strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Clay') & criteria)/sum(strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Clay') & criteria)*100)])
disp(['3D: N = ', num2str(sum(MIDTable.Z_quad == 2 & strcmp(MIDTable.ROI,'MT') & criteria)),', ', num2str(sum(MIDTable.Z_quad == 2 & strcmp(MIDTable.ROI,'MT') & criteria)/sum(strcmp(MIDTable.ROI,'MT') & criteria)*100)])
disp(['3D Jim: N = ', num2str(sum(MIDTable.Z_quad == 2 & strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Jim') & criteria)),', ' num2str(sum(MIDTable.Z_quad == 2 & strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Jim') & criteria)/sum(strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Jim') & criteria)*100)])
disp(['3D Clay: N = ', num2str(sum(MIDTable.Z_quad == 2 & strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Clay') & criteria)),', ' num2str(sum(MIDTable.Z_quad == 2 & strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Clay') & criteria)/sum(strcmp(MIDTable.ROI,'MT') & strcmp(MIDTable.Monkey,'Clay') & criteria)*100)])

fprintf(2,'FST Proportions in Z_quads:\n')
disp(['Unclassified: N = ', num2str(sum(MIDTable.Z_quad == 1 & strcmp(MIDTable.ROI,'FST') & criteria)), ', ', num2str(sum(MIDTable.Z_quad == 1 & strcmp(MIDTable.ROI,'FST') & criteria)/sum(strcmp(MIDTable.ROI,'FST') & criteria)*100)])
disp(['Unclassified Jim: N = ', num2str(sum(MIDTable.Z_quad == 1 & strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Jim') & criteria)),', ' num2str(sum(MIDTable.Z_quad == 1 & strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Jim') & criteria)/sum(strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Jim') & criteria)*100)])
disp(['Unclassified Clay: N = ', num2str(sum(MIDTable.Z_quad == 1 & strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Clay') & criteria)),', ' num2str(sum(MIDTable.Z_quad == 1 & strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Clay') & criteria)/sum(strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Clay') & criteria)*100)])
disp(['2D: N = ', num2str(sum(MIDTable.Z_quad == 4 & strcmp(MIDTable.ROI,'FST') & criteria)), ', ', num2str(sum(MIDTable.Z_quad == 4 & strcmp(MIDTable.ROI,'FST') & criteria)/sum(strcmp(MIDTable.ROI,'FST') & criteria)*100)])
disp(['2D Jim: N = ', num2str(sum(MIDTable.Z_quad == 4 & strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Jim') & criteria)),', ' num2str(sum(MIDTable.Z_quad == 4 & strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Jim') & criteria)/sum(strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Jim') & criteria)*100)])
disp(['2D Clay: N = ', num2str(sum(MIDTable.Z_quad == 4 & strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Clay') & criteria)),', ' num2str(sum(MIDTable.Z_quad == 4 & strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Clay') & criteria)/sum(strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Clay') & criteria)*100)])
disp(['3D: N = ', num2str(sum(MIDTable.Z_quad == 2 & strcmp(MIDTable.ROI,'FST') & criteria)),', ', num2str(sum(MIDTable.Z_quad == 2 & strcmp(MIDTable.ROI,'FST') & criteria)/sum(strcmp(MIDTable.ROI,'FST') & criteria)*100)])
disp(['3D Jim: N = ', num2str(sum(MIDTable.Z_quad == 2 & strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Jim') & criteria)),', ' num2str(sum(MIDTable.Z_quad == 2 & strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Jim') & criteria)/sum(strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Jim') & criteria)*100)])
disp(['3D Clay: N = ', num2str(sum(MIDTable.Z_quad == 2 & strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Clay') & criteria)),', ' num2str(sum(MIDTable.Z_quad == 2 & strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Clay') & criteria)/sum(strcmp(MIDTable.ROI,'FST') & strcmp(MIDTable.Monkey,'Clay') & criteria)*100)])

% are the means significantly different from 45 deg
fprintf(2,'MT Sign Test: Are wrapped 2D prefs different from 45 deg?\n')
p1 = signtest(MIDTable.Obliqueness(MIDTable.Z_quad == 1 & criteria & bino_eye & strcmp(MIDTable.ROI,'MT')), 45);
p2 = signtest(MIDTable.Obliqueness(MIDTable.Z_quad == 2 & criteria & bino_eye & strcmp(MIDTable.ROI,'MT')), 45);
p4 = signtest(MIDTable.Obliqueness(MIDTable.Z_quad == 4 & criteria & bino_eye & strcmp(MIDTable.ROI,'MT')), 45);
disp(['Unclassified: ', num2str(p1)])
disp(['2D: ', num2str(p4)])
disp(['3D: ', num2str(p2)])

fprintf(2,'FST Sign Test: Are wrapped 2D prefs different from 45 deg?\n')
p1 = signtest(MIDTable.Obliqueness(MIDTable.Z_quad == 1 & criteria & bino_eye & strcmp(MIDTable.ROI,'FST')), 45);
p2 = signtest(MIDTable.Obliqueness(MIDTable.Z_quad == 2 & criteria & bino_eye & strcmp(MIDTable.ROI,'FST')), 45);
p4 = signtest(MIDTable.Obliqueness(MIDTable.Z_quad == 4 & criteria & bino_eye & strcmp(MIDTable.ROI,'FST')), 45);
disp(['Unclassified: ', num2str(p1)])
disp(['2D: ', num2str(p4)])
disp(['3D: ', num2str(p2)])

lm = fitlm(MIDTable(MIDTable.sig_Anova2_Combined & bino_eye & MIDTable.Z_quad ~= 3,:),'Obliqueness ~ Z_quad');
[a1_oblique_p,~,a1_oblique_stats] = anova1(MIDTable.Obliqueness(criteria & bino_eye & MIDTable.Z_quad ~= 3 & strcmp(MIDTable.ROI,'MT')),MIDTable.Z_quad(criteria & bino_eye & MIDTable.Z_quad ~= 3 & strcmp(MIDTable.ROI,'MT')))
multcompare(a1_oblique_stats)
[a1_oblique_p,~,a1_oblique_stats] = anova1(MIDTable.Obliqueness(criteria & bino_eye & MIDTable.Z_quad ~= 3 & strcmp(MIDTable.ROI,'FST')),MIDTable.Z_quad(criteria & bino_eye & MIDTable.Z_quad ~= 3 & strcmp(MIDTable.ROI,'FST')))
multcompare(a1_oblique_stats)

%% AI Correlations
clear r p
criteria = MIDTable.sig_Anova_CLR;
fprintf(2,'\nDominant Non-Dominant AI Correlations')
[r(1),p(1)] = corr(MIDTable.Dominant_AI_Persp_3D(strcmp(MIDTable.ROI,'FST') & criteria & MIDTable.Z_quad == 2), MIDTable.Non_Dominant_AI_Persp_3D(strcmp(MIDTable.ROI,'FST') & criteria & MIDTable.Z_quad == 2));
[r(2),p(2)] = corr(MIDTable.Dominant_AI_Persp_3D(strcmp(MIDTable.ROI,'FST') & criteria & MIDTable.Z_quad == 4), MIDTable.Non_Dominant_AI_Persp_3D(strcmp(MIDTable.ROI,'FST') & criteria & MIDTable.Z_quad == 4));
[r(3),p(3)] = corr(MIDTable.Dominant_AI_Persp_3D(strcmp(MIDTable.ROI,'MT') & criteria), MIDTable.Non_Dominant_AI_Persp_3D(strcmp(MIDTable.ROI,'MT') & criteria));
fprintf('\nFST 3D: r = %d, p = %d', r(1), p(1))
fprintf('\nFST 2D: r = %d, p = %d', r(2), p(2))
fprintf('\nMT: r = %d, p = %d', r(3), p(3))

criteria = MIDTable.sig_Anova2_Combined & MIDTable.sig_Anova2_Dom & MIDTable.sig_Anova2_Bino;
fprintf(2,'\n\nDominant Stereo AI Correlations')
[r(1),p(1)] = corr(MIDTable.Dominant_AI_Persp_3D(strcmp(MIDTable.ROI,'FST') & criteria), MIDTable.Bino_AI(strcmp(MIDTable.ROI,'FST') & criteria));
% [r(2),p(2)] = corr(MIDTable.Dominant_AI_Persp_3D(strcmp(MIDTable.ROI,'FST') & criteria & MIDTable.Z_quad == 4), MIDTable.Bino_AI(strcmp(MIDTable.ROI,'FST') & criteria & MIDTable.Z_quad == 4));
[r(3),p(3)] = corr(MIDTable.Dominant_AI_Persp_3D(strcmp(MIDTable.ROI,'MT') & criteria), MIDTable.Bino_AI(strcmp(MIDTable.ROI,'MT') & criteria));
fprintf('\nFST 3D: r = %d, p = %d', r(1), p(1))
% fprintf('\nFST 2D: r = %d, p = %d', r(2), p(2))
fprintf('\nMT: r = %d, p = %d', r(3), p(3))

criteria = MIDTable.sig_Anova2_Combined & MIDTable.sig_Anova2_NonDom & MIDTable.sig_Anova2_Bino;
fprintf(2,'\n\nNon-Dominant Stereo AI Correlations')
[r(1),p(1)] = corr(MIDTable.Non_Dominant_AI_Persp_3D(strcmp(MIDTable.ROI,'FST') & criteria & MIDTable.Z_quad == 2), MIDTable.Bino_AI(strcmp(MIDTable.ROI,'FST') & criteria & MIDTable.Z_quad == 2));
[r(2),p(2)] = corr(MIDTable.Non_Dominant_AI_Persp_3D(strcmp(MIDTable.ROI,'FST') & criteria & MIDTable.Z_quad == 4), MIDTable.Bino_AI(strcmp(MIDTable.ROI,'FST') & criteria & MIDTable.Z_quad == 4));
[r(3),p(3)] = corr(MIDTable.Non_Dominant_AI_Persp_3D(strcmp(MIDTable.ROI,'MT') & criteria), MIDTable.Bino_AI(strcmp(MIDTable.ROI,'MT') & criteria));
fprintf('\nFST 3D: r = %d, p = %d', r(1), p(1))
fprintf('\nFST 2D: r = %d, p = %d', r(2), p(2))
fprintf('\nMT: r = %d, p = %d', r(3), p(3))

criteria = MIDTable.sig_Anova2_Combined & MIDTable.sig_Anova2_Dom;
fprintf(2,'\n\nDominant Combined AI Correlations')
[r(1),p(1)] = corr(MIDTable.Dominant_AI_Persp_3D(strcmp(MIDTable.ROI,'FST') & criteria), MIDTable.Combined_AI(strcmp(MIDTable.ROI,'FST') & criteria));
% [r(2),p(2)] = corr(MIDTable.Dominant_AI_Persp_3D(strcmp(MIDTable.ROI,'FST') & criteria & MIDTable.Z_quad == 4), MIDTable.Combined_AI(strcmp(MIDTable.ROI,'FST') & criteria & MIDTable.Z_quad == 4));
[r(3),p(3)] = corr(MIDTable.Dominant_AI_Persp_3D(strcmp(MIDTable.ROI,'MT') & criteria), MIDTable.Combined_AI(strcmp(MIDTable.ROI,'MT') & criteria));
fprintf('\nFST: r = %d, p = %d', r(1), p(1))
% fprintf('\nFST 2D: r = %d, p = %d', r(2), p(2))
fprintf('\nMT: r = %d, p = %d', r(3), p(3))

criteria = MIDTable.sig_Anova2_Combined & MIDTable.sig_Anova2_NonDom;
fprintf(2,'\n\nNon-Dominant Combined AI Correlations')
[r(1),p(1)] = corr(MIDTable.Non_Dominant_AI_Persp_3D(strcmp(MIDTable.ROI,'FST') & criteria & MIDTable.Z_quad == 2), MIDTable.Combined_AI(strcmp(MIDTable.ROI,'FST') & criteria & MIDTable.Z_quad == 2));
[r(2),p(2)] = corr(MIDTable.Non_Dominant_AI_Persp_3D(strcmp(MIDTable.ROI,'FST') & criteria & MIDTable.Z_quad == 4), MIDTable.Combined_AI(strcmp(MIDTable.ROI,'FST') & criteria & MIDTable.Z_quad == 4));
[r(3),p(3)] = corr(MIDTable.Non_Dominant_AI_Persp_3D(strcmp(MIDTable.ROI,'MT') & criteria), MIDTable.Combined_AI(strcmp(MIDTable.ROI,'MT') & criteria));
fprintf('\nFST 3D: r = %d, p = %d', r(1), p(1))
fprintf('\nFST 2D: r = %d, p = %d', r(2), p(2))
fprintf('\nMT: r = %d, p = %d \n', r(3), p(3))


%% Partial correlations and opposite 2D tuning
% First grab the preferred directions at the preferred speed
left_speed = LateralMotionTable.PrefSpeed(:,1);
right_speed = LateralMotionTable.PrefSpeed(:,2);
left_ind = sub2ind([length(left_speed),2],[1:length(left_speed)]',left_speed);
right_ind = sub2ind([length(right_speed),2],[1:length(right_speed)]',right_speed);
MIDTable.Left_2D_sig = LateralMotionTable.left_anova_one_way(left_ind)<0.05;
MIDTable.Right_2D_sig = LateralMotionTable.right_anova_one_way(right_ind)<0.05;
MIDTable.LR_2D_sig = MIDTable.Left_2D_sig & MIDTable.Right_2D_sig;
both_speed = LateralMotionTable.PrefSpeed(:,3);
both_ind = sub2ind([length(both_speed),2],[1:length(both_speed)]',both_speed);
MIDTable.Both_2D_sig = LateralMotionTable.both_anova_one_way(both_ind)<0.05;
MIDTable.Abs_Combined_AI = abs(MIDTable.Combined_AI); % For some reason this variable got overwritten someplace and caused all the numbers to be scaled down

% criteria = MIDTable.sig_Anova2_Combined; % & MIDTable.LR_2D_sig;
criteria = MIDTable.sig_Anova_CLR; % & MIDTable.LR_2D_sig;
MIDTable.LR_diff = wrapTo180(MIDTable.Left_Mu - MIDTable.Right_Mu);
MIDTable.LR_diff_mag = abs(MIDTable.LR_diff);
MIDTable.ATI_both = LateralMotionTable.ATI_both(both_ind);

fprintf(2,'\n\nMT: \n')
[lm,stat] = robustfit(MIDTable.LR_diff_mag(criteria & strcmp(MIDTable.ROI,'MT')), MIDTable.Z3D_v_Z2D(criteria & strcmp(MIDTable.ROI,'MT'))) % sig regardless criteria
lm = fitlm(MIDTable(criteria & strcmp(MIDTable.ROI,'MT'),:), 'Z3D_v_Z2D ~ LR_diff_mag') % sig regardless criteria
lm = fitlm(MIDTable(criteria & strcmp(MIDTable.ROI,'MT'),:), 'Z3D_v_Z2D ~ LR_diff_mag + Obliqueness') % sig regardless
lme = fitlme(MIDTable(criteria & strcmp(MIDTable.ROI,'MT'),:), 'Z3D_v_Z2D ~ LR_diff_mag + (1|Monkey)') % not sig regardless criteria

[r,p] = corr(MIDTable.Z3D_v_Z2D(criteria & strcmp(MIDTable.ROI,'MT')), MIDTable.LR_diff_mag(criteria & strcmp(MIDTable.ROI,'MT')),'type','Spearman') % sig for combined only filter
lm = fitlm(MIDTable(criteria & strcmp(MIDTable.ROI,'MT'),:), 'Abs_Combined_AI ~ LR_diff_mag') % not sig regardless criteria
lme = fitlme(MIDTable(criteria & strcmp(MIDTable.ROI,'MT'),:), 'Abs_Combined_AI ~ LR_diff_mag + (1|Monkey)') % not sig regardless criteria
[r,p] = corr(MIDTable.Abs_Combined_AI(criteria & strcmp(MIDTable.ROI,'MT')), MIDTable.LR_diff_mag(criteria & strcmp(MIDTable.ROI,'MT')),'type','Spearman') % not sig regardless

% figure; hold on;
% criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 2;
% scatter(Temp1to2(1,criteria),Temp1to2(2,criteria), 60, [0 113 188]/255,'filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
% criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 4;
% scatter(Temp1to2(1,criteria),Temp1to2(2,criteria), 60, [187 20 0]/255,'filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)
% criteria = MIDTable.sig_Anova_CLR & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 1;
% scatter(Temp1to2(1,criteria),Temp1to2(2,criteria), 60, 'k','filled','MarkerFaceAlpha',1,'MarkerEdgeColor','w','MarkerEdgeAlpha',1)

% lm = fitlm(MIDTable(criteria & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 2,:), 'Z3D_v_Z2D ~ LR_diff_mag')
% lm = fitlm(MIDTable(criteria & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 2,:), 'Abs_Combined_AI ~ LR_diff_mag')
% lm = fitlm(MIDTable(criteria & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 2,:), 'Abs_Combined_AI ~ ATI_both')
% lm = fitlm(MIDTable(criteria & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 2,:), 'Z3D_v_Z2D ~ ATI_both')

fprintf(2,'\n\nFST: \n')
lm = fitlm(MIDTable(criteria & strcmp(MIDTable.ROI,'FST'),:), 'Z3D_v_Z2D ~ LR_diff_mag') % sig regardless
lm = fitlm(MIDTable(criteria & strcmp(MIDTable.ROI,'FST'),:), 'Z3D_v_Z2D ~ LR_diff_mag + Obliqueness') % sig regardless
lme = fitlme(MIDTable(criteria & strcmp(MIDTable.ROI,'FST'),:), 'Z3D_v_Z2D ~ LR_diff_mag + (1|Monkey)') % not sig regardless criteria
[r,p] = corr(MIDTable.Z3D_v_Z2D(criteria & strcmp(MIDTable.ROI,'FST')), MIDTable.LR_diff_mag(criteria & strcmp(MIDTable.ROI,'FST')),'type','Spearman') % sig regardless
lm = fitlm(MIDTable(criteria & strcmp(MIDTable.ROI,'FST'),:), 'Abs_Combined_AI ~ LR_diff_mag') % sig for CLR but not for combined only.
lme = fitlme(MIDTable(criteria & strcmp(MIDTable.ROI,'FST'),:), 'Abs_Combined_AI ~ LR_diff_mag + (1|Monkey)') % not sig regardless criteria
[r,p] = corr(MIDTable.Abs_Combined_AI(criteria & strcmp(MIDTable.ROI,'FST')), MIDTable.LR_diff_mag(criteria & strcmp(MIDTable.ROI,'FST')),'type','Spearman') % sig for CLR selectivity only



% lm = fitlm(MIDTable(criteria & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 2,:), 'Z3D_v_Z2D ~ LR_diff_mag')
% lm = fitlm(MIDTable(criteria & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 2,:), 'Abs_Combined_AI ~ LR_diff_mag')
% lm = fitlm(MIDTable(criteria & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 2,:), 'Abs_Combined_AI ~ ATI_both')
% lm = fitlm(MIDTable(criteria & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 2,:), 'Z3D_v_Z2D ~ ATI_both')
fprintf(2,'\n\nMedian Difference Magnitudes\n');
fprintf(2,'MT: %.2f\n',round(median(MIDTable.LR_diff_mag(criteria & strcmp(MIDTable.ROI,'MT'))),2));
fprintf(2,'FST: %.2f\n',round(median(MIDTable.LR_diff_mag(criteria & strcmp(MIDTable.ROI,'FST'))),2));
fprintf(2,'Rank Sum: %.2f\n',ranksum(MIDTable.LR_diff_mag(criteria & strcmp(MIDTable.ROI,'MT')),MIDTable.LR_diff_mag(criteria & strcmp(MIDTable.ROI,'FST'))));

fprintf(2,'\n\nKappas\n');
fprintf(2,'MT: %.2f\n',round(circ_kappa(deg2rad(MIDTable.LR_diff(criteria & strcmp(MIDTable.ROI,'MT')))),2));
fprintf(2,'FST: %.2f\n',round(circ_kappa(deg2rad(MIDTable.LR_diff(criteria & strcmp(MIDTable.ROI,'FST')))),2));
fprintf(2,'\n\nVariance\n');
fprintf(2,'\nMT: %.2f',round(circ_var(deg2rad(MIDTable.LR_diff(criteria & strcmp(MIDTable.ROI,'MT')))),2));
fprintf(2,'\nFST: %.2f',round(circ_var(deg2rad(MIDTable.LR_diff(criteria & strcmp(MIDTable.ROI,'FST')))),2));
fprintf(2,'\n\nVariance Test p = %0.5f\n', circ_ktest(deg2rad(MIDTable.LR_diff(criteria & strcmp(MIDTable.ROI,'MT'))), deg2rad(MIDTable.LR_diff(criteria & strcmp(MIDTable.ROI,'FST')))));
fprintf(2,'\n\nTwo Sample F-Test for equal variances:\n')
[h,p] = vartest2(MIDTable.LR_diff(criteria & strcmp(MIDTable.ROI,'MT')),MIDTable.LR_diff(criteria & strcmp(MIDTable.ROI,'FST')))

% Neurons with preferences closer to the vertical meridian would only
% require small direction preference differences between the eyes

figure; hold on;

%% Examine whether axial tuning might be due to direction preference
% differences in the two eyes
criteria = MIDTable.sig_Anova_CLR;
lm = fitlm(MIDTable(criteria & strcmp(MIDTable.ROI,'FST'),:), 'ATI_both ~ LR_diff_mag')

lm = fitlm(MIDTable(criteria & strcmp(MIDTable.ROI,'FST'),:), 'Z3D_v_Z2D ~ ATI_both')


%% CP and selectivity
criteria = MIDTable.sig_Anova2_Combined & MIDTable.ROC_sig;
sum(MIDTable.ROC_sig(criteria & strcmp(MIDTable.ROI,'MT')))
sum(MIDTable.ROC_sig(criteria & strcmp(MIDTable.ROI,'FST')))
criteria = MIDTable.sig_Anova2_Combined;
[~, p] = ttest(MIDTable.ROC(criteria & strcmp(MIDTable.ROI,'MT')),0.5)
[~, p] = ttest(MIDTable.ROC(criteria & strcmp(MIDTable.ROI,'FST')),0.5)
disp('Below')
sum(MIDTable.ROC_sig(criteria & strcmp(MIDTable.ROI,'MT') & MIDTable.ROC<0.5))
sum(MIDTable.ROC_sig(criteria & strcmp(MIDTable.ROI,'FST') & MIDTable.ROC<0.5))
disp('Above')
sum(MIDTable.ROC_sig(criteria & strcmp(MIDTable.ROI,'MT') & MIDTable.ROC>0.5))
sum(MIDTable.ROC_sig(criteria & strcmp(MIDTable.ROI,'FST') & MIDTable.ROC>0.5))

criteria = MIDTable.sig_Anova2_Combined & MIDTable.Combined_CP_sig;
sum(MIDTable.Combined_CP_sig(criteria & strcmp(MIDTable.ROI,'MT')))
sum(MIDTable.Combined_CP_sig(criteria & strcmp(MIDTable.ROI,'FST')))
criteria = MIDTable.sig_Anova2_Combined;
[~, p] = ttest(MIDTable.ROC(criteria & strcmp(MIDTable.ROI,'MT')),0.5)
[~, p] = ttest(MIDTable.ROC(criteria & strcmp(MIDTable.ROI,'FST')),0.5)

criteria = MIDTable.sig_Anova2_MonoL & MIDTable.MonoL_CP_sig;
sum(MIDTable.MonoL_CP_sig(criteria & strcmp(MIDTable.ROI,'MT')))
sum(MIDTable.MonoL_CP_sig(criteria & strcmp(MIDTable.ROI,'FST')))
criteria = MIDTable.sig_Anova2_MonoL;
[~, p] = ttest(MIDTable.ROC(criteria & strcmp(MIDTable.ROI,'MT')),0.5)
[~, p] = ttest(MIDTable.ROC(criteria & strcmp(MIDTable.ROI,'FST')),0.5)

criteria = MIDTable.sig_Anova2_MonoR & MIDTable.MonoR_CP_sig;
sum(MIDTable.MonoR_CP_sig(criteria & strcmp(MIDTable.ROI,'MT')))
sum(MIDTable.MonoR_CP_sig(criteria & strcmp(MIDTable.ROI,'FST')))
criteria = MIDTable.sig_Anova2_MonoR;
[~, p] = ttest(MIDTable.ROC(criteria & strcmp(MIDTable.ROI,'MT')),0.5)
[~, p] = ttest(MIDTable.ROC(criteria & strcmp(MIDTable.ROI,'FST')),0.5)

criteria = MIDTable.sig_Anova2_Bino & MIDTable.Bino_CP_sig;
sum(MIDTable.Bino_CP_sig(criteria & strcmp(MIDTable.ROI,'MT')))
sum(MIDTable.Bino_CP_sig(criteria & strcmp(MIDTable.ROI,'FST')))
criteria = MIDTable.sig_Anova2_Bino;
[~, p] = ttest(MIDTable.ROC(criteria & strcmp(MIDTable.ROI,'MT')),0.5)
[~, p] = ttest(MIDTable.ROC(criteria & strcmp(MIDTable.ROI,'FST')),0.5)

criteria = MIDTable.sig_Anova_CLR;
lm = fitlm(MIDTable(criteria & strcmp(MIDTable.ROI,'MT'),:), 'ROC ~ Combined_AI')
lm = fitlm(MIDTable(criteria & strcmp(MIDTable.ROI,'MT') & MIDTable.Z_quad == 2,:), 'ROC ~ Combined_AI')
lm = fitlm(MIDTable(criteria & strcmp(MIDTable.ROI,'MT'),:), 'ROC ~ Z3D_v_Z2D')

lm = fitlm(MIDTable(criteria & strcmp(MIDTable.ROI,'FST'),:), 'ROC ~ Combined_AI')
lm = fitlm(MIDTable(criteria & strcmp(MIDTable.ROI,'FST') & MIDTable.Z_quad == 2,:), 'ROC ~ Combined_AI')
lm = fitlm(MIDTable(criteria & strcmp(MIDTable.ROI,'FST'),:), 'ROC ~ Z3D_v_Z2D')


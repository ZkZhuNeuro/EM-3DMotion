
%% Plots

figure; 
subplot(5,1,1); hold on;
title('Left vs Right Perspective');
criteria = MIDTable.sig_Anova_CLR & MIDTable.Z_quad ~= 1;
histogram(MIDTable.Mono_Congruency(strcmp(MIDTable.ROI,'MT') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'Normalization','probability','FaceColor',plotOptions.AreaColors.MT,'EdgeColor','w');
h = histogram(MIDTable.Mono_Congruency(strcmp(MIDTable.ROI,'FST') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'Normalization','probability','FaceColor',plotOptions.AreaColors.FST,'EdgeColor','w');
% xlabel('Congruency Index');
ylabel('Proportion of Neurons');
xlim([-1,1]);

subplot(5,1,2); hold on;
title([{'Dominant Persp. vs Combined'}]);
criteria = MIDTable.sig_Anova2_Combined & MIDTable.sig_Anova2_Dom & MIDTable.Z_quad ~= 1;
histogram(MIDTable.DomComb_Congruency(strcmp(MIDTable.ROI,'MT') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'Normalization','probability','FaceColor',plotOptions.AreaColors.MT,'EdgeColor','w');
histogram(MIDTable.DomComb_Congruency(strcmp(MIDTable.ROI,'FST') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'Normalization','probability','FaceColor',plotOptions.AreaColors.FST,'EdgeColor','w');
% xlabel('Congruency Index');
ylabel('Proportion of Neurons');
xlim([-1,1]);

subplot(5,1,3); hold on;
title([{'Non-Dominant Persp. vs Combined'}]);
criteria = MIDTable.sig_Anova2_Combined & MIDTable.sig_Anova2_NonDom & MIDTable.Z_quad ~= 1;
histogram(MIDTable.NonDomComb_Congruency(strcmp(MIDTable.ROI,'MT') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'Normalization','probability','FaceColor',plotOptions.AreaColors.MT,'EdgeColor','w');
histogram(MIDTable.NonDomComb_Congruency(strcmp(MIDTable.ROI,'FST') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'Normalization','probability','FaceColor',plotOptions.AreaColors.FST,'EdgeColor','w');
% xlabel('Congruency Index');
ylabel('Proportion of Neurons');
xlim([-1,1]);

subplot(5,1,4); hold on;
title([{'Dominant Persp. vs Stereoscopic'}]);
criteria = MIDTable.sig_Anova2_Combined & MIDTable.sig_Anova2_Dom & MIDTable.sig_Anova2_Bino & MIDTable.Z_quad ~= 1;
histogram(MIDTable.DomBino_Congruency(strcmp(MIDTable.ROI,'MT') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'Normalization','probability','FaceColor',plotOptions.AreaColors.MT,'EdgeColor','w');
histogram(MIDTable.DomBino_Congruency(strcmp(MIDTable.ROI,'FST') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'Normalization','probability','FaceColor',plotOptions.AreaColors.FST,'EdgeColor','w');
% xlabel('Congruency Index');
ylabel('Proportion of Neurons');
xlim([-1,1]);

subplot(5,1,5); hold on;
title([{'Non-Dominant Persp. vs Stereoscopic'}]);
criteria = MIDTable.sig_Anova2_Combined & MIDTable.sig_Anova2_NonDom & MIDTable.sig_Anova2_Bino & MIDTable.Z_quad ~= 1;
histogram(MIDTable.NonDomBino_Congruency(strcmp(MIDTable.ROI,'MT') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'Normalization','probability','FaceColor',plotOptions.AreaColors.MT,'EdgeColor','w');
histogram(MIDTable.NonDomBino_Congruency(strcmp(MIDTable.ROI,'FST') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'Normalization','probability','FaceColor',plotOptions.AreaColors.FST,'EdgeColor','w');
xlabel('Congruency Index');
ylabel('Proportion of Neurons');
xlim([-1,1]);

%% Including non-significant neurons
% We mark significant congruency index values (both p<0.05 for the
% constituent correlations)
figure; 
subplot(5,2,1); hold on;
criteria = MIDTable.sig_Anova_CLR;
title('Left vs Right Perspective');
histogram(MIDTable.Mono_Congruency(strcmp(MIDTable.ROI,'MT') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'FaceColor','w','EdgeColor',plotOptions.AreaColors.MT);
criteria = MIDTable.sig_Anova2_Combined & MIDTable.MonoL_Coh_Corr_p < 0.05 & MIDTable.MonoR_Coh_Corr_p < 0.05 & MIDTable.quadrant ~= 1;
histogram(MIDTable.Mono_Congruency(strcmp(MIDTable.ROI,'MT') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'FaceColor',plotOptions.AreaColors.MT,'EdgeColor',plotOptions.AreaColors.MT);
xlim([-1,1]);
ylabel('# of Neurons');
legend({'p>0.05','p<0.05'})

subplot(5,2,2); hold on;
title('Left vs Right Perspective');
criteria = MIDTable.sig_Anova2_Combined & MIDTable.quadrant ~= 1;
histogram(MIDTable.Mono_Congruency(strcmp(MIDTable.ROI,'FST') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'FaceColor','w','EdgeColor',plotOptions.AreaColors.FST);
criteria = MIDTable.sig_Anova2_Combined & MIDTable.MonoL_Coh_Corr_p < 0.05 & MIDTable.MonoR_Coh_Corr_p < 0.05 & MIDTable.quadrant ~= 1;
histogram(MIDTable.Mono_Congruency(strcmp(MIDTable.ROI,'FST') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'FaceColor',plotOptions.AreaColors.FST,'EdgeColor',plotOptions.AreaColors.FST);
xlim([-1,1]);

subplot(5,2,3); hold on;
criteria = MIDTable.sig_Anova2_Combined & MIDTable.quadrant ~= 1;
title('Dom vs Comb ');
histogram(MIDTable.DomComb_Congruency(strcmp(MIDTable.ROI,'MT') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'FaceColor','w','EdgeColor',plotOptions.AreaColors.MT);
criteria = MIDTable.sig_Anova2_Combined & MIDTable.Dominant_Coh_Corr_p < 0.05 & MIDTable.Combined_Coh_Corr_p < 0.05 & MIDTable.quadrant ~= 1;
histogram(MIDTable.DomComb_Congruency(strcmp(MIDTable.ROI,'MT') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'FaceColor',plotOptions.AreaColors.MT,'EdgeColor',plotOptions.AreaColors.MT);
xlim([-1,1]);
ylabel('# of Neurons');

subplot(5,2,4); hold on;
title('Domb vs Comb ');
criteria = MIDTable.sig_Anova2_Combined & MIDTable.quadrant ~= 1;
histogram(MIDTable.DomComb_Congruency(strcmp(MIDTable.ROI,'FST') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'FaceColor','w','EdgeColor',plotOptions.AreaColors.FST);
criteria = MIDTable.sig_Anova2_Combined & MIDTable.Dominant_Coh_Corr_p < 0.05 & MIDTable.Combined_Coh_Corr_p < 0.05 & MIDTable.quadrant ~= 1;
histogram(MIDTable.DomComb_Congruency(strcmp(MIDTable.ROI,'FST') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'FaceColor',plotOptions.AreaColors.FST,'EdgeColor',plotOptions.AreaColors.FST);
xlim([-1,1]);

subplot(5,2,5); hold on;
criteria = MIDTable.sig_Anova2_Combined & MIDTable.quadrant ~= 1;
title('Non-Dom vs Comb ');
histogram(MIDTable.NonDomComb_Congruency(strcmp(MIDTable.ROI,'MT') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'FaceColor','w','EdgeColor',plotOptions.AreaColors.MT);
criteria = MIDTable.sig_Anova2_Combined & MIDTable.NonDominant_Coh_Corr_p < 0.05 & MIDTable.Combined_Coh_Corr_p < 0.05 & MIDTable.quadrant ~= 1;
histogram(MIDTable.NonDomComb_Congruency(strcmp(MIDTable.ROI,'MT') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'FaceColor',plotOptions.AreaColors.MT,'EdgeColor',plotOptions.AreaColors.MT);
xlim([-1,1]);
ylabel('# of Neurons');

subplot(5,2,6); hold on;
title('Non-Domb vs Comb ');
criteria = MIDTable.sig_Anova2_Combined & MIDTable.quadrant ~= 1;
histogram(MIDTable.NonDomComb_Congruency(strcmp(MIDTable.ROI,'FST') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'FaceColor','w','EdgeColor',plotOptions.AreaColors.FST);
criteria = MIDTable.sig_Anova2_Combined & MIDTable.NonDominant_Coh_Corr_p < 0.05 & MIDTable.Combined_Coh_Corr_p < 0.05 & MIDTable.quadrant ~= 1;
histogram(MIDTable.NonDomComb_Congruency(strcmp(MIDTable.ROI,'FST') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'FaceColor',plotOptions.AreaColors.FST,'EdgeColor',plotOptions.AreaColors.FST);
xlim([-1,1]); 

subplot(5,2,7); hold on;
criteria = MIDTable.sig_Anova2_Combined & MIDTable.quadrant ~= 1;
title('Dom vs Stereo');
histogram(MIDTable.DomBino_Congruency(strcmp(MIDTable.ROI,'MT') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'FaceColor','w','EdgeColor',plotOptions.AreaColors.MT);
criteria = MIDTable.sig_Anova2_Combined & MIDTable.Dominant_Coh_Corr_p < 0.05 & MIDTable.Bino_Coh_Corr_p < 0.05 & MIDTable.quadrant ~= 1;
histogram(MIDTable.DomBino_Congruency(strcmp(MIDTable.ROI,'MT') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'FaceColor',plotOptions.AreaColors.MT,'EdgeColor',plotOptions.AreaColors.MT);
xlim([-1,1]);
ylabel('# of Neurons');

subplot(5,2,8); hold on;
criteria = MIDTable.sig_Anova2_Combined & MIDTable.quadrant ~= 1;
title('Dom vs Stereo');
histogram(MIDTable.DomBino_Congruency(strcmp(MIDTable.ROI,'FST') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'FaceColor','w','EdgeColor',plotOptions.AreaColors.FST);
criteria = MIDTable.sig_Anova2_Combined & MIDTable.Dominant_Coh_Corr_p < 0.05 & MIDTable.Bino_Coh_Corr_p < 0.05 & MIDTable.quadrant ~= 1;
histogram(MIDTable.DomBino_Congruency(strcmp(MIDTable.ROI,'FST') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'FaceColor',plotOptions.AreaColors.FST,'EdgeColor',plotOptions.AreaColors.FST);
xlim([-1,1]);
ylabel('# of Neurons');

subplot(5,2,9); hold on;
criteria = MIDTable.sig_Anova2_Combined & MIDTable.quadrant ~= 1;
title('Non-Dom vs Stereo');
histogram(MIDTable.NonDomBino_Congruency(strcmp(MIDTable.ROI,'MT') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'FaceColor','w','EdgeColor',plotOptions.AreaColors.MT);
criteria = MIDTable.sig_Anova2_Combined & MIDTable.NonDominant_Coh_Corr_p < 0.05 & MIDTable.Bino_Coh_Corr_p < 0.05 & MIDTable.quadrant ~= 1;
histogram(MIDTable.NonDomBino_Congruency(strcmp(MIDTable.ROI,'MT') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'FaceColor',plotOptions.AreaColors.MT,'EdgeColor',plotOptions.AreaColors.MT);
xlim([-1,1]);
ylabel('# of Neurons');

subplot(5,2,10); hold on;
criteria = MIDTable.sig_Anova2_Combined & MIDTable.quadrant ~= 1;
title('Non-Dom vs Stereo');
histogram(MIDTable.NonDomBino_Congruency(strcmp(MIDTable.ROI,'FST') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'FaceColor','w','EdgeColor',plotOptions.AreaColors.FST);
criteria = MIDTable.sig_Anova2_Combined & MIDTable.NonDominant_Coh_Corr_p < 0.05 & MIDTable.Bino_Coh_Corr_p < 0.05 & MIDTable.quadrant ~= 1;
histogram(MIDTable.NonDomBino_Congruency(strcmp(MIDTable.ROI,'FST') & criteria),'BinWidth',0.1,'BinLimits',[-1,1],'FaceColor',plotOptions.AreaColors.FST,'EdgeColor',plotOptions.AreaColors.FST);
xlim([-1,1]);
ylabel('# of Neurons');
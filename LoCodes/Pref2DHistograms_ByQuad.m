edges = deg2rad([-11.25:22.5:(360-11.25)]); % Center bins at horizontal, oblique and vertical positions w/bin width of 22.5 deg
criteria = MIDTable.sig_Anova_CLR;
figure; 
subplot(2,3,1); 
polarhistogram(deg2rad(MIDTable.Both_Mu(MIDTable.Z_quad == 4 & criteria & strcmp(MIDTable.ROI,'MT'))),edges,'FaceColor',[187 20 0]/255,'FaceAlpha',.5)
title('MT 2D')
subplot(2,3,2); 
polarhistogram(deg2rad(MIDTable.Both_Mu(MIDTable.Z_quad == 2 & criteria & strcmp(MIDTable.ROI,'MT'))),edges,'FaceColor',[0 113 188]/255,'FaceAlpha',.5)
title('MT 3D')
subplot(2,3,3);
polarhistogram(deg2rad(MIDTable.Both_Mu(MIDTable.Z_quad == 1 & criteria & strcmp(MIDTable.ROI,'MT'))),edges,'FaceColor','k','FaceAlpha',.5)
title('MT Unclassified')
subplot(2,3,4); 
polarhistogram(deg2rad(MIDTable.Both_Mu(MIDTable.Z_quad == 4 & criteria & strcmp(MIDTable.ROI,'FST'))),edges,'FaceColor',[187 20 0]/255,'FaceAlpha',.5)
title('FST 2D')
subplot(2,3,5); 
polarhistogram(deg2rad(MIDTable.Both_Mu(MIDTable.Z_quad == 2 & criteria & strcmp(MIDTable.ROI,'FST'))),edges,'FaceColor',[0 113 188]/255,'FaceAlpha',.5)
title('FST 3D')
subplot(2,3,6);
polarhistogram(deg2rad(MIDTable.Both_Mu(MIDTable.Z_quad == 1 & criteria & strcmp(MIDTable.ROI,'FST'))),edges,'FaceColor','k','FaceAlpha',.5)
title('FST Unclassified')

%%
criteria = MIDTable.sig_Anova_CLR;
figure; 
subplot(1,2,1);
polarhistogram(deg2rad(MIDTable.Both_Mu(MIDTable.Z_quad == 4 & criteria & strcmp(MIDTable.ROI,'MT'))),edges,'FaceColor',[187 20 0]/255,'FaceAlpha',.5)
hold on;
title('MT')
polarhistogram(deg2rad(MIDTable.Both_Mu(MIDTable.Z_quad == 2 & criteria & strcmp(MIDTable.ROI,'MT'))),edges,'FaceColor',[0 113 188]/255,'FaceAlpha',.5)
% polarhistogram(deg2rad(MIDTable.Both_Mu(MIDTable.Z_quad == 1 & criteria & strcmp(MIDTable.ROI,'MT'))),edges,'FaceColor','k','FaceAlpha',.5)

subplot(1,2,2); 
polarhistogram(deg2rad(MIDTable.Both_Mu(MIDTable.Z_quad == 4 & criteria & strcmp(MIDTable.ROI,'FST'))),edges,'FaceColor',[187 20 0]/255,'FaceAlpha',.5)
hold on;
title('FST')
polarhistogram(deg2rad(MIDTable.Both_Mu(MIDTable.Z_quad == 2 & criteria & strcmp(MIDTable.ROI,'FST'))),edges,'FaceColor',[0 113 188]/255,'FaceAlpha',.5)
% polarhistogram(deg2rad(MIDTable.Both_Mu(MIDTable.Z_quad == 1 & criteria & strcmp(MIDTable.ROI,'FST'))),edges,'FaceColor','k','FaceAlpha',.5)

%%
edges = [-11.25:22.5:(360-11.25)]; % Center bins at horizontal, oblique and vertical positions w/bin width of 22.5 deg
criteria = MIDTable.sig_Anova_CLR;
figure; 
subplot(1,2,1);
histogram(MIDTable.Both_Mu(MIDTable.Z_quad == 4 & criteria & strcmp(MIDTable.ROI,'MT')),edges,'FaceColor',[187 20 0]/255,'FaceAlpha',.5)
hold on;
title('MT')
histogram(MIDTable.Both_Mu(MIDTable.Z_quad == 2 & criteria & strcmp(MIDTable.ROI,'MT')),edges,'FaceColor',[0 113 188]/255,'FaceAlpha',.5)
% polarhistogram(deg2rad(MIDTable.Both_Mu(MIDTable.Z_quad == 1 & criteria & strcmp(MIDTable.ROI,'MT'))),edges,'FaceColor','k','FaceAlpha',.5)

subplot(1,2,2); 
histogram(MIDTable.Both_Mu(MIDTable.Z_quad == 4 & criteria & strcmp(MIDTable.ROI,'FST')),edges,'FaceColor',[187 20 0]/255,'FaceAlpha',.5)
hold on;
title('FST')
histogram(MIDTable.Both_Mu(MIDTable.Z_quad == 2 & criteria & strcmp(MIDTable.ROI,'FST')),edges,'FaceColor',[0 113 188]/255,'FaceAlpha',.5)
% polarhistogram(deg2rad(MIDTable.Both_Mu(MIDTable.Z_quad == 1 & criteria & strcmp(MIDTable.ROI,'FST'))),edges,'FaceColor','k','FaceAlpha',.5)

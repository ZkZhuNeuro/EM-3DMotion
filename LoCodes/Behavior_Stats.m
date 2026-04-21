AllBeh = table();
AllBeh.Sensit = [Behavioral_Data.Combined_Sensit; Behavioral_Data.MonoL_Sensit; Behavioral_Data.MonoR_Sensit; Behavioral_Data.Bino_Sensit]; 
AllBeh.Log_Sensit = log(AllBeh.Sensit); 
AllBeh.Condition = [repelem(-3,size(Behavioral_Data,1)), repelem(1,size(Behavioral_Data,1)), repelem(1,size(Behavioral_Data,1)), repelem(1,size(Behavioral_Data,1))]'; % compares combined to the mean of the isolated conditions
% AllBeh.Condition = [repelem('c',size(Behavioral_Data,1)),
% repelem('l',size(Behavioral_Data,1)), repelem('r',size(Behavioral_Data,1)), repelem('s',size(Behavioral_Data,1))]'; % compares each isolated cue to combined 
AllBeh.Session = repmat([1:size(Behavioral_Data,1)]',4,1);
AllBeh.Eccentricity = repmat(Behavioral_Data.Eccentricity,4,1);
AllBeh.Eccentricity = AllBeh.Eccentricity - mean(AllBeh.Eccentricity);
AllBeh.Monkey = repmat(Behavioral_Data.Monkey,4,1);
AllBeh.Monkey_Coded = repelem(-0.5,size(AllBeh,1),1);
AllBeh.Monkey_Coded(strcmp(AllBeh.Monkey,'Jim')) = 0.5;
AllBeh.ROI = repmat(Behavioral_Data.ROI,4,1);
AllBeh.ROI_Coded = strcmp(AllBeh.ROI,'FST');
AllBeh.ROI_Coded = AllBeh.ROI_Coded - 0.5;

Behavioral_Data.ROI_Coded = strcmp(Behavioral_Data.ROI,'FST');
Behavioral_Data.ROI_Coded = Behavioral_Data.ROI_Coded - 0.5;

lm = fitlme(AllBeh, 'Sensit ~ 1 + ROI_Coded + Condition + Eccentricity')
lm = fitlm(AllBeh(strcmp(AllBeh.Monkey,'Jim'),:), 'Sensit ~ 1 + ROI_Coded + Condition + Eccentricity')
lm = fitlm(AllBeh(strcmp(AllBeh.Monkey,'Clay'),:), 'Sensit ~ 1 + ROI_Coded + Condition + Eccentricity')
[p,t,stats] = anovan(AllBeh.Sensit,{AllBeh.ROI, AllBeh.Monkey, AllBeh.Condition, AllBeh.Eccentricity});
lm = fitlm(AllBeh, 'Sensit ~ 1 + ROI_Coded + Monkey + Condition')
lm = fitlme(AllBeh,'Sensit ~ ROI_Coded + Condition + Eccentricity + (1|Monkey)') % Random intercept for monkey
lm = fitlme(AllBeh,'Sensit ~ ROI_Coded + Condition + Eccentricity + (1+ROI_Coded|Monkey)') % Correlated random int and ROI slopes
anova(lm) % This will give you overall effect of condition rather than separate comparisons
[B,Bnames,stats] = randomEffects(lm) % Examine the betas for the random effects as well as slope differences


% This should be the most robust
% combined vs. all others
AllBeh.Condition = [repelem(-3,size(Behavioral_Data,1)), repelem(1,size(Behavioral_Data,1)), repelem(1,size(Behavioral_Data,1)), repelem(1,size(Behavioral_Data,1))]'; % compares combined to the mean of the isolated conditions
lm = fitlme(AllBeh,'Log_Sensit ~ ROI_Coded + Condition + Eccentricity + (1+ROI_Coded|Monkey_Coded)') % Correlated random int and ROI slopes

% left vs right
AllBeh.Condition = [repelem(0,size(Behavioral_Data,1)), repelem(0.5,size(Behavioral_Data,1)), repelem(-0.5,size(Behavioral_Data,1)), repelem(0,size(Behavioral_Data,1))]'; % compares combined to the mean of the isolated conditions
lm = fitlme(AllBeh,'Log_Sensit ~ ROI_Coded + Condition + Eccentricity + (1+ROI_Coded|Monkey)') % Correlated random int and ROI slopes

% left vs stereo
AllBeh.Condition = [repelem(0,size(Behavioral_Data,1)), repelem(0.5,size(Behavioral_Data,1)), repelem(0,size(Behavioral_Data,1)), repelem(-0.5,size(Behavioral_Data,1))]'; % compares combined to the mean of the isolated conditions
lm = fitlme(AllBeh,'Log_Sensit ~ ROI_Coded + Condition + Eccentricity + (1+ROI_Coded|Monkey)') % Correlated random int and ROI slopes

% right vs stereo
AllBeh.Condition = [repelem(0,size(Behavioral_Data,1)), repelem(0,size(Behavioral_Data,1)), repelem(0.5,size(Behavioral_Data,1)), repelem(-0.5,size(Behavioral_Data,1))]'; % compares combined to the mean of the isolated conditions
lm = fitlme(AllBeh,'Log_Sensit ~ ROI_Coded + Condition + Eccentricity + (1+ROI_Coded|Monkey)') % Correlated random int and ROI slopes

% stereo vs other isolated cues
AllBeh.Condition = [repelem(0,size(Behavioral_Data,1)), repelem(-1,size(Behavioral_Data,1)), repelem(-1,size(Behavioral_Data,1)), repelem(2,size(Behavioral_Data,1))]'; % compares combined to the mean of the isolated conditions
lm = fitlme(AllBeh,'Log_Sensit ~ ROI_Coded + Condition + Eccentricity + (1+ROI_Coded|Monkey)') % Correlated random int and ROI slopes

%% Similar models for neurometric sensitivity
AllNeuroSensit = table();
AllNeuroSensit.Sensit = [MIDTable.Neuro_Combined_Sensit_Paired; MIDTable.Neuro_MonoL_Sensit_Paired; MIDTable.Neuro_MonoR_Sensit_Paired; MIDTable.Neuro_Bino_Sensit_Paired]; 
AllNeuroSensit.Log_Sensit = log(AllNeuroSensit.Sensit); 
AllNeuroSensit.Condition = [repelem(-3,size(MIDTable,1)), repelem(1,size(MIDTable,1)), repelem(1,size(MIDTable,1)), repelem(1,size(MIDTable,1))]'; % compares combined to the mean of the isolated conditions
AllNeuroSensit.Eccentricity = repmat(MIDTable.Eccentricity,4,1);
AllNeuroSensit.Eccentricity = AllNeuroSensit.Eccentricity - mean(AllNeuroSensit.Eccentricity);
AllNeuroSensit.Monkey = repmat(MIDTable.Monkey,4,1);
AllNeuroSensit.sig_CLR = repmat(MIDTable.sig_Anova_CLR,4,1);
AllNeuroSensit.Z_quad = repmat(MIDTable.Z_quad,4,1);
AllNeuroSensit.ROI = repmat(MIDTable.ROI,4,1);
AllNeuroSensit.ROI_Coded = strcmp(AllNeuroSensit.ROI,'FST');
AllNeuroSensit.ROI_Coded = AllNeuroSensit.ROI_Coded - 0.5;

% 2D MT Neurons
% combined and stereo (binocular) vs. left and right (monocular)
criteria = AllNeuroSensit.sig_CLR & AllNeuroSensit.Z_quad == 4 & strcmp(AllNeuroSensit.ROI,'MT');
AllNeuroSensit.Condition = [repelem(0.5,size(MIDTable,1)), repelem(-0.5,size(MIDTable,1)), repelem(-0.5,size(MIDTable,1)), repelem(0.5,size(MIDTable,1))]';
lm = fitlme(AllNeuroSensit(criteria,:),'Log_Sensit ~ Condition + (1+Condition|Monkey)') % Correlated random int and ROI slopes

% 2D FST neurons
criteria = AllNeuroSensit.sig_CLR & AllNeuroSensit.Z_quad == 4 & strcmp(AllNeuroSensit.ROI,'FST');
AllNeuroSensit.Condition = [repelem(0.5,size(MIDTable,1)), repelem(-0.5,size(MIDTable,1)), repelem(-0.5,size(MIDTable,1)), repelem(0.5,size(MIDTable,1))]';
lm = fitlme(AllNeuroSensit(criteria,:),'Log_Sensit ~ Condition + (1+Condition|Monkey)') % Correlated random int and ROI slopes


% 3D MT Neurons
% combined vs isolated
criteria = AllNeuroSensit.sig_CLR & AllNeuroSensit.Z_quad == 2 & strcmp(AllNeuroSensit.ROI,'MT');
AllNeuroSensit.Condition = [repelem(3,size(MIDTable,1)), repelem(-1,size(MIDTable,1)), repelem(-1,size(MIDTable,1)), repelem(-1,size(MIDTable,1))]';
lm = fitlme(AllNeuroSensit(criteria,:),'Log_Sensit ~ Condition + (1+Condition|Monkey)') % Correlated random int and ROI slopes

% left vs right
AllNeuroSensit.Condition = [repelem(0,size(MIDTable,1)), repelem(-0.5,size(MIDTable,1)), repelem(0.5,size(MIDTable,1)), repelem(0,size(MIDTable,1))]';
lm = fitlme(AllNeuroSensit(criteria,:),'Log_Sensit ~ Condition + (1+Condition|Monkey)') % Correlated random int and ROI slopes

% left vs stereo
AllNeuroSensit.Condition = [repelem(0,size(MIDTable,1)), repelem(-0.5,size(MIDTable,1)), repelem(0,size(MIDTable,1)), repelem(0.5,size(MIDTable,1))]';
lm = fitlme(AllNeuroSensit(criteria,:),'Log_Sensit ~ Condition + (1+Condition|Monkey)') % Correlated random int and ROI slopes

% right vs stereo
AllNeuroSensit.Condition = [repelem(0,size(MIDTable,1)), repelem(0,size(MIDTable,1)), repelem(-0.5,size(MIDTable,1)), repelem(0.5,size(MIDTable,1))]';
lm = fitlme(AllNeuroSensit(criteria,:),'Log_Sensit ~ Condition + (1+Condition|Monkey)') % Correlated random int and ROI slopes

% 3D FST neurons
% combined vs isolated
criteria = AllNeuroSensit.sig_CLR & AllNeuroSensit.Z_quad == 2 & strcmp(AllNeuroSensit.ROI,'FST');
AllNeuroSensit.Condition = [repelem(3,size(MIDTable,1)), repelem(-1,size(MIDTable,1)), repelem(-1,size(MIDTable,1)), repelem(-1,size(MIDTable,1))]';
lm = fitlme(AllNeuroSensit(criteria,:),'Log_Sensit ~ Condition + (1+Condition|Monkey)') % Correlated random int and ROI slopes

% left vs right
AllNeuroSensit.Condition = [repelem(0,size(MIDTable,1)), repelem(-0.5,size(MIDTable,1)), repelem(0.5,size(MIDTable,1)), repelem(0,size(MIDTable,1))]';
lm = fitlme(AllNeuroSensit(criteria,:),'Log_Sensit ~ Condition + (1+Condition|Monkey)') % Correlated random int and ROI slopes

% left vs stereo
AllNeuroSensit.Condition = [repelem(0,size(MIDTable,1)), repelem(-0.5,size(MIDTable,1)), repelem(0,size(MIDTable,1)), repelem(0.5,size(MIDTable,1))]';
lm = fitlme(AllNeuroSensit(criteria,:),'Log_Sensit ~ Condition + (1+Condition|Monkey)') % Correlated random int and ROI slopes

% right vs stereo
AllNeuroSensit.Condition = [repelem(0,size(MIDTable,1)), repelem(0,size(MIDTable,1)), repelem(-0.5,size(MIDTable,1)), repelem(0.5,size(MIDTable,1))]';
lm = fitlme(AllNeuroSensit(criteria,:),'Log_Sensit ~ Condition + (1+Condition|Monkey)') % Correlated random int and ROI slopes
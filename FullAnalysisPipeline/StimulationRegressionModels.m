% StimulationRegressionModels
% The general form of the model proposed in the R01 is:
% delta_mu ~ b0 + b1*AI + b2*C + b3*wCI + b4*AI*C + b5*wCI*C
BiasTable.Coded_Condition = zeros(size(BiasTable,1),1);
BiasTable.Coded_Condition(BiasTable.Condition == 1 | BiasTable.Condition == 2 | BiasTable.Condition == 3) = 1; % Contrast code that sums to 0 and specifically compares non-dominant with others
BiasTable.Coded_Condition(BiasTable.Condition == 4) = -3;
BiasTable.Signed_Monocularity = sign(BiasTable.AI).*BiasTable.Abs_Monocularity;

fprintf(2,['\n\n',BiasTable.ROI{1}, ' 2D\n\n'])
criteria = BiasTable.anova2_Combined < 0.05;
temp_table = BiasTable(criteria,:);
% lm = fitlme(temp_table(temp_table.Z3D_v_Z2D < 0,:),'DeltaBias ~ AI*Condition + Stim_Ecc + (1|Session)') % Note that 1 = dominant, 2 = combined, 3 = stereo, 4 = non-dominant
% anova(lm)

fprintf(2,['\n\n',BiasTable.ROI{1}, ' 2D Coded Condition\n\n'])
lm = fitlme(temp_table(temp_table.Z3D_v_Z2D < 0,:),'DeltaBias ~ AI*Coded_Condition + Stim_Ecc + (1|Session)')
anova(lm)

% if sum(temp_table.Z_quad == 2)>0
%     fprintf(2,['\n\n',BiasTable.ROI{1}, ' 3D\n\n'])
%     temp_table = BiasTable(criteria,:);
%     lm = fitlme(temp_table(temp_table.Z3D_v_Z2D > 0,:),'DeltaBias ~ AI*Condition + Stim_Ecc + (1|Session)') % Note that 1 = dominant, 2 = combined, 3 = stereo, 4 = non-dominant
%     anova(lm)
    
    fprintf(2,['\n\n',BiasTable.ROI{1}, ' 3D Coded Condition\n\n'])
    lm = fitlme(temp_table(temp_table.Z3D_v_Z2D > 0,:),'DeltaBias ~ AI*Coded_Condition + Stim_Ecc + (1|Session)')
    anova(lm)
% end

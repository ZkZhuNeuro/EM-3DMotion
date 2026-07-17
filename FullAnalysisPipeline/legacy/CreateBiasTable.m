BiasTable = table();
for rec = 1:size(MIDTable,1)

BiasTable = [BiasTable;
        array2table([MIDTable.Dominant_AI(rec), MIDTable.Dominant_Delta(rec), 1, MIDTable.wCI_Dominant(rec), abs(MIDTable.Monocularity(rec)), rec, MIDTable.Stim_Ecc(rec), MIDTable.Z_quad(rec), MIDTable.Z_3D(rec)-MIDTable.Z_2D(rec);...
        MIDTable.Combined_AI(rec), MIDTable.Delta_Mu_Combined(rec), 2, MIDTable.wCI_Combined(rec), abs(MIDTable.Monocularity(rec)), rec, MIDTable.Stim_Ecc(rec), MIDTable.Z_quad(rec), MIDTable.Z_3D(rec)-MIDTable.Z_2D(rec);...
        MIDTable.Stereo_AI(rec), MIDTable.Delta_Mu_Stereo(rec), 3, MIDTable.wCI_Stereo(rec), abs(MIDTable.Monocularity(rec)), rec, MIDTable.Stim_Ecc(rec), MIDTable.Z_quad(rec), MIDTable.Z_3D(rec)-MIDTable.Z_2D(rec);...
        MIDTable.Non_Dominant_AI(rec), MIDTable.Non_Dominant_Delta(rec), 4, MIDTable.wCI_NonDominant(rec), abs(MIDTable.Monocularity(rec)), rec, MIDTable.Stim_Ecc(rec), MIDTable.Z_quad(rec), MIDTable.Z3D_v_Z2D(rec)],...
        'VariableNames', {'AI','DeltaBias','Condition','wCI','Abs_Monocularity', 'Session','Stim_Ecc', 'Z_quad','Z3D_v_Z2D'})]; 
    
end
BiasTable.ROI = repelem(MIDTable.ROI,4,1);
BiasTable.anova2_Combined = repelem(MIDTable.anova2_Combined,4,1);
BiasTable.anova2_MonoL = repelem(MIDTable.anova2_MonoL,4,1);
BiasTable.anova2_MonoR = repelem(MIDTable.anova2_MonoR,4,1);
BiasTable.anova2_Stereo = repelem(MIDTable.anova2_Stereo,4,1);
BiasTable.sig_Anova2_All = BiasTable.anova2_Combined < 0.05 & BiasTable.anova2_MonoL<0.05 & BiasTable.anova2_MonoR < 0.05 & BiasTable.anova2_Stereo<0.05;
BiasTable.sig_Anova2_CLR = BiasTable.anova2_Combined < 0.05 & BiasTable.anova2_MonoL<0.05 & BiasTable.anova2_MonoR < 0.05;
BiasTable.Z_CvR_v_Z_CvL = repelem(MIDTable.Z_CvR_v_Z_CvL, 4, 1);

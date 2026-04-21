%% Updated Batch3DMotionEyeDataExtraction
% This loads trial-based eye data (vergence specifically) for each session already saved from
% Offline_3DMotion_update. Then, tests for effects of vergence and whether
% its impact on FR depends on motion direction

%% (2) Extract eye data for each session
n = 0;
previous = {'a'};
plotFlag = 0;
for ith_unit = 1:size(MIDTable,1)
    disp(['Extracting eye data: ' num2str(ith_unit) '/' num2str(size(MIDTable,1))]);
    f = MIDTable.Folder_Index(ith_unit);
    selected_unit = MIDTable.Unit(ith_unit);
    name = extractBefore(MIDTable.Names(ith_unit),'_3D');
    name = strrep(name,'-','_');
    data_location = fullfile('C:',MIDTable.Monkey(ith_unit),'In_Processing',MIDTable.ROI(ith_unit),'TrialBased',name);
    new = strcmp(name,previous);
    if ~new
        % Only reload if necessary
        clear AnaData;
        AnaData = load([data_location{:},'.mat']);
        AnaData = AnaData.(name{:});
        % Now extract combined-cue trials
        AnaData = AnaData(arrayfun(@(x) x.Condition,AnaData) == 1);
        % Compute mean vergence
        mean_vergence = arrayfun(@(x) mean(x.vergence),AnaData);
        % Extract direction
        Direction = arrayfun(@(x) x.Direction,AnaData);
        % Extract coherence
        Coh = arrayfun(@(x) x.Coherence,AnaData);
        Abs_Coh = abs(Coh);
    end
    previous = name;

    % Extract FR
    FR = arrayfun(@(x) x.RawFR(selected_unit),AnaData);
    
    temp_table = array2table([FR; mean_vergence; Direction; Coh; Abs_Coh]','VariableNames',{'FR','vergence','direction','coherence','unsigned_coh'});
    temp_table = temp_table(temp_table.coherence ~= 0,:); % 0% coherence trials don't have a direction
    
    lm = fitlm(temp_table,'FR~direction + coherence + vergence'); % Does vergence impact firing rate?
    a = anova(lm);
    
    lm_int = fitlm(temp_table,'FR~direction*vergence + unsigned_coh'); % Does the effect of vergence on firing rate DEPEND on motion direction (is there an interaction)?
    a_int = anova(lm_int);
    
    % here, coherence will be highly co-linear with direction, so I don't
    % think it is appropriate and will be misleading
    lm_int_signedCoh = fitlm(temp_table,'FR~direction*vergence + coherence'); % Does the effect of vergence on firing rate DEPEND on motion direction (is there an interaction)?
    a_int_signedCoh = anova(lm_int_signedCoh);
    
    lm_int_VergCoh = fitlm(temp_table,'FR~vergence*coherence'); % Does the effect of vergence on firing rate DEPEND on motion direction (is there an interaction)?
    a_int_VergCoh = anova(lm_int_VergCoh);
    
    MIDTable.anova_verg_p(ith_unit) = a.pValue(1);
    MIDTable.anova_verg_int_p(ith_unit) = a_int.pValue(4); % I think this is the most appropriate
    MIDTable.anova_verg_int_direction_p(ith_unit) = a_int.pValue(2); % Check if direction is still significant
    MIDTable.anova_verg_signedCoh_int_p(ith_unit) = a_int_signedCoh.pValue(4); % I think this is colinear and not appropriate
    MIDTable.anova_verg_signedCoh_int_direction_p(ith_unit) = a_int_signedCoh.pValue(2); % Check if direction is still significant
    MIDTable.anova_verg_coh_int_p(ith_unit) = a_int_VergCoh.pValue(3); % This should remove the confound potentially
    MIDTable.anova_verg_coh_int_direction_p(ith_unit) = a_int_VergCoh.pValue(2);
end

fprintf('\nMT: Previous significant combined-cue: %i/%i\n',sum(MIDTable.sig_Anova2_Combined & strcmp(MIDTable.ROI,'MT')),sum(strcmp(MIDTable.ROI,'MT')))
fprintf('\nMT: Still significant combined-cue: %i/%i\n',sum(MIDTable.sig_Anova2_Combined & strcmp(MIDTable.ROI,'MT') & MIDTable.anova_verg_int_direction_p<0.05),...
    sum(MIDTable.sig_Anova2_Combined & strcmp(MIDTable.ROI,'MT')))
fprintf('\nMT: Vergence interaction significant combined-cue: %i/%i\n',sum(strcmp(MIDTable.ROI,'MT') & MIDTable.anova_verg_int_p<0.05),...
    sum(strcmp(MIDTable.ROI,'MT') & MIDTable.sig_Anova2_Combined))

fprintf('\nFST: Previous significant combined-cue: %i/%i\n',sum(MIDTable.sig_Anova2_Combined & strcmp(MIDTable.ROI,'FST')),sum(strcmp(MIDTable.ROI,'FST')))
fprintf('\nFST: Still significant combined-cue: %i/%i\n',sum(MIDTable.sig_Anova2_Combined & strcmp(MIDTable.ROI,'FST') & MIDTable.anova_verg_int_direction_p<0.05),...
    sum(MIDTable.sig_Anova2_Combined & strcmp(MIDTable.ROI,'FST')))
fprintf('\nFST: Vergence interaction significant combined-cue: %i/%i\n',sum(strcmp(MIDTable.ROI,'FST') & MIDTable.anova_verg_int_p<0.05),...
    sum(strcmp(MIDTable.ROI,'FST') & MIDTable.sig_Anova2_Combined))


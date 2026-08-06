function report = diagnose_dominant_eye_alignment(outputFile)
%DIAGNOSE_DOMINANT_EYE_ALIGNMENT Compare stored and reconstructed OD signs.

arguments
    outputFile (1,:) char = fullfile(fileparts(mfilename('fullpath')), ...
        'FisherDecoderResults','DominantEyeAlignmentAudit.csv')
end

s = load('C:\LoData\NeuroRespUnitTable.mat','NeuroRespUnitTable');
m = load('C:\LoData\MIDTable.mat','MIDTable');
responseTable = s.NeuroRespUnitTable;
T = m.MIDTable;
assert(height(responseTable)==height(T), ...
    'Response and current MID tables have different heights.');
alignment = datetime(responseTable.Date)==datetime(T.Date) & ...
    strcmp(string(responseTable.ROI),string(T.ROI)) & ...
    responseTable.Unit==T.Unit;
assert(all(alignment),'Response and current MID tables are not row-aligned.');

required = {'Monkey','ROI','Monocularity_Aligned', ...
    'sig_Anova_CLR','sig_Anova2_Combined','sig_Anova2_MonoL', ...
    'sig_Anova2_MonoR','Z_quad'};
missing = setdiff(required,T.Properties.VariableNames);
assert(isempty(missing),'NeuroRespUnitTable is missing %s',strjoin(missing,', '));

reconstructed = NaN(height(T),1);
leftMaximum = NaN(height(T),1);
rightMaximum = NaN(height(T),1);
for row = 1:height(T)
    response = responseTable.NeuroResp{row};
    meanResponse = mean(response,3,'omitnan');
    leftMaximum(row) = max(meanResponse(2,:),[],'omitnan');
    rightMaximum(row) = max(meanResponse(3,:),[],'omitnan');
    denominator = leftMaximum(row) + rightMaximum(row);
    if isfinite(denominator) && denominator ~= 0
        reconstructed(row) = (rightMaximum(row)-leftMaximum(row))/denominator;
    end
end

stored = T.Monocularity_Aligned;
valid = isfinite(stored) & isfinite(reconstructed) & stored~=0 & reconstructed~=0;
signMatch = sign(stored)==sign(reconstructed);
twoD = logical(T.sig_Anova_CLR) & T.Z_quad==4;
threeD = logical(T.sig_Anova_CLR) & T.Z_quad==2;
twoDOnly = ~logical(T.sig_Anova2_Combined) & ...
    logical(T.sig_Anova2_MonoL) & logical(T.sig_Anova2_MonoR) & T.Z_quad==4;
population = strings(height(T),1);
population(twoD) = "2D";
population(threeD) = "3D";
population(twoDOnly) = "2Donly";
keep = population~="";

dominantEye = repmat("Undefined",height(T),1);
dominantEye(stored>0) = "Right";
dominantEye(stored<0) = "Left";
originalDominantCondition = NaN(height(T),1);
originalDominantCondition(stored>0) = 3; % original condition 3 = MonoR
originalDominantCondition(stored<0) = 2; % original condition 2 = MonoL
decoderCondition2Maximum = leftMaximum;
decoderCondition3Maximum = rightMaximum;
rightDominant = stored>0;
decoderCondition2Maximum(rightDominant) = rightMaximum(rightDominant);
decoderCondition3Maximum(rightDominant) = leftMaximum(rightDominant);
postSwapDominantGreaterOrEqual = decoderCondition2Maximum >= decoderCondition3Maximum;

report = table((1:height(T))',string(T.Monkey),string(T.ROI),T.Tetrode,T.Unit, ...
    population,leftMaximum,rightMaximum,stored,reconstructed,valid,signMatch, ...
    dominantEye,originalDominantCondition,decoderCondition2Maximum, ...
    decoderCondition3Maximum,postSwapDominantGreaterOrEqual, ...
    'VariableNames',{'MIDTableRow','Monkey','ROI','Tetrode','Unit', ...
    'Population','OriginalCondition2MonoLMaximum','OriginalCondition3MonoRMaximum', ...
    'StoredAlignedOD','ReconstructedAlignedOD','Valid','SignMatch', ...
    'DominantEye','OriginalDominantCondition','DecoderCondition2DominantMaximum', ...
    'DecoderCondition3NonDominantMaximum','PostSwapDominantGreaterOrEqual'});
report = report(keep,:);
writetable(report,outputFile);

fprintf('Dominant-eye alignment audit\n');
groups = unique(report(:,{'Monkey','ROI','Population'}),'rows');
for groupIndex = 1:height(groups)
    rows = report.Monkey==groups.Monkey(groupIndex) & ...
        report.ROI==groups.ROI(groupIndex) & ...
        report.Population==groups.Population(groupIndex) & report.Valid;
    fprintf('%s %s %s: N=%d, sign matches=%d (%.1f%%), mismatches=%d\n', ...
        groups.Monkey(groupIndex),groups.ROI(groupIndex), ...
        groups.Population(groupIndex),nnz(rows),nnz(report.SignMatch(rows)), ...
        100*mean(report.SignMatch(rows)),nnz(~report.SignMatch(rows)));
end
fprintf('Overall valid N=%d, sign matches=%d (%.1f%%)\n', ...
    nnz(report.Valid),nnz(report.SignMatch & report.Valid), ...
    100*mean(report.SignMatch(report.Valid)));
fprintf(['After applying the decoder swap: condition 2 has the dominant-eye ' ...
    'maximum in %d/%d neurons (%.1f%%).\n'], ...
    nnz(report.PostSwapDominantGreaterOrEqual & report.Valid),nnz(report.Valid), ...
    100*mean(report.PostSwapDominantGreaterOrEqual(report.Valid)));
assert(all(report.SignMatch(report.Valid)), ...
    'At least one stored dominant-eye sign disagrees with the responses.');
assert(all(report.PostSwapDominantGreaterOrEqual(report.Valid)), ...
    'At least one decoder condition 2 response is not the dominant eye.');
end

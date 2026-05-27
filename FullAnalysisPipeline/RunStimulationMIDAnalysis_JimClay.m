%% Build MIDTable and run stimulation tuning analysis for Jim and Clay
clearvars -except sessionLimitPerMonkey analysisSessionIndices runSummaryPlots saveAnalysisOutput analysisOutputPath showPipelineWarnings savePipelineFigures

if ~exist('sessionLimitPerMonkey', 'var')
    sessionLimitPerMonkey = inf;
end

if ~exist('analysisSessionIndices', 'var')
    analysisSessionIndices = [];
end

if ~exist('runSummaryPlots', 'var')
    runSummaryPlots = false;
end

if ~exist('saveAnalysisOutput', 'var')
    saveAnalysisOutput = false;
end

if ~exist('analysisOutputPath', 'var')
    analysisOutputPath = 'C:\EM\MIDTable_MUAStim_JimClay_Analysis.mat';
end

if ~exist('showPipelineWarnings', 'var')
    showPipelineWarnings = false;
end

if ~exist('savePipelineFigures', 'var')
    savePipelineFigures = false;
end

colorsteps = [0 0 0;...
    0 0 255;...
    5 150 5;...
    234 0 233;
    0 100 255;...
    0 255 100]./255;

conditionNames = {'Combined','MonoL','MonoR','Stereo'};
CoherenceArray = [-22 -14 -10 -8 -4 -2 2 4 8 10 14 22]./22;
AnovaCoherenceArray = [-22 -14 -10 -8 8 10 14 22]./22;
ChannelMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10];
Distance = 0:50:50*(length(ChannelMap)-1);

run('BuildMIDTable_MUAStim_JimClay.m');

if isempty(MIDTable)
    error('MIDTable is empty. No sessions are available to analyze.');
end

if isempty(analysisSessionIndices)
    analysisSessionIndices = 1:height(MIDTable);
else
    analysisSessionIndices = analysisSessionIndices(:)';
    analysisSessionIndices = analysisSessionIndices(analysisSessionIndices >= 1 & analysisSessionIndices <= height(MIDTable));
end

if isempty(analysisSessionIndices)
    error('No valid analysis session indices were selected.');
end

MIDTable = initializeAnalysisColumns(MIDTable);
MIDTable.AnalysisStatus(:) = {'NotSelected'};
MIDTable.AnalysisMessage(:) = {''};
MIDTable.AnalysisStatus(analysisSessionIndices) = {'Pending'};

FailedSessions = table();

for rec = analysisSessionIndices
    safeDisplay(sprintf('Analyzing %s session %d/%d: %s, StimElec %d', ...
        MIDTable.Monkey{rec}, rec, height(MIDTable), datestr(MIDTable.Date(rec), 'yyyy-mm-dd'), MIDTable.StimElec(rec)));
    warningState = warning;
    warningCleanup = onCleanup(@() warning(warningState)); %#ok<NASGU>
    if ~showPipelineWarnings
        warning('off', 'all');
    end
    try
        [AI(rec,:,:), CI(rec,:), R(rec,:), Monocularity(rec), Eye(rec,:), Eye_AI(rec,:), ...
            delta_bias(rec,:), Neuro(rec), LFP_Data(rec), BehaviorData(rec), Sensits(rec)] = ...
            Stimulation_ClusteringIndexPipeline( ...
            MIDTable.Monkey{rec}, MIDTable.Paths(rec), MIDTable.Names(rec,:), ...
            MIDTable.QuickNames(rec,:), MIDTable.Names_2D(rec,:), MIDTable.StimElec(rec), savePipelineFigures);
        MIDTable.AnalysisStatus(rec) = {'Success'};
        MIDTable.AnalysisMessage(rec) = {''};
    catch ME
        FailedSessions = appendFailedSession(FailedSessions, MIDTable, rec, ME);
        MIDTable.AnalysisStatus(rec) = {'Failed'};
        MIDTable.AnalysisMessage(rec) = {ME.message};
        safeDisplay(sprintf('Failed %s %s: %s', MIDTable.Monkey{rec}, ...
            datestr(MIDTable.Date(rec), 'yyyy-mm-dd'), ME.message));
        continue
    end

    close all
end

successfulMask = false(height(MIDTable), 1);
successfulMask(analysisSessionIndices) = true;
if exist('FailedSessions', 'var') && ~isempty(FailedSessions)
    successfulMask(FailedSessions.SessionIndex) = false;
end

successfulSessions = find(successfulMask);
for rec = successfulSessions'
    MIDTable = computeSessionMetrics(MIDTable, rec, AI, CI, R, Monocularity, Eye, delta_bias, BehaviorData, Neuro, CoherenceArray, AnovaCoherenceArray, conditionNames);
    if runSummaryPlots
        generateSessionSummaryPlot(MIDTable, rec, AI, CI, R, Eye, delta_bias, Neuro, BehaviorData, colorsteps, ChannelMap, Distance);
    end
end

AnalysisIssueTable = buildAnalysisIssueTable(SkippedSessions, FailedSessions);

safeDisplay(sprintf('Completed %d analyzed sessions.', numel(successfulSessions)));
if ~isempty(FailedSessions)
    safeDisplay(sprintf('There were %d failed sessions.', height(FailedSessions)));
end
if ~isempty(AnalysisIssueTable)
    safeDisplay(sprintf('Recorded %d skipped/failed session issues.', height(AnalysisIssueTable)));
end

if saveAnalysisOutput
    save(analysisOutputPath, 'MIDTable', 'SkippedSessions', 'FailedSessions', 'AnalysisIssueTable', ...
        'AI', 'CI', 'R', 'Monocularity', 'Eye', 'Eye_AI', 'delta_bias', ...
        'Neuro', 'LFP_Data', 'BehaviorData', 'Sensits', '-v7.3');
    safeDisplay(sprintf('Saved analysis output to %s', analysisOutputPath));
end

function MIDTable = computeSessionMetrics(MIDTable, rec, AI, CI, R, Monocularity, Eye, delta_bias, BehaviorData, Neuro, CoherenceArray, AnovaCoherenceArray, conditionNames)
anovaIndices = find(ismember(round(CoherenceArray, 2), round(AnovaCoherenceArray, 2)));
for cond = 1:4
    valid_coherence = find(Neuro(rec).Trials.NumTrials(1,:) > 0);
    anova_table = table();
    for c = anovaIndices
        temp_tbl = table();
        if ismember(c, valid_coherence)
            temp = squeeze(Neuro(rec).All(cond,c,1:Neuro(rec).Trials.NumTrials(cond,c),MIDTable.StimElec(rec)));
            coh = repelem(CoherenceArray(c), length(temp), 1);
            temp_tbl = array2table([temp(:), coh(:)], 'VariableNames', {'FR','Coherence'});
        end
        anova_table = [anova_table; temp_tbl]; %#ok<AGROW>
    end
    anova_table.Abs_Coherence = abs(anova_table.Coherence);
    anova_table.Direction = sign(anova_table.Coherence);
    lm = fitlm(anova_table, 'FR ~ Abs_Coherence + Direction');
    anova_results = anova(lm);
    MIDTable.(['anova2_', conditionNames{cond}])(rec) = anova_results.pValue(2);
end

MIDTable.wCI(rec) = sum(CI(rec,:).*R(rec).All);
MIDTable.wCI_Combined(rec) = sum(CI(rec,:).*R(rec).Comb);
MIDTable.wCI_MonoL(rec) = sum(CI(rec,:).*R(rec).MonoL);
MIDTable.wCI_MonoR(rec) = sum(CI(rec,:).*R(rec).MonoR);
MIDTable.wCI_Stereo(rec) = sum(CI(rec,:).*R(rec).Stereo);

MIDTable.Combined_AI(rec) = AI(rec,1,MIDTable.StimElec(rec));
MIDTable.MonoL_AI(rec) = AI(rec,2,MIDTable.StimElec(rec));
MIDTable.MonoR_AI(rec) = AI(rec,3,MIDTable.StimElec(rec));
MIDTable.Stereo_AI(rec) = AI(rec,4,MIDTable.StimElec(rec));

MIDTable.Monocularity(rec) = Monocularity(rec).Max(MIDTable.StimElec(rec));
MIDTable.Monocularity_AI(rec) = Monocularity(rec).AI(MIDTable.StimElec(rec));
MIDTable.Monocularity_AI_2D(rec) = Monocularity(rec).AI_2D(MIDTable.StimElec(rec));
MIDTable.Monocularity_mean(rec) = Monocularity(rec).Mean(MIDTable.StimElec(rec));
MIDTable.Eye{rec} = Eye(rec,MIDTable.StimElec(rec));

MIDTable.Delta_Mu_Combined(rec) = delta_bias(rec,1);
MIDTable.Delta_Mu_MonoL(rec) = delta_bias(rec,2);
MIDTable.Delta_Mu_MonoR(rec) = delta_bias(rec,3);
MIDTable.Delta_Mu_Stereo(rec) = delta_bias(rec,4);

MIDTable.Combined_Sensit_NoStim(rec) = 1./BehaviorData(rec).NoStim.pFitVals(2,1);
MIDTable.Combined_Sensit_Stim(rec) = 1./BehaviorData(rec).Stim.pFitVals(2,1);
MIDTable.MonoL_Sensit_NoStim(rec) = 1./BehaviorData(rec).NoStim.pFitVals(2,2);
MIDTable.MonoL_Sensit_Stim(rec) = 1./BehaviorData(rec).Stim.pFitVals(2,2);
MIDTable.MonoR_Sensit_NoStim(rec) = 1./BehaviorData(rec).NoStim.pFitVals(2,3);
MIDTable.MonoR_Sensit_Stim(rec) = 1./BehaviorData(rec).Stim.pFitVals(2,3);
MIDTable.Stereo_Sensit_NoStim(rec) = 1./BehaviorData(rec).NoStim.pFitVals(2,4);
MIDTable.Stereo_Sensit_Stim(rec) = 1./BehaviorData(rec).Stim.pFitVals(2,4);

MIDTable.Delta_Sensit_Combined(rec) = MIDTable.Combined_Sensit_NoStim(rec) - MIDTable.Combined_Sensit_Stim(rec);
MIDTable.Delta_Sensit_MonoL(rec) = MIDTable.MonoL_Sensit_NoStim(rec) - MIDTable.MonoL_Sensit_Stim(rec);
MIDTable.Delta_Sensit_MonoR(rec) = MIDTable.MonoR_Sensit_NoStim(rec) - MIDTable.MonoR_Sensit_Stim(rec);
MIDTable.Delta_Sensit_Stereo(rec) = MIDTable.Stereo_Sensit_NoStim(rec) - MIDTable.Stereo_Sensit_Stim(rec);

if strcmp(MIDTable.Eye{rec}, 'R')
    MIDTable.Dominant_AI(rec) = MIDTable.MonoR_AI(rec);
    MIDTable.Non_Dominant_AI(rec) = MIDTable.MonoL_AI(rec);
    MIDTable.Dominant_Delta(rec) = MIDTable.Delta_Mu_MonoR(rec);
    MIDTable.Non_Dominant_Delta(rec) = MIDTable.Delta_Mu_MonoL(rec);
    MIDTable.wCI_Dominant(rec) = MIDTable.wCI_MonoR(rec);
    MIDTable.wCI_NonDominant(rec) = MIDTable.wCI_MonoL(rec);
else
    MIDTable.Dominant_AI(rec) = MIDTable.MonoL_AI(rec);
    MIDTable.Non_Dominant_AI(rec) = MIDTable.MonoR_AI(rec);
    MIDTable.Dominant_Delta(rec) = MIDTable.Delta_Mu_MonoL(rec);
    MIDTable.Non_Dominant_Delta(rec) = MIDTable.Delta_Mu_MonoR(rec);
    MIDTable.wCI_Dominant(rec) = MIDTable.wCI_MonoL(rec);
    MIDTable.wCI_NonDominant(rec) = MIDTable.wCI_MonoR(rec);
end

MIDTable.Stim_Ecc(rec) = sqrt(sum(MIDTable.StimLoc(rec,:).^2));
end

function MIDTable = initializeAnalysisColumns(MIDTable)
numericColumns = { ...
    'anova2_Combined','anova2_MonoL','anova2_MonoR','anova2_Stereo', ...
    'wCI','wCI_Combined','wCI_MonoL','wCI_MonoR','wCI_Stereo', ...
    'Combined_AI','MonoL_AI','MonoR_AI','Stereo_AI', ...
    'Monocularity','Monocularity_AI','Monocularity_AI_2D','Monocularity_mean', ...
    'Delta_Mu_Combined','Delta_Mu_MonoL','Delta_Mu_MonoR','Delta_Mu_Stereo', ...
    'Combined_Sensit_NoStim','Combined_Sensit_Stim', ...
    'MonoL_Sensit_NoStim','MonoL_Sensit_Stim', ...
    'MonoR_Sensit_NoStim','MonoR_Sensit_Stim', ...
    'Stereo_Sensit_NoStim','Stereo_Sensit_Stim', ...
    'Delta_Sensit_Combined','Delta_Sensit_MonoL','Delta_Sensit_MonoR','Delta_Sensit_Stereo', ...
    'Dominant_AI','Non_Dominant_AI','Dominant_Delta','Non_Dominant_Delta', ...
    'wCI_Dominant','wCI_NonDominant','Stim_Ecc'};

for iCol = 1:numel(numericColumns)
    MIDTable.(numericColumns{iCol}) = nan(height(MIDTable), 1);
end

MIDTable.Eye = repmat({''}, height(MIDTable), 1);
MIDTable.AnalysisStatus = repmat({''}, height(MIDTable), 1);
MIDTable.AnalysisMessage = repmat({''}, height(MIDTable), 1);
end

function generateSessionSummaryPlot(MIDTable, rec, AI, CI, R, Eye, delta_bias, Neuro, BehaviorData, colorsteps, ChannelMap, Distance)
stim_idx = find(ChannelMap == MIDTable.StimElec(rec));

figure; hold on;
set(gcf, 'renderer', 'Painters')

subplot(2,2,1); hold on;
AI_over_distance(ChannelMap, Distance, stim_idx, squeeze(CI(rec,:)), squeeze(AI(rec,:,:)), R(rec))

subplot(2,2,2); hold on;
plot3DMotionTuning_Stim(Neuro(rec), MIDTable.StimElec(rec))
title(['Date: ', datestr(MIDTable.Date(rec)), ' Channel: ', num2str(MIDTable.StimElec(rec))]);

text(1.02,1,{['AI: ', num2str(round(MIDTable.Combined_AI(rec),2))]},'Color',colorsteps(1,:),'Units','Normalized','FontWeight','bold');
text(1.02,0.9,{['AI: ', num2str(round(MIDTable.MonoL_AI(rec),2))]},'Color',colorsteps(2,:),'Units','Normalized','FontWeight','bold');
text(1.02,0.8,{['AI: ', num2str(round(MIDTable.MonoR_AI(rec),2))]},'Color',colorsteps(3,:),'Units','Normalized','FontWeight','bold');
text(1.02,0.7,{['AI: ', num2str(round(MIDTable.Stereo_AI(rec),2))]},'Color',colorsteps(4,:),'Units','Normalized','FontWeight','bold');

subplot(2,2,3); hold on;
pFitResult = BehaviorData(rec).NoStim.pFitResult;
plotBehavior_Stim(pFitResult)
title('Non-Stimulation Trials');

subplot(2,2,4); hold on;
pFitResult = BehaviorData(rec).Stim.pFitResult;
plotBehavior_Stim(pFitResult)
title('Stimulation Trials');

text(1.02,1,{['\Delta\mu: ', num2str(round(MIDTable.Delta_Mu_Combined(rec),2))]},'Color',colorsteps(1,:),'Units','Normalized','FontWeight','bold');
text(1.02,0.9,{['\Delta\mu: ', num2str(round(MIDTable.Delta_Mu_MonoL(rec),2))]},'Color',colorsteps(2,:),'Units','Normalized','FontWeight','bold');
text(1.02,0.8,{['\Delta\mu: ', num2str(round(MIDTable.Delta_Mu_MonoR(rec),2))]},'Color',colorsteps(3,:),'Units','Normalized','FontWeight','bold');
text(1.02,0.7,{['\Delta\mu: ', num2str(round(MIDTable.Delta_Mu_Stereo(rec),2))]},'Color',colorsteps(4,:),'Units','Normalized','FontWeight','bold');
text(1.02,0.6,{[Eye(rec,MIDTable.StimElec(rec)), ' Eye Dom.']});

f = gcf;
f.Position = [680,344,821,634];
saveas(f, [MIDTable.Paths{rec}, 'Summary.pdf']);
close(f)
end

function FailedSessions = appendFailedSession(FailedSessions, MIDTable, rec, ME)
errorFile = '';
errorFunction = '';
errorLine = NaN;
if ~isempty(ME.stack)
    errorFile = ME.stack(1).file;
    errorFunction = ME.stack(1).name;
    errorLine = ME.stack(1).line;
end

tempTable = table();
tempTable.SessionIndex = rec;
tempTable.IssueType = {'Failed'};
tempTable.Stage = {'Stimulation_ClusteringIndexPipeline'};
tempTable.Monkey = MIDTable.Monkey(rec);
tempTable.Date = MIDTable.Date(rec);
tempTable.ROI = MIDTable.ROI(rec);
tempTable.StimElec = MIDTable.StimElec(rec);
tempTable.WorkbookRow = MIDTable.WorkbookRow(rec);
tempTable.FolderPath = MIDTable.FolderPath(rec);
tempTable.Reason = {ME.message};
tempTable.ErrorFile = {errorFile};
tempTable.ErrorFunction = {errorFunction};
tempTable.ErrorLine = errorLine;
FailedSessions = [FailedSessions; tempTable]; %#ok<AGROW>
end

function AnalysisIssueTable = buildAnalysisIssueTable(SkippedSessions, FailedSessions)
AnalysisIssueTable = table();

if exist('SkippedSessions', 'var') && ~isempty(SkippedSessions)
    AnalysisIssueTable = [AnalysisIssueTable; standardizeIssueTable(SkippedSessions)]; %#ok<AGROW>
end

if exist('FailedSessions', 'var') && ~isempty(FailedSessions)
    AnalysisIssueTable = [AnalysisIssueTable; standardizeIssueTable(FailedSessions)]; %#ok<AGROW>
end
end

function issueTable = standardizeIssueTable(sourceTable)
requiredVars = {'SessionIndex','IssueType','Stage','Monkey','Date','ROI','StimElec','WorkbookRow','FolderPath','Reason','ErrorFile','ErrorFunction','ErrorLine'};
issueTable = table();

for iVar = 1:numel(requiredVars)
    varName = requiredVars{iVar};
    if ismember(varName, sourceTable.Properties.VariableNames)
        issueTable.(varName) = sourceTable.(varName);
    else
        switch varName
            case {'SessionIndex','StimElec','WorkbookRow','ErrorLine'}
                issueTable.(varName) = nan(height(sourceTable), 1);
            case 'Date'
                issueTable.(varName) = NaT(height(sourceTable), 1);
            otherwise
                issueTable.(varName) = repmat({''}, height(sourceTable), 1);
        end
    end
end
end

function safeDisplay(messageText)
try
    disp(messageText);
catch
end
end

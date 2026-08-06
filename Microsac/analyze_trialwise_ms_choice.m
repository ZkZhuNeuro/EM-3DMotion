function Analysis = analyze_trialwise_ms_choice(varargin)
%ANALYZE_TRIALWISE_MS_CHOICE Test trial-level MS effects on binary choice.
%
% This analysis consumes the per-session outputs from analyze_microsaccades.
% For every trial containing at least one microsaccade (MS), event-level
% displacement vectors are averaged within trial. Separate logistic models
% are then fit for every session:
%
%   Simple:   Choice ~ MeanMSY_Z * StimCondition
%   Base:     Choice ~ SignedCoherence * VisualCondition + StimCondition
%   Adjusted: Base + MeanMSY_Z * StimCondition
%   Vector:   Base + MeanMSX_Z * StimCondition + MeanMSY_Z * StimCondition
%
% MeanMSX_Z and MeanMSY_Z are standardized across all usable MS trials in
% the session. Thus, MS slopes are log-odds changes per session SD. The
% MeanMSY_Z:StimCondition term is the primary test of whether stimulation
% modulates the trial-level vertical-MS effect on choice. The vector model
% provides a joint two-dimensional sensitivity test.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'PopulationRoot', ...
    'C:\EM\Microsac\population_merged_12ms_no_smoothing', ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'SessionManifestFile', "", ...
    @(x) (ischar(x) || isstring(x)) && isscalar(string(x)));
addParameter(parser, 'OutputDir', "", ...
    @(x) (ischar(x) || isstring(x)) && isscalar(string(x)));
addParameter(parser, 'SessionRows', [], ...
    @(x) isempty(x) || (isnumeric(x) && isvector(x) && ...
    all(isfinite(x)) && all(x >= 1) && all(mod(x, 1) == 0)));
addParameter(parser, 'ExpectedSmoothWindowMs', 0, ...
    @(x) isscalar(x) && isfinite(x) && x >= 0);
addParameter(parser, 'ExpectedMinDurationMs', 12, ...
    @(x) isscalar(x) && isfinite(x) && x > 0);
addParameter(parser, 'ExpectedRequireBinocular', false, ...
    @(x) isempty(x) || (islogical(x) && isscalar(x)));
addParameter(parser, 'MinTrialsPerStimCondition', 10, ...
    @(x) isscalar(x) && x >= 2 && mod(x, 1) == 0);
addParameter(parser, 'MinTotalTrials', 30, ...
    @(x) isscalar(x) && x >= 4 && mod(x, 1) == 0);
addParameter(parser, 'LikelihoodPenalty', "jeffreys-prior", ...
    @(x) any(strcmpi(string(x), ["none", "jeffreys-prior"])));
addParameter(parser, 'MaxIterations', 1000, ...
    @(x) isscalar(x) && isfinite(x) && x >= 100 && mod(x, 1) == 0);
addParameter(parser, 'MakePlots', true, ...
    @(x) islogical(x) && isscalar(x));
parse(parser, varargin{:});
options = parser.Results;

populationRoot = char(options.PopulationRoot);
assert(isfolder(populationRoot), 'Population root not found: %s', populationRoot);
manifestFile = char(options.SessionManifestFile);
if isempty(manifestFile)
    manifestFile = fullfile(populationRoot, ...
        'population_microsaccade_session_manifest_complete.csv');
end
assert(isfile(manifestFile), 'Session manifest not found: %s', manifestFile);
outputDir = char(options.OutputDir);
if isempty(outputDir)
    outputDir = fullfile(populationRoot, 'population_analysis', ...
        'trialwise_ms_choice');
end
if ~isfolder(outputDir)
    mkdir(outputDir);
end

manifest = readtable(manifestFile, 'TextType', 'string', ...
    'VariableNamingRule', 'preserve');
requiredManifestVariables = {'UnitTableRow', 'Date', 'Monkey', 'ROI', ...
    'OutputDir', 'Status'};
assert(all(ismember(requiredManifestVariables, ...
    manifest.Properties.VariableNames)), ...
    'The session manifest is missing one or more required variables.');
if ~isempty(options.SessionRows)
    manifest = manifest(ismember(manifest.UnitTableRow, ...
        unique(options.SessionRows(:))), :);
end
assert(height(manifest) > 0, 'No manifest rows remained for analysis.');

nSessions = height(manifest);
summaryRows = repmat(makeSummaryRow(), nSessions, 1);
trialTables = cell(nSessions, 1);
coefficientTables = cell(nSessions, 1);
SimpleModels = cell(nSessions, 1);
BaseModels = cell(nSessions, 1);
VerticalModels = cell(nSessions, 1);
VectorModels = cell(nSessions, 1);

fprintf('Analyzing trial-level MS/choice effects in %d sessions.\n', nSessions);
for iSession = 1:nSessions
    unitTableRow = manifest.UnitTableRow(iSession);
    summary = makeSummaryRow();
    summary.UnitTableRow = unitTableRow;
    summary.Date = string(manifest.Date(iSession));
    summary.Monkey = string(manifest.Monkey(iSession));
    summary.ROI = string(manifest.ROI(iSession));

    try
        resultFile = resolveSessionResultFile(manifest.OutputDir(iSession));
        summary.ResultFile = string(resultFile);
        if isempty(resultFile)
            summary.Status = "SkippedNoResult";
            summary.Message = "No session microsaccade MAT file was found.";
            summaryRows(iSession) = summary;
            continue
        end

        saved = load(resultFile, 'Results');
        assert(isfield(saved, 'Results'), ...
            'MAT file does not contain Results: %s', resultFile);
        Results = saved.Results;
        [detectorOK, detectorMessage, detectorText] = ...
            validateDetector(Results, options);
        summary.Detector = detectorText;
        if ~detectorOK
            summary.Status = "SkippedDetectorMismatch";
            summary.Message = detectorMessage;
            summaryRows(iSession) = summary;
            continue
        end

        [sessionTrials, usableMask] = makeTrialMSData(Results, summary);
        summary.NTrialsWithMS = height(sessionTrials);
        summary.NUsableTrials = nnz(usableMask);
        summary.NNonStimTrials = nnz(usableMask & ~sessionTrials.IsStim);
        summary.NStimTrials = nnz(usableMask & sessionTrials.IsStim);
        summary.NChoice0 = nnz(usableMask & sessionTrials.Choice == 0);
        summary.NChoice1 = nnz(usableMask & sessionTrials.Choice == 1);

        [sessionTrials, summary, SimpleModels{iSession}, ...
            BaseModels{iSession}, VerticalModels{iSession}, ...
            VectorModels{iSession}] = ...
            fitSessionModels(sessionTrials, usableMask, summary, options);
        trialTables{iSession} = sessionTrials;
        coefficientTables{iSession} = makeCoefficientTable( ...
            unitTableRow, summary.Date, summary.Monkey, summary.ROI, ...
            SimpleModels{iSession}, BaseModels{iSession}, ...
            VerticalModels{iSession}, VectorModels{iSession});
    catch errorInfo
        summary.Status = "Failed";
        summary.Message = string(errorInfo.message);
    end
    summaryRows(iSession) = summary;
    if mod(iSession, 25) == 0 || iSession == nSessions
        fprintf('  Finished %d/%d sessions.\n', iSession, nSessions);
    end
end

SessionSummaryTable = struct2table(summaryRows, 'AsArray', true);
SessionSummaryTable.SimpleInteractionP_Holm = holmBonferroni( ...
    SessionSummaryTable.SimpleInteractionP);
SessionSummaryTable.SimpleAnyEffectP_Holm = holmBonferroni( ...
    SessionSummaryTable.SimpleAnyEffectJointP);
SessionSummaryTable.VerticalInteractionP_Holm = holmBonferroni( ...
    SessionSummaryTable.VerticalInteractionP);
SessionSummaryTable.VerticalAnyEffectP_Holm = holmBonferroni( ...
    SessionSummaryTable.VerticalAnyEffectJointP);
SessionSummaryTable.VectorInteractionP_Holm = holmBonferroni( ...
    SessionSummaryTable.VectorInteractionJointP);
SessionSummaryTable.VectorAnyEffectP_Holm = holmBonferroni( ...
    SessionSummaryTable.VectorAnyEffectJointP);

TrialTable = concatenateNonemptyTables(trialTables);
CoefficientTable = concatenateNonemptyTables(coefficientTables);

outputFiles = struct( ...
    'Mat', fullfile(outputDir, 'trialwise_ms_choice_results.mat'), ...
    'SessionSummaryCSV', fullfile(outputDir, ...
    'trialwise_ms_choice_session_summary.csv'), ...
    'TrialTableCSV', fullfile(outputDir, 'trialwise_ms_choice_trials.csv'), ...
    'CoefficientCSV', fullfile(outputDir, ...
    'trialwise_ms_choice_coefficients.csv'), ...
    'SummaryFigure', fullfile(outputDir, ...
    'trialwise_ms_choice_summary.png'), ...
    'ModelComparisonFigure', fullfile(outputDir, ...
    'trialwise_ms_choice_model_comparison.png'));

writetable(SessionSummaryTable, outputFiles.SessionSummaryCSV);
writetable(TrialTable, outputFiles.TrialTableCSV);
writetable(CoefficientTable, outputFiles.CoefficientCSV);
if options.MakePlots
    makeSummaryPlot(SessionSummaryTable, outputFiles.SummaryFigure);
    makeModelComparisonPlot(SessionSummaryTable, ...
        outputFiles.ModelComparisonFigure);
else
    outputFiles.SummaryFigure = '';
    outputFiles.ModelComparisonFigure = '';
end

Models = struct;
Models.Simple = SimpleModels;
Models.Base = BaseModels;
Models.Vertical = VerticalModels;
Models.AdjustedVertical = VerticalModels;
Models.Vector = VectorModels;
Analysis = struct;
Analysis.Parameters = options;
Analysis.SessionManifestFile = manifestFile;
Analysis.SessionSummaryTable = SessionSummaryTable;
Analysis.TrialTable = TrialTable;
Analysis.CoefficientTable = CoefficientTable;
Analysis.Models = Models;
Analysis.OutputFiles = outputFiles;
save(outputFiles.Mat, 'Analysis', '-v7.3');

fprintf('\nTrial-level MS/choice analysis complete.\n');
fprintf('  Complete vertical models: %d/%d\n', ...
    nnz(SessionSummaryTable.Status == "Complete"), nSessions);
fprintf('  Simple MS x Stim Holm p < .05: %d\n', nnz( ...
    SessionSummaryTable.SimpleInteractionP_Holm < 0.05));
fprintf('  Vertical MS x Stim Holm p < .05: %d\n', nnz( ...
    SessionSummaryTable.VerticalInteractionP_Holm < 0.05));
fprintf('Results saved to %s\n', outputDir);
end


function resultFile = resolveSessionResultFile(outputDir)
resultFile = '';
outputDir = char(outputDir);
if ~isfolder(outputDir)
    return
end
files = dir(fullfile(outputDir, '*_microsaccades.mat'));
files = files(~contains(string({files.name}), '_event_data.mat'));
if isempty(files)
    return
end
assert(isscalar(files), ...
    'Expected one microsaccade result MAT in %s; found %d.', ...
    outputDir, numel(files));
resultFile = fullfile(files(1).folder, files(1).name);
end


function [valid, message, description] = validateDetector(Results, options)
valid = false;
message = "";
assert(isfield(Results, 'Parameters'), ...
    'Session Results lacks detector Parameters.');
parameters = Results.Parameters;
required = {'SmoothWindowMs', 'MinDurationMs', 'RequireBinocular'};
assert(all(isfield(parameters, required)), ...
    'Session detector parameters are incomplete.');
description = sprintf('%.3g ms minimum; %.3g ms smoothing; binocular=%d', ...
    parameters.MinDurationMs, parameters.SmoothWindowMs, ...
    parameters.RequireBinocular);
if abs(parameters.SmoothWindowMs - options.ExpectedSmoothWindowMs) > 1e-9
    message = sprintf('Expected %.3g ms smoothing, found %.3g ms.', ...
        options.ExpectedSmoothWindowMs, parameters.SmoothWindowMs);
    return
end
if abs(parameters.MinDurationMs - options.ExpectedMinDurationMs) > 1e-9
    message = sprintf('Expected %.3g ms minimum duration, found %.3g ms.', ...
        options.ExpectedMinDurationMs, parameters.MinDurationMs);
    return
end
if ~isempty(options.ExpectedRequireBinocular) && ...
        parameters.RequireBinocular ~= options.ExpectedRequireBinocular
    message = sprintf('Expected RequireBinocular=%d, found %d.', ...
        options.ExpectedRequireBinocular, parameters.RequireBinocular);
    return
end
valid = true;
end


function [output, usable] = makeTrialMSData(Results, metadata)
assert(isfield(Results, 'TrialTable') && istable(Results.TrialTable), ...
    'Session Results lacks TrialTable.');
assert(isfield(Results, 'MicrosaccadeTable') && ...
    istable(Results.MicrosaccadeTable), ...
    'Session Results lacks MicrosaccadeTable.');
trials = Results.TrialTable;
events = Results.MicrosaccadeTable;
requiredTrialVariables = {'TrialIndex', 'IsStim', 'HasAnalysisWindow', ...
    'Condition', 'SignedCoherence', 'Response'};
requiredEventVariables = {'TrialIndex', 'MeanDXDeg', 'MeanDYDeg', ...
    'MeanAmplitudeDeg', 'DirectionDeg'};
assert(all(ismember(requiredTrialVariables, trials.Properties.VariableNames)), ...
    'TrialTable is missing required variables.');
assert(all(ismember(requiredEventVariables, events.Properties.VariableNames)), ...
    'MicrosaccadeTable is missing required variables.');

if isempty(events)
    output = emptyTrialTable();
    usable = false(0, 1);
    return
end
[group, trialIndex] = findgroups(events.TrialIndex);
msCount = splitapply(@numel, events.TrialIndex, group);
meanMSXDeg = splitapply(@meanFinite, events.MeanDXDeg, group);
meanMSYDeg = splitapply(@meanFinite, events.MeanDYDeg, group);
meanMSAmplitudeDeg = splitapply(@meanFinite, events.MeanAmplitudeDeg, group);
meanMSUnitX = splitapply(@meanCosine, events.DirectionDeg, group);
meanMSUnitY = splitapply(@meanSine, events.DirectionDeg, group);
meanMSDirectionDeg = mod(atan2d(meanMSUnitY, meanMSUnitX), 360);
meanMSDirectionResultant = hypot(meanMSUnitX, meanMSUnitY);
meanMSVectorAmplitudeDeg = hypot(meanMSXDeg, meanMSYDeg);
eventSummary = table(trialIndex, msCount, meanMSXDeg, meanMSYDeg, ...
    meanMSAmplitudeDeg, meanMSVectorAmplitudeDeg, meanMSUnitX, meanMSUnitY, ...
    meanMSDirectionDeg, meanMSDirectionResultant, ...
    'VariableNames', {'TrialIndex', 'MSCount', 'MeanMSXDeg', 'MeanMSYDeg', ...
    'MeanMSAmplitudeDeg', 'MeanMSVectorAmplitudeDeg', 'MeanMSUnitX', ...
    'MeanMSUnitY', 'MeanMSDirectionDeg', 'MeanMSDirectionResultant'});
joined = innerjoin(trials(:, requiredTrialVariables), eventSummary, ...
    'Keys', 'TrialIndex');

n = height(joined);
output = table(repmat(metadata.UnitTableRow, n, 1), ...
    repmat(metadata.Date, n, 1), repmat(metadata.Monkey, n, 1), ...
    repmat(metadata.ROI, n, 1), joined.TrialIndex, ...
    double(joined.Response), logical(joined.IsStim), ...
    strings(n, 1), double(joined.Condition), ...
    strings(n, 1), double(joined.SignedCoherence), ...
    logical(joined.HasAnalysisWindow), joined.MSCount, ...
    joined.MeanMSXDeg, joined.MeanMSYDeg, joined.MeanMSAmplitudeDeg, ...
    joined.MeanMSVectorAmplitudeDeg, joined.MeanMSUnitX, ...
    joined.MeanMSUnitY, joined.MeanMSDirectionDeg, ...
    joined.MeanMSDirectionResultant, nan(n, 1), nan(n, 1), false(n, 1), ...
    'VariableNames', {'UnitTableRow', 'Date', 'Monkey', 'ROI', ...
    'TrialIndex', 'Choice', 'IsStim', 'StimCondition', 'Condition', ...
    'VisualCondition', 'SignedCoherence', 'HasAnalysisWindow', 'MSCount', ...
    'MeanMSXDeg', 'MeanMSYDeg', 'MeanMSAmplitudeDeg', ...
    'MeanMSVectorAmplitudeDeg', 'MeanMSUnitX', 'MeanMSUnitY', ...
    'MeanMSDirectionDeg', 'MeanMSDirectionResultant', 'MeanMSX_Z', ...
    'MeanMSY_Z', 'UsableForModel'});
output.StimCondition(~output.IsStim) = "NonStim";
output.StimCondition(output.IsStim) = "Stim";
output.VisualCondition = string(output.Condition);
usable = output.HasAnalysisWindow & ismember(output.Choice, [0, 1]) & ...
    isfinite(output.SignedCoherence) & isfinite(output.Condition) & ...
    isfinite(output.MeanMSXDeg) & isfinite(output.MeanMSYDeg);
output.UsableForModel = usable;
end


function [trials, summary, simpleModel, baseModel, verticalModel, vectorModel] = ...
        fitSessionModels(trials, usable, summary, options)
simpleModel = [];
baseModel = [];
verticalModel = [];
vectorModel = [];
if height(trials) == 0
    summary.Status = "SkippedNoMS";
    summary.Message = "No microsaccades were detected in this session.";
    return
end
if nnz(usable) < options.MinTotalTrials
    summary.Status = "SkippedTooFewTrials";
    summary.Message = sprintf('Only %d usable MS trials; minimum is %d.', ...
        nnz(usable), options.MinTotalTrials);
    return
end
nonStim = usable & ~trials.IsStim;
stim = usable & trials.IsStim;
if nnz(nonStim) < options.MinTrialsPerStimCondition || ...
        nnz(stim) < options.MinTrialsPerStimCondition
    summary.Status = "SkippedTooFewTrials";
    summary.Message = sprintf(['Usable NonStim/Stim MS trials = %d/%d; ' ...
        'minimum per condition is %d.'], nnz(nonStim), nnz(stim), ...
        options.MinTrialsPerStimCondition);
    return
end
if numel(unique(trials.Choice(usable))) < 2
    summary.Status = "SkippedSingleChoice";
    summary.Message = "All usable trials had the same choice.";
    return
end
if numel(unique(trials.Choice(nonStim))) < 2 || ...
        numel(unique(trials.Choice(stim))) < 2
    summary.Status = "SkippedSingleChoiceCondition";
    summary.Message = "Stim or NonStim trials contained only one choice.";
    return
end

summary.MSXCenterDeg = mean(trials.MeanMSXDeg(usable), 'omitmissing');
summary.MSYCenterDeg = mean(trials.MeanMSYDeg(usable), 'omitmissing');
summary.MSXScaleDeg = std(trials.MeanMSXDeg(usable), 'omitmissing');
summary.MSYScaleDeg = std(trials.MeanMSYDeg(usable), 'omitmissing');
if ~isfinite(summary.MSYScaleDeg) || summary.MSYScaleDeg <= eps
    summary.Status = "SkippedNoMSYVariation";
    summary.Message = "Mean vertical MS displacement had no usable variation.";
    return
end
trials.MeanMSY_Z = (trials.MeanMSYDeg - summary.MSYCenterDeg) ./ ...
    summary.MSYScaleDeg;
if isfinite(summary.MSXScaleDeg) && summary.MSXScaleDeg > eps
    trials.MeanMSX_Z = (trials.MeanMSXDeg - summary.MSXCenterDeg) ./ ...
        summary.MSXScaleDeg;
end

data = trials(usable, :);
data.StimCondition = categorical(data.StimCondition, ...
    ["NonStim", "Stim"]);
data.VisualCondition = categorical(data.VisualCondition);
fitOptions = statset('glmfit');
fitOptions.MaxIter = options.MaxIterations;
simpleFormula = 'Choice ~ MeanMSY_Z * StimCondition';
baseFormula = ['Choice ~ SignedCoherence * VisualCondition + ' ...
    'StimCondition'];
verticalFormula = [baseFormula ' + MeanMSY_Z * StimCondition'];

lastwarn('');
simpleModel = fitglm(data, simpleFormula, 'Distribution', 'binomial', ...
    'LikelihoodPenalty', char(options.LikelihoodPenalty), ...
    'Options', fitOptions);
baseModel = fitglm(data, baseFormula, 'Distribution', 'binomial', ...
    'LikelihoodPenalty', char(options.LikelihoodPenalty), ...
    'Options', fitOptions);
verticalModel = fitglm(data, verticalFormula, 'Distribution', 'binomial', ...
    'LikelihoodPenalty', char(options.LikelihoodPenalty), ...
    'Options', fitOptions);
summary.SimpleFormula = string(simpleFormula);
summary.BaseFormula = string(baseFormula);
summary.VerticalFormula = string(verticalFormula);
summary.LikelihoodPenalty = string(options.LikelihoodPenalty);

[summary.SimpleNonStimSlope, summary.SimpleNonStimSlopeSE, ...
    summary.SimpleNonStimSlopeP, simpleNonStimWeights] = ...
    componentSlope(simpleModel, 'MeanMSY_Z', false);
[summary.SimpleStimSlope, summary.SimpleStimSlopeSE, ...
    summary.SimpleStimSlopeP, simpleStimWeights] = ...
    componentSlope(simpleModel, 'MeanMSY_Z', true);
summary.SimpleNonStimOddsRatio = exp(summary.SimpleNonStimSlope);
summary.SimpleStimOddsRatio = exp(summary.SimpleStimSlope);
simpleInteractionWeights = simpleStimWeights - simpleNonStimWeights;
[summary.SimpleInteraction, summary.SimpleInteractionSE, ...
    summary.SimpleInteractionP] = linearContrast( ...
    simpleModel, simpleInteractionWeights);
summary.SimpleAnyEffectJointP = jointContrast(simpleModel, ...
    [simpleNonStimWeights; simpleInteractionWeights]);

[summary.VerticalNonStimSlope, summary.VerticalNonStimSlopeSE, ...
    summary.VerticalNonStimSlopeP, nonStimWeights] = ...
    componentSlope(verticalModel, 'MeanMSY_Z', false);
[summary.VerticalStimSlope, summary.VerticalStimSlopeSE, ...
    summary.VerticalStimSlopeP, stimWeights] = ...
    componentSlope(verticalModel, 'MeanMSY_Z', true);
summary.VerticalNonStimOddsRatio = exp(summary.VerticalNonStimSlope);
summary.VerticalStimOddsRatio = exp(summary.VerticalStimSlope);
interactionWeights = stimWeights - nonStimWeights;
[summary.VerticalInteraction, summary.VerticalInteractionSE, ...
    summary.VerticalInteractionP] = linearContrast( ...
    verticalModel, interactionWeights);
summary.VerticalAnyEffectJointP = jointContrast(verticalModel, ...
    [nonStimWeights; interactionWeights]);

if isfinite(summary.MSXScaleDeg) && summary.MSXScaleDeg > eps
    vectorFormula = [baseFormula ...
        ' + MeanMSX_Z * StimCondition + MeanMSY_Z * StimCondition'];
    vectorModel = fitglm(data, vectorFormula, 'Distribution', 'binomial', ...
        'LikelihoodPenalty', char(options.LikelihoodPenalty), ...
        'Options', fitOptions);
    summary.VectorFormula = string(vectorFormula);
    [~, ~, ~, xNonStim] = componentSlope( ...
        vectorModel, 'MeanMSX_Z', false);
    [~, ~, ~, xStim] = componentSlope( ...
        vectorModel, 'MeanMSX_Z', true);
    [~, ~, ~, yNonStim] = componentSlope( ...
        vectorModel, 'MeanMSY_Z', false);
    [~, ~, ~, yStim] = componentSlope( ...
        vectorModel, 'MeanMSY_Z', true);
    summary.VectorNonStimJointP = jointContrast(vectorModel, ...
        [xNonStim; yNonStim]);
    summary.VectorStimJointP = jointContrast(vectorModel, ...
        [xStim; yStim]);
    summary.VectorInteractionJointP = jointContrast(vectorModel, ...
        [xStim - xNonStim; yStim - yNonStim]);
    summary.VectorAnyEffectJointP = jointContrast(vectorModel, ...
        [xNonStim; xStim - xNonStim; yNonStim; yStim - yNonStim]);
end
[warningMessage, ~] = lastwarn;
summary.ModelWarning = string(warningMessage);
summary.Status = "Complete";
summary.Message = "";
end


function [estimate, standardError, pValue, weights] = ...
        componentSlope(model, componentName, isStim)
names = string(model.CoefficientNames(:));
weights = zeros(1, numel(names));
mainIndex = find(names == componentName, 1);
assert(~isempty(mainIndex), 'Coefficient %s was not found.', componentName);
weights(mainIndex) = 1;
if isStim
    interactionIndex = find(contains(names, componentName) & ...
        contains(names, 'StimCondition_Stim') & contains(names, ':'), 1);
    assert(~isempty(interactionIndex), ...
        'Stim interaction for %s was not found.', componentName);
    weights(interactionIndex) = 1;
end
[estimate, standardError, pValue] = linearContrast(model, weights);
end


function [estimate, standardError, pValue] = linearContrast(model, weights)
weights = weights(:);
beta = model.Coefficients.Estimate;
covariance = model.CoefficientCovariance;
estimate = weights' * beta;
standardError = sqrt(max(0, weights' * covariance * weights));
if standardError > 0 && isfinite(standardError)
    pValue = 2 * normcdf(-abs(estimate / standardError));
else
    pValue = NaN;
end
end


function pValue = jointContrast(model, weights)
try
    pValue = coefTest(model, weights);
catch
    pValue = NaN;
end
end


function output = makeCoefficientTable(unitTableRow, dateText, monkey, roi, ...
        simpleModel, baseModel, verticalModel, vectorModel)
models = {simpleModel, baseModel, verticalModel, vectorModel};
modelNames = ["SimpleVertical"; "AdjustedBase"; ...
    "AdjustedVertical"; "AdjustedVector"];
parts = cell(4, 1);
for iModel = 1:4
    if isempty(models{iModel})
        continue
    end
    model = models{iModel};
    coefficients = model.Coefficients;
    n = height(coefficients);
    parts{iModel} = table(repmat(unitTableRow, n, 1), ...
        repmat(dateText, n, 1), repmat(monkey, n, 1), ...
        repmat(roi, n, 1), repmat(modelNames(iModel), n, 1), ...
        string(coefficients.Properties.RowNames), coefficients.Estimate, ...
        coefficients.SE, coefficients.tStat, coefficients.pValue, ...
        'VariableNames', {'UnitTableRow', 'Date', 'Monkey', 'ROI', ...
        'Model', 'Coefficient', 'Estimate', 'SE', 'Z', 'PValue'});
end
output = concatenateNonemptyTables(parts);
end


function output = concatenateNonemptyTables(parts)
nonempty = ~cellfun(@isempty, parts);
if ~any(nonempty)
    output = table;
    return
end
output = vertcat(parts{nonempty});
end


function value = meanFinite(values)
value = mean(values, 'omitmissing');
end


function value = meanCosine(directionDeg)
value = mean(cosd(directionDeg), 'omitmissing');
end


function value = meanSine(directionDeg)
value = mean(sind(directionDeg), 'omitmissing');
end


function row = makeSummaryRow()
row = struct( ...
    'UnitTableRow', NaN, 'Date', "", 'Monkey', "", 'ROI', "", ...
    'ResultFile', "", 'Detector', "", 'Status', "", 'Message', "", ...
    'NTrialsWithMS', 0, 'NUsableTrials', 0, 'NNonStimTrials', 0, ...
    'NStimTrials', 0, 'NChoice0', 0, 'NChoice1', 0, ...
    'MSXCenterDeg', NaN, 'MSXScaleDeg', NaN, ...
    'MSYCenterDeg', NaN, 'MSYScaleDeg', NaN, ...
    'SimpleFormula', "", 'BaseFormula', "", 'VerticalFormula', "", ...
    'VectorFormula', "", ...
    'LikelihoodPenalty', "", ...
    'ModelWarning', "", ...
    'SimpleNonStimSlope', NaN, 'SimpleNonStimSlopeSE', NaN, ...
    'SimpleNonStimSlopeP', NaN, 'SimpleNonStimOddsRatio', NaN, ...
    'SimpleStimSlope', NaN, 'SimpleStimSlopeSE', NaN, ...
    'SimpleStimSlopeP', NaN, 'SimpleStimOddsRatio', NaN, ...
    'SimpleInteraction', NaN, 'SimpleInteractionSE', NaN, ...
    'SimpleInteractionP', NaN, 'SimpleAnyEffectJointP', NaN, ...
    'VerticalNonStimSlope', NaN, 'VerticalNonStimSlopeSE', NaN, ...
    'VerticalNonStimSlopeP', NaN, 'VerticalNonStimOddsRatio', NaN, ...
    'VerticalStimSlope', NaN, 'VerticalStimSlopeSE', NaN, ...
    'VerticalStimSlopeP', NaN, 'VerticalStimOddsRatio', NaN, ...
    'VerticalInteraction', NaN, 'VerticalInteractionSE', NaN, ...
    'VerticalInteractionP', NaN, 'VerticalAnyEffectJointP', NaN, ...
    'VectorNonStimJointP', NaN, 'VectorStimJointP', NaN, ...
    'VectorInteractionJointP', NaN, 'VectorAnyEffectJointP', NaN);
end


function output = emptyTrialTable()
output = table('Size', [0, 24], 'VariableTypes', ...
    {'double', 'string', 'string', 'string', 'double', 'double', ...
    'logical', 'string', 'double', 'string', 'double', 'logical', ...
    'double', 'double', 'double', 'double', 'double', 'double', ...
    'double', 'double', 'double', 'double', 'double', 'logical'}, ...
    'VariableNames', {'UnitTableRow', 'Date', 'Monkey', 'ROI', ...
    'TrialIndex', 'Choice', 'IsStim', 'StimCondition', 'Condition', ...
    'VisualCondition', 'SignedCoherence', 'HasAnalysisWindow', 'MSCount', ...
    'MeanMSXDeg', 'MeanMSYDeg', 'MeanMSAmplitudeDeg', ...
    'MeanMSVectorAmplitudeDeg', 'MeanMSUnitX', 'MeanMSUnitY', ...
    'MeanMSDirectionDeg', 'MeanMSDirectionResultant', 'MeanMSX_Z', ...
    'MeanMSY_Z', 'UsableForModel'});
end


function adjustedP = holmBonferroni(p)
p = p(:);
adjustedP = nan(size(p));
valid = isfinite(p);
values = p(valid);
if isempty(values)
    return
end
[sorted, order] = sort(values);
m = numel(sorted);
adjusted = sorted .* (m:-1:1)';
adjusted = cummax(adjusted);
adjusted = min(adjusted, 1);
restored = nan(m, 1);
restored(order) = adjusted;
adjustedP(valid) = restored;
end


function makeSummaryPlot(summary, outputFile)
complete = summary.Status == "Complete";
data = summary(complete, :);
fig = figure('Color', 'w', 'Visible', 'off', ...
    'Position', [100 100 1200 850]);
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');

ax = nexttile(layout);
hold(ax, 'on');
roiNames = unique(data.ROI, 'stable');
colors = lines(max(1, numel(roiNames)));
for iROI = 1:numel(roiNames)
    mask = data.ROI == roiNames(iROI);
    scatter(ax, data.VerticalNonStimSlope(mask), ...
        data.VerticalStimSlope(mask), 26, colors(iROI, :), 'filled', ...
        'MarkerFaceAlpha', 0.65, 'DisplayName', roiNames(iROI));
end
xline(ax, 0, ':', 'HandleVisibility', 'off');
yline(ax, 0, ':', 'HandleVisibility', 'off');
axis(ax, 'square');
xlabel(ax, 'NonStim MS_y slope (log odds / SD)');
ylabel(ax, 'Stim MS_y slope (log odds / SD)');
title(ax, 'Within-session vertical MS effects');
legend(ax, 'Location', 'best');
grid(ax, 'on');

ax = nexttile(layout);
histogram(ax, data.VerticalInteractionP, 0:0.05:1, ...
    'FaceColor', [0.20 0.45 0.75]);
xline(ax, 0.05, '--r');
xlabel(ax, 'raw MS_y x Stim p');
ylabel(ax, 'Sessions');
title(ax, sprintf('Uncorrected modulation (Holm p < .05: %d)', ...
    nnz(data.VerticalInteractionP_Holm < 0.05)));

ax = nexttile(layout);
histogram(ax, data.VectorInteractionJointP, 0:0.05:1, ...
    'FaceColor', [0.25 0.65 0.45]);
xline(ax, 0.05, '--r');
xlabel(ax, 'raw joint vector MS x Stim p');
ylabel(ax, 'Sessions');
title(ax, sprintf('Uncorrected vector modulation (Holm p < .05: %d)', ...
    nnz(data.VectorInteractionP_Holm < 0.05)));

ax = nexttile(layout);
scatter(ax, data.VerticalInteraction, ...
    -log10(max(data.VerticalInteractionP, realmin)), ...
    24, 'filled', 'MarkerFaceAlpha', 0.65);
yline(ax, -log10(0.05), '--r');
xline(ax, 0, ':');
xlabel(ax, 'Stim - NonStim MS_y slope');
ylabel(ax, '-log_{10}(raw p)');
title(ax, 'Effect size and uncorrected evidence');
grid(ax, 'on');

title(layout, sprintf(['Trial-level microsaccade prediction of choice ' ...
    '(%d complete sessions)'], height(data)));
exportgraphics(fig, outputFile, 'Resolution', 180);
close(fig);
end


function makeModelComparisonPlot(summary, outputFile)
data = summary(summary.Status == "Complete", :);
fig = figure('Color', 'w', 'Visible', 'off', ...
    'Position', [100 100 1200 850]);
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
roiNames = unique(data.ROI, 'stable');
colors = lines(max(1, numel(roiNames)));

ax = nexttile(layout);
hold(ax, 'on');
for iROI = 1:numel(roiNames)
    mask = data.ROI == roiNames(iROI);
    scatter(ax, data.SimpleInteraction(mask), ...
        data.VerticalInteraction(mask), 28, colors(iROI, :), 'filled', ...
        'MarkerFaceAlpha', 0.65, 'DisplayName', roiNames(iROI));
end
limits = paddedLimits([data.SimpleInteraction; data.VerticalInteraction]);
plot(ax, limits, limits, ':k', 'HandleVisibility', 'off');
xline(ax, 0, ':', 'HandleVisibility', 'off');
yline(ax, 0, ':', 'HandleVisibility', 'off');
xlim(ax, limits);
ylim(ax, limits);
axis(ax, 'square');
xlabel(ax, 'Simple MS_y x Stim coefficient');
ylabel(ax, 'Adjusted MS_y x Stim coefficient');
title(ax, 'Interaction effect sizes');
legend(ax, 'Location', 'best');
grid(ax, 'on');

ax = nexttile(layout);
hold(ax, 'on');
simpleEvidence = -log10(max(data.SimpleInteractionP, realmin));
adjustedEvidence = -log10(max(data.VerticalInteractionP, realmin));
for iROI = 1:numel(roiNames)
    mask = data.ROI == roiNames(iROI);
    scatter(ax, simpleEvidence(mask), adjustedEvidence(mask), ...
        28, colors(iROI, :), 'filled', 'MarkerFaceAlpha', 0.65, ...
        'HandleVisibility', 'off');
end
limits = paddedLimits([simpleEvidence; adjustedEvidence; 0; -log10(0.05)]);
plot(ax, limits, limits, ':k', 'HandleVisibility', 'off');
xline(ax, -log10(0.05), '--r', 'HandleVisibility', 'off');
yline(ax, -log10(0.05), '--r', 'HandleVisibility', 'off');
xlim(ax, limits);
ylim(ax, limits);
axis(ax, 'square');
xlabel(ax, 'Simple -log_{10}(raw interaction p)');
ylabel(ax, 'Adjusted -log_{10}(raw interaction p)');
title(ax, sprintf(['Uncorrected interaction evidence ' ...
    '(Holm significant: %d/%d)'], ...
    nnz(data.SimpleInteractionP_Holm < 0.05), ...
    nnz(data.VerticalInteractionP_Holm < 0.05)));
grid(ax, 'on');

ax = nexttile(layout);
hold(ax, 'on');
for iROI = 1:numel(roiNames)
    mask = data.ROI == roiNames(iROI);
    scatter(ax, data.SimpleNonStimSlope(mask), ...
        data.VerticalNonStimSlope(mask), 28, colors(iROI, :), 'filled', ...
        'MarkerFaceAlpha', 0.65, 'HandleVisibility', 'off');
end
limits = paddedLimits([data.SimpleNonStimSlope; data.VerticalNonStimSlope]);
plot(ax, limits, limits, ':k', 'HandleVisibility', 'off');
xline(ax, 0, ':', 'HandleVisibility', 'off');
yline(ax, 0, ':', 'HandleVisibility', 'off');
xlim(ax, limits);
ylim(ax, limits);
axis(ax, 'square');
xlabel(ax, 'Simple NonStim MS_y slope');
ylabel(ax, 'Adjusted NonStim MS_y slope');
title(ax, 'NonStim slopes');
grid(ax, 'on');

ax = nexttile(layout);
hold(ax, 'on');
for iROI = 1:numel(roiNames)
    mask = data.ROI == roiNames(iROI);
    scatter(ax, data.SimpleStimSlope(mask), ...
        data.VerticalStimSlope(mask), 28, colors(iROI, :), 'filled', ...
        'MarkerFaceAlpha', 0.65, 'HandleVisibility', 'off');
end
limits = paddedLimits([data.SimpleStimSlope; data.VerticalStimSlope]);
plot(ax, limits, limits, ':k', 'HandleVisibility', 'off');
xline(ax, 0, ':', 'HandleVisibility', 'off');
yline(ax, 0, ':', 'HandleVisibility', 'off');
xlim(ax, limits);
ylim(ax, limits);
axis(ax, 'square');
xlabel(ax, 'Simple Stim MS_y slope');
ylabel(ax, 'Adjusted Stim MS_y slope');
title(ax, 'Stim slopes');
grid(ax, 'on');

title(layout, sprintf(['Simple versus stimulus-adjusted trial-level ' ...
    'MS models (%d sessions)'], height(data)));
exportgraphics(fig, outputFile, 'Resolution', 180);
close(fig);
end


function limits = paddedLimits(values)
values = values(isfinite(values));
if isempty(values)
    limits = [-1, 1];
    return
end
limits = [min(values), max(values)];
if limits(1) == limits(2)
    padding = max(1, abs(limits(1))) * 0.1;
else
    padding = diff(limits) * 0.05;
end
limits = limits + [-padding, padding];
end

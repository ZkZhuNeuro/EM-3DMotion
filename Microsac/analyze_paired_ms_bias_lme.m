function PairedResults = analyze_paired_ms_bias_lme(varargin)
%ANALYZE_PAIRED_MS_BIAS_LME Plot paired conditions and test common MS_y slope.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'LongTableFiles', {}, ...
    @(x) iscell(x) || isstring(x) || ischar(x));
addParameter(parser, 'OutputDir', "", ...
    @(x) ischar(x) || (isstring(x) && isscalar(x)));
parse(parser, varargin{:});
options = parser.Results;

longTableFiles = cellstr(string(options.LongTableFiles));
outputDir = char(options.OutputDir);
assert(~isempty(longTableFiles), 'At least one long-table file is required.');
if ~isfolder(outputDir)
    mkdir(outputDir);
end

LongTable = table;
for iFile = 1:numel(longTableFiles)
    assert(isfile(longTableFiles{iFile}), ...
        'Long-table file not found: %s', longTableFiles{iFile});
    input = readtable(longTableFiles{iFile}, 'TextType', 'string');
    LongTable = [LongTable; input]; %#ok<AGROW>
end
LongTable.condition = categorical(string(LongTable.condition), ...
    ["NonStim", "Stim"]);

roiNames = ["MT", "FST"];
cueNames = ["Combined", "MonoL", "MonoR", "Stereo"];
colors = [0.18, 0.20, 0.23; 0.78, 0.18, 0.16];
summaryRows = repmat(makePairedSummaryRow(), 8, 1);
CommonSlopeModels = cell(2, 4);
InteractionModels = cell(2, 4);
PairedTables = cell(2, 4);
coefficientTables = cell(2, 4);
outputFiles = struct;

summaryIndex = 0;
for iROI = 1:numel(roiNames)
    figureHandle = figure('Visible', 'off', 'Color', 'w', ...
        'Position', [100, 100, 1180, 850]);
    layout = tiledlayout(figureHandle, 2, 2, 'TileSpacing', 'compact', ...
        'Padding', 'compact');
    title(layout, roiNames(iROI) + ...
        ": paired Stim and NonStim MS_y versus behavioral bias");

    for iCue = 1:numel(cueNames)
        candidate = LongTable(strcmpi(LongTable.ROI, roiNames(iROI)) & ...
            LongTable.CueIndex == iCue & LongTable.GoodFit & ...
            isfinite(LongTable.Bias) & isfinite(LongTable.MS_y), :);
        paired = retainCompleteConditionPairs(candidate);
        assert(~isempty(paired), 'No complete pairs for %s cue %s.', ...
            roiNames(iROI), cueNames(iCue));
        paired.condition = reordercats(paired.condition, {'NonStim', 'Stim'});
        paired.SessionKey = categorical(paired.SessionKey);
        CommonSlopeModels{iROI, iCue} = fitlme(paired, ...
            'Bias ~ MS_y + condition + (1|SessionKey)');
        InteractionModels{iROI, iCue} = fitlme(paired, ...
            'Bias ~ MS_y * condition + (1|SessionKey)');
        PairedTables{iROI, iCue} = paired;

        commonModel = CommonSlopeModels{iROI, iCue};
        interactionModel = InteractionModels{iROI, iCue};
        commonNames = string(commonModel.CoefficientNames(:));
        slopeIndex = find(commonNames == "MS_y", 1);
        conditionIndex = find(contains(commonNames, "condition_Stim"), 1);
        interactionNames = string(interactionModel.CoefficientNames(:));
        interactionIndex = find(contains(interactionNames, "MS_y") & ...
            contains(interactionNames, "condition_Stim"), 1);
        assert(~isempty(slopeIndex) && ~isempty(conditionIndex) && ...
            ~isempty(interactionIndex), 'Expected LME coefficient was absent.');

        summaryIndex = summaryIndex + 1;
        row = makePairedSummaryRow();
        row.ROI = roiNames(iROI);
        row.CueIndex = iCue;
        row.CueName = cueNames(iCue);
        row.NSessions = numel(unique(paired.SessionKey));
        row.NRows = height(paired);
        row.CommonSlope = commonModel.Coefficients.Estimate(slopeIndex);
        row.CommonSlopeSE = commonModel.Coefficients.SE(slopeIndex);
        row.CommonSlopeP = commonModel.Coefficients.pValue(slopeIndex);
        row.ConditionEffect = commonModel.Coefficients.Estimate(conditionIndex);
        row.ConditionEffectP = commonModel.Coefficients.pValue(conditionIndex);
        row.InteractionSlopeDifference = ...
            interactionModel.Coefficients.Estimate(interactionIndex);
        row.InteractionP = interactionModel.Coefficients.pValue(interactionIndex);
        summaryRows(summaryIndex) = row;
        coefficientTables{iROI, iCue} = makePairedCoefficientTable( ...
            commonModel, interactionModel, roiNames(iROI), iCue, cueNames(iCue));

        ax = nexttile(layout);
        hold(ax, 'on');
        sessionKeys = unique(paired.SessionKey);
        for iSession = 1:numel(sessionKeys)
            session = paired(paired.SessionKey == sessionKeys(iSession), :);
            session = sortrows(session, 'condition');
            plot(ax, session.MS_y, session.Bias, '-', ...
                'Color', [0.76, 0.76, 0.76], 'LineWidth', 0.8, ...
                'HandleVisibility', 'off');
        end
        nonStimMask = paired.condition == 'NonStim';
        stimMask = paired.condition == 'Stim';
        scatter(ax, paired.MS_y(nonStimMask), paired.Bias(nonStimMask), ...
            28, colors(1, :), 'filled', 'MarkerFaceAlpha', 0.68, ...
            'DisplayName', 'NonStim');
        scatter(ax, paired.MS_y(stimMask), paired.Bias(stimMask), ...
            28, colors(2, :), 'filled', 'MarkerFaceAlpha', 0.68, ...
            'DisplayName', 'Stim');

        xMinimum = min([paired.MS_y; 0]);
        xMaximum = max([paired.MS_y; 0]);
        xPadding = max(0.05 * (xMaximum - xMinimum), 1e-4);
        xLimits = [xMinimum - xPadding, xMaximum + xPadding];
        xRange = linspace(xLimits(1), xLimits(2), 150)';
        fixed = commonModel.Coefficients.Estimate;
        interceptIndex = find(commonNames == "(Intercept)", 1);
        nonStimFit = fixed(interceptIndex) + fixed(slopeIndex) .* xRange;
        stimFit = nonStimFit + fixed(conditionIndex);
        plot(ax, xRange, nonStimFit, '-', 'Color', colors(1, :), ...
            'LineWidth', 2.2, 'HandleVisibility', 'off');
        plot(ax, xRange, stimFit, '-', 'Color', colors(2, :), ...
            'LineWidth', 2.2, 'HandleVisibility', 'off');
        xlim(ax, xLimits);
        xline(ax, 0, ':', 'Color', [0.50, 0.50, 0.50], ...
            'HandleVisibility', 'off');
        yline(ax, 0, ':', 'Color', [0.50, 0.50, 0.50], ...
            'HandleVisibility', 'off');
        xlabel(ax, 'MS_y: mean vertical displacement (deg)');
        ylabel(ax, 'Behavioral bias');
        title(ax, sprintf('%s: common slope = %.3g, p = %.3g', ...
            cueNames(iCue), row.CommonSlope, row.CommonSlopeP));
        grid(ax, 'on');
        box(ax, 'off');
        ax.Toolbar.Visible = 'off';
        if iCue == 1
            legend(ax, 'Location', 'best');
        end
    end

    pngFile = fullfile(outputDir, ...
        sprintf('%s_paired_ms_y_bias_lme.png', lower(roiNames(iROI))));
    figFile = fullfile(outputDir, ...
        sprintf('%s_paired_ms_y_bias_lme.fig', lower(roiNames(iROI))));
    exportgraphics(figureHandle, pngFile, 'Resolution', 220);
    savefig(figureHandle, figFile);
    close(figureHandle);
    outputFiles.(roiNames(iROI) + "PNG") = pngFile;
    outputFiles.(roiNames(iROI) + "FIG") = figFile;
end

SummaryTable = struct2table(summaryRows, 'AsArray', true);
for iROI = 1:numel(roiNames)
    mask = SummaryTable.ROI == roiNames(iROI);
    SummaryTable.CommonSlopeQ_FDR(mask) = ...
        benjaminiHochbergPaired(SummaryTable.CommonSlopeP(mask));
    SummaryTable.InteractionQ_FDR(mask) = ...
        benjaminiHochbergPaired(SummaryTable.InteractionP(mask));
end
CoefficientTable = vertcat(coefficientTables{:});
PairedLongTable = vertcat(PairedTables{:});
outputFiles.SummaryCSV = fullfile(outputDir, 'paired_ms_y_bias_lme_summary.csv');
outputFiles.CoefficientsCSV = fullfile(outputDir, ...
    'paired_ms_y_bias_lme_coefficients.csv');
outputFiles.PairedLongCSV = fullfile(outputDir, ...
    'paired_ms_y_bias_lme_data.csv');
writetable(SummaryTable, outputFiles.SummaryCSV);
writetable(CoefficientTable, outputFiles.CoefficientsCSV);
writetable(PairedLongTable, outputFiles.PairedLongCSV);

PairedResults = struct;
PairedResults.Formula = "Bias ~ MS_y + condition + (1|SessionKey)";
PairedResults.InteractionSensitivityFormula = ...
    "Bias ~ MS_y * condition + (1|SessionKey)";
PairedResults.SummaryTable = SummaryTable;
PairedResults.CoefficientTable = CoefficientTable;
PairedResults.PairedLongTable = PairedLongTable;
PairedResults.CommonSlopeModels = CommonSlopeModels;
PairedResults.InteractionModels = InteractionModels;
PairedResults.OutputFiles = outputFiles;
save(fullfile(outputDir, 'paired_ms_y_bias_lme_results.mat'), ...
    'PairedResults', '-v7.3');
disp(SummaryTable);
end


function paired = retainCompleteConditionPairs(input)
sessionKeys = unique(input.SessionKey);
keep = false(height(input), 1);
for iSession = 1:numel(sessionKeys)
    mask = input.SessionKey == sessionKeys(iSession);
    sessionConditions = string(input.condition(mask));
    if nnz(sessionConditions == "NonStim") == 1 && ...
            nnz(sessionConditions == "Stim") == 1
        keep(mask) = true;
    end
end
paired = input(keep, :);
end


function row = makePairedSummaryRow()
row = struct('ROI', "", 'CueIndex', NaN, 'CueName', "", ...
    'NSessions', NaN, 'NRows', NaN, 'CommonSlope', NaN, ...
    'CommonSlopeSE', NaN, 'CommonSlopeP', NaN, 'CommonSlopeQ_FDR', NaN, ...
    'ConditionEffect', NaN, 'ConditionEffectP', NaN, ...
    'InteractionSlopeDifference', NaN, 'InteractionP', NaN, ...
    'InteractionQ_FDR', NaN);
end


function output = makePairedCoefficientTable(commonModel, interactionModel, ...
        roi, cueIndex, cueName)
models = {commonModel, interactionModel};
modelNames = ["CommonSlope", "InteractionSensitivity"];
output = table;
for iModel = 1:2
    model = models{iModel};
    coefficients = model.Coefficients;
    n = numel(model.CoefficientNames);
    rows = table(repmat(roi, n, 1), repmat(cueIndex, n, 1), ...
        repmat(cueName, n, 1), repmat(modelNames(iModel), n, 1), ...
        string(model.CoefficientNames(:)), coefficients.Estimate, ...
        coefficients.SE, coefficients.tStat, coefficients.pValue, ...
        'VariableNames', {'ROI', 'CueIndex', 'CueName', 'Model', 'Term', ...
        'Estimate', 'SE', 'tStat', 'pValue'});
    output = [output; rows]; %#ok<AGROW>
end
end


function q = benjaminiHochbergPaired(p)
q = nan(size(p));
valid = find(isfinite(p));
if isempty(valid)
    return
end
[sortedP, order] = sort(p(valid));
m = numel(sortedP);
sortedQ = sortedP .* m ./ (1:m)';
sortedQ = flipud(cummin(flipud(sortedQ)));
q(valid(order)) = min(sortedQ, 1);
end

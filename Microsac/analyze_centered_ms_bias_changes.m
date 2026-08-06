function CenteredResults = analyze_centered_ms_bias_changes(varargin)
%ANALYZE_CENTERED_MS_BIAS_CHANGES Test concordant Stim-induced changes.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'LongTableFiles', {}, ...
    @(x) iscell(x) || isstring(x) || ischar(x));
addParameter(parser, 'OutputDir', "", ...
    @(x) ischar(x) || (isstring(x) && isscalar(x)));
addParameter(parser, 'ZeroTolerance', 1e-12, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0);
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
changeTables = cell(numel(roiNames), numel(cueNames));
summaryRows = repmat(makeSummaryRow(), numel(roiNames) * numel(cueNames), 1);
summaryIndex = 0;

for iROI = 1:numel(roiNames)
    for iCue = 1:numel(cueNames)
        candidate = LongTable(strcmpi(LongTable.ROI, roiNames(iROI)) & ...
            LongTable.CueIndex == iCue & LongTable.GoodFit & ...
            isfinite(LongTable.Bias) & isfinite(LongTable.MS_y), :);
        paired = retainCompleteConditionPairs(candidate);
        assert(~isempty(paired), 'No complete pairs for %s cue %s.', ...
            roiNames(iROI), cueNames(iCue));
        changes = makeChangeTable(paired, roiNames(iROI), iCue, cueNames(iCue), ...
            options.ZeroTolerance);
        changeTables{iROI, iCue} = changes;

        summaryIndex = summaryIndex + 1;
        summaryRows(summaryIndex) = summarizeChanges(changes, roiNames(iROI), ...
            iCue, cueNames(iCue));
    end
end

SummaryTable = struct2table(summaryRows, 'AsArray', true);
for iROI = 1:numel(roiNames)
    mask = SummaryTable.ROI == roiNames(iROI);
    SummaryTable.QuadrantP_Q_FDR_ROI(mask) = ...
        benjaminiHochberg(SummaryTable.QuadrantP_OneSided(mask));
    SummaryTable.OriginSlopeP_Q_FDR_ROI(mask) = ...
        benjaminiHochberg(SummaryTable.OriginSlopeP_OneSided(mask));
end
SummaryTable.QuadrantP_Q_FDR_All = ...
    benjaminiHochberg(SummaryTable.QuadrantP_OneSided);
SummaryTable.OriginSlopeP_Q_FDR_All = ...
    benjaminiHochberg(SummaryTable.OriginSlopeP_OneSided);

outputFiles = struct;
for iROI = 1:numel(roiNames)
    figureHandle = makeCenteredFigure(changeTables(iROI, :), ...
        SummaryTable(SummaryTable.ROI == roiNames(iROI), :), roiNames(iROI));
    stem = sprintf('%s_centered_delta_ms_y_bias', lower(roiNames(iROI)));
    pngFile = fullfile(outputDir, [stem '.png']);
    figFile = fullfile(outputDir, [stem '.fig']);
    exportgraphics(figureHandle, pngFile, 'Resolution', 220);
    savefig(figureHandle, figFile);
    close(figureHandle);
    outputFiles.(roiNames(iROI) + "PNG") = pngFile;
    outputFiles.(roiNames(iROI) + "FIG") = figFile;
end

ChangeTable = vertcat(changeTables{:});
outputFiles.ChangeDataCSV = fullfile(outputDir, ...
    'centered_delta_ms_y_bias_session_data.csv');
outputFiles.SummaryCSV = fullfile(outputDir, ...
    'centered_delta_ms_y_bias_test_summary.csv');
writetable(ChangeTable, outputFiles.ChangeDataCSV);
writetable(SummaryTable, outputFiles.SummaryCSV);

CenteredResults = struct;
CenteredResults.Definition = ["DeltaMS_y = Stim MS_y - NonStim MS_y"; ...
    "DeltaBias = Stim bias - NonStim bias"];
CenteredResults.PrimaryHypothesis = ...
    "P(DeltaMS_y * DeltaBias > 0) > 0.5";
CenteredResults.PrimaryTest = ...
    "Exact one-sided binomial quadrant-concordance test";
CenteredResults.SecondaryTest = ...
    "One-sided positive slope test for DeltaBias ~ 0 + DeltaMS_y";
CenteredResults.ChangeTable = ChangeTable;
CenteredResults.SummaryTable = SummaryTable;
CenteredResults.OutputFiles = outputFiles;
save(fullfile(outputDir, 'centered_delta_ms_y_bias_results.mat'), ...
    'CenteredResults', '-v7.3');
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


function changes = makeChangeTable(paired, roi, cueIndex, cueName, zeroTolerance)
sessionKeys = unique(string(paired.SessionKey), 'stable');
n = numel(sessionKeys);
ROI = repmat(roi, n, 1);
CueIndex = repmat(cueIndex, n, 1);
CueName = repmat(cueName, n, 1);
SessionKey = strings(n, 1);
Date = strings(n, 1);
Monkey = strings(n, 1);
NonStimMS_y = nan(n, 1);
StimMS_y = nan(n, 1);
DeltaMS_y = nan(n, 1);
NonStimBias = nan(n, 1);
StimBias = nan(n, 1);
DeltaBias = nan(n, 1);

for iSession = 1:n
    session = paired(string(paired.SessionKey) == sessionKeys(iSession), :);
    nonStim = session(session.condition == 'NonStim', :);
    stim = session(session.condition == 'Stim', :);
    assert(height(nonStim) == 1 && height(stim) == 1, ...
        'Expected one Stim and one NonStim row per session.');
    SessionKey(iSession) = sessionKeys(iSession);
    Date(iSession) = string(nonStim.Date);
    Monkey(iSession) = string(nonStim.Monkey);
    NonStimMS_y(iSession) = nonStim.MS_y;
    StimMS_y(iSession) = stim.MS_y;
    DeltaMS_y(iSession) = StimMS_y(iSession) - NonStimMS_y(iSession);
    NonStimBias(iSession) = nonStim.Bias;
    StimBias(iSession) = stim.Bias;
    DeltaBias(iSession) = StimBias(iSession) - NonStimBias(iSession);
end

OnAxis = abs(DeltaMS_y) <= zeroTolerance | abs(DeltaBias) <= zeroTolerance;
Concordant = ~OnAxis & sign(DeltaMS_y) == sign(DeltaBias);
Quadrant = repmat("Axis", n, 1);
Quadrant(DeltaMS_y > zeroTolerance & DeltaBias > zeroTolerance) = "Q1";
Quadrant(DeltaMS_y < -zeroTolerance & DeltaBias > zeroTolerance) = "Q2";
Quadrant(DeltaMS_y < -zeroTolerance & DeltaBias < -zeroTolerance) = "Q3";
Quadrant(DeltaMS_y > zeroTolerance & DeltaBias < -zeroTolerance) = "Q4";
SignProduct = DeltaMS_y .* DeltaBias;

changes = table(ROI, CueIndex, CueName, SessionKey, Date, Monkey, ...
    NonStimMS_y, StimMS_y, DeltaMS_y, NonStimBias, StimBias, DeltaBias, ...
    SignProduct, Quadrant, Concordant, OnAxis);
end


function row = summarizeChanges(changes, roi, cueIndex, cueName)
row = makeSummaryRow();
row.ROI = roi;
row.CueIndex = cueIndex;
row.CueName = cueName;
row.NSessions = height(changes);
row.Q1Count = nnz(changes.Quadrant == "Q1");
row.Q2Count = nnz(changes.Quadrant == "Q2");
row.Q3Count = nnz(changes.Quadrant == "Q3");
row.Q4Count = nnz(changes.Quadrant == "Q4");
row.AxisCount = nnz(changes.OnAxis);
row.NForQuadrantTest = row.NSessions - row.AxisCount;
row.ConcordantCount = row.Q1Count + row.Q3Count;
row.DiscordantCount = row.Q2Count + row.Q4Count;
if row.NForQuadrantTest > 0
    row.ConcordanceRate = row.ConcordantCount / row.NForQuadrantTest;
    [row.ConcordanceCI95Lower, row.ConcordanceCI95Upper] = ...
        wilsonInterval(row.ConcordantCount, row.NForQuadrantTest, 0.05);
    row.QuadrantP_OneSided = exactBinomialUpperTail( ...
        row.ConcordantCount, row.NForQuadrantTest, 0.5);
end

[row.OriginSlope, row.OriginSlopeSE, row.OriginSlopeT, ...
    row.OriginSlopeP_OneSided] = originSlopeTest( ...
    changes.DeltaMS_y, changes.DeltaBias);
row.MeanDeltaMS_y = mean(changes.DeltaMS_y, 'omitmissing');
row.MeanDeltaBias = mean(changes.DeltaBias, 'omitmissing');
row.MedianDeltaMS_y = median(changes.DeltaMS_y, 'omitmissing');
row.MedianDeltaBias = median(changes.DeltaBias, 'omitmissing');
end


function row = makeSummaryRow()
row = struct('ROI', "", 'CueIndex', NaN, 'CueName', "", ...
    'NSessions', NaN, 'Q1Count', NaN, 'Q2Count', NaN, 'Q3Count', NaN, ...
    'Q4Count', NaN, 'AxisCount', NaN, 'NForQuadrantTest', NaN, ...
    'ConcordantCount', NaN, 'DiscordantCount', NaN, ...
    'ConcordanceRate', NaN, 'ConcordanceCI95Lower', NaN, ...
    'ConcordanceCI95Upper', NaN, 'QuadrantP_OneSided', NaN, ...
    'QuadrantP_Q_FDR_ROI', NaN, 'QuadrantP_Q_FDR_All', NaN, ...
    'OriginSlope', NaN, 'OriginSlopeSE', NaN, 'OriginSlopeT', NaN, ...
    'OriginSlopeP_OneSided', NaN, 'OriginSlopeP_Q_FDR_ROI', NaN, ...
    'OriginSlopeP_Q_FDR_All', NaN, 'MeanDeltaMS_y', NaN, ...
    'MeanDeltaBias', NaN, 'MedianDeltaMS_y', NaN, 'MedianDeltaBias', NaN);
end


function pValue = exactBinomialUpperTail(successCount, trialCount, probability)
if trialCount == 0
    pValue = NaN;
    return
end
k = (successCount:trialCount)';
logProbability = gammaln(trialCount + 1) - gammaln(k + 1) - ...
    gammaln(trialCount - k + 1) + k .* log(probability) + ...
    (trialCount - k) .* log1p(-probability);
pValue = min(1, sum(exp(logProbability)));
end


function [lower, upper] = wilsonInterval(successCount, trialCount, alpha)
z = -norminv(alpha / 2);
proportion = successCount / trialCount;
denominator = 1 + z ^ 2 / trialCount;
center = (proportion + z ^ 2 / (2 * trialCount)) / denominator;
halfWidth = z / denominator * sqrt(proportion * (1 - proportion) / trialCount + ...
    z ^ 2 / (4 * trialCount ^ 2));
lower = max(0, center - halfWidth);
upper = min(1, center + halfWidth);
end


function [slope, standardError, tStatistic, pValue] = originSlopeTest(x, y)
valid = isfinite(x) & isfinite(y);
x = x(valid);
y = y(valid);
denominator = sum(x .^ 2);
degreesOfFreedom = numel(x) - 1;
if denominator <= 0 || degreesOfFreedom <= 0
    slope = NaN;
    standardError = NaN;
    tStatistic = NaN;
    pValue = NaN;
    return
end
slope = sum(x .* y) / denominator;
residual = y - slope .* x;
standardError = sqrt(sum(residual .^ 2) / degreesOfFreedom / denominator);
tStatistic = slope / standardError;
pValue = tcdf(tStatistic, degreesOfFreedom, 'upper');
end


function figureHandle = makeCenteredFigure(changeTables, summary, roi)
figureHandle = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [100, 100, 1180, 850]);
layout = tiledlayout(figureHandle, 2, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
title(layout, roi + ": Stim-induced changes from the NonStim origin");

for iCue = 1:numel(changeTables)
    changes = changeTables{iCue};
    row = summary(summary.CueIndex == iCue, :);
    ax = nexttile(layout);
    hold(ax, 'on');
    xMaximum = max(abs(changes.DeltaMS_y), [], 'omitmissing');
    yMaximum = max(abs(changes.DeltaBias), [], 'omitmissing');
    xLimit = max(1.08 * xMaximum, 1e-4);
    yLimit = max(1.08 * yMaximum, 1e-3);

    concordantShade = [0.90, 0.96, 0.91];
    patch(ax, [0, xLimit, xLimit, 0], [0, 0, yLimit, yLimit], ...
        concordantShade, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    patch(ax, [-xLimit, 0, 0, -xLimit], [-yLimit, -yLimit, 0, 0], ...
        concordantShade, 'EdgeColor', 'none', 'HandleVisibility', 'off');

    discordant = ~changes.Concordant & ~changes.OnAxis;
    scatter(ax, changes.DeltaMS_y(discordant), changes.DeltaBias(discordant), ...
        31, [0.76, 0.25, 0.20], 'filled', 'MarkerFaceAlpha', 0.68, ...
        'DisplayName', 'Q2 or Q4');
    scatter(ax, changes.DeltaMS_y(changes.Concordant), ...
        changes.DeltaBias(changes.Concordant), 31, [0.10, 0.45, 0.28], ...
        'filled', 'MarkerFaceAlpha', 0.72, 'DisplayName', 'Q1 or Q3');
    if any(changes.OnAxis)
        scatter(ax, changes.DeltaMS_y(changes.OnAxis), ...
            changes.DeltaBias(changes.OnAxis), 31, [0.40, 0.40, 0.40], ...
            'filled', 'DisplayName', 'On axis');
    end

    xRange = [-xLimit; xLimit];
    plot(ax, xRange, row.OriginSlope .* xRange, 'k-', 'LineWidth', 1.8, ...
        'DisplayName', 'Fit through origin');
    xline(ax, 0, '-', 'Color', [0.35, 0.35, 0.35], ...
        'HandleVisibility', 'off');
    yline(ax, 0, '-', 'Color', [0.35, 0.35, 0.35], ...
        'HandleVisibility', 'off');
    xlim(ax, [-xLimit, xLimit]);
    ylim(ax, [-yLimit, yLimit]);
    xlabel(ax, '\DeltaMS_y = Stim - NonStim (deg)');
    ylabel(ax, '\DeltaBias = Stim - NonStim');
    title(ax, sprintf('%s: Q1+Q3 %d/%d (%.1f%%), p = %s, q = %s', ...
        row.CueName, row.ConcordantCount, row.NForQuadrantTest, ...
        100 * row.ConcordanceRate, formatP(row.QuadrantP_OneSided), ...
        formatP(row.QuadrantP_Q_FDR_ROI)));
    subtitle(ax, sprintf('Origin slope = %.3g, one-sided p = %s', ...
        row.OriginSlope, formatP(row.OriginSlopeP_OneSided)));
    grid(ax, 'on');
    box(ax, 'off');
    ax.Layer = 'top';
    ax.Toolbar.Visible = 'off';
    if iCue == 1
        legend(ax, 'Location', 'best');
    end
end
end


function label = formatP(value)
if ~isfinite(value)
    label = 'NA';
elseif value < 0.001
    label = sprintf('%.2e', value);
else
    label = sprintf('%.3f', value);
end
end


function q = benjaminiHochberg(p)
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

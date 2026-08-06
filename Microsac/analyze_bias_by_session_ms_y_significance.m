function Analysis = analyze_bias_by_session_ms_y_significance(varargin)
%ANALYZE_BIAS_BY_SESSION_MS_Y_SIGNIFICANCE Compare behavioral bias changes.
%
% Sessions are divided using the raw p-value from the within-session model
%
%   MeanMSYDeg ~ IsStim
%
% Behavioral bias is taken from the repository's paired psychometric fits:
%
%   DeltaBias = StimBias - NonStimBias
%
% Histograms and distribution summaries are produced separately for every
% monkey-area subpopulation and cue definition.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'SessionMSCSV', ...
    ['C:\EM\Microsac\population_merged_12ms_no_smoothing\' ...
    'population_analysis\session_ms_y_stim\' ...
    'session_ms_y_stim_results.csv'], ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'BiasChangeCSV', ...
    ['C:\EM\Microsac\population_merged_12ms_no_smoothing\' ...
    'population_analysis\paired_ms_y_bias_lme\centered_change\' ...
    'centered_delta_ms_y_bias_session_data.csv'], ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'OutputDir', ...
    ['C:\EM\Microsac\population_merged_12ms_no_smoothing\' ...
    'population_analysis\bias_by_session_ms_y_significance'], ...
    @(x) ischar(x) || isstring(x));
addParameter(parser, 'RawPThreshold', 0.05, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0 && x < 1);
addParameter(parser, 'MakePlots', true, ...
    @(x) islogical(x) && isscalar(x));
parse(parser, varargin{:});
options = parser.Results;

sessionFile = char(options.SessionMSCSV);
biasFile = char(options.BiasChangeCSV);
outputDir = char(options.OutputDir);
assert(isfile(sessionFile), 'Session MS result file not found: %s', sessionFile);
assert(isfile(biasFile), 'Behavior bias file not found: %s', biasFile);
if ~isfolder(outputDir)
    mkdir(outputDir);
end

sessionMS = readtable(sessionFile, 'TextType', 'string', ...
    'VariableNamingRule', 'preserve');
biasChange = readtable(biasFile, 'TextType', 'string', ...
    'VariableNamingRule', 'preserve');
requiredMS = {'Date', 'Monkey', 'ROI', 'P', 'Status', 'DeltaMSYDeg'};
requiredBias = {'SessionKey', 'Date', 'Monkey', 'ROI', 'CueIndex', ...
    'CueName', 'NonStimBias', 'StimBias', 'DeltaBias'};
assert(all(ismember(requiredMS, sessionMS.Properties.VariableNames)), ...
    'Session MS table is missing required variables.');
assert(all(ismember(requiredBias, biasChange.Properties.VariableNames)), ...
    'Bias-change table is missing required variables.');

complete = sessionMS.Status == "Complete" & isfinite(sessionMS.P);
sessionMS = sessionMS(complete, :);
sessionMS.SessionKey = makeSessionKeys( ...
    sessionMS.Date, sessionMS.Monkey, sessionMS.ROI);
assert(numel(unique(sessionMS.SessionKey)) == height(sessionMS), ...
    'The session MS table has duplicate session keys.');

msJoin = sessionMS(:, {'SessionKey', 'P', 'DeltaMSYDeg'});
msJoin.Properties.VariableNames{'P'} = 'MSYStimRawP';
msJoin.Properties.VariableNames{'DeltaMSYDeg'} = 'MSYStimDeltaDeg';
biasChange.SessionKey = lower(strip(string(biasChange.SessionKey)));
JoinedTable = innerjoin(biasChange, msJoin, 'Keys', 'SessionKey');
JoinedTable.Group = string(JoinedTable.Monkey) + "-" + string(JoinedTable.ROI);
JoinedTable.MSYStimRawSignificant = ...
    JoinedTable.MSYStimRawP < options.RawPThreshold;
JoinedTable.AbsDeltaBias = abs(JoinedTable.DeltaBias);

groupLabels = ["Jim-MT"; "Jim-FST"; "Clay-MT"; "Clay-FST"];
cueLabels = ["Combined"; "MonoL"; "MonoR"; "Stereo"];
rows = repmat(makeSummaryRow(), ...
    numel(groupLabels) * numel(cueLabels), 1);
rowIndex = 0;

for iGroup = 1:numel(groupLabels)
    for iCue = 1:numel(cueLabels)
        rowIndex = rowIndex + 1;
        data = JoinedTable(JoinedTable.Group == groupLabels(iGroup) & ...
            JoinedTable.CueName == cueLabels(iCue) & ...
            isfinite(JoinedTable.DeltaBias), :);
        significant = data.MSYStimRawSignificant;
        biasSignificant = data.DeltaBias(significant);
        biasNonsignificant = data.DeltaBias(~significant);

        row = makeSummaryRow();
        row.Group = groupLabels(iGroup);
        row.Monkey = extractBefore(groupLabels(iGroup), "-");
        row.ROI = extractAfter(groupLabels(iGroup), "-");
        row.CueIndex = find(cueLabels == cueLabels(iCue), 1);
        row.CueName = cueLabels(iCue);
        row.NSessions = height(data);
        row.NRawSignificant = nnz(significant);
        row.NRawNonsignificant = nnz(~significant);
        row.MeanBias_RawSignificant = mean(biasSignificant, 'omitmissing');
        row.MedianBias_RawSignificant = median(biasSignificant, 'omitmissing');
        row.MeanBias_RawNonsignificant = mean(biasNonsignificant, 'omitmissing');
        row.MedianBias_RawNonsignificant = median(biasNonsignificant, 'omitmissing');
        row.MeanBiasDifference = row.MeanBias_RawSignificant - ...
            row.MeanBias_RawNonsignificant;
        row.MeanAbsBias_RawSignificant = mean(abs(biasSignificant), 'omitmissing');
        row.MedianAbsBias_RawSignificant = median(abs(biasSignificant), 'omitmissing');
        row.MeanAbsBias_RawNonsignificant = ...
            mean(abs(biasNonsignificant), 'omitmissing');
        row.MedianAbsBias_RawNonsignificant = ...
            median(abs(biasNonsignificant), 'omitmissing');
        row.MeanAbsBiasDifference = row.MeanAbsBias_RawSignificant - ...
            row.MeanAbsBias_RawNonsignificant;

        if numel(biasSignificant) >= 2 && numel(biasNonsignificant) >= 2
            [~, welchSignedP] = ttest2( ...
                biasSignificant, biasNonsignificant, 'Vartype', 'unequal');
            [~, welchAbsoluteP] = ttest2( ...
                abs(biasSignificant), abs(biasNonsignificant), ...
                'Vartype', 'unequal');
            row.WelchP_Signed = welchSignedP;
            row.WelchP_Absolute = welchAbsoluteP;
        end
        if ~isempty(biasSignificant) && ~isempty(biasNonsignificant)
            row.RankSumP_Signed = ranksum( ...
                biasSignificant, biasNonsignificant);
            row.RankSumP_Absolute = ranksum( ...
                abs(biasSignificant), abs(biasNonsignificant));
            [~, ksP] = kstest2( ...
                biasSignificant, biasNonsignificant);
            row.KSP_Distribution = ksP;
        end
        rows(rowIndex) = row;
    end
end

SummaryTable = struct2table(rows, 'AsArray', true);
SummaryTable.RankSumP_Signed_FDR = ...
    benjaminiHochberg(SummaryTable.RankSumP_Signed);
SummaryTable.RankSumP_Signed_Holm = ...
    holmBonferroni(SummaryTable.RankSumP_Signed);
SummaryTable.RankSumP_Absolute_FDR = ...
    benjaminiHochberg(SummaryTable.RankSumP_Absolute);
SummaryTable.RankSumP_Absolute_Holm = ...
    holmBonferroni(SummaryTable.RankSumP_Absolute);
SummaryTable.KSP_Distribution_FDR = ...
    benjaminiHochberg(SummaryTable.KSP_Distribution);
SummaryTable.KSP_Distribution_Holm = ...
    holmBonferroni(SummaryTable.KSP_Distribution);

outputFiles = struct;
outputFiles.Mat = fullfile(outputDir, ...
    'bias_by_session_ms_y_significance_results.mat');
outputFiles.JoinedCSV = fullfile(outputDir, ...
    'bias_by_session_ms_y_significance_data.csv');
outputFiles.SummaryCSV = fullfile(outputDir, ...
    'bias_by_session_ms_y_significance_summary.csv');
writetable(JoinedTable, outputFiles.JoinedCSV);
writetable(SummaryTable, outputFiles.SummaryCSV);

outputFiles.Figures = strings(numel(groupLabels), 1);
if options.MakePlots
    for iGroup = 1:numel(groupLabels)
        outputFiles.Figures(iGroup) = fullfile(outputDir, ...
            sprintf('%s_bias_histograms.png', ...
            lower(strrep(groupLabels(iGroup), '-', '_'))));
        makeHistogramFigure(JoinedTable, SummaryTable, ...
            groupLabels(iGroup), cueLabels, outputFiles.Figures(iGroup));
    end
end

Analysis = struct;
Analysis.SessionSplit = ...
    sprintf('Raw p < %.3g versus raw p >= %.3g from MeanMSYDeg ~ IsStim', ...
    options.RawPThreshold, options.RawPThreshold);
Analysis.BehavioralOutcome = "DeltaBias = StimBias - NonStimBias";
Analysis.BehavioralSample = ...
    "Existing paired Stim/NonStim psychometric fits with GoodFit in both conditions";
Analysis.JoinedTable = JoinedTable;
Analysis.SummaryTable = SummaryTable;
Analysis.OutputFiles = outputFiles;
save(outputFiles.Mat, 'Analysis', '-v7.3');
end


function keys = makeSessionKeys(dateValues, monkeyValues, roiValues)
dates = datetime(string(dateValues), 'InputFormat', 'dd-MMM-yyyy', ...
    'Locale', 'en_US');
dates.Format = 'yyyyMMdd';
keys = lower(string(dates) + "|" + strip(string(monkeyValues)) + ...
    "|" + strip(string(roiValues)));
end


function row = makeSummaryRow()
row = struct( ...
    'Group', "", 'Monkey', "", 'ROI', "", 'CueIndex', NaN, ...
    'CueName', "", 'NSessions', NaN, 'NRawSignificant', NaN, ...
    'NRawNonsignificant', NaN, ...
    'MeanBias_RawSignificant', NaN, 'MedianBias_RawSignificant', NaN, ...
    'MeanBias_RawNonsignificant', NaN, ...
    'MedianBias_RawNonsignificant', NaN, 'MeanBiasDifference', NaN, ...
    'MeanAbsBias_RawSignificant', NaN, ...
    'MedianAbsBias_RawSignificant', NaN, ...
    'MeanAbsBias_RawNonsignificant', NaN, ...
    'MedianAbsBias_RawNonsignificant', NaN, ...
    'MeanAbsBiasDifference', NaN, ...
    'WelchP_Signed', NaN, 'WelchP_Absolute', NaN, ...
    'RankSumP_Signed', NaN, 'RankSumP_Absolute', NaN, ...
    'KSP_Distribution', NaN);
end


function adjustedP = benjaminiHochberg(p)
p = p(:);
adjustedP = nan(size(p));
valid = isfinite(p);
values = p(valid);
if isempty(values)
    return
end
[sorted, order] = sort(values);
m = numel(sorted);
adjusted = sorted .* m ./ (1:m)';
adjusted = flipud(cummin(flipud(adjusted)));
adjusted = min(adjusted, 1);
restored = nan(m, 1);
restored(order) = adjusted;
adjustedP(valid) = restored;
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


function makeHistogramFigure(joined, summary, groupLabel, cueLabels, outputFile)
groupData = joined(joined.Group == groupLabel & ...
    isfinite(joined.DeltaBias), :);
limit = max(abs(groupData.DeltaBias), [], 'omitmissing');
if ~isfinite(limit) || limit <= 0
    limit = 1;
end
limit = 1.03 * limit;
edges = linspace(-limit, limit, 17);

fig = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [100, 100, 1250, 900]);
layout = tiledlayout(fig, 2, 2, ...
    'TileSpacing', 'loose', 'Padding', 'compact');
title(layout, sprintf('%s: behavioral bias by vertical-MS Stim effect', ...
    groupLabel));
xlabel(layout, '\DeltaBias = Stim - NonStim');
ylabel(layout, 'Proportion of sessions');

for iCue = 1:numel(cueLabels)
    ax = nexttile(layout);
    data = groupData(groupData.CueName == cueLabels(iCue), :);
    significant = data.MSYStimRawSignificant;
    row = summary(summary.Group == groupLabel & ...
        summary.CueName == cueLabels(iCue), :);
    hold(ax, 'on');
    histogram(ax, data.DeltaBias(~significant), 'BinEdges', edges, ...
        'Normalization', 'probability', 'FaceColor', [0.20, 0.48, 0.75], ...
        'FaceAlpha', 0.58, 'EdgeColor', 'none');
    histogram(ax, data.DeltaBias(significant), 'BinEdges', edges, ...
        'Normalization', 'probability', 'FaceColor', [0.92, 0.45, 0.15], ...
        'FaceAlpha', 0.60, 'EdgeColor', 'none');
    xline(ax, 0, ':k');
    xlim(ax, [-limit, limit]);
    title(ax, sprintf('%s: raw-significant n=%d; other n=%d', ...
        cueLabels(iCue), row.NRawSignificant, row.NRawNonsignificant), ...
        'FontSize', 12);
    text(ax, 0.02, 0.96, sprintf('signed p=%.3g; absolute p=%.3g', ...
        row.RankSumP_Signed, row.RankSumP_Absolute), ...
        'Units', 'normalized', 'VerticalAlignment', 'top', ...
        'FontSize', 8.5, 'Color', [0.25, 0.25, 0.25]);
    grid(ax, 'on');
    box(ax, 'off');
    if iCue == 1
        legend(ax, {'MS raw-nonsignificant', 'MS raw-significant'}, ...
            'Location', 'best');
    end
end

exportgraphics(fig, outputFile, 'Resolution', 220);
close(fig);
end

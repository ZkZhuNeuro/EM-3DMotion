function sim = PlotSimulatedNeurometricFourCues(varargin)
% PlotSimulatedNeurometricFourCues
% Plot simple simulated neurometric functions for the four motion cues.
%
% The simulated neurometric function is:
%   P(neural decision = toward) = lapse + (1 - 2*lapse) * Phi((coh - mu)/sigma)
%
% This review figure has two panels:
%   1) MT 2D: combined/stereo are shallow because opponent retinal-motion
%      signals are not integrated well.
%   2) FST 3D: combined is steepest, illustrating cue integration.
%
% Example:
%   sim = PlotSimulatedNeurometricFourCues;
%   sim = PlotSimulatedNeurometricFourCues( ...
%       'ExportPath', 'C:\EM\SimulatedNeurometricFourCues.png');

p = inputParser;
p.addParameter('Visible', 'on', @(x) ischar(x) || isstring(x));
p.addParameter('ExportPath', '', @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opt = p.Results;

xFine = linspace(-1, 1, 1000);

cueNames = {'Combined', 'L Mono', 'R Mono', 'Stereo'};
cueColors = [0 0 0; ...
    0 0 255; ...
    5 150 5; ...
    234 0 233] ./ 255;

nCues = numel(cueNames);

panels = struct;
panels(1).name = 'MT 2D';
panels(1).mu = [0.00, 0.00, 0.00, 0.00];
panels(1).sigma = [0.80, 0.16, 0.22, 0.62];
panels(1).lapse = [0.02, 0.02, 0.02, 0.02];

panels(2).name = 'FST 3D';
panels(2).mu = [0.00, 0.00, 0.00, 0.00];
panels(2).sigma = [0.12, 0.38, 0.52, 0.24];
panels(2).lapse = [0.02, 0.02, 0.02, 0.02];

fig = figure('Color', 'w', ...
    'Name', 'Simulated neurometric functions: MT and FST', ...
    'Visible', char(opt.Visible), ...
    'Units', 'pixels', ...
    'Position', [100 100 1120 520]);

tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = gobjects(1, numel(panels));
lineHandles = gobjects(numel(panels), nCues);
curveValues = nan(numel(panels), nCues, numel(xFine));

for iPanel = 1:numel(panels)
    ax(iPanel) = nexttile(tl);
    hold(ax(iPanel), 'on');

    plot(ax(iPanel), [-1 1], [0.5 0.5], '--', ...
        'Color', [0.65 0.65 0.65], ...
        'LineWidth', 1, ...
        'HandleVisibility', 'off');
    plot(ax(iPanel), [0 0], [0 1], '--', ...
        'Color', [0.65 0.65 0.65], ...
        'LineWidth', 1, ...
        'HandleVisibility', 'off');

    for iCue = 1:nCues
        y = neurometric_curve(xFine, panels(iPanel).mu(iCue), ...
            panels(iPanel).sigma(iCue), panels(iPanel).lapse(iCue));
        curveValues(iPanel, iCue, :) = y;

        lineHandles(iPanel, iCue) = plot(ax(iPanel), xFine, y, '-', ...
            'Color', cueColors(iCue, :), ...
            'LineWidth', 3.5);
    end

    xlim(ax(iPanel), [-1 1]);
    ylim(ax(iPanel), [0 1]);
    xticks(ax(iPanel), [-1 -0.5 0 0.5 1]);
    yticks(ax(iPanel), 0:0.25:1);
    xlabel(ax(iPanel), 'Signed coherence');
    title(ax(iPanel), panels(iPanel).name, 'FontWeight', 'normal');
    set(ax(iPanel), 'TickDir', 'out', ...
        'Box', 'off', ...
        'FontName', 'Arial', ...
        'FontSize', 16, ...
        'LineWidth', 1.5);
    axis(ax(iPanel), 'square');
end

ylabel(ax(1), 'P(neural decision = toward)');
legend(ax(2), lineHandles(2, :), cueNames, 'Location', 'southeast');

exportPath = char(opt.ExportPath);
if ~isempty(exportPath)
    exportDir = fileparts(exportPath);
    if ~isempty(exportDir) && ~exist(exportDir, 'dir')
        mkdir(exportDir);
    end
    exportgraphics(fig, exportPath, 'Resolution', 300);
end

sim = struct;
sim.figure = fig;
sim.axes = ax;
sim.xFine = xFine;
sim.cueNames = cueNames;
sim.cueColors = cueColors;
sim.panels = panels;
sim.curveValues = curveValues;
sim.sensitivity = nan(numel(panels), nCues);
for iPanel = 1:numel(panels)
    sim.sensitivity(iPanel, :) = 1 ./ panels(iPanel).sigma;
end

end

function p = neurometric_curve(coh, mu, sigma, lapse)
p = lapse + (1 - 2 .* lapse) .* gaussian_cdf(coh, mu, sigma);
p = min(max(p, eps), 1 - eps);
end

function p = gaussian_cdf(x, mu, sigma)
p = 0.5 .* (1 + erf((x - mu) ./ (sigma .* sqrt(2))));
end

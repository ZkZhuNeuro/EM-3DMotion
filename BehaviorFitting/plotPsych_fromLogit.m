function hLine = plotPsych_fromLogit(b0, b1, coh, lineColor, varargin)
% plotPsych_fromLogit
% Plot a psychometric curve defined by:
%   p = sigmoid(b0 + b1 * coh)  where sigmoid(z)=1/(1+exp(-z))
%
% INPUTS
%   b0        : intercept
%   b1        : slope
%   coh       : vector of coherence/stimulus levels (used to set plotting range)
%   lineColor : 1x3 RGB
%
% OPTIONAL name-value pairs
%   'Axes'            : axes handle (default gca)
%   'LineWidth'       : default 2
%   'ExtrapolLength'  : fraction of range to extrapolate (default 0.2)
%   'XLim'            : default [-1 1] (set [] to skip)
%   'PlotDashedEnds'  : true/false (default true)

p = inputParser;
p.addRequired('b0', @(x) isnumeric(x) && isscalar(x));
p.addRequired('b1', @(x) isnumeric(x) && isscalar(x));
p.addRequired('coh', @(x) isnumeric(x) && isvector(x) && ~isempty(x));
p.addRequired('lineColor', @(x) isnumeric(x) && numel(x)==3);

p.addParameter('Axes', [], @(h) isempty(h) || isgraphics(h,'axes'));
p.addParameter('LineWidth', 2, @(x) isnumeric(x) && isscalar(x) && x>0);
p.addParameter('ExtrapolLength', 0.2, @(x) isnumeric(x) && isscalar(x) && x>=0);
p.addParameter('XLim', [-1 1], @(x) isempty(x) || (isnumeric(x) && numel(x)==2));
p.addParameter('PlotDashedEnds', true, @(x) islogical(x) && isscalar(x));
p.parse(b0, b1, coh, lineColor, varargin{:});
opt = p.Results;

ax = opt.Axes;
if isempty(ax), ax = gca; end
axes(ax);

coh = coh(:);
coh = coh(isfinite(coh));
if isempty(coh)
    error('coh is empty after removing non-finite values.');
end

xmin = min(coh);
xmax = max(coh);
xlength = xmax - xmin;
if xlength == 0
    xlength = 1; % avoid degenerate range
end

xGrid = linspace(xmin, xmax, 1000);
pGrid = sigmoid01(b0 + b1 .* xGrid);

holdState = ishold(ax);
hold(ax, 'on');

hLine = plot(ax, xGrid, pGrid, '-', 'Color', lineColor, 'LineWidth', 3);

if opt.PlotDashedEnds && opt.ExtrapolLength > 0
    xLow  = linspace(xmin - opt.ExtrapolLength*xlength, xmin, 100);
    xHigh = linspace(xmax, xmax + opt.ExtrapolLength*xlength, 100);
    pLow  = sigmoid01(b0 + b1 .* xLow);
    pHigh = sigmoid01(b0 + b1 .* xHigh);

    plot(ax, xLow,  pLow,  '-', 'Color', lineColor, 'LineWidth', opt.LineWidth);
    plot(ax, xHigh, pHigh, '-', 'Color', lineColor, 'LineWidth', opt.LineWidth);
end

ylim(ax, [0 1]);
set(ax, 'TickDir', 'out');
box(ax, 'off');

if ~isempty(opt.XLim)
    xlim(ax, opt.XLim);
end
xtickangle(ax, 0);

if ~holdState
    hold(ax, 'off');
end

end

% ---- helper ----
function y = sigmoid01(z)
y = 1 ./ (1 + exp(-z));
end
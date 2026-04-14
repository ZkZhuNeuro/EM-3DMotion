function out = fitPlotPsych_fixedAsym(Data, lineColor, plotfit, varargin)
% fitPlotPsych_fixedAsym
% Fit psychometric data with lower & upper asymptotes fixed to 0
% (guess rate gamma=0, lapse rate lambda=0), then plot like plotPsych.m.
%
% INPUTS
%   Data      : Nx3 matrix [x, k, n]
%              x = stimulus level
%              k = # successes (e.g., chose "towards")
%              n = # trials
%   lineColor : 1x3 RGB for curve and markers
%
% OPTIONAL name-value pairs
%   'Axes'            : axes handle (default gca)
%   'LineWidth'       : default 2
%   'PlotData'        : default true
%   'ExtrapolLength'  : fraction of x-range to extrapolate (default 0.2)
%   'DataSizeScale'   : dot size scale (default 10000/sum(n))
%   'XLim'            : default [-1 1]
%   'LogX'            : true/false, fit in log-x (default false; requires x>0)
%   'Verbose'         : true/false, default false
%
% OUTPUT (struct)
%   out.params.alpha  : threshold/location
%   out.params.beta   : slope/scale
%   out.params.gamma  : fixed 0
%   out.params.lambda : fixed 0
%   out.negLL         : negative log likelihood at optimum
%   out.hLine         : line handle
%   out.hData         : data point handles
%   out.xGrid         : x grid used for plot
%   out.pGrid         : fitted p(x) on grid

% ---------------- Parse & validate ----------------
p = inputParser;
p.addRequired('Data', @(x) isnumeric(x) && size(x,2)==3);
p.addRequired('lineColor', @(x) isnumeric(x) && numel(x)==3);
p.addParameter('Axes', [], @(h) isempty(h) || isgraphics(h,'axes'));
p.addParameter('LineWidth', 2, @(x) isnumeric(x) && isscalar(x) && x>0);
p.addParameter('PlotData', true, @(x) islogical(x) && isscalar(x));
p.addParameter('ExtrapolLength', 0.2, @(x) isnumeric(x) && isscalar(x) && x>=0);
p.addParameter('DataSizeScale', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x>0));
p.addParameter('XLim', [-1 1], @(x) isnumeric(x) && numel(x)==2);
p.addParameter('LogX', false, @(x) islogical(x) && isscalar(x));
p.addParameter('Verbose', false, @(x) islogical(x) && isscalar(x));
p.parse(Data, lineColor, varargin{:});
opt = p.Results;

ax = opt.Axes;
if isempty(ax), ax = gca; end
axes(ax);

% Clean rows & basic checks
x = Data(:,1);
k = Data(:,2);
n = Data(:,3);

valid = isfinite(x) & isfinite(k) & isfinite(n) & n>0 & k>=0 & k<=n;
x = x(valid); k = k(valid); n = n(valid);

if isempty(x)
    out = struct('params',[],'negLL',[],'hLine',[],'hData',[], ...
                 'xGrid',[],'pGrid',[]);
    return
end

% If LogX, enforce x>0
if opt.LogX
    if any(x<=0)
        error('LogX=true requires all x>0.');
    end
end

% ---------------- Fit (MLE, logistic, binomial) ----------------
% Model: p(x) = 1/(1+exp(-(x-alpha)/beta))
% with gamma=0, lambda=0 fixed.

% Parameterization: optimize in unconstrained space:
% alpha free, beta>0 => beta = exp(theta2)
% (This makes fitting stable.)

if opt.LogX
    xFit = log(x);
else
    xFit = x;
end

% Reasonable init:
% alpha0: x at ~50% response (rough)
pHat = k./n;
[~, idx] = min(abs(pHat - 0.5));
alpha0 = xFit(idx);

% beta0: spread of x; avoid tiny
beta0 = max(std(xFit), 1e-2);

theta0 = [alpha0; log(beta0)];

negLLfun = @(theta) negLL_binom_logistic(theta, xFit, k, n);

% Use fminsearch (no toolbox dependency). You can swap to fminunc if you want.
opts = optimset('Display', ternary(opt.Verbose,'iter','off'), ...
                'MaxIter', 2000, 'MaxFunEvals', 4000);
[thetaHat, fval] = fminsearch(negLLfun, theta0, opts);

alphaHat = thetaHat(1);
betaHat  = exp(thetaHat(2));

% ---------------- Build plot grids (same style as your code) ----------------
% Solid line across data range; dashed extrapolated ends.
if opt.LogX
    xOK = x(x>0);
    xmin = min(xOK); xmax = max(xOK);
    xlength = log(xmax) - log(xmin);

    xGrid  = exp(linspace(log(xmin), log(xmax), 1000));
    xLow   = exp(linspace(log(xmin) - opt.ExtrapolLength*xlength, log(xmin), 100));
    xHigh  = exp(linspace(log(xmax), log(xmax) + opt.ExtrapolLength*xlength, 100));
else
    xmin = min(x); xmax = max(x);
    xlength = xmax - xmin;

    xGrid = linspace(xmin, xmax, 1000);
    xLow  = linspace(xmin - opt.ExtrapolLength*xlength, xmin, 100);
    xHigh = linspace(xmax, xmax + opt.ExtrapolLength*xlength, 100);
end

% Evaluate fitted curve (gamma=0, lambda=0 => pure sigmoid)
if opt.LogX
    pGrid  = logistic_sigmoid(log(xGrid), alphaHat, betaHat);
    pLow   = logistic_sigmoid(log(xLow),  alphaHat, betaHat);
    pHigh  = logistic_sigmoid(log(xHigh), alphaHat, betaHat);
else
    pGrid  = logistic_sigmoid(xGrid, alphaHat, betaHat);
    pLow   = logistic_sigmoid(xLow,  alphaHat, betaHat);
    pHigh  = logistic_sigmoid(xHigh, alphaHat, betaHat);
end

% ---------------- Plot (match your style) ----------------
holdState = ishold(ax);
if ~holdState
    cla(ax);
end
hold(ax, 'on');

% Marker size scaling like your original
if isempty(opt.DataSizeScale)
    dataSizeScale = 10000 ./ sum(n);
else
    dataSizeScale = opt.DataSizeScale;
end

% Plot data
if opt.PlotData
    % Preallocate handles
    if verLessThan('matlab','8.1')
        hData = zeros(numel(x),1);
    else
        hData = gobjects(numel(x),1);
    end

    for i = 1:numel(x)
        ms = sqrt(dataSizeScale * n(i));
        hData(i) = plot(ax, x(i), k(i)./n(i), '.', ...
            'MarkerSize', ms, 'Color', lineColor);
    end
else
    hData = [];
end

% Plot fit
if plotfit
hLine = plot(ax, xGrid,  pGrid,  'Color', lineColor, 'LineWidth', opt.LineWidth);
plot(ax, xLow,  pLow,  '--', 'Color', lineColor, 'LineWidth', opt.LineWidth);
plot(ax, xHigh, pHigh, '--', 'Color', lineColor, 'LineWidth', opt.LineWidth);
out.hLine  = hLine;
end

% Axis styling (like your code)
axis(ax,'tight');
set(ax,'FontSize',18);
ylim(ax,[0 1]);
set(ax,'TickDir','out');
box(ax,'off');

if opt.LogX
    set(ax,'XScale','log');
end

xlim(ax, opt.XLim);
xtickangle(ax,0);

if ~holdState
    hold(ax,'off');
end

% ---------------- Pack outputs ----------------
out = struct();
out.params = struct('alpha', alphaHat, 'beta', betaHat, 'gamma', 0, 'lambda', 0);
out.negLL  = fval;

out.hData  = hData;
out.xGrid  = xGrid;
out.pGrid  = pGrid;

end

% ===== Helper functions =====

function nll = negLL_binom_logistic(theta, x, k, n)
% theta(1)=alpha, theta(2)=log(beta)
alpha = theta(1);
beta  = exp(theta(2));
p = logistic_sigmoid(x, alpha, beta);

% Clamp to avoid log(0)
p = min(max(p, 1e-9), 1-1e-9);

% Binomial negative log-likelihood (ignores combinatorial term)
nll = -sum(k .* log(p) + (n-k) .* log(1-p));
end

function p = logistic_sigmoid(x, alpha, beta)
% Logistic psychometric: p = 1/(1+exp(-(x-alpha)/beta))
z = (x - alpha) ./ beta;
p = 1 ./ (1 + exp(-z));
end

function y = ternary(cond, a, b)
if cond, y = a; else, y = b; end
end

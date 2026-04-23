function [p_fit, within] = Fit2DGaussian_RF(rawRFmap, uniXPos, uniYPos, meanXYpos)
%% Settings
disp('Fitting 2D Gaussian curve...');
windowWidth = 1920; %(pixels)
windowHeight = 1080; %(pixels)
viewingDistance = 570; %(mm)
ScreenWidth = 635; %(mm)
ScreenHeight = 358; %(mm)
mm2deg = @(x) atand(x./viewingDistance);
pix2mm = @(x) x.*ScreenWidth./windowWidth;
mm2pix = @(x) x.*windowWidth./ScreenWidth;
pix2deg = @(x) mm2deg(pix2mm(x));
WindowCenter = [windowWidth/2, windowHeight/2];
StimOnID = 118; %Event ID: Stimulus onset
PSTH_preWinT = 0.05; PSTH_postWinT = 0.05; %seconds
Label_FontSize = 8; Text_FontSize = 8; Title_FontSize = 10; Tick_FontSize = 6;

xVal = reshape(meanXYpos(:,1), numel(uniYPos), numel(uniXPos));
yVal = reshape(meanXYpos(:,2), numel(uniYPos), numel(uniXPos));
xVal_deg = round(atand(pix2mm(xVal-WindowCenter(1))/viewingDistance),2); %round(pix2deg(xVal-WindowCenter(1)), 2);
yVal_deg = round(atand(pix2mm(WindowCenter(2)-yVal)/viewingDistance),2);

[sizey, sizex] = size(rawRFmap);
[x,y] = meshgrid(1:sizex,1:sizey);
XTick4map = round(linspace(min(xVal(1,:)), max(xVal(1,:)), 10), 1);
YTick4map = round(linspace(min(yVal(:,1)), max(yVal(:,1)), 10), 1);
XTick4map_deg = round(pix2deg(XTick4map-WindowCenter(1)), 1);
YTick4map_deg = round(pix2deg(WindowCenter(2)-YTick4map), 1);

%% Define initial guess for the parameters
[cx,cy,sx,sy] = centerofmass(rawRFmap);
% max_RF = max(rawRFmap, [], 'all');
% [cx,cy]=find(rawRFmap==max_RF);
DC_0 = mean(rawRFmap, "all");
p0 = [DC_0 1 1 1 1 cx cy];

% model (real-only)
gaussian2D = @(x, y, p) p(1) + p(2) .* exp(-(1/2) .* ( ...
    p(3) .* (x - p(6)).^2 + ...
    p(4) .* (x - p(6)) .* (y - p(7)) + ...
    p(5) .* (y - p(7)).^2 ));

% SSE objective
sse = @(p) sum((gaussian2D(x, y, p) - rawRFmap).^2, 'all');

% Nonlinear constraint for positive definiteness:
% c(p) <= 0 form
nonlcon = @(p) deal( ...
    [ ...
      -(p(3));                 % enforce A > 0  ->  -A <= 0
      -(p(5));                 % enforce C > 0  ->  -C <= 0
      (p(4)^2 - 4*p(3)*p(5))   % enforce 4AC - B^2 > 0 -> B^2-4AC < 0
    ], ...
    [] ...
);

% bounds (make sure these are sensible for your grid size)
lb = [0 0 0  -10 0  0  0];
ub = [200 100 10 10 10 30 30];

p0 = real(p0);

opts = optimoptions('fmincon', ...
    'Algorithm','interior-point', ...
    'MaxFunctionEvaluations',1e6, ...
    'MaxIterations',1e4, ...
    'OptimalityTolerance',1e-10, ...
    'StepTolerance',1e-10, ...
    'Display','off');

p_fit = fmincon(@(p) sse(real(p)), p0, [], [], [], [], lb, ub, @(p) nonlcon(real(p)), opts);
p_fit = real(p_fit);

A = p_fit(3);
B = p_fit(4);
C = p_fit(5);
h = p_fit(6);
k = p_fit(7);
within = A * (x-h).^2/(1.1)^2 + B * (x - h) .* (y - k) / (1.1)^2 + C * (y-k).^2/(1.1)^2 <= 1; % Is this correct?
end
function [RFCenter_char, RFCenter_char_old, r_new, r_old, area, area_old, fitIdx] = Fit2DGaussian_Subplot(rawRFmap, uniXPos, uniYPos, meanXYpos, Date, ROI)
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
xStep = uniXPos(2) - uniXPos(1);
yStep = uniYPos(2) - uniYPos(1);

%%
% gaussian2D = @(x, y, p) DC + G * exp(-(1/2) * (A * (x - h) .^ 2 + B * (x - h) .* (y - k) + C * (y - k) .^ 2));
% DC = p(1)
% G = p(2)
% A = p(3)
% B = p(4)
% C = p(5)
% h = p(6)
% k = p(7)
gaussian2D = @(x, y, p) p(1) + p(2) * exp(-(1/2) * (p(3) * (x - p(6)) .^ 2 + p(4) * (x - p(6)) .* (y - p(7)) + p(5) * (y - p(7)) .^ 2));

%% Define initial guess for the parameters
[cx,cy,sx,sy] = centerofmass(rawRFmap);
if Date == datetime('01-Apr-2023')
    cx = 4;
    cy = 9;
    sx = 0.5;
    sy = 0.5;
elseif Date == datetime('08-Feb-2023')
    cx = 3;
    cy = 10;
    sx = 0.5;
    sy = 0.5;
elseif Date == datetime('22-Apr-2023')
    cx = 5;
    cy = 11;
    sx = 0.5;
    sy = 0.5;
end
DC_0 = mean(rawRFmap, "all");
p0 = [DC_0 1 1 0.5 1 cx cy];

%% Define the objective function for fitting
objective = @(p, xy) gaussian2D(xy(:, :, 1), xy(:, :, 2), p);
lb = [0 0 0 -10 0 0 0];
ub = [200 100 10 10 10 30 30];

%% Fit the Gaussian function using least squares
xy(:, :, 1) = x;
xy(:, :, 2) = y;
options = optimoptions(@fmincon, 'MaxFunctionEvaluation', 1e10, 'FunctionTolerance', 1e-10, 'MaxIterations', 1e4);
p_fit = lsqcurvefit(objective, p0, xy, rawRFmap, lb, ub, options);
A = p_fit(3);
B = p_fit(4);
C = p_fit(5);
h = p_fit(6);
k = p_fit(7);
% within = A * (x-h).^2/(1.1)^2 + B * (x - h) .* (y - k) / (1.1)^2 + C * (y-k).^2/(1.1)^2 <= 1; % Is this correct?

%% Compute the fitted function values
z_fit = gaussian2D(x, y, p_fit);

rawRFmap_linear = reshape(rawRFmap, [], 1);
z_fit_linear = reshape(z_fit, [], 1);
r_new = corr(rawRFmap_linear, z_fit_linear);
if r_new < 0.3
    fitIdx = 0;
else
    fitIdx = 1;
end
% if fitIdx == 1

a = sqrt(2 / (A + C + sqrt((A - C) ^ 2 + B ^ 2)));
b = sqrt(2 / (A + C - sqrt((A - C) ^ 2 + B ^ 2)));

a_pixel = a * xStep;
b_pixel = b * yStep;
a_deg = pix2deg(a_pixel);
b_deg = pix2deg(b_pixel);


area = sqrt(a_deg * b_deg * pi);

%% Fit with the old method
try
    [c_x,c_y,s_x,s_y,PeakOD,DC] = Gaussian2D(rawRFmap,1*10^-10);
    %         [cx,cy,sx,sy,PeakOD,DC,theta] = Gaussian2D_wRot(rawRFmap,1*10^-10);
catch
    warning('Unable to fit 2D Gaussian');
    fitIdx = 0;
    c_x = NaN;
    c_y = NaN;
    s_x = NaN;
    s_y = NaN;
    PeakOD = NaN;
    DC = NaN;
    theta = NaN;
end
if fitIdx == 1
    fit_old = DC + abs(PeakOD)*(exp(-0.5*(x-c_x).^2./(s_x^2)-0.5*(y-c_y).^2./(s_y^2)));
    s_x_pixel = s_x * xStep;
    s_y_pixel = s_y * yStep;
    s_x_deg = pix2deg(s_x_pixel);
    s_y_deg = pix2deg(s_y_pixel);

    area_old = sqrt(round(s_x_deg * s_y_deg * pi, 2));

    RF_centerX = (h - 1) * xStep + uniXPos(1);
    RF_centerY = (k - 1) * yStep + uniYPos(1);
    RF_centerX_pix = (h - 1) * xStep + uniXPos(1);
    RF_centerY_pix = (k - 1) * yStep + uniYPos(1);
    RF_centerX = round(atand(pix2mm(RF_centerX-WindowCenter(1))/viewingDistance),2);
    RF_centerY = round(atand(pix2mm(WindowCenter(2)-RF_centerY)/viewingDistance),2);
    RFCenter_char = char(append("[", num2str(RF_centerX), ",", num2str(RF_centerY), "]"));
    RF_Ecc = round(sqrt(RF_centerX^2 + RF_centerY^2), 2);

    RF_centerX_old = (c_x - 1) * xStep + uniXPos(1);
    RF_centerY_old = (c_y - 1) * yStep + uniYPos(1);
    RF_centerX_old_pix = (c_x - 1) * xStep + uniXPos(1);
    RF_centerY_old_pix = (c_y - 1) * yStep + uniYPos(1);
    RF_centerX_old = round(atand(pix2mm(RF_centerX_old-WindowCenter(1))/viewingDistance),2);
    RF_centerY_old = round(atand(pix2mm(WindowCenter(2)-RF_centerY_old)/viewingDistance),2);
    RFCenter_char_old = char(append("[", num2str(RF_centerX_old), ",", num2str(RF_centerY_old), "]"));
    RF_Ecc_old = round(sqrt(RF_centerX_old^2 + RF_centerY_old^2), 2);

    %% Plot the results
    subplot(3, 4, 2);
    imagesc(xVal(:), yVal(:), rawRFmap); colormap('parula');
    axis on;
    axis square;
    caxis([min(rawRFmap(:)) max(rawRFmap(:))]); hold on;
    xlim([min(xVal(:)),max(xVal(:))]); ylim([min(yVal(:)),max(yVal(:))]);
    hold on 
    plot([min(xVal(:)),max(xVal(:))], [windowHeight/2, windowHeight/2], 'Color', [1 1 1], 'LineWidth', 2)
    plot([windowWidth/2, windowWidth/2], [min(yVal(:)),max(yVal(:))], 'Color', [1 1 1], 'LineWidth', 2)
    set(gca, 'XTick', XTick4map, 'YTick', YTick4map, 'FontSize', Tick_FontSize);
    set(gca, 'XTickLabel', num2cell(XTick4map_deg), 'box', 'on')
    set(gca, 'YTickLabel', num2cell(YTick4map_deg), 'TickDir', 'out', 'Layer', 'top')
    set(gca,'YDir','reverse');
    title(ROI, 'FontSize', 10);

    subplot(3, 4, 3);
    imagesc(xVal(:), yVal(:), z_fit); colormap('parula');
    hold on
    axis square;
    axis on;
    caxis([min(z_fit, [], "all") max(z_fit, [], "all")]);
    xlim([min(xVal(:)),max(xVal(:))]);
    ylim([min(yVal(:)),max(yVal(:))]);
    hold on 
    plot([min(xVal(:)),max(xVal(:))], [windowHeight/2, windowHeight/2], 'Color', [1 1 1], 'LineWidth', 2)
    plot([windowWidth/2, windowWidth/2], [min(yVal(:)),max(yVal(:))], 'Color', [1 1 1], 'LineWidth', 2)
    set(gca, 'XTick', XTick4map, 'YTick', YTick4map, 'FontSize', Tick_FontSize);
    set(gca, 'XTickLabel', num2cell(XTick4map_deg), 'box', 'on')
    set(gca, 'YTickLabel', num2cell(YTick4map_deg), 'TickDir', 'out', 'Layer', 'top')
    set(gca,'YDir','reverse');
%     title('Fitted Gaussian');
    x_curve = linspace(min(x, [], 'all'), max(x, [], 'all'), 10000);
    discriminant = B^2 * (x_curve - h) .^ 2 - 4 * C * (A * (x_curve - h) .^ 2 - 1);
    x_curve = x_curve(find(discriminant >= 0));
    y_curve_positive = (-B * (x_curve - h) + sqrt(B^2 * (x_curve - h) .^ 2 - 4 * C * (A * (x_curve - h) .^ 2 - 1))) / (2 * C) + k;
    y_curve_negative = (-B * (x_curve - h) - sqrt(B^2 * (x_curve - h) .^ 2 - 4 * C * (A * (x_curve - h) .^ 2 - 1))) / (2 * C) + k;
    x_curve = (x_curve - 1) * xStep + uniXPos(1);
    y_curve_positive = (y_curve_positive - 1) * yStep + uniYPos(1);
    y_curve_negative = (y_curve_negative - 1) * yStep + uniYPos(1);
    plot(x_curve, y_curve_positive, "Color", [1 0 0], "LineWidth", 2)
    plot(x_curve, y_curve_negative, "Color", [1 0 0], "LineWidth", 2)
    plot([x_curve(1), x_curve(1)], [y_curve_negative(1), y_curve_positive(1)], "Color", [1 0 0], "LineWidth", 2)
    plot([x_curve(end), x_curve(end)], [y_curve_negative(end), y_curve_positive(end)], "Color", [1 0 0], "LineWidth", 2)
    title(['Center: ', RFCenter_char, ', Ecc: ', num2str(RF_Ecc),  ', sqrt(Area): ', num2str(area)], 'FontSize', 10);
    scatter(RF_centerX_pix, RF_centerY_pix, 20, 'red', 'filled')

%     subplot(3, 4, 3);
%     imagesc(xVal(:), yVal(:), fit_old); colormap('parula');
% %     title('Old Fitted Gaussian');
%     hold on
%     axis on;
%     axis square;
%     caxis([min(fit_old, [], "all") max(fit_old, [], "all")]);
%     xlim([min(xVal(:)),max(xVal(:))]);
%     ylim([min(yVal(:)),max(yVal(:))]);
%     set(gca, 'XTick', XTick4map, 'YTick', YTick4map, 'FontSize', Tick_FontSize);
%     set(gca, 'XTickLabel', num2cell(XTick4map_deg), 'box', 'on')
%     set(gca, 'YTickLabel', num2cell(YTick4map_deg), 'TickDir', 'out', 'Layer', 'top')
%     set(gca,'YDir','reverse');
%     title(['Center: ', RFCenter_char_old, ', Ecc: ', num2str(RF_Ecc_old),  ', sqrt(Area): ', num2str(area_old)], 'FontSize', 10);
%     scatter(RF_centerX_old_pix, RF_centerY_old_pix, 20, 'red', 'filled')

    %% Test which is better
    fit_linear = reshape(fit_old, [], 1);

    r_old = corr(rawRFmap_linear, fit_linear);

    %%

else
    subplot(3, 4, 2);
    imagesc(xVal(:), yVal(:), rawRFmap); colormap('parula');
    axis on;
    axis square;
    caxis([min(rawRFmap(:)) max(rawRFmap(:))]); hold on;
    xlim([min(xVal(:)),max(xVal(:))]); ylim([min(yVal(:)),max(yVal(:))]);
    hold on 
    plot([min(xVal(:)),max(xVal(:))], [windowHeight/2, windowHeight/2], 'Color', [1 1 1], 'LineWidth', 2)
    plot([windowWidth/2, windowWidth/2], [min(yVal(:)),max(yVal(:))], 'Color', [1 1 1], 'LineWidth', 2)
    set(gca, 'XTick', XTick4map, 'YTick', YTick4map, 'FontSize', Tick_FontSize);
    set(gca, 'XTickLabel', num2cell(XTick4map_deg), 'box', 'on')
    set(gca, 'YTickLabel', num2cell(YTick4map_deg), 'TickDir', 'out', 'Layer', 'top')
    set(gca,'YDir','reverse');
    title(ROI, 'FontSize', 10);
    RFCenter_char = NaN;
    RFCenter_char_old = NaN;
    r_old = NaN;
    area = NaN;
    area_old = NaN;
end
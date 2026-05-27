% generate_quadratic_ridge_mesh.m
%
% Creates a 3D mesh where the surface is constant along x and follows
% a quadratic ridge profile along y:
%
%     z = a*y^2 + b*y + c
%
% Because z depends only on y, every x-slice has the same shape.

clear;
clc;

% Quadratic coefficients for the ridge profile in y.
a = -10;
b = 0.0;
c = 4.0;

% Sampling ranges.
xVals = linspace(-10, 10, 1000);
yVals = linspace(-10, 10, 1600);
radius = 10;

% Build the mesh grid.
[X, Y] = meshgrid(xVals, yVals);

% Surface is constant along x and quadratic along y.
Z = a .* Y.^2 + b .* Y + c;

% Keep only a circular footprint in the x-y plane.
circleMask = X.^2 + Y.^2 <= radius^2;
Z(~circleMask) = NaN;

% Plot.
figure('Color', 'w');
hold on;

% Draw a colored surface using the Z gradient.
hSurf = surf(X, Y, Z, Z);
set(hSurf, 'EdgeColor', 'none', ...
    'FaceAlpha', 1.0);
colormap([linspace(0, 1, 256)', linspace(1, 0, 256)', zeros(256, 1)]);

theta = linspace(0, 2*pi, 500);
xBoundary = radius * cos(theta);
yBoundary = radius * sin(theta);
zBoundary = a .* yBoundary.^2 + b .* yBoundary + c;
plot3(xBoundary, yBoundary, zBoundary, 'Color', [0.45, 0.45, 0.45], ...
    'LineWidth', 3);

hold off;
grid off;
axis tight;
axis off;
view(40, 28);

% Plot the vector field separately on the x-y plane.
controlFig = figure('Color', 'w', 'Name', 'Interactive 2D Vector Field', ...
    'NumberTitle', 'off', 'Position', [100, 100, 1000, 720]);
ax2D = axes('Parent', controlFig, 'Position', [0.08, 0.23, 0.72, 0.70]);

app.ax = ax2D;
app.radius = radius;
app.a = a;
app.b = b;
app.c = c;
app.zMin = min(Z(circleMask));
app.zMax = max(Z(circleMask));
app.xBoundary = xBoundary;
app.yBoundary = yBoundary;

app.controls.length = uicontrol(controlFig, 'Style', 'slider', ...
    'Min', 0.2, 'Max', 4.0, 'Value', 1.6, ...
    'Units', 'normalized', 'Position', [0.84, 0.78, 0.12, 0.04], ...
    'Callback', @(~, ~) updateVectorField(controlFig));
app.labels.length = uicontrol(controlFig, 'Style', 'text', ...
    'String', 'Arrow Length', 'BackgroundColor', 'w', ...
    'Units', 'normalized', 'Position', [0.84, 0.82, 0.12, 0.03]);
app.values.length = uicontrol(controlFig, 'Style', 'text', ...
    'String', '', 'BackgroundColor', 'w', ...
    'Units', 'normalized', 'Position', [0.84, 0.75, 0.12, 0.03]);

app.controls.width = uicontrol(controlFig, 'Style', 'slider', ...
    'Min', 0.5, 'Max', 4.0, 'Value', 1.4, ...
    'Units', 'normalized', 'Position', [0.84, 0.60, 0.12, 0.04], ...
    'Callback', @(~, ~) updateVectorField(controlFig));
app.labels.width = uicontrol(controlFig, 'Style', 'text', ...
    'String', 'Arrow Width', 'BackgroundColor', 'w', ...
    'Units', 'normalized', 'Position', [0.84, 0.64, 0.12, 0.03]);
app.values.width = uicontrol(controlFig, 'Style', 'text', ...
    'String', '', 'BackgroundColor', 'w', ...
    'Units', 'normalized', 'Position', [0.84, 0.57, 0.12, 0.03]);

app.controls.xSpacing = uicontrol(controlFig, 'Style', 'slider', ...
    'Min', 0.8, 'Max', 4.5, 'Value', 1.8, ...
    'Units', 'normalized', 'Position', [0.84, 0.42, 0.12, 0.04], ...
    'Callback', @(~, ~) updateVectorField(controlFig));
app.labels.xSpacing = uicontrol(controlFig, 'Style', 'text', ...
    'String', 'Horizontal Density', 'BackgroundColor', 'w', ...
    'Units', 'normalized', 'Position', [0.84, 0.46, 0.12, 0.03]);
app.values.xSpacing = uicontrol(controlFig, 'Style', 'text', ...
    'String', '', 'BackgroundColor', 'w', ...
    'Units', 'normalized', 'Position', [0.84, 0.39, 0.12, 0.03]);

app.controls.ySpacing = uicontrol(controlFig, 'Style', 'slider', ...
    'Min', 0.8, 'Max', 4.5, 'Value', 1.8, ...
    'Units', 'normalized', 'Position', [0.84, 0.24, 0.12, 0.04], ...
    'Callback', @(~, ~) updateVectorField(controlFig));
app.labels.ySpacing = uicontrol(controlFig, 'Style', 'text', ...
    'String', 'Vertical Density', 'BackgroundColor', 'w', ...
    'Units', 'normalized', 'Position', [0.84, 0.28, 0.12, 0.03]);
app.values.ySpacing = uicontrol(controlFig, 'Style', 'text', ...
    'String', '', 'BackgroundColor', 'w', ...
    'Units', 'normalized', 'Position', [0.84, 0.21, 0.12, 0.03]);

guidata(controlFig, app);
updateVectorField(controlFig);

% Plot a 2D circle with a vertical red-to-green speed gradient.
figure('Color', 'w');

circleRes = 800;
[Xc, Yc] = meshgrid(linspace(-radius, radius, circleRes), ...
    linspace(-radius, radius, circleRes));
circleColor = a .* Yc.^2 + b .* Yc + c;
circleColor(Xc.^2 + Yc.^2 > radius^2) = NaN;

hCircle = surf(Xc, Yc, zeros(size(Xc)), circleColor);
set(hCircle, 'EdgeColor', 'none');
colormap([linspace(0, 1, 256)', linspace(1, 0, 256)', zeros(256, 1)]);
hold on;
plot(xBoundary, yBoundary, 'Color', [0.35, 0.35, 0.35], 'LineWidth', 2.0);
hold off;
axis equal;
axis tight;
axis off;
view(2);

function updateVectorField(controlFig)
app = guidata(controlFig);

arrowLength = app.controls.length.Value;
arrowWidth = app.controls.width.Value;
xSpacing = app.controls.xSpacing.Value;
ySpacing = app.controls.ySpacing.Value;

[Xv, Yv] = meshgrid(-app.radius:xSpacing:app.radius, -app.radius:ySpacing:app.radius);
vectorMask = Xv.^2 + Yv.^2 <= app.radius^2;
Zv = app.a .* Yv.^2 + app.b .* Yv + app.c;
motionSignal = 2 * (Zv - app.zMin) ./ (app.zMax - app.zMin) - 1;
Uv = arrowLength * motionSignal;
Vv = zeros(size(Uv));

cla(app.ax);
hold(app.ax, 'on');
quiver(app.ax, Xv(vectorMask), Yv(vectorMask), Uv(vectorMask), Vv(vectorMask), ...
    0, 'k', 'LineWidth', arrowWidth, 'MaxHeadSize', 1.2);
plot(app.ax, app.xBoundary, app.yBoundary, 'Color', [0.45, 0.45, 0.45], ...
    'LineWidth', 2.0);
hold(app.ax, 'off');
axis(app.ax, 'equal');
axis(app.ax, 'tight');
axis(app.ax, 'off');

app.values.length.String = sprintf('%.2f', arrowLength);
app.values.width.String = sprintf('%.2f', arrowWidth);
app.values.xSpacing.String = sprintf('%.2f', xSpacing);
app.values.ySpacing.String = sprintf('%.2f', ySpacing);
guidata(controlFig, app);
end

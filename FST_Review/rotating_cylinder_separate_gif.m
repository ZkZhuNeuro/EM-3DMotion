% rotating_cylinder_separate_gif.m
%
% Draws the rotating dotted cylinder projection by itself and saves one GIF.

clear;
clc;

%% User settings
nFrames = 240;
gifDelayTime = 0.035;
gifFile = fullfile(pwd, 'rotating_cylinder_separate.gif');
cylinderRotationCycles = 1.0;

cylinderRadius = 1.4;
cylinderHeight = 3.0;
nDots = 300;
dotSizeCylinder = 200;
cameraAzimuthDeg = 38;

%% Dot positions on the cylinder surface
rng(1);
theta0 = 2*pi*rand(nDots, 1);
z0 = cylinderHeight * (rand(nDots, 1) - 0.5);
x0 = cylinderRadius * cos(theta0);
y0 = cylinderRadius * sin(theta0);
nx0 = cos(theta0);
ny0 = sin(theta0);

%% Build figure
fig = figure('Color', 'w', ...
    'Name', 'Rotating Cylinder Projection GIF', ...
    'NumberTitle', 'off', ...
    'Position', [120, 120, 720, 720]);
ax = axes('Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0.04, 0.04, 0.92, 0.92], ...
    'LooseInset', [0, 0, 0, 0]);
hold(ax, 'on');
axis(ax, 'equal');
axis(ax, 'off');

projectionLimit = 1.12 * max(cylinderRadius, 0.5*cylinderHeight);
axis(ax, [-projectionLimit, projectionLimit, ...
    -projectionLimit, projectionLimit]);

[screenX, screenZ] = get2DProjection(0, x0, y0, z0, nx0, ny0, ...
    cameraAzimuthDeg);
dotHandle = scatter(ax, screenX, screenZ, dotSizeCylinder, 'k', 'filled');

%% Animate and save GIF
if exist(gifFile, 'file')
    delete(gifFile);
end

for iFrame = 1:nFrames
    normalizedTime = (iFrame - 1) / nFrames;
    cylinderAngleDeg = 360*cylinderRotationCycles * normalizedTime;
    [screenX, screenZ] = get2DProjection(cylinderAngleDeg, x0, y0, z0, ...
        nx0, ny0, cameraAzimuthDeg);
    set(dotHandle, 'XData', screenX, 'YData', screenZ);

    drawnow;
    frame = getframe(fig);
    [im, cmap] = rgb2ind(frame2im(frame), 256);
    if iFrame == 1
        imwrite(im, cmap, gifFile, 'gif', 'LoopCount', inf, ...
            'DelayTime', gifDelayTime);
    else
        imwrite(im, cmap, gifFile, 'gif', 'WriteMode', 'append', ...
            'DelayTime', gifDelayTime);
    end
end

fprintf('Saved cylinder GIF: %s\n', gifFile);

%% Local functions
function [screenX, screenZ] = get2DProjection(angleDeg, x0, y0, z0, ...
    nx0, ny0, cameraAzimuthDeg)
[x, y, z] = rotateCylinderPoints(angleDeg, x0, y0, z0, nx0, ny0);

cameraDirection = [cosd(cameraAzimuthDeg), sind(cameraAzimuthDeg)];
screenRight = [cameraDirection(2), -cameraDirection(1)];
screenRight = screenRight ./ norm(screenRight);

screenX = x .* screenRight(1) + y .* screenRight(2);
screenZ = z;
end

function [x, y, z, nx, ny] = rotateCylinderPoints(angleDeg, ...
    x0, y0, z0, nx0, ny0)
angleRad = deg2rad(angleDeg);
rotMat = [cos(angleRad), -sin(angleRad); ...
          sin(angleRad),  cos(angleRad)];

xy = rotMat * [x0'; y0'];
normalXY = rotMat * [nx0'; ny0'];

x = xy(1, :)';
y = xy(2, :)';
z = z0;
nx = normalXY(1, :)';
ny = normalXY(2, :)';
end

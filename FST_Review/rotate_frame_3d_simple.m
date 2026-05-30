% rotate_frame_3d_simple.m
% Concise demo: draw a bent 3D wire frame and rotate it about a vertical axis.

clear; clc;

nFrames = 240;
pauseTime = 0.01;

fig = figure('Color', 'w', ...
    'Name', 'Rotating 3D Frame', ...
    'NumberTitle', 'off', ...
    'Position', [100, 100, 900, 900]);
ax = axes('Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0, 0, 1, 1], ...
    'LooseInset', [0, 0, 0, 0]);
hold(ax, 'on');
axis(ax, 'equal');
axis(ax, [-2.75, 2.75, -2.75, 2.75, -2.45, 2.95]);
axis(ax, 'off');
view(ax, 38, 22);
camproj(ax, 'perspective');

% Red rotation axis and rotation cue.
red = [1.0, 0.05, 0.08];
plot3(ax, [0, 0], [0, 0], [-2.0, 2.8], ...
    '--', 'Color', red, 'LineWidth', 2.2);
drawRotationCircle(ax, 2.35, -1.95, red);

% Frame points. Each row is [x y z].
B = [ 0.80, -0.80,  0.55];
C = [-0.50,  0.90, -0.22];
D = [ 0.30, -0.50, -1.00];
R2 = [ 1.75, -0.38,  1.45];
R3 = [ 2.05, -0.62, -0.50];

segments = cat(3, ...
    [B; C], ...
    [C; D], ...
    [B; R2], ...
    [R2; R3], ...
    [R3; D]);

frameGroup = hgtransform('Parent', ax);
for iSeg = 1:size(segments, 3)
    p = segments(:, :, iSeg);
    plot3(frameGroup, p(:, 1), p(:, 2), p(:, 3), ...
        '-', 'Color', [0.02, 0.02, 0.02], 'LineWidth', 4.0);
end
lighting(ax, 'gouraud');
material(ax, 'dull');
camzoom(ax, 1.35);

for angle = linspace(0, 2*pi, nFrames)
    frameGroup.Matrix = makehgtform('zrotate', angle);
    drawnow;
    pause(pauseTime);
end

function drawRotationCircle(ax, radius, zLevel, red)
theta = linspace(0, 2*pi, 400);
plot3(ax, radius*cos(theta), radius*sin(theta), ...
    zLevel*ones(size(theta)), '-', 'Color', red, 'LineWidth', 2.0);

for thetaTip = deg2rad([72, 252])
    tip = [radius*cos(thetaTip), radius*sin(thetaTip), zLevel];
    tangent = [-sin(thetaTip), cos(thetaTip), 0];
    radial = [cos(thetaTip), sin(thetaTip), 0];
    base = tip - 0.34*tangent;
    p1 = base + 0.18*radial;
    p2 = base - 0.18*radial;
    plot3(ax, [tip(1), p1(1)], [tip(2), p1(2)], [tip(3), p1(3)], ...
        '-', 'Color', red, 'LineWidth', 2.0);
    plot3(ax, [tip(1), p2(1)], [tip(2), p2(2)], [tip(3), p2(3)], ...
        '-', 'Color', red, 'LineWidth', 2.0);
end
end

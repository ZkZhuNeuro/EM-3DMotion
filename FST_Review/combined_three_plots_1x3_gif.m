% combined_three_plots_1x3_gif.m
%
% Draws the rotating frame, point-light walker, and rotating dotted
% cylinder projection together in one 1x3 layout, then saves one GIF.

clear;
clc;

%% User settings
nFrames = 240;
gifDelayTime = 0.05;
gifFile = fullfile(pwd, 'combined_three_plots_1x3.gif');

frameRotationCycles = 1.0;
walkerStepCycles = 2.0; % two walking repeats per GIF loop
cylinderRotationCycles = 1.0;

%% Shared figure
fig = figure('Color', 'w', ...
    'Name', 'Combined 1x3 Motion GIF', ...
    'NumberTitle', 'off', ...
    'Position', [40, 120, 1800, 620]);

axFrame = axes('Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0.015, 0.08, 0.31, 0.86], ...
    'LooseInset', [0, 0, 0, 0]);

axWalker = axes('Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0.345, 0.08, 0.31, 0.86], ...
    'LooseInset', [0, 0, 0, 0]);

axCylinder = axes('Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0.675, 0.08, 0.31, 0.86], ...
    'LooseInset', [0, 0, 0, 0]);

%% Plot 1: rotating frame
hold(axFrame, 'on');
axis(axFrame, 'equal');
axis(axFrame, [-2.75, 2.75, -2.75, 2.75, -2.45, 2.95]);
axis(axFrame, 'off');
view(axFrame, 38, 22);
camproj(axFrame, 'perspective');
camzoom(axFrame, 1.35);

plot3(axFrame, [0, 0], [0, 0], [-2.0, 2.8], ...
    '--', 'Color', [1.0, 0.05, 0.08], 'LineWidth', 2.2);
drawRotationArrow(axFrame, 2.35, -1.95, [1.0, 0.05, 0.08]);

frameTransform = hgtransform('Parent', axFrame);
drawBentFrame(frameTransform);

%% Plot 2: point-light walker
hold(axWalker, 'on');
axis(axWalker, 'equal');
axis(axWalker, [-1.9, 1.9, 0.0, 4.8]);
axis(axWalker, 'off');

bodyHorizontalMotion = 0.06;
bodyVerticalMotion = 0.035;
bodyLeanMotion = 0.045;
jointVerticalSeparation = 0.06;
dotSizeWalker = 115;
dotColor = [0, 0, 0];
showRedDashedLines = false;

pose = getWalkerPose(0, bodyHorizontalMotion, bodyVerticalMotion, ...
    bodyLeanMotion, jointVerticalSeparation);
jointNames = fieldnames(pose.joints);
[dotX, dotY] = getWalkerJointXY(pose, jointNames);
lineHandles = gobjects(0);
dotHandle = scatter(axWalker, dotX, dotY, dotSizeWalker, dotColor, ...
    'filled', 'MarkerEdgeColor', dotColor, 'LineWidth', 0.8);

%% Plot 3: rotating dotted cylinder 2D projection
hold(axCylinder, 'on');
axis(axCylinder, 'equal');
axis(axCylinder, 'off');

cylinderRadius = 1.4;
cylinderHeight = 3.0;
nDots = 300;
dotSizeCylinder = 200;
cameraAzimuthDeg = 38;

rng(1);
theta0 = 2*pi*rand(nDots, 1);
z0 = cylinderHeight * (rand(nDots, 1) - 0.5);
x0 = cylinderRadius * cos(theta0);
y0 = cylinderRadius * sin(theta0);
nx0 = cos(theta0);
ny0 = sin(theta0);

projectionLimit = 1.12 * max(cylinderRadius, 0.5*cylinderHeight);
axis(axCylinder, [-projectionLimit, projectionLimit, ...
    -projectionLimit, projectionLimit]);

[screenX, screenZ] = get2DProjection(0, x0, y0, z0, nx0, ny0, ...
    cameraAzimuthDeg);
cylinderDotHandle = scatter(axCylinder, screenX, screenZ, ...
    dotSizeCylinder, 'k', 'filled');

%% Animate all three plots and write one GIF
if exist(gifFile, 'file')
    delete(gifFile);
end

for iFrame = 1:nFrames
    normalizedTime = (iFrame - 1) / nFrames;

    frameAngle = 2*pi*frameRotationCycles * normalizedTime;
    frameTransform.Matrix = makehgtform('zrotate', frameAngle);

    walkerPhase = 2*pi*walkerStepCycles * normalizedTime;
    pose = getWalkerPose(walkerPhase, bodyHorizontalMotion, ...
        bodyVerticalMotion, bodyLeanMotion, jointVerticalSeparation);
    updateWalkerPlot(pose, jointNames, dotHandle, lineHandles, ...
        showRedDashedLines);

    cylinderAngleDeg = 360*cylinderRotationCycles * normalizedTime;
    [screenX, screenZ] = get2DProjection(cylinderAngleDeg, x0, y0, z0, ...
        nx0, ny0, cameraAzimuthDeg);
    set(cylinderDotHandle, 'XData', screenX, 'YData', screenZ);

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

fprintf('Saved combined GIF: %s\n', gifFile);

%% Local functions: rotating frame
function drawBentFrame(parentTransform)
lineColor = [0.02, 0.02, 0.02];
lineWidth = 4.0;

B = [ 0.8, -0.8,  0.55];
C = [-0.5,  0.9, -0.22];
D = [ 0.3, -0.5, -1];

segments = {
    B, C
    C, D
    };

R2 = [ 1.75, -0.38,  1.45];
R3 = [ 2.05, -0.62, -0.50];

segments = [segments; {
    B, R2
    R2, R3
    R3, D
    }];

for iSeg = 1:size(segments, 1)
    p1 = segments{iSeg, 1};
    p2 = segments{iSeg, 2};
    plot3(parentTransform, [p1(1), p2(1)], [p1(2), p2(2)], ...
        [p1(3), p2(3)], '-', 'Color', lineColor, ...
        'LineWidth', lineWidth);
end
end

function drawRotationArrow(ax, radius, zLevel, arrowColor)
theta = linspace(0, 2*pi, 400);
x = radius * cos(theta);
y = radius * sin(theta);
z = zLevel * ones(size(theta));
plot3(ax, x, y, z, '-', 'Color', arrowColor, 'LineWidth', 2.0);

drawTangentArrowhead(ax, radius, zLevel, deg2rad(72), arrowColor);
drawTangentArrowhead(ax, radius, zLevel, deg2rad(252), arrowColor);
end

function drawTangentArrowhead(ax, radius, zLevel, theta, arrowColor)
tip = [radius*cos(theta), radius*sin(theta), zLevel];
tangent = [-sin(theta), cos(theta), 0];
radial = [cos(theta), sin(theta), 0];

headLength = 0.34;
headSpread = 0.18;
baseCenter = tip - headLength * tangent;
p1 = baseCenter + headSpread * radial;
p2 = baseCenter - headSpread * radial;

plot3(ax, [tip(1), p1(1)], [tip(2), p1(2)], [tip(3), p1(3)], ...
    '-', 'Color', arrowColor, 'LineWidth', 2.0);
plot3(ax, [tip(1), p2(1)], [tip(2), p2(2)], [tip(3), p2(3)], ...
    '-', 'Color', arrowColor, 'LineWidth', 2.0);
end

%% Local functions: point-light walker
function updateWalkerPlot(pose, jointNames, dotHandle, lineHandles, ...
    showRedDashedLines)
[dotX, dotY] = getWalkerJointXY(pose, jointNames);

if showRedDashedLines
    for iSegment = 1:size(pose.segments, 1)
        p1 = pose.joints.(pose.segments{iSegment, 1});
        p2 = pose.joints.(pose.segments{iSegment, 2});
        lineHandles(iSegment).XData = [p1(1), p2(1)];
        lineHandles(iSegment).YData = [p1(2), p2(2)];
    end
end

dotHandle.XData = dotX;
dotHandle.YData = dotY;
end

function [dotX, dotY] = getWalkerJointXY(pose, jointNames)
nJoints = numel(jointNames);
dotX = zeros(nJoints, 1);
dotY = zeros(nJoints, 1);

for iJoint = 1:nJoints
    xy = pose.joints.(jointNames{iJoint});
    dotX(iJoint) = xy(1);
    dotY(iJoint) = xy(2);
end
end

function pose = getWalkerPose(phase, bodyHorizontalMotion, ...
    bodyVerticalMotion, bodyLeanMotion, jointVerticalSeparation)
phase = mod(phase, 2*pi);

bodyX = bodyHorizontalMotion * sin(phase - 0.2*pi);
bodyY = bodyVerticalMotion * sin(2*phase + 0.35*pi);
bodyLean = bodyLeanMotion * sin(phase + 0.15*pi);

spine = [bodyX + 0.35*bodyLean, 2.65 + bodyY];
neck = [bodyX + bodyLean, 3.55 + bodyY];
head = [bodyX + 1.15*bodyLean, 4.02 + bodyY];

leftLeg = limbPose(spine, phase, true);
rightLeg = limbPose(spine, phase + pi, true);
leftArm = limbPose(neck, phase + pi, false);
rightArm = limbPose(neck, phase, false);

leftLeg.middle(2) = leftLeg.middle(2) + jointVerticalSeparation;
rightLeg.middle(2) = rightLeg.middle(2) - jointVerticalSeparation;
leftArm.middle(2) = leftArm.middle(2) + jointVerticalSeparation;
rightArm.middle(2) = rightArm.middle(2) - jointVerticalSeparation;

joints = struct();
joints.head = head;
joints.neck = neck;
joints.spine = spine;
joints.leftElbow = leftArm.middle;
joints.rightElbow = rightArm.middle;
joints.leftWrist = leftArm.endPoint;
joints.rightWrist = rightArm.endPoint;
joints.leftKnee = leftLeg.middle;
joints.rightKnee = rightLeg.middle;
joints.leftAnkle = leftLeg.endPoint;
joints.rightAnkle = rightLeg.endPoint;

segments = {
    'head', 'neck'
    'neck', 'spine'
    'spine', 'leftKnee'
    'spine', 'rightKnee'
    'neck', 'leftElbow'
    'leftElbow', 'leftWrist'
    'neck', 'rightElbow'
    'rightElbow', 'rightWrist'
    'leftKnee', 'leftAnkle'
    'rightKnee', 'rightAnkle'
    };

pose.joints = joints;
pose.segments = segments;
end

function limb = limbPose(origin, phase, isLeg)
if isLeg
    upperLength = 0.92;
    lowerLength = 0.88;
    baseAngle = -pi/2;
    swingAmplitude = 0.78;
    flexAmplitude = 0.78;

    thighAngle = baseAngle + swingAmplitude * sin(phase);
    kneeFlex = 0.16 + flexAmplitude * max(0, sin(phase + 0.25*pi));
    shinAngle = thighAngle - kneeFlex;

    limb.middle = origin + upperLength * [cos(thighAngle), sin(thighAngle)];
    limb.endPoint = limb.middle + lowerLength * ...
        [cos(shinAngle), sin(shinAngle)];
else
    upperLength = 0.64;
    lowerLength = 0.62;
    baseAngle = -pi/2;
    swingAmplitude = 0.62;
    flexAmplitude = 0.34;

    upperAngle = baseAngle + swingAmplitude * sin(phase);
    elbowFlex = 0.24 + flexAmplitude * ...
        (0.5 + 0.5*sin(phase - 0.35*pi));
    forearmAngle = upperAngle + elbowFlex;

    limb.middle = origin + upperLength * [cos(upperAngle), sin(upperAngle)];
    limb.endPoint = limb.middle + lowerLength * ...
        [cos(forearmAngle), sin(forearmAngle)];
end
end

%% Local functions: rotating dotted cylinder 2D projection
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

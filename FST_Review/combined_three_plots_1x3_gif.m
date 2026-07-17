% combined_three_plots_1x3_gif.m
%
% Draws the rotating wire frame and point-light walker together in one
% 1x2 layout, then saves one GIF. The cylinder is generated separately by
% rotating_cylinder_separate_gif.m.

clear;
clc;

%% User settings
nFrames = 240;
gifDelayTime = 0.035;
gifFile = fullfile(pwd, 'combined_wire_frame_walker_1x2.gif');

frameRotationCycles = 1.0;
walkerStepCycles = 4.0; % twice the previous walker speed

%% Shared figure
fig = figure('Color', 'w', ...
    'Name', 'Combined Wire Frame and Walker GIF', ...
    'NumberTitle', 'off', ...
    'Position', [80, 120, 1280, 620]);

axFrame = axes('Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0.03, 0.08, 0.45, 0.86], ...
    'LooseInset', [0, 0, 0, 0]);

axWalker = axes('Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0.52, 0.08, 0.45, 0.86], ...
    'LooseInset', [0, 0, 0, 0]);

%% Plot 1: rotating frame
hold(axFrame, 'on');
axis(axFrame, 'equal');
axis(axFrame, [-2.75, 2.75, -2.75, 2.75, -2.45, 2.95]);
axis(axFrame, 'off');
view(axFrame, 38, 22);
camproj(axFrame, 'perspective');
camzoom(axFrame, 1.35);

frameTransform = hgtransform('Parent', axFrame);
drawBentFrame(frameTransform);

%% Plot 2: point-light walker
hold(axWalker, 'on');
axis(axWalker, 'equal');
axis(axWalker, [-1.9, 1.9, 0.0, 4.8]);
axis(axWalker, 'off');

bodyHorizontalMotion = 0.06;
bodyVerticalMotion = 0.02;
bodyLeanMotion = 0.045;
jointVerticalSeparation = 0.025;
shoulderHorizontalSeparation = 0.20;
hipHorizontalSeparation = 0.18;
dotSizeWalker = 115;
dotColor = [0, 0, 0];
showRedDashedLines = false;

pose = getWalkerPose(0, bodyHorizontalMotion, bodyVerticalMotion, ...
    bodyLeanMotion, jointVerticalSeparation, ...
    shoulderHorizontalSeparation, hipHorizontalSeparation);
jointNames = fieldnames(pose.joints);
[dotX, dotY] = getWalkerJointXY(pose, jointNames);
lineHandles = gobjects(0);
dotHandle = scatter(axWalker, dotX, dotY, dotSizeWalker, dotColor, ...
    'filled', 'MarkerEdgeColor', dotColor, 'LineWidth', 0.8);

%% Animate both plots and write one GIF
if exist(gifFile, 'file')
    delete(gifFile);
end

for iFrame = 1:nFrames
    normalizedTime = (iFrame - 1) / nFrames;

    frameAngle = 2*pi*frameRotationCycles * normalizedTime;
    frameTransform.Matrix = makehgtform('zrotate', frameAngle);

    walkerPhase = 2*pi*walkerStepCycles * normalizedTime;
    pose = getWalkerPose(walkerPhase, bodyHorizontalMotion, ...
        bodyVerticalMotion, bodyLeanMotion, jointVerticalSeparation, ...
        shoulderHorizontalSeparation, hipHorizontalSeparation);
    updateWalkerPlot(pose, jointNames, dotHandle, lineHandles, ...
        showRedDashedLines);

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
    bodyVerticalMotion, bodyLeanMotion, jointVerticalSeparation, ...
    shoulderHorizontalSeparation, hipHorizontalSeparation)
phase = mod(phase, 2*pi);

bodyX = bodyHorizontalMotion * sin(phase - 0.2*pi);
bodyY = bodyVerticalMotion * sin(2*phase + 0.35*pi);
bodyLean = bodyLeanMotion * sin(phase + 0.15*pi);

spine = [bodyX + 0.35*bodyLean, 2.65 + bodyY];
neck = [bodyX + bodyLean, 3.55 + bodyY];
head = [bodyX + 1.15*bodyLean, 4.02 + bodyY];
shoulderCenter = [bodyX + 0.85*bodyLean, 3.35 + bodyY];
hipCenter = [bodyX + 0.25*bodyLean, 2.55 + bodyY];

leftShoulder = shoulderCenter + ...
    [-shoulderHorizontalSeparation, jointVerticalSeparation];
rightShoulder = shoulderCenter + ...
    [shoulderHorizontalSeparation, -jointVerticalSeparation];
leftHip = hipCenter + [-hipHorizontalSeparation, jointVerticalSeparation];
rightHip = hipCenter + [hipHorizontalSeparation, -jointVerticalSeparation];

leftLeg = limbPose(leftHip, phase, true);
rightLeg = limbPose(rightHip, phase + pi, true);
leftArm = limbPose(leftShoulder, phase + pi, false);
rightArm = limbPose(rightShoulder, phase, false);

joints = struct();
joints.head = head;
joints.neck = neck;
joints.spine = spine;
joints.leftShoulder = leftShoulder;
joints.rightShoulder = rightShoulder;
joints.leftHip = leftHip;
joints.rightHip = rightHip;
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
    'neck', 'leftShoulder'
    'neck', 'rightShoulder'
    'leftShoulder', 'leftElbow'
    'leftElbow', 'leftWrist'
    'rightShoulder', 'rightElbow'
    'rightElbow', 'rightWrist'
    'neck', 'spine'
    'spine', 'leftHip'
    'spine', 'rightHip'
    'leftHip', 'leftKnee'
    'leftKnee', 'leftAnkle'
    'rightHip', 'rightKnee'
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
    swingAmplitude = 0.58;
    flexAmplitude = 0.56;

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
    swingAmplitude = 0.46;
    flexAmplitude = 0.25;

    upperAngle = baseAngle + swingAmplitude * sin(phase);
    elbowFlex = 0.24 + flexAmplitude * ...
        (0.5 + 0.5*sin(phase - 0.35*pi));
    forearmAngle = upperAngle + elbowFlex;

    limb.middle = origin + upperLength * [cos(upperAngle), sin(upperAngle)];
    limb.endPoint = limb.middle + lowerLength * ...
        [cos(forearmAngle), sin(forearmAngle)];
end
end

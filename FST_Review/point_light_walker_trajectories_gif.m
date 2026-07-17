% point_light_walker_trajectories_gif.m
%
% Draws the point-light walker by itself, with the trajectory of each dot
% shown in a different color, then saves the animation as a GIF.

clear;
clc;

%% User settings
nFrames = 160;
walkerStepCycles = 2.0;
gifDelayTime = 0.035;
gifFile = fullfile(pwd, 'point_light_walker_colored_trajectories.gif');

bodyHorizontalMotion = 0.06;
bodyVerticalMotion = 0.02;
bodyLeanMotion = 0.045;
jointVerticalSeparation = 0.025;
shoulderHorizontalSeparation = 0.18;
hipHorizontalSeparation = 0.16;

dotSize = 95;
trajectoryLineWidth = 1.8;
nTrajectorySamples = 240;

%% Precompute one full-cycle trajectory for every dot
samplePhases = linspace(0, 2*pi, nTrajectorySamples + 1);
samplePhases(end) = [];

pose0 = getWalkerPose(0, bodyHorizontalMotion, bodyVerticalMotion, ...
    bodyLeanMotion, jointVerticalSeparation, shoulderHorizontalSeparation, ...
    hipHorizontalSeparation);
jointNames = fieldnames(pose0.joints);
nJoints = numel(jointNames);

trajectoryX = zeros(nTrajectorySamples, nJoints);
trajectoryY = zeros(nTrajectorySamples, nJoints);

for iSample = 1:nTrajectorySamples
    pose = getWalkerPose(samplePhases(iSample), bodyHorizontalMotion, ...
        bodyVerticalMotion, bodyLeanMotion, jointVerticalSeparation, ...
        shoulderHorizontalSeparation, hipHorizontalSeparation);
    [trajectoryX(iSample, :), trajectoryY(iSample, :)] = ...
        getWalkerJointXY(pose, jointNames);
end

jointColors = hsv(nJoints);

%% Build figure
fig = figure('Color', 'w', ...
    'Name', 'Point-light Walker Colored Trajectories', ...
    'NumberTitle', 'off', ...
    'Position', [120, 80, 760, 920]);
ax = axes('Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0.04, 0.04, 0.92, 0.92], ...
    'LooseInset', [0, 0, 0, 0]);
hold(ax, 'on');

axis(ax, 'equal');
axis(ax, [-1.9, 1.9, 0.0, 4.8]);
axis(ax, 'off');

for iJoint = 1:nJoints
    plot(ax, trajectoryX(:, iJoint), trajectoryY(:, iJoint), '-', ...
        'Color', jointColors(iJoint, :), ...
        'LineWidth', trajectoryLineWidth);
end

pose = getWalkerPose(0, bodyHorizontalMotion, bodyVerticalMotion, ...
    bodyLeanMotion, jointVerticalSeparation, shoulderHorizontalSeparation, ...
    hipHorizontalSeparation);
[dotX, dotY] = getWalkerJointXY(pose, jointNames);
dotHandle = scatter(ax, dotX, dotY, dotSize, jointColors, 'filled', ...
    'MarkerEdgeColor', 'k', 'LineWidth', 0.7);

%% Animate and save GIF
if exist(gifFile, 'file')
    delete(gifFile);
end

for iFrame = 1:nFrames
    normalizedTime = (iFrame - 1) / nFrames;
    phase = 2*pi*walkerStepCycles * normalizedTime;

    pose = getWalkerPose(phase, bodyHorizontalMotion, ...
        bodyVerticalMotion, bodyLeanMotion, jointVerticalSeparation, ...
        shoulderHorizontalSeparation, hipHorizontalSeparation);
    [dotX, dotY] = getWalkerJointXY(pose, jointNames);
    dotHandle.XData = dotX;
    dotHandle.YData = dotY;

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

fprintf('Saved walker trajectory GIF: %s\n', gifFile);

%% Local functions
function [dotX, dotY] = getWalkerJointXY(pose, jointNames)
nJoints = numel(jointNames);
dotX = zeros(1, nJoints);
dotY = zeros(1, nJoints);

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

pose.joints = joints;
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

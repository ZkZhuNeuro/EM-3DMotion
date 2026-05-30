% point_light_walker_gif.m
%
% Draws an animated point-light walker and saves the loop as a GIF. The
% model is a simple 2D articulated walker with black joint dots and optional
% red dashed guide lines like the reference illustration.

clear;
clc;

%% User settings
nFrames = 96;
stepCycles = 2.0;
gifDelayTime = 0.04;
gifFile = fullfile(pwd, 'point_light_walker.gif');

exportPdfs = true;
nPdfSnapshots = 10;
pdfExportFolder = fullfile(pwd, 'point_light_walker_pdfs');

showRedDashedLines = false;
bodyHorizontalMotion = 0.06;
bodyVerticalMotion = 0.035;
bodyLeanMotion = 0.045;
jointVerticalSeparation = 0.06;
dotSize = 115;
dotColor = [0, 0, 0];
skeletonColor = [1.0, 0.05, 0.04];
skeletonLineWidth = 1.8;

figPosition = [100, 100, 520, 720];

%% Build figure
fig = figure('Color', 'w', ...
    'Name', 'Point-light Walker', ...
    'NumberTitle', 'off', ...
    'Position', figPosition);
ax = axes('Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0, 0, 1, 1], ...
    'LooseInset', [0, 0, 0, 0]);
hold(ax, 'on');

axis(ax, 'equal');
axis(ax, [-1.9, 1.9, 0.0, 4.8]);
axis(ax, 'off');

title(ax, 'Point-light walker', 'FontSize', 22, 'FontWeight', 'bold');

pose = getWalkerPose(0, bodyHorizontalMotion, bodyVerticalMotion, ...
    bodyLeanMotion, jointVerticalSeparation);
jointNames = fieldnames(pose.joints);
nJoints = numel(jointNames);

dotX = zeros(nJoints, 1);
dotY = zeros(nJoints, 1);
for iJoint = 1:nJoints
    xy = pose.joints.(jointNames{iJoint});
    dotX(iJoint) = xy(1);
    dotY(iJoint) = xy(2);
end

if showRedDashedLines
    lineHandles = gobjects(size(pose.segments, 1), 1);
    for iSegment = 1:size(pose.segments, 1)
        p1 = pose.joints.(pose.segments{iSegment, 1});
        p2 = pose.joints.(pose.segments{iSegment, 2});
        lineHandles(iSegment) = plot(ax, [p1(1), p2(1)], [p1(2), p2(2)], ...
            '--', 'Color', skeletonColor, 'LineWidth', skeletonLineWidth);
    end
else
    lineHandles = gobjects(0);
end

dotHandle = scatter(ax, dotX, dotY, dotSize, dotColor, 'filled', ...
    'MarkerEdgeColor', dotColor, 'LineWidth', 0.8);

%% Export evenly spaced PDF snapshots over one full walking cycle
if exportPdfs
    if ~exist(pdfExportFolder, 'dir')
        mkdir(pdfExportFolder);
    end

    snapshotPhases = linspace(0, 2*pi, nPdfSnapshots + 1);
    snapshotPhases(end) = [];

    for iSnapshot = 1:nPdfSnapshots
        pose = getWalkerPose(snapshotPhases(iSnapshot), ...
            bodyHorizontalMotion, bodyVerticalMotion, bodyLeanMotion, ...
            jointVerticalSeparation);
        updateWalkerPlot(pose, jointNames, dotHandle, lineHandles, ...
            showRedDashedLines);
        drawnow;

        pdfFile = fullfile(pdfExportFolder, ...
            sprintf('point_light_walker_frame_%02d.pdf', iSnapshot));
        exportgraphics(ax, pdfFile, 'ContentType', 'vector', ...
            'BackgroundColor', 'white');
        fprintf('Saved PDF: %s\n', pdfFile);
    end
end

%% Animate and save GIF
if exist(gifFile, 'file')
    delete(gifFile);
end

phases = linspace(0, 2*pi*stepCycles, nFrames + 1);
phases(end) = [];

for iFrame = 1:nFrames
    pose = getWalkerPose(phases(iFrame), bodyHorizontalMotion, ...
        bodyVerticalMotion, bodyLeanMotion, jointVerticalSeparation);
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

fprintf('Saved GIF: %s\n', gifFile);

%% Local functions
function updateWalkerPlot(pose, jointNames, dotHandle, lineHandles, ...
    showRedDashedLines)
% Update scatter and skeleton line handles for a new pose.

nJoints = numel(jointNames);
dotX = zeros(nJoints, 1);
dotY = zeros(nJoints, 1);

for iJoint = 1:nJoints
    xy = pose.joints.(jointNames{iJoint});
    dotX(iJoint) = xy(1);
    dotY(iJoint) = xy(2);
end

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

function pose = getWalkerPose(phase, bodyHorizontalMotion, ...
    bodyVerticalMotion, bodyLeanMotion, jointVerticalSeparation)
% Return a side-view walking pose for the requested gait phase.

phase = mod(phase, 2*pi);

bodyX = bodyHorizontalMotion * sin(phase - 0.2*pi);
bodyY = bodyVerticalMotion * sin(2*phase + 0.35*pi);
bodyLean = bodyLeanMotion * sin(phase + 0.15*pi);

spine = [bodyX + 0.35*bodyLean, 2.65 + bodyY];
neck = [bodyX + bodyLean, 3.55 + bodyY];
head = [bodyX + 1.15*bodyLean, 4.02 + bodyY];

leftLeg = limbPose(spine, phase, true);
rightLeg = limbPose(spine, phase + pi, true);

% Arms swing opposite the legs.
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
% Build a two-segment limb using a compact procedural gait cycle.

if isLeg
    upperLength = 0.92;
    lowerLength = 0.88;
    baseAngle = -pi/2;
    swingAmplitude = 0.78;
    flexAmplitude = 0.78;

    thighAngle = baseAngle + swingAmplitude * sin(phase);
    kneeFlex = 0.16 + flexAmplitude * max(0, sin(phase + 0.25*pi));
    shinAngle = thighAngle - kneeFlex;
else
    upperLength = 0.64;
    lowerLength = 0.62;
    baseAngle = -pi/2;
    swingAmplitude = 0.62;
    flexAmplitude = 0.34;

    upperAngle = baseAngle + swingAmplitude * sin(phase);
    elbowFlex = 0.24 + flexAmplitude * (0.5 + 0.5*sin(phase - 0.35*pi));
    forearmAngle = upperAngle + elbowFlex;

    limb.middle = origin + upperLength * [cos(upperAngle), sin(upperAngle)];
    limb.endPoint = limb.middle + lowerLength * ...
        [cos(forearmAngle), sin(forearmAngle)];
    return;
end

limb.middle = origin + upperLength * [cos(thighAngle), sin(thighAngle)];
limb.endPoint = limb.middle + lowerLength * [cos(shinAngle), sin(shinAngle)];
end

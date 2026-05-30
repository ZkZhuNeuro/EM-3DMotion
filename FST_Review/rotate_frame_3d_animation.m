% rotate_frame_3d_animation.m
%
% Draws a bent wire-frame object inspired by Frame.png and rotates it in 3D
% about a vertical red dashed axis. The frame geometry is built from line
% segments so it is easy to adjust the shape, camera, speed, or export.

clear;
clc;

%% User settings
nFrames = 240;
rotationCycles = 1.0;
pauseTime = 0.01;

saveVideo = false;
videoFile = fullfile(pwd, 'rotating_frame_3d.mp4');

saveGif = true;
gifFile = fullfile(pwd, 'rotating_frame_3d.gif');
gifFrameStep = 4;
gifDelayTime = 0.05;

exportQuarterTurnPngs = true;
pngExportFolder = fullfile(pwd, 'rotating_frame_90deg_pngs');
quarterTurnAnglesDeg = 0:30:330;
cameraZoom = 1.35;
pngPaddingPixels = 85;

exportPdfs = true;
pdfExportFolder = fullfile(pwd, 'rotating_frame_pdfs');
pdfExportAnglesDeg = 0:30:330;

%% Build figure
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

% Fixed red rotation axis and direction cue.
plot3(ax, [0, 0], [0, 0], [-2.0, 2.8], ...
    '--', 'Color', [1.0, 0.05, 0.08], 'LineWidth', 2.2);
drawRotationArrow(ax, 2.35, -1.95, [1.0, 0.05, 0.08]);

% Draw frame lines under one transform. Updating only this transform is
% smoother and keeps the object geometry separate from the world axes.
frameTransform = hgtransform('Parent', ax);
drawBentFrame(frameTransform);

lighting(ax, 'gouraud');
material(ax, 'dull');
camzoom(ax, cameraZoom);

if saveVideo
    videoObj = VideoWriter(videoFile, 'MPEG-4');
    videoObj.FrameRate = 30;
    open(videoObj);
end

%% Export 90-degree screen-view PNGs
if exportQuarterTurnPngs
    if ~exist(pngExportFolder, 'dir')
        mkdir(pngExportFolder);
    end

    for angleDeg = quarterTurnAnglesDeg
        frameTransform.Matrix = makehgtform('zrotate', deg2rad(angleDeg));
        drawnow;

        frame = getframe(ax);
        imageData = cropWhiteMargins(frame.cdata, pngPaddingPixels);
        pngFile = fullfile(pngExportFolder, ...
            sprintf('rotating_frame_%03ddeg.png', angleDeg));
        imwrite(imageData, pngFile);
        fprintf('Saved PNG: %s\n', pngFile);
    end
end

%% Export PDF views
if exportPdfs
    if ~exist(pdfExportFolder, 'dir')
        mkdir(pdfExportFolder);
    end

    for angleDeg = pdfExportAnglesDeg
        frameTransform.Matrix = makehgtform('zrotate', deg2rad(angleDeg));
        drawnow;

        pdfFile = fullfile(pdfExportFolder, ...
            sprintf('rotating_frame_%03ddeg.pdf', angleDeg));
        exportgraphics(ax, pdfFile, 'ContentType', 'vector', ...
            'BackgroundColor', 'white');
        fprintf('Saved PDF: %s\n', pdfFile);
    end
end

%% Animate
angles = linspace(0, 2*pi*rotationCycles, nFrames + 1);
angles(end) = [];

for iFrame = 1:nFrames
    angle = angles(iFrame);
    frameTransform.Matrix = makehgtform('zrotate', angle);
    drawnow;

    if saveVideo
        writeVideo(videoObj, getframe(fig));
    end

    if saveGif && mod(iFrame - 1, gifFrameStep) == 0
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

    pause(pauseTime);
end

if saveVideo
    close(videoObj);
    fprintf('Saved video: %s\n', videoFile);
end

if saveGif
    fprintf('Saved GIF: %s\n', gifFile);
end

%% Local functions
function drawBentFrame(parentTransform)
% Draw the black wire frame as connected line segments in body coordinates.

lineColor = [0.02, 0.02, 0.02];
lineWidth = 4.0;

% Central bent spine.
A = [-1,  1,  1.50];
B = [ 0.8, -0.8,  0.55];
C = [-0.5,  0.9, -0.22];
D = [ 0.3, -0.5, -1];

segments = {

    B, C
    C, D
    };

% Upper-right rectangular panel.
R1 = B;
R2 = [ 1.75, -0.38,  1.45];
R3 = [ 2.05, -0.62,  -0.5];
R4 = [ 0.30, -0.28, -0.88];

segments = [segments; {
    R1, R2
    R2, R3
    R3, D
    }];

% Lower-left rectangular panel, intentionally open at one edge like the
% sketch. Changing these four points reshapes the panel.
L1 = C;
L2 = [-2.05,  0.45,  0.18];
L3 = [-1.70,  0.68, -1.34];
L4 = [-0.42,  0.18, -0.62];

% segments = [segments; {
%     L1, L2
%     L2, L3
%     }];

for iSeg = 1:size(segments, 1)
    p1 = segments{iSeg, 1};
    p2 = segments{iSeg, 2};
    plot3(parentTransform, [p1(1), p2(1)], [p1(2), p2(2)], ...
        [p1(3), p2(3)], '-', 'Color', lineColor, ...
        'LineWidth', lineWidth);
end
end

function drawRotationArrow(ax, radius, zLevel, arrowColor)
% Draw a red circle with two arrowheads to show rotation direction.

theta = linspace(0, 2*pi, 400);
x = radius * cos(theta);
y = radius * sin(theta);
z = zLevel * ones(size(theta));
plot3(ax, x, y, z, '-', 'Color', arrowColor, 'LineWidth', 2.0);

drawTangentArrowhead(ax, radius, zLevel, deg2rad(72), arrowColor);
drawTangentArrowhead(ax, radius, zLevel, deg2rad(252), arrowColor);
end

function drawTangentArrowhead(ax, radius, zLevel, theta, arrowColor)
% Small two-line arrowhead tangent to the circular path.

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

function croppedImage = cropWhiteMargins(imageData, paddingPixels)
% Remove empty white border from an RGB screenshot and add a small padding.

threshold = 245;
contentMask = any(imageData < threshold, 3);

if ~any(contentMask(:))
    croppedImage = imageData;
    return;
end

[rowIdx, colIdx] = find(contentMask);
rowRange = min(rowIdx):max(rowIdx);
colRange = min(colIdx):max(colIdx);
trimmedImage = imageData(rowRange, colRange, :);

croppedSize = size(trimmedImage);
croppedImage = uint8(255 * ones(croppedSize(1) + 2*paddingPixels, ...
    croppedSize(2) + 2*paddingPixels, 3));
croppedImage((paddingPixels + 1):(paddingPixels + croppedSize(1)), ...
    (paddingPixels + 1):(paddingPixels + croppedSize(2)), :) = trimmedImage;
end

% rotate_dotted_cylinder_3d_animation.m
%
% Draws a rotating 3D cylinder covered with random dots. Dots on the front
% half of the cylinder are black, and dots on the back half are grey.

clear;
clc;

%% User settings
nFrames = 240;
rotationCycles = 1.0;
pauseTime = 0.01;

cylinderRadius = 1.4;
cylinderHeight = 3.0;
nDots = 300;
dotSize = 200;

saveVideo = false;
videoFile = fullfile(pwd, 'rotating_dotted_cylinder.mp4');

saveGif = false;
gifFile = fullfile(pwd, 'rotating_dotted_cylinder.gif');

save2DProjectionGif = true;
projectionGifFile = fullfile(pwd, 'rotating_dotted_cylinder_2d_projection_black.gif');
projectionGifFrameStep = 1;
projectionGifDelayTime = 0.03;
projectionGifPaddingPixels = 80;

exportPdfs = false;
pdfExportFolder = fullfile(pwd, 'rotating_dotted_cylinder_pdfs');
exportAnglesDeg = 0:30:330;
cameraZoom = 1.25;
separationCheckAnglesDeg = 0:15:345;
minProjectedDotSpacing = 0.14;
maxPlacementAttempts = 250000;

export2DProjectionPdfs = false;
pdf2DProjectionFolder = fullfile(pwd, 'rotating_dotted_cylinder_2d_projection_pdfs');

%% Build figure
fig = figure('Color', 'w', ...
    'Name', 'Rotating Dotted Cylinder', ...
    'NumberTitle', 'off', ...
    'Position', [100, 100, 900, 900]);
ax = axes('Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0, 0, 1, 1], ...
    'LooseInset', [0, 0, 0, 0]);
hold(ax, 'on');

axis(ax, 'equal');
axis(ax, [-2.2, 2.2, -2.2, 2.2, -2.1, 2.1]);
axis(ax, 'off');
view(ax, 38, 22);
camproj(ax, 'perspective');
camzoom(ax, cameraZoom);

%% Random non-overlapping dot positions on the cylinder surface
rng(1); % Change this seed for a different random dot pattern.
[theta0, z0] = generateSeparatedCylinderDots(nDots, cylinderRadius, ...
    cylinderHeight, separationCheckAnglesDeg, minProjectedDotSpacing, ...
    maxPlacementAttempts, ax);

x0 = cylinderRadius * cos(theta0);
y0 = cylinderRadius * sin(theta0);

% Local outward normal for each dot on the cylinder side wall.
nx0 = cos(theta0);
ny0 = sin(theta0);

% Light guide rings make the cylinder readable while keeping the dots as the
% main visual element.
drawCylinderGuides(ax, cylinderRadius, cylinderHeight);

frontDots = scatter3(ax, nan, nan, nan, dotSize, 'k', 'filled');
backDots = scatter3(ax, nan, nan, nan, dotSize, ...
    [0.62, 0.62, 0.62], 'filled');

if saveVideo
    videoObj = VideoWriter(videoFile, 'MPEG-4');
    videoObj.FrameRate = 30;
    open(videoObj);
end

anglesDeg = linspace(0, 360*rotationCycles, nFrames + 1);
anglesDeg(end) = [];

%% Export dot-only 2D screen projections
if export2DProjectionPdfs
    if ~exist(pdf2DProjectionFolder, 'dir')
        mkdir(pdf2DProjectionFolder);
    end

    fig2D = figure('Color', 'w', ...
        'Name', '2D Dotted Cylinder Projection', ...
        'NumberTitle', 'off', ...
        'Position', [1050, 100, 900, 900]);
    ax2D = axes('Parent', fig2D, ...
        'Units', 'normalized', ...
        'Position', [0, 0, 1, 1], ...
        'LooseInset', [0, 0, 0, 0]);

    projectionLimit = 1.12 * max(cylinderRadius, 0.5*cylinderHeight);

    for angleDeg = exportAnglesDeg
        [screenX, screenZ, isFront] = get2DProjection(angleDeg, ...
            x0, y0, z0, nx0, ny0, ax);

        cla(ax2D);
        hold(ax2D, 'on');
        scatter(ax2D, screenX(~isFront), screenZ(~isFront), dotSize, ...
            [0.62, 0.62, 0.62], 'filled');
        scatter(ax2D, screenX(isFront), screenZ(isFront), dotSize, ...
            'k', 'filled');
        hold(ax2D, 'off');
        axis(ax2D, 'equal');
        axis(ax2D, [-projectionLimit, projectionLimit, ...
            -projectionLimit, projectionLimit]);
        axis(ax2D, 'off');
        drawnow;

        pdfFile = fullfile(pdf2DProjectionFolder, ...
            sprintf('dotted_cylinder_2d_projection_%03ddeg.pdf', angleDeg));
        exportgraphics(ax2D, pdfFile, 'ContentType', 'vector', ...
            'BackgroundColor', 'white');
        fprintf('Saved 2D projection PDF: %s\n', pdfFile);
    end

    close(fig2D);
end

%% Export black-dot 2D projection GIF
if save2DProjectionGif
    fig2DGif = figure('Color', 'w', ...
        'Name', '2D Black Dot Projection GIF', ...
        'NumberTitle', 'off', ...
        'Position', [1050, 100, 900, 900]);
    ax2DGif = axes('Parent', fig2DGif, ...
        'Units', 'normalized', ...
        'Position', [0, 0, 1, 1], ...
        'LooseInset', [0, 0, 0, 0]);

    projectionLimit = 1.12 * max(cylinderRadius, 0.5*cylinderHeight);
    isFirstGifFrame = true;

    for iFrame = 1:projectionGifFrameStep:numel(anglesDeg)
        angleDeg = anglesDeg(iFrame);
        [screenX, screenZ] = get2DProjection(angleDeg, ...
            x0, y0, z0, nx0, ny0, ax);

        cla(ax2DGif);
        scatter(ax2DGif, screenX, screenZ, dotSize, 'k', 'filled');
        axis(ax2DGif, 'equal');
        axis(ax2DGif, [-projectionLimit, projectionLimit, ...
            -projectionLimit, projectionLimit]);
        axis(ax2DGif, 'off');
        drawnow;

        frame = getframe(ax2DGif);
        imageData = cropWhiteMarginsToSquare(frame.cdata, ...
            projectionGifPaddingPixels);
        [im, cmap] = rgb2ind(imageData, 256);

        if isFirstGifFrame
            imwrite(im, cmap, projectionGifFile, 'gif', ...
                'LoopCount', inf, 'DelayTime', projectionGifDelayTime);
            isFirstGifFrame = false;
        else
            imwrite(im, cmap, projectionGifFile, 'gif', ...
                'WriteMode', 'append', 'DelayTime', projectionGifDelayTime);
        end
    end

    close(fig2DGif);
    fprintf('Saved 2D projection GIF: %s\n', projectionGifFile);
end

%% Export PDFs
if exportPdfs
    if ~exist(pdfExportFolder, 'dir')
        mkdir(pdfExportFolder);
    end

    for angleDeg = exportAnglesDeg
        updateCylinderDots(angleDeg, x0, y0, z0, nx0, ny0, ...
            frontDots, backDots, ax);
        drawnow;

        pdfFile = fullfile(pdfExportFolder, ...
            sprintf('dotted_cylinder_%03ddeg.pdf', angleDeg));
        exportgraphics(ax, pdfFile, 'ContentType', 'vector', ...
            'BackgroundColor', 'white');
        fprintf('Saved PDF: %s\n', pdfFile);
    end
end

%% Animate
for iFrame = 1:nFrames
    updateCylinderDots(anglesDeg(iFrame), x0, y0, z0, nx0, ny0, ...
        frontDots, backDots, ax);
    drawnow;

    if saveVideo
        writeVideo(videoObj, getframe(fig));
    end

    if saveGif
        frame = getframe(fig);
        [im, cmap] = rgb2ind(frame2im(frame), 256);
        if iFrame == 1
            imwrite(im, cmap, gifFile, 'gif', 'LoopCount', inf, ...
                'DelayTime', pauseTime);
        else
            imwrite(im, cmap, gifFile, 'gif', 'WriteMode', 'append', ...
                'DelayTime', pauseTime);
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
function updateCylinderDots(angleDeg, x0, y0, z0, nx0, ny0, ...
    frontDots, backDots, ax)
% Rotate dots and recolor them based on whether their surface normal faces
% the camera.

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

cameraPosition = ax.CameraPosition(:)';
cameraTarget = ax.CameraTarget(:)';
cameraDirection = cameraPosition - cameraTarget;
cameraDirection(3) = 0;
cameraDirection = cameraDirection ./ norm(cameraDirection);

isFront = nx .* cameraDirection(1) + ny .* cameraDirection(2) > 0;

set(frontDots, 'XData', x(isFront), 'YData', y(isFront), ...
    'ZData', z(isFront));
set(backDots, 'XData', x(~isFront), 'YData', y(~isFront), ...
    'ZData', z(~isFront));
end

function drawCylinderGuides(ax, radius, height)
% Draw faint cylinder rims so the dotted surface reads as cylindrical.

theta = linspace(0, 2*pi, 300);
x = radius * cos(theta);
y = radius * sin(theta);
guideColor = [0.78, 0.78, 0.78];

plot3(ax, x, y, 0.5*height*ones(size(theta)), '-', ...
    'Color', guideColor, 'LineWidth', 1.0);
plot3(ax, x, y, -0.5*height*ones(size(theta)), '-', ...
    'Color', guideColor, 'LineWidth', 1.0);

end

function [theta0, z0] = generateSeparatedCylinderDots(nDots, radius, ...
    height, checkAnglesDeg, minProjectedSpacing, maxAttempts, ax)
% Place random cylinder-surface dots while avoiding projected overlap.

theta0 = zeros(nDots, 1);
z0 = zeros(nDots, 1);
nPlaced = 0;
nAttempts = 0;

while nPlaced < nDots && nAttempts < maxAttempts
    nAttempts = nAttempts + 1;

    thetaCandidate = 2*pi*rand;
    zCandidate = height * (rand - 0.5);

    if nPlaced == 0 || isSeparatedFromExisting(thetaCandidate, zCandidate, ...
            theta0(1:nPlaced), z0(1:nPlaced), radius, checkAnglesDeg, ...
            minProjectedSpacing, ax)
        nPlaced = nPlaced + 1;
        theta0(nPlaced) = thetaCandidate;
        z0(nPlaced) = zCandidate;
    end
end

if nPlaced < nDots
    warning(['Placed %d of %d requested dots. Reduce nDots, reduce ', ...
        'minProjectedDotSpacing, or increase maxPlacementAttempts.'], ...
        nPlaced, nDots);
    theta0 = theta0(1:nPlaced);
    z0 = z0(1:nPlaced);
else
    fprintf('Placed %d separated dots after %d attempts.\n', ...
        nPlaced, nAttempts);
end
end

function isSeparated = isSeparatedFromExisting(thetaCandidate, zCandidate, ...
    existingTheta, existingZ, radius, checkAnglesDeg, minProjectedSpacing, ax)
% Check candidate spacing in the 2D screen projection over many rotations.

candidateX0 = radius * cos(thetaCandidate);
candidateY0 = radius * sin(thetaCandidate);
existingX0 = radius * cos(existingTheta);
existingY0 = radius * sin(existingTheta);

isSeparated = true;

for angleDeg = checkAnglesDeg
    [candidateScreenX, candidateScreenZ] = get2DProjection(angleDeg, ...
        candidateX0, candidateY0, zCandidate, cos(thetaCandidate), ...
        sin(thetaCandidate), ax);
    [existingScreenX, existingScreenZ] = get2DProjection(angleDeg, ...
        existingX0, existingY0, existingZ, cos(existingTheta), ...
        sin(existingTheta), ax);

    distanceToExisting = hypot(existingScreenX - candidateScreenX, ...
        existingScreenZ - candidateScreenZ);

    if any(distanceToExisting < minProjectedSpacing)
        isSeparated = false;
        return;
    end
end
end

function [screenX, screenZ, isFront] = get2DProjection(angleDeg, ...
    x0, y0, z0, nx0, ny0, ax)
% Return an orthographic screen-plane projection of the rotating cylinder.

[x, y, z, nx, ny] = rotateCylinderPoints(angleDeg, x0, y0, z0, nx0, ny0);
[cameraDirection, screenRight] = getHorizontalCameraVectors(ax);

screenX = x .* screenRight(1) + y .* screenRight(2);
screenZ = z;
isFront = nx .* cameraDirection(1) + ny .* cameraDirection(2) > 0;
end

function [x, y, z, nx, ny] = rotateCylinderPoints(angleDeg, ...
    x0, y0, z0, nx0, ny0)
% Rotate cylinder surface points and their outward normals about z.

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

function [cameraDirection, screenRight] = getHorizontalCameraVectors(ax)
% Get camera-facing and screen-horizontal directions in the x-y plane.

cameraPosition = ax.CameraPosition(:)';
cameraTarget = ax.CameraTarget(:)';
cameraDirection = cameraPosition - cameraTarget;
cameraDirection(3) = 0;
cameraDirection = cameraDirection ./ norm(cameraDirection);

screenRight = [cameraDirection(2), -cameraDirection(1)];
screenRight = screenRight ./ norm(screenRight);
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

function croppedImage = cropWhiteMarginsToSquare(imageData, paddingPixels)
% Remove white border, then center the result on a square white canvas.

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

trimmedSize = size(trimmedImage);
canvasSide = max(trimmedSize(1), trimmedSize(2)) + 2*paddingPixels;
croppedImage = uint8(255 * ones(canvasSide, canvasSide, 3));

rowStart = floor((canvasSide - trimmedSize(1)) / 2) + 1;
colStart = floor((canvasSide - trimmedSize(2)) / 2) + 1;
croppedImage(rowStart:(rowStart + trimmedSize(1) - 1), ...
    colStart:(colStart + trimmedSize(2) - 1), :) = trimmedImage;
end

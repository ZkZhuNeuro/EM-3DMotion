% motion_defined_square_dots.m
%
% Random-dot stimulus with a moving square defined only by local dot motion.
% Dot density is uniform over the whole aperture; no square patch or outline is
% drawn. The visible square region and the surrounding field are sampled at the
% same density on every frame. Square dots live in square-relative coordinates,
% so they move with the square without accumulating at the leading edge. Dots
% outside move in random directions.

clear;
clc;
rng(7);

%% User settings
nFrames = 240;
gifDelayTime = 0.025;
saveGif = true;
gifFile = fullfile(pwd, 'motion_defined_square_dots.gif');

fieldWidth = 900;
fieldHeight = 540;
nDots = 2200;
dotSize = 16;
backgroundColor = [1, 1, 1];

squareSide = 180;
squareCenterY = fieldHeight/2;
squareStartX = -squareSide/2;
squareEndX = fieldWidth + squareSide/2;
squareCenterXByFrame = linspace(squareStartX, squareEndX, nFrames);
squareVelocity = [(squareEndX - squareStartX)/(nFrames - 1), 0];

backgroundSpeed = norm(squareVelocity);
minLifetimeFrames = 20;
maxLifetimeFrames = 20;
dotDensity = nDots / (fieldWidth * fieldHeight);

% Keep false for the actual stimulus. Set true only when checking alignment.
showDebugSquareOutline = false;
debugVisibleOptions = {'off', 'on'};
debugVisible = debugVisibleOptions{1 + double(showDebugSquareOutline)};

%% Initialize controlled-density dot populations
squareLocalX = zeros(0, 1);
squareLocalY = zeros(0, 1);
squareAge = zeros(0, 1);
squareLife = zeros(0, 1);
squareColor = zeros(0, 3);

backgroundX = zeros(0, 1);
backgroundY = zeros(0, 1);
backgroundAge = zeros(0, 1);
backgroundLife = zeros(0, 1);
backgroundColorData = zeros(0, 3);
backgroundVx = zeros(0, 1);
backgroundVy = zeros(0, 1);

%% Build figure
fig = figure('Color', backgroundColor, ...
    'Name', 'Motion-defined square random dots', ...
    'NumberTitle', 'off', ...
    'Position', [120, 120, fieldWidth, fieldHeight]);
ax = axes('Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0, 0, 1, 1], ...
    'LooseInset', [0, 0, 0, 0], ...
    'Color', backgroundColor);

axis(ax, 'equal');
axis(ax, [0, fieldWidth, 0, fieldHeight]);
axis(ax, 'off');
hold(ax, 'on');

dotHandle = scatter(ax, nan, nan, dotSize, [0, 0, 0], ...
    'filled', 'MarkerEdgeColor', 'none');

debugHandle = rectangle(ax, ...
    'Position', [0, 0, squareSide, squareSide], ...
    'EdgeColor', [1, 0, 0], ...
    'LineStyle', '--', ...
    'LineWidth', 1.5, ...
    'Visible', debugVisible);

if saveGif && exist(gifFile, 'file')
    delete(gifFile);
end

%% Animate
for iFrame = 1:nFrames
    squareCenterX = squareCenterXByFrame(iFrame);
    squareLeft = squareCenterX - squareSide/2;
    squareBottom = squareCenterY - squareSide/2;

    [visibleSquareRect, visibleSquareLocalRect, visibleSquareArea] = ...
        getVisibleSquareRects(squareLeft, squareBottom, squareSide, ...
        fieldWidth, fieldHeight);
    nSquareDots = round(dotDensity * visibleSquareArea);
    nBackgroundDots = nDots - nSquareDots;

    [squareLocalX, squareLocalY, squareAge, squareLife, squareColor] = ...
        prepareSquareDots(squareLocalX, squareLocalY, squareAge, ...
        squareLife, squareColor, nSquareDots, visibleSquareLocalRect, ...
        minLifetimeFrames, maxLifetimeFrames);

    [backgroundX, backgroundY, backgroundAge, backgroundLife, ...
        backgroundColorData, backgroundVx, backgroundVy] = ...
        prepareBackgroundDots(backgroundX, backgroundY, backgroundAge, ...
        backgroundLife, backgroundColorData, backgroundVx, backgroundVy, ...
        nBackgroundDots, visibleSquareRect, fieldWidth, fieldHeight, ...
        minLifetimeFrames, maxLifetimeFrames, backgroundSpeed);

    squareX = squareLeft + squareLocalX;
    squareY = squareBottom + squareLocalY;
    dotX = [backgroundX; squareX];
    dotY = [backgroundY; squareY];
    dotColor = [backgroundColorData; squareColor];

    dotHandle.XData = dotX;
    dotHandle.YData = dotY;
    dotHandle.CData = dotColor;
    debugHandle.Position = [squareLeft, squareBottom, squareSide, squareSide];
    drawnow;

    if saveGif
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

    backgroundX = backgroundX + backgroundVx;
    backgroundY = backgroundY + backgroundVy;
    backgroundAge = backgroundAge + 1;
    squareAge = squareAge + 1;
end

if saveGif
    gifInfo = imfinfo(gifFile);
    fprintf('Saved animated GIF: %s\n', gifFile);
    fprintf('GIF frames: %d\n', numel(gifInfo));
end

function [vx, vy] = sampleBackgroundVelocities(nDots, meanSpeed)
theta = 2*pi*rand(nDots, 1);
speedJitter = 0.75 + 0.5*rand(nDots, 1);
speed = meanSpeed * speedJitter;
vx = speed .* cos(theta);
vy = speed .* sin(theta);
end

function [visibleRect, visibleLocalRect, visibleArea] = ...
    getVisibleSquareRects(squareLeft, squareBottom, squareSide, ...
    fieldWidth, fieldHeight)
left = max(squareLeft, 0);
right = min(squareLeft + squareSide, fieldWidth);
bottom = max(squareBottom, 0);
top = min(squareBottom + squareSide, fieldHeight);

visibleWidth = max(right - left, 0);
visibleHeight = max(top - bottom, 0);
visibleRect = [left, bottom, visibleWidth, visibleHeight];
visibleLocalRect = [left - squareLeft, bottom - squareBottom, ...
    visibleWidth, visibleHeight];
visibleArea = visibleWidth * visibleHeight;
end

function [localX, localY, age, life, colorData] = prepareSquareDots( ...
    localX, localY, age, life, colorData, targetCount, localRect, ...
    minLifetimeFrames, maxLifetimeFrames)
if targetCount == 0 || localRect(3) == 0 || localRect(4) == 0
    localX = zeros(0, 1);
    localY = zeros(0, 1);
    age = zeros(0, 1);
    life = zeros(0, 1);
    colorData = zeros(0, 3);
    return;
end

insideVisibleRect = isInsideRect(localX, localY, localRect);
localX = localX(insideVisibleRect);
localY = localY(insideVisibleRect);
age = age(insideVisibleRect);
life = life(insideVisibleRect);
colorData = colorData(insideVisibleRect, :);

[localX, localY, age, life, colorData] = trimDots(localX, localY, ...
    age, life, colorData, targetCount);

nAdd = targetCount - numel(localX);
if nAdd > 0
    [addX, addY] = samplePositionsInRect(nAdd, localRect);
    [addAge, addLife] = sampleAgesAndLifetimes(nAdd, ...
        minLifetimeFrames, maxLifetimeFrames, true);
    localX = [localX; addX];
    localY = [localY; addY];
    age = [age; addAge];
    life = [life; addLife];
    colorData = [colorData; sampleDotColors(nAdd)];
end

expired = age >= life;
if any(expired)
    nExpired = sum(expired);
    [newLocalX, newLocalY] = samplePositionsInRect(nExpired, localRect);
    localX(expired) = newLocalX;
    localY(expired) = newLocalY;
    age(expired) = 0;
    life(expired) = randi([minLifetimeFrames, maxLifetimeFrames], ...
        nExpired, 1);
    colorData(expired, :) = sampleDotColors(nExpired);
end
end

function [x, y, age, life, colorData, vx, vy] = prepareBackgroundDots( ...
    x, y, age, life, colorData, vx, vy, targetCount, avoidRect, ...
    fieldWidth, fieldHeight, minLifetimeFrames, maxLifetimeFrames, ...
    backgroundSpeed)
if targetCount == 0
    x = zeros(0, 1);
    y = zeros(0, 1);
    age = zeros(0, 1);
    life = zeros(0, 1);
    colorData = zeros(0, 3);
    vx = zeros(0, 1);
    vy = zeros(0, 1);
    return;
end

[x, y, age, life, colorData, vx, vy] = trimDotsWithVelocity( ...
    x, y, age, life, ...
    colorData, vx, vy, targetCount);

nAdd = targetCount - numel(x);
if nAdd > 0
    [addX, addY] = samplePositionsOutsideRect(nAdd, fieldWidth, ...
        fieldHeight, avoidRect);
    [addAge, addLife] = sampleAgesAndLifetimes(nAdd, ...
        minLifetimeFrames, maxLifetimeFrames, true);
    [addVx, addVy] = sampleBackgroundVelocities(nAdd, backgroundSpeed);
    x = [x; addX];
    y = [y; addY];
    age = [age; addAge];
    life = [life; addLife];
    colorData = [colorData; sampleDotColors(nAdd)];
    vx = [vx; addVx];
    vy = [vy; addVy];
end

invalid = age >= life | x < 0 | x > fieldWidth | y < 0 | ...
    y > fieldHeight | isInsideRect(x, y, avoidRect);
if any(invalid)
    nInvalid = sum(invalid);
    [newX, newY] = samplePositionsOutsideRect(nInvalid, fieldWidth, ...
        fieldHeight, avoidRect);
    x(invalid) = newX;
    y(invalid) = newY;
    age(invalid) = 0;
    life(invalid) = randi([minLifetimeFrames, maxLifetimeFrames], ...
        nInvalid, 1);
    colorData(invalid, :) = sampleDotColors(nInvalid);
    [newVx, newVy] = sampleBackgroundVelocities(nInvalid, ...
        backgroundSpeed);
    vx(invalid) = newVx;
    vy(invalid) = newVy;
end
end

function [x, y, age, life, colorData] = trimDots( ...
    x, y, age, life, colorData, targetCount)
nDotsCurrent = numel(x);
if nDotsCurrent <= targetCount
    return;
end

keepIndex = randperm(nDotsCurrent, targetCount);
keepMask = false(nDotsCurrent, 1);
keepMask(keepIndex) = true;
x = x(keepMask);
y = y(keepMask);
age = age(keepMask);
life = life(keepMask);
colorData = colorData(keepMask, :);
end

function [x, y, age, life, colorData, vx, vy] = trimDotsWithVelocity( ...
    x, y, age, life, colorData, vx, vy, targetCount)
nDotsCurrent = numel(x);
if nDotsCurrent <= targetCount
    return;
end

keepIndex = randperm(nDotsCurrent, targetCount);
keepMask = false(nDotsCurrent, 1);
keepMask(keepIndex) = true;
x = x(keepMask);
y = y(keepMask);
age = age(keepMask);
life = life(keepMask);
colorData = colorData(keepMask, :);
vx = vx(keepMask);
vy = vy(keepMask);
end

function [x, y] = samplePositionsInRect(nDots, rect)
x = rect(1) + rect(3)*rand(nDots, 1);
y = rect(2) + rect(4)*rand(nDots, 1);
end

function [x, y] = samplePositionsOutsideRect(nDots, fieldWidth, ...
    fieldHeight, avoidRect)
x = zeros(nDots, 1);
y = zeros(nDots, 1);
nFilled = 0;

while nFilled < nDots
    nNeeded = nDots - nFilled;
    nCandidates = max(20, ceil(1.25*nNeeded));
    candidateX = fieldWidth * rand(nCandidates, 1);
    candidateY = fieldHeight * rand(nCandidates, 1);
    keep = ~isInsideRect(candidateX, candidateY, avoidRect);
    candidateX = candidateX(keep);
    candidateY = candidateY(keep);
    nTake = min(nNeeded, numel(candidateX));
    x(nFilled + (1:nTake)) = candidateX(1:nTake);
    y(nFilled + (1:nTake)) = candidateY(1:nTake);
    nFilled = nFilled + nTake;
end
end

function inside = isInsideRect(x, y, rect)
if rect(3) <= 0 || rect(4) <= 0
    inside = false(size(x));
    return;
end

inside = x >= rect(1) & x <= rect(1) + rect(3) & ...
    y >= rect(2) & y <= rect(2) + rect(4);
end

function [age, life] = sampleAgesAndLifetimes(nDots, minLifetimeFrames, ...
    maxLifetimeFrames, randomizeAge)
life = randi([minLifetimeFrames, maxLifetimeFrames], nDots, 1);
if randomizeAge
    age = floor(rand(nDots, 1) .* life);
else
    age = zeros(nDots, 1);
end
end

function dotColor = sampleDotColors(nDots)
hue = rand(nDots, 1);
saturation = 0.65 + 0.35*rand(nDots, 1);
value = 0.35 + 0.45*rand(nDots, 1);
dotColor = hsv2rgb([hue, saturation, value]);
end

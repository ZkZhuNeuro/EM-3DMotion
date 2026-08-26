function fig = PlotBinocularRetinalMotion3D(motionMode, motionDistance)
%PLOTBINOCULARRETINALMOTION3D Illustrate world motion and binocular retinal motion.
%
%   fig = PlotBinocularRetinalMotion3D()
%   fig = PlotBinocularRetinalMotion3D("away", 2.0)
%
% motionMode is "toward" or "away". motionDistance is expressed in eye
% radii. The eyes are ideal spherical pinhole eyes. Each world point is
% projected through the pupil on the anterior sphere surface; the retinal
% position is the ray's second intersection with the same eye sphere.

if nargin < 1 || isempty(motionMode)
    motionMode = "toward";
end
if nargin < 2 || isempty(motionDistance)
    motionDistance = 2.0;
end

motionMode = validatestring(motionMode, {'toward', 'away'});
validateattributes(motionDistance, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});

%% Geometry and appearance
eyeRadius = 1.12;
interocularDistance = 2.70;
cyclopeanEye = [0, 0, 0];
eyeCenters = [-interocularDistance/2, 0, 0; ...
               interocularDistance/2, 0, 0];

% MATLAB-native orientation: +y points forward into the visual scene and
% +z points upward. Using z-up avoids a camera reset on interactive rotation.
objectCenter = [0.55, 6.75, 0.92];
dotOffsets = [ ...
    -1.40,  0.10,  0.52; ...
    -0.50, -0.12, -0.54; ...
     0.10, -0.08,  1.72; ...
     0.56,  0.12, -0.12; ...
     1.32, -0.14,  1.24; ...
     0.82,  0.03, -1.62] * 0.5;

worldStart = objectCenter + dotOffsets;
travelDirection = objectCenter - cyclopeanEye;
travelDirection = travelDirection / norm(travelDirection);
if strcmp(motionMode, 'toward')
    travelDirection = -travelDirection;
    motionPhrase = 'toward';
else
    motionPhrase = 'away from';
end
worldDisplacement = motionDistance * eyeRadius * travelDirection;
worldEnd = worldStart + worldDisplacement;

worldColor = [0.08, 0.38, 0.86];
leftRetinaColor = [0.71, 0.18, 0.76];
rightRetinaColor = [0.93, 0.38, 0.08];
eyeColor = [0.32, 0.70, 0.93];
rayColor = [0.50, 0.55, 0.61];
showProjectionRays = true;

%% Figure and eyes
fig = figure('Color', 'w', ...
    'Name', 'Binocular retinal projection of 3D object motion', ...
    'Position', [100, 100, 1160, 760]);
ax = axes(fig);
hold(ax, 'on');
axis(ax, 'equal');
axis(ax, 'vis3d');
axis(ax, 'off');

[sx, sy, sz] = sphere(48);
for eyeIndex = 1:2
    center = eyeCenters(eyeIndex, :);
    surf(ax, center(1) + eyeRadius*sx, ...
        center(2) + eyeRadius*sy, ...
        center(3) + eyeRadius*sz, ...
        'FaceColor', eyeColor, ...
        'FaceAlpha', 0.10, ...
        'EdgeColor', eyeColor, ...
        'EdgeAlpha', 0.12, ...
        'LineWidth', 0.45);

    pupil = center + [0, eyeRadius, 0];
    scatter3(ax, pupil(1), pupil(2), pupil(3), 55, 'k', 'filled', ...
        'MarkerEdgeColor', 'w', 'LineWidth', 0.8);

    % A small posterior marker indicates the foveal direction.
    fovea = center - [0, eyeRadius, 0];
    scatter3(ax, fovea(1), fovea(2), fovea(3), 20, eyeColor, 'filled');
end

scatter3(ax, cyclopeanEye(1), cyclopeanEye(2), cyclopeanEye(3), ...
    30, [0.15, 0.15, 0.15], 'filled');

%% World dots and rigid 3D translation vectors
scatter3(ax, worldStart(:,1), worldStart(:,2), worldStart(:,3), ...
    48, worldColor, 'filled', 'MarkerEdgeColor', 'w', 'LineWidth', 0.7);
scatter3(ax, worldEnd(:,1), worldEnd(:,2), worldEnd(:,3), ...
    25, worldColor, 'filled', 'MarkerFaceAlpha', 0.38, ...
    'MarkerEdgeAlpha', 0.38);

worldVectorHandle = quiver3(ax, ...
    worldStart(:,1), worldStart(:,2), worldStart(:,3), ...
    repmat(worldDisplacement(1), size(worldStart,1), 1), ...
    repmat(worldDisplacement(2), size(worldStart,1), 1), ...
    repmat(worldDisplacement(3), size(worldStart,1), 1), ...
    0, 'Color', worldColor, 'LineWidth', 2.0, 'MaxHeadSize', 0.30);

%% Exact pupil-ray projection onto each posterior spherical retina
retinalHandles = gobjects(2,1);
retinaColors = [leftRetinaColor; rightRetinaColor];
for eyeIndex = 1:2
    center = eyeCenters(eyeIndex, :);
    pupil = center + [0, eyeRadius, 0];
    retinaStart = projectThroughPupilToRetina( ...
        worldStart, center, pupil, eyeRadius);
    retinaEnd = projectThroughPupilToRetina( ...
        worldEnd, center, pupil, eyeRadius);

    scatter3(ax, retinaStart(:,1), retinaStart(:,2), retinaStart(:,3), ...
        18, retinaColors(eyeIndex,:), 'filled');

    for dotIndex = 1:size(worldStart,1)
        retinalHandles(eyeIndex) = drawSphericalArrow(ax, center, eyeRadius, ...
            retinaStart(dotIndex,:), retinaEnd(dotIndex,:), ...
            retinaColors(eyeIndex,:), 2.2);
    end

    % Representative rays make the projection construction visible without
    % obscuring the complete set of retinal vectors.
    if showProjectionRays
        representativeDots = [1, 6];
        for dotIndex = representativeDots
            plot3(ax, ...
                [worldStart(dotIndex,1), pupil(1), retinaStart(dotIndex,1)], ...
                [worldStart(dotIndex,2), pupil(2), retinaStart(dotIndex,2)], ...
                [worldStart(dotIndex,3), pupil(3), retinaStart(dotIndex,3)], ...
                '--', 'Color', 0.72*rayColor + 0.28, 'LineWidth', 0.8);
            plot3(ax, ...
                [worldEnd(dotIndex,1), pupil(1), retinaEnd(dotIndex,1)], ...
                [worldEnd(dotIndex,2), pupil(2), retinaEnd(dotIndex,2)], ...
                [worldEnd(dotIndex,3), pupil(3), retinaEnd(dotIndex,3)], ...
                '--', 'Color', 0.82*rayColor + 0.18, 'LineWidth', 0.8);
        end
    end
end

%% Labels and view
text(ax, objectCenter(1), objectCenter(2)+0.15, objectCenter(3)+1.05, ...
    '3D dot object', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
text(ax, eyeCenters(1,1), eyeCenters(1,2), eyeCenters(1,3)+1.42, ...
    'Left eye', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
text(ax, eyeCenters(2,1), eyeCenters(2,2), eyeCenters(2,3)+1.42, ...
    'Right eye', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
text(ax, 0, 0, -0.38, 'Cyclopean eye', ...
    'HorizontalAlignment', 'center', 'Color', [0.30, 0.30, 0.30]);
text(ax, eyeCenters(1,1)-0.15, -0.20, -1.42, 'Left retinal motion', ...
    'HorizontalAlignment', 'center', 'Color', leftRetinaColor, ...
    'FontWeight', 'bold');
text(ax, eyeCenters(2,1)+0.15, -0.20, -1.42, 'Right retinal motion', ...
    'HorizontalAlignment', 'center', 'Color', rightRetinaColor, ...
    'FontWeight', 'bold');

% Fix the complete data box before establishing the interactive view.
xlim(ax, [-3.3, 3.3]);
ylim(ax, [-1.5, 8.0]);
zlim(ax, [-2.0, 2.4]);

rayLegendHandle = plot3(ax, nan, nan, nan, '--', ...
    'Color', rayColor, 'LineWidth', 0.9);
legend(ax, [worldVectorHandle, retinalHandles(1), retinalHandles(2), rayLegendHandle], ...
    {'World motion', 'Left-retinal motion', 'Right-retinal motion', ...
     'Central-projection rays'}, ...
    'Location', 'southoutside', 'Orientation', 'horizontal', ...
    'Box', 'off');

title(ax, sprintf('Rigid object motion %s the cyclopean eye', motionPhrase), ...
    'FontWeight', 'normal');

% rotate3d changes the axes View property. Build the initial camera using the
% same view-based mechanism, rather than campos/camtarget/camup, so the first
% mouse rotation does not discard the initial framing. Orthographic projection
% also keeps the apparent object scale independent of viewing direction.
drawnow;
view(ax, -38, 22);
camproj(ax, 'orthographic');
axis(ax, 'vis3d');
camzoom(ax, 1.12);
ax.CameraViewAngleMode = 'manual';
lighting(ax, 'gouraud');
camlight(ax, 'headlight');
rotate3d(ax, 'on');

hold(ax, 'off');
end


function retinalPoints = projectThroughPupilToRetina( ...
    worldPoints, eyeCenter, pupil, radius)
% Continue each world-point-to-pupil ray to its second sphere intersection.
%
% With a unit ray direction d pointing from a world point into the pupil,
% points inside the eye are X(s) = pupil + s*d. Because the pupil already
% lies on the sphere, solving ||X(s)-eyeCenter||^2 = radius^2 gives roots
% s = 0 (the pupil) and s = -2*(pupil-eyeCenter).d (the retina).

rayDirections = pupil - worldPoints;
rayDirections = rayDirections ./ vecnorm(rayDirections, 2, 2);
pupilRadius = pupil - eyeCenter;
secondIntersectionDistance = -2 * (rayDirections * pupilRadius');

if any(secondIntersectionDistance <= 0)
    error('A world-to-pupil ray does not enter the eye sphere.');
end

retinalPoints = pupil + secondIntersectionDistance .* rayDirections;

% Guard against accidental changes that move the computed points off-sphere.
sphereResidual = abs(vecnorm(retinalPoints-eyeCenter, 2, 2) - radius);
if any(sphereResidual > 1e-10*max(1, radius))
    error('Retinal ray-sphere intersection failed its geometry check.');
end
end


function h = drawSphericalArrow(ax, center, radius, startPoint, endPoint, color, lineWidth)
% Draw a finite retinal displacement along the spherical retinal surface.
u0 = (startPoint - center) / radius;
u1 = (endPoint - center) / radius;
cosAngle = max(-1, min(1, dot(u0, u1)));
angle = acos(cosAngle);

if angle < 1e-8
    h = plot3(ax, startPoint(1), startPoint(2), startPoint(3), '.', ...
        'Color', color, 'MarkerSize', 8);
    return
end

t = linspace(0, 1, 20)';
arcDirections = (sin((1-t)*angle).*u0 + sin(t*angle).*u1) / sin(angle);
arcPoints = center + radius*arcDirections;
h = plot3(ax, arcPoints(:,1), arcPoints(:,2), arcPoints(:,3), ...
    'Color', color, 'LineWidth', lineWidth);

% Add an arrowhead aligned with the final geodesic segment.
headStart = arcPoints(end-3,:);
headVector = arcPoints(end,:) - headStart;
quiver3(ax, headStart(1), headStart(2), headStart(3), ...
    headVector(1), headVector(2), headVector(3), 0, ...
    'Color', color, 'LineWidth', lineWidth, 'MaxHeadSize', 2.2);
end

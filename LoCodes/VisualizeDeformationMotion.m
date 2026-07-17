function VisualizeDeformationMotion()
% VisualizeDeformationMotion
% Interactive comparison of a rotation matrix and the deformation matrix:
%
%   R = [cos(t), -sin(t); sin(t),  cos(t)]
%   D = [cos(t),  sin(t); sin(t), -cos(t)]
%
% For the same random dots, the figure shows:
%   [uR, vR] = [x, y] * R
%   [uD, vD] = [x, y] * D
%
% Drag the slider to change t and see both vector fields update.

close all; clc;

rng(7);
nDots = 150;
speedScale = 0.20;
dotSize = 18;

theta = 2*pi*rand(nDots, 1);
radius = sqrt(rand(nDots, 1));
dots0 = [radius.*cos(theta), radius.*sin(theta)];

[xGrid, yGrid] = meshgrid(linspace(-1, 1, 13));
gridPts = [xGrid(:), yGrid(:)];

colors.rotation = [0.05 0.31 0.78];
colors.deformation = [0.86 0.28 0.12];
colors.expansion = [0.00 0.48 0.18];
colors.compression = [0.66 0.18 0.67];

fig = figure( ...
    'Color', 'w', ...
    'Name', 'Rotation vs deformation matrix', ...
    'NumberTitle', 'off', ...
    'Position', [80 80 1280 760]);

layout = tiledlayout(fig, 2, 3, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

axDots = nexttile(layout, [2 2]);
hold(axDots, 'on');
axis(axDots, 'equal');
axis(axDots, [-1.55 1.55 -1.55 1.55]);
box(axDots, 'on');
grid(axDots, 'on');
xlabel(axDots, 'x');
ylabel(axDots, 'y');

scatter(axDots, dots0(:,1), dots0(:,2), dotSize, ...
    'MarkerFaceColor', [0.18 0.18 0.18], ...
    'MarkerEdgeColor', 'w', ...
    'LineWidth', 0.3, ...
    'HandleVisibility', 'off');

rotationDots = quiver(axDots, dots0(:,1), dots0(:,2), ...
    zeros(nDots,1), zeros(nDots,1), ...
    0, 'Color', colors.rotation, 'LineWidth', 0.85, ...
    'MaxHeadSize', 0.35, 'DisplayName', 'rotation: [x,y]R');

deformationDots = quiver(axDots, dots0(:,1), dots0(:,2), ...
    zeros(nDots,1), zeros(nDots,1), ...
    0, 'Color', colors.deformation, 'LineWidth', 0.85, ...
    'MaxHeadSize', 0.35, 'DisplayName', 'deformation: [x,y]D');

expansionAxisDots = plotAxis(axDots, [1 0], colors.expansion, ...
    'D expansion axis (+1)');
compressionAxisDots = plotAxis(axDots, [0 1], colors.compression, ...
    'D compression axis (-1)');

legend(axDots, 'Location', 'southoutside', 'NumColumns', 2);

axRot = nexttile(layout);
hold(axRot, 'on');
axis(axRot, 'equal');
axis(axRot, [-1.2 1.2 -1.2 1.2]);
box(axRot, 'on');
grid(axRot, 'on');
xlabel(axRot, 'x');
ylabel(axRot, 'y');
title(axRot, 'Rotation matrix field');

rotationGrid = quiver(axRot, gridPts(:,1), gridPts(:,2), ...
    zeros(size(gridPts,1),1), zeros(size(gridPts,1),1), ...
    0, 'Color', colors.rotation, 'LineWidth', 0.8, ...
    'MaxHeadSize', 0.4);

axDef = nexttile(layout);
hold(axDef, 'on');
axis(axDef, 'equal');
axis(axDef, [-1.2 1.2 -1.2 1.2]);
box(axDef, 'on');
grid(axDef, 'on');
xlabel(axDef, 'x');
ylabel(axDef, 'y');
title(axDef, 'Deformation matrix field');

deformationGrid = quiver(axDef, gridPts(:,1), gridPts(:,2), ...
    zeros(size(gridPts,1),1), zeros(size(gridPts,1),1), ...
    0, 'Color', colors.deformation, 'LineWidth', 0.8, ...
    'MaxHeadSize', 0.4);
expansionAxisGrid = plotAxis(axDef, [1 0], colors.expansion, '');
compressionAxisGrid = plotAxis(axDef, [0 1], colors.compression, '');

sliderLabel = uicontrol(fig, ...
    'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.19 0.012 0.22 0.035], ...
    'BackgroundColor', 'w', ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'left');

slider = uicontrol(fig, ...
    'Style', 'slider', ...
    'Units', 'normalized', ...
    'Position', [0.39 0.018 0.43 0.028], ...
    'Min', 0, ...
    'Max', 2*pi, ...
    'Value', 0, ...
    'SliderStep', [1/180, 10/180]);

listener = addlistener(slider, 'Value', 'PostSet', @(~,~) updateFigure());
slider.Callback = @(~,~) updateFigure();
fig.UserData = struct('sliderListener', listener);

updateFigure();

    function updateFigure()
        t = slider.Value;
        c = cos(t);
        s = sin(t);

        R = [c, -s; s, c];
        D = [c,  s; s, -c];

        rotVec = dots0*R;
        defVec = dots0*D;
        rotGridVec = gridPts*R;
        defGridVec = gridPts*D;

        set(rotationDots, ...
            'UData', speedScale*rotVec(:,1), ...
            'VData', speedScale*rotVec(:,2));
        set(deformationDots, ...
            'UData', speedScale*defVec(:,1), ...
            'VData', speedScale*defVec(:,2));
        set(rotationGrid, ...
            'UData', 0.22*rotGridVec(:,1), ...
            'VData', 0.22*rotGridVec(:,2));
        set(deformationGrid, ...
            'UData', 0.22*defGridVec(:,1), ...
            'VData', 0.22*defGridVec(:,2));

        axisAngle = t/2;
        expansionAxis = [cos(axisAngle), sin(axisAngle)];
        compressionAxis = [-sin(axisAngle), cos(axisAngle)];

        updateAxisLine(expansionAxisDots, expansionAxis);
        updateAxisLine(compressionAxisDots, compressionAxis);
        updateAxisLine(expansionAxisGrid, expansionAxis);
        updateAxisLine(compressionAxisGrid, compressionAxis);

        title(axDots, sprintf( ...
            'Same dots: rotation field vs deformation field, t = %.2f rad (%.0f deg)', ...
            t, rad2deg(t)));
        sliderLabel.String = sprintf('t = %.3f rad   %.1f deg', t, rad2deg(t));

        drawnow limitrate;
    end
end

function h = plotAxis(ax, axisVec, color, labelText)
    axisVec = axisVec(:).';
    h = plot(ax, [-axisVec(1) axisVec(1)], [-axisVec(2) axisVec(2)], ...
        '-', 'Color', color, 'LineWidth', 2.4);
    if ~isempty(labelText)
        h.DisplayName = labelText;
    else
        h.HandleVisibility = 'off';
    end
end

function updateAxisLine(h, axisVec)
    axisVec = axisVec(:).';
    set(h, ...
        'XData', [-axisVec(1) axisVec(1)], ...
        'YData', [-axisVec(2) axisVec(2)]);
end

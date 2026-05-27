function [cx, cy, sx, sy] = centerofmass(Z)
%CENTEROFMASS Weighted center and spread for a 2D RF map.

Z = double(Z);
Z(~isfinite(Z)) = 0;

weights = Z - min(Z(:));
if sum(weights(:)) == 0
    weights = abs(Z);
end
if sum(weights(:)) == 0
    [ny, nx] = size(Z);
    cx = (nx + 1) / 2;
    cy = (ny + 1) / 2;
    sx = max(nx / 4, eps);
    sy = max(ny / 4, eps);
    return
end

[ny, nx] = size(Z);
[x, y] = meshgrid(1:nx, 1:ny);
wSum = sum(weights(:));

cx = sum(x(:) .* weights(:)) / wSum;
cy = sum(y(:) .* weights(:)) / wSum;
sx = sqrt(sum(((x(:) - cx).^2) .* weights(:)) / wSum);
sy = sqrt(sum(((y(:) - cy).^2) .* weights(:)) / wSum);

sx = max(sx, eps);
sy = max(sy, eps);
end

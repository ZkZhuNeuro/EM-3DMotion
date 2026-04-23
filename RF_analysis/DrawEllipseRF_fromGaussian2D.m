function [x_center_pix, y_center_pix, x_pix, y_pix] = DrawEllipseRF_fromGaussian2D(p_fit, Z, RF_table, i_rec)

    %%

    A = p_fit(3);
    B = p_fit(4);
    C = p_fit(5);
    h = p_fit(6);
    k = p_fit(7);

    M = [A, B/2; B/2, C];
    [V,D] = eig(M);              % columns of V are eigenvectors
    lam = diag(D);

    % semi-axis lengths for Q=1
    a = 1/sqrt(lam(1));
    b = 1/sqrt(lam(2));

    theta = atan2(V(2,1), V(1,1));  % rotation angle of axis a (radians)

    

    % parametric ellipse
    t = linspace(0, 2*pi, 400);
    ellipse = V * [a*cos(t); b*sin(t)];
    x = h + ellipse(1,:);
    y = k + ellipse(2,:);

    %% 
    Nx = size(Z, 2);
    Ny = size(Z, 1);
    [xg, yg] = meshgrid(1:Nx, 1:Ny);
    Xpos = RF_table.meanXYpos{i_rec}(:, 1);
    Ypos = RF_table.meanXYpos{i_rec}(:, 2);

    Xpos2D = reshape(Xpos, Ny, Nx);
    Ypos2D = reshape(Ypos, Ny, Nx);

    % griddedInterpolant expects grid vectors or ndgrid-style inputs;
    % easiest is to use vectors (1:Nx) and (1:Ny) and pass (y,x) order.
    Fx = griddedInterpolant({1:Ny, 1:Nx}, Xpos2D, 'linear', 'linear');
    Fy = griddedInterpolant({1:Ny, 1:Nx}, Ypos2D, 'linear', 'linear');

    x_center_pix = Fx(k, h);
    y_center_pix = Fy(k, h);

    x_pix = Fx(y, x);
    y_pix = Fy(y, x);

end

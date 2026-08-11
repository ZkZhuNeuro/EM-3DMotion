result_path = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\.codex_tmp\clay_oblique_final_output_v2\Clay_MT-FST_ObliqueResults.mat';
loaded = load(result_path, 'current_session', 'data', 'cfg');
plane = loaded.current_session;
points = loaded.data.points;
cfg = loaded.cfg;
atlas = flip(double(niftiread(cfg.atlasPath)), 1);

n = plane.normal / norm(plane.normal);
u_basis = [0 0 1] - dot([0 0 1], n) * n;
u_basis = u_basis / norm(u_basis);
v_basis = cross(n, u_basis);
if dot(v_basis, [0 -1 0]) < 0, v_basis = -v_basis; end

relative = points - plane.center;
point_u = relative * u_basis.';
point_v = relative * v_basis.';
step = cfg.sliceSpacingVox;
u_values = floor(min(point_u)-20):step:ceil(max(point_u)+20);
v_values = floor(min(point_v)-20):step:ceil(max(point_v)+20);
[ug, vg] = meshgrid(u_values, v_values);
qi = plane.center(1) + ug*u_basis(1) + vg*v_basis(1);
qj = plane.center(2) + ug*u_basis(2) + vg*v_basis(2);
qk = plane.center(3) + ug*u_basis(3) + vg*v_basis(3);
roi_slice = interpn(atlas, qi, qj, qk, 'nearest', 0);

displayed = interp2(u_values, v_values, roi_slice, point_u, point_v, 'nearest', 0);
mismatch = displayed(:) ~= plane.sampledLabels(:);
fprintf('step %.3f, mismatch %d/%d\n', step, nnz(mismatch), numel(mismatch));
fprintf('indices: %s\n', mat2str(find(mismatch).'));
fprintf('exact: %s\n', mat2str(plane.sampledLabels(mismatch).'));
fprintf('displayed: %s\n', mat2str(displayed(mismatch).'));
fprintf('point u/v: \n');
disp([point_u(mismatch), point_v(mismatch)]);

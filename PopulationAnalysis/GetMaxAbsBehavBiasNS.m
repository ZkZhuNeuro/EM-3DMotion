[unit_table_gof, data_file] = LoadLatestUnitTableGof();
[delta_bias_ns, ~, ~, goodfit_mask] = ...
    CalculateSigmoidFitBiases(unit_table_gof, 4);

max_abs_delta_bias = max(abs(delta_bias_ns), [], 'all', 'omitnan');

fprintf('Source: %s\n', data_file);
fprintf(['max abs(Behav_bias_N - Behav_bias_S), ' ...
    'good-fit only = %g (n = %d cue fits)\n'], ...
    max_abs_delta_bias, nnz(goodfit_mask));

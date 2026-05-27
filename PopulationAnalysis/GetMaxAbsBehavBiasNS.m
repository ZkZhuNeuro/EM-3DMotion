load('C:\EM\BehaviorFitting\unit_table_gof.mat', 'unit_table_gof');

bias_n = cell2mat(unit_table_gof.Behav_bias_N);
bias_s = cell2mat(unit_table_gof.Behav_bias_S);
delta_bias_ns = bias_n - bias_s;

if ismember('Behav_goodfit_both', unit_table_gof.Properties.VariableNames)
    goodfit_mask = cell2mat(unit_table_gof.Behav_goodfit_both);
else
    goodfit_n = cell2mat(unit_table_gof.Behav_goodfit_N);
    goodfit_s = cell2mat(unit_table_gof.Behav_goodfit_S);
    goodfit_mask = goodfit_n & goodfit_s;
end

delta_bias_ns(~goodfit_mask) = NaN;

max_abs_delta_bias = max(abs(delta_bias_ns), [], 'all', 'omitnan');

disp(['max abs(Behav_bias_N - Behav_bias_S), good-fit only = ' num2str(max_abs_delta_bias)])

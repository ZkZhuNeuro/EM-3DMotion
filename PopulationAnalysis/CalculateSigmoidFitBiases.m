function [delta_bias, bias_nonstim, bias_stim, valid_fit] = ...
    CalculateSigmoidFitBiases(unit_table_gof, n_cues)
% Calculate non-stimulus minus stimulus bias from sigmoid-fit PSEs.
%
% The legacy unit_table_gof.Delta_bias values are intentionally ignored.
% A cue is retained only when both sigmoid fits pass their GOF checks and
% both fitted biases are finite.

if nargin < 2 || isempty(n_cues)
    n_cues = 4;
end

if ~istable(unit_table_gof)
    error('unit_table_gof must be a table.');
end

required_variables = {'Behav_bias_N', 'Behav_bias_S', ...
    'Behav_goodfit_N', 'Behav_goodfit_S'};
missing_variables = setdiff(required_variables, ...
    unit_table_gof.Properties.VariableNames);
if ~isempty(missing_variables)
    error('unit_table_gof is missing sigmoid-fit fields: %s.', ...
        strjoin(missing_variables, ', '));
end

bias_nonstim = stack_cue_values(unit_table_gof.Behav_bias_N, ...
    height(unit_table_gof), n_cues, nan);
bias_stim = stack_cue_values(unit_table_gof.Behav_bias_S, ...
    height(unit_table_gof), n_cues, nan);
goodfit_nonstim = stack_cue_values(unit_table_gof.Behav_goodfit_N, ...
    height(unit_table_gof), n_cues, false) > 0;
goodfit_stim = stack_cue_values(unit_table_gof.Behav_goodfit_S, ...
    height(unit_table_gof), n_cues, false) > 0;

delta_bias = bias_nonstim - bias_stim;
valid_fit = goodfit_nonstim & goodfit_stim & ...
    isfinite(bias_nonstim) & isfinite(bias_stim);
delta_bias(~valid_fit) = nan;
end


function values = stack_cue_values(column, row_count, n_cues, fill_value)
values = repmat(fill_value, row_count, n_cues);

if iscell(column)
    if numel(column) ~= row_count
        error('Sigmoid-fit cell column has %d rows; expected %d.', ...
            numel(column), row_count);
    end

    for row_idx = 1:row_count
        row_values = column{row_idx};
        if isempty(row_values)
            continue
        end

        row_values = row_values(:).';
        copy_count = min(numel(row_values), n_cues);
        values(row_idx, 1:copy_count) = row_values(1:copy_count);
    end
    return
end

if isnumeric(column) || islogical(column)
    if size(column, 1) ~= row_count
        error('Sigmoid-fit array has %d rows; expected %d.', ...
            size(column, 1), row_count);
    end

    copy_count = min(size(column, 2), n_cues);
    values(:, 1:copy_count) = column(:, 1:copy_count);
    return
end

error('Unsupported sigmoid-fit column type: %s.', class(column));
end

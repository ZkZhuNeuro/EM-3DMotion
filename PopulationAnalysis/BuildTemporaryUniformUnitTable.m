function [unit_table_gof, StimChannelBaseTableMetadata] = ...
    BuildTemporaryUniformUnitTable(source_file, output_file)
%BUILDTEMPORARYUNIFORMUNITTABLE Make the compact stim-channel base table.
%
% The source file is read only. The output retains every source-table row;
% no recording-workbook selection and no adjacent-tuning discontinuity
% exclusion are applied. The obsolete Holm-corrected p_adjusted column is
% dropped; p_AI remains the tuning-significance input.
%
% Behavior is reduced to:
%   Behav_b0                    full-model intercept, one value per cue
%   Behav_b1                    coherence coefficient
%   Behav_b2                    stimulation-condition coefficient
%   Behav_b3                    coherence-by-stimulation interaction
%   Behav_delta_bias_sigmoid    non-stim minus stim fitted bias; NaN when
%                               either saved sigmoid GOF check failed
%   Behav_propTowardMat_N       empirical non-stim choice proportions
%   Behav_propTowardMat_S       empirical stim choice proportions
%   Behav_coh_levels            coherence values for the empirical points
%
% For s=0 (non-stim) and s=1 (stim), the saved full model is
%
%   logit(p) = b0 + b1*coh + b2*s + b3*coh*s.
%
% Therefore bias_N = -b0/b1, bias_S = -(b0+b2)/(b1+b3), and the compact
% delta bias is bias_N-bias_S.

arguments
    source_file (1, 1) string = ...
        "C:\EM\PopulationAnalysis\unit_table_gof.mat"
    output_file (1, 1) string = defaultOutputFile()
end

if ~isfile(source_file)
    error('UniformUnitTable:MissingSource', ...
        'Source unit-table file not found: %s', source_file);
end

loaded = load(source_file, 'unit_table_gof');
if ~isfield(loaded, 'unit_table_gof') || ...
        ~istable(loaded.unit_table_gof)
    error('UniformUnitTable:InvalidSource', ...
        '%s does not contain table unit_table_gof.', source_file);
end
source_table = loaded.unit_table_gof;

required_variables = [ ...
    "Behav_mdl_full", "Behav_goodfit_N", "Behav_goodfit_S", ...
    "Behav_propTowardMat_N", "Behav_propTowardMat_S", ...
    "Behav_coh_levels"];
missing_variables = setdiff(required_variables, ...
    string(source_table.Properties.VariableNames));
if ~isempty(missing_variables)
    error('UniformUnitTable:MissingBehaviorVariables', ...
        'Source table is missing: %s', join(missing_variables, ', '));
end

row_count = height(source_table);
cue_count = 4;
[b0, b1, b2, b3] = extractFullModelCoefficients( ...
    source_table.Behav_mdl_full, row_count, cue_count);

bias_nonstim = -b0 ./ b1;
bias_stim = -(b0 + b2) ./ (b1 + b3);
goodfit_nonstim = stackCueValues( ...
    source_table.Behav_goodfit_N, row_count, cue_count, false) > 0;
goodfit_stim = stackCueValues( ...
    source_table.Behav_goodfit_S, row_count, cue_count, false) > 0;
valid_sigmoid_fit = goodfit_nonstim & goodfit_stim & ...
    isfinite(bias_nonstim) & isfinite(bias_stim);
delta_bias_sigmoid = bias_nonstim - bias_stim;
delta_bias_sigmoid(~valid_sigmoid_fit) = nan;

validateStoredBiases(source_table, bias_nonstim, bias_stim, ...
    delta_bias_sigmoid, valid_sigmoid_fit, row_count, cue_count);
validateEmpiricalBehavior(source_table, row_count, cue_count);

source_variable_names = string(source_table.Properties.VariableNames);
behavior_variables = source_variable_names( ...
    startsWith(source_variable_names, "Behav_"));
legacy_behavior_variables = intersect(source_variable_names, ...
    ["Delta_bias", "sigma_nonStim", "sigma_Stim", "Delta_sigma", ...
    "p_adjusted"], ...
    'stable');
removed_variables = [behavior_variables, legacy_behavior_variables];

empirical_nonstim = source_table.Behav_propTowardMat_N;
empirical_stim = source_table.Behav_propTowardMat_S;
coherence_levels = source_table.Behav_coh_levels;

unit_table_gof = removevars(source_table, cellstr(removed_variables));
unit_table_gof.Behav_b0 = b0;
unit_table_gof.Behav_b1 = b1;
unit_table_gof.Behav_b2 = b2;
unit_table_gof.Behav_b3 = b3;
unit_table_gof.Behav_delta_bias_sigmoid = delta_bias_sigmoid;
unit_table_gof.Behav_propTowardMat_N = empirical_nonstim;
unit_table_gof.Behav_propTowardMat_S = empirical_stim;
unit_table_gof.Behav_coh_levels = coherence_levels;

source_info = dir(source_file);
builder_file = string(mfilename('fullpath')) + ".m";
StimChannelBaseTableMetadata = struct();
StimChannelBaseTableMetadata.SchemaVersion = ...
    "stim_channel_base_unit_table_v1";
StimChannelBaseTableMetadata.ArtifactRole = ...
    "Current reproducible base table for stimulation-channel analyses";
StimChannelBaseTableMetadata.BuilderFile = builder_file;
StimChannelBaseTableMetadata.BuilderSource = ...
    string(fileread(builder_file));
StimChannelBaseTableMetadata.CreatedAtUTC = ...
    datetime('now', 'TimeZone', 'UTC');
StimChannelBaseTableMetadata.SourceFile = source_file;
StimChannelBaseTableMetadata.SourceBytes = source_info.bytes;
StimChannelBaseTableMetadata.SourceModified = ...
    datetime(source_info.datenum, 'ConvertFrom', 'datenum');
StimChannelBaseTableMetadata.SourceRowCount = row_count;
StimChannelBaseTableMetadata.OutputRowCount = height(unit_table_gof);
StimChannelBaseTableMetadata.OutputVariableCount = width(unit_table_gof);
StimChannelBaseTableMetadata.CueCount = cue_count;
StimChannelBaseTableMetadata.ModelFormula = ...
    "logit(p) = b0 + b1*coh + b2*s + b3*coh*s; s=0 non-stim, s=1 stim";
StimChannelBaseTableMetadata.DeltaBiasDefinition = ...
    "(-b0/b1) - (-(b0+b2)/(b1+b3)); NaN unless both saved GOF checks passed";
StimChannelBaseTableMetadata.EmpiricalArrayLayout = ...
    "Behav_propTowardMat_N/S cells are cue-by-coherence; Behav_coh_levels gives columns";
StimChannelBaseTableMetadata.AppliedWorkbookSelection = false;
StimChannelBaseTableMetadata.AppliedDiscontinuityExclusion = false;
StimChannelBaseTableMetadata.AppliedHolmCorrectionToPAI = false;
StimChannelBaseTableMetadata.RemovedVariables = removed_variables(:);
StimChannelBaseTableMetadata.AddedVariables = [ ...
    "Behav_b0"; "Behav_b1"; "Behav_b2"; "Behav_b3"; ...
    "Behav_delta_bias_sigmoid"; "Behav_propTowardMat_N"; ...
    "Behav_propTowardMat_S"; "Behav_coh_levels"];

output_folder = fileparts(output_file);
if strlength(output_folder) > 0 && ~isfolder(output_folder)
    mkdir(output_folder);
end
save(output_file, 'unit_table_gof', ...
    'StimChannelBaseTableMetadata', '-v7.3');

fprintf('Saved compact unit_table_gof: %s\n', output_file);
fprintf('Rows retained: %d/%d; variables: %d -> %d\n', ...
    height(unit_table_gof), row_count, width(source_table), ...
    width(unit_table_gof));
end


function output_file = defaultOutputFile()
output_file = fullfile('C:\EM\StimChannelAnalysis', ...
    'unit_table_gof.mat');
end


function [b0, b1, b2, b3] = extractFullModelCoefficients( ...
    model_column, row_count, cue_count)
b0 = nan(row_count, cue_count);
b1 = nan(row_count, cue_count);
b2 = nan(row_count, cue_count);
b3 = nan(row_count, cue_count);

if ~iscell(model_column) || numel(model_column) ~= row_count
    error('UniformUnitTable:InvalidModelColumn', ...
        'Behav_mdl_full must be a cell column with one entry per row.');
end

expected_names = ["(Intercept)", "coh", "s", "coh:s"];
for row = 1:row_count
    cue_models = model_column{row};
    if isempty(cue_models)
        continue
    end
    if ~iscell(cue_models)
        error('UniformUnitTable:InvalidRowModels', ...
            'Behav_mdl_full{%d} must be a cue-model cell array.', row);
    end
    for cue = 1:min(cue_count, numel(cue_models))
        model = cue_models{cue};
        if isempty(model)
            continue
        end
        names = string(model.CoefficientNames);
        estimates = double(model.Coefficients.Estimate(:));
        indices = zeros(1, numel(expected_names));
        for coefficient = 1:numel(expected_names)
            match = find(names == expected_names(coefficient), 1);
            if isempty(match)
                error('UniformUnitTable:UnexpectedModel', ...
                    ['Row %d cue %d model lacks coefficient %s. ' ...
                    'Found: %s'], row, cue, expected_names(coefficient), ...
                    join(names, ', '));
            end
            indices(coefficient) = match;
        end
        values = estimates(indices);
        b0(row, cue) = values(1);
        b1(row, cue) = values(2);
        b2(row, cue) = values(3);
        b3(row, cue) = values(4);
    end
end
end


function validateStoredBiases(source_table, bias_nonstim, bias_stim, ...
    delta_bias, valid_fit, row_count, cue_count)
if all(ismember(["Behav_bias_N", "Behav_bias_S"], ...
        string(source_table.Properties.VariableNames)))
    stored_nonstim = stackCueValues(source_table.Behav_bias_N, ...
        row_count, cue_count, nan);
    stored_stim = stackCueValues(source_table.Behav_bias_S, ...
        row_count, cue_count, nan);
    assertFiniteValuesMatch(stored_nonstim, bias_nonstim, ...
        'non-stim sigmoid bias');
    assertFiniteValuesMatch(stored_stim, bias_stim, ...
        'stim sigmoid bias');
end

if ismember("Behav_bias_NminusS", ...
        string(source_table.Properties.VariableNames))
    stored_delta = stackCueValues(source_table.Behav_bias_NminusS, ...
        row_count, cue_count, nan);
    compare_mask = valid_fit & isfinite(stored_delta);
    assertFiniteValuesMatch(stored_delta(compare_mask), ...
        delta_bias(compare_mask), 'sigmoid delta bias');
end
end


function assertFiniteValuesMatch(expected, actual, label)
compare_mask = isfinite(expected) & isfinite(actual);
if ~any(compare_mask, 'all')
    return
end
scale = max(1, max(abs(expected(compare_mask)), [], 'all'));
max_error = max(abs(expected(compare_mask) - actual(compare_mask)), ...
    [], 'all');
if max_error > 1e-10 * scale
    error('UniformUnitTable:BehaviorValidationFailed', ...
        'Extracted %s differs from its saved value (max error %.6g).', ...
        label, max_error);
end
end


function validateEmpiricalBehavior(source_table, row_count, cue_count)
for condition = ["N", "S"]
    variable = "Behav_propTowardMat_" + condition;
    values = source_table.(variable);
    if ~iscell(values) || numel(values) ~= row_count
        error('UniformUnitTable:InvalidEmpiricalColumn', ...
            '%s must have one cell per table row.', variable);
    end
    for row = 1:row_count
        if ~isnumeric(values{row}) || size(values{row}, 1) ~= cue_count
            error('UniformUnitTable:InvalidEmpiricalArray', ...
                '%s{%d} must be a %d-by-coherence numeric array.', ...
                variable, row, cue_count);
        end
    end
end

coherence = source_table.Behav_coh_levels;
if ~iscell(coherence) || numel(coherence) ~= row_count
    error('UniformUnitTable:InvalidCoherenceColumn', ...
        'Behav_coh_levels must have one cell per table row.');
end
for row = 1:row_count
    n_coherence = numel(coherence{row});
    if size(source_table.Behav_propTowardMat_N{row}, 2) ~= n_coherence || ...
            size(source_table.Behav_propTowardMat_S{row}, 2) ~= n_coherence
        error('UniformUnitTable:EmpiricalSizeMismatch', ...
            'Row %d choice-proportion columns do not match coherence levels.', ...
            row);
    end
end
end


function values = stackCueValues(column, row_count, cue_count, fill_value)
values = repmat(fill_value, row_count, cue_count);
if iscell(column)
    if numel(column) ~= row_count
        error('UniformUnitTable:InvalidCueColumn', ...
            'Cue cell column has %d rows; expected %d.', ...
            numel(column), row_count);
    end
    for row = 1:row_count
        row_values = column{row};
        if isempty(row_values)
            continue
        end
        row_values = row_values(:).';
        copy_count = min(numel(row_values), cue_count);
        values(row, 1:copy_count) = row_values(1:copy_count);
    end
elseif isnumeric(column) || islogical(column)
    if size(column, 1) ~= row_count
        error('UniformUnitTable:InvalidCueArray', ...
            'Cue array has %d rows; expected %d.', ...
            size(column, 1), row_count);
    end
    copy_count = min(size(column, 2), cue_count);
    values(:, 1:copy_count) = column(:, 1:copy_count);
else
    error('UniformUnitTable:UnsupportedCueColumn', ...
        'Unsupported cue-column class: %s.', class(column));
end
end

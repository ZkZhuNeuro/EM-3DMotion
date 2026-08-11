% Trim unit_table_gof so only key behavior-GOF fields remain after
% Raw2D_StimCh, then save a cleaned copy to C:\EM\BehaviorFitting.

inputMatFile = 'C:\EM\BehaviorFitting\unit_table_gof.mat';
outputMatFile = 'C:\EM\BehaviorFitting\unit_table_GOF.mat';
varName = 'unit_table_gof';

anchorVar = 'Raw2D_StimCh';
tailKeepVars = { ...
    'OriginalRecIdx', ...
    'Behav_goodfit_S', ...
    'Behav_goodfit_N', ...
    'Behav_bias_N', ...
    'Behav_bias_S', ...
    'Behav_bias_NminusS', ...
    'Behav_slope_N', ...
    'Behav_slope_S', ...
    'Behav_slope_NminusS', ...
    'ND' ...
    };

loadedData = load(inputMatFile, varName);

if ~isfield(loadedData, varName)
    error('Variable "%s" was not found in %s.', varName, inputMatFile);
end

unit_table_gof = loadedData.(varName);

if ~istable(unit_table_gof)
    error('Variable "%s" must be a table.', varName);
end

varNames = unit_table_gof.Properties.VariableNames;
anchorIdx = find(strcmp(varNames, anchorVar), 1);

if isempty(anchorIdx)
    error('Anchor variable "%s" was not found in %s.', anchorVar, varName);
end

keepMask = false(size(varNames));
keepMask(1:anchorIdx) = true;

afterAnchor = (1:numel(varNames)) > anchorIdx;
keepMask(afterAnchor) = ismember(varNames(afterAnchor), tailKeepVars);

unit_table_gof = unit_table_gof(:, keepMask);

save(outputMatFile, 'unit_table_gof', '-v7.3');

fprintf('Saved cleaned table with %d variables to:\n%s\n', ...
    width(unit_table_gof), outputMatFile);

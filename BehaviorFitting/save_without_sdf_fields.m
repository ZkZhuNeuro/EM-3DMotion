function save_without_sdf_fields(inputMatFile, outputMatFile, varName)
%SAVE_WITHOUT_SDF_FIELDS Remove struct fields containing "SDF" and save.
%   save_without_sdf_fields(INPUTMATFILE, OUTPUTMATFILE) loads
%   MotionData_ByStim from INPUTMATFILE, removes any fields whose names
%   contain "SDF", and saves the cleaned variable to OUTPUTMATFILE.
%
%   save_without_sdf_fields(INPUTMATFILE, OUTPUTMATFILE, VARNAME) does the
%   same for the struct variable named VARNAME.

if nargin < 3 || isempty(varName)
    varName = 'MotionData_ByStim';
end

loadedData = load(inputMatFile, varName);

if ~isfield(loadedData, varName)
    error('Variable "%s" was not found in %s.', varName, inputMatFile);
end

dataStruct = loadedData.(varName);

if ~isstruct(dataStruct)
    error('Variable "%s" must be a struct or struct array.', varName);
end

fieldList = fieldnames(dataStruct);
removeMask = contains(fieldList, 'SDF');
fieldsToRemove = fieldList(removeMask);

if ~isempty(fieldsToRemove)
    dataStruct = rmfield(dataStruct, fieldsToRemove);
end

savePayload = struct();
savePayload.(varName) = dataStruct;
save(outputMatFile, '-struct', 'savePayload', '-v7.3');
end

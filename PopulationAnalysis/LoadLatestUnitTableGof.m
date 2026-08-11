function [unit_table_gof, data_file, workbook_audit] = ...
    LoadLatestUnitTableGof(data_file)
% Load unit_table_gof and refresh its selection/metadata from workbooks.
%
% Pass a MAT-file path to use a specific artifact. With no input, the
% canonical C:\EM\PopulationAnalysis\unit_table_gof.mat file is used.

if nargin < 1 || isempty(data_file)
    data_file = 'C:\EM\PopulationAnalysis\unit_table_gof.mat';
end

if ~(ischar(data_file) || (isstring(data_file) && isscalar(data_file)))
    error('data_file must be a character vector or string scalar.');
end
data_file = char(data_file);

if ~isfile(data_file)
    error('unit_table_gof file not found: %s', data_file);
end

loaded_data = load(data_file, 'unit_table_gof');
if ~isfield(loaded_data, 'unit_table_gof') || ...
        ~istable(loaded_data.unit_table_gof)
    error('The file "%s" does not contain table unit_table_gof.', ...
        data_file);
end

unit_table_gof = loaded_data.unit_table_gof;
[unit_table_gof, workbook_audit] = ...
    RefreshUnitTableGofFromRecordingWorkbooks(unit_table_gof);
if ~isempty(workbook_audit.RemovedRows)
    warning('PopulationAnalysis:WorkbookSessionsRemoved', ...
        ['%d GOF session(s) are no longer selected by the current ' ...
        'recording workbooks and were excluded.'], ...
        height(workbook_audit.RemovedRows));
end
if ~isempty(workbook_audit.MissingSessions)
    warning('PopulationAnalysis:WorkbookSessionsMissingGof', ...
        ['%d workbook-selected session(s) have no GOF row and cannot ' ...
        'be included until they are analyzed.'], ...
        height(workbook_audit.MissingSessions));
end
end

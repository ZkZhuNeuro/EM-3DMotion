function ResultTable = BuildFSTPDIAndBODITable( ...
        PatternTuningTable, BinocularOpticFlowTable, options)
%BUILDFSTPDIANDBODITABLE Build one matched-speed PDI and one BODI per neuron.
%   PDI uses TDI for toward-preferring neurons and ADI for away-preferring
%   neurons. The final table intentionally omits separate TDI and ADI fields.

arguments
    PatternTuningTable table
    BinocularOpticFlowTable table
    options.SourceDataset (1, 1) string
    options.SelectionCriterion (1, 1) string
end

requiredPattern = {'SourceRow', 'Date', 'Monkey', 'ROI', 'NeuroType', ...
    'Z3D_v_Z2D', 'Combined_AI', 'CombinedCuePreference', ...
    'IsMatchedSlowSpeed', 'TDI_Numerator', 'TDI_Denominator', 'TDI', ...
    'ADI_Numerator', 'ADI_Denominator', 'ADI', 'Valid_TDI', 'Valid_ADI'};
requiredBODI = {'SourceRow', 'CombinedCuePreference', ...
    'PreferredCoherence', 'Combined_FR', 'Stereo_FR', 'N_Combined_FR', ...
    'N_Stereo_FR', 'BODI_Numerator', 'BODI_Denominator', 'BODI', 'Valid_BODI'};
validate_variables(PatternTuningTable, requiredPattern, 'pattern-tuning');
validate_variables(BinocularOpticFlowTable, requiredBODI, 'BODI');

if ~all(PatternTuningTable.IsMatchedSlowSpeed)
    error('BuildFSTPDIAndBODITable:NonMatchedSpeed', ...
        'PDI input must contain only matched slow-speed rows.');
end
if numel(unique(PatternTuningTable.SourceRow)) ~= height(PatternTuningTable)
    error('BuildFSTPDIAndBODITable:DuplicatePDIUnits', ...
        'PDI input must contain exactly one row per neuron.');
end
if numel(unique(BinocularOpticFlowTable.SourceRow)) ~= ...
        height(BinocularOpticFlowTable)
    error('BuildFSTPDIAndBODITable:DuplicateBODIUnits', ...
        'BODI input must contain exactly one row per neuron.');
end

[foundBODI, bodiLocation] = ismember( ...
    PatternTuningTable.SourceRow, BinocularOpticFlowTable.SourceRow);
if ~all(foundBODI) || height(PatternTuningTable) ~= height(BinocularOpticFlowTable)
    error('BuildFSTPDIAndBODITable:UnitMismatch', ...
        'PDI and BODI inputs must describe the same neurons.');
end
B = BinocularOpticFlowTable(bodiLocation, :);
preference = string(PatternTuningTable.CombinedCuePreference);
if ~isequal(preference, string(B.CombinedCuePreference))
    error('BuildFSTPDIAndBODITable:PreferenceMismatch', ...
        'PDI and BODI preference labels do not match.');
end

nRows = height(PatternTuningTable);
toward = preference == "Toward";
away = preference == "Away";
PDI_Component = repmat("Undefined", nRows, 1);
PDI_Component(toward) = "TDI";
PDI_Component(away) = "ADI";
PDI_Numerator = nan(nRows, 1);
PDI_Denominator = nan(nRows, 1);
PDI = nan(nRows, 1);
Valid_PDI = false(nRows, 1);
PDI_Numerator(toward) = PatternTuningTable.TDI_Numerator(toward);
PDI_Denominator(toward) = PatternTuningTable.TDI_Denominator(toward);
PDI(toward) = PatternTuningTable.TDI(toward);
Valid_PDI(toward) = PatternTuningTable.Valid_TDI(toward);
PDI_Numerator(away) = PatternTuningTable.ADI_Numerator(away);
PDI_Denominator(away) = PatternTuningTable.ADI_Denominator(away);
PDI(away) = PatternTuningTable.ADI(away);
Valid_PDI(away) = PatternTuningTable.Valid_ADI(away);

ResultTable = table();
ResultTable.SourceDataset = repmat(options.SourceDataset, nRows, 1);
ResultTable.SourceRow = double(PatternTuningTable.SourceRow);
ResultTable.SourceID = options.SourceDataset + "_" + string(ResultTable.SourceRow);
ResultTable.Date = PatternTuningTable.Date;
ResultTable.Monkey = string(PatternTuningTable.Monkey);
ResultTable.ROI = string(PatternTuningTable.ROI);
ResultTable.Tetrode = optional_numeric(PatternTuningTable, 'Tetrode', nRows);
ResultTable.Unit = optional_numeric(PatternTuningTable, 'Unit', nRows);
ResultTable.StimElec = optional_numeric(PatternTuningTable, 'StimElec', nRows);
ResultTable.OriginalRecIdx = optional_numeric( ...
    PatternTuningTable, 'OriginalRecIdx', nRows);
ResultTable.NeuroType = string(PatternTuningTable.NeuroType);
ResultTable.SelectionCriterion = repmat(options.SelectionCriterion, nRows, 1);
ResultTable.Z3D_v_Z2D = double(PatternTuningTable.Z3D_v_Z2D);
ResultTable.Combined_AI = double(PatternTuningTable.Combined_AI);
ResultTable.CombinedCuePreference = preference;
ResultTable.PDI_2DSpeed = repmat("Slow (~4.2 deg/s)", nRows, 1);
ResultTable.PDI_Component = PDI_Component;
ResultTable.PDI_Numerator = PDI_Numerator;
ResultTable.PDI_Denominator = PDI_Denominator;
ResultTable.PDI = PDI;
ResultTable.Valid_PDI = Valid_PDI;
ResultTable.PreferredCoherence = double(B.PreferredCoherence);
ResultTable.Combined_FR = double(B.Combined_FR);
ResultTable.Stereo_FR = double(B.Stereo_FR);
ResultTable.N_Combined_FR = double(B.N_Combined_FR);
ResultTable.N_Stereo_FR = double(B.N_Stereo_FR);
ResultTable.BODI_Numerator = double(B.BODI_Numerator);
ResultTable.BODI_Denominator = double(B.BODI_Denominator);
ResultTable.BODI = double(B.BODI);
ResultTable.Valid_BODI = logical(B.Valid_BODI);
ResultTable.Valid_Both = ResultTable.Valid_PDI & ResultTable.Valid_BODI;
ResultTable.Properties.Description = sprintf( ...
    ['%s results (%s): one slow-speed PDI and one 3D-stimulus BODI ' ...
    'per neuron.'], options.SourceDataset, options.SelectionCriterion);

check_index_bounds(ResultTable.PDI, 'PDI');
check_index_bounds(ResultTable.BODI, 'BODI');
end

function validate_variables(T, required, tableName)
missing = setdiff(required, T.Properties.VariableNames);
if ~isempty(missing)
    error('BuildFSTPDIAndBODITable:MissingVariables', ...
        '%s table is missing: %s', tableName, strjoin(missing, ', '));
end
end

function values = optional_numeric(T, variableName, nRows)
if ismember(variableName, T.Properties.VariableNames)
    values = double(T.(variableName));
else
    values = nan(nRows, 1);
end
values = reshape(values, [], 1);
end

function check_index_bounds(values, label)
finiteValues = values(isfinite(values));
if any(abs(finiteValues) > 1 + 1e-10)
    error('BuildFSTPDIAndBODITable:IndexOutOfBounds', ...
        '%s contains a value outside [-1, 1].', label);
end
end

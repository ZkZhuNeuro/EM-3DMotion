function reference = calculateStimChannelPopulationReference( ...
    unitTable, row, odDefinition)
%CALCULATESTIMCHANNELPOPULATIONREFERENCE Reproduce fixed-StimElec inputs.
%
% Returns the exact AI, signed OD, and Z3D-Z2D values used by the
% stimulation-channel population pathway. Correlation-based OD uses the
% common finite Combined/MonoL/MonoR coherence support and Fisher-z
% differences without sqrt(N-3) scaling.

arguments
    unitTable table
    row (1, 1) double {mustBeInteger, mustBePositive}
    odDefinition (1, 1) string ...
        {mustBeMember(odDefinition, ...
        ["Max", "RMSE", "Correlation", "PartialCorrelation"])}
end

if row > height(unitTable)
    error('GaussianMetaInteractive:ReferenceRowOutOfRange', ...
        'Reference row %d exceeds the table height %d.', ...
        row, height(unitTable));
end
required = ["StimElec", "AI", "tuning_mean", "Z3D_v_Z2D"];
missing = required(~ismember(required, ...
    string(unitTable.Properties.VariableNames)));
if ~isempty(missing)
    error('GaussianMetaInteractive:MissingReferenceVariables', ...
        'Stimulation-channel reference requires: %s.', ...
        join(missing, ', '));
end

stimChannel = numericScalar(unitTable.StimElec, row);
aiMatrix = numericValue(unitTable.AI, row);
tuningMean = numericValue(unitTable.tuning_mean, row);
zDifference = numericScalar(unitTable.Z3D_v_Z2D, row);
if ~isfinite(stimChannel) || stimChannel < 1 || ...
        stimChannel ~= fix(stimChannel) || ...
        size(aiMatrix, 1) < 4 || stimChannel > size(aiMatrix, 2) || ...
        size(tuningMean, 1) < 3 || stimChannel > size(tuningMean, 3)
    error('GaussianMetaInteractive:InvalidStimReference', ...
        'StimElec or stimulation-channel tuning is invalid at row %d.', row);
end

ai = reshape(double(aiMatrix(1:4, stimChannel)), 1, 4);
combined = reshape(double(tuningMean(1, :, stimChannel)), 1, []);
left = reshape(double(tuningMean(2, :, stimChannel)), 1, []);
right = reshape(double(tuningMean(3, :, stimChannel)), 1, []);
commonSupport = isfinite(combined) & isfinite(left) & isfinite(right);
combined = combined(commonSupport);
left = left(commonSupport);
right = right(commonSupport);
od = calculateOD(combined, left, right, odDefinition);

reference = struct();
reference.StimChannel = stimChannel;
reference.AI = ai;
reference.OD = od;
reference.Z3DMinusZ2D = zDifference;
reference.CommonSupportCount = nnz(commonSupport);
reference.Valid = all(isfinite(ai)) && isfinite(od) && od ~= 0 && ...
    isfinite(zDifference) && zDifference ~= 0;
end


function od = calculateOD(combined, left, right, definition)
od = NaN;
if isempty(combined)
    return
end
switch definition
    case "Max"
        denominator = max(left) + max(right);
        if isfinite(denominator) && denominator ~= 0
            od = (max(left) - max(right)) ./ denominator;
        end
    case "RMSE"
        leftRMSE = sqrt(mean((combined - left) .^ 2));
        rightRMSE = sqrt(mean((combined - right) .^ 2));
        denominator = leftRMSE + rightRMSE;
        if denominator > 0 && isfinite(denominator)
            od = (rightRMSE - leftRMSE) ./ denominator;
        elseif denominator == 0
            od = 0;
        end
    case "Correlation"
        if numel(combined) < 2
            return
        end
        leftR = pearsonR(combined, left);
        rightR = pearsonR(combined, right);
        if all(isfinite([leftR, rightR]))
            od = fisherZ(leftR) - fisherZ(rightR);
        end
    case "PartialCorrelation"
        if numel(combined) <= 3
            return
        end
        leftR = pearsonR(combined, left);
        rightR = pearsonR(combined, right);
        leftRightR = pearsonR(left, right);
        leftPartial = firstOrderPartialR(leftR, rightR, leftRightR);
        rightPartial = firstOrderPartialR(rightR, leftR, leftRightR);
        if all(isfinite([leftPartial, rightPartial]))
            od = fisherZ(leftPartial) - fisherZ(rightPartial);
        end
end
end


function value = firstOrderPartialR(rXY, rXZ, rYZ)
value = NaN;
if ~isscalar(rXY) || ~isscalar(rXZ) || ~isscalar(rYZ) || ...
        any(~isfinite([rXY, rXZ, rYZ]))
    return
end
denominatorSquared = (1 - rXZ .^ 2) .* (1 - rYZ .^ 2);
if any(~isfinite(denominatorSquared), 'all') || ...
        any(denominatorSquared <= eps(1), 'all')
    return
end
value = (rXY - rXZ .* rYZ) ./ sqrt(denominatorSquared);
value = max(-1, min(1, value));
end


function value = fisherZ(r)
bounded = max(-1 + eps(1), min(1 - eps(1), double(r)));
value = atanh(bounded);
end


function value = pearsonR(x, y)
x = double(x(:));
y = double(y(:));
x = x - mean(x);
y = y - mean(y);
denominator = sqrt(sum(x .^ 2) .* sum(y .^ 2));
if isfinite(denominator) && denominator > 0
    value = sum(x .* y) ./ denominator;
    value = max(-1, min(1, value));
else
    value = NaN;
end
end


function value = numericScalar(column, row)
value = numericValue(column, row);
if ~isscalar(value)
    error('GaussianMetaInteractive:ExpectedReferenceScalar', ...
        'Expected a scalar at row %d.', row);
end
end


function value = numericValue(column, row)
if iscell(column)
    value = column{row};
else
    value = column(row, :);
end
while iscell(value) && isscalar(value)
    value = value{1};
end
if ~isnumeric(value) && ~islogical(value)
    error('GaussianMetaInteractive:ExpectedReferenceNumeric', ...
        'Expected numeric content at row %d.', row);
end
value = double(value);
end

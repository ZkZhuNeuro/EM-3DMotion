%% Save And Compare Lateral OD From Raw FR
% Computes Monocularity_2D_Max directly from
% LateralMotionRawFRTable.MeanFR_ByConditionDirectionSpeed, saves the
% result back into C:\LoData\LateralMotionRawFRTable.mat, and compares it
% row-by-row against LateralMotionTable.Monocularity_2D_Max.

rawPath = 'C:\LoData\LateralMotionRawFRTable.mat';
lateralPath = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\OD_2D3DCompare\LateralMotionTable.mat';
comparisonPath = 'C:\LoData\LateralODComparison.mat';

disp('Loading LateralMotionRawFRTable...')
Sraw = load(rawPath);
if ~isfield(Sraw, 'LateralMotionRawFRTable')
    error('Variable "LateralMotionRawFRTable" not found in %s.', rawPath);
end
LateralMotionRawFRTable = Sraw.LateralMotionRawFRTable;

disp('Loading LateralMotionTable...')
Slat = load(lateralPath, 'LateralMotionTable');
if ~isfield(Slat, 'LateralMotionTable')
    error('Variable "LateralMotionTable" not found in %s.', lateralPath);
end
LateralMotionTable = Slat.LateralMotionTable;

requiredRawVars = {'MeanFR_ByConditionDirectionSpeed', 'ConditionCodesUsed', 'Date', 'ROI', 'Unit'};
requiredLatVars = {'Monocularity_2D_Max', 'Date', 'ROI', 'Unit'};
check_required_vars(LateralMotionRawFRTable, requiredRawVars, 'LateralMotionRawFRTable');
check_required_vars(LateralMotionTable, requiredLatVars, 'LateralMotionTable');

if height(LateralMotionRawFRTable) ~= height(LateralMotionTable)
    error('LateralMotionRawFRTable and LateralMotionTable do not have the same number of rows.');
end

disp('Verifying Date / ROI / Unit row alignment...')
verify_row_alignment(LateralMotionRawFRTable, LateralMotionTable);

nRows = height(LateralMotionRawFRTable);
Monocularity_2D_Max = nan(nRows, 2);
LeftMax_2D = nan(nRows, 2);
RightMax_2D = nan(nRows, 2);

disp(['Computing Monocularity_2D_Max from raw FR for ', num2str(nRows), ' neurons...'])
for i = 1:nRows
    resp = LateralMotionRawFRTable.MeanFR_ByConditionDirectionSpeed{i};
    condCodes = LateralMotionRawFRTable.ConditionCodesUsed{i};
    [odVals, leftVals, rightVals] = compute_monocularity_2d_max(resp, condCodes);

    Monocularity_2D_Max(i, :) = odVals;
    LeftMax_2D(i, :) = leftVals;
    RightMax_2D(i, :) = rightVals;

    if mod(i, 100) == 0 || i == nRows
        disp(['  Processed ', num2str(i), '/', num2str(nRows)])
    end
end

LateralMotionRawFRTable.Monocularity_2D_Max = Monocularity_2D_Max;
LateralMotionRawFRTable.LeftMax_2D = LeftMax_2D;
LateralMotionRawFRTable.RightMax_2D = RightMax_2D;

disp('Saving updated LateralMotionRawFRTable.mat...')
Sraw.LateralMotionRawFRTable = LateralMotionRawFRTable;
save(rawPath, '-struct', 'Sraw', '-v7.3');

disp('Comparing raw-derived Monocularity_2D_Max against LateralMotionTable...')
referenceVals = LateralMotionTable.Monocularity_2D_Max;
computedVals = LateralMotionRawFRTable.Monocularity_2D_Max;
absDiff = abs(computedVals - referenceVals);
tol = 0.1;

ComparisonTable = table();
ComparisonTable.RowIndex = (1:nRows)';
ComparisonTable.Date = LateralMotionRawFRTable.Date;
ComparisonTable.ROI = string(LateralMotionRawFRTable.ROI);
ComparisonTable.Unit = LateralMotionRawFRTable.Unit;
ComparisonTable.Raw_OD_Speed1 = computedVals(:, 1);
ComparisonTable.Reference_OD_Speed1 = referenceVals(:, 1);
ComparisonTable.AbsDiff_Speed1 = absDiff(:, 1);
ComparisonTable.Match_Speed1 = absDiff(:, 1) <= tol | (isnan(computedVals(:, 1)) & isnan(referenceVals(:, 1)));
ComparisonTable.Raw_OD_Speed2 = computedVals(:, 2);
ComparisonTable.Reference_OD_Speed2 = referenceVals(:, 2);
ComparisonTable.AbsDiff_Speed2 = absDiff(:, 2);
ComparisonTable.Match_Speed2 = absDiff(:, 2) <= tol | (isnan(computedVals(:, 2)) & isnan(referenceVals(:, 2)));
ComparisonTable.AllMatch = ComparisonTable.Match_Speed1 & ComparisonTable.Match_Speed2;

save(comparisonPath, 'ComparisonTable', 'tol', '-v7.3');

disp(['Saved comparison table to ', comparisonPath])
fprintf('Speed 1 matches: %d / %d\n', sum(ComparisonTable.Match_Speed1), nRows);
fprintf('Speed 2 matches: %d / %d\n', sum(ComparisonTable.Match_Speed2), nRows);
fprintf('All-speed matches: %d / %d\n', sum(ComparisonTable.AllMatch), nRows);

disp('Plotting reference vs calculated OD scatter plots...')
plot_od_scatter(ComparisonTable.Reference_OD_Speed1, ComparisonTable.Raw_OD_Speed1, ...
    'Speed 1: Reference vs Calculated OD');
plot_od_scatter(ComparisonTable.Reference_OD_Speed2, ComparisonTable.Raw_OD_Speed2, ...
    'Speed 2: Reference vs Calculated OD');

firstMismatch = find(~ComparisonTable.AllMatch, 10, 'first');
if isempty(firstMismatch)
    disp('All rows match within tolerance.')
else
    disp('First mismatching rows:')
    disp(ComparisonTable(firstMismatch, :))
end

function check_required_vars(T, requiredVars, tableName)
missingVars = requiredVars(~ismember(requiredVars, T.Properties.VariableNames));
if ~isempty(missingVars)
    error('%s is missing required variable(s): %s', tableName, strjoin(missingVars, ', '));
end
end

function verify_row_alignment(Traw, Tref)
dateMatch = isequal(Traw.Date, Tref.Date);
roiMatch = isequal(string(Traw.ROI), string(Tref.ROI));
unitMatch = isequal(Traw.Unit, Tref.Unit);

if ~(dateMatch && roiMatch && unitMatch)
    error('Date / ROI / Unit rows do not align between LateralMotionRawFRTable and LateralMotionTable.');
end
end

function [odVals, leftVals, rightVals] = compute_monocularity_2d_max(resp, condCodes)
odVals = nan(1, 2);
leftVals = nan(1, 2);
rightVals = nan(1, 2);

if isempty(resp)
    return
end

[leftIdx, rightIdx] = get_left_right_condition_indices(condCodes, size(resp, 1));
if isnan(leftIdx) || isnan(rightIdx)
    return
end

if ndims(resp) < 3
    leftVals(1) = max(resp(leftIdx, :), [], 'all', 'omitnan');
    rightVals(1) = max(resp(rightIdx, :), [], 'all', 'omitnan');
    odVals(1) = compute_od_from_maxima(leftVals(1), rightVals(1));
else
    nSpeeds = min(size(resp, 3), 2);
    for s = 1:nSpeeds
        leftVals(s) = max(resp(leftIdx, :, s), [], 'all', 'omitnan');
        rightVals(s) = max(resp(rightIdx, :, s), [], 'all', 'omitnan');
        odVals(s) = compute_od_from_maxima(leftVals(s), rightVals(s));
    end
end
end

function [leftIdx, rightIdx] = get_left_right_condition_indices(condCodes, nConditions)
leftIdx = nan;
rightIdx = nan;

if ~isempty(condCodes)
    leftMatch = find(condCodes == 8001, 1, 'first');
    rightMatch = find(condCodes == 8002, 1, 'first');
    if ~isempty(leftMatch)
        leftIdx = leftMatch;
    end
    if ~isempty(rightMatch)
        rightIdx = rightMatch;
    end
end

if isnan(leftIdx) && nConditions >= 1
    leftIdx = 1;
end
if isnan(rightIdx) && nConditions >= 2
    rightIdx = 2;
end
end

function odVal = compute_od_from_maxima(leftMax, rightMax)
odVal = nan;
denom = leftMax + rightMax;
if isfinite(denom) && denom ~= 0
    odVal = (leftMax - rightMax) ./ denom;
end
end

function plot_od_scatter(referenceVals, calculatedVals, plotTitle)
figure('Name', plotTitle);
valid = isfinite(referenceVals) & isfinite(calculatedVals);

if any(valid)
    scatter(referenceVals(valid), calculatedVals(valid), 24, 'filled');
    hold on
    lims = [min([referenceVals(valid); calculatedVals(valid)]), ...
        max([referenceVals(valid); calculatedVals(valid)])];
    if all(isfinite(lims)) && lims(1) < lims(2)
        plot(lims, lims, 'k--', 'LineWidth', 1);
        xlim(lims);
        ylim(lims);
    end
    hold off
else
    text(0.5, 0.5, 'No valid data', 'HorizontalAlignment', 'center');
end

xlabel('Reference OD');
ylabel('Calculated OD');
title(plotTitle);
grid on
axis square
end

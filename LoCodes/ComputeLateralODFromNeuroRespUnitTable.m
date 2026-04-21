%% Compute Lateral OD From NeuroRespUnitTable
% Assumptions from user:
% - row 2 is Left
% - row 3 is Right
% - some neurons have 2 speeds, and speed 2 should be saved separately
%
% This script loads NeuroRespUnitTable, computes
%   OD = (max(Left) - max(Right)) / (max(Left) + max(Right))
% for each speed, and saves the updated table to C:\LoData.

input_path = 'C:\LoData\NeuroRespUnitTable.mat';
output_path = 'C:\LoData\NeuroRespUnitTable_LateralOD.mat';

left_row = 2;
right_row = 3;

disp('Loading NeuroRespUnitTable...')
S = load(input_path, 'NeuroRespUnitTable');
if ~isfield(S, 'NeuroRespUnitTable')
    error('Variable "NeuroRespUnitTable" not found in %s.', input_path);
end

NeuroRespUnitTable = S.NeuroRespUnitTable;
nRows = height(NeuroRespUnitTable);

NeuroRespUnitTable.LeftMax_Speed1 = nan(nRows, 1);
NeuroRespUnitTable.RightMax_Speed1 = nan(nRows, 1);
NeuroRespUnitTable.OD_Lateral_Speed1 = nan(nRows, 1);

NeuroRespUnitTable.LeftMax_Speed2 = nan(nRows, 1);
NeuroRespUnitTable.RightMax_Speed2 = nan(nRows, 1);
NeuroRespUnitTable.OD_Lateral_Speed2 = nan(nRows, 1);

disp(['Computing lateral OD for ', num2str(nRows), ' neurons...'])

for i = 1:nRows
    resp = NeuroRespUnitTable.NeuroResp{i};
    if isempty(resp)
        continue
    end

    % Supported layouts:
    %   cond x dir x repeats
    %   cond x dir x speed x repeats
    if ndims(resp) == 3
        [leftMax, rightMax, odVal] = compute_od_single_speed(resp, left_row, right_row);
        NeuroRespUnitTable.LeftMax_Speed1(i) = leftMax;
        NeuroRespUnitTable.RightMax_Speed1(i) = rightMax;
        NeuroRespUnitTable.OD_Lateral_Speed1(i) = odVal;

    elseif ndims(resp) >= 4
        nSpeeds = size(resp, 3);

        if nSpeeds >= 1
            resp_speed1 = squeeze(resp(:, :, 1, :));
            [leftMax, rightMax, odVal] = compute_od_single_speed(resp_speed1, left_row, right_row);
            NeuroRespUnitTable.LeftMax_Speed1(i) = leftMax;
            NeuroRespUnitTable.RightMax_Speed1(i) = rightMax;
            NeuroRespUnitTable.OD_Lateral_Speed1(i) = odVal;
        end

        if nSpeeds >= 2
            resp_speed2 = squeeze(resp(:, :, 2, :));
            [leftMax, rightMax, odVal] = compute_od_single_speed(resp_speed2, left_row, right_row);
            NeuroRespUnitTable.LeftMax_Speed2(i) = leftMax;
            NeuroRespUnitTable.RightMax_Speed2(i) = rightMax;
            NeuroRespUnitTable.OD_Lateral_Speed2(i) = odVal;
        end
    end

    if mod(i, 100) == 0 || i == nRows
        disp(['  Processed ', num2str(i), '/', num2str(nRows)])
    end
end

save(output_path, 'NeuroRespUnitTable', '-v7.3');
disp(['Saved updated table to ', output_path])

function [leftMax, rightMax, odVal] = compute_od_single_speed(resp, left_row, right_row)
leftMax = nan;
rightMax = nan;
odVal = nan;

if size(resp, 1) < max(left_row, right_row)
    return
end

leftResp = squeeze(resp(left_row, :, :));
rightResp = squeeze(resp(right_row, :, :));

leftMean = mean_across_repeats(leftResp);
rightMean = mean_across_repeats(rightResp);

leftMax = max(leftMean(:), [], 'omitnan');
rightMax = max(rightMean(:), [], 'omitnan');

denom = leftMax + rightMax;
if isfinite(denom) && denom ~= 0
    odVal = (leftMax - rightMax) ./ denom;
end
end

function meanResp = mean_across_repeats(resp)
if isvector(resp)
    meanResp = resp(:);
else
    meanResp = nanmean(resp, 2);
end
end

%% Compute Monocularity Max From NeuroRespUnitTable
% Loads NeuroRespUnitTable, computes Monocularity_max from cue 2 (Left)
% and cue 3 (Right), and saves the updated table to C:\LoData.
%
% Formula follows the 3D analysis logic:
%   LeftMax  = max(mean response across repeats for cue 2)
%   RightMax = max(mean response across repeats for cue 3)
%   Monocularity_max = (LeftMax - RightMax) / (LeftMax + RightMax)

input_path = 'C:\LoData\NeuroRespUnitTable.mat';
output_path = 'C:\LoData\NeuroRespUnitTable_Monocularity.mat';

disp('Loading NeuroRespUnitTable...')
S = load(input_path, 'NeuroRespUnitTable');
if ~isfield(S, 'NeuroRespUnitTable')
    error('Variable "NeuroRespUnitTable" not found in %s.', input_path);
end

NeuroRespUnitTable = S.NeuroRespUnitTable;
nRows = height(NeuroRespUnitTable);

NeuroRespUnitTable.LeftMax = nan(nRows, 1);
NeuroRespUnitTable.RightMax = nan(nRows, 1);
NeuroRespUnitTable.Monocularity_max = nan(nRows, 1);

disp(['Computing Monocularity_max for ', num2str(nRows), ' neurons...'])

for i = 1:nRows
    resp = NeuroRespUnitTable.NeuroResp{i};

    if isempty(resp) || ndims(resp) < 2 || size(resp, 1) < 3
        continue
    end

    leftResp = squeeze(resp(2, :, :));
    rightResp = squeeze(resp(3, :, :));

    leftMean = mean_across_repeats(leftResp);
    rightMean = mean_across_repeats(rightResp);

    leftMax = max(leftMean(:), [], 'omitnan');
    rightMax = max(rightMean(:), [], 'omitnan');

    NeuroRespUnitTable.LeftMax(i) = leftMax;
    NeuroRespUnitTable.RightMax(i) = rightMax;

    denom = leftMax + rightMax;
    if isfinite(denom) && denom ~= 0
        NeuroRespUnitTable.Monocularity_max(i) = (leftMax - rightMax) ./ denom;
    end

    if mod(i, 100) == 0 || i == nRows
        disp(['  Processed ', num2str(i), '/', num2str(nRows)])
    end
end

save(output_path, 'NeuroRespUnitTable', '-v7.3');
disp(['Saved updated table to ', output_path])

function meanResp = mean_across_repeats(resp)
if isvector(resp)
    meanResp = resp(:);
else
    meanResp = nanmean(resp, 2);
end
end

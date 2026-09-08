function cueOrder = gaussianChannelConditionCueOrder(signedOD)
%GAUSSIANCHANNELCONDITIONCUEORDER Map local conditions to physical cue rows.
% Output columns are Dominant, Combined, Stereo, NonDominant. Each input
% OD is evaluated independently; zero/nonfinite OD has no eye assignment.
arguments
    signedOD {mustBeNumeric, mustBeReal}
end
signedOD = double(signedOD(:));
cueOrder = nan(numel(signedOD), 4);
left = isfinite(signedOD) & signedOD > 0;
right = isfinite(signedOD) & signedOD < 0;
cueOrder(left, :) = repmat([2 1 4 3], nnz(left), 1);
cueOrder(right, :) = repmat([3 1 4 2], nnz(right), 1);
end

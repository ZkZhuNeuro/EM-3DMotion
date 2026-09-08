function metaOD = calculateGaussianMetaOD( ...
    rawMetaMean, observationCount, odDefinition)
%CALCULATEGAUSSIANMETAOD Calculate signed OD from raw meta tuning curves.
%
% Positive values indicate left-eye dominance and negative values indicate
% right-eye dominance. Correlation OD uses only coherence bins with finite
% Combined, MonoL, and MonoR responses and positive observation counts.

arguments
    rawMetaMean {mustBeNumeric, mustBeReal}
    observationCount {mustBeNumeric, mustBeReal}
    odDefinition (1, 1) string ...
        {mustBeMember(odDefinition, ...
        ["Max", "RMSE", "Correlation", "PartialCorrelation"])} = "Max"
end

if size(rawMetaMean, 1) < 3
    error('GaussianMetaInteractive:InsufficientCues', ...
        'rawMetaMean must contain Combined, MonoL, and MonoR cues.');
end
coherenceCount = size(rawMetaMean, 2);
if size(observationCount, 1) < 3 || ...
        size(observationCount, 2) ~= coherenceCount
    error('GaussianMetaInteractive:ObservationCountSize', ...
        'observationCount must match the cue and coherence dimensions.');
end

numSigmas = size(rawMetaMean, 3);
metaOD = nan(1, numSigmas);
for sigmaIndex = 1:numSigmas
    combined = reshape(double(rawMetaMean(1, :, sigmaIndex)), 1, []);
    left = reshape(double(rawMetaMean(2, :, sigmaIndex)), 1, []);
    right = reshape(double(rawMetaMean(3, :, sigmaIndex)), 1, []);
    if odDefinition == "Max"
        leftSupport = observationCount(2, :) > 0 & isfinite(left);
        rightSupport = observationCount(3, :) > 0 & isfinite(right);
        if ~any(leftSupport) || ~any(rightSupport)
            continue
        end
        leftMaximum = max(left(leftSupport));
        rightMaximum = max(right(rightSupport));
        denominator = leftMaximum + rightMaximum;
        if isfinite(denominator) && abs(denominator) > eps
            metaOD(sigmaIndex) = ...
                (leftMaximum - rightMaximum) ./ denominator;
        end
        continue
    end

    commonSupport = observationCount(1, :) > 0 & ...
        observationCount(2, :) > 0 & observationCount(3, :) > 0 & ...
        isfinite(combined) & isfinite(left) & isfinite(right);
    if nnz(commonSupport) < 2
        continue
    end
    combined = combined(commonSupport);
    left = left(commonSupport);
    right = right(commonSupport);
    if odDefinition == "RMSE"
        leftRMSE = sqrt(mean((combined - left) .^ 2));
        rightRMSE = sqrt(mean((combined - right) .^ 2));
        denominator = leftRMSE + rightRMSE;
        if denominator > 0 && isfinite(denominator)
            metaOD(sigmaIndex) = ...
                (rightRMSE - leftRMSE) ./ denominator;
        elseif denominator == 0
            metaOD(sigmaIndex) = 0;
        end
        continue
    end

    leftR = pearsonR(combined, left);
    rightR = pearsonR(combined, right);
    if odDefinition == "Correlation"
        if isfinite(leftR) && isfinite(rightR)
            leftR = max(-1 + eps, min(1 - eps, leftR));
            rightR = max(-1 + eps, min(1 - eps, rightR));
            metaOD(sigmaIndex) = atanh(leftR) - atanh(rightR);
        end
        continue
    end

    leftRightR = pearsonR(left, right);
    n = numel(combined);
    if n <= 3 || any(~isfinite([leftR, rightR, leftRightR]))
        continue
    end
    leftDenominator = sqrt((1 - rightR .^ 2) .* ...
        (1 - leftRightR .^ 2));
    rightDenominator = sqrt((1 - leftR .^ 2) .* ...
        (1 - leftRightR .^ 2));
    if leftDenominator <= 0 || rightDenominator <= 0
        continue
    end
    partialLeft = (leftR - rightR .* leftRightR) ./ leftDenominator;
    partialRight = (rightR - leftR .* leftRightR) ./ rightDenominator;
    partialLeft = max(-1 + eps, min(1 - eps, partialLeft));
    partialRight = max(-1 + eps, min(1 - eps, partialRight));
    zLeft = atanh(partialLeft);
    zRight = atanh(partialRight);
    if isfinite(zLeft) && isfinite(zRight)
        metaOD(sigmaIndex) = zLeft - zRight;
    end
end
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

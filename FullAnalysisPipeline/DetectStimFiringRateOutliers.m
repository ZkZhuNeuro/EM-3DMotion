function [outlierMask, audit] = DetectStimFiringRateOutliers( ...
    firingRateHz, trialSummary, options)
%DETECTSTIMFIRINGRATEOUTLIERS Flag trial FR outliers with median and MAD.
%
% Detection is performed independently for every electrical-stimulation
% status x cue x coherence x acquisition-channel x unit cell. For eligible
% cells, the modified Z-score is
%
%   0.674489750196082 * (x - median(x)) / median(abs(x - median(x))).
%
% Observations with absolute modified Z-score above Threshold are flagged.
% Cells with fewer than MinimumTrials finite observations or zero MAD are
% left unchanged. The input firing rates are never modified.

arguments
    firingRateHz {mustBeNumeric}
    trialSummary table
    options.Enabled (1, 1) logical = true
    options.Threshold (1, 1) double {mustBeFinite, mustBePositive} = 3.5
    options.MinimumTrials (1, 1) double ...
        {mustBeInteger, mustBePositive} = 8
end

requiredColumns = ["Included", "ElectricalStim", "Condition", ...
    "CoherenceIndex"];
missing = setdiff(requiredColumns, ...
    string(trialSummary.Properties.VariableNames));
if ~isempty(missing)
    error('StimTuningOutliers:MissingTrialColumns', ...
        'TrialSummary is missing required column(s): %s', ...
        join(missing, ', '));
end
if size(firingRateHz, 1) ~= height(trialSummary)
    error('StimTuningOutliers:TrialCountMismatch', ...
        'Firing-rate rows must match TrialSummary height.');
end

trialCount = size(firingRateHz, 1);
channelCount = size(firingRateHz, 2);
unitCount = size(firingRateHz, 3);
outlierMask = false(size(firingRateHz));

settings = struct( ...
    'Method', "modified Z-score using median and raw MAD", ...
    'Grouping', "ElectricalStim x Condition x Coherence x Channel x Unit", ...
    'Enabled', options.Enabled, ...
    'Threshold', options.Threshold, ...
    'MinimumTrials', options.MinimumTrials, ...
    'ConsistencyConstant', 0.674489750196082, ...
    'ZeroMADPolicy', "retain all observations", ...
    'InsufficientTrialPolicy', "retain all observations");

testedCellCount = 0;
insufficientTrialCellCount = 0;
zeroMADCellCount = 0;
eligibleObservationCount = 0;
maximumAbsoluteModifiedZ = NaN;

if options.Enabled
    stimValues = [false true];
    conditionValues = unique(trialSummary.Condition( ...
        trialSummary.Included & isfinite(trialSummary.Condition)))';
    coherenceValues = unique(trialSummary.CoherenceIndex( ...
        trialSummary.Included & isfinite(trialSummary.CoherenceIndex)))';

    for electricalStim = stimValues
        for condition = conditionValues
            for coherenceIndex = coherenceValues
                trialMask = trialSummary.Included & ...
                    trialSummary.ElectricalStim == electricalStim & ...
                    trialSummary.Condition == condition & ...
                    trialSummary.CoherenceIndex == coherenceIndex;
                trialIndices = find(trialMask);

                for channel = 1:channelCount
                    for unit = 1:unitCount
                        values = reshape( ...
                            firingRateHz(trialIndices, channel, unit), [], 1);
                        finite = isfinite(values);
                        finiteCount = nnz(finite);
                        if finiteCount < options.MinimumTrials
                            insufficientTrialCellCount = ...
                                insufficientTrialCellCount + 1;
                            continue
                        end

                        testedCellCount = testedCellCount + 1;
                        eligibleObservationCount = ...
                            eligibleObservationCount + finiteCount;
                        center = median(values(finite));
                        rawMAD = median(abs(values(finite) - center));
                        if ~isfinite(rawMAD) || rawMAD <= 0
                            zeroMADCellCount = zeroMADCellCount + 1;
                            continue
                        end

                        scores = nan(size(values));
                        scores(finite) = settings.ConsistencyConstant .* ...
                            (values(finite) - center) ./ rawMAD;
                        flagged = finite & abs(scores) > options.Threshold;
                        outlierMask(trialIndices(flagged), channel, unit) = true;
                        cellMaximum = max(abs(scores(finite)));
                        if ~isfinite(maximumAbsoluteModifiedZ) || ...
                                cellMaximum > maximumAbsoluteModifiedZ
                            maximumAbsoluteModifiedZ = cellMaximum;
                        end
                    end
                end
            end
        end
    end
end

trialOutlierCount = reshape(sum(outlierMask, [2 3]), trialCount, 1);
audit = struct();
audit.Settings = settings;
audit.OutlierObservationCount = nnz(outlierMask);
audit.TrialWithAnyOutlierCount = nnz(trialOutlierCount > 0);
audit.TestedCellCount = testedCellCount;
audit.InsufficientTrialCellCount = insufficientTrialCellCount;
audit.ZeroMADCellCount = zeroMADCellCount;
audit.EligibleObservationCount = eligibleObservationCount;
audit.TrialOutlierObservationCount = trialOutlierCount;
audit.MaximumAbsoluteModifiedZ = maximumAbsoluteModifiedZ;
end

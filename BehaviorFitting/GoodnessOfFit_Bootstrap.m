clear
load C:\EM\BehaviorFitting\unit_table_lapseHardCap_06.mat


%%
if ~ismember('Behave_QC_N', unit_table.Properties.VariableNames)
    unit_table.Behave_QC_N = cell(height(unit_table),1);
end

if ~ismember('Behave_QC_S', unit_table.Properties.VariableNames)
    unit_table.Behave_QC_S = cell(height(unit_table),1);
end

CI_N = NaN(size(unit_table, 1), 4, 2);
CI_S = NaN(size(unit_table, 1), 4, 2);

for i_rec = 1:size(unit_table, 1)
    if isempty(unit_table.Behave_QC_N{i_rec})
        unit_table.Behave_QC_N{i_rec} = cell(1,4);
    end
    if isempty(unit_table.Behave_QC_S{i_rec})
        unit_table.Behave_QC_S{i_rec} = cell(1,4);
    end

    for i_cue = 1
        CI_N(i_rec, i_cue, :) = unit_table.Behave_N{i_rec}{i_cue}.conf_Intervals(1, :, 1);
        CI_S(i_rec, i_cue, :) = unit_table.Behave_S{i_rec}{i_cue}.conf_Intervals(1, :, 1);

        if ~isempty(unit_table.Behave_N{i_rec}{i_cue})
            unit_table.Behave_QC_N{i_rec}{i_cue} = ...
                evaluate_psignifit_quality(unit_table.Behave_N{i_rec}{i_cue}, 100, 0.5, 0.005);
        end

        if ~isempty(unit_table.Behave_S{i_rec}{i_cue})
            unit_table.Behave_QC_S{i_rec}{i_cue} = ...
                evaluate_psignifit_quality(unit_table.Behave_S{i_rec}{i_cue}, 100, 0.5, 0.005);
        end
    end
end

%%
CI_N_width = squeeze(CI_N(:, :, 2) - CI_N(:, :, 1));
CI_S_width = squeeze(CI_S(:, :, 2) - CI_S(:, :, 1));

figure(); hold on
for i_cue = 1:4
histogram(CI_N_width(:, i_cue), 0:0.05:1.5);
end

figure(); hold on
for i_cue = 1:4
histogram(CI_S_width(:, i_cue), 0:0.05:1.5);
end

%%
function qc = evaluate_psignifit_quality(result, nBoot, relCIThresh, edgeTol)

        % Evaluate psychometric fit quality for one psignifit result
        %
        % Inputs
        %   result       : psignifit result struct
        %   nBoot        : number of bootstrap simulations, e.g. 200 or 500
        %   relCIThresh  : threshold CI width / stimulus range cutoff, e.g. 0.5
        %   edgeTol      : closeness-to-boundary tolerance, e.g. 0.005
        %
        % Output
        %   qc           : struct with GOF, CI width, boundary flags, overall pass/fail

        if nargin < 2 || isempty(nBoot),       nBoot = 200; end
        if nargin < 3 || isempty(relCIThresh), relCIThresh = 0.5; end
        if nargin < 4 || isempty(edgeTol),     edgeTol = 0.005; end

        qc = struct();

        % -----------------------------
        % 1) Observed deviance
        % -----------------------------
        qc.obsDeviance = result.deviance;

        % -----------------------------
        % 2) Parametric bootstrap GOF
        % -----------------------------
        [gof_p, devBoot] = bootstrap_gof_deviance(result, nBoot);
        qc.gof_p = gof_p;
        qc.devBoot = devBoot;
        qc.devBoot95 = prctile(devBoot, 95);
        qc.fail_gof = qc.obsDeviance > qc.devBoot95;


end

function [gof_p, devBoot] = bootstrap_gof_deviance(result, nBoot)

% Parametric bootstrap goodness-of-fit based on deviance.
%
% p-value is the fraction of bootstrap deviances >= observed deviance.
% Small p means observed data fit worse than expected under the fitted model.

    if nargin < 2 || isempty(nBoot)
        nBoot = 200;
    end

    obsDev = result.deviance;
    data = result.data;
    opt = result.options;

    % Hard-cap value inferred from borders
    if isfield(opt, 'borders') && size(opt.borders,1) >= 4
        lapseCap = max(opt.borders(3,2), opt.borders(4,2));
    else
        lapseCap = 0.1;
    end

    devBoot = NaN(nBoot,1);

    for b = 1:nBoot
        simData = simulate_psychometric_dataset(result);

        try
            simResult = psignifit_controlLapse(simData, lapseCap, opt);
            devBoot(b) = simResult.deviance;
        catch
            devBoot(b) = NaN;
        end
    end

    devBoot = devBoot(~isnan(devBoot));

    if isempty(devBoot)
        gof_p = NaN;
    else
        gof_p = mean(devBoot >= obsDev);
    end
end

function simData = simulate_psychometric_dataset(result)

% Simulate a psychometric count dataset with the same x and n as the original

    data = result.data;
    x = data(:,1);
    n = data(:,3);

    p = result.Fit(4) + ...
        (1 - result.Fit(3) - result.Fit(4)) .* ...
        result.options.sigmoidHandle(x, result.Fit(1), result.Fit(2));

    p = min(max(p, 1e-12), 1 - 1e-12);

    kSim = zeros(size(n));
    for i = 1:numel(n)
        if n(i) > 0
            kSim(i) = sum(rand(n(i),1) < p(i));
        else
            kSim(i) = 0;
        end
    end

    simData = [x, kSim, n];
end


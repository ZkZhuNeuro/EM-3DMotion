clear
load C:\EM\BehaviorFitting\unit_table_lapseHardCap_06.mat
inclusionData = load("C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\BehaviorFitting\inclusion_index.mat");

inclusionFields = fieldnames(inclusionData);
inclusion_idx = [];
for i_field = 1:numel(inclusionFields)
    candidate = inclusionData.(inclusionFields{i_field});
    if islogical(candidate) && isvector(candidate) && numel(candidate) == height(unit_table)
        inclusion_idx = candidate(:);
        break
    end
end

assert(~isempty(inclusion_idx), ...
    'Could not find a logical inclusion index matching height(unit_table).');

origRecIdx = find(inclusion_idx);
unit_table = unit_table(inclusion_idx, :);
clear inclusionData inclusionFields candidate i_field

%%
if ~ismember('Behave_QC_N', unit_table.Properties.VariableNames)
    unit_table.Behave_QC_N = cell(height(unit_table),1);
end

if ~ismember('Behave_QC_S', unit_table.Properties.VariableNames)
    unit_table.Behave_QC_S = cell(height(unit_table),1);
end

CI_N = NaN(size(unit_table, 1), 4, 2);
CI_S = NaN(size(unit_table, 1), 4, 2);
pGOF_N = NaN(size(unit_table, 1), 4);
pGOF_S = NaN(size(unit_table, 1), 4);

for i_rec = 1:size(unit_table, 1)
    if isempty(unit_table.Behave_QC_N{i_rec})
        unit_table.Behave_QC_N{i_rec} = cell(1,4);
    end
    if isempty(unit_table.Behave_QC_S{i_rec})
        unit_table.Behave_QC_S{i_rec} = cell(1,4);
    end

    for i_cue = 1:4
        disp(['Cue: ', num2str(i_cue), '/4, Rec: ', num2str(i_rec), '/', num2str(size(unit_table, 1))])
        CI_N(i_rec, i_cue, :) = unit_table.Behave_N{i_rec}{i_cue}.conf_Intervals(1, :, 1);
        CI_S(i_rec, i_cue, :) = unit_table.Behave_S{i_rec}{i_cue}.conf_Intervals(1, :, 1);

        if ~isempty(unit_table.Behave_N{i_rec}{i_cue})
            if isempty(unit_table.Behave_QC_N{i_rec}{i_cue})
                unit_table.Behave_QC_N{i_rec}{i_cue} = ...
                    evaluate_psignifit_quality(unit_table.Behave_N{i_rec}{i_cue}, 100, 0.5, 0.005);
            end
            pGOF_N(i_rec, i_cue) = extract_first_p_gof(unit_table.Behave_QC_N{i_rec}{i_cue});
        end

        if ~isempty(unit_table.Behave_S{i_rec}{i_cue})
            if isempty(unit_table.Behave_QC_S{i_rec}{i_cue})
                unit_table.Behave_QC_S{i_rec}{i_cue} = ...
                    evaluate_psignifit_quality(unit_table.Behave_S{i_rec}{i_cue}, 100, 0.5, 0.005);
            end
            pGOF_S(i_rec, i_cue) = extract_first_p_gof(unit_table.Behave_QC_S{i_rec}{i_cue});
        end
    end
end

%%
cueNames = {'Comb', 'Left', 'Right', 'Stereo'};
pThresh = 0.05;

badFits_N = collect_bad_gof(unit_table, unit_table.Behave_QC_N, cueNames, pThresh, origRecIdx);
badFits_S = collect_bad_gof(unit_table, unit_table.Behave_QC_S, cueNames, pThresh, origRecIdx);

disp('N fits with first p_gof < 0.05:')
disp(badFits_N)

disp('S fits with first p_gof < 0.05:')
disp(badFits_S)

%%
plot_p_gof_matrix(pGOF_N, cueNames, pThresh, 'N');
plot_p_gof_matrix(pGOF_S, cueNames, pThresh, 'S');

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
    lastBootstrapError = [];
    nSuccess = 0;

    for b = 1:nBoot
        simData = simulate_psychometric_dataset(result);

        try
            simResult = psignifit_controlLapse(simData, lapseCap, opt);
            devBoot(b) = simResult.deviance;
            nSuccess = nSuccess + 1;
        catch ME
            lastBootstrapError = ME;
            devBoot(b) = NaN;
        end
    end

    devBoot = devBoot(~isnan(devBoot));

    if isempty(devBoot)
        if isempty(lastBootstrapError)
            error('bootstrap_gof_deviance:NoSuccessfulBootstrapFits', ...
                'All bootstrap refits failed: psignifit_controlLapse never completed successfully.');
        else
            error('bootstrap_gof_deviance:NoSuccessfulBootstrapFits', ...
                ['All bootstrap refits failed: psignifit_controlLapse never completed successfully. ' ...
                 'Last error: %s'], lastBootstrapError.message);
        end
    else
        if nSuccess < nBoot
            warning('bootstrap_gof_deviance:PartialBootstrapFailure', ...
                '%d of %d bootstrap refits failed and were excluded from p_g_o_f.', ...
                nBoot - nSuccess, nBoot);
        end
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

function badFits = collect_bad_gof(unit_table, qcCell, cueNames, pThresh, origRecIdx)

    rows = [];
    recLabels = {};
    cueIdx = [];
    cueLabels = {};
    pVals = [];

    for i_rec = 1:height(unit_table)
        if isempty(qcCell{i_rec})
            continue
        end

        for i_cue = 1:numel(qcCell{i_rec})
            qc = qcCell{i_rec}{i_cue};
            p_gof = extract_first_p_gof(qc);

            if ~isnan(p_gof) && p_gof < pThresh
                if nargin >= 5 && ~isempty(origRecIdx)
                    rows(end+1, 1) = origRecIdx(i_rec); %#ok<AGROW>
                else
                    rows(end+1, 1) = i_rec; %#ok<AGROW>
                end
                recLabels{end+1, 1} = get_rec_label(unit_table, i_rec); %#ok<AGROW>
                cueIdx(end+1, 1) = i_cue; %#ok<AGROW>
                cueLabels{end+1, 1} = cueNames{min(i_cue, numel(cueNames))}; %#ok<AGROW>
                pVals(end+1, 1) = p_gof; %#ok<AGROW>
            end
        end
    end

    badFits = table(rows, recLabels, cueIdx, cueLabels, pVals, ...
        'VariableNames', {'row', 'rec', 'cueIdx', 'cue', 'p_gof_first'});
end

function p_gof = extract_first_p_gof(qc)

    p_gof = NaN;

    if isempty(qc) || ~isstruct(qc)
        return
    end

    if isfield(qc, 'p_gof')
        p_gof = qc.p_gof;
    elseif isfield(qc, 'gof_p')
        p_gof = qc.gof_p;
    end

    if ~isempty(p_gof)
        p_gof = p_gof(1);
    else
        p_gof = NaN;
    end
end

function recLabel = get_rec_label(unit_table, i_rec)

    recCandidates = {'rec', 'Rec', 'recording', 'Recording', ...
        'session', 'Session', 'filename', 'Filename', ...
        'file', 'File', 'unit', 'Unit'};

    recLabel = sprintf('row_%d', i_rec);

    for i_name = 1:numel(recCandidates)
        varName = recCandidates{i_name};
        if ismember(varName, unit_table.Properties.VariableNames)
            recLabel = stringify_table_value(unit_table.(varName), i_rec);
            return
        end
    end
end

function out = stringify_table_value(columnData, i_rec)

    if iscell(columnData)
        value = columnData{i_rec};
    else
        value = columnData(i_rec, :);
    end

    if isstring(value)
        out = char(value);
    elseif ischar(value)
        out = value;
    elseif isnumeric(value) || islogical(value)
        out = mat2str(value);
    else
        out = char(string(value));
    end
end

function plot_p_gof_matrix(pGOF, cueNames, pThresh, condLabel)

    figure('Color', 'w');
    imagesc(pGOF, [0, 1]);
    ax = gca;
    ax.YDir = 'normal';
    ax.XTick = 1:numel(cueNames);
    ax.XTickLabel = cueNames;
    xlabel('Cue');
    ylabel('Recording index');
    title(sprintf('%s first p_g_o_f', condLabel));
    colormap(parula);
    cb = colorbar;
    cb.Label.String = 'first p_g_o_f';

    hold on
    [badRec, badCue] = find(pGOF < pThresh);
    plot(badCue, badRec, 'ko', 'MarkerSize', 4, 'LineWidth', 0.75);
    hold off
end


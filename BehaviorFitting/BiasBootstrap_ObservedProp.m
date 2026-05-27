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
includedRecIdx = find(inclusion_idx);
clear inclusionData inclusionFields candidate i_field

nBoot = 1000;
pThresh = 0.05;
cueNames = {'Comb', 'Left', 'Right', 'Stereo'};

fieldBootN = 'Behave_bootBiasObsProp_N';
fieldBootS = 'Behave_bootBiasObsProp_S';
fieldPN = 'Behave_bootBiasObsProp_p_N';
fieldPS = 'Behave_bootBiasObsProp_p_S';
fieldValidN = 'Behave_bootBiasObsProp_validN_N';
fieldValidS = 'Behave_bootBiasObsProp_validN_S';

if ~ismember(fieldBootN, unit_table.Properties.VariableNames)
    unit_table.(fieldBootN) = cell(height(unit_table), 1);
end
if ~ismember(fieldBootS, unit_table.Properties.VariableNames)
    unit_table.(fieldBootS) = cell(height(unit_table), 1);
end
if ~ismember(fieldPN, unit_table.Properties.VariableNames)
    unit_table.(fieldPN) = cell(height(unit_table), 1);
end
if ~ismember(fieldPS, unit_table.Properties.VariableNames)
    unit_table.(fieldPS) = cell(height(unit_table), 1);
end
if ~ismember(fieldValidN, unit_table.Properties.VariableNames)
    unit_table.(fieldValidN) = cell(height(unit_table), 1);
end
if ~ismember(fieldValidS, unit_table.Properties.VariableNames)
    unit_table.(fieldValidS) = cell(height(unit_table), 1);
end

trueBias_N = NaN(height(unit_table), 4);
trueBias_S = NaN(height(unit_table), 4);
pBias_N = NaN(height(unit_table), 4);
pBias_S = NaN(height(unit_table), 4);
validBootN_N = NaN(height(unit_table), 4);
validBootN_S = NaN(height(unit_table), 4);

for i_idx = 1:numel(includedRecIdx)
    i_rec = includedRecIdx(i_idx);
    disp(['Rec: ', num2str(i_rec), '/', num2str(height(unit_table)), ...
        ' (included ', num2str(i_idx), '/', num2str(numel(includedRecIdx)), ')'])

    if isempty(unit_table.(fieldBootN){i_rec})
        unit_table.(fieldBootN){i_rec} = cell(1, 4);
    end
    if isempty(unit_table.(fieldBootS){i_rec})
        unit_table.(fieldBootS){i_rec} = cell(1, 4);
    end
    if isempty(unit_table.(fieldPN){i_rec})
        unit_table.(fieldPN){i_rec} = NaN(1, 4);
    end
    if isempty(unit_table.(fieldPS){i_rec})
        unit_table.(fieldPS){i_rec} = NaN(1, 4);
    end
    if isempty(unit_table.(fieldValidN){i_rec})
        unit_table.(fieldValidN){i_rec} = NaN(1, 4);
    end
    if isempty(unit_table.(fieldValidS){i_rec})
        unit_table.(fieldValidS){i_rec} = NaN(1, 4);
    end

    for i_cue = 1:4
        disp(['  Cue: ', num2str(i_cue), '/4'])

        result_N = unit_table.Behave_N{i_rec}{i_cue};
        result_S = unit_table.Behave_S{i_rec}{i_cue};

        if isempty(result_N) || isempty(result_S)
            continue
        end

        trueBias_N(i_rec, i_cue) = result_N.Fit(1);
        trueBias_S(i_rec, i_cue) = result_S.Fit(1);

        bootBias_N = bootstrap_bias_from_observed_proportion(result_N, nBoot);
        bootBias_S = bootstrap_bias_from_observed_proportion(result_S, nBoot);

        unit_table.(fieldBootN){i_rec}{i_cue} = bootBias_N;
        unit_table.(fieldBootS){i_rec}{i_cue} = bootBias_S;

        validBootN_N(i_rec, i_cue) = sum(~isnan(bootBias_N));
        validBootN_S(i_rec, i_cue) = sum(~isnan(bootBias_S));
        pBias_N(i_rec, i_cue) = empirical_p_value_from_bootstrap(trueBias_N(i_rec, i_cue), bootBias_N);
        pBias_S(i_rec, i_cue) = empirical_p_value_from_bootstrap(trueBias_S(i_rec, i_cue), bootBias_S);

        unit_table.(fieldPN){i_rec}(i_cue) = pBias_N(i_rec, i_cue);
        unit_table.(fieldPS){i_rec}(i_cue) = pBias_S(i_rec, i_cue);
        unit_table.(fieldValidN){i_rec}(i_cue) = validBootN_N(i_rec, i_cue);
        unit_table.(fieldValidS){i_rec}(i_cue) = validBootN_S(i_rec, i_cue);
    end
end

sigBias_N = collect_sig_bias(unit_table, includedRecIdx, trueBias_N, pBias_N, cueNames, pThresh);
sigBias_S = collect_sig_bias(unit_table, includedRecIdx, trueBias_S, pBias_S, cueNames, pThresh);

disp('N true biases with empirical p < 0.05:')
disp(sigBias_N)

disp('S true biases with empirical p < 0.05:')
disp(sigBias_S)

figure('Color', 'w');
imagesc(pBias_N(includedRecIdx, :), [0, 1]);
ax = gca;
ax.YDir = 'normal';
ax.XTick = 1:numel(cueNames);
ax.XTickLabel = cueNames;
xlabel('Cue');
ylabel('Included recording index');
title('N bias bootstrap p-values');
colorbar

figure('Color', 'w');
imagesc(pBias_S(includedRecIdx, :), [0, 1]);
ax = gca;
ax.YDir = 'normal';
ax.XTick = 1:numel(cueNames);
ax.XTickLabel = cueNames;
xlabel('Cue');
ylabel('Included recording index');
title('S bias bootstrap p-values');
colorbar

function bootBias = bootstrap_bias_from_observed_proportion(result, nBoot)

    if nargin < 2 || isempty(nBoot)
        nBoot = 1000;
    end

    data = result.data;
    x = data(:, 1);
    k = data(:, 2);
    n = data(:, 3);
    validRows = n > 0 & ~isnan(k) & ~isnan(n);

    pObs = zeros(size(k));
    pObs(validRows) = k(validRows) ./ n(validRows);
    pObs = min(max(pObs, 0), 1);

    lapseCap = infer_lapse_cap(result.options);
    bootBias = NaN(nBoot, 1);
    lastBootstrapError = [];
    nSuccess = 0;

    for i_boot = 1:nBoot
        simData = [x, zeros(size(k)), n];
        kSim = zeros(size(k));

        for i_row = 1:numel(n)
            if validRows(i_row)
                kSim(i_row) = sum(rand(n(i_row), 1) < pObs(i_row));
            end
        end

        simData(:, 2) = kSim;

        try
            simResult = psignifit_controlLapse(simData, lapseCap, result.options);
            bootBias(i_boot) = simResult.Fit(1);
            nSuccess = nSuccess + 1;
        catch ME
            lastBootstrapError = ME;
            bootBias(i_boot) = NaN;
        end
    end

    if nSuccess == 0
        if isempty(lastBootstrapError)
            error('bootstrap_bias_from_observed_proportion:NoSuccessfulBootstrapFits', ...
                'All bootstrap refits failed: psignifit_controlLapse never completed successfully.');
        else
            error('bootstrap_bias_from_observed_proportion:NoSuccessfulBootstrapFits', ...
                ['All bootstrap refits failed: psignifit_controlLapse never completed successfully. ' ...
                 'Last error: %s'], lastBootstrapError.message);
        end
    end

    if nSuccess < nBoot
        warning('bootstrap_bias_from_observed_proportion:PartialBootstrapFailure', ...
            '%d of %d bootstrap refits failed and were excluded from the bias distribution.', ...
            nBoot - nSuccess, nBoot);
    end
end

function lapseCap = infer_lapse_cap(opt)

    if isfield(opt, 'borders') && size(opt.borders, 1) >= 4
        lapseCap = max(opt.borders(3, 2), opt.borders(4, 2));
    else
        lapseCap = 0.1;
    end
end

function p = empirical_p_value_from_bootstrap(obsVal, bootVals)

    bootVals = bootVals(~isnan(bootVals));
    if isempty(bootVals) || isnan(obsVal)
        p = NaN;
        return
    end

    centerVal = median(bootVals);
    obsDist = abs(obsVal - centerVal);
    bootDist = abs(bootVals - centerVal);
    p = mean(bootDist >= obsDist);
end

function sigBias = collect_sig_bias(unit_table, includedRecIdx, trueBias, pVals, cueNames, pThresh)

    rows = [];
    recLabels = {};
    cueIdx = [];
    cueLabels = {};
    biasVals = [];
    pValsSig = [];

    for i_idx = 1:numel(includedRecIdx)
        i_rec = includedRecIdx(i_idx);

        for i_cue = 1:size(trueBias, 2)
            if ~isnan(pVals(i_rec, i_cue)) && pVals(i_rec, i_cue) < pThresh
                rows(end+1, 1) = i_rec; %#ok<AGROW>
                recLabels{end+1, 1} = get_rec_label(unit_table, i_rec); %#ok<AGROW>
                cueIdx(end+1, 1) = i_cue; %#ok<AGROW>
                cueLabels{end+1, 1} = cueNames{min(i_cue, numel(cueNames))}; %#ok<AGROW>
                biasVals(end+1, 1) = trueBias(i_rec, i_cue); %#ok<AGROW>
                pValsSig(end+1, 1) = pVals(i_rec, i_cue); %#ok<AGROW>
            end
        end
    end

    sigBias = table(rows, recLabels, cueIdx, cueLabels, biasVals, pValsSig, ...
        'VariableNames', {'row', 'rec', 'cueIdx', 'cue', 'true_bias', 'p_bias'});
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

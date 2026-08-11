clear;

workspaceDir = fileparts(mfilename('fullpath'));
gofFile = 'C:\EM\BehaviorFitting\unit_table_gof.mat';
resultFile = fullfile(fileparts(gofFile), 'DeltaBiasBootstrap_zeroTest.mat');
jimFile = fullfile(workspaceDir, 'BehaviorData_Jim.mat');
clayFile = fullfile(workspaceDir, 'BehaviorData_Clay.mat');

nBoot = 1000;
alpha = 0.05;
minimumValidFraction = 0.90;
baseSeed = 20260806;
checkpointEvery = 10;

gofData = load(gofFile, 'unit_table_gof');
unit_table_gof = gofData.unit_table_gof;
jimData = load(jimFile, 'BehaviorData_nonStim_pFit_all', 'BehaviorData_Stim_pFit_all');
clayData = load(clayFile, 'BehaviorData_nonStim_pFit_all', 'BehaviorData_Stim_pFit_all');

dataN = [jimData.BehaviorData_nonStim_pFit_all; ...
    clayData.BehaviorData_nonStim_pFit_all];
dataS = [jimData.BehaviorData_Stim_pFit_all; ...
    clayData.BehaviorData_Stim_pFit_all];

nRec = height(unit_table_gof);
includedMask = (strcmp(unit_table_gof.ROI, 'MT') | strcmp(unit_table_gof.ROI, 'FST')) & ...
    (strcmp(unit_table_gof.ND, '2D') | strcmp(unit_table_gof.ND, '3D'));
includedRec = find(includedMask);

bootstrapResult = initialize_or_load_result(resultFile, nRec, nBoot, alpha, ...
    minimumValidFraction, baseSeed, includedMask, unit_table_gof.OriginalRecIdx);

fprintf('Testing delta bias against zero for %d included sessions x 4 cues.\n', ...
    numel(includedRec));
fprintf('Bootstrap replicates per session/cue: %d\n', nBoot);

nCompletedThisRun = 0;
runTimer = tic;

for i_included = 1:numel(includedRec)
    i_rec = includedRec(i_included);
    sourceRec = unit_table_gof.OriginalRecIdx(i_rec);

    for i_cue = 1:4
        if bootstrapResult.completed(i_rec, i_cue)
            continue
        end

        resultN = dataN{sourceRec}(i_cue);
        resultS = dataS{sourceRec}(i_cue);
        observedDelta = fit_delta_probit(resultN.data, resultS.data);

        % A separate seed per session/cue makes checkpointed reruns reproducible.
        rng(baseSeed + 10 * sourceRec + i_cue, 'twister');
        bootDelta = bootstrap_delta_probit(resultN.data, resultS.data, nBoot);
        validBoot = bootDelta(isfinite(bootDelta));
        nValid = numel(validBoot);

        bootstrapResult.observedDeltaProbit(i_rec, i_cue) = observedDelta;
        bootstrapResult.bootDelta{i_rec, i_cue} = bootDelta;
        bootstrapResult.nValid(i_rec, i_cue) = nValid;

        if nValid >= ceil(minimumValidFraction * nBoot)
            ci = prctile(validBoot, [100 * alpha / 2, 100 * (1 - alpha / 2)]);
            pLower = (sum(validBoot <= 0) + 1) / (nValid + 1);
            pUpper = (sum(validBoot >= 0) + 1) / (nValid + 1);
            pValue = min(1, 2 * min(pLower, pUpper));

            bootstrapResult.ci(i_rec, i_cue, :) = ci;
            bootstrapResult.pValue(i_rec, i_cue) = pValue;
            bootstrapResult.significant(i_rec, i_cue) = ci(1) > 0 || ci(2) < 0;
        end

        bootstrapResult.completed(i_rec, i_cue) = true;
        nCompletedThisRun = nCompletedThisRun + 1;

        fprintf('[%3d/%3d] %s %s | cue %d | p = %.4g | CI = [% .4f, % .4f] | valid = %d\n', ...
            i_included, numel(includedRec), ...
            string(unit_table_gof.ROI{i_rec}), string(unit_table_gof.ND{i_rec}), i_cue, ...
            bootstrapResult.pValue(i_rec, i_cue), ...
            bootstrapResult.ci(i_rec, i_cue, 1), ...
            bootstrapResult.ci(i_rec, i_cue, 2), nValid);

        if mod(nCompletedThisRun, checkpointEvery) == 0
            bootstrapResult.lastUpdated = datetime('now');
            save(resultFile, 'bootstrapResult', '-v7.3');
        end
    end
end

bootstrapResult.lastUpdated = datetime('now');
bootstrapResult.elapsedSecondsLastRun = toc(runTimer);
save(resultFile, 'bootstrapResult', '-v7.3');

fprintf('Completed %d new session/cue tests in %.1f minutes.\n', ...
    nCompletedThisRun, bootstrapResult.elapsedSecondsLastRun / 60);
fprintf('Saved bootstrap results to:\n%s\n', resultFile);

function bootstrapResult = initialize_or_load_result(resultFile, nRec, nBoot, alpha, ...
        minimumValidFraction, baseSeed, includedMask, originalRecIdx)
    if exist(resultFile, 'file')
        saved = load(resultFile, 'bootstrapResult');
        candidate = saved.bootstrapResult;
        settingsMatch = candidate.nBoot == nBoot && candidate.alpha == alpha && ...
            candidate.minimumValidFraction == minimumValidFraction && ...
            candidate.baseSeed == baseSeed && numel(candidate.includedMask) == nRec && ...
            isequal(candidate.includedMask(:), includedMask(:)) && ...
            isequal(candidate.originalRecIdx(:), originalRecIdx(:));
        if settingsMatch
            bootstrapResult = candidate;
            fprintf('Resuming compatible bootstrap checkpoint: %s\n', resultFile);
            return
        end
        error('Existing bootstrap result has incompatible settings: %s', resultFile);
    end

    bootstrapResult = struct();
    bootstrapResult.method = ['Within-coherence binomial bootstrap; each condition is ' ...
        'refit by binomial probit regression; delta PSE = PSE(non-stim) - PSE(stim).'];
    bootstrapResult.nBoot = nBoot;
    bootstrapResult.alpha = alpha;
    bootstrapResult.minimumValidFraction = minimumValidFraction;
    bootstrapResult.baseSeed = baseSeed;
    bootstrapResult.includedMask = includedMask;
    bootstrapResult.originalRecIdx = originalRecIdx;
    bootstrapResult.observedDeltaProbit = nan(nRec, 4);
    bootstrapResult.bootDelta = cell(nRec, 4);
    bootstrapResult.ci = nan(nRec, 4, 2);
    bootstrapResult.pValue = nan(nRec, 4);
    bootstrapResult.nValid = zeros(nRec, 4);
    bootstrapResult.significant = false(nRec, 4);
    bootstrapResult.completed = false(nRec, 4);
    bootstrapResult.lastUpdated = NaT;
end

function bootDelta = bootstrap_delta_probit(dataN, dataS, nBoot)
    [xN, ~, nN, pN] = prepare_data(dataN);
    [xS, ~, nS, pS] = prepare_data(dataS);
    bootDelta = nan(nBoot, 1);

    priorWarningState = warning;
    warning('off', 'all');
    cleanupObj = onCleanup(@() warning(priorWarningState));

    for i_boot = 1:nBoot
        kBootN = binornd(nN, pN);
        kBootS = binornd(nS, pS);
        try
            betaN = glmfit(xN, [kBootN, nN], 'binomial', 'link', 'probit');
            betaS = glmfit(xS, [kBootS, nS], 'binomial', 'link', 'probit');
            pseN = -betaN(1) / betaN(2);
            pseS = -betaS(1) / betaS(2);
            if isfinite(pseN) && isfinite(pseS)
                bootDelta(i_boot) = pseN - pseS;
            end
        catch
            bootDelta(i_boot) = NaN;
        end
    end
end

function delta = fit_delta_probit(dataN, dataS)
    [xN, kN, nN] = prepare_data(dataN);
    [xS, kS, nS] = prepare_data(dataS);
    betaN = glmfit(xN, [kN, nN], 'binomial', 'link', 'probit');
    betaS = glmfit(xS, [kS, nS], 'binomial', 'link', 'probit');
    delta = -betaN(1) / betaN(2) + betaS(1) / betaS(2);
end

function [x, k, n, p] = prepare_data(data)
    valid = data(:, 3) > 0 & all(isfinite(data), 2);
    x = data(valid, 1);
    k = data(valid, 2);
    n = data(valid, 3);
    p = min(max(k ./ n, 0), 1);
end

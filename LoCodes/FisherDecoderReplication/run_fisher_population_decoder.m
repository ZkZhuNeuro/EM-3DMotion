function result = run_fisher_population_decoder(firingRates,trialNum,cfg)
%RUN_FISHER_POPULATION_DECODER Combined-cue-trained binary Fisher decoder.

nNeurons = size(firingRates,1);
nConditions = numel(cfg.testConditions);
nonzero = [cfg.awayCoherenceIndices cfg.towardCoherenceIndices];
nNonzero = numel(nonzero);
timeMask = cfg.binStartTimesMs >= cfg.responseWindowMs(1) & ...
    cfg.binStartTimesMs <= cfg.responseWindowMs(2);
assert(numel(timeMask)==size(firingRates,4), ...
    ['cfg.binStartTimesMs has %d entries but firingRates has %d time bins. ' ...
     'Update cfg.binStartTimesMs to match the source data.'], ...
     numel(timeMask),size(firingRates,4));

proportionCorrect = NaN(cfg.nBootstraps,nConditions,nNonzero);
weights = NaN(nNeurons,cfg.nFolds,cfg.nBootstraps);
thresholds = NaN(cfg.nFolds,cfg.nBootstraps);

for boot = 1:cfg.nBootstraps
    pseudo = sample_pseudotrials(firingRates,trialNum,cfg.nPseudoTrials);
    foldId = balanced_random_folds(cfg.nPseudoTrials,cfg.nFolds);
    foldCorrect = NaN(cfg.nFolds,nConditions,nNonzero);

    for fold = 1:cfg.nFolds
        isTest = foldId == fold;
        isTrain = ~isTest;

        % Average the response over the post-stimulus interval.
        train = mean(pseudo(:,cfg.combinedCondition,:,timeMask,isTrain),4,'omitnan');
        train = reshape(train,nNeurons,size(firingRates,3),sum(isTrain));
        away = reshape(train(:,cfg.awayCoherenceIndices,:),nNeurons,[]);
        toward = reshape(train(:,cfg.towardCoherenceIndices,:),nNeurons,[]);

        sigma = 0.5*(cov(away') + cov(toward'));
        sigmaInv = pinv(sigma);
        muAway = mean(away,2);
        muToward = mean(toward,2);
        w = sigmaInv*(muToward-muAway);
        k = 0.5*(muToward'*sigmaInv*muToward - muAway'*sigmaInv*muAway);
        weights(:,fold,boot) = w;
        thresholds(fold,boot) = k;

        test = mean(pseudo(:,cfg.testConditions,:,timeMask,isTest),4,'omitnan');
        test = reshape(test,nNeurons,nConditions,size(firingRates,3),sum(isTest));
        scores = reshape(w'*reshape(test,nNeurons,[]), ...
            nConditions,size(firingRates,3),sum(isTest));
        predictedToward = scores > k;

        truth = false(1,size(firingRates,3),1);
        truth(1,cfg.towardCoherenceIndices,1) = true;
        truth = repmat(truth,nConditions,1,sum(isTest));
        correct = predictedToward == truth;
        foldCorrect(fold,:,:) = mean(correct(:,nonzero,:),3);
    end
    proportionCorrect(boot,:,:) = mean(foldCorrect,1,'omitnan');

    if cfg.verbose && (boot==1 || mod(boot,max(1,round(cfg.nBootstraps/20)))==0)
        fprintf('  bootstrap %d/%d\n',boot,cfg.nBootstraps);
    end
end

% Pair away/toward coherences with equal absolute magnitude. The signed
% nonzero ordering is [-1 ... -small, +small ... +1]. Store paired results
% from the smallest absolute coherence to 1 so the columns align directly
% with an ascending coherence axis.
pairScores = NaN(cfg.nBootstraps,nConditions,6);
for plotIndex = 1:6
    signedIndex = 7-plotIndex;
    pairScores(:,:,plotIndex) = mean( ...
        proportionCorrect(:,:,[signedIndex 13-signedIndex]),3,'omitnan');
end

result.proportionCorrect = proportionCorrect;
result.pairedBootstrapScores = pairScores;
result.meanByMagnitude = squeeze(mean(pairScores,1,'omitnan'));
result.ci95ByMagnitude = permute(prctile(pairScores,[2.5 97.5],1),[2 3 1]);
result.magnitudeOrder = 'ascending';
result.weights = weights;
result.thresholds = thresholds;
end

function pseudo = sample_pseudotrials(firingRates,trialNum,nPseudoTrials)
% Independently sample each neuron's trial distribution with replacement.
[nNeurons,nConditions,nCoherences,nTimes,nStoredTrials] = size(firingRates);
pseudo = NaN(nNeurons,nConditions,nCoherences,nTimes,nPseudoTrials, ...
    'like',firingRates);

for neuron = 1:nNeurons
    for condition = 1:nConditions
        for coherence = 1:nCoherences
            nAvailable = min(double(trialNum(neuron,condition,coherence)),nStoredTrials);
            valid = find(squeeze(any(~isnan( ...
                firingRates(neuron,condition,coherence,:,:)),4)));
            valid = valid(valid <= nAvailable);
            if isempty(valid)
                continue;
            end
            selected = valid(randi(numel(valid),1,nPseudoTrials));
            pseudo(neuron,condition,coherence,:,:) = ...
                firingRates(neuron,condition,coherence,:,selected);
        end
    end
end
end

function foldId = balanced_random_folds(nTrials,nFolds)
foldId = repmat(1:nFolds,1,nTrials/nFolds);
foldId = foldId(randperm(nTrials));
end

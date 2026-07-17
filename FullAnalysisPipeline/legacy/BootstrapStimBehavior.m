function [CI_stim, CI_no_stim] = BootstrapStimBehavior(NonStimTrials,StimTrials,bootstraps)
%% Behavior Bootstrapping
%%%%%%%%%%%%%%%%%%%%%%%%%
% Parameter options
CoherenceArray = [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22]./22;
options.sigmoidName = 'norm'; % norm cdf fit
%options.estimateType = 'MAP';
options.fixedPars = NaN(5,1);
%options.fixedPars(3:4) = 0.00001; % Fix the upper and lower asymptotes\
options.expType = 'equalAsymptote'; %'YesNo';%'equalAsymptote';

% Provide prior on width
lowerBound = 2;
priorWidth = @(x) (x>0&x<=lowerBound).*(1-cos(pi.*x./lowerBound)) + (x>lowerBound&x<=100).*2; % raised cosine
options.priors{2} = priorWidth;
options.borders = nan(5,2);
options.borders(3,:)=[0,.05]; % upper range of lapse rate
options.borders(4,:)=[0,.05]; % lower range of lapse rate
%%%%%%%%%%%%%%%%%%%%%%%%%
f = waitbar(0, 'Bootstrapping');
%% Bootstrap psignifit
for b = 1:bootstraps
    waitbar(b/bootstraps,f,['Bootstrap: ',num2str(b),'/',num2str(bootstraps)])
    for cond = 1:4
        for coh = 1:length(CoherenceArray)
            % 1) Non-stimulation trials
            temp_data = [ones(NonStimTrials.Toward(cond,coh),1); zeros(NonStimTrials.NumTrials(cond,coh) - NonStimTrials.Toward(cond,coh),1)];
            % Randomly sample the data
            boot_toward_no_stim(coh) = sum(temp_data(randsample(length(temp_data),length(temp_data),true))); % sum number of toward reports
            
            % 2) Stimulation trials
            temp_data = [ones(StimTrials.Toward(cond,coh),1); zeros(StimTrials.NumTrials(cond,coh) - StimTrials.Toward(cond,coh),1)];
            % Randomly sample the data
            boot_toward_stim(coh) = sum(temp_data(randsample(length(temp_data),length(temp_data),true))); % sum number of toward reports
        end
        pfitMat(:,:,cond) = [CoherenceArray', boot_toward_no_stim', NonStimTrials.NumTrials(cond,:)'];
        temp_pFit(cond) = psignifit(pfitMat(:,:,cond),options);
        pFitVals_no_stim(:,cond,b) = getStandardParameters(temp_pFit(cond),'gauss');
                
        pfitMat(:,:,cond) = [CoherenceArray', boot_toward_stim',StimTrials.NumTrials(cond,:)'];
        temp_pFit(cond) = psignifit(pfitMat(:,:,cond),options);
        pFitVals_stim(:,cond,b) = getStandardParameters(temp_pFit(cond),'gauss');
%         plotOptions.dataColor = colorsteps(cond,:);
%         plotOptions.lineColor = colorsteps(cond,:);
%         pfitPlot(cond) = plotPsych(temp_pFit(cond),plotOptions);
    end
end
close(f)
%% Calculate confidence intervals for each parameter
CI_no_stim = prctile(pFitVals_no_stim,[2.5,97.5],3);
CI_stim = prctile(pFitVals_stim,[2.5,97.5],3);

end
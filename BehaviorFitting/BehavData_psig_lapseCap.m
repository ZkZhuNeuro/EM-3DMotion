clear;
load('UnitTable_updating.mat')

load("P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\BehaviorFitting\BehaviorData_Clay.mat")
Clay_nonStim = BehaviorData_nonStim_pFit_all;
Clay_Stim    = BehaviorData_Stim_pFit_all;

load("P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\BehaviorFitting\BehaviorData_Jim.mat")
Jim_nonStim = BehaviorData_nonStim_pFit_all;
Jim_Stim    = BehaviorData_Stim_pFit_all;

Data_N = [Jim_nonStim; Clay_nonStim];
Data_S = [Jim_Stim;  Clay_Stim];

clear BehaviorData_nonStim_pFit_all BehaviorData_Stim_pFit_all ...
      Jim_nonStim Clay_nonStim Jim_Stim Clay_Stim

%% =========================
%  Settings
%  =========================
fieldName = 'Behave_lapseCap';

K = 5;
lambdaDelta_grid = logspace(-3, 3, 10);   % strength of deltaPSE penalty
deltaMax = 1;                              % tolerated abs(deltaPSE) before penalty starts
epsSlope = 1e-4;                           % minimum allowed slope
lapseMax = 0.10;                           % max lower/upper lapse

%%%%%%%%%%%%%%%%%%%%%%%%%
% Parameters from behavioral data collection before recording:
options.sigmoidName = 'norm'; % norm cdf fit
%options.estimateType = 'MAP';
options.fixedPars = NaN(5,1);
options.fixedPars(3:4) = 0.00001; % Fix the upper and lower asymptotes\
options.expType = 'equalAsymptote'; %'YesNo';%'equalAsymptote';

% Provide prior on width
lowerBound = 2;
priorWidth = @(x) (x>0&x<=lowerBound).*(1-cos(pi.*x./lowerBound)) + (x>lowerBound&x<=100).*2; % raised cosine
options.priors{2} = priorWidth;
options.borders = nan(5,2);
options.borders(3,:)=[0,.05]; % upper range of lapse rate
options.borders(4,:)=[0,.05]; % lower range of lapse rate
%%%%%%%%%%%%%%%%%%%%%%%%%

%% =========================
%  Add output field if needed
%  =========================
if ~ismember('Behave_lapseCap_N', unit_table.Properties.VariableNames)
    unit_table.Behave_lapseCap_N = cell(height(unit_table), 1);
end

if ~ismember('Behave_lapseCap_S', unit_table.Properties.VariableNames)
    unit_table.Behave_lapseCap_S = cell(height(unit_table), 1);
end

%% =========================
%  Fit all recordings / cues
%  =========================
for i_rec = 1:size(unit_table, 1)
% for i_rec = 1
    disp(['Rec number: ' num2str(i_rec) '/' num2str(size(unit_table, 1))])

    if isempty(unit_table.Behave_lapseCap_N{i_rec})
        unit_table.Behave_lapseCap_N{i_rec} = cell(1, size(Data_N{i_rec}, 2));
    end

    if isempty(unit_table.Behave_lapseCap_S{i_rec})
        unit_table.Behave_lapseCap_S{i_rec} = cell(1, size(Data_S{i_rec}, 2));
    end

    for i_cue = 1:size(Data_N{i_rec}, 2)

        Behav_N = Data_N{i_rec}(i_cue).data;
        Behav_S = Data_S{i_rec}(i_cue).data;

        % coh = [Behav_N(:,1); Behav_S(:,1)];
        % y   = [Behav_N(:,2); Behav_S(:,2)];
        % n   = [Behav_N(:,3); Behav_S(:,3)];
        % s   = [zeros(size(Behav_N,1),1); ones(size(Behav_S,1),1)];
        % 
        % % X = [coh, s, coh*s]
        % X_full = [coh, s, coh.*s];

        result_N = psignifit_controlLapse(Behav_N, lapseMax, options);
        result_S = psignifit_controlLapse(Behav_S, lapseMax, options);

        result_N.Posterior = [];
        result_S.Posterior = [];
        result_N.weight = [];
        result_S.weight = [];

        unit_table.Behave_lapseCap_N{i_rec}{i_cue} = result_N;
        unit_table.Behave_lapseCap_S{i_rec}{i_cue} = result_S;
        % cd C:\EM\BehaviorFitting
        % save unti_table_lapseCap unit_table
        % cd P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\BehaviorFitting
    end
end

%%
cd C:\EM\BehaviorFitting
save unit_table_lapseCap unit_table


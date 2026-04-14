clear;
load('UnitTable_updating.mat')
%%
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

lapseMax = 0.000010;                           % max lower/upper lapse

% Parameters from behavioral fitting:
options.sigmoidName = 'norm'; % norm cdf fit
lowerBound = 2;
priorWidth = @(x) (x>0&x<=lowerBound).*(1-cos(pi.*x./lowerBound)) + (x>lowerBound&x<=100).*2; % raised cosine
options.priors{2} = priorWidth;

%% =========================
%  Add output field if needed
%  =========================
if ~ismember('Behave_N', unit_table.Properties.VariableNames)
    unit_table.Behave_N = cell(height(unit_table), 1);
end

if ~ismember('Behave_S', unit_table.Properties.VariableNames)
    unit_table.Behave_S = cell(height(unit_table), 1);
end

%% =========================
%  Fit all recordings / cues
%  =========================

for i_rec = 1:size(unit_table, 1)
% for i_rec = 1:15
    disp(['Rec number: ' num2str(i_rec) '/' num2str(size(unit_table, 1))])

    if isempty(unit_table.Behave_N{i_rec})
        unit_table.Behave_N{i_rec} = cell(1, size(Data_N{i_rec}, 2));
    end

    if isempty(unit_table.Behave_S{i_rec})
        unit_table.Behave_S{i_rec} = cell(1, size(Data_S{i_rec}, 2));
    end

    for i_cue = 1:4

        Behav_N = Data_N{i_rec}(i_cue).data;
        Behav_S = Data_S{i_rec}(i_cue).data;

        result_N = psignifit_controlLapse(Behav_N, lapseMax, options);
        result_S = psignifit_controlLapse(Behav_S, lapseMax, options);

        result_N.Posterior = [];
        result_S.Posterior = [];
        result_N.weight = [];
        result_S.weight = [];
        result_N.psiHandle = [];
        result_S.psiHandle = [];

        unit_table.Behave_N{i_rec}{i_cue} = result_N;
        unit_table.Behave_S{i_rec}{i_cue} = result_S;
    end
end

cd C:\EM\BehaviorFitting
save('unit_table_lapseHardCap_00.mat', 'unit_table', '-v7.3')
cd P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\BehaviorFitting
%%
colorsteps = [0 0 0;...
    0 0 255;...
    5 150 5;...
    234 0 233]/255;

lapse_S_left = NaN(size(Data_N, 1), 4);
lapse_S_right = NaN(size(Data_N, 1), 4);
lapse_S_left_cap = NaN(size(Data_N, 1), 4);
lapse_S_right_cap = NaN(size(Data_N, 1), 4);
for i_rec = 1:size(unit_table, 1)
    for i_cue = 1:4
        lapse_S_left(i_rec, i_cue) = Data_S{i_rec}(i_cue).Fit(4);
        lapse_S_right(i_rec, i_cue) = Data_S{i_rec}(i_cue).Fit(3);
        lapse_S_left_cap(i_rec, i_cue) = unit_table.Behave_S{i_rec}{i_cue}.Fit(4);
        lapse_S_right_cap(i_rec, i_cue) = unit_table.Behave_S{i_rec}{i_cue}.Fit(3);
    end
end

%%
figure()
hold on
for i_cue = 1:4
    scatter(lapse_S_left(:, i_cue), lapse_S_left_cap(:, i_cue), 'MarkerEdgeColor', colorsteps(i_cue,:));
end
axis square
xlabel('Original lapse leftside')
ylabel('Capped lapse leftside')
ylim([0 0.5])
plot([0 0.5], [0 0.5], 'k')

figure()
hold on
for i_cue = 1:4
    scatter(lapse_S_right(:, i_cue), lapse_S_right_cap(:, i_cue), 'MarkerEdgeColor', colorsteps(i_cue,:));
end
axis square
xlabel('Original lapse leftside')
ylabel('Capped lapse leftside')
ylim([0 0.5])
plot([0 0.5], [0 0.5], 'k')

%%
if ~ismember('DeltaBias_lapseCap', unit_table.Properties.VariableNames)
    unit_table.DeltaBias_lapseCap = cell(height(unit_table), 1);
end
Bias_ori = NaN(size(unit_table, 1), 4);
Bias_check = NaN(size(unit_table, 1), 4);
for i_rec = 1:size(unit_table, 1)
    for i_cue = 1:4
        Bias_ori(i_rec, i_cue) = unit_table.Delta_bias{i_rec}(i_cue);
        Bias_check(i_rec, i_cue) = unit_table.Behave_N{i_rec}{i_cue}.Fit(1) ...
            - unit_table.Behave_S{i_rec}{i_cue}.Fit(1);
        unit_table.DeltaBias_lapseCap{i_rec}(i_cue) = unit_table.Behave_N{i_rec}{i_cue}.Fit(1) - unit_table.Behave_S{i_rec}{i_cue}.Fit(1);
    end
end

figure()
hold on
for i_cue = 1:4
    scatter(Bias_ori(:, i_cue), Bias_check(:, i_cue), 'MarkerEdgeColor', colorsteps(i_cue,:));
end
axis square
xlabel('Original biases')
ylabel('Checking biases')


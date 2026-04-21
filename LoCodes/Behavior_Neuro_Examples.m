figure; hold on;
%% Behavioral Data
% 14 May 2019
matching_unit_beh = datefind(datenum('11/13/2019'),Behavioral_Data.Date);
matching_unit_neuro = min(datefind(datenum('11/13/2019'),MIDTable.Date));

% First subplot is actual behavior
f = MIDTable.Folder_Index(matching_unit_neuro);
selected_unit = MIDTable.Unit(matching_unit_neuro);

combined_dat = MotionData_ByStim(f).pFitOut(1).data(:,2)./MotionData_ByStim(f).pFitOut(1).data(:,3);
combined_fit = normcdf(xvals,MotionData_ByStim(f).pFit(1,1),MotionData_ByStim(f).pFit(2,1));

monoL_dat = MotionData_ByStim(f).pFitOut(2).data(:,2)./MotionData_ByStim(f).pFitOut(2).data(:,3);
monoL_fit = normcdf(xvals,MotionData_ByStim(f).pFit(1,2),MotionData_ByStim(f).pFit(2,2));

monoR_dat = MotionData_ByStim(f).pFitOut(3).data(:,2)./MotionData_ByStim(f).pFitOut(3).data(:,3);
monoR_fit = normcdf(xvals,MotionData_ByStim(f).pFit(1,3),MotionData_ByStim(f).pFit(2,3));

bino_dat = MotionData_ByStim(f).pFitOut(4).data(:,2)./MotionData_ByStim(f).pFitOut(4).data(:,3);
bino_fit = normcdf(xvals,MotionData_ByStim(f).pFit(1,4),MotionData_ByStim(f).pFit(2,4));

subplot(1,3,1); hold on;
plot([-1,1],[0.5,0.5],'--k');
plot([0,0],[0,1],'--k');


h2 = plot(xvals, monoL_fit,'-', 'Color', colorsteps(2,:));
scatter(CoherenceArray, monoL_dat, point_size, colorsteps(2,:), 'filled', 'jitter', 'off', 'jitterAmount', 0.01);

h3 = plot(xvals, monoR_fit,'-', 'Color', colorsteps(3,:));
scatter(CoherenceArray, monoR_dat, point_size, colorsteps(3,:), 'filled', 'jitter', 'off', 'jitterAmount', 0.01);

h4 = plot(xvals, bino_fit,'-', 'Color', colorsteps(4,:));
scatter(CoherenceArray, bino_dat, point_size, colorsteps(4,:), 'filled', 'jitter', 'off', 'jitterAmount', 0.01);

h1 = plot(xvals, combined_fit,'-', 'Color', colorsteps(1,:));
scatter(CoherenceArray, combined_dat, point_size, colorsteps(1,:), 'filled', 'jitter', 'off', 'jitterAmount', 0);

xlim([-1,1]);
ylim([0 1]);
xticks([-1, -0.5, 0, 0.5, 1]);
yticks([0,0.5,1]);
% title([datestr(MIDTable.Date(ith_unit)) ' TT: ' num2str(MIDTable.Tetrode(ith_unit)) ' Unit: ' num2str(MIDTable.Unit(ith_unit))]);
axis square; box off;


% sensitivity vals in top left
sensits = [Behavioral_Data.Combined_Sensit(matching_unit_beh), Behavioral_Data.MonoL_Sensit(matching_unit_beh), Behavioral_Data.MonoR_Sensit(matching_unit_beh), Behavioral_Data.Bino_Sensit(matching_unit_beh)];
for cond = 1:4 % For each condition
    pos_sensit = [-0.9,0.93];
    pos_mu = [0.5, 0.2];
    pos_sensit(2) = pos_sensit(2) - 0.05*(cond-1);
    text(pos_sensit(1),pos_sensit(2), ['\boldmath$\sigma^{-1} = ', ' ', num2str(round(sensits(cond),2)), '$'],'FontSize',16,'FontName','Arial','Color',colorsteps(cond,:),'FontWeight','bold','Interpreter', 'latex');
end

%% MT 2D Example
% matching_unit_neuro = find(MIDTable.Date == '6/4/2021' & MIDTable.Tetrode == 5 & MIDTable.Unit == 2);
matching_unit_neuro = find(MIDTable.Date == '2/15/2019' & MIDTable.Tetrode == 2 & MIDTable.Unit == 2);
ith_unit = matching_unit_neuro;

subplot(1,3,2); hold on;
plot([-1,1],[0.5,0.5],'--k');
plot([0,0],[0,1],'--k');

h2 = plot(xvals, normcdf(xvals, neurometric_fits.paired_comp.MonoL(ith_unit,1),  neurometric_fits.paired_comp.MonoL(ith_unit,2)),'-', 'Color', colorsteps(2,:));
scatter(CoherenceArray, neurometric_responses.paired_comp.MonoL(ith_unit,:), point_size, colorsteps(2,:), 'filled', 'jitter', 'off', 'jitterAmount', 0.01);

h3 = plot(xvals, normcdf(xvals, neurometric_fits.paired_comp.MonoR(ith_unit,1),  neurometric_fits.paired_comp.MonoR(ith_unit,2)),'-', 'Color', colorsteps(3,:));
scatter(CoherenceArray, neurometric_responses.paired_comp.MonoR(ith_unit,:), point_size, colorsteps(3,:), 'filled', 'jitter', 'off', 'jitterAmount', 0.01);

h4 = plot(xvals, normcdf(xvals, neurometric_fits.paired_comp.Bino(ith_unit,1),  neurometric_fits.paired_comp.Bino(ith_unit,2)),'-', 'Color', colorsteps(4,:));
scatter(CoherenceArray, neurometric_responses.paired_comp.Bino(ith_unit,:), point_size, colorsteps(4,:), 'filled', 'jitter', 'off', 'jitterAmount', 0.05);

h1 = plot(xvals, normcdf(xvals, neurometric_fits.paired_comp.Combined(ith_unit,1),  neurometric_fits.paired_comp.Combined(ith_unit,2)),'-', 'Color', colorsteps(1,:));
scatter(CoherenceArray, neurometric_responses.paired_comp.Combined(ith_unit,:), point_size, colorsteps(1,:), 'filled', 'jitter', 'off', 'jitterAmount', 0.01);

xlim([-1,1]);
ylim([0 1]);
xticks([-1, -0.5, 0, 0.5, 1]);
yticks([0,0.5,1]);
% title([datestr(MIDTable.Date(ith_unit)) ' TT: ' num2str(MIDTable.Tetrode(ith_unit)) ' Unit: ' num2str(MIDTable.Unit(ith_unit))]);
axis square; box off;


% sensitivity vals in top left
sensits = [1/neurometric_fits.paired_comp.Combined(ith_unit,2), 1/neurometric_fits.paired_comp.MonoL(ith_unit,2), 1/neurometric_fits.paired_comp.MonoR(ith_unit,2), 1/neurometric_fits.paired_comp.Bino(ith_unit,2)];
for cond = 1:4 % For each condition
    pos_sensit = [-0.9,0.93];
    pos_mu = [0.5, 0.2];
    pos_sensit(2) = pos_sensit(2) - 0.05*(cond-1);
    text(pos_sensit(1),pos_sensit(2), ['\boldmath$\sigma^{-1} = ', ' ', num2str(round(sensits(cond),2)), '$'],'FontSize',16,'FontName','Arial','Color',colorsteps(cond,:),'FontWeight','bold','Interpreter', 'latex');
end

%% FST 3D Example
matching_unit_beh = datefind(datenum('09/15/2020'),Behavioral_Data.Date);
matching_unit_neuro = find(MIDTable.Date == '9/15/2020' & MIDTable.Tetrode == 7 & MIDTable.Unit == 5);
ith_unit = matching_unit_neuro;

subplot(1,3,3); hold on;
plot([-1,1],[0.5,0.5],'--k');
plot([0,0],[0,1],'--k');

h2 = plot(xvals, normcdf(xvals, neurometric_fits.paired_comp.MonoL(ith_unit,1),  neurometric_fits.paired_comp.MonoL(ith_unit,2)),'-', 'Color', colorsteps(2,:));
scatter(CoherenceArray, neurometric_responses.paired_comp.MonoL(ith_unit,:), point_size, colorsteps(2,:), 'filled', 'jitter', 'off', 'jitterAmount', 0.01);

h3 = plot(xvals, normcdf(xvals, neurometric_fits.paired_comp.MonoR(ith_unit,1),  neurometric_fits.paired_comp.MonoR(ith_unit,2)),'-', 'Color', colorsteps(3,:));
scatter(CoherenceArray, neurometric_responses.paired_comp.MonoR(ith_unit,:), point_size, colorsteps(3,:), 'filled', 'jitter', 'off', 'jitterAmount', 0.01);

h4 = plot(xvals, normcdf(xvals, neurometric_fits.paired_comp.Bino(ith_unit,1),  neurometric_fits.paired_comp.Bino(ith_unit,2)),'-', 'Color', colorsteps(4,:));
scatter(CoherenceArray, neurometric_responses.paired_comp.Bino(ith_unit,:), point_size, colorsteps(4,:), 'filled', 'jitter', 'off', 'jitterAmount', 0.05);

h1 = plot(xvals, normcdf(xvals, neurometric_fits.paired_comp.Combined(ith_unit,1),  neurometric_fits.paired_comp.Combined(ith_unit,2)),'-', 'Color', colorsteps(1,:));
scatter(CoherenceArray, neurometric_responses.paired_comp.Combined(ith_unit,:), point_size, colorsteps(1,:), 'filled', 'jitter', 'off', 'jitterAmount', 0.01);

xlim([-1,1]);
ylim([0 1]);
xticks([-1, -0.5, 0, 0.5, 1]);
yticks([0,0.5,1]);
% title([datestr(MIDTable.Date(ith_unit)) ' TT: ' num2str(MIDTable.Tetrode(ith_unit)) ' Unit: ' num2str(MIDTable.Unit(ith_unit))]);
axis square; box off;


% sensitivity vals in top left
sensits = [1/neurometric_fits.paired_comp.Combined(ith_unit,2), 1/neurometric_fits.paired_comp.MonoL(ith_unit,2), 1/neurometric_fits.paired_comp.MonoR(ith_unit,2), 1/neurometric_fits.paired_comp.Bino(ith_unit,2)];
for cond = 1:4 % For each condition
    pos_sensit = [-0.9,0.93];
    pos_mu = [0.5, 0.2];
    pos_sensit(2) = pos_sensit(2) - 0.05*(cond-1);
    text(pos_sensit(1),pos_sensit(2), ['\boldmath$\sigma^{-1} = ', ' ', num2str(round(sensits(cond),2)), '$'],'FontSize',16,'FontName','Arial','Color',colorsteps(cond,:),'FontWeight','bold','Interpreter', 'latex');
end

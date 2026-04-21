%% Example Neurons
set(groot, {'DefaultAxesXColor','DefaultAxesYColor','DefaultAxesZColor', 'DefaultTextFontName'}, {'k','k','k', 'Arial'})
set(groot, {'DefaultAxesLineWidth', 'DefaultLineLineWidth'}, {2,2})
set(groot, 'FixedWidthFontName', 'Arial')
save_dir = 'P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Thompson3DMotionMTFST2022\FigureDrafts\ExampleNeurons';

Jim_EU = {'Jim_MT_30April2019_TT3_mrg_Sorted-02_3DMotion_TInfo.mat', 2;...
    'Jim_FST_15September2020_TT7_mrg_Sorted-02_3DMotion_TInfo.mat', 5};
Clay_EU = {'Clay_MT_29April2021_TT8_mrg_Sorted-04_3DMotion_TInfo.mat', 2;...
    'Clay_MT_04June2021_TT5_mrg_Sorted-01_3DMotion_TInfo.mat', 2};
    
%% Jim Example plots
% First
f = find(strcmp(Jim_EU{1,1},MIDTable.Names(:,1)) & MIDTable.Unit == Jim_EU{1,2});
Offline_3DMotion_update(MIDTable.Paths(f),MIDTable.Names(f,:), 1, Jim_EU{1,2});

fig = gcf; hold on;
saveas(fig, fullfile([save_dir, '\',MIDTable.Labels{f},'.pdf']));

% Second
f = find(strcmp(Jim_EU{2,1},MIDTable.Names(:,1)) & MIDTable.Unit == Jim_EU{2,2});
Offline_3DMotion_update(MIDTable.Paths(f),MIDTable.Names(f,:), 1, Jim_EU{2,2});

fig = gcf; hold on;
saveas(fig, fullfile([save_dir, '\',MIDTable.Labels{f},'.pdf']));


%% Clay Example Plots
% First
f = find(strcmp(Clay_EU{1,1},MIDTable.Names(:,1)) & MIDTable.Unit == Clay_EU{1,2});
Offline_3DMotion_update(MIDTable.Paths(f),MIDTable.Names(f,:), 1, Clay_EU{1,2});

fig = gcf; hold on;
saveas(fig, fullfile([save_dir, '\',MIDTable.Labels{f},'.pdf']));

% Second
f = find(strcmp(Clay_EU{2,1},MIDTable.Names(:,1)) & MIDTable.Unit == Clay_EU{2,2});
Offline_3DMotion_update(MIDTable.Paths(f),MIDTable.Names(f,:), 1, Clay_EU{2,2});

fig = gcf; hold on;
saveas(fig, fullfile([save_dir, '\',MIDTable.Labels{f},'.pdf']));



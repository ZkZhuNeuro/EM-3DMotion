clear all; close all

isSave = 1;

colorsteps = [0 0 0;...
    0 0 255;...
    5 150 5;...
    234 0 233]./255;
ElectrodeNums = [1:16];
ChannelMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]; % Edge Design Dorsal-->Ventral
CoherenceArray = [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22]./22;
windowWidth = 1920; %(pixels)
windowHeight = 1080; %(pixels)
WindowCenter = [windowWidth/2, windowHeight/2];
viewingDistance = 570; %(mm)
ScreenWidth = 635; %(mm)
ScreenHeight = 358; %(mm)
mm2pix = @(x) x.*windowWidth./ScreenWidth;
conditionNames = {'Combined','MonoL','MonoR','Stereo'};
% Define distance between channels
Distance = 0:50:50*(length(ChannelMap)-1); % 50 micrometers apart
cell_column = ['MUAStim']; % Will find all cells with stimulus in RF
monkeys = ["Jim"];
areas = ["MT", "FST"];
file_tag = '3DMotionQuick';

%% Get excel sheet with session information
xls_table = 'P:\Jim\NeuroData\RecordingRecord_Stimulation.xlsx';
path_options = {'P:\Jim\NeuroData\'};
exclusion_criteria = [{'ROI','MT/FST'}; {'ROI','MT?'};{'MUAStim',''}; {'MUAStim','N'}];
inclusion_criteria = [{'MUAStim','Y'}];

%% Read in the excel file
tb = readtable(xls_table);
unit_table = table();

%% Use inclusion and exclusion criteria
if ~isempty(inclusion_criteria)
    for i = 1:size(inclusion_criteria,1)
        inclusion(:,i) = strcmp(tb.(inclusion_criteria{i,1}), inclusion_criteria{i,2}); % These are inclusion criteria that contain strings
    end
else
    inclusion = ones(size(tb,1),size(tb,2));
end

if ~isempty(exclusion_criteria)
    for e = 1:size(exclusion_criteria,1)
        exclusion(:,e) = strcmp(tb.(exclusion_criteria{e,1}), exclusion_criteria{e,2});
    end
else
    exclusion = zeros(size(tb,1),size(tb,2));
end
exclusion = any(exclusion,2);
inclusion = all(inclusion,2);
inclusion = logical(inclusion & ~exclusion);

%% Extract paths corresponding to each recording date that will be included
excel_table_inds = find(inclusion);
% Find the folders with the appropriate date
sorted_folders = dir(path_options{1});
if length(path_options) > 1
    alt_sorts = dir(path_options{2});
    sorted_folders = [sorted_folders; alt_sorts]; % Concatanate so that it checks local drive first, server second
end
[un, ia] = unique(datenum({sorted_folders.name},'yyyymmdd')); % finds first instance -- therefore, if on local drive, will use that file first
sorted_folders = sorted_folders(ia); % We have now thinned our folders to include only the fist instance of each possible recording date, checking the paths sequentially.
inclusion_folder_indices = datefind(tb.Date(excel_table_inds), datenum({sorted_folders.name},'yyyymmdd')); % Now only select folders based on your inclusion/exclusion criteria

if length(inclusion_folder_indices) ~= length(excel_table_inds)
    error('number of files does not match the number of indices selected');
end

%% Step through each recording date and obtain the file names of interest
for recording_num = 1:length(inclusion_folder_indices)
    % Build structure of file paths and relevant waveform files
    expression = {};
    recording_dir = dir(fullfile([sorted_folders(inclusion_folder_indices(recording_num)).folder, '/' sorted_folders(inclusion_folder_indices(recording_num)).name],'*.mat'));
    expression{end+1} = 'MUA';
    expression{end+1} = file_tag;
    expression_TInfo = [expression, 'TInfo'];
    expression_SelIndex = [expression, 'SelIndex'];
    tinfo_file = recording_dir(~cellfun(@isempty, regexp({recording_dir.name}, strjoin(expression_TInfo,'.*')))).name;
    sinfo_file = recording_dir(~cellfun(@isempty, regexp({recording_dir.name}, strjoin(expression_SelIndex,'.*')))).name;


    temp_table = table();
    temp_table.Date = tb.Date(excel_table_inds(recording_num));
    temp_table.ROI = tb.ROI(excel_table_inds(recording_num));
    temp_table.Hole = str2num(char(tb.Hole(excel_table_inds(recording_num))));
    temp_table.Depth = tb.Depth(excel_table_inds(recording_num));
    temp_table.Offset = str2num(char(tb.Offset(excel_table_inds(recording_num))));
    temp_table.Guide = tb.GuideTube(excel_table_inds(recording_num));
    temp_table.StimLoc = str2num(char(tb.StimulusLocation(excel_table_inds(recording_num))));
    temp_table.Paths = {fullfile(recording_dir(1).folder,'\')};
    temp_table.Names = {tinfo_file, sinfo_file};
    temp_table.Folder_Index = recording_num;
    temp_table.NChannels = tb.Channels(excel_table_inds(recording_num));
    temp_table.StimElec = tb.StimElec(excel_table_inds(recording_num));
    temp_table.ROI_review = tb.Area_Ari_20230805(excel_table_inds(recording_num));
    temp_table.DeadChannel = {str2num(char(tb.DeadChannel(excel_table_inds(recording_num))))};

    unit_table = [unit_table; temp_table];

end

%%
load('Neuro_AllSession_20230628.mat')
load('RF_table_20230718_2DFit.mat')
load('MIDTable_20230620.mat')
load('RF_table_20230821_allCh.mat')
for rec = 1:size(unit_table, 1)
%%
% for rec = 2
    f = figure();
    set(gcf, 'Position', [0 0 1920 1080])
    %%
    pathname = unit_table.Paths{rec};
    file_names = unit_table.Names(rec, :);
    channel = unit_table.StimElec(rec);
    unit = 1;
    options.ZeroE = 118;

    if isempty(pathname) || isempty(file_names)
        [file_names, pathname] = uigetfile({'*.mat' }, 'Select Files',pwd, 'MultiSelect', 'on');
        if length(file_names) == 2
            TrialInfo_file = load(fullfile(pathname,file_names{~contains(file_names, 'SelIndex')}));
            TrialInfo = TrialInfo_file.TrialInfo;
            SelectionInfo_file = load(fullfile(pathname,file_names{contains(file_names, 'SelIndex')}));
            Config = SelectionInfo_file.Config;
            SelectionInfo = logical(SelectionInfo_file.EditSel);
            TrialInfo = TrialInfo(SelectionInfo); % Only look at selected trials
            plotFlag = 1;
        else
            error('Not enough files selected, please select a TInfo file and SellIndex file');
        end
    else
        if length(file_names) == 2
            %         pathname = pathname{1};
            %         file_names = file_names{:};
            TrialInfo_file = load(fullfile(pathname,file_names{~contains(file_names, 'SelIndex')}));
            TrialInfo = TrialInfo_file.TrialInfo;
            SelectionInfo_file = load(fullfile(pathname,file_names{contains(file_names, 'SelIndex')}));
            Config = SelectionInfo_file.Config;
            SelectionInfo = logical(SelectionInfo_file.EditSel);
            TrialInfo = TrialInfo(SelectionInfo); % Only look at selected trials
            plotFlag = 1;
        else
            error('Not enough files selected, please select a TInfo file and SellIndex file');
        end
    end
    %%
    lineSpecX = '-r';
    lineSpecY = '-b';
    options.ZeroE = 118;
    options.PreT = 0.3;
    options.PostT = 1.4;
    options.BaseT = 0.1;
    options.PathName = pathname;
    options.FName = extractBefore(file_names{~contains(file_names, 'SelIndex')},'_TInfo');
    options.PlotFlag = 1;
    for iUnit = 1:length(unit)
        CountT = 1;RawSDF = zeros(10,10); SpkMark = [];
        h = waitbar(0,'Drawing Spikes Rasters'); % Get the raw SDF for each trial for this unit
        for i=1:length(TrialInfo)
            waitbar(i/length(TrialInfo));
            p = find(TrialInfo(i).EID==options.ZeroE);
            if ~isempty(p)
                zeroT = TrialInfo(i).EventT(p(1));
                ST = zeroT-options.PreT;
                if ST<=TrialInfo(i).StartTimeStamp
                    ST = TrialInfo(i).StartTimeStamp;
                end
                ET = zeroT+options.PostT;
                if ET>=TrialInfo(i).EndTimeStamp
                    ET = TrialInfo(i).EndTimeStamp;
                end
                pp = find(TrialInfo(i).AITs>=ST & TrialInfo(i).AITs<=ET);
                RawSDF(CountT,1:length(pp)) = TrialInfo(i).UnitSDF(channel,unit(iUnit),pp(1:end));
                p = find(TrialInfo(i).UnitT(channel,unit(iUnit),1:end)>=ST &...
                    TrialInfo(i).UnitT(channel,unit(iUnit),1:end)<=ET);
                if ~isempty(p)
                    tempI = round((TrialInfo(i).UnitT(channel,unit(iUnit),p(1:end))-ST)*1000)+1;
                    SpkMark(CountT,tempI) = 1;
                else
                    SpkMark(CountT,:) = 0;
                end
                CountT = CountT + 1;
            end
        end
        CountT = CountT-1;
        MeanSDF = mean(RawSDF);
        yRange = max(MeanSDF);
        if isnan(yRange) || yRange==0
            yRange = 1;
        end
        
        fig = subplot(3, 4, 6);
        stepS = yRange/CountT;
        if options.PlotFlag
%             fig = figure('color', [1 1 1], 'position', [450 500 1000 400]); hold on;
            fig.Color = [1 1 1];
%             fig.Position = [450 500 1000 400];
            
            for i=1:CountT
                p = find(SpkMark(i,:)>0);
                if ~isempty(p)
                    tempY = ones(1,length(p))*(i-1)*stepS;
                    plot(p,tempY,'.k','MarkerSize',3);  %% raster
                    hold on
                end
            end
            plot(MeanSDF,'-b','LineWidth',2); hold on;
            line([options.PreT*1000 options.PreT*1000],[0 max(MeanSDF)],'Color','b');
            ylim([0 yRange+yRange*0.1])
        end

        PreT = options.PreT;
        PostT = options.PostT;
        BaseT = options.BaseT;

        %Find Spike Burst Onset
        if options.ZeroE == 118 && PreT>=0.05 && BaseT>=0.04
            ST = (PreT - BaseT)*1000+1;
            VLatency(iUnit) = 300;
            if PostT*1000<VLatency(iUnit)
                VLatency(iUnit) = PostT*1000;
            end
            ATable =[];
            for i=1:CountT
                ATable(i,1) = mean(RawSDF(i,ST:PreT*1000));  %% baseline activity distribution
                for iT = PreT*1000:PreT*1000+VLatency(iUnit)
                    ATable(i,iT-PreT*1000+2) = RawSDF(i,iT);  %% activity after stimulus onset
                end
            end

            [~,~,stats]=anova1(ATable,[],'off');
            tempBaseMean = stats.means(1);  %% baseline activity
            tempMean = stats.means(2:end);
            %multcompare(stats);
            [c,~,~,~] = multcompare(stats,'Display','off');
            tmpIdx = find(c(:,1)==1);
            if ~isempty(tmpIdx)
                p = find(c(tmpIdx,6)<=0.05);
                OnIdx = [];
                if ~isempty(p)
                    OnIdx = PreT * 1000 + min(p);
                    if tempBaseMean>tempMean(min(p))
                        OnIdx = -1*OnIdx;
                    end
                end
            else
                OnIdx = [];
            end

            if ~isempty(OnIdx)
                if options.PlotFlag
                    line([abs(OnIdx), abs(OnIdx)],[0 yRange+yRange*0.1], 'Color', 'r');
                    text(abs(OnIdx)+10, yRange+yRange*0.05, ['Onset: '  num2str(abs(OnIdx)-PreT*1000) 'ms'], 'FontSize', 14, 'Color', 'r');
                end
                if OnIdx>0
                    VLatency(iUnit) = abs(OnIdx)-PreT*1000;
                else
                    VLatency(iUnit) = -1*(abs(OnIdx)-PreT*1000); % for inhibitory visual response
                end
            else
                if options.PlotFlag
                    text(abs(OnIdx)+10, yRange+yRange*0.05, ['Visual Resp. Onset Not Detected']);
                end
                VLatency(iUnit) = NaN;
            end
            if options.PlotFlag
                saveas(fig, [options.PathName options.FName '_SDF_Unit' num2str(unit(iUnit)) '.fig'])
            end
        elseif isequal(options.ZeroE,190)
            if options.PlotFlag
                saveas(fig, [options.PathName options.FName '_SacAlign_SDF_Unit' num2str(unit(iUnit)) '.fig'])
            end
        end
        close(h);
    end


    %%
    plotSpikeMat_Means = Neuro_AllSession(rec).Means;
    subplot(3, 4, 5); hold on;
    ch = unit_table.StimElec(rec);
    tempCh = squeeze(plotSpikeMat_Means(:,:,ch));
    p = find(ChannelMap == ch);
    box on;
    temp = tempCh(:,:,1);
    fr = plot(CoherenceArray(temp(1,:)>0), temp(:, temp(1,:)>0),'-o');
    title(['Date:', datestr(unit_table.Date(rec)), ', Channel: ', num2str(ch)]);
    ylabel('Firing Rate');
    xlabel('Coherence');
    for cond=1:4
        fr(cond).Color = colorsteps(cond,:);
        fr(cond).MarkerFaceColor = colorsteps(cond,:);
        fr(cond).MarkerEdgeColor = colorsteps(cond,:);
    end
    axis square;

    %%
    [RFCenter_char, RFCenter_char_old, r_new, r_old, area, area_old, fitIdx] = Fit2DGaussian_Subplot(cell2mat(RF_table.rawRFmap(rec)), ... 
        cell2mat(RF_table.uniXPos(rec)), cell2mat(RF_table.uniYPos(rec)), cell2mat(RF_table.meanXYpos(rec)), RF_table.Date(rec));
    hold off

    %% Plot the recording location in MRI map. 
    hole = unit_table.Hole(rec, :);
    guideTube = unit_table.Guide(rec);
    depth = unit_table.Depth(rec);
    offset = unit_table.Offset(rec, :);
    PlotRecordingLocation_JohnTry(hole, guideTube, depth, offset);
    hold off

    %% Plot behavior
    fprintf('\nLoad Stimulation Behavior Data')
    date = datestr(RF_table.Date(rec), 'yyyymmdd');
    load(['C:\Jim\StimData\', date, '.mat'], 'BehaviorData')

    % Non-Stimulation Trials
    subplot(3,4,4); hold on;
    pFitResult = BehaviorData.NoStim.pFitResult;
    plotBehavior_Stim(pFitResult)
    title('Non-Stimulation Trials');

    % Stimulation Trials
    pFitResult = BehaviorData.Stim.pFitResult;

    subplot(3,4,8); hold on;
    plotBehavior_Stim(pFitResult)
    title('Stimulation Trials');

    text(1.02,1,{['\Delta\mu: ', num2str(round(MIDTable.Delta_Mu_Combined(rec),2))]},'Color',colorsteps(1,:),'Units','Normalized','FontWeight','bold');
    text(1.02,0.9,{['\Delta\mu: ', num2str(round(MIDTable.Delta_Mu_MonoL(rec),2))]},'Color',colorsteps(2,:),'Units','Normalized','FontWeight','bold');
    text(1.02,0.8,{['\Delta\mu: ', num2str(round(MIDTable.Delta_Mu_MonoR(rec),2))]},'Color',colorsteps(3,:),'Units','Normalized','FontWeight','bold');
    text(1.02,0.7,{['\Delta\mu: ', num2str(round(MIDTable.Delta_Mu_Stereo(rec),2))]},'Color',colorsteps(4,:),'Units','Normalized','FontWeight','bold');
    
    subplot(3,4,2)
    title(['ROI:', cell2mat(unit_table.ROI(rec)), ', ROI review:', cell2mat(unit_table.ROI_review(rec))])

    %% Plot RF scatters
    subplot(3, 8, [19:21])
    poor_fit = 0;
    xlim([0 1920])
    ylim([0 1080])
    color_step = cool(16);
    hold on
    for u = ElectrodeNums
        fitIdx = RF_table_allCh.fitIdx{rec}(u);
        if fitIdx == 1
        RF_center = str2num(RF_table_allCh.RFCenter_char{rec}{u});
        RF_center_mm = tand(RF_center) * viewingDistance;
        RF_center_pix = mm2pix(RF_center_mm) + WindowCenter;
        curve = RF_table_allCh.curve{rec}{u};
        x_curve = curve(1, :);
        y_curve_positive = 1080 - curve(2, :);
        y_curve_negative = 1080 - curve(3, :);
        plot(x_curve, y_curve_positive, "Color", [color_step(u, :) 0.8], "LineWidth", 1.5)
        plot(x_curve, y_curve_negative, "Color", [color_step(u, :) 0.8], "LineWidth", 1.5)
        plot([x_curve(1), x_curve(1)], [y_curve_negative(1), y_curve_positive(1)], "Color", [color_step(u, :) 0.8], "LineWidth", 1.5)
        plot([x_curve(end), x_curve(end)], [y_curve_negative(end), y_curve_positive(end)], "Color", [color_step(u, :)  0.8], "LineWidth", 1.5)
        scatter(RF_center_pix(1), RF_center_pix(2), 15, color_step(u, :), 'filled', 'MarkerFaceAlpha', 0.8)
        else
            poor_fit = poor_fit + 1;
        end
    end
    title(['Poor fits on ', num2str(poor_fit), ' Channels'])

    %%
    RFScatter_Dist2_function(unit_table, RF_table_allCh, ElectrodeNums, rec)
    %%
    if isSave == 1
        savefig(f, ['P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\StimSiteFigures\', datestr(unit_table.Date(rec))])
        print(['P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\StimSiteFigures\', datestr(unit_table.Date(rec))], '-dpng')
    close all
    end
end
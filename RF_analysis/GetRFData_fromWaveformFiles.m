
clear all
ElectrodeNums = [1:16];
ChannelMap = [8 6 4 2 7 5 3 1 15 13 11 9 16 14 12 10]; % Edge Design Dorsal-->Ventral
% Define distance between channels
Distance = 0:50:50*(length(ChannelMap)-1); % 50 micrometers apart
cell_column = ['MUAStim']; % Will find all cells with stimulus in RF
monkeys = ["Clay"];
areas = ["MT", "FST"];
file_tag = {'mua_sparsenoise.wfexp','sparsenoise_mua.wfexp'};

%% Get excel sheet with session information
% xls_table = 'P:\Jim\NeuroData\RecordingRecord_Stimulation_20250331.xlsx';
xls_table = 'P:\Clay\NeuroData\RecordingRecord_Stimulation.xlsx';
% path_options = {'P:\Jim\NeuroData\'};
path_options = {'P:\Clay\NeuroData\'};
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
if numel(path_options) > 1
    alt_sorts = dir(path_options{2});
    sorted_folders = [sorted_folders; alt_sorts];
end

names = {sorted_folders.name};

% keep only directories, exclude . and .., and require exactly 8 digits
isDir   = [sorted_folders.isdir];
isDot   = ismember(names, {'.','..'});
isDate8 = ~cellfun(@isempty, regexp(names, '^\d{8}$', 'once'));

keep = isDir & ~isDot & isDate8;

sorted_folders = sorted_folders(keep);
names = names(keep);

dn = datenum(names, 'yyyymmdd');           % now safe
[~, ia] = unique(dn, 'stable');            % stable keeps first occurrence (local before server if concatenated that way)
sorted_folders = sorted_folders(ia);

folder_dt = datetime(names,"InputFormat","yyyyMMdd");
excel_dt  = datetime(tb.Date(excel_table_inds));

[tf, inclusion_folder_indices] = ismember(excel_dt, folder_dt);

%% Step through each recording date and obtain the file names of interest
for recording_num = 1:length(inclusion_folder_indices)
% for recording_num = 73
    % Build structure of file paths and relevant waveform files
    recording_dir = dir(fullfile([sorted_folders(inclusion_folder_indices(recording_num)).folder, '/' sorted_folders(inclusion_folder_indices(recording_num)).name],'*.wfexp.mat'));
    expression = file_tag;

    pattern = strjoin(expression, '|');   % 'MUA_SparseNoise|SparseNoise_MUA'

    names = {recording_dir.name};
    isMatch = ~cellfun(@isempty, regexp(names, pattern, 'once'));

    matches = recording_dir(isMatch);

    waveform_filename = matches(1).name;
    % waveform_filename = recording_dir(~cellfun(@isempty, regexp({recording_dir.name}, strjoin(expression,'.*')))).name;
    RawRipple_folder_idx = 0;
    recording_dir_nev = dir(fullfile( ...
        [sorted_folders(inclusion_folder_indices(recording_num)).folder, '/' ...
        sorted_folders(inclusion_folder_indices(recording_num)).name], ...
        '*SparseNoise000*.nev'));
    % Extract run numbers
    nums = nan(numel(recording_dir_nev),1);

    for i = 1:numel(recording_dir_nev)
        tok = regexp(recording_dir_nev(i).name,'SparseNoise000(\d+)\.nev','tokens');
        nums(i) = str2double(tok{1}{1});
    end

    % Find highest index
    [~, idx] = max(nums);

    % Final file
    recording_dir_nev = recording_dir_nev(idx);

    if size(recording_dir_nev, 1) == 0
        RawRipple_folder_idx = 1;
        basePath = fullfile(sorted_folders(inclusion_folder_indices(recording_num)).folder, ...
            sorted_folders(inclusion_folder_indices(recording_num)).name);

        recording_dir_nev = [
            dir(fullfile(basePath, 'RawRipple', '*.nev'));
            dir(fullfile(basePath, 'Raw Ripple', '*.nev'))
            ];
        
    end
    expression_nev = {'SparseNoise'};
    match_idx = ~cellfun(@isempty, regexp({recording_dir_nev.name}, strjoin(expression_nev,'.*')));

    nev_matches = recording_dir_nev(match_idx);

    if isempty(nev_matches)
        nev_filename = [];
    elseif numel(nev_matches) == 1
        nev_filename = nev_matches(1).name;
    else
        nev_filename = nev_matches(end).name;   % take last one
    end


    temp_table = table();
    temp_table.Date = tb.Date(excel_table_inds(recording_num));
    temp_table.ROI = tb.ROI(excel_table_inds(recording_num));
    temp_table.Hole = str2num(char(tb.Hole(excel_table_inds(recording_num))));
    temp_table.Depth = tb.Depth(excel_table_inds(recording_num));
    temp_table.Offset = str2num(char(tb.Offset(excel_table_inds(recording_num))));
    temp_table.Guide = tb.GuideTube(excel_table_inds(recording_num));
    temp_table.StimLoc = str2num(char(tb.StimulusLocation(excel_table_inds(recording_num))));
    temp_table.Paths = {fullfile(recording_dir(1).folder,'\')};
    temp_table.Names = {waveform_filename};
    temp_table.NevNames = {nev_filename};
    temp_table.Folder_Index = recording_num;
    temp_table.NChannels = tb.Channels(excel_table_inds(recording_num));
    temp_table.StimElec = tb.StimElec(excel_table_inds(recording_num));
    temp_table.RawRippleIdx = RawRipple_folder_idx;

    unit_table = [unit_table; temp_table];

end

%%
% for rec = 1
for rec = 1:size(unit_table, 1)
    [rawRFmap, uniXPos, uniYPos, meanXYpos, RFmapTable_allSti, SpikeRate_Baseline] = RFMappingFunction(unit_table, rec, ElectrodeNums);
    unit_table.rawRFmap(rec) = {rawRFmap};
    unit_table.uniXPos(rec) = {uniXPos};
    unit_table.uniYPos(rec) = {uniYPos};
    unit_table.meanXYpos(rec) = {meanXYpos};
    unit_table.FRbyTrial(rec) = {RFmapTable_allSti};
    unit_table.Baseline(rec) = {SpikeRate_Baseline};
end
RF_table = unit_table;
save('RF_table_Clay', 'RF_table');

% load("P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\RF_analysis\RF_table_Jim_20260201.mat")

%% Transform pix into mm and deg
windowWidth = 1920; %(pixels)
windowHeight = 1080; %(pixels)
viewingDistance = 570; %(mm)
ScreenWidth = 635; %(mm)
ScreenHeight = 358; %(mm)
mm2deg = @(x) atand(x./viewingDistance);
pix2mm = @(x) x.*ScreenWidth./windowWidth;
mm2pix = @(x) x.*windowWidth./ScreenWidth;
pix2deg = @(x) mm2deg(pix2mm(x));
WindowCenter = [windowWidth/2, windowHeight/2]; 

% for i_rec = 1
for i_rec = 1:size(RF_table, 1)
    XPos_pix = RF_table.uniXPos{i_rec};
    YPos_pix = RF_table.uniYPos{i_rec};
    meanXYpos_Pix = RF_table.meanXYpos{i_rec};

    XPos_mm = pix2mm(XPos_pix);
    YPos_mm = pix2mm(YPos_pix);
    meanXYpos_mm = pix2mm(meanXYpos_Pix);

    XPos_deg = pix2deg(XPos_pix - windowWidth/2);
    YPos_deg = pix2deg(-YPos_pix + windowHeight/2);
    meanXYpos_deg = pix2deg([meanXYpos_Pix(:, 1) - windowWidth/2, ...
        -meanXYpos_Pix(:, 2) + windowHeight/2]);

    RF_table.XPos_mm{i_rec} = XPos_mm;
    RF_table.YPos_mm{i_rec} = YPos_mm;
    RF_table.meanXYpos_mm{i_rec} = meanXYpos_mm;

    RF_table.XPos_deg{i_rec} = XPos_deg;
    RF_table.YPos_deg{i_rec} = YPos_deg;
    RF_table.meanXYpos_deg{i_rec} = meanXYpos_deg;
end

%%
ROI = 'MT';
% for i_rec = 1
for i_rec = 1:size(RF_table, 1)
    if strcmp(RF_table.ROI{i_rec}, ROI)
        fig = figure(); hold on
        %%
        % Inputs:
        %   L : N x 2  (columns: [x y]) centers of each bin/block
        %   M : N x 1  value at each center
        %   x : # unique x locations
        %   y : # unique y locations
        x = numel(RF_table.XPos_deg{i_rec});
        y = numel(RF_table.YPos_deg{i_rec});
        meanXYpos_deg = RF_table.meanXYpos_deg{i_rec};

        xVals = sort(unique(meanXYpos_deg(:,1)));
        yVals = sort(unique(meanXYpos_deg(:,2)));

        % Map each (x,y) in L to grid indices
        [~, ix] = ismember(meanXYpos_deg(:,1), xVals);
        [~, iy] = ismember(meanXYpos_deg(:,2), yVals);

        map = nan(y, x);                    % rows=y, cols=x (standard image convention)
        lin = sub2ind([y, x], iy, ix);
        map(lin) = RF_table.rawRFmap{i_rec};

        % Plot heatmap
        % figure
        imagesc(xVals, yVals, map);
        set(gca, 'YDir', 'normal');       % make y increase upward
        axis tight;
        colorbar;
        xlabel('X'); ylabel('Y');
        title('2D heat map');

        %%
        BaselineFR = RF_table.Baseline{i_rec};
        meanFR_Threshold = NaN(size(RF_table.FRbyTrial{i_rec}));
        for i_loc = 1:size(RF_table.FRbyTrial{i_rec}, 2)
            FR_loc = RF_table.FRbyTrial{i_rec}{i_loc};
            if numel(FR_loc) == 0
                meanFR_Threshold(i_loc) = 0;
            else
                p_loc = ranksum(BaselineFR, FR_loc);
                if p_loc < 0.05 / size(RF_table.FRbyTrial{i_rec}, 2) % Bonferroni
                    meanFR_Threshold(i_loc) = mean(FR_loc);
                else
                    meanFR_Threshold(i_loc) = 0;
                end
            end
        end
        rawRFmap_Threshold = reshape(meanFR_Threshold, numel(RF_table.uniYPos{i_rec}), numel(RF_table.uniXPos{i_rec}));
        %% Interpolate NaN by averaging the 3x3 surroundings.
        rawRFmap = cell2mat(RF_table.rawRFmap(i_rec));
        Z = rawRFmap;   % your matrix

        nanMask = isnan(Z);

        % Mask of valid entries
        validMask = ~nanMask;

        % Replace NaNs with zero for summation
        Z0 = Z;
        Z0(nanMask) = 0;

        kernel = ones(3,3);   % 8-neighborhood + center

        % Sum of neighbors
        neighborSum = conv2(Z0, kernel, 'same');

        % Count of valid neighbors
        neighborCount = conv2(double(validMask), kernel, 'same');

        % Remove center pixel contribution
        neighborSum   = neighborSum - Z0;
        neighborCount = neighborCount - double(validMask);

        % Compute mean (ignores NaNs automatically)
        neighborMean = neighborSum ./ neighborCount;

        % Fill NaNs where neighbors exist
        fillable = nanMask & neighborCount > 0;
        Z(fillable) = neighborMean(fillable);

        %% Fit 2D gaussian

        % [p_fit, within] = Fit2DGaussian_RF(Z, ...
        %     cell2mat(RF_table.uniXPos(i_rec)), cell2mat(RF_table.uniYPos(i_rec)), cell2mat(RF_table.meanXYpos(i_rec)));
        % 
        % RF_table.p_fit{i_rec} = p_fit;
        % 
        % [x_center_pix, y_center_pix, x_pix, y_pix] = DrawEllipseRF_fromGaussian2D(p_fit, Z, RF_table, i_rec);
        % 
        % RF_table.FitCenter_pix{i_rec} = [x_center_pix, y_center_pix];
        % RF_table.FitEllipseX_pix{i_rec} = x_pix;
        % RF_table.FitEllipseY_pix{i_rec} = y_pix;
        % 
        % x_center_mm = pix2mm(x_center_pix - windowWidth/2);
        % y_center_mm = pix2mm(y_center_pix - windowHeight/2);
        % 
        % x_mm = pix2mm(x_pix - windowWidth/2);
        % y_mm = pix2mm(y_pix - windowHeight/2);
        % 
        % x_center_deg = pix2deg(x_center_pix - windowWidth/2);
        % y_center_deg = pix2deg(y_center_pix - windowHeight/2);
        % 
        % x_deg = pix2deg(x_pix - windowWidth/2);
        % y_deg = pix2deg(y_pix - windowHeight/2);
        % 
        % plot(x_deg, -y_deg, 'LineWidth', 2, 'Color', [0 0 0]); axis equal


        % plot(x_pix, flipud(y_pix), 'LineWidth', 2, 'Color', [0 0 0 0.1]); axis equal
        % xlim([0 windowWidth])
        % ylim([0 windowHeight])

        %%
        % Connected component analysis based on largest group
        CC = bwconncomp(Z, 4);
        % Remove groups smaller than 3 pixels
        minSize = 3;
        cluster_sizes = cellfun(@numel, CC.PixelIdxList);
        keep_idx = find(cluster_sizes >= minSize);
        % Select largest remaining cluster
        [~, max_i] = max(cluster_sizes(keep_idx));
        best_idx = keep_idx(max_i);

        %%
        if ~isempty(best_idx)
            clean_mask = zeros(size(rawRFmap_Threshold));
            clean_mask(CC.PixelIdxList{best_idx}) = 1;

            for iX = 1:size(clean_mask,1)
                for iY = 1:size(clean_mask,2)
                    if clean_mask(iX,iY) == 1
                        clean_mask(iX,iY) = rawRFmap_Threshold(iX,iY);
                    end
                end
            end

            if sum(clean_mask, "all") == 0
                RF_table.EllipseFit(i_rec) = 0;
            else
                RF_table.EllipseFit(i_rec) = 1;

                clean_mask(clean_mask > 0) = 1;

                Counter = 1; %for each spike, reproduce the xPosition and yPosition of the stimulus.

                xVal = reshape(RF_table.meanXYpos{i_rec}(:, 1), numel(RF_table.uniYPos{i_rec}), numel(RF_table.uniXPos{i_rec}));
                yVal = reshape(RF_table.meanXYpos{i_rec}(:, 2), numel(RF_table.uniYPos{i_rec}), numel(RF_table.uniXPos{i_rec}));
                for xthPos = 1:size(clean_mask,2)
                    for ythPos = 1:size(clean_mask,1)
                        nSpikes = clean_mask(ythPos,xthPos);
                        if 0 <= nSpikes
                            for ithSpike = 1:nSpikes
                                xPositions(Counter) = xVal(1,xthPos);
                                yPositions(Counter) = yVal(ythPos,1);
                                Counter = Counter+1;
                            end
                        end
                    end
                end

                x = xVal(1,:);
                y = yVal(:,1);

                xPeak = sum(x .* sum(clean_mask,1)) / sum(clean_mask(:));
                yPeak = sum(y .* sum(clean_mask,2)) / sum(clean_mask(:));

                Mu = [xPeak,yPeak];

                %substract mean
                xPositions = xPositions - xPeak;
                yPositions = yPositions - yPeak;
                SpikeLocations = [xPositions; yPositions]';

                %eigen decomposition [sorted by eigen values]
                scale = sqrt(chi2inv(0.9,2));     %inverse chi-squared with dof=#dimensions

                Cov = cov(SpikeLocations);
                [eigenVectors, eigenValues] = eig(Cov);

                radians = linspace(0,2*pi,100);
                circle = [cos(radians) ; sin(radians)];        %unit circle
                scaledEigenValues = sqrt(eigenValues)*scale; %Scale the eigenvalues, they will now equal the 'radii' of the minor & major axes
                scaledEigenVectors = eigenVectors*scaledEigenValues; %scale the eigenvectors accordingly
                ellipse = bsxfun(@plus, scaledEigenVectors*circle, Mu'); %project circle onto ellipse

                %% Save parameters
                uniXPos = unique(xVal);
                uniYPos = unique(yVal);
                ellipse_deg = [pix2deg(ellipse(1,:)-WindowCenter(1)); pix2deg(WindowCenter(2)-ellipse(2,:))];
                % ellipse_deg = [pix2deg(ellipse(1,:)-WindowCenter(1)); pix2deg(-WindowCenter(2)+ellipse(2,:))];
                area = polyarea(ellipse_deg(1,:), ellipse_deg(2,:));
                plot(ellipse_deg(1, :), ellipse_deg(2, :), 'LineWidth', 2, 'Color', [1 0 0]);
            end
                xlim([-25 25])
                ylim([-20 20])
                plot([0 0], [-20 20], 'color', [1 1 1])
                plot([-25 25], [0 0], 'color', [1 1 1])
            %%
            PathStr = strsplit(unit_table.Paths{rec}, '\\');
            Monkey = PathStr{2};
            if ~(strcmp(Monkey, 'Jim') | strcmp(Monkey, 'Clay'))
                error('The monkey is not Jim or Clay')
            end

            savePath = ['P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\RF_analysis\RFPlots\', Monkey, '\', ROI, '\'];
            FigureSaveName = ['RF_', datestr(unit_table.Date(i_rec), 'yyyymmdd')];
            % saveas(fig, [savePath FigureSaveName '.fig' ]);
            print(fig, [savePath, FigureSaveName ], '-dpng', '-painters', '-r300');
            close all
            clear xPositions yPositions
        end
    end
end


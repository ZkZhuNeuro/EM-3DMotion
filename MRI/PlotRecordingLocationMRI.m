function PlotRecordingLocationMRI(OrigPoint_Voxel, Img_nii, ROI_nii_file, hole, depth, tetrode, ROI_intensity, color_mat, intensity_labels, fig_handle,ML_Offset)
%% Plot a single or multiple recording locations onto a given MRI image. For coronal MRI sections only.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Input Variables
% OrigPoint_Voxel: The center of your grid in MRI voxels
% Img_nii: MRI image file
% ROI_nii_file: ROI mapping file
% hole: hole on the grid. Can be n x 2 matrix or single row vector.
% depth: depth of the recording (including guide tube)
% tetrode: tetrode number if applicable - assumes TT 1 is the tip and will
% be equal to your depth value. All other tetrodes are 0.3 mm above this.
% ROI_intensity: intensity values of the ROI locations to include on image
% color_mat: n x 3 array of colors for each ROI
% intensity_labels: Cell array of labels for your ROI locations
% fig_handle: optional figure handle to plot this in. Multiple figures are
% needed if you want to plot on multiple AP slices (AP hole values). The
% number of figures should be equal to the number of unique AP holes.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % E.g., for CLAY: 
% colorsteps = hsv(10);
% intensity_labels = []
% PlotRecordingLocationMRI([125,206,70], 'P:\MRI\R14008_GridScan\R14008_T1W_brain_Org2AvgGrid.nii.gz','P:\MRI\R14008_GridScan\R14008_LEV00_ROIs_org2Grid.nii.gz', [20,24],20+14,1,[24,25,38,46,55],colorsteps,intensity_labels)
% Jim:
% PlotRecordingLocationMRI(OrigPoint_Voxel, Img_nii, ROI_nii_file, [19,19], recording_offset(1)+23.5, 1, [28,24], colorsteps, intensity_labels)
%% Begin code
AP_holes = unique(hole(:,2)); % unique AP slices for figure

% Some checks
if nargin >= 10
    if length(fig_handle) < length(AP_holes)
        error('If you provide a figure handle, the number of figure handles must equal the number of unique AP hole locations');
    end
end
if nargin<11
    ML_Offset = [0 0 0];
end
if size(color_mat,1) < length(ROI_intensity)
    error('Your color matrix should contain as many rows as ROI intensity values');
end
if ~isempty(intensity_labels) && length(intensity_labels)<length(ROI_intensity)
    error('If you provide intensity labels, there must be as many labels as ROI intensity values');
end

f = 0;
% Do this for each AP slice
for slice = AP_holes
    f = f+1;
    AP_Voxel = OrigPoint_Voxel(3) - ((29-slice)*0.8)*2; 
    holes_to_plot = find(hole(:,2) == slice); % all holes on this AP slice
    
    % Get the ML and  depth values for each relevant hole
    GoalHole_Left = hole(holes_to_plot,:);
    GoalDepth = depth(holes_to_plot);
    GoalTetrode = tetrode(holes_to_plot);
    ML_Voxel = [];
    Depth_Voxel = [];
    for i = 1:size(GoalHole_Left,1)
        h = GoalHole_Left(i,:);
        %Estimate the location in MRI
        if h(2) >= 5 && h(2) <= 35
            if mod(h(2),2) == 1
                if h(1)>0 % Left
                    ML_Voxel(i) = OrigPoint_Voxel(1) - ((h(1)-1)*0.8+1.4)*2; % The first hole is only 1.4mm away from center. Multiply the hole number by 0.8mm, since that is the distance for each (we subtract 1 because the first hole is only 1.4mm away). *2 for voxel transformation
                else % Right
                    ML_Voxel(i) = OrigPoint_Voxel(1) + ((abs(h(1))-1)*0.8+1.4)*2;
                end
            else
                if h(1)>0 % Left
                    ML_Voxel(i) = OrigPoint_Voxel(1) - ((h(1)-1)*0.8+1.8)*2;
                else % Right
                    ML_Voxel(i) = OrigPoint_Voxel(1) + ((abs(h(1))-1)*0.8+1.8)*2;
                end
            end
        else
            error('Coming Soon!')
        end
        Depth_Voxel(i) = 256 - (OrigPoint_Voxel(2) - 2*(GoalDepth(i) - (GoalTetrode(i)-1)*0.3)) + 2*ML_Offset(3); % 0.3 mm between tetrodes
    end
    ML_Voxel = ML_Voxel + (ML_Offset(1)*2);
    AP_Index = AP_Voxel +1;
    ML_Index = ML_Voxel + 1; % add 1 because voxel 0 corresponds to index 1!
    
    Img_nii = load_nii(Img_nii); % Load structural image
    Image = Img_nii.img(:,:, round(AP_Index)); % Take slice based on AP position
    Image = fliplr(imrotate(Image, 90)); % Rotate properly
    ROI = load_nii(ROI_nii_file); % Load ROI file
    ROI = ROI.img(:,:,round(AP_Index)); % Take slice based on AP position
    ROI = double(ROI); % Sometimes this is stored as uint8 which won't work
    ROI = fliplr(imrotate(ROI,90)); % Flip to match coordinate conventions of these images (one is opposite...can't remember which)
    
    if nargin >= 10
        ax = fig_handle(f); hold on;
    else
        ax = figure; hold on;
    end
    
    if ~isinteger(Image)
        Image = mat2gray(Image); % Fix non integer values so that we can grey scale things and remove all the extra black ink
    end
    Image(Image == 0) = 255; % Get rid of all the black outside the brain to save ink
    [I,J] = find(Image ~=255);
    h=imshow(Image,'InitialMagnification',1000); hold on;
    for r = 1:length(ROI_intensity)
        % Add colors for each ROI area
        slice_ROI = ROI;
        slice_ROI(slice_ROI ~= ROI_intensity(r) ) = 0;
        slice_ROI(slice_ROI == ROI_intensity(r) ) = 1;
        color = cat(3, ones(size(Image)).*color_mat(r,1), ones(size(Image)).*color_mat(r,2), ones(size(Image)).*color_mat(r,3));
        hG(r) = imshow(color,'InitialMagnification',500); 
        set(hG(r), 'AlphaData', 1*slice_ROI); % Color code the area
        ROI_legend_points(r) = plot(NaN,NaN,'MarkerFaceColor',color_mat(r,:));
    end
    scatter(ML_Index, Depth_Voxel,15,'go','filled','MarkerEdgeColor','k');
    if ~isempty(intensity_labels)
        legend(ROI_legend_points,intensity_labels); % Are you labeling your intensities?
    else
        legend('off');
    end
    
    if GoalHole_Left(:,1) < 0 % zoom right side
        xlim([256/2,max(J)]);
    elseif GoalHole_Left(:,1) > 0 % zoom left side
        xlim([min(J),256/2]);
    end
    ylim([min(I), max(I)]);
    
    if length(depth) == 1
        title(['Grid Hole: <' num2str(GoalHole_Left(1)) ',' num2str(GoalHole_Left(2)) '>'],'FontSize',12);
    else
        title(['Grid Hole AP: ', num2str(slice)]);
    end
    hold off;
end
end
clear
load('RF_table_20240703.mat')

%%
ecc = [];
row = [];
col = [];
GT = [];
depth = [];
RF = {};
xVal = {};
yVal = {};
offset = [];
for i_unit = 1:size(RF_table, 1)
    if ~isempty(RF_table.RFCenter_char{i_unit}) && strcmp(RF_table.ROI{i_unit}, 'FST')
        ch = RF_table.StimElec(i_unit);
        loc_all = RF_table.RFCenter_char{i_unit};
        loc = str2num(loc_all{ch});
        ecc = [ecc, sqrt(loc * loc')];
        col = [col, RF_table.Hole(i_unit, 1)];
        row = [row, RF_table.Hole(i_unit, 2)];
        GT = [GT; RF_table.Guide(i_unit)];
        depth = [depth; RF_table.Depth(i_unit)];
        RF = [RF; RF_table.rawRFmap{i_unit}(ch)];
        xVal = [xVal; RF_table.uniXPos{i_unit}(ch)];
        yVal = [yVal; RF_table.uniYPos{i_unit}(ch)];
        offset = [offset; RF_table.Offset(i_unit, :)];
    end
end

%%
% figure();
% scatter(row, ecc)

%%
row_unique = unique(row);

for i_row = row_unique
    row_idx = find(row == i_row);
    col_row = col(row_idx);
    row_row = ones(size(col_row)) * i_row;
    GT_row = GT(row_idx);
    depth_row = depth(row_idx);
    offset_row = offset(row_idx, :);
    RF_row = RF(row_idx);
    xVal_row = xVal(row_idx);
    yVal_row = yVal(row_idx);
    [h, ML_Index, Depth_Voxel] = PlotRecordingLocation_JimFST([col_row', row_row'], GT_row, depth_row, offset_row);
    
    hold on;
%     PlotRecordingLocation_JimFST([21,21;22,21], [27; 27], [10; 10], [0 0 0; 0 0 0])
    for i_rec = 1:size(ML_Index, 2)
        h;
        scatter(ML_Index(i_rec), Depth_Voxel(i_rec),15,'go','filled','MarkerEdgeColor','k', 'ButtonDownFcn', @Callback);
    end
end


function Callback(dot, ~)
windowWidth = 1920; %(pixels)
windowHeight = 1080; %(pixels)

ML_Index = evalin('base', 'ML_Index');
Depth_Voxel = evalin('base', 'Depth_Voxel');
RF_row = evalin('base', 'RF_row');
xVal_row = evalin('base', 'xVal_row');
yVal_row = evalin('base', 'yVal_row');


idx = find(ML_Index == dot.XData & Depth_Voxel == dot.YData);
RF_rec = RF_row{idx};
xVal_rec = xVal_row{idx};
yVal_rec = yVal_row{idx};
figure()
imagesc(xVal_rec(:), yVal_rec(:), RF_rec); colormap('parula');
axis on;
axis square;
caxis([min(RF_rec(:)) max(RF_rec(:))]); hold on;
xlim([min(xVal_rec(:)),max(xVal_rec(:))]); ylim([min(yVal_rec(:)),max(yVal_rec(:))]);
hold on
plot([min(xVal_rec(:)),max(xVal_rec(:))], [windowHeight/2, windowHeight/2], 'Color', [1 1 1], 'LineWidth', 2)
plot([windowWidth/2, windowWidth/2], [min(yVal_rec(:)),max(yVal_rec(:))], 'Color', [1 1 1], 'LineWidth', 2)
% set(gca, 'XTick', XTick4map, 'YTick', YTick4map, 'FontSize', Tick_FontSize);
% set(gca, 'XTickLabel', num2cell(XTick4map_deg), 'box', 'on')
% set(gca, 'YTickLabel', num2cell(YTick4map_deg), 'TickDir', 'out', 'Layer', 'top')
% set(gca,'YDir','reverse');
% title(ROI, 'FontSize', 10);
end
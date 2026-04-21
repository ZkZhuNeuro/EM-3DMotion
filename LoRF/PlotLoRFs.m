clear
load("P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\LoRFs\LoRFTable.mat")
load("P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\LoRFs\LoRFData.mat")
amt_cross = 0;
amt_FST = 0;
% figure();

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
% for i_neuron = 700:720
for i_neuron = 1:size(AllRFTable, 1)
    if strcmp(AllRFTable.ROI{i_neuron}, 'FST') & AllRFTable.Hole(i_neuron) > 0
        %%
        % ---- parameters (replace with yours) ----
        amt_FST = amt_FST + 1; 
        rawRFmap = AllRFData.rawData{i_neuron};
        % [c_x,c_y,s_x,s_y,PeakOD,DC] = Gaussian2D(rawRFmap,1*10^-10);
        DC = AllRFData.FitParams(i_neuron, 6);
        PeakOD = AllRFData.FitParams(i_neuron, 5);
        c_x = AllRFData.Center_Deg(i_neuron, 1);
        c_y = AllRFData.Center_Deg(i_neuron, 2);
        s_x = AllRFData.Sigmas_Deg(i_neuron, 1);
        s_y = AllRFData.Sigmas_Deg(i_neuron, 1);

        % ---- make grid ----
        [x,y] = meshgrid(linspace(-5,5,300), linspace(-5,5,300));

        % ---- evaluate function ----
        Z = DC + abs(PeakOD).*exp( ...
            -0.5*(x-c_x).^2./(s_x^2) ...
            -0.5*(y-c_y).^2./(s_y^2));

        % ---- 2D plot ----

        % imagesc(x(1,:), y(:,1), Z)
        theta = linspace(0,2*pi,200);
        % figure();
        % axis xy equal tight
        % xlabel('x (deg)')
        % ylabel('y (deg)')
        % title('FST RF fits')
        % hold on
        % 
        % plot(c_x + s_x*cos(theta), c_y + s_y*sin(theta), ...
        %     'Color', [0 0 0 0.1],  'LineWidth',2)

        if any(c_x + s_x*cos(theta) < -2)
            amt_cross = amt_cross + 1;
            fig = figure();
            rawRF = AllRFData.rawData{i_neuron};
            rawRF = flipud(rawRF);
            imagesc(rawRF)
            hold on
            x_c_scale = (mm2pix(tan(c_x/180 * pi + s_x/180 * pi*cos(theta)) * viewingDistance) + AllRFData.WindowCenter(i_neuron, 1) - AllRFData.xtickmarks(i_neuron, 1)) ...
                ./ (AllRFData.xtickmarks(i_neuron, end) - AllRFData.xtickmarks(i_neuron, 1));
            x_c_plot = size(AllRFData.rawData{i_neuron}, 2) * x_c_scale; 
            y_c_scale = (AllRFData.ytickmarks(i_neuron, end) - (-mm2pix(tan(c_y/180 * pi + s_y/180 * pi*sin(theta)) * viewingDistance) + AllRFData.WindowCenter(i_neuron, 2))) ...
                ./ (AllRFData.ytickmarks(i_neuron, end) - AllRFData.ytickmarks(i_neuron, 1));
            y_c_plot = size(AllRFData.rawData{i_neuron}, 1) * y_c_scale;

            mid_x = windowWidth / 2;
            x_mid_scale = (mid_x - AllRFData.xtickmarks(i_neuron, 1)) ./ (AllRFData.xtickmarks(i_neuron, end) - AllRFData.xtickmarks(i_neuron, 1));
            x_mid_plot = size(AllRFData.rawData{i_neuron}, 2) * x_mid_scale; 

            plot(x_c_plot, y_c_plot, ...
                'Color', [0 0 0],  'LineWidth',2)
            plot([x_mid_plot x_mid_plot], [0.5 size(AllRFData.rawData{i_neuron}, 1) + 0.5], ...
                'Color', [1 0 0],  'LineWidth',2)
            axis xy equal tight
            xlabel('x (deg)')
            ylabel('y (deg)')
            xticks(0:size(AllRFData.rawData{i_neuron}, 2)/9:size(AllRFData.rawData{i_neuron}, 2))
            yticks(0:size(AllRFData.rawData{i_neuron}, 1)/9:size(AllRFData.rawData{i_neuron}, 1))
            xticklabels(AllRFData.xtick_deg(i_neuron, :))
            yticklabels(fliplr(AllRFData.ytick_deg(i_neuron, :)))
            FigureSaveName = ['FST_', num2str(i_neuron)];
            print(fig, ['P:\Codes\Matlab\offlineAnalysis\3DMotionAnalysis\Stimulation\John_analysis_try\LoRFs\FST_CrossVertical\', FigureSaveName ], '-dpng', '-painters', '-r300');
            close all
        end

    end
end
% figure()
% plot([0 0], [-20 50], 'k')
% xlim([-20 30])
% ylim([-20 40])
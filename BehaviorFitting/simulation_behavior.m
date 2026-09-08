% MATLAB script to plot cumulative Gaussian curves
colorsteps =  [254 191 15;...
    0 0 0;...
    234 0 233;...
    110 205 221]./255;
% Define the x-axis range
x = linspace(-1, 1, 1000);  % 1000 points from -1.5 to 1.5

% Parameters for the Gaussian curves (mean and standard deviation)
mu = 0.4;  % mean
% mu = 0;  % mean
sigma1 = 0.2;  % standard deviation for first curve
sigma2 = 0.25;  % standard deviation for second curve
sigma3 = 0.30;  % standard deviation for third curve
sigma4 = 0.35;

% Compute cumulative Gaussian curves
y1 = 0.5 * (1 + erf((x - mu+0.2) / (sigma1 * sqrt(2))));
y2 = 0.5 * (1 + erf((x - mu+0.1) / (sigma2 * sqrt(2))));
y3 = 0.5 * (1 + erf((x - mu) / (sigma3 * sqrt(2))));
y4 = 0.5 * (1 + erf((x - mu) / (sigma4 * sqrt(2))));

% Plot the curves
figure('Renderer', 'painters', 'Position', [100 100 900 600]); hold on;
line([0 0], ylim, 'LineStyle','--','Color',[0 0 0]*0.8, 'LineWidth', 2);
line(xlim, [0.5 0.5], 'LineStyle','--','Color',[0 0 0]*0.8, 'LineWidth', 2);
axis square;
xticks(-1:0.5:1)
xticklabels({'-1', 'Away', '0', 'Towards', '1'})
xtickangle(0)
ylim([0 1]);
yticks([0 0.5 1])
plot(x, y1, 'color', colorsteps(2, :), 'LineWidth', 4);  % First curve in black
plot(x, y2, 'color', colorsteps(3, :), 'LineWidth', 4);  % Second curve in blue
plot(x, y3, 'color', colorsteps(1, :), 'LineWidth', 4);  % Third curve in green
plot(x, y4, 'color', colorsteps(4, :), 'LineWidth', 4);  % Third curve in green
a = get(gca,'XTickLabel');
set(gca,'XTickLabel',a,'fontsize',30)
b = get(gca,'YTickLabel');
set(gca,'YTickLabel',b,'fontsize',30)
% title('Neuron tuning curve', 'FontSize', 20)
% ylabel('Proportion Chose Towards', 'FontSize', 30);
xlabel('Coherence', 'FontSize', 30);
set(gca,'linewidth',3)
hold off;

% Set axis limits


% Customize plot appearance
% xlabel('Away                        Toward');
% ylabel('Proportion Chose Toward');
% set(gca, 'XTick', [-1, 0, 1], 'XTickLabel', {'Away', '0', 'Toward'}, 'YTick', [0, 0.5, 1], 'YTickLabel', {'0', '0.5', '1'});
% grid on;

% Add dashed lines for reference
% line([0 0], ylim, 'Color', 'k', 'LineStyle', '--');  % Vertical dashed line
% line(xlim, [0.5 0.5], 'Color', 'k', 'LineStyle', '--');  % Horizontal dashed line

% Display the plot
% title('Cumulative Gaussian Curves');

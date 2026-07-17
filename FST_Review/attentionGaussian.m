%% Approximate histogram data extracted from screenshots
% Shared bin centers from 0 to 1
x_bin = 0.025:0.05:0.975;

%% First screenshot: four ROC-area histograms
y_green1 = [0 0 0 0 0 0 0.016 0.089 0.106 0.203 ...
            0.886 0.959 1.000 0.569 0.236 0.179 0.106 0.057 0.098 0.146];

y_blue1  = [0 0 0 0 0 0 0 0 0.145 0.365 ...
            0.824 0.962 1.000 0.434 0.233 0.145 0.132 0.101 0.025 0];

y_green2 = [0 0 0 0 0 0 0 0 0.245 0.434 ...
            1.000 0.986 0.944 0.755 0.643 0.357 0.112 0 0 0];

y_blue2  = [0 0 0 0 0 0 0 0 0.041 0.311 ...
            1.000 0.943 0.779 0.525 0.238 0.148 0 0 0 0];

%% Second screenshot: two added histograms
% Approximate, colors ignored and merged into one histogram per panel

% Before
y_before = [0 0 0 0 0 0 0.02 0.04 0.08 0.35 ...
            0.65 1.00 0.90 0.72 0.50 0.18 0.08 0 0 0];

% During
y_during = [0 0 0 0 0 0.02 0.10 0.28 0.52 0.72 ...
            1.00 0.78 0.48 0.32 0.10 0 0 0 0 0];

Y = {
    y_green1
    y_blue1
    y_green2
    y_blue2
    y_before
    y_during
};

panel_names = {
    ''
    ''
    ''
    ''
    'Before'
    'During'
};

%% Plot six Gaussian envelopes with less-flat subplot shape
figure;
set(gcf, 'Color', 'w', 'Position', [200 200 500 650]);

x_fit = linspace(0, 1, 500);

tiledlayout(3, 2, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

for i = 1:6
    y = Y{i};

    % Normalize histogram heights as weights
    w = y ./ sum(y);

    % Weighted Gaussian parameters
    mu = sum(x_bin .* w);
    sigma = sqrt(sum(w .* (x_bin - mu).^2));

    % Gaussian envelope
    g = exp(-0.5 * ((x_fit - mu) ./ sigma).^2);
    g = g ./ max(g);

    nexttile;
    hold on;

    plot(x_fit, g, 'k-', 'LineWidth', 2);
    xline(0.5, 'k--', 'LineWidth', 1);

    xlim([0 1]);
    ylim([0 1.1]);

    box off;
    yticks([]);

    set(gca, ...
        'TickDir', 'out', ...
        'LineWidth', 1, ...
        'FontSize', 10);

    % Make axes shape less flat
    pbaspect([1.6 1 1]);   % width : height : depth

    if ~isempty(panel_names{i})
        title(panel_names{i}, ...
            'FontWeight', 'normal', ...
            'FontSize', 10);
    end

    % Only label bottom row
    if i <= 4
        xticklabels([]);
    else
        xlabel('ROC area');
    end
end
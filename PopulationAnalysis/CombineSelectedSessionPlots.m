function combined_manifest = CombineSelectedSessionPlots( ...
    slope_threshold, bias_threshold, tuning_folder, location_folder, output_folder)
% Combine tuning/behavior and recording-location plots for selected sessions.
%
% Sessions are selected from PlotSessionBiasVsSlopeChange using:
%   CombinedSlopeChange < slope_threshold
%   AbsMeanBiasChange < bias_threshold
%   MaxAbsBiasChange <= bias_threshold
%
% The source figures are stacked vertically at their native resolution so
% plot labels and MRI annotations remain readable and are not resampled.

if nargin < 1 || isempty(slope_threshold)
    slope_threshold = -0.5;
end
if nargin < 2 || isempty(bias_threshold)
    bias_threshold = 0.5;
end
if nargin < 3 || isempty(tuning_folder)
    tuning_folder = 'C:\EM\allSessions';
end
if nargin < 4 || isempty(location_folder)
    location_folder = 'C:\EM\RecordingLocationPlots';
end
if nargin < 5 || isempty(output_folder)
    output_folder = fullfile(fileparts(mfilename('fullpath')), ...
        'CombinedSessionPlots_CombinedSlope_MaxCueBias');
end

if ~isfolder(tuning_folder)
    error('Tuning/behavior folder not found: %s', tuning_folder);
end
if ~isfolder(location_folder)
    error('Recording-location folder not found: %s', location_folder);
end
if ~isfolder(output_folder)
    mkdir(output_folder);
end

[summary_fig, session_table] = PlotSessionBiasVsSlopeChange();
close(summary_fig);

keep_session = session_table.CombinedSlopeChange < slope_threshold & ...
    session_table.AbsMeanBiasChange < bias_threshold & ...
    session_table.MaxAbsBiasChange <= bias_threshold;
selected_sessions = sortrows(session_table(keep_session, :), 'Date');

if isempty(selected_sessions)
    error(['No sessions satisfy slope < %.3g, absolute mean bias < %.3g, ' ...
        'and maximum absolute cue bias <= %.3g.'], ...
        slope_threshold, bias_threshold, bias_threshold);
end

session_count = height(selected_sessions);
tuning_plot = strings(session_count, 1);
location_plot = strings(session_count, 1);
combined_plot = strings(session_count, 1);

for session_idx = 1:session_count
    date_text = char(string(selected_sessions.Date(session_idx), 'yyyy-MM-dd'));
    monkey = char(selected_sessions.Monkey(session_idx));
    roi = char(selected_sessions.ROI(session_idx));

    tuning_pattern = sprintf('*_%s_%s_%s_stim*.png', monkey, roi, date_text);
    tuning_match = dir(fullfile(tuning_folder, tuning_pattern));
    assert_one_match(tuning_match, 'tuning/behavior', tuning_pattern, tuning_folder);

    monkey_location_folder = fullfile(location_folder, monkey);
    location_pattern = sprintf('%s_%s_%s_Hole_*.png', monkey, roi, date_text);
    location_match = dir(fullfile(monkey_location_folder, location_pattern));
    assert_one_match(location_match, 'recording-location', ...
        location_pattern, monkey_location_folder);

    tuning_path = fullfile(tuning_match.folder, tuning_match.name);
    location_path = fullfile(location_match.folder, location_match.name);
    output_name = regexprep(tuning_match.name, '_stim\d+\.png$', '_combined.png');
    output_path = fullfile(output_folder, output_name);

    tuning_image = read_rgb_png(tuning_path);
    location_image = read_rgb_png(location_path);
    combined_image = stack_images_vertically(tuning_image, location_image);
    imwrite(combined_image, output_path, 'png');

    tuning_plot(session_idx) = string(tuning_path);
    location_plot(session_idx) = string(location_path);
    combined_plot(session_idx) = string(output_path);
end

combined_manifest = selected_sessions;
combined_manifest.TuningBehaviorPlot = tuning_plot;
combined_manifest.RecordingLocationPlot = location_plot;
combined_manifest.CombinedPlot = combined_plot;

manifest_path = fullfile(output_folder, 'combined_session_manifest.csv');
writetable(combined_manifest, manifest_path);

fprintf('Created %d combined session plots in:\n%s\n', session_count, output_folder);

end


function assert_one_match(matches, plot_type, pattern, source_folder)
if isempty(matches)
    error('No %s plot matched "%s" in %s.', plot_type, pattern, source_folder);
end
if numel(matches) > 1
    error('%d %s plots matched "%s" in %s.', ...
        numel(matches), plot_type, pattern, source_folder);
end
end


function rgb = read_rgb_png(file_path)
[raw_image, color_map, alpha] = imread(file_path);

if ~isempty(color_map)
    rgb = uint8(round(255 .* ind2rgb(raw_image, color_map)));
elseif ismatrix(raw_image)
    rgb = repmat(to_uint8(raw_image), 1, 1, 3);
else
    rgb = to_uint8(raw_image(:, :, 1:3));
end

if ~isempty(alpha)
    alpha = double(alpha) ./ double(intmax(class(alpha)));
    alpha = repmat(alpha, 1, 1, 3);
    rgb = uint8(round(double(rgb) .* alpha + 255 .* (1 - alpha)));
end
end


function output = to_uint8(input)
if isa(input, 'uint8')
    output = input;
elseif isinteger(input)
    output = uint8(round(double(input) .* (255 / double(intmax(class(input))))));
elseif islogical(input)
    output = uint8(input) .* 255;
else
    output = uint8(round(255 .* max(0, min(1, double(input)))));
end
end


function combined = stack_images_vertically(top_image, bottom_image)
outer_padding = 24;
section_gap = 32;
separator_height = 2;

top_height = size(top_image, 1);
top_width = size(top_image, 2);
bottom_height = size(bottom_image, 1);
bottom_width = size(bottom_image, 2);

content_width = max(top_width, bottom_width);
canvas_width = content_width + 2 * outer_padding;
canvas_height = top_height + bottom_height + ...
    2 * outer_padding + section_gap + separator_height;
combined = uint8(255 .* ones(canvas_height, canvas_width, 3));

top_x = outer_padding + floor((content_width - top_width) / 2) + 1;
top_y = outer_padding + 1;
combined(top_y:(top_y + top_height - 1), ...
    top_x:(top_x + top_width - 1), :) = top_image;

separator_y = top_y + top_height + floor(section_gap / 2);
combined(separator_y:(separator_y + separator_height - 1), ...
    (outer_padding + 1):(canvas_width - outer_padding), :) = 210;

bottom_x = outer_padding + floor((content_width - bottom_width) / 2) + 1;
bottom_y = top_y + top_height + section_gap + separator_height;
combined(bottom_y:(bottom_y + bottom_height - 1), ...
    bottom_x:(bottom_x + bottom_width - 1), :) = bottom_image;
end

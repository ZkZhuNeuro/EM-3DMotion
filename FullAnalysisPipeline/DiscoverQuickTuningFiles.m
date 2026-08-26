function sources = DiscoverQuickTuningFiles( ...
    recordingFolder, quick3DSource, recordingDate)
%DISCOVERQUICKTUNINGFILES Resolve exact 3D Quick and 2D Quick file pairs.

arguments
    recordingFolder (1, 1) string
    quick3DSource
    recordingDate (1, 1) datetime
end

if ~isfolder(recordingFolder)
    error('QuickTuningCleaning:MissingRecordingFolder', ...
        'Recording folder does not exist: %s', recordingFolder);
end

threeDNames = normalizeNames(quick3DSource);
threeDPair = resolveProvidedPair(recordingFolder, threeDNames, ...
    "3DMotionQuick");
twoDPair = discoverTwoDPair(recordingFolder, recordingDate);

sources = struct();
sources.ThreeD = makeSourceStruct(threeDPair, "3DQuick", ...
    "Offline_3DMotion_NoSaccade_v1_081421");
if contains(lower(twoDPair(1)), "lateralmotion")
    extractor = "Offline_LateralMotion_Separate";
    taskVariant = "LateralMotion";
else
    extractor = "Offline_Rapid2D_v1_051822";
    taskVariant = "2DMotionQuick";
end
sources.TwoD = makeSourceStruct(twoDPair, taskVariant, extractor);
end


function names = normalizeNames(values)
if iscell(values)
    names = string(values);
elseif ischar(values) || isstring(values)
    names = string(values);
else
    error('QuickTuningCleaning:InvalidQuickNames', ...
        'The 3D Quick source must contain filename text.');
end
names = strip(names(:)');
names = names(strlength(names) > 0);
end


function pair = resolveProvidedPair(folder, names, requiredTag)
if isempty(names)
    error('QuickTuningCleaning:Missing3DQuickName', ...
        'No 3D Quick filename is stored for this session.');
end
if numel(names) > 2
    error('QuickTuningCleaning:TooMany3DQuickNames', ...
        'Expected one TInfo name or one TInfo/SelIndex pair.');
end

resolved = strings(size(names));
for index = 1:numel(names)
    resolved(index) = resolveFile(folder, names(index));
end
isSelection = contains(lower(resolved), "selindex");
if numel(resolved) == 2
    if nnz(isSelection) ~= 1
        error('QuickTuningCleaning:Invalid3DQuickPair', ...
            'The provided pair must contain exactly one SelIndex file.');
    end
    tInfoPath = resolved(~isSelection);
    selIndexPath = resolved(isSelection);
else
    tInfoPath = resolved;
    if contains(lower(tInfoPath), "selindex")
        error('QuickTuningCleaning:Missing3DQuickTInfo', ...
            'The stored 3D Quick name points only to a SelIndex file.');
    end
    stem = regexprep(tInfoPath, '(?i)_TInfo\.mat$', '');
    candidate = stem + "_SelIndex.mat";
    if isfile(candidate)
        selIndexPath = candidate;
    else
        selIndexPath = findStemMatchedSelection(folder, tInfoPath);
    end
end
if ~contains(lower(tInfoPath), lower(requiredTag))
    error('QuickTuningCleaning:Wrong3DQuickFile', ...
        'Stored Quick TInfo does not contain %s: %s', requiredTag, tInfoPath);
end
pair = [tInfoPath selIndexPath];
end


function path = resolveFile(folder, name)
if isfile(name)
    info = dir(name);
    path = string(fullfile(info.folder, info.name));
else
    candidate = fullfile(folder, name);
    if ~isfile(candidate)
        error('QuickTuningCleaning:MissingSourceFile', ...
            'Source file does not exist: %s', candidate);
    end
    info = dir(candidate);
    path = string(fullfile(info.folder, info.name));
end
end


function selectionPath = findStemMatchedSelection(folder, tInfoPath)
files = dir(fullfile(folder, '*.mat'));
names = string({files.name});
selectionMask = contains(lower(names), "selindex");
targetStem = normalizedStem(string(tInfoPath));
candidateStems = arrayfun(@normalizedStem, names(selectionMask));
match = find(strcmpi(candidateStems, targetStem));
if numel(match) ~= 1
    error('QuickTuningCleaning:MissingStemMatchedSelection', ...
        'Expected one stem-matched SelIndex for %s; found %d.', ...
        tInfoPath, numel(match));
end
selectionFiles = files(selectionMask);
selectionPath = string(fullfile( ...
    selectionFiles(match).folder, selectionFiles(match).name));
end


function pair = discoverTwoDPair(folder, recordingDate)
files = dir(fullfile(folder, '*.mat'));
names = string({files.name});
lowerNames = lower(names);
isTInfo = contains(lowerNames, "tinfo");
isSelection = contains(lowerNames, "selindex");
isLateral = contains(lowerNames, "lateralmotion");
isRapid = contains(lowerNames, "2dmotion");
taskMask = isLateral | isRapid;

tInfoIndices = find(taskMask & isTInfo & ~isSelection);
selectionIndices = find(taskMask & isSelection);
maximumCandidates = numel(tInfoIndices) * numel(selectionIndices);
candidates = repmat(struct('TInfoIndex', 0, 'SelectionIndex', 0, ...
    'Score', 0, 'Time', 0), maximumCandidates, 1);
candidateCount = 0;
for tIndex = tInfoIndices(:)'
    tStem = normalizedStem(names(tIndex));
    for sIndex = selectionIndices(:)'
        if strcmpi(tStem, normalizedStem(names(sIndex)))
            expectedLateral = recordingDate < datetime(2022, 5, 12);
            candidateIsLateral = isLateral(tIndex);
            score = 100 * (expectedLateral == candidateIsLateral) + ...
                20 * contains(lowerNames(tIndex), "mua") + ...
                10 * (candidateIsLateral || ...
                contains(lowerNames(tIndex), "2dmotionquick"));
            candidateCount = candidateCount + 1;
            candidates(candidateCount) = struct( ...
                'TInfoIndex', tIndex, 'SelectionIndex', sIndex, ...
                'Score', score, 'Time', files(tIndex).datenum);
        end
    end
end
candidates = candidates(1:candidateCount);
if isempty(candidates)
    error('QuickTuningCleaning:Missing2DQuickPair', ...
        ['No stem-matched LateralMotion or 2DMotion TInfo/SelIndex ' ...
        'pair was found in %s.'], folder);
end
[~, order] = sortrows([-[candidates.Score]', -[candidates.Time]']);
best = candidates(order(1));
pair = [string(fullfile(files(best.TInfoIndex).folder, ...
    files(best.TInfoIndex).name)), ...
    string(fullfile(files(best.SelectionIndex).folder, ...
    files(best.SelectionIndex).name))];
end


function stem = normalizedStem(path)
[~, name, extension] = fileparts(path);
stem = regexprep(lower(string(name) + string(extension)), ...
    '(?i)_(tinfo|selindex)\.mat$', '');
end


function source = makeSourceStruct(pair, variant, extractor)
source = struct();
source.TInfoFile = pair(1);
source.SelIndexFile = pair(2);
source.FileNames = {char(extractFileName(pair(1))), ...
    char(extractFileName(pair(2)))};
source.Variant = variant;
source.Extractor = extractor;
end


function name = extractFileName(path)
[~, stem, extension] = fileparts(path);
name = string(stem) + string(extension);
end

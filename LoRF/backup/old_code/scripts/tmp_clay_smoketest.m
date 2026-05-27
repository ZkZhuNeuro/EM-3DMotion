base = 'P:\Clay\NeuroData\20210803';
summaryFile = 'C:\Users\zzhu329\Documents\GitHub\EM-3DMotion\LoRF\tmp_clay_smoketest_summary.txt';
logfid = fopen(summaryFile, 'w');
cleanupObj = onCleanup(@() fclose(logfid)); %#ok<NASGU>

files = dir(fullfile(base, '*.mat'));
names = {files.name};
lowerNames = lower(names);
perUnitMask = ~cellfun(@isempty, regexp(lowerNames, 'sparsenoise_\d+_\d+\.mat$', 'once'));
matched = names(perUnitMask);
if isempty(matched)
    fprintf(logfid, 'No per-unit SparseNoise waveform files found in %s\n', base);
    return
end
pickedFile = matched{1};
fprintf(logfid, 'Picked waveform file: %s\n', pickedFile);

[nevName, rawRippleIdx] = findSparseNoiseNevLocal(base);
[ttNum, sortedNum] = parseSparseNoiseUnitNameLocal(pickedFile);
unitIDs = getWaveformUnitIDsLocal(base, pickedFile);
fprintf(logfid, 'Parsed TT=%g sorted=%g unitIDs=%s rawRippleIdx=%g nev=%s\n', ttNum, sortedNum, mat2str(unitIDs), rawRippleIdx, nevName);

T = table();
T.Date = datetime(2021, 8, 3);
T.ROI = {'FST'};
T.Hole = {[NaN NaN]};
T.Depth = NaN;
T.Offset = {[]};
T.Guide = {''};
T.StimLoc = {[]};
T.Paths = {[base filesep]};
T.Names = {{pickedFile}};
T.NevNames = {{nevName}};
T.Folder_Index = 1;
T.RawRippleIdx = rawRippleIdx;

[targetRawRFmap, uniXPos, uniYPos, meanXYpos, FRbyTrial, Baseline] = RFMappingFunction_Lo_Clay(T, 1, 1, 'Clay smoke test 20210803', unitIDs(1));

fprintf(logfid, 'rawRFmap size: %s\n', mat2str(size(targetRawRFmap)));
finiteVals = targetRawRFmap(isfinite(targetRawRFmap));
fprintf(logfid, 'rawRFmap nonzero count: %d\n', nnz(targetRawRFmap ~= 0 & isfinite(targetRawRFmap)));
if isempty(finiteVals)
    fprintf(logfid, 'rawRFmap finite min/max: none\n');
else
    fprintf(logfid, 'rawRFmap finite min/max: %g / %g\n', min(finiteVals), max(finiteVals));
end
frMeans = nan(numel(FRbyTrial),1);
for i = 1:numel(FRbyTrial)
    if ~isempty(FRbyTrial{i})
        frMeans(i) = mean(FRbyTrial{i}, 'omitnan');
    end
end
finiteFrMeans = frMeans(isfinite(frMeans));
if isempty(finiteFrMeans)
    fprintf(logfid, 'FRbyTrial finite mean range: none\n');
else
    fprintf(logfid, 'FRbyTrial finite mean range: %g / %g\n', min(finiteFrMeans), max(finiteFrMeans));
end
fprintf(logfid, 'Baseline mean: %g\n', mean(Baseline, 'omitnan'));

function [nev_filename, rawRippleFolderIdx] = findSparseNoiseNevLocal(baseRecordingPath)
nev_filename = [];
rawRippleFolderIdx = 0;
topNev = dir(fullfile(baseRecordingPath, '*.nev'));
rawRippleNev = dir(fullfile(baseRecordingPath, 'RawRipple', '*.nev'));
rawRippleSpacedNev = dir(fullfile(baseRecordingPath, 'Raw Ripple', '*.nev'));
rippleDataNev = dir(fullfile(baseRecordingPath, 'RippleData', '*.nev'));
allNev = [topNev; rawRippleNev; rawRippleSpacedNev; rippleDataNev];
if isempty(allNev)
    allNev = dir(fullfile(baseRecordingPath, '**', '*.nev'));
end
allNames = {allNev.name};
lowerNevNames = lower(allNames);
nevMatches = allNev(contains(lowerNevNames, 'sparsenoise'));
if isempty(nevMatches)
    error('No SparseNoise NEV found in %s', baseRecordingPath);
end
matchNames = {nevMatches.name};
runNums = nan(numel(matchNames), 1);
for iName = 1:numel(matchNames)
    tok = regexp(matchNames{iName}, '(?i)sparsenoise0*(\d+)\.nev$', 'tokens', 'once');
    if ~isempty(tok)
        runNums(iName) = str2double(tok{1});
    end
end
if any(isfinite(runNums))
    maxRun = max(runNums(isfinite(runNums)));
    keepIdx = find(runNums == maxRun, 1, 'last');
else
    keepIdx = numel(nevMatches);
end
chosenNev = nevMatches(keepIdx);
nev_filename = chosenNev.name;
chosenFolder = strrep(chosenNev.folder, '/', '\');
if contains(lower(chosenFolder), '\rawripple') || contains(lower(chosenFolder), '\raw ripple')
    rawRippleFolderIdx = 1;
elseif contains(lower(chosenFolder), '\rippledata')
    rawRippleFolderIdx = 2;
else
    rawRippleFolderIdx = 3;
end
end

function [ttNum, sortedNum] = parseSparseNoiseUnitNameLocal(fileName)
tok = regexp(fileName, '(?i)tt(\d+).*sorted-(\d+)', 'tokens', 'once');
if isempty(tok)
    ttNum = NaN; sortedNum = NaN;
else
    ttNum = str2double(tok{1}); sortedNum = str2double(tok{2});
end
end

function unitIDs = getWaveformUnitIDsLocal(pathName, fileName)
S = load(string(fullfile(pathName, fileName)));
RawSpikes = extractWaveformSpikeMatrixLocal(S);
unitIDs = unique(RawSpikes(:, 2));
unitIDs(unitIDs == 0) = [];
unitIDs = unitIDs(:)';
end

function RawSpikes = extractWaveformSpikeMatrixLocal(S)
if isfield(S, 'Raw1') && isnumeric(S.Raw1) && ismatrix(S.Raw1) && size(S.Raw1, 2) >= 3
    RawSpikes = S.Raw1; return
end
candidates = {};
fieldNames = fieldnames(S);
for iField = 1:numel(fieldNames)
    candidates = [candidates, collectWaveformCandidatesLocal(S.(fieldNames{iField}))]; %#ok<AGROW>
end
scores = cellfun(@scoreWaveformCandidateLocal, candidates);
[~, bestIdx] = max(scores);
RawSpikes = candidates{bestIdx};
end

function candidates = collectWaveformCandidatesLocal(value)
candidates = {};
if isnumeric(value) && ismatrix(value) && size(value, 2) >= 3
    candidates = {value}; return
end
if ~isstruct(value), return, end
subFields = fieldnames(value);
for iSub = 1:numel(subFields)
    candidates = [candidates, collectWaveformCandidatesLocal(value.(subFields{iSub}))]; %#ok<AGROW>
end
end

function score = scoreWaveformCandidateLocal(candidate)
if isempty(candidate) || size(candidate, 2) < 3
    score = -inf; return
end
score = min(size(candidate, 1) / 1000, 5);
col2 = candidate(:, 2);
col3 = candidate(:, 3);
if all(isfinite(col2))
    score = score + 3;
    if all(abs(col2 - round(col2)) < 1e-6), score = score + 4; end
    if all(col2 >= 0), score = score + 1; end
    nonzeroUnits = unique(col2(col2 ~= 0));
    if numel(nonzeroUnits) <= 32, score = score + 3; end
end
if all(isfinite(col3))
    score = score + 2;
    if nnz(diff(col3) >= 0) >= max(numel(col3) - 1, 0) * 0.95, score = score + 6; end
end
end

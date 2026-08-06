function prepared = prepare_lodata_fisher_inputs(sourceFile,outputDirectory,forceRebuild)
%PREPARE_LODATA_FISHER_INPUTS Build decoder arrays from the aligned LoData tables.
%
% NeuroResp contains one stimulus-duration firing rate for every available
% trial/block, arranged as condition x signed coherence x repeat. The
% NeuroType labels were matched to MIDTable using the paper's sig_Anova_CLR
% and Z_quad criteria. This function converts those cells into the common
% numeric arrays expected by replicate_fisher_decoder.

arguments
    sourceFile (1,:) char = 'C:\LoData\NeuroRespUnitTable.mat'
    outputDirectory (1,:) char = fullfile(fileparts(mfilename('fullpath')),'FisherDecoderInputs')
    forceRebuild (1,1) logical = false
end

prepared.metadataFile = fullfile(outputDirectory,'AllMonkeyMIDTable_FisherDecoder.mat');
prepared.dataFiles.Jim.MT = fullfile(outputDirectory,'Jim_MT_FisherDecoderInput.mat');
prepared.dataFiles.Jim.FST = fullfile(outputDirectory,'Jim_FST_FisherDecoderInput.mat');
prepared.dataFiles.Clay.MT = fullfile(outputDirectory,'Clay_MT_FisherDecoderInput.mat');
prepared.dataFiles.Clay.FST = fullfile(outputDirectory,'Clay_FST_FisherDecoderInput.mat');

allOutputs = [{prepared.metadataFile}, ...
    {prepared.dataFiles.Jim.MT,prepared.dataFiles.Jim.FST, ...
     prepared.dataFiles.Clay.MT,prepared.dataFiles.Clay.FST}];
if ~forceRebuild && prepared_cache_is_current(allOutputs,prepared.metadataFile)
    fprintf('Using prepared Fisher decoder inputs in %s\n',outputDirectory);
    return
end

assert(isfile(sourceFile),'LoData response source not found: %s',sourceFile);
if ~isfolder(outputDirectory)
    mkdir(outputDirectory);
end

fprintf('Loading aligned trial-response table: %s\n',sourceFile);
source = load_decoder_source(sourceFile);
required = {'Monkey','ROI','TT','Unit','NeuroResp','NeuroType'};
missing = setdiff(required,source.Properties.VariableNames);
assert(isempty(missing),'Response table is missing: %s',strjoin(missing,', '));

% The 213 Figure 5 neurons consist of MT 2D=80, MT 3D=9, FST 2D=66,
% and FST 3D=58. Include the additional 95 "2Donly" neurons requested for
% the follow-up analysis. They have significant monocular direction tuning
% but no significant combined-cue direction tuning.
included = source.NeuroType == "2D" | source.NeuroType == "3D" | ...
    source.NeuroType == "2Donly";
source = source(included,:);
assert(height(source)==308 && nnz(source.NeuroType=="2Donly")==95, ...
    'Expected 213 Figure 5 plus 95 2D-only neurons, but found %d total.', ...
    height(source));

Monocularity_Aligned = NaN(height(source),1);
Z_quad = NaN(height(source),1);
for row = 1:height(source)
    response = source.NeuroResp{row};
    validate_response(response,row);
    meanResponse = mean(response,3,'omitnan');
    leftMaximum = max(meanResponse(2,:),[],'omitnan');
    rightMaximum = max(meanResponse(3,:),[],'omitnan');
    denominator = leftMaximum + rightMaximum;
    if isfinite(denominator) && denominator ~= 0
        % This is equivalent to the final Monocularity_Aligned definition
        % for both monkeys: positive means the right eye is dominant.
        Monocularity_Aligned(row) = (rightMaximum-leftMaximum)/denominator;
    else
        Monocularity_Aligned(row) = 0;
    end
    if ismember('StoredMonocularityAligned',source.Properties.VariableNames)
        storedOD = source.StoredMonocularityAligned(row);
        assert(sign(storedOD)==sign(Monocularity_Aligned(row)) || ...
            (storedOD==0 && Monocularity_Aligned(row)==0), ...
            'Stored/reconstructed dominant-eye mismatch at source row %d.',row);
        Monocularity_Aligned(row) = storedOD;
    end
    if source.NeuroType(row) == "2D"
        Z_quad(row) = 4;
    elseif source.NeuroType(row) == "3D"
        Z_quad(row) = 2;
    else
        Z_quad(row) = 5;
    end
end

AllMonkeyMIDTable = table(string(source.Monkey),string(source.ROI), ...
    true(height(source),1),Z_quad,Monocularity_Aligned,source.TT,source.Unit, ...
    source.NeuroType,repmat("MIDTable.Monocularity_Aligned",height(source),1), ...
    'VariableNames',{'Monkey','ROI','sig_Anova_CLR','Z_quad', ...
    'Monocularity_Aligned','Tetrode','Unit','NeuroType','ODSource'});
save(prepared.metadataFile,'AllMonkeyMIDTable');

monkeys = {'Jim','Clay'};
areas = {'MT','FST'};
for monkeyIndex = 1:numel(monkeys)
    monkey = monkeys{monkeyIndex};
    for areaIndex = 1:numel(areas)
        area = areas{areaIndex};
        rows = strcmp(string(source.Monkey),monkey) & strcmp(string(source.ROI),area);
        population = source(rows,:);
        assert(~isempty(population),'No rows found for %s/%s.',monkey,area);

        maxTrials = 0;
        for neuron = 1:height(population)
            response = population.NeuroResp{neuron};
            for condition = 1:4
                for coherence = 1:13
                    maxTrials = max(maxTrials,nnz(~isnan(response(condition,coherence,:))));
                end
            end
        end
        firingRates = NaN(height(population),4,13,1,maxTrials);
        trialNum = zeros(height(population),4,13);
        for neuron = 1:height(population)
            response = population.NeuroResp{neuron};
            for condition = 1:4
                for coherence = 1:13
                    values = reshape(response(condition,coherence,:),1,[]);
                    values = values(~isnan(values));
                    nTrials = numel(values);
                    if nTrials > 0
                        firingRates(neuron,condition,coherence,1,1:nTrials) = values;
                    end
                    trialNum(neuron,condition,coherence) = nTrials;
                end
            end
        end

        Coherence = [-22 -14 -10 -8 -4 -2 0 2 4 8 10 14 22]/22; %#ok<NASGU>
        responseDefinition = ['NeuroResp: spike count divided by stimulus duration; ' ...
            'condition x coherence x trial/block']; %#ok<NASGU>
        filename = prepared.dataFiles.(monkey).(area);
        save(filename,'firingRates','trialNum','Coherence','responseDefinition','-v7.3');
        fprintf('Prepared %s/%s: %d neurons, up to %d trials\n', ...
            monkey,area,height(population),maxTrials);
    end
end

fprintf('Prepared Fisher decoder inputs in %s\n',outputDirectory);
end

function source = load_decoder_source(sourceFile)
s = load(sourceFile);
if isfield(s,'NeuroRespUnitTable')
    responseTable = s.NeuroRespUnitTable;
    metadataFile = fullfile(fileparts(sourceFile),'MIDTable.mat');
    assert(isfile(metadataFile),'Current MIDTable not found: %s',metadataFile);
    m = load(metadataFile,'MIDTable');
    metadata = m.MIDTable;
    assert(height(responseTable)==height(metadata), ...
        'NeuroRespUnitTable and MIDTable heights differ.');
    aligned = datetime(responseTable.Date)==datetime(metadata.Date) & ...
        strcmp(string(responseTable.ROI),string(metadata.ROI)) & ...
        responseTable.Unit==metadata.Unit;
    assert(all(aligned),'NeuroRespUnitTable and MIDTable are not row-aligned.');

    source = metadata;
    source.NeuroResp = responseTable.NeuroResp;
    source.TT = source.Tetrode;
    source.StoredMonocularityAligned = source.Monocularity_Aligned;
    source.NeuroType = repmat("unincluded",height(source),1);
    source.NeuroType(logical(source.sig_Anova_CLR) & source.Z_quad==4) = "2D";
    source.NeuroType(logical(source.sig_Anova_CLR) & source.Z_quad==2) = "3D";
    twoDOnly = ~logical(source.sig_Anova2_Combined) & ...
        logical(source.sig_Anova2_MonoL) & logical(source.sig_Anova2_MonoR) & ...
        source.Z_quad==4;
    source.NeuroType(twoDOnly) = "2Donly";
elseif isfield(s,'NeuroRespByNeuronTable')
    source = s.NeuroRespByNeuronTable;
else
    error('Source must contain NeuroRespUnitTable or NeuroRespByNeuronTable.');
end
end

function current = prepared_cache_is_current(allOutputs,metadataFile)
current = all(cellfun(@isfile,allOutputs));
if ~current
    return
end
try
    cached = load(metadataFile,'AllMonkeyMIDTable');
    T = cached.AllMonkeyMIDTable;
    current = height(T)==308 && nnz(T.Z_quad==5)==95 && ...
        ismember('ODSource',T.Properties.VariableNames) && ...
        all(T.ODSource=="MIDTable.Monocularity_Aligned");
catch
    current = false;
end
end

function validate_response(response,row)
assert(isnumeric(response) && ndims(response)==3, ...
    'NeuroResp row %d must be condition x coherence x repeat.',row);
assert(size(response,1)>=4 && size(response,2)==13, ...
    ['NeuroResp row %d has size %s; expected at least the four decoder ' ...
    'conditions x 13 coherences x repeats.'], ...
    row,mat2str(size(response)));
end

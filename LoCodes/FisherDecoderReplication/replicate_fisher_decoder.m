function results = replicate_fisher_decoder(cfg)
%REPLICATE_FISHER_DECODER Run pooled and monkey-separated FLD analyses.
%
% The implementation follows FLDModels_Area_Quadrant.m and FLDModels.m:
%   1. Select significant 2D- or 3D-selective neurons in MT/FST.
%   2. Relabel monocular conditions by each neuron's dominant eye.
%   3. Sample 20 pseudo-trials with replacement per neuron/condition/coherence.
%   4. Train a Fisher discriminant on combined-cue toward versus away data.
%   5. Test the fixed weights on all four cue conditions using two-fold CV.
%   6. Repeat 1000 times and compute percentile confidence intervals.

arguments
    cfg (1,1) struct
end

validate_config(cfg);
rng(cfg.randomSeed,'twister');

if ~exist(cfg.outputDirectory,'dir')
    mkdir(cfg.outputDirectory);
end

metadata = load_metadata_table(cfg.metadataFile);
loaded = load_all_populations(cfg,metadata);
if isempty(cfg.signedCoherence)
    firstPopulation = loaded.(cfg.monkeys{1}).(cfg.areas{1});
    cfg.signedCoherence = firstPopulation.signedCoherence;
end

analyses = [{'Pooled'}, cfg.monkeys];
results = struct();
results.config = cfg;
results.generatedAt = datetime('now');

for a = 1:numel(analyses)
    analysisName = analyses{a};
    if cfg.verbose
        fprintf('\n========== %s analysis ==========\n',analysisName);
    end

    for areaIndex = 1:numel(cfg.areas)
        area = cfg.areas{areaIndex};
        if strcmp(analysisName,'Pooled')
            population = concatenate_monkeys(loaded,cfg.monkeys,area);
        else
            population = loaded.(analysisName).(area);
        end

        population = align_dominant_eye(population,cfg);

        for classIndex = 1:numel(cfg.motionClasses)
            classInfo = cfg.motionClasses(classIndex);
            keep = population.metadata.(cfg.significanceVariable) == 1 & ...
                population.metadata.(cfg.classificationVariable) == classInfo.value;
            firingRates = population.firingRates(keep,:,:,:,:);
            trialNum = population.trialNum(keep,:,:);

            if isempty(firingRates)
                warning('No neurons for %s/%s/%s.',analysisName,area,classInfo.name);
                decoder = empty_decoder_result(cfg);
            else
                if cfg.verbose
                    fprintf('%s, %s-selective: N = %d\n',area,classInfo.name,size(firingRates,1));
                end
                decoder = run_fisher_population_decoder(firingRates,trialNum,cfg);
            end
            decoder.nNeurons = size(firingRates,1);
            results.(analysisName).(area).(classInfo.field) = decoder;
        end
    end

    fig = plot_fisher_decoder_results(results.(analysisName),cfg,analysisName);
    if cfg.saveFigures
        exportgraphics(fig,fullfile(cfg.outputDirectory, ...
            sprintf('FisherDecoder_%s.png',analysisName)),'Resolution',300);
        savefig(fig,fullfile(cfg.outputDirectory,sprintf('FisherDecoder_%s.fig',analysisName)));
        if isfield(results.(analysisName).(cfg.areas{1}),'D2Only')
            fig2DOnly = plot_fisher_2donly_results( ...
                results.(analysisName),cfg,analysisName);
            exportgraphics(fig2DOnly,fullfile(cfg.outputDirectory, ...
                sprintf('FisherDecoder_2DOnly_%s.png',analysisName)),'Resolution',300);
            savefig(fig2DOnly,fullfile(cfg.outputDirectory, ...
                sprintf('FisherDecoder_2DOnly_%s.fig',analysisName)));
        end
    end
end

results.summary = summarize_fisher_decoder_results(results, ...
    fullfile(cfg.outputDirectory,'FisherDecoderSummary.csv'));
save(fullfile(cfg.outputDirectory,'FisherDecoderResults.mat'),'results','-v7.3');
fprintf('\nSaved results to %s\n',cfg.outputDirectory);
end

function validate_config(cfg)
required = {'metadataFile','dataFiles','monkeys','areas','nBootstraps', ...
    'nPseudoTrials','nFolds','binStartTimesMs','responseWindowMs'};
for i = 1:numel(required)
    assert(isfield(cfg,required{i}),'Missing configuration field: %s',required{i});
end
assert(isfile(cfg.metadataFile),'Metadata file not found: %s',cfg.metadataFile);
assert(mod(cfg.nPseudoTrials,cfg.nFolds)==0, ...
    'nPseudoTrials must be divisible by nFolds for balanced folds.');
end

function metadata = load_metadata_table(filename)
s = load(filename);
if isfield(s,'AllMonkeyMIDTable')
    metadata = s.AllMonkeyMIDTable;
elseif isfield(s,'MIDTable')
    metadata = s.MIDTable;
else
    error('Metadata file must contain AllMonkeyMIDTable or MIDTable.');
end
assert(istable(metadata),'The metadata variable must be a table.');
end

function loaded = load_all_populations(cfg,metadata)
loaded = struct();
for m = 1:numel(cfg.monkeys)
    monkey = cfg.monkeys{m};
    for a = 1:numel(cfg.areas)
        area = cfg.areas{a};
        filename = cfg.dataFiles.(monkey).(area);
        assert(isfile(filename),'Data file not found: %s',filename);
        s = load(filename);
        assert(isfield(s,'firingRates') && isfield(s,'trialNum'), ...
            '%s must contain firingRates and trialNum.',filename);

        rows = strcmp(string(metadata.Monkey),monkey) & strcmp(string(metadata.ROI),area);
        areaMetadata = metadata(rows,:);
        assert(height(areaMetadata)==size(s.firingRates,1), ...
            ['Metadata/data mismatch for %s/%s: %d table rows but %d neurons. ' ...
             'Check the metadata file and row ordering.'], ...
             monkey,area,height(areaMetadata),size(s.firingRates,1));

        assert(ndims(s.firingRates)==5, ...
            'Expected a 5-D firingRates array in %s.',filename);
        assert(size(s.firingRates,2)>=4 && size(s.firingRates,3)==13, ...
            'Expected at least four conditions and 13 coherences in %s.',filename);

        loaded.(monkey).(area).firingRates = s.firingRates;
        loaded.(monkey).(area).trialNum = s.trialNum;
        loaded.(monkey).(area).metadata = areaMetadata;

        if isempty(cfg.signedCoherence)
            if isfield(s,'Coherence') && numel(s.Coherence)==13
                loaded.(monkey).(area).signedCoherence = s.Coherence(:)';
            elseif isfield(s,'CoherenceArray') && numel(s.CoherenceArray)==13
                loaded.(monkey).(area).signedCoherence = s.CoherenceArray(:)';
            else
                loaded.(monkey).(area).signedCoherence = [];
            end
        end
    end
end
end

function population = concatenate_monkeys(loaded,monkeys,area)
population = loaded.(monkeys{1}).(area);
for m = 2:numel(monkeys)
    next = loaded.(monkeys{m}).(area);
    maxTrials = max(size(population.firingRates,5),size(next.firingRates,5));
    population.firingRates(:,:,:,:,end+1:maxTrials) = NaN;
    next.firingRates(:,:,:,:,end+1:maxTrials) = NaN;
    population.firingRates = cat(1,population.firingRates,next.firingRates);
    population.trialNum = cat(1,population.trialNum,next.trialNum);
    population.metadata = [population.metadata; next.metadata];
end
end

function population = align_dominant_eye(population,cfg)
for neuron = 1:height(population.metadata)
    if population.metadata.(cfg.dominanceVariable)(neuron) > 0
        tempFR = population.firingRates(neuron,2,:,:,:);
        population.firingRates(neuron,2,:,:,:) = population.firingRates(neuron,3,:,:,:);
        population.firingRates(neuron,3,:,:,:) = tempFR;

        tempN = population.trialNum(neuron,2,:);
        population.trialNum(neuron,2,:) = population.trialNum(neuron,3,:);
        population.trialNum(neuron,3,:) = tempN;
    end
end
end

function out = empty_decoder_result(cfg)
out.proportionCorrect = NaN(cfg.nBootstraps,numel(cfg.testConditions),12);
out.meanByMagnitude = NaN(numel(cfg.testConditions),6);
out.ci95ByMagnitude = NaN(numel(cfg.testConditions),6,2);
end

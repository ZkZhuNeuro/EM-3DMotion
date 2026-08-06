function summary = summarize_fisher_decoder_results(results,outputFile)
%SUMMARIZE_FISHER_DECODER_RESULTS Tabulate decoder means and bootstrap CIs.

arguments
    results (1,1) struct
    outputFile (1,:) char = ''
end

if isempty(results.config.signedCoherence)
    magnitudes = 1:6;
else
    magnitudes = sort(unique(abs(results.config.signedCoherence)));
    magnitudes = magnitudes(magnitudes>0);
end

Analysis = strings(0,1);
Area = strings(0,1);
Population = strings(0,1);
Condition = strings(0,1);
NeuronCount = zeros(0,1);
Coherence = zeros(0,1);
MeanCorrect = zeros(0,1);
CI95Low = zeros(0,1);
CI95High = zeros(0,1);

analyses = [{'Pooled'},results.config.monkeys];
for analysisIndex = 1:numel(analyses)
    analysis = analyses{analysisIndex};
    for areaIndex = 1:numel(results.config.areas)
        area = results.config.areas{areaIndex};
        for classIndex = 1:numel(results.config.motionClasses)
            classInfo = results.config.motionClasses(classIndex);
            decoder = results.(analysis).(area).(classInfo.field);
            for conditionIndex = 1:numel(results.config.conditionNames)
                for magnitudeIndex = 1:numel(magnitudes)
                    Analysis(end+1,1) = string(analysis); %#ok<AGROW>
                    Area(end+1,1) = string(area); %#ok<AGROW>
                    Population(end+1,1) = string(classInfo.name); %#ok<AGROW>
                    Condition(end+1,1) = string(results.config.conditionNames{conditionIndex}); %#ok<AGROW>
                    NeuronCount(end+1,1) = decoder.nNeurons; %#ok<AGROW>
                    Coherence(end+1,1) = magnitudes(magnitudeIndex); %#ok<AGROW>
                    MeanCorrect(end+1,1) = decoder.meanByMagnitude(conditionIndex,magnitudeIndex); %#ok<AGROW>
                    CI95Low(end+1,1) = decoder.ci95ByMagnitude(conditionIndex,magnitudeIndex,1); %#ok<AGROW>
                    CI95High(end+1,1) = decoder.ci95ByMagnitude(conditionIndex,magnitudeIndex,2); %#ok<AGROW>
                end
            end
        end
    end
end

AboveChance95 = CI95Low > 0.5;
BelowChance95 = CI95High < 0.5;
summary = table(Analysis,Area,Population,Condition,NeuronCount,Coherence, ...
    MeanCorrect,CI95Low,CI95High,AboveChance95,BelowChance95);

if ~isempty(outputFile)
    writetable(summary,outputFile);
    fprintf('Saved decoder summary to %s\n',outputFile);
end
end


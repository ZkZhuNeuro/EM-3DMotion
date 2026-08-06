function results = correct_saved_coherence_order(resultsFile)
%CORRECT_SAVED_COHERENCE_ORDER Correct ordering and regenerate saved plots.
%
% This does not rerun decoding. Earlier paired summaries were stored from
% high-to-low absolute coherence but plotted against a low-to-high axis.

arguments
    resultsFile (1,:) char = fullfile(fileparts(mfilename('fullpath')), ...
        'FisherDecoderResults','FisherDecoderResults.mat')
end

assert(isfile(resultsFile),'Results file not found: %s',resultsFile);
s = load(resultsFile,'results');
assert(isfield(s,'results'),'File does not contain results.');
results = s.results;

analyses = [{'Pooled'},results.config.monkeys];
for analysisIndex = 1:numel(analyses)
    analysis = analyses{analysisIndex};
    for areaIndex = 1:numel(results.config.areas)
        area = results.config.areas{areaIndex};
        for classIndex = 1:numel(results.config.motionClasses)
            field = results.config.motionClasses(classIndex).field;
            decoder = results.(analysis).(area).(field);
            if isfield(decoder,'magnitudeOrder') && ...
                    strcmp(decoder.magnitudeOrder,'ascending')
                continue
            end
            decoder.pairedBootstrapScores = flip(decoder.pairedBootstrapScores,3);
            decoder.meanByMagnitude = flip(decoder.meanByMagnitude,2);
            decoder.ci95ByMagnitude = flip(decoder.ci95ByMagnitude,2);
            decoder.magnitudeOrder = 'ascending';
            results.(analysis).(area).(field) = decoder;
        end
    end
end

save(resultsFile,'results','-v7.3');
outputDirectory = fileparts(resultsFile);
for analysisIndex = 1:numel(analyses)
    analysis = analyses{analysisIndex};
    fig = plot_fisher_decoder_results(results.(analysis),results.config,analysis);
    exportgraphics(fig,fullfile(outputDirectory, ...
        sprintf('FisherDecoder_%s.png',analysis)),'Resolution',300);
    savefig(fig,fullfile(outputDirectory,sprintf('FisherDecoder_%s.fig',analysis)));
    if isfield(results.(analysis).(results.config.areas{1}),'D2Only')
        fig2DOnly = plot_fisher_2donly_results( ...
            results.(analysis),results.config,analysis);
        exportgraphics(fig2DOnly,fullfile(outputDirectory, ...
            sprintf('FisherDecoder_2DOnly_%s.png',analysis)),'Resolution',300);
        savefig(fig2DOnly,fullfile(outputDirectory, ...
            sprintf('FisherDecoder_2DOnly_%s.fig',analysis)));
    end
end
fprintf('Corrected coherence ordering and replotted %s\n',resultsFile);
end

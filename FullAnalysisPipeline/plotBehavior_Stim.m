function plotBehavior_Stim(pFitResult)
colorsteps = [0 0 0;...
    0 0 255;...
    5 150 5;...
    234 0 233;
    0 100 255;...
    0 255 100]./255;
xRange = -1:0.01:1;

for cond = 1:4
    plotOptions.dataColor = colorsteps(cond,:);
    plotOptions.lineColor = colorsteps(cond,:);
    plotOptions.plotAsymptote  = false;
    pfitPlot(cond) = plotPsych(pFitResult(cond),plotOptions);
end
line(xRange, ones(length(xRange),1)*0.5,'LineStyle','--','Color',[0 0 0]);
line(zeros(length(xRange),1),[0:0.5:100],'LineStyle','--','Color',[0 0 0]);
xlabel('Coherence');
ylabel('Proportion Chose Towards');
xlim([-1,1]);
axis square;
end
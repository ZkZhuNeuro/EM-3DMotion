function plot3DMotionTuning_Stim(Neuro, elec)
colorsteps = [0 0 0;...
    0 0 255;...
    5 150 5;...
    234 0 233;
    0 100 255;...
    0 255 100]./255;
CoherenceArray_no0 = [-22 -14 -10 -8 -4 -2 2 4 8 10 14 22]./22;
CoherenceArray_8 = [-22 -14 -10 -8 8 10 14 22]./22;

tempCh = squeeze(Neuro.Means(:,:,elec));
tempChErr = squeeze(Neuro.SEM(:,:,elec));
validCols = Neuro.Trials.NumTrials(1,:)>0;

if size(tempCh,2) == 12
    CoherenceArray = CoherenceArray_no0;
elseif size(tempCh,2) == 8
    CoherenceArray = CoherenceArray_8;
else
    CoherenceArray = CoherenceArray_no0(1:size(tempCh,2));
end

fr = plot(CoherenceArray(validCols),tempCh(:,validCols),'-o'); % assumes equal trials for each condition (first dim of trial resp)

hold on;
box on;
ylabel('Firing Rate');
xlabel('Coherence');
for cond=1:4
    fr(cond).Color = colorsteps(cond,:);
    fr(cond).MarkerFaceColor = colorsteps(cond,:);
    fr(cond).MarkerEdgeColor = colorsteps(cond,:);
    errorbar(CoherenceArray(validCols),tempCh(cond,validCols),tempChErr(cond,validCols),"LineStyle","none",'Color',colorsteps(cond,:));
end
axis square;
end

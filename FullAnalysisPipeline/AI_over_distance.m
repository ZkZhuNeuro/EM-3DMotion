function AI_over_distance(ChannelMap,Distance,stim_idx,CI,AI,R)

colorsteps = [0 0 0;...
    0 0 255;...
    5 150 5;...
    234 0 233;
    0 100 255;...
    0 255 100]./255;

for c = 1:length(ChannelMap) % for each channel
    p = find(ChannelMap == c);
    relative_dist(c) = Distance(p)-Distance(stim_idx);
end
colororder({'k','r'}); % left and right axis colors
[sorted_dist,inds] = sort(relative_dist);
sorted_auc = squeeze(CI(inds));
yyaxis right
plot(sorted_dist,sorted_auc,'-ro','MarkerFaceColor','r')
ylim([0,1])
ylabel('W')
xlabel('Distance from Stim Elec.');
yyaxis left
for c = 1:size(AI,1)
    plot(sorted_dist, squeeze(AI(c,inds)),'-o','Color',colorsteps(c,:),'MarkerFaceColor',colorsteps(c,:),'MarkerEdgeColor',colorsteps(c,:));
end
% plot(sorted_dist,R.Comb(inds),'-co','MarkerFaceColor','c')
xticks(sorted_dist);
xlim([min(sorted_dist), max(sorted_dist)]);
ylim([-1,1]);
ylabel('AI');
end
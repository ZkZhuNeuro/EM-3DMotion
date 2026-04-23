p_left = [];
p_right = [];
p_comb = [];
ecc = [];
area = {};
for i_unit = 1:size(unit_table, 1)
    p_left(end + 1) = unit_table.p_adjusted{i_unit}(2);
    p_right(end + 1) = unit_table.p_adjusted{i_unit}(3);
    p_comb(end + 1) = unit_table.p_adjusted{i_unit}(1);
    area = [area; unit_table.ROI{i_unit}];
%     loc = unit_table.StimLoc(i_unit, :);
%     ecc(end + 1) = sqrt(loc(1) ^ 2 + loc(2) ^ 2);
    ecc(end + 1) = sqrt(unit_table.StimLoc(i_unit, :) * unit_table.StimLoc(i_unit, :)');

end

N_MT = sum(strcmp(area, 'MT'));
MT_LR_sig = sum(strcmp(area, 'MT') & p_left' < 0.05 & p_right' < 0.05);
MT_LRC_sig = sum(strcmp(area, 'MT') & p_left' < 0.05 & p_right' < 0.05 & p_comb' < 0.05);
MT_LRC_sig_ecc = sum(strcmp(area, 'MT') & p_left' < 0.05 & p_right' < 0.05 & p_comb' < 0.05 & ecc' < 12);
MT_LOrR_sig = sum(strcmp(area, 'MT') & xor(p_left' < 0.05, p_right' < 0.05));


N_FST = sum(strcmp(area, 'FST'));
FST_LR_sig = sum(strcmp(area, 'FST') & p_left' < 0.05 & p_right' < 0.05);
FST_LRC_sig = sum(strcmp(area, 'FST') & p_left' < 0.05 & p_right' < 0.05 & p_comb' < 0.05);
FST_LRC_sig_ecc = sum(strcmp(area, 'FST') & p_left' < 0.05 & p_right' < 0.05 & p_comb' < 0.05 & ecc' < 12);
FST_ecc = sum(strcmp(area, 'FST') & ecc' < 10);
FST_LOrR_sig = sum(strcmp(area, 'FST') & xor(p_left' < 0.05, p_right' < 0.05));





%Plot Option
set(groot, {'DefaultAxesXColor','DefaultAxesYColor','DefaultAxesZColor', 'DefaultTextFontName'}, {'k','k','k', 'Arial'})
set(groot, {'DefaultAxesLineWidth', 'DefaultLineLineWidth'}, {2,2})
set(groot, 'FixedWidthFontName', 'Arial')
plotOptions.MonkeySymbols.Jim = 'o';
plotOptions.MonkeySymbols.Clay = 'd';
plotOptions.MonkeyColors.Jim = [3 206 247]./255; 
plotOptions.MonkeyColors.Clay = [247 44 3]./255;
plotOptions.AreaColors.MT = [226 100 0]./255;  %[237 125 49]./255;
plotOptions.AreaColors.FST = [135 2 214]./255; %[112 48 160]./255;
plotOptions.Conditions.Dom = [255 191 0]./255;
plotOptions.Conditions.NonDom = [0 198 212]./255;
plotOptions.Conditions.Combined = [0 0 0]./255;
plotOptions.Conditions.MonoL = [0 0 255]./255;
plotOptions.Conditions.MonoR = [5 150 5]./255;
plotOptions.Conditions.Bino = [234 0 233]./255;

plotOptions.ExampleNeurons.MT.Date = {'03/06/2019', '04/29/2021','02/15/2019'};
plotOptions.ExampleNeurons.MT.TT = [4, 5, 2];
plotOptions.ExampleNeurons.MT.Unit = [2, 3, 2];

plotOptions.ExampleNeurons.FST.Date = {'09/15/2020', '11/12/2021', '04/29/2021'};
plotOptions.ExampleNeurons.FST.TT = [7, 5, 8];
plotOptions.ExampleNeurons.FST.Unit = [5, 2, 2];

%%%%%%%%%%%%%%%%%%%%%%% ZKZ commented this on 08/03/2023
% for ex = 1:length(plotOptions.ExampleNeurons.MT.Unit)
%     plotOptions.ExampleNeurons.MT.Inx(ex) = find(MIDTable.Date == plotOptions.ExampleNeurons.MT.Date{ex} & MIDTable.Tetrode == plotOptions.ExampleNeurons.MT.TT(ex)...
%         & MIDTable.Unit == plotOptions.ExampleNeurons.MT.Unit(ex));
%     plotOptions.ExampleNeurons.FST.Inx(ex) = find(MIDTable.Date == plotOptions.ExampleNeurons.FST.Date{ex} & MIDTable.Tetrode == plotOptions.ExampleNeurons.FST.TT(ex)...
%         & MIDTable.Unit == plotOptions.ExampleNeurons.FST.Unit(ex));
% end
%%%%%%%%%%%%%%%%%%%%%%%

% matching_unit_beh = datefind(datenum('09/15/2020'),Behavioral_Data.Date);


areas = ["MT", "FST"];

colorsteps = [0 0 0;...
    0 0 255;...
    5 150 5;...
    234 0 233;
    0 100 255;...
    0 255 100]./255;

conditionNames = {'Combined','L Mono','R Mono','Binocular','L Control', 'R Control'};

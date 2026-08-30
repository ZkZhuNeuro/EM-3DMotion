function app = ExploreGaussianMetaPopulationApp(options)
%EXPLOREGAUSSIANMETAPOPULATIONAPP Unified cached population selector.
%
% The app switches among MT/FST, meta-2D/meta-3D, and the three cached
% optimization methods. Max-OD and correlation-OD use separate app instances
% and separate caches.

arguments
    options.ODDefinition (1, 1) string ...
        {mustBeMember(options.ODDefinition, ["Max", "Correlation"])} = "Max"
    options.InitialArea (1, 1) string ...
        {mustBeMember(options.InitialArea, ["MT", "FST"])} = "MT"
    options.InitialUnitType (1, 1) string ...
        {mustBeMember(options.InitialUnitType, ["2D", "3D"])} = "2D"
    options.InitialMethod (1, 1) string ...
        {mustBeMember(options.InitialMethod, ...
        ["CV", "Ordinary", "Distance"])} = "Ordinary"
    options.CacheRoot (1, 1) string = [ ...
        "C:\EM\CurrentSpread\02_gaussian\" + ...
        "InteractiveGaussianMetaPopulation"]
    options.Position (1, 4) double = [60 60 1540 930]
    options.CorrelationFaceAlphaFloor (1, 1) double ...
        {mustBeGreaterThanOrEqual(options.CorrelationFaceAlphaFloor, 0), ...
        mustBeLessThanOrEqual(options.CorrelationFaceAlphaFloor, 1)} = 0
    options.CorrelationEdgeAlpha (1, 1) double ...
        {mustBeGreaterThanOrEqual(options.CorrelationEdgeAlpha, 0), ...
        mustBeLessThanOrEqual(options.CorrelationEdgeAlpha, 1)} = 0.95
end

commonFolder = string(fileparts(mfilename('fullpath')));
interactiveRoot = string(fileparts(commonFolder));
cvFolder = fullfile(interactiveRoot, 'cv_ai_od');
ordinaryFolder = fullfile(interactiveRoot, 'ordinary_ai_od');
distanceFolder = fullfile(interactiveRoot, 'type2_distance');
addpath(interactiveRoot, commonFolder, cvFolder, ordinaryFolder, ...
    distanceFolder);

currentViewer = struct();
currentSelection = struct('Area', options.InitialArea, ...
    'UnitType', options.InitialUnitType, ...
    'Method', options.InitialMethod);
renderSelection(currentSelection);

app = struct();
app.ODDefinition = options.ODDefinition;
app.GetCurrentViewer = @getCurrentViewer;
app.Show = @renderSelection;

    function viewer = getCurrentViewer()
        viewer = currentViewer;
    end

    function renderSelection(selection)
        selection.Area = string(selection.Area);
        selection.UnitType = string(selection.UnitType);
        selection.Method = string(selection.Method);
        previousViewer = currentViewer;
        if isfield(previousViewer, 'Figure') && ...
                isvalid(previousViewer.Figure)
            previousViewer.Figure.Name = sprintf( ...
                'Loading %s %s %s...', selection.Area, ...
                selection.UnitType, methodLabel(selection.Method));
            drawnow
        end

        configuration = loadConfiguration(selection);
        if options.ODDefinition == "Correlation"
            faceAlphaFloor = options.CorrelationFaceAlphaFloor;
            edgeAlpha = options.CorrelationEdgeAlpha;
        else
            faceAlphaFloor = 0;
            edgeAlpha = 0.85;
        end
        newViewer = ExploreInteractiveGaussianMetaPopulation( ...
            CacheFile=configuration.CacheFile, ...
            UnitType=selection.UnitType, ...
            MetricMode=configuration.MetricMode, ...
            MetricPerCue=configuration.MetricPerCue, ...
            ObjectiveValues=configuration.ObjectiveValues, ...
            ObjectiveLabel=configuration.ObjectiveLabel, ...
            InitialSigma=configuration.InitialSigma, ...
            MarkerFaceAlphaFloor=faceAlphaFloor, ...
            MarkerEdgeAlpha=edgeAlpha, ...
            ReserveSelectionRow=true, Visible="off", ...
            Position=options.Position);
        addSelectionControls(newViewer, selection);
        newViewer.Figure.Name = sprintf( ...
            '%s-OD Gaussian-meta population app', options.ODDefinition);
        newViewer.Figure.Visible = 'on';
        currentViewer = newViewer;
        currentSelection = selection;
        if isfield(previousViewer, 'Figure') && ...
                isvalid(previousViewer.Figure)
            close(previousViewer.Figure);
        end
    end

    function addSelectionControls(viewer, selection)
        areaDropDown = uidropdown(viewer.ControlGrid, ...
            'Items', {'Area: MT', 'Area: FST'}, ...
            'ItemsData', {'MT', 'FST'}, 'Value', char(selection.Area), ...
            'Tooltip', 'Select cortical area');
        areaDropDown.Layout.Row = 1;
        areaDropDown.Layout.Column = 1;
        unitDropDown = uidropdown(viewer.ControlGrid, ...
            'Items', {'Population: meta 2D', 'Population: meta 3D'}, ...
            'ItemsData', {'2D', '3D'}, 'Value', char(selection.UnitType), ...
            'Tooltip', 'Select meta-derived unit class');
        unitDropDown.Layout.Row = 1;
        unitDropDown.Layout.Column = 2;
        methodDropDown = uidropdown(viewer.ControlGrid, ...
            'Items', {'Method: CV AI + AI:OD', ...
            'Method: ordinary AI + AI:OD', ...
            'Method: Type-II distance'}, ...
            'ItemsData', {'CV', 'Ordinary', 'Distance'}, ...
            'Value', char(selection.Method), ...
            'Tooltip', 'Select sigma optimization method');
        methodDropDown.Layout.Row = 1;
        methodDropDown.Layout.Column = [3 4];
        areaDropDown.ValueChangedFcn = @selectionChanged;
        unitDropDown.ValueChangedFcn = @selectionChanged;
        methodDropDown.ValueChangedFcn = @selectionChanged;

        function selectionChanged(~, ~)
            nextSelection = struct( ...
                'Area', string(areaDropDown.Value), ...
                'UnitType', string(unitDropDown.Value), ...
                'Method', string(methodDropDown.Value));
            renderSelection(nextSelection);
        end
    end

    function configuration = loadConfiguration(selection)
        areaRoot = options.CacheRoot;
        if options.ODDefinition == "Correlation"
            areaRoot = fullfile(areaRoot, 'CorrelationOD');
        end
        areaRoot = fullfile(areaRoot, selection.Area);
        cacheFile = fullfile(areaRoot, ...
            'GaussianMetaPopulationSigmaCache.mat');
        [objectiveFolder, objectiveFile] = objectivePath( ...
            areaRoot, selection.UnitType, selection.Method);
        if needsBuild(cacheFile, objectiveFile)
            BuildInteractiveGaussianMetaPopulationSuite( ...
                Area=selection.Area, ODDefinition=options.ODDefinition, ...
                OutputRoot=areaRoot, ValidateAgainstBuilder=false);
        end

        configuration = struct();
        configuration.CacheFile = cacheFile;
        switch selection.Method
            case "CV"
                loaded = load(objectiveFile, 'all_cue_r2_optimization');
                objective = loaded.all_cue_r2_optimization;
                configuration.MetricMode = "SumFourCueR2";
                configuration.MetricPerCue = objective.CrossValidatedR2;
                configuration.ObjectiveValues = ...
                    objective.SumFourCueCrossValidatedR2;
                configuration.ObjectiveLabel = ...
                    "Sum of four cue CV R^2: AI + AI:OD";
            case "Ordinary"
                loaded = load(objectiveFile, ...
                    'all_cue_ordinary_r2_optimization');
                objective = loaded.all_cue_ordinary_r2_optimization;
                configuration.MetricMode = "SumFourCueOrdinaryR2";
                configuration.MetricPerCue = objective.PerCueR2;
                configuration.ObjectiveValues = objective.SumFourCueR2;
                configuration.ObjectiveLabel = ...
                    "Sum of four ordinary R^2: AI + AI:OD";
            case "Distance"
                loaded = load(objectiveFile, ...
                    'all_cue_type2_distance_optimization');
                objective = loaded.all_cue_type2_distance_optimization;
                configuration.MetricMode = ...
                    "SumFourCueMeanSquaredDistance";
                configuration.MetricPerCue = ...
                    objective.PerCueMeanSquaredDistance;
                configuration.ObjectiveValues = ...
                    objective.SumFourCueMeanSquaredDistance;
                configuration.ObjectiveLabel = ...
                    "Sum of four cue mean squared distances";
        end
        configuration.InitialSigma = objective.BestSigma;
        configuration.ObjectiveFolder = objectiveFolder;
    end
end


function [folder, fileName] = objectivePath(areaRoot, unitType, method)
switch method
    case "CV"
        folder = fullfile(areaRoot, unitType, 'AllCueR2Optimization');
        fileName = fullfile(folder, ...
            'AllCueR2GaussianMetaOptimization.mat');
    case "Ordinary"
        folder = fullfile(areaRoot, unitType, ...
            'AllCueOrdinaryR2Optimization');
        fileName = fullfile(folder, ...
            'AllCueOrdinaryR2GaussianMetaOptimization.mat');
    case "Distance"
        folder = fullfile(areaRoot, unitType, ...
            'AllCueType2DistanceOptimization');
        fileName = fullfile(folder, ...
            'AllCueType2DistanceGaussianMetaOptimization.mat');
end
end


function value = needsBuild(cacheFile, objectiveFile)
value = ~isfile(cacheFile) || ~isfile(objectiveFile);
if value
    return
end
cacheInfo = dir(cacheFile);
objectiveInfo = dir(objectiveFile);
value = objectiveInfo.datenum < cacheInfo.datenum;
end


function label = methodLabel(method)
switch method
    case "CV"
        label = 'CV AI + AI:OD';
    case "Ordinary"
        label = 'ordinary AI + AI:OD';
    otherwise
        label = 'Type-II distance';
end
end

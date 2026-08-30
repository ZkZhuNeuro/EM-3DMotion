function data = selectGaussianMetaUnitTypeData(cache, unitType)
%SELECTGAUSSIANMETAUNITTYPEDATA Select cached 2D or 3D population arrays.

arguments
    cache (1, 1) struct
    unitType (1, 1) string ...
        {mustBeMember(unitType, ["2D", "3D"])}
end

if isfield(cache, 'Area')
    area = string(cache.Area);
else
    area = "MT";
end

if unitType == "2D"
    pointValid = cache.PointValid;
    statistics = cache.Statistics;
    if isfield(cache, 'PointValid2D')
        pointValid = cache.PointValid2D;
    end
    if isfield(cache, 'Statistics2D')
        statistics = cache.Statistics2D;
    end
else
    if ~isfield(cache, 'PointValid3D') || ~isfield(cache, 'Statistics3D')
        error('GaussianMetaInteractive:CacheMissing3D', ...
            ['The cache does not contain 3D point validity/statistics. ' ...
            'Rebuild it with BuildInteractiveGaussianMetaPopulationCache.']);
    end
    pointValid = cache.PointValid3D;
    statistics = cache.Statistics3D;
end

if ~isequal(size(pointValid), size(cache.PointAI))
    error('GaussianMetaInteractive:PointValiditySize', ...
        'The selected %s validity array does not match PointAI.', unitType);
end

data = struct();
data.Area = area;
data.UnitType = unitType;
data.PointValid = pointValid;
data.Statistics = statistics;
end

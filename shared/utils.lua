HBSFuel = HBSFuel or {}

function HBSFuel.Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

function HBSFuel.Round(value, decimals)
    local power = 10 ^ (decimals or 0)
    return math.floor((value * power) + 0.5) / power
end

function HBSFuel.GetVehicleModelName(vehicle)
    local model = GetEntityModel(vehicle)
    return string.lower(GetDisplayNameFromVehicleModel(model))
end

function HBSFuel.GetTankCapacity(vehicle)
    local modelName = HBSFuel.GetVehicleModelName(vehicle)
    local byModel = VehicleTankSizes[modelName]
    if byModel then
        return byModel
    end

    local class = GetVehicleClass(vehicle)
    return Config.ClassTankSizes[class] or Config.DefaultTankSize
end

function HBSFuel.IsAircraft(vehicle)
    local class = GetVehicleClass(vehicle)
    return class == 15 or class == 16
end

function HBSFuel.CanVehicleBeFuelled(vehicle)
    return DoesEntityExist(vehicle) and HBSFuel.GetTankCapacity(vehicle) > 0.0
end

local function vecDist(a, b)
    return #(a - b)
end

function HBSFuel.IsInPumpExclusionZone(coords)
    if not coords then return false end

    local customZones = Config.PumpExclusionZones or {}
    for i = 1, #customZones do
        local zone = customZones[i]
        if zone.coords and vecDist(coords, zone.coords) <= (zone.radius or 10.0) then
            return true
        end
    end

    if not Config.BlockVehiclePumpUseInRefineryZones then
        return false
    end

    for _, refinery in pairs(Refineries or {}) do
        if refinery.coords and vecDist(coords, refinery.coords) <= (refinery.radius or Config.RefineryPumpExclusionFallbackRadius or 25.0) then
            return true
        end

        local points = refinery.points or {}
        for key, point in pairs(points) do
            if type(point) == 'vector3' then
                if vecDist(coords, point) <= (Config.RefineryPumpExclusionFallbackRadius or 25.0) then
                    return true
                end
            elseif type(point) == 'table' then
                for idx = 1, #point do
                    local subPoint = point[idx]
                    if subPoint and type(subPoint) == 'vector3' and vecDist(coords, subPoint) <= (Config.RefineryPumpExclusionFallbackRadius or 25.0) then
                        return true
                    end
                end
            end
        end
    end

    return false
end

local function isFuelBlockedForVehicle(modelName, class, fuelType)
    local rules = Config.VehicleFuelRules or {}
    local modelBlacklist = rules.ModelBlacklist or {}
    local classBlacklist = rules.ClassBlacklist or {}

    local blockedByModel = modelBlacklist[modelName] or {}
    for i = 1, #blockedByModel do
        if blockedByModel[i] == fuelType then
            return true
        end
    end

    local blockedByClass = classBlacklist[class] or {}
    for i = 1, #blockedByClass do
        if blockedByClass[i] == fuelType then
            return true
        end
    end

    return false
end

function HBSFuel.GetAllowedFuelTypes(vehicle)
    if not DoesEntityExist(vehicle) then return {} end

    local rules = Config.VehicleFuelRules or {}
    local modelName = HBSFuel.GetVehicleModelName(vehicle)
    local class = GetVehicleClass(vehicle)

    local allowed = nil
    local overrides = rules.ModelOverrides or {}
    if overrides[modelName] then
        allowed = overrides[modelName]
    else
        local classDefaults = rules.ClassDefaults or {}
        if classDefaults[class] then
            allowed = classDefaults[class]
        else
            allowed = rules.Default or { Config.DefaultFuelType }
        end
    end

    local filtered = {}
    for i = 1, #allowed do
        local fuelType = allowed[i]
        if not isFuelBlockedForVehicle(modelName, class, fuelType) then
            filtered[#filtered + 1] = fuelType
        end
    end

    return filtered
end

function HBSFuel.CanVehicleUseFuelType(vehicle, fuelType)
    if not DoesEntityExist(vehicle) then return false end
    local fuelData = FuelTypes[fuelType]
    if not fuelData then return false end

    local allowed = HBSFuel.GetAllowedFuelTypes(vehicle)
    for i = 1, #allowed do
        if allowed[i] == fuelType then
            return true
        end
    end

    return false
end

function HBSFuel.GetClosestStation(coords)
    local closestId, closestData, closestDist

    for stationId, station in pairs(Stations) do
        local dist = #(coords - station.coords)
        if not closestDist or dist < closestDist then
            closestId = stationId
            closestData = station
            closestDist = dist
        end
    end

    if closestId and closestDist <= (closestData.radius or 25.0) then
        return closestId, closestData, closestDist
    end

    return nil, nil, nil
end

function HBSFuel.GetSupportedFuelTypes(station)
    return station and station.supports or { Config.DefaultFuelType }
end

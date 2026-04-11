local activeRefuels = {}

local function getStationById(stationId)
    if stationId and StationState[stationId] then
        return StationState[stationId]
    end
    return nil
end

local function stationSupportsFuel(station, fuelType)
    for _, supported in ipairs(station.supports or {}) do
        if supported == fuelType then
            return true
        end
    end

    return false
end

local function getTankerRoleForModel(modelName)
    if not modelName then return nil end
    modelName = string.lower(modelName)
    for role, data in pairs(Config.Tanker.Roles or {}) do
        for i = 1, #(data.models or {}) do
            if modelName == string.lower(data.models[i]) then
                return role
            end
        end
    end
    return nil
end

local function calculatePricePerLitre(station, fuelType)
    local fuel = FuelTypes[fuelType]
    if not fuel then return nil end

    local price = fuel.price * (station and station.priceMultiplier or Config.DefaultStationPriceMultiplier)

    if Config.Features.DynamicPricing and station and station.tanks[fuelType] then
        local tank = station.tanks[fuelType]
        local pct = tank.max > 0 and (tank.current / tank.max) or 0.0
        if pct <= 0.10 then
            price = price * 1.25
        elseif pct <= 0.25 then
            price = price * 1.10
        end
    end

    return HBSFuel.Round(price, 2)
end

local function getOrBuildVirtualStation(stationId)
    if stationId then
        return getStationById(stationId)
    end

    if not Config.AllowUnmappedStations then
        return nil
    end

    return {
        label = 'Generic Fuel Station',
        supports = Config.UnmappedStationSupportedFuelTypes or { Config.DefaultFuelType },
        priceMultiplier = Config.DefaultStationPriceMultiplier,
        emergencyRefill = Config.DefaultStationEmergencyRefill,
        tanks = {
            [Config.DefaultFuelType] = { current = 999999.0, max = 999999.0 }
        }
    }
end

lib.callback.register('hbs-fuel:server:previewRefuel', function(source, stationId, fuelType, litresNeeded, paymentMethod)
    local station = getOrBuildVirtualStation(stationId)
    if not station then
        return { ok = false, message = 'No configured station found.' }
    end

    if not FuelTypes[fuelType] then
        return { ok = false, message = 'Invalid fuel type.' }
    end

    if not stationSupportsFuel(station, fuelType) then
        return { ok = false, message = Config.Notifications.RefuelBlockedWrongFuel }
    end

    local tank = station.tanks[fuelType] or { current = 0.0, max = 0.0 }
    local available = tank.current

    if Config.Features.StationStock and available <= 0.0 then
        if Config.Features.EmergencyAutoRefill and station.emergencyRefill then
            available = tank.max > 0 and tank.max or litresNeeded
            if tank.max > 0 then
                tank.current = tank.max
            end
        elseif Config.AllowFuelWithoutStock then
            available = litresNeeded
        else
            return { ok = false, message = Config.Notifications.RefuelBlockedNoStock }
        end
    end

    local approved = math.min(litresNeeded or 0.0, available)
    local pricePerLitre = calculatePricePerLitre(station, fuelType)
    local totalPrice = HBSFuel.Round(approved * pricePerLitre, 2)

    paymentMethod = (paymentMethod == 'bank' and 'bank') or 'cash'

    if not HBSFuelHasMoney(source, totalPrice, paymentMethod) then
        return { ok = false, message = Config.Notifications.NotEnoughMoney }
    end

    return {
        ok = true,
        approvedLitres = approved,
        pricePerLitre = pricePerLitre,
        totalPrice = totalPrice,
        stationLabel = station.label,
        paymentMethod = paymentMethod,
    }
end)

lib.callback.register('hbs-fuel:server:commitRefuelTick', function(source, stationId, fuelType, litres, paymentMethod)
    litres = tonumber(litres) or 0.0
    if litres <= 0.0 then
        return { ok = false, message = 'Invalid litres.' }
    end

    local station = getOrBuildVirtualStation(stationId)
    if not station then
        return { ok = false, message = 'No configured station found.' }
    end

    if not FuelTypes[fuelType] then
        return { ok = false, message = 'Invalid fuel type.' }
    end

    if not stationSupportsFuel(station, fuelType) then
        return { ok = false, message = Config.Notifications.RefuelBlockedWrongFuel }
    end

    paymentMethod = (paymentMethod == 'bank' and 'bank') or 'cash'

    local approvedLitres = litres
    if Config.Features.StationStock then
        station.tanks[fuelType] = station.tanks[fuelType] or { current = 0.0, max = litres }
        local tank = station.tanks[fuelType]
        if tank.current < approvedLitres and not Config.AllowFuelWithoutStock then
            if Config.Features.EmergencyAutoRefill and station.emergencyRefill then
                tank.current = tank.max
            else
                approvedLitres = math.max(tank.current, 0.0)
            end
        end
    end

    if approvedLitres <= 0.0 then
        return { ok = false, message = Config.Notifications.RefuelBlockedNoStock }
    end

    local pricePerLitre = calculatePricePerLitre(station, fuelType)
    local totalPrice = HBSFuel.Round(approvedLitres * pricePerLitre, 2)

    if not HBSFuelHasMoney(source, totalPrice, paymentMethod) then
        return { ok = false, message = Config.Notifications.NotEnoughMoney }
    end

    if Config.Features.StationStock then
        local tank = station.tanks[fuelType]
        tank.current = math.max(tank.current - approvedLitres, 0.0)
        if stationId then
            SaveStationState(stationId)
        end
    end

    if not HBSFuelRemoveMoney(source, totalPrice, paymentMethod, ('fuel_purchase_%s'):format(fuelType)) then
        return { ok = false, message = Config.Notifications.NotEnoughMoney }
    end

    if stationId and AddOwnerRevenue then
        local ownerCut = (Config.Ownership and Config.Ownership.OwnerRevenueCut or 0.70)
        AddOwnerRevenue('station', stationId, HBSFuel.Round(totalPrice * ownerCut, 2))
    end

    activeRefuels[source] = {
        stationId = stationId,
        fuelType = fuelType,
        litres = (activeRefuels[source] and activeRefuels[source].litres or 0.0) + approvedLitres,
        totalPrice = (activeRefuels[source] and activeRefuels[source].totalPrice or 0.0) + totalPrice,
    }

    return {
        ok = true,
        litres = approvedLitres,
        totalPrice = totalPrice,
        pricePerLitre = pricePerLitre,
    }
end)

lib.callback.register('hbs-fuel:server:startCharging', function(source, stationId, fuelType, litres, paymentMethod)
    litres = tonumber(litres) or 0.0
    if litres <= 0.0 then
        return { ok = false, message = 'Invalid charge amount.' }
    end

    local pricePerLitre = Config.Charging and Config.Charging.PricePerLitre or 1.80
    local totalPrice = HBSFuel.Round(litres * pricePerLitre, 2)
    local intPrice = math.ceil(totalPrice)

    if not HBSFuelHasMoney(source, intPrice, paymentMethod or 'cash') then
        return { ok = false, message = Config.Notifications.NotEnoughMoney }
    end

    if not HBSFuelRemoveMoney(source, intPrice, paymentMethod or 'cash', 'fuel_ev_charge') then
        return { ok = false, message = 'Payment failed.' }
    end

    if stationId and AddOwnerRevenue then
        local ownerCut = (Config.Ownership and Config.Ownership.OwnerRevenueCut or 0.70)
        AddOwnerRevenue('station', stationId, HBSFuel.Round(totalPrice * ownerCut, 2))
    end

    return { ok = true, totalPrice = totalPrice, litres = litres }
end)

lib.callback.register('hbs-fuel:server:unloadTankerToStation', function(_, stationId, plate, litres, modelName)
    litres = tonumber(litres) or 0.0
    if not stationId or not plate or litres <= 0.0 then
        return { ok = false, message = 'Invalid tanker unload.' }
    end

    if getTankerRoleForModel(modelName) ~= 'refined' then
        return { ok = false, message = Config.Notifications.TankerWrongRoleRefined }
    end

    local station = getStationById(stationId)
    if not station then
        return { ok = false, message = 'Station not found.' }
    end

    local load = MySQL.single.await('SELECT fuel_type, litres, max_litres FROM hbs_fuel_tanker_state WHERE plate = ?', { plate })
    if not load or not load.fuel_type or tonumber(load.litres) <= 0.0 then
        return { ok = false, message = 'Tanker is empty.' }
    end

    local fuelType = load.fuel_type
    if fuelType == 'crude' then
        return { ok = false, message = 'Crude must be unloaded at the refinery.' }
    end

    if not stationSupportsFuel(station, fuelType) then
        return { ok = false, message = Config.Notifications.RefuelBlockedWrongFuel }
    end

    station.tanks[fuelType] = station.tanks[fuelType] or { current = 0.0, max = litres }
    local tank = station.tanks[fuelType]
    local free = math.max(tank.max - tank.current, 0.0)
    local tankerLitres = tonumber(load.litres)
    local moved = math.min(litres, tankerLitres, free)
    if moved <= 0.0 then
        return { ok = false, message = 'Station tank is already full.' }
    end

    tank.current = tank.current + moved
    SaveStationState(stationId)
    exports['hbs-fuel']:SetTankerLoad(plate, tankerLitres - moved > 0.01 and fuelType or nil, math.max(tankerLitres - moved, 0.0), tonumber(load.max_litres) or Config.Tanker.DefaultMaxLitres)

    return { ok = true, litres = moved, fuelType = fuelType, stationLevel = tank.current, message = Config.Notifications.TankerUnloaded }
end)

lib.callback.register('hbs-fuel:server:getStationPrice', function(_, stationId)
    local station = getStationById(stationId)
    return station and station.priceMultiplier or 1.0
end)

exports('GetStationStock', function(stationId, fuelType)
    local station = getStationById(stationId)
    return station and station.tanks[fuelType] and station.tanks[fuelType].current or nil
end)

exports('AddStationStock', function(stationId, fuelType, litres)
    local station = getStationById(stationId)
    if not station then return false end

    station.tanks[fuelType] = station.tanks[fuelType] or { current = 0.0, max = litres }
    station.tanks[fuelType].current = math.min(station.tanks[fuelType].current + litres, station.tanks[fuelType].max)
    SaveStationState(stationId)
    return true
end)

CreateThread(function()
    while true do
        Wait(Config.PassiveDemandInterval * 1000)
        if not Config.Features.PassiveDemand or not Config.Features.StationStock then
            goto continue
        end

        for stationId, station in pairs(StationState) do
            for fuelType, tank in pairs(station.tanks or {}) do
                local drain = Config.PassiveDemandBaseLitres * (station.demandMultiplier or 1.0)
                tank.current = math.max(tank.current - drain, 0.0)
            end
            SaveStationState(stationId)
        end

        ::continue::
    end
end)

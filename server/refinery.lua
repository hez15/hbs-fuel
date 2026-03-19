local activeBatches = {}
local refineryValveState = {}

local function getRefinery(refineryId)
    return refineryId and RefineryState[refineryId] or nil
end

local function getTankerMaxLitres(plate)
    local row = MySQL.single.await('SELECT max_litres FROM hbs_fuel_tanker_state WHERE plate = ?', { plate })
    return row and tonumber(row.max_litres) or Config.Tanker.DefaultMaxLitres
end

local function getTankerRoleForModel(modelName)
    if not modelName then return nil end
    modelName = string.lower(modelName)
    for role, data in pairs(Config.Tanker.Roles or {}) do
        for i = 1, #(data.models or {}) do
            if modelName == string.lower(data.models[i]) then
                return role, data
            end
        end
    end
    return nil
end

local function getTankerMaxLitresForRole(role)
    local data = role and Config.Tanker.Roles and Config.Tanker.Roles[role] or nil
    return data and tonumber(data.maxLitres) or Config.Tanker.DefaultMaxLitres
end


exports('AddCrudeToRefinery', function(refineryId, litres)
    local refinery = getRefinery(refineryId)
    if not refinery then return false end

    refinery.crude.current = math.min(refinery.crude.current + litres, refinery.crude.max)
    SaveRefineryState(refineryId)
    return true
end)

exports('ProcessRefineryBatch', function(refineryId)
    local refinery = getRefinery(refineryId)
    if not refinery then return false, 'Invalid refinery.' end
    if activeBatches[refineryId] then return false, 'Batch already running.' end

    local recipe = Config.RefineryRecipes[refinery.recipe]
    if not recipe then return false, 'Recipe missing.' end
    if refinery.crude.current < recipe.input.crude then return false, 'Not enough crude.' end

    refinery.crude.current = refinery.crude.current - recipe.input.crude
    activeBatches[refineryId] = true
    SaveRefineryState(refineryId)

    CreateThread(function()
        Wait(recipe.processTime * 1000)
        for fuelType, amount in pairs(recipe.output) do
            refinery.products[fuelType] = refinery.products[fuelType] or { current = 0.0, max = amount }
            refinery.products[fuelType].current = math.min(refinery.products[fuelType].current + amount, refinery.products[fuelType].max)
        end
        activeBatches[refineryId] = nil
        SaveRefineryState(refineryId)
    end)

    return true
end)

lib.callback.register('hbs-fuel:server:getRefineryData', function(_, refineryId)
    local refinery = getRefinery(refineryId)
    if not refinery then return nil end
    return refinery
end)

lib.callback.register('hbs-fuel:server:openRefineryValve', function(_, refineryId)
    local refinery = getRefinery(refineryId)
    if not refinery then
        return { ok = false, message = 'Refinery not found.' }
    end

    refineryValveState[refineryId] = os.time() + Config.Tanker.ValveOpenSeconds
    return { ok = true, message = Config.Notifications.ValveOpened }
end)

lib.callback.register('hbs-fuel:server:startRefineryBatch', function(_, refineryId)
    local valveExpiry = refineryValveState[refineryId] or 0
    if valveExpiry < os.time() then
        return { ok = false, message = 'Open the valve first.' }
    end

    local ok, reason = exports['hbs-fuel']:ProcessRefineryBatch(refineryId)
    if not ok then
        return { ok = false, message = reason or 'Unable to start batch.' }
    end

    refineryValveState[refineryId] = nil
    return { ok = true, message = 'Refinery batch started.' }
end)

lib.callback.register('hbs-fuel:server:loadCrudeTanker', function(_, plate, litres, modelName)
    litres = tonumber(litres) or 0.0
    if not plate or litres <= 0.0 then
        return { ok = false, message = 'Invalid tanker load.' }
    end

    local role = getTankerRoleForModel(modelName)
    if role ~= 'crude' then
        return { ok = false, message = Config.Notifications.TankerWrongRoleCrude }
    end

    local current = MySQL.single.await('SELECT fuel_type, litres, max_litres FROM hbs_fuel_tanker_state WHERE plate = ?', { plate })
    local maxLitres = current and tonumber(current.max_litres) or getTankerMaxLitresForRole(role)
    local currentFuelType = current and current.fuel_type or nil
    local currentLitres = current and tonumber(current.litres) or 0.0

    if currentFuelType and currentFuelType ~= 'crude' and currentLitres > 0.0 then
        return { ok = false, message = 'Tanker already contains another product.' }
    end

    local free = math.max(maxLitres - currentLitres, 0.0)
    local moved = math.min(litres, free)
    if moved <= 0.0 then
        return { ok = false, message = Config.Notifications.TankerFull }
    end

    local finalLitres = currentLitres + moved
    exports['hbs-fuel']:SetTankerLoad(plate, 'crude', finalLitres, maxLitres)

    return { ok = true, litres = moved, tankerLitres = finalLitres, maxLitres = maxLitres, message = Config.Notifications.TankerLoaded }
end)

lib.callback.register('hbs-fuel:server:unloadCrudeToRefinery', function(_, refineryId, plate, litres)
    litres = tonumber(litres) or 0.0
    local refinery = getRefinery(refineryId)
    if not refinery or not plate or litres <= 0.0 then
        return { ok = false, message = 'Invalid crude unload.' }
    end

    local load = MySQL.single.await('SELECT fuel_type, litres, max_litres FROM hbs_fuel_tanker_state WHERE plate = ?', { plate })
    if not load or load.fuel_type ~= 'crude' or tonumber(load.litres) <= 0.0 then
        return { ok = false, message = Config.Notifications.TankerWrongProduct }
    end

    local tankerLitres = tonumber(load.litres)
    local free = math.max(refinery.crude.max - refinery.crude.current, 0.0)
    local moved = math.min(litres, tankerLitres, free)
    if moved <= 0.0 then
        return { ok = false, message = 'No refinery capacity left for crude.' }
    end

    refinery.crude.current = refinery.crude.current + moved
    SaveRefineryState(refineryId)
    exports['hbs-fuel']:SetTankerLoad(plate, tankerLitres - moved > 0.01 and 'crude' or nil, math.max(tankerLitres - moved, 0.0), tonumber(load.max_litres) or Config.Tanker.DefaultMaxLitres)

    return { ok = true, litres = moved, refineryCrude = refinery.crude.current, message = Config.Notifications.TankerUnloaded }
end)

lib.callback.register('hbs-fuel:server:loadRefinedProduct', function(_, refineryId, plate, fuelType, litres, modelName)
    litres = tonumber(litres) or 0.0
    local refinery = getRefinery(refineryId)
    if not refinery or not plate or litres <= 0.0 then
        return { ok = false, message = 'Invalid fuel load.' }
    end

    local role = getTankerRoleForModel(modelName)
    if role ~= 'refined' then
        return { ok = false, message = Config.Notifications.TankerWrongRoleRefined }
    end

    if fuelType == 'motoroil' or fuelType == 'crude' then
        return { ok = false, message = 'That product is not loaded into a road tanker here.' }
    end

    local product = refinery.products[fuelType]
    if not product or product.current <= 0.0 then
        return { ok = false, message = 'No product available.' }
    end

    local current = MySQL.single.await('SELECT fuel_type, litres, max_litres FROM hbs_fuel_tanker_state WHERE plate = ?', { plate })
    local maxLitres = current and tonumber(current.max_litres) or getTankerMaxLitresForRole(role)
    local currentFuelType = current and current.fuel_type or nil
    local currentLitres = current and tonumber(current.litres) or 0.0

    if currentFuelType and currentFuelType ~= fuelType and currentLitres > 0.0 then
        return { ok = false, message = 'Tanker already contains another product.' }
    end

    local free = math.max(maxLitres - currentLitres, 0.0)
    local moved = math.min(litres, free, product.current)
    if moved <= 0.0 then
        return { ok = false, message = 'No tanker capacity available.' }
    end

    product.current = product.current - moved
    SaveRefineryState(refineryId)
    exports['hbs-fuel']:SetTankerLoad(plate, fuelType, currentLitres + moved, maxLitres)

    return { ok = true, litres = moved, fuelType = fuelType, tankerLitres = currentLitres + moved, message = Config.Notifications.TankerLoaded }
end)

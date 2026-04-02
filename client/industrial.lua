local hoseState = {
    active = false,
    refineryId = nil,
    anchorCoords = nil,
    anchorEntity = nil,
    hoseType = nil,
    prop = nil,
    rope = nil,
}
local remoteHoses = {}
local remoteHoseRopes = {}

local function loadModel(model)
    if type(model) == 'string' then
        model = joaat(model)
    end
    if not IsModelValid(model) then return false end
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        Wait(0)
        if GetGameTimer() > timeout then return false end
    end
    return model
end

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        Wait(0)
        if GetGameTimer() > timeout then return false end
    end
    return true
end

local function playCarryAnim(force)
    local ped = PlayerPedId()
    local anim = Config.NozzleCarryAnim
    if not anim then return end
    if not force and IsEntityPlayingAnim(ped, anim.dict, anim.clip, 3) then return end
    if not loadAnimDict(anim.dict) then return end
    TaskPlayAnim(ped, anim.dict, anim.clip, 2.0, 2.0, -1, anim.flag or 49, 0.0, false, false, false)
end

local function clearHose()
    if hoseState.rope then
        DeleteRope(hoseState.rope)
        hoseState.rope = nil
    end

    if RopeAreTexturesLoaded() then
        RopeUnloadTextures()
    end

    if hoseState.prop and DoesEntityExist(hoseState.prop) then
        DetachEntity(hoseState.prop, true, true)
        SetEntityAsMissionEntity(hoseState.prop, true, true)
        DeleteObject(hoseState.prop)
        DeleteEntity(hoseState.prop)
    end

    if hoseState.anchorEntity and DoesEntityExist(hoseState.anchorEntity) then
        SetEntityAsMissionEntity(hoseState.anchorEntity, true, true)
        DeleteObject(hoseState.anchorEntity)
        DeleteEntity(hoseState.anchorEntity)
    end

    hoseState.prop = nil
    hoseState.anchorEntity = nil
    hoseState.active = false
    hoseState.refineryId = nil
    hoseState.anchorCoords = nil
    hoseState.hoseType = nil

    TriggerServerEvent('hbs-fuel:server:syncHoseReturn')

    local anim = Config.NozzleCarryAnim
    if anim and anim.dict and anim.clip then
        StopAnimTask(PlayerPedId(), anim.dict, anim.clip, 1.0)
    end
    ClearPedSecondaryTask(PlayerPedId())
end

local function createHose(anchorCoords, hoseType, refineryId)
    clearHose()

    local ped = PlayerPedId()
    local nozzleCfg = Config.IndustrialNozzle
    local model = loadModel(nozzleCfg.model)
    if not model then
        HBSFuelNotify('Failed to load industrial nozzle.', 'error')
        return false
    end

    local pedCoords = GetEntityCoords(ped)
    local prop = CreateObject(model, pedCoords.x, pedCoords.y, pedCoords.z + 0.2, true, true, false)
    local anchor = CreateObject(model, anchorCoords.x, anchorCoords.y, anchorCoords.z, false, false, false)
    if not prop or prop == 0 or not anchor or anchor == 0 then
        HBSFuelNotify('Failed to create industrial hose parts.', 'error')
        return false
    end

    local bone = GetPedBoneIndex(ped, nozzleCfg.bone or 57005)
    local attach = nozzleCfg.offset or {}

    SetEntityCollision(prop, false, false)
    SetEntityAsMissionEntity(prop, true, true)
    AttachEntityToEntity(
        prop,
        ped,
        bone,
        attach.x or 0.13,
        attach.y or 0.03,
        attach.z or -0.02,
        attach.rx or -85.0,
        attach.ry or 0.0,
        attach.rz or -20.0,
        true,
        true,
        false,
        true,
        1,
        true
    )

    SetModelAsNoLongerNeeded(model)

    FreezeEntityPosition(anchor, true)
    SetEntityCollision(anchor, false, false)
    SetEntityAlpha(anchor, 0, false)
    SetEntityVisible(anchor, false, false)

    hoseState.active = true
    hoseState.refineryId = refineryId
    hoseState.anchorCoords = anchorCoords
    hoseState.anchorEntity = anchor
    hoseState.prop = prop
    hoseState.hoseType = hoseType

    if nozzleCfg.rope and nozzleCfg.rope.enabled then
        RopeLoadTextures()
        while not RopeAreTexturesLoaded() do Wait(0) end

        local ropeCfg = nozzleCfg.rope
        local rope = AddRope(
            anchorCoords.x,
            anchorCoords.y,
            anchorCoords.z,
            0.0,
            0.0,
            0.0,
            ropeCfg.length or 7.5,
            ropeCfg.type or 4,
            ropeCfg.length or 7.5,
            ropeCfg.minLength or 0.25,
            ropeCfg.lengthChangeRate or 0.0,
            false,
            false,
            false,
            ropeCfg.timeMultiplier or 1.0,
            ropeCfg.breakable or false
        )

        if rope and rope ~= 0 then
            local nozzlePos = GetEntityCoords(prop)
            ActivatePhysics(prop)
            AttachEntitiesToRope(
                rope,
                anchor,
                prop,
                anchorCoords.x,
                anchorCoords.y,
                anchorCoords.z,
                nozzlePos.x,
                nozzlePos.y,
                nozzlePos.z,
                ropeCfg.length or 7.5,
                false,
                false,
                nil,
                nil
            )
            RopeForceLength(rope, ropeCfg.length or 7.5)
            hoseState.rope = rope
        end
    end

    playCarryAnim(true)
    TriggerServerEvent('hbs-fuel:server:syncHoseGrab', anchorCoords)
    HBSFuelNotify(Config.Notifications.IndustrialHoseGrabbed, 'inform')
    return true
end

local function getVehicleModelName(vehicle)
    if not DoesEntityExist(vehicle) then return nil end
    local display = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    if not display or display == '' then return nil end
    return string.lower(display)
end

local function getTankerRoleForModel(modelName)
    if not modelName then return nil end
    for role, data in pairs(Config.Tanker.Roles or {}) do
        for i = 1, #(data.models or {}) do
            if modelName == string.lower(data.models[i]) then
                return role, data
            end
        end
    end
    return nil
end

local function getNearbySupportedTanker(coords, requiredRole)
    local handle, veh = FindFirstVehicle()
    local success
    local bestVeh, bestDist, bestRole, bestModel

    repeat
        if DoesEntityExist(veh) then
            local modelName = getVehicleModelName(veh)
            local role = getTankerRoleForModel(modelName)
            if role and (not requiredRole or role == requiredRole) then
                local dist = #(GetEntityCoords(veh) - coords)
                if dist <= Config.Tanker.SearchRadius and (not bestDist or dist < bestDist) then
                    bestVeh = veh
                    bestDist = dist
                    bestRole = role
                    bestModel = modelName
                end
            end
        end
        success, veh = FindNextVehicle(handle)
    until not success

    EndFindVehicle(handle)
    return bestVeh, bestDist, bestRole, bestModel
end

local function notifyWrongTankerRole(requiredRole)
    if requiredRole == 'crude' then
        HBSFuelNotify(Config.Notifications.TankerWrongRoleCrude, 'error')
    elseif requiredRole == 'refined' then
        HBSFuelNotify(Config.Notifications.TankerWrongRoleRefined, 'error')
    else
        HBSFuelNotify(Config.Notifications.NoTankerNearby, 'error')
    end
end

local function getVehiclePlate(vehicle)
    return HBSFuelNormalizePlate(GetVehicleNumberPlateText(vehicle))
end

local function showStock(refineryId)
    local data = lib.callback.await('hbs-fuel:server:getRefineryData', false, refineryId)
    if not data then
        HBSFuelNotify('Refinery data unavailable.', 'error')
        return
    end

    local lines = {
        ('Crude: %.2f / %.2fL'):format(data.crude.current or 0.0, data.crude.max or 0.0)
    }

    for fuelType, stock in pairs(data.products or {}) do
        local fuel = FuelTypes[fuelType]
        lines[#lines + 1] = ('%s: %.2f / %.2fL'):format(
            fuel and fuel.label or fuelType,
            stock.current or 0.0,
            stock.max or 0.0
        )
    end

    lib.alertDialog({
        header = 'Refinery Stock',
        content = table.concat(lines, '\n'),
        centered = true,
        cancel = false
    })
end

local function handleLoadCrude(refineryId, point)
    if not hoseState.active then
        if not createHose(point, 'crude_load', refineryId) then return end
        return
    end

    if hoseState.hoseType ~= 'crude_load' then
        HBSFuelNotify('Return the current hose first.', 'error')
        return
    end

    local tanker, _, _, modelName = getNearbySupportedTanker(point, 'crude')
    if not tanker then
        notifyWrongTankerRole('crude')
        return
    end

    local input = lib.inputDialog('Load Crude Tanker', {
        {
            type = 'number',
            label = 'Litres',
            default = Config.Tanker.DefaultMaxLitres,
            min = 100.0,
            max = Config.Tanker.DefaultMaxLitres,
            step = 100.0,
            required = true
        },
    })

    if not input then return end

    local litres = tonumber(input[1]) or 0.0
    if litres <= 0.0 then return end

    local ok = lib.progressCircle({
        duration = Config.Tanker.CrudeLoadStepSeconds * 1000,
        label = 'Loading crude oil...',
        canCancel = true,
        disable = { car = true, move = false, combat = true }
    })

    if not ok then return end

    local result = lib.callback.await('hbs-fuel:server:loadCrudeTanker', false, getVehiclePlate(tanker), litres, modelName)
    HBSFuelNotify(result and result.message or 'Unable to load crude.', result and result.ok and 'success' or 'error')
end

local function handleUnloadCrude(refineryId, point)
    if not hoseState.active then
        if not createHose(point, 'crude_unload', refineryId) then return end
        return
    end

    if hoseState.hoseType ~= 'crude_unload' then
        HBSFuelNotify('Return the current hose first.', 'error')
        return
    end

    local tanker, _, _, _ = getNearbySupportedTanker(point, 'crude')
    if not tanker then
        notifyWrongTankerRole('crude')
        return
    end

    local load = exports['hbs-fuel']:GetTankerVehicleLoad(tanker)
    if not load or load.fuelType ~= 'crude' or (load.litres or 0.0) <= 0.0 then
        HBSFuelNotify(Config.Notifications.TankerWrongProduct, 'error')
        return
    end

    local input = lib.inputDialog('Unload Crude', {
        {
            type = 'number',
            label = 'Litres',
            default = load.litres,
            min = 100.0,
            max = load.litres,
            step = 100.0,
            required = true
        },
    })

    if not input then return end

    local litres = tonumber(input[1]) or 0.0
    if litres <= 0.0 then return end

    local ok = lib.progressCircle({
        duration = Config.Tanker.FuelUnloadStepSeconds * 1000,
        label = 'Unloading crude into refinery...',
        canCancel = true,
        disable = { car = true, move = false, combat = true }
    })

    if not ok then return end

    local result = lib.callback.await('hbs-fuel:server:unloadCrudeToRefinery', false, refineryId, getVehiclePlate(tanker), litres)
    HBSFuelNotify(result and result.message or 'Unable to unload crude.', result and result.ok and 'success' or 'error')
end

local function handleOpenValve(refineryId)
    local result = lib.callback.await('hbs-fuel:server:openRefineryValve', false, refineryId)
    HBSFuelNotify(result and result.message or 'Unable to open valve.', result and result.ok and 'success' or 'error')
end

local function handleStartRefinery(refineryId)
    local ok = lib.progressCircle({
        duration = Config.Tanker.RefineStepSeconds * 1000,
        label = 'Starting refinery batch...',
        canCancel = true,
        disable = { car = true, move = true, combat = true }
    })
    if not ok then return end

    local result = lib.callback.await('hbs-fuel:server:startRefineryBatch', false, refineryId)
    HBSFuelNotify(result and result.message or 'Unable to start refinery batch.', result and result.ok and 'success' or 'error')
end

local function handleLoadRefined(refineryId, point)
    if not hoseState.active then
        if not createHose(point, 'fuel_load', refineryId) then return end
        return
    end

    if hoseState.hoseType ~= 'fuel_load' then
        HBSFuelNotify('Return the current hose first.', 'error')
        return
    end

    local tanker, _, _, modelName = getNearbySupportedTanker(point, 'refined')
    if not tanker then
        notifyWrongTankerRole('refined')
        return
    end

    local refinery = lib.callback.await('hbs-fuel:server:getRefineryData', false, refineryId)
    if not refinery then
        HBSFuelNotify('Refinery data unavailable.', 'error')
        return
    end

    local options = {}
    for fuelType, stock in pairs(refinery.products or {}) do
        if fuelType ~= 'motoroil' and fuelType ~= 'crude' and (stock.current or 0.0) > 0.0 then
            local fuel = FuelTypes[fuelType]
            options[#options + 1] = {
                label = fuel and fuel.label or fuelType,
                value = fuelType,
                description = ('%.2fL available'):format(stock.current or 0.0)
            }
        end
    end

    if #options == 0 then
        HBSFuelNotify('No refined fuel is available.', 'error')
        return
    end

    local input = lib.inputDialog('Load Tanker', {
        {
            type = 'select',
            label = 'Fuel Type',
            options = options,
            default = options[1].value,
            required = true
        },
        {
            type = 'number',
            label = 'Litres',
            default = Config.Tanker.DefaultMaxLitres,
            min = 100.0,
            max = Config.Tanker.DefaultMaxLitres,
            step = 100.0,
            required = true
        },
    })

    if not input then return end

    local fuelType = input[1]
    local litres = tonumber(input[2]) or 0.0
    if litres <= 0.0 then return end

    local ok = lib.progressCircle({
        duration = Config.Tanker.FuelLoadStepSeconds * 1000,
        label = 'Loading refined fuel...',
        canCancel = true,
        disable = { car = true, move = false, combat = true }
    })

    if not ok then return end

    local result = lib.callback.await('hbs-fuel:server:loadRefinedProduct', false, refineryId, getVehiclePlate(tanker), fuelType, litres, modelName)
    HBSFuelNotify(result and result.message or 'Unable to load refined fuel.', result and result.ok and 'success' or 'error')
end

local function handleUnloadStation(stationId, point)
    if not hoseState.active then
        if not createHose(point, 'station_unload', stationId) then return end
        return
    end

    if hoseState.hoseType ~= 'station_unload' then
        HBSFuelNotify('Return the current hose first.', 'error')
        return
    end

    local tanker, _, _, modelName = getNearbySupportedTanker(point, 'refined')
    if not tanker then
        notifyWrongTankerRole('refined')
        return
    end

    local load = exports['hbs-fuel']:GetTankerVehicleLoad(tanker)
    if not load or not load.fuelType or load.fuelType == 'crude' or (load.litres or 0.0) <= 0.0 then
        HBSFuelNotify(Config.Notifications.TankerWrongProduct, 'error')
        return
    end

    local input = lib.inputDialog('Unload Tanker to Station', {
        {
            type = 'number',
            label = 'Litres',
            default = load.litres,
            min = 100.0,
            max = load.litres,
            step = 100.0,
            required = true
        },
    })

    if not input then return end

    local litres = tonumber(input[1]) or 0.0
    if litres <= 0.0 then return end

    local ok = lib.progressCircle({
        duration = Config.Tanker.FuelUnloadStepSeconds * 1000,
        label = 'Unloading tanker to station...',
        canCancel = true,
        disable = { car = true, move = false, combat = true }
    })

    if not ok then return end

    local result = lib.callback.await('hbs-fuel:server:unloadTankerToStation', false, stationId, getVehiclePlate(tanker), litres, modelName)
    HBSFuelNotify(result and result.message or 'Unable to unload tanker.', result and result.ok and 'success' or 'error')
end

local function registerRefineryTargets()
    for refineryId, refinery in pairs(Refineries) do
        local points = refinery.points or {}

        if points.crudeSource then
            exports.ox_target:addSphereZone({
                coords = points.crudeSource,
                radius = 2.0,
                debug = Config.Debug,
                options = {
                    {
                        name = ('hbs_fuel_crude_source_%s'):format(refineryId),
                        icon = 'fa-solid fa-truck-ramp-box',
                        label = 'Grab / Use Crude Load Hose',
                        onSelect = function()
                            handleLoadCrude(refineryId, points.crudeSource)
                        end
                    },
                    {
                        name = ('hbs_fuel_crude_source_return_%s'):format(refineryId),
                        icon = 'fa-solid fa-rotate-left',
                        label = 'Return Hose',
                        canInteract = function()
                            return hoseState.active and hoseState.hoseType == 'crude_load'
                        end,
                        onSelect = function()
                            clearHose()
                            HBSFuelNotify(Config.Notifications.IndustrialHoseReturned, 'success')
                        end
                    },
                }
            })
        end

        for index, coords in ipairs(points.crudeDelivery or {}) do
            exports.ox_target:addSphereZone({
                coords = coords,
                radius = 2.5,
                debug = Config.Debug,
                options = {
                    {
                        name = ('hbs_fuel_crude_unload_%s_%s'):format(refineryId, index),
                        icon = 'fa-solid fa-oil-can',
                        label = 'Grab / Use Crude Hose',
                        onSelect = function()
                            handleUnloadCrude(refineryId, coords)
                        end
                    },
                    {
                        name = ('hbs_fuel_crude_hose_return_%s_%s'):format(refineryId, index),
                        icon = 'fa-solid fa-rotate-left',
                        label = 'Return Hose',
                        canInteract = function()
                            return hoseState.active and hoseState.hoseType == 'crude_unload'
                        end,
                        onSelect = function()
                            clearHose()
                            HBSFuelNotify(Config.Notifications.IndustrialHoseReturned, 'success')
                        end
                    },
                }
            })
        end

        if points.valve then
            exports.ox_target:addSphereZone({
                coords = points.valve,
                radius = 1.5,
                debug = Config.Debug,
                options = {
                    {
                        name = ('hbs_fuel_valve_%s'):format(refineryId),
                        icon = 'fa-solid fa-faucet',
                        label = 'Open Refinery Valve',
                        onSelect = function()
                            handleOpenValve(refineryId)
                        end
                    },
                }
            })
        end

        if points.processStart then
            exports.ox_target:addSphereZone({
                coords = points.processStart,
                radius = 2.0,
                debug = Config.Debug,
                options = {
                    {
                        name = ('hbs_fuel_process_%s'):format(refineryId),
                        icon = 'fa-solid fa-industry',
                        label = 'Start Refinery Batch',
                        onSelect = function()
                            handleStartRefinery(refineryId)
                        end
                    },
                    {
                        name = ('hbs_fuel_stock_%s'):format(refineryId),
                        icon = 'fa-solid fa-chart-column',
                        label = 'View Refinery Stock',
                        onSelect = function()
                            showStock(refineryId)
                        end
                    },
                    {
                        name = ('hbs_fuel_contracts_%s'):format(refineryId),
                        icon = 'fa-solid fa-clipboard-list',
                        label = 'Open Contracts Board',
                        onSelect = function()
                            TriggerEvent('hbs-fuel:client:openContractsBoard')
                        end
                    },
                }
            })
        end

        if points.tankerLoad then
            exports.ox_target:addSphereZone({
                coords = points.tankerLoad,
                radius = 2.5,
                debug = Config.Debug,
                options = {
                    {
                        name = ('hbs_fuel_load_fuel_%s'):format(refineryId),
                        icon = 'fa-solid fa-gas-pump',
                        label = 'Grab / Use Fuel Hose',
                        onSelect = function()
                            handleLoadRefined(refineryId, points.tankerLoad)
                        end
                    },
                    {
                        name = ('hbs_fuel_load_return_%s'):format(refineryId),
                        icon = 'fa-solid fa-rotate-left',
                        label = 'Return Hose',
                        canInteract = function()
                            return hoseState.active and hoseState.hoseType == 'fuel_load'
                        end,
                        onSelect = function()
                            clearHose()
                            HBSFuelNotify(Config.Notifications.IndustrialHoseReturned, 'success')
                        end
                    },
                }
            })
        end
    end
end

local function registerStationTargets()
    for stationId, station in pairs(Stations) do
        local unloadPoints = station.unloadPoints or { station.coords }

        for index, coords in ipairs(unloadPoints) do
            exports.ox_target:addSphereZone({
                coords = coords,
                radius = 2.5,
                debug = Config.Debug,
                options = {
                    {
                        name = ('hbs_fuel_station_unload_%s_%s'):format(stationId, index),
                        icon = 'fa-solid fa-truck-droplet',
                        label = 'Grab / Use Station Hose',
                        onSelect = function()
                            handleUnloadStation(stationId, coords)
                        end
                    },
                    {
                        name = ('hbs_fuel_station_hose_return_%s_%s'):format(stationId, index),
                        icon = 'fa-solid fa-rotate-left',
                        label = 'Return Hose',
                        canInteract = function()
                            return hoseState.active and hoseState.hoseType == 'station_unload'
                        end,
                        onSelect = function()
                            clearHose()
                            HBSFuelNotify(Config.Notifications.IndustrialHoseReturned, 'success')
                        end
                    },
                    {
                        name = ('hbs_fuel_station_contracts_%s_%s'):format(stationId, index),
                        icon = 'fa-solid fa-clipboard-list',
                        label = 'Open Contracts Board',
                        onSelect = function()
                            TriggerEvent('hbs-fuel:client:openContractsBoard')
                        end
                    },
                }
            })
        end
    end
end

CreateThread(function()
    if not Config.UseOxTarget then return end
    registerRefineryTargets()
    registerStationTargets()
end)

CreateThread(function()
    while true do
        if hoseState.active and hoseState.anchorCoords then
            local pedCoords = GetEntityCoords(PlayerPedId())
            if #(pedCoords - hoseState.anchorCoords) > Config.Tanker.HoseMaxDistance then
                clearHose()
                HBSFuelNotify(Config.Notifications.IndustrialTooFar, 'error')
            else
                if not hoseState.prop or not DoesEntityExist(hoseState.prop) then
                    createHose(hoseState.anchorCoords, hoseState.hoseType, hoseState.refineryId)
                end
                playCarryAnim(false)
            end
            Wait(350)
        else
            Wait(750)
        end
    end
end)

RegisterNetEvent('hbs-fuel:client:syncHoseGrab', function(serverId, anchorCoords)
    if GetPlayerServerId(PlayerId()) == serverId then return end

    local player = GetPlayerFromServerId(serverId)
    if player == -1 then return end

    local ped = GetPlayerPed(player)
    if not DoesEntityExist(ped) then return end

    if remoteHoses[serverId] then
        DeleteEntity(remoteHoses[serverId])
        remoteHoses[serverId] = nil
    end
    if remoteHoseRopes[serverId] then
        DeleteRope(remoteHoseRopes[serverId])
        remoteHoseRopes[serverId] = nil
    end

    local nozzleCfg = Config.IndustrialNozzle
    local model = loadModel(nozzleCfg.model)
    if not model then return end

    local obj = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
    if not obj or obj == 0 then return end

    SetEntityCollision(obj, false, false)
    SetEntityAsMissionEntity(obj, true, true)

    local attach = nozzleCfg.offset or {}
    AttachEntityToEntity(
        obj, ped,
        GetPedBoneIndex(ped, nozzleCfg.bone or 57005),
        attach.x or 0.13, attach.y or 0.03, attach.z or -0.02,
        attach.rx or -85.0, attach.ry or 0.0, attach.rz or -20.0,
        true, true, false, true, 1, true
    )

    remoteHoses[serverId] = obj

    if anchorCoords and nozzleCfg.rope and nozzleCfg.rope.enabled then
        local ropeCfg = nozzleCfg.rope
        local anchorOff = ropeCfg.anchorOffset or { x = 0.0, y = 0.0, z = 1.15 }
        local ax = anchorCoords.x + (anchorOff.x or 0.0)
        local ay = anchorCoords.y + (anchorOff.y or 0.0)
        local az = anchorCoords.z + (anchorOff.z or 1.15)

        local rope = AddRope(
            ax, ay, az, 0.0, 0.0, 0.0,
            ropeCfg.length or 7.5, ropeCfg.type or 4,
            ropeCfg.length or 7.5, ropeCfg.minLength or 0.25,
            ropeCfg.lengthChangeRate or 0.0,
            false, false, false,
            ropeCfg.timeMultiplier or 1.0, ropeCfg.breakable or false
        )

        if rope and rope ~= 0 then
            AttachEntitiesToRope(
                rope, obj, obj,
                ax, ay, az,
                0.0, 0.0, 0.0,
                ropeCfg.length or 7.5,
                false, false, nil, nil
            )
            RopeForceLength(rope, ropeCfg.length or 7.5)
            remoteHoseRopes[serverId] = rope
        end
    end
end)

RegisterNetEvent('hbs-fuel:client:syncHoseReturn', function(serverId)
    if remoteHoseRopes[serverId] then
        DeleteRope(remoteHoseRopes[serverId])
        remoteHoseRopes[serverId] = nil
    end
    if remoteHoses[serverId] then
        DeleteEntity(remoteHoses[serverId])
        remoteHoses[serverId] = nil
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clearHose()

    for serverId, obj in pairs(remoteHoses) do
        DeleteEntity(obj)
        remoteHoses[serverId] = nil
    end
    for serverId, rope in pairs(remoteHoseRopes) do
        DeleteRope(rope)
        remoteHoseRopes[serverId] = nil
    end
end)
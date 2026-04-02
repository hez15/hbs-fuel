local pumpModels = {
    `prop_gas_pump_1a`,
    `prop_gas_pump_1b`,
    `prop_gas_pump_1c`,
    `prop_gas_pump_1d`,
    `prop_vintage_pump`,
    `prop_gas_pump_old2`,
    `prop_gas_pump_old3`,
}

local isRefuelling = false
local nozzleState = {
    active = false,
    pump = nil,
    pumpCoords = nil,
    stationId = nil,
    station = nil,
}
local nozzleVisual = {
    prop = nil,
    rope = nil,
}
local lastUiText
local remoteNozzles = {}

local function hidePumpUi()
    if lastUiText then
        lib.hideTextUI()
        lastUiText = nil
    end
end

local function showPumpUi(text)
    if lastUiText ~= text then
        hidePumpUi()
        lib.showTextUI(text)
        lastUiText = text
    end
end

local function loadModel(model)
    if type(model) == 'string' then
        model = joaat(model)
    end

    if not IsModelValid(model) then
        return false
    end

    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        Wait(0)
        if GetGameTimer() > timeout then
            return false
        end
    end

    return model
end

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        Wait(0)
        if GetGameTimer() > timeout then
            return false
        end
    end
    return true
end


local function deletePropEntity(entity)
    if entity and DoesEntityExist(entity) then
        DetachEntity(entity, true, true)
        SetEntityAsMissionEntity(entity, true, true)
        DeleteObject(entity)
        DeleteEntity(entity)
    end
end

local function clearNozzleVisuals()
    if nozzleVisual.rope then
        DeleteRope(nozzleVisual.rope)
        nozzleVisual.rope = nil
    end

    if RopeAreTexturesLoaded() then
        RopeUnloadTextures()
    end

    if nozzleVisual.prop then
        deletePropEntity(nozzleVisual.prop)
    end
    nozzleVisual.prop = nil

    local ped = PlayerPedId()
    StopAnimTask(ped, Config.NozzleCarryAnim.dict, Config.NozzleCarryAnim.clip, 1.0)
    ClearPedSecondaryTask(ped)
end

local function playNozzleCarryAnim(force)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped) then
        return
    end

    local anim = Config.NozzleCarryAnim
    if not anim or not anim.dict or not anim.clip then
        return
    end

    if not force and IsEntityPlayingAnim(ped, anim.dict, anim.clip, 3) then
        return
    end

    if not loadAnimDict(anim.dict) then
        return
    end

    TaskPlayAnim(ped, anim.dict, anim.clip, 2.0, 2.0, -1, anim.flag or 49, 0.0, false, false, false)
end

local function getPumpRopeWorldCoords(pump)
    local offset = Config.NozzleRope and Config.NozzleRope.pumpOffset or { x = 0.0, y = 0.0, z = 1.25 }
    return GetOffsetFromEntityInWorldCoords(pump, offset.x or 0.0, offset.y or 0.0, offset.z or 1.25)
end

local function getNozzleRopeWorldCoords(prop)
    return GetOffsetFromEntityInWorldCoords(prop, 0.0, 0.0, 0.0)
end

local function createNozzleVisuals()
    clearNozzleVisuals()

    local ped = PlayerPedId()
    local model = loadModel((Config.Nozzles and Config.Nozzles.Vehicle and Config.Nozzles.Vehicle.model) or 'prop_cs_fuel_nozle')
    if not model then
        HBSFuelNotify('Failed to load nozzle prop model.', 'error')
        return false
    end

    local coords = GetEntityCoords(ped)
    local prop = CreateObject(model, coords.x, coords.y, coords.z + 0.2, true, true, false)
    if not prop or prop == 0 then
        HBSFuelNotify('Failed to create nozzle prop.', 'error')
        return false
    end

    local bone = GetPedBoneIndex(ped, Config.NozzlePropBone or 57005)
    local attach = Config.NozzlePropOffset or {}
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
    nozzleVisual.prop = prop

    if Config.NozzleRope and Config.NozzleRope.enabled and nozzleState.pump and DoesEntityExist(nozzleState.pump) then
        RopeLoadTextures()
        while not RopeAreTexturesLoaded() do
            Wait(0)
        end

        local ropeCfg = Config.NozzleRope
        local pumpPos = getPumpRopeWorldCoords(nozzleState.pump)
        local rope = AddRope(
            pumpPos.x,
            pumpPos.y,
            pumpPos.z,
            0.0,
            0.0,
            0.0,
            ropeCfg.length or 4.8,
            ropeCfg.type or 4,
            ropeCfg.length or 4.8,
            ropeCfg.minLength or 0.25,
            ropeCfg.lengthChangeRate or 0.0,
            false,
            false,
            false,
            ropeCfg.timeMultiplier or 1.0,
            ropeCfg.breakable or false
        )

        if rope and rope ~= 0 then
            local nozzlePos = getNozzleRopeWorldCoords(prop)
            ActivatePhysics(prop)
            AttachEntitiesToRope(
                rope,
                nozzleState.pump,
                prop,
                pumpPos.x,
                pumpPos.y,
                pumpPos.z,
                nozzlePos.x,
                nozzlePos.y,
                nozzlePos.z,
                ropeCfg.length or 4.8,
                false,
                false,
                nil,
                nil
            )
            RopeForceLength(rope, ropeCfg.length or 4.8)
            nozzleVisual.rope = rope
        end
    end

    playNozzleCarryAnim(true)
    return true
end

local function clearNozzleState(notifyMessage, notifyType)
    clearNozzleVisuals()
    TriggerServerEvent('hbs-fuel:server:syncNozzleReturn')

    nozzleState.active = false
    nozzleState.pump = nil
    nozzleState.pumpCoords = nil
    nozzleState.stationId = nil
    nozzleState.station = nil
    hidePumpUi()

    if notifyMessage then
        HBSFuelNotify(notifyMessage, notifyType or 'inform')
    end
end

local function getPumpData(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return nil, nil, nil
    end

    local pumpCoords = GetEntityCoords(entity)
    if HBSFuel.IsInPumpExclusionZone(pumpCoords) then
        return nil, nil, nil
    end

    local stationId, station = HBSFuel.GetClosestStation(pumpCoords)
    return pumpCoords, stationId, station
end

local function buildFuelOptions(station, vehicle)
    local options = {}
    local supported = station and HBSFuel.GetSupportedFuelTypes(station) or (Config.AllowUnmappedStations and Config.UnmappedStationSupportedFuelTypes) or {}

    for _, fuelType in ipairs(supported) do
        local fuelData = FuelTypes[fuelType]
        if fuelData and HBSFuel.CanVehicleUseFuelType(vehicle, fuelType) then
            options[#options + 1] = {
                label = fuelData.label,
                value = fuelType,
                description = ('Base $%.2f/L'):format(fuelData.price)
            }
        end
    end

    return options
end

local function vehicleInPumpRange(vehicle)
    if not nozzleState.active or not nozzleState.pumpCoords or not DoesEntityExist(vehicle) then
        return false
    end

    local pedCoords = GetEntityCoords(PlayerPedId())
    local vehicleCoords = GetEntityCoords(vehicle)

    if #(pedCoords - nozzleState.pumpCoords) > Config.NozzleMaxDistance then
        return false
    end

    if #(vehicleCoords - nozzleState.pumpCoords) > Config.PumpVehicleSearchRadius then
        return false
    end

    if #(vehicleCoords - pedCoords) > Config.PlayerVehicleRefuelRange then
        return false
    end

    return true
end

local function doRefuel(vehicle, fuelType, litresTarget, paymentMethod)
    if isRefuelling or not DoesEntityExist(vehicle) or not nozzleState.active then return end

    local ped = PlayerPedId()
    local tankCapacity = HBSFuel.GetTankCapacity(vehicle)
    local currentFuel = GetCachedVehicleFuel(vehicle) or 0.0
    local litresNeeded = HBSFuel.Round(math.min(tankCapacity - currentFuel, litresTarget), 2)

    if litresNeeded <= 0.05 then
        HBSFuelNotify('Vehicle is already full.', 'inform')
        return
    end

    paymentMethod = (paymentMethod == 'bank' and 'bank') or 'cash'

    local preview = lib.callback.await('hbs-fuel:server:previewRefuel', false, nozzleState.stationId, fuelType, litresNeeded, paymentMethod)
    if not preview or not preview.ok then
        HBSFuelNotify(preview and preview.message or 'Unable to refuel.', 'error')
        return
    end

    local approvedTarget = math.min(preview.approvedLitres or litresNeeded, litresNeeded)
    if approvedTarget <= 0.05 then
        HBSFuelNotify(preview.message or 'Nothing available to refuel.', 'error')
        return
    end

    if Config.ShutOffEngineDuringRefuel and GetIsVehicleEngineRunning(vehicle) then
        SetVehicleEngineOn(vehicle, false, true, true)
    end

    isRefuelling = true
    hidePumpUi()
    local cancelReason = nil
    local duration = math.max(1500, math.floor(approvedTarget * (Config.RefuelProgressMsPerLitre or 450)))

    playNozzleCarryAnim(true)
    TaskTurnPedToFaceEntity(ped, vehicle, 1000)
    HBSFuelNotify(Config.Notifications.RefuelStarted, 'inform')

    CreateThread(function()
        while isRefuelling do
            Wait(200)
            playNozzleCarryAnim(false)

            if not DoesEntityExist(vehicle) or not nozzleState.active or not vehicleInPumpRange(vehicle) then
                cancelReason = Config.Notifications.RefuelBlockedVehicleTooFar
                pcall(function() lib.cancelProgress() end)
                break
            end
        end
    end)

    local completed = lib.progressBar({
        duration = duration,
        label = ('Refuelling %.2fL of %s...'):format(approvedTarget, FuelTypes[fuelType].label),
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = false, combat = true },
    })

    isRefuelling = false

    if not completed then
        HBSFuelNotify(cancelReason or Config.Notifications.RefuelCancelled, cancelReason and 'error' or 'inform')
        showPumpUi('Nozzle ready - target a vehicle to refuel or target the pump to return it')
        return
    end

    local result = lib.callback.await('hbs-fuel:server:commitRefuelTick', false, nozzleState.stationId, fuelType, approvedTarget, paymentMethod)
    if not result or not result.ok then
        HBSFuelNotify(result and result.message or 'Refuel stopped.', 'error')
        showPumpUi('Nozzle ready - target a vehicle to refuel or target the pump to return it')
        return
    end

    local addedLitres = result.litres or 0.0
    if addedLitres > 0.0 then
        local finalFuel = currentFuel + addedLitres
        SetCachedVehicleFuel(vehicle, finalFuel)

        local plate = HBSFuelNormalizePlate(GetVehicleNumberPlateText(vehicle))
        if plate then
            HBSFuelSaveFuelByPlate(plate, finalFuel)
        end

        HBSFuelNotify(('%s Added %.2fL for $%.2f.'):format(Config.Notifications.RefuelComplete, addedLitres, result.totalPrice or 0.0), 'success')
    end

    showPumpUi('Nozzle ready - target a vehicle to refuel or target the pump to return it')
end

local function promptRefuelVehicle(vehicle)
    if not nozzleState.active then
        HBSFuelNotify('Grab the nozzle from the pump first.', 'error')
        return
    end

    if not HBSFuel.CanVehicleBeFuelled(vehicle) then
        HBSFuelNotify(Config.Notifications.RefuelBlockedIncompatibleVehicle, 'error')
        return
    end

    if not vehicleInPumpRange(vehicle) then
        HBSFuelNotify(Config.Notifications.RefuelBlockedVehicleTooFar, 'error')
        return
    end

    local currentFuel = GetCachedVehicleFuel(vehicle) or 0.0
    local tankCapacity = HBSFuel.GetTankCapacity(vehicle)
    local litresNeeded = HBSFuel.Round(tankCapacity - currentFuel, 2)

    if litresNeeded <= 0.05 then
        HBSFuelNotify('Vehicle is already full.', 'inform')
        return
    end

    local fuelOptions = buildFuelOptions(nozzleState.station, vehicle)
    if #fuelOptions == 0 then
        HBSFuelNotify(Config.Notifications.RefuelBlockedIncompatibleVehicle, 'error')
        return
    end

    local input = lib.inputDialog('Refuel Vehicle', {
        {
            type = 'select',
            label = 'Fuel Type',
            options = fuelOptions,
            default = fuelOptions[1].value,
            required = true,
        },
        {
            type = 'number',
            label = 'Litres',
            description = ('Max %.2fL'):format(litresNeeded),
            default = litresNeeded,
            min = 0.5,
            max = litresNeeded,
            step = 0.5,
            required = true,
        },
        {
            type = 'select',
            label = 'Pay With',
            options = {
                { label = 'Cash', value = 'cash' },
                { label = 'Bank', value = 'bank' },
            },
            default = 'cash',
            required = true,
        }
    })

    if not input or not input[1] or not input[2] or not input[3] then
        return
    end

    local fuelType = input[1]
    local requestedLitres = tonumber(input[2]) or 0.0
    local paymentMethod = input[3]
    if requestedLitres <= 0.0 then
        return
    end

    local preview = lib.callback.await('hbs-fuel:server:previewRefuel', false, nozzleState.stationId, fuelType, requestedLitres, paymentMethod)
    if not preview or not preview.ok then
        HBSFuelNotify(preview and preview.message or 'Unable to quote refuel.', 'error')
        return
    end

    local stationLabel = preview.stationLabel or (nozzleState.station and nozzleState.station.label) or 'Fuel Station'
    local confirmed = lib.alertDialog({
        header = 'Confirm Refuel',
        content = ('Station: %s\nFuel: %s\nLitres: %.2fL\nPrice/L: $%.2f\nEstimated total: $%.2f\nPayment: %s')
            :format(stationLabel, FuelTypes[fuelType].label, preview.approvedLitres or requestedLitres, preview.pricePerLitre or 0.0, preview.totalPrice or 0.0, paymentMethod == 'bank' and 'Bank' or 'Cash'),
        centered = true,
        cancel = true,
    })

    if confirmed ~= 'confirm' then
        return
    end

    doRefuel(vehicle, fuelType, requestedLitres, paymentMethod)
end

local function grabNozzle(entity)
    if Config.RequirePlayerOutsideVehicleForPump and IsPedInAnyVehicle(PlayerPedId(), false) then
        HBSFuelNotify(Config.Notifications.RefuelBlockedInsideVehicle, 'error')
        return
    end

    local pumpCoords, stationId, station = getPumpData(entity)
    if not pumpCoords then
        HBSFuelNotify('This pump is not set up for public vehicle refuelling.', 'error')
        return
    end

    nozzleState.active = true
    nozzleState.pump = entity
    nozzleState.pumpCoords = pumpCoords
    nozzleState.stationId = stationId
    nozzleState.station = station

    if not createNozzleVisuals() then
        nozzleState.active = false
        nozzleState.pump = nil
        nozzleState.pumpCoords = nil
        nozzleState.stationId = nil
        nozzleState.station = nil
        return
    end

    TriggerServerEvent('hbs-fuel:server:syncNozzleGrab')

    showPumpUi('Nozzle ready - target a vehicle to refuel or target the pump to return it')
    HBSFuelNotify(Config.Notifications.NozzleGrabbed, 'inform')
end

RegisterNetEvent('hbs-fuel:client:syncNozzleGrab', function(serverId)
    if GetPlayerServerId(PlayerId()) == serverId then return end

    local player = GetPlayerFromServerId(serverId)
    if player == -1 then return end

    local ped = GetPlayerPed(player)
    if not DoesEntityExist(ped) then return end

    if remoteNozzles[serverId] then
        deletePropEntity(remoteNozzles[serverId])
        remoteNozzles[serverId] = nil
    end

    local model = loadModel((Config.Nozzles and Config.Nozzles.Vehicle and Config.Nozzles.Vehicle.model) or 'prop_cs_fuel_nozle')
    if not model then return end

    local obj = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
    if not obj or obj == 0 then return end

    SetEntityCollision(obj, false, false)
    SetEntityAsMissionEntity(obj, true, true)

    AttachEntityToEntity(
        obj,
        ped,
        GetPedBoneIndex(ped, Config.NozzlePropBone or 57005),
        Config.NozzlePropOffset.x or 0.13,
        Config.NozzlePropOffset.y or 0.03,
        Config.NozzlePropOffset.z or -0.02,
        Config.NozzlePropOffset.rx or -85.0,
        Config.NozzlePropOffset.ry or 0.0,
        Config.NozzlePropOffset.rz or -20.0,
        true,
        true,
        false,
        true,
        1,
        true
    )

    remoteNozzles[serverId] = obj
end)

RegisterNetEvent('hbs-fuel:client:syncNozzleReturn', function(serverId)
    if remoteNozzles[serverId] then
        deletePropEntity(remoteNozzles[serverId])
        remoteNozzles[serverId] = nil
    end
end)

local function registerTargets()
    exports.ox_target:addModel(pumpModels, {
        {
            name = 'hbs_fuel_grab_nozzle',
            icon = 'fa-solid fa-gas-pump',
            label = 'Grab Nozzle',
            distance = 2.0,
            canInteract = function(entity)
                if isRefuelling or nozzleState.active then return false end
                if Config.RequirePlayerOutsideVehicleForPump and IsPedInAnyVehicle(PlayerPedId(), false) then return false end
                if not entity or entity == 0 then return false end

                local pumpCoords = GetEntityCoords(entity)
                if HBSFuel.IsInPumpExclusionZone(pumpCoords) then
                    return false
                end

                local stationId = HBSFuel.GetClosestStation(pumpCoords)
                if stationId then
                    return true
                end

                return Config.AllowUnmappedStations == true
            end,
            onSelect = function(data)
                grabNozzle(data.entity)
            end,
        },
        {
            name = 'hbs_fuel_return_nozzle',
            icon = 'fa-solid fa-rotate-left',
            label = 'Return Nozzle',
            distance = 2.0,
            canInteract = function(entity)
                return (not isRefuelling) and nozzleState.active and nozzleState.pump == entity
            end,
            onSelect = function()
                clearNozzleState(Config.Notifications.NozzleReturned, 'success')
            end,
        }
    })

    exports.ox_target:addGlobalVehicle({
        {
            name = 'hbs_fuel_refuel_vehicle',
            icon = 'fa-solid fa-oil-can',
            label = 'Refuel Vehicle',
            distance = 2.5,
            canInteract = function(entity)
                return (not isRefuelling)
                    and nozzleState.active
                    and entity and entity ~= 0
                    and HBSFuel.CanVehicleBeFuelled(entity)
                    and vehicleInPumpRange(entity)
            end,
            onSelect = function(data)
                promptRefuelVehicle(data.entity)
            end,
        }
    })
end

CreateThread(function()
    if not Config.UseOxTarget then
        if Config.Debug then
            print('[hbs-fuel] Config.UseOxTarget is false, pump nozzle target flow is disabled.')
        end
        return
    end

    registerTargets()
end)

CreateThread(function()
    while true do
        if nozzleState.active and not isRefuelling then
            local ped = PlayerPedId()
            local pedCoords = GetEntityCoords(ped)
            if not nozzleState.pumpCoords or #(pedCoords - nozzleState.pumpCoords) > Config.NozzleMaxDistance then
                clearNozzleState(Config.Notifications.NozzleTooFar, 'error')
            else
                if not nozzleVisual.prop or not DoesEntityExist(nozzleVisual.prop) then
                    createNozzleVisuals()
                end
                playNozzleCarryAnim(false)
                showPumpUi('Nozzle ready - target a vehicle to refuel or target the pump to return it')
            end
            Wait(350)
        else
            if not isRefuelling then
                hidePumpUi()
            end
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    hidePumpUi()
    clearNozzleVisuals()
    TriggerServerEvent('hbs-fuel:server:syncNozzleReturn')

    for serverId, obj in pairs(remoteNozzles) do
        deletePropEntity(obj)
        remoteNozzles[serverId] = nil
    end

    if Config.UseOxTarget then
        pcall(function() exports.ox_target:removeModel(pumpModels, { 'hbs_fuel_grab_nozzle', 'hbs_fuel_return_nozzle' }) end)
        pcall(function() exports.ox_target:removeGlobalVehicle({ 'hbs_fuel_refuel_vehicle' }) end)
    end
end)

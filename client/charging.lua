if not Config.Charging or not Config.Charging.Enabled then return end

local chargingProps = {}
local chargingState = {
    active = false,    -- nozzle grabbed
    vehicle = nil,
    stationId = nil,
    chargerCoords = nil,
    prop = nil,
    anchor = nil,
    rope = nil,
}

local function isElectricVehicle(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    return HBSFuel.CanVehicleUseFuelType(vehicle, 'electric')
end

local function clearChargingHose()
    local ped = PlayerPedId()
    local anim = Config.NozzleCarryAnim
    if anim and anim.dict and anim.clip then
        StopAnimTask(ped, anim.dict, anim.clip, 1.0)
    end
    ClearPedSecondaryTask(ped)
    ClearPedTasks(ped)

    if chargingState.rope then
        DeleteRope(chargingState.rope)
        chargingState.rope = nil
    end
    if chargingState.prop and DoesEntityExist(chargingState.prop) then
        DetachEntity(chargingState.prop, true, true)
        SetEntityAsMissionEntity(chargingState.prop, true, true)
        DeleteObject(chargingState.prop)
        if DoesEntityExist(chargingState.prop) then DeleteEntity(chargingState.prop) end
    end
    if chargingState.anchor and DoesEntityExist(chargingState.anchor) then
        SetEntityAsMissionEntity(chargingState.anchor, true, true)
        DeleteObject(chargingState.anchor)
        if DoesEntityExist(chargingState.anchor) then DeleteEntity(chargingState.anchor) end
    end

    chargingState.prop = nil
    chargingState.anchor = nil
    chargingState.rope = nil
    chargingState.active = false
    chargingState.vehicle = nil
    chargingState.stationId = nil
    chargingState.chargerCoords = nil
end

local function createChargingHose(anchorCoords)
    local ped = PlayerPedId()
    local nozzleCfg = Config.IndustrialNozzle
    local nozzleHash = joaat(nozzleCfg.model or 'hei_prop_hei_hose_nozzle')
    RequestModel(nozzleHash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(nozzleHash) do Wait(0); if GetGameTimer() > timeout then return false end end

    local pedCoords = GetEntityCoords(ped)
    local prop = CreateObject(nozzleHash, pedCoords.x, pedCoords.y, pedCoords.z + 0.2, true, true, false)
    if not prop or prop == 0 then return false end

    local bone = GetPedBoneIndex(ped, nozzleCfg.bone or 57005)
    local attach = nozzleCfg.offset or {}
    SetEntityCollision(prop, false, false)
    SetEntityAsMissionEntity(prop, true, true)
    AttachEntityToEntity(prop, ped, bone,
        attach.x or 0.13, attach.y or 0.03, attach.z or -0.02,
        attach.rx or -85.0, attach.ry or 0.0, attach.rz or -20.0,
        true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(nozzleHash)

    local anchorModelName = nozzleCfg.rope and nozzleCfg.rope.anchorModel or nozzleCfg.model
    local anchorHash = joaat(anchorModelName)
    RequestModel(anchorHash)
    timeout = GetGameTimer() + 5000
    while not HasModelLoaded(anchorHash) do Wait(0); if GetGameTimer() > timeout then break end end

    local anchor = nil
    if HasModelLoaded(anchorHash) then
        anchor = CreateObject(anchorHash, anchorCoords.x, anchorCoords.y, anchorCoords.z, false, false, false)
        if anchor and anchor ~= 0 then
            FreezeEntityPosition(anchor, true)
            SetEntityCollision(anchor, false, false)
            PlaceObjectOnGroundProperly(anchor)
            SetModelAsNoLongerNeeded(anchorHash)
        end
    end

    local ropeCfg = nozzleCfg.rope or {}
    if ropeCfg.enabled ~= false then
        if not RopeAreTexturesLoaded() then RopeLoadTextures() end
        local anchorOff = ropeCfg.anchorOffset or { x = 0, y = 0, z = 1.15 }
        local rope = AddRope(
            anchorCoords.x + anchorOff.x, anchorCoords.y + anchorOff.y, anchorCoords.z + anchorOff.z,
            0.0, 0.0, 0.0,
            ropeCfg.length or 7.5, ropeCfg.type or 4, ropeCfg.length or 7.5,
            ropeCfg.minLength or 0.25, ropeCfg.lengthChangeRate or 0.0,
            false, false, false,
            ropeCfg.timeMultiplier or 1.0, ropeCfg.breakable or false
        )
        if rope then
            AttachEntitiesToRope(rope, anchor or 0, prop,
                anchorCoords.x + anchorOff.x, anchorCoords.y + anchorOff.y, anchorCoords.z + anchorOff.z,
                pedCoords.x, pedCoords.y, pedCoords.z + 0.5, ropeCfg.length or 7.5, false, false, nil, nil)
            chargingState.rope = rope
        end
    end

    chargingState.prop = prop
    chargingState.anchor = anchor

    local anim = Config.NozzleCarryAnim
    if anim and anim.dict and anim.clip then
        RequestAnimDict(anim.dict)
        timeout = GetGameTimer() + 3000
        while not HasAnimDictLoaded(anim.dict) do Wait(0); if GetGameTimer() > timeout then break end end
        TaskPlayAnim(ped, anim.dict, anim.clip, 2.0, 2.0, -1, anim.flag or 49, 0.0, false, false, false)
    end

    return true
end

-- Step 1: Grab nozzle from charger
local function grabChargingNozzle(stationId, chargerCoords)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        HBSFuelNotify('Exit the vehicle first.', 'error')
        return
    end

    if chargingState.active then
        HBSFuelNotify('Return the charging cable first.', 'error')
        return
    end

    if not createChargingHose(chargerCoords) then
        HBSFuelNotify('Failed to grab charging cable.', 'error')
        return
    end

    chargingState.active = true
    chargingState.stationId = stationId
    chargingState.chargerCoords = chargerCoords

    HBSFuelNotify('Charging cable grabbed. Target an electric vehicle to charge.', 'success')
end

-- Step 2: Target vehicle to open refuel NUI
local function openChargeOnVehicle(vehicle)
    if not chargingState.active then return end
    if not DoesEntityExist(vehicle) or not isElectricVehicle(vehicle) then
        HBSFuelNotify('This vehicle is not electric.', 'error')
        return
    end

    chargingState.vehicle = vehicle

    local currentFuel = GetCachedVehicleFuel(vehicle) or 0.0
    local tankCapacity = HBSFuel.GetTankCapacity(vehicle)
    local pricePerLitre = Config.Charging.PricePerLitre or 1.80

    SendNUIMessage({
        action = 'openRefuel',
        stationId = chargingState.stationId,
        stationLabel = 'EV Charging',
        fuelTypes = {
            { value = 'electric', label = 'Electric', price = pricePerLitre },
        },
        currentFuel = currentFuel,
        tankCapacity = tankCapacity,
    })
    SetNuiFocus(true, true)
end

-- Handle NUI confirm for electric
RegisterNUICallback('nuiConfirmRefuel', function(data, cb)
    if not chargingState.active or data.fuelType ~= 'electric' then return end

    cb('ok')
    SetNuiFocus(false, false)

    local vehicle = chargingState.vehicle
    local stationId = chargingState.stationId

    if not vehicle or not DoesEntityExist(vehicle) then
        clearChargingHose()
        return
    end

    local litres = tonumber(data.litres) or 0.0
    local payment = data.paymentMethod or 'cash'
    if litres <= 0 then return end

    local currentFuel = GetCachedVehicleFuel(vehicle) or 0.0
    local capacity = HBSFuel.GetTankCapacity(vehicle)
    litres = math.min(litres, math.max(capacity - currentFuel, 0))

    local result = lib.callback.await('hbs-fuel:server:startCharging', false, stationId, 'electric', litres, payment)
    if not result or not result.ok then
        HBSFuelNotify(result and result.message or 'Charging failed.', 'error')
        return
    end

    local chargeRate = Config.Charging.ChargeRate or 2.0
    local duration = math.ceil(litres / chargeRate) * 1000

    local ok = lib.progressCircle({
        duration = duration,
        label = ('Charging — %.0fL ($%.2f)'):format(litres, result.totalPrice or 0),
        canCancel = true,
        disable = { car = true, move = true, combat = true }
    })

    if ok then
        local finalFuel = math.min(currentFuel + litres, capacity)
        SetCachedVehicleFuel(vehicle, finalFuel)

        local plate = HBSFuelNormalizePlate(GetVehicleNumberPlateText(vehicle))
        if plate then
            HBSFuelSaveFuelByPlate(plate, finalFuel)
        end

        HBSFuelNotify(('Charged %.0fL for $%.2f.'):format(litres, result.totalPrice or 0), 'success')
    else
        HBSFuelNotify('Charging cancelled.', 'inform')
    end

    clearChargingHose()
end)

-- ── VEHICLE TARGET (step 2) ──

CreateThread(function()
    Wait(2500)

    exports.ox_target:addGlobalVehicle({
        {
            name = 'hbs_fuel_ev_charge_vehicle',
            icon = 'fa-solid fa-bolt',
            label = 'Charge Vehicle',
            canInteract = function(entity)
                return chargingState.active and isElectricVehicle(entity)
            end,
            onSelect = function(data)
                openChargeOnVehicle(data.entity)
            end,
        },
    })
end)

-- ── CHARGER PROP SPAWNING + GRAB TARGET (step 1) ──

CreateThread(function()
    Wait(2000)

    local hash = joaat(Config.Charging.PropModel or 'bzzz_pumps_charger_b')
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        Wait(0)
        if GetGameTimer() > timeout then break end
    end
    if not HasModelLoaded(hash) then return end

    for stationId, station in pairs(Stations) do
        if station.chargerPoint then
            local cp = station.chargerPoint
            local prop = CreateObject(hash, cp.x, cp.y, cp.z, false, false, false)
            if prop and prop ~= 0 then
                PlaceObjectOnGroundProperly(prop)
                FreezeEntityPosition(prop, true)
                SetEntityHeading(prop, cp.w or 0.0)
                chargingProps[#chargingProps + 1] = prop

                local chargerCoords = vec3(cp.x, cp.y, cp.z)
                exports.ox_target:addLocalEntity(prop, {
                    {
                        name = ('hbs_fuel_charger_grab_%s'):format(stationId),
                        icon = 'fa-solid fa-plug',
                        label = 'Grab Charging Cable',
                        canInteract = function()
                            return not chargingState.active and not IsPedInAnyVehicle(PlayerPedId(), false)
                        end,
                        onSelect = function()
                            grabChargingNozzle(stationId, chargerCoords)
                        end
                    },
                    {
                        name = ('hbs_fuel_charger_return_%s'):format(stationId),
                        icon = 'fa-solid fa-rotate-left',
                        label = 'Return Charging Cable',
                        canInteract = function()
                            return chargingState.active
                        end,
                        onSelect = function()
                            clearChargingHose()
                            HBSFuelNotify('Charging cable returned.', 'success')
                        end
                    },
                })
            end
        end
    end

    SetModelAsNoLongerNeeded(hash)
end)

-- ── CLEANUP LOOP ──

CreateThread(function()
    while true do
        if chargingState.active then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped) then
                clearChargingHose()
                HBSFuelNotify('Charging cable returned.', 'inform')
            elseif chargingState.chargerCoords then
                local dist = #(GetEntityCoords(ped) - chargingState.chargerCoords)
                if dist > (Config.Tanker.HoseMaxDistance or 15.0) then
                    clearChargingHose()
                    HBSFuelNotify('Too far from charger — cable returned.', 'error')
                end
            end
            Wait(350)
        else
            Wait(750)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clearChargingHose()
    for _, prop in ipairs(chargingProps) do
        if DoesEntityExist(prop) then
            SetEntityAsMissionEntity(prop, true, true)
            DeleteObject(prop)
        end
    end
    chargingProps = {}
end)

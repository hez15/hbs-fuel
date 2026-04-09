if not Config.Charging or not Config.Charging.Enabled then return end

local chargingProps = {}
local chargingHose = {
    active = false,
    prop = nil,
    anchor = nil,
    rope = nil,
    stationId = nil,
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

    if chargingHose.rope then
        DeleteRope(chargingHose.rope)
        chargingHose.rope = nil
    end
    if chargingHose.prop and DoesEntityExist(chargingHose.prop) then
        DetachEntity(chargingHose.prop, true, true)
        SetEntityAsMissionEntity(chargingHose.prop, true, true)
        DeleteObject(chargingHose.prop)
        if DoesEntityExist(chargingHose.prop) then DeleteEntity(chargingHose.prop) end
    end
    if chargingHose.anchor and DoesEntityExist(chargingHose.anchor) then
        SetEntityAsMissionEntity(chargingHose.anchor, true, true)
        DeleteObject(chargingHose.anchor)
        if DoesEntityExist(chargingHose.anchor) then DeleteEntity(chargingHose.anchor) end
    end

    chargingHose.prop = nil
    chargingHose.anchor = nil
    chargingHose.active = false
    chargingHose.stationId = nil
end

local function createChargingHose(anchorCoords)
    clearChargingHose()

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

    -- Anchor prop at charger
    local anchorModelName = nozzleCfg.rope and nozzleCfg.rope.anchorModel or nozzleCfg.model
    local anchorHash = joaat(anchorModelName)
    RequestModel(anchorHash)
    timeout = GetGameTimer() + 5000
    while not HasModelLoaded(anchorHash) do Wait(0); if GetGameTimer() > timeout then break end end

    local anchor = CreateObject(anchorHash, anchorCoords.x, anchorCoords.y, anchorCoords.z, false, false, false)
    if anchor and anchor ~= 0 then
        FreezeEntityPosition(anchor, true)
        SetEntityCollision(anchor, false, false)
        PlaceObjectOnGroundProperly(anchor)
        SetModelAsNoLongerNeeded(anchorHash)
    end

    -- Rope
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
            ropeCfg.timeMultiplier or 1.0,
            ropeCfg.breakable or false
        )
        if rope then
            AttachEntitiesToRope(rope, anchor or 0, prop, anchorCoords.x + anchorOff.x, anchorCoords.y + anchorOff.y, anchorCoords.z + anchorOff.z, pedCoords.x, pedCoords.y, pedCoords.z + 0.5, ropeCfg.length or 7.5, false, false, nil, nil)
            chargingHose.rope = rope
        end
    end

    chargingHose.prop = prop
    chargingHose.anchor = anchor
    chargingHose.active = true

    -- Play carry anim
    local anim = Config.NozzleCarryAnim
    if anim and anim.dict and anim.clip then
        RequestAnimDict(anim.dict)
        timeout = GetGameTimer() + 3000
        while not HasAnimDictLoaded(anim.dict) do Wait(0); if GetGameTimer() > timeout then break end end
        TaskPlayAnim(ped, anim.dict, anim.clip, 2.0, 2.0, -1, anim.flag or 49, 0.0, false, false, false)
    end

    return true
end

local function handleCharge(stationId, chargerCoords)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        HBSFuelNotify('Exit the vehicle to charge.', 'error')
        return
    end
    local vehicle = lib.getClosestVehicle(GetEntityCoords(ped), 8.0, true)
    if not vehicle or vehicle == 0 or not isElectricVehicle(vehicle) then
        HBSFuelNotify('No electric vehicle nearby.', 'error')
        return
    end

    local currentFuel = GetCachedVehicleFuel(vehicle) or 0.0
    local capacity = HBSFuel.GetTankCapacity(vehicle)
    local needed = math.max(capacity - currentFuel, 0)

    if needed <= 0.5 then
        HBSFuelNotify('Vehicle is already fully charged.', 'inform')
        return
    end

    local pricePerLitre = Config.Charging.PricePerLitre or 1.80

    local input = lib.inputDialog('EV Charging', {
        {
            type = 'slider',
            label = 'Charge Amount (L)',
            default = math.ceil(needed),
            min = 1,
            max = math.ceil(needed),
            step = 1,
        },
        {
            type = 'select',
            label = 'Payment',
            options = {
                { label = 'Cash', value = 'cash' },
                { label = 'Bank', value = 'bank' },
            },
            default = 'cash',
        },
    })

    if not input then return end

    local litres = tonumber(input[1]) or 0.0
    local payment = input[2] or 'cash'
    if litres <= 0 then return end
    litres = math.min(litres, needed)

    local result = lib.callback.await('hbs-fuel:server:startCharging', false, stationId, 'electric', litres, payment)
    if not result or not result.ok then
        HBSFuelNotify(result and result.message or 'Charging failed.', 'error')
        return
    end

    -- Create hose from charger to player
    createChargingHose(chargerCoords)

    local chargeRate = Config.Charging.ChargeRate or 2.0
    local duration = math.ceil(litres / chargeRate) * 1000

    local ok = lib.progressCircle({
        duration = duration,
        label = ('Charging — %.0fL ($%.2f)'):format(litres, result.totalPrice or 0),
        canCancel = true,
        disable = { car = true, move = true, combat = true }
    })

    clearChargingHose()

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
end

-- ── PROP SPAWNING + TARGETS ──

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
                        name = ('hbs_fuel_charger_%s'):format(stationId),
                        icon = 'fa-solid fa-bolt',
                        label = 'Charge Electric Vehicle',
                        canInteract = function()
                            local ped = PlayerPedId()
                            if IsPedInAnyVehicle(ped, false) then return false end
                            local veh = lib.getClosestVehicle(GetEntityCoords(ped), 8.0, true)
                            return veh and veh ~= 0 and isElectricVehicle(veh)
                        end,
                        onSelect = function()
                            handleCharge(stationId, chargerCoords)
                        end
                    },
                })
            end
        end
    end

    SetModelAsNoLongerNeeded(hash)
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

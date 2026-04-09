if not Config.Charging or not Config.Charging.Enabled then return end

local chargingProps = {}

local function isElectricVehicle(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    local fuelTypes = HBSFuel.GetSupportedFuelTypes(nil, vehicle)
    if fuelTypes then
        for _, ft in ipairs(fuelTypes) do
            if ft == 'electric' then return true end
        end
    end
    return false
end

local function openChargingNUI(vehicle, stationId)
    local currentFuel = GetCachedVehicleFuel(vehicle) or 0.0
    local capacity = HBSFuel.GetTankCapacity(vehicle)

    SendNUIMessage({
        action = 'openCharging',
        currentFuel = currentFuel,
        tankCapacity = capacity,
        pricePerLitre = Config.Charging.PricePerLitre or 1.80,
        stationId = stationId,
    })
    SetNuiFocus(true, true)
end

RegisterNUICallback('nuiStartCharging', function(data, cb)
    cb('ok')
    SetNuiFocus(false, false)

    local ped = PlayerPedId()
    local vehicle = lib.getClosestVehicle(GetEntityCoords(ped), 5.0, true)
    if not vehicle or vehicle == 0 or not isElectricVehicle(vehicle) then
        HBSFuelNotify('No electric vehicle nearby.', 'error')
        return
    end

    local litres = tonumber(data.litres) or 0.0
    if litres <= 0 then return end

    local currentFuel = GetCachedVehicleFuel(vehicle) or 0.0
    local capacity = HBSFuel.GetTankCapacity(vehicle)
    local needed = math.max(capacity - currentFuel, 0)
    litres = math.min(litres, needed)
    if litres <= 0 then
        HBSFuelNotify('Vehicle is already full.', 'inform')
        return
    end

    local result = lib.callback.await('hbs-fuel:server:startCharging', false, data.stationId, 'electric', litres, data.payment or 'cash')
    if not result or not result.ok then
        HBSFuelNotify(result and result.message or 'Charging failed.', 'error')
        return
    end

    local chargeRate = Config.Charging.ChargeRate or 2.0
    local duration = math.ceil(litres / chargeRate) * 1000

    ShowRefuelProgress(litres, litres)

    local ok = lib.progressCircle({
        duration = duration,
        label = 'Charging vehicle...',
        canCancel = true,
        disable = { car = true, move = true, combat = true }
    })

    HideRefuelProgress()

    if ok then
        local finalFuel = math.min(currentFuel + litres, capacity)
        SetCachedVehicleFuel(vehicle, finalFuel)

        local plate = HBSFuelNormalizePlate(GetVehicleNumberPlateText(vehicle))
        if plate then
            HBSFuelSaveFuelByPlate(plate, finalFuel)
        end

        HBSFuelNotify(('Charged %.1fL for $%.2f.'):format(litres, result.totalPrice or 0), 'success')
    else
        HBSFuelNotify('Charging cancelled.', 'inform')
    end
end)

-- ── PROP SPAWNING + TARGETS ──

CreateThread(function()
    Wait(2000)

    for i, loc in ipairs(Config.Charging.Locations or {}) do
        local hash = joaat(Config.Charging.PropModel or 'bzzz_pumps_charger_b')
        RequestModel(hash)
        local timeout = GetGameTimer() + 5000
        while not HasModelLoaded(hash) do
            Wait(0)
            if GetGameTimer() > timeout then break end
        end

        if HasModelLoaded(hash) then
            local prop = CreateObject(hash, loc.coords.x, loc.coords.y, loc.coords.z, false, false, false)
            if prop and prop ~= 0 then
                PlaceObjectOnGroundProperly(prop)
                FreezeEntityPosition(prop, true)
                if loc.heading then
                    SetEntityHeading(prop, loc.heading)
                end
                chargingProps[#chargingProps + 1] = prop

                exports.ox_target:addLocalEntity(prop, {
                    {
                        name = ('hbs_fuel_charger_%d'):format(i),
                        icon = 'fa-solid fa-bolt',
                        label = 'Charge Electric Vehicle',
                        canInteract = function()
                            local ped = PlayerPedId()
                            local veh = lib.getClosestVehicle(GetEntityCoords(ped), 5.0, true)
                            return veh and veh ~= 0 and isElectricVehicle(veh)
                        end,
                        onSelect = function()
                            local ped = PlayerPedId()
                            local veh = lib.getClosestVehicle(GetEntityCoords(ped), 5.0, true)
                            if veh and veh ~= 0 then
                                local stationId = HBSFuel.GetClosestStation(loc.coords)
                                openChargingNUI(veh, stationId)
                            end
                        end
                    },
                })
            end
            SetModelAsNoLongerNeeded(hash)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, prop in ipairs(chargingProps) do
        if DoesEntityExist(prop) then
            SetEntityAsMissionEntity(prop, true, true)
            DeleteObject(prop)
        end
    end
    chargingProps = {}
end)

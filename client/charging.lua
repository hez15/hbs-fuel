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

local function handleCharge(stationId)
    local ped = PlayerPedId()
    local vehicle = lib.getClosestVehicle(GetEntityCoords(ped), 6.0, true)
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
    local estimatedCost = litres * pricePerLitre

    local confirm = lib.alertDialog({
        header = 'Confirm Charge',
        content = ('Charge **%.0fL** for **$%.2f**?'):format(litres, estimatedCost),
        centered = true,
        cancel = true,
    })

    if confirm ~= 'confirm' then return end

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

                exports.ox_target:addLocalEntity(prop, {
                    {
                        name = ('hbs_fuel_charger_%s'):format(stationId),
                        icon = 'fa-solid fa-bolt',
                        label = 'Charge Electric Vehicle',
                        canInteract = function()
                            local veh = lib.getClosestVehicle(GetEntityCoords(PlayerPedId()), 6.0, true)
                            return veh and veh ~= 0 and isElectricVehicle(veh)
                        end,
                        onSelect = function()
                            handleCharge(stationId)
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
    for _, prop in ipairs(chargingProps) do
        if DoesEntityExist(prop) then
            SetEntityAsMissionEntity(prop, true, true)
            DeleteObject(prop)
        end
    end
    chargingProps = {}
end)

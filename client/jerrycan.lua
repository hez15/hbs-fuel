RegisterNetEvent('hbs-fuel:client:useJerryCan', function(item)
    if not Config.Features.JerryCan then return end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicle = lib.getClosestVehicle(coords, 4.0, true)
    if vehicle == 0 then
        HBSFuelNotify('No vehicle nearby.', 'error')
        return
    end

    local metadata = item and item.metadata or {}
    local litresAvailable = tonumber(metadata.litres) or 0.0
    if litresAvailable <= 0.0 then
        HBSFuelNotify('This jerry can is empty.', 'error')
        return
    end

    local fuelType = metadata.fuelType or Config.DefaultFuelType
    if not HBSFuel.CanVehicleUseFuelType(vehicle, fuelType) then
        HBSFuelNotify(Config.Notifications.RefuelBlockedIncompatibleVehicle, 'error')
        return
    end

    local currentFuel = GetCachedVehicleFuel(vehicle) or 0.0
    local capacity = HBSFuel.GetTankCapacity(vehicle)
    local needed = math.max(capacity - currentFuel, 0.0)
    if needed <= 0.05 then
        HBSFuelNotify('Vehicle is already full.', 'inform')
        return
    end

    local used = math.min(needed, litresAvailable)
    local finalFuel = currentFuel + used
    SetCachedVehicleFuel(vehicle, finalFuel)

    local plate = HBSFuelNormalizePlate(GetVehicleNumberPlateText(vehicle))
    if plate then
        HBSFuelSaveFuelByPlate(plate, finalFuel)
    end

    TriggerServerEvent('hbs-fuel:server:updateJerryCan', item.slot, litresAvailable - used)
    HBSFuelNotify(('Added %.2fL from jerry can.'):format(used), 'success')
end)

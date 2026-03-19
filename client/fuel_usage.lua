CreateThread(function()
    while true do
        if not Config.Features.FuelUsage then
            Wait(1500)
            goto continue
        end

        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
            Wait(1000)
            goto continue
        end

        if Config.Usage.EngineOnOnly and not GetIsVehicleEngineRunning(vehicle) then
            Wait(1000)
            goto continue
        end

        local currentFuel = GetCachedVehicleFuel(vehicle)
        if not currentFuel or currentFuel <= 0.0 then
            SetCachedVehicleFuel(vehicle, 0.0)
            Wait(1000)
            goto continue
        end

        local class = GetVehicleClass(vehicle)
        local classMultiplier = Config.Usage.ClassMultipliers[class] or 1.0
        local rpm = HBSFuel.Clamp(GetVehicleCurrentRpm(vehicle), 0.0, 1.0)
        local speed = GetEntitySpeed(vehicle)

        local drain = Config.Usage.IdleDrainPerSecond
        if Config.Usage.DrainByRPM then
            drain = drain + (((rpm * rpm) * 0.05) * classMultiplier * Config.Usage.BaseDrainMultiplier)
        end

        if speed > 0.1 then
            drain = drain + ((speed / 100.0) * 0.02 * classMultiplier)
        end

        drain = math.max(drain, 0.001)
        SetCachedVehicleFuel(vehicle, currentFuel - drain)

        Wait(1000)

        ::continue::
    end
end)

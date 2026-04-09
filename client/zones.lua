local stationBlips = {}

CreateThread(function()
    -- Station blips (grouped under one legend entry)
    for stationId, station in pairs(Stations) do
        local isAviation = false
        for _, ft in ipairs(station.supports or {}) do
            if ft == 'jetfuel' then isAviation = true break end
        end

        local blip = AddBlipForCoord(station.coords.x, station.coords.y, station.coords.z)
        SetBlipSprite(blip, isAviation and 423 or 361)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.65)
        SetBlipColour(blip, isAviation and 3 or 1)
        SetBlipAsShortRange(blip, true)
        SetBlipCategory(blip, 10)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(isAviation and 'Aviation Fuel' or 'Gas Station')
        EndTextCommandSetBlipName(blip)
        stationBlips[#stationBlips + 1] = blip
    end

    -- Oil shop blips
    for _, shop in pairs(Config.OilShops or {}) do
        local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
        SetBlipSprite(blip, 446)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.65)
        SetBlipColour(blip, 17)
        SetBlipAsShortRange(blip, true)
        SetBlipCategory(blip, 10)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Mechanic Shop')
        EndTextCommandSetBlipName(blip)
        stationBlips[#stationBlips + 1] = blip
    end

    -- Refinery blips
    for _, refinery in pairs(Refineries) do
        local blip = AddBlipForCoord(refinery.coords.x, refinery.coords.y, refinery.coords.z)
        SetBlipSprite(blip, 436)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.75)
        SetBlipColour(blip, 17)
        SetBlipAsShortRange(blip, true)
        SetBlipCategory(blip, 10)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Refinery')
        EndTextCommandSetBlipName(blip)
        stationBlips[#stationBlips + 1] = blip
    end

    if Config.Debug then
        for stationId, station in pairs(Stations) do
            print(('[hbs-fuel] station loaded: %s (%s)'):format(stationId, station.label))
        end
        for refineryId, refinery in pairs(Refineries) do
            print(('[hbs-fuel] refinery loaded: %s (%s)'):format(refineryId, refinery.label))
        end
    end
end)

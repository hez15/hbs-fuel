lib.addCommand('fuel_refill_station', {
    help = 'Refill one station tank',
    params = {
        { name = 'stationId', type = 'string', help = 'Configured station id' },
        { name = 'fuelType', type = 'string', help = 'Fuel type' },
        { name = 'litres', type = 'number', help = 'Litres to add' },
    },
    restricted = 'group.admin'
}, function(source, args)
    local station = StationState[args.stationId]
    if not station then
        TriggerClientEvent('ox_lib:notify', source, { title = 'Fuel', description = 'Station not found.', type = 'error' })
        return
    end

    station.tanks[args.fuelType] = station.tanks[args.fuelType] or { current = 0.0, max = args.litres }
    station.tanks[args.fuelType].current = math.min(station.tanks[args.fuelType].current + args.litres, station.tanks[args.fuelType].max)
    SaveStationState(args.stationId)

    TriggerClientEvent('ox_lib:notify', source, { title = 'Fuel', description = 'Station refilled.', type = 'success' })
end)

lib.addCommand('fuel_pedcoords', {
    help = 'Print your current position as a vec4 for ped placement',
    restricted = 'group.admin'
}, function(source)
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local formatted = ('vec4(%.2f, %.2f, %.2f, %.1f)'):format(coords.x, coords.y, coords.z, heading)
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Ped Coords',
        description = formatted,
        type = 'inform'
    })
    print(('[hbs-fuel] Ped coords for %s: %s'):format(GetPlayerName(source), formatted))
end)

lib.addCommand('fuel_toggle_stock', {
    help = 'Toggle station stock use',
    restricted = 'group.admin'
}, function(source)
    Config.Features.StationStock = not Config.Features.StationStock
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Fuel',
        description = ('Station stock %s'):format(Config.Features.StationStock and 'enabled' or 'disabled'),
        type = 'success'
    })
end)

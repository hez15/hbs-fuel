CreateThread(function()
    if Config.Debug then
        for stationId, station in pairs(Stations) do
            print(('[hbs-fuel] station loaded: %s (%s)'):format(stationId, station.label))
        end
        for refineryId, refinery in pairs(Refineries) do
            print(('[hbs-fuel] refinery loaded: %s (%s)'):format(refineryId, refinery.label))
        end
    end
end)

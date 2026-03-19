CreateThread(function()
    Wait(1000)
    print('[hbs-fuel] starter resource loaded')
end)
local activeNozzles = {}

CreateThread(function()
    Wait(1000)
    print('[hbs-fuel] starter resource loaded')
end)

RegisterNetEvent('hbs-fuel:server:syncNozzleGrab', function()
    local src = source
    activeNozzles[src] = true
    TriggerClientEvent('hbs-fuel:client:syncNozzleGrab', -1, src)
end)

RegisterNetEvent('hbs-fuel:server:syncNozzleReturn', function()
    local src = source
    activeNozzles[src] = nil
    TriggerClientEvent('hbs-fuel:client:syncNozzleReturn', -1, src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    if activeNozzles[src] then
        activeNozzles[src] = nil
        TriggerClientEvent('hbs-fuel:client:syncNozzleReturn', -1, src)
    end
end)

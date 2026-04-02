local activeNozzles = {}

CreateThread(function()
    Wait(1000)
    print('[hbs-fuel] resource loaded')
end)

RegisterNetEvent('hbs-fuel:server:syncNozzleGrab', function(anchorCoords)
    local src = source
    activeNozzles[src] = { anchor = anchorCoords }
    TriggerClientEvent('hbs-fuel:client:syncNozzleGrab', -1, src, anchorCoords)
end)

RegisterNetEvent('hbs-fuel:server:syncNozzleReturn', function()
    local src = source
    activeNozzles[src] = nil
    TriggerClientEvent('hbs-fuel:client:syncNozzleReturn', -1, src)
end)

RegisterNetEvent('hbs-fuel:server:syncHoseGrab', function(anchorCoords)
    local src = source
    TriggerClientEvent('hbs-fuel:client:syncHoseGrab', -1, src, anchorCoords)
end)

RegisterNetEvent('hbs-fuel:server:syncHoseReturn', function()
    local src = source
    TriggerClientEvent('hbs-fuel:client:syncHoseReturn', -1, src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    if activeNozzles[src] then
        activeNozzles[src] = nil
        TriggerClientEvent('hbs-fuel:client:syncNozzleReturn', -1, src)
    end
    TriggerClientEvent('hbs-fuel:client:syncHoseReturn', -1, src)
end)

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

RegisterNetEvent('hbs-fuel:server:updateJerryCan', function(slot, newLitres)
    local src = source
    slot = tonumber(slot)
    newLitres = tonumber(newLitres) or 0.0
    if not slot then return end

    if newLitres <= 0.01 then
        exports.ox_inventory:SetMetadata(src, slot, { litres = 0, fuelType = nil })
    else
        exports.ox_inventory:SetMetadata(src, slot, { litres = HBSFuel.Round(newLitres, 2) })
    end
end)

-- ── ADMIN COMMANDS ──

RegisterCommand('fueladmin', function(source, args)
    if source > 0 and not IsPlayerAceAllowed(source, 'hbs-fuel.admin') then
        TriggerClientEvent('ox_lib:notify', source, { title = 'Fuel', description = 'No permission.', type = 'error' })
        return
    end

    local action = args[1]

    if action == 'addstock' then
        local stationId = args[2]
        local fuelType = args[3]
        local litres = tonumber(args[4]) or 5000
        if not stationId or not fuelType then
            print('[hbs-fuel] Usage: fueladmin addstock <stationId> <fuelType> [litres]')
            return
        end
        local ok = exports['hbs-fuel']:AddStationStock(stationId, fuelType, litres)
        print(('[hbs-fuel] AddStationStock %s %s %d → %s'):format(stationId, fuelType, litres, tostring(ok)))

    elseif action == 'addcrude' then
        local refineryId = args[2]
        local litres = tonumber(args[3]) or 10000
        if not refineryId then
            print('[hbs-fuel] Usage: fueladmin addcrude <refineryId> [litres]')
            return
        end
        local ok = exports['hbs-fuel']:AddCrudeToRefinery(refineryId, litres)
        print(('[hbs-fuel] AddCrudeToRefinery %s %d → %s'):format(refineryId, litres, tostring(ok)))

    elseif action == 'filltanker' then
        local plate = args[2]
        local fuelType = args[3] or 'regular'
        local litres = tonumber(args[4]) or 12000
        if not plate then
            print('[hbs-fuel] Usage: fueladmin filltanker <plate> <fuelType> [litres]')
            return
        end
        exports['hbs-fuel']:SetTankerLoad(plate, fuelType, litres, litres)
        print(('[hbs-fuel] SetTankerLoad %s %s %d'):format(plate, fuelType, litres))

    elseif action == 'refinery' then
        local refineryId = args[2]
        if not refineryId then
            print('[hbs-fuel] Usage: fueladmin refinery <refineryId>')
            return
        end
        local data = RefineryState and RefineryState[refineryId]
        if data then
            print(('[hbs-fuel] Refinery %s — Crude: %.0f/%.0f'):format(refineryId, data.crude.current, data.crude.max))
            for ft, stock in pairs(data.products or {}) do
                print(('  %s: %.0f/%.0f'):format(ft, stock.current, stock.max))
            end
        else
            print('[hbs-fuel] Refinery not found: ' .. refineryId)
        end

    elseif action == 'station' then
        local stationId = args[2]
        if not stationId then
            print('[hbs-fuel] Usage: fueladmin station <stationId>')
            return
        end
        local data = StationState and StationState[stationId]
        if data then
            print(('[hbs-fuel] Station %s'):format(stationId))
            for ft, tank in pairs(data.tanks or {}) do
                print(('  %s: %.0f/%.0f'):format(ft, tank.current, tank.max))
            end
        else
            print('[hbs-fuel] Station not found: ' .. stationId)
        end

    else
        print('[hbs-fuel] Commands: addstock, addcrude, filltanker, refinery, station')
    end
end, true)

AddEventHandler('playerDropped', function()
    local src = source
    if activeNozzles[src] then
        activeNozzles[src] = nil
        TriggerClientEvent('hbs-fuel:client:syncNozzleReturn', -1, src)
    end
    TriggerClientEvent('hbs-fuel:client:syncHoseReturn', -1, src)
end)

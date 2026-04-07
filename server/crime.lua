if not Config.Crime or not Config.Crime.Enabled then return end

RegisterNetEvent('hbs-fuel:server:siphonTanker', function(plate, litres)
    local src = source
    if not plate then return end
    litres = tonumber(litres) or 10.0

    local load = MySQL.single.await('SELECT fuel_type, litres, max_litres FROM hbs_fuel_tanker_state WHERE plate = ?', { plate })
    if not load or not load.fuel_type or tonumber(load.litres) <= 0 then return end

    local tankerLitres = tonumber(load.litres)
    local siphoned = math.min(litres, tankerLitres)
    if siphoned <= 0 then return end

    exports['hbs-fuel']:SetTankerLoad(
        plate,
        tankerLitres - siphoned > 0.01 and load.fuel_type or nil,
        math.max(tankerLitres - siphoned, 0.0),
        tonumber(load.max_litres) or Config.Tanker.DefaultMaxLitres
    )

    local itemName = Config.Items.JerryCanFilled or 'jerry_can_fuel'
    local canCarry = exports.ox_inventory:CanCarryItem(src, itemName, 1)
    if canCarry then
        exports.ox_inventory:AddItem(src, itemName, 1, {
            litres = siphoned,
            fuelType = load.fuel_type
        })
    end

    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Fuel',
        description = ('Siphoned %.0fL of %s.'):format(siphoned, load.fuel_type),
        type = 'success'
    })
end)

lib.callback.register('hbs-fuel:server:blackMarketSell', function(source, plate)
    if not plate then
        return { ok = false, message = 'Invalid plate.' }
    end

    local load = MySQL.single.await('SELECT fuel_type, litres, max_litres FROM hbs_fuel_tanker_state WHERE plate = ?', { plate })
    if not load or not load.fuel_type or tonumber(load.litres) <= 0 then
        return { ok = false, message = 'Tanker is empty.' }
    end

    local litres = tonumber(load.litres)
    local payPerLitre = Config.Crime.BlackMarketPayPerLitre or 0.30
    local payout = math.floor(litres * payPerLitre)

    exports['hbs-fuel']:SetTankerLoad(plate, nil, 0.0, tonumber(load.max_litres) or Config.Tanker.DefaultMaxLitres)

    if HBSFuelAddMoney and payout > 0 then
        HBSFuelAddMoney(source, 'cash', payout, 'fuel_blackmarket_sale')
    end

    return { ok = true, message = ('Sold %.0fL for $%d cash.'):format(litres, payout) }
end)

RegisterNetEvent('hbs-fuel:server:crimeAlert', function(crimeType, coords)
    if not Config.Crime.PoliceAlert then return end

    local dispatchEvent = Config.Crime.DispatchEvent
    if dispatchEvent then
        TriggerEvent(dispatchEvent, crimeType, coords, source)
    else
        local label = crimeType == 'siphon' and 'Fuel Theft in Progress' or 'Suspicious Fuel Sale'
        for _, playerId in ipairs(GetPlayers()) do
            playerId = tonumber(playerId)
            if IsPlayerAceAllowed(playerId, 'hbs-fuel.police') then
                TriggerClientEvent('ox_lib:notify', playerId, {
                    title = 'Police Dispatch',
                    description = label,
                    type = 'error'
                })
            end
        end
    end
end)

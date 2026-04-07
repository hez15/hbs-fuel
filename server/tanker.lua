lib.callback.register('hbs-fuel:server:getTankerLoad', function(_, plate)
    if not plate then return nil end
    plate = plate:gsub('^%s*(.-)%s*$', '%1')

    local row = MySQL.single.await('SELECT fuel_type, litres, max_litres FROM hbs_fuel_tanker_state WHERE plate = ?', { plate })
    if not row then return nil end

    return {
        fuelType = row.fuel_type,
        litres = tonumber(row.litres),
        maxLitres = tonumber(row.max_litres),
    }
end)

exports('SetTankerLoad', function(plate, fuelType, litres, maxLitres)
    MySQL.prepare.await([[INSERT INTO hbs_fuel_tanker_state (plate, fuel_type, litres, max_litres)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE fuel_type = VALUES(fuel_type), litres = VALUES(litres), max_litres = VALUES(max_litres)]], {
        plate, fuelType, litres, maxLitres or 12000.0
    })
end)

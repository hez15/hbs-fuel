lib.callback.register('hbs-fuel:server:getVehicleFuel', function(_, plate)
    if not plate then return nil end
    local row = MySQL.single.await('SELECT litres FROM hbs_fuel_vehicle_state WHERE plate = ?', { plate })
    return row and tonumber(row.litres) or nil
end)

RegisterNetEvent('hbs-fuel:server:saveVehicleFuel', function(plate, litres)
    if not plate or type(litres) ~= 'number' then return end

    MySQL.prepare.await([[INSERT INTO hbs_fuel_vehicle_state (plate, litres)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE litres = VALUES(litres)]], {
        plate, HBSFuel.Clamp(litres, 0.0, 50000.0)
    })
end)

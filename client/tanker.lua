exports('GetTankerVehicleLoad', function(vehicle)
    if not DoesEntityExist(vehicle) then return nil end
    local plate = GetVehicleNumberPlateText(vehicle)
    return lib.callback.await('hbs-fuel:server:getTankerLoad', false, plate)
end)

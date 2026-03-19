FuelContracts = FuelContracts or {}

exports('CreateFuelContract', function(data)
    local id = ('fuel_%s_%s'):format(os.time(), math.random(1000, 9999))
    FuelContracts[id] = {
        id = id,
        type = data.type or 'delivery',
        stationId = data.stationId,
        fuelType = data.fuelType,
        litres = data.litres,
        payout = data.payout or 0,
        status = 'open',
        createdAt = os.time(),
    }

    return FuelContracts[id]
end)

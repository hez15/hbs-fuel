exports('GetTankerVehicleLoad', function(vehicle)
    if not DoesEntityExist(vehicle) then return nil end
    local plate = HBSFuelNormalizePlate(GetVehicleNumberPlateText(vehicle))
    return lib.callback.await('hbs-fuel:server:getTankerLoad', false, plate)
end)

-- ── TANKER CONTENT INSPECTION ──

local function isTankerModel(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    local model = GetEntityModel(vehicle)
    for _, name in ipairs(Config.Tanker.SupportedModels or {}) do
        if model == joaat(name) then return true end
    end
    return false
end

local function formatTankerContents(load)
    if not load or not load.fuelType or (load.litres or 0.0) <= 0.0 then
        return 'Tanker is **empty**.'
    end

    local fuel = FuelTypes and FuelTypes[load.fuelType]
    local label = (fuel and fuel.label) or (load.fuelType == 'crude' and 'Crude Oil') or load.fuelType
    local litres = load.litres or 0.0
    local maxLitres = load.maxLitres or Config.Tanker.DefaultMaxLitres or 12000.0
    local pct = maxLitres > 0 and (litres / maxLitres * 100.0) or 0.0

    return ('**%s**  \n%.1fL / %.0fL (%.0f%%)'):format(label, litres, maxLitres, pct)
end

local function handleInspectTanker(vehicle)
    if not DoesEntityExist(vehicle) then return end
    local plate = HBSFuelNormalizePlate(GetVehicleNumberPlateText(vehicle))
    if not plate then return end

    local load = lib.callback.await('hbs-fuel:server:getTankerLoad', false, plate)
    lib.notify({
        title = 'Tanker Contents',
        description = formatTankerContents(load),
        type = 'inform',
        duration = 6000,
    })
end

CreateThread(function()
    if not Config.UseOxTarget then return end

    exports.ox_target:addGlobalVehicle({
        {
            name = 'hbs_fuel_inspect_tanker',
            icon = 'fa-solid fa-gauge',
            label = 'Check Tanker Contents',
            distance = 2.5,
            canInteract = function(entity)
                return isTankerModel(entity)
            end,
            onSelect = function(data)
                handleInspectTanker(data.entity)
            end,
        },
    })
end)

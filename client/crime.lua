if not Config.Crime or not Config.Crime.Enabled then return end

-- ── DISPATCH ──

local function dispatchAlert(crimeType, coords)
    local dispatch = Config.Crime.Dispatch or 'ps-dispatch'

    if dispatch == 'ps-dispatch' then
        local alertData = {
            coords = coords,
            gender = IsPedMale(PlayerPedId()) and 'male' or 'female',
        }
        if crimeType == 'siphon' then
            exports['ps-dispatch']:CustomAlert({
                coords = coords,
                message = 'Fuel Theft in Progress',
                dispatchCode = '10-90',
                description = 'Suspect siphoning fuel from a tanker vehicle',
                radius = 0,
                sprite = 477,
                color = 1,
                scale = 1.0,
                length = 3,
                sound = 'Lose_1st',
                sound2 = 'GTAO_FM_Events_Soundset',
            })
        elseif crimeType == 'blackmarket' then
            exports['ps-dispatch']:CustomAlert({
                coords = coords,
                message = 'Suspicious Fuel Sale',
                dispatchCode = '10-31',
                description = 'Suspect selling stolen fuel at an illegal drop-off',
                radius = 0,
                sprite = 477,
                color = 1,
                scale = 1.0,
                length = 3,
                sound = 'Lose_1st',
                sound2 = 'GTAO_FM_Events_Soundset',
            })
        end
    elseif dispatch == 'custom' and Config.Crime.DispatchEvent then
        TriggerEvent(Config.Crime.DispatchEvent, crimeType, coords)
    end
end

RegisterNetEvent('hbs-fuel:client:crimeAlert', function(crimeType, coords)
    dispatchAlert(crimeType, coords)
end)

-- ── SIPHON FUEL FROM TANKERS ──

local function isTankerVehicle(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    local model = GetEntityModel(vehicle)
    for _, name in ipairs(Config.Tanker.SupportedModels or {}) do
        if model == joaat(name) then return true end
    end
    return false
end

local function handleSiphonTanker(vehicle)
    if not Config.Crime.SiphonEnabled then return end

    local load = exports['hbs-fuel']:GetTankerVehicleLoad(vehicle)
    if not load or not load.fuelType or (load.litres or 0) <= 0 then
        HBSFuelNotify('This tanker is empty.', 'error')
        return
    end

    local plate = HBSFuelNormalizePlate(GetVehicleNumberPlateText(vehicle))
    local litresPerCan = Config.Crime.SiphonLitresPerCan or 10.0

    local ped = PlayerPedId()
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_WELDING', 0, true)

    local ok = lib.progressCircle({
        duration = (Config.Crime.SiphonTimeSeconds or 30) * 1000,
        label = 'Siphoning fuel...',
        canCancel = true,
        disable = { car = true, move = true, combat = true }
    })

    ClearPedTasks(ped)

    if not ok then return end

    TriggerServerEvent('hbs-fuel:server:siphonTanker', plate, litresPerCan)

    if Config.Crime.PoliceAlert then
        dispatchAlert('siphon', GetEntityCoords(PlayerPedId()))
    end
end

-- ── BLACK MARKET DROP-OFF ──

local function handleBlackMarketSell(dropoffIndex, point)
    local tanker, _, _, modelName, foundAnyTanker = getNearbySupportedTanker(point, nil)
    if not tanker then
        HBSFuelNotify('No tanker nearby.', 'error')
        return
    end

    local load = exports['hbs-fuel']:GetTankerVehicleLoad(tanker)
    if not load or not load.fuelType or (load.litres or 0) <= 0 then
        HBSFuelNotify('Tanker is empty.', 'error')
        return
    end

    local ok = lib.progressCircle({
        duration = 15000,
        label = 'Selling fuel...',
        canCancel = true,
        disable = { car = true, move = true, combat = true }
    })

    if not ok then return end

    local plate = HBSFuelNormalizePlate(GetVehicleNumberPlateText(tanker))
    local result = lib.callback.await('hbs-fuel:server:blackMarketSell', false, plate)
    HBSFuelNotify(result and result.message or 'Sale failed.', result and result.ok and 'success' or 'error')

    if Config.Crime.PoliceAlert and result and result.ok then
        dispatchAlert('blackmarket', GetEntityCoords(PlayerPedId()))
    end
end

-- ── TARGET REGISTRATION ──

CreateThread(function()
    if not Config.UseOxTarget then return end

    -- Siphon target on all tanker vehicles
    if Config.Crime.SiphonEnabled then
        exports.ox_target:addGlobalVehicle({
            {
                name = 'hbs_fuel_siphon',
                icon = 'fa-solid fa-faucet-drip',
                label = 'Siphon Fuel',
                canInteract = function(entity)
                    return isTankerVehicle(entity)
                end,
                onSelect = function(data)
                    handleSiphonTanker(data.entity)
                end
            },
        })
    end

    -- Black market drop-off zones
    for index, dropoff in ipairs(Config.Crime.BlackMarketDropoffs or {}) do
        exports.ox_target:addSphereZone({
            coords = dropoff.coords,
            radius = dropoff.radius or 4.0,
            debug = Config.Debug,
            options = {
                {
                    name = ('hbs_fuel_blackmarket_%d'):format(index),
                    icon = 'fa-solid fa-sack-dollar',
                    label = 'Sell Fuel (Black Market)',
                    onSelect = function()
                        handleBlackMarketSell(index, dropoff.coords)
                    end
                },
            }
        })
    end
end)

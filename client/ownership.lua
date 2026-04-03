local shopPed = nil
local shopBlip = nil

local function getEntityLabel(entityType, entityId)
    if entityType == 'station' and Stations[entityId] then
        return Stations[entityId].label
    elseif entityType == 'refinery' and Refineries[entityId] then
        return Refineries[entityId].label
    end
    return entityId
end

local function spawnShopPed()
    local cfg = Config.Ownership
    if not cfg or not cfg.Enabled then return end

    local pedPos = cfg.PedCoords
    if not pedPos or (pedPos.x == 0.0 and pedPos.y == 0.0 and pedPos.z == 0.0) then
        if Config.Debug then
            print('[hbs-fuel] Ownership ped coords not set — skipping ped spawn. Set Config.Ownership.PedCoords.')
        end
        return
    end

    local model = cfg.PedModel or 's_m_y_autoshop_02'
    local hash = type(model) == 'string' and GetHashKey(model) or model

    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    if not HasModelLoaded(hash) then
        print('[hbs-fuel] Failed to load ownership ped model: ' .. tostring(model))
        return
    end

    shopPed = CreatePed(0, hash, pedPos.x, pedPos.y, pedPos.z, pedPos.w or 0.0, false, true)
    if not shopPed or shopPed == 0 then
        print('[hbs-fuel] Failed to create ownership ped at ' .. tostring(pedPos))
        return
    end

    SetPedFleeAttributes(shopPed, 0, false)
    FreezeEntityPosition(shopPed, true)
    SetEntityInvincible(shopPed, true)
    SetBlockingOfNonTemporaryEvents(shopPed, true)
    SetPedDiesWhenInjured(shopPed, false)
    SetPedCanPlayAmbientAnims(shopPed, true)
    SetPedCanRagdollFromPlayerImpact(shopPed, false)
    SetEntityAsMissionEntity(shopPed, true, true)
    PlaceObjectOnGroundProperly(shopPed)
    SetModelAsNoLongerNeeded(hash)

    exports['ox_target']:addLocalEntity(shopPed, {
        {
            name = 'hbs_fuel_shop',
            label = 'Fuel Properties',
            icon = 'fas fa-gas-pump',
            distance = 2.5,
            onSelect = function()
                openShopMenu()
            end,
        }
    })

    shopBlip = AddBlipForCoord(pedPos.x, pedPos.y, pedPos.z)
    SetBlipSprite(shopBlip, cfg.PedBlipSprite or 374)
    SetBlipDisplay(shopBlip, 4)
    SetBlipScale(shopBlip, 0.75)
    SetBlipColour(shopBlip, cfg.PedBlipColour or 46)
    SetBlipAsShortRange(shopBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Fuel Properties')
    EndTextCommandSetBlipName(shopBlip)

    if Config.Debug then
        print('[hbs-fuel] Ownership ped spawned.')
    end
end

local function openPurchaseDialog(entityType, entityId)
    local cfg = Config.Ownership
    if not cfg or not cfg.Enabled then return end

    local prices = entityType == 'station' and cfg.StationPrices or cfg.RefineryPrices
    local price = prices and prices[entityId]
    if not price then
        HBSFuelNotify('This property is not for sale.', 'error')
        return
    end

    local label = getEntityLabel(entityType, entityId)

    local result = lib.alertDialog({
        header = ('Purchase %s'):format(label),
        content = ('Do you want to purchase **%s** for **$%s**?\n\nAs the owner you will earn %.0f%% of all fuel sales revenue and can adjust pricing.'):format(
            label, price, (cfg.OwnerRevenueCut or 0.70) * 100
        ),
        centered = true,
        cancel = true,
        labels = {
            cancel = 'Cancel',
            confirm = 'Purchase'
        }
    })

    if result ~= 'confirm' then return end

    local response = lib.callback.await('hbs-fuel:server:purchaseEntity', false, entityType, entityId)
    if response and response.ok then
        HBSFuelNotify(response.message or 'Property purchased!', 'success')
    else
        HBSFuelNotify(response and response.message or 'Purchase failed.', 'error')
    end
end

function openShopMenu()
    local cfg = Config.Ownership
    if not cfg or not cfg.Enabled then
        HBSFuelNotify('Ownership system is disabled.', 'error')
        return
    end

    local ownedData = lib.callback.await('hbs-fuel:server:getOwnedEntities', false)
    local ownedMap = {}
    if ownedData and ownedData.ok then
        for _, entity in ipairs(ownedData.entities or {}) do
            local key = ('%s_%s'):format(entity.entityType, entity.entityId)
            ownedMap[key] = entity
        end
    end

    local options = {}

    -- Stations
    for stationId, station in pairs(Stations) do
        local key = 'station_' .. stationId
        local owned = ownedMap[key]
        local price = cfg.StationPrices and cfg.StationPrices[stationId]

        if owned then
            local available = HBSFuel.Round((owned.revenueTotal or 0) - (owned.revenueWithdrawn or 0), 2)
            options[#options + 1] = {
                title = station.label,
                description = ('Owned | Revenue: $%.0f available'):format(available),
                icon = 'gas-pump',
                iconColor = '#10b981',
                onSelect = function()
                    OpenOwnerDashboardNUI('station', stationId)
                end,
            }
        elseif price then
            options[#options + 1] = {
                title = station.label,
                description = ('For Sale — $%s'):format(price),
                icon = 'gas-pump',
                iconColor = '#f59e0b',
                onSelect = function()
                    openPurchaseDialog('station', stationId)
                end,
            }
        else
            options[#options + 1] = {
                title = station.label,
                description = 'Not for sale',
                icon = 'gas-pump',
                iconColor = '#666',
                readOnly = true,
            }
        end
    end

    -- Refineries
    for refineryId, refinery in pairs(Refineries) do
        local key = 'refinery_' .. refineryId
        local owned = ownedMap[key]
        local price = cfg.RefineryPrices and cfg.RefineryPrices[refineryId]

        if owned then
            local available = HBSFuel.Round((owned.revenueTotal or 0) - (owned.revenueWithdrawn or 0), 2)
            options[#options + 1] = {
                title = refinery.label,
                description = ('Owned | Revenue: $%.0f available'):format(available),
                icon = 'industry',
                iconColor = '#10b981',
                onSelect = function()
                    OpenOwnerDashboardNUI('refinery', refineryId)
                end,
            }
        elseif price then
            options[#options + 1] = {
                title = refinery.label,
                description = ('For Sale — $%s'):format(price),
                icon = 'industry',
                iconColor = '#f59e0b',
                onSelect = function()
                    openPurchaseDialog('refinery', refineryId)
                end,
            }
        else
            options[#options + 1] = {
                title = refinery.label,
                description = 'Not for sale',
                icon = 'industry',
                iconColor = '#666',
                readOnly = true,
            }
        end
    end

    if #options == 0 then
        options[#options + 1] = {
            title = 'No properties available',
            icon = 'ban',
            readOnly = true,
        }
    end

    lib.registerContext({
        id = 'hbs_fuel_shop',
        title = 'Fuel Properties',
        options = options,
    })

    lib.showContext('hbs_fuel_shop')
end

CreateThread(function()
    if not Config.Ownership or not Config.Ownership.Enabled then return end
    Wait(2000)
    spawnShopPed()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if shopPed and DoesEntityExist(shopPed) then
        DeleteEntity(shopPed)
    end

    if shopBlip and DoesBlipExist(shopBlip) then
        RemoveBlip(shopBlip)
    end
end)

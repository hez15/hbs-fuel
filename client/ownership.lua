local function getEntityLabel(entityType, entityId)
    if entityType == 'station' and Stations[entityId] then
        return Stations[entityId].label
    elseif entityType == 'refinery' and Refineries[entityId] then
        return Refineries[entityId].label
    end
    return entityId
end

local function openPurchaseDialog(entityType, entityId)
    if not Config.Ownership or not Config.Ownership.Enabled then return end

    local prices = entityType == 'station' and Config.Ownership.StationPrices or Config.Ownership.RefineryPrices
    local price = prices and prices[entityId]
    if not price then return end

    local label = getEntityLabel(entityType, entityId)

    local result = lib.alertDialog({
        header = ('Purchase %s'):format(label),
        content = ('Do you want to purchase **%s** for **$%s**?\n\nAs the owner you will earn %.0f%% of all fuel sales revenue and can adjust pricing.'):format(
            label, price, (Config.Ownership.OwnerRevenueCut or 0.70) * 100
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

local function openDashboard(entityType, entityId)
    local data = lib.callback.await('hbs-fuel:server:getOwnerDashboard', false, entityType, entityId)
    if not data or not data.ok then
        HBSFuelNotify(data and data.message or 'Unable to load dashboard.', 'error')
        return
    end

    local options = {}

    options[#options + 1] = {
        title = data.label or entityId,
        description = ('Type: %s'):format(entityType == 'station' and 'Fuel Station' or 'Refinery'),
        icon = entityType == 'station' and 'gas-pump' or 'industry',
        readOnly = true,
    }

    for fuelType, stock in pairs(data.stock or {}) do
        local pct = stock.max > 0 and math.floor((stock.current / stock.max) * 100) or 0
        options[#options + 1] = {
            title = ('%s Stock'):format(fuelType),
            description = ('%.0f / %.0f L (%d%%)'):format(stock.current, stock.max, pct),
            icon = 'fill-drip',
            readOnly = true,
            progress = pct,
        }
    end

    options[#options + 1] = {
        title = 'Revenue',
        description = ('Total: $%.2f | Withdrawn: $%.2f | Available: $%.2f'):format(
            data.revenueTotal or 0, data.revenueWithdrawn or 0, data.revenueAvailable or 0
        ),
        icon = 'money-bill-trend-up',
        iconColor = '#4ade80',
        readOnly = true,
    }

    if (data.revenueAvailable or 0) > 0 then
        options[#options + 1] = {
            title = ('Withdraw $%d'):format(math.floor(data.revenueAvailable)),
            description = 'Deposit available revenue to your bank account.',
            icon = 'money-bill-transfer',
            iconColor = '#60a5fa',
            onSelect = function()
                local result = lib.callback.await('hbs-fuel:server:withdrawRevenue', false, entityType, entityId)
                if result and result.ok then
                    HBSFuelNotify(('Withdrawn $%d to your bank.'):format(result.withdrawn or 0), 'success')
                else
                    HBSFuelNotify(result and result.message or 'Withdrawal failed.', 'error')
                end
            end,
        }
    end

    if entityType == 'station' and data.priceMultiplier then
        options[#options + 1] = {
            title = ('Price Multiplier: %.2fx'):format(data.priceMultiplier),
            description = ('Range: %.1fx - %.1fx'):format(
                Config.Ownership.MinPriceMultiplier or 0.5,
                Config.Ownership.MaxPriceMultiplier or 2.0
            ),
            icon = 'tag',
            onSelect = function()
                local input = lib.inputDialog('Set Price Multiplier', {
                    {
                        type = 'number',
                        label = 'Price Multiplier',
                        default = data.priceMultiplier,
                        min = Config.Ownership.MinPriceMultiplier or 0.5,
                        max = Config.Ownership.MaxPriceMultiplier or 2.0,
                        step = 0.05,
                    }
                })

                if not input then return end

                local newMult = tonumber(input[1])
                if not newMult then return end

                local result = lib.callback.await('hbs-fuel:server:setStationPrice', false, entityId, newMult)
                if result and result.ok then
                    HBSFuelNotify(('Price multiplier set to %.2fx'):format(result.priceMultiplier), 'success')
                else
                    HBSFuelNotify(result and result.message or 'Failed to set price.', 'error')
                end
            end,
        }
    end

    options[#options + 1] = {
        title = 'Refresh',
        icon = 'arrows-rotate',
        onSelect = function()
            openDashboard(entityType, entityId)
        end,
    }

    lib.registerContext({
        id = 'hbs_fuel_owner_dashboard',
        title = ('Owner: %s'):format(data.label or entityId),
        options = options,
    })

    lib.showContext('hbs_fuel_owner_dashboard')
end

local function handleEntityInteraction(entityType, entityId)
    if not Config.Ownership or not Config.Ownership.Enabled then return end

    local ownership = lib.callback.await('hbs-fuel:server:getOwnership', false, entityType, entityId)

    if ownership and ownership.owned and ownership.isOwner then
        OpenOwnerDashboardNUI(entityType, entityId)
    elseif not ownership or not ownership.owned then
        openPurchaseDialog(entityType, entityId)
    else
        HBSFuelNotify(('This property is owned by %s.'):format(ownership.ownerName or 'someone'), 'inform')
    end
end

CreateThread(function()
    if not Config.Ownership or not Config.Ownership.Enabled then return end

    Wait(1500)

    for stationId, station in pairs(Stations) do
        if Config.Ownership.StationPrices[stationId] or true then
            exports['ox_target']:addSphereZone({
                coords = station.coords,
                radius = 2.0,
                options = {
                    {
                        name = ('fuel_ownership_station_%s'):format(stationId),
                        label = 'Station Management',
                        icon = 'fas fa-building',
                        onSelect = function()
                            handleEntityInteraction('station', stationId)
                        end,
                    }
                }
            })
        end
    end

    for refineryId, refinery in pairs(Refineries) do
        if Config.Ownership.RefineryPrices[refineryId] or true then
            exports['ox_target']:addSphereZone({
                coords = refinery.coords,
                radius = 2.0,
                options = {
                    {
                        name = ('fuel_ownership_refinery_%s'):format(refineryId),
                        label = 'Refinery Management',
                        icon = 'fas fa-industry',
                        onSelect = function()
                            handleEntityInteraction('refinery', refineryId)
                        end,
                    }
                }
            })
        end
    end
end)

RegisterCommand('fuelproperties', function()
    if not Config.Ownership or not Config.Ownership.Enabled then
        HBSFuelNotify('Ownership system is disabled.', 'error')
        return
    end

    local data = lib.callback.await('hbs-fuel:server:getOwnedEntities', false)
    if not data or not data.ok or #(data.entities or {}) == 0 then
        HBSFuelNotify('You do not own any properties.', 'inform')
        return
    end

    local options = {}
    for _, entity in ipairs(data.entities) do
        local label = getEntityLabel(entity.entityType, entity.entityId)
        local available = HBSFuel.Round((entity.revenueTotal or 0) - (entity.revenueWithdrawn or 0), 2)

        options[#options + 1] = {
            title = label,
            description = ('Type: %s | Revenue available: $%.2f'):format(
                entity.entityType == 'station' and 'Station' or 'Refinery',
                available
            ),
            icon = entity.entityType == 'station' and 'gas-pump' or 'industry',
            onSelect = function()
                OpenOwnerDashboardNUI(entity.entityType, entity.entityId)
            end,
        }
    end

    lib.registerContext({
        id = 'hbs_fuel_my_properties',
        title = 'My Fuel Properties',
        options = options,
    })

    lib.showContext('hbs_fuel_my_properties')
end, false)

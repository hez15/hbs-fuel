local nuiOpen = false

local function setNuiFocus(focus)
    SetNuiFocus(focus, focus)
    nuiOpen = focus
end

-- ── REFUEL NUI ──

function OpenRefuelNUI(stationId, station, vehicle)
    local currentFuel = GetCachedVehicleFuel(vehicle) or 0.0
    local tankCapacity = HBSFuel.GetTankCapacity(vehicle)
    local litresNeeded = HBSFuel.Round(tankCapacity - currentFuel, 2)

    if litresNeeded <= 0.05 then
        HBSFuelNotify('Vehicle is already full.', 'inform')
        return
    end

    -- Fetch live price multiplier from server — owner may have changed it
    local livePriceMult = nil
    if stationId then
        livePriceMult = lib.callback.await('hbs-fuel:server:getStationPrice', false, stationId)
    end
    if not livePriceMult or livePriceMult <= 0 then
        livePriceMult = (station and station.priceMultiplier) or Config.DefaultStationPriceMultiplier
    end

    -- Keep client cache in sync so subsequent opens are instant
    if stationId and Stations and Stations[stationId] then
        Stations[stationId].priceMultiplier = livePriceMult
    end

    local allowedTypes = HBSFuel.GetAllowedFuelTypes(vehicle)
    local fuelOptions = {}

    local supported = station and station.supports or (Config.UnmappedStationSupportedFuelTypes or { Config.DefaultFuelType })
    for _, fuelType in ipairs(supported) do
        if FuelTypes[fuelType] and not FuelTypes[fuelType].byproduct then
            local allowed = false
            for _, a in ipairs(allowedTypes) do
                if a == fuelType then allowed = true; break end
            end

            if allowed then
                local pricePerLitre = FuelTypes[fuelType].price * livePriceMult
                fuelOptions[#fuelOptions + 1] = {
                    value = fuelType,
                    label = FuelTypes[fuelType].label,
                    price = HBSFuel.Round(pricePerLitre, 2),
                }
            end
        end
    end

    if #fuelOptions == 0 then
        HBSFuelNotify(Config.Notifications.RefuelBlockedIncompatibleVehicle, 'error')
        return
    end

    SendNUIMessage({
        action = 'openRefuel',
        stationId = stationId,
        stationLabel = station and station.label or 'Fuel Station',
        fuelTypes = fuelOptions,
        currentFuel = currentFuel,
        tankCapacity = tankCapacity,
    })
    setNuiFocus(true)
end

RegisterNUICallback('nuiConfirmRefuel', function(data, cb)
    cb('ok')
    setNuiFocus(false)

    local fuelType = data.fuelType
    local litres = tonumber(data.litres) or 0
    local paymentMethod = data.paymentMethod or 'cash'

    if not fuelType or litres <= 0 then return end

    TriggerEvent('hbs-fuel:client:nuiRefuelConfirmed', fuelType, litres, paymentMethod)
end)

function ShowRefuelProgress(label, totalLitres)
    SendNUIMessage({
        action = 'showProgress',
        label = label,
        totalLitres = totalLitres,
    })
end

function UpdateRefuelProgress(delivered, total)
    local pct = total > 0 and math.floor((delivered / total) * 100) or 0
    SendNUIMessage({
        action = 'updateProgress',
        percent = pct,
        delivered = delivered,
        total = total,
    })
end

function HideRefuelProgress()
    SendNUIMessage({ action = 'hideProgress' })
end

-- ── OWNER DASHBOARD NUI ──

function OpenOwnerDashboardNUI(entityType, entityId)
    local data = lib.callback.await('hbs-fuel:server:getOwnerDashboard', false, entityType, entityId)
    if not data or not data.ok then
        HBSFuelNotify(data and data.message or 'Unable to load dashboard.', 'error')
        return
    end

    local orders = {}
    local fuelTypes = {}
    if entityType == 'station' then
        local orderData = lib.callback.await('hbs-fuel:server:getStationOrders', false, entityId)
        if orderData and orderData.ok then
            orders = orderData.orders
        end

        local station = Stations[entityId]
        if station and station.supports then
            for _, ft in ipairs(station.supports) do
                if FuelTypes[ft] and not FuelTypes[ft].byproduct then
                    fuelTypes[#fuelTypes + 1] = ft
                end
            end
        end
    end

    SendNUIMessage({
        action = 'openOwnerDashboard',
        entityType = entityType,
        entityId = entityId,
        label = data.label,
        revenueTotal = data.revenueTotal,
        revenueAvailable = data.revenueAvailable,
        revenueWithdrawn = data.revenueWithdrawn,
        priceMultiplier = data.priceMultiplier,
        minMult = Config.Ownership and Config.Ownership.MinPriceMultiplier or 0.5,
        maxMult = Config.Ownership and Config.Ownership.MaxPriceMultiplier or 2.0,
        stock = data.stock,
        orders = orders,
        fuelTypes = fuelTypes,
        payoutConfig = {
            rates = Config.Contracts and Config.Contracts.Payout or { crude = { base = 750, perLitre = 0.25 }, refined = { base = 1000, perLitre = 0.40 } },
            urgencyMultipliers = Config.Contracts and Config.Contracts.UrgencyMultipliers or { normal = 1.0, high = 1.15, critical = 1.30 },
        },
    })
    setNuiFocus(true)
end

RegisterNUICallback('nuiSetPrice', function(data, cb)
    cb('ok')
    local result = lib.callback.await('hbs-fuel:server:setStationPrice', false, data.entityId, tonumber(data.priceMultiplier))
    if result and result.ok then
        HBSFuelNotify(('Price multiplier set to %.2fx'):format(result.priceMultiplier), 'success')
    else
        HBSFuelNotify(result and result.message or 'Failed to set price.', 'error')
    end
end)

RegisterNUICallback('nuiWithdrawRevenue', function(data, cb)
    cb('ok')
    local result = lib.callback.await('hbs-fuel:server:withdrawRevenue', false, data.entityType, data.entityId)
    if result and result.ok then
        HBSFuelNotify(('Withdrawn $%d to your bank.'):format(result.withdrawn or 0), 'success')
        -- Refresh dashboard
        OpenOwnerDashboardNUI(data.entityType, data.entityId)
    else
        HBSFuelNotify(result and result.message or 'Withdrawal failed.', 'error')
    end
end)

RegisterNUICallback('nuiOrderFuel', function(data, cb)
    cb('ok')
    local result = lib.callback.await('hbs-fuel:server:ownerOrderFuel', false, data.entityId, data.fuelType, tonumber(data.litres), data.urgency)
    if result and result.ok then
        HBSFuelNotify(result.message or 'Order placed!', 'success')
        OpenOwnerDashboardNUI('station', data.entityId)
    else
        HBSFuelNotify(result and result.message or 'Failed to place order.', 'error')
    end
end)

-- ── REFINERY STOCK NUI ──

function OpenRefineryStockNUI(refineryId)
    local data = lib.callback.await('hbs-fuel:server:getRefineryData', false, refineryId)
    if not data then
        HBSFuelNotify('Refinery data unavailable.', 'error')
        return
    end

    local refinery = Refineries[refineryId]
    SendNUIMessage({
        action = 'openRefineryStock',
        label = refinery and refinery.label or 'Refinery Stock',
        crude = data.crude,
        products = data.products,
        batch = data.batch,
    })
    setNuiFocus(true)
end

-- ── CONTRACTS NUI ──

local function resolveLabel(locationType, locationId)
    if locationType == 'station' and Stations[locationId] then
        return Stations[locationId].label
    elseif locationType == 'refinery' then
        if Refineries[locationId] then
            return Refineries[locationId].label
        end
        for _, r in pairs(Refineries) do return r.label end
    elseif locationType == 'oilshop' and Config.OilShops and Config.OilShops[locationId] then
        return Config.OilShops[locationId].label
    elseif locationType == 'crude_source' then
        return 'Crude Source'
    end
    return locationId or 'Unknown'
end

local function resolveCoords(locationType, locationId)
    if locationType == 'station' and Stations[locationId] then
        return Stations[locationId].coords
    elseif locationType == 'refinery' then
        if Refineries[locationId] then
            return Refineries[locationId].coords
        end
        for _, r in pairs(Refineries) do return r.coords end
    elseif locationType == 'oilshop' and Config.OilShops and Config.OilShops[locationId] then
        return Config.OilShops[locationId].coords
    elseif locationType == 'crude_source' then
        for _, refinery in pairs(Refineries) do
            if refinery.points and refinery.points.crudeSource then
                return refinery.points.crudeSource
            end
        end
    end
    return nil
end

local function formatExpiry(expiresAt)
    if not expiresAt then return '?' end
    local now = GetCloudTimeAsInt()
    local remaining = expiresAt - now
    if remaining <= 0 then return 'Expired' end
    local mins = math.floor(remaining / 60)
    if mins > 0 then return ('%dm'):format(mins) end
    return ('%ds'):format(remaining)
end

local lastContractsData = nil

function OpenContractsNUI()
    local data = lib.callback.await('hbs-fuel:server:getContracts', false)
    if not data then
        HBSFuelNotify('Unable to load contracts.', 'error')
        return
    end

    lastContractsData = data

    local available = {}
    for _, c in ipairs(data.available or {}) do
        available[#available + 1] = {
            id = c.id,
            type = c.type,
            product = c.product,
            litresRequired = c.litresRequired,
            litresDelivered = c.litresDelivered,
            payout = c.payout,
            urgency = c.urgency,
            pickupLabel = resolveLabel(c.pickupType, c.pickupId),
            dropoffLabel = resolveLabel(c.dropoffType, c.dropoffId),
            expiresIn = formatExpiry(c.expiresAt),
        }
    end

    local active = nil
    if data.active then
        local c = data.active
        active = {
            id = c.id,
            type = c.type,
            product = c.product,
            litresRequired = c.litresRequired,
            litresDelivered = c.litresDelivered,
            payout = c.payout,
            urgency = c.urgency,
            pickupType = c.pickupType,
            pickupId = c.pickupId,
            dropoffType = c.dropoffType,
            dropoffId = c.dropoffId,
        }
    end

    SendNUIMessage({
        action = 'openContracts',
        available = available,
        active = active,
    })
    setNuiFocus(true)
end

RegisterNUICallback('nuiAcceptContract', function(data, cb)
    cb('ok')
    setNuiFocus(false)

    local accepted = lib.callback.await('hbs-fuel:server:acceptContract', false, data.contractId)
    if not accepted or not accepted.ok then
        HBSFuelNotify(accepted and accepted.message or 'Unable to accept contract.', 'error')
        return
    end

    HBSFuelNotify(('Accepted contract — $%s payout'):format(accepted.contract and accepted.contract.payout or 0), 'success')

    local c = accepted.contract
    if c then
        HBSFuelStartContractHud(c)
    end
end)

RegisterNUICallback('nuiCancelContract', function(_, cb)
    cb('ok')
    setNuiFocus(false)

    local result = lib.callback.await('hbs-fuel:server:cancelActiveContract', false)
    if result and result.ok then
        HBSFuelClearContractHud()
        HBSFuelNotify('Contract cancelled.', 'inform')
    else
        HBSFuelNotify(result and result.message or 'Unable to cancel.', 'error')
    end
end)

RegisterNUICallback('nuiContractWaypoint', function(data, cb)
    cb('ok')
    if not lastContractsData or not lastContractsData.active then return end

    local c = lastContractsData.active
    local coords
    if data.type == 'pickup' then
        coords = resolveCoords(c.pickupType, c.pickupId)
    else
        coords = resolveCoords(c.dropoffType, c.dropoffId)
    end

    if coords then
        SetNewWaypoint(coords.x, coords.y)
        HBSFuelNotify('Waypoint set.', 'success')
    end
end)

RegisterNUICallback('nuiRefreshContracts', function(_, cb)
    cb('ok')
    OpenContractsNUI()
end)

-- ── CLOSE ──

RegisterNUICallback('nuiClose', function(_, cb)
    cb('ok')
    setNuiFocus(false)
end)

-- Close NUI on resource stop
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if nuiOpen then
        setNuiFocus(false)
    end
end)

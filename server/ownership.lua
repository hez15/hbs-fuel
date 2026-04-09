local OwnershipCache = {}

local function getCitizenId(source)
    local ok, player = pcall(function()
        return exports['qbx_core']:GetPlayer(source)
    end)
    if ok and player and player.PlayerData then
        return player.PlayerData.citizenid
    end
    return nil
end

local function getPlayerName(source)
    local ok, player = pcall(function()
        return exports['qbx_core']:GetPlayer(source)
    end)
    if ok and player and player.PlayerData and player.PlayerData.charinfo then
        local info = player.PlayerData.charinfo
        return ('%s %s'):format(info.firstname or '', info.lastname or ''):gsub('^%s+', ''):gsub('%s+$', '')
    end
    return 'Unknown'
end

local function loadOwnership()
    MySQL.query('SELECT * FROM hbs_fuel_ownership', {}, function(rows)
        for _, row in ipairs(rows or {}) do
            local key = ('%s_%s'):format(row.entity_type, row.entity_id)
            OwnershipCache[key] = {
                entityType = row.entity_type,
                entityId = row.entity_id,
                ownerIdentifier = row.owner_identifier,
                ownerName = row.owner_name,
                purchasePrice = tonumber(row.purchase_price) or 0,
                purchasedAt = row.purchased_at,
                revenueTotal = tonumber(row.revenue_total) or 0.0,
                revenueWithdrawn = tonumber(row.revenue_withdrawn) or 0.0,
                businessId = row.business_id,
            }
        end
    end)
end

local function saveOwnership(data)
    if not data then return end
    MySQL.insert.await([[
        INSERT INTO hbs_fuel_ownership
            (entity_type, entity_id, owner_identifier, owner_name, purchase_price, purchased_at, revenue_total, revenue_withdrawn, business_id)
        VALUES (?, ?, ?, ?, ?, NOW(), ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            owner_identifier = VALUES(owner_identifier),
            owner_name = VALUES(owner_name),
            purchase_price = VALUES(purchase_price),
            revenue_total = VALUES(revenue_total),
            revenue_withdrawn = VALUES(revenue_withdrawn),
            business_id = VALUES(business_id),
            purchased_at = purchased_at,
            updated_at = NOW()
    ]], {
        data.entityType,
        data.entityId,
        data.ownerIdentifier,
        data.ownerName,
        data.purchasePrice,
        data.revenueTotal,
        data.revenueWithdrawn,
        data.businessId,
    })
end

function GetOwnership(entityType, entityId)
    local key = ('%s_%s'):format(entityType, entityId)
    return OwnershipCache[key]
end

function AddOwnerRevenue(entityType, entityId, amount)
    if not Config.Ownership or not Config.Ownership.Enabled then return end
    local key = ('%s_%s'):format(entityType, entityId)
    local ownership = OwnershipCache[key]
    if not ownership or not ownership.ownerIdentifier then return end

    local businessId = ownership.businessId
    if businessId and Config.Ownership.UseNonstopBanking then
        pcall(function()
            exports['nonstop-banking']:CreditBusinessAccount(businessId, math.floor(amount), {
                description = ('Fuel sale at %s'):format(entityId),
                source = 'hbs-fuel',
            })
        end)
    end

    ownership.revenueTotal = (ownership.revenueTotal or 0) + amount
    saveOwnership(ownership)
end

function IsEntityOwner(source, entityType, entityId)
    local citizenId = getCitizenId(source)
    if not citizenId then return false end

    local ownership = GetOwnership(entityType, entityId)
    if not ownership then return false end

    return ownership.ownerIdentifier == citizenId
end

lib.callback.register('hbs-fuel:server:getOwnership', function(source, entityType, entityId)
    local ownership = GetOwnership(entityType, entityId)
    if not ownership then
        return { ok = false, owned = false }
    end

    local isOwner = IsEntityOwner(source, entityType, entityId)
    return {
        ok = true,
        owned = true,
        isOwner = isOwner,
        ownerName = ownership.ownerName,
        purchasePrice = ownership.purchasePrice,
    }
end)

lib.callback.register('hbs-fuel:server:getOwnedEntities', function(source)
    local citizenId = getCitizenId(source)
    if not citizenId then return { ok = false, entities = {} } end

    local owned = {}
    for _, data in pairs(OwnershipCache) do
        if data.ownerIdentifier == citizenId then
            owned[#owned + 1] = {
                entityType = data.entityType,
                entityId = data.entityId,
                ownerName = data.ownerName,
                purchasePrice = data.purchasePrice,
                revenueTotal = data.revenueTotal,
                revenueWithdrawn = data.revenueWithdrawn,
            }
        end
    end

    return { ok = true, entities = owned }
end)

lib.callback.register('hbs-fuel:server:getOwnerDashboard', function(source, entityType, entityId)
    if not IsEntityOwner(source, entityType, entityId) then
        return { ok = false, message = 'You do not own this property.' }
    end

    local ownership = GetOwnership(entityType, entityId)
    if not ownership then
        return { ok = false, message = 'Ownership data not found.' }
    end

    local stockData = {}
    if entityType == 'station' and StationState[entityId] then
        local station = StationState[entityId]
        for fuelType, tank in pairs(station.tanks or {}) do
            stockData[fuelType] = {
                current = HBSFuel.Round(tank.current, 2),
                max = HBSFuel.Round(tank.max, 2),
            }
        end
    elseif entityType == 'refinery' and RefineryState[entityId] then
        local refinery = RefineryState[entityId]
        stockData.crude = {
            current = HBSFuel.Round(refinery.crude.current, 2),
            max = HBSFuel.Round(refinery.crude.max, 2),
        }
        for fuelType, product in pairs(refinery.products or {}) do
            stockData[fuelType] = {
                current = HBSFuel.Round(product.current, 2),
                max = HBSFuel.Round(product.max, 2),
            }
        end
    end

    local label = entityId
    if entityType == 'station' and Stations[entityId] then
        label = Stations[entityId].label
    elseif entityType == 'refinery' and Refineries[entityId] then
        label = Refineries[entityId].label
    end

    local priceMultiplier = nil
    if entityType == 'station' and StationState[entityId] then
        priceMultiplier = StationState[entityId].priceMultiplier or Config.DefaultStationPriceMultiplier
    end

    return {
        ok = true,
        label = label,
        entityType = entityType,
        entityId = entityId,
        revenueTotal = ownership.revenueTotal,
        revenueWithdrawn = ownership.revenueWithdrawn,
        revenueAvailable = HBSFuel.Round(ownership.revenueTotal - ownership.revenueWithdrawn, 2),
        businessId = ownership.businessId,
        useNonstopBanking = Config.Ownership.UseNonstopBanking or false,
        stock = stockData,
        priceMultiplier = priceMultiplier,
    }
end)

lib.callback.register('hbs-fuel:server:setStationPrice', function(source, entityId, newMultiplier)
    if not IsEntityOwner(source, 'station', entityId) then
        return { ok = false, message = 'You do not own this station.' }
    end

    local cfg = Config.Ownership or {}
    newMultiplier = tonumber(newMultiplier) or 1.0
    newMultiplier = HBSFuel.Clamp(newMultiplier, cfg.MinPriceMultiplier or 0.5, cfg.MaxPriceMultiplier or 2.0)

    local station = StationState[entityId]
    if not station then
        return { ok = false, message = 'Station not found.' }
    end

    station.priceMultiplier = newMultiplier

    return { ok = true, priceMultiplier = newMultiplier }
end)

lib.callback.register('hbs-fuel:server:withdrawRevenue', function(source, entityType, entityId)
    if not IsEntityOwner(source, entityType, entityId) then
        return { ok = false, message = 'You do not own this property.' }
    end

    local ownership = GetOwnership(entityType, entityId)
    if not ownership then
        return { ok = false, message = 'Ownership data not found.' }
    end

    if ownership.businessId and Config.Ownership.UseNonstopBanking then
        return { ok = false, message = 'Revenue goes directly to your business account. Check nonstop-banking.' }
    end

    local available = HBSFuel.Round(ownership.revenueTotal - ownership.revenueWithdrawn, 2)
    if available <= 0 then
        return { ok = false, message = 'No revenue to withdraw.' }
    end

    local intAmount = math.floor(available)
    if intAmount <= 0 then
        return { ok = false, message = 'No revenue to withdraw.' }
    end

    if not HBSFuelAddMoney then
        return { ok = false, message = 'Payment system not available.' }
    end

    if not HBSFuelAddMoney(source, 'bank', intAmount, ('fuel_revenue_%s_%s'):format(entityType, entityId)) then
        return { ok = false, message = 'Failed to deposit revenue.' }
    end

    ownership.revenueWithdrawn = ownership.revenueWithdrawn + intAmount
    saveOwnership(ownership)

    return { ok = true, withdrawn = intAmount, remaining = HBSFuel.Round(ownership.revenueTotal - ownership.revenueWithdrawn, 2) }
end)

lib.callback.register('hbs-fuel:server:purchaseEntity', function(source, entityType, entityId)
    local cfg = Config.Ownership or {}
    if not cfg.Enabled then
        return { ok = false, message = 'Ownership is disabled.' }
    end

    local existing = GetOwnership(entityType, entityId)
    if existing and existing.ownerIdentifier then
        return { ok = false, message = 'This property is already owned.' }
    end

    local prices = entityType == 'station' and cfg.StationPrices or cfg.RefineryPrices
    local price = prices and prices[entityId]
    if not price then
        return { ok = false, message = 'This property is not for sale.' }
    end

    local citizenId = getCitizenId(source)
    if not citizenId then
        return { ok = false, message = 'Unable to verify identity.' }
    end

    if not HBSFuelHasMoney(source, price, 'bank') then
        return { ok = false, message = Config.Notifications.NotEnoughMoney }
    end

    if not HBSFuelRemoveMoney(source, price, 'bank', ('fuel_purchase_%s_%s'):format(entityType, entityId)) then
        return { ok = false, message = 'Payment failed.' }
    end

    local businessId = nil
    if Config.Ownership.UseNonstopBanking then
        local ok, id = pcall(function()
            return exports['nonstop-banking']:CreateBusinessAccount(
                ('fuel_%s_%s'):format(entityType, entityId),
                getPlayerName(source) .. ' Fuel Business'
            )
        end)
        if ok and id then
            businessId = id
        end
    end

    local key = ('%s_%s'):format(entityType, entityId)
    OwnershipCache[key] = {
        entityType = entityType,
        entityId = entityId,
        ownerIdentifier = citizenId,
        ownerName = getPlayerName(source),
        purchasePrice = price,
        revenueTotal = 0.0,
        revenueWithdrawn = 0.0,
        businessId = businessId,
    }

    saveOwnership(OwnershipCache[key])

    return { ok = true, message = 'Property purchased successfully.' }
end)

lib.callback.register('hbs-fuel:server:ownerOrderFuel', function(source, entityId, fuelType, litres, urgency)
    if not IsEntityOwner(source, 'station', entityId) then
        return { ok = false, message = 'You do not own this station.' }
    end

    litres = tonumber(litres) or 0
    if litres <= 0 or litres > 12000 then
        return { ok = false, message = 'Invalid amount (1-12000 litres).' }
    end

    if not FuelTypes[fuelType] then
        return { ok = false, message = 'Invalid fuel type.' }
    end

    local station = StationState and StationState[entityId]
    if not station then
        return { ok = false, message = 'Station not found.' }
    end

    local contract = exports['hbs-fuel']:CreateStationRefillContract(entityId, fuelType, litres, urgency or 'normal')
    if not contract then
        return { ok = false, message = 'A similar order already exists for this station.' }
    end

    return { ok = true, message = ('Order placed: %.0fL of %s'):format(litres, fuelType), contractId = contract.id }
end)

lib.callback.register('hbs-fuel:server:getStationOrders', function(source, entityId)
    if not IsEntityOwner(source, 'station', entityId) then
        return { ok = false, orders = {} }
    end

    local contracts = exports['hbs-fuel']:GetContractsForStation(entityId) or {}
    local orders = {}
    for _, c in ipairs(contracts) do
        orders[#orders + 1] = {
            id = c.id,
            product = c.product,
            litresRequired = c.litresRequired,
            litresDelivered = c.litresDelivered or 0,
            urgency = c.urgency,
            status = c.status,
            payout = c.payout,
        }
    end

    return { ok = true, orders = orders }
end)

CreateThread(function()
    Wait(2000)
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `hbs_fuel_ownership` (
          `id` INT NOT NULL AUTO_INCREMENT,
          `entity_type` ENUM('station', 'refinery') NOT NULL,
          `entity_id` VARCHAR(64) NOT NULL,
          `owner_identifier` VARCHAR(64) DEFAULT NULL,
          `owner_name` VARCHAR(128) DEFAULT NULL,
          `purchase_price` INT NOT NULL DEFAULT 0,
          `purchased_at` TIMESTAMP NULL DEFAULT NULL,
          `revenue_total` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
          `revenue_withdrawn` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
          `business_id` VARCHAR(128) DEFAULT NULL,
          `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          UNIQUE KEY `uq_hbs_fuel_ownership_entity` (`entity_type`, `entity_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    pcall(function()
        MySQL.query.await([[ALTER TABLE hbs_fuel_ownership ADD COLUMN IF NOT EXISTS `business_id` VARCHAR(128) DEFAULT NULL]])
    end)

    loadOwnership()
end)

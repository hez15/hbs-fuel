local Contracts = {}
local ActiveByPlayer = {}

local function now()
    return os.time()
end

local function makeId()
    return ('CTR-%s-%04d'):format(os.date('%Y%m%d%H%M%S'), math.random(1000, 9999))
end

local function getCfg()
    Config.Contracts = Config.Contracts or {}
    return Config.Contracts
end

local function getExpiry()
    local cfg = getCfg()
    return now() + (cfg.ExpirySeconds or 1800)
end

local function saveContract(contract)
    if not contract then return end

    MySQL.insert.await([[
        INSERT INTO hbs_fuel_contracts
            (contract_id, type, product, pickup_type, pickup_id, dropoff_type, dropoff_id, litres_required, litres_delivered, payout, urgency, status, accepted_by, expires_at, created_at, updated_at)
        VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, FROM_UNIXTIME(?), NOW(), NOW())
        ON DUPLICATE KEY UPDATE
            litres_required = VALUES(litres_required),
            litres_delivered = VALUES(litres_delivered),
            payout = VALUES(payout),
            urgency = VALUES(urgency),
            status = VALUES(status),
            accepted_by = VALUES(accepted_by),
            expires_at = VALUES(expires_at),
            updated_at = NOW()
    ]], {
        contract.id,
        contract.type,
        contract.product,
        contract.pickupType,
        contract.pickupId,
        contract.dropoffType,
        contract.dropoffId,
        contract.litresRequired,
        contract.litresDelivered,
        contract.payout,
        contract.urgency,
        contract.status,
        contract.acceptedBy,
        contract.expiresAt
    })
end

local function deleteContractDb(contractId)
    MySQL.query.await('DELETE FROM hbs_fuel_contracts WHERE contract_id = ?', { contractId })
end

local function getUrgencyMultiplier(urgency)
    local cfg = getCfg()
    local multipliers = cfg.UrgencyMultipliers or {
        normal = 1.0,
        high = 1.15,
        critical = 1.30,
    }

    return multipliers[urgency] or 1.0
end

local function calculatePayout(contractType, litres, urgency)
    local cfg = getCfg()
    local rates = cfg.Payout or {
        crude = { base = 900, perLitre = 0.20 },
        refined = { base = 1200, perLitre = 0.35 },
    }

    local rate = rates[contractType] or rates.refined
    local total = (rate.base or 0) + ((rate.perLitre or 0) * litres)
    total = total * getUrgencyMultiplier(urgency)

    return math.floor(total + 0.5)
end

local function isExpired(contract)
    return contract and contract.expiresAt and contract.expiresAt <= now()
end

local function sanitizeContractForClient(contract)
    if not contract then return nil end

    return {
        id = contract.id,
        type = contract.type,
        product = contract.product,
        pickupType = contract.pickupType,
        pickupId = contract.pickupId,
        dropoffType = contract.dropoffType,
        dropoffId = contract.dropoffId,
        litresRequired = contract.litresRequired,
        litresDelivered = contract.litresDelivered,
        payout = contract.payout,
        urgency = contract.urgency,
        status = contract.status,
        acceptedBy = contract.acceptedBy,
        expiresAt = contract.expiresAt,
        createdAt = contract.createdAt,
    }
end

local function getAvailableContracts()
    local available = {}

    for _, contract in pairs(Contracts) do
        if contract.status == 'available' and not isExpired(contract) then
            available[#available + 1] = sanitizeContractForClient(contract)
        end
    end

    table.sort(available, function(a, b)
        if a.urgency ~= b.urgency then
            local score = { critical = 3, high = 2, normal = 1 }
            return (score[a.urgency] or 0) > (score[b.urgency] or 0)
        end
        return (a.createdAt or 0) > (b.createdAt or 0)
    end)

    return available
end

local function getActiveContractForSource(source)
    local id = ActiveByPlayer[source]
    if not id then return nil end
    return Contracts[id]
end

local function hasSimilarAvailable(contractType, product, dropoffType, dropoffId)
    for _, contract in pairs(Contracts) do
        if contract.status == 'available'
            and contract.type == contractType
            and contract.product == product
            and contract.dropoffType == dropoffType
            and contract.dropoffId == dropoffId
            and not isExpired(contract)
        then
            return true
        end
    end

    return false
end

local function addContract(data)
    local contract = {
        id = makeId(),
        type = data.type,
        product = data.product,
        pickupType = data.pickupType,
        pickupId = data.pickupId,
        dropoffType = data.dropoffType,
        dropoffId = data.dropoffId,
        litresRequired = math.floor((data.litresRequired or 0) * 100) / 100,
        litresDelivered = 0.0,
        payout = data.payout or calculatePayout(data.type, data.litresRequired or 0, data.urgency or 'normal'),
        urgency = data.urgency or 'normal',
        status = 'available',
        acceptedBy = nil,
        expiresAt = getExpiry(),
        createdAt = now(),
    }

    Contracts[contract.id] = contract
    saveContract(contract)
    return contract
end

local function expireOldContracts()
    local changed = false

    for id, contract in pairs(Contracts) do
        if contract.status == 'available' and isExpired(contract) then
            contract.status = 'expired'
            saveContract(contract)
            changed = true
        end
    end

    return changed
end

local function ensureCrudeContract()
    local cfg = getCfg()
    if cfg.Enabled == false then return end
    if cfg.CrudeHaulEnabled == false then return end

    local minimum = cfg.CrudeMinContracts or 1
    local count = 0

    for _, contract in pairs(Contracts) do
        if contract.type == 'crude' and contract.status == 'available' and not isExpired(contract) then
            count += 1
        end
    end

    while count < minimum do
        addContract({
            type = 'crude',
            product = 'crude',
            pickupType = 'crude_source',
            pickupId = 'default_crude_source',
            dropoffType = 'refinery',
            dropoffId = 'default_refinery',
            litresRequired = cfg.DefaultCrudeLitres or 8000.0,
            urgency = 'normal',
        })
        count += 1
    end
end

local function createStationRefillContract(stationId, fuelType, litresNeeded, urgency)
    if not stationId or not fuelType or not litresNeeded or litresNeeded <= 0 then return nil end
    if hasSimilarAvailable('refined', fuelType, 'station', stationId) then return nil end

    return addContract({
        type = 'refined',
        product = fuelType,
        pickupType = 'refinery',
        pickupId = 'default_refinery',
        dropoffType = 'station',
        dropoffId = stationId,
        litresRequired = litresNeeded,
        urgency = urgency or 'normal',
    })
end

local function ensureStationContracts()
    local cfg = getCfg()
    if cfg.Enabled == false then return end

    local threshold = cfg.AutoRefillThreshold or 0.10

    for stationId, station in pairs(StationState or {}) do
        for fuelType, tank in pairs(station.tanks or {}) do
            if tank.max > 0 and (tank.current / tank.max) < threshold then
                local litresNeeded = math.floor(tank.max * 0.75)
                local urgency = (tank.current / tank.max) < 0.03 and 'critical' or 'high'
                createStationRefillContract(stationId, fuelType, litresNeeded, urgency)
            end
        end
    end
end

RegisterNetEvent('hbs-fuel:server:contracts:stationNeedsRefill', function(stationId, fuelType, litresNeeded, urgency)
    createStationRefillContract(stationId, fuelType, litresNeeded, urgency)
end)

lib.callback.register('hbs-fuel:server:getContracts', function(source)
    local active = getActiveContractForSource(source)
    return {
        available = getAvailableContracts(),
        active = sanitizeContractForClient(active),
    }
end)

lib.callback.register('hbs-fuel:server:acceptContract', function(source, contractId)
    local cfg = getCfg()
    if cfg.Enabled == false then
        return { ok = false, message = 'Contracts are disabled.' }
    end

    if getActiveContractForSource(source) then
        return { ok = false, message = 'You already have an active contract.' }
    end

    local contract = Contracts[contractId]
    if not contract then
        return { ok = false, message = 'Contract not found.' }
    end

    if contract.status ~= 'available' or isExpired(contract) then
        return { ok = false, message = 'Contract is no longer available.' }
    end

    contract.status = 'active'
    contract.acceptedBy = source
    saveContract(contract)

    ActiveByPlayer[source] = contract.id

    return {
        ok = true,
        contract = sanitizeContractForClient(contract),
    }
end)

lib.callback.register('hbs-fuel:server:cancelActiveContract', function(source)
    local contract = getActiveContractForSource(source)
    if not contract then
        return { ok = false, message = 'No active contract.' }
    end

    contract.status = 'available'
    contract.acceptedBy = nil
    contract.expiresAt = getExpiry()
    saveContract(contract)

    ActiveByPlayer[source] = nil

    return { ok = true }
end)

local function completeContractForSource(source, deliveredLitres)
    local contract = getActiveContractForSource(source)
    if not contract then
        return nil
    end

    deliveredLitres = tonumber(deliveredLitres) or 0.0
    if deliveredLitres <= 0 then
        return nil
    end

    contract.litresDelivered = math.floor((contract.litresDelivered + deliveredLitres) * 100) / 100

    local done = contract.litresDelivered >= contract.litresRequired
    local fraction = math.min(contract.litresDelivered / contract.litresRequired, 1.0)
    local payout = math.floor((contract.payout or 0) * fraction + 0.5)

    if done then
        contract.status = 'completed'
        saveContract(contract)
        ActiveByPlayer[source] = nil

        if HBSFuelAddMoney then
            HBSFuelAddMoney(source, 'bank', payout, ('Fuel contract %s'):format(contract.id))
        end

        TriggerClientEvent('hbs-fuel:client:contractCompleted', source, payout)

        return {
            ok = true,
            completed = true,
            payout = payout,
            contract = sanitizeContractForClient(contract),
        }
    end

    saveContract(contract)

    return {
        ok = true,
        completed = false,
        payout = payout,
        contract = sanitizeContractForClient(contract),
    }
end

RegisterNetEvent('hbs-fuel:server:contracts:progressCrude', function(deliveredLitres)
    local source = source
    local contract = getActiveContractForSource(source)
    if not contract or contract.type ~= 'crude' or contract.product ~= 'crude' then return end
    completeContractForSource(source, deliveredLitres)
end)

RegisterNetEvent('hbs-fuel:server:contracts:progressRefined', function(product, deliveredLitres, stationId)
    local source = source
    local contract = getActiveContractForSource(source)
    if not contract or contract.type ~= 'refined' then return end
    if contract.product ~= product then return end
    if contract.dropoffType ~= 'station' or tostring(contract.dropoffId) ~= tostring(stationId) then return end
    completeContractForSource(source, deliveredLitres)
end)

exports('GetActiveContract', function(source)
    return getActiveContractForSource(source)
end)

exports('GetContractsForStation', function(stationId)
    local results = {}
    for _, contract in pairs(Contracts) do
        if contract.dropoffType == 'station' and contract.dropoffId == stationId
            and (contract.status == 'available' or contract.status == 'active')
        then
            results[#results + 1] = sanitizeContractForClient(contract)
        end
    end
    return results
end)

exports('CreateStationRefillContract', function(stationId, fuelType, litresNeeded, urgency)
    return createStationRefillContract(stationId, fuelType, litresNeeded, urgency)
end)

exports('CreateFuelContract', function(data)
    if not data then return nil end

    local contractType = data.type or 'refined'
    local product = data.fuelType or data.product or 'regular'
    local litres = tonumber(data.litres or data.litresRequired) or 0

    if contractType == 'crude' then
        product = 'crude'
    end

    if litres <= 0 then return nil end

    return addContract({
        type = contractType,
        product = product,
        pickupType = data.pickupType or (contractType == 'crude' and 'crude_source' or 'refinery'),
        pickupId = data.pickupId or (contractType == 'crude' and 'default_crude_source' or 'default_refinery'),
        dropoffType = data.dropoffType or (contractType == 'crude' and 'refinery' or 'station'),
        dropoffId = data.dropoffId or data.stationId or 'default',
        litresRequired = litres,
        urgency = data.urgency or 'normal',
        payout = data.payout,
    })
end)

CreateThread(function()
    Wait(2500)

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `hbs_fuel_contracts` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `contract_id` VARCHAR(64) NOT NULL,
            `type` VARCHAR(32) NOT NULL,
            `product` VARCHAR(32) NOT NULL,
            `pickup_type` VARCHAR(64) NOT NULL,
            `pickup_id` VARCHAR(64) NOT NULL,
            `dropoff_type` VARCHAR(64) NOT NULL,
            `dropoff_id` VARCHAR(64) NOT NULL,
            `litres_required` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
            `litres_delivered` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
            `payout` INT NOT NULL DEFAULT 0,
            `urgency` VARCHAR(16) NOT NULL DEFAULT 'normal',
            `status` VARCHAR(16) NOT NULL DEFAULT 'available',
            `accepted_by` INT NULL DEFAULT NULL,
            `expires_at` DATETIME NULL DEFAULT NULL,
            `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uq_hbs_fuel_contracts_contract_id` (`contract_id`)
        )
    ]])

    local rows = MySQL.query.await([[
        SELECT contract_id, type, product, pickup_type, pickup_id, dropoff_type, dropoff_id,
               litres_required, litres_delivered, payout, urgency, status, accepted_by,
               UNIX_TIMESTAMP(expires_at) AS expires_at, UNIX_TIMESTAMP(created_at) AS created_at
        FROM hbs_fuel_contracts
        WHERE status IN ('available', 'active')
    ]])

    for _, row in ipairs(rows or {}) do
        local contract = {
            id = row.contract_id,
            type = row.type,
            product = row.product,
            pickupType = row.pickup_type,
            pickupId = row.pickup_id,
            dropoffType = row.dropoff_type,
            dropoffId = row.dropoff_id,
            litresRequired = tonumber(row.litres_required) or 0.0,
            litresDelivered = tonumber(row.litres_delivered) or 0.0,
            payout = tonumber(row.payout) or 0,
            urgency = row.urgency or 'normal',
            status = row.status,
            acceptedBy = row.accepted_by and tonumber(row.accepted_by) or nil,
            expiresAt = tonumber(row.expires_at) or getExpiry(),
            createdAt = tonumber(row.created_at) or now(),
        }

        Contracts[contract.id] = contract

        if contract.status == 'active' and contract.acceptedBy then
            ActiveByPlayer[contract.acceptedBy] = contract.id
        end
    end

    ensureCrudeContract()
    ensureStationContracts()
end)

CreateThread(function()
    while true do
        local cfg = getCfg()
        Wait((cfg.GenerationIntervalSeconds or 120) * 1000)
        expireOldContracts()
        ensureCrudeContract()
        ensureStationContracts()
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local contractId = ActiveByPlayer[src]
    if not contractId then return end

    local contract = Contracts[contractId]
    if contract and contract.status == 'active' then
        contract.status = 'available'
        contract.acceptedBy = nil
        contract.expiresAt = getExpiry()
        saveContract(contract)
    end

    ActiveByPlayer[src] = nil
end)
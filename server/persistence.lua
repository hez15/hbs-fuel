local started = false

local function copyStationDefaults(stationId, station)
    local tanks = {}
    for fuelType, data in pairs(station.tanks or {}) do
        tanks[fuelType] = {
            current = data.current,
            max = data.max,
        }
    end

    return {
        stationId = stationId,
        label = station.label,
        supports = station.supports,
        priceMultiplier = station.priceMultiplier or 1.0,
        demandMultiplier = station.demandMultiplier or 1.0,
        emergencyRefill = station.emergencyRefill == true,
        tanks = tanks,
    }
end

StationState = StationState or {}
RefineryState = RefineryState or {}
TankerState = TankerState or {}

local function ensureTables()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS hbs_fuel_vehicle_state (
        plate VARCHAR(16) PRIMARY KEY,
        litres DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS hbs_fuel_station_stock (
        station_id VARCHAR(64) NOT NULL,
        fuel_type VARCHAR(32) NOT NULL,
        current_litres DECIMAL(12,2) NOT NULL DEFAULT 0.00,
        max_litres DECIMAL(12,2) NOT NULL DEFAULT 0.00,
        price_multiplier DECIMAL(4,2) NOT NULL DEFAULT 1.00,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (station_id, fuel_type)
    )]])

    pcall(function()
        MySQL.query.await([[ALTER TABLE hbs_fuel_station_stock ADD COLUMN IF NOT EXISTS price_multiplier DECIMAL(4,2) NOT NULL DEFAULT 1.00]])
    end)

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS hbs_fuel_refinery_stock (
        refinery_id VARCHAR(64) NOT NULL,
        fuel_type VARCHAR(32) NOT NULL,
        current_litres DECIMAL(12,2) NOT NULL DEFAULT 0.00,
        max_litres DECIMAL(12,2) NOT NULL DEFAULT 0.00,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (refinery_id, fuel_type)
    )]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS hbs_fuel_refinery_crude (
        refinery_id VARCHAR(64) PRIMARY KEY,
        current_litres DECIMAL(12,2) NOT NULL DEFAULT 0.00,
        max_litres DECIMAL(12,2) NOT NULL DEFAULT 0.00,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS hbs_fuel_tanker_state (
        plate VARCHAR(16) PRIMARY KEY,
        fuel_type VARCHAR(32) NULL,
        litres DECIMAL(12,2) NOT NULL DEFAULT 0.00,
        max_litres DECIMAL(12,2) NOT NULL DEFAULT 12000.00,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )]])
end

local function loadStationState()
    for stationId, station in pairs(Stations) do
        StationState[stationId] = copyStationDefaults(stationId, station)
    end

    local rows = MySQL.query.await('SELECT station_id, fuel_type, current_litres, max_litres, price_multiplier FROM hbs_fuel_station_stock') or {}
    for _, row in ipairs(rows) do
        local station = StationState[row.station_id]
        if station then
            station.tanks[row.fuel_type] = station.tanks[row.fuel_type] or {}
            station.tanks[row.fuel_type].current = tonumber(row.current_litres)
            station.tanks[row.fuel_type].max = tonumber(row.max_litres)
            local pm = tonumber(row.price_multiplier)
            if pm and pm > 0 then
                station.priceMultiplier = pm
            end
        end
    end
end

local function loadRefineryState()
    for refineryId, refinery in pairs(Refineries) do
        RefineryState[refineryId] = {
            label = refinery.label,
            crude = {
                current = refinery.crude.current,
                max = refinery.crude.max,
            },
            products = {},
            recipe = refinery.recipe,
        }

        for fuelType, data in pairs(refinery.products or {}) do
            RefineryState[refineryId].products[fuelType] = {
                current = data.current,
                max = data.max,
            }
        end
    end

    local crudeRows = MySQL.query.await('SELECT refinery_id, current_litres, max_litres FROM hbs_fuel_refinery_crude') or {}
    for _, row in ipairs(crudeRows) do
        if RefineryState[row.refinery_id] then
            RefineryState[row.refinery_id].crude.current = tonumber(row.current_litres)
            RefineryState[row.refinery_id].crude.max = tonumber(row.max_litres)
        end
    end

    local productRows = MySQL.query.await('SELECT refinery_id, fuel_type, current_litres, max_litres FROM hbs_fuel_refinery_stock') or {}
    for _, row in ipairs(productRows) do
        if RefineryState[row.refinery_id] then
            RefineryState[row.refinery_id].products[row.fuel_type] = RefineryState[row.refinery_id].products[row.fuel_type] or {}
            RefineryState[row.refinery_id].products[row.fuel_type].current = tonumber(row.current_litres)
            RefineryState[row.refinery_id].products[row.fuel_type].max = tonumber(row.max_litres)
        end
    end
end

function SaveStationState(stationId)
    local station = StationState[stationId]
    if not station then return end

    local pm = tonumber(station.priceMultiplier) or 1.0

    for fuelType, tank in pairs(station.tanks) do
        MySQL.prepare.await([[INSERT INTO hbs_fuel_station_stock (station_id, fuel_type, current_litres, max_litres, price_multiplier)
            VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                current_litres = VALUES(current_litres),
                max_litres = VALUES(max_litres),
                price_multiplier = VALUES(price_multiplier)]], {
            stationId, fuelType, tank.current, tank.max, pm
        })
    end
end

function SaveAllStationState()
    for stationId in pairs(StationState) do
        SaveStationState(stationId)
    end
end

function SaveRefineryState(refineryId)
    local refinery = RefineryState[refineryId]
    if not refinery then return end

    MySQL.prepare.await([[INSERT INTO hbs_fuel_refinery_crude (refinery_id, current_litres, max_litres)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE current_litres = VALUES(current_litres), max_litres = VALUES(max_litres)]], {
        refineryId, refinery.crude.current, refinery.crude.max
    })

    for fuelType, stock in pairs(refinery.products or {}) do
        MySQL.prepare.await([[INSERT INTO hbs_fuel_refinery_stock (refinery_id, fuel_type, current_litres, max_litres)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE current_litres = VALUES(current_litres), max_litres = VALUES(max_litres)]], {
            refineryId, fuelType, stock.current, stock.max
        })
    end
end

CreateThread(function()
    ensureTables()
    loadStationState()
    loadRefineryState()

    -- Emergency refill: top up stations to 10% if below
    local minPct = Config.RestartMinFuelPercent or 0.10
    for stationId, station in pairs(StationState) do
        for fuelType, tank in pairs(station.tanks or {}) do
            if tank.max > 0 and (tank.current / tank.max) < minPct then
                tank.current = math.floor(tank.max * minPct)
                SaveStationState(stationId)
            end
        end
    end

    started = true

    while true do
        Wait(60000)
        if started then
            SaveAllStationState()
            for refineryId in pairs(RefineryState) do
                SaveRefineryState(refineryId)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if started then
        SaveAllStationState()
        for refineryId in pairs(RefineryState) do
            SaveRefineryState(refineryId)
        end
    end
end)

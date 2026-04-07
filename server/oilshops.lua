OilShopState = OilShopState or {}

local function loadOilShopState()
    for shopId, shop in pairs(Config.OilShops or {}) do
        OilShopState[shopId] = {
            label = shop.label,
            tank = {
                current = shop.tank.current,
                max = shop.tank.max,
            },
        }
    end

    local rows = MySQL.query.await('SELECT shop_id, current_litres, max_litres FROM hbs_fuel_oilshop_stock') or {}
    for _, row in ipairs(rows) do
        if OilShopState[row.shop_id] then
            OilShopState[row.shop_id].tank.current = tonumber(row.current_litres)
            OilShopState[row.shop_id].tank.max = tonumber(row.max_litres)
        end
    end
end

local function saveOilShopState(shopId)
    local shop = OilShopState[shopId]
    if not shop then return end

    MySQL.prepare.await([[INSERT INTO hbs_fuel_oilshop_stock (shop_id, current_litres, max_litres)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE current_litres = VALUES(current_litres), max_litres = VALUES(max_litres)]], {
        shopId, shop.tank.current, shop.tank.max
    })
end

lib.callback.register('hbs-fuel:server:unloadOilToShop', function(_, shopId, plate, litres, modelName)
    litres = tonumber(litres) or 0.0
    if not shopId or not plate or litres <= 0.0 then
        return { ok = false, message = 'Invalid oil unload.' }
    end

    local shop = OilShopState[shopId]
    if not shop then
        return { ok = false, message = 'Oil shop not found.' }
    end

    local load = MySQL.single.await('SELECT fuel_type, litres, max_litres FROM hbs_fuel_tanker_state WHERE plate = ?', { plate })
    if not load or load.fuel_type ~= 'motoroil' or tonumber(load.litres) <= 0.0 then
        return { ok = false, message = 'Tanker does not contain motor oil.' }
    end

    local tank = shop.tank
    local free = math.max(tank.max - tank.current, 0.0)
    local tankerLitres = tonumber(load.litres)
    local moved = math.min(litres, tankerLitres, free)
    if moved <= 0.0 then
        return { ok = false, message = 'Shop oil tank is already full.' }
    end

    tank.current = tank.current + moved
    saveOilShopState(shopId)
    exports['hbs-fuel']:SetTankerLoad(plate, tankerLitres - moved > 0.01 and 'motoroil' or nil, math.max(tankerLitres - moved, 0.0), tonumber(load.max_litres) or Config.Tanker.DefaultMaxLitres)

    return { ok = true, litres = moved, message = ('Delivered %.0fL motor oil.'):format(moved) }
end)

exports('GetOilShopStock', function(shopId)
    local shop = OilShopState[shopId]
    return shop and shop.tank and shop.tank.current or nil
end)

CreateThread(function()
    Wait(2000)

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS hbs_fuel_oilshop_stock (
        shop_id VARCHAR(64) PRIMARY KEY,
        current_litres DECIMAL(12,2) NOT NULL DEFAULT 0.00,
        max_litres DECIMAL(12,2) NOT NULL DEFAULT 0.00,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )]])

    loadOilShopState()
end)

local spawnedPeds = {}
local spawnedBlips = {}

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

local function spawnPed(modelName, coords, heading)
    local hash = type(modelName) == 'string' and joaat(modelName) or modelName
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    if not HasModelLoaded(hash) then return nil end

    local ped = CreatePed(0, hash, coords.x, coords.y, coords.z - 1.0, heading or 0.0, false, true)
    if not ped or ped == 0 then return nil end

    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanPlayAmbientAnims(ped, true)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetEntityAsMissionEntity(ped, true, true)

    SetModelAsNoLongerNeeded(hash)
    return ped
end

local function createBlip(coords, sprite, colour, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.7)
    SetBlipColour(blip, colour)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
    return blip
end

local function getPedCoords(data)
    if data.pedCoords then
        return data.pedCoords
    end
    return vec4(data.coords.x + 1.5, data.coords.y + 1.5, data.coords.z, 0.0)
end

local function getPedHeading(data)
    if data.pedCoords and data.pedCoords.w then
        return data.pedCoords.w
    end
    return 0.0
end

CreateThread(function()
    if not Config.Ownership or not Config.Ownership.Enabled then return end

    Wait(2000)

    local pedModel = Config.Ownership.PedModel or 's_m_y_autoshop_02'

    for stationId, station in pairs(Stations) do
        local pedPos = getPedCoords(station)
        local heading = getPedHeading(station)

        local ped = spawnPed(pedModel, pedPos, heading)
        if ped then
            spawnedPeds[#spawnedPeds + 1] = ped

            exports['ox_target']:addLocalEntity(ped, {
                {
                    name = ('fuel_ownership_station_%s'):format(stationId),
                    label = 'Station Management',
                    icon = 'fas fa-gas-pump',
                    distance = 2.5,
                    onSelect = function()
                        handleEntityInteraction('station', stationId)
                    end,
                }
            })
        end

        local blip = createBlip(station.coords, 361, 46, station.label)
        spawnedBlips[#spawnedBlips + 1] = blip
    end

    for refineryId, refinery in pairs(Refineries) do
        local pedPos = getPedCoords(refinery)
        local heading = getPedHeading(refinery)

        local ped = spawnPed(pedModel, pedPos, heading)
        if ped then
            spawnedPeds[#spawnedPeds + 1] = ped

            exports['ox_target']:addLocalEntity(ped, {
                {
                    name = ('fuel_ownership_refinery_%s'):format(refineryId),
                    label = 'Refinery Management',
                    icon = 'fas fa-industry',
                    distance = 2.5,
                    onSelect = function()
                        handleEntityInteraction('refinery', refineryId)
                    end,
                }
            })
        end

        local blip = createBlip(refinery.coords, 436, 47, refinery.label)
        spawnedBlips[#spawnedBlips + 1] = blip
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

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, ped in ipairs(spawnedPeds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end

    for _, blip in ipairs(spawnedBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
end)

if not Config.Rentals or not Config.Rentals.Enabled then return end

local rentalNPCs = {}
local rentalVehicles = {}
local rentalBlips = {}
local rentalCost = 0

local function loadVehicleModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(hash) do
        Wait(0)
        if GetGameTimer() > timeout then return nil end
    end
    return hash
end

local function giveVehicleKeys(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle)
    if not plate then return end

    pcall(function()
        TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', plate)
    end)
    pcall(function()
        exports['qbx_vehiclekeys']:GiveKeys(source, plate)
    end)
end

local function cleanupRentals()
    for _, veh in ipairs(rentalVehicles) do
        if DoesEntityExist(veh) then
            SetEntityAsMissionEntity(veh, true, true)
            DeleteVehicle(veh)
        end
    end
    rentalVehicles = {}

    for _, blip in ipairs(rentalBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    rentalBlips = {}
    rentalCost = 0
end

local function addRentalBlip(entity)
    local blip = AddBlipForEntity(entity)
    SetBlipSprite(blip, 477)
    SetBlipColour(blip, 3)
    SetBlipScale(blip, 0.9)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Rental Vehicle')
    EndTextCommandSetBlipName(blip)
    rentalBlips[#rentalBlips + 1] = blip
end

local function spawnRental(vehicleCfg, truckSpawn, trailerSpawn)
    local price = vehicleCfg.price or 0
    local result = lib.callback.await('hbs-fuel:server:rentalPayment', false, price)
    if not result or not result.ok then
        HBSFuelNotify(result and result.message or 'Payment failed.', 'error')
        return
    end

    rentalCost = rentalCost + price

    if vehicleCfg.truck and vehicleCfg.trailer then
        local truckHash = loadVehicleModel(vehicleCfg.truck)
        if not truckHash then
            HBSFuelNotify('Failed to load truck model.', 'error')
            return
        end
        local trailerHash = loadVehicleModel(vehicleCfg.trailer)
        if not trailerHash then
            SetModelAsNoLongerNeeded(truckHash)
            HBSFuelNotify('Failed to load trailer model.', 'error')
            return
        end

        local tx, ty, tz, tw = truckSpawn.x, truckSpawn.y, truckSpawn.z, truckSpawn.w or 0.0
        local truck = CreateVehicle(truckHash, tx, ty, tz, tw, true, false)
        SetEntityAsMissionEntity(truck, true, true)
        SetVehicleOnGroundProperly(truck)
        SetModelAsNoLongerNeeded(truckHash)

        local rx, ry, rz, rw = trailerSpawn.x, trailerSpawn.y, trailerSpawn.z, trailerSpawn.w or 0.0
        local trailer = CreateVehicle(trailerHash, rx, ry, rz, rw, true, false)
        SetEntityAsMissionEntity(trailer, true, true)
        SetVehicleOnGroundProperly(trailer)
        SetModelAsNoLongerNeeded(trailerHash)

        AttachVehicleToTrailer(truck, trailer, 1.0)
        rentalVehicles[#rentalVehicles + 1] = truck
        rentalVehicles[#rentalVehicles + 1] = trailer

        giveVehicleKeys(truck)
        addRentalBlip(truck)
    else
        local isTrailer = vehicleCfg.model == 'tanker2' or vehicleCfg.model == 'tanker'
        local spawn = isTrailer and trailerSpawn or truckSpawn
        local x, y, z, w = spawn.x, spawn.y, spawn.z, spawn.w or 0.0
        local hash = loadVehicleModel(vehicleCfg.model)
        if not hash then
            HBSFuelNotify('Failed to load vehicle model.', 'error')
            return
        end

        local veh = CreateVehicle(hash, x, y, z, w, true, false)
        SetEntityAsMissionEntity(veh, true, true)
        SetVehicleOnGroundProperly(veh)
        SetModelAsNoLongerNeeded(hash)
        rentalVehicles[#rentalVehicles + 1] = veh

        if not isTrailer then
            giveVehicleKeys(veh)
        end
        addRentalBlip(veh)
    end

    HBSFuelNotify(('Rental spawned. Cost: $%d'):format(price), 'success')
end

local function returnSingleVehicle(index)
    local veh = rentalVehicles[index]
    if not veh or not DoesEntityExist(veh) then
        table.remove(rentalVehicles, index)
        return
    end

    SetEntityAsMissionEntity(veh, true, true)
    DeleteVehicle(veh)
    table.remove(rentalVehicles, index)

    -- Remove corresponding blip
    if rentalBlips[index] and DoesBlipExist(rentalBlips[index]) then
        RemoveBlip(rentalBlips[index])
    end
    table.remove(rentalBlips, index)

    HBSFuelNotify('Vehicle returned.', 'success')
end

local function returnRental()
    if #rentalVehicles == 0 then
        HBSFuelNotify('You have no active rentals.', 'error')
        return
    end

    local refund = math.floor(rentalCost * (Config.Rentals.ReturnRefund or 0.5))
    if refund > 0 then
        TriggerServerEvent('hbs-fuel:server:rentalRefund', refund)
    end

    cleanupRentals()
    HBSFuelNotify(('All rentals returned. Refund: $%d'):format(refund), 'success')
end

local function openRentalMenu(truckSpawn, trailerSpawn)
    local vehicles = Config.Rentals.Vehicles or {}
    local options = {}

    for _, veh in ipairs(vehicles) do
        options[#options + 1] = {
            title = veh.label,
            description = ('$%s'):format(veh.price),
            icon = veh.truck and 'fa-solid fa-truck-moving' or 'fa-solid fa-truck',
            onSelect = function()
                spawnRental(veh, truckSpawn, trailerSpawn)
            end,
        }
    end

    if #rentalVehicles > 0 then
        for i, veh in ipairs(rentalVehicles) do
            if DoesEntityExist(veh) then
                local modelName = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
                options[#options + 1] = {
                    title = ('Return: %s'):format(modelName or 'Vehicle'),
                    description = 'Return this vehicle',
                    icon = 'fa-solid fa-rotate-left',
                    onSelect = function()
                        returnSingleVehicle(i)
                    end,
                }
            end
        end

        local refund = math.floor(rentalCost * (Config.Rentals.ReturnRefund or 0.5))
        options[#options + 1] = {
            title = 'Return All Rentals',
            description = ('Refund: $%d'):format(refund),
            icon = 'fa-solid fa-xmark',
            onSelect = function()
                returnRental()
            end,
        }
    end

    lib.registerContext({
        id = 'hbs_fuel_rental_menu',
        title = 'Vehicle Rental',
        options = options,
    })
    lib.showContext('hbs_fuel_rental_menu')
end

-- ── NPC SPAWNING ──

local function spawnRentalNPCs()
    for i, loc in ipairs(Config.Rentals.Locations or {}) do
        local hash = joaat(loc.model)
        RequestModel(hash)
        local timeout = GetGameTimer() + 5000
        while not HasModelLoaded(hash) do
            Wait(0)
            if GetGameTimer() > timeout then break end
        end
        if not HasModelLoaded(hash) then goto continue end

        local x, y, z, w = loc.coords.x, loc.coords.y, loc.coords.z, loc.coords.w or 0.0
        local ped = CreatePed(0, hash, x, y, z, w, false, true)
        if not ped or ped == 0 then goto continue end

        SetPedFleeAttributes(ped, 0, false)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedDiesWhenInjured(ped, false)
        SetPedCanPlayAmbientAnims(ped, true)
        SetPedCanRagdollFromPlayerImpact(ped, false)
        SetEntityAsMissionEntity(ped, true, true)
        PlaceObjectOnGroundProperly(ped)
        SetModelAsNoLongerNeeded(hash)

        exports['ox_target']:addLocalEntity(ped, {
            {
                name = ('hbs_fuel_rental_npc_%d'):format(i),
                icon = 'fa-solid fa-truck',
                label = loc.label or 'Vehicle Rental',
                onSelect = function()
                    openRentalMenu(loc.truckSpawn, loc.trailerSpawn)
                end
            },
        })

        rentalNPCs[#rentalNPCs + 1] = ped
        ::continue::
    end
end

CreateThread(function()
    Wait(2000)
    spawnRentalNPCs()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    cleanupRentals()
    for _, ped in ipairs(rentalNPCs) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    rentalNPCs = {}
end)

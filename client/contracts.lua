local jobVehicles = {}
local jobBlip = nil
local contractHud = {
    active = false,
    contract = nil,
    stage = nil,   -- 'pickup' or 'dropoff'
}

local function cleanupJobVehicles()
    for _, veh in ipairs(jobVehicles) do
        if DoesEntityExist(veh) then
            SetEntityAsMissionEntity(veh, true, true)
            DeleteVehicle(veh)
        end
    end
    jobVehicles = {}

    if jobBlip and DoesBlipExist(jobBlip) then
        RemoveBlip(jobBlip)
    end
    jobBlip = nil
end

-- ── CONTRACT HUD ──

local function resolveRefineryFallback()
    for id, refinery in pairs(Refineries) do
        return id, refinery
    end
    return nil, nil
end

local function resolveLabel(locationType, locationId)
    if locationType == 'station' and Stations[locationId] then
        return Stations[locationId].label
    elseif locationType == 'refinery' then
        if Refineries[locationId] then
            return Refineries[locationId].label
        end
        local _, r = resolveRefineryFallback()
        if r then return r.label end
    elseif locationType == 'oilshop' and Config.OilShops and Config.OilShops[locationId] then
        return Config.OilShops[locationId].label
    elseif locationType == 'crude_source' then
        return 'Crude Source (Coast)'
    end
    return locationId or 'Unknown'
end

local function resolveCoords(locationType, locationId, forAction)
    -- forAction: 'pickup' (loading) or 'dropoff' (unloading)
    if locationType == 'station' and Stations[locationId] then
        local s = Stations[locationId]
        if forAction == 'dropoff' and s.unloadPoints and s.unloadPoints[1] then
            return s.unloadPoints[1]
        end
        return s.coords
    elseif locationType == 'refinery' then
        local r = Refineries[locationId]
        if not r then
            for _, rf in pairs(Refineries) do r = rf; break end
        end
        if r then
            if forAction == 'pickup' and r.points and r.points.tankerLoad then
                return r.points.tankerLoad
            elseif forAction == 'dropoff' and r.points and r.points.crudeDelivery and r.points.crudeDelivery[1] then
                return r.points.crudeDelivery[1]
            end
            return r.coords
        end
    elseif locationType == 'oilshop' and Config.OilShops and Config.OilShops[locationId] then
        local shop = Config.OilShops[locationId]
        if forAction == 'dropoff' and shop.unloadPoints and shop.unloadPoints[1] then
            return shop.unloadPoints[1]
        end
        return shop.coords
    elseif locationType == 'crude_source' then
        for _, refinery in pairs(Refineries) do
            if refinery.points and refinery.points.crudeSource then
                return refinery.points.crudeSource
            end
        end
    end
    return nil
end

local function buildHudText(contract, stage)
    if not contract then return nil end

    local productLabel = contract.product or 'fuel'
    if FuelTypes and FuelTypes[productLabel] then
        productLabel = FuelTypes[productLabel].label
    elseif productLabel == 'crude' then
        productLabel = 'Crude Oil'
    end

    local lines = {}
    lines[#lines + 1] = ('📋 **%s Contract**'):format(contract.type == 'crude' and 'Crude Haul' or 'Delivery')
    lines[#lines + 1] = ('Product: %s'):format(productLabel)
    lines[#lines + 1] = ('Amount: %.0fL'):format(contract.litresRequired or 0)
    lines[#lines + 1] = ('Payout: $%s'):format(contract.payout or 0)
    lines[#lines + 1] = ''

    if stage == 'pickup' then
        local label = resolveLabel(contract.pickupType, contract.pickupId)
        lines[#lines + 1] = ('🎯 **Load at:** %s'):format(label)
        if contract.type == 'crude' then
            lines[#lines + 1] = 'Load crude into your tanker'
        else
            lines[#lines + 1] = ('Load %s into your tanker'):format(productLabel)
        end
    elseif stage == 'dropoff' then
        local label = resolveLabel(contract.dropoffType, contract.dropoffId)
        lines[#lines + 1] = ('🎯 **Deliver to:** %s'):format(label)
        lines[#lines + 1] = 'Unload the tanker at the destination'
    end

    return table.concat(lines, '  \n')
end

local function updateHud(contract, stage)
    lib.hideTextUI()

    if not contract then
        contractHud.active = false
        contractHud.contract = nil
        contractHud.stage = nil
        return
    end

    contractHud.active = true
    contractHud.contract = contract
    contractHud.stage = stage

    local text = buildHudText(contract, stage)
    if text then
        Wait(50)
        lib.showTextUI(text, {
            position = 'right-center',
            icon = 'clipboard-list',
            style = {
                borderRadius = 8,
                backgroundColor = '#1a1a1eee',
                color = '#ffffff',
            }
        })
    end
end

local function setPickupWaypoint(contract)
    local coords = resolveCoords(contract.pickupType, contract.pickupId, 'pickup')
    if coords then
        SetNewWaypoint(coords.x, coords.y)
        local label = resolveLabel(contract.pickupType, contract.pickupId)
        HBSFuelNotify(('Head to %s to load'):format(label), 'inform')
    end
end

local function setDropoffWaypoint(contract)
    local coords = resolveCoords(contract.dropoffType, contract.dropoffId, 'dropoff')
    if coords then
        SetNewWaypoint(coords.x, coords.y)
        local label = resolveLabel(contract.dropoffType, contract.dropoffId)
        HBSFuelNotify(('Deliver to %s'):format(label), 'inform')
    end
end

-- Called when a contract is accepted
RegisterNetEvent('hbs-fuel:client:contractStarted', function(contract)
    if not contract then return end
    updateHud(contract, 'pickup')
    setPickupWaypoint(contract)
end)

-- Called after loading tanker with correct product
RegisterNetEvent('hbs-fuel:client:contractLoaded', function()
    if not contractHud.active or not contractHud.contract then return end
    updateHud(contractHud.contract, 'dropoff')
    setDropoffWaypoint(contractHud.contract)
    HBSFuelNotify('Fuel loaded! Heading to delivery location.', 'success')
end)

-- Exported so nui.lua + industrial.lua can trigger it directly
function HBSFuelStartContractHud(contract)
    if not contract then return end
    updateHud(contract, 'pickup')
    setPickupWaypoint(contract)
end

function HBSFuelContractLoaded(contract)
    if not contract then
        contract = contractHud.contract
    end
    if not contract then
        local data = lib.callback.await('hbs-fuel:server:getContracts', false)
        contract = data and data.active
    end
    if not contract then return end
    updateHud(contract, 'dropoff')
    setDropoffWaypoint(contract)
    HBSFuelNotify('Fuel loaded! Heading to delivery location.', 'success')
end

function HBSFuelClearContractHud()
    updateHud(nil)
end

-- Used by other systems (e.g. help-marker thread) to know if the contract
-- HUD currently owns the text UI so they don't clobber it.
function HBSFuelIsContractHudActive()
    return contractHud.active == true
end

-- Re-shows the current contract HUD text. Used after another system
-- temporarily took over the text UI (e.g. help markers) so the contract
-- info doesn't vanish.
function HBSFuelRefreshContractHud()
    if not contractHud.active or not contractHud.contract or not contractHud.stage then
        return
    end
    local text = buildHudText(contractHud.contract, contractHud.stage)
    if text then
        lib.showTextUI(text, {
            position = 'right-center',
            icon = 'clipboard-list',
            style = {
                borderRadius = 8,
                backgroundColor = '#1a1a1eee',
                color = '#ffffff',
            }
        })
    end
end

-- ── JOB VEHICLE SPAWNING ──

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

RegisterNetEvent('hbs-fuel:client:spawnJobVehicle', function(contractType, truckSpawn, trailerSpawn)
    cleanupJobVehicles()

    local cfg = Config.JobVehicles and Config.JobVehicles[contractType]
    if not cfg then return end

    local truckHash = loadVehicleModel(cfg.truck)
    if not truckHash then
        HBSFuelNotify('Failed to load truck model.', 'error')
        return
    end

    local trailerHash = loadVehicleModel(cfg.trailer)
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

    jobVehicles = { truck, trailer }

    jobBlip = AddBlipForEntity(truck)
    SetBlipSprite(jobBlip, 477)
    SetBlipColour(jobBlip, 5)
    SetBlipScale(jobBlip, 0.9)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Job Vehicle')
    EndTextCommandSetBlipName(jobBlip)

    HBSFuelNotify('Job vehicle spawned. Check your map.', 'success')
end)

RegisterNetEvent('hbs-fuel:client:openContractsBoard', function()
    OpenContractsNUI()
end)

RegisterNetEvent('hbs-fuel:client:contractCompleted', function(payout)
    cleanupJobVehicles()
    HBSFuelClearContractHud()
    HBSFuelNotify(('Contract completed! $%s deposited to your bank.'):format(payout or 0), 'success')
end)

RegisterCommand('fuelcontracts', function()
    OpenContractsNUI()
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    cleanupJobVehicles()
    lib.hideTextUI()
end)

-- On player load, check for active contract and restore HUD
CreateThread(function()
    Wait(5000)
    local data = lib.callback.await('hbs-fuel:server:getContracts', false)
    if data and data.active then
        HBSFuelStartContractHud(data.active)
    end
end)

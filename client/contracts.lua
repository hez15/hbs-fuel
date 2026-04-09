local jobVehicles = {}

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

local jobBlip = nil

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

RegisterNetEvent('hbs-fuel:client:spawnJobVehicle', function(contractType, spawnCoords)
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

    local x, y, z, w = spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w or 0.0

    local truck = CreateVehicle(truckHash, x, y, z, w, true, false)
    SetEntityAsMissionEntity(truck, true, true)
    SetVehicleOnGroundProperly(truck)
    SetModelAsNoLongerNeeded(truckHash)

    local behindX = x - math.sin(math.rad(w)) * 12.0
    local behindY = y + math.cos(math.rad(w)) * 12.0
    local trailer = CreateVehicle(trailerHash, behindX, behindY, z, w, true, false)
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
    HBSFuelNotify(('Contract completed! $%s deposited to your bank.'):format(payout or 0), 'success')
end)

RegisterCommand('fuelcontracts', function()
    OpenContractsNUI()
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    cleanupJobVehicles()
end)

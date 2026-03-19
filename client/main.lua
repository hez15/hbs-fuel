local currentVehicle
local currentPlate
local vehicleFuelCache = {}
local fuelSaveTimer = 0

local function normalizePlate(plate)
    return plate and plate:gsub('^%s*(.-)%s*$', '%1') or nil
end

function HBSFuelNormalizePlate(plate)
    return normalizePlate(plate)
end

function HBSFuelSaveFuelByPlate(plate, litres)
    plate = normalizePlate(plate)
    if not plate or type(litres) ~= 'number' then return false end

    vehicleFuelCache[plate] = litres
    TriggerServerEvent('hbs-fuel:server:saveVehicleFuel', plate, litres)
    return true
end

function GetCachedVehicleFuel(vehicle)
    if not DoesEntityExist(vehicle) then return nil end

    local plate = normalizePlate(GetVehicleNumberPlateText(vehicle))
    if plate and vehicleFuelCache[plate] then
        return vehicleFuelCache[plate]
    end

    local capacity = HBSFuel.GetTankCapacity(vehicle)
    local currentPercent = GetVehicleFuelLevel(vehicle)
    local litres = HBSFuel.Clamp((currentPercent / 100.0) * capacity, 0.0, capacity)

    if plate then
        vehicleFuelCache[plate] = litres
    end

    return litres
end

function SetCachedVehicleFuel(vehicle, litres)
    if not DoesEntityExist(vehicle) then return end

    local capacity = HBSFuel.GetTankCapacity(vehicle)
    litres = HBSFuel.Clamp(litres, 0.0, capacity)

    local plate = normalizePlate(GetVehicleNumberPlateText(vehicle))
    if plate then
        vehicleFuelCache[plate] = litres
    end

    local percent = (litres / capacity) * 100.0
    SetVehicleFuelLevel(vehicle, percent + 0.0)

    if litres <= 0.05 and GetIsVehicleEngineRunning(vehicle) then
        SetVehicleEngineOn(vehicle, false, true, true)
    end
end

exports('GetVehicleFuel', function(vehicle)
    return GetCachedVehicleFuel(vehicle)
end)

exports('SetVehicleFuel', function(vehicle, litres)
    SetCachedVehicleFuel(vehicle, litres)
end)

exports('AddVehicleFuel', function(vehicle, litres)
    local current = GetCachedVehicleFuel(vehicle) or 0.0
    SetCachedVehicleFuel(vehicle, current + litres)
end)

local function loadVehicleFuel(vehicle)
    local plate = normalizePlate(GetVehicleNumberPlateText(vehicle))
    if not plate then return end

    local saved = lib.callback.await('hbs-fuel:server:getVehicleFuel', false, plate)
    if saved then
        SetCachedVehicleFuel(vehicle, saved)
        return
    end

    local capacity = HBSFuel.GetTankCapacity(vehicle)
    local currentPercent = GetVehicleFuelLevel(vehicle)
    local defaultLitres = HBSFuel.Clamp((currentPercent / 100.0) * capacity, 0.0, capacity)

    if defaultLitres <= 0.0 then
        defaultLitres = capacity * 0.8
    end

    SetCachedVehicleFuel(vehicle, defaultLitres)
end

local function saveVehicleFuel(vehicle)
    local plate = normalizePlate(GetVehicleNumberPlateText(vehicle))
    if not plate then return end

    local litres = GetCachedVehicleFuel(vehicle)
    if not litres then return end

    HBSFuelSaveFuelByPlate(plate, litres)
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
            if currentVehicle ~= vehicle then
                if currentVehicle and DoesEntityExist(currentVehicle) then
                    saveVehicleFuel(currentVehicle)
                end

                currentVehicle = vehicle
                currentPlate = normalizePlate(GetVehicleNumberPlateText(vehicle))

                if Config.LoadFuelOnVehicleEnter then
                    loadVehicleFuel(vehicle)
                end
            end

            if Config.SaveFuelEverySeconds > 0 then
                fuelSaveTimer = fuelSaveTimer + 1000
                if fuelSaveTimer >= (Config.SaveFuelEverySeconds * 1000) then
                    fuelSaveTimer = 0
                    saveVehicleFuel(vehicle)
                end
            end
        else
            if currentVehicle and DoesEntityExist(currentVehicle) then
                saveVehicleFuel(currentVehicle)
            end

            currentVehicle = nil
            currentPlate = nil
            fuelSaveTimer = 0
        end

        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if currentVehicle and DoesEntityExist(currentVehicle) then
        saveVehicleFuel(currentVehicle)
    end
end)

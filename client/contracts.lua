local activeContractHud = false
local hudThread = false

local function urgencyLabel(urgency)
    if urgency == 'critical' then
        return '~r~Critical~s~'
    elseif urgency == 'high' then
        return '~y~High~s~'
    end
    return 'Normal'
end

local function urgencyIcon(urgency)
    if urgency == 'critical' then return 'circle-exclamation' end
    if urgency == 'high' then return 'triangle-exclamation' end
    return 'circle-info'
end

local function resolveLocationLabel(locationType, locationId)
    if locationType == 'station' and Stations[locationId] then
        return Stations[locationId].label
    elseif locationType == 'refinery' and Refineries[locationId] then
        return Refineries[locationId].label
    elseif locationType == 'crude_source' then
        return 'Crude Source'
    end
    return locationId or 'Unknown'
end

local function resolveLocationCoords(locationType, locationId)
    if locationType == 'station' and Stations[locationId] then
        return Stations[locationId].coords
    elseif locationType == 'refinery' and Refineries[locationId] then
        return Refineries[locationId].coords
    elseif locationType == 'crude_source' then
        for _, refinery in pairs(Refineries) do
            if refinery.points and refinery.points.crudeSource then
                return refinery.points.crudeSource
            end
        end
    end
    return nil
end

local function setWaypoint(locationType, locationId)
    local coords = resolveLocationCoords(locationType, locationId)
    if coords then
        SetNewWaypoint(coords.x, coords.y)
    end
end

local function formatTimeRemaining(expiresAt)
    if not expiresAt then return '' end
    local remaining = expiresAt - os.time()
    if remaining <= 0 then return '~r~Expired~s~' end
    local mins = math.floor(remaining / 60)
    local secs = remaining % 60
    if mins > 0 then
        return ('%dm %ds'):format(mins, secs)
    end
    return ('%ds'):format(secs)
end

local function buildDescription(contract)
    local pickupLabel = resolveLocationLabel(contract.pickupType, contract.pickupId)
    local dropoffLabel = resolveLocationLabel(contract.dropoffType, contract.dropoffId)

    local lines = {
        ('Type: %s'):format(contract.type == 'crude' and 'Crude Haul' or 'Fuel Delivery'),
        ('Product: %s'):format(contract.product),
        ('Required: %.0fL'):format(contract.litresRequired or 0.0),
        ('Pickup: %s'):format(pickupLabel),
        ('Dropoff: %s'):format(dropoffLabel),
        ('Urgency: %s'):format(urgencyLabel(contract.urgency)),
        ('Payout: $%s'):format(contract.payout or 0),
    }

    if contract.litresDelivered and contract.litresDelivered > 0 then
        local pct = math.floor((contract.litresDelivered / (contract.litresRequired or 1)) * 100)
        lines[#lines + 1] = ('Progress: %.0f / %.0fL (%d%%)'):format(contract.litresDelivered, contract.litresRequired or 0.0, pct)
    end

    if contract.expiresAt then
        lines[#lines + 1] = ('Expires: %s'):format(formatTimeRemaining(contract.expiresAt))
    end

    return table.concat(lines, '\n')
end

local function stopContractHud()
    activeContractHud = false
end

local function startContractHud(contract)
    if hudThread then
        activeContractHud = false
        Wait(100)
    end

    activeContractHud = true
    hudThread = true

    CreateThread(function()
        while activeContractHud do
            local active = lib.callback.await('hbs-fuel:server:getContracts', false)
            if not active or not active.active then
                activeContractHud = false
                break
            end

            local c = active.active
            local pct = math.floor((c.litresDelivered / (c.litresRequired or 1)) * 100)
            local dropoffLabel = resolveLocationLabel(c.dropoffType, c.dropoffId)
            local text = ('Contract: %s | %.0f/%.0fL (%d%%) | Drop: %s'):format(
                c.product, c.litresDelivered, c.litresRequired, pct, dropoffLabel
            )

            lib.showTextUI(text, { position = 'top-center' })
            Wait(5000)
            lib.hideTextUI()

            if c.status == 'completed' then
                activeContractHud = false
                break
            end
        end

        hudThread = false
        lib.hideTextUI()
    end)
end

local function openContractsBoard()
    local data = lib.callback.await('hbs-fuel:server:getContracts', false)
    if not data then
        HBSFuelNotify('Unable to load contracts.', 'error')
        return
    end

    local options = {}

    if data.active then
        local pct = 0
        if data.active.litresRequired and data.active.litresRequired > 0 then
            pct = math.floor((data.active.litresDelivered or 0) / data.active.litresRequired * 100)
        end

        options[#options + 1] = {
            title = ('Active: %s (%d%%)'):format(data.active.id, pct),
            description = buildDescription(data.active),
            icon = 'clipboard-check',
            iconColor = '#4ade80',
            onSelect = function()
                local result = lib.alertDialog({
                    header = 'Active Contract',
                    content = buildDescription(data.active) .. '\n\nSet waypoint to pickup or dropoff, or cancel the contract.',
                    centered = true,
                    cancel = true,
                    labels = {
                        cancel = 'Close',
                        confirm = 'Cancel Contract'
                    }
                })

                if result == 'confirm' then
                    local cancelled = lib.callback.await('hbs-fuel:server:cancelActiveContract', false)
                    if cancelled and cancelled.ok then
                        HBSFuelNotify('Contract cancelled.', 'inform')
                        stopContractHud()
                    else
                        HBSFuelNotify(cancelled and cancelled.message or 'Unable to cancel contract.', 'error')
                    end
                end
            end,
            metadata = {
                { label = 'Waypoint: Pickup', value = resolveLocationLabel(data.active.pickupType, data.active.pickupId) },
                { label = 'Waypoint: Dropoff', value = resolveLocationLabel(data.active.dropoffType, data.active.dropoffId) },
            },
        }

        options[#options + 1] = {
            title = 'Set Waypoint to Pickup',
            icon = 'location-arrow',
            iconColor = '#60a5fa',
            onSelect = function()
                setWaypoint(data.active.pickupType, data.active.pickupId)
                HBSFuelNotify('Waypoint set to pickup location.', 'success')
            end,
        }

        options[#options + 1] = {
            title = 'Set Waypoint to Dropoff',
            icon = 'flag-checkered',
            iconColor = '#f97316',
            onSelect = function()
                setWaypoint(data.active.dropoffType, data.active.dropoffId)
                HBSFuelNotify('Waypoint set to dropoff location.', 'success')
            end,
        }
    end

    if #(data.available or {}) == 0 then
        options[#options + 1] = {
            title = 'No contracts available',
            description = 'Check back shortly.',
            icon = 'ban',
            readOnly = true,
        }
    else
        for _, contract in ipairs(data.available) do
            local iconColor = '#9ca3af'
            if contract.urgency == 'critical' then
                iconColor = '#ef4444'
            elseif contract.urgency == 'high' then
                iconColor = '#eab308'
            end

            options[#options + 1] = {
                title = ('%s [%s]'):format(contract.id, urgencyLabel(contract.urgency)),
                description = buildDescription(contract),
                icon = contract.type == 'crude' and 'truck-ramp-box' or 'gas-pump',
                iconColor = iconColor,
                onSelect = function()
                    if data.active then
                        HBSFuelNotify('You already have an active contract. Cancel it first.', 'error')
                        return
                    end

                    local accepted = lib.callback.await('hbs-fuel:server:acceptContract', false, contract.id)
                    if not accepted or not accepted.ok then
                        HBSFuelNotify(accepted and accepted.message or 'Unable to accept contract.', 'error')
                        return
                    end

                    HBSFuelNotify(('Accepted contract %s — $%s payout'):format(contract.id, contract.payout or 0), 'success')

                    setWaypoint(contract.pickupType, contract.pickupId)
                    startContractHud(accepted.contract)
                end
            }
        end
    end

    options[#options + 1] = {
        title = 'Refresh',
        description = 'Reload the contracts board.',
        icon = 'arrows-rotate',
        onSelect = function()
            openContractsBoard()
        end
    }

    lib.registerContext({
        id = 'hbs_fuel_contracts_board',
        title = 'Fuel Contracts',
        options = options,
    })

    lib.showContext('hbs_fuel_contracts_board')
end

RegisterNetEvent('hbs-fuel:client:openContractsBoard', function()
    OpenContractsNUI()
end)

RegisterNetEvent('hbs-fuel:client:contractCompleted', function(payout)
    stopContractHud()
    HBSFuelNotify(('Contract completed! $%s deposited to your bank.'):format(payout or 0), 'success')
end)

RegisterCommand('fuelcontracts', function()
    OpenContractsNUI()
end, false)

local function urgencyLabel(urgency)
    if urgency == 'critical' then
        return 'Critical'
    elseif urgency == 'high' then
        return 'High'
    end
    return 'Normal'
end

local function buildDescription(contract)
    local lines = {
        ('Type: %s'):format(contract.type == 'crude' and 'Crude Haul' or 'Fuel Delivery'),
        ('Product: %s'):format(contract.product),
        ('Required: %.2fL'):format(contract.litresRequired or 0.0),
        ('Urgency: %s'):format(urgencyLabel(contract.urgency)),
        ('Payout: $%s'):format(contract.payout or 0),
    }

    if contract.litresDelivered and contract.litresDelivered > 0 then
        lines[#lines + 1] = ('Progress: %.2f / %.2fL'):format(contract.litresDelivered, contract.litresRequired or 0.0)
    end

    return table.concat(lines, '\n')
end

local function openContractsBoard()
    local data = lib.callback.await('hbs-fuel:server:getContracts', false)
    if not data then
        HBSFuelNotify('Unable to load contracts.', 'error')
        return
    end

    local options = {}

    if data.active then
        options[#options + 1] = {
            title = ('Active Contract: %s'):format(data.active.id),
            description = buildDescription(data.active),
            icon = 'clipboard-check',
            onSelect = function()
                local result = lib.alertDialog({
                    header = 'Active Contract',
                    content = buildDescription(data.active),
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
                    else
                        HBSFuelNotify(cancelled and cancelled.message or 'Unable to cancel contract.', 'error')
                    end
                end
            end
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
            options[#options + 1] = {
                title = ('%s [%s]'):format(contract.id, urgencyLabel(contract.urgency)),
                description = buildDescription(contract),
                icon = contract.type == 'crude' and 'truck-ramp-box' or 'gas-pump',
                onSelect = function()
                    local accepted = lib.callback.await('hbs-fuel:server:acceptContract', false, contract.id)
                    if not accepted or not accepted.ok then
                        HBSFuelNotify(accepted and accepted.message or 'Unable to accept contract.', 'error')
                        return
                    end

                    HBSFuelNotify(('Accepted contract %s'):format(contract.id), 'success')
                end
            }
        end
    end

    lib.registerContext({
        id = 'hbs_fuel_contracts_board',
        title = 'Fuel Contracts',
        options = options,
    })

    lib.showContext('hbs_fuel_contracts_board')
end

RegisterNetEvent('hbs-fuel:client:openContractsBoard', function()
    openContractsBoard()
end)

RegisterCommand('fuelcontracts', function()
    openContractsBoard()
end, false)
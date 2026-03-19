local function getPlayer(source)
    local ok, player = pcall(function()
        return exports['qbx_core']:GetPlayer(source)
    end)

    if ok then
        return player
    end

    return nil
end

local function getAccountBalance(player, account)
    if not player then return 0 end
    return player.PlayerData and player.PlayerData.money and player.PlayerData.money[account] or 0
end

function HBSFuelHasMoney(source, amount, account)
    local player = getPlayer(source)
    if not player then return false end

    local selected = (account == 'bank' and 'bank') or 'cash'
    return getAccountBalance(player, selected) >= amount
end

function HBSFuelRemoveMoney(source, amount, account, reason)
    local player = getPlayer(source)
    if not player then return false end

    local selected = (account == 'bank' and 'bank') or 'cash'
    return player.Functions.RemoveMoney(selected, amount, reason or 'fuel_purchase')
end

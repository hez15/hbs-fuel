function HBSFuelNotify(message, notifyType)
    if Config.NotificationsEnabled == false then
        return
    end

    lib.notify({
        title = Config.NotifyTitle or 'Fuel',
        description = message,
        type = notifyType or 'inform'
    })
end

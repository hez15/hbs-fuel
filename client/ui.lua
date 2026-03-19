function HBSFuelNotify(message, notifyType)
    lib.notify({
        title = 'Fuel',
        description = message,
        type = notifyType or 'inform'
    })
end

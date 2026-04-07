RegisterNetEvent('hbs-fuel:client:openContractsBoard', function()
    OpenContractsNUI()
end)

RegisterNetEvent('hbs-fuel:client:contractCompleted', function(payout)
    HBSFuelNotify(('Contract completed! $%s deposited to your bank.'):format(payout or 0), 'success')
end)

RegisterCommand('fuelcontracts', function()
    OpenContractsNUI()
end, false)

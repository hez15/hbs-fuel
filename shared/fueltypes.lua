FuelTypes = {
    regular = {
        label = 'Regular',
        price = 2.15,         -- balanced for typical server economy
        aircraftOnly = false,
        canUseJerryCan = true,
    },
    diesel = {
        label = 'Diesel',
        price = 2.45,         -- premium over regular for commercial vehicles
        aircraftOnly = false,
        canUseJerryCan = true,
    },
    jetfuel = {
        label = 'Jet Fuel',
        price = 4.50,         -- aviation premium
        aircraftOnly = true,
        canUseJerryCan = false,
    },
    motoroil = {
        label = 'Motor Oil',
        price = 8.50,
        aircraftOnly = false,
        canUseJerryCan = false,
        byproduct = true,
    }
}

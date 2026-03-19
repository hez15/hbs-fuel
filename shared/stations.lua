Stations = {
    ltd_little_seoul = {
        label = 'Little Seoul LTD',
        coords = vec3(-709.64, -905.17, 19.22),
        radius = 35.0,
        supports = { 'regular', 'diesel' },
        unloadPoints = {
            vec3(-715.0, -916.75, 19.22),
        },
        tanks = {
            regular = { current = 6500.0, max = 8000.0 },
            diesel = { current = 2200.0, max = 4000.0 },
        },
        priceMultiplier = 1.0,
        demandMultiplier = 1.15,
        emergencyRefill = true,
    },
    ltd_davis = {
        label = 'Davis LTD',
        coords = vec3(-48.72, -1761.03, 29.42),
        radius = 35.0,
        supports = { 'regular', 'diesel' },
        unloadPoints = {
            vec3(-37.4, -1747.9, 29.3),
        },
        tanks = {
            regular = { current = 7000.0, max = 9000.0 },
            diesel = { current = 2600.0, max = 4500.0 },
        },
        priceMultiplier = 1.02,
        demandMultiplier = 1.25,
        emergencyRefill = true,
    },
    airport_aviation = {
        label = 'LSIA Aviation Fuel',
        coords = vec3(-1027.34, -2735.23, 13.76),
        radius = 60.0,
        supports = { 'jetfuel' },
        unloadPoints = {
            vec3(-1020.6, -2727.9, 13.76),
        },
        tanks = {
            jetfuel = { current = 15000.0, max = 25000.0 },
        },
        priceMultiplier = 1.15,
        demandMultiplier = 0.5,
        emergencyRefill = true,
    },
}

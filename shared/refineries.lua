Refineries = {
    cypress_refinery = {
        label = 'Cypress Refinery',
        coords = vec3(1687.2, -1662.05, 110.44),
        -- TODO: Set exact ped position in-game. Format: vec4(x, y, z, heading)
        pedCoords = vec4(1685.0, -1660.0, 110.44, 220.0),
        radius = 90.0,
        crude = {
            current = 10000.0,
            max = 50000.0,
        },
        products = {
            regular = { current = 12000.0, max = 40000.0 },
            diesel = { current = 7000.0, max = 22000.0 },
            jetfuel = { current = 4000.0, max = 18000.0 },
            motoroil = { current = 1500.0, max = 6000.0 },
        },
        recipe = 'crude_basic',
        points = {
            crudeSource = vec3(1293.16, -3250.9, 4.91),
            crudeDelivery = {
                vec3(1716.59, -1621.22, 111.48),
                vec3(1696.63, -1553.45, 111.65),
            },
            processStart = vec3(1687.2, -1662.05, 110.44),
            valve = vec3(1661.34, -1685.59, 111.53),
            tankerLoad = vec3(1673.77, -1619.95, 111.48),
        }
    }
}

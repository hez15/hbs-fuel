Config = {}

Config.Debug = true
Config.UseOxTarget = true
Config.UseJerryCan = true
Config.DefaultFuelType = 'regular'
Config.DefaultTankSize = 65.0

Config.ClassTankSizes = {
    [0] = 50.0,
    [1] = 60.0,
    [2] = 70.0,
    [3] = 65.0,
    [4] = 70.0,
    [5] = 75.0,
    [6] = 80.0,
    [7] = 85.0,
    [8] = 20.0,
    [9] = 85.0,
    [10] = 120.0,
    [11] = 100.0,
    [12] = 90.0,
    [13] = 0.0,
    [14] = 0.0,
    [15] = 450.0,
    [16] = 2200.0,
    [17] = 65.0,
    [18] = 80.0,
    [19] = 120.0,
    [20] = 150.0,
    [21] = 0.0,
}

Config.LoadFuelOnVehicleEnter = true
Config.SaveFuelEverySeconds = 30
Config.RefuelTickMs = 250
Config.RefuelProgressMsPerLitre = 450
Config.PassiveDemandInterval = 600     -- 10 minutes between demand ticks
Config.PassiveDemandBaseLitres = 25.0  -- gentler drain to avoid constant refill contracts
Config.AllowFuelWithoutStock = false
Config.AllowUnmappedStations = true
Config.UnmappedStationSupportedFuelTypes = { 'regular', 'diesel' }

Config.BlockVehiclePumpUseInRefineryZones = true
Config.RefineryPumpExclusionFallbackRadius = 25.0
Config.PumpExclusionZones = {
    -- { coords = vec3(x, y, z), radius = 10.0 },
}
Config.DefaultStationPriceMultiplier = 1.0
Config.DefaultStationEmergencyRefill = true
Config.MaxRefuelLitresPerTick = 0.75
Config.RefuelDistance = 3.5
Config.RefuelCancelKey = 202 -- BACKSPACE
Config.PumpSearchRadius = 2.5
Config.PumpVehicleSearchRadius = 5.0
Config.PlayerVehicleRefuelRange = 5.0
Config.NozzleMaxDistance = 12.0
Config.RequirePlayerOutsideVehicleForPump = true
Config.ShutOffEngineDuringRefuel = true

Config.NotificationsEnabled = true
Config.NotifyTitle = 'Fuel'


Config.Nozzles = {
    Vehicle = {
        model = 'prop_cs_fuel_nozle',
    },
    Industrial = {
        model = 'prop_hose_nozzle',
    }
}

-- Legacy fallback kept for compatibility with older code paths.
Config.NozzlePropModel = Config.Nozzles.Vehicle.model
Config.NozzleCarryAnim = {
    dict = 'timetable@gardener@filling_can',
    clip = 'gar_ig_5_filling_can',
    flag = 49,
}
Config.NozzlePropBone = 57005
Config.NozzlePropOffset = {
    x = 0.13,
    y = 0.03,
    z = -0.02,
    rx = -85.0,
    ry = 0.0,
    rz = -20.0,
}
Config.NozzleRope = {
    enabled = true,
    type = 4,
    length = 4.8,
    minLength = 0.25,
    lengthChangeRate = 0.0,
    timeMultiplier = 1.0,
    breakable = false,
    pumpOffset = { x = 0.0, y = 0.0, z = 1.25 },
}



Config.IndustrialNozzle = {
    model = 'prop_hose_nozzle',
    bone = 57005,
    offset = {
        x = 0.13,
        y = 0.03,
        z = -0.02,
        rx = -85.0,
        ry = 0.0,
        rz = -20.0,
    },
    rope = {
        enabled = true,
        type = 4,
        length = 7.5,
        minLength = 0.25,
        lengthChangeRate = 0.0,
        timeMultiplier = 1.0,
        breakable = false,
        anchorOffset = { x = 0.0, y = 0.0, z = 1.15 },
    },
}

Config.UnloadProps = {
    Enabled = true,
    Props = {
        { model = 'prop_gas_tank_02a', offset = vec3(0.0, 0.0, -0.5) },
        { model = 'prop_barrier_work05', offset = vec3(2.0, 0.0, -0.5) },
        { model = 'prop_barrier_work05', offset = vec3(-2.0, 0.0, -0.5) },
    },
}

Config.Tanker = {
    Roles = {
        crude = {
            models = { 'tanker2' },
            maxLitres = 12000.0,
            label = 'Crude Tanker',
        },
        refined = {
            models = { 'tanker' },
            maxLitres = 12000.0,
            label = 'Fuel Tanker',
        },
    },
    SupportedModels = { 'tanker', 'tanker2' },
    DefaultMaxLitres = 12000.0,
    SearchRadius = 18.0,
    HoseMaxDistance = 15.0,
    ValveOpenSeconds = 120,
    CrudeLoadStepSeconds = 10,
    RefineStepSeconds = 12,
    FuelLoadStepSeconds = 12,
    FuelUnloadStepSeconds = 12,
}

Config.VehicleFuelRules = {
    Default = { 'regular' },
    ClassBlacklist = {
        [13] = { 'regular', 'diesel', 'jetfuel' }, -- cycles
        [21] = { 'regular', 'diesel', 'jetfuel' }, -- trains
    },
    ModelBlacklist = {},
    ClassDefaults = {
        [0] = { 'regular' },  -- compacts
        [1] = { 'regular' },  -- sedans
        [2] = { 'regular' },  -- SUVs
        [3] = { 'regular' },  -- coupes
        [4] = { 'regular' },  -- muscle
        [5] = { 'regular' },  -- sports classics
        [6] = { 'regular' },  -- sports
        [7] = { 'regular' },  -- super
        [8] = { 'regular' },  -- motorcycles
        [9] = { 'regular' },  -- off-road
        [10] = { 'diesel' },  -- industrial
        [11] = { 'diesel' },  -- utility
        [12] = { 'regular' }, -- vans
        [13] = {},            -- cycles
        [14] = { 'diesel' },  -- boats
        [15] = { 'jetfuel' }, -- helicopters
        [16] = { 'jetfuel' }, -- planes
        [17] = { 'diesel' },  -- service
        [18] = { 'regular' }, -- emergency
        [19] = { 'diesel' },  -- military
        [20] = { 'diesel' },  -- commercial
        [21] = {},            -- trains
    },
    ModelOverrides = {
        -- diesel road fleet overrides
        benson = { 'diesel' },
        boxville = { 'diesel' },
        bus = { 'diesel' },
        coach = { 'diesel' },
        docktug = { 'diesel' },
        hauler = { 'diesel' },
        mule = { 'diesel' },
        packer = { 'diesel' },
        phantom = { 'diesel' },
        phantom3 = { 'diesel' },
        pounder = { 'diesel' },
        ripley = { 'diesel' },
        rumpo = { 'diesel' },
        stockade = { 'diesel' },
        tanker = { 'diesel' },
        tanker2 = { 'diesel' },
        tiptruck = { 'diesel' },
        tiptruck2 = { 'diesel' },
        trash = { 'diesel' },
        trash2 = { 'diesel' },
        vetir = { 'diesel' },

        -- aviation
        annihilator = { 'jetfuel' },
        frogger = { 'jetfuel' },
        havok = { 'jetfuel' },
        luxor = { 'jetfuel' },
        maverick = { 'jetfuel' },
        shamal = { 'jetfuel' },
        swift = { 'jetfuel' },
        volatus = { 'jetfuel' },
    }
}

Config.Features = {
    FuelUsage = true,
    JerryCan = true,
    StationStock = true,
    PassiveDemand = true,
    Refinery = true,
    TankerJobs = true,
    JetFuel = true,
    MotorOil = true,
    DynamicPricing = true,
    EmergencyAutoRefill = true,
}

Config.Usage = {
    BaseDrainMultiplier = 0.85,      -- slightly reduced global drain for smoother economy
    EngineOnOnly = true,
    DrainByRPM = true,
    IdleDrainPerSecond = 0.003,      -- reduced idle drain to not punish standing still
    ClassMultipliers = {
        [0] = 0.85,   -- compacts: most efficient road vehicle
        [1] = 0.95,   -- sedans: slightly below average
        [2] = 1.10,   -- SUVs: heavier, more consumption
        [3] = 1.00,   -- coupes: average
        [4] = 1.20,   -- muscle: big engines, more fuel
        [5] = 1.10,   -- sports classics: older, less efficient
        [6] = 1.25,   -- sports: high performance
        [7] = 1.50,   -- super: highest road drain
        [8] = 0.45,   -- motorcycles: very efficient
        [9] = 1.15,   -- off-road: moderate
        [10] = 1.30,  -- industrial: heavy diesel
        [11] = 1.10,  -- utility: moderate
        [12] = 1.00,  -- vans: average
        [13] = 0.0,   -- cycles: no fuel
        [14] = 1.80,  -- boats: high consumption
        [15] = 2.50,  -- helicopters: aviation drain
        [16] = 3.00,  -- planes: highest drain
        [17] = 1.80,  -- service: above average
        [18] = 1.30,  -- emergency: moderate-high
        [19] = 1.50,  -- military: heavy
        [20] = 1.15,  -- commercial: efficient diesel
        [21] = 0.0,   -- trains: no fuel
    }
}

Config.RefineryRecipes = {
    crude_basic = {
        input = { crude = 100.0 },
        output = {
            regular = 48.0,   -- ~5% processing loss for realism
            diesel = 18.0,
            jetfuel = 14.0,
            motoroil = 8.0,   -- total output: 88L from 100L crude
        },
        processTime = 240,    -- 4 minutes per batch
    }
}

Config.Contracts = {
    Enabled = true,
    CrudeHaulEnabled = true,     -- set false to disable crude haul contracts
    ExpirySeconds = 1800,
    GenerationIntervalSeconds = 120,
    CrudeMinContracts = 1,
    DefaultCrudeLitres = 8000.0,
    MaxActivePerPlayer = 1,
    MaxPerStation = 2,
    AutoRefillThreshold = 0.10,  -- auto-create contracts when station fuel drops below 10%

    UrgencyMultipliers = {
        normal = 1.0,
        high = 1.15,
        critical = 1.30,
    },

    Payout = {
        crude = {
            base = 750,         -- crude hauls are simpler runs
            perLitre = 0.25,    -- incentivize full loads
        },
        refined = {
            base = 1000,        -- refined delivery is more involved
            perLitre = 0.40,    -- higher per-litre for precision delivery
        }
    },

    NPCs = {
        {
            label = 'Fuel Dispatch',
            coords = vec4(1684.5, -1665.0, 110.44, 215.0),
            model = 's_m_y_dockwork_01',
            spawnPoint = vec4(1680.0, -1660.0, 110.44, 215.0),
        },
        {
            label = 'Fuel Dispatch',
            coords = vec4(-714.0, -909.0, 19.22, 90.0),
            model = 's_m_y_dockwork_01',
            spawnPoint = vec4(-718.0, -912.0, 19.22, 90.0),
        },
    },
}

Config.Items = {
    JerryCanFilled = 'jerry_can_fuel',
    JerryCanEmpty = 'jerry_can_empty',
    MotorOilBottle = 'motoroil_bottle',
    MotorOilDrum = 'motoroil_drum',
}

Config.Ownership = {
    Enabled = true,
    UseNonstopBanking = true,   -- revenue goes to nonstop-banking business account
    OwnerRevenueCut = 0.70,
    MaxPriceMultiplier = 2.0,
    MinPriceMultiplier = 0.5,
    PedModel = 'mp_m_shopkeep_01',
    -- TODO: Set exact ped position in-game. Use /fuel_pedcoords to get your vec4.
    PedCoords = vec4(198.34, -936.28, 29.69, 143.82),
    PedBlipSprite = 374,
    PedBlipColour = 46,
    StationPrices = {
        ltd_little_seoul = 150000,
        ltd_davis = 120000,
        ltd_strawberry = 140000,
        ltd_mirror_park = 130000,
        ltd_east_vinewood = 145000,
        ron_little_seoul = 135000,
        ron_del_perro = 160000,
        ron_paleto = 80000,
        ron_sandy_shores = 75000,
        ron_harmony = 70000,
        ron_catfish_view = 72000,
        globe_downtown = 175000,
        globe_tataviam = 95000,
        xero_la_mesa = 140000,
        xero_murrieta_heights = 130000,
        flywheels_vinewood = 85000,
        gas_route68 = 70000,
        gas_grapeseed = 65000,
        gas_richman_glen = 110000,
        gas_chumash = 90000,
        airport_aviation = 250000,
        sandy_airfield = 120000,
    },
    RefineryPrices = {},
}

Config.MotorOil = {
    BottleLitres = 2.0,
    DrumLitres = 20.0,
    BottleTimeSeconds = 5,
    DrumTimeSeconds = 12,
}

Config.OilShops = {
    bennys_burton = {
        label = "Benny's Original Motorworks",
        coords = vec3(-205.0, -1312.0, 31.0),
        unloadPoints = { vec3(-213.0, -1320.0, 31.0) },
        tank = { current = 50.0, max = 500.0 },
    },
    lsc_burton = {
        label = 'Los Santos Customs',
        coords = vec3(-337.0, -137.0, 39.0),
        unloadPoints = { vec3(-330.0, -140.0, 39.0) },
        tank = { current = 30.0, max = 400.0 },
    },
}

Config.JobVehicles = {
    crude = { truck = 'hauler', trailer = 'tanker2' },
    refined = { truck = 'hauler', trailer = 'tanker' },
}

Config.Rentals = {
    Enabled = true,
    Locations = {
        {
            label = 'Vehicle Rental',
            coords = vec4(1642.0, -1680.0, 111.48, 45.0),
            spawnPoint = vec4(1638.0, -1675.0, 111.48, 45.0),
            model = 's_m_y_construct_01',
        },
    },
    Vehicles = {
        { id = 'hauler', label = 'Hauler (Truck Cab)', price = 500, model = 'hauler' },
        { id = 'tanker_crude', label = 'Crude Tanker Trailer', price = 1000, model = 'tanker2' },
        { id = 'tanker_refined', label = 'Fuel Tanker Trailer', price = 1000, model = 'tanker' },
        { id = 'hauler_crude', label = 'Hauler + Crude Tanker', price = 1400, truck = 'hauler', trailer = 'tanker2' },
        { id = 'hauler_refined', label = 'Hauler + Fuel Tanker', price = 1400, truck = 'hauler', trailer = 'tanker' },
    },
    ReturnRefund = 0.5,  -- 50% refund when returning rental
}

Config.Crime = {
    Enabled = true,
    SiphonEnabled = true,
    SiphonTimeSeconds = 30,
    SiphonLitresPerCan = 10.0,
    PoliceAlert = true,
    Dispatch = 'ps-dispatch',    -- 'ps-dispatch' or 'custom'
    DispatchEvent = nil,         -- only used when Dispatch = 'custom'
    BlackMarketDropoffs = {
        { label = 'Docks Buyer', coords = vec3(1250.0, -3200.0, 5.5), radius = 4.0 },
    },
    BlackMarketPayPerLitre = 0.30,
}

Config.Notifications = {
    RefuelBlockedNoStock = 'This station is out of stock for that fuel type.',
    RefuelBlockedWrongFuel = 'That fuel type is not supported here.',
    RefuelBlockedAircraft = 'Aircraft must use jet fuel.',
    RefuelBlockedNoVehicle = 'No vehicle is close enough to the pump.',
    RefuelBlockedInsideVehicle = 'Get out of the vehicle to use the pump.',
    RefuelBlockedVehicleTooFar = 'Move the vehicle closer to the pump.',
    RefuelBlockedIncompatibleVehicle = 'This vehicle cannot be fuelled here.',
    RefuelCancelled = 'Refuelling cancelled.',
    NozzleGrabbed = 'Nozzle grabbed. Target the vehicle to refuel it.',
    NozzleReturned = 'Nozzle returned.',
    NozzleTooFar = 'You moved too far away from the pump.',
    RefuelStarted = 'Refuelling started.',
    RefuelComplete = 'Refuelling complete.',
    NotEnoughMoney = 'Not enough money.',

    IndustrialHoseGrabbed = 'Hose grabbed. Move to the tanker and start transfer.',
    IndustrialHoseReturned = 'Hose returned.',
    IndustrialTooFar = 'You moved too far from the hose anchor.',
    NoTankerNearby = 'No supported tanker is nearby.',
    TankerWrongProduct = 'That tanker is carrying the wrong product.',
    TankerWrongRoleCrude = 'You need a crude tanker trailer here (tanker2).',
    TankerWrongRoleRefined = 'You need a refined fuel tanker trailer here (tanker).',
    TankerFull = 'That tanker is already full.',
    TankerLoaded = 'Tanker loaded.',
    TankerUnloaded = 'Tanker unloaded.',
    ValveOpened = 'Valve opened. Start refining while the line is primed.',
}


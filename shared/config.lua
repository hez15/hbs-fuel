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
Config.PassiveDemandInterval = 900
Config.PassiveDemandBaseLitres = 35.0
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

Config.NotificationsEnabled = false
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
    SearchRadius = 12.0,
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
    BaseDrainMultiplier = 1.0,
    EngineOnOnly = true,
    DrainByRPM = true,
    IdleDrainPerSecond = 0.005,
    ClassMultipliers = {
        [0] = 0.90,
        [1] = 1.00,
        [2] = 1.10,
        [3] = 1.05,
        [4] = 1.25,
        [5] = 1.15,
        [6] = 1.30,
        [7] = 1.60,
        [8] = 0.55,
        [9] = 1.10,
        [10] = 1.25,
        [11] = 1.15,
        [12] = 1.05,
        [13] = 0.0,
        [14] = 0.0,
        [15] = 2.80,
        [16] = 3.50,
        [17] = 2.00,
        [18] = 1.40,
        [19] = 1.60,
        [20] = 1.20,
        [21] = 0.0,
    }
}

Config.RefineryRecipes = {
    crude_basic = {
        input = { crude = 100.0 },
        output = {
            regular = 55.0,
            diesel = 20.0,
            jetfuel = 15.0,
            motoroil = 10.0,
        },
        processTime = 300,
    }
}

Config.Contracts = {
    Enabled = true,
    ExpirySeconds = 1800,
    GenerationIntervalSeconds = 120,
    CrudeMinContracts = 1,
    DefaultCrudeLitres = 8000.0,
    MaxActivePerPlayer = 1,
    MaxPerStation = 2,

    UrgencyMultipliers = {
        normal = 1.0,
        high = 1.15,
        critical = 1.30,
    },

    Payout = {
        crude = {
            base = 900,
            perLitre = 0.20,
        },
        refined = {
            base = 1200,
            perLitre = 0.35,
        }
    }
}

Config.Items = {
    JerryCanFilled = 'jerry_can_fuel',
    JerryCanEmpty = 'jerry_can_empty',
    MotorOilBottle = 'motoroil_bottle',
    MotorOilDrum = 'motoroil_drum',
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


# hbs-fuel v0.7.0

QBX + ox_inventory fuel system with full industrial supply chain, contract jobs, ownership, and crime.

## Features

- **Vehicle fuel** — litres-based tank system, fuel drain while driving, saved by plate
- **Public pumps** — ox_target refuelling with nozzle prop, rope sync, cash/bank payment
- **Station stock** — passive demand drain, dynamic pricing, emergency refill fallback
- **Refinery** — crude intake, batch processing (100L crude → 48L regular, 18L diesel, 14L jetfuel, 8L motor oil), valve + batch flow
- **Tanker roles** — `tanker2` = crude, `tanker` = refined products (including motor oil)
- **Motor oil** — bottling at refinery into bottles (2L) / drums (20L) with animation, tanker delivery to mechanic shops
- **Mechanic shops** — Benny's and LS Customs receive motor oil deliveries, auto-generate contracts when stock is low
- **Contracts** — NUI job board with urgency tiers, auto-generated station/crude/oil shop refill contracts, waypoints, progress tracking, payouts
- **NPC dispatch** — dock worker NPCs at configurable locations open the contracts board and spawn job vehicles
- **Job vehicles** — hauler + tanker trailer spawns on contract accept, blip on map, cleaned up on complete/cancel
- **Ownership** — purchase stations, owner dashboard with revenue tracking, price adjustment, fuel ordering
- **Crime** — siphon fuel from tankers, sell stolen fuel at black market drop-offs, police dispatch alerts
- **Admin tools** — `fueladmin` command suite for inspecting/modifying state

## Install

1. Place the folder in your resources (e.g. `resources/[hbs]/hbs-fuel`)
2. Make sure these resources start before `hbs-fuel`:
   - `ox_lib`
   - `oxmysql`
   - `ox_inventory`
   - `ox_target`
   - `qbx_core`
3. Add `ensure hbs-fuel` to your server config
4. All database tables are created automatically on first start — no manual SQL import needed
5. Register motor oil items in ox_inventory (see below)
6. Set up ACE permissions (see below)

## ox_inventory Items

These items must be registered in your ox_inventory items config for motor oil bottling and siphoning:

| Item Name | Label | Weight | Stack |
|-----------|-------|--------|-------|
| `motoroil_bottle` | Motor Oil Bottle | 200 | 20 |
| `motoroil_drum` | Motor Oil Drum | 2000 | 5 |
| `jerry_can_fuel` | Jerry Can (Fuel) | 1000 | 5 |
| `jerry_can_empty` | Jerry Can (Empty) | 500 | 10 |

## ACE Permissions

hbs-fuel uses two ACE permissions to gate sensitive features:

### `hbs-fuel.admin`
**What it does:** Grants access to the `fueladmin` server command which can add fuel to stations, add crude to refineries, fill tankers, and inspect server state. Without this permission, the command is blocked.

**Why it's needed:** These commands bypass normal gameplay — they create fuel out of thin air. Restricting them to admins prevents players from exploiting the economy.

```cfg
add_ace group.admin hbs-fuel.admin allow
```

### `hbs-fuel.police`
**What it does:** Players with this permission receive dispatch alerts when someone siphons fuel from a tanker or sells stolen fuel at a black market drop-off.

**Why it's needed:** The crime system needs a way to notify law enforcement without broadcasting to all players. Only players in your police role should see these alerts. If you use a custom MDT/dispatch system, set `Config.Crime.DispatchEvent` to your event name instead.

```cfg
add_ace group.police hbs-fuel.police allow
```

If you don't use ACE groups, you can also assign directly:
```cfg
add_principal identifier.license:abc123 group.admin
```

## Config Overview

| Section | File | Purpose |
|---------|------|---------|
| `Config.Tanker` | `shared/config.lua` | Tanker roles, search radius, timings |
| `Config.Contracts` | `shared/config.lua` | Contract generation, payouts, NPCs, auto-refill threshold |
| `Config.Ownership` | `shared/config.lua` | Station purchase prices, revenue cut, price range |
| `Config.MotorOil` | `shared/config.lua` | Bottle/drum litres and bottling timings |
| `Config.OilShops` | `shared/config.lua` | Mechanic shop locations and tank sizes |
| `Config.JobVehicles` | `shared/config.lua` | Truck + trailer models per contract type |
| `Config.Crime` | `shared/config.lua` | Siphon timing, black market locations, pay rate, police alerts |
| `Stations` | `shared/stations.lua` | Station definitions, coords, stock, supported fuel types |
| `Refineries` | `shared/refineries.lua` | Refinery layout, interaction points, storage |
| `FuelTypes` | `shared/fueltypes.lua` | Fuel type definitions, prices, flags |

### Key toggles

```lua
Config.Features.MotorOil = true           -- enable/disable motor oil bottling
Config.Contracts.Enabled = true           -- enable/disable contract system
Config.Contracts.CrudeHaulEnabled = true  -- enable/disable crude haul contracts
Config.Contracts.AutoRefillThreshold = 0.10  -- auto-create contracts below 10%
Config.Ownership.Enabled = true           -- enable/disable station ownership
Config.Crime.Enabled = true               -- enable/disable crime system
Config.Crime.SiphonEnabled = true         -- enable/disable fuel siphoning
Config.Crime.PoliceAlert = true           -- enable/disable police dispatch
Config.NotificationsEnabled = true        -- enable/disable all notifications
```

## Admin Commands

All gated behind `hbs-fuel.admin` ACE permission.

| Command | Description |
|---------|-------------|
| `fueladmin addstock <stationId> <fuelType> [litres]` | Add fuel to a station tank |
| `fueladmin addcrude <refineryId> [litres]` | Add crude oil to a refinery |
| `fueladmin filltanker <plate> <fuelType> [litres]` | Fill a tanker by plate |
| `fueladmin refinery <refineryId>` | Inspect refinery crude + product levels |
| `fueladmin station <stationId>` | Inspect station fuel stock levels |

## Player Commands

| Command | Description |
|---------|-------------|
| `/fuelcontracts` | Open the fuel contracts job board |
| `/fuelproperties` | View your owned fuel properties |

## File Map

| File | Purpose |
|------|---------|
| `shared/config.lua` | All configuration and toggles |
| `shared/stations.lua` | Station definitions and stock |
| `shared/refineries.lua` | Refinery layout and storage |
| `shared/fueltypes.lua` | Fuel type definitions |
| `client/pumps.lua` | Public pump nozzle flow |
| `client/industrial.lua` | Refinery, tanker, oil shop hose flow + bottling + NPC spawning |
| `client/contracts.lua` | Contract events + job vehicle spawning |
| `client/nui.lua` | NUI panels (refuel, dashboard, contracts, refinery stock) |
| `client/crime.lua` | Siphoning and black market targets |
| `client/ownership.lua` | Ownership purchase and dashboard UI |
| `server/stations.lua` | Station pricing and stock logic |
| `server/refinery.lua` | Refinery batch processing + motor oil bottling |
| `server/contracts.lua` | Contract generation, acceptance, completion |
| `server/oilshops.lua` | Mechanic shop state and unload logic |
| `server/crime.lua` | Siphon handler, black market sales, police dispatch |
| `server/ownership.lua` | Ownership backend and revenue tracking |
| `server/persistence.lua` | DB table creation and state persistence |
| `server/payments.lua` | Money add/remove/check helpers |
| `server/main.lua` | Nozzle sync, jerry can handler, admin commands |

## Notes

- All 8 database tables auto-create on resource start (no manual SQL import needed)
- Nozzle and hose props are network-synced so other players see them
- Fuel is stored internally in litres; native fuel level is the visible gameplay representation
- Refinery has ~12% processing loss (100L crude → 88L products) for economic realism
- Contracts auto-generate for stations below 10% stock and for crude haul minimums
- Motor oil is a refinery byproduct — produced passively during crude batches
- Crime alerts use ACE permissions by default, or can fire a custom event via `Config.Crime.DispatchEvent` for MDT integration

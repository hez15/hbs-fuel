# hbs-fuel v0.4.0

Starter resource for a **QBX + ox_inventory** fuel system that replaces basic fuel usage and lays the groundwork for:

- vehicle fuel drain
- pump refuelling
- jerry cans
- station stock
- refinery stock
- tanker loads
- future delivery contracts

## Included right now

### Working first pass
- fuel drain while driving
- per-vehicle tank capacities
- fuel saved by plate to database
- ox_target pump nozzle flow (grab nozzle -> target vehicle -> refuel)
- station stock preview + per-tick sale logic
- emergency refill fallback toggle
- passive demand drain on stations
- refinery state + batch processing exports
- tanker state persistence export
- basic admin commands

### Scaffolding only for now
- full tanker gameplay loop
- contract board UI
- crude hauling gameplay
- station owner logic
- proper nozzle / rope / prop system
- nozzle prop / rope visuals
- motor oil packaging flow
- jet fuel airport job loop

## Install

1. Put the folder in your resources, for example:
   `resources/[hbs]/hbs-fuel`
2. Import `sql/hbs-fuel.sql`
3. Ensure these resources are started before `hbs-fuel`:
   - ox_lib
   - oxmysql
   - ox_inventory
   - ox_target
   - qbx_core
4. Add `ensure hbs-fuel` to your server cfg.

## Key config files

- `shared/config.lua` - feature toggles and general settings
- `shared/stations.lua` - station placeholders and stock levels
- `shared/refineries.lua` - refinery storage setup
- `shared/vehicles.lua` - vehicle tank sizes
- `shared/fueltypes.lua` - fuel products and base prices

## Important notes

### 1. Station config is placeholder only
The included stations are example entries. Add all your real stations to `shared/stations.lua`.

### 2. Fuel is stored internally as litres
The GTA native fuel level is only used as the display percentage.

### 3. Jerry can item hookup
The client event already exists:
- `hbs-fuel:client:useJerryCan`

Wire your ox_inventory item to that event in your item definition / item use setup.

Suggested metadata:

```lua
metadata = {
    fuelType = 'regular',
    litres = 15.0
}
```

### 4. Pump refuelling flow
Use ox_target on a pump to grab the nozzle, then target the vehicle to choose fuel type and litres.

### 5. Admin commands
- `/fuel_refill_station [stationId] [fuelType] [litres]`
- `/fuel_toggle_stock`

## Exports

### Client
- `exports['hbs-fuel']:GetVehicleFuel(vehicle)`
- `exports['hbs-fuel']:SetVehicleFuel(vehicle, litres)`
- `exports['hbs-fuel']:AddVehicleFuel(vehicle, litres)`
- `exports['hbs-fuel']:GetTankerVehicleLoad(vehicle)`

### Server
- `exports['hbs-fuel']:GetStationStock(stationId, fuelType)`
- `exports['hbs-fuel']:AddStationStock(stationId, fuelType, litres)`
- `exports['hbs-fuel']:AddCrudeToRefinery(refineryId, litres)`
- `exports['hbs-fuel']:ProcessRefineryBatch(refineryId)`
- `exports['hbs-fuel']:SetTankerLoad(plate, fuelType, litres, maxLitres)`
- `exports['hbs-fuel']:CreateFuelContract(data)`

## Recommended next step

Build phase 2 next:
- proper station list
- tanker load / unload interactions
- refinery loading points
- crude intake jobs
- contract board + payout logic


## v0.4 additions

- Cypress refinery layout using your supplied coords
- Crude source loading point
- Dual crude delivery/unload points
- Separate valve + start batch interactions
- Tanker load point for refined fuel
- Industrial hose/nozzle flow using `prop_hose_nozzle`
- Station tanker unload hose flow
- Vehicle fuel-type rules so road vehicles use regular/diesel and aircraft use jet fuel

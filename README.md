# hbs-fuel v0.5.1

QBX + ox_inventory fuel system with:

- vehicle fuel usage and persistence
- ox_target public pump refuelling
- car nozzle visuals with networked carry prop sync
- refinery hose flow for crude and refined transfers
- station stock and passive demand
- refinery crude and product storage
- motor oil packaging
- tanker role separation

## Current feature status

### Working now
- vehicle fuel drain while driving
- litres-based tank system
- fuel saved by plate
- public pump flow: grab nozzle -> target vehicle -> refuel
- public pump nozzle prop: `prop_cs_fuel_nozle`
- refinery / industrial hose prop: `prop_hose_nozzle`
- networked public nozzle carry prop so nearby players can see it
- cash / bank selection when refuelling
- station stock usage with emergency fallback
- passive demand drain
- crude intake and refinery storage
- refinery runtime state and batch processing
- motor oil bottle / drum packaging
- tanker role split:
  - `tanker2` = crude only
  - `tanker` = refined products only

### Still to build / finish
- full contracts UI / job board
- ownership backend and owner dashboard
- society purchase flow
- fully synced rope visuals
- final balancing pass

## Install

1. Place the folder in your resources, for example:
   `resources/[hbs]/hbs-fuel`
2. Import `sql/hbs-fuel.sql` into your database.
3. Make sure these resources start before `hbs-fuel`:
   - `ox_lib`
   - `oxmysql`
   - `ox_inventory`
   - `ox_target`
   - `qbx_core`
4. Add `ensure hbs-fuel` to your server config.
5. Restart the server or `refresh` then `ensure hbs-fuel`.

## Update steps

When updating from an older version:

1. Replace the resource files.
2. Re-run `sql/hbs-fuel.sql` so missing tables are created.
3. Check `shared/config.lua` for any new settings and merge your custom values back in.
4. Confirm your station / refinery coords still match your setup.

## Important config notes

### Public vs industrial nozzle props
Public car pumps now use:
- `Config.Nozzles.Vehicle.model = 'prop_cs_fuel_nozle'`

Industrial / refinery hose flow uses:
- `Config.Nozzles.Industrial.model = 'prop_hose_nozzle'`
- `Config.IndustrialNozzle.model = 'prop_hose_nozzle'`

### Notifications
Notifications are controlled by:
- `Config.NotificationsEnabled`
- `Config.NotifyTitle`

### Tanker roles
The default tanker role split is:
- `tanker2` = crude
- `tanker` = refined fuel

### Vehicle fuel compatibility
Fuel usage by class / model is configured in:
- `Config.VehicleFuelRules`

### Station stock
Station stock and fallback behaviour are configured in:
- `shared/stations.lua`
- `Config.Features`

## File map

- `shared/config.lua` - general settings and toggles
- `shared/stations.lua` - station definitions and stock
- `shared/refineries.lua` - refinery layout and storage
- `client/pumps.lua` - public pump and nozzle flow
- `client/industrial.lua` - refinery / tanker hose flow
- `server/stations.lua` - station pricing / stock logic
- `server/refinery.lua` - refinery batch logic
- `server/persistence.lua` - DB persistence

## Admin commands

- `/fuel_refill_station [stationId] [fuelType] [litres]`
- `/fuel_toggle_stock`

## Notes

- The public nozzle prop is network-synced enough for other players to see it in-hand.
- Rope visuals are still local and not fully multiplayer-perfect yet.
- Fuel is stored internally in litres; native fuel level is just the visible gameplay representation.


## v0.5.2 quick notes
- Public pump carry prop changed to `prop_cs_fuel_hose`.
- Added stronger nozzle cleanup so returning the nozzle detaches and deletes the local/remote prop more reliably.
- Rope remains a GTA rope effect, not a swappable model prop.

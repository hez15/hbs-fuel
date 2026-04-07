# hbs-fuel v0.6.1

QBX + ox_inventory fuel system with:

- vehicle fuel usage and persistence
- ox_target public pump refuelling
- car nozzle visuals with networked carry prop and rope sync
- refinery hose flow for crude and refined transfers
- station stock and passive demand
- refinery crude and product storage
- motor oil packaging
- tanker role separation
- contract system with job board UI
- station and refinery ownership with purchase flow and owner dashboard

## Current feature status

### Working now
- vehicle fuel drain while driving
- litres-based tank system
- fuel saved by plate
- public pump flow: grab nozzle -> target vehicle -> refuel
- public pump nozzle prop: `prop_cs_fuel_nozle`
- refinery / industrial hose prop: `prop_hose_nozzle`
- networked public nozzle carry prop and rope so nearby players see the hose
- networked industrial hose carry prop and rope for refinery/tanker operations
- cash / bank selection when refuelling
- station stock usage with emergency fallback
- passive demand drain
- crude intake and refinery storage
- refinery runtime state and batch processing
- motor oil bottle / drum packaging
- tanker role split:
  - `tanker2` = crude only
  - `tanker` = refined products only
- contract system:
  - job board UI with urgency color-coding and location names
  - auto-waypoint on contract accept
  - progress HUD during active delivery
  - payout notification on completion
  - refresh and cancel from the board
  - contract board accessible from refinery/station ox_target and `/fuelcontracts` command
- ownership system:
  - purchase unowned stations and refineries
  - owner dashboard with stock levels, revenue tracking, price adjustment
  - revenue withdrawal to bank
  - `/fuelproperties` command to view owned properties
- dynamic pricing based on station stock levels
- balanced fuel drain rates, prices, and contract payouts

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
2. Re-run `sql/hbs-fuel.sql` so missing tables are created (including the new `hbs_fuel_ownership` table).
3. Check `shared/config.lua` for any new settings and merge your custom values back in.
4. Confirm your station / refinery coords still match your setup.
5. Review `Config.Ownership` settings and set station/refinery purchase prices for your economy.

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

### Ownership
Station and refinery ownership is configured in:
- `Config.Ownership`
- Set `Config.Ownership.Enabled = false` to disable the ownership system
- Adjust `StationPrices` and `RefineryPrices` for your server economy
- `OwnerRevenueCut` controls what percentage of fuel sales go to the owner (default 70%)

## File map

- `shared/config.lua` - general settings and toggles
- `shared/stations.lua` - station definitions and stock
- `shared/refineries.lua` - refinery layout and storage
- `client/pumps.lua` - public pump and nozzle flow
- `client/industrial.lua` - refinery / tanker hose flow
- `client/contracts.lua` - contracts job board UI
- `client/ownership.lua` - ownership dashboard and purchase UI
- `server/stations.lua` - station pricing / stock logic
- `server/refinery.lua` - refinery batch logic
- `server/contracts.lua` - contract generation and management
- `server/ownership.lua` - ownership backend and revenue tracking
- `server/payments.lua` - money add/remove/check helpers
- `server/persistence.lua` - DB persistence

## Admin commands

- `/fuel_refill_station [stationId] [fuelType] [litres]`
- `/fuel_toggle_stock`

## Player commands

- `/fuelcontracts` - open the fuel contracts job board
- `/fuelproperties` - view your owned fuel properties

## Notes

- Nozzle and hose props are network-synced so other players can see them.
- Rope visuals are now synced to nearby players for both public pumps and industrial hoses.
- Fuel is stored internally in litres; native fuel level is just the visible gameplay representation.
- Refinery processing has a ~12% loss (100L crude yields 88L of products) for economic realism.

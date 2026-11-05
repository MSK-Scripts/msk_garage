# Graph Report - msk_garage  (2026-10-19)

## Corpus Check
- 89 files · ~72,970 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 594 nodes · 1139 edges · 47 communities (43 shown, 4 thin omitted)
- Extraction: 84% EXTRACTED · 16% INFERRED · 0% AMBIGUOUS · INFERRED: 187 edges (avg confidence: 0.86)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `7bc5533e`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- editors.tsx
- server/vehicles.lua
- App.tsx
- Frontend Dependencies
- System Features and Policies
- admin/api.lua
- client/nui.lua
- registerLocation
- permissions.lua
- TypeScript Configuration
- Vehicle Class Icons
- Vehicle Type Assets
- Utils.T
- customSessions.lua
- Admin Data Store
- Database and Integrations
- Asset Loading Policy
- private.lua
- versionchecker.lua
- CFX_POST.md
- export.lua
- db.lua

## God Nodes (most connected - your core abstractions)
1. `Utils.Log()` - 26 edges
2. `Vehicles.ParkOut()` - 20 edges
3. `Vehicles.ParkOutFromImpound()` - 19 edges
4. `compilerOptions` - 16 edges
5. `Utils.T()` - 15 edges
6. `Vehicles.LoadOwned()` - 12 edges
7. `Translation` - 11 edges
8. `applyTheme()` - 11 edges
9. `AdminApi.BuildBootstrap()` - 10 edges
10. `Private.IsPrivate()` - 10 edges

## Surprising Connections (you probably didn't know these)
- `Zero External Requests at Runtime (bundled fonts and icons)` --semantically_similar_to--> `Per-Model Vehicle Images (nui:// local, offline)`  [INFERRED] [semantically similar]
  web/README.md → CHANGELOG.md
- `jobAllowsBlip()` --calls--> `Utils.JobMatches()`  [INFERRED]
  client/blips.lua → shared/utils.lua
- `NUI.OpenGarage()` --calls--> `Utils.T()`  [INFERRED]
  client/nui.lua → shared/utils.lua
- `vehicleImageUrls()` --calls--> `Utils.Log()`  [INFERRED]
  client/nui.lua → shared/utils.lua
- `Peds.Spawn()` --calls--> `Utils.Log()`  [INFERRED]
  client/peds.lua → shared/utils.lua

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **DB-Authoritative Configuration Flow (seed once, dashboard edits live)** — changelog_db_driven_configuration, changelog_config_split_static, changelog_admin_dashboard, changelog_job_garage_policy, changelog_ui_theme_customisation [EXTRACTED 1.00]
- **Server-Authority Exploit Gates (v4 security pass)** — changelog_server_authority, changelog_custom_session_registration, changelog_plate_spawn_lock, changelog_nickname_sanitization, changelog_group_permission_system, changelog_job_garage_policy [EXTRACTED 1.00]
- **Vehicle Class Icon Family (shared grad1 gradient, potrace paths, square viewBox)** — web_public_images_bicycle_icon, web_public_images_boat_icon, web_public_images_compact_icon, web_public_images_coupe_icon, web_public_images_emergency_icon, web_public_images_helicopter_icon, web_public_images_motorcycle_icon, web_public_images_muscle_icon, web_public_images_offroad_icon [EXTRACTED 1.00]
- **Vehicle class SVG icons sharing the grad1 green gradient style system** — web_public_images_plane_icon, web_public_images_sedan_icon, web_public_images_sport_icon, web_public_images_supersport_icon, web_public_images_suv_icon, web_public_images_trailer_icon, web_public_images_truck_icon, web_public_images_van_icon, web_public_images_plane_msk_green_gradient_token [EXTRACTED 1.00]
- **Vehicle-Key Adapter Contract Participants** — changelog_vehiclekey_adapter_pattern, changelog_keys_removeallkeys, changelog_jobvehiclesdeleted_hook, changelog_second_key_badge, changelog_escrow_open_files [EXTRACTED 1.00]
- **Land Vehicle Class Icons (garage `land` category)** — web_public_images_compact_icon, web_public_images_coupe_icon, web_public_images_muscle_icon, web_public_images_offroad_icon, web_public_images_emergency_icon, web_public_images_motorcycle_icon, web_public_images_bicycle_icon [INFERRED 0.85]

## Communities (47 total, 4 thin omitted)

### Community 0 - "editors.tsx"
Cohesion: 0.05
Nodes (81): AdminApp(), TabId, BlipEditor(), FeeEditor(), JobsEditor(), MarkerEditor(), PedEditor(), Text3dEditor() (+73 more)

### Community 1 - "server/vehicles.lua"
Cohesion: 0.06
Nodes (67): getVehicleClassName(), CustomSessions.GetImpound(), appendKeyedVehicles(), buildQuery(), Garages.ForGarage(), Garages.ForImpound(), Garages.GetNameFav(), Garages.IsOwnedByPlayer() (+59 more)

### Community 2 - "App.tsx"
Cohesion: 0.07
Nodes (42): App(), AccessDialog(), AccessDialogProps, EmptyState(), FuelBar(), Header(), HeaderProps, Loader() (+34 more)

### Community 3 - "Frontend Dependencies"
Cohesion: 0.05
Nodes (36): autoprefixer, @fontsource/open-sans, @fontsource/work-sans, lucide-react, postcss, react, react-dom, tailwindcss (+28 more)

### Community 4 - "System Features and Policies"
Cohesion: 0.07
Nodes (34): In-Game Admin Dashboard (/garageadmin), AdvancedParking Export Bridge (GetVehiclePositions / GetVehiclePosition), AdvancedParking vehicles_parking Table Lookup (removed), Config Split: settings.lua (DB-managed) vs static.lua (code hooks), Server-Side Custom Garage/Impound Sessions (forge protection), Database-Driven Configuration (DB is authoritative, config seeds once), Escrow Boundary (open: config, locales, shared, handlers, keys), Faction Filter in the Garage List (+26 more)

### Community 5 - "admin/api.lua"
Cohesion: 0.15
Nodes (22): AdminApi.BuildBootstrap(), AdminApi.GaragesArray(), AdminApi.GroupsArray(), AdminApi.ImpoundsArray(), AdminApi.JobsList(), AdminApi.SanitizeGarage(), AdminApi.SanitizeImpound(), AdminApi.SanitizeSettings() (+14 more)

### Community 6 - "client/nui.lua"
Cohesion: 0.10
Nodes (28): focusOff(), focusOn(), NUI.AddVehicle(), NUI.Close(), NUI.OpenGarage(), NUI.OpenImpound(), NUI.Refresh(), openGarage() (+20 more)

### Community 7 - "registerLocation"
Cohesion: 0.12
Nodes (18): applyDefs(), add(), Blips.Refresh(), jobAllowsBlip(), bootstrap(), loadModel(), Peds.Farewell(), Peds.Greet() (+10 more)

### Community 8 - "permissions.lua"
Cohesion: 0.11
Nodes (22): Config.GetDefaultGarage(), AdminCommand.Register(), AdminPerms.CanOpen(), AdminPerms.EnsureAce(), AdminPerms.EnsureAces(), AdminPerms.GetFrameworkGroup(), AdminPerms.GetLuxuGroup(), AdminPerms.GetPlayerPerms() (+14 more)

### Community 9 - "TypeScript Configuration"
Cohesion: 0.09
Nodes (21): DOM, DOM.Iterable, ES2020, src, compilerOptions, allowImportingTsExtensions, isolatedModules, jsx (+13 more)

### Community 10 - "Vehicle Class Icons"
Cohesion: 0.42
Nodes (12): Bicycle Vehicle-Class Icon, MSK Green Gradient Fill (grad1), Potrace Silhouette Icon Convention, Vehicle Class Icon Set, Boat Vehicle-Class Icon, Compact Vehicle-Class Icon, Coupe Vehicle-Class Icon, Emergency Vehicle-Class Icon (+4 more)

### Community 11 - "Vehicle Type Assets"
Cohesion: 0.42
Nodes (10): Plane Vehicle Class Icon (plane.svg), MSK Green Gradient Fill Token (grad1), Vehicle Class Icon Set (Garage NUI), Sedan Vehicle Class Icon (sedan.svg), Sport Vehicle Class Icon (sport.svg), Supersport Vehicle Class Icon (supersport.svg), SUV Vehicle Class Icon (suv.svg), Trailer Vehicle Class Icon (trailer.svg) (+2 more)

### Community 12 - "Utils.T"
Cohesion: 0.24
Nodes (16): apLookupFailed(), apPositions(), Impound.AdvancedParkedPlates(), Impound.ChargeFee(), Impound.ChecksAdvancedParking(), Impound.IsAdvancedParked(), identifierFromServerId(), listAccess() (+8 more)

### Community 13 - "customSessions.lua"
Cohesion: 0.43
Nodes (5): alive(), CustomSessions.GetGarage(), CustomSessions.RegisterGarage(), CustomSessions.RegisterImpound(), touch()

### Community 14 - "Admin Data Store"
Cohesion: 0.61
Nodes (7): AdminStore.LoadAll(), AdminStore.LoadGarages(), AdminStore.LoadImpounds(), AdminStore.LoadPermissions(), AdminStore.LoadSettings(), isEnabled(), jdecode()

### Community 15 - "Database and Integrations"
Cohesion: 0.67
Nodes (3): msk_fuel Integration (real tank volume in liters), owned_vehicles Auto-Migration (TINYINT to SMALLINT, garage column), oxmysql Named-Placeholder DDL Fix

### Community 34 - "private.lua"
Cohesion: 0.12
Nodes (30): AdminApi.Broadcast(), AdminApi.ClientSettingsPayload(), AdminApi.PublicGarages(), AdminApi.PushTo(), ownedGarage(), current(), Housing.AdapterNames(), Housing.GetMembers() (+22 more)

### Community 43 - "CFX_POST.md"
Cohesion: 0.29
Nodes (6): :clipboard: Requirements, Free, My other Scripts, Paid, :sparkles: What it does, :star2: The new in-game admin dashboard

## Knowledge Gaps
- **82 isolated node(s):** `name`, `private`, `version`, `type`, `dev` (+77 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Utils.Log()` connect `server/vehicles.lua` to `private.lua`, `client/nui.lua`, `registerLocation`?**
  _High betweenness centrality (0.069) - this node is a cross-community bridge._
- **Why does `Utils.T()` connect `Utils.T` to `server/vehicles.lua`, `client/nui.lua`?**
  _High betweenness centrality (0.051) - this node is a cross-community bridge._
- **Why does `Validation.RequireGarageAccess()` connect `server/vehicles.lua` to `private.lua`, `Utils.T`?**
  _High betweenness centrality (0.041) - this node is a cross-community bridge._
- **Are the 24 inferred relationships involving `Utils.Log()` (e.g. with `vehicleImageUrls()` and `Peds.Remove()`) actually correct?**
  _`Utils.Log()` has 24 INFERRED edges - model-reasoned connections that need verification._
- **Are the 8 inferred relationships involving `Vehicles.ParkOut()` (e.g. with `Garages.JobAllowedAtPublicGarage()` and `Validation.AcquirePlateLock()`) actually correct?**
  _`Vehicles.ParkOut()` has 8 INFERRED edges - model-reasoned connections that need verification._
- **Are the 8 inferred relationships involving `Vehicles.ParkOutFromImpound()` (e.g. with `Impound.ChargeFee()` and `Impound.IsAdvancedParked()`) actually correct?**
  _`Vehicles.ParkOutFromImpound()` has 8 INFERRED edges - model-reasoned connections that need verification._
- **Are the 14 inferred relationships involving `Utils.T()` (e.g. with `NUI.OpenGarage()` and `startHotkeyTick()`) actually correct?**
  _`Utils.T()` has 14 INFERRED edges - model-reasoned connections that need verification._
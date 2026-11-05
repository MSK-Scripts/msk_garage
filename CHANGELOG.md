# Changelog — msk_garage

All notable changes to this script are documented here.

---

## [5.7.0] - 2026-10-19 - Tuning Protection, Client Spawn Mode and CDN Images

### Fixed

- **Vehicles lost their tuning when a slow PC parked them in again.** After a park-out the client writes the saved tuning onto the car. On a slow PC, or when another player holds the entity, that write could fail for good after about one second. The player then drove a stock car, and the next park-in stored the stock state over the real tuning. Two changes close this:
  - The client keeps re-applying the tuning for up to 30 seconds and tells the server once it really sits on the car. *(client/vehicles.lua)*
  - As long as that confirmation is missing, park-in keeps the tuning from the database and only takes the condition (damage, dirt, plate) from the car. The tuning is read from the row at park-in time, so a mechanic script that wrote new tuning in between is not undone. *(server/vehicles.lua, server/api.lua)*
- **A failed park-out from the impound moved the car into the garage.** The rollback set `stored = 1` for impound vehicles too, so the car left the impound with the fee refunded. Anyone could trigger this by calling `msk_garage:rollbackSpawn` directly. The car stays in the impound now, only the fee is refunded. *(server/vehicles.lua)*
- **A saved mod the model does not offer kept the tuning check failing**, for example after an addon car was updated. Such a slot is skipped now. *(client/vehicles.lua)*

### Added

- **`Config.spawnMode = 'server' | 'client'`.** `'server'` (default) spawns with `CreateVehicleServerSetter` as before. `'client'` lets the player's client create the car, so it owns it from the first frame and the tuning lands at once. The server reserves the spawn and checks the reported car before the park-out counts: it must be a vehicle owned by that player, the model must match the database and it must stand within 10 m of the reserved spot. A car that fails is deleted and the park-out rolled back. The DB plate is forced onto the car and the entity is kept in the world when the player disconnects. Selectable in the dashboard under Settings. `'client'` does not work with `sv_entityLockdown strict`. *(config/settings.lua, server/vehicles.lua, server/api.lua, server/admin/api.lua, shared/admin_perms.lua, client/vehicles.lua, web/)*
- **Vehicle images from JG Vehicle Studio or a CDN.** `Config.GetVehicleImage(model, hash)` in `config/static.lua` returns the image URLs for a model. By default it uses `jg-vehiclestudio` automatically while it runs (`getImage` plus its fallbacks), then `Config.VehicleImageCdn`. The default CDN is `https://cdn.msk-scripts.de/vehicles/{model}.png`, tokens are `{model}`, `{MODEL}` and `{hash}`. The UI tries these URLs first, then the local `vehicle_images/` folder, then the class icon. The dashboard switch Settings → Vehicle Images still has to be on. *(config/static.lua, client/nui.lua, web/, vehicle_images/A_README.md)*

### Update notes

The NUI changed, so replace the `html/` folder together with the rest of the resource files, then restart it. No database change.

If you keep your own config files, add `Config.spawnMode` to `config/settings.lua` and the new image block (`Config.VehicleImageCdn`, `Config.GetVehicleImage`) to `config/static.lua`. Without them the server spawn stays active and no CDN images are loaded. On an existing install `spawnMode` is not in the database yet, so the value from `config/settings.lua` applies until you save it in the dashboard.

### Changed files

```text
fxmanifest.lua
client/nui.lua
client/vehicles.lua
config/settings.lua
config/static.lua
server/admin/api.lua
server/api.lua
server/vehicles.lua
shared/admin_perms.lua
vehicle_images/A_README.md
html/**   (rebuilt)
```

---

## [5.6.1] - 2026-09-14 - msk_core 4.1.0

### Requires msk_core 4.1.0

Uses the table forms that msk_core 4.1.0 introduced, so the deprecation warnings in the server console are gone. The notifications are sent as a table, which an older msk_core takes as the title. Update msk_core along with this script.

### Added

- **The msk_core version is checked on start.** `MSK.Check.Dependency('msk_core', '4.1.0', true)` logs an error in the server console when msk_core is older, instead of leaving you to wonder why the notifications look wrong. *(server/versionchecker.lua)*

### Changed

- **`Config.Notification` passes a table to `MSK.Notification`.** The form with title, message, type and duration is deprecated since msk_core 4.1.0 and logs a warning once per resource. If you keep your own config, change the two `MSK.Notification` lines the same way. Leaving them works too, the old form is still accepted for now. *(config/static.lua)*

- **`Config.openTextUI` passes a table to `MSK.TextUI.Show`.** The form with key, text and color is deprecated since msk_core 4.1.0. *(config/static.lua)*

### Fixed

- **`Config.closeTextUI` called `MSK.TextUI.Close()`, which does not exist.** With `Config.defaultTextUI = false` hiding the TextUI raised an error instead. It calls `MSK.TextUI.Hide()` now. If you keep your own `config/static.lua`, change that line yourself. *(config/static.lua)*

### Changed files

```text
fxmanifest.lua
config/static.lua
server/versionchecker.lua
```

---

## [5.6.0] - 2026-09-09 - Runs on ESX, QBCore and Qbox

### Requires msk_core 4.0.0

This release reads the vehicle table layout, the player object and the job
events from the rewritten bridge. On msk_core 3.x none of them answers in this
form. Update msk_core along with this script.

`ox_lib` is a dependency now, `es_extended` is not.

### Changed

- **`es_extended` is no longer a dependency.** It was listed in `dependencies`
  and imported through `@es_extended/imports.lua`, so the resource refused to
  start on any server without ESX. `@ox_lib/init.lua` takes its place.
  *(fxmanifest.lua)*

- **The vehicle table is resolved instead of hardcoded.** It is `owned_vehicles`
  keyed by `owner` on ESX and `player_vehicles` keyed by `citizenid` on QBCore
  and Qbox, where the stored flag is `state` rather than `stored` and the
  properties live in `mods` while `vehicle` holds the spawn name.
  `Config.MySQL` is filled from `MSK.VehicleStore.GetSchema()` on start, and
  every query in the resource reads the names from there, so there is exactly one
  place that has to be right.
  *(config/static.lua, server/garages.lua, server/vehicles.lua, server/main.lua,
  shared/utils.lua)*

- **Vehicle properties are read and written in the format of the running
  framework.** ESX has its own layout, QBCore and Qbox use the one from `ox_lib`,
  and these properties go back into the framework's vehicle table where every
  other garage on the server reads them. Handing an ox_lib table to an ESX garage
  produces a car without mods, or none at all. ESX is fetched lazily when it is
  actually the running framework.
  *(client/state.lua, client/vehicles.lua, client/nui.lua)*

- **The client no longer keeps its own copy of the player data.** It mirrored
  `esx:playerLoaded` and `esx:setJob` into a local table. msk_core keeps that
  copy itself and raises `msk_core:playerLoaded`, `msk_core:playerLogout`,
  `msk_core:setJob` and `msk_core:onPlayerDeath` on every framework.
  *(client/main.lua, client/blips.lua, client/points.lua, client/admin/sync.lua)*

### Fixed

- **Park-in was broken.** The `UPDATE` for park-in built its statement with two
  `%s` placeholders but passed only one value to `format`, which raises
  `bad argument #2 to 'format' (no value)` before the query is ever sent.
  *(server/vehicles.lua)*

- **Job vehicles were never purged on QBCore or Qbox.** The handler for
  `Config.deleteJobVehiclesOnJobChange` hung on `esx:setJob`, an event that only
  exists on ESX. It listens to `msk_core:setJob` now, which msk_core raises on
  every framework with the same arguments.
  *(server/main.lua, config/settings.lua)*

- **The framework group was only ever resolved on ESX.** It went through
  `xPlayer.getGroup()`, a method QBCore and Qbox do not have, so a dashboard
  admin without the matching `add_principal` line was refused there.
  *(server/admin/permissions.lua)*

- **A vehicle row with unreadable property JSON no longer takes the caller
  down.** Park-out and the impound release decoded it unchecked.
  *(server/vehicles.lua)*

### Changed files

```text
fxmanifest.lua
config/static.lua
config/settings.lua
shared/utils.lua
client/main.lua
client/state.lua
client/blips.lua
client/nui.lua
client/points.lua
client/vehicles.lua
client/admin/sync.lua
server/main.lua
server/api.lua
server/garages.lua
server/impound.lua
server/private.lua
server/private_command.lua
server/validation.lua
server/vehicles.lua
server/admin/api.lua
server/admin/permissions.lua
```

---

## [5.5.0] - 2026-08-30 - Private Garages

### Added

- **Private garages.** A garage now becomes private the moment it has an owner,
  and from then on only that owner and the people they let in can park there.
  Everything else stays exactly as it was: a garage without an owner behaves
  like it always has, so a server that ignores this feature will not notice it
  at all. The owner is set with `/garageowner <garageId> <serverId>` (needs the
  `garage.edit` right) and cleared again with `/garageowner <garageId> clear`.
  *(fxmanifest.lua, server/private.lua, server/validation.lua, server/api.lua,
  server/admin/boot.lua, server/admin/store.lua, server/admin/api.lua)*

- **The owner shares the garage from the garage menu.** A private garage the
  player owns shows an **Access** button in its header. It lists who may
  currently park there, takes a server id to let somebody in, and removes people
  again with one click. Both sides get a notification. Only the owner sees the
  button and only the owner can hand out access, so the first roommate cannot
  pass the house on to the whole server. How many people fit into one garage is
  capped by `Config.PrivateGarageMaxMembers`.
  *(client/nui.lua, server/api.lua, web/src/components/AccessDialog.tsx,
  web/src/components/Header.tsx, web/src/App.tsx, web/src/i18n/types.ts,
  web/src/lib/nui.ts, web/src/devMock.ts, web/package.json,
  web/package-lock.json, locales/*.lua, html/**)*

- **The same thing as a command**, for when the garage is out of reach.
  `/garagezugriff` lists the private garages a player owns,
  `/garagezugriff <garageId>` who may use it, and
  `/garagezugriff <garageId> add <serverId>` lets somebody in. `remove` also
  accepts an identifier, because the person you want to remove is usually
  offline. Works from rcon and txAdmin as well.
  *(server/private_command.lua, config/static.lua)*

- **A housing bridge that works with any housing script.** msk_garage does not
  know a single housing script by name, and that is deliberate: it offers an
  interface instead. The preferred direction is your housing script telling
  msk_garage what happened, through seven new server exports
  (`CreatePrivateGarage`, `DeletePrivateGarage`, `SetPrivateGarageOwner`,
  `GrantPrivateGarageAccess`, `RevokePrivateGarageAccess`,
  `GetPrivateGarageAccess`, `PlayerHasGarageAccess`). For housing scripts you
  cannot patch there are three adapters instead, all configured in
  `config/static.lua`: `db` reads the owner straight out of the housing table
  and therefore works even with escrow protected scripts, `export` calls an
  export whose name you fill in, and `custom` lets you write the lookup
  yourself. The adapter files are unencrypted, so you can add your own without
  waiting for an update.
  *(server/housing/init.lua, server/housing/db.lua, server/housing/export.lua,
  server/housing/custom.lua)*

- **A garage template, so a housing script does not have to build one.** A full
  garage definition has a ped, a blip, a marker, types and distances, and no
  third-party script can be expected to produce that. `CreatePrivateGarage` only
  needs coordinates and an owner, everything else comes from
  `Config.PrivateGarageTemplate`. *(config/static.lua)*

### Changed

- **Definitions are now sent per player when private garages exist.** A client
  only ever learns about the private garages it may actually use. Without that,
  every house on the server would end up as a blip on everyone else map, and a
  server with a few hundred houses would push a few hundred definitions into
  every single client on join. Servers without a single private garage keep the
  old single broadcast, so nothing changes for them.
  *(server/admin/api.lua, server/private.lua)*

- **`dashboardGroups` is no longer part of the definitions sent to clients.**
  The client never read it. It listed the names of your admin groups, which is
  the one thing in that payload that is not already visible in the world
  anyway. *(server/admin/api.lua)*

### Fixed

- **Vehicles can no longer be locked inside a garage you lost access to.**
  This is the one way this feature could have cost somebody their car, and it
  is handled in all four cases: losing access, an owner change, a public garage
  becoming private for the first time, and a housing script re-registering a
  house after a resale. In each of them the affected vehicles are moved to the
  default garage of their category first, boats to the sea default, helicopters
  to the air one, and only then does the change take effect. Making a private
  garage public again moves nothing, because everybody may use it afterwards.
  *(server/private.lua)*

### Database

Two changes, both applied automatically on start, nothing to run by hand:

- `msk_garage_garages` gains the columns `owner` and `house_ref`, both nullable
- the new table `msk_garage_private_access` holds who may use which garage

The NUI changed, so replace the `html/` folder together with the rest of the
resource files, then restart it. If you want to connect a housing script, have a
look at the new block at the bottom of `config/static.lua`.

---

## [5.4.4] - 2026-08-19 - Startup Crash on Older Databases

### Fixed

- **The resource refused to start on servers that already had a `garage` column,
  with `Data truncated for column 'garage' at row 2` in the console.** The boot
  migration adds the columns msk_garage needs and then tightens `garage` to
  `varchar(60) NOT NULL`. On a fresh database the column is created correctly in
  the first step and the second one has nothing left to do. If the column already
  existed, from msk_garage v3 or from another garage script, the first step does
  nothing at all, because `ADD COLUMN IF NOT EXISTS` skips a column that is
  already there without touching its definition. The column stays as it was, which
  usually means it allows `NULL` and is sometimes wider than 60 characters. The
  second step then has to map those existing rows onto the stricter definition,
  and a `NULL` cannot become `NOT NULL`. Whether that aborts the start or passes
  silently comes down to your `sql_mode`: with `STRICT_TRANS_TABLES`, the MariaDB
  default since 10.2.4, it is an error, without it the value is quietly turned
  into an empty string and you only get a warning. That combination, an older
  database on a strict server, is why this hit some of you and not others.
  msk_garage now cleans the column up while the old, looser definition is still in
  place: rows that are `NULL` or empty get your `Config.DefaultGarage`, values
  longer than 60 characters are shortened to fit, and only then is the column
  tightened. On a healthy database the cleanup matches no rows and costs nothing.
  It runs on every start, so a database that breaks later repairs itself.
  *(fxmanifest.lua, server/main.lua)*

### Changed

- **The vehicle type table moved from `server/vehicles.lua` to `server/main.lua`.**
  This is a pure reorganisation, the mapping from the `type` column in
  `owned_vehicles` to the type `CreateVehicleServerSetter` expects is unchanged and
  behaves exactly as before. *(server/vehicles.lua, server/main.lua)*

There is nothing to rebuild and no database change you have to make by hand, the
script repairs the column itself on start. Replace the resource files and restart
it.

---

## [5.4.3] — 2026-08-15 — Tuning Lost on Park-Out

### Fixed

- **Vehicles came out of the garage and the impound without their tuning.** Mods,
  colours, wheels, extras, everything back to stock, while the saved data in the
  database was perfectly fine the whole time. The cause sits in how a park-out
  vehicle is created: it comes from `CreateVehicleServerSetter`, so for the first
  few hundred milliseconds the entity belongs to the *server*. The natives behind
  `ESX.Game.SetVehicleProperties` (`SetVehicleMod`, `SetVehicleColours`,
  `SetVehicleExtra` and the rest) only take effect on the client that owns the
  entity. On any other client they do nothing at all, without an error and without
  a line in the console. The properties were written in exactly that window, so
  they went nowhere and the car spawned stock. Whether it worked came down to how
  fast the ownership migrated, which depends on ping, on the distance to the spawn
  point and on who else is standing around, and that is why it hit some players
  and not others. The script now takes control of the vehicle first and writes the
  properties afterwards. On top of that it reads the values back (primary and
  secondary colour, wheel type, turbo and every mod slot) and writes them again if
  something did not stick, for up to a second, because the game keeps normalising
  a freshly created vehicle for a few more frames and can wipe a write that did
  land. Garage and impound share this code path, so both are fixed. Nothing needs
  to be repaired in the database, vehicles that used to come out stock have their
  tuning back with this update. *(fxmanifest.lua, client/vehicles.lua)*
- **Side effects of the same fix.** The mod kit is now set explicitly before the
  properties are written instead of relying on the es_extended build to do it, and
  both spellings of the armour field (`modArmor` and `modArmour`, they differ
  between es_extended builds) are recognised when the result is verified. The
  engine, body and tank health are re-asserted together with the rest of the
  properties now, in one place, instead of in a separate pass.
  *(client/vehicles.lua)*

There is nothing to rebuild and no database change. Replace the resource files and
restart it.

---

## [5.4.2] — 2026-08-01 — Dashboard Access on ESX, QBCore and Qbox

### Fixed

- **Admins could not open the dashboard even though their `server.cfg` gave them
  the group.** Two things were stacked on top of each other here. First, FiveM
  keeps principals and ace objects apart: a line like `add_principal
  identifier.license:xxx group.admin` only makes that player a *member* of the
  group, it does not create the ace object of the same name that the check was
  looking for. Unless someone had also written `add_ace group.admin group.admin
  allow` by hand, the check came back empty. Second, the frameworks do not even
  agree on how a group principal is named: ESX and Qbox use `group.admin`, QBCore
  uses `qbcore.admin`, and that is not something you can configure away, it is
  what `/addpermission` and `QBCore.Functions.AddPermission` write. QBCore also
  only ever links `qbcore.god` to `group.admin`, so anyone below god level was a
  member of no `group.*` principal at all. On ESX this often stayed invisible
  because the group from the `users` table caught it, and that fallback does not
  exist on QBCore. The script now registers its own ace object per group on start
  and points both spellings at it, for `admin`, for every group in
  `Config.dashboardGroups` and for every group in the permission matrix. So a
  plain `add_principal ... group.mod` and a `/addpermission 1 mod` both get you
  in, and groups you add on the Permissions tab are covered right away without a
  restart. *(fxmanifest.lua, server/admin/permissions.lua, server/admin/boot.lua,
  server/admin/api.lua)*
- **Checking a group name on the Permissions tab reported "not found" for brand
  new groups.** The check ran before the group existed as an ace object, so it
  could never find anyone in it. The group is registered first now.
  *(server/admin/api.lua)*

- **`Access denied for command add_ace` spam on every server start.** FiveM checks
  `add_ace` against the resource that runs it, and no resource holds that right by
  default, so the ace objects were never actually created. Every attempt was refused
  and only printed an error. On ESX this went unnoticed because the framework group
  caught it. The aces are registered through msk_core now, which is the one resource
  your server.cfg already grants that right, and the script checks up front whether it
  is allowed instead of spamming the console.
  *(server/admin/permissions.lua)*

### Requires msk_core 3.3.0

This release uses `MSK.AddRawAce` and `MSK.CanAddAce`, both added in msk_core 3.3.0.
Update msk_core along with this script, and make sure your server.cfg has the msk_core
ace lines. They are the ones the msk_core documentation has always listed and they
cover every MSK script at once:

```cfg
add_ace resource.msk_core command.add_ace allow
add_ace resource.msk_core command.remove_ace allow
add_ace resource.msk_core command.add_principal allow
add_ace resource.msk_core command.remove_principal allow
```

If they are missing nothing breaks, the script says so on start and group access falls
back to your framework group.

There is nothing to rebuild and no database change. Replace the resource files and
restart it.

---

## [5.4.1] — 2026-07-27 — Impound Lock via AdvancedParking Exports

### Changed

- **The impound lock no longer reads AdvancedParking's database table.** The lock
  from v5.3.0 (`Config.blockImpoundWhileAdvancedParked`) asked AdvancedParking's
  `vehicles_parking` table whether a plate was still out in the world. It now asks
  AdvancedParking itself, through its serverside exports `GetVehiclePositions`
  (whole impound list in one call) and `GetVehiclePosition` (the park-out check),
  the same exports the impound list already uses for the tracking waypoint. Those
  answer from the live vehicle **or** from AdvancedParking's own saved data, so the
  result is the same as before without msk_garage knowing anything about a foreign
  table. Nothing changes for you in-game, the setting and its behaviour stay
  exactly as they were. If a build does not expose the batch export, single lookups
  are used instead, and only if those fail too does the lock disable itself after
  one console warning. *(fxmanifest.lua, config/settings.lua, config/static.lua,
  server/impound.lua, web/src/admin/i18n.ts, html/\*\*)*

- **All comments in `config/` are English and a lot shorter now.** A few of them had
  drifted into German over the last releases. **No setting and no value changed**, so
  you can keep your own config files as they are, this is purely about readability.
  The same goes for the one German comment left in `shared/utils.lua`.
  *(config/settings.lua, config/static.lua, config/garages.lua, config/impounds.lua,
  shared/utils.lua)*

### Removed

- **`Config.AdvancedParkingTable` and `Config.AdvancedParkingPlateColumn`** are
  gone from `config/static.lua`. There is no table or column left to configure, so
  a renamed AdvancedParking schema no longer breaks the lock. If you changed those
  values, you can simply drop them. *(config/static.lua)*

---

## [5.4.0] — 2026-07-26 — Faction Filter, Job-Vehicle Cleanup & Key Badges

### Added

- **Faction filter in the garage.** The park-out list gets a toggle next to the
  favourites filter that narrows the view down to the **job/faction vehicles of
  that garage**. Turning it off shows everything again, and it always starts off
  when the garage is opened. The button only appears when the current list
  actually contains job vehicles, so purely civilian garages keep the toolbar
  clean. *(client/nui.lua, web/src/App.tsx, web/src/components/SearchBar.tsx,
  web/src/i18n/types.ts, locales/\*.lua)*
- **Second-key badge on the vehicle card.** Vehicles that are only in your list
  because you hold a key for them are now marked as such, in the garage **and**
  in the impound. The badge reads **"Key from &lt;owner name&gt;"**, or a neutral
  **"Second key"** when the name cannot be resolved. The new setting
  **Settings → Faction vehicles & keys → "Show the owner's name on the second-key
  badge"** (`Config.showKeyOwnerName`, **on by default**) switches between the two.
  Names are resolved by the new `Utils.GetOwnerName` in `shared/utils.lua` (online
  player first, then the ESX `users` table, with a fallback for older schemas) and
  cached for 5 minutes. That function is not escrow-protected, so a different
  framework or `users` layout can be wired up by rewriting its body.
  *(config/settings.lua, shared/utils.lua, shared/admin_perms.lua,
  server/garages.lua, client/nui.lua, web/src/components/VehicleCard.tsx,
  web/src/i18n/types.ts, locales/\*.lua)*
- **Delete job vehicles when their owner leaves the job.** New setting
  **Settings → Faction vehicles & keys → "Delete faction vehicles on job change"**
  (`Config.deleteJobVehiclesOnJobChange`, **off by default**). With it enabled,
  every vehicle a player **personally owns** and that is registered on the job
  they just left is permanently removed from `owned_vehicles`. Hooked to the
  serverside ESX event `esx:setJob`, which is never a net event and therefore
  cannot be faked from a client. A pure **grade change** inside the same job does
  nothing, and **society vehicles** (`Config.useSocietyName`) are never touched
  because those belong to `society_<job>` and not to the player. Deletions are
  printed to the server console with the plates, and the new serverside hook
  `msk_garage:jobVehiclesDeleted(identifier, jobName, plates)` in
  `server/handler.lua` lets you clean up whatever else references them.
  *(config/settings.lua, shared/admin_perms.lua, server/main.lua,
  server/vehicles.lua, server/handler.lua)*
- **Key cleanup through the key-script adapters.** New
  `Keys.RemoveAllKeys(identifier, plate)` drops the keys of a plate through the
  adapter of the script set in `Config.VehicleKeys` — so it works for every
  supported key script instead of being hardcoded to one. The
  `msk_garage:jobVehiclesDeleted` hook uses it **out of the box**, so deleting a
  job vehicle no longer leaves orphaned keys behind; drop the loop in
  `server/handler.lua` if you'd rather keep them. Implemented for all three
  supported scripts: **msk_vehiclekeys** (`RemoveAllExistingKeys`) and
  **VehicleKeyChain** (`RemoveAllKeysUsingPlate`) remove the keys of **all**
  players for that plate, **vehicles_keys** only exposes a per-owner remove
  (`removeKeysFromIdentifier`) and therefore leaves second-key holders alone.
  `RemoveAllKeys` stays an **optional** part of the adapter contract, so a custom
  adapter without it just turns the call into a no-op. The adapter files in
  `server/keys/` are not escrow-protected.
  *(server/keys/init.lua, server/keys/msk_vehiclekeys.lua,
  server/keys/VehicleKeyChain.lua, server/keys/vehicles_keys.lua,
  server/handler.lua)*

---

## [5.3.0] — 2026-07-26 — Impound Lock for AdvancedParking

### Added

- **Impound lock while AdvancedParking still holds the vehicle.** New setting
  **Settings → Impounds → "Lock impound while AdvancedParking holds the vehicle"**
  (`Config.blockImpoundWhileAdvancedParked`, **off by default**, so nothing changes
  unless you turn it on). With it enabled, a vehicle can only be fetched from the
  impound once AdvancedParking no longer has a row for that plate in its
  `vehicles_parking` table, i.e. once the car has really left the map. Until then
  the card in the impound UI shows up greyed out and labelled, and the park-out is
  refused server-side **before** the impound fee is charged, so nobody pays for a
  blocked vehicle. With the setting off the old behaviour stays: msk_garage clears
  the AdvancedParking row itself and hands the vehicle out right away.
  Plates are matched space-insensitively, so a padded DB plate and a trimmed
  AdvancedParking plate still find each other. The table and column name can be
  changed in `config/static.lua` (`Config.AdvancedParkingTable`,
  `Config.AdvancedParkingPlateColumn`); if the table does not exist, the lock
  disables itself after one console warning instead of erroring on every request.
  *(config/settings.lua, config/static.lua, shared/admin_perms.lua,
  server/impound.lua, server/vehicles.lua, server/garages.lua, client/nui.lua,
  locales/\*.lua, web/src/components/VehicleCard.tsx, web/src/App.tsx,
  web/src/i18n/types.ts, web/src/admin/SettingsTab.tsx, web/src/admin/i18n.ts,
  web/src/admin/types.ts, web/src/devMock.ts, html/\*\*)*

---

## [5.2.1] — 2026-07-18 — Column-Migration Fix (oxmysql Named Placeholders)

### Fixed

- **Resource boot failed on newer oxmysql versions with `Column 'garage' cannot
  be null`.** The `owned_vehicles` column migration passed the default garage as a
  named placeholder (`@default`). Newer oxmysql versions no longer substitute
  named placeholders, and a placeholder is not allowed in a DDL `DEFAULT` clause
  anyway. MariaDB therefore treated `@default` as an unset user variable (`NULL`),
  so adding the `NOT NULL` `garage` column to a table that already had rows was
  rejected. The default is now written as an inline, escaped SQL literal, so the
  migration runs on every oxmysql version. *(server/main.lua)*

---

## [5.2.0] — 2026-07-08 — luxu_admin Dashboard Access & Vehicle-Type Synonyms

### Added

- **luxu_admin dashboard access.** The admin dashboard now also recognises
  **luxu_admin v2** staff groups. luxu_admin keeps its groups internally (not as
  FiveM ACE principals), so a normal `IsPlayerAceAllowed('group.x')` check never
  sees them. When enabled, the dashboard resolves a player's staff group via
  luxu_admin's `getPlayerStaffGroup` export and matches it against your dashboard
  groups (`group.admin` still means full access). Configure it in
  `config/static.lua` via the new `Config.LuxuAdmin`: `enable` (`'auto'` = on when
  the resource is started, or `true`/`false`), `resource`, `requireDuty`, and an
  optional `groupMap` to map luxu_admin group names onto your dashboard groups.
  *(config/static.lua, server/admin/permissions.lua)*

### Fixed

- **Heli/aircraft garages could stay empty when the vehicle shop stored the type
  as `air`.** Added `air` as a synonym for the `helicopter` and `aircraft`
  categories, so those garages fill regardless of the shop's naming convention.
  *(shared/classes.lua)*

---

## [5.1.0] — 2026-06-28 — Job-Garage Policies, UI Theming & Branding

### Added

- **Job-Garages tab.** A dedicated dashboard tab to control, **per job**, which
  **public garages** that job's vehicles may be parked in/out at. Each job can use a
  **whitelist** (only the selected public garages) or a **blacklist** (all public
  garages except the selected ones), with **"Select all" / "Deselect all"** buttons
  and a job search. A job with no entry has no public-garage access (default). The
  policy is stored centrally (DB setting `JobGaragePolicy`) and enforced
  **server-side** on vehicle listing, park-in, park-out and the park-in pre-check.
  *(web/src/admin/JobGaragesTab.tsx, server/admin/api.lua, server/garages.lua,
  server/vehicles.lua, config/settings.lua)*
- **UI colour customisation.** Settings → Colors lets you change the 5 brand colours
  (accent, background, panel, primary/secondary text) with a **live preview** and a
  **"Reset to default"** button. The theme applies to the **dashboard, garage and
  impound** UI and is stored in the DB (`Theme`). Derived shades are computed
  automatically. *(web/src/lib/theme.ts, web/tailwind.config.ts,
  web/src/styles/index.css, web/src/admin/SettingsTab.tsx, server/admin/api.lua)*
- **Editable brand tag.** The badge next to the dashboard title (default `MSK`) is
  now editable in Settings → Colors (`Config.BrandTag`); empty hides it.
  *(shared/admin_perms.lua, server/admin/api.lua, web/src/admin/AdminApp.tsx)*
- **Per-model vehicle images.** Real pictures per vehicle in the garage/impound UI:
  drop image files into the `vehicle_images/<spawnname>.<ext>` folder (served
  locally via `nui://`, offline). Toggle it and pick the format (PNG/JPG/WEBP) in
  Settings → Vehicle Images. Missing images fall back to the vehicle-class icon, so
  a partial set is fine. *(config/settings.lua, shared/admin_perms.lua,
  server/admin/api.lua, client/nui.lua, web/src/components/VehicleCard.tsx,
  vehicle_images/)*

### Fixed

- **Job vehicles could be parked into a public garage and become unretrievable.**
  Park-in/out of job vehicles at public garages is now governed by the new
  per-job garage policy — they are only accepted where the policy allows, and the
  listing/validation stay consistent. *(server/vehicles.lua, server/garages.lua)*

---

## [5.0.0] — 2026-06-28 — In-Game Admin Dashboard + DB-Driven Configuration

### Added

- **In-Game Admin Dashboard (`/garageadmin`).** A full admin UI to create, edit
  and delete **garages** and **impounds**, manage all global settings and the
  permission system — applied **live, without a server restart**. The command name
  is configurable (`Config.adminCommand`). Coordinates can be captured in-game via a
  "current position" button; locations and park-out points are managed as lists.
  *(server/admin/*, client/admin/*, web/src/admin/* — NUI rebuilt)*
- **Group / permission system.** 8 garage/impound rights
  (`view`/`create`/`edit`/`delete` each) plus `settings.manage` and
  `permissions.manage`. `group.admin` always has every right and is not editable;
  `group.user` can never open the dashboard. Groups are taken from the existing
  **server.cfg ACE groups** (FiveM can't enumerate them, so they're added in the
  dashboard and validated via `IsPlayerAceAllowed`). Every admin action is gated
  **server-side** (exploit-proof) with strict input sanitisation.
  *(shared/admin_perms.lua, server/admin/permissions.lua, server/admin/api.lua)*
- **Database-driven definitions.** Garages, impounds and settings now live in the
  DB (`msk_garage_garages`, `_impounds`, `_settings`, `_permissions`, auto-created
  on start). On first start the existing `config/*` is **seeded once** into the DB;
  afterwards the DB is authoritative and the config files are only the default
  template. *(server/admin/boot.lua, server/admin/seed.lua, server/admin/store.lua)*
- **Per-category default garages** (`Config.DefaultGarages = { land, sea, air }`).
  Deleting a garage reassigns its stored vehicles to the matching category's default
  garage; a garage that is set as a default is **protected from deletion** (must be
  replaced first). `Config.GetDefaultGarage(type)` resolves the right default.
  *(config/settings.lua, config/static.lua, server/admin/api.lua)*
- **Per-rank job access.** A garage's job restriction can now allow **individual
  ranks** instead of only "this grade and above": a job entry accepts
  `grades = { 0, 2, 4 }` (exact ranks) alongside the legacy `grade = N` (minimum).
  In the dashboard the job is picked from a dropdown of all server jobs and the
  exact ranks are ticked in a popup. Fully backwards-compatible.
  *(shared/utils.lua, server/admin/api.lua, web/src/admin/editors.tsx)*
- **More languages.** Added **HU, FR, ES, PT, PL** locales (in addition to EN/DE)
  for both the in-game strings and the admin dashboard; selectable from the
  dashboard. *(locales/*, web/src/admin/i18n.ts)*
- **Search & type filter** in the dashboard's garage and impound lists.
  *(web/src/admin/GaragesTab.tsx, ImpoundsTab.tsx)*

### Changed

- **Config split for clarity.** `config/settings.lua` now holds **only the
  dashboard/DB-managed values** (seed defaults). All code hooks, adapters and column
  mappings that the DB never touches moved to the new **`config/static.lua`**, each
  file clearly marked. *(config/settings.lua, config/static.lua)*
- **Vehicle-key script and target script are now dropdowns** in the dashboard,
  populated from the adapters available in code (`AdminPerms.VEHICLEKEY_SCRIPTS`,
  `AdminPerms.TARGET_SCRIPTS`) and validated server-side.
  *(shared/admin_perms.lua, server/admin/api.lua, web/src/admin/SettingsTab.tsx)*
- The existing garage/impound player flow (park-in / park-out / impound) is
  **unchanged** — the dashboard is a separate admin surface.
- **Marker & 3D-text are disabled in the editor when the NPC (ped) is enabled** —
  they are only shown in-world without a ped, so the dashboard now greys them out
  to match the runtime behaviour. *(web/src/admin/editors.tsx)*
- **Dashboard fonts** refreshed (Work Sans for headings, Open Sans for the rest).
  *(web/src/styles/index.css, web/tailwind.config.ts)*

### Fixed

- **"failed to load ped model" / NPC missing after teleport.** The ped loader
  treated an already-streamed model as a load failure, so garages sharing a model
  showed no NPC (and a false error), and teleporting to a garage spawned no ped
  until you moved away and back. Already-loaded models are now handled correctly,
  with a fast, clear failure for genuinely invalid models. *(client/peds.lua)*
- **Dashboard access for framework-defined admins.** Group checks now also honour
  the framework group (e.g. ESX `users.group = 'admin'`), not just FiveM ACE
  principals — so admins defined in the database can open the dashboard.
  *(server/admin/permissions.lua)*
- **Frozen dashboard on add/delete.** Replaced the native `window.confirm` (which
  hard-freezes the FiveM NUI) with an in-UI confirmation dialog; added a focus
  safety-net so a stuck cursor is always released on resource (re)start.
  *(web/src/admin/*, client/admin/main.lua)*

### Removed

- **`Config.AdvancedParking` flag removed.** AdvancedParking is now **detected
  automatically** (enabled whenever the `AdvancedParking` resource is running, via
  `Config.UsesAdvancedParking()`). *(config/static.lua, client/nui.lua,
  client/vehicles.lua, server/vehicles.lua)*

---

## [4.1.0] — 2026-06-27 — msk_fuel Integration (Real Tank Volume)

### Added

- **Automatic msk_fuel support.** msk_garage now detects whether `msk_fuel` is
  running (`GetResourceState`) and, if so, displays the **real tank volume** in
  the garage as configured in msk_fuel — e.g. `53 / 65 L` instead of a bare
  percentage. Without msk_fuel the display stays a percentage exactly as before.
  No new hard dependency — the integration is fully optional and self-detecting.
  *(config/settings.lua, client/nui.lua, web/src/components/FuelBar.tsx — NUI rebuilt)*
- **`Config.FuelTankDefaultVolume`** (default `65.0` L). Used only for the max-volume
  denominator (`/ X L`) of **stored** vehicles (park-out / impound list, where no
  live entity exists) whose model has no per-model override in msk_fuel's
  `config.tankvolume.lua`. The saved/shown liters themselves are always exact;
  park-in (live entity) uses the exact `GetVehicleMaxFuel`. *(config/settings.lua)*

### Fixed

- **Fuel was stored and displayed incorrectly when msk_fuel was active.** msk_fuel
  keeps the fuel level as **absolute liters** on the statebag (0..maxFuel), but the
  old fuel adapter read/wrote that value as if it were a 0–100 percentage — so a
  50 L tank was saved to `owned_vehicles.fuel` and shown in the UI as a wrong number
  (e.g. 54 L / 60 L). The adapter now reads/writes the **exact liters** directly via
  `exports.msk_fuel:GetVehicleFuel` / `SetVehicleFuel` (no percentage round-trip), so
  the saved value and the displayed value match the real fuel 1:1.
  *(config/settings.lua)*
- **`owned_vehicles.fuel` migrated from `TINYINT` to `SMALLINT`** (auto-migration on
  resource start) so msk_fuel tanks larger than 100 L are stored without being
  capped; the server clamp was raised accordingly (0–32767).
  *(server/main.lua, server/vehicles.lua)*
### Changed

- **Park-out locking now respects the vehicle-keys script.** Locking a freshly
  parked-out vehicle goes through a new `Config.LockVehicle` adapter that uses the
  keys script's lock export (`msk_vehiclekeys:SetVehicleLockState`) when present,
  instead of a raw `SetVehicleDoorsLocked`. This keeps the keys script's tracked
  lock state in sync so the owner's normal unlock works as expected.
  *(config/settings.lua, client/vehicles.lua)*

---

## [4.0.4] — 2026-06-27 — Boat/Aircraft Fixes + Security & Robustness Review

### Security

- **Park-in trusted client vehicle model (vehicle/upgrade injection).** The
  client-supplied props blob was stored verbatim and the model spawned back on
  park-out, so a crafted event could turn any car into a maxed supercar. Park-in
  now forces `props.model = GetEntityModel(vehicle)` (the only server-authoritative
  value). *(server/vehicles.lua)*
- **Park-out skipped the garage/vehicle type check.** Only park-in validated type,
  so the cosmetic UI filter was bypassable by calling the callback directly (boat
  out of a car garage → wrong setter type). Same `Classes.TypeMatches` guard added
  to park-out. *(server/vehicles.lua)*
- **`getVehiclegarage` callback leaked any plate's home garage.** Now gated on
  ownership via `LoadOwned`; the server-side function stays open for trusted
  callers. *(server/api.lua)*
- **Park-in allowed re-parking an already-stored plate** (overwrite window). Now
  requires `stored = 0`. *(server/vehicles.lua)*
- **Fuel value unvalidated** → could overflow the signed TINYINT column / bypass
  fuel economy. Now coerced and clamped to 0–100. *(server/vehicles.lua)*
- **Removed dead `msk_garage:impoundFee` callback** that accepted a client fee
  table. *(server/api.lua)*
- **`IsOwnedByPlayer` society branch** returned ownership from job membership alone
  (false positive + name/type leak). Now requires a real matching row. *(server/garages.lua)*

### Fixed

- **Key-only vehicles (key held, not owned) didn't show in the garage.** The
  keyed lookup matches on plate, but FiveM plates are space-padded and the key
  script may return a trimmed plate, so a padded DB plate vs a trimmed key plate
  matched nothing (owned vehicles were unaffected — they match on `owner`). The
  keyed query now matches raw, trimmed, and space-stripped (`REPLACE`), and logs
  a debug line per key lookup to pinpoint key-script vs garage/type mismatches.
  *(server/garages.lua)*
- **Society/job vehicles resolved inconsistently across read paths.** The
  `society_<job>` owner string was computed three different ways (garage list,
  impound list, `LoadOwned`), so depending on `Config.useSocietyName` society
  vehicles could appear in the garage but never the impound, or a job garage could
  come up empty. Unified via a shared `Utils.SocietyOwner(job)` helper + owner
  `IN (...)` lists. *(shared/utils.lua, server/garages.lua, server/vehicles.lua)*
- **One corrupt `vehicle` JSON row blanked the whole garage/impound list.**
  `mapRow` now decodes defensively (`safeDecode`, defaults to `{}`); the client
  list builders skip rows without a model and `show-parkin` is wrapped in pcall so
  a mid-session displacement can't throw before releasing NUI focus.
  *(server/garages.lua, client/nui.lua)*
- **`mapRow` / `GetNameFav` hardcoded column names** instead of the configurable
  `Config.MySQL.*` mapping. *(server/garages.lua)*
- **`setterType` could mis-spawn synonym types.** `motorbike` / `submarinecar`
  passed `TypeMatches` but were missing from the setter map (→ spawned as
  automobile). Map and synonyms re-synced. *(server/vehicles.lua)*
- **Escape closed the whole garage even with the rename dialog open.** The window
  keyup handler now cancels the dialog first. *(web/src/App.tsx — NUI rebuilt)*
- **`openGarage` / `openImpound` exports could double-open the UI** (no
  `isNuiOpen` guard) → reset state + redundant focus toggle. *(client/nui.lua)*
- **`VehicleDeformation` guard** used `~= 'missing'` instead of the project-wide
  `== 'started'`, so the export was called even when the resource was
  stopped/restarting. *(client/vehicles.lua)*
- **Marker opacity was hardcoded to 100.** Now reads optional `color.alpha`;
  documented that `color.a/b/c` are positional RGB, not alpha. *(client/points.lua)*

#### Boat & Aircraft (from the previous pass)

- **Cursor stuck after parking a boat out.** Boat garages use `warp = true`, so
  park-out closes the UI from Lua via `NUI.Close()`. That only sent the `closeUI`
  action to the NUI, and the React `closeUI` handler merely hides the panel — it
  does not round-trip a `closeGarage` callback the way the manual close button
  does. As a result `focusOff()` / `SetNuiFocus(false, false)` never ran and the
  mouse cursor stayed on screen. `NUI.Close()` now releases NUI focus directly.
- **Helicopter / aircraft garages showed no vehicles.** The garage config uses the
  categories `helicopter` / `aircraft`, but vehicle shops commonly store the
  `owned_vehicles.type` column using the `GetVehicleType()` convention (`heli` /
  `plane`). The list query (`type = 'helicopter'`) therefore matched nothing, and
  the same mismatch affected park-in eligibility and the spawn setter type. Type
  matching is now synonym-tolerant via `Classes.TypeSynonyms` / `Classes.TypeMatches`
  (`helicopter`↔`heli`, `aircraft`↔`plane`/`airplane`, `car`/`truck`↔`automobile`,
  `bike`↔`motorcycle`), so garages fill regardless of the shop's naming convention.
  List queries dedupe by plate to avoid double entries from overlapping synonyms.

> **Note:** If helis/aircraft still don't show up, check the value of the `type`
> column in `owned_vehicles` for such a vehicle and add it to `TYPE_SYNONYMS`
> (`shared/classes.lua`) if needed.

---

## [4.0.2] — 2026-06-14 — Impound Fixes

### Fixed

- **Impound listed no vehicles.** `Config.Impounds` entries were missing an
  `impoundId` field, so the server-side lookup (`Validation.GetImpound`) always
  resolved to `nil` and returned an empty list. Each impound now carries its
  config key as `impoundId` (mirroring how garages carry `id`).
- **Impounded vehicle was not removed on park-out (AdvancedParking).** Taking a
  car out of the impound spawned a fresh copy while the old one remained on the
  map. AdvancedParking persists vehicles in its own table and respawns them, so a
  plain `DeleteEntity` had no lasting effect. The old copy is now purged from
  AdvancedParking via `DeleteVehicleUsingData(..., keepInWorld = false)` (raw DB
  plate) in addition to the server-authoritative `GetAllVehicles` sweep — no
  client broadcast, so there is no performance cost or multi-client delete race.

### Changed

- Simplified impound park-out: `impoundId` is now read directly from the impound
  definition instead of being resolved via a table-comparison loop.

---

## [4.0.0] — 2026-06-03 — Full Rewrite

Complete rewrite of frontend and backend. Monolithic files were split into clean
modules, the NUI was migrated from vanilla HTML/jQuery to **React + Vite +
TypeScript + Tailwind**, and the entire backend was moved to **server authority**
(every write path is validated server-side).

> ⚠️ **Breaking Changes** — see the section below. This release is **not** a
> drop-in update from v3.x.

---

### 🎨 Frontend (NUI)

#### Added

- **Full NUI rewrite** as a React 18 app (Vite + TypeScript + Tailwind). Source
  lives under `web/`, the built output under `html/` (exactly what
  `fxmanifest.lua` ships).
- **Component architecture** instead of a single `script.js`: `App.tsx`,
  `Header`, `Sidebar`, `SearchBar`, `VehicleCard`, `FuelBar`, `RenameDialog`,
  `EmptyState`, `Loader`.
- **Typed NUI protocol** (`src/i18n/types.ts`) for all messages between Lua and
  the UI.
- **Dev mock** (`src/devMock.ts`): the UI can be tested in a plain browser with
  mock data via `npm run dev`; tree-shaken out of production builds via
  `import.meta.env.DEV`.
- **Custom vehicle-class icons** as local SVGs (`web/public/images/*.svg`) for
  all 18 vehicle types (sedan, sport, suv, boat, plane, …).

#### Changed

- **Fonts & icons are now fully bundled locally** (`@fontsource` — DM Sans,
  Space Mono; `lucide-react` icons). **Zero external requests** at runtime.
- MSK design fully driven by Tailwind tokens (`tailwind.config.ts`).

#### Removed

- **All external CDN dependencies of the old UI**: Google Fonts (Roboto,
  Poppins, Rajdhani), the **FontAwesome-Pro CDN mirror**, and **jQuery 3.4.1**.
- Old vanilla files `html/script.js` (~337 lines) and `html/style.css`
  (~721 lines).

#### Security

- **Nickname XSS vector structurally eliminated**: React escapes all rendered
  text and there is no `dangerouslySetInnerHTML` anywhere. The v3 nickname XSS
  is no longer possible.
- **Client-side input validation** (`src/lib/sanitize.ts`) mirrors the server
  rules (`server/validation.lua`) exactly — the input field can never submit
  characters the server would reject.

---

### ⚙️ Backend (Lua)

#### Added — Modular structure

- **Config split** (instead of one `config.lua` of ~746 lines):
  `config/garages.lua`, `config/impounds.lua`, `config/settings.lua`.
- **Localization split** (instead of `translation.lua`): `locales/de.lua`,
  `locales/en.lua`.
- **Shared modules**: `shared/classes.lua`, `shared/utils.lua`.
- **Modular server**: `server/main.lua`, `garages.lua`, `vehicles.lua`,
  `impound.lua`, `validation.lua`, `customSessions.lua`, `api.lua`,
  `handler.lua`, `versionchecker.lua`.
- **Vehicle keys as a dedicated subsystem** (`server/keys/`): `init.lua` plus
  bridges for `msk_vehiclekeys`, `VehicleKeyChain`, `vehicles_keys`.
- **Modular client** (instead of `client/main.lua` ~690 lines + `functions.lua`):
  `state.lua`, `target.lua`, `peds.lua`, `blips.lua`, `vehicles.lua`,
  `nui.lua`, `points.lua`, `main.lua`, `handler.lua`.

#### Security — Server authority

- **All write paths validated** through central endpoints in `server/api.lua`.
  The client can no longer inject a garage/impound definition — these come
  exclusively from `Config` or server-registered sessions.
- **Forge protection for custom garages/impounds** (`server/customSessions.lua`):
  in v3 the client passed a custom garage table over RPC — a modified client
  could forge arbitrary park-out coordinates, type lists, and (for impounds)
  `fee = 0`. Now **server-side** third-party resources register their garages via
  `exports.msk_garage:RegisterCustomGarage(src, def)` /
  `RegisterCustomImpound`; sessions auto-expire after 60s without a write and are
  cleared on `playerDropped`.
- **Distance check** (`Validation.PlayerNearCoord` / `RequireGarageAccess`):
  players must actually be at the garage/impound.
- **Server-side job/grade check** for job-restricted garages.
- **Nickname sanitization** (`Validation.SanitizeNickname`): whitelist
  (`%w %s . - _` + umlauts/ß) and max length (24 characters).
- **Plate spawn lock** (`Validation.AcquirePlateLock`): prevents vehicle dupe via
  park-out spam; one lock per plate while `CreateVehicleServerSetter` is in
  flight, with a stale-lock sweep every minute.
- **Spawn claim/rollback** (`msk_garage:claimSpawn` / `rollbackSpawn`): clean
  teardown if the entity fails to resolve client-side.
- **Ownership gate on vehicle locate**: only the owner / key holder receives the
  coordinates (`Vehicles.GetWorldCoords`).
- **Plate normalization** (`Validation.NormalisePlate`): carries both the trimmed
  and the 8-char whitespace-padded plate consistently through every query.

#### Removed

- Old files `server/encrypted.lua`, `server/vehiclekeys.lua`,
  `client/functions.lua`, `translation.lua`, `config.lua` (replaced by the
  modules above).

---

### 📦 Build / Manifest

- `fxmanifest.lua` updated to the v4 module structure; `escrow_ignore` set for
  open files (`config/`, `locales/`, `shared/`, handlers, keys).
- New build step for the NUI: after changes in `web/src/` →
  `cd web && npm run build` (runs `tsc -b`, builds into `../html/`). The server
  needs **no** npm.

---

### ⚠️ Breaking Changes

- **Config migration required**: the old `config.lua` no longer exists. Settings
  must be moved to `config/garages.lua`, `config/impounds.lua`, and
  `config/settings.lua`.
- **Custom garages/impounds**: third-party scripts that previously passed a
  garage table client-side must now register **server-side** via the new exports
  (`RegisterCustomGarage` / `RegisterCustomImpound`).
- **Translations**: `translation.lua` → `locales/de.lua` + `locales/en.lua`.

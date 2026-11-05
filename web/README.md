# msk_garage — NUI (React + Vite + Tailwind)

The in-game UI source. The **built output lives in `../html/`** and is
what `fxmanifest.lua` ships. Rebuild after any change in `src/`.

## Commands

```bash
cd web
npm install      # once
npm run dev      # browser preview with mock data (http://localhost:5173)
npm run build    # type-check + bundle into ../html/
```

`npm run build` runs `tsc -b` first, so type errors fail the build.

## How it talks to the Lua client

The UI is a pure consumer of the v4 NUI protocol emitted by
`client/nui.lua`. It never owns game state or strings.

**Incoming (Lua → UI), via `SendNUIMessage`:**
`openUI`, `addVehicle`, `refreshUI`, `noVehiclesFound`, `closeUI`
(see `src/i18n/types.ts`).

**Outgoing (UI → Lua), via `fetchNui` POST:**
`show-parkin` / `show-parkout` / `show-impound`, `park-in`, `park-out`,
`impound-park-out`, `impound-track`, `toggle-fav`, `rename-vehicle`,
`closeGarage`.

## Security notes

- React escapes all rendered text — there is no `dangerouslySetInnerHTML`
  anywhere, so the v3 nickname-XSS vector is structurally impossible.
- `src/lib/sanitize.ts` mirrors `server/validation.lua` so the input
  field can never submit characters the server would reject.
- All fonts (`@fontsource/*`) and icons (`lucide-react`) are bundled —
  no Google Fonts, no FontAwesome-Pro CDN mirror. Zero external requests
  at runtime.

## Dev mock

`src/devMock.ts` simulates the Lua client when running in a plain
browser (`npm run dev`). It is tree-shaken out of production builds
(guarded by `import.meta.env.DEV`).

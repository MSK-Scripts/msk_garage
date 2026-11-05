# Vehicle Images

Drop per-model vehicle images into **this folder** to show a real picture of each
vehicle in the garage / impound UI instead of the generic vehicle-class icon.

## Naming

Name each file after the vehicle's **spawn name** (model name), in lowercase:

```
vehicle_images/
├── sultanrs.png
├── adder.png
├── police.png
└── ...
```

- The spawn name is the model name used by `GetHashKey` / the vehicle's
  `DisplayName` (e.g. `sultanrs`, `adder`, `t20`), **lowercase**.
- Recommended size: ~512×288 px (16:9), transparent PNG looks best.
- Supported extensions: `png`, `jpg`, `webp` — pick one in the dashboard
  (Settings → Vehicle Images) and use that extension for all files.

## Enabling

1. Add your image files here.
2. Open the admin dashboard (`/garageadmin`) → **Settings → Vehicle Images** and
   enable it (and pick the file extension you used).

If a model has no image, the UI automatically falls back to the vehicle-class
icon, so a partial image set is fine.

## Export or CDN instead of files

Images can also come from a script export or a CDN, configured in
`config/static.lua` (not in the dashboard):

- **JG Vehicle Studio** is used automatically while `jg-vehiclestudio` is
  started (`exports['jg-vehiclestudio']:getImage(model)`, plus its fallbacks).
- **CDN:** set `Config.VehicleImageCdn`, e.g.
  `'https://cdn.msk-scripts.de/vehicles/{model}.png'` (the default). Tokens: `{model}`,
  `{MODEL}`, `{hash}`.
- For anything else, change `Config.GetVehicleImage(model, hash)`. Return one
  URL, a list of URLs or `nil`.

The dashboard switch (Settings → Vehicle Images) still has to be on. The UI tries
the export/CDN URLs first, then this folder, then the vehicle-class icon.

## Notes

- Files are served locally over `nui://` — no internet connection required.
- This folder is intentionally **outside** `html/`, so rebuilding the NUI never
  deletes your images.
- Make sure you have the rights to use any images you add. Community vehicle-image
  packs (named by spawn name) work out of the box.

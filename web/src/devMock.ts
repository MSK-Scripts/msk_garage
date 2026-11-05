import type { IncomingMessage, Translation, Vehicle, VehicleImageConfig } from './i18n/types'
import { DEFAULT_THEME } from './lib/theme'

const en: Translation = {
  open_garage: 'Press E to open %s',
  open_garage_textui: 'Press E to open %s',
  no_vehicles: "You don't have vehicles here",
  parked_in: 'Parked in',
  parked_out: 'Parked out',
  currency: '$',
  parkin: 'Park In',
  parkout: 'Park Out',
  pay_impound: 'Pay',
  vehicle_park_out: 'Park Out',
  vehicles: 'Vehicles',
  favorite_vehicles: 'Favorites',
  stat_total: 'Total',
  stat_favorites: 'Favorites',
  stat_parked: 'Parked',
  stat_out: 'Out',
  rename_popup_title: 'Rename Vehicle',
  rename_popup_submit: 'Submit',
  rename_popup_cancel: 'Cancel',
  rename_input_placeholder: 'Nickname',
  search_input_placeholder: 'Search Vehicle',
  vehicle_impound_track: 'Track',
  vehicle_track: '',
  vehicle_track_delete: '',
  vehicle_not_owned: '',
  already_parked_out: 'Already parked out',
  can_be_parked_out: 'Parked In',
  spawnLocations_blocked: 'No parking spots available',
  no_vehicles_found: 'No vehicles nearby',
  is_job_vehicle: '',
  paid_impound_fee: '',
  not_enough_money: '',
  impound_blocked: 'This vehicle is still out in the world and has to be removed first.',
  impound_blocked_btn: 'Still in the world',
  job_vehicles: 'Faction vehicles',
  key_from: 'Key from %s',
  key_secondary: 'Second key',
  access_button: 'Access',
  access_title: 'Manage access',
  access_subtitle: 'Who may park here?',
  access_placeholder: 'Server ID',
  access_add: 'Add',
  access_remove: 'Remove',
  access_close: 'Close',
  access_empty_list: 'Nobody but you may park here yet.',
  private_player_not_found: 'That player is not online.',
  private_limit: 'The limit of allowed people has been reached.',
  private_self: 'You are the owner, you already have access.',
  private_failed: 'That did not work.',
}

// `maxFuel` set -> msk_fuel active, `fuel` is absolute liters, shown as "X / Y L".
// `maxFuel` omitted -> `fuel` is a 0-100 percentage, shown as "X %".
const SAMPLE: Vehicle[] = [
  { id: 1, plate: 'MSK 001', label: 'Sultan RS', fuel: 50, maxFuel: 65, type: 'sport', model: 'sultanrs', isFav: 1, isStored: 1 },
  { id: 2, plate: 'MSK 002', label: 'Kuruma', fuel: 22, maxFuel: 65, type: 'sedan', model: 'kuruma', isFav: 0, isStored: 0, isJob: true },
  { id: 3, plate: 'MSK 003', label: 'Sandking', fuel: 10, maxFuel: 80, type: 'offroad', model: 'sandking', isFav: 0, isStored: 1, keyed: true, keyOwner: 'Max Mustermann' },
  { id: 4, plate: 'MSK 004', label: 'Patriot', fuel: 100, maxFuel: 100, type: 'suv', model: 'patriot', isFav: 1, isStored: 0, isJob: true },
  { id: 5, plate: 'MSK 005', label: 'Akuma', fuel: 60, type: 'motorcycle', model: 'akuma', isFav: 0, isStored: 1, keyed: true },
]

function post(msg: IncomingMessage) {
  window.postMessage(msg, '*')
}

// Live vehicle list + image config. Defaults to the static SAMPLE / class icons,
// but `loadVehicles()` swaps in the real images from the vehicle_images/ folder
// when the dev server exposes them (see vite.config.ts).
let VEHICLES: Vehicle[] = SAMPLE
let IMAGES: VehicleImageConfig = { enable: false, base: 'nui://msk_garage/vehicle_images/', ext: 'png' }

const CLASS_CYCLE = ['sport', 'sedan', 'suv', 'offroad', 'muscle', 'coupe', 'compact', 'van', 'supersport', 'motorcycle']

// Pulls the real image filenames from the dev server and builds a vehicle list
// from them, so the mock shows your actual vehicle_images/ pictures.
async function loadVehicles(): Promise<void> {
  try {
    const res = await fetch('/__vehicle_images')
    const files: string[] = await res.json()
    if (!Array.isArray(files) || files.length === 0) return

    // Pick the dominant extension and only use files matching it (the UI builds
    // base + model + single ext, so a mixed set would otherwise 404).
    const extOf = (f: string) => (f.split('.').pop() || 'png').toLowerCase()
    const counts: Record<string, number> = {}
    files.forEach((f) => { counts[extOf(f)] = (counts[extOf(f)] || 0) + 1 })
    const ext = Object.keys(counts).sort((a, b) => counts[b] - counts[a])[0] || 'png'
    const matching = files.filter((f) => extOf(f) === ext).slice(0, 120)
    if (matching.length === 0) return

    VEHICLES = matching.map((f, i) => {
      const model = f.replace(/\.[^.]+$/, '')
      const label = model.replace(/[_-]+/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())
      return {
        id: i + 1,
        plate: `MSK ${String(i + 1).padStart(3, '0')}`,
        label,
        fuel: 15 + ((i * 13) % 85),
        maxFuel: 65,
        type: CLASS_CYCLE[i % CLASS_CYCLE.length],
        model,
        isFav: i % 6 === 0 ? 1 : 0,
        isStored: i % 4 === 0 ? 0 : 1,
        isJob: i % 5 === 0,
        keyed: i % 7 === 0,
        keyOwner: i % 14 === 0 ? 'Max Mustermann' : undefined,
      }
    })
    IMAGES = { enable: true, base: '/vehicle_images/', ext }
  } catch {
    /* dev server without the plugin -> keep the static SAMPLE */
  }
}

function streamList(mode: 'parkin' | 'parkout' | 'impound') {
  // parkout: all owned vehicles for this garage (stored ones are
  //          parkable, out ones show as "already parked out").
  // parkin:  only vehicles physically out in the world (stored=0) —
  //          mirrors the real client, which lists nearby world entities.
  // impound: only vehicles lost on the map (stored=0).
  const list = mode === 'parkout' ? VEHICLES : VEHICLES.filter((v) => v.isStored === 0)
  if (list.length === 0) {
    post({ action: 'noVehiclesFound', text: en.no_vehicles })
    return
  }
  list.forEach((v) =>
    post({
      action: 'addVehicle',
      type: mode,
      // Every 3rd impound entry renders locked, to preview the AdvancedParking lock.
      vehicle: mode === 'impound' ? { ...v, canTrack: true, fee: 150, locked: v.id % 3 === 0 } : v,
    }),
  )
}

window.addEventListener('nui:dev-call', (e: Event) => {
  const { endpoint } = (e as CustomEvent).detail as { endpoint: string }
  if (endpoint === 'show-parkout') streamList('parkout')
  else if (endpoint === 'show-parkin') streamList('parkin')
  else if (endpoint === 'show-impound') streamList('impound')
  else if (endpoint.startsWith('access-')) { /* handled by the responder below */ }
  // eslint-disable-next-line no-console
  else console.log('[devMock] NUI call:', endpoint)
})

// Private garage access dialog. These callbacks RETURN a value, which the
// browser has no way of producing on its own, so fetchNui asks this responder
// instead (see lib/nui.ts). Open with `?access` to get the button.
const ACCESS: { identifier: string; name?: string }[] = [
  { identifier: 'license:aaa111', name: 'Bob Baumeister' },
  { identifier: 'license:bbb222', name: 'Clara Kohm' },
]

;(window as unknown as { __mskDevRespond?: unknown }).__mskDevRespond = (
  endpoint: string,
  data: unknown,
) => {
  const payload = (data ?? {}) as { serverId?: string; identifier?: string }

  if (endpoint === 'access-list') return { ok: true, list: [...ACCESS] }

  if (endpoint === 'access-grant') {
    // Mirrors the server: id 99 is nobody, everything else becomes a new entry.
    if (payload.serverId === '99') return { ok: false, err: 'player_not_found' }
    if (ACCESS.length >= 4) return { ok: false, err: 'limit_reached' }
    ACCESS.push({ identifier: 'license:new' + payload.serverId, name: 'Player ' + payload.serverId })
    return { ok: true, list: [...ACCESS] }
  }

  if (endpoint === 'access-revoke') {
    const i = ACCESS.findIndex((a) => a.identifier === payload.identifier)
    if (i >= 0) ACCESS.splice(i, 1)
    return { ok: true, list: [...ACCESS] }
  }

  return null
}

// Admin dashboard preview: open with `?admin` in the URL.
const ADMIN_MOCK = {
  locale: 'en',
  perms: {
    'garage.view': true, 'garage.create': true, 'garage.edit': true, 'garage.delete': true,
    'impound.view': true, 'impound.create': true, 'impound.edit': true, 'impound.delete': true,
    'settings.manage': true, 'permissions.manage': true,
  },
  permKeys: [
    'garage.view', 'garage.create', 'garage.edit', 'garage.delete',
    'impound.view', 'impound.create', 'impound.edit', 'impound.delete',
    'settings.manage', 'permissions.manage',
  ],
  garages: [
    {
      id: 'A', label: 'Garage | Meetingpoint', type: ['car', 'truck'], distance: 40, park_dist: 5, warp: false,
      jobs: { enable: false, identifier: 'player', ownJob: true, jobs: [] },
      pedmodel: { enable: true, model: 'csb_trafficwarden', distance: 20 },
      text3d: { enable: true, label: '~g~Open Garage', size: 0.8 },
      marker: { enable: true, distance: 5, type: 27, size: { a: 1, b: 1, c: 1 }, color: { a: 255, b: 255, c: 255, alpha: 100 } },
      blip: { enable: true, id: 524, color: 26, scale: 0.8 },
      locations: [{ x: 213.98, y: -808.45, z: 31.01, w: 156.59 }],
      park_out: [{ x: 232.98, y: -790.3, z: 30.6, w: 161.46 }],
    },
    {
      id: 'downtown', label: 'Garage | Downtown', type: ['car', 'bike'], distance: 40, park_dist: 5, warp: false,
      jobs: { enable: false, identifier: 'player', ownJob: true, jobs: [] },
      pedmodel: { enable: false, model: 'csb_trafficwarden', distance: 20 },
      text3d: { enable: true, label: '~g~Open Garage', size: 0.8 },
      marker: { enable: true, distance: 5, type: 27, size: { a: 1, b: 1, c: 1 }, color: { a: 0, b: 230, c: 118, alpha: 120 } },
      blip: { enable: true, id: 357, color: 26, scale: 0.8 },
      locations: [{ x: -340.12, y: -1487.25, z: 28.2, w: 90.0 }],
      park_out: [{ x: -350.4, y: -1490.1, z: 27.9, w: 270.0 }],
    },
    {
      id: 'marina', label: 'Garage | Marina', type: ['boat'], distance: 40, park_dist: 8, warp: true,
      jobs: { enable: false, identifier: 'player', ownJob: true, jobs: [] },
      pedmodel: { enable: true, model: 's_m_y_baywatch_01', distance: 20 },
      text3d: { enable: true, label: '~g~Open Marina', size: 0.8 },
      marker: { enable: true, distance: 5, type: 27, size: { a: 1, b: 1, c: 1 }, color: { a: 0, b: 160, c: 230, alpha: 120 } },
      blip: { enable: true, id: 427, color: 38, scale: 0.8 },
      locations: [{ x: -794.5, y: -1497.4, z: 1.6, w: 110.0 }],
      park_out: [{ x: -802.1, y: -1496.0, z: 0.2, w: 130.0 }],
    },
    {
      id: 'airfield', label: 'Garage | Airfield', type: ['aircraft', 'helicopter'], distance: 60, park_dist: 10, warp: false,
      jobs: { enable: false, identifier: 'player', ownJob: true, jobs: [] },
      pedmodel: { enable: true, model: 's_m_y_airworker', distance: 25 },
      text3d: { enable: true, label: '~g~Open Hangar', size: 0.8 },
      marker: { enable: true, distance: 6, type: 27, size: { a: 1.5, b: 1.5, c: 1 }, color: { a: 230, b: 180, c: 0, alpha: 120 } },
      blip: { enable: true, id: 569, color: 30, scale: 0.8 },
      locations: [{ x: -1267.2, y: -3014.5, z: 13.9, w: 330.0 }],
      park_out: [{ x: -1300.8, y: -3030.2, z: 13.9, w: 145.0 }],
    },
    {
      id: 'police_garage', label: 'Garage | LSPD', type: ['car', 'bike'], distance: 40, park_dist: 5, warp: false,
      jobs: { enable: true, identifier: 'society', ownJob: true, jobs: [{ job: 'police', grade: 0, grades: [] }] },
      pedmodel: { enable: true, model: 's_m_y_cop_01', distance: 20 },
      text3d: { enable: true, label: '~b~Police Garage', size: 0.8 },
      marker: { enable: true, distance: 5, type: 27, size: { a: 1, b: 1, c: 1 }, color: { a: 0, b: 120, c: 255, alpha: 120 } },
      blip: { enable: true, id: 524, color: 38, scale: 0.8 },
      locations: [{ x: 454.6, y: -1017.4, z: 28.4, w: 90.0 }],
      park_out: [{ x: 438.2, y: -1018.3, z: 28.7, w: 0.0 }],
    },
  ],
  impounds: [
    {
      id: 'impound_car', label: 'Impound | Car', type: ['car', 'truck'], park_dist: 5, warp: false,
      pedmodel: { enable: true, model: 'csb_trafficwarden', distance: 20 },
      text3d: { enable: true, label: '~g~Open Impound', size: 0.8 },
      marker: { enable: true, distance: 5, type: 27, size: { a: 1, b: 1, c: 1 }, color: { a: 255, b: 255, c: 255, alpha: 100 } },
      blip: { enable: true, id: 524, color: 17, scale: 0.8 },
      fee: { enable: true, price: 150, account: 'money' },
      locations: [{ x: 409.0, y: -1622.75, z: 29.29, w: 231.88 }],
      park_out: [{ x: 401.36, y: -1647.98, z: 29.29, w: 318.54 }],
    },
    {
      id: 'impound_boat', label: 'Impound | Boat', type: ['boat'], park_dist: 5, warp: true,
      pedmodel: { enable: true, model: 'csb_trafficwarden', distance: 20 },
      text3d: { enable: true, label: '~g~Open Impound', size: 0.8 },
      marker: { enable: true, distance: 5, type: 27, size: { a: 1, b: 1, c: 1 }, color: { a: 255, b: 255, c: 255, alpha: 100 } },
      blip: { enable: true, id: 410, color: 17, scale: 0.8 },
      fee: { enable: true, price: 200, account: 'money' },
      locations: [{ x: -788.38, y: -1490.3, z: 1.6, w: 289.21 }],
      park_out: [{ x: -797.84, y: -1490.21, z: -0.47, w: 301.0 }],
    },
    {
      id: 'impound_heli', label: 'Impound | Aircrafts', type: ['aircraft', 'helicopter'], park_dist: 5, warp: false,
      pedmodel: { enable: true, model: 'csb_trafficwarden', distance: 20 },
      text3d: { enable: true, label: '~g~Open Impound', size: 0.8 },
      marker: { enable: true, distance: 5, type: 27, size: { a: 1, b: 1, c: 1 }, color: { a: 255, b: 255, c: 255, alpha: 100 } },
      blip: { enable: true, id: 569, color: 17, scale: 0.8 },
      fee: { enable: true, price: 500, account: 'money' },
      locations: [{ x: -1070.57, y: -2867.78, z: 13.95, w: 152.85 }],
      park_out: [{ x: -1112.54, y: -2883.81, z: 13.95, w: 147.98 }],
    },
  ],
  settings: {
    Locale: 'en', Debug: true, VersionChecker: true, Hotkey: 38, defaultTextUI: true,
    Parking: 'specific', spawnMode: 'server', FuelTankDefaultVolume: 65, enableImpound: true,
    parkoutWithKey: true, needEnoughMoney: true, useSocietyName: false,
    blockImpoundWhileAdvancedParked: false,
    deleteJobVehiclesOnJobChange: false, showKeyOwnerName: true,
    TargetSystem: { enable: true, script: 'ox_target' }, VehicleKeys: { enable: true, script: 'msk_vehiclekeys' },
    DefaultGarages: { land: 'A', sea: 'marina', air: 'airfield' }, adminCommand: 'garageadmin', dashboardGroups: ['mod'],
    Theme: DEFAULT_THEME, BrandTag: 'MSK', VehicleImages: { enable: false, ext: 'png' },
  },
  groups: [
    { name: 'admin', protected: true, perms: {} },
    { name: 'mod', protected: false, perms: { 'garage.view': true, 'impound.view': true } },
  ],
  suggestedGroups: ['admin', 'mod', 'dev'],
  counts: { A: 3, downtown: 2, marina: 1, airfield: 0, police_garage: 4 },
  jobGaragePolicy: {
    police: { mode: 'whitelist', garages: ['A', 'downtown'] },
    mechanic: { mode: 'blacklist', garages: [] },
  },
  jobsList: [
    { name: 'police', label: 'Police', grades: [
      { grade: 0, label: 'Recruit' }, { grade: 1, label: 'Officer' },
      { grade: 2, label: 'Sergeant' }, { grade: 3, label: 'Lieutenant' }, { grade: 4, label: 'Chief' },
    ] },
    { name: 'ambulance', label: 'EMS', grades: [
      { grade: 0, label: 'Trainee' }, { grade: 1, label: 'Paramedic' }, { grade: 2, label: 'Doctor' },
    ] },
    { name: 'mechanic', label: 'Mechanic', grades: [
      { grade: 0, label: 'Apprentice' }, { grade: 1, label: 'Mechanic' }, { grade: 2, label: 'Boss' },
    ] },
  ],
  scripts: { target: ['ox_target'], vehicleKeys: ['msk_vehiclekeys', 'VehicleKeyChain', 'vehicles_keys'] },
}

// Kick off the UI shortly after load. URL switches which view opens:
//   ?admin    -> admin dashboard
//   ?impound  -> in-game impound UI
//   ?parkin   -> in-game park-in UI
//   (default) -> in-game park-out garage UI
setTimeout(() => {
  const search = window.location.search
  if (search.includes('admin')) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    post({ action: 'openAdmin', data: ADMIN_MOCK as any })
    return
  }
  const mode: 'parkin' | 'parkout' | 'impound' = search.includes('impound')
    ? 'impound'
    : search.includes('parkin')
      ? 'parkin'
      : 'parkout'
  // Load real images first (if available) so the cards show actual pictures.
  void loadVehicles().then(() => {
    post({
      action: 'openUI',
      type: mode,
      translation: en,
      garageTitle: mode === 'impound' ? 'Impound | Car' : 'Garage | Meetingpoint',
      parkinButton: en.parkin,
      parkoutButton: en.parkout,
      theme: DEFAULT_THEME,
      vehicleImages: IMAGES,
      garageId: 'haus_17',
      canManageAccess: search.includes('access'),
    })
  })
}, 300)

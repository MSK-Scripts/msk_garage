import type { AdminBootstrap } from '../admin/types'
import type { Theme } from '../lib/theme'

export interface Translation {
  open_garage: string
  open_garage_textui: string
  no_vehicles: string
  parked_in: string
  parked_out: string
  currency: string
  parkin: string
  parkout: string
  pay_impound: string
  vehicle_park_out: string
  vehicles: string
  favorite_vehicles: string
  stat_total: string
  stat_favorites: string
  stat_parked: string
  stat_out: string
  rename_popup_title: string
  rename_popup_submit: string
  rename_popup_cancel: string
  rename_input_placeholder: string
  search_input_placeholder: string
  vehicle_impound_track: string
  vehicle_track: string
  vehicle_track_delete: string
  vehicle_not_owned: string
  already_parked_out: string
  can_be_parked_out: string
  spawnLocations_blocked: string
  no_vehicles_found: string
  is_job_vehicle: string
  paid_impound_fee: string
  not_enough_money: string
  impound_blocked: string
  impound_blocked_btn: string
  job_vehicles: string
  key_from: string
  key_secondary: string
  // Private garage access dialog (v5.5.0)
  access_button: string
  access_title: string
  access_subtitle: string
  access_placeholder: string
  access_add: string
  access_remove: string
  access_close: string
  access_empty_list: string
  private_player_not_found: string
  private_limit: string
  private_self: string
  private_failed: string
}

/** One entry of a private garage access list. */
export interface AccessEntry {
  identifier: string
  /** Character name, resolved server-side. Falls back to the identifier. */
  name?: string
}

/** Reply shape of the access-* NUI callbacks. */
export interface AccessResult {
  ok: boolean
  err?: string
  list?: AccessEntry[]
}

export type Mode = 'parkin' | 'parkout' | 'impound'

// Per-model vehicle image config sent with `openUI`. `base` is a fully-qualified
// nui:// folder; the UI builds `${base}${model}.${ext}` and falls back to the
// class icon on error.
export interface VehicleImageConfig {
  enable: boolean
  base: string
  ext: string
}

export interface Vehicle {
  id: number
  plate: string
  label: string
  fuel: number
  // Max tank volume (liters). Present only when msk_fuel is running — the
  // FuelBar then renders absolute liters ("53 / 65 L") instead of a percentage.
  maxFuel?: number
  type: string
  // Spawn name (lowercase) used to resolve a per-model image; class icon otherwise.
  model?: string
  // Image URLs from Config.GetVehicleImage (export or CDN), tried in order
  // before the local vehicle_images/ folder.
  images?: string[]
  isFav?: number | boolean
  isStored?: number
  canTrack?: unknown
  fee?: number | null
  // Impound only: AdvancedParking still tracks this plate, so the server refuses
  // the park-out (Config.blockImpoundWhileAdvancedParked).
  locked?: boolean
  // Job/faction vehicle — drives the "faction" filter in the garage.
  isJob?: boolean
  // Only in the list because the player holds a key for it.
  keyed?: boolean
  // Owner's character name for the key badge. Absent when the name lookup failed
  // or Config.showKeyOwnerName is off — the badge then reads "second key".
  keyOwner?: string
}

export type IncomingMessage =
  | {
      action: 'openUI'
      type: Mode
      translation: Translation
      garageTitle: string
      parkinButton?: string
      parkoutButton?: string
      theme?: Theme
      vehicleImages?: VehicleImageConfig
      /** Id of the garage, needed for the access callbacks. Absent on impounds. */
      garageId?: string
      /** True only for the owner of a private garage. Server-decided. */
      canManageAccess?: boolean
    }
  | { action: 'addVehicle'; type: Mode; vehicle: Vehicle }
  | { action: 'refreshUI'; type: Mode }
  | { action: 'closeUI' }
  | { action: 'noVehiclesFound'; text: string }
  | { action: 'openAdmin'; data: AdminBootstrap }

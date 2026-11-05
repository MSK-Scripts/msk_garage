import type { Theme } from '../lib/theme'

export interface Coord { x: number; y: number; z: number; w: number }

export interface JobEntry { job: string; grade: number; grades?: number[] }

export type JobGarageMode = 'whitelist' | 'blacklist'
export interface JobGarageRule { mode: JobGarageMode; garages: string[] }
export type JobGaragePolicy = Record<string, JobGarageRule>
export interface JobGrade { grade: number; label: string }
export interface JobInfo { name: string; label: string; grades: JobGrade[] }
export interface Jobs {
  enable: boolean
  identifier: 'player' | 'society'
  ownJob: boolean
  jobs: JobEntry[]
}

export interface Blip { enable: boolean; id: number; color: number; scale: number }
export interface Ped { enable: boolean; model: string; distance: number }
export interface Text3d { enable: boolean; label: string; size: number }
export interface Marker {
  enable: boolean
  distance: number
  type: number
  size: { a: number; b: number; c: number }
  color: { a: number; b: number; c: number; alpha?: number }
}
export interface Fee { enable: boolean; price: number; account: string }

export interface GarageDef {
  id: string
  label: string
  type: string[]
  distance: number
  park_dist: number
  warp: boolean
  jobs: Jobs
  pedmodel: Ped
  text3d: Text3d
  marker: Marker
  blip: Blip
  locations: Coord[]
  park_out: Coord[]
}

export interface ImpoundDef {
  id: string
  impoundId?: string
  label: string
  type: string[]
  park_dist: number
  warp: boolean
  pedmodel: Ped
  text3d: Text3d
  marker: Marker
  blip: Blip
  fee: Fee
  locations: Coord[]
  park_out: Coord[]
}

export interface SettingsPayload {
  Locale: string
  Debug: boolean
  VersionChecker: boolean
  Hotkey: number
  defaultTextUI: boolean
  Parking: 'all' | 'specific'
  spawnMode?: 'server' | 'client'
  FuelTankDefaultVolume: number
  enableImpound: boolean
  parkoutWithKey: boolean
  needEnoughMoney: boolean
  useSocietyName: boolean
  blockImpoundWhileAdvancedParked: boolean
  deleteJobVehiclesOnJobChange: boolean
  showKeyOwnerName: boolean
  TargetSystem: { enable: boolean; script: string }
  VehicleKeys: { enable: boolean; script: string }
  DefaultGarages: { land: string; sea: string; air: string }
  adminCommand: string
  dashboardGroups: string[]
  Theme: Theme
  BrandTag: string
  VehicleImages: { enable: boolean; ext: string }
}

export interface GroupDef {
  name: string
  protected: boolean
  perms: Record<string, boolean>
}

export interface AdminBootstrap {
  locale: string
  perms: Record<string, boolean>
  permKeys: string[]
  garages: GarageDef[]
  impounds: ImpoundDef[]
  settings: SettingsPayload
  groups: GroupDef[]
  suggestedGroups: string[]
  counts: Record<string, number>
  jobsList: JobInfo[]
  jobGaragePolicy: JobGaragePolicy
  scripts: { target: string[]; vehicleKeys: string[] }
}

export interface CallResult {
  ok: boolean
  err?: string
  data?: AdminBootstrap
  valid?: boolean
  exists?: boolean
  blacklisted?: boolean
}

export const VEHICLE_TYPES = [
  'car', 'truck', 'bike', 'boat', 'submarine', 'helicopter', 'aircraft', 'trailer', 'train',
] as const

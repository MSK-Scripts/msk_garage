import { useEffect, useMemo, useState } from 'react'
import { Star, Pencil, MapPin, KeyRound } from 'lucide-react'
import type { Mode, Translation, Vehicle, VehicleImageConfig } from '../i18n/types'
import { FuelBar } from './FuelBar'

interface VehicleCardProps {
  vehicle: Vehicle
  mode: Mode
  t: Translation
  images?: VehicleImageConfig | null
  onAction: () => void
  onToggleFav: () => void
  onRename: () => void
  onTrack: () => void
}

const FALLBACK_ICON = 'coupe'

export function VehicleCard({
  vehicle,
  mode,
  t,
  images,
  onAction,
  onToggleFav,
  onRename,
  onTrack,
}: VehicleCardProps) {
  const isFav = Boolean(vehicle.isFav)
  const parkedOut = mode === 'parkout' && vehicle.isStored === 0
  const canTrack = mode === 'impound' && Boolean(vehicle.canTrack)
  // AdvancedParking still holds this plate — the server refuses the park-out, so
  // the button is dead here too instead of letting the player run into an error.
  const locked = mode === 'impound' && Boolean(vehicle.locked)
  const disabled = parkedOut || locked

  let actionLabel = t.parkin
  if (mode === 'parkout') actionLabel = parkedOut ? t.already_parked_out : t.parkout
  if (mode === 'impound') {
    actionLabel = vehicle.fee ? `${t.pay_impound} ${t.currency}${vehicle.fee}` : t.parkout
    if (locked) actionLabel = t.impound_blocked_btn
  }

  // Second-key badge: named when the server could resolve the owner, neutral
  // otherwise (name lookup failed, or Config.showKeyOwnerName is off).
  const keyBadge = vehicle.keyed
    ? vehicle.keyOwner
      ? t.key_from.replace('%s', vehicle.keyOwner)
      : t.key_secondary
    : null

  // Image source chain: export/CDN URLs → local per-model photo → class icon →
  // coupe fallback. Each entry marks whether it's a real photo (full-bleed, no
  // tint) or a class glyph (tinted).
  const sources = useMemo(() => {
    const list: { src: string; photo: boolean }[] = []
    for (const src of vehicle.images ?? []) list.push({ src, photo: true })
    if (images?.enable && vehicle.model) {
      list.push({ src: `${images.base}${vehicle.model}.${images.ext}`, photo: true })
    }
    list.push({ src: `./images/${vehicle.type}.svg`, photo: false })
    list.push({ src: `./images/${FALLBACK_ICON}.svg`, photo: false })
    return list
  }, [images, vehicle.images, vehicle.model, vehicle.type])

  const [idx, setIdx] = useState(0)
  useEffect(() => setIdx(0), [sources])
  const current = sources[Math.min(idx, sources.length - 1)]

  return (
    <div
      className={[
        'msk-vehicle-card group relative flex flex-col gap-5 rounded-lg border border-border bg-panel-raised p-5 transition-all',
        disabled ? 'opacity-40' : 'hover:border-border-accent',
      ].join(' ')}
      title={locked ? t.impound_blocked : undefined}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="truncate font-display text-xl font-semibold text-text-primary">
            {vehicle.label}
          </div>
          <div className="mt-0.5 font-mono text-xs uppercase tracking-wider text-text-muted">
            {vehicle.plate}
          </div>
          {keyBadge && (
            <div
              title={keyBadge}
              className="mt-2 inline-flex max-w-full items-center gap-1.5 rounded-sm border border-border-accent bg-accent/10 px-2 py-1 font-mono text-[10px] uppercase tracking-wider text-accent"
            >
              <KeyRound className="h-3 w-3 shrink-0" />
              <span className="truncate">{keyBadge}</span>
            </div>
          )}
        </div>

        <div className="flex shrink-0 items-center gap-1.5">
          {mode !== 'impound' && (
            <>
              <button
                onClick={onToggleFav}
                aria-label="Favorite"
                className={[
                  'flex h-8 w-8 items-center justify-center rounded-sm transition-colors',
                  isFav ? 'text-accent' : 'text-text-muted hover:text-text-secondary',
                ].join(' ')}
              >
                <Star className="h-[18px] w-[18px]" fill={isFav ? 'currentColor' : 'none'} />
              </button>
              <button
                onClick={onRename}
                aria-label="Rename"
                className="flex h-8 w-8 items-center justify-center rounded-sm text-text-muted transition-colors hover:text-text-secondary"
              >
                <Pencil className="h-4 w-4" />
              </button>
            </>
          )}
          {canTrack && (
            <button
              onClick={onTrack}
              aria-label={t.vehicle_impound_track}
              className="flex h-8 w-8 items-center justify-center rounded-sm text-text-muted transition-colors hover:text-accent"
            >
              <MapPin className="h-[18px] w-[18px]" />
            </button>
          )}
        </div>
      </div>

      <div className="flex items-center justify-center py-2">
        <img
          src={current.src}
          onError={() => setIdx((i) => Math.min(i + 1, sources.length - 1))}
          alt=""
          className={current.photo ? 'h-24 w-full object-contain' : 'veh-icon h-20 w-36 object-contain'}
        />
      </div>

      <FuelBar fuel={vehicle.fuel} maxFuel={vehicle.maxFuel} />

      <button
        disabled={disabled}
        onClick={onAction}
        className={[
          'w-full rounded-sm py-3 font-mono text-[13px] uppercase tracking-[0.1em] transition-all',
          disabled
            ? 'cursor-not-allowed bg-input text-text-muted'
            : 'bg-accent/15 text-accent hover:bg-accent hover:text-bg',
        ].join(' ')}
      >
        {actionLabel}
      </button>
    </div>
  )
}

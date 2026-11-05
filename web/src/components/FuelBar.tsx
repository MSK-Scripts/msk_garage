import { Fuel } from 'lucide-react'
import { fuelColor, fuelPct } from '../lib/fuel'

// Two modes, distinguished by `maxFuel`:
//  - msk_fuel active (maxFuel given): `fuel` is ABSOLUTE liters. The bar shows
//    the real tank fill (fuel / maxFuel) and the readout the exact liters,
//    e.g. "50 / 65 L".
//  - otherwise: `fuel` is a 0-100 percentage, shown as "82 %".
export function FuelBar({ fuel, maxFuel }: { fuel: number; maxFuel?: number }) {
  const liters = maxFuel != null && maxFuel > 0
  const pct = liters ? fuelPct((fuel / maxFuel) * 100) : fuelPct(fuel)
  const color = fuelColor(pct)
  const label = liters ? `${Math.round(fuel)} / ${Math.round(maxFuel)} L` : `${Math.round(pct)} %`

  return (
    <div className="flex items-center gap-2">
      <Fuel className="h-4 w-4 text-text-muted" />
      <div className="relative h-2 flex-1 overflow-hidden rounded-full bg-bg/60">
        <div
          className="absolute inset-y-0 left-0 rounded-full transition-all"
          style={{ width: `${pct}%`, backgroundColor: color }}
        />
      </div>
      <span className="font-mono text-[11px] tabular-nums text-text-secondary">{label}</span>
    </div>
  )
}

export function fuelColor(fuel: number): string {
  if (fuel <= 15) return '#ff4d4f'
  if (fuel <= 35) return '#ffae42'
  return '#00E676'
}

export function fuelPct(fuel: number): number {
  return Math.max(0, Math.min(100, fuel))
}

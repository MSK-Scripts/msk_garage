import { LogIn, LogOut } from 'lucide-react'
import type { Mode, Translation } from '../i18n/types'

export interface Stat {
  label: string
  value: number | string
}

interface SidebarProps {
  mode: Mode
  contextLabel: string
  title: string
  t: Translation
  stats: Stat[]
  onChange: (mode: Mode) => void
}

export function Sidebar({ mode, contextLabel, title, t, stats, onChange }: SidebarProps) {
  const tab = (target: Mode, label: string, Icon: typeof LogIn) => {
    const active = mode === target
    return (
      <button
        onClick={() => onChange(target)}
        className={[
          'flex w-full items-center gap-2.5 rounded-sm px-3 py-2.5 font-mono text-xs uppercase tracking-[0.1em] transition-all',
          active
            ? 'bg-accent/15 text-accent shadow-glow'
            : 'text-text-muted hover:bg-input hover:text-text-secondary',
        ].join(' ')}
      >
        <Icon className="h-4 w-4 shrink-0" strokeWidth={2} />
        <span className="truncate">{label}</span>
      </button>
    )
  }

  return (
    <div className="flex flex-col gap-5 border-r border-border p-4">
      {mode !== 'impound' && (
        <div className="flex flex-col gap-2">
          {tab('parkout', t.parkout, LogOut)}
          {tab('parkin', t.parkin, LogIn)}
        </div>
      )}

      <div className="flex flex-col gap-2 rounded-sm border border-border bg-bg/30 p-3">
        {stats.map((s) => (
          <div key={s.label} className="flex items-center justify-between gap-2">
            <span className="msk-label truncate text-[10px]">{s.label}</span>
            <span className="font-mono text-sm tabular-nums text-text-primary">{s.value}</span>
          </div>
        ))}
      </div>

      <div className="mt-auto border-t border-border pt-3">
        <p className="msk-label text-[10px]">{contextLabel}</p>
        <p className="mt-1 truncate font-sans text-sm text-text-secondary">{title}</p>
      </div>
    </div>
  )
}

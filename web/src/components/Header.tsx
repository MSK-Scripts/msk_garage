import { Warehouse, X, Users } from 'lucide-react'

interface HeaderProps {
  title: string
  onClose: () => void
  /** Shown only for the owner of a private garage. */
  accessLabel?: string
  onManageAccess?: () => void
}

export function Header({ title, onClose, accessLabel, onManageAccess }: HeaderProps) {
  return (
    <div className="flex items-center justify-between gap-3 px-5 py-4 border-b border-border">
      <div className="flex items-center gap-3 min-w-0">
        <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-sm bg-accent/10 text-accent">
          <Warehouse className="h-5 w-5" strokeWidth={1.75} />
        </div>
        <h1 className="truncate font-display text-lg font-bold tracking-tight text-text-primary">
          {title}
        </h1>
      </div>
      <div className="flex shrink-0 items-center gap-2">
        {onManageAccess && (
          <button
            onClick={onManageAccess}
            className="flex items-center gap-2 rounded-sm border border-border bg-input px-3 py-1.5 font-mono text-[11px] uppercase tracking-[0.1em] text-text-secondary transition-colors hover:border-border-accent hover:text-text-primary"
          >
            <Users className="h-4 w-4" strokeWidth={1.75} />
            {accessLabel}
          </button>
        )}
        <button
          onClick={onClose}
          className="flex h-8 w-8 items-center justify-center rounded-sm text-text-muted transition-colors hover:bg-input hover:text-text-primary"
          aria-label="Close"
        >
          <X className="h-5 w-5" />
        </button>
      </div>
    </div>
  )
}

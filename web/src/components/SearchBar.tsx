import { Briefcase, Search, Star } from 'lucide-react'

interface SearchBarProps {
  value: string
  placeholder: string
  showFav: boolean
  favActive: boolean
  onSearch: (value: string) => void
  onToggleFav: () => void
  // Faction filter — only rendered when the current list actually holds job
  // vehicles, so a purely civilian garage keeps the toolbar clean.
  showJob?: boolean
  jobActive?: boolean
  jobLabel?: string
  onToggleJob?: () => void
}

const TOGGLE_BASE =
  'flex h-[42px] w-[42px] shrink-0 items-center justify-center rounded-sm border transition-all'
const TOGGLE_ON = 'border-border-accent bg-accent/15 text-accent'
const TOGGLE_OFF = 'border-border bg-input text-text-muted hover:text-text-secondary'

export function SearchBar({
  value,
  placeholder,
  showFav,
  favActive,
  onSearch,
  onToggleFav,
  showJob = false,
  jobActive = false,
  jobLabel,
  onToggleJob,
}: SearchBarProps) {
  return (
    <div className="flex items-center gap-2">
      <div className="relative flex-1">
        <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-text-muted" />
        <input
          value={value}
          onChange={(e) => onSearch(e.target.value)}
          placeholder={placeholder}
          className="w-full rounded-sm border border-border bg-input py-2.5 pl-9 pr-3 font-sans text-sm text-text-primary placeholder:text-text-muted outline-none transition-colors focus:border-border-accent"
        />
      </div>
      {showJob && (
        <button
          onClick={onToggleJob}
          aria-label={jobLabel}
          title={jobLabel}
          className={[TOGGLE_BASE, jobActive ? TOGGLE_ON : TOGGLE_OFF].join(' ')}
        >
          <Briefcase className="h-4 w-4" />
        </button>
      )}
      {showFav && (
        <button
          onClick={onToggleFav}
          aria-label="Toggle favorites"
          className={[TOGGLE_BASE, favActive ? TOGGLE_ON : TOGGLE_OFF].join(' ')}
        >
          <Star className="h-4 w-4" fill={favActive ? 'currentColor' : 'none'} />
        </button>
      )}
    </div>
  )
}

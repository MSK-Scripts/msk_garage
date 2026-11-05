import { useEffect, useRef, useState } from 'react'
import { UserPlus, Trash2, Loader2 } from 'lucide-react'
import type { AccessEntry, AccessResult, Translation } from '../i18n/types'
import { fetchNui } from '../lib/nui'

interface AccessDialogProps {
  garageId: string
  garageLabel: string
  t: Translation
  onClose: () => void
}

/**
 * Lets the owner of a private garage decide who else may park there.
 *
 * The list is always what the server just returned: every mutation replies with
 * the fresh list, so the dialog never has to guess what the server did with the
 * request. Ownership is re-checked server-side on all three calls.
 */
export function AccessDialog({ garageId, garageLabel, t, onClose }: AccessDialogProps) {
  const [list, setList] = useState<AccessEntry[]>([])
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [value, setValue] = useState('')
  const [error, setError] = useState<string | null>(null)
  const inputRef = useRef<HTMLInputElement>(null)

  // Translates the server error codes into the strings the locales already ship.
  const messageFor = (err?: string): string => {
    switch (err) {
      case 'player_not_found': return t.private_player_not_found
      case 'limit_reached': return t.private_limit
      case 'self': return t.private_self
      default: return t.private_failed
    }
  }

  const apply = (res: AccessResult | null) => {
    if (!res || !res.ok) {
      setError(messageFor(res?.err))
      return false
    }
    setError(null)
    if (res.list) setList(res.list)
    return true
  }

  useEffect(() => {
    let cancelled = false
    // State is set after the await, never inside the effect body itself.
    void fetchNui<AccessResult>('access-list', { garageId }).then((res) => {
      if (cancelled) return
      setLoading(false)
      if (res?.ok && res.list) setList(res.list)
      else if (res && !res.ok) setError(messageFor(res.err))
    })
    return () => {
      cancelled = true
    }
  }, [garageId])

  useEffect(() => {
    inputRef.current?.focus()
  }, [])

  const add = async () => {
    const serverId = value.trim()
    if (!serverId || busy) return
    setBusy(true)
    const res = await fetchNui<AccessResult>('access-grant', { garageId, serverId })
    setBusy(false)
    if (apply(res)) setValue('')
  }

  const remove = async (identifier: string) => {
    if (busy) return
    setBusy(true)
    const res = await fetchNui<AccessResult>('access-revoke', { garageId, identifier })
    setBusy(false)
    apply(res)
  }

  return (
    <div className="absolute inset-0 z-20 flex items-center justify-center bg-black/60 animate-fade-in">
      <div className="flex max-h-[80%] w-[420px] flex-col msk-panel animate-scale-in">
        <div className="border-b border-border px-5 py-4">
          <h2 className="font-display text-base font-semibold text-text-primary">
            {t.access_title}
          </h2>
          <p className="truncate font-mono text-xs uppercase tracking-wider text-text-muted">
            {garageLabel}
          </p>
        </div>

        <div className="flex min-h-0 flex-col gap-4 p-5">
          <div>
            <p className="msk-label mb-2 text-[11px]">{t.access_subtitle}</p>
            <div className="flex gap-2">
              <input
                ref={inputRef}
                value={value}
                inputMode="numeric"
                maxLength={6}
                // Server ids are numeric; stripping everything else here means a
                // typo cannot even reach the server.
                onChange={(e) => setValue(e.target.value.replace(/[^0-9]/g, ''))}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') void add()
                  if (e.key === 'Escape') onClose()
                }}
                placeholder={t.access_placeholder}
                className="min-w-0 flex-1 rounded-sm border border-border bg-input px-3 py-2.5 font-sans text-sm text-text-primary placeholder:text-text-muted outline-none focus:border-border-accent"
              />
              <button
                onClick={() => void add()}
                disabled={!value || busy}
                className="flex items-center gap-2 rounded-sm bg-accent px-4 py-2.5 font-mono text-xs uppercase tracking-[0.1em] text-bg transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-40"
              >
                {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <UserPlus className="h-4 w-4" />}
                {t.access_add}
              </button>
            </div>
            {error && (
              <p className="mt-2 font-sans text-xs text-red-400">{error}</p>
            )}
          </div>

          <div className="msk-scroll min-h-0 flex-1 overflow-y-auto pr-1">
            {loading ? (
              <div className="flex items-center justify-center py-6 text-text-muted">
                <Loader2 className="h-5 w-5 animate-spin" />
              </div>
            ) : list.length === 0 ? (
              <p className="py-6 text-center font-sans text-sm text-text-muted">
                {t.access_empty_list}
              </p>
            ) : (
              <ul className="flex flex-col gap-2">
                {list.map((entry) => (
                  <li
                    key={entry.identifier}
                    className="flex items-center justify-between gap-3 rounded-sm border border-border bg-input px-3 py-2.5"
                  >
                    <span className="min-w-0 truncate font-sans text-sm text-text-primary">
                      {entry.name || entry.identifier}
                    </span>
                    <button
                      onClick={() => void remove(entry.identifier)}
                      disabled={busy}
                      title={t.access_remove}
                      aria-label={t.access_remove}
                      className="flex h-7 w-7 shrink-0 items-center justify-center rounded-sm text-text-muted transition-colors hover:bg-bg hover:text-red-400 disabled:opacity-40"
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </div>

          <button
            onClick={onClose}
            className="rounded-sm border border-border bg-input py-2.5 font-mono text-xs uppercase tracking-[0.1em] text-text-secondary transition-colors hover:text-text-primary"
          >
            {t.access_close}
          </button>
        </div>
      </div>
    </div>
  )
}

import { useEffect, useRef, useState } from 'react'
import type { Translation, Vehicle } from '../i18n/types'
import { sanitizeNickname, NICKNAME_MAX } from '../lib/sanitize'

interface RenameDialogProps {
  vehicle: Vehicle
  t: Translation
  onSubmit: (nickname: string) => void
  onCancel: () => void
}

export function RenameDialog({ vehicle, t, onSubmit, onCancel }: RenameDialogProps) {
  const [value, setValue] = useState(vehicle.label ?? '')
  const inputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    inputRef.current?.focus()
    inputRef.current?.select()
  }, [])

  const submit = () => onSubmit(sanitizeNickname(value))

  return (
    <div className="absolute inset-0 z-20 flex items-center justify-center bg-black/60 animate-fade-in">
      <div className="w-[340px] msk-panel animate-scale-in">
        <div className="border-b border-border px-5 py-4">
          <h2 className="font-display text-base font-semibold text-text-primary">
            {t.rename_popup_title}
          </h2>
          <p className="font-mono text-xs uppercase tracking-wider text-text-muted">
            {vehicle.plate}
          </p>
        </div>

        <div className="p-5">
          <input
            ref={inputRef}
            value={value}
            maxLength={NICKNAME_MAX}
            onChange={(e) => setValue(sanitizeNickname(e.target.value))}
            onKeyDown={(e) => {
              if (e.key === 'Enter') submit()
              if (e.key === 'Escape') onCancel()
            }}
            placeholder={t.rename_input_placeholder}
            className="w-full rounded-sm border border-border bg-input px-3 py-2.5 font-sans text-sm text-text-primary placeholder:text-text-muted outline-none focus:border-border-accent"
          />
          <div className="mt-1 text-right font-mono text-[10px] text-text-muted">
            {value.length}/{NICKNAME_MAX}
          </div>

          <div className="mt-4 flex gap-2">
            <button
              onClick={submit}
              className="flex-1 rounded-sm bg-accent py-2.5 font-mono text-xs uppercase tracking-[0.1em] text-bg transition-opacity hover:opacity-90"
            >
              {t.rename_popup_submit}
            </button>
            <button
              onClick={onCancel}
              className="flex-1 rounded-sm border border-border bg-input py-2.5 font-mono text-xs uppercase tracking-[0.1em] text-text-secondary transition-colors hover:text-text-primary"
            >
              {t.rename_popup_cancel}
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

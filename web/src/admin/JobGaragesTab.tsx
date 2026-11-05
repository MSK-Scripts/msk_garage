import { useMemo, useState } from 'react'
import { Check } from 'lucide-react'
import type { AdminStrings } from './i18n'
import { fmt } from './i18n'
import type { CallResult, GarageDef, JobGarageMode, JobGaragePolicy, JobInfo } from './types'
import { Btn, Chip, Section, StatusText } from './ui'

type Call = (endpoint: string, payload?: unknown) => Promise<CallResult | null>

function JobRow({
  t,
  job,
  publicGarages,
  rule,
  onSave,
}: {
  t: AdminStrings
  job: JobInfo
  publicGarages: GarageDef[]
  rule?: { mode: JobGarageMode; garages: string[] }
  onSave: (job: string, mode: JobGarageMode, garages: string[]) => void
}) {
  const [mode, setMode] = useState<JobGarageMode>(rule?.mode ?? 'whitelist')
  const [sel, setSel] = useState<Set<string>>(new Set(rule?.garages ?? []))
  const [dirty, setDirty] = useState(false)

  const toggle = (id: string) => {
    setSel((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
    setDirty(true)
  }
  const selectAll = () => { setSel(new Set(publicGarages.map((g) => g.id))); setDirty(true) }
  const deselectAll = () => { setSel(new Set()); setDirty(true) }
  const changeMode = (m: JobGarageMode) => { setMode(m); setDirty(true) }

  // Access summary badge.
  const summary =
    mode === 'whitelist' && sel.size === 0
      ? t.jg_no_access
      : `${mode === 'whitelist' ? t.mode_whitelist : t.mode_blacklist} · ${fmt(t.ranks_selected, sel.size)}`

  return (
    <div className="rounded-sm border border-border bg-panel-raised p-4">
      <div className="mb-3 flex items-center justify-between gap-2">
        <div className="flex flex-col">
          <span className="font-display text-[14px] font-bold text-text-primary">{job.label}</span>
          <span className="font-mono text-[11px] text-text-muted">{job.name}</span>
        </div>
        <div className="flex items-center gap-3">
          <span className={`font-sans text-[11px] ${mode === 'whitelist' && sel.size === 0 ? 'text-text-muted' : 'text-accent'}`}>{summary}</span>
          <Btn variant="accent" disabled={!dirty} onClick={() => { onSave(job.name, mode, [...sel]); setDirty(false) }}>
            {t.save}
          </Btn>
        </div>
      </div>

      <div className="mb-3 flex flex-wrap items-center gap-1.5">
        <Chip active={mode === 'whitelist'} onClick={() => changeMode('whitelist')}>{t.mode_whitelist}</Chip>
        <Chip active={mode === 'blacklist'} onClick={() => changeMode('blacklist')}>{t.mode_blacklist}</Chip>
        <span className="ml-1 font-sans text-[11px] text-text-muted">
          {mode === 'whitelist' ? t.jg_hint_whitelist : t.jg_hint_blacklist}
        </span>
      </div>

      <div className="mb-2 flex items-center justify-between">
        <span className="msk-label text-[10px] font-bold">{t.public_garages}</span>
        <div className="flex gap-2">
          <Btn variant="default" onClick={selectAll}>{t.select_all}</Btn>
          <Btn variant="default" onClick={deselectAll}>{t.deselect_all}</Btn>
        </div>
      </div>
      <div className="grid grid-cols-2 gap-1.5 md:grid-cols-3">
        {publicGarages.map((g) => {
          const on = sel.has(g.id)
          return (
            <button
              key={g.id}
              type="button"
              onClick={() => toggle(g.id)}
              className={`flex items-center justify-between gap-2 rounded-sm border px-3 py-2 text-left text-[12px] transition-colors ${
                on
                  ? 'border-border-accent bg-accent/15 text-accent'
                  : 'border-border bg-input text-text-secondary hover:text-text-primary'
              }`}
              title={g.id}
            >
              <span className="truncate">{g.label}</span>
              {on && <Check size={13} className="shrink-0" />}
            </button>
          )
        })}
      </div>
    </div>
  )
}

export function JobGaragesTab({
  t,
  jobsList,
  garages,
  policy,
  call,
  notify,
  toast,
}: {
  t: AdminStrings
  jobsList: JobInfo[]
  garages: GarageDef[]
  policy: JobGaragePolicy
  call: Call
  notify: (msg: string, ok: boolean) => void
  toast: { msg: string; ok: boolean } | null
}) {
  const [search, setSearch] = useState('')

  const publicGarages = useMemo(
    () => garages.filter((g) => !g.jobs?.enable).slice().sort((a, b) => a.id.localeCompare(b.id)),
    [garages],
  )

  const jobs = useMemo(() => {
    const q = search.trim().toLowerCase()
    const list = jobsList.slice().sort((a, b) => a.label.localeCompare(b.label))
    if (!q) return list
    return list.filter((j) => j.label.toLowerCase().includes(q) || j.name.toLowerCase().includes(q))
  }, [jobsList, search])

  const save = async (job: string, mode: JobGarageMode, list: string[]) => {
    const res = await call('admin:jobGarages:save', { job, mode, garages: list })
    notify(res?.ok ? t.saved : `${t.error}: ${res?.err ?? ''}`, Boolean(res?.ok))
  }

  const inputCls = 'w-full rounded-sm border border-border bg-input px-3 py-2 text-[13px] text-text-primary outline-none focus:border-border-accent'

  return (
    <div className="flex flex-col gap-4">
      <div className="flex min-h-[18px] items-center justify-between gap-3">
        <p className="font-sans text-[12px] text-text-muted">{t.job_garages_intro}</p>
        <StatusText toast={toast} />
      </div>

      {publicGarages.length === 0 ? (
        <Section title={t.public_garages}>
          <p className="font-sans text-[12px] text-text-muted">{t.no_public_garages}</p>
        </Section>
      ) : (
        <>
          <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder={t.search} className={inputCls} />
          <div className="flex flex-col gap-3">
            {jobs.map((job) => (
              <JobRow key={job.name} t={t} job={job} publicGarages={publicGarages} rule={policy[job.name]} onSave={save} />
            ))}
          </div>
        </>
      )}
    </div>
  )
}

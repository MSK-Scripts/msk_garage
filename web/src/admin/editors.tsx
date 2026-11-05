import { useState } from 'react'
import { Check, Plus, Trash2, X } from 'lucide-react'
import type { AdminStrings } from './i18n'
import { fmt } from './i18n'
import type { Blip, Fee, JobEntry, JobInfo, Jobs, Marker, Ped, Text3d } from './types'
import { VEHICLE_TYPES } from './types'
import { Btn, Chip, Field, NumInput, Section, Select, TextInput, ToggleRow } from './ui'

export function TypeSelector({
  t,
  value,
  onChange,
}: {
  t: AdminStrings
  value: string[]
  onChange: (v: string[]) => void
}) {
  const toggle = (type: string) =>
    onChange(value.includes(type) ? value.filter((x) => x !== type) : [...value, type])
  return (
    <Field label={t.vehicle_types}>
      <div className="flex flex-wrap gap-1.5">
        {VEHICLE_TYPES.map((type) => (
          <Chip key={type} active={value.includes(type)} onClick={() => toggle(type)}>
            {type}
          </Chip>
        ))}
      </div>
    </Field>
  )
}

export function BlipEditor({ t, value, onChange }: { t: AdminStrings; value: Blip; onChange: (v: Blip) => void }) {
  return (
    <Section title={t.blip}>
      <ToggleRow label={t.enable} checked={value.enable} onChange={(enable) => onChange({ ...value, enable })} />
      <div className="grid grid-cols-3 gap-3">
        <Field label={t.blip_sprite}>
          <NumInput value={value.id} onChange={(id) => onChange({ ...value, id })} />
        </Field>
        <Field label={t.blip_color}>
          <NumInput value={value.color} onChange={(color) => onChange({ ...value, color })} />
        </Field>
        <Field label={t.blip_scale}>
          <NumInput step={0.1} value={value.scale} onChange={(scale) => onChange({ ...value, scale })} />
        </Field>
      </div>
    </Section>
  )
}

export function PedEditor({ t, value, onChange }: { t: AdminStrings; value: Ped; onChange: (v: Ped) => void }) {
  return (
    <Section title={t.ped}>
      <ToggleRow label={t.enable} checked={value.enable} onChange={(enable) => onChange({ ...value, enable })} />
      <div className="grid grid-cols-2 gap-3">
        <Field label={t.ped_model}>
          <TextInput value={value.model} onChange={(model) => onChange({ ...value, model })} />
        </Field>
        <Field label={t.distance}>
          <NumInput step={0.5} value={value.distance} onChange={(distance) => onChange({ ...value, distance })} />
        </Field>
      </div>
    </Section>
  )
}

export function Text3dEditor({ t, value, onChange, disabled }: { t: AdminStrings; value: Text3d; onChange: (v: Text3d) => void; disabled?: boolean }) {
  return (
    <Section title={t.text3d} disabled={disabled} hint={t.npc_disables}>
      <ToggleRow label={t.enable} checked={value.enable} onChange={(enable) => onChange({ ...value, enable })} />
      <div className="grid grid-cols-2 gap-3">
        <Field label={t.text3d_label}>
          <TextInput value={value.label} onChange={(label) => onChange({ ...value, label })} />
        </Field>
        <Field label={t.text3d_size}>
          <NumInput step={0.1} value={value.size} onChange={(size) => onChange({ ...value, size })} />
        </Field>
      </div>
    </Section>
  )
}

export function MarkerEditor({ t, value, onChange, disabled }: { t: AdminStrings; value: Marker; onChange: (v: Marker) => void; disabled?: boolean }) {
  return (
    <Section title={t.marker} disabled={disabled} hint={t.npc_disables}>
      <ToggleRow label={t.enable} checked={value.enable} onChange={(enable) => onChange({ ...value, enable })} />
      <div className="grid grid-cols-2 gap-3">
        <Field label={t.marker_type}>
          <NumInput value={value.type} onChange={(type) => onChange({ ...value, type })} />
        </Field>
        <Field label={t.distance}>
          <NumInput step={0.5} value={value.distance} onChange={(distance) => onChange({ ...value, distance })} />
        </Field>
      </div>
      <div className="grid grid-cols-3 gap-2">
        {(['a', 'b', 'c'] as const).map((k) => (
          <Field key={k} label={`RGB ${k.toUpperCase()}`}>
            <NumInput
              value={value.color[k]}
              onChange={(n) => onChange({ ...value, color: { ...value.color, [k]: n } })}
            />
          </Field>
        ))}
      </div>
    </Section>
  )
}

function GradePopup({
  t,
  job,
  selected,
  onToggle,
  onClose,
}: {
  t: AdminStrings
  job?: JobInfo
  selected: number[]
  onToggle: (grade: number) => void
  onClose: () => void
}) {
  return (
    <div className="fixed inset-0 z-[80] flex items-center justify-center bg-black/60 animate-fade-in">
      <div className="msk-panel flex max-h-[80vh] w-[420px] max-w-[92vw] flex-col animate-scale-in">
        <div className="flex items-center justify-between border-b border-border px-4 py-3">
          <h3 className="font-display text-[14px] font-bold text-text-primary">
            {t.select_ranks}{job ? ` — ${job.label}` : ''}
          </h3>
          <button
            type="button"
            onClick={onClose}
            className="flex h-7 w-7 items-center justify-center rounded-sm text-text-muted transition-colors hover:bg-input hover:text-text-primary"
            aria-label="Close"
          >
            <X size={16} />
          </button>
        </div>
        <div className="msk-scroll flex flex-col gap-1.5 overflow-y-auto p-4">
          {(job?.grades ?? []).map((g) => {
            const on = selected.includes(g.grade)
            return (
              <button
                key={g.grade}
                type="button"
                onClick={() => onToggle(g.grade)}
                className={`flex items-center justify-between rounded-sm border px-3 py-2 text-left text-[13px] transition-colors ${
                  on
                    ? 'border-border-accent bg-accent/15 text-accent'
                    : 'border-border bg-input text-text-secondary hover:text-text-primary'
                }`}
              >
                <span>{g.grade} · {g.label}</span>
                {on && <Check size={14} />}
              </button>
            )
          })}
          {(!job || job.grades.length === 0) && (
            <p className="py-4 text-center font-sans text-[12px] text-text-muted">—</p>
          )}
        </div>
        <div className="flex items-center justify-between border-t border-border px-4 py-3">
          <span className="font-sans text-[11px] text-text-muted">{t.all_ranks}</span>
          <Btn variant="accent" onClick={onClose}>{t.save}</Btn>
        </div>
      </div>
    </div>
  )
}

export function JobsEditor({
  t,
  value,
  onChange,
  jobsList,
}: {
  t: AdminStrings
  value: Jobs
  onChange: (v: Jobs) => void
  jobsList: JobInfo[]
}) {
  const [gradePopupFor, setGradePopupFor] = useState<number | null>(null)

  const jobOptions = [
    { value: '', label: '—' },
    ...jobsList.map((j) => ({ value: j.name, label: `${j.label} (${j.name})` })),
  ]

  const addJob = () =>
    onChange({ ...value, jobs: [...value.jobs, { job: jobsList[0]?.name ?? '', grade: 0, grades: [] }] })
  const setJob = (i: number, job: string) =>
    onChange({ ...value, jobs: value.jobs.map((j, idx) => (idx === i ? { ...j, job, grades: [] } : j)) })
  const removeJob = (i: number) => onChange({ ...value, jobs: value.jobs.filter((_, idx) => idx !== i) })
  const toggleGrade = (i: number, grade: number) =>
    onChange({
      ...value,
      jobs: value.jobs.map((j, idx) => {
        if (idx !== i) return j
        const cur = j.grades ?? []
        const next = cur.includes(grade) ? cur.filter((g) => g !== grade) : [...cur, grade].sort((a, b) => a - b)
        return { ...j, grades: next }
      }),
    })

  const summary = (j: JobEntry) => {
    const n = j.grades?.length ?? 0
    return n > 0 ? fmt(t.ranks_selected, n) : t.all_ranks
  }

  return (
    <Section title={t.jobs}>
      <ToggleRow label={t.job_restricted} checked={value.enable} onChange={(enable) => onChange({ ...value, enable })} />
      {value.enable && (
        <>
          <Field label={t.job_identifier}>
            <Select
              value={value.identifier}
              onChange={(v) => onChange({ ...value, identifier: v as Jobs['identifier'] })}
              options={[
                { value: 'player', label: 'player' },
                { value: 'society', label: 'society' },
              ]}
            />
          </Field>
          <div className="flex flex-col gap-2">
            {value.jobs.map((j, i) => (
              <div key={i} className="flex items-end gap-2">
                <div className="flex-1">
                  <Field label={t.job_name}>
                    <Select value={j.job} onChange={(v) => setJob(i, v)} options={jobOptions} />
                  </Field>
                </div>
                <div className="w-48">
                  <Field label={t.job_grade}>
                    <button
                      type="button"
                      disabled={!j.job}
                      onClick={() => setGradePopupFor(i)}
                      className="w-full truncate rounded-sm border border-border bg-input px-3 py-2 text-left font-sans text-[13px] text-text-primary outline-none transition-colors hover:border-border-accent disabled:cursor-not-allowed disabled:opacity-40"
                    >
                      {summary(j)}
                    </button>
                  </Field>
                </div>
                <button
                  type="button"
                  onClick={() => removeJob(i)}
                  className="mb-1 rounded-sm border border-border p-2 text-text-muted hover:text-red-400"
                >
                  <Trash2 size={14} />
                </button>
              </div>
            ))}
            <Btn variant="default" onClick={addJob}>
              <Plus size={13} /> {t.add_job}
            </Btn>
          </div>
        </>
      )}

      {gradePopupFor !== null && value.jobs[gradePopupFor] && (
        <GradePopup
          t={t}
          job={jobsList.find((jl) => jl.name === value.jobs[gradePopupFor!].job)}
          selected={value.jobs[gradePopupFor!].grades ?? []}
          onToggle={(g) => toggleGrade(gradePopupFor!, g)}
          onClose={() => setGradePopupFor(null)}
        />
      )}
    </Section>
  )
}

export function FeeEditor({ t, value, onChange }: { t: AdminStrings; value: Fee; onChange: (v: Fee) => void }) {
  return (
    <Section title={t.fee}>
      <div className="grid grid-cols-2 gap-3">
        <Field label={t.fee_price}>
          <NumInput value={value.price} onChange={(price) => onChange({ ...value, price, enable: price > 0 })} />
        </Field>
        <Field label={t.fee_account}>
          <TextInput value={value.account} onChange={(account) => onChange({ ...value, account })} />
        </Field>
      </div>
    </Section>
  )
}

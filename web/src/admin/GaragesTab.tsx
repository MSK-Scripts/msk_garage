import { useState } from 'react'
import { Pencil, Plus, Trash2 } from 'lucide-react'
import type { AdminStrings } from './i18n'
import { fmt } from './i18n'
import type { CallResult, GarageDef, JobInfo } from './types'
import { VEHICLE_TYPES } from './types'
import { Btn, ConfirmDialog, CoordList, Field, Modal, NumInput, Section, Select, StatusText, TextInput, ToggleRow } from './ui'
import { BlipEditor, JobsEditor, MarkerEditor, PedEditor, TypeSelector, Text3dEditor } from './editors'

type Call = (endpoint: string, payload?: unknown) => Promise<CallResult | null>

function emptyGarage(): GarageDef {
  return {
    id: '',
    label: '',
    type: ['car', 'truck'],
    distance: 40.0,
    park_dist: 5.0,
    warp: false,
    jobs: { enable: false, identifier: 'player', ownJob: true, jobs: [] },
    pedmodel: { enable: true, model: 'csb_trafficwarden', distance: 20.0 },
    text3d: { enable: true, label: '~g~Open Garage', size: 0.8 },
    marker: { enable: true, distance: 5.0, type: 27, size: { a: 1, b: 1, c: 1 }, color: { a: 255, b: 255, c: 255, alpha: 100 } },
    blip: { enable: true, id: 524, color: 26, scale: 0.8 },
    locations: [],
    park_out: [],
  }
}

function GarageForm({
  t,
  initial,
  isNew,
  onSave,
  onClose,
  toast,
  jobsList,
}: {
  t: AdminStrings
  initial: GarageDef
  isNew: boolean
  onSave: (g: GarageDef) => Promise<void>
  onClose: () => void
  toast: { msg: string; ok: boolean } | null
  jobsList: JobInfo[]
}) {
  const [g, setG] = useState<GarageDef>(initial)
  const [busy, setBusy] = useState(false)
  const set = (patch: Partial<GarageDef>) => setG((prev) => ({ ...prev, ...patch }))

  const save = async () => {
    setBusy(true)
    await onSave(g)
    setBusy(false)
  }

  return (
    <Modal
      title={isNew ? t.create_garage : `${t.edit}: ${initial.label || initial.id}`}
      onClose={onClose}
      footer={
        <>
          <StatusText toast={toast} />
          <div className="flex-1" />
          <Btn variant="ghost" onClick={onClose}>{t.cancel}</Btn>
          <Btn variant="accent" onClick={save} disabled={busy}>{t.save}</Btn>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        <Section title={t.general}>
          <div className="grid grid-cols-2 gap-3">
            <Field label={t.id}>
              <TextInput value={g.id} onChange={(id) => set({ id })} disabled={!isNew} />
            </Field>
            <Field label={t.label}>
              <TextInput value={g.label} onChange={(label) => set({ label })} />
            </Field>
          </div>
          <TypeSelector t={t} value={g.type} onChange={(type) => set({ type })} />
          <div className="grid grid-cols-2 gap-3">
            <Field label={t.distance}>
              <NumInput step={0.5} value={g.distance} onChange={(distance) => set({ distance })} />
            </Field>
            <Field label={t.park_dist}>
              <NumInput step={0.5} value={g.park_dist} onChange={(park_dist) => set({ park_dist })} />
            </Field>
          </div>
          <ToggleRow label={t.warp} checked={g.warp} onChange={(warp) => set({ warp })} />
        </Section>

        <Section title={t.locations}>
          <CoordList
            title={t.locations}
            addLabel={t.add_location}
            useLabel={t.use_position}
            coords={g.locations}
            onChange={(locations) => set({ locations })}
          />
          <CoordList
            title={t.park_out}
            addLabel={t.add_parkout}
            useLabel={t.use_position}
            coords={g.park_out}
            onChange={(park_out) => set({ park_out })}
          />
        </Section>

        <JobsEditor t={t} value={g.jobs} onChange={(jobs) => set({ jobs })} jobsList={jobsList} />
        <BlipEditor t={t} value={g.blip} onChange={(blip) => set({ blip })} />
        <PedEditor t={t} value={g.pedmodel} onChange={(pedmodel) => set({ pedmodel })} />
        <Text3dEditor t={t} value={g.text3d} onChange={(text3d) => set({ text3d })} disabled={g.pedmodel.enable} />
        <MarkerEditor t={t} value={g.marker} onChange={(marker) => set({ marker })} disabled={g.pedmodel.enable} />
      </div>
    </Modal>
  )
}

export function GaragesTab({
  t,
  garages,
  counts,
  perms,
  call,
  notify,
  toast,
  jobsList,
}: {
  t: AdminStrings
  garages: GarageDef[]
  counts: Record<string, number>
  perms: Record<string, boolean>
  call: Call
  notify: (msg: string, ok: boolean) => void
  toast: { msg: string; ok: boolean } | null
  jobsList: JobInfo[]
}) {
  const [editing, setEditing] = useState<GarageDef | null>(null)
  const [isNew, setIsNew] = useState(false)
  const [search, setSearch] = useState('')
  const [typeFilter, setTypeFilter] = useState('')
  const [pendingDelete, setPendingDelete] = useState<GarageDef | null>(null)

  const canCreate = perms['garage.create']
  const canEdit = perms['garage.edit']
  const canDelete = perms['garage.delete']

  const typeOptions = [
    { value: '', label: t.filter_all_types },
    ...VEHICLE_TYPES.map((ty) => ({ value: ty, label: ty })),
  ]

  const list = garages
    .filter((g) => `${g.id} ${g.label}`.toLowerCase().includes(search.toLowerCase()))
    .filter((g) => !typeFilter || g.type.includes(typeFilter))
    .sort((a, b) => a.id.localeCompare(b.id))

  const save = async (g: GarageDef) => {
    const res = await call('admin:garage:save', { garage: g })
    if (res?.ok) {
      notify(t.saved, true)
      setEditing(null)
    } else {
      notify(`${t.error}: ${res?.err ?? ''}`, false)
    }
  }

  const del = async (g: GarageDef) => {
    const res = await call('admin:garage:delete', { id: g.id })
    if (res?.ok) notify(t.saved, true)
    else notify(res?.err === 'is_default_garage' ? t.is_default_garage : `${t.error}: ${res?.err ?? ''}`, false)
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder={t.search}
            className="w-64 rounded-sm border border-border bg-input px-3 py-2 text-[13px] text-text-primary outline-none focus:border-border-accent"
          />
          <div className="w-44">
            <Select value={typeFilter} onChange={setTypeFilter} options={typeOptions} />
          </div>
        </div>
        <div className="flex items-center gap-3">
          <StatusText toast={toast} />
          {canCreate && (
            <Btn variant="accent" onClick={() => { setEditing(emptyGarage()); setIsNew(true) }}>
              <Plus size={14} /> {t.create_garage}
            </Btn>
          )}
        </div>
      </div>

      <div className="msk-scroll grid max-h-[62vh] grid-cols-2 gap-3 overflow-y-auto pr-1">
        {list.map((g) => (
          <div key={g.id} className="flex items-center justify-between rounded-sm border border-border bg-panel-raised p-3">
            <div className="min-w-0">
              <div className="truncate font-display text-[14px] text-text-primary">{g.label || g.id}</div>
              <div className="font-mono text-[11px] text-text-muted">
                {g.id} · {g.type.join(', ')} · {(counts[g.id] ?? 0)} 🚗
              </div>
            </div>
            <div className="flex shrink-0 gap-1.5">
              {canEdit && (
                <button onClick={() => { setEditing(g); setIsNew(false) }} className="rounded-sm border border-border p-2 text-text-secondary hover:text-accent">
                  <Pencil size={14} />
                </button>
              )}
              {canDelete && (
                <button onClick={() => setPendingDelete(g)} className="rounded-sm border border-border p-2 text-text-secondary hover:text-red-400">
                  <Trash2 size={14} />
                </button>
              )}
            </div>
          </div>
        ))}
      </div>

      {editing && (
        <GarageForm t={t} initial={editing} isNew={isNew} onSave={save} onClose={() => setEditing(null)} toast={toast} jobsList={jobsList} />
      )}

      {pendingDelete && (
        <ConfirmDialog
          title={t.delete}
          message={fmt(t.confirm_delete_garage, pendingDelete.label || pendingDelete.id, counts[pendingDelete.id] ?? 0)}
          confirmLabel={t.delete}
          cancelLabel={t.cancel}
          onCancel={() => setPendingDelete(null)}
          onConfirm={() => {
            const g = pendingDelete
            setPendingDelete(null)
            void del(g)
          }}
        />
      )}
    </div>
  )
}

import { useState } from 'react'
import { Pencil, Plus, Trash2 } from 'lucide-react'
import type { AdminStrings } from './i18n'
import { fmt } from './i18n'
import type { CallResult, ImpoundDef } from './types'
import { VEHICLE_TYPES } from './types'
import { Btn, ConfirmDialog, CoordList, Field, Modal, NumInput, Section, Select, StatusText, TextInput, ToggleRow } from './ui'
import { BlipEditor, FeeEditor, MarkerEditor, PedEditor, TypeSelector, Text3dEditor } from './editors'

type Call = (endpoint: string, payload?: unknown) => Promise<CallResult | null>

function emptyImpound(): ImpoundDef {
  return {
    id: '',
    label: '',
    type: ['car', 'truck'],
    park_dist: 5.0,
    warp: false,
    pedmodel: { enable: true, model: 'csb_trafficwarden', distance: 20.0 },
    text3d: { enable: true, label: '~g~Open Impound', size: 0.8 },
    marker: { enable: true, distance: 5.0, type: 27, size: { a: 1, b: 1, c: 1 }, color: { a: 255, b: 255, c: 255, alpha: 100 } },
    blip: { enable: true, id: 524, color: 17, scale: 0.8 },
    fee: { enable: true, price: 150, account: 'money' },
    locations: [],
    park_out: [],
  }
}

function ImpoundForm({
  t,
  initial,
  isNew,
  onSave,
  onClose,
  toast,
}: {
  t: AdminStrings
  initial: ImpoundDef
  isNew: boolean
  onSave: (i: ImpoundDef) => Promise<void>
  onClose: () => void
  toast: { msg: string; ok: boolean } | null
}) {
  const [im, setIm] = useState<ImpoundDef>(initial)
  const [busy, setBusy] = useState(false)
  const set = (patch: Partial<ImpoundDef>) => setIm((prev) => ({ ...prev, ...patch }))

  const save = async () => {
    setBusy(true)
    await onSave(im)
    setBusy(false)
  }

  return (
    <Modal
      title={isNew ? t.create_impound : `${t.edit}: ${initial.label || initial.id}`}
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
              <TextInput value={im.id} onChange={(id) => set({ id })} disabled={!isNew} />
            </Field>
            <Field label={t.label}>
              <TextInput value={im.label} onChange={(label) => set({ label })} />
            </Field>
          </div>
          <TypeSelector t={t} value={im.type} onChange={(type) => set({ type })} />
          <Field label={t.park_dist}>
            <NumInput step={0.5} value={im.park_dist} onChange={(park_dist) => set({ park_dist })} />
          </Field>
          <ToggleRow label={t.warp} checked={im.warp} onChange={(warp) => set({ warp })} />
        </Section>

        <Section title={t.locations}>
          <CoordList
            title={t.locations}
            addLabel={t.add_location}
            useLabel={t.use_position}
            coords={im.locations}
            onChange={(locations) => set({ locations })}
          />
          <CoordList
            title={t.park_out}
            addLabel={t.add_parkout}
            useLabel={t.use_position}
            coords={im.park_out}
            onChange={(park_out) => set({ park_out })}
          />
        </Section>

        <FeeEditor t={t} value={im.fee} onChange={(fee) => set({ fee })} />
        <BlipEditor t={t} value={im.blip} onChange={(blip) => set({ blip })} />
        <PedEditor t={t} value={im.pedmodel} onChange={(pedmodel) => set({ pedmodel })} />
        <Text3dEditor t={t} value={im.text3d} onChange={(text3d) => set({ text3d })} disabled={im.pedmodel.enable} />
        <MarkerEditor t={t} value={im.marker} onChange={(marker) => set({ marker })} disabled={im.pedmodel.enable} />
      </div>
    </Modal>
  )
}

export function ImpoundsTab({
  t,
  impounds,
  perms,
  call,
  notify,
  toast,
}: {
  t: AdminStrings
  impounds: ImpoundDef[]
  perms: Record<string, boolean>
  call: Call
  notify: (msg: string, ok: boolean) => void
  toast: { msg: string; ok: boolean } | null
}) {
  const [editing, setEditing] = useState<ImpoundDef | null>(null)
  const [isNew, setIsNew] = useState(false)
  const [search, setSearch] = useState('')
  const [typeFilter, setTypeFilter] = useState('')
  const [pendingDelete, setPendingDelete] = useState<ImpoundDef | null>(null)

  const canCreate = perms['impound.create']
  const canEdit = perms['impound.edit']
  const canDelete = perms['impound.delete']

  const typeOptions = [
    { value: '', label: t.filter_all_types },
    ...VEHICLE_TYPES.map((ty) => ({ value: ty, label: ty })),
  ]

  const list = impounds
    .filter((im) => `${im.id} ${im.label}`.toLowerCase().includes(search.toLowerCase()))
    .filter((im) => !typeFilter || im.type.includes(typeFilter))
    .sort((a, b) => a.id.localeCompare(b.id))

  const save = async (im: ImpoundDef) => {
    const res = await call('admin:impound:save', { impound: im })
    if (res?.ok) {
      notify(t.saved, true)
      setEditing(null)
    } else {
      notify(`${t.error}: ${res?.err ?? ''}`, false)
    }
  }

  const del = async (im: ImpoundDef) => {
    const res = await call('admin:impound:delete', { id: im.id })
    if (res?.ok) notify(t.saved, true)
    else notify(`${t.error}: ${res?.err ?? ''}`, false)
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
            <Btn variant="accent" onClick={() => { setEditing(emptyImpound()); setIsNew(true) }}>
              <Plus size={14} /> {t.create_impound}
            </Btn>
          )}
        </div>
      </div>

      <div className="msk-scroll grid max-h-[62vh] grid-cols-2 gap-3 overflow-y-auto pr-1">
        {list.map((im) => (
          <div key={im.id} className="flex items-center justify-between rounded-sm border border-border bg-panel-raised p-3">
            <div className="min-w-0">
              <div className="truncate font-display text-[14px] text-text-primary">{im.label || im.id}</div>
              <div className="font-mono text-[11px] text-text-muted">
                {im.id} · {im.type.join(', ')} · ${im.fee?.price ?? 0}
              </div>
            </div>
            <div className="flex shrink-0 gap-1.5">
              {canEdit && (
                <button onClick={() => { setEditing(im); setIsNew(false) }} className="rounded-sm border border-border p-2 text-text-secondary hover:text-accent">
                  <Pencil size={14} />
                </button>
              )}
              {canDelete && (
                <button onClick={() => setPendingDelete(im)} className="rounded-sm border border-border p-2 text-text-secondary hover:text-red-400">
                  <Trash2 size={14} />
                </button>
              )}
            </div>
          </div>
        ))}
      </div>

      {editing && (
        <ImpoundForm t={t} initial={editing} isNew={isNew} onSave={save} onClose={() => setEditing(null)} toast={toast} />
      )}

      {pendingDelete && (
        <ConfirmDialog
          title={t.delete}
          message={fmt(t.confirm_delete_impound, pendingDelete.label || pendingDelete.id)}
          confirmLabel={t.delete}
          cancelLabel={t.cancel}
          onCancel={() => setPendingDelete(null)}
          onConfirm={() => {
            const im = pendingDelete
            setPendingDelete(null)
            void del(im)
          }}
        />
      )}
    </div>
  )
}

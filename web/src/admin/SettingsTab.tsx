import { useEffect, useRef, useState } from 'react'
import type { AdminStrings } from './i18n'
import type { CallResult, GarageDef, SettingsPayload } from './types'
import { Btn, ColorInput, Field, NumInput, Section, Select, StatusText, TextInput, ToggleRow } from './ui'
import { DEFAULT_THEME, applyTheme, normalizeTheme, type Theme } from '../lib/theme'

type Call = (endpoint: string, payload?: unknown) => Promise<CallResult | null>

export function SettingsTab({
  t,
  settings,
  garages,
  scripts,
  call,
  notify,
  toast,
}: {
  t: AdminStrings
  settings: SettingsPayload
  garages: GarageDef[]
  scripts: { target: string[]; vehicleKeys: string[] }
  call: Call
  notify: (msg: string, ok: boolean) => void
  toast: { msg: string; ok: boolean } | null
}) {
  const [s, setS] = useState<SettingsPayload>(settings)
  const [busy, setBusy] = useState(false)
  const set = (patch: Partial<SettingsPayload>) => setS((prev) => ({ ...prev, ...patch }))

  const theme = normalizeTheme(s.Theme)
  // Restore the persisted theme if the user previews colours but leaves without
  // saving. A ref keeps the cleanup pointed at the latest saved theme.
  const savedTheme = useRef<Theme>(normalizeTheme(settings.Theme))
  savedTheme.current = normalizeTheme(settings.Theme)
  useEffect(() => () => applyTheme(savedTheme.current), [])

  const setTheme = (patch: Partial<Theme>) =>
    setS((prev) => {
      const next = { ...normalizeTheme(prev.Theme), ...patch }
      applyTheme(next)
      return { ...prev, Theme: next }
    })

  const garageOptions = garages
    .slice()
    .sort((a, b) => a.id.localeCompare(b.id))
    .map((g) => ({ value: g.id, label: `${g.id} — ${g.label}` }))

  const toOptions = (list: string[]) => list.map((v) => ({ value: v, label: v }))

  const save = async () => {
    setBusy(true)
    const res = await call('admin:settings:save', { settings: s })
    setBusy(false)
    if (res?.ok) notify(t.saved, true)
    else notify(`${t.error}: ${res?.err ?? ''}`, false)
  }

  return (
    <div className="flex flex-col gap-4">
      <Section title={t.general}>
        <div className="grid grid-cols-2 gap-3">
          <Field label={t.locale}>
            <Select
              value={s.Locale}
              onChange={(v) => set({ Locale: v })}
              options={[
                { value: 'en', label: 'English' },
                { value: 'de', label: 'Deutsch' },
                { value: 'hu', label: 'Magyar' },
                { value: 'fr', label: 'Français' },
                { value: 'es', label: 'Español' },
                { value: 'pt', label: 'Português' },
                { value: 'pl', label: 'Polski' },
              ]}
            />
          </Field>
          <Field label={t.parking_mode}>
            <Select
              value={s.Parking}
              onChange={(v) => set({ Parking: v as SettingsPayload['Parking'] })}
              options={[
                { value: 'specific', label: t.parking_specific },
                { value: 'all', label: t.parking_all },
              ]}
            />
          </Field>
          <Field label={t.spawn_mode}>
            <Select
              value={s.spawnMode ?? 'server'}
              onChange={(v) => set({ spawnMode: v as NonNullable<SettingsPayload['spawnMode']> })}
              options={[
                { value: 'server', label: t.spawn_mode_server },
                { value: 'client', label: t.spawn_mode_client },
              ]}
            />
          </Field>
          <p className="col-span-2 font-sans text-[12px] text-text-muted">{t.spawn_mode_hint}</p>
          <Field label={t.hotkey}>
            <NumInput value={s.Hotkey} onChange={(Hotkey) => set({ Hotkey })} />
          </Field>
          <Field label={t.fuel_tank_default}>
            <NumInput step={0.5} value={s.FuelTankDefaultVolume} onChange={(FuelTankDefaultVolume) => set({ FuelTankDefaultVolume })} />
          </Field>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <ToggleRow label={t.debug} checked={s.Debug} onChange={(Debug) => set({ Debug })} />
          <ToggleRow label={t.version_checker} checked={s.VersionChecker} onChange={(VersionChecker) => set({ VersionChecker })} />
          <ToggleRow label={t.default_textui} checked={s.defaultTextUI} onChange={(defaultTextUI) => set({ defaultTextUI })} />
          <ToggleRow label={t.impound_enabled} checked={s.enableImpound} onChange={(enableImpound) => set({ enableImpound })} />
          <ToggleRow label={t.parkout_with_key} checked={s.parkoutWithKey} onChange={(parkoutWithKey) => set({ parkoutWithKey })} />
          <ToggleRow label={t.need_money} checked={s.needEnoughMoney} onChange={(needEnoughMoney) => set({ needEnoughMoney })} />
          <ToggleRow label={t.use_society} checked={s.useSocietyName} onChange={(useSocietyName) => set({ useSocietyName })} />
        </div>
      </Section>

      <Section title={t.tab_impounds}>
        <p className="font-sans text-[12px] text-text-muted">{t.block_impound_ap_hint}</p>
        <ToggleRow
          label={t.block_impound_ap}
          checked={s.blockImpoundWhileAdvancedParked ?? false}
          onChange={(blockImpoundWhileAdvancedParked) => set({ blockImpoundWhileAdvancedParked })}
        />
      </Section>

      <Section title={t.job_vehicles_section}>
        <ToggleRow
          label={t.show_key_owner}
          checked={s.showKeyOwnerName ?? true}
          onChange={(showKeyOwnerName) => set({ showKeyOwnerName })}
        />
        <p className="font-sans text-[12px] text-text-muted">{t.show_key_owner_hint}</p>

        <ToggleRow
          label={t.delete_job_vehicles}
          checked={s.deleteJobVehiclesOnJobChange ?? false}
          onChange={(deleteJobVehiclesOnJobChange) => set({ deleteJobVehiclesOnJobChange })}
        />
        <p className="font-sans text-[12px] text-red-400/90">{t.delete_job_vehicles_hint}</p>
      </Section>

      <Section title={t.default_garages}>
        <div className="grid grid-cols-3 gap-3">
          <Field label={t.default_land}>
            <Select value={s.DefaultGarages.land} onChange={(land) => set({ DefaultGarages: { ...s.DefaultGarages, land } })} options={garageOptions} />
          </Field>
          <Field label={t.default_sea}>
            <Select value={s.DefaultGarages.sea} onChange={(sea) => set({ DefaultGarages: { ...s.DefaultGarages, sea } })} options={garageOptions} />
          </Field>
          <Field label={t.default_air}>
            <Select value={s.DefaultGarages.air} onChange={(air) => set({ DefaultGarages: { ...s.DefaultGarages, air } })} options={garageOptions} />
          </Field>
        </div>
      </Section>

      <Section title={t.target_system}>
        <ToggleRow label={t.enable} checked={s.TargetSystem.enable} onChange={(enable) => set({ TargetSystem: { ...s.TargetSystem, enable } })} />
        <Field label={t.script}>
          <Select
            value={s.TargetSystem.script}
            onChange={(script) => set({ TargetSystem: { ...s.TargetSystem, script } })}
            options={toOptions(scripts.target)}
          />
        </Field>
      </Section>

      <Section title={t.vehicle_keys}>
        <ToggleRow label={t.enable} checked={s.VehicleKeys.enable} onChange={(enable) => set({ VehicleKeys: { ...s.VehicleKeys, enable } })} />
        <Field label={t.script}>
          <Select
            value={s.VehicleKeys.script}
            onChange={(script) => set({ VehicleKeys: { ...s.VehicleKeys, script } })}
            options={toOptions(scripts.vehicleKeys)}
          />
        </Field>
      </Section>

      <Section title={t.admin_command}>
        <Field label={t.admin_command}>
          <TextInput value={s.adminCommand} onChange={(adminCommand) => set({ adminCommand })} />
        </Field>
        <p className="font-sans text-[12px] text-text-muted">{t.admin_command_hint}</p>
      </Section>

      <Section title={t.vehicle_images}>
        <p className="font-sans text-[12px] text-text-muted">{t.vehicle_images_hint}</p>
        <ToggleRow label={t.enable} checked={s.VehicleImages?.enable ?? false} onChange={(enable) => set({ VehicleImages: { ...(s.VehicleImages ?? { ext: 'png' }), enable } })} />
        <Field label={t.image_format}>
          <Select
            value={s.VehicleImages?.ext ?? 'png'}
            onChange={(ext) => set({ VehicleImages: { ...(s.VehicleImages ?? { enable: false }), ext } })}
            options={[
              { value: 'png', label: 'PNG' },
              { value: 'jpg', label: 'JPG' },
              { value: 'webp', label: 'WEBP' },
            ]}
          />
        </Field>
      </Section>

      <Section title={t.colors}>
        <p className="font-sans text-[12px] text-text-muted">{t.colors_hint}</p>
        <Field label={t.brand_tag}>
          <TextInput value={s.BrandTag ?? ''} onChange={(BrandTag) => set({ BrandTag })} placeholder="MSK" />
        </Field>
        <div className="grid grid-cols-3 gap-3">
          <ColorInput label={t.color_accent} value={theme.accent} onChange={(accent) => setTheme({ accent })} />
          <ColorInput label={t.color_bg} value={theme.bg} onChange={(bg) => setTheme({ bg })} />
          <ColorInput label={t.color_panel} value={theme.panel} onChange={(panel) => setTheme({ panel })} />
          <ColorInput label={t.color_text_primary} value={theme.textPrimary} onChange={(textPrimary) => setTheme({ textPrimary })} />
          <ColorInput label={t.color_text_secondary} value={theme.textSecondary} onChange={(textSecondary) => setTheme({ textSecondary })} />
        </div>
        <div className="flex justify-start">
          <Btn variant="default" onClick={() => setTheme(DEFAULT_THEME)}>{t.reset_colors}</Btn>
        </div>
      </Section>

      <div className="flex items-center justify-end gap-3">
        <StatusText toast={toast} />
        <Btn variant="accent" onClick={save} disabled={busy}>{t.save}</Btn>
      </div>
    </div>
  )
}

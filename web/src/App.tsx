import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import type { Mode, Translation, Vehicle, VehicleImageConfig } from './i18n/types'
import { useNuiEvent } from './hooks/useNuiEvent'
import { fetchNui } from './lib/nui'
import { Header } from './components/Header'
import { Sidebar, type Stat } from './components/Sidebar'
import { SearchBar } from './components/SearchBar'
import { VehicleCard } from './components/VehicleCard'
import { RenameDialog } from './components/RenameDialog'
import { AccessDialog } from './components/AccessDialog'
import { EmptyState } from './components/EmptyState'
import { Loader } from './components/Loader'
import { AdminApp } from './admin/AdminApp'
import type { AdminBootstrap } from './admin/types'
import { applyTheme } from './lib/theme'

const LOADING_FALLBACK_MS = 1500

export default function App() {
  const [visible, setVisible] = useState(false)
  const [mode, setMode] = useState<Mode>('parkout')
  const [title, setTitle] = useState('Garage')
  const [t, setT] = useState<Translation | null>(null)

  const [vehicles, setVehicles] = useState<Vehicle[]>([])
  const [loading, setLoading] = useState(false)
  const [statusText, setStatusText] = useState<string | null>(null)

  const [favFilter, setFavFilter] = useState(false)
  const [jobFilter, setJobFilter] = useState(false)
  const [search, setSearch] = useState('')
  const [renameTarget, setRenameTarget] = useState<Vehicle | null>(null)

  // Private garages: the id is needed for the access callbacks, canManageAccess
  // is decided server-side (the owner identifier never reaches the client).
  const [garageId, setGarageId] = useState<string | null>(null)
  const [canManageAccess, setCanManageAccess] = useState(false)
  const [accessOpen, setAccessOpen] = useState(false)

  const [adminData, setAdminData] = useState<AdminBootstrap | null>(null)
  const [vehicleImages, setVehicleImages] = useState<VehicleImageConfig | null>(null)

  const loadTimer = useRef<number | null>(null)

  const loadList = useCallback((next: Mode) => {
    setVehicles([])
    setStatusText(null)
    setLoading(true)
    if (loadTimer.current) window.clearTimeout(loadTimer.current)
    loadTimer.current = window.setTimeout(() => setLoading(false), LOADING_FALLBACK_MS)
    fetchNui(`show-${next}`)
  }, [])

  useNuiEvent((msg) => {
    switch (msg.action) {
      case 'openUI': {
        applyTheme(msg.theme)
        setVehicleImages(msg.vehicleImages ?? null)
        setT(msg.translation)
        setTitle(msg.garageTitle)
        setMode(msg.type)
        setFavFilter(false)
        setJobFilter(false)
        setSearch('')
        setRenameTarget(null)
        setGarageId(msg.garageId ?? null)
        setCanManageAccess(msg.canManageAccess === true)
        setAccessOpen(false)
        setVisible(true)
        loadList(msg.type)
        break
      }
      case 'addVehicle': {
        setLoading(false)
        setStatusText(null)
        setVehicles((prev) => [...prev, msg.vehicle])
        break
      }
      case 'refreshUI': {
        setMode(msg.type)
        loadList(msg.type)
        break
      }
      case 'noVehiclesFound': {
        setLoading(false)
        setVehicles([])
        setStatusText(msg.text)
        break
      }
      case 'closeUI': {
        setVisible(false)
        setAdminData(null)
        break
      }
      case 'openAdmin': {
        setAdminData(msg.data)
        break
      }
    }
  })

  const closeAdmin = useCallback(() => {
    setAdminData(null)
    fetchNui('admin:close')
  }, [])

  const close = useCallback(() => {
    setVisible(false)
    setRenameTarget(null)
    setAccessOpen(false)
    fetchNui('closeGarage')
  }, [])

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== 'Escape' || !visible) return
      // Escape closes an open dialog first; only tear down the whole panel when
      // none is open. Without this the same keypress that cancels the dialog
      // also closes the garage.
      if (renameTarget) {
        setRenameTarget(null)
        return
      }
      if (accessOpen) {
        setAccessOpen(false)
        return
      }
      close()
    }
    window.addEventListener('keyup', onKey)
    return () => window.removeEventListener('keyup', onKey)
  }, [visible, renameTarget, accessOpen, close])

  const switchMode = (next: Mode) => {
    setMode(next)
    setFavFilter(false)
    setJobFilter(false)
    setSearch('')
    loadList(next)
  }

  const doAction = (v: Vehicle) => {
    if (mode === 'parkin') {
      fetchNui('park-in', { plate: v.plate, fuel: v.fuel })
    } else if (mode === 'parkout') {
      if (v.isStored === 0) return
      fetchNui('park-out', { plate: v.plate, fuel: v.fuel, isStored: v.isStored })
    } else if (mode === 'impound') {
      if (v.locked) return
      fetchNui('impound-park-out', { plate: v.plate, fuel: v.fuel, isStored: 0 })
    }
  }

  const toggleFav = (v: Vehicle) => {
    const next = v.isFav ? 0 : 1
    setVehicles((prev) => prev.map((x) => (x.plate === v.plate ? { ...x, isFav: next } : x)))
    fetchNui('toggle-fav', { plate: v.plate, isFav: !v.isFav })
  }

  const track = (v: Vehicle) => fetchNui('impound-track', { plate: v.plate })

  const submitRename = (nickname: string) => {
    if (renameTarget) {
      fetchNui('rename-vehicle', { plate: renameTarget.plate, nickname })
      setVehicles((prev) =>
        prev.map((x) => (x.plate === renameTarget.plate ? { ...x, label: nickname || x.label } : x)),
      )
    }
    setRenameTarget(null)
  }

  // The faction filter only makes sense in the park-out list, and only while that
  // list actually holds job vehicles. Tying "is the filter applied" to the same
  // condition that shows the button means a refresh which drops the last job
  // vehicle can never strand the player on a permanently empty list.
  const hasJobVehicles = useMemo(
    () => mode === 'parkout' && vehicles.some((v) => v.isJob),
    [mode, vehicles],
  )
  const jobFilterActive = jobFilter && hasJobVehicles

  const filtered = useMemo(() => {
    let list = vehicles
    if (favFilter) list = list.filter((v) => Boolean(v.isFav))
    if (jobFilterActive) list = list.filter((v) => Boolean(v.isJob))
    if (search.trim()) {
      const q = search.toUpperCase()
      list = list.filter(
        (v) => v.label.toUpperCase().includes(q) || v.plate.toUpperCase().includes(q),
      )
    }
    return list
  }, [vehicles, favFilter, jobFilterActive, search])

  if (adminData) return <AdminApp data={adminData} onClose={closeAdmin} />

  if (!visible || !t) return null

  const listTitle = jobFilterActive
    ? t.job_vehicles
    : favFilter
      ? t.favorite_vehicles
      : t.vehicles

  const favCount = vehicles.filter((v) => Boolean(v.isFav)).length
  const stats: Stat[] =
    mode === 'parkout'
      ? [
          { label: t.stat_total, value: vehicles.length },
          { label: t.stat_parked, value: vehicles.filter((v) => v.isStored === 1).length },
          { label: t.stat_out, value: vehicles.filter((v) => v.isStored === 0).length },
          { label: t.stat_favorites, value: favCount },
        ]
      : mode === 'parkin'
        ? [
            { label: t.stat_total, value: vehicles.length },
            { label: t.stat_favorites, value: favCount },
          ]
        : [{ label: t.stat_total, value: vehicles.length }]

  return (
    <div className="flex h-full w-full items-center justify-center font-sans">
      <div className="relative w-[1280px] max-w-[95vw] msk-panel animate-slide-up">
        <Header
          title={title}
          onClose={close}
          accessLabel={t.access_button}
          onManageAccess={
            canManageAccess && garageId ? () => setAccessOpen(true) : undefined
          }
        />

        <div className="grid grid-cols-[180px_1fr] gap-0">
          <Sidebar
            mode={mode}
            contextLabel={mode === 'impound' ? 'Impound' : 'Garage'}
            title={title}
            t={t}
            stats={stats}
            onChange={switchMode}
          />

          <div className="flex flex-col gap-4 p-5">
            <SearchBar
              value={search}
              placeholder={t.search_input_placeholder}
              showFav={mode !== 'impound'}
              favActive={favFilter}
              onSearch={setSearch}
              onToggleFav={() => setFavFilter((f) => !f)}
              showJob={hasJobVehicles}
              jobActive={jobFilterActive}
              jobLabel={t.job_vehicles}
              onToggleJob={() => setJobFilter((f) => !f)}
            />

            <div className="flex items-center justify-between">
              <h2 className="msk-label text-[11px]">{listTitle}</h2>
              <span className="font-mono text-[11px] text-text-muted">{filtered.length}</span>
            </div>

            <div className="msk-scroll grid h-[min(640px,82vh)] content-start grid-cols-4 gap-4 overflow-y-auto pr-1">
              {loading ? (
                <div className="col-span-4">
                  <Loader />
                </div>
              ) : statusText || filtered.length === 0 ? (
                <div className="col-span-4">
                  <EmptyState text={statusText ?? t.no_vehicles} />
                </div>
              ) : (
                filtered.map((v) => (
                  <VehicleCard
                    key={`${v.plate}-${v.id}`}
                    vehicle={v}
                    mode={mode}
                    t={t}
                    images={vehicleImages}
                    onAction={() => doAction(v)}
                    onToggleFav={() => toggleFav(v)}
                    onRename={() => setRenameTarget(v)}
                    onTrack={() => track(v)}
                  />
                ))
              )}
            </div>
          </div>
        </div>

        {renameTarget && (
          <RenameDialog
            vehicle={renameTarget}
            t={t}
            onSubmit={submitRename}
            onCancel={() => setRenameTarget(null)}
          />
        )}

        {accessOpen && garageId && (
          <AccessDialog
            garageId={garageId}
            garageLabel={title}
            t={t}
            onClose={() => setAccessOpen(false)}
          />
        )}
      </div>
    </div>
  )
}

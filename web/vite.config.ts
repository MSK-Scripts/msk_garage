import { defineConfig, type Plugin } from 'vite'
import react from '@vitejs/plugin-react'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

// Dev-only: the per-model vehicle images live in the resource folder
// `../vehicle_images` (outside the Vite root and only reachable via nui:// in
// game). To preview them in the browser dev server we expose two endpoints:
//   GET /__vehicle_images   -> JSON list of available image filenames
//   GET /vehicle_images/<f> -> the raw image file
// This plugin has no effect on the production build (apply: 'serve').
function vehicleImagesDev(): Plugin {
  const dir = fileURLToPath(new URL('../vehicle_images', import.meta.url))
  const mime: Record<string, string> = { png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg', webp: 'image/webp' }
  return {
    name: 'vehicle-images-dev',
    apply: 'serve',
    configureServer(server) {
      server.middlewares.use('/__vehicle_images', (_req, res) => {
        let files: string[] = []
        try {
          files = fs.readdirSync(dir).filter((f) => /\.(png|jpe?g|webp)$/i.test(f))
        } catch {
          /* folder may not exist */
        }
        res.setHeader('Content-Type', 'application/json')
        res.end(JSON.stringify(files))
      })
      server.middlewares.use('/vehicle_images/', (req, res, next) => {
        const name = path.basename(decodeURIComponent((req.url || '').split('?')[0]))
        const file = path.join(dir, name)
        fs.readFile(file, (err, data) => {
          if (err) {
            res.statusCode = 404
            res.end('not found')
            return
          }
          const ext = path.extname(file).slice(1).toLowerCase()
          res.setHeader('Content-Type', mime[ext] || 'application/octet-stream')
          res.end(data)
        })
        void next
      })
    },
  }
}

// NUI loads assets from the resource over a file:// style origin, so we
// emit relative paths. The build output lands directly in ../html which
// is what fxmanifest's ui_page points at.
export default defineConfig({
  plugins: [react(), vehicleImagesDev()],
  base: './',
  build: {
    outDir: '../html',
    emptyOutDir: true,
    assetsDir: 'assets',
    chunkSizeWarningLimit: 1500,
  },
})

import { CarFront } from 'lucide-react'

export function EmptyState({ text }: { text: string }) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 py-16 text-center animate-fade-in">
      <CarFront className="h-10 w-10 text-text-muted/60" strokeWidth={1.5} />
      <p className="msk-label text-xs">{text}</p>
    </div>
  )
}

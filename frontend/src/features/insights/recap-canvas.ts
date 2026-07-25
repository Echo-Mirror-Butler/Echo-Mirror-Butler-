/**
 * recap-canvas.ts — Issue #617
 *
 * Shareable recap image export. Reuses the Canvas → Blob → navigator.share
 * pattern established in dashboard/streak-card-canvas.ts rather than
 * introducing a second export mechanism.
 */
import { PERIOD_LABELS, type Recap } from './recap'

const CARD_SIZE = 1080
const DEFAULT_APP_NAME = 'EchoMirror'
const DEFAULT_URL = 'echomirrorbutler.vercel.app'

export type ShareRecapResult = 'shared' | 'downloaded' | 'cancelled'

export function drawRecapCard(canvas: HTMLCanvasElement, recap: Recap): void {
  canvas.width = CARD_SIZE
  canvas.height = CARD_SIZE

  const ctx = canvas.getContext('2d')
  if (!ctx) {
    throw new Error('Canvas 2D context is not available')
  }

  const background = ctx.createLinearGradient(0, 0, CARD_SIZE, CARD_SIZE)
  background.addColorStop(0, '#0a0f24')
  background.addColorStop(1, '#141d3d')
  ctx.fillStyle = background
  ctx.fillRect(0, 0, CARD_SIZE, CARD_SIZE)

  ctx.strokeStyle = 'rgba(129, 140, 248, 0.35)'
  ctx.lineWidth = 4
  ctx.strokeRect(48, 48, CARD_SIZE - 96, CARD_SIZE - 96)

  const centerX = CARD_SIZE / 2
  ctx.textAlign = 'center'
  ctx.textBaseline = 'middle'

  ctx.fillStyle = '#818cf8'
  ctx.font = '600 56px system-ui, -apple-system, Segoe UI, Roboto, sans-serif'
  ctx.fillText(`✦ ${DEFAULT_APP_NAME} Recap`, centerX, 150)

  ctx.fillStyle = 'rgba(255,255,255,0.75)'
  ctx.font = '40px system-ui, -apple-system, Segoe UI, Roboto, sans-serif'
  ctx.fillText(PERIOD_LABELS[recap.period], centerX, 220)

  // Four stat tiles.
  const tiles: { label: string; value: string }[] = [
    { label: 'Logs', value: String(recap.totalLogs) },
    { label: 'Avg mood', value: recap.avgMood != null ? String(recap.avgMood) : '—' },
    { label: 'Longest streak', value: `${recap.longestStreak}🔥` },
    { label: 'ECHO earned', value: `${recap.echoEarned}🪙` },
  ]

  const cols = 2
  const tileW = 420
  const tileH = 200
  const gap = 40
  const gridW = cols * tileW + gap
  const startX = centerX - gridW / 2
  const startY = 300

  tiles.forEach((tile, i) => {
    const col = i % cols
    const row = Math.floor(i / cols)
    const x = startX + col * (tileW + gap)
    const y = startY + row * (tileH + gap)

    ctx.fillStyle = 'rgba(129, 140, 248, 0.12)'
    roundRect(ctx, x, y, tileW, tileH, 24)
    ctx.fill()

    ctx.fillStyle = '#ffffff'
    ctx.font = '700 90px system-ui, -apple-system, Segoe UI, Roboto, sans-serif'
    ctx.fillText(tile.value, x + tileW / 2, y + tileH / 2 - 10)

    ctx.fillStyle = 'rgba(255,255,255,0.65)'
    ctx.font = '36px system-ui, -apple-system, Segoe UI, Roboto, sans-serif'
    ctx.fillText(tile.label, x + tileW / 2, y + tileH - 40)
  })

  // Top habit line.
  const topHabit = recap.topHabits[0]
  if (topHabit) {
    ctx.fillStyle = 'rgba(255,255,255,0.85)'
    ctx.font = '600 44px system-ui, -apple-system, Segoe UI, Roboto, sans-serif'
    ctx.fillText(`Top habit: ${topHabit.habit}`, centerX, 830)
  }

  ctx.fillStyle = 'rgba(129, 140, 248, 0.85)'
  ctx.font = '600 38px system-ui, -apple-system, Segoe UI, Roboto, sans-serif'
  ctx.fillText(DEFAULT_URL, centerX, 990)
}

function roundRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number,
): void {
  ctx.beginPath()
  ctx.moveTo(x + r, y)
  ctx.arcTo(x + w, y, x + w, y + h, r)
  ctx.arcTo(x + w, y + h, x, y + h, r)
  ctx.arcTo(x, y + h, x, y, r)
  ctx.arcTo(x, y, x + w, y, r)
  ctx.closePath()
}

export function createRecapCardBlob(recap: Recap): Promise<Blob> {
  const canvas = document.createElement('canvas')
  drawRecapCard(canvas, recap)

  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => {
      if (blob) resolve(blob)
      else reject(new Error('Could not export recap card image'))
    }, 'image/png')
  })
}

function downloadBlob(blob: Blob, filename: string): void {
  const objectUrl = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = objectUrl
  link.download = filename
  document.body.appendChild(link)
  link.click()
  link.remove()
  URL.revokeObjectURL(objectUrl)
}

export async function shareRecapCard(recap: Recap): Promise<ShareRecapResult> {
  const blob = await createRecapCardBlob(recap)
  const filename = `echomirror-recap-${recap.period}.png`
  const file = new File([blob], filename, { type: 'image/png' })

  const shareData: ShareData = {
    files: [file],
    title: `My ${DEFAULT_APP_NAME} recap`,
    text: `My ${PERIOD_LABELS[recap.period].toLowerCase()} on ${DEFAULT_APP_NAME}: ${recap.totalLogs} logs, ${recap.longestStreak}-day streak!`,
  }

  if (
    typeof navigator.share === 'function' &&
    typeof navigator.canShare === 'function' &&
    navigator.canShare(shareData)
  ) {
    try {
      await navigator.share(shareData)
      return 'shared'
    } catch (error) {
      if (error instanceof DOMException && error.name === 'AbortError') {
        return 'cancelled'
      }
    }
  }

  downloadBlob(blob, filename)
  return 'downloaded'
}

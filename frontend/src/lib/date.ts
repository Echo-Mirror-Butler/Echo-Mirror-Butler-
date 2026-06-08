export function formatDateTime(value: string): string {
  return new Intl.DateTimeFormat(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value))
}

export function formatDate(value: string): string {
  return new Intl.DateTimeFormat(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  }).format(new Date(value))
}

export function toDateInputValue(date: Date): string {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

export function moodToEmoji(mood: number | null): string {
  switch (mood) {
    case 1:
      return '😞'
    case 2:
      return '😕'
    case 3:
      return '😐'
    case 4:
      return '🙂'
    case 5:
      return '😄'
    default:
      return '—'
  }
}

export function getCountdownLabel(targetIso: string): string {
  const now = Date.now()
  const target = new Date(targetIso).getTime()
  const deltaMs = Math.max(0, target - now)
  const totalMinutes = Math.floor(deltaMs / 60000)
  const days = Math.floor(totalMinutes / (60 * 24))
  const hours = Math.floor((totalMinutes % (60 * 24)) / 60)
  const minutes = totalMinutes % 60

  if (days > 0) {
    return `${days}d ${hours}h left`
  }

  return `${hours}h ${minutes}m left`
}

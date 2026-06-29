export function generateErrorReferenceCode() {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) {
    return crypto.randomUUID().slice(0, 8).toUpperCase()
  }

  return Math.random().toString(36).slice(2, 10).toUpperCase()
}

export function getErrorMessage(value: unknown) {
  if (value instanceof Error) {
    return value.message
  }

  if (typeof value === 'string') {
    return value
  }

  return 'An unexpected problem occurred.'
}

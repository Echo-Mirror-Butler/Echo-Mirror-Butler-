import { supabase } from './supabase'

export const LOG_IMAGE_BUCKET = 'log-images'
export const MAX_LOG_IMAGE_BYTES = 5 * 1024 * 1024
export const ALLOWED_LOG_IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/webp']

export async function uploadLogImage(userId: string, entryId: string, file: File): Promise<string> {
  const ext = file.name.split('.').pop() ?? 'jpg'
  const path = `${userId}/${entryId}.${ext}`

  const { error } = await supabase.storage
    .from(LOG_IMAGE_BUCKET)
    .upload(path, file, { upsert: true, contentType: file.type })

  if (error) throw error
  return path
}

export async function removeLogImage(path: string): Promise<void> {
  const { error } = await supabase.storage.from(LOG_IMAGE_BUCKET).remove([path])
  if (error) throw error
}

export async function getLogImageSignedUrl(path: string): Promise<string | null> {
  const { data, error } = await supabase.storage
    .from(LOG_IMAGE_BUCKET)
    .createSignedUrl(path, 3600)

  if (error) return null
  return data.signedUrl
}

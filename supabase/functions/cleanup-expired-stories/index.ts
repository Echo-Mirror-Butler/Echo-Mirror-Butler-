import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

type SupabaseLike = any

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const STORY_BUCKET = 'stories'
const GRACE_PERIOD_MINUTES = 30

export function extractStorageObjectPaths(urls: unknown): string[] {
  if (!Array.isArray(urls)) return []

  const objectPaths = new Set<string>()

  for (const value of urls) {
    if (typeof value !== 'string') continue

    try {
      const parsed = new URL(value)
      const pathname = decodeURIComponent(parsed.pathname)
      const prefix = `/storage/v1/object/public/${STORY_BUCKET}/`

      if (!pathname.startsWith(prefix)) continue

      const objectPath = pathname.slice(prefix.length).trim()
      if (!objectPath) continue

      objectPaths.add(objectPath)
    } catch {
      // Ignore non-URL values. Story media is stored in the public stories bucket.
    }
  }

  return [...objectPaths]
}

async function removeStoryMedia(
  supabase: SupabaseLike,
  storyId: string,
  imageUrls: unknown,
): Promise<void> {
  const objectPaths = extractStorageObjectPaths(imageUrls)
  if (objectPaths.length === 0) return

  try {
    const { error } = await supabase.storage.from(STORY_BUCKET).remove(objectPaths)

    if (error) {
      const message = (error as { message?: string }).message ?? 'Unknown storage error'
      if (!/not found|does not exist|no such object/i.test(message)) {
        console.warn(`Failed to remove media for story ${storyId}: ${message}`)
      }
    }
  } catch (error) {
    console.warn(`Storage cleanup threw for story ${storyId}: ${String(error)}`)
  }
}

async function deleteStoryRow(
  supabase: SupabaseLike,
  storyId: string,
): Promise<void> {
  const { error } = await supabase.from('stories').delete().eq('id', storyId)

  if (error) {
    console.warn(`Failed to delete story row ${storyId}: ${error.message}`)
  }
}

Deno.serve(async (req) => {
  if (req.method !== 'POST' && req.method !== 'GET') {
    return new Response('Method not allowed', { status: 405 })
  }

  const supabase = createClient(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
    {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    },
  )

  const cutoff = new Date(Date.now() - GRACE_PERIOD_MINUTES * 60_000).toISOString()

  const { data: expiredStories, error: fetchError } = await supabase
    .from('stories')
    .select('id, image_urls, expires_at')
    .lt('expires_at', cutoff)

  if (fetchError) {
    console.error('Failed to fetch expired stories:', fetchError)
    return new Response(
      JSON.stringify({
        error: fetchError.message,
        deleted: 0,
        checked: 0,
        grace_period_minutes: GRACE_PERIOD_MINUTES,
        cutoff,
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }

  const stories = (expiredStories ?? []) as Array<{
    id: string
    image_urls?: unknown
    expires_at?: string
  }>

  let deleted = 0

  for (const story of stories) {
    const storyId = story.id
    if (!storyId) continue

    try {
      await removeStoryMedia(supabase, storyId, story.image_urls)
      await deleteStoryRow(supabase, storyId)
      deleted++
    } catch (error) {
      console.warn(`Cleanup failed for story ${storyId}: ${String(error)}`)
    }
  }

  return new Response(
    JSON.stringify({
      deleted,
      checked: stories.length,
      grace_period_minutes: GRACE_PERIOD_MINUTES,
      cutoff,
      message:
        'Stories older than the grace-period cutoff are removed from storage and the stories table.',
    }),
    { headers: { 'Content-Type': 'application/json' } },
  )
})

export default {} 

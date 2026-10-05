/**
 * cleanup-expired-stories — Supabase Edge Function
 *
 * Issue #763: this cron-only job had no caller check, so any unauthenticated
 * client could trigger it and force early deletion of stories that are already
 * past `expires_at` minus the grace window. The work itself is idempotent and
 * destroys nothing that was not already scheduled to go away, but it is still
 * an admin operation reachable by the public.
 *
 * The request path now runs `cronDenialResponse(req)` first (see
 * `../_shared/require-cron-secret.ts`): a missing `CRON_SECRET` fails closed
 * with 500, a caller without the credential gets 401, and the scheduled
 * invocation authenticates with `Authorization: Bearer <CRON_SECRET>` or
 * `x-cron-secret: <CRON_SECRET>`.
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import {
  assertCronSecretConfigured,
  cronDenialResponse,
  type EnvLike,
} from '../_shared/require-cron-secret.ts'
import { shouldServe } from "../_shared/serve-guard.ts";

type SupabaseLike = any

const STORY_BUCKET = 'stories'
const GRACE_PERIOD_MINUTES = 30

export interface CleanupDeps {
  createClientImpl?: typeof createClient
}

assertCronSecretConfigured((message) => {
  // Fail closed on the request path, but say it at boot as well so a
  // misconfigured deployment is visible in the logs before the first cron tick.
  console.error(`cleanup-expired-stories: ${message}`)
})

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

/**
 * The whole request path, exported so tests can drive it without binding a
 * port. `env` and the Supabase client factory are injectable for the same
 * reason.
 */
export async function handleCleanupRequest(
  req: Request,
  env: EnvLike = Deno.env,
  deps: CleanupDeps = {},
): Promise<Response> {
  if (req.method !== 'POST' && req.method !== 'GET') {
    return new Response('Method not allowed', { status: 405 })
  }

  const denial = cronDenialResponse(req, env)
  if (denial) return denial

  const supabaseUrl = env.get('SUPABASE_URL')
  const supabaseServiceRoleKey = env.get('SUPABASE_SERVICE_ROLE_KEY')

  if (!supabaseUrl || !supabaseServiceRoleKey) {
    return new Response(
      JSON.stringify({
        error: 'SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be configured',
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }

  const clientFactory = deps.createClientImpl ?? createClient
  const supabase = clientFactory(supabaseUrl, supabaseServiceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  }) as SupabaseLike

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
}

if (shouldServe()) Deno.serve((req) => handleCleanupRequest(req))

export default {}

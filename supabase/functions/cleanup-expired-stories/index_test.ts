import {
  assertEquals,
  assertStringIncludes,
} from 'https://deno.land/std@0.192.0/testing/asserts.ts'
import {
  extractStorageObjectPaths,
  handleCleanupRequest,
} from './index.ts'

Deno.test('extractStorageObjectPaths keeps only story-bucket objects', () => {
  const urls = [
    'https://project.supabase.co/storage/v1/object/public/stories/user-123/abc.png',
    'https://project.supabase.co/storage/v1/object/public/stories/user-123/abc.png',
    'https://cdn.example.com/other/path.png',
    'https://project.supabase.co/storage/v1/object/public/other/user-123/other.png',
    'not-a-url',
  ]

  assertEquals(extractStorageObjectPaths(urls), ['user-123/abc.png'])
})

Deno.test('extractStorageObjectPaths returns empty array for non-story data', () => {
  assertEquals(extractStorageObjectPaths([]), [])
  assertEquals(extractStorageObjectPaths(['https://cdn.example.com/x.jpg']), [])
})

const SECRET = 'cron-secret-for-tests'

const envWith = (vars: Record<string, string>) => ({
  get: (key: string) => vars[key],
})

const READY_ENV = envWith({
  CRON_SECRET: SECRET,
  SUPABASE_URL: 'https://project.supabase.co',
  SUPABASE_SERVICE_ROLE_KEY: 'service-role-key',
})

const request = (headers: Record<string, string> = {}) =>
  new Request('http://localhost/cleanup-expired-stories', {
    method: 'POST',
    headers,
  })

/** Minimal stand-in for the Supabase client, recording what the job touched. */
function createFakeClient(
  stories: Array<{ id: string; image_urls?: unknown; expires_at?: string }>,
) {
  const removedPaths: string[][] = []
  const deletedStoryIds: string[] = []
  let selectCount = 0

  const client = {
    from(table: string) {
      if (table !== 'stories') throw new Error(`unexpected table: ${table}`)
      return {
        select: () => ({
          lt: () => {
            selectCount++
            return Promise.resolve({ data: stories, error: null })
          },
        }),
        delete: () => ({
          eq: (_column: string, id: string) => {
            deletedStoryIds.push(id)
            return Promise.resolve({ error: null })
          },
        }),
      }
    },
    storage: {
      from: () => ({
        remove: (paths: string[]) => {
          removedPaths.push(paths)
          return Promise.resolve({ error: null })
        },
      }),
    },
  }

  return {
    client,
    removedPaths,
    deletedStoryIds,
    get selectCount() {
      return selectCount
    },
  }
}

Deno.test('handleCleanupRequest rejects an anonymous caller and does no work', async () => {
  const fake = createFakeClient([])
  const res = await handleCleanupRequest(request(), READY_ENV, {
    createClientImpl: () => fake.client as never,
  })

  assertEquals(res.status, 401)
  assertStringIncludes(await res.text(), 'Missing scheduler credential')
  assertEquals(fake.selectCount, 0)
  assertEquals(fake.deletedStoryIds, [])
  assertEquals(fake.removedPaths, [])
})

Deno.test('handleCleanupRequest rejects a wrong credential', async () => {
  const fake = createFakeClient([])
  const res = await handleCleanupRequest(
    request({ 'x-cron-secret': 'guessed-value' }),
    READY_ENV,
    { createClientImpl: () => fake.client as never },
  )

  assertEquals(res.status, 401)
  assertEquals(fake.selectCount, 0)
})

Deno.test('handleCleanupRequest fails closed when CRON_SECRET is not configured', async () => {
  const fake = createFakeClient([])
  const res = await handleCleanupRequest(
    request({ authorization: `Bearer ${SECRET}` }),
    envWith({
      SUPABASE_URL: 'https://project.supabase.co',
      SUPABASE_SERVICE_ROLE_KEY: 'service-role-key',
    }),
    { createClientImpl: () => fake.client as never },
  )

  assertEquals(res.status, 500)
  assertStringIncludes(await res.text(), 'CRON_SECRET')
  assertEquals(fake.selectCount, 0)
})

Deno.test('handleCleanupRequest runs the job for the scheduler credential', async () => {
  const stories = [
    {
      id: 'story-1',
      image_urls: [
        'https://project.supabase.co/storage/v1/object/public/stories/u1/a.png',
      ],
      expires_at: '2026-09-01T00:00:00.000Z',
    },
    { id: 'story-2', image_urls: null, expires_at: '2026-09-01T00:00:00.000Z' },
  ]
  const fake = createFakeClient(stories)

  const res = await handleCleanupRequest(
    request({ authorization: `Bearer ${SECRET}` }),
    READY_ENV,
    { createClientImpl: () => fake.client as never },
  )

  assertEquals(res.status, 200)
  const body = JSON.parse(await res.text())
  assertEquals(body.deleted, 2)
  assertEquals(body.checked, 2)
  assertEquals(body.grace_period_minutes, 30)
  assertEquals(fake.selectCount, 1)
  // Media is removed before the row, and only for the story that has any.
  assertEquals(fake.removedPaths, [['u1/a.png']])
  assertEquals(fake.deletedStoryIds, ['story-1', 'story-2'])
})

Deno.test('handleCleanupRequest also accepts the x-cron-secret header', async () => {
  const fake = createFakeClient([])
  const res = await handleCleanupRequest(
    request({ 'x-cron-secret': SECRET }),
    READY_ENV,
    { createClientImpl: () => fake.client as never },
  )

  assertEquals(res.status, 200)
})

Deno.test('handleCleanupRequest keeps rejecting unsupported methods', async () => {
  const res = await handleCleanupRequest(
    new Request('http://localhost/cleanup-expired-stories', {
      method: 'PUT',
      headers: { 'x-cron-secret': SECRET },
    }),
    READY_ENV,
  )

  assertEquals(res.status, 405)
})

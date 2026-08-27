/**
 * EchoMirror Service Worker
 *
 * Handles:
 * - Push notifications (#303)
 * - PWA offline caching (#433)
 *   - Cache-first for static assets (JS, CSS, fonts, images)
 *   - Network-first for API / Supabase requests (falls back to cache)
 *   - App-shell precache on install so the SPA loads offline
 */

const CACHE_VERSION = 'v1'
const STATIC_CACHE = `echomirror-static-${CACHE_VERSION}`
const API_CACHE = `echomirror-api-${CACHE_VERSION}`

// App-shell resources to precache on install
const PRECACHE_URLS = ['/', '/offline.html']

// ── Install — precache app shell ──────────────────────────────────────────────

self.addEventListener('install', (event) => {
  self.skipWaiting()
  // #605: intentionally NOT swallowing cache.addAll() failures here anymore.
  // A missing precache entry (e.g. offline.html deleted by accident) should
  // fail the install loudly — surfaced in devtools/CI — rather than silently
  // shipping a service worker with no real offline fallback.
  event.waitUntil(caches.open(STATIC_CACHE).then((cache) => cache.addAll(PRECACHE_URLS)))
})

// ── Activate — clean up old caches ───────────────────────────────────────────

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter((k) => k !== STATIC_CACHE && k !== API_CACHE)
            .map((k) => caches.delete(k)),
        ),
      )
      .then(() => clients.claim()),
  )
})

// ── Fetch — routing strategy ──────────────────────────────────────────────────

self.addEventListener('fetch', (event) => {
  const { request } = event
  const url = new URL(request.url)

  // Only handle GET requests; let mutations through unmodified
  if (request.method !== 'GET') return

  // API / Supabase — network-first, fall back to cache
  if (
    url.hostname.includes('supabase') ||
    url.pathname.startsWith('/functions/') ||
    url.pathname.startsWith('/rest/') ||
    url.pathname.startsWith('/auth/')
  ) {
    event.respondWith(networkFirst(request, API_CACHE))
    return
  }

  // Static assets (JS, CSS, fonts, images, icons) — cache-first
  if (
    url.pathname.match(/\.(js|css|woff2?|ttf|eot|png|jpg|jpeg|svg|ico|webp)$/)
  ) {
    event.respondWith(cacheFirst(request, STATIC_CACHE))
    return
  }

  // Navigation requests — network-first, fall back to the dedicated offline
  // page (#605), then the cached app shell, then a bare 503 as a last resort.
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request).catch(() =>
        caches
          .match('/offline.html')
          .then((r) => r ?? caches.match('/'))
          .then((r) => r ?? new Response('Offline', { status: 503 })),
      ),
    )
    return
  }
})

async function cacheFirst(request, cacheName) {
  const cached = await caches.match(request)
  if (cached) return cached

  const response = await fetch(request)
  if (response.ok) {
    const cache = await caches.open(cacheName)
    cache.put(request, response.clone())
  }
  return response
}

async function networkFirst(request, cacheName) {
  try {
    const response = await fetch(request)
    if (response.ok) {
      const cache = await caches.open(cacheName)
      cache.put(request, response.clone())
    }
    return response
  } catch {
    const cached = await caches.match(request)
    if (cached) return cached
    return new Response(JSON.stringify({ error: 'You are offline' }), {
      status: 503,
      headers: { 'Content-Type': 'application/json' },
    })
  }
}

// ── Push notifications ────────────────────────────────────────────────────────

self.addEventListener('push', (event) => {
  const data = event.data ? event.data.json() : {}
  const title = data.title ?? 'EchoMirror'
  const options = {
    body: data.body ?? 'Time to log your mood today! Keep your streak alive.',
    icon: '/icons/icon-192.png',
    badge: '/icons/icon-192.png',
    tag: 'daily-reminder',
    renotify: true,
    data: { url: data.url ?? '/logs/new' },
  }

  event.waitUntil(self.registration.showNotification(title, options))
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  const targetUrl = event.notification.data?.url ?? '/logs/new'

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          client.navigate(targetUrl)
          return client.focus()
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetUrl)
      }
    }),
  )
})

/**
 * EchoMirror Service Worker
 * Issue #303 — Push notification support
 *
 * Handles:
 * - Push event: display notification
 * - notificationclick: open /logs/new when notification is clicked
 */

self.addEventListener('push', (event) => {
  const data = event.data ? event.data.json() : {}
  const title = data.title ?? 'EchoMirror'
  const options = {
    body: data.body ?? "Time to log your mood today! Keep your streak alive. 🔥",
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
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
      // Focus existing window if open
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          client.navigate(targetUrl)
          return client.focus()
        }
      }
      // Otherwise open a new window
      if (clients.openWindow) {
        return clients.openWindow(targetUrl)
      }
    }),
  )
})

self.addEventListener('install', () => {
  self.skipWaiting()
})

self.addEventListener('activate', (event) => {
  event.waitUntil(clients.claim())
})
